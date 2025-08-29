(** DMG palette mapping helpers *)

(** Map color number (0..3) to RGB555 using custom colors. Color number is the result
    after palette lookup. *)
val dmg_index_to_rgb555 :
  idx:int -> white:int -> light:int -> dark:int -> black:int -> int

(** Apply BGP palette register to color index. Returns color number (0..3) from 2-bit
    palette entry. *)
val apply_bgp : palette:int -> color_index:int -> int
