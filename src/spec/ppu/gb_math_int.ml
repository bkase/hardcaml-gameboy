(* Integer instantiations of the functorized math modules *)
open Gb_shared
module Pixels = Gb_pixels.Make (Bitops_int)
module Palette = Gb_palette.Make (Bitops_int)
module Addressing = Gb_addressing.Make (Bitops_int)

(* Helper for RGB888 conversion that uses int implementation *)
let to_rgb888 ~rgb555 =
  let r5, g5, b5 = Pixels.unpack_rgb555 rgb555 in
  let scale c5 = c5 * 255 / 31 in
  scale r5, scale g5, scale b5
