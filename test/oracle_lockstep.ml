open Core
open Hardcaml
module Top = Ppu.Top_checker_to_framebuf

(* Test configuration *)
let rom_env_var = "ROM"
let default_rom = "flat_bg.gb"
let oracle_dir = "_oracle"
let dut_dir = "_dut" 
let artifacts_dir = "../_artifacts"

(* Working with RGB555 pixels directly as int values *)


(* Run HardCaml DUT simulation to generate framebuffer *)
let run_hardcaml_dut ~rom:_ ~output_dir ~lines =
  let screen_width = 160 in
  let screen_height = 144 in
  let total_pixels = screen_width * screen_height in
  
  (* Create and setup HardCaml simulator *)
  let module Sim = Cyclesim.With_interface(Top.I)(Top.O) in
  let sim = Sim.create (Top.create (Scope.create ())) in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  
  (* Reset and start simulation *)
  Cyclesim.reset sim;
  inputs.start := Bits.vdd;
  Cyclesim.cycle sim;
  inputs.start := Bits.gnd;
  
  (* Wait for completion *)
  while Bits.to_bool !(outputs.busy) do
    Cyclesim.cycle sim;
  done;
  
  (* Read framebuffer data *)
  let framebuffer_data = Array.create ~len:total_pixels 0 in
  for addr = 0 to total_pixels - 1 do
    inputs.b_addr := Bits.of_int ~width:15 addr;
    Cyclesim.cycle sim;  (* Wait for read latency *)
    framebuffer_data.(addr) <- Bits.to_int !(outputs.b_rdata);
  done;
  
  (* Extract RGB555 pixels - only extract requested lines *)
  let pixels = Array.init (160 * lines) ~f:(fun i ->
    framebuffer_data.(i)
  ) in
  
  (* Create output directory and save as RGB555 *)
  Core_unix.mkdir_p output_dir;
  let rgb555_path = output_dir ^ "/frame_0300.rgb555" in
  let oc = Out_channel.create rgb555_path in
  Array.iter pixels ~f:(fun rgb555 ->
    (* Write as little-endian 16-bit value *)
    Out_channel.output_char oc (Char.of_int_exn (rgb555 land 0xFF));
    Out_channel.output_char oc (Char.of_int_exn ((rgb555 lsr 8) land 0xFF));
  );
  Out_channel.close oc;
  
  pixels

(* Run oracle (SameBoy) *)
let run_oracle ~rom ~output_dir:_ =
  (* Use sameboy_headless tool from _build directory *)
  let sameboy_tool = "./sameboy_headless" in
  
  (* Run sameboy_headless - need 300 frames for flat_bg.gb to fully initialize with boot ROM *)
  let cmd = Printf.sprintf "%s %s 300" sameboy_tool rom in
  Printf.printf "Running oracle: %s\n" cmd;
  
  (* Capture stdout from sameboy_headless, redirect stderr to /dev/null *)
  let cmd_with_stderr = cmd ^ " 2>/dev/null" in
  let ic = Caml_unix.open_process_in cmd_with_stderr in
  let expected_bytes = 160 * 144 * 2 in
  let buf = Bytes.create expected_bytes in
  let rec read_all pos remaining =
    if remaining = 0 then pos
    else begin
      let bytes_read = In_channel.input ic ~buf ~pos ~len:remaining in
      if bytes_read = 0 then pos (* EOF reached *)
      else read_all (pos + bytes_read) (remaining - bytes_read)
    end
  in
  let total_bytes_read = read_all 0 expected_bytes in
  let result = Caml_unix.close_process_in ic in
  
  match result with
  | WEXITED 0 when total_bytes_read = (160 * 144 * 2) ->
    (* Parse RGB555 data from stdout and extract first two lines *)
    let pixels = Array.init (160 * 2) ~f:(fun i ->
      let offset = i * 2 in
      let low_byte = Char.to_int (Bytes.get buf offset) in
      let high_byte = Char.to_int (Bytes.get buf (offset + 1)) in
      (* Reconstruct RGB555 from little-endian bytes *)
      (high_byte lsl 8) lor low_byte
    ) in
    pixels
  | WEXITED 0 -> failwith (Printf.sprintf "Oracle produced %d bytes, expected %d" total_bytes_read (160 * 144 * 2))
  | WEXITED code -> failwith (Printf.sprintf "Oracle failed with exit code %d" code)
  | WSIGNALED signal -> failwith (Printf.sprintf "Oracle killed by signal %d" signal)
  | WSTOPPED signal -> failwith (Printf.sprintf "Oracle stopped by signal %d" signal)

(* Compare pixel streams *)
let compare_pixels ~oracle ~dut =
  let mismatches = ref [] in
  
  Array.iteri oracle ~f:(fun i oracle_pixel ->
    let dut_pixel = dut.(i) in
    if oracle_pixel <> dut_pixel then begin
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
    Array.iteri pixels ~f:(fun i rgb555 ->
      let y = i / 160 in
      let x = i % 160 in
      let r5 = (rgb555 lsr 10) land 0x1F in
      let g5 = (rgb555 lsr 5) land 0x1F in
      let b5 = rgb555 land 0x1F in
      Printf.fprintf oc "%d,%d,0x%04X,%d,%d,%d\n" y x rgb555 r5 g5 b5
    );
    Out_channel.close oc
  in
  
  write_csv ~filename:"trace.expected.csv" ~pixels:oracle;
  write_csv ~filename:"trace.actual.csv" ~pixels:dut;
  
  (* Write diff info *)
  if not (List.is_empty mismatches) then begin
    let oc = Out_channel.create (artifacts_rom_dir ^/ "mismatches.txt") in
    List.iter mismatches ~f:(fun (y, x, exp, act) ->
      Printf.fprintf oc "(%d, %d): expected 0x%04X -> actual 0x%04X\n" y x exp act
    );
    Out_channel.close oc;
    
    (* Print first 10 mismatches to console *)
    Printf.printf "\nFirst mismatches:\n";
    List.take mismatches 10 |> List.iter ~f:(fun (y, x, exp, act) ->
      let exp_r = (exp lsr 10) land 0x1F in
      let exp_g = (exp lsr 5) land 0x1F in
      let exp_b = exp land 0x1F in
      let act_r = (act lsr 10) land 0x1F in
      let act_g = (act lsr 5) land 0x1F in
      let act_b = act land 0x1F in
      Printf.printf "  (%d, %d): exp 0x%04X (r=%d,g=%d,b=%d) -> act 0x%04X (r=%d,g=%d,b=%d)\n"
        y x exp exp_r exp_g exp_b act act_r act_g act_b
    );
  end

(* Main test *)
let test_lockstep () =
  (* Ensure we're running from the _build directory *)
  let cwd = Sys_unix.getcwd () in
  if String.is_suffix cwd ~suffix:"_build/default/test" then
    Sys_unix.chdir "../../../_build"
  else if not (String.is_suffix cwd ~suffix:"_build") then
    Sys_unix.chdir "_build";
  
  let rom = 
    match Sys.getenv rom_env_var with
    | Some r -> r
    | None -> default_rom
  in
  
  let rom_name = Filename.basename rom |> Filename.chop_extension in
  let oracle_output = oracle_dir ^/ rom_name in
  let dut_output = dut_dir ^/ rom_name in
  
  Printf.printf "Testing with ROM: %s\n" rom;
  
  (* Run oracle *)
  Printf.printf "Running oracle (SameBoy)...\n";
  let oracle_pixels = run_oracle ~rom ~output_dir:oracle_output in
  
  (* Run DUT (HardCaml simulation) *)
  Printf.printf "Running DUT (HardCaml simulation)...\n";
  let dut_pixels = run_hardcaml_dut ~rom ~output_dir:dut_output ~lines:2 in
  
  (* Compare *)
  Printf.printf "Comparing pixel streams (first 2 lines)...\n";
  let mismatches = compare_pixels ~oracle:oracle_pixels ~dut:dut_pixels in
  
  if List.is_empty mismatches then begin
    Printf.printf "✓ All pixels match! (2 lines, 320 pixels)\n";
    Alcotest.(check bool) "pixels match" true true
  end else begin
    Printf.printf "✗ Found %d pixel mismatches\n" (List.length mismatches);
    write_artifacts ~rom_name ~oracle:oracle_pixels ~dut:dut_pixels ~mismatches;
    Printf.printf "Artifacts written to %s/%s/\n" artifacts_dir rom_name;
    Alcotest.fail (Printf.sprintf "%d pixels don't match" (List.length mismatches))
  end

(* Alcotest setup *)
let () =
  let open Alcotest in
  run "Oracle Lockstep Tests" [
    "differential", [
      test_case "SameBoy vs DUT (2 lines)" `Quick test_lockstep;
    ];
  ]