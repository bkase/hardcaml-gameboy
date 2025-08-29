(** DMG background addressing helpers for Phase-2 *)

(** Decompose scroll values for BG fetching. Returns (eff_y, tile_row, map_row, tile_x0,
    fine_x) *)
val scroll_decompose : ly:int -> scy:int -> scx:int -> int * int * int * int * int

(** Get VRAM-local address for tile map entry. Returns offset from VRAM start (e.g., $9800
    -> 0x1800) *)
val map_addr_local : map_row:int -> tile_x:int -> int

(** Get VRAM-local addresses for tile row data using $8000 method. Returns (lo_addr,
    hi_addr) pair *)
val tile_row_addrs_local : tile_index:int -> tile_row:int -> int * int
