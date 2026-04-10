(* P9999: Assigning STRING or ARRAY field on function return struct.

   When a function returns a struct, assigning to a STRING field or
   an ARRAY element of the return value fails in codegen. Simple
   numeric field assignments (MAKE_ESR.typ := 1) work fine.

   Error: P9999 - Not implemented at codegen
   OSCAT impact: 1 function (STATUS_TO_ESR)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/46_function_return_struct_field.st
*)

TYPE MY_DATA :
STRUCT
    TYP : BYTE;
    NAME : STRING[10];
    VALUES : ARRAY[0..3] OF BYTE;
END_STRUCT
END_TYPE

FUNCTION MAKE_DATA : MY_DATA
VAR_INPUT
    t : BYTE;
    n : STRING[10];
END_VAR
    MAKE_DATA.TYP := t;
    MAKE_DATA.NAME := n;
    MAKE_DATA.VALUES[0] := t;
END_FUNCTION

PROGRAM main
VAR
    d : MY_DATA;
END_VAR
    d := MAKE_DATA(t := BYTE#1, n := 'test');
END_PROGRAM
