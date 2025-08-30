module Make (B : Bitops.S) = struct
  let scroll_decompose ~ly ~scy ~scx =
    let open B in
    let eff_y = (ly + scy) land const 0xFF ~width:8 in
    let tile_row = eff_y land const 7 ~width:8 |> uresize ~width:3 in
    let map_row = (eff_y lsr 3) land const 31 ~width:8 |> uresize ~width:5 in
    let tile_x0 = (scx lsr 3) land const 31 ~width:8 |> uresize ~width:5 in
    let fine_x = scx land const 7 ~width:8 |> uresize ~width:3 in
    eff_y, tile_row, map_row, tile_x0, fine_x

  let map_addr_local ~map_row ~tile_x =
    let open B in
    let base = const 0x1800 ~width:16 in
    (* map_row * 32 = map_row << 5 *)
    let map_row_16 = map_row |> uresize ~width:16 in
    let tile_x_16 = tile_x |> uresize ~width:16 in
    let row_offset = map_row_16 lsl 5 in
    let col_offset = tile_x_16 land const 31 ~width:16 in
    base + row_offset + col_offset

  let tile_row_addrs_local ~tile_index ~tile_row =
    let open B in
    (* tile_index * 16 = tile_index << 4 *)
    let tile_index_16 = tile_index |> uresize ~width:16 in
    let tile_row_16 = tile_row |> uresize ~width:16 in
    let tile_base = tile_index_16 lsl 4 in
    (* tile_row * 2 = tile_row << 1 *)
    let row_offset = tile_row_16 lsl 1 in
    let base_addr = tile_base + row_offset in
    base_addr, base_addr + const 1 ~width:16
end
