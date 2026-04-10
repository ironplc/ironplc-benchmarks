(* P4030: VAR CONSTANT used as array bound not resolved.

   Using a VAR CONSTANT declared in the same FUNCTION_BLOCK as an
   array dimension bound fails with P4030 "Constant referenced in
   type parameter is not defined". The constant is defined after the
   array declaration in a separate VAR CONSTANT block.

   This pattern is used in OSCAT for configurable-size FIFO and STACK
   function blocks where the size is a local constant.

   Error: P4030 - Constant referenced in type parameter is not defined
   OSCAT impact: FIFO_16, FIFO_32, STACK_16, STACK_32 (4 function blocks)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/36_var_constant_array_bound.st
*)

FUNCTION_BLOCK MY_FIFO
VAR_INPUT
    din : DWORD;
END_VAR
VAR
    fifo : ARRAY[0..n] OF DWORD;
    idx : INT;
END_VAR
VAR CONSTANT
    n : INT := 16;
END_VAR
    fifo[idx] := din;
    idx := idx + 1;
    IF idx > n THEN idx := 0; END_IF;
END_FUNCTION_BLOCK

PROGRAM main
VAR
    f : MY_FIFO;
END_VAR
    f(din := DWORD#42);
END_PROGRAM
