(* P4030: Constant referenced in type parameter is not defined.

   IronPLC with --allow-constant-type-params allows using constants in
   type parameters like STRING[MY_CONST], but the analyzer still requires
   the constant to be defined in the current compilation unit. OSCAT uses
   STRING[STRING_LENGTH] extensively, where STRING_LENGTH is a global
   constant defined elsewhere.

   Error: P4030 — Constant referenced in type parameter is not defined
   OSCAT functions affected: 9 functions (CLEAN, DEL_CHARS, FINDB,
     IS_CC, IS_NCC, REPLACE_CHARS, TRIM, TRIM1, TRIME)

   The fix should make --allow-constant-type-params (which is already
   included in --dialect rusty) also tolerate undefined constants in type
   parameters by using a default size, rather than raising an error.
   Alternatively, add a separate --allow-undefined-constant-type-params
   flag.

   Compile with:
     ironplcc compile --dialect rusty -o /tmp/test.iplc benchmarks/minimal_repros/23_undefined_constant_type_param.st
*)

FUNCTION MY_TRIM : STRING[STRING_LENGTH]
VAR_INPUT
    str : STRING[STRING_LENGTH];
END_VAR
    MY_TRIM := str;
END_FUNCTION

PROGRAM main
VAR
    result : STRING[255];
END_VAR
    result := MY_TRIM(str := 'hello');
END_PROGRAM
