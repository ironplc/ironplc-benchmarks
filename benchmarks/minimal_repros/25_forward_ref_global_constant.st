(* P9999: VAR_GLOBAL CONSTANT not handled in declaration toposort.

   Using a VAR_GLOBAL CONSTANT in STRING[MY_LENGTH] type parameters
   fails because the analyzer's toposort pass does not handle
   VAR_GLOBAL CONSTANT declarations.

   In OSCAT, STRING_LENGTH and LIST_LENGTH are defined as VAR_GLOBAL
   CONSTANT and used throughout oscat.st. This is the primary blocker
   for full-mode compilation — it fails regardless of whether the
   constant is declared before or after its use.

   Error: P9999 — Not implemented at analyzer/src/xform_toposort_declarations.rs#L535
   Also causes: P4030 when compiled in isolation without the constant
   OSCAT functions affected: 18+ functions (full-mode blocker)

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/25_forward_ref_global_constant.st
*)

(* Case 1: constant declared AFTER use — matches oscat.st layout *)
FUNCTION MY_FUNC : STRING[MY_LENGTH]
VAR_INPUT
    str : STRING[MY_LENGTH];
END_VAR
    MY_FUNC := str;
END_FUNCTION

VAR_GLOBAL CONSTANT
    MY_LENGTH : INT := 250;
END_VAR

PROGRAM main
VAR
    result : STRING[250];
END_VAR
    result := MY_FUNC(str := 'hello');
END_PROGRAM

(* Note: if the above triggers a different error than P4030, try Case 2
   below which declares the constant BEFORE use but still fails.
   Uncomment Case 2 and comment out Case 1 to test. *)

(* Case 2: constant declared BEFORE use — still fails with P4030
VAR_GLOBAL CONSTANT
    MY_LENGTH : INT := 250;
END_VAR

FUNCTION MY_FUNC2 : STRING[MY_LENGTH]
VAR_INPUT
    str : STRING[MY_LENGTH];
END_VAR
    MY_FUNC2 := str;
END_FUNCTION

PROGRAM main
VAR
    result : STRING[250];
END_VAR
    result := MY_FUNC2(str := 'hello');
END_PROGRAM
*)
