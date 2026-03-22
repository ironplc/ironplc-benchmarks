(* The compiler crashes trying to render the error diagnostic for this
   program. The actual error is hidden behind:
   "Failed writing to terminal: file missing"

   Root cause: accessing a global struct variable (e.g. setup.EXTENDED_ASCII)
   that is not defined in the compilation unit. The codegen hits a "not
   implemented" path, but the error renderer crashes before printing it.

   Affects 8 OSCAT functions: RDM2, FSTRING_TO_BYTE, FSTRING_TO_DWORD,
   ISC_ALPHA, ISC_LOWER, ISC_UPPER, DAYS_IN_YEAR, LEAP_OF_DATE.

   Note: unresolved function calls (compile.rs#L2430) render their error
   fine — only unresolved global variable access crashes the renderer. *)

FUNCTION TEST_FUNC : BOOL
VAR_INPUT
    X : BYTE;
END_VAR
    IF setup.EXTENDED_ASCII THEN
        TEST_FUNC := X > 64;
    ELSE
        TEST_FUNC := X > 96;
    END_IF;
END_FUNCTION

PROGRAM main
VAR
    result : BOOL;
END_VAR
    result := TEST_FUNC(X := BYTE#16#41);
END_PROGRAM
