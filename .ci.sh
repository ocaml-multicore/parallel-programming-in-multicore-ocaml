# use opam to install multicore and dune
opam update -u
opam switch create ${OCAML_VERSION} --packages=ocaml-variants.${OCAML_VERSION} --repositories=multicore=git+https://github.com/ocaml-multicore/multicore-opam.git,default
eval $(opam env)
opam install dune domainslib

cd code
make all
make test