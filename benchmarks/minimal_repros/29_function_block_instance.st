(* P4013: Function block instantiation treated as duplicate POU declaration.

   Declaring a variable whose type is a FUNCTION_BLOCK causes P4013
   "POU declaration name is duplicated". This is standard IEC 61131-3
   behavior: you define a FUNCTION_BLOCK and then create instances of
   it as variables. IronPLC incorrectly treats the variable type
   reference as a second POU declaration.

   This is a regression in v0.184.0 (commit ceb2f6f8). It blocks all
   FUNCTION_BLOCK usage in oscat.st, which means all 294 testable
   functions fail in full mode.

   Error: P4013 - POU declaration name is duplicated
   OSCAT impact: full-mode blocker, all functions fail

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/29_function_block_instance.st
*)

FUNCTION_BLOCK COUNTER
VAR
    count : INT;
END_VAR
    count := count + 1;
END_FUNCTION_BLOCK

PROGRAM main
VAR
    c : COUNTER;
END_VAR
    c();
END_PROGRAM
