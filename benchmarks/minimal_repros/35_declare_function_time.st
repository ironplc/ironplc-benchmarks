(* P0002: Cannot declare a function named TIME.

   The rusty dialect includes --allow-time-as-function-name which
   allows calling TIME() as a function. However, declaring
   FUNCTION TIME is rejected by the parser because TIME is still
   treated as a keyword in the declaration context.

   This prevents creating a user-defined TIME function in a
   compatibility library to wrap __SYSTEM_UP_TIME.

   Error: P0002 - Syntax error (parser rejects TIME as function name)
   OSCAT impact: 2 calls to TIME() in OSCAT, needed for compat library

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/35_declare_function_time.st
*)

FUNCTION TIME : TIME
    TIME := T#0s;
END_FUNCTION

PROGRAM main
VAR
    t : TIME;
END_VAR
    t := TIME();
END_PROGRAM
