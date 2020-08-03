let square n = n * n

let x = 5
let y = 10

let _ =
  let d = Domain.spawn (fun _ -> square x) in
  let sy = square y in
  let sx = Domain.join d in
  Printf.printf "x = %d, y = %d\n" sx sy
