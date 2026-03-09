(* alarm_interlock.st — Multi-zone alarm and interlock logic.
   Exercises dense boolean expressions (AND, OR, NOT) with latching
   and priority resolution — the dominant pattern in safety-critical
   PLC programs.

   Four independent alarm zones feed into a priority resolver.
   Each zone latches on its trigger and can only be cleared by
   an acknowledge when the trigger is no longer active.
   The interlock output is TRUE when any zone is in alarm.

   Zone triggers cycle deterministically so that after 110 scans
   the final state is analytically predictable. *)

PROGRAM alarm_interlock
VAR
    (* Simulated sensor inputs — derived from a scan counter *)
    scan_count   : INT := 0;
    trigger_a    : BOOL := FALSE;
    trigger_b    : BOOL := FALSE;
    trigger_c    : BOOL := FALSE;
    trigger_d    : BOOL := FALSE;

    (* Zone alarm latches *)
    alarm_a      : BOOL := FALSE;
    alarm_b      : BOOL := FALSE;
    alarm_c      : BOOL := FALSE;
    alarm_d      : BOOL := FALSE;

    (* Acknowledge — auto-pulses every 17 scans *)
    ack          : BOOL := FALSE;

    (* Priority-resolved outputs *)
    any_alarm    : BOOL := FALSE;
    critical     : BOOL := FALSE;  (* zones A or B *)
    warning      : BOOL := FALSE;  (* zones C or D, no critical *)
    interlock    : BOOL := FALSE;  (* master trip *)
    alarm_count  : INT := 0;
END_VAR
    scan_count := scan_count + 1;

    (* Generate deterministic trigger patterns using modular arithmetic *)
    (* Zone A: active on scans 5-9 of every 20 *)
    trigger_a := (scan_count MOD 20 >= 5) AND (scan_count MOD 20 < 10);

    (* Zone B: active on scans 10-14 of every 30 *)
    trigger_b := (scan_count MOD 30 >= 10) AND (scan_count MOD 30 < 15);

    (* Zone C: active on scans 3-7 of every 15 *)
    trigger_c := (scan_count MOD 15 >= 3) AND (scan_count MOD 15 < 8);

    (* Zone D: active on scans 0-4 of every 25 *)
    trigger_d := (scan_count MOD 25 >= 0) AND (scan_count MOD 25 < 5);

    (* Auto-acknowledge pulse *)
    ack := (scan_count MOD 17) = 0;

    (* Latch logic: set on trigger, clear only when ack AND NOT trigger *)
    IF trigger_a THEN
        alarm_a := TRUE;
    END_IF;
    IF ack AND NOT trigger_a THEN
        alarm_a := FALSE;
    END_IF;

    IF trigger_b THEN
        alarm_b := TRUE;
    END_IF;
    IF ack AND NOT trigger_b THEN
        alarm_b := FALSE;
    END_IF;

    IF trigger_c THEN
        alarm_c := TRUE;
    END_IF;
    IF ack AND NOT trigger_c THEN
        alarm_c := FALSE;
    END_IF;

    IF trigger_d THEN
        alarm_d := TRUE;
    END_IF;
    IF ack AND NOT trigger_d THEN
        alarm_d := FALSE;
    END_IF;

    (* Priority resolver *)
    any_alarm := alarm_a OR alarm_b OR alarm_c OR alarm_d;
    critical  := alarm_a OR alarm_b;
    warning   := (alarm_c OR alarm_d) AND NOT critical;
    interlock := any_alarm;

    (* Count active alarms *)
    alarm_count := 0;
    IF alarm_a THEN alarm_count := alarm_count + 1; END_IF;
    IF alarm_b THEN alarm_count := alarm_count + 1; END_IF;
    IF alarm_c THEN alarm_count := alarm_count + 1; END_IF;
    IF alarm_d THEN alarm_count := alarm_count + 1; END_IF;
END_PROGRAM
