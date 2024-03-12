# Parallel Programming in Multicore OCaml

This tutorial will help you get started with writing parallel programs in
Multicore OCaml. All the code examples along with their corresponding **dune** file
are available in the `code/` directory. The tutorial is organised into the
following sections:

- [Introduction](#introduction)
  * [Installation](#installation)
  * [Compatibility with existing code](#compatibility-with-existing-code)
- [Domains](#domains)
- [Domainslib](#domainslib)
  * [Task pool](#task-pool)
  * [Parallel for](#parallel-for)
  * [Async-Await](#async-await)
    + [Fibonacci numbers in parallel](#fibonacci-numbers-in-parallel)
- [Channels](#channels)
  * [Bounded Channels](#bounded-channels)
  * [Task Distribution using Channels](#task-distribution-using-channels)
- [Profiling your code](#profiling-your-code)
  * [Perf](#perf)
  * [Eventlog](#eventlog)

# Introduction

Multicore OCaml is an extension of OCaml with native support for Shared-Memory
Parallelism (SMP) through `Domains` and Concurrency through `Algebraic Effects`.
It is merged to trunk OCaml. OCaml 5.0 will be the first release to officially
support Multicore.

**Concurrency** is how we partition multiple computations such that they can
run in overlapping time periods rather than strictly sequentially.
**Parallelism** is the act of running multiple computations simultaneously,
primarily by using multiple cores on a multicore machine. The Multicore Wiki
has [comprehensive notes](https://github.com/ocaml-multicore/ocaml-multicore/wiki/Concurrency-and-parallelism-design-notes) on the design decisions and
current status of Concurrency and Parallelism in Multicore OCaml.

The Multicore OCaml compiler ships with a concurrent major and a stop-the-world
minor *garbage collector* (GC). The parallel minor GC doesn't require any
changes to the C API, thereby not breaking any associated code with C API.
OCaml 5.0 is expected to land with support for Shared-Memory Parallelism and
Algebraic Effects. A historical variant of the Multicore minor
garbage collector is the concurrent minor collector. Benchmarking experiments
showed better results in terms of throughput and latency on the stop-the-world
parallel minor collector, hence that's chosen to be the default minor collector
on Multicore OCaml, and the concurrent minor collector is not actively developed.
For the intrigued, details on the design and evaluation of the Multicore GC and
compiler are in our
[academic publications](https://github.com/ocaml-multicore/ocaml-multicore/wiki#articles).

The Multicore ecosystem also has the following libraries to complement the
compiler:

* [**Domainslib**](https://github.com/ocaml-multicore/domainslib): data and
control structures for parallel programming
* [**Eio**](https://github.com/ocaml-multicore/eio): effects-based direct-style IO for multicore OCaml
* [**Saturn**](https://github.com/ocaml-multicore/saturn): [lock-free](https://en.wikipedia.org/wiki/Non-blocking_algorithm#Lock-freedom) data
structures (list, hash, bag and queue)
* [**Reagents**](https://github.com/ocaml-multicore/reagents): composable lock-free 
concurrency library for expressing fine grained parallel programs on
Multicore OCaml
* [**Kcas**](https://github.com/ocaml-multicore/kcas): software
  transactional memory (STM) implementation based on an atomic
  lock-free multi-word compare-and-set (MCAS) algorithm

Find ways to profitably write parallel programs in Multicore OCaml. The reader
is assumed to be familiar with OCaml. If not, they are encouraged to read [Real
World OCaml](https://dev.realworldocaml.org/toc.html). The effect handlers'
story is not covered here. For anyone interested, please check out this
[tutorial](https://github.com/ocamllabs/ocaml-effects-tutorial) and some
[examples](https://github.com/ocaml-multicore/effects-examples).

## Installation

Instructions to install OCaml 5 compiler is [here](https://github.com/ocaml-multicore/awesome-multicore-ocaml#installation).

It will also be useful to install `utop` on your Multicore switch by running
`opam install utop`, which should work out of the box.

# Domains

Domains are the basic unit of Parallelism in Multicore OCaml.

```ocaml
let square n = n * n

let x = 5
let y = 10

let _ =
  let d = Domain.spawn (fun _ -> square x) in
  let sy = square y in
  let sx = Domain.join d in
  Printf.printf "x = %d, y = %d\n" sx sy
```
`Domain.spawn` creates a new execution process that runs along with the
current domain.

`Domain.join d` blocks until the domain `d` runs to completion. If the domain
returns a result after its execution, `Domain.join d` also returns that value.
If it raises an uncaught exception, that is thrown. When the parent domain
terminates, all other domains also terminate. To ensure that a domain runs to
completion, we have to join the domain.

Note that the square of x is computed in a new domain and that of y in the
parent domain.

To create its corresponding **dune** file, run this code:

```
(executable
  (name square_domain)
  (modules square_domain))
```

Make sure to use a Multicore switch to build this and all other subsequent
examples in this tutorial.

To execute the code:

```
$ dune build square_domain.exe
$ ./_build/default/square_domain.exe
x = 25, y = 100
```

As expected, the squares of x and y are 25 and 100.

**Common Error Message**

Some common errors while compiling Multicore code are:

```
Error: Unbound module Domain
```

```
Error: Unbound module Atomic
```

```
Error: Library "domainslib" not found.
```

These errors usually mean that the compiler switch used is
not a Multicore switch. Using a Multicore compiler variant should resolve them.

# Domainslib

`Domainslib` is a parallel programming library for Multicore OCaml. It provides
the following APIs which enable easy ways to parallelise OCaml code with only a few
modifications to sequential code:

* **Task**: Work stealing task pool with async/await Parallelism and `parallel_{for, scan}`
* **Channels**: Multiple Producer Multiple Consumer channels which come in two flavours—bounded and unbounded

`Domainslib` is effective in scaling performance when parallelisable
workloads are available.

## Task.pool

In the **Domains** section, we saw how to run programs on multiple cores by
spawning new domains. We often find ourselves spawning and joining
new domains numerous times in the same program, if we were to use that approach
for executing code in parallel. Creating new domains is an expensive operation, so 
we should attempt to limit those when possible. `Task.pool` allows 
execution of all parallel workloads in the same set of domains spawned at
the beginning of the program. Here is how they work:

Note: If you are running this on `utop,` run `#require "domainslib"` with the hash before this.

```ocaml
# open Domainslib

# let pool = Task.setup_pool ~num_domains:3 ()
val pool : Task.pool = <abstr>
```
We have created a new *task pool* with three new domains. The parent domain is
also part of this pool, thus making it a pool of four domains. After the pool is
setup, we can use it to execute all tasks we want to run in parallel. The
`setup_pool` function requires us to specify the number of new domains to be
spawned in the task pool. Ideally, the number of domains used to initiate a task pool 
will match the number of available cores. Since the parent domain also
takes part in the pool, the `num_domains` parameter should be one
less than the number of available cores.

Although not strictly necessary, we highly recommended closing the task pool 
after execution of all tasks. This can be done as follows:

```ocaml
# Task.teardown_pool pool
```

This deactivates the pool, so it's no longer usable. Make sure to do this only
after all tasks are done.

## Parallel_for

In the Task API, a powerful primitive called `parallel_for` can be used to
parallelise computations used in `for` loops. It scales well with very little
change to the sequential code.

Consider the example of matrix multiplication.

First, write the sequential version of a function which performs
matrix multiplication of two matrices and returns the result:

```ocaml
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
```

To make this function run in parallel, one might be inclined to spawn a new
domain for every iteration in the loop, which would look like:

```ocaml
  let domains = Array.init i_n (fun i ->
    Domain.spawn(fun _ ->
      for j = 0 to j_n - 1 do
        for k = 0 to k_n - 1 do
          res.(i).(j) <- res.(i).(j) + a.(i).(k) * b.(k).(j)
        done
      done)) in
   Array.iter Domain.join domains
```
This will be *disastrous* in terms of performance, mostly because 
spawning a new domain is an expensive operation. Alternatively, a task pool offers 
a finite set of available domains that can be used to run your
computations in parallel.

Arrays are usually more efficient compared with lists in Multicore OCaml. 
Although they are not generally favoured in functional
programming, using arrays for the sake of efficiency is a reasonable trade-off.

A better way to parallelise matrix multiplication is with the help of a
`parallel_for`.

```ocaml
let parallel_matrix_multiply pool a b =
  let i_n = Array.length a in
  let j_n = Array.length b.(0) in
  let k_n = Array.length b in
  let res = Array.make_matrix i_n j_n 0 in

  Task.parallel_for pool ~start:0 ~finish:(i_n - 1) ~body:(fun i ->
    for j = 0 to j_n - 1 do
      for k = 0 to k_n - 1 do
        res.(i).(j) <- res.(i).(j) + a.(i).(k) * b.(k).(j)
      done
    done);
  res
```

Observe quite a few differences between the parallel and sequential
versions: The parallel version takes an additional parameter `pool` because 
the `parallel_for` executes the `for` loop on the domains present in
that task pool. While it is possible to initialise a task pool inside the
function itself, it's always better to have a single task pool used across the
entire program. As mentioned earlier, this is to minimise the cost involved in
spawning a new domain. It's also possible to create a global task pool to use 
across, but for the sake of reasoning better about your code, it's recommended 
to use it as a function parameter.

Let's examine the parameters of `parallel_for`. It takes in 
- `pool`, as discussed earlier 
- `start` and `finish`, as the names suggest, are the starting
and ending values of the loop iterations
- `body` contains the actual loop body to be executed

`parallel_for` also has an optional parameter: `chunk_size`, which determines the
granularity of tasks when executing on multiple domains. If no parameter
is given for `chunk size`, the program determines a default chunk size that performs
well in most cases. Only if the default chunk size doesn't work well is it
recommended to experiment with different chunk sizes. The ideal `chunk_size`
depends on a combination of factors:

* **Nature of the Loop:** There are two things to consider pertaining to the
loop when deciding on a `chunk_size`—the *number of iterations* in the
loop and the *amount of time* each iteration takes. If the amount of time is roughly equal, 
then the `chunk_size` could be the number of
iterations divided by the number of cores. On the other hand, if the amount of
time taken is different for every iteration, the chunks should be smaller. If
the total number of iterations is a sizeable number, a `chunk_size` like 32 or
16 is safe to use, whearas if the number of iterations is low, like 10, a
`chunk_size` of 1 would perform best.

* **Machine:** Optimal chunk size varies across machines, so it's recommended
to experiment with a range of values to find out what works best on yours.

### Speedup

Let's find how the parallel matrix multiplication scales on multiple cores.

**Speedup**

The speedup vs. core is enumerated below for input matrices of size 1024x1024:

| Cores | Time (s) | Speedup     |
|-------|----------|-------------|
| 1     | 9.172    | 1           |
| 2     | 4.692    | 1.954816709 |
| 4     | 2.293    | 4           |
| 8     | 1.196    | 7.668896321 |
| 12    | 0.854    | 10.74004684 |
| 16    | 0.76     | 12.06842105 |
| 20    | 0.66     | 13.8969697  |
| 24    | 0.587    | 15.62521295 |

![matrix-graph](images/matrix_multiplication.png)

We've achieved a speedup of 16 with the help of a `parallel_for`. It's very
much possible to achieve linear speedups when parallelisable workloads are
available.

Note that parallel code performance heavily depends on the machine. Some
machine settings specific to Linux systems for obtaining optimal results are
described [here](https://github.com/ocaml-bench/ocaml_bench_scripts#notes-on-hardware-and-os-settings-for-linux-benchmarking).

### Properties and Caveats of `parallel_for`

#### Implicit Barrier

The `parallel_for` has an implicit barrier, meaning any other tasks 
waiting to be executed in the same pool will start only after all chunks
in the `parallel_for` are complete, so we need not worry about creating and
inserting barriers explicitly between two `parallel_for` loops (or some other
operation) after a `parallel_for`. Consider this scenario: we have three
matrices `m1`, `m2`, and `m3`. We want to compute `(m1*m2) * m3`, where `*`
indicates matrix multiplication. For the sake of simplicity, let's assume all
three are square matrices of the same size.

```ocaml
let parallel_matrix_multiply_3 pool m1 m2 m3 =
  let size = Array.length m1 in
  let t = Array.make_matrix size size 0 in (* stores m1*m2 *)
  let res = Array.make_matrix size size 0 in

  Task.parallel_for pool ~start:0 ~finish:(size - 1) ~body:(fun i ->
    for j = 0 to size - 1 do
      for k = 0 to size - 1 do
        t.(i).(j) <- t.(i).(j) + m1.(i).(k) * m2.(k).(j)
      done
    done);

  Task.parallel_for pool ~start:0 ~finish:(size - 1) ~body:(fun i ->
    for j = 0 to size - 1 do
      for k = 0 to size - 1 do
        res.(i).(j) <- res.(i).(j) + t.(i).(k) * m3.(k).(j)
      done
    done);

    res
```

In a hypothetical situation where `parallel_for` didn't have an implicit
barrier, as in the example above, it's very likely that the computation of `res`
wouldn't be correct. Since we already have an implicit barrier, it will perform 
the right computation.

#### Order of Execution

```
for i = start to finish do
  <body>
done
```

A sequential `for` loop, like the one above, runs its iterations in the exact
same order, from `start` to `finish`. However, `parallel_for` makes the order of
execution arbitrary and varies it between two runs of the exact same code. If
the iteration order is important for your code, it's
advisable to use `parallel_for` with some caution.

#### Dependencies Within the Loop

If there are any dependencies within the loop, such as a current iteration
depending on the result of a previous iteration, odds are very high that the
correctness of the code no longer holds if `parallel_for` is used. Task API has
a primitive `parallel_scan` which might come in handy in scenarios like this.

## Async-Await

A `parallel_for` loop easily parallelises iterative tasks. *Async-Await* offers more
flexibility to execute parallel tasks, which is especially useful in
recursive functions. Earlier we saw how to setup and tear down a task
pool. The Task API also has the facility to run specific tasks on a task pool.

### Fibonacci Numbers in Parallel

To calculate a Fibonacci Sequence in parallel, first write a sequential function to calculate Fibonacci numbers. 
The following is a naive Fibonacci function without tail-recursion:

```ocaml
let rec fib n =
if n < 2 then 1
else fib (n - 1) + fib (n - 2)
```

Observe that the two operations in recursive case `fib (n - 1)` and `fib (n -2)` 
do not have any mutual dependencies, which makes it convenient to
compute them in parallel. Essentially, we can calculate `fib (n - 1)` and `fib (n - 2)` 
in parallel and then add the results to get the answer.

Do this by spawning a new domain for performing the calculation and joining
it to obtain the result. Be careful to not spawn more domains
than number of cores available.

```ocaml
let rec fib_par n d =
  if d <= 1 then fib n
  else
    let a = fib_par (n-1) (d-1) in
    let b = Domain.spawn (fun _ -> fib_par (n-2) (d-1)) in
    a + Domain.join b
```
We can also use task pools to execute tasks asynchronously, which is less tedious and scales better.

```ocaml
let rec fib_par pool n =
  if n <= 40 then fib n
  else
    let a = Task.async pool (fun _ -> fib_par pool (n-1)) in
    let b = Task.async pool (fun _ -> fib_par pool (n-2)) in
    Task.await pool a + Task.await pool b
```

Note some differences from the sequential version of Fibonacci:

* `pool` —> an additional parameter for the same reasons in `parallel_for`

* `if n <= 40 then fib n` -> when the input is less than 40, run the
sequential `fib` function. When the input number is small enough, it's better 
to perform the calculations sequentially. We've taken `40` as the
threshold (above). Some experimentation would help find an acceptible 
threshold, below which the computation can be performed sequentially.

* `Task.async` and `Task.await` -> used to run the tasks in parallel
  + **Task.async** executes the task in the pool asynchronously and returns
  a promise, a computation that is not yet complete. After the execution finishes, 
  it result will be stored in the promise.

  + **Task.await** waits for the promise to complete its execution. Once it's 
  done, it returns the result of the task. In case the task raises an
  uncaught exception, `await` also raises the same exception.


# Channels

## Bounded Channels

Channels act as a medium to communicate data between domains and can be shared
between multiple sending and receiving domains. Channels in Multicore OCaml
come in two flavours:

* **Bounded**: buffered channels with a fixed size. A channel with the buffer size
0 corresponds to a synchronised channel, and buffer size 1 gives the `MVar`
structure. Bounded channels can be created with any buffer size.

* **Unbounded**: unbounded channels have no limit on the number of objects they
can hold, so they are only constrained by memory availability.

```ocaml
open Domainslib

let c = Chan.make_bounded 0

let _ =
  let send = Domain.spawn(fun _ -> Chan.send c "hello") in
  let msg =  Chan.recv c in
  Domain.join send;
  Printf.printf "Message: %s\n" msg
```

In the above example, we have a bounded channel `c` of size 0. Any `send` to the channel will be blocked 
until a corresponding receive (`recv`) is encountered. So, if we
remove the `recv`, the program would be blocked indefinitely.

```ocaml
open Domainslib

let c = Chan.make_bounded 0

let _ =
  let send = Domain.spawn(fun _ -> Chan.send c "hello") in
  Domain.join send;
```

The above example would block indefinitely because the `send`
does not have a corresponding `recv`. If we instead create a bounded channel
with buffer size n, it can store up to [n] objects in the channel without a
corresponding receive, exceeding which the sending would block. We can try it
with the same example as above by changing the buffer size to 1:

```ocaml
open Domainslib

let c = Chan.make_bounded 1

let _ =
  let send = Domain.spawn(fun _ -> Chan.send c "hello") in
  Domain.join send;
```

Now the send will not block anymore.

If you don't want to block in `send` or `recv`, `send_poll` and `recv_poll` might
come in handy. They return a Boolean value, so if the operation was successful we
get a `true`, otherwise a `false`.

```ocaml
open Domainslib

let c = Chan.make_bounded 0

let _ =
  let send = Domain.spawn(fun _ ->
          let b = Chan.send_poll c "hello" in
          Printf.printf "%B\n" b) in
  Domain.join send;
```

Here the buffer size is 0 and the channel cannot hold any object, so this program
prints a false.

The same channel may be shared by multiple sending and receiving domains.

```ocaml
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
```

`(Domain.self () :> int)` returns the id of current domain.

## Task Distribution Using Channels

Now that we have some idea about how channels work, let's consider a more
realistic example by writing a generic task distributor that
executes tasks on multiple domains:

```ocaml
module C = Domainslib.Chan
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4
let n = try int_of_string Sys.argv.(2) with _ -> 100

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
```

We have created an unbounded channel `c` which acts as a store for all 
tasks. We'll pay attention to two functions here: `create_work` and `worker`.

`create_work` takes an array of tasks and pushes all task elements to the
channel `c`. The `worker` function receives tasks from the channel and executes
a function `f` with the received task as a parameter. It keeps repeating until it
encounters a `Quit` message, which indicates `worker` can terminate.

Use this template to run any task on multiple cores by running the
`worker` function on all domains. This example runs a naive factorial
function. The granularity of a task could also be tweaked by changing it in
the `worker` function. For instance, `worker` can run for a range of tasks instead
of single one.


# Profiling Your Code

While writing parallel programs in Multicore OCaml, it's quite common to
encounter overheads that might deteriorate the code's performance. This
section describes ways to discover and fix those overheads. Within the Multicore runtime, 
Linux commands `perf` and `eventlog` are particularly useful tools for
performance debugging. Let's do that with the help of an example:

## Perf

The Linux `perf` tool has proven to be very useful when profiling Multicore
OCaml code.

**Profiling Serial Code**

Profiling serial code can help identify parts of code that can potentially
benefit from parallelising. Let's do it for the sequential version of matrix
multiplication:

```
perf record --call-graph dwarf ./matrix_multiplication.exe 1024
```

This results in a profile showing how much time is spent in the `matrix_multiply`
function, which we wanted to parallelise. Remember, if a lot more time is spent 
outside the function we'd like to parallelise,
the maximum speedup possible to achieve would be lower.

Profiling serial code can help reveal the hotspots where we might want to
introduce parallelism.

```
Samples: 51K of event 'cycles:u', Event count (approx.): 28590830181
  Children      Self  Command     Shared Object     Symbol
+   99.84%     0.00%  matmul.exe  matmul.exe        [.] caml_start_program
+   99.84%     0.00%  matmul.exe  matmul.exe        [.] caml_program
+   99.84%     0.00%  matmul.exe  matmul.exe        [.] camlDune__exe__Matmul__entry
+   99.32%    99.31%  matmul.exe  matmul.exe        [.] camlDune__exe__Matmul__matrix_multiply_211
+    0.57%     0.04%  matmul.exe  matmul.exe        [.] camlStdlib__array__init_104
     0.47%     0.37%  matmul.exe  matmul.exe        [.] camlStdlib__random__intaux_278
```



### Overheads in Parallel Code

Linux `perf` can be helpful when identifying overheads in parallel code, which can improve 
the performance by removing overheads.

**Parallel Initialisation of a Float Array with Random Numbers**

Array initialisation using the standard library's `Array.init` is sequential.
A program's parallel workloads scale according to the number of cores
used, although the initialisation takes the same amount of time in all cases.
This might become a bottleneck for parallel workloads.

For float arrays, we have `Array.create_float` to create a fresh float
array. Use this to allocate an array and perform the initialisation in
parallel. Let's do the initialisation of a float array with random numbers in
parallel.

**Naive Implementation**

Below is a naive implementation that will initialise all array elements 
with a Random number:

```ocaml
open Domainslib

let num_domains = try int_of_string Sys.argv.(1) with _ -> 4
let n = try int_of_string Sys.argv.(2) with _ -> 100000
let a = Array.create_float n

let _ =
  let pool = Task.setup_pool ~num_domains:(num_domains - 1) () in
  Task.run pool (fun () -> Task.parallel_for pool ~start:0
  ~finish:(n - 1) ~body:(fun i -> Array.set a i (Random.float 1000.)));
  Task.teardown_pool pool
```

Measure how it scales:

| #Cores | Time(s) |
|--------|---------|
| 1      | 3.136   |
| 2      | 10.19   |
| 4      | 11.815  |

Although we expected to see speedup executing in multiple cores, the code 
actually slows down as the number of cores increase. There's
something unnoticably wrong with the code.

Let's profile the performance with the Linux `perf` profiler:

```
$ perf record ./_build/default/float_init_par.exe 4 100_000_000
$ perf report
```

The `perf` report would look something like this:

![perf-report-1](images/perf_random_1.png)

The overhead at Random bits is a whopping 87.99%! Typically there's
no single cause that we can attribute to such overheads, since they are very
specific to the program. It might need a little careful inspection to find out
what is causing them. In this case, the Random module shares the same state
amongst all domains, which causes contention when multiple domains are
trying to access it simultaneously.

To overcome that, use a different state for every domain so there
isn't any contention from a shared state.

```ocaml
module T = Domainslib.Task
let n = try int_of_string Sys.argv.(2) with _ -> 1000
let num_domains = try int_of_string Sys.argv.(1) with _ -> 4

let arr = Array.create_float n

let _ =
  let domains = T.setup_pool ~num_domains:(num_domains - 1) () in
  let states = Array.init num_domains (fun _ -> Random.State.make_self_init()) in
  T.run domains (fun () -> T.parallel_for domains ~start:0 ~finish:(n-1)
  ~body:(fun i ->
    let d = (Domain.self() :> int) mod num_domains in
    Array.unsafe_set arr i (Random.State.float states.(d) 100. )))
```

We have created `num_domains` different Random States, each to be used by a different domain. This might come 
across as a hack, but if it helps achieve better performance, there is no harm in using them, 
as long as the correctness is intact.

Let's run this on multiple cores:

| #Cores | Time(s) |
|--------|---------|
| 1      | 3.828   |
| 2      | 3.641   |
| 4      | 3.119   |

Examining the times, though it is not as bad as the previous case, it isn't 
close to what we expected. Here's the `perf` report:

![perf-report-2](images/perf_random_2.png)

The overheads at Random bits is less than the previous case, but it's still
quite high at 59.73%. We've used a separate Random State for every domain, so
the overheads aren't caused by any shared state; however, if we look closely, the
Random States are all allocated by the same domain in an array with a small
number of elements, possibly located close to each other in physical memory.
When multiple domains try to access them, they might be sharing cache
lines, or `false sharing`. We can confirm our suspicion with the
help of `perf c2c` on Intel machines:

```
$ perf c2c record _build/default/float_init_par2.exe 4 100_000_000
$ perf c2c report

Shared Data Cache Line Table     (2 entries, sorted on Total HITMs)
       ----------- Cacheline ----------    Total      Tot  ----- LLC Load Hitm -----  ---- Store Reference ----  --- Loa
Index             Address  Node  PA cnt  records     Hitm    Total      Lcl      Rmt    Total    L1Hit   L1Miss       Lc
    0      0x7f2bf49d7dc0     0   11473    13008   94.23%     1306     1306        0     1560      595      965        ◆
    1      0x7f2bf49a7b80     0     271      368    5.48%       76       76        0      123       76       47
```

As evident from the report, there's quite a considerable amount of false sharing happening in
the code. To eliminate false sharing, allocate the Random State in the
domain that is going to use it, so the states will be allocated with
memory locations far from each other.

```ocaml
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
  let domains = T.setup_pool ~num_domains:(num_domains - 1) () in
  T.run domains (fun () -> T.parallel_for domains ~chunk_size:1 ~start:0 ~finish:(num_domains - 1)
  ~body:(fun i -> init_part (i * n / num_domains) ((i+1) * n / num_domains - 1) arr));
  T.teardown_pool domains
```

Now the results are:

| Cores | Time  | Speedup     |
|-------|-------|-------------|
| 1     | 3.055 | 1           |
| 2     | 1.552 | 1.968427835 |
| 4     | 0.799 | 3.823529412 |
| 8     | 0.422 | 7.239336493 |
| 12    | 0.302 | 10.11589404 |
| 16    | 0.242 | 12.62396694 |
| 20    | 0.208 | 14.6875     |
| 24    | 0.186 | 16.42473118 |


![initialisation](images/initialisation.png)

In this process, we have essentially identified bottlenecks for scaling and
eliminated them to achieve better speedups. For more details on profiling with
`perf`, please refer [these notes](https://github.com/ocaml-bench/notes/blob/master/profiling_notes.md).

## Eventlog

The Multicore runtime supports [OCaml instrumented
runtime](https://ocaml.org/manual/runtime-tracing.html).
The instrumented runtime enables capturing metrics about various GC activities.
[Eventlog-tools](https://github.com/ocaml-multicore/eventlog-tools/tree/multicore)
is a library that provides tools to parse the instrumentation logs generated by
the runtime. Some handy tools are described [in the
README](https://github.com/ocaml-multicore/eventlog-tools/tree/multicore).

Eventlog tools can be useful for optimizing Multicore programs.

**Identify Large Pausetimes**

Identifying and fixing events that cause maximum latency can improve the overall
throughput of the program. `ocaml-eventlog-pausetimes` displays statistics from
the generated trace files. For Multicore programs, every domain has its own
trace file, and all of them need to be fed into the input.

```
$ ocaml-eventlog-pausetimes caml-10599-0.eventlog caml-10599-2.eventlog caml-10599-4.eventlog caml-10599-6.eventlog
{
  "name": "caml-10599-6.eventlog",
  "mean_latency": 78328,
  "max_latency": 5292643,
  "distr_latency": [85,89,104,231,303,9923,117639,145118,179488,692880,2728990]
}
```

**Diagnose Imbalance in Task Distribution**

*Eventlog* can be useful to find imbalance in task distribution 
in a parallel program. Imbalance in task distribution essentially means that
not all domains are provided with equal amount of computation to perform, so some 
domains take longer than others to finish their computations, while the idle domains 
keep waiting. This can occur when a sub-
optimal `chunk_size` is picked in a `parallel_for`.

Time periods show when an idle domain is recorded as `domain/idle_wait` in the
`eventlog`. Here is an example `eventlog` generated by a program with unbalanced
task distribution.

![eventlog_task_imbalance](images/unbalanced_task1.png)

If we zoom in further, we see many `domain/idle_wait` events.

![eventlog_task_imbalance_zoomed](images/unbalanced_zoomed.png)

So far we've only found an imbalance in task distribution
in the code, so we'll need to change our code accordingly to make the task
distribution more balanced, which could increase the speedup.

---

Performance debugging can be quite tricky at times, so if you could use some help in
debugging your Multicore OCaml code, feel free to create an Issue in the
Multicore OCaml [issue tracker](https://github.com/ocaml-multicore/ocaml-multicore/issues) along with a minimal code example.
