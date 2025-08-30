(* Checker fill pattern generator for testing *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a; clear : 'a; pixel_addr : 'a [@bits Constants.pixel_addr_width] }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { pixel_data : 'a [@bits Constants.pixel_data_width] }
  [@@deriving sexp_of, hardcaml]
end

let create _scope { I.clock = _; clear = _; pixel_addr } =
  (* Create checker pattern based on pixel address *)
  let x_coord =
    pixel_addr &: of_int ~width:Constants.pixel_addr_width (Constants.screen_width - 1)
  in
  let y_coord = srl pixel_addr 8 in
  (* 8 bits for 256 pixel width, but screen is 160 so this is approximate *)

  (* Checker pattern: alternate between white and black *)
  let checker_bit = x_coord +: y_coord &: of_int ~width:1 1 in
  let pixel_data =
    mux2 checker_bit
      (of_int ~width:Constants.pixel_data_width Constants.rgb555_white)
      (of_int ~width:Constants.pixel_data_width Constants.rgb555_black)
  in

  { O.pixel_data }
