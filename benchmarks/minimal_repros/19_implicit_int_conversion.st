(* P4026: Implicit integer type conversion not supported.

   IronPLC with --dialect rusty rejects passing an integer literal where
   a narrower integer type is expected. RuSTy and most PLC runtimes
   implicitly convert between integer types (e.g. DINT to INT).

   Error: P4026 — Function call argument type does not match parameter type
          (expected=INT, actual=DINT)
   OSCAT functions affected: 41 functions (BFT_TO_MS, BIT_LOAD_B, etc.)

   The fix should add an --allow-implicit-int-conversion flag (or include
   it in --dialect rusty) that permits implicit narrowing/widening
   conversions between integer types (SINT, INT, DINT, LINT and their
   unsigned variants) in function call arguments.

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/19_implicit_int_conversion.st
*)

FUNCTION ADD_ONE : INT
VAR_INPUT
    x : INT;
END_VAR
    ADD_ONE := x + 1;
END_FUNCTION

PROGRAM main
VAR
    result : INT;
END_VAR
    (* 5 is inferred as DINT, but ADD_ONE expects INT *)
    result := ADD_ONE(x := 5);
END_PROGRAM
