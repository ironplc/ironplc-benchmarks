(* Category 8: REF_TO / pointer dereference (Edition 3).
   Affects 45 OSCAT functions. *)

FUNCTION DEREF_ADD : REAL
VAR_INPUT
    P : REF_TO REAL;
    X : REAL;
END_VAR
    DEREF_ADD := P^ + X;
END_FUNCTION

PROGRAM main
VAR
    val : REAL := 10.0;
    result : REAL;
END_VAR
    result := DEREF_ADD(P := REF(val), X := 5.0);
END_PROGRAM
