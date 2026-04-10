(* P4026: Implicit type widening not supported in function arguments.

   IEC 61131-3 allows implicit widening conversions where the range
   and precision of the source type are preserved:
   - ANY_INT widening: SINT->INT->DINT->LINT, USINT->UINT->UDINT->ULINT
   - ANY_INT to ANY_REAL: SINT/INT/DINT->REAL, any integer->LREAL
   - ANY_REAL widening: REAL->LREAL
   - ANY_BIT widening: BOOL->BYTE->WORD->DWORD->LWORD

   Cross-family conversions (e.g. INT->WORD, BYTE->INT) and narrowing
   conversions (e.g. DINT->INT) should NOT be implicitly allowed.

   IronPLC currently rejects ALL implicit conversions in function
   arguments, including the valid widening ones.

   Error: P4026 - Function call argument type does not match parameter type
   OSCAT impact: full-mode blocker, all 294 functions fail

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/33_implicit_integer_widening.st
*)

(* Target functions for each destination type *)
FUNCTION TAKES_INT : INT
VAR_INPUT x : INT; END_VAR TAKES_INT := x; END_FUNCTION

FUNCTION TAKES_DINT : DINT
VAR_INPUT x : DINT; END_VAR TAKES_DINT := x; END_FUNCTION

FUNCTION TAKES_LINT : LINT
VAR_INPUT x : LINT; END_VAR TAKES_LINT := x; END_FUNCTION

FUNCTION TAKES_UINT : UINT
VAR_INPUT x : UINT; END_VAR TAKES_UINT := x; END_FUNCTION

FUNCTION TAKES_UDINT : UDINT
VAR_INPUT x : UDINT; END_VAR TAKES_UDINT := x; END_FUNCTION

FUNCTION TAKES_ULINT : ULINT
VAR_INPUT x : ULINT; END_VAR TAKES_ULINT := x; END_FUNCTION

FUNCTION TAKES_REAL : REAL
VAR_INPUT x : REAL; END_VAR TAKES_REAL := x; END_FUNCTION

FUNCTION TAKES_LREAL : LREAL
VAR_INPUT x : LREAL; END_VAR TAKES_LREAL := x; END_FUNCTION

FUNCTION TAKES_WORD : WORD
VAR_INPUT x : WORD; END_VAR TAKES_WORD := x; END_FUNCTION

FUNCTION TAKES_DWORD : DWORD
VAR_INPUT x : DWORD; END_VAR TAKES_DWORD := x; END_FUNCTION

FUNCTION TAKES_LWORD : LWORD
VAR_INPUT x : LWORD; END_VAR TAKES_LWORD := x; END_FUNCTION

FUNCTION TAKES_BYTE : BYTE
VAR_INPUT x : BYTE; END_VAR TAKES_BYTE := x; END_FUNCTION

PROGRAM test_any_int_widening
VAR
    si : SINT := 1;
    i : INT := 1;
    di : DINT := 1;
    usi : USINT := 1;
    ui : UINT := 1;
    udi : UDINT := 1;
    ri : INT;
    rdi : DINT;
    rli : LINT;
    rui : UINT;
    rudi : UDINT;
    ruli : ULINT;
END_VAR
    (* Signed integer widening *)
    ri := TAKES_INT(x := si);       (* SINT -> INT *)
    rdi := TAKES_DINT(x := si);     (* SINT -> DINT *)
    rdi := TAKES_DINT(x := i);      (* INT -> DINT - the OSCAT blocker *)
    rli := TAKES_LINT(x := si);     (* SINT -> LINT *)
    rli := TAKES_LINT(x := i);      (* INT -> LINT *)
    rli := TAKES_LINT(x := di);     (* DINT -> LINT *)

    (* Unsigned integer widening *)
    rui := TAKES_UINT(x := usi);    (* USINT -> UINT *)
    rudi := TAKES_UDINT(x := usi);  (* USINT -> UDINT *)
    rudi := TAKES_UDINT(x := ui);   (* UINT -> UDINT *)
    ruli := TAKES_ULINT(x := usi);  (* USINT -> ULINT *)
    ruli := TAKES_ULINT(x := ui);   (* UINT -> ULINT *)
    ruli := TAKES_ULINT(x := udi);  (* UDINT -> ULINT *)
END_PROGRAM

PROGRAM test_int_to_real_widening
VAR
    si : SINT := 1;
    i : INT := 1;
    di : DINT := 1;
    r : REAL;
    lr : LREAL;
END_VAR
    (* Integer to REAL widening *)
    r := TAKES_REAL(x := si);       (* SINT -> REAL *)
    r := TAKES_REAL(x := i);        (* INT -> REAL *)
    r := TAKES_REAL(x := di);       (* DINT -> REAL *)

    (* REAL to LREAL widening *)
    lr := TAKES_LREAL(x := r);      (* REAL -> LREAL *)
END_PROGRAM

PROGRAM test_any_bit_widening
VAR
    bo : BOOL := TRUE;
    by : BYTE := BYTE#1;
    w : WORD := WORD#1;
    dw : DWORD := DWORD#1;
    rb : BYTE;
    rw : WORD;
    rdw : DWORD;
    rlw : LWORD;
END_VAR
    (* BOOL widening *)
    rb := TAKES_BYTE(x := bo);      (* BOOL -> BYTE *)
    rw := TAKES_WORD(x := bo);      (* BOOL -> WORD *)
    rdw := TAKES_DWORD(x := bo);    (* BOOL -> DWORD *)
    rlw := TAKES_LWORD(x := bo);    (* BOOL -> LWORD *)

    (* BYTE widening *)
    rw := TAKES_WORD(x := by);      (* BYTE -> WORD *)
    rdw := TAKES_DWORD(x := by);    (* BYTE -> DWORD *)
    rlw := TAKES_LWORD(x := by);    (* BYTE -> LWORD *)

    (* WORD widening *)
    rdw := TAKES_DWORD(x := w);     (* WORD -> DWORD *)
    rlw := TAKES_LWORD(x := w);     (* WORD -> LWORD *)

    (* DWORD widening *)
    rlw := TAKES_LWORD(x := dw);    (* DWORD -> LWORD *)
END_PROGRAM
