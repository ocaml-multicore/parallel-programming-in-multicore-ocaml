let num_domains = try int_of_string Sys.argv.(1) with _ -> 1
let n = try int_of_string Sys.argv.(2) with _ -> 40

open Domainslib

let rec fib n =
  if n < 2 then 1
  else fib (n-1) + fib (n-2)

let rec fib_par pool n =
  if n <= 40 then fib n
  else
    let a = Task.async pool (fun _ -> fib_par pool (n-1)) in
    let b = Task.async pool (fun _ -> fib_par pool (n-2)) in
    Task.await pool a + Task.await pool b

let main =
  let pool = Task.setup_pool ~num_domains:(num_domains - 1) () in
  let res = Task.run pool (fun () -> fib_par pool) n in
  Task.teardown_pool pool;
  Printf.printf "fib(%d) = %d\n" n res
