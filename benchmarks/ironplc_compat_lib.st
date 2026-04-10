(* IronPLC Compatibility Library

   Provides CODESYS-specific functions that are not part of IEC 61131-3
   and not built into IronPLC, but are needed by the OSCAT library.

   These are prepended to the compilation unit when running the
   compatibility test with --lib.
*)

(* Byte_of_Dword: Extract a byte from a DWORD by index.
   N=0 is the least significant byte, N=3 is the most significant.
   CODESYS built-in, used 16 times in OSCAT. *)
FUNCTION Byte_of_Dword : BYTE
VAR_INPUT
    in : DWORD;
    N : BYTE;
END_VAR
    Byte_of_Dword := DWORD_TO_BYTE(SHR(in, BYTE_TO_INT(N) * 8));
END_FUNCTION

(* DAY_OF_WEEK: Return day of week for a DATE value.
   Returns 0=Sunday, 1=Monday, ..., 6=Saturday.
   CODESYS extension, used 12 times in OSCAT.
   DATE is seconds since 1970-01-01. Jan 1 1970 was Thursday (=4). *)
FUNCTION DAY_OF_WEEK : SINT
VAR_INPUT
    in : DATE;
END_VAR
VAR
    days : DINT;
END_VAR
    days := DWORD_TO_DINT(DATE_TO_DWORD(in) / 86400);
    DAY_OF_WEEK := DINT_TO_SINT(((days MOD 7) + 4) MOD 7);
END_FUNCTION

(* TIME: Return current PLC uptime.
   CODESYS built-in, used 2 times in OSCAT.
   NOTE: Returns T#0s stub because __SYSTEM_UP_TIME is not accessible
   from FUNCTION context. Runtime value will not be correct until
   global variable access from functions is supported. *)
FUNCTION TIME : TIME
    TIME := T#0s;
END_FUNCTION
