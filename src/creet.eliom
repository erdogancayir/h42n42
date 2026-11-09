(* A creet: its position, its state and the <div> that displays it *)

[%%client
open Js_of_ocaml
open Rules

type t = {
  elt : Dom_html.element Js.t;
  mutable x : float; (* center of the creet, relative to the board *)
  mutable y : float;
  mutable dir : float * float; (* unit vector *)
  mutable kind : kind;
  mutable diameter : float;
  mutable alive : bool;
  mutable dragged : bool;
  mutable last_move : float; (* time of the last movement *)
  mutable next_turn : float; (* time of the next random change of direction *)
  mutable next_check : float; (* next evolution roll, or next berserk growth *)
  mutable mean_since : float;
}

let now () = (new%js Js.date_now)##getTime /. 1000.

let random_between a b = a +. Random.float (b -. a)

let random_direction () = direction_of_angle (Random.float (2. *. Float.pi))

let radius c = c.diameter /. 2.

(* Never let a creet on the board stick out of it (see Rules.push_inside) *)
let fit_in_board c =
  let x, y = push_inside ~x:c.x ~y:c.y ~r:(radius c) in
  c.x <- x;
  c.y <- y

let px v =Js.string (Printf.sprintf "%.1fpx" v)

let draw c =
  let style = c.elt##.style in
  style##.left := px (c.x -. radius c);
  style##.top := px (c.y -. radius c);
  style##.width := px c.diameter;
  style##.height := px c.diameter

let add_class c name = c.elt##.classList##add (Js.string name)

let remove_class c name = c.elt##.classList##remove (Js.string name)

(* Short visual effect, removed after a moment *)
let flash c name =
  add_class c name;
  Lwt.async (fun () ->
      let%lwt () = Js_of_ocaml_lwt.Lwt_js.sleep 0.6 in
      remove_class c name;
      Lwt.return_unit)

let set_kind c kind =
  remove_class c (class_of_kind c.kind);
  c.kind <- kind;
  add_class c (class_of_kind kind)

let set_dragged c dragged =
  c.dragged <- dragged;
  if dragged then add_class c "dragged" else remove_class c "dragged"

let create x y =
  let div =
    Eliom_content.Html.D.(div ~a:[ a_class [ "creet"; class_of_kind Healthy ] ] [])
  in
  let t = now () in
  let c =
    {
      elt = Eliom_content.Html.To_dom.of_element div;
      x;
      y;
      dir = random_direction ();
      kind = Healthy;
      diameter = base_diameter;
      alive = true;
      dragged = false;
      last_move = t;
      next_turn = t +. random_between min_turn_delay max_turn_delay;
      next_check = 0.;
      mean_since = 0.;
    }
  in
  draw c;
  c

(* The river or another creet made this creet sick *)
let infect c =
  set_kind c Sick;
  c.next_check <- now ();
  flash c "infected"

(* Dropped in the hospital by the player *)
let heal c =
  set_kind c Healthy;
  flash c "healed"

(* Every 10 seconds a sick creet may turn berserk or mean *)
let evolve c t =
  match Rules.evolve (Random.float 1.) with
  | Berserk ->
      set_kind c Berserk;
      c.next_check <- t +. evolve_period
  | Mean ->
      set_kind c Mean;
      c.diameter <- base_diameter *. mean_size_factor;
      c.mean_since <- t
  | Sick | Healthy -> c.next_check <- t +. evolve_period

(* Returns false when the creet dies *)
let update_disease c t =
  match c.kind with
  | Healthy -> true
  | Sick ->
      if t >= c.next_check then evolve c t;
      true
  | Berserk ->
      if t >= c.next_check then begin
        c.diameter <- grow_berserk c.diameter;
        fit_in_board c;
        c.next_check <- c.next_check +. evolve_period
      end;
      not (berserk_is_dead ~original:base_diameter c.diameter)
  | Mean -> not (mean_is_dead ~since:c.mean_since ~now:t)
]
