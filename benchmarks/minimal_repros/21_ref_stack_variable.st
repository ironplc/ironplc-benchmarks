(* P2029/P2032: REF() of stack-allocated variables and reference type punning.

   IronPLC rejects taking a reference to VAR_INPUT parameters in FUNCTION
   context (they are stack-allocated, so the reference would dangle after
   the function returns). It also rejects assigning a REF_TO of one type
   to a REF_TO of a different type.

   OSCAT uses this pattern for type punning — e.g. interpreting a REAL's
   bit pattern as a DWORD by taking REF(real_var) into a REF_TO DWORD.
   The reference never escapes the function, so it is safe in practice.

   Errors:
     P2029 — REF() of stack-allocated variable
     P2032 — Reference type mismatch in assignment
   OSCAT functions affected: 9 functions (CHK_REAL, DW_TO_REAL, REAL_TO_DW,
     CODE, FIND_CHAR, etc.)

   The fix should add an --allow-ref-stack-variables flag (or include it
   in --dialect rusty) that permits REF() on function-local and input
   variables, and an --allow-ref-type-punning flag that permits assigning
   between REF_TO types of different base types.

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/21_ref_stack_variable.st
*)

FUNCTION CHK_REAL : BYTE
VAR_INPUT
    X : REAL;
END_VAR
VAR
    pt : REF_TO DWORD;
    tmp : DWORD;
END_VAR
    pt := REF(X);      (* P2029: REF of stack VAR_INPUT *)
                        (* P2032: REF_TO REAL assigned to REF_TO DWORD *)
    tmp := pt^;
    IF tmp < 16#7F800000 THEN
        CHK_REAL := 0;
    ELSE
        CHK_REAL := 16#80;
    END_IF;
END_FUNCTION

PROGRAM main
VAR
    result : BYTE;
END_VAR
    result := CHK_REAL(X := 1.0);
END_PROGRAM
