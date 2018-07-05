(**

Basic transformations.

*)


Set Implicit Arguments.

Require Export Semantics.


Hint Constructors red.

Open Scope list_scope.


Global Instance Inhab_trm : Inhab trm.
Proof using. apply (Inhab_of_val (trm_val val_unit)). Qed.

(* Initial typdefctx *)
Definition pos : typdef_struct := (\{})["x" := typ_int]["y" := typ_int]["z" := typ_int].
Definition C : typdefctx := (\{})["pos" := pos].

(* Final typdefctx *)
Definition struct_x : typdef_struct := (\{})["x" := typ_int].
Definition pos' : typdef_struct := (\{})["s" := (typ_struct "struct_x")]["y" := typ_int]["z" := typ_int].
Definition C' : typdefctx := (\{})["pos" := pos'].

(* Grouping transformation *)
Record group_tr := make_group_tr {
  group_tr_struct_name : typvar; (* Ts *)
  group_tr_fields : set field; (* {..f..} *)
  group_tr_new_struct_name : typvar; (* Tsg *)
  group_tr_new_struct_field : field (* fg *)
}.

Notation make_group_tr' := make_group_tr.

(* π ~ |π| *)
Inductive tr_accesses (gt:group_tr) : accesses -> accesses -> Prop :=
  | tr_accesses_nil : 
      tr_accesses gt nil nil
  | tr_accesses_array : forall π π' i,
      tr_accesses gt π π' ->
      tr_accesses gt ((access_array i)::π) ((access_array i)::π')
  | tr_accesses_field_group : forall π π' f fg Ts Tsg,
      tr_accesses gt π π' ->
      Ts = group_tr_struct_name gt ->
      Tsg = group_tr_new_struct_name gt ->
      f \in (group_tr_fields gt) ->
      fg = group_tr_new_struct_field gt ->
      tr_accesses gt ((access_field Ts f)::π) ((access_field Ts fg)::(access_field Tsg f)::π')
  | tr_accesses_field_other : forall T Ts π π' f,
      tr_accesses gt π π' ->
      Ts = group_tr_struct_name gt ->
      (T <> Ts \/ f \notin (group_tr_fields gt)) ->
      tr_accesses gt ((access_field T f)::π) ((access_field T f)::π').

(* v ~ |v| *)
Inductive tr_val (gt:group_tr) : val -> val -> Prop :=
  | tr_val_error :
      tr_val gt val_error val_error
  | tr_val_unit : 
      tr_val gt val_unit val_unit
  | tr_val_bool : forall b,
      tr_val gt (val_bool b) (val_bool b)
  | tr_val_int : forall i,
      tr_val gt (val_int i) (val_int i)
  | tr_val_double : forall d,
      tr_val gt (val_double d) (val_double d)
  | tr_val_abstract_ptr : forall l π π',
      tr_accesses gt π π' ->
      tr_val gt (val_abstract_ptr l π) (val_abstract_ptr l π')
  | tr_val_array : forall a a',
      length a = length a' ->
      (forall i, 
        index a i -> 
        tr_val gt a[i] a'[i]) -> 
      tr_val gt (val_array a) (val_array a')
  | tr_val_struct_group : forall Ts Tsg s s' fg fs sg,
      gt = make_group_tr Ts fs Tsg fg ->
      fs \c dom s ->  
      fg \notindom s ->
      dom s' = (dom s \- fs) \u \{fg} ->
      dom sg = fs ->
      (forall f,
        f \indom sg ->
        tr_val gt s[f] sg[f]) ->
      (forall f,       
        f \notin fs ->
        f \indom s ->
        tr_val gt s[f] s'[f]) ->
      binds s' fg (val_struct Tsg sg) ->
      tr_val gt (val_struct Ts s) (val_struct Ts s')
  | tr_val_struct_other : forall T s s',
      T <> group_tr_struct_name gt ->
      dom s = dom s' ->
      (forall f,
        index s f ->
        tr_val gt s[f] s'[f]) ->
      tr_val gt (val_struct T s) (val_struct T s').

Search map.

Axiom ctx_vars : forall A, Ctx.ctx A -> set var.

Axiom ctx_vars_eq_lookup_none : forall A (c1 c2:Ctx.ctx A) (x:var),
  ctx_vars c1 = ctx_vars c2 ->
  Ctx.lookup x c1 = None ->
  Ctx.lookup x c2 = None.

(* S ~ |S| *)
Inductive tr_stack (gt:group_tr) : stack -> stack -> Prop :=
  | tr_stack_intro : forall S S',
     ctx_vars S = ctx_vars S' ->
      (forall x v,
        Ctx.lookup x S = Some v ->
        (exists v', Ctx.lookup x S' = Some v' /\ tr_val gt v v')) ->
      tr_stack gt S S'.

(* m ~ |m| *)
Inductive tr_state (gt:group_tr) : state -> state -> Prop :=
  | tr_state_intro : forall m m',
      dom m = dom m' ->
      (forall l,
        index m l ->
        tr_val gt m[l] m'[l]) ->
      tr_state gt m m'.

(* t ~ |t| *)
Inductive tr_trm (gt:group_tr) : trm -> trm -> Prop :=
  | tr_trm_val : forall v v',
      tr_val gt v v' ->
      tr_trm gt (trm_val v) (trm_val v')
  | tr_trm_var : forall x,
      tr_trm gt (trm_var x) (trm_var x)
  | tr_trm_if : forall t1 t2 t3 t1' t2' t3',
      tr_trm gt t1 t1' ->
      tr_trm gt t2 t2' ->
      tr_trm gt t3 t3' ->
      tr_trm gt (trm_if t1 t2 t3) (trm_if t1' t2' t3')
  | tr_trm_let : forall x t1 t2 t1' t2',
      tr_trm gt t1 t1' ->
      tr_trm gt t2 t2' ->
      tr_trm gt (trm_let x t1 t2) (trm_let x t1' t2')
  | tr_trm_binop : forall v1 v2 v1' v2' r,
      tr_val gt v1 v1' ->
      tr_val gt v2 v2' ->
      r = (trm_app binop_add ((trm_val v1')::(trm_val v2')::nil)) ->
      tr_trm gt (trm_app binop_add ((trm_val v1)::(trm_val v2)::nil)) r
  (* Abstract heap operations *)
  | tr_trm_get : forall T l π π' r,
      tr_accesses gt π π' ->
      r = (trm_app (prim_get T) ((trm_val (val_abstract_ptr l π'))::nil)) ->
      tr_trm gt (trm_app (prim_get T) ((trm_val (val_abstract_ptr l π))::nil)) r
  | tr_trm_set : forall T v v' l π π' r,
      tr_accesses gt π π' ->
      tr_val gt v v' ->
      r = (trm_app (prim_set T) ((trm_val (val_abstract_ptr l π'))::(trm_val v')::nil)) ->
      tr_trm gt (trm_app (prim_set T) ((trm_val (val_abstract_ptr l π))::(trm_val v)::nil)) r
  | tr_trm_new : forall T v v' r,
      tr_val gt v v' ->
      r = (trm_app (prim_new T) ((trm_val v')::nil)) ->
      tr_trm gt (trm_app (prim_new T) ((trm_val v)::nil)) r
  | tr_trm_array_access : forall A v1 v2 v1' v2' r,
      tr_val gt v1 v1' ->
      tr_val gt v2 v2' ->
      r = trm_app (prim_array_access A) ((trm_val v1')::(trm_val v2')::nil) ->
      tr_trm gt (trm_app (prim_array_access A) ((trm_val v1)::(trm_val v2)::nil)) r
  (* Special case: struct access *)
  | tr_trm_struct_access_x : forall l π π' Tt Tg fs f fg a1 a2 r,
      tr_accesses gt π π' ->
      gt = make_group_tr Tt fs Tg fg ->
      f \in fs ->
      a1 = prim_struct_access Tg f ->
      a2 = prim_struct_access Tt fg ->
      r = trm_app a1 ((trm_app a2 ((trm_val (val_abstract_ptr l π'))::nil))::nil) ->
      tr_trm gt (trm_app (prim_struct_access Tt f) ((trm_val (val_abstract_ptr l π))::nil)) r
  | tr_trm_struct_access_other : forall Tt l π π' T f r,
      tr_accesses gt π π' ->
      Tt = group_tr_struct_name gt ->
      (T <> Tt \/ f \notin (group_tr_fields gt)) ->       
      r = (trm_app (prim_struct_access T f) ((trm_val (val_abstract_ptr l π'))::nil)) ->
      tr_trm gt (trm_app (prim_struct_access T f) ((trm_val (val_abstract_ptr l π))::nil)) r
  (* Args *)
  | tr_trm_args_1 : forall op t t',
      ~ is_val t ->
      tr_trm gt t t' ->
      tr_trm gt (trm_app op (t::nil)) (trm_app op (t'::nil))
  | tr_trm_args_2 : forall op v v' t t' ts,
      ~ is_val t ->
      tr_val gt v v' ->
      tr_trm gt t t' ->
      tr_trm gt (trm_app op ((trm_val v)::t::ts)) (trm_app op ((trm_val v')::t'::ts)).

Lemma index_of_index_length' : forall A (l' l : list A) i,
  index l' i ->
  length l' = length l ->
  index l i.
Proof.
  intros. rewrite index_eq_index_length in *.
  applys* index_of_index_length'.
Qed.

Hint Resolve index_of_index_length'.

(* Transformations are functions. *)
Theorem functional_tr_accesses : forall gt π π1 π2,
  tr_accesses gt π π1 ->
  tr_accesses gt π π2 ->
    π1 = π2.
Proof.
  introv H1 H2. gen π2. induction H1; intros;
  try solve [ inverts* H2 ; repeat fequals* ].
  { inverts H4; repeat fequals*;
    inverts H11; tryfalse. }
  { inverts H2; repeat fequals*;
    inverts H0; tryfalse. }
Qed.

Lemma tr_accesses_app : forall gt π1 π2 π1' π2',
  tr_accesses gt π1 π1' ->
  tr_accesses gt π2 π2' ->
  tr_accesses gt (π1 ++ π2) (π1' ++ π2').
Proof.
  introv Ha1 Ha2. gen π2 π2'. induction Ha1; intros;
  try solve [ subst ; forwards Ha': IHHa1 Ha2 ;
  repeat rewrite* <- List.app_comm_cons ; constructors* ].
  1: repeat rewrite* List.app_nil_l. 
Qed.

Theorem functional_tr_val : forall gt v v1 v2,
  tr_val gt v v1 ->
  tr_val gt v v2 ->
  v1 = v2.
Proof.
  introv H1 H2. gen v2. induction H1; intros; 
  try solve [ inverts H2 ; fequals* ].
  { inverts H2. fequals. applys* functional_tr_accesses. }
  { inverts H2. fequals. applys* eq_of_extens. math. }
  { admit. } (* extens lemma for maps *)
Admitted.

Hint Resolve functional_tr_val functional_tr_accesses.

Theorem functional_tr_trm : forall gt t t1 t2,
  tr_trm gt t t1 ->
  tr_trm gt t t2 ->
  t1 = t2.
Proof.
  introv H1 H2. gen t2. induction H1; intros;
  try solve [ inverts* H2 as ; introv HN ; forwards*: HN ];
  try solve [ inverts* H2 as ; intros ; subst* ; 
  repeat fequals* ; simpls ; contradiction ].
  { subst. inverts H5; repeat fequals; simpls*; 
    try contradiction; inverts* H9; contradiction. }
  { subst. inverts H3; repeat fequals; simpls*;
    try contradiction; inverts* H1; contradiction.  }
Qed.

Theorem functional_tr_stack : forall gt S S1 S2,
  tr_stack gt S S1 ->
  tr_stack gt S S2 ->
  S1 = S2.
Proof.
  admit. (* extens lemma for ctxts. *)
Admitted.

Theorem functional_tr_state : forall gt m m1 m2,
  tr_state gt m m1 ->
  tr_state gt m m2 ->
  m1 = m2.
Proof.
  admit. (* extens lemma for maps. *)
Admitted.

Lemma tr_stack_add : forall gt z v S v' S',
  tr_stack gt S S' ->
  tr_val gt v v' ->
  tr_stack gt (Ctx.add z v S) (Ctx.add z v' S').
Proof.
Admitted.

Hint Constructors tr_trm tr_val tr_accesses tr_state tr_stack 
                  read_accesses write_accesses.

Axiom in_union : forall A (x:A) (S1 S2:set A), 
        (x \in S1) \/ (x \in S2) -> 
        x \in (S1 \u S2).

Axiom in_setminus : forall A (x:A) (S1 S2: set A),
        x \in S1 -> 
        x \notin S2 -> 
        x \in (S1 \- S2).

Axiom not_tr_val_error : forall gt v1 v2, 
  tr_val gt v1 v2 -> 
  ~ is_error v2.

Axiom index_of_update_neq : forall A B (v:B) (l l':A) (m:map A B),
  index m[l:=v] l' ->
  l <> l' ->
  index m l'.

Axiom index_of_update_neq' : forall A (v:A) i i' (l:list A),
  index l[i:=v] i' ->
  i <> i' ->
  index l i'.

Lemma in_notin_neq : forall A (x y:A) (S:set A),
  x \in S ->
  y \notin S ->
  y <> x.
Admitted.

Axiom notin_notin_subset : forall A (x:A) (S1 S2:set A),
  S1 \c S2 ->
  x \notin S2 ->
  x \notin S1.

Lemma in_subset : forall A (x:A) (S1 S2:set A),
  S2 \c S1 ->
  x \in S2 ->
  x \in S1.
Admitted.
(*
intros. set_prove.
*)

Axiom in_single : forall A (x:A) (S:set A),
  S = '{x} ->
  x \in S.

Axiom union_eq : forall A (S1 S2 S3 S4:set A),
  S1 = S3 ->
  S2 = S4 ->
  S1 \u S2 = S3 \u S4.

Tactic Notation "rew_set" "*" := 
  rew_set; auto_star.

Lemma tr_read_accesses : forall gt v π v' π' w,
  tr_val gt v v' ->
  tr_accesses gt π π' ->
  read_accesses v π w ->
  (exists w',
      tr_val gt w w'
  /\  read_accesses v' π' w').
Proof.
  introv Hv Ha HR. gen gt v' π'. induction HR; intros.
  { (* nil *) 
    inverts Ha. exists* v'. } 
  { (* array_access *)
    inverts Ha as Ha. inverts Hv as Hl Htr.
    forwards Htra: Htr H. 
    forwards (w'&Hw'&Hπ'): IHHR Htra Ha.
    exists* w'. }
  { (* struct_access *) 
    inverts Ha as; inverts Hv as; 
    try solve [ intros ; false ].
    { (* one of the fields to group *) 
      introv HD1 Hgt HD2 HD3 Hsg Hfs HB Ha Hin.
      rewrite* Hgt in Hin. simpls.
      forwards Hsf: Hsg Hin.
      forwards Heq: read_of_binds H. 
      subst_hyp Heq.
      forwards (w'&Hw'&HR'): IHHR Hsf Ha.
      exists* w'. splits*.
      constructors*; rewrite Hgt; simpls*. 
      constructors*. applys* binds_of_indom_read. }
    { (* struct transformed but another field *) 
      introv HD1 HD2 HD3 Hsg Hfs HB Ha Hor.
      inverts Hor as Hf; simpl in Hf; tryfalse.
      forwards Hf': indom_of_binds H. typeclass.
      forwards Hsf: Hfs Hf Hf'.
      forwards Hv1: read_of_binds H. 
      subst_hyp Hv1.
      forwards (w'&Hw'&HR'): IHHR Hsf Ha.
      exists w'. splits*. constructors*. 
      applys* binds_of_indom_read.
      rewrite HD3. rew_set*. }
    { (* another struct *)
      intros Hn HD Hfs Ha Hor. 
      forwards Hidx: index_of_binds H. typeclass.
      forwards Hsf: Hfs Hidx. 
      forwards Heq: read_of_binds H.
      subst_hyp Heq. 
      forwards (w'&Hw'&HR'): IHHR Hsf Ha.
      exists w'. splits*. constructors*. 
      applys* binds_of_indom_read.
      rewrite <- HD. 
      rewrite* <- index_eq_indom. } }
Qed.

(*Ltac rew_dom_at_core tt := repeat rewrite dom_update_at_indom.
        Tactic Notation "rew_dom_at" := rew_dom_at_core tt.
        Tactic Notation "rew_dom_at" "*" := rew_dom_at; auto_star.*)

Lemma tr_write_accesses : forall v1 w gt π v1' π' w' v2,
  tr_val gt v1 v1' ->
  tr_val gt w w' ->
  tr_accesses gt π π' ->
  write_accesses v1 π w v2 ->
  (exists v2',
        tr_val gt v2 v2'
    /\  write_accesses v1' π' w' v2').
Proof.
  introv Hv1 Hw Ha HW. gen gt v1' w' π'. induction HW; intros.
  { (* nil *)
    inverts Ha. subst_hyp H. exists* w'. }
  { (* array_access *)
    inverts Ha as Ha. inverts Hv1 as Hl Htr.
    forwards Htra: Htr H.
    forwards (v2'&Hv2'&HW'): IHHW Htra Hw Ha.
    exists (val_array a'[i:=v2']).
    splits; constructors*.
    { (* val_array under tr *)
      rewrite H0. repeat rewrite* length_update. }
    { (* write_accesses of transformed array *) 
      introv Hi0. rewrite read_update_case. 
      { case_if*; subst_hyp H0.
        { subst_hyp C0. rewrites* LibListZ.read_update_same. }
        { forwards: index_of_update_neq' Hi0 C0. 
          rewrites* LibListZ.read_update_neq. } }
      { rewrite index_eq_index_length in *.
        rewrite H0 in Hi0. rewrite length_update in Hi0.
        rewrite* <- Hl. } } }
  { (* struct_access *)
    inverts Ha as; inverts Hv1 as;
    try solve [ intros ; false ].
    { (* one of the fields to group *) 
      introv HD1 Hgt HD2 HD3 Hsg Hfs HB Ha Hin.
      rewrite* Hgt in Hin. simpls.
      forwards Hsf: Hsg Hin.
      forwards Heq: read_of_binds H. 
      subst_hyp Heq.
      forwards (v2'&Hv2'&HW'): IHHW Hsf Hw Ha.
      remember (group_tr_struct_name gt) as T.
      exists (val_struct T s'[fg:=(val_struct Tsg sg[f:=v2'])]).
      splits.
      { substs. 
        applys tr_val_struct_group (sg[f:=v2']); try reflexivity; 
        repeat rewrite dom_update_at_indom; try typeclass;
        try solve [ applys* in_subset ].
        { forwards*: indom_of_binds HB. }
        { introv HD4. repeat rewrite read_update. case_if*. }
        { introv HD4 HD5. repeat rewrite read_update. 
          repeat case_if*; subst; contradiction. }
        { applys* binds_update_same. } }
      { constructors*; subst_hyp Hgt; simpls*.
        constructors*. applys* binds_of_indom_read. } }
    { (* struct transformed but another field *) 
      introv HD1 HD2 HD3 Hsg Hfs HB Ha Hor. 
      inverts Hor as Hf; simpl in Hf; tryfalse.
      forwards Hf': indom_of_binds H. typeclass.
      forwards Hsf: Hfs Hf Hf'.
      forwards Hv1: read_of_binds H. 
      subst_hyp Hv1.
      forwards (v2'&Hv2'&HW'): IHHW Hsf Hw Ha.
      exists (val_struct T s'[f:=v2']). splits.
      { applys* tr_val_struct_group; subst_hyp H0;
        try solve [ rewrite* dom_update_at_indom ].
        { repeat rewrite* dom_update_at_indom.
          rewrite HD3. applys* in_union. left.
          applys* in_setminus. }        
        { introv Hf0. rewrite read_update. case_if*.
          forwards: in_notin_neq Hf0 Hf. false. }
        { introv HD4 HD5. repeat rewrite read_update.
          case_if*. rewrite* dom_update_at_indom in HD5. }
        { applys* binds_update_neq.
          apply in_notin_neq with (S:=dom s1); auto. } }
      { constructors*.  applys* binds_of_indom_read.
        rewrite HD3. applys in_union. left.
        applys* in_setminus. } }
    { (* another struct *)
      intros Hn HD Hfs Ha Hor.
      forwards Hidx: index_of_binds H. typeclass.
      forwards Hsf: Hfs Hidx. 
      forwards Heq: read_of_binds H.
      subst_hyp Heq. 
      forwards (v2'&Hv2'&HW'): IHHW Hsf Hw Ha.
      exists (val_struct T s'[f:=v2']). splits.
      { constructors*; subst_hyp H0.
        { rewrite index_eq_indom in Hidx.
          rewrites* dom_update_at_indom.
          rewrite HD in Hidx.
          rewrites* dom_update_at_indom. }
        { introv Hif0. rewrite read_update. case_if*.
          { subst_hyp C0. rewrite* read_update_same. }
          { rewrite* read_update_neq. 
            forwards Hif0': index_of_update_neq Hif0 C0.
            forwards*: Hfs Hif0'. } } }
      { constructors*. applys* binds_of_indom_read.
        rewrite index_eq_indom in Hidx.
        rewrite* <- HD. } } }
Qed.

Lemma not_is_val_tr : forall gt t1 t2,
  ~ is_val t1 ->
  tr_trm gt t1 t2 ->
  ~ is_val t2.
Proof.
Admitted.

Lemma not_is_ptr_tr : forall gt p1 p2,
  ~ is_ptr p1 ->
  tr_trm gt p1 p2 ->
  ~ is_ptr p2.
Proof.
Admitted.

Lemma not_is_int_tr : forall gt t1 t2,
  ~ is_int t1 ->
  tr_trm gt t1 t2 ->
  ~ is_int t2.
Proof.
Admitted.

Lemma ptr_is_val : forall p,
  is_ptr p -> is_val p.
Proof.
Admitted.

(* Semantics preserved by tr. *)
Theorem red_tr: forall gt t t' v S S' m1 m1' m2,
  tr_trm gt t t' ->
  tr_stack gt S S' ->
  tr_state gt m1 m1' ->
  red S m1 t m2 v -> 
  ~ is_error v -> exists v' m2',
      tr_val gt v v'
  /\  tr_state gt m2 m2'
  /\  red S' m1' t' m2' v'.
Proof.
  introv Ht HS Hm1 HR He. gen t' S' m1'. induction HR; intros;
  try solve [ forwards*: He; unfolds* ].
  { (* var *)
    inverts Ht. inverts HS. 
    forwards: H1 H. inverts H2. exists* x0 m1'. }
  { (* val *)
    inverts Ht. exists* v' m1'. }
  { (* if *)
    inverts Ht as Hb HTrue HFalse. 
    forwards (v'&m2'&Hv'&Hm2'&HR3): IHHR1 Hb HS Hm1.
    introv HN. inverts HN.
    inverts* Hv'.
    forwards* (vr'&m3'&Hvr'&Hm3'&HR4): IHHR2 HS Hm2'. 2: 
    exists* vr' m3'. case_if*. } 
  { (* let *)
    inverts Ht as Ht1 Ht2.
    forwards* (v'&m2'&Hv'&Hm2'&HR3): IHHR1 Ht1 HS Hm1.
    forwards HS': tr_stack_add z HS Hv'.
    forwards* (vr'&m3'&Hvr'&Hm3'&HR4): IHHR2 Ht2 HS' Hm2'.
    forwards: not_tr_val_error Hv'.
    exists* vr' m3'. }
  { (* binop *)
    inverts Ht as Ht1 Ht2.
    inverts H. 2: forwards*: Ht1.
    exists (n1 + n2)%Z m1'. 
    splits*. constructors*. 
    inverts Ht1. inverts Ht2. constructors*. }
  { (* get *)
    subst. inverts Ht as Hp. 2: { forwards*: Hp. } 
    inverts Hm1 as HD Htrm. 
    inverts H0 as Hb Ha. forwards* Hi: index_of_binds Hb.
    forwards Htrml: Htrm Hi.
    forwards: read_of_binds Hb. subst_hyp H.
    forwards (w'&Hw'&Ha'): tr_read_accesses Htrml Hp Ha.
    exists w' m1'. splits*. 
    constructors*. constructors*.
    applys* binds_of_indom_read. 
    rewrite <- HD at 1.
    forwards*: indom_of_binds Hb. }
  { (* set *)
    subst. inverts Ht as Ha Hv. inverts Hm1 as HD Htrm.
    inverts H2 as Hb HW. forwards Hi: index_of_binds Hb.
    typeclass. forwards Htrml: Htrm Hi.
    forwards Heq: read_of_binds Hb. subst_hyp Heq.
    forwards (w'&Hw'&HW'): tr_write_accesses Htrml Hv Ha HW.
    exists val_unit m1'[l:=w']. splits*.
    { constructors. 
      { rewrite index_eq_indom in Hi.
        forwards* HDm1: dom_update_at_indom Hi.
        rewrite HD in Hi at 1.
        forwards* HDm1': dom_update_at_indom Hi.
        rewrite* HDm1. rewrite* HDm1'. }
      { introv Hi'. do 2 rewrites read_update.
        case_if*. 
        forwards Hi'': index_of_update_neq Hi' C0. 
        forwards*: Htrm Hi''. } }
    { constructors*. applys* not_tr_val_error.
      constructors*. applys* binds_of_indom_read.
      rewrite <- HD at 1. forwards*: indom_of_binds Hb. }
    { forwards*: Ha. } }
  { (* new *) 
    inverts Ht as Hv. 
    inverts Hm1 as HD Htrm.
    subst_hyp H1.
    exists (val_abstract_ptr l0 nil) m1'[l0:=v'].
    splits*.
    { constructors. 
      { unfold state. repeat rewrite dom_update. 
        applys* union_eq.  }
      { introv Hi. rewrite read_update. case_if*.
        { subst_hyp C0. rewrite* read_update_same. }
        { rewrite* read_update_neq. 
          forwards Hi': index_of_update_neq Hi C0.
          forwards*: Htrm Hi'. } } }
    { constructors*. rewrite* <- HD. }
    { forwards*: Hv. } }
  { (* struct_access *) 
    subst. inverts Ht as; inverts Hm1 as HD Htrm.
    { (* accessing grouped field *)
      introv Ha Hf. 
      remember (access_field T fg) as a1.
      remember (access_field Tg f) as a2.
      exists (val_abstract_ptr l (π'++(a1::a2::nil))) m1'.
      splits*.
      { constructors. applys* tr_accesses_app. subst*. }
      { subst. applys* red_args_1. applys* red_struct_access.
        fequals*. rewrite* <- List.app_assoc. } }
    { (* accessing another field *) 
      introv Ha Hor. subst.
      exists (val_abstract_ptr l (π'++(access_field T f :: nil))) m1'.
      splits; constructors*. applys* tr_accesses_app. }
    { introv HN. forwards*: HN. } }
  { (* array_access *)
    subst. inverts Ht as Ht Hti. 
    inverts Ht as Ha. 
    inverts Hti as Hv.
    inverts Hm1 as HD Htrm.
    exists (val_abstract_ptr l (π'++(access_array i::nil))) m1'. 
    splits; constructors*. applys* tr_accesses_app.
    { forwards*: Ht. }  }
  { (* args_1 *) 
    inverts Ht; try solve [ forwards*: H ].
    forwards* (v'&m2'&Hv'&Hm2'&HR'): IHHR1. 
    { admit. }
    inverts HR2.
    { inverts H6. inverts Hv'. forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2.
      exists v'' m3'. splits*. applys* red_args_1. applys* not_is_val_tr. }
    { forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2. exists v'' m3'. splits*.
      applys* red_args_1. applys* not_is_val_tr. }

    { (*inverts H6. inverts Hv'. forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2.
      { tests CT: (T = (group_tr_struct_name gt)).
          { tests Cf: (f \in (group_tr_fields gt)).
            { admit. }
            { applys* tr_trm_struct_access_other. } }
          { constructors*. } }
      { exists v'' m3'. splits*. constructors*. applys* not_is_val_tr. }*) admit. }

    { forwards*: H7. }

    { forwards*: He. unfolds*. }
    { forwards*: He. unfolds*. }
    { forwards*: He. unfolds*. }
    { forwards*: He. unfolds*. }
   (*
      exists v'' m3'. splits*. applys* red_args_1. applys* not_is_val_tr. }


    forwards* (v''&m3'&Hv''&Hm3'&HR''): IHHR2.
    {  }

    { inverts* HR2; try solve [ forwards*: He ; unfolds* ].
        { inverts H6. inverts Hv'. applys* tr_trm_get. }
        { inverts H6. inverts Hv'. tests CT: (T = (group_tr_struct_name gt)).
          { tests Cf: (f \in (group_tr_fields gt)).
            {  }
            { applys* tr_trm_struct_access_other. } }
          { applys* tr_trm_struct_access_other. } } } } }
    exists v'' m3'. splits*. constructors*.
    applys* not_is_val_tr.*) }
  { (* args_2 *) 
    admit. }
Qed.
























