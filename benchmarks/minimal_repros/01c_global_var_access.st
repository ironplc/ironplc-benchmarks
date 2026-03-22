(* Category 1c: Accessing an undefined global variable (dot notation).
   compile.rs#L3307 — 14 OSCAT functions affected.
   e.g. C_TO_K uses phys.T0, GAMMA uses math.PI2.
   Also: compile.rs#L3302 for global array indexing (math.FACTS[X]). *)

FUNCTION MY_FUNC : REAL
VAR_INPUT
    X : REAL;
END_VAR
    MY_FUNC := X - phys.T0;
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := MY_FUNC(X := 100.0);
END_PROGRAM
