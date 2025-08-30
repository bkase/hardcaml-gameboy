open Core

(* Test configuration *)
let rom_path = "out/flat_bg.gb"

let oracle_dir = "_build/_oracle/phase2_bg"

let dut_dir = "_build/_dut"

let artifacts_dir = "_artifacts/phase2_bg"

let frame_number = 300

(* Run SameBoy oracle to generate expected frame and VRAM dump *)
let run_sameboy_oracle ~workspace_root =
  (* Ensure oracle directory exists *)
  Core_unix.mkdir_p oracle_dir ;

  (* Run sameboy tool with VRAM dump option *)
  let sameboy_tool = workspace_root ^/ "out/sameboy_headless" in
  let rom = workspace_root ^/ rom_path in
  let cmd = Printf.sprintf "%s %s %d --vram 2>/dev/null" sameboy_tool rom frame_number in

  (* Capture output from sameboy tool *)
  let ic = Caml_unix.open_process_in cmd in

  (* First read RGB555 frame data (160*144*2 bytes) *)
  let frame_bytes = 160 * 144 * 2 in
  let frame_buf = Bytes.create frame_bytes in
  let rec read_all buf pos remaining =
    if remaining = 0 then pos
    else begin
      let bytes_read = In_channel.input ic ~buf ~pos ~len:remaining in
      if bytes_read = 0 then pos
      else read_all buf (pos + bytes_read) (remaining - bytes_read)
    end
  in

  let frame_read = read_all frame_buf 0 frame_bytes in

  (* Then read VRAM dump (0x2000 bytes for $8000-$9FFF) *)
  let vram_bytes = 0x2000 in
  let vram_buf = Bytes.create vram_bytes in
  let vram_read = read_all vram_buf 0 vram_bytes in

  let result = Caml_unix.close_process_in ic in

  match result with
  | WEXITED 0 when frame_read = frame_bytes && vram_read = vram_bytes ->
    (* Parse RGB555 frame data *)
    let pixels =
      Array.init (160 * 144) ~f:(fun i ->
          let offset = i * 2 in
          let low_byte = Char.to_int (Bytes.get frame_buf offset) in
          let high_byte = Char.to_int (Bytes.get frame_buf (offset + 1)) in
          (high_byte lsl 8) lor low_byte)
    in

    (* Save oracle RGB555 raw file *)
    let rgb555_path = oracle_dir ^/ Printf.sprintf "frame_%04d.rgb555" frame_number in
    let oc = Out_channel.create ~binary:true rgb555_path in
    Array.iter pixels ~f:(fun rgb555 ->
        Out_channel.output_byte oc (rgb555 land 0xFF) ;
        Out_channel.output_byte oc ((rgb555 lsr 8) land 0xFF)) ;
    Out_channel.close oc ;

    (* Save oracle PPM file *)
    let ppm_path = oracle_dir ^/ "phase2_bg.ppm" in
    Hardcaml_gameboy_spec.Ppm.write_ppm_rgb555 ~path:ppm_path ~width:160 ~height:144
      ~buf:pixels ;

    (* Save VRAM dump *)
    let vram_path = oracle_dir ^/ Printf.sprintf "vram_%04d.bin" frame_number in
    let oc = Out_channel.create ~binary:true vram_path in
    Out_channel.output_bytes oc vram_buf ;
    Out_channel.close oc ;

    pixels, vram_buf
  | WEXITED 0 ->
    failwith
      (Printf.sprintf "Oracle produced wrong amount of data: frame=%d, vram=%d" frame_read
         vram_read)
  | WEXITED code -> failwith (Printf.sprintf "Oracle failed with exit code %d" code)
  | WSIGNALED signal -> failwith (Printf.sprintf "Oracle killed by signal %d" signal)
  | WSTOPPED signal -> failwith (Printf.sprintf "Oracle stopped by signal %d" signal)

(* Run the Phase 2 BG spec to generate actual frame *)
let run_spec ~vram =
  (* Ensure DUT directory exists *)
  Core_unix.mkdir_p dut_dir ;

  (* Generate the BG using the spec with fixed SCX=0, SCY=0, BGP=0xE4 *)
  let pixels =
    Hardcaml_gameboy_spec.Phase2_bg_spec.render ~vram ~scx:0 ~scy:0 ~bgp:0xE4
  in

  (* Save DUT RGB555 raw file *)
  let rgb555_path = dut_dir ^/ "phase2_bg.rgb555" in
  let oc = Out_channel.create ~binary:true rgb555_path in
  Array.iter pixels ~f:(fun rgb555 ->
      Out_channel.output_byte oc (rgb555 land 0xFF) ;
      Out_channel.output_byte oc ((rgb555 lsr 8) land 0xFF)) ;
  Out_channel.close oc ;

  (* Save DUT PPM file *)
  let ppm_path = dut_dir ^/ "phase2_bg.ppm" in
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
           let exp_r5, exp_g5, exp_b5 =
             Spec_ppu.Gb_math_int.Pixels.unpack_rgb555 exp_val
           in
           let act_r5, act_g5, act_b5 =
             Spec_ppu.Gb_math_int.Pixels.unpack_rgb555 act_val
           in
           Printf.printf
             "  (%d,%d): exp=0x%04x (r=%d,g=%d,b=%d) act=0x%04x (r=%d,g=%d,b=%d) | \
              ΔR=%d,ΔG=%d,ΔB=%d\n"
             x y exp_val exp_r5 exp_g5 exp_b5 act_val act_r5 act_g5 act_b5
             (act_r5 - exp_r5) (act_g5 - exp_g5) (act_b5 - exp_b5))
  end ;

  (* Write mismatch summary *)
  let mismatch_path = artifacts_dir ^/ "mismatches.txt" in
  let oc = Out_channel.create mismatch_path in
  Printf.fprintf oc "Total mismatches: %d / %d pixels\n" (List.length !mismatches)
    (160 * 144) ;
  List.iter (List.rev !mismatches) ~f:(fun (x, y, exp_val, act_val) ->
      Printf.fprintf oc "(%d,%d): expected=0x%04x actual=0x%04x\n" x y exp_val act_val) ;
  Out_channel.close oc ;

  List.length !mismatches

(* Main test function *)
let test_phase2_bg () =
  let workspace_root =
    let cwd = Sys_unix.getcwd () in
    if String.is_suffix cwd ~suffix:"/_build/default/test" then
      cwd |> Filename.dirname |> Filename.dirname |> Filename.dirname
    else
      match Sys.getenv "DUNE_WORKSPACE_ROOT" with
      | Some root -> root
      | None -> cwd
  in

  Printf.printf "Running Phase 2 BG test (frame %d)...\n" frame_number ;

  (* Run oracle to get expected frame and VRAM *)
  Printf.printf "Running SameBoy oracle...\n" ;
  let expected_pixels, vram = run_sameboy_oracle ~workspace_root in

  (* Run spec with VRAM dump *)
  Printf.printf "Running Phase 2 BG spec...\n" ;
  let actual_pixels = run_spec ~vram in

  (* Compare results *)
  Printf.printf "Comparing results...\n" ;
  let matches = Array.for_all2_exn expected_pixels actual_pixels ~f:( = ) in

  if matches then begin
    Printf.printf "[32mPASS:[0m Phase 2 BG spec matches SameBoy oracle exactly!\n" ;
    0
  end
  else begin
    let mismatch_count =
      write_diff_artifacts ~expected:expected_pixels ~actual:actual_pixels
    in
    Printf.printf "[31mFAIL:[0m Phase 2 BG spec has %d pixel mismatches.\n" mismatch_count ;
    Printf.printf "Artifacts written to %s\n" artifacts_dir ;
    1
  end

(* Test entry point *)
let () =
  Alcotest.run "Phase 2 BG vs SameBoy"
    [ ( "BG Rendering"
      , [ Alcotest.test_case "DMG BG path frame 300" `Quick (fun () ->
              let result = test_phase2_bg () in
              if result <> 0 then
                Alcotest.fail "Phase 2 BG spec does not match SameBoy oracle")
        ] )
    ]
