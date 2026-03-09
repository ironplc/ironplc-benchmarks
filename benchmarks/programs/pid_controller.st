(* pid_controller.st — Discrete PID controller.
   Exercises floating-point arithmetic (REAL), multi-term expressions,
   and stateful accumulation. The controller drives a simulated process
   variable toward a setpoint, producing analytically traceable output.

   After each scan the controller computes:
     error      = setpoint - process_var
     accum      = accum + error            (integral term)
     deriv      = error - prev_error       (derivative term)
     ctrl_out   = Kp*error + Ki*accum + Kd*deriv
     process_var = process_var + ctrl_out * step_size

   With Kp=2.0, Ki=0.5, Kd=0.1, step_size=0.1, setpoint=100.0 and
   process_var starting at 0.0 the system converges over ~50 scans. *)

PROGRAM pid_controller
VAR
    setpoint   : REAL := 100.0;
    pv         : REAL := 0.0;      (* process variable / measurement *)
    err        : REAL := 0.0;
    prev_err   : REAL := 0.0;
    accum      : REAL := 0.0;      (* integral accumulator *)
    deriv      : REAL := 0.0;
    ctrl_out   : REAL := 0.0;
    kp         : REAL := 2.0;
    ki         : REAL := 0.5;
    kd         : REAL := 0.1;
    step_size  : REAL := 0.1;
END_VAR
    err := setpoint - pv;
    accum := accum + err;
    deriv := err - prev_err;
    ctrl_out := kp * err + ki * accum + kd * deriv;
    prev_err := err;
    pv := pv + ctrl_out * step_size;
END_PROGRAM
