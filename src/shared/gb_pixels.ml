open Core

let pack_rgb555 ~r5 ~g5 ~b5 =
  let r5 = r5 land 0x1F in
  let g5 = g5 land 0x1F in
  let b5 = b5 land 0x1F in
  (r5 lsl 10) lor (g5 lsl 5) lor b5

let unpack_rgb555 rgb555 =
  let r5 = (rgb555 lsr 10) land 0x1F in
  let g5 = (rgb555 lsr 5) land 0x1F in
  let b5 = rgb555 land 0x1F in
  r5, g5, b5

let to_rgb888 ~rgb555 =
  let r5, g5, b5 = unpack_rgb555 rgb555 in
  let scale c5 = c5 * 255 / 31 in
  scale r5, scale g5, scale b5

let expand_row_2bpp_msb_first ~lo ~hi =
  Array.init 8 ~f:(fun i ->
      let bit = 7 - i in
      let lo_bit = (lo lsr bit) land 1 in
      let hi_bit = (hi lsr bit) land 1 in
      (hi_bit lsl 1) lor lo_bit)
