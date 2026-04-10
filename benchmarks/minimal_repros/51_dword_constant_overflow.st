(* P2026: DWORD hex literal overflows when used in comparison expression.

   Using a large DWORD hex literal like 16#FFFF_FFFC in both an
   assignment and an IF comparison causes P2026 "Constant value
   overflows the target type". The value 4294967292 fits in DWORD
   (unsigned 32-bit) but the codegen appears to evaluate it as
   signed during comparison.

   Using the literal once (in assignment only) works fine.

   Error: P2026 - Constant value overflows the target type
   OSCAT impact: 1 function (LAMBERT_W)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/51_dword_constant_overflow.st
*)

FUNCTION GET_DW : DWORD
VAR_INPUT x : REAL; END_VAR
    GET_DW := REAL_TO_DWORD(x);
END_FUNCTION

FUNCTION TEST_FUNC : REAL
VAR_INPUT x : REAL; END_VAR
VAR
    w : REAL := 1.0;
    last : DWORD;
END_VAR
    last := GET_DW(w) AND 16#FFFF_FFFC;
    IF (GET_DW(w) AND 16#FFFF_FFFC) = last THEN
        TEST_FUNC := w;
    END_IF;
END_FUNCTION

PROGRAM main
VAR r : REAL; END_VAR
    r := TEST_FUNC(x := 1.0);
END_PROGRAM
