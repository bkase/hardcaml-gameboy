open Base
open Hardcaml

(* Framebuffer module for GameBoy LCD (Constants.screen_width x Constants.screen_height pixels)
 *
 * Addressing scheme:
 * - Each pixel is stored as one Constants.pixel_data_width-bit word (RGB555 format)
 * - Word address = pixel address (they are equivalent in this design)
 * - Pixel address range: 0 to Constants.total_pixels-1
 * - Address 0 = first pixel (top-left), Address (Constants.total_pixels-1) = last pixel (bottom-right)
 * - Address calculation: pixel_address = row * Constants.screen_width + column
 * - Constants.pixel_addr_width-bit address width supports 0-32,767 but only 0-(Constants.total_pixels-1) are valid
 * - Out-of-range addresses (Constants.total_pixels+) will cause undefined behavior
 * - Simulation-only validation signals detect invalid addresses
 *
 * The framebuffer stores RGB555 pixel data (Constants.pixel_data_width-bit per pixel):
 * - Bit 15: Unused (always 0)
 * - Bits 14-10: Red channel (Constants.rgb555_channel_width bits)
 * - Bits 9-5: Green channel (Constants.rgb555_channel_width bits)
 * - Bits 4-0: Blue channel (Constants.rgb555_channel_width bits)
 *)

module I = struct
  type 'a t =
    { clock : 'a
    ; (* Port A - Write interface *)
      a_addr : 'a
          [@bits Constants.pixel_addr_width]
          (* Pixel address 0..(Constants.total_pixels-1) (word address = pixel address) -
             MUST be within valid range *)
    ; a_wdata : 'a [@bits Constants.pixel_data_width] (* RGB555 pixel data *)
    ; a_we : 'a [@bits 1] (* Write enable *)
    ; (* Port B - Read interface *)
      b_addr : 'a [@bits Constants.pixel_addr_width]
          (* Pixel address 0..(Constants.total_pixels-1) (word address = pixel address) -
             MUST be within valid range *)
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { b_rdata : 'a [@bits Constants.pixel_data_width] (* Read data (1 cycle latency) *) }
  [@@deriving hardcaml]
end

let create scope (i : _ I.t) =
  let open Signal in
  (* Register specification for synchronous logic *)
  let spec = Reg_spec.create ~clock:i.clock () in

  (* Framebuffer size: Constants.screen_width × Constants.screen_height =
     Constants.total_pixels pixels = Constants.total_pixels Constants.pixel_data_width-bit
     words (one word per pixel) *)
  let framebuf_size = Constants.total_pixels in

  (* Maximum valid pixel address is (Constants.total_pixels-1) = GameBoy screen size *)
  let max_valid_addr = framebuf_size - 1 in

  (* Debug signals for pixel address validation - these will be visible in simulation
     waveforms *)
  let ( -- ) = Scope.naming scope in
  let write_addr_too_large = i.a_addr >:. max_valid_addr in
  let invalid_write = i.a_we &: write_addr_too_large in
  let read_addr_too_large = i.b_addr >:. max_valid_addr in

  (* Name these signals for debugging - they'll show up in waveforms *)
  let _invalid_write_debug = invalid_write -- "invalid_framebuf_write_addr" in
  let _read_addr_too_large_debug = read_addr_too_large -- "invalid_framebuf_read_addr" in

  (* Create dual-port RAM using HardCaml's Ram.create *)
  let ram_output =
    Ram.create ~name:"framebuffer_ram" ~collision_mode:Read_before_write
      ~size:framebuf_size
      ~write_ports:
        [| { write_clock = i.clock
           ; write_enable = i.a_we
           ; write_address = i.a_addr
           ; write_data = i.a_wdata
           }
        |]
      ~read_ports:
        [| { read_clock = i.clock
           ; read_enable = vdd (* Always enabled for simplicity *)
           ; read_address = i.b_addr
           }
        |]
      ()
  in

  (* Port B has registered (1-cycle latency) read output *)
  let b_rdata = reg spec ram_output.(0) in

  { O.b_rdata }
