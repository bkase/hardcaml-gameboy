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
    | Init_coords (* New state to allow coordinate initialization *)
    | Fetch_tile_no_1 (* First cycle of fetch tile no *)
    | Fetch_tile_no_2 (* Second cycle of fetch tile no *)
    | Fetch_tile_low_1 (* First cycle of fetch tile low *)
    | Fetch_tile_low_2 (* Second cycle of fetch tile low *)
    | Fetch_tile_high_1 (* First cycle of fetch tile high *)
    | Fetch_tile_high_2 (* Second cycle of fetch tile high *)
    | Push_pixels
    | Done_state
  [@@deriving sexp_of]

  let compare a b =
    match a, b with
    | Idle, Idle -> 0
    | Idle, _ -> -1
    | _, Idle -> 1
    | Init_coords, Init_coords -> 0
    | Init_coords, _ -> -1
    | _, Init_coords -> 1
    | Fetch_tile_no_1, Fetch_tile_no_1 -> 0
    | Fetch_tile_no_1, _ -> -1
    | _, Fetch_tile_no_1 -> 1
    | Fetch_tile_no_2, Fetch_tile_no_2 -> 0
    | Fetch_tile_no_2, _ -> -1
    | _, Fetch_tile_no_2 -> 1
    | Fetch_tile_low_1, Fetch_tile_low_1 -> 0
    | Fetch_tile_low_1, _ -> -1
    | _, Fetch_tile_low_1 -> 1
    | Fetch_tile_low_2, Fetch_tile_low_2 -> 0
    | Fetch_tile_low_2, _ -> -1
    | _, Fetch_tile_low_2 -> 1
    | Fetch_tile_high_1, Fetch_tile_high_1 -> 0
    | Fetch_tile_high_1, _ -> -1
    | _, Fetch_tile_high_1 -> 1
    | Fetch_tile_high_2, Fetch_tile_high_2 -> 0
    | Fetch_tile_high_2, _ -> -1
    | _, Fetch_tile_high_2 -> 1
    | Push_pixels, Push_pixels -> 0
    | Push_pixels, _ -> -1
    | _, Push_pixels -> 1
    | Done_state, Done_state -> 0

  let all =
    [ Idle
    ; Init_coords
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
  let pixel_count = Always.Variable.reg spec ~width:3 in
  (* Debug counter *)

  (* Timing control variables *)
  let fetch_cycle = Always.Variable.reg spec ~width:1 in
  (* 2-cycle timing for fetch states *)
  let initial_fetch_done = Always.Variable.reg spec ~width:1 in
  (* Track initial 12-cycle delay *)
  let first_pixel = Always.Variable.reg spec ~width:1 in
  (* Track if this is the very first pixel *)

  (* Control signals *)
  let busy = Always.Variable.wire ~default:gnd in
  let done_ = Always.Variable.wire ~default:gnd in
  let fb_a_we = Always.Variable.wire ~default:gnd in
  let fb_a_wdata = Always.Variable.wire ~default:(zero Constants.pixel_data_width) in

  (* Hardcoded tilemap: XOR checkerboard pattern - not used in simplified version *)
  (* let tile_number = lsb (tile_x.value ^: tile_y.value) in *)
  (* XOR pattern: 0 or 1 *)

  (* Hardcoded tile data: Tile 0 = 0xFF (black), Tile 1 = 0x00 (white) - not used *)
  (* let get_tile_data tile_id =
    mux2 (lsb tile_id) (of_int ~width:8 0x00) (of_int ~width:8 0xFF)
  in *)

  (* Simple checkerboard pattern: use (x XOR y) to determine color *)
  let blk_x =
    uresize (srl x.value Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let blk_y =
    uresize (srl y.value Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let color_sel = lsb (blk_x ^: blk_y) in
  let white = of_int ~width:Constants.pixel_data_width Constants.rgb555_white in
  let black = of_int ~width:Constants.pixel_data_width Constants.rgb555_black in
  let rgb555_pixel = mux2 color_sel black white in

  (* Calculate pixel address: y * screen_width + x *)
  let y_times_width =
    sll (uresize y.value Constants.pixel_addr_width) Constants.screen_width_shift_7
    +: sll (uresize y.value Constants.pixel_addr_width) Constants.screen_width_shift_5
  in
  let addr_pix = y_times_width +: uresize x.value Constants.pixel_addr_width in

  (* Width-aware constants *)
  let total_pixels_minus_1 = Constants.total_pixels - 1 in

  (* State machine logic *)
  Always.(
    compile
      [ busy
        <-- (sm.is Init_coords |: sm.is Fetch_tile_no_1 |: sm.is Fetch_tile_no_2
           |: sm.is Fetch_tile_low_1 |: sm.is Fetch_tile_low_2 |: sm.is Fetch_tile_high_1
           |: sm.is Fetch_tile_high_2 |: sm.is Push_pixels)
      ; done_ <-- sm.is Done_state
      ; fb_a_wdata <-- rgb555_pixel
      ; (* fb_a_we will be set within the state machine *)
        sm.switch
          [ ( Idle
            , [ fb_a_we <-- gnd
              ; when_ i.start
                  [ (* Initialize all coordinates and timing *)
                    x <--. 0
                  ; y <--. 0
                  ; pixel_in_tile <--. 0
                  ; pixel_count <--. 0
                  ; (* Initialize debug counter *)
                    fetch_cycle <--. 0
                  ; initial_fetch_done <--. 0
                  ; first_pixel <--. 1
                  ; (* Mark that we need to write the first pixel at (0,0) *)
                    sm.set_next Init_coords
                  ]
              ] )
          ; ( Init_coords
            , [ fb_a_we <-- gnd
              ; (* Wait one cycle for coordinate initialization, then start fetch
                   pipeline *)
                sm.set_next Fetch_tile_no_1
              ] )
          ; (* 2-cycle fetch tile number *)
            ( Fetch_tile_no_1
            , [ fb_a_we <-- gnd
              ; (* Reset pixel counters when entering new tile *)
                pixel_count <--. 0
              ; pixel_in_tile <--. 0
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
              ; (* First time through, repeat the fetch cycle for 12-cycle initial
                   delay *)
                if_
                  (initial_fetch_done.value ==:. 0)
                  [ initial_fetch_done <--. 1
                  ; sm.set_next Fetch_tile_no_1 (* Repeat fetch cycle once more *)
                  ]
                  [ pixel_in_tile <--. 0
                  ; (* Reset pixel counter for new tile *)
                    pixel_count <--. 0
                  ; (* Reset debug counter *)
                    (* Don't reset coordinates - they should continue from where they left
                       off *)
                    sm.set_next Push_pixels (* Proceed to pixel pushing *)
                  ]
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
                  ; (* Increment counters *)
                    pixel_count <-- pixel_count.value +:. 1
                  ; pixel_in_tile <-- pixel_in_tile.value +:. 1
                  ]
              ] )
          ; Done_state, [ fb_a_we <-- gnd; sm.set_next Idle ]
          ]
      ]) ;

  { O.busy = busy.value
  ; done_ = done_.value
  ; fb_a_addr = addr_pix
  ; fb_a_wdata = fb_a_wdata.value
  ; fb_a_we = fb_a_we.value
  }
