(** GameBoy PPU Constants

    This module centralizes all GameBoy display-related constants to eliminate magic
    numbers throughout the codebase. *)

(* Screen dimensions *)
let screen_width = 160

let screen_height = 144

let total_pixels = 23_040 (* screen_width * screen_height *)

(* Address and bit widths *)
let pixel_addr_width = 15 (* Sufficient for addressing 0..23039 pixels *)

let pixel_data_width = 16 (* RGB555 format *)

let coord_width = 8 (* For x,y coordinates (0..159 for width, 0..143 for height) *)

(* Checkerboard pattern constants *)
let checker_block_size = 8 (* 8x8 pixel blocks *)

let checker_shift_bits = 3 (* log2(checker_block_size) for dividing by 8 *)

(* RGB555 color constants *)
let rgb555_white = 0x7FFF (* All RGB bits set to maximum *)

let rgb555_black = 0x0000 (* All RGB bits set to zero *)

(* RGB555 bit field positions *)
let rgb555_red_shift = 10 (* Red channel starts at bit 10 *)

let rgb555_green_shift = 5 (* Green channel starts at bit 5 *)

let rgb555_blue_shift = 0 (* Blue channel starts at bit 0 *)

let rgb555_channel_width = 5 (* Each color channel is 5 bits *)

(* Optimized multiplication constants for y * screen_width *)
let screen_width_shift_7 = 7 (* 160 = (1 << 7) + (1 << 5) *)

let screen_width_shift_5 = 5 (* Used for optimized multiplication *)
