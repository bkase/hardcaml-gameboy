open Core

let write_ppm_rgb555 ~path ~width ~height ~buf =
  let oc = Out_channel.create ~binary:true path in
  (* Write PPM header *)
  Out_channel.fprintf oc "P6\n%d %d\n255\n" width height ;

  (* Convert RGB555 to RGB888 and write *)
  Array.iter buf ~f:(fun rgb555 ->
      let r8, g8, b8 = Spec_ppu.Gb_math_int.to_rgb888 ~rgb555 in
      Out_channel.output_byte oc r8 ;
      Out_channel.output_byte oc g8 ;
      Out_channel.output_byte oc b8) ;

  Out_channel.close oc
