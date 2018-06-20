(**

This file describes the syntax and semantics of a lambda calculus
with mutable heap. The language includes recursive functions, and a
couple of primitive functions. Records and arrays operations are
encoded using pointer arithmetics, and using the [alloc] operation
which allocates at once a requested number of consecutive memory cells.

Author: Arthur Charguéraud.
License: MIT.

*)

Set Implicit Arguments.
Require Import LibMonoid.
Require Export LibString LibList LibCore.
Require Export Fmap Bind TLCbuffer.
Open Scope string_scope.

Axiom fmap_get : forall A B, fmap A B -> A -> B.

(*Axiom fmap_fold : forall A B C, (monoid_op C) -> (A->B->C) -> fmap A B -> C. *)
Axiom fmap_fold : forall A B C, (monoid_op C) -> (A->B->C) -> fmap A B -> C.

Axiom fold_induction:
  forall A B C (m : monoid_op C) (f : A -> B -> C) (P : C -> Prop),
  Comm_monoid m ->
  P (monoid_neutral m) ->
  (forall x a b, P x -> P (monoid_oper m (f a b) x)) ->
  forall E,
  P (fmap_fold m f E).

Axiom fmap_indom : forall A B, fmap A B -> A -> Prop.


(* ********************************************************************** *)
(* * Source language syntax *)


(* ---------------------------------------------------------------------- *)
(** Representation of locations and fields *)

(** [loc] describes base pointers to an allocated block. *)

Definition loc := nat. 

Definition null : loc := 0%nat.

Definition field := var.

Definition size := nat.

Definition offset := nat.

Definition typvar := var.

Global Opaque field loc size offset typvar.


(* ---------------------------------------------------------------------- *)
(** Grammar of types *)

Inductive typ : Type :=
  | typ_unit : typ
  | typ_int : typ
  | typ_double : typ
  | typ_bool : typ
  | typ_ptr : typ -> typ
  | typ_array : typ -> size -> typ
  | typ_struct : typvar -> typ
  | typ_fun : list typ -> typ -> typ.

Definition typdef_struct : Type := fmap field typ.

Definition typdefctx := fmap typvar typdef_struct.


(* ---------------------------------------------------------------------- *)
(** Size of types *)

Definition typdefctx_size := fmap typvar size.

Definition typdefctx_offset := fmap typvar (fmap field offset).

Section TypeSizes.

Open Scope nat_scope.

Fixpoint sizeof (S:typdefctx_size) (T:typ) : nat := 
  match T with
  | typ_unit => 0%nat
  | typ_bool => 1%nat
  | typ_int => 1%nat
  | typ_double => 2%nat
  | typ_ptr _ => 1%nat
  | typ_array T' n => (n * (sizeof S T'))%nat
  | typ_struct X => fmap_get S X
  | typ_fun _ _ => 1%nat
  end.

Definition sizeof_typdef_struct (S:typdefctx_size) (m:typdef_struct) : nat :=
  fmap_fold (monoid_make plus 0%nat) (fun f T => sizeof S T) m.

Definition wf_typctx_size (C:typdefctx) (S:typdefctx_size) : Prop :=
  forall X, fmap_indom C X -> 
     fmap_indom S X 
  /\ fmap_get S X = sizeof_typdef_struct S (fmap_get C X).

End TypeSizes.


(* ---------------------------------------------------------------------- *)
(** Syntax of the source language *)

Inductive access : Type :=
  | access_array : nat -> access
  | access_field : field -> access.

Definition accesses := list access. 

Inductive binop : Type :=
  | binop_eq : binop
  | binop_sub : binop
  | binop_add : binop
  | binop_ptr_add : binop.

Inductive prim : Type :=
  | prim_binop : binop -> prim
  | prim_get : typ -> prim
  | prim_set : typ -> prim
  | prim_new : typ -> prim
  | prim_struct_access : typ -> field -> prim
  | prim_array_access : typ -> nat -> prim.

(** TODO: Change this! Probably use Flocq? *)
Definition double := int.

Inductive val : Type :=
  | val_unit : val
  | val_bool : bool -> val
  | val_int : int -> val
  | val_double : double -> val
  | val_abstract_ptr : loc -> accesses -> val
  | val_concrete_ptr : loc -> offset -> val
  | val_prim : prim -> val
  | val_array : list val -> val
  | val_struct : Fmap.map field val -> val.

Axiom fmap_of_map : forall A B, Fmap.map A B -> fmap A B.

Inductive trm : Type :=
  | trm_var : var -> trm
  | trm_val : val -> trm
  | trm_if : trm -> trm -> trm -> trm
  | trm_let : bind -> trm -> trm -> trm
  | trm_app : prim -> list trm -> trm.
  (*
  | trm_while : trm -> trm -> trm
  | trm_for : var -> trm -> trm -> trm -> trm
  *)


(** Sequence is a special case of let bindings *)

Notation trm_seq := (trm_let bind_anon).

(** The type of values is inhabited *)

Global Instance Inhab_val : Inhab val.
Proof using. apply (Inhab_of_val val_unit). Qed.

(** Shorthand [vars], [vals] and [trms] for lists of items. *)

Definition vals : Type := list val.
Definition trms : Type := list trm.


(* ---------------------------------------------------------------------- *)
(** Coercions *)

Coercion prim_binop : binop >-> prim.
Coercion val_prim : prim >-> val.
Coercion val_int : Z >-> val.
Coercion trm_val : val >-> trm.
Coercion trm_var : var >-> trm.
Coercion trm_app : prim >-> Funclass.

Coercion trms_vals (vs:vals) : trms :=
  List.map trm_val vs.


(* ---------------------------------------------------------------------- *)
(** Induction principle *)

(** An induction principle for trees *)

Section Trm_induct.

Variables
(P : trm -> Prop)
(Q : trms -> Prop)
(P1: forall v : var, P v)
(P2: forall v : val, P v)
(P3: forall t : trm, P t -> forall t0 : trm, P t0 -> forall t1 : trm, P t1 -> P (trm_if t t0 t1))
(P4: forall (b : bind) (t : trm), P t -> forall t0 : trm, P t0 -> P (trm_let b t t0))
(P5: forall (f : prim) (l : list trm), Q l -> P (trm_app f l))
(Q1: Q nil)
(Q2: forall t l, P t -> Q l -> Q (t::l)).

Fixpoint trm_induct_gen (t : trm) : P t :=
  let F := trm_induct_gen in
  match t as x return P x with
  | trm_var v => P1 v
  | trm_val v => P2 v
  | trm_if t0 t1 t2 => P3 (F t0) (F t1) (F t2)
  | trm_let b t0 t1 => P4 b (F t0) (F t1)
  | trm_app f l => P5 f 
      ((fix trms_induct (l : trms) : Q l :=
      match l as x return Q x with
      | nil   => Q1
      | t::l' => Q2 (F t) (trms_induct l')
      end) l)
  end.

End Trm_induct.

(* To use it:
  eapply tree_induct_gen with (Q := fun l =>
    forall t, Mem t l -> P t);
*)


(* ********************************************************************** *)
(* * Source language semantics *)

(* ---------------------------------------------------------------------- *)
(** Big-step evaluation *)

Implicit Types t : trm.
Implicit Types v : val.
Implicit Types l : loc.
Implicit Types i : field.
Implicit Types b : bool.
Implicit Types n : int.
Implicit Types x : var.
Implicit Types z : bind.
Implicit Types vs : vals.
Implicit Types ts : trms.

Definition state := fmap loc val.

Definition env := Ctx.ctx val.

Section Red.

Definition is_val t :=
  match t with
  | trm_val v => True
  | _ => False
  end.

Local Open Scope fmap_scope.

Inductive redbinop : binop -> val -> val -> val -> Prop :=
  | redbinop_add : forall n1 n2,
      redbinop binop_add (val_int n1) (val_int n2) (val_int (n1 + n2))
  | redbinop_sub : forall n1 n2,
      redbinop binop_sub (val_int n1) (val_int n2) (val_int (n1 - n2))
  | redbinop_eq : forall v1 v2,
      redbinop binop_eq v1 v2 (val_bool (isTrue (v1 = v2))).

Open Scope list_scope.

(** Returns v.π0...πn. *)
Fixpoint follow (v:val) (π:accesses) : option val :=
  match v, π with
  | val_array l, ((access_array i)::π') => 
    match List.nth_error l i with
    | Some v' => follow v' π'
    | None => None
    end
  | val_struct s, ((access_field f)::π') => 
    match s f with
    | Some v' => follow v' π'
    | None => None
    end
  | _, nil => Some v
  | _, _ => None
  end.

(** m' is m but with m[l].π0...πn = v. *)
Definition updated_state (l:loc) (π:accesses) (v:val) (m:state) (m':state) : Prop :=
  forall l' π' w' w,
  fmap_data m l = Some w /\ fmap_data m' l = Some w' ->
      (not (l = l') -> fmap_data m l' = fmap_data m' l') 
  /\  (l = l'-> (not (π = π') -> follow w π' = follow w' π')
            /\  (π = π' -> follow w' π' = Some v)).

Check access_array.

Inductive red : env -> state -> trm -> state -> val -> Prop :=
  | red_var : forall E m v x,
      Ctx.lookup x E = Some v ->
      red E m (trm_var x) m v
  | red_val : forall E m v,
      red E m v m v
  | red_if : forall E m1 m2 m3 b r t0 t1 t2,
      red E m1 t0 m2 (val_bool b) ->
      red E m2 (if b then t1 else t2) m3 r ->
      red E m1 (trm_if t0 t1 t2) m3 r
  | red_let : forall E m1 m2 m3 z t1 t2 v1 r,
      red E m1 t1 m2 v1 ->
      red (Ctx.add z v1 E) m2 t2 m3 r ->
      red E m1 (trm_let z t1 t2) m3 r
  (* Binary operations *)
  | red_binop : forall E (op:binop) m v1 v2 v,
      redbinop op v1 v2 v ->
      red E m (trm_app op ((trm_val v1)::(trm_val v2)::nil)) m v
  (* Operations on the abstract heap *) 
  | red_get : forall E m p l π T v w,
      red E m p m (val_abstract_ptr l π) ->
      fmap_data m l = Some v ->
      follow v π = Some w ->
      red E m (trm_app (prim_get T) (p::nil)) m w
  | red_set : forall E m1 m2 p l π t v T,
      red E m1 p m1 (val_abstract_ptr l π) ->
      red E m1 t m1 v ->
      updated_state l π v m1 m2 ->
      red E m1 (trm_app (prim_set T) (p::t::nil)) m2 val_unit
  | red_new: forall E l v ma mb T,
      mb = (fmap_single l v) ->
      l <> null ->
      \# ma mb ->
      red E ma (trm_app (prim_new T) ((trm_val v)::nil)) mb (val_abstract_ptr l nil)
  | red_struct_access : forall E m l s f π T v,
      fmap_data m l = Some (val_struct s) ->
      fmap_data (fmap_of_map s) f = Some v ->
      red E m (trm_app (prim_struct_access T f) ((trm_val (val_abstract_ptr l π))::nil)) m 
              (val_abstract_ptr l (π++((access_field f)::nil)))
  | red_array_access : forall E m l a (i:nat) π T v,
      fmap_data m l = Some (val_array a) ->
      List.nth_error a i = Some v ->
      red E m (trm_app (prim_array_access T i) ((trm_val (val_abstract_ptr l π))::nil)) m 
              (val_abstract_ptr l (π++((access_array i)::nil))).

End Red.

(* Derived *)

Lemma red_seq : forall E m1 m2 m3 t1 t2 r1 r,
  red E m1 t1 m2 r1 ->
  red E m2 t2 m3 r ->
  red E m1 (trm_seq t1 t2) m3 r.
Proof using. intros. applys* red_let. Qed.



(* ---------------------------------------------------------------------- *)
(** Type inference rules *)

Definition typctx_var := fmap var typ.
Definition typctx_loc := fmap (loc * accesses) typ.

(*
Inductive val : Type :=
  | val_unit : val
  | val_bool : bool -> val
  | val_int : int -> val
  | val_double : double -> val
  | val_abstract_ptr : loc -> accesses -> val
  | val_concrete_ptr : loc -> offset -> val
  | val_prim : prim -> val
  | val_array : list val -> val
  | val_struct : Fmap.map field val -> val.
*)

Inductive typ_inf : typctx_var -> typctx_loc -> trm -> typ -> Prop :=
  | typ_inf_val_unit : forall cv cl,
      typ_inf cv cl val_unit typ_unit
  | typ_inf_val_bool : forall cv cl b,
      typ_inf cv cl (val_bool b) typ_bool
  | typ_inf_val_int : forall cv cl i,
      typ_inf cv cl (val_int i) typ_int
  | typ_inf_val_double : forall cv cl d,
      typ_inf cv cl (val_double d) typ_double
  | typ_inf_val_abstract_ptr : forall cv cl l π T,
      fmap_data cl (l, π) = Some T ->
      typ_inf cv cl (val_abstract_ptr l π) T
.

(* ********************************************************************** *)
(* * Notation for terms *)

(* ---------------------------------------------------------------------- *)
(** Notation for concrete programs *)

Module NotationForTerms.

(** Note: below, many occurences of [x] have type [bind], and not [var] *)

Notation "'()" := val_unit : trm_scope.

Notation "'If_' t0 'Then' t1 'Else' t2" :=
  (trm_if t0 t1 t2)
  (at level 69, t0 at level 0) : trm_scope.

Notation "'If_' t0 'Then' t1 'End'" :=
  (trm_if t0 t1 val_unit)
  (at level 69, t0 at level 0) : trm_scope.

Notation "'Let' x ':=' t1 'in' t2" :=
  (trm_let x t1 t2)
  (at level 69, x at level 0, right associativity,
  format "'[v' '[' 'Let'  x  ':='  t1  'in' ']'  '/'  '[' t2 ']' ']'") : trm_scope.

Notation "t1 ;;; t2" :=
  (trm_seq t1 t2)
  (at level 68, right associativity, only parsing,
   format "'[v' '[' t1 ']'  ;;;  '/'  '[' t2 ']' ']'") : trm_scope.

End NotationForTerms.
