module type S = sig
  val ( lsl ) : int -> int -> int

  val ( lsr ) : int -> int -> int

  val ( land ) : int -> int -> int

  val ( lor ) : int -> int -> int

  val ( lxor ) : int -> int -> int

  val mask : int -> bits:int -> int

  val test_bit : int -> idx:int -> int
end

module Int : S = struct
  let ( lsl ) = ( lsl )

  let ( lsr ) = ( lsr )

  let ( land ) = ( land )

  let ( lor ) = ( lor )

  let ( lxor ) = ( lxor )

  let mask x ~bits = x land ((1 lsl bits) - 1)

  let test_bit x ~idx = (x lsr idx) land 1
end
