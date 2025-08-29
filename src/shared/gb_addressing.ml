let scroll_decompose ~ly ~scy ~scx =
  let eff_y = (ly + scy) land 0xFF in
  let tile_row = eff_y land 7 in
  let map_row = (eff_y lsr 3) land 31 in
  let tile_x0 = (scx lsr 3) land 31 in
  let fine_x = scx land 7 in
  eff_y, tile_row, map_row, tile_x0, fine_x

let map_addr_local ~map_row ~tile_x = 0x1800 + (map_row * 32) + (tile_x land 31)

let tile_row_addrs_local ~tile_index ~tile_row =
  let base_addr = (tile_index * 16) + (tile_row * 2) in
  base_addr, base_addr + 1
