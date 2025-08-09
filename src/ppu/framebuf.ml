open Base
open Hardcaml

module I = struct
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

module O = struct
  type 'a t = { b_rdata : 'a [@bits 16] (* Read data (1 cycle latency) *) }
  [@@deriving hardcaml]
end

let create _scope (i : _ I.t) =
  let open Signal in
  (* Register specification for synchronous logic *)
  let spec = Reg_spec.create ~clock:i.clock () in

  (* Framebuffer size: 160×144 = 23,040 pixels = 23,040 16-bit words *)
  let framebuf_size = 23040 in

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
