module type S = sig
  type t

  val zero : int -> t

  val const : int -> width:int -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t

  val ( land ) : t -> t -> t

  val ( lor ) : t -> t -> t

  val ( lxor ) : t -> t -> t

  val ( lsl ) : t -> int -> t

  val ( lsr ) : t -> int -> t

  val eq : t -> t -> t

  val lt : t -> t -> t

  val uresize : t -> width:int -> t

  val select : t -> int -> int -> t

  val mux2 : sel:t -> t -> t -> t

  val mux : sel:t -> t list -> t
end
