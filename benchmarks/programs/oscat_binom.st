(* oscat_binom.st — Binomial coefficient from OSCAT library.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: FOR loop, IF/ELSIF/ELSE, RETURN, integer multiply/divide.
   BINOM(10, 5) = 252 each cycle. *)

FUNCTION BINOM : DINT
VAR_INPUT
	N : INT;
	K : INT;
END_VAR
VAR
	i: INT;
END_VAR
(* @END_DECLARATION := '0' *)
IF 2 * K > n THEN
	k := n - k;
END_IF;
IF k > n THEN
	RETURN;
ELSIF k = 0 OR k = n THEN
	BINOM := 1;
ELSIF k = 1 THEN
	BINOM := n;
ELSE
	BINOM := n;
	n := n + 1;
	FOR i := 2 TO k DO
		BINOM := BINOM * (n - i) / i;
	END_FOR;
END_IF;
END_FUNCTION

PROGRAM oscat_binom
VAR
    result : INT;
END_VAR
    result := DINT_TO_INT(BINOM(N := 10, K := 5));
END_PROGRAM
