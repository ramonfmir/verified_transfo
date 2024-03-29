(**

This file describes the array tiling transformation.

Author: Ramon Fernandez I Mir and Arthur Charguéraud.

License: MIT.

*)


Set Implicit Arguments.
Require Export Semantics LibSet LibMap LibList TLCbuffer Typing.

Implicit Types i j k I J K : int.

Open Scope Z_scope.


(* ---------------------------------------------------------------------- *)
(** Definition of the transformation *)

(** Tiling transformation. Specified by:
    - The typvar of the array to be tiled.
    - The new typvar of the tiles.
    - The size of the tiles. *)

Record tiling_tr := make_tiling_tr {
  tiling_tr_array_name : typvar;
  tiling_tr_tile_name : typvar;
  tiling_tr_tile_size : size
}.

Notation make_tiling_tr' := make_tiling_tr.

(** Checking if the transformation is acceptable. *)

Inductive tiling_tr_ok : tiling_tr -> typdefctx -> Prop :=
  | tiling_tr_ok_intros : forall Ta Tt K T os tt C,
      tt = make_tiling_tr Ta Tt K ->
      Ta \indom C ->
      C[Ta] = typ_array T os ->
      Tt \notindom C ->
      K > 0%Z ->
      (forall Tv,
        Tv \indom C ->
        Tv <> Ta ->
        ~ free_typvar C Ta C[Tv]) ->
      tiling_tr_ok tt C.


(* ---------------------------------------------------------------------- *)
(** Representation of indices. *)

Definition nb_tiles (K I J:int) : Prop :=
  J = I / K + If (I mod K = 0) then 0 else 1.

Definition tiled_indices (I J K i j k:int) : Prop :=
      i = j * K + k
  /\  index I i
  /\  index J j
  /\  index K k.


(* ---------------------------------------------------------------------- *)
(** The transformation applied to the different constructs. *)

(** Transformation of typdefctxs: C ~ |C| *)

Inductive tr_typdefctx (tt:tiling_tr) : typdefctx -> typdefctx -> Prop :=
  | tr_typdefctx_intro : forall T Tt Ta K os os' C C',
      tt = make_tiling_tr Ta Tt K ->
      dom C' = dom C \u \{Tt} ->
      C[Ta] = typ_array T os ->
      C'[Ta] = typ_array (typ_var Tt) os' ->
      C'[Tt] = typ_array T (Some K) ->
      (forall Tv,
        Tv \indom C ->
        Tv <> Ta ->
        C'[Tv] = C[Tv]) ->
      (match os, os' with
      | Some Ii, Some Jj => nb_tiles K Ii Jj
      | None, None => True
      | _,_ => False
      end) ->
      tr_typdefctx tt C C'.

(** Transformation of paths: π ~ |π| *)

Inductive tr_accesses (tt:tiling_tr) : accesses -> accesses -> Prop :=
  | tr_accesses_nil :
      tr_accesses tt nil nil
  | tr_accesses_array_tiling : forall π π' Ta Tt i n a0 a1 a2,
      tr_accesses tt π π' ->
      tt = make_tiling_tr Ta Tt n ->
      a0 = access_array (typ_var Ta) i ->
      a1 = access_array (typ_var Ta) (i/n) ->
      a2 = access_array (typ_var Tt) (i mod n) ->
      tr_accesses tt (a0::π) (a1::a2::π')
  | tr_accesses_array_other : forall π π' T i,
      T <> typ_var (tiling_tr_array_name tt) ->
      tr_accesses tt π π' ->
      tr_accesses tt ((access_array T i)::π) ((access_array T i)::π')
  | tr_accesses_field : forall T π π' f,
      tr_accesses tt π π' ->
      tr_accesses tt ((access_field T f)::π) ((access_field T f)::π').

(** Transformation of values: v ~ |v| *)

Inductive tr_val (tt:tiling_tr) : val -> val -> Prop :=
  | tr_val_uninitialized :
      tr_val tt val_uninitialized val_uninitialized
  | tr_val_unit :
      tr_val tt val_unit val_unit
  | tr_val_bool : forall b,
      tr_val tt (val_bool b) (val_bool b)
  | tr_val_int : forall i,
      tr_val tt (val_int i) (val_int i)
  | tr_val_double : forall d,
      tr_val tt (val_double d) (val_double d)
  | tr_val_abstract_ptr : forall l π π',
      tr_accesses tt π π' ->
      tr_val tt (val_abstract_ptr l π) (val_abstract_ptr l π')
  | tr_val_array_tiling : forall K I J Tt Ta aI aJ,
      tt = make_tiling_tr Ta Tt K ->
      nb_tiles K I J ->
      length aI = I ->
      length aJ = J ->
      (forall j,
        index aJ j ->
        exists aK,
            aJ[j] = (val_array (typ_var Tt) aK)
        /\  length aK = K) ->
      (forall i j k aK,
        tiled_indices I J K i j k ->
        aJ[j] = (val_array (typ_var Tt) aK) ->
        tr_val tt aI[i] aK[k]) ->
      tr_val tt (val_array (typ_var Ta) aI) (val_array (typ_var Ta) aJ)
  | tr_val_array_other : forall T a a',
      T <> typ_var (tiling_tr_array_name tt) ->
      length a = length a' ->
      (forall i,
        index a i ->
        tr_val tt a[i] a'[i]) ->
      tr_val tt (val_array T a) (val_array T a')
  | tr_val_struct_other : forall T s s',
      dom s = dom s' ->
      (forall f,
        f \indom s ->
        tr_val tt s[f] s'[f]) ->
      tr_val tt (val_struct T s) (val_struct T s').

(** Transformation used in the struct cases to avoid repetition. *)

Inductive tr_prim (tt:tiling_tr) (pr:typ->prim) : trm -> trm -> trm -> Prop :=
  | tr_prim_intro : forall op1 Ta op2 Tt ta1 ta2 K tlk tlj v1 v2,
      tt = make_tiling_tr Ta Tt K ->
      op1 = pr (typ_var Ta) ->
      op2 = pr (typ_var Tt) ->
      tlk = trm_app binop_mod ((trm_val v2)::(trm_val (val_int K))::nil) ->
      tlj = trm_app binop_div ((trm_val v2)::(trm_val (val_int K))::nil) ->
      ta1 = trm_app op1 ((trm_val v1)::tlj::nil) ->
      ta2 = trm_app op2 (ta1::tlk::nil) ->
      tr_prim tt pr (trm_val v1) (trm_val v2) ta2.

(** v1[v2 / K][v2 % K] *)

Inductive tr_array_op (tt:tiling_tr) : trm -> trm -> Prop :=
  | tr_array_op_tiling_access : forall op t1 t2 tlt,
      op = prim_array_access (typ_var (tiling_tr_array_name tt)) ->
      tr_prim tt prim_array_access t1 t2 tlt ->
      tr_array_op tt (trm_app op (t1::t2::nil)) tlt
  | tr_array_op_tiling_get : forall op t1 t2 tlt,
      op = prim_array_get (typ_var (tiling_tr_array_name tt)) ->
      tr_prim tt prim_array_get t1 t2 tlt ->
      tr_array_op tt (trm_app op (t1::t2::nil)) tlt
  | tr_array_op_other_access : forall Ta op T ts,
      Ta = tiling_tr_array_name tt ->
      T <> (typ_var Ta) ->
      op = prim_array_access T ->
      tr_array_op tt (trm_app op ts) (trm_app op ts)
  | tr_array_op_other_get : forall Ta op T ts,
      Ta = tiling_tr_array_name tt ->
      T <> (typ_var Ta) ->
      op = prim_array_get T ->
      tr_array_op tt (trm_app op ts) (trm_app op ts).

(** Transformation of terms: t ~ |t| *)

Inductive tr_trm (tt:tiling_tr) : trm -> trm -> Prop :=
  | tr_trm_val : forall v v',
      tr_val tt v v' ->
      tr_trm tt (trm_val v) (trm_val v')
  | tr_trm_var : forall x,
      tr_trm tt (trm_var x) (trm_var x)
  | tr_trm_if : forall t1 t2 t3 t1' t2' t3',
      tr_trm tt t1 t1' ->
      tr_trm tt t2 t2' ->
      tr_trm tt t3 t3' ->
      tr_trm tt (trm_if t1 t2 t3) (trm_if t1' t2' t3')
  | tr_trm_let : forall x t1 t2 t1' t2',
      tr_trm tt t1 t1' ->
      tr_trm tt t2 t2' ->
      tr_trm tt (trm_let x t1 t2) (trm_let x t1' t2')
  (* new *)
  | tr_trm_new : forall T,
      tr_trm tt (trm_app (prim_new T) nil) (trm_app (prim_new T) nil)
  (* Special case: array access *)
  | tr_trm_array : forall t1' t2' op t1 t2 tr,
      is_array_op op ->
      tr_trm tt t1 t1' ->
      tr_trm tt t2 t2' ->
      tr_array_op tt (trm_app op (t1'::t2'::nil)) tr ->
      tr_trm tt (trm_app op (t1::t2::nil)) tr
  (* Args *)
  | tr_trm_args1 : forall op t1 t1',
      tr_trm tt t1 t1' ->
      tr_trm tt (trm_app op (t1::nil)) (trm_app op (t1'::nil))
  | tr_trm_args2 : forall op t1 t1' t2 t2',
      ~ is_array_op op ->
      tr_trm tt t1 t1' ->
      tr_trm tt t2 t2' ->
      tr_trm tt (trm_app op (t1::t2::nil)) (trm_app op (t1'::t2'::nil)).

(** Transformation of stacks: S ~ |S| *)

Inductive tr_stack_item (tt:tiling_tr) : (var * val) -> (var * val) -> Prop :=
  | tr_stack_item_intro : forall x v v',
      tr_val tt v v' -> 
      tr_stack_item tt (x, v) (x, v').

Inductive tr_stack (tt:tiling_tr) : stack -> stack -> Prop :=
  | tr_stack_intro : forall S S',
      LibList.Forall2 (tr_stack_item tt) S S' ->
      tr_stack tt S S'.

(** Transformation of states: m ~ |m| *)

Inductive tr_state (tt:tiling_tr) : state -> state -> Prop :=
  | tr_state_intro : forall m m',
      dom m = dom m' ->
      (forall l,
        l \indom m ->
        tr_val tt m[l] m'[l]) ->
      tr_state tt m m'.


(* ---------------------------------------------------------------------- *)
(** Results about division and modulo operation. *)

Section DivModResults.

(** Axioms. *)

Axiom div_mod_eq : forall i j k:Z,
  k > 0%Z ->
  (i / k)%Z = (j / k)%Z ->
  (i mod k)%Z = (j mod k)%Z ->
  i = j.

Axiom div_plus_mod_eq : forall i K,
  K > 0%Z ->
  i = (i/K)*K + (i mod K).

Axiom residual_div : forall (x i:int) (K:size),
  K > 0%Z ->
  index K i ->
  ((x * K + i) / K)%Z = x.

Axiom index_div : forall I K i:Z,
  K > 0%Z ->
  index I i ->
  index ((I/K + If (I mod K = 0) then 0 else 1)%Z) ((i/K)%Z).

Axiom index_mod : forall K i:Z,
  K > 0%Z ->
  index K ((i mod K)%Z).

Axiom index_mul_plus : forall I K i k:Z,
  K > 0%Z ->
  index ((I/K + If (I mod K = 0) then 0 else 1)%Z) i ->
  index K k ->
  index I (i * K + k)%Z.

(** Numerical results. *)

Lemma div_mod_enforce_mod : forall i k j:Z,
  k > 0%Z ->
  i = i / k * k + j ->
  j = (i mod k)%Z.
Proof using.
  introv Hnz Heq. forwards~ H: div_plus_mod_eq i k.
  remember (i/k * k) as n. rewrite H in Heq.
  forwards*: Z.add_reg_l Heq.
Qed.

Lemma div_mod_enforce_mod_inv : forall i k j:Z,
  k > 0%Z ->
  j = (i mod k)%Z ->
  i = i / k * k + j.
Proof using.
  introv Hnz Heq. rewrite Heq. apply~ div_plus_mod_eq.
Qed.

Lemma div_mod_enforce_div : forall i k j:Z,
  k > 0%Z ->
  i = j * k + (i mod k)%Z ->
  j = (i / k)%Z.
Proof using.
  introv Hnz Heq. forwards~ H: div_plus_mod_eq i k.
  remember ((i mod k)%Z) as n. rewrite H in Heq.
  rewrite Z.add_comm in Heq.
  rewrite Z.add_comm with (n:=j*k) (m:=n) in Heq.
  forwards H0: Z.add_reg_l Heq.
  forwards*: Z.mul_reg_r H0.
  math.
Qed.

Lemma div_mod_enforce_div_inv : forall i (k:size) j,
  k > 0%Z ->
  j = (i / k)%Z ->
  i = j * k + (i mod k)%Z.
Proof using.
  introv Hnz Heq. rewrite Heq. apply~ div_plus_mod_eq.
Qed.

Lemma div_quotient_neq : forall i K j r,
  K > 0%Z ->
  (r / K)%Z <> i ->
  index K j ->
  (i * K + j)%Z <> r.
Proof using.
  introv Hnz Hneq Hineq. introv HN.
  rewrite <- HN in Hneq.
  forwards* Heq: residual_div Hnz Hineq.
Qed.

Lemma div_both_sides : forall a b c,
  a = b ->
  (a/c)%Z = (b/c)%Z.
Proof using.
  introv Heq. rewrite~ Heq.
Qed.

Lemma j_value : forall i j k K,
  K > 0%Z ->
  i = (j * K + k)%Z ->
  index K k ->
  j = (i/K)%Z.
Proof using.
  introv HK Heq Hi.
  forwards* Heq': div_both_sides i (j * K + k)%Z K.
  rewrite~ residual_div in Heq'.
Qed.

(** Higher-level results. *)

Lemma tiled_indices_i : forall I J K i,
  K > 0%Z ->
  nb_tiles K I J ->
  index I i ->
  tiled_indices I J K i (i / K) (i mod K).
Proof using.
  introv Hgtz Hnb HI.
  unfolds nb_tiles. unfolds tiled_indices.
  splits~.
  { applys~ div_plus_mod_eq. }
  { subst. applys~ index_div. }
  { applys~ index_mod. }
Qed.

Lemma tiled_indices_jk : forall I J K j k,
  K > 0%Z ->
  nb_tiles K I J ->
  index J j ->
  index K k ->
  tiled_indices I J K (j * K + k) j k.
Proof using.
  introv Hgtz Hnb HJ HK.
  unfolds nb_tiles. unfolds tiled_indices.
  splits~. subst. applys~ index_mul_plus.
Qed.

Lemma tiled_index_range_i : forall J I j K k,
  K > 0%Z ->
  nb_tiles K I J ->
  index J j ->
  index K k ->
  index I (j * K + k).
Proof using.
  introv Hgtz Hnb HJ HK. unfolds nb_tiles.
  subst. applys~ index_mul_plus.
Qed.

Lemma tiled_index_range_k : forall k K i I j J,
  K > 0%Z ->
  nb_tiles K I J ->
  tiled_indices I J K i j k ->
  index K k.
Proof using.
  introv Hgtz Hnb Hti. unfolds tiled_indices.
  destructs~ Hti.
Qed.

End DivModResults.


(* ---------------------------------------------------------------------- *)
(** Hints and tactics *)

Hint Constructors red redbinop.
Hint Constructors read_accesses write_accesses.
Hint Constructors tr_trm tr_val tr_accesses tr_state tr_stack.
Hint Constructors wf_trm wf_prim wf_val.

Hint Resolve wf_red.

(** Rewrite lengths. *)

Ltac rew_index_length_val_goal :=
  repeat match goal with
    Hl: length ?a = ?n
    |- index (length ?a) ?i =>
      rewrite Hl; clear Hl end.

Ltac rew_index_length_val_hyp :=
  repeat match goal with
    Hl: length ?a = ?n,
    Hi: index (length ?a) ?i
    |- ?G =>
      rewrite Hl in Hi end.

Ltac rew_index_length_val :=
  rew_index_length_val_goal;
  rew_index_length_val_hyp.

(** Rewrite and solve indeces. *)

Hint Rewrite length_update index_eq_index_length : rew_int.

Ltac solve_index :=
  unfolds nb_tiles;
  rew_index_length_val;
  rew_int in *;
  try solve [ congruence ];
  first [ applys index_div | applys index_mod ].

Hint Extern 1 (index ?a (?i mod ?k)%Z) => 
  rew_index_length_val;
  solve_index.

Hint Extern 1 (index ?a (?i/?k)%Z) => 
  rew_index_length_val;
  solve_index.

Hint Extern 1 (index ?a ?i) =>
  rew_index_length_val;
  solve_index.

Hint Extern 1 (index ?I (?j * ?K + ?k)) =>
  apply tiled_index_range_i; auto.

Hint Extern 1 (length ?a[?i:=?v] = ?l) =>
  rewrite length_update.

Hint Extern 1 (tiled_indices ?I ?J ?K ?i (?i / ?K) (?i mod ?K)) =>
  apply tiled_indices_i; auto.

Hint Extern 1 (tiled_indices ?I ?J ?K (?j * ?K + ?k) ?j ?k) =>
  apply tiled_indices_jk; auto.

(** Quick way of proving K > 0 in many cases. *)

Ltac inverts_Hok :=
  match goal with 
    Hok: tiling_tr_ok ?C ?tt
    |- ?G =>
      inverts Hok end.

Hint Extern 1 (?K > 0%Z) => 
  inverts_Hok; simpls*.


(* ---------------------------------------------------------------------- *)
(** Regularity of the transformation with respect to values *)

(** Basic values stay basic after the transformation. *)

Lemma is_basic_tr : forall tt v1 v2,
  tr_val tt v1 v2 ->
  is_basic v1 ->
  is_basic v2.
Proof using.
  introv Htr Hv1. induction Htr;
  try solve [ inverts Hv1 ];
  constructors~.
Qed.

(** The transformation doesn't transform errors. *)

Lemma not_tr_val_error : forall tt v1 v2,
  tr_val tt v1 v2 ->
  ~ is_error v2.
Proof using.
  introv Hv He. unfolds is_error.
  destruct* v2. inverts Hv.
Qed.

(** The core primitive transformation returns a term. *)

Lemma not_is_val_tr_access : forall tt pr t1 t2 tlt,
  tr_prim tt pr t1 t2 tlt ->
  ~ is_val tlt.
Proof using.
  introv Htra HN. inverts Htra. inverts HN.
Qed.

(** Terms stay terms after the transformation. *)

Lemma not_is_val_tr : forall tt t1 t2,
  tr_trm tt t1 t2 ->
  ~ is_val t1 ->
  ~ is_val t2.
Proof using.
  introv Htr Hv. induction Htr; introv HN;
  try solve [ subst ; inverts HN ].
  forwards*: Hv. inverts H0 as.
  { introv Htr. applys* not_is_val_tr_access. }
  { introv Htr. applys* not_is_val_tr_access. }
  { introv Hneq. inverts HN. }
  { introv Hneq. inverts HN. }
Qed.

(** Initialized values are transformed to initialized values. *)

Lemma not_is_uninitialized_tr : forall tt v v',
  tiling_tr_tile_size tt > 0%Z ->
  tr_val tt v v' ->
  ~ is_uninitialized v ->
  ~ is_uninitialized v'.
Proof using.
  introv Hgtz Htr Hu HN. induction Htr; subst; inverts HN as.
  { applys* Hu. constructors. }
  { introv (j&Hj&HuaJj).
    forwards* (aK&HaJj&HlaK): H3 j.
    rewrite HaJj in HuaJj.
    inverts HuaJj as (k&Hk&HuaKk).
    forwards*: H5 (j * K + k) j k.
    introv HuaI. applys~ Hu.
    constructors. exists (j * K + k). splits~. 
    applys* tiled_index_range_i. }
  { introv (i&Hi&Hua'i). asserts Hi': (index a i).
    { rewrite index_eq_index_length in *. rewrite~ H0. }
    applys* H2. introv Huai. applys~ Hu. constructors.
    exists* i. }
  { introv (f&Hfin&Hus'f). asserts Hfin': (f \indom s).
    { rewrite~ H. }
    applys* H1. introv Husf. applys~ Hu. constructors.
    exists* f. }
Qed.

(** The relation [nb_tiles] is a (partial) function. *)

Lemma functional_nb_tiles : forall n k m1 m2,
  nb_tiles n k m1 ->
  nb_tiles n k m2 ->
  m1 = m2.
Proof using.
  introv Hm1 Hm2. unfolds nb_tiles. subst*.
Qed.

(** The relation [tr_accesses] is a (partial) function. *)

Theorem functional_tr_accesses : forall tt π π1 π2,
  tr_accesses tt π π1 ->
  tr_accesses tt π π2 ->
    π1 = π2.
Proof using.
  introv H1 H2. gen π2. induction H1; intros;
  inverts_head tr_accesses; repeat fequals*;
  inverts_head access_array; subst; simpls; tryfalse.
Qed.

(** Path surgery *)

Lemma tr_accesses_app : forall tt π1 π2 π1' π2',
  tr_accesses tt π1 π1' ->
  tr_accesses tt π2 π2' ->
  tr_accesses tt (π1 ++ π2) (π1' ++ π2').
Proof using.
  introv Ha1 Ha2. gen π2 π2'. induction Ha1; intros;
  rew_list in *; eauto.
Qed.

(** The relation [tr_val] is a (partial) function. *)

Theorem functional_tr_val : forall tt v v1 v2,
  tiling_tr_tile_size tt > 0%Z ->
  tr_val tt v v1 ->
  tr_val tt v v2 ->
  v1 = v2.
Proof using.
  introv Hnz H1 H2. gen v2. induction H1; intros;
  try solve [ inverts_head tr_val; fequals*; subst; simpls; tryfalse ].
  { inverts H2 as Hπ. forwards*: functional_tr_accesses H Hπ.
    subst. fequals. }
  { (* Tiled array *)
    inverts H6 as; inverts_head make_tiling_tr'.
    { introv Hnb HE Ha''.
      asserts Hl: (length aJ = length aJ0).
      { subst. forwards*: functional_nb_tiles H0 Hnb. }
      fequals*. applys* eq_of_extens. introv Hi.
      asserts Hi': (index aJ0 i).
      { rewrite index_eq_index_length in *. rewrite~ <- Hl. }
      forwards* (aK1&HaJ0i&HlaK1): HE i.
      forwards* (aK2&HaJi&HlaK2): H3 i.
      rewrite HaJ0i. rewrite HaJi. fequals.
      asserts HlK: (length aK1 = length aK2).
      { congruence. }
      applys~ eq_of_extens. introv Hi0.
      asserts Hik: (index K0 i0).
      { rewrite index_eq_index_length in Hi0. rewrite~ HlaK2 in Hi0. }
      asserts Hij: (index J i).
      { rewrite index_eq_index_length in Hi. rewrite~ H2 in Hi. }
      applys* H5 (i * K0 + i0). eauto.
      applys~ Ha'' i. }
    { simpls. introv HN. false. } }
  { (* Another array *)
    inverts H3 as; simpls; tryfalse.
    introv Hneq Hl Htr. fequals. applys eq_of_extens.
    { congruence. }
    { introv Hi. asserts: (index a i).
      { rewrite index_eq_index_length in *. rewrite~ H0. }
      applys* H2. } }
  { (* Structs *)
    inverts H2 as HD Htr. fequals. applys read_extens.
    { congruence. }
    { introv Hin. asserts_rewrite* (dom s' = dom s) in *. } }
Qed.

(** The function [tr_accesses] is injective. *)

Lemma tr_accesses_inj : forall C tt π π1 π2,
  tiling_tr_ok tt C ->
  wf_accesses C π1 ->
  wf_accesses C π2 ->
  tr_accesses tt π1 π ->
  tr_accesses tt π2 π ->
    π1 = π2.
Proof using.
  introv Hok Hva1 Hva2 Hπ1 Hπ2. gen C π2. induction Hπ1; intros.
  { inverts Hπ2. auto. }
  { subst. inverts Hπ2; inverts Hva1; inverts Hva2.
    { inverts_head make_tiling_tr'. repeat inverts_head access_array.
      repeat fequals*. applys* div_mod_eq. inverts Hok.
      inverts_head make_tiling_tr'. auto. }
    { simpls. false. } }
  { inverts Hπ2; inverts Hva1; inverts Hva2.
    { inverts_head access_array. fequals*. }
    { fequals*. } }
  { inverts Hπ2; inverts Hva1; inverts Hva2.
    { inverts_head access_array. }
    { fequals*. } }
Qed.

(** The function [tr_val] is injective. *)

Lemma tr_val_inj : forall C tt v v1 v2,
  tiling_tr_ok tt C ->
  is_basic v1 ->
  is_basic v2 ->
  wf_val C v1 ->
  wf_val C v2 ->
  tr_val tt v1 v ->
  tr_val tt v2 v ->
  v1 = v2.
Proof using.
  introv Hok HBv1 HBv2 Hwfv1 Hwfv2 Hv1 Hv2. gen C v2. induction Hv1; intros;
  try solve [ inverts Hv2; repeat fequals*; subst; simpls; tryfalse* ].
  { inverts Hv2 as Hπ. repeat fequals*.
    inverts Hwfv1 as HRφ1. inverts Hwfv2 as HRφ2.
    applys* tr_accesses_inj. }
Qed.

(** Contrapositive of the previous statement. *)

Lemma tr_val_inj_cp : forall C tt v1 v2 v1' v2',
  tiling_tr_ok tt C ->
  is_basic v1 ->
  is_basic v2 ->
  wf_val C v1 ->
  wf_val C v2 ->
  tr_val tt v1 v1' ->
  tr_val tt v2 v2' ->
  v1 <> v2 ->
  v1' <> v2'.
Proof using.
  introv Hok HBv1 HBv2 HTv1 HTv2 Hv1 Hv2 Hneq HN. subst.
  forwards*: tr_val_inj Hok HTv1 HTv2 Hv1.
Qed.


(* ---------------------------------------------------------------------- *)
(** Specific results about the transformation and typing. *)

(** The transformation preserves well-formed types. *)

Lemma tr_typdefctx_wf_typ : forall tt C C' T,
  tr_typdefctx tt C C' ->
  wf_typ C T ->
  wf_typ C' T.
Proof using.
  introv HC HT. induction HT; try solve [ constructors* ].
  inverts HC as HDC' HCTa HC'Ta HC'Tt HC'Tv Hos.
  constructors.
  { rewrite HDC'. rew_set~. }
  { tests: (Tv=Ta).
    { rewrite HC'Ta. repeat constructors~.
      { rewrite HDC'. rew_set~. }
      { rewrite HC'Tt. constructors~.
        rewrite HCTa in IHHT.
        inverts~ IHHT. } }
    { rewrite~ HC'Tv. } }
Qed.

(** All structs have the same type in C and C'. *)

Lemma tr_typing_struct : forall tt C C' Ts Tfs,
  tr_typdefctx tt C C' ->
  typing_struct C Ts Tfs ->
  typing_struct C' Ts Tfs.
Proof using.
  introv HC HTs. induction HTs; intros.
  { constructors~. }
  { inverts HC as HD HCTa HC'Ta HC'Tt HC'Tv _.
    constructors~.
    { rewrite HD. rew_set~. }
    { tests: (Tv=Ta).
      { rewrite HCTa in HTs. inverts HTs. }
      { rewrite~ HC'Tv. } } }
Qed.

(** Arrays where Tat does not appear free have the same type. *)

Lemma tr_typing_array : forall Tat Tt k C C' Ta T os,
  tr_typdefctx (make_tiling_tr Tat Tt k) C C' ->
  wf_typdefctx C ->
  ~ free_typvar C Tat Ta ->
  typing_array C Ta T os ->
  typing_array C' Ta T os.
Proof using.
  introv HC Hwf Hfv HTa. gen Tt Tat k C'. induction HTa; intros.
  { constructors~. applys* tr_typdefctx_wf_typ. }
  { inverts HC as Htt HD HCTa HC'Ta HC'Tt HC'Tv Hos.
    inverts Htt. constructors.
    { rewrite HD. rew_set~. }
    { tests: (Tv=Ta).
      { false. applys~ Hfv. constructors~. }
      { rewrite~ HC'Tv. applys* IHHTa Tt0 Ta K.
        { introv HN. applys~ Hfv. constructors~. }
        { constructors*. } } } }
Qed.


(* ---------------------------------------------------------------------- *)
(** Correctness proofs *)

Section TransformationProofs.

(** Lookup into the translated stack. *)

Lemma stack_lookup_tr : forall tt S S' x v,
  tr_stack tt S S' ->
  Ctx.lookup x S = Some v ->
    exists v',
       Ctx.lookup x S' = Some v'
    /\ tr_val tt v v'.
Proof using.
  introv HS Hx. inverts HS as HS. induction HS.
  { inverts Hx. }
  { inverts H as Hv. inverts Hx as Hx. case_if in Hx.
    { inverts Hx. exists v'. splits*. unfolds. case_if*. }
    { forwards (v''&Hx'&Hv''): IHHS Hx. exists v''.
      splits*. unfolds. case_if. fold Ctx.lookup. auto. } }
Qed.

(** Used in the [let] case. *)

Lemma tr_stack_add : forall tt z v S v' S',
  tr_stack tt S S' ->
  tr_val tt v v' ->
  tr_stack tt (Ctx.add z v S) (Ctx.add z v' S').
Proof using.
  introv HS Hv. constructors~. inverts HS.
  unfolds Ctx.add. destruct* z.
  applys~ Forall2_cons. constructors~.
Qed.

(** Used in the [get] case. *)

Lemma tr_read_accesses : forall tt v π v' π' w,
  tiling_tr_tile_size tt > 0%Z ->
  tr_val tt v v' ->
  tr_accesses tt π π' ->
  read_accesses v π w ->
  (exists w',
      tr_val tt w w'
  /\  read_accesses v' π' w').
Proof using.
  introv Hgt Hv Ha HR. gen tt v' π'. induction HR; intros.
  { (* nil *)
    inverts Ha. exists~ v'. }
  { (* array_access *)
    inverts Ha as.
    { (* tiling array *) 
      introv Hπ Heq. inverts Heq.
      inverts Hv as.
      2:{ introv HN. simpls. false. }
      introv Heq Hnb Ha'' Htrv. inverts Heq.
      unfolds nb_tiles.
      forwards* (a''&Ha'i&Hla''): Ha'' ((i0/K)%Z).
      { rewrite index_eq_index_length in *. rewrite* Hnb. }
      forwards* Hai0: Htrv i0 (i0/K)%Z (i0 mod K)%Z a''.
      forwards* (w'&Hvw'&HR'): IHHR.
      simpls~.
      exists w'. splits~.
      constructors~. 
      { rewrite index_eq_index_length in *. rewrite* Hnb. }
      rewrite Ha'i. constructors~.
      { rewrite index_eq_index_length in *. rewrite* Hla''. } }
    { (* absurd case *)
      introv Hneq Hπ. inverts Hv as.
      { intros. simpls. false. }
      { introv _ Hla Htrv.
        forwards Htrv': Htrv H.
        forwards* (w'&Hvw'&HR'): IHHR. } } }
  { (* struct_access *)
    inverts Ha as.
    { introv _ HN. inverts HN. }
    introv Hπ. inverts Hv as HD Hsf.
    forwards~ Htr: Hsf f.
    forwards* (w'&Htrv2w'&HR'): IHHR.
    exists w'. splits~.
    constructors~. rewrite~ <- HD. }
Qed.

(** Used in the [set] case. *)

Lemma tr_write_accesses : forall tt Ta Tt K v1 w π v1' π' w' v2,
  tt = make_tiling_tr' Ta Tt K ->
  K > 0%Z ->
  tr_val tt v1 v1' ->
  tr_val tt w w' ->
  tr_accesses tt π π' ->
  write_accesses v1 π w v2 ->
  (exists v2',
        tr_val tt v2 v2'
    /\  write_accesses v1' π' w' v2').
Proof using.
  introv Htt HK Hv1 Hw Hπ HW. gen v1' w' π'. induction HW; intros.
  { (* nil *)
    inverts Hπ. exists~ w'. }
  { (* array_access *)
    inverts Hπ as; inverts Hv1 as; inverts_head make_tiling_tr'.
    { (* tiling *)
      introv Htt Hnb Ha'i1 Htra1 Hπ Heq.
      inverts Htt. inverts Heq. subst.
      forwards* (aK&HaJiK&HlK): Ha'i1 ((i0/K0)%Z).
      { rewrite index_eq_index_length in *. rewrite* Hnb. }
      forwards* HtraK: Htra1 i0 (i0/K0)%Z (i0 mod K0)%Z aK.
      forwards* (v2'&Hv2'&HW'): IHHW.
      remember (val_array (typ_var Tt1) aK[((i0 mod K0)%Z):=v2']) as aK'.
      exists (val_array (typ_var Ta1) aJ[((i0/K0)%Z):=aK']).
      subst_hyp HeqaK'. splits.
      { remember aK[(i0 mod K0)%Z:=v2'] as aK'.
        remember aJ[(i0/K0)%Z:=val_array (typ_var Tt1) aK'] as aJ'.
        asserts Hex:
          (forall j : int,
            index aJ' j ->
            exists aK,
                  aJ'[j] = val_array (typ_var Tt1) aK
               /\ length aK = K0).
        { subst. introv Hi. rew_reads*. }
        subst_hyp HeqaK'. subst_hyp HeqaJ'.
        applys* tr_val_array_tiling.
        introv Hi' Hup.
        unfolds tiled_indices. destruct Hi' as (Hieq&Hi&Hk&Hj).
        forwards* (aK1&Heq&HlaK1): Hex j.
        inverts Heq.
        asserts Hi''': (index a1 (j * K0 + k)%Z).
        { rewrite index_eq_index_length in *.
          unfolds nb_tiles. rewrite Hnb in *. eauto. }
        rew_reads~ in Hup.
        { introv Heq. subst. inverts Hup. rew_reads*.
          { introv Hneq Heq.
            forwards*: div_mod_enforce_mod Heq. false. }
          { introv Heq Hneq. symmetry in Heq.
            forwards*: div_mod_enforce_mod_inv Heq. } }
        { introv Hneq.
          forwards* Htra1': Htra1.
          asserts Hneq': (j*K0+k <> i0).
          { applys~ div_quotient_neq. }
          rew_reads~. } }
        { constructors~. 
          { rewrite index_eq_index_length in *. eauto. }
          rewrite HaJiK. constructors*.
          { rewrite index_eq_index_length in *. eauto. } } }
      { (* absurd case *)
        introv Hneq Hla1 Htra1i1 Hπ Heq. inverts Heq. simpls. false. }
      { (* absurd case *) 
        intros. simpls. false. }
      { (* other array *) 
        introv _ Hla1 Htra1i0 Hneq Hπ. subst.
        forwards* (v2'&Hv2'&HW'): IHHW.
        exists (val_array T a'[i:=v2']). splits.
        { constructors~.
          { repeat rewrite~ length_update. }
          { introv Hi0. rewrite index_update_eq in Hi0. rew_reads*. } }
        { constructors~. auto. } } }
  { (* struct *) 
    inverts Hπ as; inverts Hv1 as. 
    { (* absurd case *)
      introv _ _ _ HN. inverts HN. }
    { (* any struct *) 
      introv HDs1 Hs1f0 Hπ. subst.
      forwards* (v2'&Hv2'&HW'): IHHW.
      exists (val_struct T s'[f:=v2']). splits.
      { constructors~.
        { repeat rewrite dom_update. congruence. }
        { introv Hf0. rewrite* dom_update_at_indom in Hf0.
          rew_reads*. } }
      { constructors~. rewrite~ <- HDs1. auto. } } }
Qed.

(** Lemma for the [new] case. *)

Lemma tr_uninitialized_val_aux : forall tt v v' T C C',
  tr_typdefctx tt C C' ->
  tiling_tr_ok tt C ->
  wf_typdefctx C ->
  tr_val tt v v' ->
  uninitialized C T v ->
  uninitialized C' T v'.
Proof using.
  introv HC Hok Hwf Hv Hu. gen tt C' v'. induction Hu; intros;
  try solve [ inverts Hv ; constructors~ ].
  { (* array *)
    inverts HC as HD HCTa HC'Ta HC'Tt HC'Tv Hos.
    inverts Hv as.
    { (* tiling array *)
      introv Htt Hnb Ha'i Htra. inverts Htt.
      inverts Hok as Htt HTain HCTa' HTt0nin Hnz Hfv.
      inverts Htt. unfolds wf_typdefctx.
      rewrite HCTa in HCTa'. inverts HCTa'.
      inverts H as _ HTCTa.
      rewrite HCTa in HTCTa. inverts HTCTa.
      destruct* os; destruct* os'.
      { (* Fixed-size array. *)
        applys uninitialized_array (Some (length aJ)).
        3:{ introv Hi. forwards* (a''&Ha'i'&Hla''): Ha'i.
            rewrite Ha'i'. applys uninitialized_array (Some K).
            { constructors.
              { rewrite HD. rew_set~. }
              { rewrite HC'Tt. constructors~.
                applys* tr_typdefctx_wf_typ. constructors*. } }
            { introv Heq. inverts~ Heq. }
            { introv Hi0. forwards* Htra'': Htra (i*K + i0)%Z i i0 a''.
              applys* H2.
              { applys* tiled_index_range_i. }
              { constructors*. }
              { constructors*. } } }
        { constructors.
          { rewrite HD. rew_set~. }
          { rewrite HC'Ta. unfolds nb_tiles.
            rewrite Hos. rewrite Hnb.
            forwards* Heq: H0 s. rewrite Heq.
            constructors. constructors.
            { rewrite HD. rew_set~. }
            { rewrite HC'Tt. constructors.
              applys* tr_typdefctx_wf_typ. constructors*. } } }
        { introv Heq. inverts~ Heq. } }
      { (* Variable length array. *)
        applys uninitialized_array.
        { constructors.
          { rewrite HD. rew_set~. }
          { rewrite HC'Ta. repeat constructors~.
            { rewrite HD. rew_set~. }
            { rewrite HC'Tt. constructors~.
              applys* tr_typdefctx_wf_typ. constructors*. } } }
        { introv HN. inverts HN. }
        { introv Hi. forwards* (a''&Ha'i'&Hla''): Ha'i.
          rewrite Ha'i'. constructors.
          { constructors.
            { rewrite HD. rew_set~. }
            { rewrite HC'Tt. constructors~.
              applys* tr_typdefctx_wf_typ. constructors*. } }
          { introv Hn. inverts~ Hn. }
          { introv Hi0. forwards* Htra': Htra (i*K + i0)%Z i i0 a''.
            applys* H2.
            { applys* tiled_index_range_i. }
            { constructors*. }
            { constructors*. } } } } }
    { (* other array *)
      introv Hneq Hla Htra. simpls. constructors.
      2:{ rewrite <- Hla. eapply H0. }
      { inverts H as.
        { introv HwfT. constructors*. 
          applys* tr_typdefctx_wf_typ. constructors*. }
        { introv HTvin HTCTv.
          inverts Hok as Htt HTain HCTa' HTt0nin Hnz Hfv.
          inverts Htt. unfolds wf_typdefctx. constructors*.
          { rewrite HD. rew_set~. }
          { rewrite~ HC'Tv. applys~ tr_typing_array Ta Tt0 K0 C.
            { rewrite HCTa in HCTa'. inverts HCTa'. constructors*. }
            { applys~ Hfv. introv HN. subst. applys~ Hneq. }
            { introv HN. subst. applys~ Hneq. } } } }
      { introv Hi.
        asserts: (index a i).
        { rewrite index_eq_index_length in *. rewrite~ Hla. }
        forwards* Htra': Htra i.
        applys* H2. constructors*. } } }
  { (* struct *)
    inverts Hv as HD Hvfsf. constructors.
    2:{ rewrite~ H0. }
    { applys* tr_typing_struct. }
    { introv Hfin. applys* H2. applys Hvfsf.
      rewrite~ <- H0. } }
Qed.

(** This will be proved when the relation is translated to a function.
    See TrTilingFun.v. *)

Lemma total_tr_val_aux : forall gt v,
  exists v', tr_val gt v v'.
Proof using.
Admitted.

(** Usable lemma for the [new] case. *)

Lemma tr_uninitialized_val : forall tt v T C C',
  tr_typdefctx tt C C' ->
  tiling_tr_ok tt C ->
  wf_typdefctx C ->
  uninitialized C T v ->
  exists v',
        tr_val tt v v'
    /\  uninitialized C' T v'.
Proof using.
  introv HC Hok Hwf Hu. forwards* (v'&Hv'): total_tr_val_aux tt v.
  exists v'. splits~. applys* tr_uninitialized_val_aux.
Qed.


(* ---------------------------------------------------------------------- *)
(** Main lemma *)

Theorem red_tr_ind: forall tt C LLC C' t t' v S S' m1 m1' m2,
  red C LLC S m1 t m2 v ->
  tiling_tr_ok tt C ->
  tr_typdefctx tt C C' ->
  tr_trm tt t t' ->
  tr_stack tt S S' ->
  tr_state tt m1 m1' ->
  wf_typdefctx C ->
  wf_trm C t ->
  wf_stack C S ->
  wf_state C m1 ->
  ~ is_error v ->
  exists v' m2',
      tr_val tt v v'
  /\  tr_state tt m2 m2'
  /\  red C' LLC S' m1' t' m2' v'.
Proof using.
  introv HR Hok HC Ht HS Hm1 HwfC Hwft HwfS Hwfm1.
  introv He. gen tt C' t' S' m1'.
  induction HR; intros; try solve [ forwards*: He; unfolds* ].
  { (* val *) 
    inverts Ht as Hv. exists* v' m1'. }
  { (* var *) 
    inverts Ht. forwards* (v'&H'&Hv'): stack_lookup_tr HS H. exists* v' m1'. }
  { (* if *)
    inverts Ht as Hb HTrue HFalse. 
    inverts Hwft as Hwft0 Hwft1 Hwft2.
    forwards* (v'&m2'&Hv'&Hm2'&HR3): IHHR1 Hb HS Hm1.
    inverts* Hv'. destruct b;
    forwards* (vr'&m3'&Hvr'&Hm3'&HR4): IHHR2 HS Hm2';
    forwards*: wf_red HR1; exists* vr' m3'. }
  { (* let *)
    inverts Ht as Ht1 Ht2.
    inverts Hwft as Hwft0 Hwft1.
    forwards* (v'&m2'&Hv'&Hm2'&HR3): IHHR1 Ht1 HS Hm1.
    forwards HS': tr_stack_add z HS Hv'.
    forwards: not_tr_val_error Hv'.
    forwards* (vr'&m3'&Hvr'&Hm3'&HR4): IHHR2 Ht2 HS' Hm2'.
    { applys~ wf_stack_add. applys* wf_red HR1. }
    { applys* wf_red HR1. }
    exists* vr' m3'. }
  { (* binop *)
    inverts Ht as.
    { introv Hop. inverts Hop. }
    { introv Hop Ht1 Ht2. inverts Ht1 as Ht1. inverts Ht2 as Ht2.
      inverts H3;
      try solve [ exists __ m1' ; splits~ ; inverts Ht1 ;
      inverts Ht2 ; repeat constructors~ ].
      { exists __ m1'. splits~.
        forwards~: functional_tr_val Ht1 Ht2. subst.
        constructors;
        repeat applys* is_basic_tr;
        repeat applys* not_tr_val_error.
        constructors~. }
      { exists __ m1'. splits~. constructors;
        repeat applys* is_basic_tr;
        repeat applys* not_tr_val_error.
        inverts Hwft as Hwfp Hwft1 Hwft2.
        inverts Hwft1 as Hwft1. inverts Hwft2 as Hwft2.
        forwards*: tr_val_inj_cp H H0. } } }
  { (* get *)
    inverts Ht as Ht1'. subst.
    inverts Ht1' as Ht1'. inverts Ht1' as Hπ.
    inverts Hm1 as HD Htrm.
    inverts H0 as Hi Ha.
    forwards Htrml: Htrm Hi.
    forwards~ (w'&Hw'&Ha'): tr_read_accesses Htrml Hπ Ha.
    exists w' m1'. splits*.
    repeat constructors~. rewrite~ <- HD.
    applys* not_is_uninitialized_tr. inverts~ Hok. }
  { (* set *)
    inverts Ht as.
    { introv HN. inverts HN. }
    introv Hneq Htrt1' Htrt2'. subst.
    inverts Hm1 as HD Htrm.
    inverts H2 as Hin HW.
    forwards Htrml: Htrm Hin.
    inverts Htrt1' as Hp.
    inverts Hp as Hπ.
    inverts Htrt2' as Hv.
    inverts Hok as HTain HCTa HTtnin Hnz Hfv.
    forwards* (w'&Hw'&HW'): tr_write_accesses Htrml Hv Hπ HW.
    exists val_unit m1'[l:=w']. splits~.
    { constructors.
      { unfold state. repeat rewrite~ dom_update.
        fold state. rewrite~ HD. }
      { introv Hi'. rew_reads~. intros. applys Htrm.
        applys~ indom_update_inv_neq Hi'. } }
    { constructors~. applys* not_tr_val_error.
      constructors*. rewrite~ <- HD. } }
  { (* new *)
    inverts Ht. subst.
    inverts Hm1 as HD Htrm.
    forwards* (v'&Hv'&Hu): tr_uninitialized_val.
    exists (val_abstract_ptr l nil) m1'[l:=v']. splits~.
    { constructors.
      { unfold state. repeat rewrite~ dom_update.
        fold state. rewrite~ HD. }
      { introv Hin. unfolds state. rew_reads; intros; eauto. } }
    { constructors*. rewrite~ <- HD. applys* tr_typdefctx_wf_typ. } }
  { (* new_array *)
    inverts Ht as.
    introv Ht.
    inverts Ht as Hv.
    inverts Hm1 as HD Htrm. subst.
    forwards* (v''&Hv''&Hu): tr_uninitialized_val.
    inverts Hv''.
    exists (val_abstract_ptr l nil) m1'[l:=(val_array (typ_array T None) a')].
    splits~.
    { constructors.
      { unfold state. repeat rewrite~ dom_update.
        fold state. rewrite~ HD. }
      { introv Hin. unfolds state. rew_reads; intros; eauto.
        constructors*. introv HN. inverts HN. } }
    { inverts Hv. applys~ red_new_array. rewrite~ <- HD.
      applys* tr_typdefctx_wf_typ. auto. } }
  { (* struct access *)
    inverts Ht as Ht. subst.
    inverts Ht as Ht.
    inverts Ht as Hπ.
    exists (val_abstract_ptr l (π' & access_field T f)) m1'.
    splits~.
    { constructors. applys~ tr_accesses_app. }
    { constructors~. } }
  { (* array access *)
    inverts Hok as HTain HCTa HTtnin Hnz Hfv.
    subst. inverts Ht as.
    { introv Hop Ht1' Ht2' Haop.
      inverts Haop as; try solve [ intros; simpls; false* ].
      { (* tiling array *)
        introv Hpr Htrp. inverts Hpr.
        inverts Ht1' as Htp.
        inverts Ht2' as Htv.
        inverts Htp as Hπ.
        inverts Htv.
        inverts Htrp.
        inverts_head make_tiling_tr'. simpls.
        remember (access_array (typ_var Ta0) ((i/K0)%Z)) as a1.
        remember (access_array (typ_var Tt0) ((i mod K0)%Z)) as a2.
        exists (val_abstract_ptr l (π'++(a1::a2::nil))) m1'.
        subst. splits~.
        { constructors~. applys~ tr_accesses_app. constructors~. }
        { constructors*.
          { applys red_args_2.
            { introv HN. inverts HN. }
            { applys~ red_binop. constructors~. math. }
            applys~ red_array_access. }
          { applys red_args_2.
            { introv HN. inverts HN. }
            { applys~ red_binop. constructors~. math. }
            applys~ red_array_access. fequals. rew_list~. } } }
      { (* other array *)
        introv Hneq Hpr.
        inverts Hpr. simpls.
        inverts Ht1' as Htp.
        inverts Ht2' as Htv.
        inverts Htp as Hπ.
        inverts Htv.
        exists (val_abstract_ptr l (π'++(access_array T1 i::nil))) m1'.
        splits~.
        { constructors~. applys~ tr_accesses_app. }
        { constructors~. } } }
    { (* absurd case *)
      introv HN. false. applys HN. unfolds~. } }
  { (* struct get *)
    inverts Ht as Ht. subst.
    inverts Ht as Hv.
    inverts Hv as HD Hsf.
    exists s'[f] m1'. splits~.
    constructors~. rewrite~ <- HD. }
  { (* array get *)
    inverts Hok as HTain HCTa HTtnin Hnz Hfv.
    subst. inverts Ht as.
    { (* array get *)
      introv Hop Ht1' Ht2' Haop.
      inverts Haop as; try solve [ intros; tryfalse* ].
      { (* tiling array *)
        introv Hpr Htrp.
        inverts Hpr. simpls.
        inverts Ht1' as Hva.
        inverts Ht2' as Hvi.
        inverts Hva as; try solve [ intros ; false* ].
        introv Htt Hnb Ha' Ha''.
        inverts Hvi. inverts Htt.
        forwards* (a''&Ha'i&Hla''): Ha' ((i/K0)%Z).
        { rewrite index_eq_index_length in *. eauto. }
        forwards* Htra: Ha'' i ((i/K0)%Z) ((i mod K0)%Z) a''.
        exists a''[(i mod K0)%Z] m1'. splits~.
        inverts Htrp as Htt. rewrite <- Hla'' in *.
        inverts Htt. constructors*.
        { applys red_args_2.
          { introv HN. inverts HN. }
          { applys~ red_binop. constructors~. math. }
          applys~ red_array_get.
          { rewrite index_eq_index_length. eauto. } }
        { applys red_args_2.
          { introv HN. inverts HN. }
          { applys~ red_binop. constructors~. math. }
          applys* red_array_get. } }
      { (* another array *)
        introv Hneq Hpr.
        inverts Hpr. simpls.
        inverts Ht1' as Hva.
        inverts Ht2' as Hvi.
        inverts Hvi.
        inverts Hva as.
        { introv Htt. inverts Htt. simpls. false~. }
        { introv _ Hla Htrai.
          exists a'[i] m1'. splits~.
          constructors~. } } }
    { (* absurd case *)
      introv HN. false. applys HN. unfolds~. } }
  { (* ll_get *)
    admit. }
  { (* ll_set *)
    admit. }
  { (* ll_new *)
    admit. }
  { (* ll_access *)
    admit. }
  { (* args 1 *)
    inverts Ht; inverts Hwft;
    forwards* (v'&m2'&Hv'&Hm2'&HR'): IHHR1;
    forwards*: not_is_error_args_1 HR2 He.
    { (* array op *)
      inverts_head tr_array_op;
      forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2;
      try solve [ repeat constructors~; applys* wf_red HR1 ].
      { applys* tr_trm_array.
        applys* tr_array_op_tiling_access.
        asserts Htv: (t1' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. eauto. }
      { exists v'' m3'; splits*.
        asserts Htv: (t1' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. inverts~ HR'. }
      { applys* tr_trm_array.
        applys* tr_array_op_tiling_get.
        asserts Htv: (t1' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. eauto. }
      { exists v'' m3'; splits*.
        asserts Htv: (t1' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. inverts~ HR'. }
      { applys* tr_trm_array. applys*
        tr_array_op_other_access. }
      { exists v'' m3'; splits*. applys* red_args_1.
        applys* not_is_val_tr. }
      { applys* tr_trm_array.
        applys* tr_array_op_other_get. }
      { exists v'' m3'; splits*. applys* red_args_1.
        applys* not_is_val_tr. } }
    { (* ops with just one argument *)
      forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2;
      try solve [ repeat constructors~; applys* wf_red HR1 ].
      exists v'' m3'; splits*. applys* red_args_1.
      applys* not_is_val_tr. }
    { (* ops with two arguments that are not array ops *)
      forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2;
      try solve [ repeat constructors~; applys* wf_red HR1 ].
      exists v'' m3'; splits*. applys* red_args_1.
      applys* not_is_val_tr. } }
  { (* args 2 *)
    inverts Ht; inverts Hwft;
    forwards* (v'&m2'&Hv'&Hm2'&HR'): IHHR1;
    forwards*: not_is_error_args_2 HR2 He.
    { (* array op *)
      inverts_head tr_array_op;
      forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2;
      try solve [ repeat constructors~; applys* wf_red HR1 ].
      { applys* tr_trm_array.
        applys* tr_array_op_tiling_access.
        asserts Htv: (t2' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. eauto. }
      { exists v'' m3'; splits*.
        asserts Htv: (t2' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. inverts~ HR'. }
      { applys* tr_trm_array.
        applys* tr_array_op_tiling_get.
        asserts Htv: (t2' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. eauto. }
      { exists v'' m3'; splits*.
        asserts Htv: (t2' = trm_val v').
        { inverts_head tr_prim. inverts~ HR'. }
        subst_hyp Htv. inverts~ HR'. }
      { applys* tr_trm_array. applys*
        tr_array_op_other_access. }
      { exists v'' m3'; splits*. inverts H6. applys* red_args_2.
        applys* not_is_val_tr. }
      { applys* tr_trm_array.
        applys* tr_array_op_other_get. }
      { exists v'' m3'; splits*. inverts H6. applys* red_args_2.
        applys* not_is_val_tr. } }
    { (* not array op *)
      forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2;
      try solve [ repeat constructors~; applys* wf_red HR1 ].
      exists v'' m3'; splits*. inverts H6. applys* red_args_2.
      applys* not_is_val_tr. } }
Qed.

(** From full execution. *)

Theorem red_tr: forall tt LLC C C' t t' v m2,
  red C LLC empty_stack empty_state t m2 v ->
  tiling_tr_ok tt C ->
  tr_typdefctx tt C C' ->
  tr_trm tt t t' ->
  wf_typdefctx C ->
  wf_trm C t ->
  ~ is_error v ->
  exists v' m2',
      tr_val tt v v'
  /\  tr_state tt m2 m2'
  /\  red C' LLC empty_stack empty_state t' m2' v'.
Proof using.
  introv HR Hok HC Ht HwfC Hwft Hne.
  asserts HS: (tr_stack tt empty_stack empty_stack).
  { constructors. applys~ Forall2_nil. }
  asserts Hm1: (tr_state tt empty_state empty_state).
  { constructors~. introv Hl. false. applys* indom_empty_inv. }
  asserts HwfS: (wf_stack C empty_stack).
  { unfolds~. introv HN. false. }
  asserts Hwfm1: (wf_state C empty_state).
  { unfolds~. introv HN. false. applys* indom_empty_inv. }
  forwards*: red_tr_ind HR Hok HC Ht HS.
Qed.

End TransformationProofs.
