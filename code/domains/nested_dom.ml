let _ =
  let t = Domain.spawn(fun _ -> Domain.spawn(fun _ -> Printf.printf "hello")) in
  Domain.join t
