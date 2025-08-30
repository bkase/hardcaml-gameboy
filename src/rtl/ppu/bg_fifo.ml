(* Background FIFO for GameBoy PPU *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; push : 'a
    ; pop : 'a
    ; data_in : 'a [@bits 8] (* 8 pixels, 2 bits each *)
    }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t =
    { data_out : 'a [@bits 2] (* Single pixel, 2 bits *)
    ; empty : 'a
    ; full : 'a
    ; count : 'a [@bits 4] (* FIFO can hold up to 16 pixels *)
    }
  [@@deriving sexp_of, hardcaml]
end

let create _scope { I.clock; clear; push; pop; data_in } =
  let open Always in
  let spec = Reg_spec.create ~clock ~clear () in

  (* Simple shift register FIFO for 16 pixels (32 bits total) *)
  let fifo_reg = Variable.reg ~width:32 spec in
  let count = Variable.reg ~width:4 spec in

  compile
    [ (* Push 8 pixels (16 bits) when push is asserted *)
      when_ push
        [ (* Shift existing data and insert new data at the top *)
          fifo_reg <-- data_in @: fifo_reg.value.:[23, 0]
        ; count <-- count.value +: of_int ~width:4 8
        ]
    ; (* Pop single pixel (2 bits) when pop is asserted *)
      when_
        (pop &: ~:(count.value ==: of_int ~width:4 0))
        [ (* Shift FIFO right by 2 bits *)
          fifo_reg <-- of_int ~width:2 0 @: fifo_reg.value.:[31, 2]
        ; count <-- count.value -: of_int ~width:4 1
        ]
    ] ;

  let empty = count.value ==: of_int ~width:4 0 in
  let full = count.value >=: of_int ~width:4 16 in
  let data_out = fifo_reg.value.:[1, 0] in

  { O.data_out; empty; full; count = count.value }
