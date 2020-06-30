let size = try int_of_string Sys.argv.(1) with _ -> 1024

let matrix_multiply a b =
  let i_n = Array.length a in
  let j_n = Array.length b.(0) in
  let k_n = Array.length b in
  let res = Array.make_matrix i_n j_n 0 in
  for i = 0 to i_n - 1 do
    for j = 0 to j_n - 1 do
      for k = 0 to k_n - 1 do
        res.(i).(j) <- res.(i).(j) + a.(i).(k) * b.(k).(j)
      done
    done
  done;
  res

let print_matrix m =
  for i = 0 to pred (Array.length m) do
    for j = 0 to pred (Array.length m.(0)) do
      print_string @@ Printf.sprintf " %d " m.(i).(j)
    done;
    print_endline ""
  done

let _ =
  let m1 = Array.init size (fun _ -> Array.init size (fun _ -> Random.int 100)) in
  let m2 = Array.init size (fun _ -> Array.init size (fun _ -> Random.int 100)) in
  let _ = matrix_multiply m1 m2 in
  ()
