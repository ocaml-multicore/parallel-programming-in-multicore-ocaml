let n = try int_of_string Sys.argv.(1) with _ -> 40

let rec fib n =
  if n < 2 then 1
  else fib (n-1) + fib (n-2)

let _ = Printf.printf "fib(%d) = %d\n" n (fib n)
