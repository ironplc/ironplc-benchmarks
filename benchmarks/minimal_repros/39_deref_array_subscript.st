(* P9999: Array subscript on dereferenced REF_TO ARRAY OF BYTE.

   Expressions like pt^[i] where pt is REF_TO ARRAY[..] OF BYTE
   fail during code generation. This pattern is used in OSCAT for
   byte-level string manipulation via REF(str) cast to byte array.

   REF_TO ARRAY OF REAL works, but BYTE does not.

   Error: P9999 - Not implemented at codegen/src/compile_array.rs#L138
   OSCAT impact: 8 functions (LIST_GET, LIST_LEN, FIND_CHAR,
     FIND_CTRL, FIND_NONUM, FIND_NUM, FLOAT_TO_REAL, MIRROR)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/39_deref_array_subscript.st
*)

FUNCTION GET_BYTE : BYTE
VAR_INPUT
    pt : REF_TO ARRAY[1..255] OF BYTE;
    i : INT;
END_VAR
    GET_BYTE := pt^[i];
END_FUNCTION

PROGRAM main
VAR
    arr : ARRAY[1..255] OF BYTE;
    r : BYTE;
END_VAR
    arr[1] := BYTE#42;
    r := GET_BYTE(pt := REF(arr), i := 1);
END_PROGRAM
