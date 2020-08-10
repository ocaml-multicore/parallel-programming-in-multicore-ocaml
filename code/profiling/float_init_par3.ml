module T = Domainslib.Task
let n = try int_of_string Sys.argv.(2) with _ -> 1000
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4

let k : Random.State.t Domain.DLS.key = Domain.DLS.new_key ()
let get_state () = try Option.get @@ Domain.DLS.get k with _ ->
  begin
    Domain.DLS.set k (Random.State.make_self_init ());
    Option.get @@ Domain.DLS.get k
  end

let arr = Array.create_float n

let init_part s e arr =
    let my_state = get_state () in
    for i = s to e do
      Array.unsafe_set arr i (Random.State.float my_state 100.)
    done

let _ =
  let domains = T.setup_pool ~num_domains:(num_domains - 1) in
  T.parallel_for domains ~chunk_size:1 ~start:0 ~finish:(num_domains - 1)
  ~body:(fun i -> init_part (i * n / num_domains) ((i+1) * n / num_domains - 1) arr);
  T.teardown_pool domains
