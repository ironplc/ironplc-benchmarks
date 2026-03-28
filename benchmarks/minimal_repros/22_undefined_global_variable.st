(* P4007: Undefined global variables accessed via dotted notation.

   IronPLC rejects references to variables like math.PI, phys.T0, and
   setup.EXTENDED_ASCII because these global variable namespaces are not
   defined in the compilation unit. In OSCAT, these are defined as
   VAR_GLOBAL blocks that are expected to be linked from another file.

   Error: P4007 — Variable not defined before used
   OSCAT variables affected:
     math.PI, math.PI2, math.E, math.FACTS[] (13 functions)
     setup.EXTENDED_ASCII, setup.LANGUAGE (8 functions)
     LANGUAGE.DEFAULT, LANGUAGE.LMAX (6 functions)
     phys.T0, phys.C0, etc. (5 functions)

   The fix should add an --allow-undefined-globals flag (or include it in
   --dialect rusty) that treats unresolved dotted variable references as
   external globals rather than raising an error. This allows compilation
   units to reference globals defined elsewhere.

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/22_undefined_global_variable.st
*)

FUNCTION C_TO_K : REAL
VAR_INPUT
    Celsius : REAL;
END_VAR
    C_TO_K := Celsius - phys.T0;     (* P4007: 'phys' not defined *)
END_FUNCTION

PROGRAM main
VAR
    result : REAL;
END_VAR
    result := C_TO_K(Celsius := 100.0);
END_PROGRAM
