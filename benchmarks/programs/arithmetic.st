(* arithmetic.st — Integer arithmetic operations.
   Exercises ADD, SUB, MUL, DIV, and MOD with analytically verifiable
   outputs. After each cycle, result_add = 30, result_sub = 10,
   result_mul = 200, result_div = 2, result_mod = 0. *)

PROGRAM arithmetic
VAR
    a : INT := 20;
    b : INT := 10;
    result_add : INT;
    result_sub : INT;
    result_mul : INT;
    result_div : INT;
    result_mod : INT;
END_VAR
    result_add := a + b;
    result_sub := a - b;
    result_mul := a * b;
    result_div := a / b;
    result_mod := a MOD b;
END_PROGRAM
