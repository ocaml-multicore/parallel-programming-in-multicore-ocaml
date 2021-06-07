open Domainslib

let num_domains = try int_of_string Sys.argv.(1) with _ -> 4
let n = try int_of_string Sys.argv.(2) with _ -> 100000
let a = Array.create_float n

let _ =
  let pool = Task.setup_pool ~num_additional_domains:(num_domains-1) in
  Task.parallel_for pool ~chunk_size:(n/num_domains) ~start:0
  ~finish:(n - 1) ~body:(fun i -> Array.set a i (Random.float 1000.));
  Task.teardown_pool pool
