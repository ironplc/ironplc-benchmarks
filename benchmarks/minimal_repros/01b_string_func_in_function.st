(* Category 1b: String stdlib function called from FUNCTION context.
   compile.rs#L2513 (LEN), #L2537 (FIND) — separate codegen paths.
   Works in PROGRAM, fails in FUNCTION.
   Affects COUNT_SUBSTRING, FSTRING_TO_WEEK, and other string-using functions. *)

FUNCTION MY_LEN : INT
VAR_INPUT
    S : STRING;
END_VAR
    MY_LEN := LEN(S);
END_FUNCTION

PROGRAM main
VAR
    result : INT;
END_VAR
    result := MY_LEN(S := 'Hello');
END_PROGRAM
