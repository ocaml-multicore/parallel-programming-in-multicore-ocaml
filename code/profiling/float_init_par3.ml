module T = Domainslib.Task
let n = try int_of_string Sys.argv.(2) with _ -> 1000
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4

let arr = Array.create_float n

let init_part s e arr =
    let my_state = Random.State.make_self_init () in
    for i = s to e do
      Array.unsafe_set arr i (Random.State.float my_state 100.)
    done

let _ =
  let domains = T.setup_pool ~num_additional_domains:(num_domains - 1) in
  T.parallel_for domains ~chunk_size:1 ~start:0 ~finish:(num_domains - 1)
  ~body:(fun i -> init_part (i * n / num_domains) ((i+1) * n / num_domains - 1) arr);
  T.teardown_pool domains
