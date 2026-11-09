(* Game rules that do not depend on the browser.
   They are shared by the client code and by the unit tests. *)

type kind = Healthy | Sick | Berserk | Mean

(* Board layout, in pixels.
   Must match the sizes in static/css/h42n42.css *)
let board_width = 800. (* bounce, push_inside, touches_river, in_hospital, Game.spawn *)
let board_height = 600. (* bounce, push_inside, in_hospital, Game.spawn *)
let river_height = 60. (* touches_river; Game.spawn never spawns in it *)
let hospital_height = 80. (* in_hospital; Game.spawn never spawns in it *)

(* Creets *)
let initial_count = 8 (* Game.start: creets on the board at the beginning *)
let base_diameter = 30. (* Creet.create, Game.spawn; reference size for mean and berserk *)
let base_speed = 50. (* pixels per second, used by speed *)
let sick_speed_factor = 0.85 (* speed_factor: sick, berserk and mean are 15% slower *)
let mean_size_factor = 0.85 (* Creet.evolve: a mean creet is 15% smaller *)

(* Timings, in seconds *)
let tick = 0.02 (* Game.life, Game.watch_game_over: sleep between two iterations *)
let spawn_period = 5. (* Game.spawner: a new creet is born every 5 s *)
let evolve_period = 10. (* Creet: sick evolution roll, and berserk growth *)
let min_turn_delay = 2. (* Creet.create, Game.move: random change of direction *)
let max_turn_delay = 5. (* happens between min_turn_delay and max_turn_delay *)
let mean_lifetime = 60. (* mean_is_dead: a mean creet dies after 1 minute *)

(* Probabilities, compared with a random roll in [0, 1) *)
let infection_chance = 0.02 (* catches_virus: per iteration of contact *)
let berserk_chance = 0.10 (* evolve: sick -> berserk *)
let mean_chance = 0.10 (* evolve: sick -> mean *)

(* Berserk creets *)
let berserk_growth = 1.10 (* grow_berserk: +10% diameter every evolve_period *)
let berserk_max_factor = 4. (* berserk_is_dead: dies at 4x base_diameter *)

let class_of_kind = function
  | Healthy -> "healthy"
  | Sick -> "sick"
  | Berserk -> "berserk"
  | Mean -> "mean"

let is_sick kind = kind <> Healthy

(* Only healthy and plain sick creets can be grabbed by the player *)
let can_be_grabbed kind = kind = Healthy || kind = Sick

let speed_factor kind = if kind = Healthy then 1. else sick_speed_factor

(* Global speed multiplier, grows linearly with the elapsed time (seconds).
   Used by speed, so all creets speed up over time:

     elapsed | multiplier | healthy speed
     --------+------------+--------------
       0 s   |    x1.0    |   50 px/s
      30 s   |    x1.3    |   65 px/s
     100 s   |    x2.0    |  100 px/s
     200 s   |    x3.0    |  150 px/s *)
let difficulty elapsed = 1. +. (elapsed /. 100.)

let speed ~kind ~elapsed = base_speed *. speed_factor kind *. difficulty elapsed

(* Two circles touch when the distance between their centers
   is not greater than the sum of their radii *)
let touching (x1, y1, r1) (x2, y2, r2) =
  let dx = x1 -. x2 and dy = y1 -. y2 in
  let reach = r1 +. r2 in
  (dx *. dx) +. (dy *. dy) <= reach *. reach

(* [roll] is a random number in [0, 1) *)
let catches_virus roll = roll < infection_chance

(* The river is the rectangle [0, board_width] x [0, river_height].
   A circle touches it when the point of the rectangle closest to its
   center is within its radius, so a creet outside the board does not
   touch the river just because it is at the same height *)
let touches_river ~x ~y ~r =
  let clamp low high v = Float.max low (Float.min high v) in
  let dx = x -. clamp 0. board_width x in
  let dy = y -. clamp 0. river_height y in
  (dx *. dx) +. (dy *. dy) <= r *. r

(* A creet is dropped in the hospital when its center is inside it *)
let in_hospital ~x ~y =
  x >= 0. && x <= board_width
  && y >= board_height -. hospital_height
  && y <= board_height

(* Reflection on the four walls: the velocity component normal to the wall
   is reversed, so the angle of reflection equals the angle of incidence.
   Using abs makes a creet dropped outside the board come back inside. *)
let bounce ~x ~y ~r (dx, dy) =
  let dx =
    if x -. r <= 0. then Float.abs dx
    else if x +. r >= board_width then -.Float.abs dx
    else dx
  in
  let dy =
    if y -. r <= 0. then Float.abs dy
    else if y +. r >= board_height then -.Float.abs dy
    else dy
  in
  (dx, dy)

(* bounce only changes the direction: a creet moving almost along a wall, or a
   berserk growing next to one, would stick out of the board. This puts it back
   against the wall on each axis where its center is on the board. A creet
   dropped outside keeps its position and comes back with bounce. *)
let push_inside ~x ~y ~r =
  let fit size v = if v < 0. || v > size then v else Float.max r (Float.min (size -. r) v) in
  (fit board_width x, fit board_height y)

(* Keeps a dragged creet fully visible in the window.
   [view] is the visible area (left, top, right, bottom) in board coordinates *)
let keep_on_screen ~view:(left, top, right, bottom) ~x ~y ~r =
  let clamp low high v = Float.max low (Float.min high v) in
  (clamp (left +. r) (right -. r) x, clamp (top +. r) (bottom -. r) y)

let direction_of_angle a = (cos a, sin a)

(* Unit vector from [from] to [target], None if they are at the same place.
   Used by Game.chase *)
let direction_towards ~from:(x1, y1) ~target:(x2, y2) =
  let dx = x2 -. x1 and dy = y2 -. y1 in
  let len = sqrt ((dx *. dx) +. (dy *. dy)) in
  if len = 0. then None else Some (dx /. len, dy /. len)

(* Nearest element of [targets], [position] gives the center of an element.
   None if [targets] is empty. Used by Game.chase *)
let nearest ~position (x, y) targets =
  let distance t =
    let tx, ty = position t in
    ((tx -. x) *. (tx -. x)) +. ((ty -. y) *. (ty -. y))
  in
  List.fold_left
    (fun best t ->
      match best with
      | Some b when distance b <= distance t -> best
      | _ -> Some t)
    None targets

(* One random roll in [0, 1) decides the evolution of a sick creet,
   so a creet can never become both berserk and mean *)
let evolve roll =
  if roll < berserk_chance then Berserk
  else if roll < berserk_chance +. mean_chance then Mean
  else Sick

let grow_berserk diameter = diameter *. berserk_growth

let berserk_is_dead ~original diameter =
  diameter >= (original *. berserk_max_factor) -. 1e-9

let mean_is_dead ~since ~now = now -. since >= mean_lifetime

let game_over ~healthy = healthy = 0
