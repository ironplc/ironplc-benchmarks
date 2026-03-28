(* TIME() used as a function call to read PLC system clock.
   IronPLC treats TIME as a type keyword and expects '#' for a literal,
   not '(' for a function call.

   Error: P0002 — Expected '#'. Found '('
   OSCAT functions affected: T_PLC_MS, T_PLC_US

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/13_time_function_call.st
*)

FUNCTION T_PLC_MS : DWORD
VAR
    tx : TIME;
END_VAR
    tx := TIME();
    T_PLC_MS := TIME_TO_DWORD(tx);
END_FUNCTION

PROGRAM main
VAR
    result : DWORD;
END_VAR
    result := T_PLC_MS();
END_PROGRAM
