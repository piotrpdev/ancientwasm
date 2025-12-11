000100 IDENTIFICATION DIVISION.
000200 PROGRAM-ID. MAIN.
000300 DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 JSCODE PIC A(37) VALUE 'console.log("Hello from Javascript")'.
       PROCEDURE DIVISION.
       000-Main. *>Can this be something else?
           DISPLAY "Hello from COBOL"
           CALL 'emscripten_run_script' USING BY CONTENT JSCODE
           STOP RUN.
       END PROGRAM MAIN.
