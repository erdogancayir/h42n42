# h42n42

Simulation of a population of creatures (the **Creets**) threatened by the
H42N42 virus, written in OCaml with [Ocsigen](https://ocsigen.org)
(Eliom, Js_of_ocaml, Lwt and TyXML). The game runs entirely in the browser;
the Ocsigen server only delivers the page and the compiled client program.

## Objectives

- Run an OCaml program in the browser with Js_of_ocaml
- Generate statically checked HTML with TyXML (`Eliom_content.Html.D`)
- Manipulate the DOM from OCaml
- Handle mouse events with `Lwt_js_events`
- Drive every Creet with its own cooperative Lwt thread

## Prerequisites

- Docker
- Docker Compose

## Installation and launch

```sh
git clone <repository> h42n42
cd h42n42
docker-compose up --build
```

The first build downloads and compiles the OCaml dependencies, so it takes a
few minutes. The unit tests run during the image build: if one fails, the
build stops.

Open **http://localhost:8080** in a browser.

Stop the application with `Ctrl+C`, or `docker-compose down`.

## Game rules

- The **toxic river** is at the top of the board, the **hospital** at the bottom.
- Creets move in straight lines, change direction from time to time and bounce
  on the edges of the board. They pass through each other.
- The game starts with 8 Creets. A new one is born every 5 seconds as long as
  at least one healthy Creet is alive.
- A Creet that touches the river becomes **sick** (red) and moves 15% slower.
  Only a real contact counts: a Creet outside the board, next to the river,
  is not infected.
- A sick Creet touching a healthy one has a 2% chance to infect it at each
  iteration of the contact.
- Every 10 seconds, a sick Creet has a 10% chance to become **berserk** and a
  10% chance to become **mean** (never both):
  - **berserk** (brown): its diameter grows by 10% every 10 seconds; it dies
    when it reaches 4 times its original size (about 2 min 30 s);
  - **mean** (black): 15% smaller, chases the nearest healthy Creet and dies
    after 1 minute.
- Drag any healthy or sick Creet with the mouse. A Creet being dragged cannot
  be infected. It can be dropped anywhere, even outside the board, and then
  bounces back into it. It always stays visible in the window, even if the
  mouse is released outside of it.
- Dropping a sick Creet into the hospital heals it. A sick Creet that wanders
  into the hospital on its own is not healed. Berserk and mean Creets cannot be
  grabbed or healed.
- All Creets speed up over time.
- **GAME OVER** is displayed when no healthy Creet is left.

| Color | State |
|-------|-------|
| green | healthy |
| red | sick |
| brown | berserk |
| black | mean |

A blue halo shows the Creet being dragged, a red flash shows an infection and a
green flash shows a healing.

## Project structure

```
.
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── h42n42.conf.in       Ocsigen server configuration template
├── src/
│   ├── rules.ml         game rules and constants (no browser code)
│   ├── creet.eliom      a Creet: state, display, disease
│   ├── game.eliom       Lwt threads, drag and drop, births, game over
│   └── h42n42.eliom     the service and the HTML page
├── static/css/          style sheet
└── tests/
    ├── test_rules.ml    unit tests of the rules
    └── smoke.sh         checks a running server
```

## Makefile

| Rule | Effect |
|------|--------|
| `make` / `make all` | compile the server module, the client program and the configuration |
| `make run` | build then start `ocsigenserver` on port 8080 |
| `make test` | build and run the unit tests |
| `make clean` | remove the compiled objects |
| `make fclean` | also remove the JavaScript, the configuration and the server data |
| `make re` | `fclean` then `all` |

Only the files whose sources changed are compiled again.

Inside the container:

```sh
docker exec h42n42 opam exec -- make test
```

With the application running:

```sh
./tests/smoke.sh
```

## Versions

OCaml 5.2, Eliom 11.1.1, Js_of_ocaml 5.9, Ocsigen Server 6.0.

## Bonus

No bonus part is implemented.
