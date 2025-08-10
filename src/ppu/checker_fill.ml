open Base
open Hardcaml
open Signal

(* Import GameBoy display constants *)
let width = Constants.screen_width

let height = Constants.screen_height

let _total_pixels = Constants.total_pixels

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

let create _scope (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in

  let x = wire Constants.coord_width in
  let y = wire Constants.coord_width in
  let running = wire 1 in
  let done_pulse = wire 1 in

  let x_reg = reg spec x in
  let y_reg = reg spec y in
  let running_reg = reg spec running in

  let at_last_pixel = x_reg ==:. width - 1 &: (y_reg ==:. height - 1) in
  let at_end_of_line = x_reg ==:. width - 1 in

  let next_x = mux2 at_end_of_line (zero Constants.coord_width) (x_reg +:. 1) in
  let next_y =
    mux2 at_end_of_line
      (mux2 (y_reg ==:. height - 1) (zero Constants.coord_width) (y_reg +:. 1))
      y_reg
  in

  (* Fix: Use current coordinate values instead of registered values to match SameBoy
     timing *)
  let current_x = mux2 running_reg next_x (zero Constants.coord_width) in
  let current_y = mux2 running_reg next_y (zero Constants.coord_width) in

  let blk_x =
    uresize (srl current_x Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let blk_y =
    uresize (srl current_y Constants.checker_shift_bits) Constants.rgb555_channel_width
  in
  let color_sel = lsb (blk_x ^: blk_y) in

  let white = of_int ~width:Constants.pixel_data_width Constants.rgb555_white in
  (* RGB555: all bits set = white *)
  let black = of_int ~width:Constants.pixel_data_width Constants.rgb555_black in
  let pixel_color = mux2 color_sel white black in

  (* Optimize pixel address calculation: y * screen_width = (y << 7) + (y << 5) *)
  let y_times_width =
    sll (uresize y_reg Constants.pixel_addr_width) Constants.screen_width_shift_7
    +: sll (uresize y_reg Constants.pixel_addr_width) Constants.screen_width_shift_5
  in
  let addr_pix = y_times_width +: uresize x_reg Constants.pixel_addr_width in

  (* Fix: Separate reset from start - reset initializes via Reg_spec, start only triggers
     transitions *)
  (* Fix: Gate start signal to prevent corruption from repeated start pulses during operation *)
  let start_gated = i.start &: ~:running_reg in
  x <== mux2 running_reg next_x x_reg ;
  y <== mux2 running_reg next_y y_reg ;
  running <== mux2 i.reset gnd (mux2 start_gated vdd (mux2 at_last_pixel gnd running_reg)) ;
  done_pulse <== (running_reg &: at_last_pixel) ;

  { O.busy = running_reg
  ; done_ = done_pulse
  ; fb_a_addr = addr_pix
  ; fb_a_wdata = pixel_color
  ; fb_a_we = running_reg
  }
