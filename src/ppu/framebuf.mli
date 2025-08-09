open Hardcaml

(** Dual-port framebuffer module for 160x144 RGB555 display
    
    Addressing scheme:
    - Each pixel is stored as one 16-bit word (RGB555 format)
    - Word address = pixel address (they are equivalent in this design)
    - Address 0 = first pixel (top-left corner: row 0, column 0)
    - Address 23039 = last pixel (bottom-right corner: row 143, column 159)
    - Address calculation: pixel_address = row * 160 + column *)

module I : sig
  type 'a t =
    { clock : 'a
    ; (* Port A - Write interface *)
      a_addr : 'a [@bits 15] (* Pixel address 0..23039 (word address = pixel address) *)
    ; a_wdata : 'a [@bits 16] (* RGB555 pixel data *)
    ; a_we : 'a [@bits 1] (* Write enable *)
    ; (* Port B - Read interface *)
      b_addr : 'a [@bits 15] (* Pixel address 0..23039 (word address = pixel address) *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { b_rdata : 'a [@bits 16] (* Read data (1 cycle latency) *) }
  [@@deriving hardcaml]
end

(** Create framebuffer with dual-port RAM
    - Size: 23,040 words × 16 bits (160×144 pixels, one word per pixel)
    - Port A: Synchronous write port
    - Port B: Synchronous read port with 1-cycle latency  
    - Collision mode: Read_before_write
    - Addressing: Word address equals pixel address (0 to 23039) *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t
