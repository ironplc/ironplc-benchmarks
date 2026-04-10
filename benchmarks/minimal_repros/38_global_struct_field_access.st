(* P9999: Accessing field of a global struct variable in a FUNCTION.

   Functions that reference fields of global struct variables like
   phys.T0 or math.FACTS[X] fail in codegen. The struct field
   access on a global is not implemented.

   Error: P9999 - Not implemented at codegen
   OSCAT impact: 36 functions (C_TO_K, DEG_TO_DIR, FACT, BETA, etc.)

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/38_global_struct_field_access.st
*)

TYPE MY_CONSTANTS :
STRUCT
    PI : REAL := 3.14159;
    T0 : REAL := 273.15;
END_STRUCT
END_TYPE

VAR_GLOBAL CONSTANT
    phys : MY_CONSTANTS;
END_VAR

FUNCTION CELSIUS_TO_KELVIN : REAL
VAR_INPUT
    c : REAL;
END_VAR
    CELSIUS_TO_KELVIN := c - phys.T0;
END_FUNCTION

PROGRAM main
VAR
    r : REAL;
END_VAR
    r := CELSIUS_TO_KELVIN(c := 100.0);
END_PROGRAM
