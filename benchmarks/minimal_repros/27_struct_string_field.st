(* P9999: STRING field in TYPE STRUCT not implemented in analyzer.

   Declaring a TYPE STRUCT with a STRING field (with or without a
   size specifier) causes "Not implemented" in the analyzer's
   intermediates/structure pass. The struct does not need to be
   referenced or used - its mere presence triggers the error.

   Structs with only numeric fields (INT, SINT, REAL, etc.) work fine.

   Error: P9999 - Not implemented at analyzer/src/intermediates/structure.rs#L276
   OSCAT types affected: CALENDAR, ESR_DATA, HOLIDAY_DATA
   OSCAT impact: blocks compilation of all 294 testable functions
     when compiled together with oscat.st (full mode), because the
     analyzer aborts on the struct definition before reaching any
     function.

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/27_struct_string_field.st
*)

(* Case 1: STRING without size specifier *)
TYPE MY_DATA :
STRUCT
    NAME : STRING;
    VALUE : INT;
END_STRUCT
END_TYPE

PROGRAM main
VAR
    x : INT;
END_VAR
    x := 1;
END_PROGRAM

(* Case 2: STRING with size specifier - same error
TYPE MY_DATA2 :
STRUCT
    NAME : STRING[30];
    VALUE : INT;
END_STRUCT
END_TYPE

PROGRAM main2
VAR
    x : INT;
END_VAR
    x := 1;
END_PROGRAM
*)
