open Core
open Alcotest
open Gb_shared

let test_rgb555_pack_unpack () =
  (* Test known constants *)
  let red = Gb_pixels.pack_rgb555 ~r5:31 ~g5:0 ~b5:0 in
  check int "red packed correctly" 0x7C00 red ;

  let green = Gb_pixels.pack_rgb555 ~r5:0 ~g5:31 ~b5:0 in
  check int "green packed correctly" 0x03E0 green ;

  let blue = Gb_pixels.pack_rgb555 ~r5:0 ~g5:0 ~b5:31 in
  check int "blue packed correctly" 0x001F blue ;

  let white = Gb_pixels.pack_rgb555 ~r5:31 ~g5:31 ~b5:31 in
  check int "white packed correctly" 0x7FFF white ;

  let black = Gb_pixels.pack_rgb555 ~r5:0 ~g5:0 ~b5:0 in
  check int "black packed correctly" 0x0000 black ;

  (* Test round-trip *)
  let r5, g5, b5 = Gb_pixels.unpack_rgb555 0x03E0 in
  check int "green unpack R5" 0 r5 ;
  check int "green unpack G5" 31 g5 ;
  check int "green unpack B5" 0 b5 ;

  (* Test channel masking *)
  let overflow = Gb_pixels.pack_rgb555 ~r5:63 ~g5:63 ~b5:63 in
  let r5', g5', b5' = Gb_pixels.unpack_rgb555 overflow in
  check int "overflow masked R5" 31 r5' ;
  check int "overflow masked G5" 31 g5' ;
  check int "overflow masked B5" 31 b5'

let test_rgb888_conversion () =
  (* Test white conversion *)
  let r8, g8, b8 = Gb_pixels.to_rgb888 ~rgb555:0x7FFF in
  check int "white R8" 255 r8 ;
  check int "white G8" 255 g8 ;
  check int "white B8" 255 b8 ;

  (* Test black conversion *)
  let r8, g8, b8 = Gb_pixels.to_rgb888 ~rgb555:0x0000 in
  check int "black R8" 0 r8 ;
  check int "black G8" 0 g8 ;
  check int "black B8" 0 b8

let test_fb_index () =
  let width, height = Fb_index.dims () in
  check int "screen width" 160 width ;
  check int "screen height" 144 height ;

  (* Test corner indexing *)
  check int "top-left" 0 (Fb_index.word_index ~x:0 ~y:0 ~width:160) ;
  check int "top-right" 159 (Fb_index.word_index ~x:159 ~y:0 ~width:160) ;
  check int "bottom-left" (143 * 160) (Fb_index.word_index ~x:0 ~y:143 ~width:160) ;
  check int "bottom-right" 23039 (Fb_index.word_index ~x:159 ~y:143 ~width:160) ;

  (* Test bounds checking *)
  check bool "in bounds" true (Fb_index.in_bounds ~x:0 ~y:0 ~width:160 ~height:144) ;
  check bool "out of bounds x" false
    (Fb_index.in_bounds ~x:160 ~y:0 ~width:160 ~height:144) ;
  check bool "out of bounds y" false
    (Fb_index.in_bounds ~x:0 ~y:144 ~width:160 ~height:144)

let test_gb_addressing () =
  (* Test scroll decompose with SCX=SCY=0, LY=0 *)
  let eff_y, tile_row, map_row, tile_x0, fine_x =
    Gb_addressing.scroll_decompose ~ly:0 ~scy:0 ~scx:0
  in
  check int "eff_y=0" 0 eff_y ;
  check int "tile_row=0" 0 tile_row ;
  check int "map_row=0" 0 map_row ;
  check int "tile_x0=0" 0 tile_x0 ;
  check int "fine_x=0" 0 fine_x ;

  (* Test map addressing *)
  check int "map addr (0,0)" 0x1800 (Gb_addressing.map_addr_local ~map_row:0 ~tile_x:0) ;

  (* Test tile row addressing *)
  let lo_addr, hi_addr = Gb_addressing.tile_row_addrs_local ~tile_index:0 ~tile_row:0 in
  check int "tile row lo addr" 0 lo_addr ;
  check int "tile row hi addr" 1 hi_addr

let test_gb_palette () =
  (* Test color number mapping *)
  let white = 0x7FFF and black = 0x0000 in
  let light = 0x5AD6 and dark = 0x318C in

  check int "color 0 -> white" white
    (Gb_palette.dmg_index_to_rgb555 ~idx:0 ~white ~light ~dark ~black) ;
  check int "color 3 -> black" black
    (Gb_palette.dmg_index_to_rgb555 ~idx:3 ~white ~light ~dark ~black) ;

  (* Test BGP application *)
  let bgp = 0b11100100 in
  (* 3,2,1,0 -> black,dark,light,white *)
  check int "BGP color 0" 0 (Gb_palette.apply_bgp ~palette:bgp ~color_index:0) ;
  check int "BGP color 1" 1 (Gb_palette.apply_bgp ~palette:bgp ~color_index:1) ;
  check int "BGP color 2" 2 (Gb_palette.apply_bgp ~palette:bgp ~color_index:2) ;
  check int "BGP color 3" 3 (Gb_palette.apply_bgp ~palette:bgp ~color_index:3)

let rgb555_pixel_tests =
  [ "pack/unpack RGB555", `Quick, test_rgb555_pack_unpack
  ; "RGB888 conversion", `Quick, test_rgb888_conversion
  ]

let framebuffer_tests = [ "framebuffer indexing", `Quick, test_fb_index ]

let addressing_tests = [ "GB addressing", `Quick, test_gb_addressing ]

let palette_tests = [ "GB palette", `Quick, test_gb_palette ]

let () =
  Alcotest.run "Shared Math Library Tests"
    [ "pixels", rgb555_pixel_tests
    ; "framebuffer", framebuffer_tests
    ; "addressing", addressing_tests
    ; "palette", palette_tests
    ]
