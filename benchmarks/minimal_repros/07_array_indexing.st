(* Category 7: Array indexing not implemented in codegen.
   Affects all OSCAT functions using arrays (ARRAY_* family, interpolation, etc.).
   Error: Not implemented at codegen/src/compile.rs#L3248 *)

PROGRAM main
VAR
    data : ARRAY[0..3] OF DINT;
    result : DINT;
END_VAR
    data[0] := 10;
    data[1] := 20;
    result := data[0] + data[1];
END_PROGRAM
