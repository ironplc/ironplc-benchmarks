(* P9999: STRING comparison as IF condition not implemented in codegen.

   Using a STRING equality (or other comparison) as the condition of
   an IF statement triggers compile_expr.rs#L34. Direct assignment of
   the comparison result (CMP := a = b) works fine.

   This affects all functions that conditionally branch on string
   equality, which is a very common pattern.

   Suspected root cause (per compiler dev): "STRING outside the
   dedicated string-compare path".

   Error: P9999 - Not implemented at codegen/src/compile_expr.rs#L34
   OSCAT impact: 14 functions including DIR_TO_DEG (compares
     language.DIRS[ly,i] = DIR), CHARCODE, FINDB, REPLACE_ALL,
     TRIM1, TRIME, FSTRING_TO_*, EXEC

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/52_string_compare_in_if.st
*)

FUNCTION COMPARE_STRINGS : BOOL
VAR_INPUT
    a : STRING[10];
    b : STRING[10];
END_VAR
    IF a = b THEN
        COMPARE_STRINGS := TRUE;
    ELSE
        COMPARE_STRINGS := FALSE;
    END_IF;
END_FUNCTION

PROGRAM main
VAR
    r : BOOL;
END_VAR
    r := COMPARE_STRINGS(a := 'hello', b := 'world');
END_PROGRAM
