(**

In this file we prove a major property of the language. We show that the
types are preserved by the semantics.

Author: Ramon Fernandez I Mir and Arthur Charguéraud.

License: MIT.

*)


Set Implicit Arguments.
Require Export TLCbuffer Semantics.

Hint Constructors typing_val redbinop.


(* ---------------------------------------------------------------------- *)
(** Preservation of typing over operations *)

(** Lemma for typing preservation of [let]. *)

Lemma stack_typing_ctx_add : forall C φ z T Γ v S,
  stack_typing C φ Γ S ->
  typing_val C φ v T ->
  stack_typing C φ (Ctx.add z T Γ) (Ctx.add z v S).
Proof.
  introv HS HT. unfolds* stack_typing. introv HS1 HT1.
  destruct z.
  { simpls. forwards*: HS. }
  { simpls. rewrite var_eq_spec in *. case_if.
    { inverts* HS1; inverts* HT1. }
    { forwards*: HS. } }
Qed.

(** Auxiliary lemma for typing preservation of [get]. *)

Lemma typing_val_follow : forall T1 w1 π C φ w2 T2,
  typing_val C φ w1 T1 ->
  follow_typ C T1 π T2 ->
  read_accesses w1 π w2 ->
  typing_val C φ w2 T2.
Proof.
  introv HT HF HR. gen π. induction HT; intros;
   try solve [ intros ; inverts HR; inverts HF; constructors* ].
  { inverts HF as; inverts* HR as. introv Hfin HR HTs Hfin' HF. 
    rewrite H0 in *. forwards*: functional_typing_struct H HTs.
    applys* H2. subst~. }
  { inverts HF as; inverts* HR as. introv Hi HR HTa HF.
    forwards* (HT&Hos): functional_typing_array H HTa.
    applys* H2. subst~. }
Qed.

(** Lemma for typing preservation of [get]. *)

Lemma typing_val_get : forall m l π C φ w T,
  state_typing C φ m ->
  read_state m l π w ->
  read_phi C φ l π T ->
  typing_val C φ w T.
Proof.
  introv (HD&HT) HS HP. inverts HS as Hlin HR.
  inverts HP as Hlin' HF. forwards~ HTl: HT l.
  applys* typing_val_follow HTl HF HR.
Qed.

(** Auxiliary lemma for typing preservation of [set]. *)

Lemma typing_val_after_write : forall v1 w π T2 C φ v2 T1,
  write_accesses v1 π w v2 ->
  typing_val C φ v1 T1 ->
  follow_typ C T1 π T2 ->
  typing_val C φ w T2 ->
  typing_val C φ v2 T1.
Proof.
  introv HW HT1 HF HT2. gen T1. induction HW; intros.
  { subst. inverts* HF. }
  { inverts HF. inverts HT1. subst. constructors*. 
    { rewrite* length_update. }
    { intros. rewrite index_update_eq in *. 
      rewrite* read_update_case. case_if*. subst. 
      forwards* (HT&Hos): functional_typing_array T T0 T1. 
      applys* IHHW. subst~. } }
  { inverts HF as HTs HF.
    inverts HT1 as HTs HD HCT. subst. constructors*.
    { unfold state. rewrite* dom_update_at_index. }
    { intros f' Hi1 Hi2. rewrite read_update.
      case_if*. subst.
      forwards*: functional_typing_struct T Tfs Tfs0.
      applys* IHHW. subst~. } }
Qed.

(** Lemma for typing preservation of [set]. *)

Lemma state_typing_set : forall T m1 l π v C φ m2,
  state_typing C φ m1 ->
  write_state m1 l π v m2 ->
  typing_val C φ (val_abstract_ptr l π) (typ_ptr T) ->
  typing_val C φ v T ->
  state_typing C φ m2.
Proof.
  introv HS HW HTp HTv.
  inverts HS as HD HT.
  inverts HW as Hv1 HWA.
  inverts HTp as HP.
  unfolds. split.
  { unfold state. rewrite* dom_update_at_index. }
  { introv Hl0. forwards HT': HT l0. unfolds state.
    rewrite dom_update_at_indom in *; auto.
    rewrite read_update. case_if*.
    subst. inverts HP as HF. applys* typing_val_after_write. }
Qed.

(** Lemma for typing preservation of [struct_access]. *)

Lemma follow_typ_access_field : forall C T1 π T2 Tfs f,
  typing_struct C T2 Tfs ->
  f \indom Tfs ->
  follow_typ C T1 π T2 ->
  follow_typ C T1 (π & (access_field T2 f)) Tfs[f].
Proof.
  introv HTs Hfin HF. gen C T1 T2 Tfs f. induction π; 
  intros; inverts HF as; rew_list; repeat constructors*.
Qed.

(** Lemma for typing preservation of [array_access]. *)

Lemma follow_typ_access_array : forall C os T1 π T2 i T,
  typing_array C T2 T os ->
  follow_typ C T1 π T2 ->
  follow_typ C T1 (π & access_array T2 i) T.
Proof.
  introv HTa HF. gen C os T1 T2 i T. induction π;
  intros; inverts HF; rew_list; repeat constructors*.
Qed.

(** Lemma for typing preservation of [new]. *)

Lemma uninitialized_val_typ : forall C T v φ,
  uninitialized C T v ->
  wf_typ C T ->
  typing_val C φ v T.
Proof.
  introv Hu Hwf. induction Hu; subst; try repeat constructors*.
  { introv Hi. applys~ H2. applys* wf_typing_array. }
  { introv Hf Hf'. forwards*: wf_typing_struct. }
Qed.


(* ---------------------------------------------------------------------- *)
(** Type preservation proof without changing φ *)

Theorem type_soundess_warmup : forall C LLC φ m t v T Γ S m',
  red C LLC S m t m' v -> 
  ~ is_error v ->
  typing C φ Γ t T ->
  state_typing C φ m ->
  stack_typing C φ Γ S ->
        typing_val C φ v T
    /\  state_typing C φ m'.
Proof.
  introv R He. gen φ T Γ. induction R; introv HT HM HS;
  try solve [ forwards*: He ; unfolds~ ].
  { (* val *)
    inverts* HT. }
  { (* val *)
    inverts* HT. }
  { (* if *)
    inverts HT.
    forwards* (HT1&HM1): IHR1.
    forwards* (HT2&HM2): IHR2.
    case_if*. }
  { (* let *)
    inverts HT. forwards* (HT1&HM1): IHR1. forwards* (HT2&HM2): IHR2.
    applys* stack_typing_ctx_add. }
  { (* binop *) 
    rename H3 into R. inverts HT; inverts* R. }
  { (* get *)
    splits*.
    { subst. inverts HT as HT. inverts HT as HT; simpls.  
      inverts HT. applys* typing_val_get. } }
  { (* set *) 
    subst. inverts HT as HT1 HT2. splits*.
    { inverts HT1 as HT1. inverts HT2 as HT2. 
      applys* state_typing_set. } }
  { (* new *) 
    admit. }
  { (* new_array *)
    admit. }
  { (* struct_access *) 
    subst. inverts HT as HTs HTfs HT.
    splits~.
    inverts HT as HT.
    simpls.
    inverts HT as Hφ.
    inverts Hφ as HF.
    repeat constructors~.
    applys~ follow_typ_access_field. }
  { (* array_access *) 
    inverts HT as HTa HT HTi. subst.
    inverts HT as HT. simpls.
    inverts HT as Hφ.
    inverts Hφ as HF.
    inverts HM as HD HM.
    repeat constructors~.
    applys* follow_typ_access_array. }
  { (* struct_get *) 
    subst. inverts HT as HTs Hfin HT.
    splits~.
    inverts HT as HT. simpls.
    inverts HT as HTs0 HD HT.
    forwards*: functional_typing_struct HTs HTs0.
    subst.
    applys~ HT. }
  { (* array_get *) 
    subst. inverts HT as HTa HT HTi.
    splits~.
    inverts HT as HT. simpls.
    inverts HT as HTa0 Hl HT.
    forwards* (HTeq&Hos): functional_typing_array HTa HTa0.
    subst.
    applys~ HT. }
  { (* ll_get *) 
    admit. }
  { (* ll_set *)
    admit. }
  { (* ll_new *)
    admit. }
  { (* ll_access *)
    admit. }
  { (* app 1 *) 
    forwards*: IHR2; inverts HT; forwards* (HTv1&Hm2): IHR1;
    try applys* not_is_error_args_1 ; repeat constructors*. }
  { (* app 2 *) 
    forwards*: IHR2; inverts HT; forwards* (HTv1&Hm2): IHR1;
    try applys* not_is_error_args_2 ; repeat constructors*. }
Qed.


(* ---------------------------------------------------------------------- *)
(** Typing state extension lemmas *)

Definition extends (φ:phi) (φ':phi) :=
      dom φ \c dom φ'
  /\  forall l, l \indom φ -> φ'[l] = φ[l].

(** φ <= φ *)

Lemma refl_extends : refl extends.
Proof.
  unfolds. intros. unfolds. splits~. applys~ incl_refl.
Qed.

(** φ1 <= φ2 /\ φ2 <= φ3 ===> φ1 <= φ3 *)

Lemma trans_extends : trans extends.
Proof.
  unfolds. introv H1 H2. unfolds extends. 
  destruct H1 as (HD1&H1). destruct H2 as (HD2&H2). splits~.
  { applys* @incl_trans. typeclass. }
  { introv Hl. rewrite~ <- H1. rewrite~ H2. rew_set in *. auto. }
Qed.

Hint Extern 1 (extends ?φ1 ?φ3) => 
  match goal with
  | H: extends ?φ1 ?φ2 |- _ => applys trans_extends H
  | H: extends ?φ2 ?φ3 |- _ => applys trans_extends H
  end.

(** Typing values from an extended φ. *)

Lemma extended_typing_val : forall C φ φ' v T,
  extends φ φ' ->
  typing_val C φ v T ->
  typing_val C φ' v T.
Proof.
  introv Hφ HT. gen φ'. induction HT; intros;
  try solve [ constructors* ].
  { inverts H. inverts Hφ. repeat constructors.
    { rew_set in *. auto. }
    { rewrite~ H2. } }
Qed.

(** Typing terms from an extended φ. *)

Lemma extended_typing : forall C φ φ' Γ t T,
  extends φ φ' ->
  typing C φ Γ t T ->
  typing C φ' Γ t T.
Proof.
  introv Hφ HT. gen φ'.
  induction HT; intros; subst; try solve [ constructors* ].
  { constructors.
    forwards*: extended_typing_val Hφ H. }
Qed.

(** Typing the stack from an extended φ. *)

Lemma extended_stack_typing : forall C φ φ' Γ S,
  extends φ φ' ->
  stack_typing C φ Γ S ->
  stack_typing C φ' Γ S.
Proof.
  introv Hφ HS. unfolds stack_typing.
  introv HxS HxΓ. forwards HT: HS HxS HxΓ.
  forwards~: extended_typing_val Hφ HT.
Qed.


(* ---------------------------------------------------------------------- *)
(** Type preservation theorem *)

Section TypeSoundness.

(** Theorem to prove by induction. *)

Theorem type_soundness_ind : forall C LLC φ m t v T Γ S m',
  red C LLC S m t m' v ->
  ~ is_error v ->
  typing C φ Γ t T ->
  state_typing C φ m ->
  stack_typing C φ Γ S ->
  exists φ',
        extends φ φ'
    /\  typing_val C φ' v T
    /\  state_typing C φ' m'.
Proof.
  introv R He. gen φ T Γ. induction R; introv HT HM HS;
  try solve [ forwards*: He ; unfolds~ ]. 
  { (* val *)
    exists φ. inverts* HT. splits~. applys~ refl_extends. }
  { (* var *)  
    exists φ. inverts* HT. simpls. splits*. applys~ refl_extends. }
  { (* if *) 
    inverts HT as Ht0 Ht1 Ht2. 
    forwards* (φ'&Hφ'&HT1&HM1): IHR1.
    forwards* (φ''&Hφ''&HT2&HM2): IHR2 He φ' T Γ.  
    case_if*; apply* extended_typing. 
    apply* extended_stack_typing. }
  { (* let *)
    inverts HT. 
    forwards* (φ'&Hφ'&HT1&HM1): IHR1.
    forwards* (φ''&Hφ''HT2&HM2): IHR2 He φ' T (Ctx.add z T1 Γ).
    { apply* extended_typing. }
    { applys* stack_typing_ctx_add. apply* extended_stack_typing. } }
  { (* binop *) 
    exists φ. lets: refl_extends φ. 
    inverts HT; inverts_head redbinop; splits*. }
  { (* get *)
    exists φ. splits*. 
    { applys~ refl_extends. } 
    { subst. inverts HT as HT. inverts HT as HT; simpls.  
      inverts HT. applys* typing_val_get. } }
  { (* set *)
    exists φ. subst. inverts HT as HT1 HT2. splits*.
    { applys~ refl_extends. }
    { inverts HT1 as HT1. inverts HT2 as HT2. 
      applys* state_typing_set. } }
  { (* new *) 
    exists φ[l:=T]. inverts HM as HD Hm1l. splits.
    { unfolds. splits.
      { rew_set. introv Hl0. unfolds phi.
        rewrite dom_update. set_prove. }
      { introv Hl0. unfolds phi. rew_reads~. 
        intros. subst. rewrite <- HD in Hl0.
        false*. } }
    { inverts HT. subst. repeat constructors.
      { unfolds phi. rewrite dom_update. set_prove. }
      { rew_reads. constructors~. } }
    { constructors.
      { subst m2. unfolds phi. 
        unfolds state. repeat rewrite dom_update.
        rewrite~ HD. }
      { introv Hl1. subst. rew_reads; intros.
        { subst. forwards*: uninitialized_val_typ C T v. }
        { forwards: Hm1l l0. 
          { unfolds state. rewrite~ indom_update_neq_eq in Hl1. }
          { applys* extended_typing_val. unfolds. splits.
            { unfolds phi. rewrite dom_update. set_prove. }
            { introv Hl2. rew_reads~. intros. subst.
              rewrite HD in *. false*. } } } } } }
  { (* new_array *) 
    inverts_head uninitialized. 
    inverts_head typing_array. subst. inverts HT.
    exists φ[l:=(typ_array T1 None)].
    splits.
    { unfolds. splits.
      { rew_set. introv Hx. unfolds phi.
        rewrite dom_update. set_prove. }
      { introv Hx. rew_reads~. intros. subst.
        inverts HM as HD HM. rewrite <- HD in Hx.
        false*. } }
    { repeat constructors.
      { unfolds phi. rewrite dom_update. set_prove. }
      { rew_reads. constructors~. } }
    { constructors.
      { inverts HM as HD HM. 
        unfolds phi. unfolds state. repeat rewrite dom_update.
        rewrite~ HD. }
      { introv Hl0. rew_reads; intros.
        { apply typing_val_array with (os:=None) (T:=T1). 
          { constructors~. }
          { introv HN. inverts HN. }
          { introv Hi. forwards Hu: H10 Hi.
             forwards*: uninitialized_val_typ Hu. } }
        { inverts HM as HD HM. unfolds state. rewrite dom_update in Hl0.
          forwards: HM l0. 
          { rew_set in Hl0. inverts* Hl0. }
          { applys* extended_typing_val. unfolds. splits.
            { unfolds phi. rewrite dom_update. set_prove. }
            { introv Hl1. rew_reads~. intros. subst.
              rewrite HD in *. false*. } } } } } }
  { (* struct_access *)
    subst. inverts HT as HTs Hfin HT. 
    exists φ. splits~.
    { applys~ refl_extends. }
    { inverts HT as HT. simpls.
      inverts HT as Hφ.
      inverts Hφ as HF.
      repeat constructors~.
      applys~ follow_typ_access_field. } }
  { (* array_access *)
    subst. inverts HT as HTa HT HTi.
    inverts HT as HT. simpls.
    inverts HT as Hφ.
    inverts Hφ as HF.
    exists φ. splits~.
    { applys~ refl_extends. }
    { repeat constructors~.
     applys* follow_typ_access_array. } }
  { (* struct_get *)
    subst. inverts HT as HTs Hfin HT. 
    exists φ. splits~.
    { applys~ refl_extends. }
    { inverts HT as HT. simpls.
      inverts HT as HTs' HD HT.
      forwards*: functional_typing_struct HTs HTs'.
      subst. applys~ HT. } }
  { (* array_get *)
    subst. inverts HT as HTa HT HTi.
    exists φ. splits~.
    { applys~ refl_extends. }
    { inverts HT as HT. simpls.
      inverts HT as HTa' Hl HT.
      forwards* (Heq1&Heq2): functional_typing_array HTa HTa'.
      subst. applys* HT. } }
  { (* ll_get *)
    admit. }
  { (* ll_set *)
    admit. }
  { (* ll_new *)
    admit. }
  { (* ll_access *)
    admit. }
  { (* args_1 *)
    inverts HT;
    forwards* (φ'&Hφ'&HTv1&Hm2): IHR1 φ Γ;
    try applys* not_is_error_args_1;
    forwards* (φ''&Hφ''&HTv2&Hm3): IHR2 φ' Γ;
    repeat constructors*;
    try applys* extended_typing;
    try applys* extended_stack_typing. }
  { (* args_2 *)
    inverts HT; try solve [ forwards* (φ'&Hφ'&HTv1&Hm2): IHR1 φ Γ;
    try applys* not_is_error_args_2;
    forwards* (φ''&Hφ''&HTv2&Hm3): IHR2 φ' Γ;
    try applys* extended_stack_typing; constructors*;
    try applys* extended_typing; constructors*; simpls;
    inverts HTv1; constructors*; 
    try inverts_head typing_struct;
    try inverts_head typing_array ].
    { forwards* (φ'&Hφ'&HTv1&Hm2): IHR1 φ Γ.
      applys* not_is_error_args_2.
      forwards* (φ''&Hφ''&HTv2&Hm3): IHR2 φ' Γ.
      { constructors*. applys* extended_typing.
        constructors*. }
      { applys* extended_stack_typing. } }
    { forwards* (φ'&Hφ'&HTv1&Hm2): IHR1 φ Γ.
      applys* not_is_error_args_2.
      forwards* (φ''&Hφ''&HTv2&Hm3): IHR2 φ' Γ.
      { constructors*. applys* extended_typing.
        constructors*. }
      { applys* extended_stack_typing. } } }
Unshelve. typeclass.
Qed.

(** Theorem from initial execution. *)

Theorem type_soundness : forall C LLC m t v T,
  red C LLC empty_stack empty_state t m v ->
  typing C empty_phi empty_gamma t T ->
  ~ is_error v ->
  exists φ,
        typing_val C φ v T
    /\  state_typing C φ m.
Proof.
  introv HR HT Hne.
  asserts Hm: (state_typing C \{} \{}). 
  { unfolds. lets HDe: @dom_empty. unfolds phi. splits.
    { rew_set; intuition; try solve
      [ false; forwards: @is_empty_inv x (dom \{});
        eauto; typeclass ]. }
    { introv Hl. false. forwards: @is_empty_inv l (dom \{});
      eauto; typeclass. } }
  asserts HS: (stack_typing C \{} nil nil).
  { unfolds. introv Hx1. false. }
  forwards* (φ&Hφ&HTv&Hm'): type_soundness_ind HR HT.
Qed.

End TypeSoundness.
