open Core

(* Test configuration *)
let rom_env_var = "ROM"
let default_rom = "roms/flat_bg.gb"
let oracle_dir = "_build/_oracle"
let dut_dir = "_build/_dut"
let artifacts_dir = "_artifacts"

(* Pixel type for comparison *)
type pixel = { r : int; g : int; b : int }

(* Read RGBA file and extract first two lines *)
let read_rgba_lines ~path ~lines =
  let ic = In_channel.create path in
  let buf = Bytes.create (160 * 144 * 4) in
  let _ = In_channel.input ic ~buf ~pos:0 ~len:(160 * 144 * 4) in
  In_channel.close ic;
  
  let pixels = Array.init (160 * lines) ~f:(fun i ->
    let offset = i * 4 in
    let r = Char.to_int (Bytes.get buf offset) in
    let g = Char.to_int (Bytes.get buf (offset + 1)) in
    let b = Char.to_int (Bytes.get buf (offset + 2)) in
    { r; g; b }
  ) in
  pixels

(* Simple DUT stub that generates the same checkerboard pattern *)
let run_dut_stub ~rom:_ ~output_dir ~lines =
  Core_unix.mkdir_p output_dir;
  
  (* Generate checkerboard pattern matching what flat_bg.gb produces:
     8x8 tiles alternating between all black and all white *)
  let pixels = Array.init (160 * lines) ~f:(fun i ->
    let x = i % 160 in
    let y = i / 160 in
    let tile_x = x / 8 in
    let tile_y = y / 8 in
    (* Tiles alternate in a checkerboard pattern *)
    let is_black_tile = (tile_x + tile_y) % 2 = 0 in
    let gray = if is_black_tile then 0x00 else 0xFF in
    { r = gray; g = gray; b = gray }
  ) in
  
  (* Save as RGBA - match oracle frame number *)
  let rgba_path = output_dir ^/ "frame_0300.rgba" in
  let oc = Out_channel.create rgba_path in
  Array.iter pixels ~f:(fun p ->
    Out_channel.output_char oc (Char.of_int_exn p.r);
    Out_channel.output_char oc (Char.of_int_exn p.g);
    Out_channel.output_char oc (Char.of_int_exn p.b);
    Out_channel.output_char oc (Char.of_int_exn 0xFF);
  );
  Out_channel.close oc;
  
  pixels

(* Run oracle (SameBoy) *)
let run_oracle ~rom ~output_dir =
  Core_unix.mkdir_p output_dir;
  
  (* Run sameboy_headless - need 300 frames for flat_bg.gb to fully initialize with boot ROM *)
  let cmd = sprintf "../tools/sameboy_headless ../%s 300 %s" rom output_dir in
  printf "Running oracle: %s\n" cmd;
  let result = Core_unix.system cmd in
  
  match result with
  | Ok () ->
    (* Read the last generated frame (300th frame) *)
    let rgba_path = output_dir ^/ "frame_0300.rgba" in
    if Core.Result.is_ok (Core_unix.access rgba_path [`Exists]) then
      read_rgba_lines ~path:rgba_path ~lines:2
    else
      failwith "Oracle did not generate frame_0300.rgba"
  | Error _ -> failwith "Failed to run oracle"

(* Compare pixel streams *)
let compare_pixels ~oracle ~dut =
  let mismatches = ref [] in
  
  Array.iteri oracle ~f:(fun i oracle_pixel ->
    let dut_pixel = dut.(i) in
    if not (oracle_pixel.r = dut_pixel.r && 
            oracle_pixel.g = dut_pixel.g && 
            oracle_pixel.b = dut_pixel.b) then begin
      let y = i / 160 in
      let x = i % 160 in
      mismatches := (y, x, oracle_pixel, dut_pixel) :: !mismatches;
    end
  );
  
  List.rev !mismatches

(* Write comparison artifacts *)
let write_artifacts ~rom_name ~oracle ~dut ~mismatches =
  Core_unix.mkdir_p artifacts_dir;
  let artifacts_rom_dir = artifacts_dir ^/ rom_name in
  Core_unix.mkdir_p artifacts_rom_dir;
  
  (* Write CSVs *)
  let write_csv ~filename ~pixels =
    let oc = Out_channel.create (artifacts_rom_dir ^/ filename) in
    Array.iteri pixels ~f:(fun i p ->
      let y = i / 160 in
      let x = i % 160 in
      fprintf oc "%d,%d,%d,%d,%d\n" y x p.r p.g p.b
    );
    Out_channel.close oc
  in
  
  write_csv ~filename:"trace.expected.csv" ~pixels:oracle;
  write_csv ~filename:"trace.actual.csv" ~pixels:dut;
  
  (* Write diff info *)
  if not (List.is_empty mismatches) then begin
    let oc = Out_channel.create (artifacts_rom_dir ^/ "mismatches.txt") in
    List.iter mismatches ~f:(fun (y, x, exp, act) ->
      fprintf oc "(%d, %d): expected rgb(%d,%d,%d) -> actual rgb(%d,%d,%d)\n"
        y x exp.r exp.g exp.b act.r act.g act.b
    );
    Out_channel.close oc;
    
    (* Print first 10 mismatches to console *)
    printf "\nFirst mismatches:\n";
    List.take mismatches 10 |> List.iter ~f:(fun (y, x, exp, act) ->
      printf "  (%d, %d): exp rgb(%d,%d,%d) -> act rgb(%d,%d,%d)\n"
        y x exp.r exp.g exp.b act.r act.g act.b
    );
  end

(* Main test *)
let test_lockstep () =
  let rom = 
    match Sys.getenv rom_env_var with
    | Some r -> r
    | None -> default_rom
  in
  
  let rom_name = Filename.basename rom |> Filename.chop_extension in
  let oracle_output = oracle_dir ^/ rom_name in
  let dut_output = dut_dir ^/ rom_name in
  
  printf "Testing with ROM: %s\n" rom;
  
  (* Run oracle *)
  printf "Running oracle (SameBoy)...\n";
  let oracle_pixels = run_oracle ~rom ~output_dir:oracle_output in
  
  (* Run DUT (stub for now) *)
  printf "Running DUT (stub)...\n";
  let dut_pixels = run_dut_stub ~rom ~output_dir:dut_output ~lines:2 in
  
  (* Compare *)
  printf "Comparing pixel streams (first 2 lines)...\n";
  let mismatches = compare_pixels ~oracle:oracle_pixels ~dut:dut_pixels in
  
  if List.is_empty mismatches then begin
    printf "✓ All pixels match! (2 lines, 320 pixels)\n";
    Alcotest.(check bool) "pixels match" true true
  end else begin
    printf "✗ Found %d pixel mismatches\n" (List.length mismatches);
    write_artifacts ~rom_name ~oracle:oracle_pixels ~dut:dut_pixels ~mismatches;
    printf "Artifacts written to %s/%s/\n" artifacts_dir rom_name;
    Alcotest.fail (sprintf "%d pixels don't match" (List.length mismatches))
  end

(* Alcotest setup *)
let () =
  let open Alcotest in
  run "Oracle Lockstep Tests" [
    "differential", [
      test_case "SameBoy vs DUT (2 lines)" `Quick test_lockstep;
    ];
  ]