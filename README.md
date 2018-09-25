# Verification of Data Layout Transformations in Coq

Data layout transformations such as array-of-structures to structure-of-arrays, peeling and splitting of records, can lead to significant performance improvement. Yet, these transformations are error-prone and hard to debug. In this work, we aim at formalizing in Coq the correctness of such transformations.

To that end, we consider a C-like language with arrays, records, and pointers. We assign this language both a high-level semantics, where record fields are accessed by name, and a low-level semantics, based on low-level pointers. Ultimately, transformations could be defined as type-directed source-to-source translations. For the moment, to simplify the proof, we describe them as relations, and prove a forward simulation result.

## Requirements
The only system requirements to be able to compile the files are:
- Coq 8.8.0.
- The [TLC Coq Library](https://gitlab.inria.fr/charguer/tlc) (version 4.05.0).

In order to install the last one we recommend doing it through OPAM and simply add
`
-R $HOME/.opam/4.05.0/lib/coq/user-contrib/TLC TLC
`
in your `_CoqProject` file.

## Authors

- Arthur Chargéraud ([@charguer](https://gitlab.inria.fr/charguer)).
- Ramon Fernández Mir ([@ramonfmir](https://github.com/ramonfmir)).

