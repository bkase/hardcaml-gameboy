open Base
open Hardcaml
open Signal

(* Import GameBoy display constants *)

module I = struct
  type 'a t =
    { clock : 'a; reset : 'a; start : 'a (* Pulse high for one cycle to begin filling *) }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { (* Control signals *)
      busy : 'a (* High while filling framebuffer *)
    ; done_ : 'a (* 1-cycle pulse when fill completes *)
    ; (* Framebuffer Port A interface *)
      fb_a_addr : 'a
          [@bits Constants.pixel_addr_width]
          (* Pixel address 0..23039 (word address = pixel address) *)
    ; fb_a_wdata : 'a [@bits Constants.pixel_data_width] (* RGB555 pixel data *)
    ; fb_a_we : 'a (* Write enable *)
    }
  [@@deriving hardcaml]
end

(* Background fetcher state machine states *)
module State = struct
  type t =
    | Idle
    | Init_coords (* Initialize coordinates *)
    | Initial_delay (* 12-cycle initial delay (first fetch sequence) *)
    | Fetch_tile_no_1 (* First cycle of fetch tile no *)
    | Fetch_tile_no_2 (* Second cycle of fetch tile no *)
    | Fetch_tile_low_1 (* First cycle of fetch tile low *)
    | Fetch_tile_low_2 (* Second cycle of fetch tile low *)
    | Fetch_tile_high_1 (* First cycle of fetch tile high *)
    | Fetch_tile_high_2 (* Second cycle of fetch tile high *)
    | Push_pixels
    | Done_state
  [@@deriving sexp_of]

  let compare a b = Poly.compare a b

  let all =
    [ Idle
    ; Init_coords
    ; Initial_delay
    ; Fetch_tile_no_1
    ; Fetch_tile_no_2
    ; Fetch_tile_low_1
    ; Fetch_tile_low_2
    ; Fetch_tile_high_1
    ; Fetch_tile_high_2
    ; Push_pixels
    ; Done_state
    ]
end

let create _scope (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in

  (* State machine for background fetcher *)
  let sm = Always.State_machine.create (module State) spec in

  (* Position tracking variables *)
  let x = Always.Variable.reg spec ~width:Constants.coord_width in
  let y = Always.Variable.reg spec ~width:Constants.coord_width in
  let pixel_in_tile = Always.Variable.reg spec ~width:3 in
  (* 0-7 pixels within tile *)


  (* Timing control variables - simplified with cycle counter *)
  let cycle_counter = Always.Variable.reg spec ~width:4 in
  (* 0-11 for initial delay timing *)

  (* Control signals - use a running register like checker_fill *)
  let running = Always.Variable.reg spec ~width:1 in
  let done_ = Always.Variable.wire ~default:gnd in
  let fb_a_we = Always.Variable.wire ~default:gnd in
  let fb_a_wdata = Always.Variable.wire ~default:(zero Constants.pixel_data_width) in

  (* VRAM interface preparation - currently hardcoded but designed for future expansion *)
  (* 
   * Future VRAM interface will include:
   * 
   * Tilemap interface:
   *   - Input: tile_x (5-bit), tile_y (5-bit) 
   *   - Address: $9800 + (tile_y * 32 + tile_x)
   *   - Output: tile_id (8-bit)
   *
   * Tile data interface:
   *   - Input: tile_id (8-bit), row_in_tile (3-bit)
   *   - Address: $8000 + (tile_id * 16 + row_in_tile * 2)
   *   - Output: tile_low (8-bit), tile_high (8-bit)
   *
   * 2BPP decoder:
   *   - Input: tile_low, tile_high, pixel_in_row (3-bit)
   *   - Output: color_index (2-bit) for BGP palette lookup
   *
   * This structure will replace the current hardcoded checkerboard pattern.
   *)

  (* Calculate next coordinates for color calculation (1-cycle ahead) *)
  let at_end_of_line = x.value ==:. Constants.screen_width - 1 in
  let next_x = mux2 at_end_of_line (zero Constants.coord_width) (x.value +:. 1) in
  let next_y =
    mux2 at_end_of_line
      (mux2
         (y.value ==:. Constants.screen_height - 1)
         (zero Constants.coord_width) (y.value +:. 1))
      y.value
  in

  (* Generate checkerboard pattern (original implementation) *)
  let blk_x =
    uresize (srl next_x Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let blk_y =
    uresize (srl next_y Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let color_sel = lsb (blk_x ^: blk_y) in
  let white = of_int ~width:Constants.pixel_data_width Constants.rgb555_white in
  let black = of_int ~width:Constants.pixel_data_width Constants.rgb555_black in
  let rgb555_pixel = mux2 color_sel white black in

  (* Calculate pixel address: y * screen_width + x (using current coordinates) *)
  let y_extended = uresize y.value Constants.pixel_addr_width in
  let x_extended = uresize x.value Constants.pixel_addr_width in
  let y_times_width =
    sll y_extended Constants.screen_width_shift_7
    +: sll y_extended Constants.screen_width_shift_5
  in
  let addr_pix = y_times_width +: x_extended in

  (* Width-aware constants *)
  let total_pixels_minus_1 = Constants.total_pixels - 1 in

  (* Determine when operation is at last pixel *)
  let at_last_pixel = addr_pix ==:. total_pixels_minus_1 in

  (* State machine logic *)
  Always.(
    compile
      [ done_ <-- (running.value &: at_last_pixel &: sm.is Push_pixels)
      ; fb_a_wdata <-- rgb555_pixel
      ; (* Control running register similar to checker_fill *)
        running
        <-- mux2 i.reset gnd
              (mux2
                 (i.start &: sm.is Idle)
                 vdd
                 (mux2 (at_last_pixel &: sm.is Push_pixels) gnd running.value))
      ; (* fb_a_we and busy will be derived from running *)
        sm.switch
          [ ( Idle
            , [ fb_a_we <-- gnd
              ; when_ (i.start &: ~:(i.reset))
                  [ (* Initialize all coordinates and timing *)
                    x <--. 0
                  ; y <--. 0
                  ; pixel_in_tile <--. 0
                  ; cycle_counter <--. 0
                  ; sm.set_next Init_coords
                  ]
              ] )
          ; ( Init_coords
            , [ fb_a_we <-- gnd
              ; (* Wait one cycle for coordinate initialization, then start initial delay *)
                sm.set_next Initial_delay
              ] )
          ; ( Initial_delay
            , [ fb_a_we <-- gnd
              ; cycle_counter <-- cycle_counter.value +:. 1
              ; (* 12-cycle initial delay - simple counter approach *)
                when_ (cycle_counter.value ==:. 11) [ sm.set_next Push_pixels ]
              ] )
          ; (* 2-cycle fetch tile number *)
            ( Fetch_tile_no_1
            , [ fb_a_we <-- gnd
              ; pixel_in_tile <--. 0 (* Reset pixel counter for new tile *)
              ; sm.set_next Fetch_tile_no_2
              ] )
          ; Fetch_tile_no_2, [ fb_a_we <-- gnd; sm.set_next Fetch_tile_low_1 ]
          ; (* 2-cycle fetch tile low *)
            Fetch_tile_low_1, [ fb_a_we <-- gnd; sm.set_next Fetch_tile_low_2 ]
          ; Fetch_tile_low_2, [ fb_a_we <-- gnd; sm.set_next Fetch_tile_high_1 ]
          ; (* 2-cycle fetch tile high *)
            Fetch_tile_high_1, [ fb_a_we <-- gnd; sm.set_next Fetch_tile_high_2 ]
          ; ( Fetch_tile_high_2
            , [ fb_a_we <-- gnd
              ; pixel_in_tile <--. 0 (* Reset pixel counter for new tile *)
              ; sm.set_next Push_pixels (* Always proceed to pixel pushing *)
              ] )
          ; ( Push_pixels
            , [ (* Output pixel to framebuffer at current coordinates *)
                fb_a_we <-- vdd
              ; (* Check for end of frame first *)
                if_
                  (addr_pix ==:. total_pixels_minus_1)
                  [ sm.set_next Done_state ]
                  [ (* Always advance coordinates for next pixel *)
                    x <-- x.value +:. 1
                  ; when_
                      (x.value ==:. Constants.screen_width - 1)
                      [ x <--. 0; y <-- y.value +:. 1 ]
                  ; (* Increment pixel in tile counter *)
                    pixel_in_tile <-- pixel_in_tile.value +:. 1
                  ; (* After 8 pixels, reset pixel counter but continue pushing *)
                    when_ (pixel_in_tile.value ==:. 7) [ pixel_in_tile <--. 0 ]
                  ]
              ] )
          ; Done_state, [ fb_a_we <-- gnd; when_ ~:(i.reset) [ sm.set_next Idle ] ]
          ]
      ]) ;

  { O.busy = running.value
  ; done_ = done_.value
  ; fb_a_addr = addr_pix
  ; fb_a_wdata = fb_a_wdata.value
  ; fb_a_we = running.value &: sm.is Push_pixels
  }
