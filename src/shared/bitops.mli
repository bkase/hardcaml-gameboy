(** Bit operations abstraction for future functorization *)

(** Bit operations signature for integers and signals *)
module type S = sig
  (** Left shift *)
  val ( lsl ) : int -> int -> int

  (** Right shift *)
  val ( lsr ) : int -> int -> int

  (** Bitwise AND *)
  val ( land ) : int -> int -> int

  (** Bitwise OR *)
  val ( lor ) : int -> int -> int

  (** Bitwise XOR *)
  val ( lxor ) : int -> int -> int

  (** Mask to specified number of bits *)
  val mask : int -> bits:int -> int

  (** Test bit at index *)
  val test_bit : int -> idx:int -> int
end

(** Integer implementation *)
module Int : S
