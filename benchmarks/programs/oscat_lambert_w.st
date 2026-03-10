(* oscat_lambert_w.st — Lambert W function from OSCAT.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: FOR loop with EXIT, EXP, LN, REAL arithmetic, RETURN,
   IF/ELSIF/ELSE, REAL_TO_DW (bitwise float comparison via REF_TO).
   LAMBERT_W(1.0) ~= 0.5671 each cycle, result = 5671. *)

FUNCTION REAL_TO_DW : DWORD
VAR_INPUT
	X : REAL;
END_VAR
VAR
	pt : REF_TO DWORD;
END_VAR
(* @END_DECLARATION := '0' *)
pt := REF(X);
REAL_TO_DW := pt^;
END_FUNCTION

FUNCTION LAMBERT_W : REAL
VAR_INPUT
	X : REAL;
END_VAR
VAR
	w : REAL;
	i : INT;
	we: REAL;
	w1e: REAL;
	last: DWORD;
	ewx: REAL;
END_VAR
(* @END_DECLARATION := '0' *)
IF x < -0.367879441171442 THEN
	LAMBERT_W := -1000.0;
	RETURN;
ELSIF x = 0.0 THEN
	RETURN;
ELSIF x <= 500.0 THEN
	w := LN(x + 1.0);
	w := 0.665 * (1.0 + 0.0195 * w) * w + 0.04;
ELSE
	w := LN(x - 4.0) - (1.0 - 1.0/LN(x)) * LN(LN(x));
END_IF;
FOR i := 0 TO 5 DO
	ewx := EXP(w);
	we := w * ewx - x;
	w1e := (w+1.0) * ewx;
	last := REAL_TO_DW(w) AND 16#FFFF_FFFC;
	w := w - (we / (w1e - (w+2.0) * we / (2.0 * w + 2.0)));
	IF (REAL_TO_DW(w) AND 16#FFFF_FFFC) = last THEN EXIT; END_IF;
END_FOR;
LAMBERT_W := w;
END_FUNCTION

PROGRAM oscat_lambert_w
VAR
    result : INT;
END_VAR
    result := REAL_TO_INT(LAMBERT_W(X := 1.0) * 10000.0);
END_PROGRAM
