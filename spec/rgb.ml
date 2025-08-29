open Core

let pack_rgb555 ~r5 ~g5 ~b5 =
  assert (r5 >= 0 && r5 < 32) ;
  assert (g5 >= 0 && g5 < 32) ;
  assert (b5 >= 0 && b5 < 32) ;
  (r5 lsl 10) lor (g5 lsl 5) lor b5

let unpack_rgb555 rgb555 =
  let r5 = (rgb555 lsr 10) land 0x1F in
  let g5 = (rgb555 lsr 5) land 0x1F in
  let b5 = rgb555 land 0x1F in
  r5, g5, b5

let to_rgb888 ~rgb555 =
  let r5, g5, b5 = unpack_rgb555 rgb555 in
  (* Scale 5-bit to 8-bit using (c5 * 255) / 31 for proper scaling *)
  let r8 = r5 * 255 / 31 in
  let g8 = g5 * 255 / 31 in
  let b8 = b5 * 255 / 31 in
  r8, g8, b8
