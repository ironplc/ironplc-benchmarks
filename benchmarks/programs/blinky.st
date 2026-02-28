(* blinky.st — Minimal benchmark baseline.
   Toggles an output coil on each scan cycle. Exercises the absolute
   minimum VM path: variable read, boolean NOT, variable write. *)

PROGRAM blinky
VAR
    output : BOOL := FALSE;
END_VAR
    output := NOT output;
END_PROGRAM
