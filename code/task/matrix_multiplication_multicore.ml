open Domainslib

let num_domains = try int_of_string Sys.argv.(1) with _ -> 1
let n = try int_of_string Sys.argv.(2) with _ -> 1024
let chunk_size = try int_of_string Sys.argv.(3) with _ -> 0

let parallel_matrix_multiply pool a b =
  let i_n = Array.length a in
  let j_n = Array.length b.(0) in
  let k_n = Array.length b in
  let res = Array.make_matrix i_n j_n 0 in

  Task.parallel_for pool ~chunk_size ~start:0 ~finish:(i_n - 1) ~body:(fun i ->
    for j = 0 to j_n - 1 do
      for k = 0 to k_n - 1 do
        res.(i).(j) <- res.(i).(j) + a.(i).(k) * b.(k).(j)
      done
    done);
  res

let print_matrix m =
  for i = 0 to pred (Array.length m) do
    for j = 0 to pred (Array.length m.(0)) do
      print_string @@ Printf.sprintf " %d " m.(i).(j)
    done;
    print_endline ""
  done

let _ =
    let pool = Task.setup_pool ~num_additional_domains:(num_domains - 1) in
    let m1 = Array.init n (fun _ -> Array.init n (fun _ -> Random.int 100)) in
    let m2 = Array.init n (fun _ -> Array.init n (fun _ -> Random.int 100)) in
    (* print_matrix m1;
    print_matrix m2; *)
    let _ = parallel_matrix_multiply pool m1 m2 in
    Task.teardown_pool pool
    (* print_matrix m3; *)
