(*
   Copyright 2009, 2010, 2011, 2012 Anton Lavrik

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

(*
 * Piq AST (abstract syntax tree)
 *)


module rec Piq_ast :
             sig
type ast =
 [
   | `int of int64
   | `uint of int64
   | `float of float
   | `bool of bool
   | `word of string
   | `ascii_string of string
   | `utf8_string of string
   | `binary of string
   | `text of string
   | `name of string
   | `named of Named.t (* TODO: string * ast *)
   | `typename of string
   | `typed of Typed.t (* TODO: string * ast *)
   | `list of ast list
   | `control of ast list

   (* These two token types are used only in several special cases, and can't be
    * represented in Piq text format directly *)

   (* Raw word -- a valid utf8 Piq word: may be parsed as either of these: word,
    * bool, number, string, binary *)
   | `raw_word of string

   (* Raw binary -- just a sequence of bytes: may be parsed as either binary or
    * utf8 string *)
   | `raw_binary of string

   (* reference to Piqobj.any object in Piqi_objstore *)
   | `any of int
 ]

    end = Piq_ast
and
  Typed :
    sig
      type t =
        { mutable typename : string; mutable value : Piq_ast.ast
        }
      
    end = Typed

and
  Named :
    sig
      type t =
        { mutable name : string; mutable value : Piq_ast.ast
        }
      
    end = Named


include Piq_ast


(* these functions are not going to be used; this are just stubs for
 * autogenerated Piqi-OCaml type mapping *)
let ast_of_bool x = `bool x
let ast_to_bool _ = true


(* apply function f to the node identified by its path in the tree *)
let transform_ast path f (ast:ast) =
  let rec aux p = function
    | `list l when p = [] -> (* leaf node *)
        (* f replaces, removes element, or splices elements of the list *)
        let res = Piqi_util.flatmap f l in
        `list res
    | x when p = [] -> (* leaf node *)
        (* expecting f to replace the existing value, no other modifications
         * such as removal or splicing is allowed in this context *)
        (match f x with [res] -> res | _ -> assert false)
    | `list l ->
        (* haven't reached the leaf node => continue tree traversal *)
        let res = List.map (aux p) l in
        `list res
    | `named {Named.name = n; value = v} when List.hd p = n ->
        (* found path element => continue tree traversal *)
        let res = {Named.name = n; value = aux (List.tl p) v} in
        `named res
    | x -> x
  in
  aux path ast


let map_words (ast:ast) f :ast =
  let rec aux = function
    | `word s -> `word (f s)
    | `raw_word s -> `raw_word (f s)
    | `name s -> `name (f s)
    | `named {Named.name = n; Named.value = v} ->
        `named {Named.name = f n; Named.value = aux v}
    (* XXX: apply function to the last segment of the type names? *)
    | `typename s -> `typename s
    | `typed ({Typed.value = ast} as x) ->
        let ast = aux ast in
       `typed {x with Typed.value = ast}
    | `list l -> `list (List.map aux l)
    | `control l -> `control (List.map aux l)
    | x -> x
  in
  aux ast

