(* oscat_expn.st — Fast integer exponentiation by squaring from OSCAT.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: WHILE loop, bit access (.0, .15), SHR, REAL arithmetic.
   EXPN(2.0, 10) = 1024.0 each cycle. *)

FUNCTION EXPN : REAL
VAR_INPUT
	X : REAL;
	N : INT;
END_VAR
VAR
	sign: BOOL;
END_VAR
(* @END_DECLARATION := '0' *)
sign := n.15;
N := ABS(N);
IF N.0 THEN EXPN := X; ELSE EXPN := 1.0; END_IF;
N := SHR(N,1);
WHILE N > 0 DO
   X := X * X;
   IF N.0 THEN EXPN := EXPN * X; END_IF;
   N := SHR(N,1);
END_WHILE;
IF sign THEN EXPN := 1.0 / EXPN; END_IF;
END_FUNCTION

PROGRAM oscat_expn
VAR
    result : INT;
END_VAR
    result := REAL_TO_INT(EXPN(X := 2.0, N := 10));
END_PROGRAM
