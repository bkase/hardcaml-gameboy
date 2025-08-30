open Hardcaml

include (
  struct
    type t = Signal.t

    let zero w = Signal.zero w

    let const x ~width = Signal.of_int ~width x

    let ( + ) = Signal.( +: )

    let ( - ) = Signal.( -: )

    let ( land ) = Signal.( &: )

    let ( lor ) = Signal.( |: )

    let ( lxor ) = Signal.( ^: )

    let ( lsl ) x n = Signal.sll x n

    let ( lsr ) x n = Signal.srl x n

    let eq = Signal.( ==: )

    let lt = Signal.( <: )

    let uresize t ~width = Signal.uresize t width

    let select = Signal.select

    let mux2 ~sel f t = Signal.mux2 sel t f

    let mux ~sel lst = Signal.mux sel lst
  end :
    Gb_shared.Bitops.S with type t = Signal.t)
