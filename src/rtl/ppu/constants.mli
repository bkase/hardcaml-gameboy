(** GameBoy PPU Constants

    This module centralizes all GameBoy display-related constants to eliminate magic
    numbers throughout the codebase. Use these constants instead of hardcoding numeric
    values in PPU modules. *)

(** {1 Screen Dimensions} *)

(** GameBoy LCD screen width in pixels (160) *)
val screen_width : int

(** GameBoy LCD screen height in pixels (144) *)
val screen_height : int

(** Total number of pixels in the GameBoy screen (23,040 = 160 × 144) *)
val total_pixels : int

(** {1 Hardware Bit Widths} *)

(** Address width for pixel addressing (15 bits, supports 0..23039) *)
val pixel_addr_width : int

(** Data width for pixel data in RGB555 format (16 bits) *)
val pixel_data_width : int

(** Coordinate width for x,y pixel coordinates (8 bits) *)
val coord_width : int

(** {1 Checkerboard Pattern Constants} *)

(** Size of each checkerboard block in pixels (8×8) *)
val checker_block_size : int

(** Number of bits to shift right for dividing by checker_block_size (3 = log2(8)) *)
val checker_shift_bits : int

(** {1 RGB555 Color Constants} *)

(** White color in RGB555 format (0x7FFF) *)
val rgb555_white : int

(** Black color in RGB555 format (0x0000) *)
val rgb555_black : int

val rgb555_light_gray : int

val rgb555_dark_gray : int

(** {1 RGB555 Bit Field Layout} *)

(** Bit position for red channel start (10) *)
val rgb555_red_shift : int

(** Bit position for green channel start (5) *)
val rgb555_green_shift : int

(** Bit position for blue channel start (0) *)
val rgb555_blue_shift : int

(** Width of each color channel in bits (5) *)
val rgb555_channel_width : int

(** {1 Optimized Arithmetic Constants} *)

(** Left shift amount for optimized multiplication by screen_width (7) *)
val screen_width_shift_7 : int

(** Left shift amount for optimized multiplication by screen_width (5) *)
val screen_width_shift_5 : int

(** {2 Usage Note}

    For optimized multiplication by screen_width (160): [y * 160 = (y << 7) + (y << 5)]
    since [160 = 128 + 32 = 2^7 + 2^5] *)
