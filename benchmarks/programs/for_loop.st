(* for_loop.st — FOR loop with accumulator.
   Exercises loop control flow opcodes. Sums integers 1..100 each cycle,
   producing a verifiable result of 5050. *)

PROGRAM for_loop
VAR
    i : INT;
    total : INT := 0;
END_VAR
    total := 0;
    FOR i := 1 TO 100 DO
        total := total + i;
    END_FOR;
END_PROGRAM
