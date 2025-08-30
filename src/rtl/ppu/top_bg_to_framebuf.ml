(* Top-level module connecting background rendering to framebuffer *)

open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; enable : 'a
    ; vram_data : 'a [@bits 8]
    ; palette : 'a [@bits 8]
    }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t =
    { framebuf_we : 'a
    ; framebuf_addr : 'a [@bits Constants.pixel_addr_width]
    ; framebuf_data : 'a [@bits Constants.pixel_data_width]
    ; vram_addr : 'a [@bits 16]
    ; frame_complete : 'a
    }
  [@@deriving sexp_of, hardcaml]
end

let create scope { I.clock; clear; enable; vram_data = _; palette = _ } =
  let _ = clear in
  (* Unused for now but kept for interface consistency *)

  (* Line controller for pixel positioning - not used in this simple implementation *)
  let _line_ctrl_o =
    Line_controller.create scope
      { Line_controller.I.clock
      ; clear
      ; line_start = enable
      ; (* Start each line when enabled *)
        pixel_ready = enable (* Advance pixel when enabled *)
      }
  in

  (* Background fetcher for tile data *)
  let bg_fetcher_o =
    Bg_fetcher_dmg.create scope { Bg_fetcher_dmg.I.clock; reset = clear; start = enable }
  in

  (* The bg_fetcher already outputs RGB555 data directly *)
  { O.framebuf_we = bg_fetcher_o.fb_a_we
  ; framebuf_addr = bg_fetcher_o.fb_a_addr
  ; framebuf_data = bg_fetcher_o.fb_a_wdata
  ; vram_addr = of_int ~width:16 0
  ; (* Not used in this simple implementation *)
    frame_complete = bg_fetcher_o.done_
  }
