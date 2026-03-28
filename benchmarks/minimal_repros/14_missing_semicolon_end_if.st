(* Missing semicolon after END_IF before END_FUNCTION.
   The --allow-missing-semicolon flag does not cover this case.

   Error: P0002 — Expected ';'. Found 'END_FUNCTION'
   OSCAT functions affected: SCALE_B

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/14_missing_semicolon_end_if.st
*)

FUNCTION SCALE_B : REAL
VAR_INPUT
    X : BYTE;
    I_LO : BYTE;
    I_HI : BYTE;
    O_LO : REAL;
    O_HI : REAL;
END_VAR
    IF I_HI = I_LO THEN
        SCALE_B := O_LO;
    ELSE
        SCALE_B := O_HI;
    END_IF

END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := SCALE_B(X := BYTE#1, I_LO := BYTE#0, I_HI := BYTE#10, O_LO := 0.0, O_HI := 100.0);
END_PROGRAM
