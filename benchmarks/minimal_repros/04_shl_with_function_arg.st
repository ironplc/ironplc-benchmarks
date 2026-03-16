(* Category 3: SHL/SHR with function call as first argument.
   Affects 15 OSCAT functions. *)

FUNCTION MY_SHIFT : WORD
VAR_INPUT
    B : BYTE;
END_VAR
    MY_SHIFT := SHL(BYTE_TO_WORD(B), 8);
END_FUNCTION

PROGRAM main
VAR
    result : WORD;
END_VAR
    result := MY_SHIFT(B := BYTE#16#AB);
END_PROGRAM
