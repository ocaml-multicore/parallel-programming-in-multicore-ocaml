open Domainslib

let c = Chan.make_bounded 0

let _ =
  let send = Domain.spawn(fun _ ->
          let b = Chan.send_poll c "hello" in
          Printf.printf "%B\n" b) in
  Domain.join send;
