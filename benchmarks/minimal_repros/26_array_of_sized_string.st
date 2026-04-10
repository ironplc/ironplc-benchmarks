(* P9999: ARRAY OF STRING[N] not implemented in codegen.

   Declaring a variable or struct field as ARRAY[...] OF STRING[N]
   parses correctly but fails during code generation with P9999
   "Unsupported array element type".

   In OSCAT, the CONSTANTS_LANGUAGE struct uses patterns like:
     WEEKDAYS : ARRAY[1..3, 1..7] OF STRING[10] := [...]

   Error: P9999 - Unsupported array element type (codegen)
   OSCAT impact: TYPE CONSTANTS_LANGUAGE cannot be parsed, which
     blocks parsing all 370 functions when compiled together.

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/26_array_of_sized_string.st
*)

(* Case 1: ARRAY OF STRING[N] in a PROGRAM variable *)
PROGRAM main
VAR
    names : ARRAY[1..3] OF STRING[10];
END_VAR
    names[1] := 'hello';
END_PROGRAM

(* Case 2: ARRAY OF STRING[N] in a TYPE STRUCT - matches oscat.st usage
TYPE MY_STRUCT :
STRUCT
    ITEMS : ARRAY[1..7] OF STRING[10] := ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
END_STRUCT
END_TYPE

PROGRAM main2
VAR
    s : MY_STRUCT;
END_VAR
    s.ITEMS[1] := 'Monday';
END_PROGRAM
*)
