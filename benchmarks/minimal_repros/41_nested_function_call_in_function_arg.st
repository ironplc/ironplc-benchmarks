(* P9999: Nested stdlib function call as argument to another stdlib function.

   Calling a standard string function like FIND where one argument
   is itself a function call (e.g. FIND(str, MID(s, 1, n))) fails
   in codegen. The nested function call result is not handled as
   an argument.

   Error: P9999 - Not implemented at codegen/src/compile.rs#L4055
   OSCAT impact: 7 functions (CLEAN, DEL_CHARS, FSTRING_TO_BYTE,
     FSTRING_TO_DWORD, IS_CC, IS_NCC, REPLACE_CHARS)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/41_nested_function_call_in_function_arg.st
*)

FUNCTION MY_SEARCH : INT
VAR_INPUT
    haystack : STRING[255];
    needle : STRING[255];
    maxlen : INT;
END_VAR
    MY_SEARCH := FIND(haystack, MID(needle, 1, maxlen));
END_FUNCTION

PROGRAM main
VAR
    r : INT;
END_VAR
    r := MY_SEARCH(haystack := 'hello world', needle := 'world', maxlen := 3);
END_PROGRAM
