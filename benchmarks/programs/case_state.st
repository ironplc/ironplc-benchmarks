(* case_state.st — CASE-based state machine.
   Cycles through 4 states on each scan. Exercises CASE/branch opcodes
   which map to jump tables in both compiled and interpreted execution. *)

PROGRAM case_state
VAR
    state : INT := 0;
    output_a : BOOL := FALSE;
    output_b : BOOL := FALSE;
    output_c : BOOL := FALSE;
    output_d : BOOL := FALSE;
END_VAR
    CASE state OF
        0:
            output_a := TRUE;
            output_b := FALSE;
            output_c := FALSE;
            output_d := FALSE;
            state := 1;
        1:
            output_a := FALSE;
            output_b := TRUE;
            output_c := FALSE;
            output_d := FALSE;
            state := 2;
        2:
            output_a := FALSE;
            output_b := FALSE;
            output_c := TRUE;
            output_d := FALSE;
            state := 3;
        3:
            output_a := FALSE;
            output_b := FALSE;
            output_c := FALSE;
            output_d := TRUE;
            state := 0;
    END_CASE;
END_PROGRAM
