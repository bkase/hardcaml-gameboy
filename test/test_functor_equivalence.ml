open Core
open Hardcaml
open Alcotest

(* Test that functorized implementations produce identical results for int and Signal *)

let test_palette_equivalence () =
  let module Palette_int = Spec_ppu.Gb_math_int.Palette in
  let module Palette_signal =
    Gb_shared.Gb_palette.Make (Hardcaml_gameboy_rtl_ppu.Bitops_signal) in
  (* Test apply_bgp exhaustively *)
  for palette = 0 to 255 do
    for color_index = 0 to 3 do
      let int_result = Palette_int.apply_bgp ~palette ~color_index in

      let signal_palette = Signal.of_int ~width:8 palette in
      let signal_color_index = Signal.of_int ~width:2 color_index in
      let signal_result =
        Palette_signal.apply_bgp ~palette:signal_palette ~color_index:signal_color_index
      in
      let signal_result_int = Signal.to_constant signal_result |> Constant.to_int in

      check int
        (Printf.sprintf "apply_bgp palette=%d color_index=%d" palette color_index)
        int_result signal_result_int
    done
  done ;

  (* Test dmg_index_to_rgb555 *)
  let white = 0x7FFF in
  let light = 0x5294 in
  let dark = 0x294A in
  let black = 0x0000 in

  for idx = 0 to 3 do
    let int_result = Palette_int.dmg_index_to_rgb555 ~idx ~white ~light ~dark ~black in

    let signal_idx = Signal.of_int ~width:2 idx in
    let signal_white = Signal.of_int ~width:16 white in
    let signal_light = Signal.of_int ~width:16 light in
    let signal_dark = Signal.of_int ~width:16 dark in
    let signal_black = Signal.of_int ~width:16 black in
    let signal_result =
      Palette_signal.dmg_index_to_rgb555 ~idx:signal_idx ~white:signal_white
        ~light:signal_light ~dark:signal_dark ~black:signal_black
    in
    let signal_result_int = Signal.to_constant signal_result |> Constant.to_int in

    check int
      (Printf.sprintf "dmg_index_to_rgb555 idx=%d" idx)
      int_result signal_result_int
  done

let test_pixels_equivalence () =
  let module Pixels_int = Spec_ppu.Gb_math_int.Pixels in
  let module Pixels_signal =
    Gb_shared.Gb_pixels.Make (Hardcaml_gameboy_rtl_ppu.Bitops_signal) in
  (* Test pack_rgb555 *)
  let test_cases =
    [ 31, 0, 0
    ; (* Red *)
      0, 31, 0
    ; (* Green *)
      0, 0, 31
    ; (* Blue *)
      31, 31, 31
    ; (* White *)
      0, 0, 0
    ; (* Black *)
      15, 15, 15 (* Gray *)
    ]
  in

  List.iter test_cases ~f:(fun (r5, g5, b5) ->
      let int_result = Pixels_int.pack_rgb555 ~r5 ~g5 ~b5 in

      let signal_r5 = Signal.of_int ~width:5 r5 in
      let signal_g5 = Signal.of_int ~width:5 g5 in
      let signal_b5 = Signal.of_int ~width:5 b5 in
      let signal_result =
        Pixels_signal.pack_rgb555 ~r5:signal_r5 ~g5:signal_g5 ~b5:signal_b5
      in
      let signal_result_int = Signal.to_constant signal_result |> Constant.to_int in

      check int
        (Printf.sprintf "pack_rgb555 r=%d g=%d b=%d" r5 g5 b5)
        int_result signal_result_int) ;

  (* Test expand_row_2bpp_msb_first *)
  for lo = 0 to 255 do
    for hi = 0 to 255 do
      let int_result = Pixels_int.expand_row_2bpp_msb_first ~lo ~hi in

      let signal_lo = Signal.of_int ~width:8 lo in
      let signal_hi = Signal.of_int ~width:8 hi in
      let signal_result =
        Pixels_signal.expand_row_2bpp_msb_first ~lo:signal_lo ~hi:signal_hi
      in

      Array.iteri int_result ~f:(fun i int_val ->
          let signal_val = Signal.to_constant signal_result.(i) |> Constant.to_int in
          check int
            (Printf.sprintf "expand_row lo=%d hi=%d pixel=%d" lo hi i)
            int_val signal_val)
    done
  done

let test_addressing_equivalence () =
  let module Addr_int = Spec_ppu.Gb_math_int.Addressing in
  let module Addr_signal =
    Gb_shared.Gb_addressing.Make (Hardcaml_gameboy_rtl_ppu.Bitops_signal) in
  (* Test scroll_decompose with various inputs *)
  let test_cases =
    [ 0, 0, 0
    ; (* No scroll *)
      10, 20, 30
    ; (* Some scroll *)
      143, 255, 255
    ; (* Edge cases *)
      100, 100, 100 (* Mid values *)
    ]
  in

  List.iter test_cases ~f:(fun (ly, scy, scx) ->
      let int_eff_y, int_tile_row, int_map_row, int_tile_x0, int_fine_x =
        Addr_int.scroll_decompose ~ly ~scy ~scx
      in

      let signal_ly = Signal.of_int ~width:8 ly in
      let signal_scy = Signal.of_int ~width:8 scy in
      let signal_scx = Signal.of_int ~width:8 scx in
      let signal_eff_y, signal_tile_row, signal_map_row, signal_tile_x0, signal_fine_x =
        Addr_signal.scroll_decompose ~ly:signal_ly ~scy:signal_scy ~scx:signal_scx
      in

      let get_int s = Signal.to_constant s |> Constant.to_int in

      check int
        (Printf.sprintf "scroll_decompose ly=%d scy=%d scx=%d - eff_y" ly scy scx)
        int_eff_y (get_int signal_eff_y) ;
      check int
        (Printf.sprintf "scroll_decompose ly=%d scy=%d scx=%d - tile_row" ly scy scx)
        int_tile_row (get_int signal_tile_row) ;
      check int
        (Printf.sprintf "scroll_decompose ly=%d scy=%d scx=%d - map_row" ly scy scx)
        int_map_row (get_int signal_map_row) ;
      check int
        (Printf.sprintf "scroll_decompose ly=%d scy=%d scx=%d - tile_x0" ly scy scx)
        int_tile_x0 (get_int signal_tile_x0) ;
      check int
        (Printf.sprintf "scroll_decompose ly=%d scy=%d scx=%d - fine_x" ly scy scx)
        int_fine_x (get_int signal_fine_x))

let () =
  Alcotest.run "Functor Equivalence Tests"
    [ "palette", [ "int vs signal equivalence", `Quick, test_palette_equivalence ]
    ; "pixels", [ "int vs signal equivalence", `Quick, test_pixels_equivalence ]
    ; "addressing", [ "int vs signal equivalence", `Quick, test_addressing_equivalence ]
    ]
