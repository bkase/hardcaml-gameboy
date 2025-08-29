(** RGB555 pixel helpers for GameBoy display *)

(** Pack RGB555 from 5-bit channels *)
val pack_rgb555 : r5:int -> g5:int -> b5:int -> int

(** Unpack RGB555 to 5-bit channels *)
val unpack_rgb555 : int -> int * int * int

(** Convert RGB555 to RGB888 with correct scaling *)
val to_rgb888 : rgb555:int -> int * int * int

(** Expand a row of 2BPP tile data to 8 color indices (0-3). Returns array of 8 ints, MSB
    first (bit 7 is leftmost pixel) *)
val expand_row_2bpp_msb_first : lo:int -> hi:int -> int array
