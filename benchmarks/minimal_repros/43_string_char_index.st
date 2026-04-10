(* P9999: String character indexing via FIND/MID patterns not implemented.

   Functions that use FINDB-style byte-level string searching with
   comparison operators on individual characters fail in codegen.
   This covers patterns like comparing characters extracted from
   strings against character ranges.

   Error: P9999 - Not implemented at codegen/src/compile.rs#L2074
   OSCAT impact: 6 functions (CHARCODE, FINDB, FINDB_NONUM,
     FINDP, REPLACE_ALL, TRIM1, TRIME)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/43_string_char_index.st
*)

FUNCTION FIND_BACKWARDS : INT
VAR_INPUT
    str : STRING[255];
    ch : STRING[1];
END_VAR
VAR
    i : INT;
    c : STRING[1];
END_VAR
    FOR i := LEN(str) TO 1 BY -1 DO
        c := MID(str, 1, i);
        IF c = ch THEN
            FIND_BACKWARDS := i;
            RETURN;
        END_IF;
    END_FOR;
    FIND_BACKWARDS := 0;
END_FUNCTION

PROGRAM main
VAR
    r : INT;
END_VAR
    r := FIND_BACKWARDS(str := 'hello', ch := 'l');
END_PROGRAM
