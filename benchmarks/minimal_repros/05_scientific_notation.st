(* Category 4: Scientific notation in REAL literals (e.g. 2E-3).
   Part of 38 syntax errors. *)

FUNCTION APPROX : REAL
VAR_INPUT
    X : REAL;
END_VAR
    IF ABS(X) < 2E-3 THEN
        APPROX := X;
    ELSE
        APPROX := X * 1.5E+2;
    END_IF;
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := APPROX(X := 0.001);
END_PROGRAM
