open Hardcaml

(** Top-level checkerboard to framebuffer module *)

module I : sig
  type 'a t =
    { clock : 'a
    ; reset : 'a (* Active-high asynchronous reset signal *)
    ; start : 'a (* Pulse to start checkerboard generation *)
    ; b_addr : 'a [@bits Constants.pixel_addr_width]
          (* Pixel read address 0..(Constants.total_pixels-1) (word address = pixel
             address) *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { busy : 'a (* High while generating pattern *)
    ; done_ : 'a (* Pulse when generation complete *)
    ; b_rdata : 'a [@bits Constants.pixel_data_width]
          (* Read data from Port B (1-cycle latency) *)
    }
  [@@deriving hardcaml]
end

(** Create top-level module that wires Checker_fill to Framebuf

    Reset behavior: The reset signal (active-high) is passed through to the Checker_fill
    module which uses it for asynchronous reset of internal registers. The framebuffer
    (RAM) itself is not reset, but the pattern generator is reset to idle state. *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t
