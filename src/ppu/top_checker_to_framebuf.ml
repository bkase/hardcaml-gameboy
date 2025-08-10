module I = struct
  type 'a t =
    { clock : 'a
    ; reset : 'a
    ; start : 'a (* Pulse to start checkerboard generation *)
    ; b_addr : 'a [@bits Constants.pixel_addr_width] (* Read address for Port B *)
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { busy : 'a (* High while generating pattern *)
    ; done_ : 'a (* Pulse when generation complete *)
    ; b_rdata : 'a [@bits Constants.pixel_data_width]
          (* Read data from Port B (1-cycle latency) *)
    }
  [@@deriving hardcaml]
end

let create scope (i : _ I.t) =
  (* Instantiate checker fill pattern generator *)
  let checker_out =
    Checker_fill.create scope
      { Checker_fill.I.clock = i.clock; reset = i.reset; start = i.start }
  in

  (* Instantiate framebuffer *)
  let framebuf_out =
    Framebuf.create scope
      { Framebuf.I.clock = i.clock
      ; a_addr = checker_out.fb_a_addr
      ; a_wdata = checker_out.fb_a_wdata
      ; a_we = checker_out.fb_a_we
      ; b_addr = i.b_addr
      }
  in

  (* Wire outputs *)
  { O.busy = checker_out.busy; done_ = checker_out.done_; b_rdata = framebuf_out.b_rdata }
