open Domainslib

let num_domains = try int_of_string Sys.argv.(1) with _ -> 1
let n = try int_of_string Sys.argv.(2) with _ -> 1024
let chunk_size = try int_of_string Sys.argv.(3) with _ -> 0

let parallel_matrix_multiply_3 pool m1 m2 m3 =
  let size = Array.length m1 in
  let t = Array.make_matrix size size 0 in (* stores m1*m2 *)
  let res = Array.make_matrix size size 0 in

  Task.parallel_for pool ~chunk_size ~start:0 ~finish:(size - 1) ~body:(fun i ->
    for j = 0 to size - 1 do
      for k = 0 to size - 1 do
        t.(i).(j) <- t.(i).(j) + m1.(i).(k) * m2.(k).(j)
      done
    done);

  Task.parallel_for pool ~chunk_size ~start:0 ~finish:(size - 1) ~body:(fun i ->
    for j = 0 to size - 1 do
      for k = 0 to size - 1 do
        res.(i).(j) <- res.(i).(j) + t.(i).(k) * m3.(k).(j)
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
    let pool = Task.setup_pool ~num_additional_domains:(num_domains - 1) () in
    let m1 = Array.init n (fun _ -> Array.init n (fun _ -> Random.int 100)) in
    let m2 = Array.init n (fun _ -> Array.init n (fun _ -> Random.int 100)) in
    let m3 = Array.init n (fun _ -> Array.init n (fun _ -> Random.int 100)) in
    (* print_matrix m1;
    print_matrix m2; *)
    let _ = Task.run pool (fun () -> parallel_matrix_multiply_3 pool m1 m2 m3) in
    Task.teardown_pool pool
    (* print_matrix m3; *)
