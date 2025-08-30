(** DMG background addressing helpers for Phase-2 *)

module Make (B : Bitops.S) : sig
  (** Decompose scroll values for BG fetching. Returns (eff_y, tile_row, map_row, tile_x0,
      fine_x) *)
  val scroll_decompose : ly:B.t -> scy:B.t -> scx:B.t -> B.t * B.t * B.t * B.t * B.t

  (** Get VRAM-local address for tile map entry. Returns offset from VRAM start (e.g.,
      $9800 -> 0x1800) *)
  val map_addr_local : map_row:B.t -> tile_x:B.t -> B.t

  (** Get VRAM-local addresses for tile row data using $8000 method. Returns (lo_addr,
      hi_addr) pair *)
  val tile_row_addrs_local : tile_index:B.t -> tile_row:B.t -> B.t * B.t
end
