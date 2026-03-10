(* oscat_polynom_int.st — Newton polynomial interpolation from OSCAT.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: nested FOR loops (BY -1), 2D array access, REAL arithmetic, MIN.
   Interpolates X=2.5 over y=x^2 points: (1,1),(2,4),(3,9),(4,16),(5,25).
   Result = REAL_TO_INT(6.25) = 6 each cycle. *)

FUNCTION POLYNOM_INT : REAL
VAR_INPUT
	X : REAL;
	XY : ARRAY[1..5,0..1] OF REAL;
	Pts : INT;
END_VAR
VAR
	I, J : INT;
	stop: INT;
END_VAR
(* @END_DECLARATION := '0' *)
pts := MIN(pts, 5);

FOR i := 1 TO pts DO
	stop := i + 1;
   	FOR j := pts TO stop BY -1 DO
   		XY[j,1] := (XY[j,1] - XY[j-1,1]) / (XY[j,0] - XY[j-i,0]);
	END_FOR;
END_FOR;

POLYNOM_INT := 0.0;
FOR i := pts TO 1 BY -1 DO
       POLYNOM_INT := POLYNOM_INT * (X - XY[i,0]) + XY[i,1];
END_FOR;
END_FUNCTION

PROGRAM oscat_polynom_int
VAR
    points : ARRAY[1..5,0..1] OF REAL;
    result : INT;
END_VAR
    points[1,0] := 1.0;  points[1,1] := 1.0;
    points[2,0] := 2.0;  points[2,1] := 4.0;
    points[3,0] := 3.0;  points[3,1] := 9.0;
    points[4,0] := 4.0;  points[4,1] := 16.0;
    points[5,0] := 5.0;  points[5,1] := 25.0;
    result := REAL_TO_INT(POLYNOM_INT(X := 2.5, XY := points, Pts := 5));
END_PROGRAM
