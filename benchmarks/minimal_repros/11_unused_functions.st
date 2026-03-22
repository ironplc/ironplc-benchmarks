(* Demonstrates: multiple functions defined but only some are referenced.
   The compiler should compile this successfully by excluding unreferenced
   functions from codegen. Once supported, the compat test can include
   all of oscat.st and let the compiler tree-shake unused functions.

   Call graph:
     main -> OUTER -> INNER
     UNUSED_FUNC is defined but never called.
*)

FUNCTION INNER : REAL
VAR_INPUT
    X : REAL;
END_VAR
    INNER := X * 2.0;
END_FUNCTION

FUNCTION UNUSED_FUNC : REAL
VAR_INPUT
    X : REAL;
END_VAR
    (* This function is never called — compiler should skip it.
       It uses features that may not be implemented yet, but since
       it is unreferenced, compilation should still succeed. *)
    UNUSED_FUNC := SOME_UNDEFINED_FUNC(X) + 42.0;
END_FUNCTION

FUNCTION OUTER : REAL
VAR_INPUT
    A : REAL;
    B : REAL;
END_VAR
    OUTER := INNER(X := A) + B;
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := OUTER(A := 3.0, B := 1.0);
END_PROGRAM
