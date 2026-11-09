(* The simulation: one Lwt thread per creet, the spawner,
   drag and drop, and the game over detection *)

[%%client
open Js_of_ocaml
open Js_of_ocaml_lwt
open Rules

type state = {
  board : Dom_html.element Js.t;
  message : Dom_html.element Js.t;
  start : float;
  mutable creets : Creet.t list;
  mutable over : bool;
}

let healthy_count st =
  List.length (List.filter (fun (c : Creet.t) -> c.kind = Healthy) st.creets)

let remove st (c : Creet.t) =
  c.alive <- false;
  st.creets <- List.filter (fun o -> o != c) st.creets;
  Dom.removeChild st.board c.elt

(* A healthy creet that is not being dragged can be contaminated
   by the river, or with a small chance by each sick creet it touches *)
let check_contamination st (c : Creet.t) =
  if c.kind = Healthy then begin
    let r = Creet.radius c in
    let touched_by_sick (o : Creet.t) =
      o != c && o.alive && is_sick o.kind
      && touching (c.x, c.y, r) (o.x, o.y, Creet.radius o)
    in
    if touches_river ~x:c.x ~y:c.y ~r then Creet.infect c
    else if
      List.exists
        (fun o -> touched_by_sick o && catches_virus (Random.float 1.))
        st.creets
    then Creet.infect c
  end

(* Mean creets head for the nearest healthy creet *)
let chase st (c : Creet.t) =
  let targets =
    List.filter
      (fun (o : Creet.t) -> o.kind = Healthy && not o.dragged)
      st.creets
  in
  match nearest ~position:(fun (o : Creet.t) -> (o.x, o.y)) (c.x, c.y) targets with
  | None -> ()
  | Some o -> (
      match direction_towards ~from:(c.x, c.y) ~target:(o.x, o.y) with
      | Some d -> c.dir <- d
      | None -> ())

let move st (c : Creet.t) t =
  let dt = Float.min (t -. c.last_move) 0.1 in
  c.last_move <- t;
  if t >= c.next_turn then begin
    c.dir <- Creet.random_direction ();
    c.next_turn <- t +. Creet.random_between min_turn_delay max_turn_delay
  end;
  if c.kind = Mean then chase st c;
  let v = speed ~kind:c.kind ~elapsed:(t -. st.start) in
  let dx, dy = c.dir in
  c.x <- c.x +. (dx *. v *. dt);
  c.y <- c.y +. (dy *. v *. dt);
  Creet.fit_in_board c;
  c.dir <- bounce ~x:c.x ~y:c.y ~r:(Creet.radius c) c.dir

(* The Lwt thread that drives one creet until it dies or the game ends *)
let rec life st (c : Creet.t) =
  if st.over || not c.alive then Lwt.return_unit
  else begin
    let t = Creet.now () in
    if c.dragged then c.last_move <- t
    else begin
      move st c t;
      check_contamination st c;
      if not (Creet.update_disease c t) then remove st c
    end;
    if c.alive then Creet.draw c;
    let%lwt () = Lwt_js.sleep tick in
    life st c
  end

(* Mouse position converted to board coordinates.
   A creet can be dropped outside the board (bounce brings it back),
   but it stays visible in the window, even if the mouse leaves it *)
let place st (c : Creet.t) (ev : Dom_html.mouseEvent Js.t) =
  let rect = st.board##getBoundingClientRect in
  let x = float_of_int ev##.clientX -. rect##.left in
  let y = float_of_int ev##.clientY -. rect##.top in
  let root = Dom_html.document##.documentElement in
  let view =
    ( -.rect##.left,
      -.rect##.top,
      float_of_int root##.clientWidth -. rect##.left,
      float_of_int root##.clientHeight -. rect##.top )
  in
  let x, y = keep_on_screen ~view ~x ~y ~r:(Creet.radius c) in
  c.x <- x;
  c.y <- y;
  Creet.draw c

let drop (c : Creet.t) =
  Creet.set_dragged c false;
  if c.kind = Sick && in_hospital ~x:c.x ~y:c.y then Creet.heal c

let handle_drag st (c : Creet.t) =
  Lwt_js_events.mousedowns c.elt (fun ev _ ->
      if st.over || (not c.alive) || not (can_be_grabbed c.kind) then
        Lwt.return_unit
      else begin
        Dom.preventDefault ev;
        Creet.set_dragged c true;
        place st c ev;
        let%lwt () =
          Lwt.pick
            [
              Lwt_js_events.mousemoves Dom_html.document (fun ev _ ->
                  place st c ev;
                  Lwt.return_unit);
              (let%lwt _ = Lwt_js_events.mouseup Dom_html.document in
               Lwt.return_unit);
            ]
        in
        drop c;
        Lwt.return_unit
      end)

let spawn st =
  let r = base_diameter /. 2. in
  let x = Creet.random_between r (board_width -. r) in
  let y =
    Creet.random_between (river_height +. r +. 1.)
      (board_height -. hospital_height -. r)
  in
  let c = Creet.create x y in
  st.creets <- c :: st.creets;
  Dom.appendChild st.board c.elt;
  Lwt.async (fun () -> handle_drag st c);
  Lwt.async (fun () -> life st c)

(* A new creet is born every few seconds while a healthy one is alive *)
let rec spawner st =
  let%lwt () = Lwt_js.sleep spawn_period in
  if st.over then Lwt.return_unit
  else begin
    if healthy_count st > 0 then spawn st;
    spawner st
  end

let rec watch_game_over st =
  if game_over ~healthy:(healthy_count st) then begin
    st.over <- true;
    st.message##.classList##add (Js.string "visible");
    Lwt.return_unit
  end
  else
    let%lwt () = Lwt_js.sleep tick in
    watch_game_over st

let start board message =
  Random.self_init ();
  let st = { board; message; start = Creet.now (); creets = []; over = false } in
  for _ = 1 to initial_count do
    spawn st
  done;
  Lwt.async (fun () -> spawner st);
  Lwt.async (fun () -> watch_game_over st)
]
