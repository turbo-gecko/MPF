            .org    1800h
            ld      ix,HELP
DISP:
            call    SCAN
            cp      13h
            jr      nz,DISP
            halt
            
            .org    1820h
HELP:
            .db     0aeh
            .db     0b5h
            .db     01fh
            .db     085h
            .db     08fh
            .db     037h
            
SCAN        .equ    05feh
            .end            
                                    