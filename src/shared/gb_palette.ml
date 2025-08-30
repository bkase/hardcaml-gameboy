module Make (B : Bitops.S) = struct
  let dmg_index_to_rgb555 ~idx ~white ~light ~dark ~black =
    let open B in
    (* Use mux to select based on 2-bit index *)
    mux ~sel:(idx land const 3 ~width:2) [ white; light; dark; black ]

  let apply_bgp ~palette ~color_index =
    let open B in
    (* Extract each 2-bit field from palette *)
    let extract_color shift =
      (palette lsr shift) land const 3 ~width:8 |> uresize ~width:2
    in
    (* Use mux to select the appropriate color based on color_index *)
    mux
      ~sel:(color_index land const 3 ~width:2)
      [ extract_color 0 (* color 0: bits 1:0 *)
      ; extract_color 2 (* color 1: bits 3:2 *)
      ; extract_color 4 (* color 2: bits 5:4 *)
      ; extract_color 6 (* color 3: bits 7:6 *)
      ]
end
