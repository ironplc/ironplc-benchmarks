(* P2033/P2035: Pointer arithmetic and comparison on REF_TO types.

   IronPLC rejects arithmetic (+, -) and ordering comparisons (<, >, <=, >=)
   on REF_TO types. RuSTy and OSCAT use pointer arithmetic extensively for
   efficient buffer and string manipulation.

   Errors:
     P2033 — Arithmetic operations are not allowed on reference types
     P2035 — Ordering comparison on reference types (only = and <> are allowed)
   OSCAT functions affected: 29 functions (CAPITALIZE, BIN_TO_BYTE, etc.)

   The fix should add an --allow-pointer-arithmetic flag (or include it
   in --dialect rusty) that permits arithmetic operations and ordering
   comparisons on REF_TO types, treating them as memory addresses.

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/20_pointer_arithmetic.st
*)

FUNCTION FILL_ZEROS : BOOL
VAR_INPUT
    pt : REF_TO BYTE;
    size : INT;
END_VAR
VAR
    i : INT;
    end_ptr : REF_TO BYTE;
END_VAR
    end_ptr := pt + INT_TO_DWORD(size);    (* P2033: arithmetic on REF_TO *)
    WHILE pt < end_ptr DO                  (* P2035: comparison on REF_TO *)
        pt^ := 0;
        pt := pt + 1;                      (* P2033: arithmetic on REF_TO *)
    END_WHILE;
    FILL_ZEROS := TRUE;
END_FUNCTION

PROGRAM main
VAR
    result : BOOL;
END_VAR
    result := TRUE;
END_PROGRAM
