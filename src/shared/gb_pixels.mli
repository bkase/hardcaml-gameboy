(** RGB555 pixel helpers for GameBoy display *)

(** Pack RGB555 from 5-bit channels *)
val pack_rgb555 : r5:int -> g5:int -> b5:int -> int

(** Unpack RGB555 to 5-bit channels *)
val unpack_rgb555 : int -> int * int * int

(** Convert RGB555 to RGB888 with correct scaling *)
val to_rgb888 : rgb555:int -> int * int * int
