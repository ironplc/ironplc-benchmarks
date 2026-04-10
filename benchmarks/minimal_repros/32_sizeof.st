(* P4017: SIZEOF operator not supported.

   SIZEOF returns the size in bytes of a variable or type. It is not
   part of IEC 61131-3 but is a CODESYS extension also supported by
   TwinCAT/Beckhoff and RuSTy. It requires compile-time knowledge
   of type sizes so it cannot be implemented as a user-defined function.

   In OSCAT, SIZEOF is used in buffer management functions that work
   with REF_TO pointers.

   Error: P4017 - Function is not declared
   OSCAT functions affected: buffer management functions (8 uses)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/32_sizeof.st
*)

PROGRAM main
VAR
    x : INT;
    y : DWORD;
    arr : ARRAY[1..10] OF INT;
    s : DINT;
END_VAR
    s := SIZEOF(x);
    s := SIZEOF(y);
    s := SIZEOF(arr);
END_PROGRAM
