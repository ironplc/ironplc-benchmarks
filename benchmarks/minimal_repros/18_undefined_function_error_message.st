(* Calling a function not defined in the compilation unit produces a
   misleading error message.

   Expected: a clear diagnostic like "function 'HELPER' is not defined"
   Actual: error[P9999]: Capability is not implemented (yet!)
           Not implemented at codegen/src/compile.rs#L2736

   This affects ~40 OSCAT functions when compiled in isolation (without
   the full oscat.st), since they call other OSCAT functions that aren't
   present in the compilation unit.

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/18_undefined_function_error_message.st
*)

FUNCTION MY_FUNC : INT
VAR_INPUT
    x : INT;
END_VAR
    MY_FUNC := HELPER(x);
END_FUNCTION

PROGRAM main
VAR
    result : INT;
END_VAR
    result := MY_FUNC(x := 5);
END_PROGRAM
