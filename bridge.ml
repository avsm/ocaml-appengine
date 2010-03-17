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

let of_jlong (j:CadmiumObj.jObject) = (new lang_long (`Cd'initObj j))#longValue
let of_jbool (j:CadmiumObj.jObject) = (new lang_bool (`Cd'initObj j))#booleanValue
let of_jfloat (j:CadmiumObj.jObject) = (new lang_float (`Cd'initObj j))#floatValue
let of_jstring (j:CadmiumObj.jObject) = (new lang_string (`Cd'initObj j))#toString

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
  let x1 = {foo="hello world"; bar=(Random.int 1000); barl=[ 10L;11L;12L ]; baru=[();()]; assoc=[ "k1","v1"; "k2","v2"] } in
  let ent = to_entity x1 in
  let _ = ds#put2 ent in
  ent#toString

let foldIter fn i o =
  let r = ref i in
  while o#hasNext do
     r := fn !r o#next
  done;
  !r

let to_value (ent:entity) =
  let ps = foldIter (fun a o ->
      let key = (new lang_string (`Cd'initObj o))#toString in
      let prop = ent#getProperty key in
      let v = match prop#getClass#getName with 
        | "java.lang.String" -> Value.String (of_jstring prop)
        | "java.lang.Long" -> Value.Int (of_jlong prop)
        | "java.util.ArrayList" -> 
            let l = new util_arraylist (`Cd'initObj prop) in
            Value.Enum (foldIter (fun a v ->
              let r = match v#getClass#getName with
              | "java.lang.String" -> Value.String (of_jstring v)
              | "java.lang.Long" -> Value.Int (of_jlong v)
              | "java.lang.Boolean" -> Value.Bool (of_jbool v)
              | unknown -> (print_endline unknown; raise Not_found)
              in r :: a
              ) [] l#iterator)
        | unknown -> (print_endline ("unknown class: " ^ unknown); raise Not_found) in
      (key,v) :: a
    ) [] ent#getProperties#keySet#iterator in
  Value.Dict ps
   
let get () =
  let dsf = new datastore_service_factory `Null in
  let entity_class = new CadmiumObj.jClass (`For_name "com.google.appengine.api.datastore.Entity") in
  let ds = dsf#getDatastoreService in
  let q = new query (`String "x") in
  let pq = ds#prepare2 q in
  let iter = pq#asIterator2 in
  let r = foldIter (fun a o ->
    let ent = new entity (`Cd'initObj o) in
    let props_map = ent#getProperties in
    let keys = props_map#keySet#iterator in
    let keys_string = foldIter (fun a o ->
      let k = (new lang_string (`Cd'initObj o))#toString in
      let v = ent#getProperty k in
      let v' = to_value ent in
      let kv = Printf.sprintf "%s=%s (%s) (json=%s)\n" k (v#toString) (v#getClass#getName) (Json.to_string v') in
      kv :: a
    ) [] keys in
    String.concat "," keys_string :: a
  ) [] iter in
  String.concat " ; " r

