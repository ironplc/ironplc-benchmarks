(* P4007: VAR_GLOBAL not accessible from FUNCTION or FUNCTION_BLOCK.

   Variables declared in VAR_GLOBAL blocks cannot be read from
   FUNCTION or FUNCTION_BLOCK bodies. They work in PROGRAM context.

   In OSCAT, global constants STRING_LENGTH, LIST_LENGTH, and struct
   globals like phys.T0, math.FACTS are used from functions.

   Error: P4007 - Variable not defined before used
   OSCAT impact: 9 functions (DWORD_TO_STRF, FILL, FIX, LIST_ADD,
     LIST_CLEAN, LIST_INSERT, LIST_RETRIEVE, LIST_RETRIEVE_LAST,
     REPLACE_UML) plus C_TO_K etc via phys/math globals

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/37_global_var_in_function.st
*)

VAR_GLOBAL CONSTANT
    MY_CONST : INT := 100;
END_VAR

FUNCTION USE_GLOBAL : INT
    USE_GLOBAL := MY_CONST;
END_FUNCTION

PROGRAM main
VAR
    r : INT;
END_VAR
    r := USE_GLOBAL();
END_PROGRAM
