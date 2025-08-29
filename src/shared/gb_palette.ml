let dmg_index_to_rgb555 ~idx ~white ~light ~dark ~black =
  match idx land 3 with
  | 0 -> white
  | 1 -> light
  | 2 -> dark
  | 3 -> black
  | _ -> assert false

let apply_bgp ~palette ~color_index =
  let shift = color_index land 3 * 2 in
  (palette lsr shift) land 3
