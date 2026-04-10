(* These conversions should be REJECTED by the compiler.

   IEC 61131-3 does not allow implicit narrowing or cross-family
   conversions. Each case below should produce a compile error.
   IronPLC correctly rejects all of these today.

   This file is a negative test - it should NOT compile.

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/33b_rejected_conversions.st
   Expected: compile errors on every conversion below
*)

FUNCTION TAKES_INT : INT
VAR_INPUT x : INT; END_VAR TAKES_INT := x; END_FUNCTION

FUNCTION TAKES_SINT : SINT
VAR_INPUT x : SINT; END_VAR TAKES_SINT := x; END_FUNCTION

FUNCTION TAKES_WORD : WORD
VAR_INPUT x : WORD; END_VAR TAKES_WORD := x; END_FUNCTION

FUNCTION TAKES_REAL : REAL
VAR_INPUT x : REAL; END_VAR TAKES_REAL := x; END_FUNCTION

FUNCTION TAKES_BOOL : BOOL
VAR_INPUT x : BOOL; END_VAR TAKES_BOOL := x; END_FUNCTION

PROGRAM test_narrowing_rejected
VAR
    di : DINT := 1;
    i : INT := 1;
    li : LINT := 1;
    lr : LREAL := 1.0;
    dw : DWORD := DWORD#1;
    ri : INT;
    rsi : SINT;
    rr : REAL;
    rw : WORD;
END_VAR
    (* Narrowing - should all fail *)
    ri := TAKES_INT(x := di);       (* DINT -> INT: narrowing *)
    rsi := TAKES_SINT(x := i);      (* INT -> SINT: narrowing *)
    ri := TAKES_INT(x := li);       (* LINT -> INT: narrowing *)
    rr := TAKES_REAL(x := lr);      (* LREAL -> REAL: narrowing *)
    rw := TAKES_WORD(x := dw);      (* DWORD -> WORD: narrowing *)
END_PROGRAM

PROGRAM test_cross_family_rejected
VAR
    i : INT := 1;
    w : WORD := WORD#1;
    by : BYTE := BYTE#1;
    bo : BOOL := TRUE;
    ri : INT;
    rw : WORD;
    rb : BOOL;
END_VAR
    (* Cross-family - should all fail *)
    rw := TAKES_WORD(x := i);       (* INT -> WORD: num to bit *)
    ri := TAKES_INT(x := w);        (* WORD -> INT: bit to num *)
    ri := TAKES_INT(x := by);       (* BYTE -> INT: bit to num *)
    ri := TAKES_INT(x := bo);       (* BOOL -> INT: bit to num *)
    rb := TAKES_BOOL(x := i);       (* INT -> BOOL: num to bit *)
END_PROGRAM
