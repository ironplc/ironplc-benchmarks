(* P9999: Global struct field access blocks BYTE comparison codegen.

   Functions like ISC_ALPHA that compare BYTE values with integer
   literals (in > 64 AND in < 91) fail because they also access
   global struct fields like setup.EXTENDED_ASCII. The error
   appears at :1:1 because the global access fails before reaching
   the comparison code.

   This is the same root cause as #38 (global struct field access
   in functions) but manifests in character classification functions.

   Error: P9999 - Not implemented at codegen/src/compile.rs#L2072
   OSCAT impact: 7 functions (IS_ALNUM, IS_ALPHA, IS_LOWER,
     IS_UPPER, ISC_ALPHA, ISC_LOWER, ISC_UPPER)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/42_string_comparison_operators.st
*)

TYPE SETUP_DATA :
STRUCT
    EXTENDED_ASCII : BOOL := TRUE;
END_STRUCT
END_TYPE

VAR_GLOBAL CONSTANT
    setup : SETUP_DATA;
END_VAR

FUNCTION ISC_ALPHA : BOOL
VAR_INPUT
    in : BYTE;
END_VAR
    IF setup.EXTENDED_ASCII THEN
        ISC_ALPHA := (in > 64 AND in < 91) OR (in > 96 AND in < 123);
    ELSE
        ISC_ALPHA := (in > 64 AND in < 91) OR (in > 96 AND in < 123);
    END_IF;
END_FUNCTION

PROGRAM main
VAR
    r : BOOL;
END_VAR
    r := ISC_ALPHA(in := BYTE#72);
END_PROGRAM
