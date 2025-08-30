open Core

let rgb555_white = 0x7FFF

let rgb555_black = 0x0000

let render ~vram ~scx ~scy ~bgp =
  let open Gb_shared in
  let result = Array.create ~len:(160 * 144) 0 in

  for ly = 0 to 143 do
    let eff_y, tile_row, map_row, tile_x0, fine_x =
      Spec_ppu.Gb_math_int.Addressing.scroll_decompose ~ly ~scy ~scx
    in

    let line_pixels = Array.create ~len:160 0 in
    let pixel_idx = ref 0 in

    for tile_offset = 0 to 19 do
      let tile_x = (tile_x0 + tile_offset) land 31 in

      let map_addr = Spec_ppu.Gb_math_int.Addressing.map_addr_local ~map_row ~tile_x in
      let tile_index = Bytes.get vram map_addr |> Char.to_int in

      let lo_addr, hi_addr =
        Spec_ppu.Gb_math_int.Addressing.tile_row_addrs_local ~tile_index ~tile_row
      in

      let lo_byte = Bytes.get vram lo_addr |> Char.to_int in
      let hi_byte = Bytes.get vram hi_addr |> Char.to_int in

      let pixels =
        Spec_ppu.Gb_math_int.Pixels.expand_row_2bpp_msb_first ~lo:lo_byte ~hi:hi_byte
      in

      let start_px = if tile_offset = 0 then fine_x else 0 in
      for px = start_px to 7 do
        if !pixel_idx < 160 then begin
          let color_idx = pixels.(px) in
          let palette_idx =
            Spec_ppu.Gb_math_int.Palette.apply_bgp ~palette:bgp ~color_index:color_idx
          in

          let rgb555 =
            Spec_ppu.Gb_math_int.Palette.dmg_index_to_rgb555 ~idx:palette_idx
              ~white:rgb555_white ~light:0x5294 ~dark:0x294A ~black:rgb555_black
          in

          line_pixels.(!pixel_idx) <- rgb555 ;
          incr pixel_idx
        end
      done
    done ;

    for x = 0 to 159 do
      let fb_idx = Fb_index.word_index ~x ~y:ly ~width:160 in
      result.(fb_idx) <- line_pixels.(x)
    done
  done ;

  result
