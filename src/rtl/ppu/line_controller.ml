(* Line controller for GameBoy PPU *)

open Hardcaml
open Signal

module I = struct
  type 'a t = { clock : 'a; clear : 'a; line_start : 'a; pixel_ready : 'a }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t =
    { pixel_x : 'a [@bits Constants.coord_width]
    ; pixel_y : 'a [@bits Constants.coord_width]
    ; line_complete : 'a
    ; frame_complete : 'a
    }
  [@@deriving sexp_of, hardcaml]
end

let create _scope { I.clock; clear; line_start; pixel_ready } =
  let open Always in
  let spec = Reg_spec.create ~clock ~clear () in

  let pixel_x = Variable.reg ~width:Constants.coord_width spec in
  let pixel_y = Variable.reg ~width:Constants.coord_width spec in

  compile
    [ when_ line_start [ pixel_x <-- of_int ~width:Constants.coord_width 0 ]
    ; when_ pixel_ready
        [ if_
            (pixel_x.value
            <: of_int ~width:Constants.coord_width (Constants.screen_width - 1))
            [ pixel_x <-- pixel_x.value +: of_int ~width:Constants.coord_width 1 ]
            [ pixel_x <-- of_int ~width:Constants.coord_width 0
            ; if_
                (pixel_y.value
                <: of_int ~width:Constants.coord_width (Constants.screen_height - 1))
                [ pixel_y <-- pixel_y.value +: of_int ~width:Constants.coord_width 1 ]
                [ pixel_y <-- of_int ~width:Constants.coord_width 0 ]
            ]
        ]
    ] ;

  let line_complete =
    pixel_x.value ==: of_int ~width:Constants.coord_width (Constants.screen_width - 1)
  in
  let frame_complete =
    pixel_y.value
    ==: of_int ~width:Constants.coord_width (Constants.screen_height - 1)
    &: line_complete
  in

  { O.pixel_x = pixel_x.value; pixel_y = pixel_y.value; line_complete; frame_complete }
