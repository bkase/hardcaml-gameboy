open Hardcaml

(** DMG Background Fetcher - Implements minimal background fetching using tilemap +
    tiledata *)

module I : sig
  type 'a t =
    { clock : 'a
    ; reset : 'a (* Active-high asynchronous reset signal *)
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
      fb_a_addr : 'a
          [@bits Constants.pixel_addr_width]
          (* Pixel address 0..23039 (word address = pixel address) *)
    ; fb_a_wdata : 'a [@bits Constants.pixel_data_width] (* RGB555 pixel data *)
    ; fb_a_we : 'a (* Write enable *)
    }
  [@@deriving hardcaml]
end

(** Create bg_fetcher_dmg that generates checkerboard pattern via tilemap + tiledata path
    - Uses real PPU fetching process: tilemap lookup -> tile data fetch -> pixel decode
    - Hardcoded tilemap: XOR checkerboard pattern with tile 0 (black) and tile 1 (white)
    - Hardcoded tiledata: Tile 0 = all 0xFF (black), Tile 1 = all 0x00 (white)
    - BGP palette: 0xE4 (standard GameBoy palette)
    - 1 pixel per clock cycle throughput
    - Total Constants.total_pixels cycles to fill entire frame
    - Addressing: Outputs pixel addresses 0-(Constants.total_pixels-1) (word address =
      pixel address) where address = y * Constants.screen_width + x for coordinate (x,y)

    Reset behavior: All internal registers are reset asynchronously when reset signal is
    high (active-high). This initializes the FSM to idle state, clearing all counters and
    state machine state. *)
val create : Scope.t -> Signal.t I.t -> Signal.t O.t
