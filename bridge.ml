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
  let x1 = {foo="hello world"; bar=(Random.int 1000); barl=[ 10L;11L;12L ]; 
    baru=[();()]; assoc=[ "k1","v1"; "k2","v2"] } in
  let ent = to_entity x1 in
  let _ = ds#put ent in
  ent#toString

let foldIter fn i o =
  let r = ref i in
  while o#hasNext do
     r := fn !r o#next
  done;
  !r

let foldIter2 fn i o l =
  let r = ref i in
  List.iter (fun l' -> 
    if o#hasNext then
      r := fn !r o#next l'
    else
      Printf.printf "foldIter2 fail\n%!"
  ) l;
  !r

let rec to_value prop ty =
  let cl = prop#getClass#getName in
  match ty, cl with
    | Type.Unit, _ -> Value.Unit
    | Type.Int _, _ -> Value.Int (of_jlong prop)
    | Type.Bool, _ -> Value.Bool (of_jbool prop)
    | Type.Char, _ | Type.String, _ -> Value.String (of_jstring prop)
    | Type.Enum ty', "java.util.ArrayList" ->
        let l = new util_arraylist (`Cd'initObj prop) in
        Value.Enum (foldIter (fun a v -> to_value v ty' :: a) [] l#iterator)
    | Type.Tuple tyl, "java.util.ArrayList" ->
        let l = new util_arraylist (`Cd'initObj prop) in
        Value.Tuple (foldIter2 (fun a v ty' -> (to_value v ty') :: a) [] l#iterator tyl)
    | _, "java.lang.String" -> Json.of_string (of_jstring prop)
    | ty,cl ->
        Printf.printf "Unknown ty/cl: %s %s, returning null\n%!" (Type.to_string ty) cl; Value.Unit
 
let entity_to_value ty (ent:entity) =
  let ty_fields = match ty with
   | Type.Ext (_, Type.Dict ts) -> List.map (fun (k,_,v) -> (k,v)) ts
   | _ -> failwith "only works with Dicts at the mo" in
  let ps = foldIter (fun a o ->
      let key = (new lang_string (`Cd'initObj o))#toString in
      let prop = ent#getProperty key in
      let v = to_value prop (List.assoc key ty_fields) in
      (key,v) :: a
    ) [] ent#getProperties#keySet#iterator in
  Value.Dict ps
   
let get () =
  let dsf = new datastore_service_factory `Null in
  let ds = dsf#getDatastoreService in
  let q = new query (`String "x") in
  let pq = ds#prepare q in
  let iter = pq#asIterator in
  let r = foldIter (fun a o ->
    let ent = new entity (`Cd'initObj o) in
    let props_map = ent#getProperties in
    let keys = props_map#keySet#iterator in
    let keys_string = foldIter (fun a o ->
      let k = (new lang_string (`Cd'initObj o))#toString in
      let v = ent#getProperty k in
      let v' = entity_to_value type_of_x ent in
      let kv = Printf.sprintf "%s=%s (%s) (json=%s)\n" k (v#toString) (v#getClass#getName) (Json.to_string v') in
      kv :: a
    ) [] keys in
    String.concat "," keys_string :: a
  ) [] iter in
  String.concat " ; " r

