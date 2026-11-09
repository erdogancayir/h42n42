FROM ocaml/opam:debian-12-ocaml-5.2

ENV OPAMCONFIRMLEVEL=unsafe-yes

RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends \
       pkg-config libgmp-dev libssl-dev libev-dev zlib1g-dev libsqlite3-dev \
    && sudo rm -rf /var/lib/apt/lists/*

RUN opam update \
    && opam install -y eliom.11.1.1 ocsipersist-sqlite ocsipersist-sqlite-config \
    && opam clean -a -c -s --logs

WORKDIR /home/opam/h42n42
COPY --chown=opam:opam . .

RUN opam exec -- make re && opam exec -- make test

EXPOSE 8080

CMD ["opam", "exec", "--", "make", "run"]
