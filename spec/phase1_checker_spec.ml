open Core

let render () =
  let width = 160 in
  let height = 144 in
  let buf = Array.create ~len:(width * height) 0 in

  (* Generate 8x8 tile-aligned checkerboard pattern *)
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      (* Block parity: ((x >> 3) ^ (y >> 3)) & 1 *)
      let sel = (x lsr 3) lxor (y lsr 3) land 1 in
      (* White (0x7FFF) or Black (0x0000) based on parity - inverted to match oracle *)
      let color = if sel = 0 then 0x0000 else 0x7FFF in
      buf.((y * width) + x) <- color
    done
  done ;
  buf
