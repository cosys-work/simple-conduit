Require Import ZArith Permutation Omega List Classical_sets.
Require Import FunctionalExtensionality.
Require Export CpdtTactics.

Axiom prop_ext: ClassicalFacts.prop_extensionality.

Implicit Arguments prop_ext.

Ltac inv H := inversion H; subst; clear H.

(* Set Implicit Arguments. *)

Axiom ext_eq : forall {T1 T2 : Type} (f1 f2 : T1 -> T2),
  (forall x, f1 x = f2 x) -> f1 = f2.

Theorem ext_eqS : forall (T1 T2 : Type) (f1 f2 : T1 -> T2),
  (forall x, f1 x = f2 x) -> f1 = f2.
Proof. intros; rewrite (ext_eq f1 f2); auto. Qed.

Hint Resolve ext_eq.
Hint Resolve ext_eqS.

Ltac ext_eq := (apply ext_eq || apply ext_eqS); intro.
Ltac crush_ext := (intros; ext_eq; crush); intro.

Definition id {X} (a : X) : X := a.

Theorem id_x : forall {A} (f : A -> A) (x : A),
  f = id -> f x = x.
Proof. crush. Defined.

Definition compose {A B C}
  (f : B -> C) (g : A -> B) (x : A) : C := f (g x).

Notation "f ∘ g" := (compose f g) (at level 69, right associativity).

Theorem comp_left_id : forall {A B C D} (f : C -> D) (g : B -> C) (h : A -> B),
  id ∘ f = f.
Proof. crush. Defined.

Theorem comp_id_right : forall {A B C D} (f : C -> D) (g : B -> C) (h : A -> B),
  f ∘ id = f.
Proof. crush. Defined.

Theorem comp_assoc : forall {A B C D} (f : C -> D) (g : B -> C) (h : A -> B),
  f ∘ g ∘ h = (f ∘ g) ∘ h.
Proof. crush. Defined.

Theorem uncompose : forall {A B C} (f : B -> C) (g : A -> B) (x : A) (y : C),
  (f ∘ g) x = f (g x).
Proof. crush. Defined.

Theorem compose_x : forall {A B C} (f : B -> C) (g : A -> B) (x : A) (y : C),
  (f ∘ g) x = y -> f (g x) = y.
Proof. crush. Defined.

Class Isomorphism X Y :=
{ to   : X -> Y
; from : Y -> X

; iso_to   : from ∘ to = id
; iso_from : to ∘ from = id
}.
  Arguments to       {X} {Y} {Isomorphism} x.
  Arguments from     {X} {Y} {Isomorphism} x.
  Arguments iso_to   {X} {Y} {Isomorphism}.
  Arguments iso_from {X} {Y} {Isomorphism}.

Hint Resolve id_x.
Hint Resolve compose_x.
Hint Resolve iso_to.
Hint Resolve iso_from.

Notation "X ≅ Y" := (Isomorphism X Y) (at level 50) : type_scope.
Notation "x |≅| y" := (from x = y /\ to y = x) (at level 50).

Theorem iso_to_x : forall {X Y} {iso : X ≅ Y} (x : X),
  from (to x) = x.
Proof. crush. Defined.

Theorem iso_from_x : forall {X Y} {iso : X ≅ Y} (y : Y),
  to (from y) = y.
Proof. crush. Defined.

Hint Resolve iso_to_x.
Hint Resolve iso_from_x.

(* Even though we have the Category class in Category.v, the Functors
   and Monads I'm interested in reasoning about are all endofunctors on
   Coq, so there is no reason to carry around that extra machinery. *)

Class Functor (F : Type -> Type) :=
{ fobj := F
; fmap : forall {X Y}, (X -> Y) -> F X -> F Y

; fun_identity : forall {X}, fmap (@id X) = id
; fun_composition : forall {X Y Z} (f : Y -> Z) (g : X -> Y),
    fmap f ∘ fmap g = fmap (f ∘ g)
}.
  Arguments fmap            [F] [Functor] [X] [Y] f g.
  Arguments fun_identity    [F] [Functor] [X].
  Arguments fun_composition [F] [Functor] [X] [Y] [Z] f g.

Hint Resolve fun_identity.
Hint Resolve fun_composition.

Notation "f <$> g" := (fmap f g) (at level 68, left associativity).

Theorem fun_identity_x
  : forall (F : Type -> Type) (app_dict : Functor F) {X} (x : F X),
  fmap id x = id x.
Proof. crush. Defined.

Hint Resolve fun_identity_x.

Theorem fun_composition_x
  : forall (F : Type -> Type) (app_dict : Functor F)
      {X Y Z} (f : Y -> Z) (g : X -> Y) (x : F X),
  f <$> (g <$> x) = (f ∘ g) <$> x.
Proof. intros. rewrite <- fun_composition. reflexivity.  Defined.

Hint Resolve fun_composition_x.

Global Instance Functor_Isomorphism
  {F : Type -> Type} {app_dict : Functor F} {A B} (iso : A ≅ B)
  : F A ≅ F B :=
{ to   := fmap to
; from := fmap from
}.
Proof.
  - rewrite fun_composition. rewrite iso_to. crush.
  - rewrite fun_composition. rewrite iso_from. crush.
Defined.

Reserved Notation "f <*> g" (at level 68, left associativity).

Class Applicative (F : Type -> Type) :=
{ is_functor :> Functor F

; eta : forall {X}, X -> F X
; apply : forall {X Y}, F (X -> Y) -> F X -> F Y
    where "f <*> g" := (apply f g)

; app_identity : forall {X}, apply (eta (@id X)) = id
; app_composition : forall {X Y Z} (v : F (X -> Y)) (u : F (Y -> Z)) (w : F X),
    eta compose <*> u <*> v <*> w = u <*> (v <*> w)
; app_homomorphism : forall {X Y} (x : X) (f : X -> Y),
    eta f <*> eta x = eta (f x)
; app_interchange : forall {X Y} (y : X) (u : F (X -> Y)),
    u <*> eta y = eta (fun f => f y) <*> u
; app_fmap_unit : forall {X Y} (f : X -> Y), apply (eta f) = fmap f
}.

Hint Resolve app_identity.
Hint Resolve app_composition.
Hint Resolve app_homomorphism.
Hint Resolve app_interchange.
Hint Resolve app_fmap_unit.

Notation "f <*> g" := (apply f g) (at level 68, left associativity).

Theorem app_identity_x
  : forall {F : Type -> Type} {app_dict : Applicative F}
      {X} {x : F X}, apply (eta (@id X)) x = id x.
Proof.
  intros. rewrite app_fmap_unit. apply fun_identity_x.
Defined.

Notation "[| f x y .. z |]" := (.. (f <$> x <*> y) .. <*> z)
    (at level 9, left associativity, f at level 9,
     x at level 9, y at level 9, z at level 9).

Theorem app_homomorphism_2
  : forall {F : Type -> Type} {app_dict : Applicative F}
      {X Y Z} (x : X) (y : Y) (f : X -> Y -> Z),
  f <$> eta x <*> eta y = eta (f x y).
Proof.
  intros.
  rewrite <- app_homomorphism.
  rewrite <- app_homomorphism.
  rewrite app_fmap_unit. reflexivity.
Defined.

Hint Resolve app_homomorphism_2.

Definition flip {X Y} (x : X) (f : X -> Y) : Y := f x.

Theorem app_flip
  : forall {F : Type -> Type} {app_dict : Applicative F}
      {X Y} (x : F X) (f : X -> Y),
  eta f <*> x = eta flip <*> x <*> eta f.
Proof.
  intros. rewrite app_interchange.
  rewrite <- app_composition.
  rewrite app_fmap_unit.
  rewrite app_fmap_unit.
  rewrite app_homomorphism_2.
  unfold compose.
  rewrite app_fmap_unit. reflexivity.
Defined.

Definition app_unit {F : Type -> Type} {app_dict : Applicative F}
  : F unit := eta tt.

Inductive Tuple X Y : Type :=
  | Pair : X -> Y -> Tuple X Y.

Definition fst {X Y} (p : Tuple X Y) : X :=
  match p with | Pair x _ => x end.

Definition snd {X Y} (p : Tuple X Y) : Y :=
  match p with | Pair _ x => x end.

Global Instance LTuple_Isomorphism {A} : A ≅ Tuple unit A :=
{ to   := Pair unit A tt
; from := snd
}.
Proof. crush. crush_ext. Defined.

Global Instance RTuple_Isomorphism {A} : A ≅ Tuple A unit :=
{ to   := fun x => Pair A unit x tt
; from := fst
}.
Proof. crush_ext. crush_ext. Defined.

Definition tuple_swap_a_bc_to_ab_c {A B C} (x : Tuple A (Tuple B C))
  : Tuple (Tuple A B) C :=
  match x with
  | Pair a (Pair b c) => Pair (Tuple A B) C (Pair A B a b) c
  end.

Definition tuple_swap_ab_c_to_a_bc {A B C} (x : Tuple (Tuple A B) C)
  : Tuple A (Tuple B C) :=
  match x with
  | Pair (Pair a b) c => Pair A (Tuple B C) a (Pair B C b c)
  end.

Global Instance TupleAssoc_Isomorphism {A B C}
  : Tuple A (Tuple B C) ≅ Tuple (Tuple A B) C :=
{ to   := tuple_swap_a_bc_to_ab_c
; from := tuple_swap_ab_c_to_a_bc
}.
Proof. crush_ext. crush_ext. Defined.

Definition uncurry {X Y Z} (f : X -> Y -> Z) (xy : Tuple X Y) : Z :=
  match xy with Pair x y => f x y end.

Theorem uncurry_works : forall {X Y Z} (x : X) (y : Y) (f : X -> Y -> Z),
  uncurry f (Pair X Y x y) = f x y.
Proof. crush. Defined.

Theorem uncurry_under_functors
  : forall {F : Type -> Type} {app_dict : Applicative F}
      {X Y Z} (x : X) (y : Y) (f : X -> Y -> Z),
  uncurry f <$> eta (Pair X Y x y) = eta (f x y).
Proof.
  intros. rewrite <- app_fmap_unit.
  rewrite app_homomorphism. crush.
Defined.

Definition app_merge {X Y Z W} (f : X -> Y) (g : Z -> W)
  (t : Tuple X Z) : Tuple Y W  :=
  match t with Pair x z => Pair Y W (f x) (g z) end.

Notation "f *** g" := (app_merge f g) (at level 68, left associativity).

Definition app_prod {F : Type -> Type} {app_dict : Applicative F}
  {X Y} (x : F X) (y : F Y) : F (Tuple X Y) := Pair X Y <$> x <*> y.

Notation "f ** g" := (app_prod f g) (at level 68, left associativity).

Ltac rewrite_app_homomorphisms :=
  (repeat (rewrite <- app_fmap_unit);
   rewrite app_homomorphism;
   repeat (rewrite app_fmap_unit)).

Theorem app_embed
  : forall {F : Type -> Type} `{Applicative F}
      {G : Type -> Type} `{Applicative G}
      {X Y} (x : G (X -> Y)) (y : G X),
  eta (x <*> y) = eta apply <*> eta x <*> eta y.
Proof.
  intros.
  rewrite_app_homomorphisms.
  rewrite <- app_homomorphism.
  rewrite <- app_fmap_unit. reflexivity.
Defined.

Theorem app_eta_inj
  : forall {F : Type -> Type} `{Applicative F}
      {X} (x y : X),
  x = y -> eta x = eta y.
Proof. crush. Defined.

Theorem app_naturality
  : forall (F : Type -> Type) (app_dict : Applicative F)
      A B C D (f : A -> C) (g : B -> D) (u : F A) (v : F B),
  fmap (f *** g) (u ** v) = fmap f u ** fmap g v.
Proof.
  intros. unfold app_prod, app_merge.
  (* How can we make progress from here? *)
Abort.

Theorem app_left_identity
  : forall (F : Type -> Type) (app_dict : Applicative F) A (v : F A)
      (isoF : F (Tuple unit A) ≅ F A),
  app_prod app_unit v |≅| v.
Proof.
  (* Prove the app identity *)
  intros. unfold app_prod, app_unit. rewrite_app_homomorphisms.

  (* Prove that the result is isomorphic to v *)
  assert (fmap (Pair unit A tt) = to). reflexivity. rewrite H.
  split. apply iso_to_x. reflexivity.
Defined.

Theorem app_right_identity
  : forall (F : Type -> Type) (app_dict : Applicative F)
      A (v : F A) (isoF : F (Tuple A unit) ≅ F A),
  app_prod v app_unit |≅| v.
Proof.
  intros. unfold app_prod, app_unit.
  rewrite <- app_fmap_unit.
  rewrite app_interchange.
  rewrite <- app_composition.
  rewrite app_homomorphism.
  rewrite app_homomorphism.
  rewrite app_fmap_unit.
  unfold compose.

  assert (fmap (fun x => Pair A unit x tt) = to). reflexivity.
  split. rewrite H. apply iso_to_x. reflexivity.
Defined.

Theorem app_associativity
  : forall (F : Type -> Type) (app_dict : Applicative F)
      A B C (u : F A) (v : F B) (w : F C)
      (iso : F (Tuple (Tuple A B) C) ≅ F (Tuple A (Tuple B C))),
  app_prod u (app_prod v w) |≅| app_prod (app_prod u v) w.
Proof.
  intros. unfold app_prod.
  (* I do not know how to proceed from here. *)
Abort.

Theorem fmap_unit_eq
  : forall (F : Type -> Type) (app_dict : Applicative F)
      A B (f : A -> B) (x : A),
  fmap f (eta x) = eta (f x).
Proof.
  intros.
  rewrite <- app_fmap_unit.
  rewrite app_interchange.
  rewrite app_homomorphism.
  reflexivity.
Defined.

Theorem app_split
  : forall (F : Type -> Type) (app_dict : Applicative F)
      A B C (f : A -> B -> C) (x : F A) (y : F B),
  f <$> x <*> y = uncurry f <$> (x ** y).
Proof.
  intros. unfold app_prod.
  repeat (rewrite <- app_fmap_unit).
  repeat (rewrite <- app_composition; f_equal).
  repeat (rewrite app_homomorphism).
  crush.
Defined.

Definition liftA2 {F : Type -> Type} {app_dict : Applicative F}
  {A B C} (f : A -> B -> C) (x : F A) (y : F B) : F C := f <$> x <*> y.

Class Monad (M : Type -> Type) :=
{ is_applicative :> Applicative M

; mu : forall {X}, M (M X) -> M X

; monad_law_1 : forall {X}, mu ∘ fmap mu = (@mu X) ∘ mu
; monad_law_2 : forall {X}, mu ∘ fmap (@eta M is_applicative X) = id
; monad_law_3 : forall {X}, (@mu X) ∘ eta = id
; monad_law_4 : forall {X Y} (f : X -> Y), eta ∘ f = fmap f ∘ eta
; monad_law_5 : forall {X Y} (f : X -> Y), mu ∘ fmap (fmap f) = fmap f ∘ mu
}.

Definition bind {M X Y} {m_dict : Monad M}
  (x : M X) (f : (X -> M Y)) : M Y := mu (fmap f x).

Notation "m >>= f" := (bind m f) (at level 67, left associativity).

Theorem monad_law_1_x
  : forall (M : Type -> Type) (m_dict : Monad M) A (x : M (M (M A))),
  mu (fmap mu x) = (@mu M m_dict A) (mu x).
Proof.
  intros.
  assert (mu (fmap mu x) = (mu ∘ fmap mu) x). unfold compose. reflexivity.
  assert (mu (mu x) = (mu ∘ mu) x). unfold compose. reflexivity.
  rewrite H. rewrite H0. rewrite monad_law_1. reflexivity.
Defined.

Theorem monad_law_2_x
  : forall (M : Type -> Type) (m_dict : Monad M) A (x : M A),
  mu (fmap (@eta M is_applicative A) x) = x.
Proof.
  intros.
  assert (mu (fmap eta x) = (mu ∘ fmap eta) x). unfold compose. reflexivity.
  rewrite H. rewrite monad_law_2. reflexivity.
Defined.

Theorem monad_law_3_x
  : forall (M : Type -> Type) (m_dict : Monad M) A (x : M A),
  (@mu M m_dict A) (eta x) = x.
Proof.
  intros.
  assert (mu (eta x) = (mu ∘ eta) x). unfold compose. reflexivity.
  rewrite H. rewrite monad_law_3. reflexivity.
Defined.

Theorem monad_law_4_x
  : forall (M : Type -> Type) (m_dict : Monad M) A B (f : A -> B) (x : A),
  eta (f x) = fmap f (eta x).
Proof.
  intros.
  assert (eta (f x) = (eta ∘ f) x). unfold compose. reflexivity.
  assert (fmap f (eta x) = (fmap f ∘ eta) x). unfold compose. reflexivity.
  rewrite H. rewrite H0. rewrite monad_law_4. reflexivity.
Defined.

Theorem monad_law_5_x
  : forall (M : Type -> Type) (m_dict : Monad M)
      A B (f : A -> B) (x : M (M A)),
  mu (fmap (fmap f) x) = fmap f (mu x).
Proof.
  intros.
  assert (mu (fmap (fmap f) x) = (mu ∘ fmap (fmap f)) x).
    unfold compose. reflexivity.
  assert (fmap f (mu x) = (fmap f ∘ mu) x). unfold compose. reflexivity.
  rewrite H. rewrite H0. rewrite monad_law_5. reflexivity.
Defined.

(* Composition of functors produces a functor. *)

Global Instance Compose_Functor
  `{F : Functor} `{G : Functor}
  : Functor (fun X => fobj (fobj X))  :=
{ fmap := fun X Y f x => fmap (@fmap fobj G X Y f) x
}.
Proof.
  - (* fun_identity *)
    intros. ext_eq.
    rewrite fun_identity.
    rewrite fun_identity. reflexivity.

  - (* fun_composition *)
    intros. ext_eq.
    rewrite fun_composition.
    rewrite fun_composition. reflexivity.
Defined.

(* Composition of applicatives produces an applicative. *)

Global Instance Compose_Applicative
  `{F : Applicative} `{G : Applicative}
  : Applicative (fun X => fobj (fobj X))  :=
{ is_functor := Compose_Functor
; eta := fun X x => eta (eta x)
; apply := fun X Y f x => apply (fmap (@apply fobj G X Y) f) x
}.
Proof.
  - (* app_identity *)
    intros. ext_eq.
    rewrite <- app_fmap_unit. rewrite app_homomorphism.
    rewrite app_identity. rewrite app_fmap_unit.
    rewrite fun_identity. reflexivity.

  - (* app_composition *)
    intros. repeat (rewrite <- app_fmap_unit).
    rewrite app_homomorphism. admit.

  - (* app_homomorphism *)
    intros. rewrite <- app_fmap_unit.
    repeat (rewrite app_homomorphism). reflexivity.

  - (* app_interchange *)
    intros.
    repeat (rewrite <- app_fmap_unit).
    rewrite app_interchange.
    rewrite_app_homomorphisms.
    rewrite fun_composition_x.
    unfold compose. f_equal. ext_eq.
    rewrite <- app_fmap_unit.
    rewrite app_interchange. reflexivity.

  - (* app_fmap_unit *)
    intros. rewrite_app_homomorphisms. reflexivity.
Defined.

(* Composition of monads is a monad. *)

(*
Global Instance Either_Monad {E} : Monad (Either E) :=
{ is_applicative := Either_Applicative
; mu := @Either_join E
}.
Proof.
  (* monad_law_1 *) crush_ext.
  (* monad_law_2 *) crush_ext.
  (* monad_law_3 *) crush_ext.
  (* monad_law_4 *) crush.
  (* monad_law_5 *) crush_ext.
Defined.
*)