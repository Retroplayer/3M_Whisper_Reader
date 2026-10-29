; LEX-31 / 3M Whisper Reader — experimental 40×2 editor patch.
; The original renderer for row 1 is preserved; row 2 displays the logical
; line following the next CR after the current cursor. Selected-file length
; bounds prevent reads into the following file.
;
; Orig U4 padding at 2EA0h–2FFFh is all zero. This module occupies 2EA0h–2EF3h.
; Build with patches/40x2/build.py; do NOT overwrite original ROMs.

ORG 2EA0h
EDITOR_RENDER_40x2:
    CALL 233Bh              ; original row 1 renderer
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    LD HL,(459Ah)           ; selected document start
    LD DE,(459Ch)           ; selected document length
    ADD HL,DE               ; end of selected document
    EX DE,HL                ; DE=end
    LD HL,(4669h)           ; current editor cursor pointer
FIND_NEXT_CR:
    LD A,H
    CP D
    JR NZ,READ_FOR_CR
    LD A,L
    CP E
    JR Z,BEGIN_ROW2         ; end reached: blank row 2
READ_FOR_CR:
    LD A,(HL)
    CP 0Dh
    JR Z,AFTER_CR
    INC HL
    JR FIND_NEXT_CR
AFTER_CR:
    INC HL
BEGIN_ROW2:
    LD A,0C0h              ; second-row DDRAM 40h
    CALL 0760h             ; original raw LCD command function
    LD B,28h               ; write exactly 40 character cells
ROW2_CELL:
    LD A,H
    CP D
    JR NZ,ROW2_FETCH
    LD A,L
    CP E
    JR Z,ROW2_PAD
ROW2_FETCH:
    LD A,(HL)
    CP 0Dh
    JR Z,ROW2_PAD
    CALL 0755h             ; original translated character writer
    INC HL
    DJNZ ROW2_CELL
    JR RESTORE_ROW1_CURSOR
ROW2_PAD:
    LD A,20h
    CALL 0755h
    DJNZ ROW2_PAD
RESTORE_ROW1_CURSOR:
    LD A,(4002h)          ; first-row cursor shadow
    OR 80h
    CALL 0760h
    POP HL
    POP DE
    POP BC
    POP AF
    RET

ORG 2F80h
GLYPHS_5x8:
    DB 1Eh,10h,1Ch,10h,1Eh,07h,08h,06h
    DB 1Ch,12h,12h,12h,1Ch,01h,01h,01h
    DB 00h,10h,08h,04h,02h,01h,00h,00h
    DB 00h,04h,04h,0Eh,0Eh,0Eh,1Fh,04h

; Required same-length modifications to original ROM:
; 0653h: 34 34 -> 38 38     ; two-line 5×8 HD44780 function set
; 0659h: 21 6F 06 -> 21 80 2F ; CGRAM bitmap source 2F80h
; 0898h: 06 0B -> 06 08     ; eight CGRAM row bytes
; 22CEh: CD 3B 23 -> CD A0 2E ; editor redraw hook
