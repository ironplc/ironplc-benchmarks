(* P4026: Integer literal passed to REAL parameter not implicitly converted.

   Passing an integer literal like 0 to a function parameter declared
   as REAL fails with P4026 type mismatch. The literal is typed as
   ANY_INT instead of being implicitly widened to REAL.

   Using 0.0 instead of 0 works as a workaround. RuSTy allows this
   implicit conversion.

   In OSCAT, the RDM function is called as RDM(0) where the parameter
   is declared as REAL. This single call in a FUNCTION_BLOCK blocks
   all 294 testable functions in full mode.

   Error: P4026 - Function call argument type does not match parameter type
   OSCAT impact: full-mode blocker, all 294 functions fail

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/30_int_literal_to_real_param.st
*)

FUNCTION TAKES_REAL : REAL
VAR_INPUT
    x : REAL;
END_VAR
    TAKES_REAL := x;
END_FUNCTION

PROGRAM main
VAR
    r : REAL;
END_VAR
    r := TAKES_REAL(x := 0);
END_PROGRAM
