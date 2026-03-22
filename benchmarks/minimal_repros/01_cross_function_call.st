(* Category 1: Calling a function not defined in the compilation unit.
   compile.rs#L2116 — 49 OSCAT functions affected.
   e.g. CTRL_IN calls DEAD_ZONE, but DEAD_ZONE is not in the same file.
   NOTE: this works when both functions are in the same file. *)

FUNCTION OUTER : REAL
VAR_INPUT
    A : REAL;
    B : REAL;
    C : REAL;
END_VAR
    (* DEAD_ZONE is not defined here — triggers the error *)
    OUTER := DEAD_ZONE(A - B, C);
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := OUTER(A := 10.0, B := 3.0, C := 1.0);
END_PROGRAM
