(* oscat_fib.st — Fibonacci sequence from OSCAT library.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: WHILE loop, IF/ELSIF/ELSE, RETURN, integer arithmetic.
   FIB(20) = 6765 each cycle. *)

FUNCTION FIB : DINT
VAR_INPUT
	X : INT;
END_VAR
VAR
	t1, t2: DINT;
END_VAR
(* @END_DECLARATION := '0' *)
IF X < 0 OR X > 46 THEN
	FIB := -1;
ELSIF x < 2 THEN
	FIB := X;
	RETURN;
ELSE
	t2 := 1;
	WHILE X > 3 DO
		X := X-2;
		t1 := t1 + t2;
		t2 := t1 + t2;
	END_WHILE;
	IF X > 2 THEN t1 := t1 + t2; END_IF;
	fib := t1 + t2;
END_IF;
END_FUNCTION

PROGRAM oscat_fib
VAR
    result : INT;
END_VAR
    result := DINT_TO_INT(FIB(X := 20));
END_PROGRAM
