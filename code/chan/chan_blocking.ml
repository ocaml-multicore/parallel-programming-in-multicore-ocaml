open Domainslib

let c = Chan.make_bounded 0

let _ =
  let send = Domain.spawn(fun _ -> Chan.send c "hello") in
  Domain.join send;
