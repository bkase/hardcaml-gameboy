open Hardcaml

(** Dual-port framebuffer module for GameBoy RGB555 display

    Addressing scheme:
    - Each pixel is stored as one Constants.pixel_data_width-bit word (RGB555 format)
    - Word address = pixel address (they are equivalent in this design)
    - Address 0 = first pixel (top-left corner: row 0, column 0)
    - Address (Constants.total_pixels-1) = last pixel (bottom-right corner: row
      (Constants.screen_height-1), column (Constants.screen_width-1))
    - Address calculation: pixel_address = row * Constants.screen_width + column *)

module I : sig
  type 'a t =
    { clock : 'a
    ; (* Port A - Write interface *)
      a_addr : 'a
          [@bits Constants.pixel_addr_width]
          (* Pixel address 0..(Constants.total_pixels-1) (word address = pixel address) *)
    ; a_wdata : 'a [@bits Constants.pixel_data_width] (* RGB555 pixel data *)
    ; a_we : 'a [@bits 1] (* Write enable *)
    ; (* Port B - Read interface *)
      b_addr : 'a [@bits Constants.pixel_addr_width]
          (* Pixel address 0..(Constants.total_pixels-1) (word address = pixel address) *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { b_rdata : 'a [@bits Constants.pixel_data_width] (* Read data (1 cycle latency) *) }
  [@@deriving hardcaml]
end

(** Create framebuffer with dual-port RAM
    - Size: Constants.total_pixels words × Constants.pixel_data_width bits
      (Constants.screen_width×Constants.screen_height pixels, one word per pixel)
    - Port A: Synchronous write port
    - Port B: Synchronous read port with 1-cycle latency
    - Collision mode: Read_before_write
    - Addressing: Word address equals pixel address (0 to Constants.total_pixels-1) *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t
