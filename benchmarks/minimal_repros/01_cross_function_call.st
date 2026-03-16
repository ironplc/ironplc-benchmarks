(* Category 1: Cross-function calls
   Calling a user-defined function from within another user-defined function.
   Affects 49 OSCAT functions. *)

FUNCTION INNER : REAL
VAR_INPUT
    X : REAL;
END_VAR
    INNER := X * 2.0;
END_FUNCTION

FUNCTION OUTER : REAL
VAR_INPUT
    Y : REAL;
END_VAR
    OUTER := INNER(X := Y);
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := OUTER(Y := 3.0);
END_PROGRAM
