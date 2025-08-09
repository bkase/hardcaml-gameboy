open Hardcaml

(** Top-level checkerboard to framebuffer module *)

module I : sig
  type 'a t =
    { clock : 'a
    ; reset : 'a
    ; start : 'a (* Pulse to start checkerboard generation *)
    ; b_addr : 'a [@bits 15] (* Read address for Port B *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { busy : 'a (* High while generating pattern *)
    ; done_ : 'a (* Pulse when generation complete *)
    ; b_rdata : 'a [@bits 16] (* Read data from Port B (1-cycle latency) *)
    }
  [@@deriving hardcaml]
end

(** Create top-level module that wires Checker_fill to Framebuf *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t