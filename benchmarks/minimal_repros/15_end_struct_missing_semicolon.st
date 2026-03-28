(* Missing semicolon after END_STRUCT before END_TYPE.
   OSCAT consistently writes END_STRUCT without a trailing semicolon.

   Error: P0002 — Expected ';'. Found 'END_TYPE'
   OSCAT functions affected: CPOL, CSET, R2_SET, REAL_TO_FRAC,
     STATUS_TO_ESR, DT2_TO_SDT, DT_TO_SDT (via their TYPE dependencies)

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/15_end_struct_missing_semicolon.st
*)

TYPE COMPLEX :
STRUCT
    re : REAL;
    im : REAL;
END_STRUCT
END_TYPE

FUNCTION CPOL_RE : REAL
VAR_INPUT
    L : REAL;
    A : REAL;
END_VAR
    CPOL_RE := L * COS(A);
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := CPOL_RE(L := 1.0, A := 0.0);
END_PROGRAM
