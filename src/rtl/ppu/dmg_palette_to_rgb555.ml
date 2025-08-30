(* DMG palette to RGB555 conversion *)

open Hardcaml
open Signal
module Palette_signal = Gb_shared.Gb_palette.Make (Bitops_signal)

module I = struct
  type 'a t =
    { color_index : 'a [@bits 2] (* GameBoy color index (0-3) *)
    ; palette : 'a [@bits 8] (* Palette register value *)
    }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { rgb555 : 'a [@bits Constants.pixel_data_width] }
  [@@deriving sexp_of, hardcaml]
end

let create _scope { I.color_index; palette } =
  (* Use the functorized apply_bgp to get the palette index *)
  let palette_idx = Palette_signal.apply_bgp ~palette ~color_index in

  (* Convert to RGB555 using functorized dmg_index_to_rgb555 *)
  let rgb555 =
    Palette_signal.dmg_index_to_rgb555 ~idx:palette_idx
      ~white:(of_int ~width:Constants.pixel_data_width Constants.rgb555_white)
      ~light:(of_int ~width:Constants.pixel_data_width Constants.rgb555_light_gray)
      ~dark:(of_int ~width:Constants.pixel_data_width Constants.rgb555_dark_gray)
      ~black:(of_int ~width:Constants.pixel_data_width Constants.rgb555_black)
  in

  { O.rgb555 }
