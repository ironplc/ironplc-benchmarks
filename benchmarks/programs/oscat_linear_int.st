(* oscat_linear_int.st — Piecewise linear interpolation from OSCAT.
   Source: https://github.com/PLC-lang/oscat (OSCAT BASIC, www.oscat.de)
   Exercises: WHILE loop, 2D array access, REAL arithmetic, MIN.
   Interpolates X=25 over 5 points: (0,0),(10,100),(20,200),(30,300),(40,400).
   Result = 250 each cycle. *)

FUNCTION LINEAR_INT : REAL
VAR_INPUT
	X : REAL;
	XY : ARRAY[1..20,0..1] OF REAL;
	Pts : INT;
END_VAR
VAR
	i : INT;
END_VAR
(* @END_DECLARATION := '0' *)
pts := MIN(pts,20);

i := 2;
WHILE (i < pts) AND (XY[i,0] < X) DO
	i := i + 1;
END_WHILE;

LINEAR_INT := ((XY[i,1] - XY[i-1,1]) * X - XY[i,1] * XY[i-1,0] + XY[i-1,1] * XY[i,0]) / (XY[i,0] - XY[i-1,0]);
END_FUNCTION

PROGRAM oscat_linear_int
VAR
    points : ARRAY[1..20,0..1] OF REAL;
    result : INT;
END_VAR
    points[1,0] := 0.0;   points[1,1] := 0.0;
    points[2,0] := 10.0;  points[2,1] := 100.0;
    points[3,0] := 20.0;  points[3,1] := 200.0;
    points[4,0] := 30.0;  points[4,1] := 300.0;
    points[5,0] := 40.0;  points[5,1] := 400.0;
    result := REAL_TO_INT(LINEAR_INT(X := 25.0, XY := points, Pts := 5));
END_PROGRAM
