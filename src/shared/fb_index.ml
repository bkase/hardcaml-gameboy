let word_index ~x ~y ~width = (y * width) + x

let in_bounds ~x ~y ~width ~height = x >= 0 && x < width && y >= 0 && y < height

let dims () = 160, 144
