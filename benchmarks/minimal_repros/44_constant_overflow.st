(* P2026: Constant value overflows target type.

   A DWORD constant with value 4294967292 (0xFFFFFFFC, which is -4
   in signed 32-bit) triggers an overflow error. This value fits in
   DWORD (unsigned 32-bit) but the compiler may be treating it as
   signed.

   Error: P2026 - Constant value overflows the target type
   OSCAT impact: 1 function (LAMBERT_W)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/44_constant_overflow.st
*)

FUNCTION MY_FUNC : REAL
VAR
    mask : DWORD := 4294967292;
END_VAR
    MY_FUNC := 0.0;
END_FUNCTION

PROGRAM main
VAR
    r : REAL;
END_VAR
    r := MY_FUNC();
END_PROGRAM
