(** DMG palette mapping helpers *)

module Make (B : Bitops.S) : sig
  (** Map color number (0..3) to RGB555 using custom colors. Color number is the result
      after palette lookup. *)
  val dmg_index_to_rgb555 :
    idx:B.t -> white:B.t -> light:B.t -> dark:B.t -> black:B.t -> B.t

  (** Apply BGP palette register to color index. Returns color number (0..3) from 2-bit
      palette entry. *)
  val apply_bgp : palette:B.t -> color_index:B.t -> B.t
end
