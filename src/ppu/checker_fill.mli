open Hardcaml

(** FSM-based checkerboard pattern generator *)

module I : sig
  type 'a t =
    { clock : 'a
    ; reset : 'a
    ; start : 'a (* Pulse high for one cycle to begin filling *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { (* Control signals *)
      busy : 'a (* High while filling framebuffer *)
    ; done_ : 'a (* 1-cycle pulse when fill completes *)
    ; (* Framebuffer Port A interface *)
      fb_a_addr : 'a [@bits 15] (* Word address 0..23039 *)
    ; fb_a_wdata : 'a [@bits 16] (* RGB555 pixel data *)
    ; fb_a_we : 'a (* Write enable *)
    }
  [@@deriving hardcaml]
end

(** Create checker_fill FSM that generates 8×8 checkerboard pattern
    - Pattern: (x>>3 XOR y>>3) & 1 determines color
    - Red (0x7C00) for pattern=0, Black (0x0000) for pattern=1
    - 1 pixel per clock cycle throughput
    - Total 23,040 cycles to fill entire frame *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t