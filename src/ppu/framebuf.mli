open Hardcaml

(** Dual-port framebuffer module for 160x144 RGB555 display *)

module I : sig
  type 'a t =
    { clock : 'a
    ; (* Port A - Write interface *)
      a_addr : 'a [@bits 15] (* Address 0..23039 *)
    ; a_wdata : 'a [@bits 16] (* RGB555 pixel data *)
    ; a_we : 'a [@bits 1] (* Write enable *)
    ; (* Port B - Read interface *)
      b_addr : 'a [@bits 15] (* Address 0..23039 *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { b_rdata : 'a [@bits 16] (* Read data (1 cycle latency) *) }
  [@@deriving hardcaml]
end

(** Create framebuffer with dual-port RAM
    - Size: 23,040 words × 16 bits (160×144 pixels)
    - Port A: Synchronous write port
    - Port B: Synchronous read port with 1-cycle latency
    - Collision mode: Read_before_write *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t