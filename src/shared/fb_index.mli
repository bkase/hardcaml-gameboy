(** Framebuffer indexing helpers *)

(** Convert (x,y) coordinates to word index in row-major layout *)
val word_index : x:int -> y:int -> width:int -> int

(** Check if coordinates are within bounds *)
val in_bounds : x:int -> y:int -> width:int -> height:int -> bool

(** Get GameBoy screen dimensions (160, 144) *)
val dims : unit -> int * int
