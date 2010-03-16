(*pp camlp4orf `ocamlfind query -i-format type-conv dyntype.syntax shelf.syntax` pa_type_conv.cmo pa_dyntype.cma pa_shelf.cmo *)

open Appengine

type x = {
  foo: string;
  bar: int;
  barl: int64 list;
  baru: unit list;
  assoc: (string * string) list;
} with value,type_of,json


let to_jlong i = (new lang_long (`Long i) :> CadmiumObj.jObject)
let to_jbool b = (new lang_bool (`Bool b) :> CadmiumObj.jObject)
let to_jfloat v = (new lang_float (`Float v) :> CadmiumObj.jObject)
let to_jstring s = (new lang_string (`String s) :> CadmiumObj.jObject)
let to_jlist fn l = 
    let v = new lang_vector (`Int (Int32.of_int (List.length l))) in
    List.iter (fun e -> v#addElement (fn e)) l;
    (v :> CadmiumObj.jObject)

let to_entity x =
  match type_of_x, (value_of_x x) with
  | (Type.Ext (n, Type.Dict ts)), (Value.Ext (_, Value.Dict vs)) ->
      let ent = new entity (`String n) in
      List.iter (fun (f, v) ->
          match v with
          | Value.Unit -> ent#setProperty f (to_jlong 0L)
          | Value.Int i -> ent#setProperty f (to_jlong i)
          | Value.Bool b -> ent#setProperty f (to_jbool b)
          | Value.Float v -> ent#setProperty f (to_jfloat v)
          | Value.String s -> ent#setProperty f (to_jstring s)
          | Value.Tuple vl
          | Value.Enum vl ->
              let l = to_jlist (function 
                | Value.Int i -> to_jlong i 
                | Value.Bool b -> to_jbool b
                | Value.Float v -> to_jfloat v
                | Value.String s -> to_jstring s
                | Value.Unit -> to_jlong 0L
                | x -> to_jstring (Json.to_string x)
              ) vl in
              ent#setProperty f l
      ) vs;
      ent
  | _ -> failwith "eek"

let save () =
  let dsf = new datastore_service_factory `Null in
  let ds = dsf#getDatastoreService in
  let x1 = {foo="hello world"; bar=123; barl=[ 10L;11L;12L ]; baru=[();()]; assoc=[ "k1","v1"; "k2","v2"] } in
  let ent = to_entity x1 in
  let _ = ds#put2 ent in
  ent#toString
