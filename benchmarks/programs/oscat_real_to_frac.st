(* oscat_real_to_frac.st — Real to fraction (continued fractions) from OSCAT.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: REPEAT/UNTIL loop, EXIT, IF/ELSE, REAL/DINT arithmetic,
   struct return type, ABS, type conversions.
   REAL_TO_FRAC(3.14159, 1000) = 355/113 each cycle. *)

TYPE FRACTION :
STRUCT
	NUMERATOR : INT;
	DENOMINATOR : INT;
END_STRUCT
END_TYPE

FUNCTION REAL_TO_FRAC : FRACTION
VAR_INPUT
	X : REAL;
	N : INT;
END_VAR
VAR
	temp : DINT;
	sign: BOOL;
	X_gerundet: DINT;
	X_ohne_Nachkomma: REAL;
	Numerator:       DINT := 1;
	Denominator:     DINT := 0;
	Numerator_old:   DINT := 0;
	Denominator_old: DINT := 1;
END_VAR
(* @END_DECLARATION := '0' *)
IF X < 0.0 THEN
	sign := TRUE;
	X := ABS(X);
END_IF;

REPEAT
	X_gerundet := REAL_TO_DINT(X);

	temp := numerator * X_gerundet + numerator_old;
	numerator_old := numerator;
	numerator := temp;

	temp := denominator * X_gerundet + denominator_old;
	denominator_old := denominator;
	denominator := temp;

	X_ohne_Nachkomma := DINT_TO_REAL(X_gerundet);
	IF X = X_ohne_Nachkomma THEN
		IF ABS(denominator) <= N THEN
			numerator_old := numerator;
			denominator_old := denominator;
		END_IF;
		EXIT;
	ELSE
		X := 1.0 / (X - X_ohne_Nachkomma);
	END_IF;

UNTIL
	ABS(Denominator) > N
END_REPEAT;

IF sign THEN
	REAL_TO_FRAC.NUMERATOR := -1 * ABS(DINT_TO_INT(numerator_old));
ELSE
	REAL_TO_FRAC.NUMERATOR :=  ABS(DINT_TO_INT(numerator_old));
END_IF;
REAL_TO_FRAC.DENOMINATOR := ABS(DINT_TO_INT(denominator_old));
END_FUNCTION

PROGRAM oscat_real_to_frac
VAR
    temp : FRACTION;
    result_num : INT;
    result_den : INT;
END_VAR
    temp := REAL_TO_FRAC(X := 3.14159, N := 1000);
    result_num := temp.NUMERATOR;
    result_den := temp.DENOMINATOR;
END_PROGRAM
