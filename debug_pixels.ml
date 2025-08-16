open Base
open Hardcaml
open Stdio

module Bg_fetcher = Ppu.Bg_fetcher_dmg

let debug_first_tile () =
  printf "=== Debug: First Tile Analysis with Waveforms ===\n";
  
  let module Sim = Cyclesim.With_interface (Bg_fetcher.I) (Bg_fetcher.O) in
  let scope = Scope.create ~flatten_design:true () in
  let sim = Sim.create (Bg_fetcher.create scope) in
  (* Skip waveforms for now, focus on the analysis *)
  let sim = sim in
  
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  
  (* Reset and initialize *)
  printf "Initializing...\n";
  Cyclesim.reset sim;
  inputs.start := Bits.gnd;
  Cyclesim.cycle sim;
  
  (* Check initial state *)
  printf "Initial state: addr=%d, we=%b, busy=%b\n"
    (Bits.to_int !(outputs.fb_a_addr))
    (Bits.to_bool !(outputs.fb_a_we))
    (Bits.to_bool !(outputs.busy));
  
  (* Start operation using EXACT same logic as test *)
  printf "Starting operation...\n";
  inputs.start := Bits.vdd;
  Cyclesim.cycle sim;
  inputs.start := Bits.gnd;
  
  (* Monitor using exact same logic as the test *)
  printf "\nCycle-by-cycle analysis (mimicking test logic):\n";
  printf "Cycle | Addr | WE | Busy | Data  | Notes\n";
  printf "------|------|----|----- |-------|-------\n";
  
  let initial_addr = ref (Bits.to_int !(outputs.fb_a_addr)) in
  let cycle_count = ref 1 in (* Already cycled once after start *)
  let pixels_written = ref 0 in
  let last_addr = ref (-1) in (* Initialize to invalid address to count first pixel *)
  
  printf "Initial addr: %d\n" !initial_addr;
  
  let target_pixels = 8 in
  let max_cycles_per_tile = 20 in
  
  while !pixels_written < target_pixels && !cycle_count < max_cycles_per_tile do
    Cyclesim.cycle sim;
    Int.incr cycle_count;
    let current_addr = Bits.to_int !(outputs.fb_a_addr) in
    let current_we = Bits.to_bool !(outputs.fb_a_we) in
    let current_busy = Bits.to_bool !(outputs.busy) in
    let data = Bits.to_int !(outputs.fb_a_wdata) in
    
    (* Count pixel writes using same logic as test *)
    if current_we && current_addr <> !last_addr then begin
      Int.incr pixels_written ;
      printf "      Cycle %d: pixel %d written at addr %d\n" !cycle_count
        !pixels_written current_addr ;
      last_addr := current_addr
    end ;
    
    let note = 
      if current_we && current_addr <> !last_addr then "PIXEL"
      else if current_we then "WRITE(same)"
      else if current_busy then "fetch/idle"
      else "idle"
    in
    
    printf "%5d | %4d | %2s | %4s | %04X | %s\n" 
      !cycle_count current_addr (if current_we then "Y" else "N") (if current_busy then "Y" else "N") data note;
      
    (* Check if FSM went idle *)
    if (not current_busy) && !cycle_count > 20 then begin
      printf "FSM went idle at cycle %d\n" !cycle_count ;
      ()
    end
  done;
  
  printf "\nTotal pixels written: %d\n" !pixels_written;
  printf "\nAnalysis complete.\n"

let () = debug_first_tile ()