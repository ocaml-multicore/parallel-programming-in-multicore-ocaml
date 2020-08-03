open Domainslib

let num_domains = try int_of_string Sys.argv.(1) with _ -> 4

let c = Chan.make_bounded num_domains

let send c =
  Printf.printf "Sending from: %d\n" (Domain.self () :> int);
  Chan.send c "howdy!"

let recv c =
  Printf.printf "Receiving at: %d\n" (Domain.self () :> int);
  Chan.recv c |> ignore

let _ =
  let senders = Array.init num_domains
                  (fun _ -> Domain.spawn(fun _ -> send c )) in
  let receivers = Array.init num_domains
                  (fun _ -> Domain.spawn(fun _ -> recv c)) in

  Array.iter Domain.join senders;
  Array.iter Domain.join receivers
