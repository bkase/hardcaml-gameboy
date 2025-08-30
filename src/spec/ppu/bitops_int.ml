include (
  struct
    type t = int

    let zero _ = 0

    let const x ~width:_ = x

    let ( + ) = ( + )

    let ( - ) = ( - )

    let ( land ) = ( land )

    let ( lor ) = ( lor )

    let ( lxor ) = ( lxor )

    let ( lsl ) x n = x lsl n

    let ( lsr ) x n = x lsr n

    let eq a b = if a = b then 1 else 0

    let lt a b = if a < b then 1 else 0

    let uresize x ~width:_ = x

    let select x hi lo = (x lsr lo) land ((1 lsl (hi - lo + 1)) - 1)

    let mux2 ~sel f t = if sel <> 0 then t else f

    let mux ~sel lst =
      let len = List.length lst in
      if len = 0 then failwith "mux: empty list"
      else if sel < 0 then List.hd lst
      else if sel >= len then List.nth lst (len - 1)
      else List.nth lst sel
  end :
    Gb_shared.Bitops.S with type t = int)
