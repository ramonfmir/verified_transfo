(**

This file describes transformations of the layout of records and arrays on
the memory.

Author: Ramon Fernandez I Mir and Arthur Charguéraud.

License: MIT.

*)

Set Implicit Arguments.
Require Export Typing.

(* ---------------------------------------------------------------------- *)
(** Type-directed transformation to low-level *)

Inductive prefix_sum : list int -> list int -> int -> Prop :=
  | prefix_sum_nil : forall acc,
      prefix_sum nil nil acc
  | prefix_sum_cons : forall l l' acc i,
      prefix_sum l l' (i + acc) ->
      prefix_sum (i::l) (acc::l') acc.

Lemma prefix_sum_example :
  prefix_sum (1::2::3::4::5::6::nil) (0::1::3::6::10::15::nil) 0.
Proof.
  repeat constructors.
Qed.

Lemma prefix_sum_length : forall l l' n,
  prefix_sum l l' n ->
  length l = length l'.
Proof.
  introv Hps. induction Hps.
  { rewrite~ length_nil. }
  { repeat rewrite length_cons. rewrite~ IHHps. }
Qed.

Lemma prefix_sum_spec : forall l l' n,
  prefix_sum l l' n ->
  (forall i,
    index l i ->
    l'[i] = fold_left Z.add n (take i l)).
Proof.
  introv Hps. induction Hps.
  { introv Hi. false. rewrite index_eq_index_length in Hi.
    rewrite length_nil in Hi. inverts Hi. math. }
  { introv Hi. rewrite read_cons_case. case_if.
    { subst. eauto. }
    { lets Hi': Hi.
      rewrite index_eq_index_length in Hi.
      rewrite int_index_eq in Hi.
      destruct Hi as (Hle&Hlt).
      rewrite length_cons in Hlt.
      rewrite take_cons_pos; try solve [ math ].
      rewrite fold_left_cons.
      asserts Hl: (index (length l) (i0 - 1)).
      { rewrite int_index_eq. math. }
      rewrite <- index_eq_index_length in Hl.
      forwards*: IHHps Hl. } }
Qed.

Axiom list_to_map : forall A B, list A -> list B -> map A B.

Axiom list_to_map_spec : forall ks vs m,
  m = list_to_map ks vs ->
      length ks = length vs
  /\  forall i,
        index ks i ->
        ks[i] \indom m /\ m[ks[i]] = vs[i].

Inductive ll_typdefctx_ok (C:typdefctx) (LLC:ll_typdefctx) : Prop :=
  | low_level_ctx_ok_intros : forall CS CFOrd CFOff,
      LLC = make_ll_typdefctx CS CFOff CFOrd ->
      (* Same fields in C and LLC. *)
      (forall Tv Tfs,
        Tv \indom C ->
        C[Tv] = typ_struct Tfs ->
            dom Tfs = dom CFOff[Tv]
        /\  dom Tfs = to_set CFOrd[Tv]) ->
      (* Coherency between the sizes. *)
      (forall Tv Tfs,
        Tv \indom C ->
        C[Tv] = typ_struct Tfs ->
        (exists FT FS FO,
            (* Fields types. *)
            FT = List.map (fun f => Tfs[f]) CFOrd[Tv]
            (* Fields sizes. *)
        /\  List.Forall2 (typ_size CS) FT FS
            (* Fields offsets. *)
        /\  prefix_sum FS FO 0
            (* The relationship. *)
        /\  CS[Tv] = fold_left Z.add 0 FS
        /\  CFOff[Tv] = list_to_map CFOrd[Tv] FO)) ->
      ll_typdefctx_ok C LLC.

(* Given a list of accesses, computes the offset. Used to translate
   pointer values. *)

Inductive tr_ll_accesses (C:typdefctx) (LLC:ll_typdefctx) : accesses -> offset -> Prop :=
  | tr_ll_accesses_nil :
      tr_ll_accesses C LLC nil 0%Z
  | tr_ll_accesses_access_array : forall T T' os πs i n o,
      typing_array C T T' os ->
      typ_size (typvar_sizes LLC) T' n ->
      tr_ll_accesses C LLC πs o ->
      (0 <= i)%Z ->
      (0 <= n)%Z ->
      tr_ll_accesses C LLC ((access_array T i)::πs) ((i * n) + o)
  | tr_ll_accesses_access_field : forall Tfs FO πs Tv f o,
      typing_struct C (typ_var Tv) Tfs ->
      FO = fields_offsets LLC ->
      Tv \indom FO ->
      f \indom FO[Tv] ->
      tr_ll_accesses C LLC πs o ->
      (0 <= FO[Tv][f])%Z ->
      tr_ll_accesses C LLC ((access_field (typ_var Tv) f)::πs) (FO[Tv][f] + o).

(* Relates values with a list of words. This is how the memory is transformed. *)

Inductive tr_ll_val (C:typdefctx) (LLC:ll_typdefctx) (α:alpha) : typ -> val -> list word -> Prop :=
  | tr_ll_val_unit :
      tr_ll_val C LLC α typ_unit val_unit (word_int 0%Z::nil)
  | tr_ll_val_bool : forall b,
      tr_ll_val C LLC α typ_bool (val_bool b) (word_int (if b then 1 else 0)%Z::nil)
  | tr_ll_val_int : forall i,
      tr_ll_val C LLC α typ_int (val_int i) (word_int i::nil)
  | tr_ll_val_double : forall d,
      tr_ll_val C LLC α typ_double (val_double d) (word_int d::word_int d::nil)
  | tr_ll_val_abstract_ptr : forall T π l o,
      tr_ll_accesses C LLC π o ->
      tr_ll_val C LLC α (typ_ptr T) (val_abstract_ptr l π) ((word_int (α[l] + o))::nil)
  | tr_ll_val_array : forall k T a a',
      length a = k ->
      List.Forall2 (tr_ll_val C LLC α T) a a' ->
      tr_ll_val C LLC α (typ_array T (Some k)) (val_array T a) (concat a')
  | tr_ll_val_struct : forall FCOrd Tv Tfs sc st s s',
      FCOrd = fields_order LLC ->
      Tv \indom FCOrd ->
      Tv \indom C ->
      typing_struct C (typ_var Tv) Tfs ->
      sc = List.map (fun f => s[f]) FCOrd[Tv] ->
      st = List.map (fun f => Tfs[f]) FCOrd[Tv] ->
      length s' = length FCOrd[Tv] ->
      (forall i,
        index s' i ->
        tr_ll_val C LLC α st[i] sc[i] s'[i]) ->
      tr_ll_val C LLC α (typ_var Tv) (val_struct (typ_var Tv) s) (concat s').


(* ---------------------------------------------------------------------- *)
(** General results about these predicates. *)
