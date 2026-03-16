(* Category 9: LTIME type (Edition 3).
   Affects 1 OSCAT function. *)

FUNCTION USE_LTIME : LTIME
VAR_INPUT
    X : LTIME;
END_VAR
    USE_LTIME := X;
END_FUNCTION

PROGRAM main
VAR
    result : LTIME;
END_VAR
    result := USE_LTIME(X := LTIME#100ms);
END_PROGRAM
