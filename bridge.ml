(*pp camlp4orf `ocamlfind query -i-format type-conv dyntype.syntax shelf.syntax orm.syntax` pa_type_conv.cmo pa_dyntype.cma pa_shelf.cmo pa_orm.cma *)

open Orm.Appengine_datastore

type en = 
  | Foo
  | Bar of int
  | Fu of (string * string)
and x = {
  foo: string;
  bar: int;
  barl: int64 list;
  baru: unit list;
  assoc: (string * string) list;
  esl: en list;
  es: en;
} with value,type_of,json,orm(mode:appengine)


let save () =
  let x1 = {foo="hello world"; bar=(Random.int 1000); barl=[ 10L;11L;12L ]; 
    baru=[();()]; assoc=[ "k1","v1"; "k2","v2"]; es=Fu ("one","two"); esl=[Foo; Bar 1; Fu ("one1","two2")] } in
  let db = x_init "foo" in
  x_save db x1;
  "ok"

let get () =
  let db = x_init "foo" in
  let xs = x_get db in
  String.concat ", " (List.map json_of_x xs)
