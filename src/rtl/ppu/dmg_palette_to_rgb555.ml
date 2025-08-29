(* DMG palette to RGB555 conversion *)

open Hardcaml
open Signal

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
  (* Extract 2-bit color value from palette based on color_index *)
  let palette_color =
    mux color_index
      [ palette.:[1, 0]
      ; (* Color 0 *)
        palette.:[3, 2]
      ; (* Color 1 *)
        palette.:[5, 4]
      ; (* Color 2 *)
        palette.:[7, 6] (* Color 3 *)
      ]
  in

  (* Convert 2-bit palette color to RGB555 *)
  let rgb555 =
    mux palette_color
      [ of_int ~width:Constants.pixel_data_width Constants.rgb555_white
      ; (* 00: White *)
        of_int ~width:Constants.pixel_data_width Constants.rgb555_light_gray
      ; (* 01: Light gray *)
        of_int ~width:Constants.pixel_data_width Constants.rgb555_dark_gray
      ; (* 10: Dark gray *)
        of_int ~width:Constants.pixel_data_width Constants.rgb555_black (* 11: Black *)
      ]
  in

  { O.rgb555 }
