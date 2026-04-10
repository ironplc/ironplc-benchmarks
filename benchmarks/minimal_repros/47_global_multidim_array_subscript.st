(* P9999: Multi-dimensional array subscript on global struct field.

   Accessing a multi-dimensional array field of a global struct
   variable like language.WEEKDAYS[ly, wday] fails in codegen.

   Error: P9999 - Not implemented at codegen
   OSCAT impact: 2 functions (MONTH_TO_STRING, WEEKDAY_TO_STRING)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/47_global_multidim_array_subscript.st
*)

TYPE MY_LANG :
STRUCT
    NAMES : ARRAY[1..2, 1..3] OF STRING[10] := [
        'Mon', 'Tue', 'Wed',
        'Mo', 'Di', 'Mi'];
END_STRUCT
END_TYPE

VAR_GLOBAL
    lang : MY_LANG;
END_VAR

FUNCTION GET_NAME : STRING[10]
VAR_INPUT
    row : INT;
    col : INT;
END_VAR
    GET_NAME := lang.NAMES[row, col];
END_FUNCTION

PROGRAM main
VAR
    s : STRING[10];
END_VAR
    s := GET_NAME(row := 1, col := 1);
END_PROGRAM
