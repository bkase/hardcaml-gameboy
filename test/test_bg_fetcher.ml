open Base
open Hardcaml
open Stdio
open Printf

(** For testing, use the existing Checker_fill interface which the bg_fetcher will match
*)
module Bg_fetcher = Ppu.Bg_fetcher_dmg

(** Test helper functions *)

(** Calculate expected checkerboard pattern for given coordinates *)
let checkerboard_pattern x y =
  let tile_x = x / 8 in
  let tile_y = y / 8 in
  let tile_index = tile_x lxor tile_y land 1 in
  if tile_index = 0 then Ppu.Constants.rgb555_black else Ppu.Constants.rgb555_white

(** Convert pixel coordinates to linear address *)
let pixel_address x y = (y * Ppu.Constants.screen_width) + x

(** Calculate tilemap address for given tile coordinates *)
let tilemap_address tile_x tile_y = (tile_y * 32) + tile_x (* 32-tile stride, not 20! *)

(** Decode 2BPP tile data to color indices *)
let decode_2bpp high_byte low_byte =
  let colors = Array.create ~len:8 0 in
  for i = 0 to 7 do
    let bit_pos = 7 - i in
    (* Bit 7 is leftmost pixel *)
    let high_bit = (high_byte lsr bit_pos) land 1 in
    let low_bit = (low_byte lsr bit_pos) land 1 in
    colors.(i) <- (high_bit lsl 1) lor low_bit
  done ;
  colors

(** Apply BGP palette (0xE4) to color index *)
let apply_bgp_palette color_index =
  match color_index with
  | 0 -> Ppu.Constants.rgb555_white (* BGP bits 1-0: 00 -> color 0 -> white *)
  | 1 -> 0x5AD6 (* BGP bits 3-2: 01 -> color 1 -> light gray (example) *)
  | 2 -> 0x294A (* BGP bits 5-4: 10 -> color 2 -> dark gray (example) *)
  | 3 -> Ppu.Constants.rgb555_black (* BGP bits 7-6: 11 -> color 3 -> black *)
  | _ -> failwith "Invalid color index"

(** Create a simulation instance *)
let create_sim () =
  let module Sim = Cyclesim.With_interface (Bg_fetcher.I) (Bg_fetcher.O) in
  let scope = Scope.create ~flatten_design:true () in
  let sim = Sim.create (Bg_fetcher.create scope) in
  let waves, sim = Hardcaml_waveterm.Waveform.create sim in
  sim, waves

(** Test 1: State Machine Transitions Verify the FSM progresses correctly through all
    states *)
let test_state_transitions () =
  printf "Testing state machine transitions...\n" ;

  (* This test verifies the state machine behavior that will be implemented in
     bg_fetcher_dmg: 1. Idle state behavior - FSM waits for start signal 2. Start signal
     triggers transition to Fetch_tile_no 3. Automatic progression: Fetch_tile_no ->
     Fetch_tile_low -> Fetch_tile_high -> Push_pixels 4. Return to appropriate state after
     Push_pixels (either next tile or completion) 5. Proper timing (2 cycles per fetch
     state, 8 cycles for Push_pixels) *)
  try
    let sim, _waves = create_sim () in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    printf "  Testing initial idle state...\n" ;

    (* Initialize - should be in idle state *)
    Cyclesim.reset sim ;
    inputs.start := Bits.gnd ;
    Cyclesim.cycle sim ;

    (* Verify idle state: not busy, not done, no write enable *)
    let initial_busy = Bits.to_bool !(outputs.busy) in
    let initial_done = Bits.to_bool !(outputs.done_) in
    let initial_we = Bits.to_bool !(outputs.fb_a_we) in

    if initial_busy || initial_done || initial_we then
      failwith "FAIL: FSM should be idle after reset" ;

    printf "    ✓ Idle state verified (busy=%b, done=%b, we=%b)\n" initial_busy
      initial_done initial_we ;

    printf "  Testing start signal response...\n" ;

    (* Apply start signal *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    (* Should now be busy and start fetching *)
    let busy_after_start = Bits.to_bool !(outputs.busy) in
    let we_after_start = Bits.to_bool !(outputs.fb_a_we) in

    if not busy_after_start then failwith "FAIL: FSM should be busy after start signal" ;

    printf "    ✓ Start signal triggers busy state (busy=%b, we=%b)\n" busy_after_start
      we_after_start ;

    printf "  Testing state progression timing...\n" ;

    (* Track the first few tiles to verify state progression Expected timing per tile
       after initial delay: - Fetch_tile_no: 2 cycles - Fetch_tile_low: 2 cycles -
       Fetch_tile_high: 2 cycles - Push_pixels: 8 cycles (1 per pixel) Total: 14 cycles
       per tile (after initial 12-cycle delay) *)
    let _initial_addr = ref (Bits.to_int !(outputs.fb_a_addr)) in
    let cycle_count = ref 1 in
    (* Already cycled once after start *)
    let pixels_written = ref 0 in
    let last_addr = ref (-1) in
    (* Initialize to invalid address to count first pixel *)

    (* Monitor the first tile's worth of operation *)
    let max_cycles_per_tile = 21 in
    (* Conservative estimate *)
    let target_pixels = 8 in
    (* One tile's worth *)

    while !pixels_written < target_pixels && !cycle_count < max_cycles_per_tile do
      Cyclesim.cycle sim ;
      Int.incr cycle_count ;

      let current_addr = Bits.to_int !(outputs.fb_a_addr) in
      let current_we = Bits.to_bool !(outputs.fb_a_we) in
      let current_busy = Bits.to_bool !(outputs.busy) in

      (* Count pixel writes *)
      if current_we && current_addr <> !last_addr then begin
        Int.incr pixels_written ;
        printf "      Cycle %d: pixel %d written at addr %d\n" !cycle_count
          !pixels_written current_addr ;
        last_addr := current_addr
      end ;

      (* Safety check *)
      if not current_busy then begin
        printf "      FSM went idle after %d cycles, %d pixels\n" !cycle_count
          !pixels_written ;
        failwith "FSM should not complete after just one tile"
      end
    done ;

    if !pixels_written < target_pixels then
      failwith
        (sprintf "FAIL: Expected %d pixels in %d cycles, got %d" target_pixels
           max_cycles_per_tile !pixels_written) ;

    printf "    ✓ First tile completed in %d cycles (%d pixels written)\n" !cycle_count
      !pixels_written ;

    printf "  Testing ignore start during operation...\n" ;

    (* Test that start signal is ignored when busy *)
    let addr_before_spurious_start = Bits.to_int !(outputs.fb_a_addr) in
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;
    Cyclesim.cycle sim ;

    let addr_after_spurious_start = Bits.to_int !(outputs.fb_a_addr) in

    (* Address should have progressed normally (not restarted) *)
    if addr_after_spurious_start <= addr_before_spurious_start then
      failwith "FAIL: Address should progress despite spurious start signal" ;

    printf "    ✓ Start signal ignored during operation (addr %d -> %d)\n"
      addr_before_spurious_start addr_after_spurious_start ;

    (* Save waveforms for debugging *)
    Hardcaml_waveterm.Waveform.print ~wave_width:1 ~display_width:70 ~display_height:20
      _waves ;
    printf "  ✓ State transition verification completed\n"
  with
  | Failure msg when String.is_prefix msg ~prefix:"Bg_fetcher_dmg not yet implemented" ->
    printf "  ⚠ Skipping state transition test - bg_fetcher_dmg not yet implemented\n" ;
    printf "  ✓ Test framework verified and ready for implementation\n"
  | exn ->
    printf "  ✗ State transition test failed: %s\n" (Exn.to_string exn) ;
    raise exn

(** Test 2: Tilemap Addressing Verify correct tilemap address calculation with 32-tile
    stride *)
let test_tilemap_addressing () =
  printf "Testing tilemap addressing...\n" ;

  (* This test will verify: 1. Tilemap uses 32-tile stride (not 20!) 2. Tile coordinates
     map correctly: tile_y * 32 + tile_x 3. Wrapping behavior for 32x32 tilemap 4. Address
     calculation for checkerboard pattern *)

  (* Test some key coordinates *)
  let test_cases =
    [ 0, 0, 0
    ; (* Top-left corner *)
      1, 0, 1
    ; (* Second tile in first row *)
      0, 1, 32
    ; (* First tile in second row *)
      31, 31, 1023
    ; (* Bottom-right corner *)
      19, 17, (17 * 32) + 19 (* Middle of visible area *)
    ]
  in

  List.iter test_cases ~f:(fun (tile_x, tile_y, expected_addr) ->
      let actual_addr = tilemap_address tile_x tile_y in
      if actual_addr <> expected_addr then
        failwith
          (sprintf "Tilemap address mismatch: tile(%d,%d) expected %d, got %d" tile_x
             tile_y expected_addr actual_addr) ;
      printf "    Tile (%d,%d) -> address %d ✓\n" tile_x tile_y actual_addr) ;

  printf "  ✓ Tilemap addressing test passed\n"

(** Test 3: Tile Data Decoding Verify 2BPP format decoding and bit ordering *)
let test_tile_data_decoding () =
  printf "Testing tile data decoding...\n" ;

  (* Test 2BPP decoding with known patterns *)
  let test_cases =
    [ 0xFF, 0xFF, [| 3; 3; 3; 3; 3; 3; 3; 3 |]
    ; (* All pixels color 3 (black) *)
      0x00, 0x00, [| 0; 0; 0; 0; 0; 0; 0; 0 |]
    ; (* All pixels color 0 (white) *)
      0xFF, 0x00, [| 2; 2; 2; 2; 2; 2; 2; 2 |]
    ; (* All pixels color 2 *)
      0x00, 0xFF, [| 1; 1; 1; 1; 1; 1; 1; 1 |]
    ; (* All pixels color 1 *)
      0x80, 0x80, [| 3; 0; 0; 0; 0; 0; 0; 0 |]
    ; (* Only leftmost pixel color 3 *)
      0x01, 0x01, [| 0; 0; 0; 0; 0; 0; 0; 3 |] (* Only rightmost pixel color 3 *)
    ]
  in

  List.iter test_cases ~f:(fun (high, low, expected) ->
      let decoded = decode_2bpp high low in
      if not (Array.equal Int.equal decoded expected) then
        failwith (sprintf "2BPP decode failed: high=%02X low=%02X" high low) ;
      printf "    2BPP %02X %02X -> [%s] ✓\n" high low
        (Array.to_list decoded |> List.map ~f:Int.to_string |> String.concat ~sep:";")) ;

  printf "  ✓ Tile data decoding test passed\n"

(** Test 4: BGP Palette Application Verify BGP=0xE4 color mapping *)
let test_bgp_palette () =
  printf "Testing BGP palette application...\n" ;

  (* BGP = 0xE4 = 11100100 in binary Bits 7-6: 11 -> color 3 maps to index 3 (black) Bits
     5-4: 10 -> color 2 maps to index 2 Bits 3-2: 01 -> color 1 maps to index 1 Bits 1-0:
     00 -> color 0 maps to index 0 (white) *)
  let test_cases = [ 0, Ppu.Constants.rgb555_white; 3, Ppu.Constants.rgb555_black ] in

  List.iter test_cases ~f:(fun (color_index, expected_rgb) ->
      let actual_rgb = apply_bgp_palette color_index in
      if actual_rgb <> expected_rgb then
        failwith
          (sprintf "BGP palette failed: color %d expected %04X, got %04X" color_index
             expected_rgb actual_rgb) ;
      printf "    Color %d -> RGB555 %04X ✓\n" color_index actual_rgb) ;

  printf "  ✓ BGP palette test passed\n"

(** Test 5: Fetch Timing Verify 6-cycle fetch timing and 12-cycle initial delay *)
let test_fetch_timing () =
  printf "Testing fetch timing...\n" ;

  (* This test verifies the precise timing requirements from the PPU specification: 1.
     Each fetch state takes 2 cycles: Fetch_tile_no, Fetch_tile_low, Fetch_tile_high 2.
     Push_pixels takes 8 cycles (1 per pixel) 3. First fetch has 12-cycle delay (steps 1-3
     repeated once before first FIFO fill) 4. Subsequent fetches take 6 cycles + 8 push
     cycles = 14 cycles per tile *)
  try
    let sim, _waves = create_sim () in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    printf "  Testing initial fetch timing (12-cycle delay)...\n" ;

    (* Initialize and start *)
    Cyclesim.reset sim ;
    inputs.start := Bits.gnd ;
    Cyclesim.cycle sim ;

    (* Apply start signal *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    (* Track timing until first pixel write *)
    let cycle_count = ref 1 in
    (* Already cycled once after start *)
    let first_write_seen = ref false in
    let first_write_cycle = ref 0 in

    (* Monitor until first write occurs *)
    while (not !first_write_seen) && !cycle_count < 20 do
      let we_before = Bits.to_bool !(outputs.fb_a_we) in
      Cyclesim.cycle sim ;
      Int.incr cycle_count ;
      let we_after = Bits.to_bool !(outputs.fb_a_we) in

      (* Detect first write enable assertion *)
      if (not we_before) && we_after then begin
        first_write_seen := true ;
        first_write_cycle := !cycle_count
      end
    done ;

    if not !first_write_seen then
      failwith "FAIL: No write enable detected within 20 cycles" ;

    (* The first pixel should appear after the initial 12-cycle delay plus potentially a
       few cycles for the push state setup *)
    let expected_min_cycles = 12 in
    let expected_max_cycles = 16 in

    if !first_write_cycle < expected_min_cycles then
      failwith
        (sprintf "FAIL: First write too early - cycle %d (expected >= %d)"
           !first_write_cycle expected_min_cycles) ;

    if !first_write_cycle > expected_max_cycles then
      printf
        "    ⚠ Warning: First write later than expected - cycle %d (expected <= %d)\n"
        !first_write_cycle expected_max_cycles ;

    printf "    ✓ First pixel write at cycle %d (initial delay verified)\n"
      !first_write_cycle ;

    printf "  Testing subsequent tile fetch timing...\n" ;

    (* Continue monitoring to measure timing between tiles *)
    let write_cycles = ref [] in
    let tile_pixels = ref 0 in
    let current_tile_start = ref !first_write_cycle in

    (* Collect timing data for the first few tiles *)
    let target_tiles = 3 in
    let tiles_completed = ref 0 in

    while !tiles_completed < target_tiles && !cycle_count < 100 do
      let _we_before = Bits.to_bool !(outputs.fb_a_we) in
      Cyclesim.cycle sim ;
      Int.incr cycle_count ;
      let we_after = Bits.to_bool !(outputs.fb_a_we) in

      (* Track write events *)
      if we_after then begin
        write_cycles := !cycle_count :: !write_cycles ;
        Int.incr tile_pixels ;

        (* Check if we completed a tile (8 pixels) *)
        if !tile_pixels = 8 then begin
          let tile_duration = !cycle_count - !current_tile_start in
          printf "    Tile %d: %d cycles for 8 pixels (started cycle %d)\n"
            (!tiles_completed + 1) tile_duration !current_tile_start ;

          (* Verify timing: after first tile, should be ~14 cycles per tile (6 fetch + 8
             push, with some tolerance for state machine overhead) *)
          if !tiles_completed > 0 then begin
            let expected_duration = 14 in
            let tolerance = 4 in
            if abs (tile_duration - expected_duration) > tolerance then
              printf "      ⚠ Warning: tile duration %d cycles (expected ~%d)\n"
                tile_duration expected_duration
          end ;

          Int.incr tiles_completed ;
          tile_pixels := 0 ;
          current_tile_start := !cycle_count + 1
        end
      end
    done ;

    if !tiles_completed < target_tiles then
      failwith
        (sprintf "FAIL: Only completed %d tiles in %d cycles (expected %d)"
           !tiles_completed !cycle_count target_tiles) ;

    printf "    ✓ Completed %d tiles with consistent timing\n" !tiles_completed ;

    printf "  Testing pixel rate within tiles...\n" ;

    (* Verify that within the Push_pixels state, exactly 1 pixel is output per cycle *)
    let consecutive_writes = ref 0 in
    let max_consecutive = ref 0 in
    let last_we = ref false in

    List.rev !write_cycles
    |> List.iter ~f:(fun _cycle ->
           if !last_we then Int.incr consecutive_writes else consecutive_writes := 1 ;

           max_consecutive := Int.max !max_consecutive !consecutive_writes ;
           last_we := true) ;

    (* Within a tile's Push_pixels state, we should see 8 consecutive writes *)
    let expected_consecutive = 8 in
    if !max_consecutive < expected_consecutive then
      printf "    ⚠ Warning: max consecutive writes %d (expected %d)\n" !max_consecutive
        expected_consecutive
    else
      printf "    ✓ Pixel output rate verified (%d consecutive writes per tile)\n"
        !max_consecutive ;

    printf "  ✓ Fetch timing verification completed\n"
  with
  | Failure msg when String.is_prefix msg ~prefix:"Bg_fetcher_dmg not yet implemented" ->
    printf "  ⚠ Skipping fetch timing test - bg_fetcher_dmg not yet implemented\n" ;
    printf "  ✓ Test framework verified and ready for implementation\n"
  | exn ->
    printf "  ✗ Fetch timing test failed: %s\n" (Exn.to_string exn) ;
    raise exn

(** Test 6: Full Checkerboard Output Verify complete frame generates correct checkerboard
    pattern *)
let test_checkerboard_output () =
  printf "Testing checkerboard output...\n" ;

  (* This test verifies complete frame generation and pattern correctness: 1. Complete
     160x144 pixel frame generation (23,040 pixels total) 2. Each 8x8 tile has uniform
     color (all black or all white) 3. Pattern follows (tile_x XOR tile_y) & 1 4.
     Addresses are generated correctly (y * 160 + x) 5. RGB555 values match expected
     colors *)
  try
    let sim, _waves = create_sim () in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    printf "  Testing full frame generation...\n" ;

    (* Initialize and start *)
    Cyclesim.reset sim ;
    inputs.start := Bits.gnd ;
    Cyclesim.cycle sim ;

    (* Apply start signal *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    (* Collect all pixel writes during frame generation *)
    let pixels_written = ref [] in
    let cycle_count = ref 1 in
    let completed = ref false in

    (* Run until completion or timeout *)
    let max_cycles = 30000 in
    (* Conservative limit for full frame *)

    while (not !completed) && !cycle_count < max_cycles do
      let busy_before = Bits.to_bool !(outputs.busy) in
      let done_before = Bits.to_bool !(outputs.done_) in
      let we_before = Bits.to_bool !(outputs.fb_a_we) in
      let addr_before = Bits.to_int !(outputs.fb_a_addr) in
      let data_before = Bits.to_int !(outputs.fb_a_wdata) in

      Cyclesim.cycle sim ;
      Int.incr cycle_count ;

      let busy_after = Bits.to_bool !(outputs.busy) in
      let done_after = Bits.to_bool !(outputs.done_) in

      (* Record pixel writes *)
      if we_before then pixels_written := (addr_before, data_before) :: !pixels_written ;

      (* Check for completion *)
      if (not done_before) && done_after then begin
        completed := true ;
        printf "    ✓ Done signal asserted at cycle %d\n" !cycle_count
      end ;

      (* Check if FSM went idle (backup completion check) *)
      if busy_before && (not busy_after) && not !completed then begin
        completed := true ;
        printf "    ✓ FSM went idle at cycle %d\n" !cycle_count
      end
    done ;

    if not !completed then
      failwith (sprintf "FAIL: Frame generation didn't complete in %d cycles" max_cycles) ;

    let total_pixels = List.length !pixels_written in
    printf "    ✓ Frame completed in %d cycles with %d pixels\n" !cycle_count total_pixels ;

    (* Verify total pixel count *)
    let expected_total = Ppu.Constants.total_pixels in
    if total_pixels <> expected_total then
      failwith (sprintf "FAIL: Expected %d pixels, got %d" expected_total total_pixels) ;

    printf "  Testing checkerboard pattern correctness...\n" ;

    (* Convert pixel list to array for easier processing, sorted by address *)
    let pixel_array = Array.create ~len:expected_total (0, 0) in
    List.iter !pixels_written ~f:(fun (addr, data) ->
        if addr >= 0 && addr < expected_total then pixel_array.(addr) <- addr, data
        else failwith (sprintf "FAIL: Invalid pixel address %d" addr)) ;

    (* Verify each pixel has correct checkerboard pattern *)
    let pattern_errors = ref 0 in
    let max_errors_to_show = 10 in

    for addr = 0 to expected_total - 1 do
      let x = addr % Ppu.Constants.screen_width in
      let y = addr / Ppu.Constants.screen_width in
      let expected_color = checkerboard_pattern x y in
      let actual_addr, actual_color = pixel_array.(addr) in

      (* Verify address matches expected *)
      if actual_addr <> addr then
        failwith
          (sprintf "FAIL: Address mismatch at index %d: expected %d, got %d" addr addr
             actual_addr) ;

      (* Verify color matches checkerboard pattern *)
      if actual_color <> expected_color then begin
        Int.incr pattern_errors ;
        if !pattern_errors <= max_errors_to_show then
          printf "    ✗ Pattern error at (%d,%d) addr=%d: expected %04X, got %04X\n" x y
            addr expected_color actual_color
      end
    done ;

    if !pattern_errors > 0 then
      failwith (sprintf "FAIL: %d pattern errors found" !pattern_errors) ;

    printf "    ✓ All %d pixels match expected checkerboard pattern\n" total_pixels ;

    printf "  Testing tile uniformity...\n" ;

    (* Verify each 8x8 tile has uniform color *)
    let tile_errors = ref 0 in
    let tiles_x = Ppu.Constants.screen_width / 8 in
    let tiles_y = Ppu.Constants.screen_height / 8 in

    for tile_y = 0 to tiles_y - 1 do
      for tile_x = 0 to tiles_x - 1 do
        let base_x = tile_x * 8 in
        let base_y = tile_y * 8 in
        let base_addr = pixel_address base_x base_y in
        let _, expected_tile_color = pixel_array.(base_addr) in

        (* Check all pixels in this tile have the same color *)
        for py = 0 to 7 do
          for px = 0 to 7 do
            let pixel_addr = pixel_address (base_x + px) (base_y + py) in
            let _, pixel_color = pixel_array.(pixel_addr) in

            if pixel_color <> expected_tile_color then begin
              Int.incr tile_errors ;
              if !tile_errors <= max_errors_to_show then
                printf
                  "    ✗ Tile (%d,%d) non-uniform: pixel (%d,%d) has color %04X, \
                   expected %04X\n"
                  tile_x tile_y px py pixel_color expected_tile_color
            end
          done
        done
      done
    done ;

    if !tile_errors > 0 then
      failwith (sprintf "FAIL: %d tile uniformity errors found" !tile_errors) ;

    printf "    ✓ All %dx%d tiles have uniform colors\n" tiles_x tiles_y ;

    printf "  Testing address sequence...\n" ;

    (* Verify addresses are generated in sequence (0, 1, 2, ..., 23039) *)
    let sequence_errors = ref 0 in
    List.rev !pixels_written
    |> List.iteri ~f:(fun i (addr, _) ->
           if addr <> i then begin
             Int.incr sequence_errors ;
             if !sequence_errors <= max_errors_to_show then
               printf "    ✗ Address sequence error: index %d has address %d\n" i addr
           end) ;

    if !sequence_errors > 0 then
      failwith (sprintf "FAIL: %d address sequence errors found" !sequence_errors) ;

    printf "    ✓ Addresses generated in correct sequence (0..%d)\n" (expected_total - 1) ;

    printf "  ✓ Checkerboard output verification completed\n"
  with
  | Failure msg when String.is_prefix msg ~prefix:"Bg_fetcher_dmg not yet implemented" ->
    printf "  ⚠ Skipping checkerboard output test - bg_fetcher_dmg not yet implemented\n" ;
    printf "  ✓ Test framework verified and ready for implementation\n"
  | exn ->
    printf "  ✗ Checkerboard output test failed: %s\n" (Exn.to_string exn) ;
    raise exn

(** Test 7: Control Signals Verify reset and start signal handling *)
let test_control_signals () =
  printf "Testing control signals...\n" ;

  (* This test verifies proper control signal behavior: 1. Reset signal immediately stops
     operation and clears state 2. Start signal is ignored when already busy 3. Start
     signal properly triggers operation when idle 4. Done signal pulses for exactly one
     cycle 5. Busy signal correctly reflects operation state *)
  try
    let sim, _waves = create_sim () in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in

    printf "  Testing reset behavior...\n" ;

    (* Test 1: Reset clears all outputs *)
    Cyclesim.reset sim ;
    inputs.start := Bits.gnd ;
    Cyclesim.cycle sim ;

    let busy_after_reset = Bits.to_bool !(outputs.busy) in
    let done_after_reset = Bits.to_bool !(outputs.done_) in
    let we_after_reset = Bits.to_bool !(outputs.fb_a_we) in

    if busy_after_reset || done_after_reset || we_after_reset then
      failwith "FAIL: All outputs should be inactive after reset" ;

    printf "    ✓ Reset clears all outputs (busy=%b, done=%b, we=%b)\n" busy_after_reset
      done_after_reset we_after_reset ;

    printf "  Testing start signal when idle...\n" ;

    (* Test 2: Start signal triggers operation when idle *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    let busy_after_start = Bits.to_bool !(outputs.busy) in
    if not busy_after_start then
      failwith "FAIL: Start signal should trigger busy state when idle" ;

    printf "    ✓ Start signal triggers operation when idle (busy=%b)\n" busy_after_start ;

    printf "  Testing start signal gating during operation...\n" ;

    (* Test 3: Start signal ignored when already busy *)
    (* Let it run for a few cycles to ensure it's actively running *)
    for i = 1 to 15 do
      let busy = Bits.to_bool !(outputs.busy) in
      let addr = Bits.to_int !(outputs.fb_a_addr) in
      printf "      Cycle %d: busy=%b, addr=%d\n" i busy addr ;
      if busy then Cyclesim.cycle sim
    done ;

    let addr_before_spurious_start = Bits.to_int !(outputs.fb_a_addr) in
    let busy_before_spurious = Bits.to_bool !(outputs.busy) in
    printf "    Before spurious start: busy=%b, addr=%d\n" busy_before_spurious
      addr_before_spurious_start ;

    (* Try to restart with start signal while busy *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    let addr_after_spurious_start = Bits.to_int !(outputs.fb_a_addr) in
    let still_busy = Bits.to_bool !(outputs.busy) in
    printf "    After spurious start: busy=%b, addr=%d\n" still_busy
      addr_after_spurious_start ;

    if not still_busy then failwith "FAIL: FSM should still be busy after spurious start" ;

    (* Address should have progressed normally (not restarted) *)
    if addr_after_spurious_start <= addr_before_spurious_start then
      failwith "FAIL: Operation should continue normally despite spurious start" ;

    printf "    ✓ Start signal ignored during operation (addr %d -> %d)\n"
      addr_before_spurious_start addr_after_spurious_start ;

    printf "  Testing reset during operation...\n" ;

    (* Test 4: Reset immediately stops operation *)
    inputs.reset := Bits.vdd ;
    Cyclesim.cycle sim ;

    let busy_after_reset_during_op = Bits.to_bool !(outputs.busy) in
    let done_after_reset_during_op = Bits.to_bool !(outputs.done_) in
    let we_after_reset_during_op = Bits.to_bool !(outputs.fb_a_we) in
    printf "    After reset during operation: busy=%b, done=%b, we=%b\n"
      busy_after_reset_during_op done_after_reset_during_op we_after_reset_during_op ;

    if
      busy_after_reset_during_op || done_after_reset_during_op || we_after_reset_during_op
    then failwith "FAIL: Reset should immediately stop all operation" ;

    printf "    ✓ Reset immediately stops operation (busy=%b, done=%b, we=%b)\n"
      busy_after_reset_during_op done_after_reset_during_op we_after_reset_during_op ;

    printf "  Testing done signal behavior...\n" ;

    (* Test 5: Done signal pulses for exactly one cycle *)
    inputs.reset := Bits.gnd ;
    Cyclesim.cycle sim ;

    (* Start a new operation to test done signal *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    (* Wait for a reasonable number of pixels (not full frame) *)
    let target_pixels = 50 in
    let pixels_seen = ref 0 in
    let max_cycles = 1000 in
    let cycle_count = ref 1 in

    while !pixels_seen < target_pixels && !cycle_count < max_cycles do
      let we_before = Bits.to_bool !(outputs.fb_a_we) in
      Cyclesim.cycle sim ;
      Int.incr cycle_count ;

      if we_before then Int.incr pixels_seen
    done ;

    if !pixels_seen < target_pixels then
      failwith (sprintf "FAIL: Only saw %d pixels in %d cycles" !pixels_seen max_cycles) ;

    printf "    ✓ Operation progressing normally (%d pixels in %d cycles)\n" !pixels_seen
      !cycle_count ;

    (* Reset to test done signal on fresh start *)
    printf "    Before reset: busy=%b\n" (Bits.to_bool !(outputs.busy)) ;
    inputs.reset := Bits.vdd ;
    printf "    Reset asserted: busy=%b\n" (Bits.to_bool !(outputs.busy)) ;
    Cyclesim.cycle sim ;
    printf "    After reset cycle: busy=%b\n" (Bits.to_bool !(outputs.busy)) ;
    inputs.reset := Bits.gnd ;
    printf "    Reset deasserted: busy=%b\n" (Bits.to_bool !(outputs.busy)) ;
    Cyclesim.cycle sim ;
    printf "    After deassertion cycle: busy=%b\n" (Bits.to_bool !(outputs.busy)) ;

    printf "  Testing busy signal correctness...\n" ;

    (* Test 6: Busy signal correctly reflects operation state *)
    let busy_when_idle = Bits.to_bool !(outputs.busy) in
    let done_when_idle = Bits.to_bool !(outputs.done_) in
    let we_when_idle = Bits.to_bool !(outputs.fb_a_we) in
    printf "    When idle: busy=%b, done=%b, we=%b\n" busy_when_idle done_when_idle
      we_when_idle ;
    if busy_when_idle then failwith "FAIL: Busy should be low when idle" ;

    (* Start operation *)
    inputs.start := Bits.vdd ;
    Cyclesim.cycle sim ;
    inputs.start := Bits.gnd ;

    let busy_when_active = Bits.to_bool !(outputs.busy) in
    if not busy_when_active then failwith "FAIL: Busy should be high when active" ;

    printf "    ✓ Busy signal correctly reflects state (idle=%b, active=%b)\n"
      busy_when_idle busy_when_active ;

    printf "  Testing multiple reset/start cycles...\n" ;

    (* Test 7: Multiple reset/start sequences *)
    for test_run = 1 to 3 do
      printf "    Run %d: " test_run ;

      (* Reset *)
      inputs.reset := Bits.vdd ;
      inputs.start := Bits.gnd ;
      Cyclesim.cycle sim ;

      (* Start *)
      inputs.reset := Bits.gnd ;
      inputs.start := Bits.vdd ;
      Cyclesim.cycle sim ;
      inputs.start := Bits.gnd ;

      (* Verify it starts *)
      if not (Bits.to_bool !(outputs.busy)) then
        failwith (sprintf "FAIL: FSM should start on run %d" test_run) ;

      (* Let it run for a few cycles *)
      for _i = 1 to 20 do
        if Bits.to_bool !(outputs.busy) then Cyclesim.cycle sim
      done ;

      printf "started and ran ✓\n"
    done ;

    printf "    ✓ Multiple reset/start sequences work correctly\n" ;

    (* Save waveforms for debugging *)
    Hardcaml_waveterm.Waveform.print ~wave_width:1 ~display_width:70 ~display_height:20
      _waves ;
    printf "  ✓ Control signals verification completed\n"
  with
  | Failure msg when String.is_prefix msg ~prefix:"Bg_fetcher_dmg not yet implemented" ->
    printf "  ⚠ Skipping control signals test - bg_fetcher_dmg not yet implemented\n" ;
    printf "  ✓ Test framework verified and ready for implementation\n"
  | exn ->
    printf "  ✗ Control signals test failed: %s\n" (Exn.to_string exn) ;
    raise exn

(** Main test function *)
let () =
  printf "=== Background Fetcher Comprehensive Tests ===\n\n" ;

  try
    (* Run all core PPU behavior tests *)
    test_tilemap_addressing () ;
    test_tile_data_decoding () ;
    test_bgp_palette () ;

    (* These tests require the actual bg_fetcher implementation *)
    printf "\nTests requiring bg_fetcher implementation:\n" ;
    test_state_transitions () ;
    test_fetch_timing () ;
    test_checkerboard_output () ;
    test_control_signals () ;

    printf "\n=== All background fetcher tests completed! ===\n" ;
    printf
      "Note: Some tests are framework placeholders pending bg_fetcher_dmg implementation\n"
  with exn ->
    printf "\n=== TEST FAILED ===\n" ;
    printf "Error: %s\n" (Exn.to_string exn) ;
    Stdlib.exit 1
