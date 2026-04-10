(* P9999: Array subscript on global struct member not implemented.

   Accessing an array field of a global struct like math.FACTS[X]
   fails in codegen. This combines global struct access with array
   subscripting.

   Error: P9999 - Not implemented at codegen/src/compile_array.rs#L155
   OSCAT impact: 6 functions (FACT, DATE_ADD, DAY_OF_MONTH,
     DT2_TO_SDT, DT_TO_SDT, MONTH_BEGIN)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/40_global_array_subscript.st
*)

TYPE MY_MATH :
STRUCT
    FACTS : ARRAY[0..10] OF REAL;
END_STRUCT
END_TYPE

VAR_GLOBAL CONSTANT
    math : MY_MATH;
END_VAR

FUNCTION LOOKUP : REAL
VAR_INPUT
    x : INT;
END_VAR
    LOOKUP := math.FACTS[x];
END_FUNCTION

PROGRAM main
VAR
    r : REAL;
END_VAR
    r := LOOKUP(x := 5);
END_PROGRAM
