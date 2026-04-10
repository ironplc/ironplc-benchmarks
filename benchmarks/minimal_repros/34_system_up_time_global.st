(* P4007: __SYSTEM_UP_TIME global variable not exposed.

   The rusty dialect lists --allow-system-uptime-global which should
   expose __SYSTEM_UP_TIME and __SYSTEM_UP_LTIME as implicit VAR_GLOBALs
   providing runtime monotonic uptime. However, the variable is not
   actually available and produces P4007 "Variable not defined".

   Error: P4007 - Variable not defined before used
   OSCAT impact: needed to implement TIME() function in compat library

   Compile with:
     ironplcc compile --dialect rusty benchmarks/minimal_repros/34_system_up_time_global.st
*)

PROGRAM main
VAR
    t : TIME;
END_VAR
    t := __SYSTEM_UP_TIME;
END_PROGRAM
