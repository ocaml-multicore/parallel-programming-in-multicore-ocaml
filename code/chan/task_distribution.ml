module C = Domainslib.Chan
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4
let n = try int_of_string Sys.argv.(2) with _ -> 10

type 'a message = Task of 'a | Quit

let c = C.make_unbounded ()

let create_work tasks =
  Array.iter (fun t -> C.send c (Task t)) tasks;
  for _ = 1 to num_domains do
    C.send c Quit
  done

let rec worker f () =
  match C.recv c with
  | Task a ->
      f a;
      worker f ()
  | Quit -> ()

let _ =
  let tasks = Array.init n (fun i -> i) in
  create_work tasks ;
  let factorial n =
    let rec aux n acc =
        if (n > 0) then aux (n-1) (acc*n)
        else acc in
    aux n 1
  in
  let results = Array.make n 0 in
  let update r i = r.(i) <- factorial i in
  let domains = Array.init (num_domains - 1)
              (fun _ -> Domain.spawn(worker (update results))) in
  worker (update results) ();
  Array.iter Domain.join domains;
  Array.iter (Printf.printf "%d ") results
