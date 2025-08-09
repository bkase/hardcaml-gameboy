open Base
open Hardcaml
open Signal

let width = 160
let height = 144
let _total_pixels = width * height

module I = struct
  type 'a t =
    { clock : 'a
    ; reset : 'a
    ; start : 'a (* Pulse high for one cycle to begin filling *)
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { (* Control signals *)
      busy : 'a (* High while filling framebuffer *)
    ; done_ : 'a (* 1-cycle pulse when fill completes *)
    ; (* Framebuffer Port A interface *)
      fb_a_addr : 'a [@bits 15] (* Word address 0..23039 *)
    ; fb_a_wdata : 'a [@bits 16] (* RGB555 pixel data *)
    ; fb_a_we : 'a (* Write enable *)
    }
  [@@deriving hardcaml]
end

let create _scope (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in
  
  let x = wire 8 in
  let y = wire 8 in
  let running = wire 1 in
  let done_pulse = wire 1 in
  
  let x_reg = reg spec x in
  let y_reg = reg spec y in
  let running_reg = reg spec running in
  
  let at_last_pixel = (x_reg ==:. (width - 1)) &: (y_reg ==:. (height - 1)) in
  let at_end_of_line = x_reg ==:. (width - 1) in
  
  let next_x = mux2 at_end_of_line (zero 8) (x_reg +:. 1) in
  let next_y = mux2 at_end_of_line 
    (mux2 (y_reg ==:. (height - 1)) (zero 8) (y_reg +:. 1))
    y_reg in
  
  
  (* Fix: Use current coordinate values instead of registered values to match SameBoy timing *)
  let current_x = mux2 running_reg next_x (zero 8) in
  let current_y = mux2 running_reg next_y (zero 8) in
  
  let blk_x = uresize (srl current_x 3) 5 in
  let blk_y = uresize (srl current_y 3) 5 in
  let color_sel = lsb (blk_x ^: blk_y) in
  
  let white = of_int ~width:16 0x7FFF in (* RGB555: all bits set = white *)
  let black = of_int ~width:16 0x0000 in
  let pixel_color = mux2 color_sel white black in
  
  (* Optimize address calculation: y * 160 = (y << 7) + (y << 5) *)
  let y_times_160 = (sll (uresize y_reg 15) 7) +: (sll (uresize y_reg 15) 5) in
  let addr_pix = y_times_160 +: uresize x_reg 15 in
  
  x <== mux2 i.start (zero 8) (mux2 running_reg next_x x_reg);
  y <== mux2 i.start (zero 8) (mux2 running_reg next_y y_reg);
  running <== mux2 i.start vdd (mux2 at_last_pixel gnd running_reg);
  done_pulse <== (running_reg &: at_last_pixel);
  
  {
    O.busy = running_reg;
    done_ = done_pulse;
    fb_a_addr = addr_pix;
    fb_a_wdata = pixel_color;
    fb_a_we = running_reg;
  }
