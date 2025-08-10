open Stdio
open Hardcaml

(* Generate Verilog for all synthesizable modules *)

let write_verilog_file ~filename ~circuit =
  (* Redirect stdout to file for Rtl.print *)
  let stdout_backup = Unix.dup Unix.stdout in
  let fd = Unix.openfile filename [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o644 in
  Unix.dup2 fd Unix.stdout ;
  Unix.close fd ;
  flush stdout ;

  (* Generate Verilog to redirected stdout *)
  Rtl.print Verilog circuit ;

  (* Restore original stdout *)
  flush stdout ;
  Unix.dup2 stdout_backup Unix.stdout ;
  Unix.close stdout_backup ;
  printf "Generated %s\n%!" filename

let synthesize_checker_fill () =
  printf "Synthesizing Checker_fill module...\n%!" ;
  let module I = Ppu.Checker_fill.I in
  let module O = Ppu.Checker_fill.O in
  let module Circuit = Circuit.With_interface (I) (O) in
  let scope = Scope.create ~flatten_design:false () in
  let circuit = Circuit.create_exn ~name:"checker_fill" (Ppu.Checker_fill.create scope) in
  write_verilog_file ~filename:"synth/checker_fill.v" ~circuit

let synthesize_framebuf () =
  printf "Synthesizing Framebuf module...\n%!" ;
  let module I = Ppu.Framebuf.I in
  let module O = Ppu.Framebuf.O in
  let module Circuit = Circuit.With_interface (I) (O) in
  let scope = Scope.create ~flatten_design:false () in
  let circuit = Circuit.create_exn ~name:"framebuf" (Ppu.Framebuf.create scope) in
  write_verilog_file ~filename:"synth/framebuf.v" ~circuit

let synthesize_top_checker_to_framebuf () =
  printf "Synthesizing Top_checker_to_framebuf module...\n%!" ;
  let module I = Ppu.Top_checker_to_framebuf.I in
  let module O = Ppu.Top_checker_to_framebuf.O in
  let module Circuit = Circuit.With_interface (I) (O) in
  let scope = Scope.create ~flatten_design:false () in
  let circuit =
    Circuit.create_exn ~name:"top_checker_to_framebuf"
      (Ppu.Top_checker_to_framebuf.create scope)
  in
  write_verilog_file ~filename:"synth/top_checker_to_framebuf.v" ~circuit

let () =
  printf "HardCaml GameBoy Synthesis\n" ;
  printf "==========================\n\n" ;

  (* Create synthesis directory *)
  let _ = Unix.system "mkdir -p synth" in

  (* Synthesize each module *)
  synthesize_checker_fill () ;
  synthesize_framebuf () ;
  synthesize_top_checker_to_framebuf () ;

  printf "\nSynthesis complete! Verilog files are in synth/\n%!"
