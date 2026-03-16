(* Category 5: TYPE STRUCT declarations.
   Part of 38 syntax errors. *)

TYPE MY_POINT :
STRUCT
    X : REAL;
    Y : REAL;
END_STRUCT
END_TYPE

PROGRAM main
VAR
    pt : MY_POINT;
END_VAR
    pt.X := 1.0;
    pt.Y := 2.0;
END_PROGRAM
