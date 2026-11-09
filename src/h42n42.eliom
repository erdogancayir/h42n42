(* Server side: the only page of the application.
   The game itself runs in the browser (see game.eliom). *)

module H42n42_app = Eliom_registration.App (struct
  let application_name = "h42n42"
  let global_data_path = None
end)

let main_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit) ()

let color_legend =
  let open Eliom_content.Html.D in
  let item kind label =
    li [ span ~a:[ a_class [ "dot"; kind ] ] []; txt label ]
  in
  ul
    ~a:[ a_class [ "legend" ] ]
    [
      item "healthy" "Healthy";
      item "sick" "Sick";
      item "berserk" "Berserk";
      item "mean" "Mean";
    ]

let page () =
  let open Eliom_content.Html.D in
  let board =
    div
      ~a:[ a_class [ "board" ] ]
      [
        div ~a:[ a_class [ "river" ] ] [ txt "Toxic river" ];
        div ~a:[ a_class [ "hospital" ] ] [ txt "Hospital" ];
      ]
  in
  let message =
    div
      ~a:[ a_class [ "game-over" ] ]
      [ p [ txt "GAME OVER" ]; p ~a:[ a_class [ "hint" ] ] [ txt "Reload the page to play again" ] ]
  in
  let _ =
    [%client
      (Eliom_client.onload (fun () ->
           Game.start
             (Eliom_content.Html.To_dom.of_element ~%board)
             (Eliom_content.Html.To_dom.of_element ~%message))
        : unit)]
  in
  html
    (head
       (title (txt "h42n42"))
       [
         css_link
           ~uri:
             (make_uri ~service:(Eliom_service.static_dir ()) [ "css"; "h42n42.css" ])
           ();
       ])
    (body
       [
         h1 [ txt "h42n42" ];
         p
           ~a:[ a_class [ "help" ] ]
           [
             txt
               "Keep the creets away from the river. Drag sick creets to the \
                hospital to heal them.";
           ];
         color_legend;
         div ~a:[ a_class [ "game" ] ] [ board; message ];
       ])

let () =
  H42n42_app.register ~service:main_service (fun () () -> Lwt.return (page ()))
