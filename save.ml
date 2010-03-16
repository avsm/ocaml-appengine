(*pp camlp4orf `ocamlfind query -i-format type-conv dyntype.syntax` pa_type_conv.cmo pa_dyntype.cma *)

open Appengine

type x = {
  foo: string;
  bar: int;
} with value,type_of


let to_entity x =
  match type_of_x, (value_of_x x) with
  | (Type.Ext (n, Type.Dict ts)), (Value.Ext (_, Value.Dict vs)) ->
      let ent = new entity (`String n) in
      List.iter (fun (f, v) ->
          match v with
          | Value.Int i -> ent#setProperty f (new lang_long (`Long i) :> CadmiumObj.jObject)
          | Value.String s -> ent#setProperty f (new lang_string (`String s) :> CadmiumObj.jObject)
      ) vs;
      ent
  | _ -> failwith "eek"

let save () =
  let dsf = new datastore_service_factory `Null in
  let ds = dsf#getDatastoreService in
  let x1 = {foo="hello world"; bar=123 } in
  let ent = to_entity x1 in
  let _ = ds#put2 ent in
  ent#toString
