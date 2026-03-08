(* counter_up.st — Counter with reset.
   Exercises integer arithmetic, comparison, and conditional assignment.
   The counter increments each cycle and resets at a threshold. *)

PROGRAM counter_up
VAR
    count : INT := 0;
    threshold : INT := 1000;
    reset_flag : BOOL := FALSE;
END_VAR
    IF count >= threshold THEN
        count := 0;
        reset_flag := TRUE;
    ELSE
        count := count + 1;
        reset_flag := FALSE;
    END_IF;
END_PROGRAM
