module T = Domainslib.Task
let n = try int_of_string Sys.argv.(2) with _ -> 1000
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4

let arr = Array.create_float n

let _ =
  let domains = T.setup_pool ~num_domains:(num_domains - 1) () in
  let states = Array.init num_domains (fun _ -> Random.State.make_self_init()) in
  T.run domains @@ fun () -> T.parallel_for domains ~chunk_size:(n/num_domains) ~start:0 ~finish:(n-1)
  ~body:(fun i ->
    let d = (Domain.self() :> int) mod num_domains in
    Array.unsafe_set arr i (Random.State.float states.(d) 100. ))
