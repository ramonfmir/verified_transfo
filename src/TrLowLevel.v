(**

This file describes transformations of the layout of records and arrays.

Author: Ramon Fernandez I Mir and Arthur Charguéraud.

License: MIT.

*)

Set Implicit Arguments.
Require Export Semantics.

(* ********************************************************************** *)
(* * Definition of the transformation *)

(** This is a special kind of transformation. We need to define new 
    new semantics. Essentially get and set for the concrete pointer.
    It can be included in the general semantics and just check that no
    concrete pointers are used in the other transformations. *)


(* ---------------------------------------------------------------------- *)

Definition in_block (m:state) (l1:loc) (l:loc) : Prop :=
  exists ws,
      m[l1] = val_words ws
  /\  l1 <= l < l1 + length ws.

Definition disjoint_blocks (m:state) : Prop :=
  forall l1 l2,
    l1 <> l2 ->
    forall l, ~ (in_block m l1 l /\ in_block m l1 l).

(** Transformation of states: m ~ |m| *)

Inductive tr_state (C:typdefctx) (LLC:ll_typdefctx) (φ:phi) (α:alpha) : state -> state -> Prop :=
  | tr_state_intro : forall m m',
      dom m = dom m' ->
      disjoint_blocks m' ->
      (forall l lw T,
        l \indom m ->
            typing_val C LLC φ m[l] T
        /\  tr_ll_val C LLC α T m[l] lw
        /\  m'[α[l]] = val_words lw) ->
      tr_state C LLC φ α m m'.

(* ---------------------------------------------------------------------- *)
(* Transformation of a term from high-level to low-level. This is how the code is transformed. *)

Inductive tr_val (C:typdefctx) (LLC:ll_typdefctx) (α:alpha) : val -> val -> Prop :=
  | tr_val_error :
      tr_val C LLC α val_error val_error
  | tr_val_unit :
      tr_val C LLC α val_unit val_unit
  | tr_val_bool : forall b,
      tr_val C LLC α (val_bool b) (val_bool b)
  | tr_val_int : forall i,
      tr_val C LLC α (val_int i) (val_int i)
  | tr_val_double : forall d,
      tr_val C LLC α (val_double d) (val_double d)
  | tr_val_abstract_ptr : forall π l o,
      tr_ll_accesses C LLC π o ->
      tr_val C LLC α (val_abstract_ptr l π) (val_concrete_ptr α[l] o)
  | tr_val_array : forall T a a',
      List.Forall2 (tr_val C LLC α) a a' ->
      tr_val C LLC α (val_array T a) (val_array T a')
  | tr_val_struct : forall Tv s s',
      dom s = dom s' ->
      (forall f,
        index s f ->
        tr_val C LLC α s[f] s'[f]) ->
      tr_val C LLC α (val_struct (typ_var Tv) s) (val_struct (typ_var Tv) s').

(** Transformation of stacks: S ~ |S| *)

Inductive tr_stack_item (C:typdefctx) (LLC:ll_typdefctx) (α:alpha) : (var * val) -> (var * val) -> Prop :=
  | tr_stack_item_intro : forall x v v',
      tr_val C LLC α v v' -> 
      tr_stack_item C LLC α (x, v) (x, v').

Inductive tr_stack (C:typdefctx) (LLC:ll_typdefctx) (α:alpha) : stack -> stack -> Prop :=
  | tr_stack_intro : forall S S',
      LibList.Forall2 (tr_stack_item C LLC α) S S' ->
      tr_stack C LLC α S S'.

Lemma stack_lookup_tr : forall C LLC α S S' x v,
  tr_stack C LLC α S S' ->
  Ctx.lookup x S = Some v -> 
    exists v', 
       Ctx.lookup x S' = Some v' 
    /\ tr_val C LLC α v v'.
Proof.
  introv HS Hx. inverts HS as HS. induction HS.
  { inverts Hx. }
  { inverts H as Hv. inverts Hx as Hx. case_if in Hx.
    { inverts Hx. exists v'. splits*. unfolds. case_if*. }
    { forwards (v''&Hx'&Hv''): IHHS Hx. exists v''.
      splits*. unfolds. case_if. fold Ctx.lookup. auto. } }
Qed.

(** Transformation of terms: t ~ |t| *)

Inductive tr_trm (C:typdefctx) (LLC:ll_typdefctx) (α:alpha) : trm -> trm -> Prop :=
  | tr_trm_val : forall v v',
      tr_val C LLC α v v' ->
      tr_trm C LLC α (trm_val v) (trm_val v')
  | tr_trm_var : forall x,
      tr_trm C LLC α (trm_var x) (trm_var x)
  | tr_trm_if : forall t0 t1 t2 t0' t1' t2',
      tr_trm C LLC α t0 t0' ->
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α t2 t2' ->
      tr_trm C LLC α (trm_if t0 t1 t2) (trm_if t0' t1' t2')
  | tr_trm_let : forall t0 t1 z t0' t1',
      tr_trm C LLC α t0 t0' ->
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α (trm_let z t0 t1) (trm_let z t0' t1')
  | tr_trm_binop : forall t1 t2 op t1' t2', 
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α t2 t2' ->
      tr_trm C LLC α (trm_app (prim_binop op) (t1::t2::nil)) (trm_app (prim_binop op) (t1'::t2'::nil))
  | tr_trm_get : forall t1 T t1',
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α (trm_app (prim_get T) (t1::nil)) (trm_app (prim_ll_get T) (t1'::nil))
  | tr_trm_set : forall t1 t2 T t1' t2',
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α (trm_app (prim_set T) (t1::t2::nil)) (trm_app (prim_ll_set T) (t1'::t2'::nil))
  | tr_trm_new : forall T,
      tr_trm C LLC α (trm_app (prim_new T) nil) (trm_app (prim_ll_new T) nil)
 (*| tr_trm_new_array :
      TODO: prim_new_array is needed here. *)
  | tr_trm_struct_access : forall Tfs t1' o Tv f t1 tr,
      Tv \indom C ->
      typing_struct C (typ_var Tv) Tfs ->
      f \indom Tfs ->
      o = (fields_offsets LLC)[Tv][f] ->
      tr_trm C LLC α t1 t1' ->
      tr = trm_app (prim_ll_access Tfs[f]) (t1'::(trm_val (val_int o))::nil) ->
      tr_trm C LLC α (trm_app (prim_struct_access (typ_var Tv) f) (t1::nil)) tr
  | tr_trm_array_access : forall os t2' n tr T' t1' toff T t1 t2,
      typing_array C T T' os ->
      typ_size (typvar_sizes LLC) T' n ->
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α t2 t2' ->
      toff = trm_app (prim_binop binop_mul) (t2'::(trm_val (val_int n))::nil) ->
      tr = trm_app (prim_ll_access T') (t1'::toff::nil) ->
      tr_trm C LLC α (trm_app (prim_array_access T) (t1::t2::nil)) tr
  | tr_trm_struct_get : forall t1 T f t1',
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α (trm_app (prim_struct_get T f) (t1::nil)) (trm_app (prim_struct_get T f) (t1'::nil))
  | tr_trm_array_get : forall t1 t2 T t1' t2',
      tr_trm C LLC α t1 t1' ->
      tr_trm C LLC α t2 t2' ->
      tr_trm C LLC α (trm_app (prim_array_get T) (t1::t2::nil)) (trm_app (prim_array_get T) (t1'::t2'::nil)).

(* ---------------------------------------------------------------------- *)
(** Correctness of the transformation *)

Hint Constructors red.

Theorem red_tr : forall m2 t m1 φ S LLC v C S' m1' t',
  red C LLC S m1 t m2 v ->
  ll_typdefctx_ok C LLC ->
  tr_trm C LLC t t' ->
  tr_stack C LLC S S' ->
  tr_state C LLC φ m1 m1' ->
  state_typing C LLC φ m1 ->
  exists v' m2' φ',
      extends φ φ' ->
  /\  tr_state C LLC φ' m2 m2'
  /\  tr_val C LLC v v'
  /\  red C LLC S' m1' t' m2' v'.
Proof.
  introv HR Hok Ht HS Hm1 Hφ. gen φ t' S' m1'. induction HR; intros.
  { (* val *)
    inverts Ht. exists* v' m1'. }
  { (* var *)
    inverts Ht. forwards~ (v'&HCl&Htr): stack_lookup_tr HS H.
    exists* v' m1'. }
  { (* if *)
    inverts Ht as Hb HTrue HFalse.
    forwards* (v'&m2'&Hv'&Hm2'&HR3): IHHR1 Hb HS Hm1.
    inverts* Hv'.
    destruct b;
    forwards* (vr'&m3'&Hvr'&Hm3'&HR4): IHHR2 HS Hm2'.
    { admit. (* use type soundness. *) }
    exists* vr' m3'. }
Admitted.
















