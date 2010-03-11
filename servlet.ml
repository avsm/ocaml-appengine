open CadmiumServlet

let handle_get srv req resp = 
  let out = Response.get_output_stream resp in 
  match Request.get_path_info req with 
  | "/Service1" -> output_string out "service1"
  | "/Service2" -> output_string out "service2"
  | url ->
      output_string out "<html><head><title>Hello OCaml World!</title></head><body>"; 
      output_string out (Printf.sprintf "<b>Looks like you asked for: %s</b>" url); 
      output_string out "</body></html>"

let () = Servlet.register {
  Servlet.destroy = ignore; 
  Servlet.init = ignore; 
  Servlet.info = "my first servlet"; 
  Servlet.do_delete = None; 
  Servlet.do_get = Some handle_get; 
  Servlet.do_head = None; 
  Servlet.do_options = None; 
  Servlet.do_post = None; 
  Servlet.do_put = None; 
  Servlet.do_trace = None; 
  Servlet.get_last_modified = None; 
}
