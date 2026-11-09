open Rules

let failures = ref 0
let count = ref 0

let check name cond =
  incr count;
  if not cond then begin
    incr failures;
    Printf.printf "FAIL: %s\n" name
  end

let close a b = Float.abs (a -. b) < 1e-6

let test_contact () =
  check "same center touches" (touching (10., 10., 5.) (10., 10., 5.));
  check "exactly r1 + r2 touches" (touching (0., 0., 15.) (30., 0., 15.));
  check "just over r1 + r2 does not touch"
    (not (touching (0., 0., 15.) (30.01, 0., 15.)));
  check "diagonal distance uses euclidean norm"
    (not (touching (0., 0., 15.) (22., 22., 15.)));
  check "different radii" (touching (0., 0., 60.) (70., 0., 10.))

let test_river () =
  let x = 400. in
  check "top edge inside river" (touches_river ~x ~y:(river_height +. 15.) ~r:15.);
  check "below river" (not (touches_river ~x ~y:(river_height +. 15.1) ~r:15.));
  check "center in river" (touches_river ~x ~y:10. ~r:15.);
  check "outside the board at river height does not touch"
    (not (touches_river ~x:(-40.) ~y:30. ~r:15.));
  check "right of the board at river height does not touch"
    (not (touches_river ~x:(board_width +. 40.) ~y:30. ~r:15.));
  check "overlapping the river from the side touches"
    (touches_river ~x:(-10.) ~y:30. ~r:15.);
  check "above the board does not touch" (not (touches_river ~x ~y:(-40.) ~r:15.));
  check "corner uses the real distance"
    (not (touches_river ~x:(-12.) ~y:(river_height +. 12.) ~r:15.))

let test_push_inside () =
  let r = 15. in
  check "inside is kept" (push_inside ~x:300. ~y:200. ~r = (300., 200.));
  check "sticking out on the left is pushed back"
    (push_inside ~x:5. ~y:200. ~r = (r, 200.));
  check "sticking out at the bottom is pushed back"
    (push_inside ~x:300. ~y:(board_height -. 2.) ~r = (300., board_height -. r));
  check "a grown berserk at the wall is pushed back"
    (push_inside ~x:(board_width -. 15.) ~y:300. ~r:20.
    = (board_width -. 20., 300.));
  check "center outside the board is not moved"
    (push_inside ~x:(-50.) ~y:(board_height +. 30.) ~r = (-50., board_height +. 30.))

let test_keep_on_screen () =
  let view = (-100., -50., 1100., 750.) and r = 15. in
  check "visible position is kept" (keep_on_screen ~view ~x:900. ~y:(-20.) ~r = (900., -20.));
  check "left of the window is clamped"
    (keep_on_screen ~view ~x:(-500.) ~y:300. ~r = (-100. +. r, 300.));
  check "below the window is clamped"
    (keep_on_screen ~view ~x:300. ~y:2000. ~r = (300., 750. -. r))

let test_hospital () =
  let y = board_height -. (hospital_height /. 2.) in
  check "center in hospital" (in_hospital ~x:400. ~y);
  check "above hospital"
    (not (in_hospital ~x:400. ~y:(board_height -. hospital_height -. 1.)));
  check "outside board on the left" (not (in_hospital ~x:(-10.) ~y));
  check "below the board" (not (in_hospital ~x:400. ~y:(board_height +. 5.)))

let test_bounce () =
  let r = 15. in
  let mid = 300. in
  check "no wall, no change" (bounce ~x:mid ~y:mid ~r (0.6, 0.8) = (0.6, 0.8));
  check "left wall reverses dx only"
    (bounce ~x:r ~y:mid ~r (-0.6, 0.8) = (0.6, 0.8));
  check "right wall reverses dx only"
    (bounce ~x:(board_width -. r) ~y:mid ~r (0.6, -0.8) = (-0.6, -0.8));
  check "top wall reverses dy only"
    (bounce ~x:mid ~y:r ~r (0.6, -0.8) = (0.6, 0.8));
  check "bottom wall reverses dy only"
    (bounce ~x:mid ~y:(board_height -. r) ~r (-0.6, 0.8) = (-0.6, -0.8));
  check "corner reverses both" (bounce ~x:r ~y:r ~r (-0.6, -0.8) = (0.6, 0.8));
  check "already going away from wall is kept"
    (bounce ~x:r ~y:mid ~r (0.6, 0.8) = (0.6, 0.8));
  check "dropped far outside comes back"
    (bounce ~x:(-200.) ~y:(board_height +. 200.) ~r (-0.6, 0.8) = (0.6, -0.8));
  let dx, dy = bounce ~x:r ~y:mid ~r (-0.6, 0.8) in
  check "speed is preserved by a bounce" (close ((dx *. dx) +. (dy *. dy)) 1.)

let test_speed () =
  check "healthy at start" (close (speed ~kind:Healthy ~elapsed:0.) base_speed);
  check "sick is 15% slower"
    (close (speed ~kind:Sick ~elapsed:0.) (base_speed *. 0.85));
  check "berserk is sick speed"
    (close (speed ~kind:Berserk ~elapsed:0.) (base_speed *. 0.85));
  check "mean is sick speed"
    (close (speed ~kind:Mean ~elapsed:0.) (base_speed *. 0.85));
  check "speed increases with time"
    (speed ~kind:Healthy ~elapsed:60. > speed ~kind:Healthy ~elapsed:0.);
  check "acceleration never stops"
    (difficulty 600. > difficulty 300.)

let test_grab () =
  check "healthy can be grabbed" (can_be_grabbed Healthy);
  check "sick can be grabbed" (can_be_grabbed Sick);
  check "berserk cannot be grabbed" (not (can_be_grabbed Berserk));
  check "mean cannot be grabbed" (not (can_be_grabbed Mean))

let test_evolve () =
  check "low roll gives berserk" (evolve 0. = Berserk);
  check "roll 0.0999 gives berserk" (evolve 0.0999 = Berserk);
  check "roll 0.1 gives mean" (evolve 0.1 = Mean);
  check "roll 0.1999 gives mean" (evolve 0.1999 = Mean);
  check "roll 0.2 stays sick" (evolve 0.2 = Sick);
  check "high roll stays sick" (evolve 0.99 = Sick);
  Random.init 42;
  let n = 100_000 in
  let b = ref 0 and m = ref 0 in
  for _ = 1 to n do
    match evolve (Random.float 1.) with
    | Berserk -> incr b
    | Mean -> incr m
    | _ -> ()
  done;
  let ratio x = float_of_int !x /. float_of_int n in
  check "about 10% berserk" (Float.abs (ratio b -. 0.10) < 0.01);
  check "about 10% mean" (Float.abs (ratio m -. 0.10) < 0.01)

let test_berserk () =
  let original = base_diameter in
  let rec steps d n =
    if berserk_is_dead ~original d then n else steps (grow_berserk d) (n + 1)
  in
  let n = steps original 0 in
  check "one growth is +10%" (close (grow_berserk 30.) 33.);
  check "dies after 15 growths" (n = 15);
  check "about 2 min 30 s"
    (close (float_of_int n *. evolve_period) 150.);
  check "alive at 3.9x" (not (berserk_is_dead ~original (original *. 3.9)));
  check "dead at 4x" (berserk_is_dead ~original (original *. 4.))

let test_mean () =
  check "mean alive at 59.9 s" (not (mean_is_dead ~since:10. ~now:69.9));
  check "mean dead at 60 s" (mean_is_dead ~since:10. ~now:70.);
  check "mean is 15% smaller" (close (base_diameter *. mean_size_factor) 25.5);
  let pos (x, y) = (x, y) in
  check "nearest picks closest"
    (nearest ~position:pos (0., 0.) [ (100., 0.); (3., 4.); (50., 50.) ]
    = Some (3., 4.));
  check "nearest of empty list" (nearest ~position:pos (0., 0.) [] = None);
  (match direction_towards ~from:(0., 0.) ~target:(3., 4.) with
  | Some (dx, dy) -> check "direction is normalized" (close dx 0.6 && close dy 0.8)
  | None -> check "direction exists" false);
  check "no direction to itself"
    (direction_towards ~from:(1., 1.) ~target:(1., 1.) = None)

let test_infection () =
  check "roll below 2% infects" (catches_virus 0.0199);
  check "roll of 2% does not infect" (not (catches_virus 0.02));
  Random.init 7;
  let n = 100_000 in
  let hits = ref 0 in
  for _ = 1 to n do
    if catches_virus (Random.float 1.) then incr hits
  done;
  check "about 2% per contact"
    (Float.abs ((float_of_int !hits /. float_of_int n) -. 0.02) < 0.003)

let test_game_over () =
  check "game over with no healthy creet" (game_over ~healthy:0);
  check "game goes on with one healthy creet" (not (game_over ~healthy:1))

let () =
  test_contact ();
  test_river ();
  test_push_inside ();
  test_keep_on_screen ();
  test_hospital ();
  test_bounce ();
  test_speed ();
  test_grab ();
  test_evolve ();
  test_berserk ();
  test_mean ();
  test_infection ();
  test_game_over ();
  Printf.printf "%d/%d tests passed\n" (!count - !failures) !count;
  if !failures > 0 then exit 1
