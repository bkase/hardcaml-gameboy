open Core

module Make (B : Bitops.S) = struct
  let pack_rgb555 ~r5 ~g5 ~b5 =
    let open B in
    (* Ensure all components are 5-bit masked and then extend to 16-bit for shifting *)
    let r5_16 = r5 |> uresize ~width:16 in
    let g5_16 = g5 |> uresize ~width:16 in
    let b5_16 = b5 |> uresize ~width:16 in
    (r5_16 lsl 10) lor (g5_16 lsl 5) lor b5_16

  let unpack_rgb555 rgb555 =
    let open B in
    let r5 = select rgb555 14 10 in
    let g5 = select rgb555 9 5 in
    let b5 = select rgb555 4 0 in
    r5, g5, b5

  let expand_row_2bpp_msb_first ~lo ~hi =
    Array.init 8 ~f:(fun i ->
        let bit = 7 - i in
        (* This is an OCaml int for the shift amount *)
        let open B in
        let lo_bit = (lo lsr bit) land const 1 ~width:8 |> uresize ~width:2 in
        let hi_bit = (hi lsr bit) land const 1 ~width:8 |> uresize ~width:2 in
        (hi_bit lsl 1) lor lo_bit)
end
