(* P4026: SEL/MUX return type inferred from selector, not value parameters.

   When the standard function SEL or MUX is used as a nested argument
   to another function call, its return type is incorrectly inferred
   from the selector parameter type, BOOL for SEL, ANY_INT for MUX,
   instead of from the value parameters.

   SEL[BOOL, REAL, REAL] should return REAL, but IronPLC infers BOOL.
   MUX[INT, REAL, REAL] should return REAL, but IronPLC infers ANY_INT.

   Direct assignment works correctly because the target type guides
   inference. Assigning to a variable first also works as a workaround.
   The bug only manifests when the result is passed directly as an
   argument to another function call.

   Error: P4026 - Function call argument type does not match parameter type
   OSCAT impact: blocks 294 functions in full mode because the METER
     function_block uses SEL nested in R2_ADD call, and any error
     anywhere blocks the entire compilation.

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/28_sel_return_type_nested.st
*)

FUNCTION TAKES_REAL : REAL
VAR_INPUT
    Y : REAL;
END_VAR
    TAKES_REAL := Y;
END_FUNCTION

PROGRAM main
VAR
    r : REAL;
END_VAR
    r := TAKES_REAL(Y := SEL(TRUE, 0.0, 1.0));
END_PROGRAM
