(* VAR_TEMP block in FUNCTION declaration.
   IronPLC does not recognize VAR_TEMP as a valid variable section.
   Also blocks full-mode oscat.st parsing since FUNCTION_BLOCKs use VAR_TEMP.

   Error: P0002 — Found 'VAR_TEMP', expected identifier/statement
   OSCAT functions affected: REPLACE_UML (in FUNCTION),
     plus many FUNCTION_BLOCKs in full oscat.st

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/16_var_temp.st
*)

FUNCTION MY_FUNC : INT
VAR_INPUT
    x : INT;
END_VAR
VAR_TEMP
    temp : INT;
END_VAR
    temp := x * 2;
    MY_FUNC := temp;
END_FUNCTION

PROGRAM main
VAR
    result : INT;
END_VAR
    result := MY_FUNC(x := 5);
END_PROGRAM
