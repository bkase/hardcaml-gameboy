open Core

(* Test configuration *)
let rom_path = "out/flat_bg.gb"

let oracle_dir = "_build/_oracle/phase1_checker"

let dut_dir = "_build/_dut"

let artifacts_dir = "_artifacts/phase1_checker"

let frame_number = 300

(* Run SameBoy oracle to generate expected frame *)
let run_sameboy_oracle ~workspace_root =
  (* Ensure oracle directory exists *)
  Core_unix.mkdir_p oracle_dir ;

  (* Run sameboy_headless tool *)
  let sameboy_tool = workspace_root ^/ "out/sameboy_headless" in
  let rom = workspace_root ^/ rom_path in
  let cmd = Printf.sprintf "%s %s %d 2>/dev/null" sameboy_tool rom frame_number in

  (* Capture RGB555 output from sameboy_headless *)
  let ic = Caml_unix.open_process_in cmd in
  let expected_bytes = 160 * 144 * 2 in
  let buf = Bytes.create expected_bytes in

  let rec read_all pos remaining =
    if remaining = 0 then pos
    else begin
      let bytes_read = In_channel.input ic ~buf ~pos ~len:remaining in
      if bytes_read = 0 then pos else read_all (pos + bytes_read) (remaining - bytes_read)
    end
  in

  let total_bytes_read = read_all 0 expected_bytes in
  let result = Caml_unix.close_process_in ic in

  match result with
  | WEXITED 0 when total_bytes_read = expected_bytes ->
    (* Parse RGB555 data from stdout *)
    let pixels =
      Array.init (160 * 144) ~f:(fun i ->
          let offset = i * 2 in
          let low_byte = Char.to_int (Bytes.get buf offset) in
          let high_byte = Char.to_int (Bytes.get buf (offset + 1)) in
          (* Reconstruct RGB555 from little-endian bytes *)
          (high_byte lsl 8) lor low_byte)
    in

    (* Save oracle RGB555 raw file *)
    let rgb555_path = oracle_dir ^/ Printf.sprintf "frame_%04d.rgb555" frame_number in
    let oc = Out_channel.create ~binary:true rgb555_path in
    Array.iter pixels ~f:(fun rgb555 ->
        (* Write as little-endian 16-bit value *)
        Out_channel.output_byte oc (rgb555 land 0xFF) ;
        Out_channel.output_byte oc ((rgb555 lsr 8) land 0xFF)) ;
    Out_channel.close oc ;

    (* Save oracle PPM file *)
    let ppm_path = "_build/_oracle/phase1_checker.ppm" in
    Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:ppm_path ~width:160 ~height:144
      ~buf:pixels ;

    pixels
  | WEXITED 0 ->
    failwith
      (Printf.sprintf "Oracle produced %d bytes, expected %d" total_bytes_read
         expected_bytes)
  | WEXITED code -> failwith (Printf.sprintf "Oracle failed with exit code %d" code)
  | WSIGNALED signal -> failwith (Printf.sprintf "Oracle killed by signal %d" signal)
  | WSTOPPED signal -> failwith (Printf.sprintf "Oracle stopped by signal %d" signal)

(* Run the spec to generate actual frame *)
let run_spec () =
  (* Ensure DUT directory exists *)
  Core_unix.mkdir_p dut_dir ;

  (* Generate the checkerboard pattern using the spec *)
  let pixels = Hardcaml_gameboy_spec.Phase1_checker_spec.render () in

  (* Save DUT RGB555 raw file *)
  let rgb555_path = dut_dir ^/ "phase1_checker.rgb555" in
  let oc = Out_channel.create ~binary:true rgb555_path in
  Array.iter pixels ~f:(fun rgb555 ->
      (* Write as little-endian 16-bit value *)
      Out_channel.output_byte oc (rgb555 land 0xFF) ;
      Out_channel.output_byte oc ((rgb555 lsr 8) land 0xFF)) ;
  Out_channel.close oc ;

  (* Save DUT PPM file *)
  let ppm_path = dut_dir ^/ "phase1_checker.ppm" in
  Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:ppm_path ~width:160 ~height:144
    ~buf:pixels ;

  pixels

(* Write artifacts on mismatch *)
let write_diff_artifacts ~expected ~actual =
  Core_unix.mkdir_p artifacts_dir ;

  (* Save expected PPM *)
  let expected_ppm = artifacts_dir ^/ "expected.ppm" in
  Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:expected_ppm ~width:160 ~height:144
    ~buf:expected ;

  (* Save actual PPM *)
  let actual_ppm = artifacts_dir ^/ "actual.ppm" in
  Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:actual_ppm ~width:160 ~height:144
    ~buf:actual ;

  (* Create diff image *)
  let diff =
    Array.init (160 * 144) ~f:(fun i ->
        let exp_val = expected.(i) in
        let act_val = actual.(i) in
        if exp_val = act_val then 0x0000 (* Black for matching pixels *)
        else 0x7C00 (* Red for mismatches *))
  in

  let diff_ppm = artifacts_dir ^/ "diff.ppm" in
  Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:diff_ppm ~width:160 ~height:144
    ~buf:diff ;

  (* Log mismatches *)
  let mismatches = ref [] in
  Array.iteri expected ~f:(fun i exp_val ->
      let act_val = actual.(i) in
      if exp_val <> act_val then begin
        let x = i mod 160 in
        let y = i / 160 in
        mismatches := (x, y, exp_val, act_val) :: !mismatches
      end) ;

  if not (List.is_empty !mismatches) then begin
    Printf.printf "\nFirst 10 mismatches:\n" ;
    List.take (List.rev !mismatches) 10
    |> List.iter ~f:(fun (x, y, exp_val, act_val) ->
           let exp_r5, exp_g5, exp_b5 = Hardcaml_gameboy_spec.Rgb.unpack_rgb555 exp_val in
           let act_r5, act_g5, act_b5 = Hardcaml_gameboy_spec.Rgb.unpack_rgb555 act_val in
           Printf.printf
             "  (%d,%d): exp=0x%04x (r=%d,g=%d,b=%d) act=0x%04x (r=%d,g=%d,b=%d) | \
              ΔR=%d,ΔG=%d,ΔB=%d\n"
             x y exp_val exp_r5 exp_g5 exp_b5 act_val act_r5 act_g5 act_b5
             (act_r5 - exp_r5) (act_g5 - exp_g5) (act_b5 - exp_b5))
  end ;

  List.length !mismatches

(* Compute simple checksum of pixel data *)
let compute_checksum pixels =
  let sum =
    Array.fold pixels ~init:0 ~f:(fun acc pixel -> (acc + pixel) land 0xFFFFFFFF)
  in
  Printf.sprintf "0x%08x" sum

(* Main test function *)
let test_spec_vs_sameboy () =
  (* Get workspace root *)
  let workspace_root =
    let cwd = Core_unix.getcwd () in
    if String.is_suffix cwd ~suffix:"/_build/default/test" then
      (* We're in the dune build directory *)
      cwd |> Filename.dirname |> Filename.dirname |> Filename.dirname
    else
      match Sys.getenv "DUNE_WORKSPACE_ROOT" with
      | Some root -> root
      | None -> cwd
  in

  Printf.printf "Workspace root: %s\n" workspace_root ;
  Printf.printf "Running Phase 1 Spec vs SameBoy comparison test...\n" ;

  (* Run oracle *)
  Printf.printf "Running SameBoy oracle for frame %d...\n" frame_number ;
  let oracle_pixels = run_sameboy_oracle ~workspace_root in

  (* Run spec *)
  Printf.printf "Running spec to generate checkerboard pattern...\n" ;
  let spec_pixels = run_spec () in

  (* Compare *)
  Printf.printf "Comparing %d pixels...\n" (Array.length oracle_pixels) ;

  (* Check if arrays are equal *)
  let arrays_equal = Array.equal Int.equal oracle_pixels spec_pixels in

  if arrays_equal then begin
    (* Compute and print checksum *)
    let checksum = compute_checksum oracle_pixels in
    Printf.printf "✓ PASS: Spec matches SameBoy oracle exactly!\n" ;
    Printf.printf "  Checksum: %s\n" checksum ;
    Alcotest.(check pass) "spec matches oracle" () ()
  end
  else begin
    (* Write artifacts and fail *)
    let mismatch_count =
      write_diff_artifacts ~expected:oracle_pixels ~actual:spec_pixels
    in
    Printf.printf "✗ FAIL: Found %d pixel mismatches\n" mismatch_count ;
    Printf.printf "  Artifacts written to %s/\n" artifacts_dir ;
    Alcotest.fail
      (Printf.sprintf "Frame comparison failed - %d mismatches - see %s/" mismatch_count
         artifacts_dir)
  end

(* Alcotest test suite *)
let test_cases = [ "spec_phase1_vs_sameboy", `Quick, test_spec_vs_sameboy ]

let () = Alcotest.run "PPU Phase 1 Spec Tests" [ "spec", test_cases ]
