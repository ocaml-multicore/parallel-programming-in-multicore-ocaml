let _ =
  let d1 = Domain.spawn(fun _ -> Printf.printf "Hello, World from spawned domain!\n") in
  Printf.printf "Hello, World!\n";
  Domain.join d1
