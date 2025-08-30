(** RGB555 pixel helpers for GameBoy display *)

module Make (B : Bitops.S) : sig
  (** Pack RGB555 from 5-bit channels *)
  val pack_rgb555 : r5:B.t -> g5:B.t -> b5:B.t -> B.t

  (** Unpack RGB555 to 5-bit channels *)
  val unpack_rgb555 : B.t -> B.t * B.t * B.t

  (** Expand a row of 2BPP tile data to 8 color indices (0-3). Returns array of 8 values,
      MSB first (bit 7 is leftmost pixel) *)
  val expand_row_2bpp_msb_first : lo:B.t -> hi:B.t -> B.t array
end
