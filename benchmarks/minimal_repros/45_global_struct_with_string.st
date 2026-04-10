(* P9999: Global struct variable with STRING field not supported in codegen.

   Instantiating a TYPE STRUCT that contains a STRING field as a
   VAR_GLOBAL variable fails with "Structure contains unsupported
   field types (STRING, WSTRING, or FunctionBlock)".

   The struct definition itself is accepted. Using the struct as a
   local variable in a PROGRAM also works. Only VAR_GLOBAL
   instantiation fails.

   In OSCAT, the global variables LANGUAGE (CONSTANTS_LANGUAGE) and
   SETUP (CONSTANTS_SETUP) contain STRING fields, and their presence
   in VAR_GLOBAL blocks all 294 functions in full mode.

   Error: P9999 - Structure contains unsupported field types
   OSCAT impact: full-mode blocker, all 294 functions fail

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/45_global_struct_with_string.st
*)

TYPE MY_DATA :
STRUCT
    NAME : STRING[30];
    VALUE : INT;
END_STRUCT
END_TYPE

VAR_GLOBAL
    data1 : MY_DATA;
END_VAR

PROGRAM main
VAR
    x : INT;
END_VAR
    x := 1;
END_PROGRAM
