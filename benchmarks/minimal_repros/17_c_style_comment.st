(* C-style block comment /* ... */ inside function body.
   IronPLC does not recognize /* */ comments, only (* *) comments.

   Error: P0002 — Found '/' unexpected
   OSCAT functions affected: LIST_RETRIEVE_LAST

   Compile with:
     ironplcc compile --allow-all --std-iec-61131-3 2013 -o /tmp/test.iplc benchmarks/minimal_repros/17_c_style_comment.st
*)

FUNCTION MY_FUNC : INT
VAR_INPUT
    x : INT;
END_VAR
    /* This is a C-style comment */
    MY_FUNC := x;
END_FUNCTION

PROGRAM main
VAR
    result : INT;
END_VAR
    result := MY_FUNC(x := 5);
END_PROGRAM
