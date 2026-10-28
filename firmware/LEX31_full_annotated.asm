; Lexicon LEX-31 / 3M Whisper Reader — ANNOTATED FULL ROM SOURCE
; Original binary: 3 x 2732 (U2 red / U3 green / U4 white), 12 KiB
; Z80/NSC800 instruction format. Address locations are inferred from code; verify PCB decoder.
; Generated source has exact coverage of every byte. Executable regions use Z80 mnemonics;
; unproven/undocumented regions use DB to preserve original ROM without pretending to know code.
; Addresses and original bytes after each line allow precise cross-checking.
; IMPORTANT: Byte exact source coverage checked by the accompanying validation script;
; independent assembly by a third-party Z80 assembler has not yet been run.
; Hardware labels identify firmware behavior, not connector/pin assignments.

PORT_LCD_CONTROL       EQU 047h  ; shared with keyboard scanner and RTC bank switch (bit 6)
RTC_WINDOW_BASE        EQU 04000h ; MM58167 5-bit registers visible while port 47h bit 6 is asserted
RTC_REG_IRQ_STATUS     EQU 04010h ; reading acknowledges MM58167 interrupt
RTC_REG_IRQ_CONTROL    EQU 04011h ; interrupt enable mask
RTC_REG_ROLLOVER       EQU 04014h ; bit 0 set when clock rolled over during read
RTC_REG_GO             EQU 04015h ; restart clock counters
PORT_LCD_READ          EQU 04Bh  ; HD44780 busy/data read candidate
PORT_STATUS_HI         EQU 04Fh  ; shadow 4007h
PORT_STATUS_LO         EQU 053h  ; shadow 4006h
PORT_COMM_DATA         EQU 05Bh  ; firmware communication byte
PORT_COMM_STATUS       EQU 05Fh  ; communications status/control
PORT_AUX_OUTPUT        EQU 0D7h  ; printer-style output; DB-37 not confirmed
PORT_NS800_ICR          EQU 0BBh  ; CPU internal interrupt control register: bit1 RSTC, bit2 RSTB
RAM_STATUS_LO_SHADOW   EQU 04006h
RAM_STATUS_HI_SHADOW   EQU 04007h
RAM_COMMAND_MODE       EQU 04507h
RAM_DOCUMENT_COUNT     EQU 04593h
RAM_DOCUMENT_DIRECTORY EQU 04598h
RAM_DOCUMENT_START     EQU 04800h

; Notes: some Z80 assemblers treat certain undocumented prefixes differently.
; Verify with compare_sources.py before burning any EPROM.

; red_u2.bin SHA256=7ff2ab423b202d3755f8ffbe06c5804412252459ea7434f99c1ba4bce2020e14
ORG 0000h
; ---- red_u2.bin start 0000h ----

RESET_ENTRY:
    ; CPU reset entry; U2 appears mapped at 0000h
    DI                                         ; @0000  F3                
    XOR A                                      ; @0001  AF                
    OUT (47h),A                                ; @0002  D3 47               Early output to port 47h (shared display/keyboard control)
    JR loc_000B                                ; @0004  18 05             
    DB FFh,FFh                                  ; @0006  FF FF
loc_0008:
    JP loc_0879                                ; @0008  C3 79 08          
loc_000B:
    ; Stack pointer set to 4800h; OS working-RAM layout must be reviewed for conflicts
    LD SP,4800h                                ; @000B  31 00 48          
    JR loc_001B                                ; @000E  18 0B             
RST10_LOAD_POINTERS:
    ; RST 10h loads HL and DE from saved OS pointers
    LD HL,(4654h)                              ; @0010  2A 54 46          
    LD DE,(4656h)                              ; @0013  ED 5B 56 46       
    RET                                        ; @0017  C9                
RST18_LCD_SERVICE:
    JP LCD_MAIN_INIT                           ; @0018  C3 67 08          
loc_001B:
    LD HL,4591h                                ; @001B  21 91 45          
    JR loc_0069                                ; @001E  18 49             
RST20_DOCUMENT_POINTERS:
    ; RST 20h retrieves document-memory pointers
    LD DE,(4594h)                              ; @0020  ED 5B 94 45       
    LD HL,(4669h)                              ; @0024  2A 69 46          
    RET                                        ; @0027  C9                
RST28_SET_INDICATOR:
    ; RST 28h enters 16-bit status-mask set function
    JP STATUS_SET_MASK                         ; @0028  C3 34 0A          
    DB FFh                                      ; @002B  FF
NSC800_RSTC_PERIODIC_VECTOR:
    ; NSC800 RSTC vector (002Ch) jumps to 017Eh periodic service; enabled by OUT (BBh),06h
    JP PERIODIC_SERVICE                        ; @002C  C3 7E 01          
    DB FFh                                      ; @002F  FF
loc_0030:
    JR loc_003E                                ; @0030  18 0C             
    DB FFh,FFh                                  ; @0032  FF FF
NSC800_RSTB_C000_VECTOR:
    ; NSC800 RSTB vector (0034h) jumps to C000h; enabled by OUT (BBh),06h; destination external/banked UNKNOWN
    JP C000h                                   ; @0034  C3 00 C0          
    DB FFh                                      ; @0037  FF
RST38_COMPARE_HL_DE:
    ; RST 38h performs 16-bit compare, not a conventional IRQ handler
    LD A,D                                     ; @0038  7A                
    CP H                                       ; @0039  BC                
    RET NZ                                     ; @003A  C0                
    LD A,E                                     ; @003B  7B                
    CP L                                       ; @003C  BD                
    RET                                        ; @003D  C9                
loc_003E:
    RST 18h                                    ; @003E  DF                
loc_003F:
    CALL loc_09F0                              ; @003F  CD F0 09          
    JP loc_09D7                                ; @0042  C3 D7 09          
loc_0045:
    RST 30h                                    ; @0045  F7                
    CALL loc_0A64                              ; @0046  CD 64 0A          
    RST 18h                                    ; @0049  DF                
    RET                                        ; @004A  C9                
loc_004B:
    CP 59h                                     ; @004B  FE 59             
    RET Z                                      ; @004D  C8                
    CP 79h                                     ; @004E  FE 79             
    RET                                        ; @0050  C9                
loc_0051:
    CP 41h                                     ; @0051  FE 41             
    RET C                                      ; @0053  D8                
    CP 5Bh                                     ; @0054  FE 5B             
    RET NC                                     ; @0056  D0                
    ADD A,20h                                  ; @0057  C6 20             
    RET                                        ; @0059  C9                
loc_005A:
    LD A,(HL)                                  ; @005A  7E                
    RRCA                                       ; @005B  0F                
    RRCA                                       ; @005C  0F                
    RRCA                                       ; @005D  0F                
    RRCA                                       ; @005E  0F                
    CALL loc_072D                              ; @005F  CD 2D 07          
    LD (DE),A                                  ; @0062  12                
    INC DE                                     ; @0063  13                
    RET                                        ; @0064  C9                
    DB FFh                                      ; @0065  FF
NSC800_NMI_LOCKUP_VECTOR:
    ; NSC800 NMI vector (0066h) loops to itself; NMI is not serviceable in this firmware configuration
    JP NSC800_NMI_LOCKUP_VECTOR                ; @0066  C3 66 00          
loc_0069:
    LD BC,1CE8h                                ; @0069  01 E8 1C          
loc_006C:
    DEC BC                                     ; @006C  0B                
    LD A,B                                     ; @006D  78                
    OR C                                       ; @006E  B1                
    JR NZ,loc_006C                             ; @006F  20 FB             
    LD DE,4590h                                ; @0071  11 90 45          
    LD BC,0591h                                ; @0074  01 91 05          
    LD (HL),A                                  ; @0077  77                
    LDDR                                       ; @0078  ED B8             
    IN A,(63h)                                 ; @007A  DB 63             
    LD A,06h                                   ; @007C  3E 06             
    OUT (BBh),A                                ; @007E  D3 BB               Write 06h to NSC800 interrupt control: enable RSTC/RSTB             
    LD HL,C0FFh                                ; @0080  21 FF C0          
    LD (44AFh),HL                              ; @0083  22 AF 44          
    LD (4466h),HL                              ; @0086  22 66 44          
    LD A,L                                     ; @0089  7D                
    LD (4526h),A                               ; @008A  32 26 45          
    INC A                                      ; @008D  3C                
    LD (452Ah),A                               ; @008E  32 2A 45          
    LD A,11h                                   ; @0091  3E 11             
    LD (4525h),A                               ; @0093  32 25 45          
    LD A,20h                                   ; @0096  3E 20             
    LD (457Ch),A                               ; @0098  32 7C 45          
    CALL loc_0165                              ; @009B  CD 65 01          
    LD HL,4800h                                ; @009E  21 00 48          
loc_00A1:
    LD A,(HL)                                  ; @00A1  7E                
    LD B,A                                     ; @00A2  47                
    LD A,AAh                                   ; @00A3  3E AA             
    LD (HL),A                                  ; @00A5  77                
    CP (HL)                                    ; @00A6  BE                
    JR NZ,loc_00B2                             ; @00A7  20 09             
    CPL                                        ; @00A9  2F                
    LD (HL),A                                  ; @00AA  77                
    CP (HL)                                    ; @00AB  BE                
    JR NZ,loc_00B2                             ; @00AC  20 04             
    LD (HL),B                                  ; @00AE  70                
    INC HL                                     ; @00AF  23                
    JR loc_00A1                                ; @00B0  18 EF             
loc_00B2:
    DEC HL                                     ; @00B2  2B                
    LD DE,(4665h)                              ; @00B3  ED 5B 65 46       
    RST 38h                                    ; @00B7  FF                
    LD (4665h),HL                              ; @00B8  22 65 46          
    JR NZ,loc_00C0                             ; @00BB  20 03             
    CALL loc_04AD                              ; @00BD  CD AD 04          
loc_00C0:
    PUSH AF                                    ; @00C0  F5                
    CALL LCD_INIT_START                        ; @00C1  CD 3D 06          
    POP AF                                     ; @00C4  F1                
    CALL NZ,DOCUMENT_POOL_INIT                 ; @00C5  C4 80 1E          
    CALL loc_04BA                              ; @00C8  CD BA 04          
    CALL NZ,loc_1E9B                           ; @00CB  C4 9B 1E          
    CALL loc_1828                              ; @00CE  CD 28 18          
    EI                                         ; @00D1  FB                
    CALL loc_013A                              ; @00D2  CD 3A 01          
    RST 10h                                    ; @00D5  D7                
    LD (466Ch),HL                              ; @00D6  22 6C 46          
    LD HL,112Fh                                ; @00D9  21 2F 11          
    CALL loc_0045                              ; @00DC  CD 45 00          
    LD HL,0002h                                ; @00DF  21 02 00          
    RST 28h                                    ; @00E2  EF                
OS_MAIN_LOOP:
    CALL loc_0491                              ; @00E3  CD 91 04          
    JR Z,loc_011E                              ; @00E6  28 36             
    CALL OS_COMMAND_LOOKUP                     ; @00E8  CD 38 02            Resolve keycode and mode into handler pointer in HL
    JR NC,loc_00F5                             ; @00EB  30 08             
    LD DE,00E3h                                ; @00ED  11 E3 00          
    PUSH DE                                    ; @00F0  D5                
    JP (HL)                                    ; @00F1  E9                  Dispatcher performs computed JP (HL); no general-purpose RAM loader proven
loc_00F2:
    ; Dispatched for keycode/mode: 91/00
    POP HL                                     ; @00F2  E1                
    LD A,08h                                   ; @00F3  3E 08             
loc_00F5:
    OR A                                       ; @00F5  B7                
    JP M,loc_011E                              ; @00F6  FA 1E 01          
    LD B,A                                     ; @00F9  47                
    RST 10h                                    ; @00FA  D7                
    BIT 6,L                                    ; @00FB  CB 75             
    JR Z,loc_011A                              ; @00FD  28 1B             
    XOR 0Dh                                    ; @00FF  EE 0D             
    JR NZ,loc_0109                             ; @0101  20 06             
    DEC A                                      ; @0103  3D                
    LD (400Dh),A                               ; @0104  32 0D 40          
    JR loc_0113                                ; @0107  18 0A             
loc_0109:
    LD A,(400Dh)                               ; @0109  3A 0D 40          
    INC A                                      ; @010C  3C                
    JR NZ,loc_0113                             ; @010D  20 04             
    LD (400Dh),A                               ; @010F  32 0D 40          
    RST 18h                                    ; @0112  DF                
loc_0113:
    LD A,B                                     ; @0113  78                
    CALL AUX_QUEUE_OUTPUT                      ; @0114  CD 0C 0B          
    CALL LCD_CHAR_OUTPUT                       ; @0117  CD 9E 06          
loc_011A:
    LD A,B                                     ; @011A  78                
    CALL loc_02BA                              ; @011B  CD BA 02          
loc_011E:
    CALL loc_1B4A                              ; @011E  CD 4A 1B          
    LD A,(451Fh)                               ; @0121  3A 1F 45          
    OR A                                       ; @0124  B7                
    JR Z,OS_MAIN_LOOP                          ; @0125  28 BC             
    LD HL,(451Dh)                              ; @0127  2A 1D 45          
    LD A,H                                     ; @012A  7C                
    OR L                                       ; @012B  B5                
    JR NZ,OS_MAIN_LOOP                         ; @012C  20 B5             
    EX DE,HL                                   ; @012E  EB                
    LD HL,(4464h)                              ; @012F  2A 64 44          
    RST 38h                                    ; @0132  FF                
    JR NZ,OS_MAIN_LOOP                         ; @0133  20 AE             
    LD (451Fh),A                               ; @0135  32 1F 45          
    JR OS_MAIN_LOOP                            ; @0138  18 A9             
loc_013A:
    LD HL,462Fh                                ; @013A  21 2F 46          
loc_013D:
    LD A,(HL)                                  ; @013D  7E                
    OR A                                       ; @013E  B7                
    RET Z                                      ; @013F  C8                
    PUSH HL                                    ; @0140  E5                
    CALL loc_0494                              ; @0141  CD 94 04          
    POP HL                                     ; @0144  E1                
    JR Z,loc_013D                              ; @0145  28 F6             
    CP (HL)                                    ; @0147  BE                
    JR NZ,loc_014D                             ; @0148  20 03             
    INC HL                                     ; @014A  23                
    JR loc_013D                                ; @014B  18 F0             
loc_014D:
    LD HL,1149h                                ; @014D  21 49 11          
    RST 30h                                    ; @0150  F7                
    LD A,01h                                   ; @0151  3E 01             
    OUT (63h),A                                ; @0153  D3 63             
    DI                                         ; @0155  F3                
loc_0156:
    JR loc_0156                                ; @0156  18 FE             
loc_0158:
    ; Dispatched for keycode/mode: 8F/00
    RST 18h                                    ; @0158  DF                
loc_0159:
    DI                                         ; @0159  F3                
    LD C,00h                                   ; @015A  0E 00             
    LD HL,405Ah                                ; @015C  21 5A 40          
    LD DE,4462h                                ; @015F  11 62 44          
    CALL loc_0306                              ; @0162  CD 06 03          
loc_0165:
    LD A,FCh                                   ; @0165  3E FC             
    LD (405Dh),A                               ; @0167  32 5D 40          
    EI                                         ; @016A  FB                
    RET                                        ; @016B  C9                
loc_016C:
    LD HL,01FFh                                ; @016C  21 FF 01          
loc_016F:
    PUSH DE                                    ; @016F  D5                
    EX DE,HL                                   ; @0170  EB                
    LD HL,(4505h)                              ; @0171  2A 05 45          
    ADD HL,DE                                  ; @0174  19                
    POP DE                                     ; @0175  D1                
    LD (4505h),HL                              ; @0176  22 05 45          
    OR 01h                                     ; @0179  F6 01             
    OUT (63h),A                                ; @017B  D3 63             
    RET                                        ; @017D  C9                
PERIODIC_SERVICE:
    ; RSTC interrupt service: disables CPU interrupts via BBh=00, services keyboard/serial/timers then restores BBh=06; source not traced
    PUSH AF                                    ; @017E  F5                
    XOR A                                      ; @017F  AF                
    OUT (BBh),A                                ; @0180  D3 BB               Write 00h to NSC800 interrupt control: mask all sources             
    PUSH BC                                    ; @0182  C5                
    PUSH DE                                    ; @0183  D5                
    PUSH HL                                    ; @0184  E5                
    CALL KEY_SCAN                              ; @0185  CD 5A 03          
    CALL SERIAL_RECEIVE_SERVICE                ; @0188  CD A9 18          
    CALL STATUS_REFRESH_ALL                    ; @018B  CD 9A 0A          
    LD HL,(4528h)                              ; @018E  2A 28 45          
    LD A,H                                     ; @0191  7C                
    OR L                                       ; @0192  B5                
    JR Z,loc_0199                              ; @0193  28 04             
    DEC HL                                     ; @0195  2B                
    LD (4528h),HL                              ; @0196  22 28 45          
loc_0199:
    CALL Z,loc_1BFE                            ; @0199  CC FE 1B          
    LD HL,(4505h)                              ; @019C  2A 05 45          
    LD A,H                                     ; @019F  7C                
    OR L                                       ; @01A0  B5                
    JR NZ,loc_01AA                             ; @01A1  20 07             
    OUT (63h),A                                ; @01A3  D3 63             
    LD (44F5h),A                               ; @01A5  32 F5 44          
    JR loc_01AB                                ; @01A8  18 01             
loc_01AA:
    DEC HL                                     ; @01AA  2B                
loc_01AB:
    LD (4505h),HL                              ; @01AB  22 05 45          
    LD HL,4516h                                ; @01AE  21 16 45          
    LD A,(HL)                                  ; @01B1  7E                
    OR A                                       ; @01B2  B7                
    JR Z,loc_01B8                              ; @01B3  28 03             
    DEC (HL)                                   ; @01B5  35                
    JR NZ,loc_01BE                             ; @01B6  20 06             
loc_01B8:
    LD HL,4000h                                ; @01B8  21 00 40          
    CALL STATUS_CLEAR_MASK                     ; @01BB  CD 4A 0A          
loc_01BE:
    LD A,(4012h)                               ; @01BE  3A 12 40          
    OR A                                       ; @01C1  B7                
    LD B,A                                     ; @01C2  47                
    JR Z,loc_0229                              ; @01C3  28 64             
    CALL loc_0AED                              ; @01C5  CD ED 0A          
    JR Z,loc_01DA                              ; @01C8  28 10             
    INC B                                      ; @01CA  04                
    JR Z,loc_0224                              ; @01CB  28 57             
    LD HL,(452Dh)                              ; @01CD  2A 2D 45          
    LD A,H                                     ; @01D0  7C                
    OR L                                       ; @01D1  B5                
    JR Z,loc_0229                              ; @01D2  28 55             
    DEC HL                                     ; @01D4  2B                
    LD (452Dh),HL                              ; @01D5  22 2D 45          
    JR loc_0218                                ; @01D8  18 3E             
loc_01DA:
    LD HL,186Ah                                ; @01DA  21 6A 18          
    LD (452Dh),HL                              ; @01DD  22 2D 45          
    INC B                                      ; @01E0  04                
    JR Z,loc_0224                              ; @01E1  28 41             
    LD HL,0200h                                ; @01E3  21 00 02          
    RST 28h                                    ; @01E6  EF                
AUX_OUTPUT_SERVICE:
    LD HL,400Fh                                ; @01E7  21 0F 40          
    LD A,(HL)                                  ; @01EA  7E                
    OR A                                       ; @01EB  B7                
    JR Z,loc_0218                              ; @01EC  28 2A             
    INC HL                                     ; @01EE  23                
    IN A,(D7h)                                 ; @01EF  DB D7             
    RRCA                                       ; @01F1  0F                
    JR NC,loc_0218                             ; @01F2  30 24             
    LD A,(HL)                                  ; @01F4  7E                
    LD B,A                                     ; @01F5  47                
    CP 0Dh                                     ; @01F6  FE 0D             
    JR NZ,loc_0204                             ; @01F8  20 0A             
    IN A,(4Fh)                                 ; @01FA  DB 4F             
    BIT 2,A                                    ; @01FC  CB 57             
    JR Z,loc_0211                              ; @01FE  28 11             
    LD (HL),0Ah                                ; @0200  36 0A             
    JR loc_020C                                ; @0202  18 08             
loc_0204:
    CP 80h                                     ; @0204  FE 80             
    JR NZ,loc_0211                             ; @0206  20 09             
    LD B,64h                                   ; @0208  06 64             
    LD (HL),6Ah                                ; @020A  36 6A             
loc_020C:
    LD A,B                                     ; @020C  78                
    OUT (D7h),A                                ; @020D  D3 D7             
    JR loc_0218                                ; @020F  18 07             
loc_0211:
    LD A,B                                     ; @0211  78                
    AND 7Fh                                    ; @0212  E6 7F             
AUX_SEND_CHAR:
    OUT (D7h),A                                ; @0214  D3 D7             
    DEC HL                                     ; @0216  2B                
    DEC (HL)                                   ; @0217  35                
loc_0218:
    POP HL                                     ; @0218  E1                
    POP DE                                     ; @0219  D1                
    POP BC                                     ; @021A  C1                
    IN A,(63h)                                 ; @021B  DB 63             
    LD A,06h                                   ; @021D  3E 06             
    OUT (BBh),A                                ; @021F  D3 BB               Write 06h to NSC800 interrupt control: re-enable RSTC/RSTB             
    POP AF                                     ; @0221  F1                
    EI                                         ; @0222  FB                
    RET                                        ; @0223  C9                
loc_0224:
    LD A,0Dh                                   ; @0224  3E 0D             
    OUT (D7h),A                                ; @0226  D3 D7             
    LD A,B                                     ; @0228  78                
loc_0229:
    LD (4012h),A                               ; @0229  32 12 40          
    LD HL,0200h                                ; @022C  21 00 02          
    CALL STATUS_CLEAR_MASK                     ; @022F  CD 4A 0A          
    XOR A                                      ; @0232  AF                
    LD (400Fh),A                               ; @0233  32 0F 40          
    JR loc_0218                                ; @0236  18 E0             
OS_COMMAND_LOOKUP:
    ; Mode-dependent command lookup, data table at 0F7Dh (crosses U2/U3 boundary)
    LD C,A                                     ; @0238  4F                
    LD A,(4507h)                               ; @0239  3A 07 45          
    CP 06h                                     ; @023C  FE 06             
    LD A,C                                     ; @023E  79                
    JR Z,loc_024F                              ; @023F  28 0E             
    LD HL,1FE5h                                ; @0241  21 E5 1F          
    CP 90h                                     ; @0244  FE 90             
    JR Z,loc_0271                              ; @0246  28 29             
    LD HL,0C6Bh                                ; @0248  21 6B 0C          
    CP 8Bh                                     ; @024B  FE 8B             
    JR Z,loc_0271                              ; @024D  28 22             
loc_024F:
    LD HL,0F7Dh                                ; @024F  21 7D 0F          
loc_0252:
    LD A,(HL)                                  ; @0252  7E                
    OR A                                       ; @0253  B7                
    JR NZ,loc_0258                             ; @0254  20 02             
loc_0256:
    LD A,C                                     ; @0256  79                
    RET                                        ; @0257  C9                
loc_0258:
    XOR C                                      ; @0258  A9                
    INC HL                                     ; @0259  23                
    LD B,(HL)                                  ; @025A  46                
    INC HL                                     ; @025B  23                
    JR NZ,loc_0274                             ; @025C  20 16             
    LD A,(4507h)                               ; @025E  3A 07 45          
loc_0261:
    CP (HL)                                    ; @0261  BE                
    JR Z,loc_026C                              ; @0262  28 08             
    INC HL                                     ; @0264  23                
    INC HL                                     ; @0265  23                
    INC HL                                     ; @0266  23                
    DJNZ loc_0261                              ; @0267  10 F8             
    OR A                                       ; @0269  B7                
    JR loc_0256                                ; @026A  18 EA             
loc_026C:
    INC HL                                     ; @026C  23                
loc_026D:
    LD E,(HL)                                  ; @026D  5E                
    INC HL                                     ; @026E  23                
    LD D,(HL)                                  ; @026F  56                
    EX DE,HL                                   ; @0270  EB                
loc_0271:
    SCF                                        ; @0271  37                
    JR loc_0256                                ; @0272  18 E2             
loc_0274:
    INC HL                                     ; @0274  23                
    INC HL                                     ; @0275  23                
    INC HL                                     ; @0276  23                
    DJNZ loc_0274                              ; @0277  10 FB             
    JR loc_0252                                ; @0279  18 D7             
loc_027B:
    LD C,A                                     ; @027B  4F                
loc_027C:
    LD A,(HL)                                  ; @027C  7E                
    OR A                                       ; @027D  B7                
    JR Z,loc_0256                              ; @027E  28 D6             
    INC HL                                     ; @0280  23                
    XOR C                                      ; @0281  A9                
    JR Z,loc_026D                              ; @0282  28 E9             
    INC HL                                     ; @0284  23                
    INC HL                                     ; @0285  23                
    JR loc_027C                                ; @0286  18 F4             
QUEUE_HANDLER_A:
    LD D,(HL)                                  ; @0288  56                
    INC HL                                     ; @0289  23                
    LD E,(HL)                                  ; @028A  5E                
    INC DE                                     ; @028B  13                
    INC HL                                     ; @028C  23                
    LD B,(HL)                                  ; @028D  46                
    INC HL                                     ; @028E  23                
    LD C,(HL)                                  ; @028F  4E                
    EX DE,HL                                   ; @0290  EB                
    PUSH HL                                    ; @0291  E5                
    ADD HL,BC                                  ; @0292  09                
    POP HL                                     ; @0293  E1                
    EX DE,HL                                   ; @0294  EB                
    RET C                                      ; @0295  D8                
    DEC HL                                     ; @0296  2B                
    DEC HL                                     ; @0297  2B                
    LD (HL),E                                  ; @0298  73                
    DEC HL                                     ; @0299  2B                
    LD (HL),D                                  ; @029A  72                
    LD DE,0006h                                ; @029B  11 06 00          
    ADD HL,DE                                  ; @029E  19                
    LD D,(HL)                                  ; @029F  56                
    INC HL                                     ; @02A0  23                
    LD E,(HL)                                  ; @02A1  5E                
    PUSH DE                                    ; @02A2  D5                
    INC DE                                     ; @02A3  13                
    EX DE,HL                                   ; @02A4  EB                
    PUSH HL                                    ; @02A5  E5                
    ADD HL,BC                                  ; @02A6  09                
    POP HL                                     ; @02A7  E1                
    JR NC,loc_02AD                             ; @02A8  30 03             
    LD HL,0000h                                ; @02AA  21 00 00          
loc_02AD:
    EX DE,HL                                   ; @02AD  EB                
    LD (HL),E                                  ; @02AE  73                
    DEC HL                                     ; @02AF  2B                
    LD (HL),D                                  ; @02B0  72                
    INC HL                                     ; @02B1  23                
    INC HL                                     ; @02B2  23                
    POP DE                                     ; @02B3  D1                
    ADD HL,DE                                  ; @02B4  19                
    LD (HL),A                                  ; @02B5  77                
    LD A,01h                                   ; @02B6  3E 01             
    OR A                                       ; @02B8  B7                
    RET                                        ; @02B9  C9                
loc_02BA:
    LD C,A                                     ; @02BA  4F                
    IN A,(5Fh)                                 ; @02BB  DB 5F             
    AND 10h                                    ; @02BD  E6 10             
    RET NZ                                     ; @02BF  C0                
    LD A,(4517h)                               ; @02C0  3A 17 45          
    OR A                                       ; @02C3  B7                
    LD A,C                                     ; @02C4  79                
    JR NZ,loc_02D2                             ; @02C5  20 0B             
    LD HL,4464h                                ; @02C7  21 64 44          
    DI                                         ; @02CA  F3                
    CALL QUEUE_HANDLER_A                       ; @02CB  CD 88 02          
    EI                                         ; @02CE  FB                
    JR C,loc_02BA                              ; @02CF  38 E9             
    RET                                        ; @02D1  C9                
loc_02D2:
    LD (44F8h),A                               ; @02D2  32 F8 44          
    JP loc_1C97                                ; @02D5  C3 97 1C          
QUEUE_HANDLER_B:
    LD D,(HL)                                  ; @02D8  56                
    INC HL                                     ; @02D9  23                
    LD E,(HL)                                  ; @02DA  5E                
    LD A,D                                     ; @02DB  7A                
    OR E                                       ; @02DC  B3                
    RET Z                                      ; @02DD  C8                
    DEC DE                                     ; @02DE  1B                
    LD (HL),E                                  ; @02DF  73                
    DEC HL                                     ; @02E0  2B                
    LD (HL),D                                  ; @02E1  72                
    INC HL                                     ; @02E2  23                
    INC HL                                     ; @02E3  23                
    LD B,(HL)                                  ; @02E4  46                
    INC HL                                     ; @02E5  23                
    LD C,(HL)                                  ; @02E6  4E                
    INC HL                                     ; @02E7  23                
    LD D,(HL)                                  ; @02E8  56                
    INC HL                                     ; @02E9  23                
    LD E,(HL)                                  ; @02EA  5E                
    PUSH DE                                    ; @02EB  D5                
    INC DE                                     ; @02EC  13                
    EX DE,HL                                   ; @02ED  EB                
    PUSH HL                                    ; @02EE  E5                
    ADD HL,BC                                  ; @02EF  09                
    POP HL                                     ; @02F0  E1                
    JR NC,loc_02F6                             ; @02F1  30 03             
    LD HL,0000h                                ; @02F3  21 00 00          
loc_02F6:
    EX DE,HL                                   ; @02F6  EB                
    LD (HL),E                                  ; @02F7  73                
    DEC HL                                     ; @02F8  2B                
    LD (HL),D                                  ; @02F9  72                
    POP DE                                     ; @02FA  D1                
    INC HL                                     ; @02FB  23                
    INC HL                                     ; @02FC  23                
    INC HL                                     ; @02FD  23                
    INC HL                                     ; @02FE  23                
    ADD HL,DE                                  ; @02FF  19                
    OR 01h                                     ; @0300  F6 01             
    LD A,(HL)                                  ; @0302  7E                
    RET                                        ; @0303  C9                
    DB 0Eh,20h                                  ; @0304  0E 20
loc_0306:
    LD A,C                                     ; @0306  79                
    LD (DE),A                                  ; @0307  12                
    RST 38h                                    ; @0308  FF                
    RET Z                                      ; @0309  C8                
    DEC DE                                     ; @030A  1B                
    JR loc_0306                                ; @030B  18 F9             
loc_030D:
    LD E,04h                                   ; @030D  1E 04             
    PUSH DE                                    ; @030F  D5                
    LD DE,457Eh                                ; @0310  11 7E 45          
    XOR A                                      ; @0313  AF                
    LD (DE),A                                  ; @0314  12                
    INC DE                                     ; @0315  13                
    LD (DE),A                                  ; @0316  12                
    INC DE                                     ; @0317  13                
    LD (DE),A                                  ; @0318  12                
    JR loc_0323                                ; @0319  18 08             
loc_031B:
    EX (SP),HL                                 ; @031B  E3                
    CALL loc_0345                              ; @031C  CD 45 03          
    ADD HL,HL                                  ; @031F  29                
    ADD HL,HL                                  ; @0320  29                
    ADD HL,HL                                  ; @0321  29                
    ADD HL,HL                                  ; @0322  29                
loc_0323:
    CALL loc_032C                              ; @0323  CD 2C 03          
    EX (SP),HL                                 ; @0326  E3                
    DEC L                                      ; @0327  2D                
    JR NZ,loc_031B                             ; @0328  20 F1             
    POP HL                                     ; @032A  E1                
    RET                                        ; @032B  C9                
loc_032C:
    LD A,H                                     ; @032C  7C                
    RRCA                                       ; @032D  0F                
    RRCA                                       ; @032E  0F                
    RRCA                                       ; @032F  0F                
    RRCA                                       ; @0330  0F                
    AND 0Fh                                    ; @0331  E6 0F             
    LD DE,4580h                                ; @0333  11 80 45          
    OR A                                       ; @0336  B7                
    DAA                                        ; @0337  27                
    LD B,03h                                   ; @0338  06 03             
loc_033A:
    LD C,A                                     ; @033A  4F                
    LD A,(DE)                                  ; @033B  1A                
    ADC A,C                                    ; @033C  89                
    DAA                                        ; @033D  27                
    LD (DE),A                                  ; @033E  12                
    DEC DE                                     ; @033F  1B                
    LD A,00h                                   ; @0340  3E 00             
    DJNZ loc_033A                              ; @0342  10 F6             
    RET                                        ; @0344  C9                
loc_0345:
    PUSH HL                                    ; @0345  E5                
    LD B,04h                                   ; @0346  06 04             
loc_0348:
    LD HL,4580h                                ; @0348  21 80 45          
    XOR A                                      ; @034B  AF                
    LD C,03h                                   ; @034C  0E 03             
loc_034E:
    LD A,(HL)                                  ; @034E  7E                
    ADC A,(HL)                                 ; @034F  8E                
    DAA                                        ; @0350  27                
    LD (HL),A                                  ; @0351  77                
    DEC HL                                     ; @0352  2B                
    DEC C                                      ; @0353  0D                
    JR NZ,loc_034E                             ; @0354  20 F8             
    DJNZ loc_0348                              ; @0356  10 F0             
    POP HL                                     ; @0358  E1                
    RET                                        ; @0359  C9                
KEY_SCAN:
    ; Keyboard scan; port 47h is shared with display control
    LD A,(4000h)                               ; @035A  3A 00 40          
    AND F0h                                    ; @035D  E6 F0             
    OUT (47h),A                                ; @035F  D3 47             
    EX AF,AF'                                  ; @0361  08                
    IN A,(47h)                                 ; @0362  DB 47             
    CPL                                        ; @0364  2F                
    AND C0h                                    ; @0365  E6 C0             
    CP C0h                                     ; @0367  FE C0             
    RET Z                                      ; @0369  C8                
    LD (4530h),A                               ; @036A  32 30 45          
    LD HL,4531h                                ; @036D  21 31 45          
    DEC (HL)                                   ; @0370  35                
    INC HL                                     ; @0371  23                
    XOR A                                      ; @0372  AF                
    OR (HL)                                    ; @0373  B6                
    LD B,A                                     ; @0374  47                
    INC HL                                     ; @0375  23                
    LD A,(HL)                                  ; @0376  7E                
    JP NZ,loc_0406                             ; @0377  C2 06 04          
    DEC (HL)                                   ; @037A  35                
    OR A                                       ; @037B  B7                
    JR NZ,loc_0380                             ; @037C  20 02             
    LD (HL),08h                                ; @037E  36 08             
loc_0380:
    LD C,A                                     ; @0380  4F                
    EX AF,AF'                                  ; @0381  08                
    OR C                                       ; @0382  B1                
    LD (4000h),A                               ; @0383  32 00 40          
    OUT (47h),A                                ; @0386  D3 47             
    LD A,C                                     ; @0388  79                
    OR A                                       ; @0389  B7                
    IN A,(47h)                                 ; @038A  DB 47             
    CPL                                        ; @038C  2F                
    JR NZ,loc_0391                             ; @038D  20 02             
    AND 3Fh                                    ; @038F  E6 3F             
loc_0391:
    OR A                                       ; @0391  B7                
    RET Z                                      ; @0392  C8                
    PUSH AF                                    ; @0393  F5                
    LD A,(4530h)                               ; @0394  3A 30 45          
    LD D,A                                     ; @0397  57                
    RRCA                                       ; @0398  0F                
    RRCA                                       ; @0399  0F                
    RRCA                                       ; @039A  0F                
    ADD A,D                                    ; @039B  82                
    LD D,00h                                   ; @039C  16 00             
    LD B,D                                     ; @039E  42                
    LD E,A                                     ; @039F  5F                
    LD A,C                                     ; @03A0  79                
    INC A                                      ; @03A1  3C                
    LD (4532h),A                               ; @03A2  32 32 45          
    DEC A                                      ; @03A5  3D                
    RLCA                                       ; @03A6  07                
    RLCA                                       ; @03A7  07                
    RLCA                                       ; @03A8  07                
    LD C,A                                     ; @03A9  4F                
KEY_TABLE_INDEX:
    LD HL,0565h                                ; @03AA  21 65 05          
    ADD HL,DE                                  ; @03AD  19                
    ADD HL,BC                                  ; @03AE  09                
    POP AF                                     ; @03AF  F1                
    LD (4534h),A                               ; @03B0  32 34 45          
    LD C,07h                                   ; @03B3  0E 07             
loc_03B5:
    RLCA                                       ; @03B5  07                
    JR C,loc_03BB                              ; @03B6  38 03             
    DEC C                                      ; @03B8  0D                
    JR NZ,loc_03B5                             ; @03B9  20 FA             
loc_03BB:
    ADD HL,BC                                  ; @03BB  09                
    LD A,C                                     ; @03BC  79                
    LD A,02h                                   ; @03BD  3E 02             
    LD (4535h),A                               ; @03BF  32 35 45          
    LD A,(HL)                                  ; @03C2  7E                
    LD (4536h),A                               ; @03C3  32 36 45          
KEY_TRANSLATE_EVENT:
    RST 10h                                    ; @03C6  D7                
    BIT 1,E                                    ; @03C7  CB 4B             
    JR Z,loc_03D1                              ; @03C9  28 06             
    LD HL,0003h                                ; @03CB  21 03 00          
    CALL loc_016F                              ; @03CE  CD 6F 01          
loc_03D1:
    BIT 0,E                                    ; @03D1  CB 43             
    LD A,(4536h)                               ; @03D3  3A 36 45          
    JR NZ,loc_03E7                             ; @03D6  20 0F             
    CP 61h                                     ; @03D8  FE 61             
    JR C,loc_03E4                              ; @03DA  38 08             
    CP 7Bh                                     ; @03DC  FE 7B             
    JR NC,loc_03E4                             ; @03DE  30 04             
    SUB 20h                                    ; @03E0  D6 20             
    JR loc_03E7                                ; @03E2  18 03             
loc_03E4:
    CALL loc_0051                              ; @03E4  CD 51 00          
loc_03E7:
    CP 92h                                     ; @03E7  FE 92             
    JP Z,OUTPUT_MODE_KEY                       ; @03E9  CA F2 0A          
    CP FFh                                     ; @03EC  FE FF             
    JR NZ,loc_0400                             ; @03EE  20 10             
    LD A,(4507h)                               ; @03F0  3A 07 45          
    CP 06h                                     ; @03F3  FE 06             
    JR Z,loc_03FE                              ; @03F5  28 07             
    LD A,FFh                                   ; @03F7  3E FF             
    OUT (57h),A                                ; @03F9  D3 57             
    CALL loc_0448                              ; @03FB  CD 48 04          
loc_03FE:
    LD A,FFh                                   ; @03FE  3E FF             
loc_0400:
    LD HL,44ADh                                ; @0400  21 AD 44          
    JP QUEUE_HANDLER_A                         ; @0403  C3 88 02          
loc_0406:
    DEC B                                      ; @0406  05                
    DEC (HL)                                   ; @0407  35                
    OR A                                       ; @0408  B7                
    JR NZ,loc_040D                             ; @0409  20 02             
    LD (HL),08h                                ; @040B  36 08             
loc_040D:
    XOR B                                      ; @040D  A8                
    RET NZ                                     ; @040E  C0                
    INC HL                                     ; @040F  23                
    EX AF,AF'                                  ; @0410  08                
    OR B                                       ; @0411  B0                
    OUT (47h),A                                ; @0412  D3 47             
    LD A,B                                     ; @0414  78                
    OR A                                       ; @0415  B7                
    IN A,(47h)                                 ; @0416  DB 47             
    CPL                                        ; @0418  2F                
    AND (HL)                                   ; @0419  A6                
    JR NZ,loc_0435                             ; @041A  20 19             
    INC HL                                     ; @041C  23                
    DEC (HL)                                   ; @041D  35                
    RET NZ                                     ; @041E  C0                
    LD A,(4536h)                               ; @041F  3A 36 45          
    XOR FFh                                    ; @0422  EE FF             
    JR NZ,loc_0428                             ; @0424  20 02             
    OUT (57h),A                                ; @0426  D3 57             
loc_0428:
    XOR A                                      ; @0428  AF                
    LD (4532h),A                               ; @0429  32 32 45          
    LD (4536h),A                               ; @042C  32 36 45          
    OR 20h                                     ; @042F  F6 20             
    LD (457Ch),A                               ; @0431  32 7C 45          
    RET                                        ; @0434  C9                
loc_0435:
    INC HL                                     ; @0435  23                
    LD (HL),02h                                ; @0436  36 02             
    LD HL,457Ch                                ; @0438  21 7C 45          
    DEC (HL)                                   ; @043B  35                
    RET NZ                                     ; @043C  C0                
    LD (HL),08h                                ; @043D  36 08             
    LD A,(4536h)                               ; @043F  3A 36 45          
    CP 8Bh                                     ; @0442  FE 8B             
    JP NZ,KEY_TRANSLATE_EVENT                  ; @0444  C2 C6 03          
    RET                                        ; @0447  C9                
loc_0448:
    LD HL,(466Ch)                              ; @0448  2A 6C 46          
    LD (4654h),HL                              ; @044B  22 54 46          
    CALL loc_04BA                              ; @044E  CD BA 04          
loc_0451:
    LD HL,4515h                                ; @0451  21 15 45          
    XOR A                                      ; @0454  AF                
    LD B,16h                                   ; @0455  06 16             
loc_0457:
    LD (HL),A                                  ; @0457  77                
    INC HL                                     ; @0458  23                
    DJNZ loc_0457                              ; @0459  10 FC             
    LD (4592h),A                               ; @045B  32 92 45          
    LD HL,0000h                                ; @045E  21 00 00          
    LD (4464h),HL                              ; @0461  22 64 44          
    LD (4468h),HL                              ; @0464  22 68 44          
    LD (446Ah),HL                              ; @0467  22 6A 44          
    LD A,11h                                   ; @046A  3E 11             
    LD (4525h),A                               ; @046C  32 25 45          
    RET                                        ; @046F  C9                
loc_0470:
    PUSH BC                                    ; @0470  C5                
    CALL loc_07E6                              ; @0471  CD E6 07          
    LD HL,1327h                                ; @0474  21 27 13          
    CALL loc_003F                              ; @0477  CD 3F 00          
loc_047A:
    CALL loc_0494                              ; @047A  CD 94 04          
    JR Z,loc_047A                              ; @047D  28 FB             
    CALL loc_004B                              ; @047F  CD 4B 00          
    PUSH AF                                    ; @0482  F5                
    POP HL                                     ; @0483  E1                
    LD (4503h),HL                              ; @0484  22 03 45          
    CALL loc_0828                              ; @0487  CD 28 08          
    POP BC                                     ; @048A  C1                
    LD HL,(4503h)                              ; @048B  2A 03 45          
    PUSH HL                                    ; @048E  E5                
    POP AF                                     ; @048F  F1                
    RET                                        ; @0490  C9                
loc_0491:
    CALL loc_0F35                              ; @0491  CD 35 0F          
loc_0494:
    LD HL,4537h                                ; @0494  21 37 45          
    LD A,(HL)                                  ; @0497  7E                
    OR A                                       ; @0498  B7                
    LD (HL),00h                                ; @0499  36 00             
    RET NZ                                     ; @049B  C0                
    LD HL,44ACh                                ; @049C  21 AC 44          
    JR loc_04A4                                ; @049F  18 03             
loc_04A1:
    LD HL,405Ah                                ; @04A1  21 5A 40          
loc_04A4:
    DI                                         ; @04A4  F3                
    INC HL                                     ; @04A5  23                
    CALL QUEUE_HANDLER_B                       ; @04A6  CD D8 02          
    PUSH AF                                    ; @04A9  F5                
    EI                                         ; @04AA  FB                
    POP AF                                     ; @04AB  F1                
    RET                                        ; @04AC  C9                
loc_04AD:
    LD HL,4593h                                ; @04AD  21 93 45          
    LD B,7Dh                                   ; @04B0  06 7D             
loc_04B2:
    XOR A                                      ; @04B2  AF                
loc_04B3:
    XOR (HL)                                   ; @04B3  AE                
    INC HL                                     ; @04B4  23                
    DJNZ loc_04B3                              ; @04B5  10 FC             
    CP (HL)                                    ; @04B7  BE                
    LD (HL),A                                  ; @04B8  77                
    RET                                        ; @04B9  C9                
loc_04BA:
    LD HL,4611h                                ; @04BA  21 11 46          
    LD B,46h                                   ; @04BD  06 46             
    JR loc_04B2                                ; @04BF  18 F1             
DJ_ALT_SHORTCUT:
    ; DJ variant: alters communications flag then enters common shortcut
    ; Dispatched for keycode/mode: C0/00
    LD A,FFh                                   ; @04C1  3E FF                (alternate DJ keycode C0h)
    LD (457Bh),A                               ; @04C3  32 7B 45          
DJ_SHORTCUT:
    ; DJ macro path; strings at 0543h include DOW1;;
    ; Dispatched for keycode/mode: 80/00
    CALL loc_1A06                              ; @04C6  CD 06 1A             (normal DJ keycode 80h)
    IN A,(5Fh)                                 ; @04C9  DB 5F             
    BIT 4,A                                    ; @04CB  CB 67             
    RET NZ                                     ; @04CD  C0                
    RST 10h                                    ; @04CE  D7                
    BIT 5,E                                    ; @04CF  CB 6B             
    LD DE,054Ch                                ; @04D1  11 4C 05          
    CALL Z,loc_0527                            ; @04D4  CC 27 05          
    LD A,0Dh                                   ; @04D7  3E 0D             
    JR Z,loc_04F1                              ; @04D9  28 16             
    CALL loc_02BA                              ; @04DB  CD BA 02          
    CALL loc_0A5F                              ; @04DE  CD 5F 0A          
    LD DE,0556h                                ; @04E1  11 56 05          
    LD A,(457Bh)                               ; @04E4  3A 7B 45          
    OR A                                       ; @04E7  B7                
    JR Z,loc_04EB                              ; @04E8  28 01             
    INC DE                                     ; @04EA  13                
loc_04EB:
    CALL loc_0527                              ; @04EB  CD 27 05          
    CALL loc_0A5F                              ; @04EE  CD 5F 0A          
loc_04F1:
    LD DE,4611h                                ; @04F1  11 11 46          
    CALL loc_0527                              ; @04F4  CD 27 05          
    LD A,0Dh                                   ; @04F7  3E 0D             
    CALL loc_02BA                              ; @04F9  CD BA 02          
    LD HL,457Bh                                ; @04FC  21 7B 45          
    LD A,(HL)                                  ; @04FF  7E                
    LD (HL),00h                                ; @0500  36 00             
    OR A                                       ; @0502  B7                
    RET NZ                                     ; @0503  C0                
    CALL loc_07E6                              ; @0504  CD E6 07          
    LD A,80h                                   ; @0507  3E 80             
    PUSH AF                                    ; @0509  F5                
    CALL loc_1E05                              ; @050A  CD 05 1E          
    OR A                                       ; @050D  B7                
    JP M,loc_1AE7                              ; @050E  FA E7 1A          
    CALL loc_1E5A                              ; @0511  CD 5A 1E          
    POP AF                                     ; @0514  F1                
    CALL loc_1E05                              ; @0515  CD 05 1E          
    XOR A                                      ; @0518  AF                
    LD (4514h),A                               ; @0519  32 14 45          
    LD (4515h),A                               ; @051C  32 15 45          
    CALL loc_0A64                              ; @051F  CD 64 0A          
    LD B,58h                                   ; @0522  06 58             
    JP loc_1946                                ; @0524  C3 46 19          
loc_0527:
    LD A,(457Bh)                               ; @0527  3A 7B 45          
    OR A                                       ; @052A  B7                
    JR NZ,loc_0538                             ; @052B  20 0B             
loc_052D:
    LD A,(DE)                                  ; @052D  1A                
    OR A                                       ; @052E  B7                
    RET Z                                      ; @052F  C8                
    PUSH DE                                    ; @0530  D5                
    CALL loc_02BA                              ; @0531  CD BA 02          
    POP DE                                     ; @0534  D1                
    INC DE                                     ; @0535  13                
    JR loc_0527                                ; @0536  18 EF             
loc_0538:
    LD HL,054Ch                                ; @0538  21 4C 05          
    RST 38h                                    ; @053B  FF                
    JR NZ,loc_052D                             ; @053C  20 EF             
    LD DE,0543h                                ; @053E  11 43 05          
    JR loc_052D                                ; @0541  18 EA             
DJ_SCRIPT_DATA:  ; NUL-terminated connection scripts containing DOW1;; (the exact service protocol is not yet decoded)
    DB 41h,44h,4Fh,57h,31h,3Bh,3Bh,0Dh,00h,41h,08h,44h,4Fh,57h,31h,3Bh ; @0543  41 44 4F 57 31 3B 3B 0D 00 41 08 44 4F 57 31 3B  NUL-terminated connection scripts containing DOW1;; (the exact service protocol is not yet decoded) |ADOW1;;..A.DOW1;|
    DB 3Bh,0Dh,00h,3Bh,0Dh,44h,31h,0Dh,43h,20h,36h,30h,39h,34h,32h,0Dh ; @0553  3B 0D 00 3B 0D 44 31 0D 43 20 36 30 39 34 32 0D   |;..;.D1.C 60942.|
    DB 0Dh,00h                                  ; @0563  0D 00
KB_NORMAL_TABLE:  ; First keycode layer: 72 entries, nine groups of eight
    DB 2Ch,6Bh,6Fh,39h,31h,71h,FEh,FEh          ; @0565  2C 6B 6F 39 31 71 FE FE  First keycode layer: 72 entries, nine groups of eight layer 0, scan group 0 |,ko91q..|
    DB 2Eh,6Ch,70h,30h,32h,77h,61h,7Ah          ; @056D  2E 6C 70 30 32 77 61 7A   layer 0, scan group 1 |.lp02waz|
    DB 2Fh,3Bh,40h,2Dh,33h,65h,73h,78h          ; @0575  2F 3B 40 2D 33 65 73 78   layer 0, scan group 2 |/;@-3esx|
    DB 8Dh,3Ah,0Dh,5Bh,34h,72h,64h,63h          ; @057D  8D 3A 0D 5B 34 72 64 63   layer 0, scan group 3 |.:.[4rdc|
    DB 8Bh,5Ch,89h,5Dh,35h,74h,66h,76h          ; @0585  8B 5C 89 5D 35 74 66 76   layer 0, scan group 4 |.\.]5tfv|
    DB 8Fh,8Ah,8Eh,88h,36h,79h,67h,62h          ; @058D  8F 8A 8E 88 36 79 67 62   layer 0, scan group 5
    DB 91h,20h,98h,8Ch,37h,75h,68h,6Eh          ; @0595  91 20 98 8C 37 75 68 6E   layer 0, scan group 6 |. ..7uhn|
    DB 90h,5Eh,5Fh,1Bh,38h,69h,6Ah,6Dh          ; @059D  90 5E 5F 1B 38 69 6A 6D   layer 0, scan group 7 |.^_.8ijm|
    DB 80h,81h,82h,83h,84h,85h,86h,87h          ; @05A5  80 81 82 83 84 85 86 87   layer 0, scan group 8
KB_ALT_TABLE:  ; Second keycode layer: 72 entries
    DB FEh,0Bh,0Fh,FEh,FEh,11h,FEh,FEh          ; @05AD  FE 0B 0F FE FE 11 FE FE  Second keycode layer: 72 entries layer 1, scan group 0
    DB FEh,0Ch,10h,FEh,FEh,17h,01h,1Ah          ; @05B5  FE 0C 10 FE FE 17 01 1A   layer 1, scan group 1
    DB FEh,FEh,00h,FEh,FEh,05h,13h,18h          ; @05BD  FE FE 00 FE FE 05 13 18   layer 1, scan group 2
    DB EBh,FEh,0Dh,1Bh,FEh,12h,04h,03h          ; @05C5  EB FE 0D 1B FE 12 04 03   layer 1, scan group 3
    DB CBh,1Ch,89h,1Dh,FEh,14h,06h,16h          ; @05CD  CB 1C 89 1D FE 14 06 16   layer 1, scan group 4
    DB FEh,8Ah,99h,88h,FEh,19h,07h,02h          ; @05D5  FE 8A 99 88 FE 19 07 02   layer 1, scan group 5
    DB FEh,20h,D8h,D4h,FEh,15h,08h,0Eh          ; @05DD  FE 20 D8 D4 FE 15 08 0E   layer 1, scan group 6
    DB CCh,1Eh,1Fh,FEh,FEh,09h,0Ah,0Dh          ; @05E5  CC 1E 1F FE FE 09 0A 0D   layer 1, scan group 7
    DB C0h,81h,82h,83h,84h,85h,86h,87h          ; @05ED  C0 81 82 83 84 85 86 87   layer 1, scan group 8
KB_SHIFT_TABLE:  ; Third keycode layer: 72 entries
    DB 3Ch,4Bh,4Fh,29h,21h,51h,FEh,FEh          ; @05F5  3C 4B 4F 29 21 51 FE FE  Third keycode layer: 72 entries layer 2, scan group 0 |<KO)!Q..|
    DB 3Eh,4Ch,50h,30h,22h,57h,41h,5Ah          ; @05FD  3E 4C 50 30 22 57 41 5A   layer 2, scan group 1 |>LP0"WAZ|
    DB 3Fh,2Bh,60h,3Dh,23h,45h,53h,58h          ; @0605  3F 2B 60 3D 23 45 53 58   layer 2, scan group 2 |?+`=#ESX|
    DB 95h,2Ah,0Ah,7Bh,24h,52h,44h,43h          ; @060D  95 2A 0A 7B 24 52 44 43   layer 2, scan group 3 |.*.{$RDC|
    DB 8Bh,7Ch,89h,7Dh,25h,54h,46h,56h          ; @0615  8B 7C 89 7D 25 54 46 56   layer 2, scan group 4 |.|.}%TFV|
    DB 97h,8Ah,96h,88h,26h,59h,47h,42h          ; @061D  97 8A 96 88 26 59 47 42   layer 2, scan group 5
    DB 92h,20h,93h,94h,27h,55h,48h,4Eh          ; @0625  92 20 93 94 27 55 48 4E   layer 2, scan group 6 |. ..'UHN|
    DB 90h,7Eh,7Fh,FFh,28h,49h,4Ah,4Dh          ; @062D  90 7E 7F FF 28 49 4A 4D   layer 2, scan group 7 |.~..(IJM|
    DB 80h,81h,82h,83h,C4h,C5h,C6h,C7h          ; @0635  80 81 82 83 C4 C5 C6 C7   layer 2, scan group 8
LCD_INIT_START:
    ; HD44780 initialization driven from command bytes at 0653h
    LD HL,FFFFh                                ; @063D  21 FF FF          
    CALL STATUS_CLEAR_MASK                     ; @0640  CD 4A 0A          
    LD HL,0653h                                ; @0643  21 53 06          
loc_0646:
    LD A,(HL)                                  ; @0646  7E                
    OR A                                       ; @0647  B7                
    JR Z,loc_0659                              ; @0648  28 0F             
    LD (44F6h),A                               ; @064A  32 F6 44          
    CALL LCD_COMMAND                           ; @064D  CD 60 07          
    INC HL                                     ; @0650  23                
    JR loc_0646                                ; @0651  18 F3             
LCD_INIT_COMMANDS:  ; HD44780 command table; original 34h,34h,01h,06h,0Eh,00h
    DB 34h,34h,01h,06h,0Eh,00h                  ; @0653  34 34 01 06 0E 00  HD44780 command table; original 34h,34h,01h,06h,0Eh,00h
loc_0659:
    LD HL,066Fh                                ; @0659  21 6F 06          
    LD DE,066Bh                                ; @065C  11 6B 06          
    LD B,04h                                   ; @065F  06 04             
loc_0661:
    LD A,(DE)                                  ; @0661  1A                
    CALL LCD_PATTERN_LOAD                      ; @0662  CD 96 08          
    INC DE                                     ; @0665  13                
    DJNZ loc_0661                              ; @0666  10 F9             
    JP loc_0878                                ; @0668  C3 78 08          
    DB 00h,10h,20h,30h,1Eh,10h,1Ch,10h,1Eh,07h,08h,06h,01h,0Eh,00h,1Ch ; @066B  00 10 20 30 1E 10 1C 10 1E 07 08 06 01 0E 00 1C
    DB 12h,12h,12h,1Ch,01h,01h,01h,09h,06h,00h,00h,10h,08h,04h,02h,01h ; @067B  12 12 12 1C 01 01 01 09 06 00 00 10 08 04 02 01
    DB 00h,00h,00h,00h,00h,00h,04h,04h,0Eh,0Eh,0Eh,1Fh,04h,00h,00h,00h ; @068B  00 00 00 00 00 00 04 04 0E 0E 0E 1F 04 00 00 00
    DB CDh,2Dh,07h                              ; @069B  CD 2D 07
LCD_CHAR_OUTPUT:
    PUSH BC                                    ; @069E  C5                
    CP 08h                                     ; @069F  FE 08             
    JR Z,loc_070C                              ; @06A1  28 69             
loc_06A3:
    PUSH AF                                    ; @06A3  F5                
    CALL LCD_WAIT_READY                        ; @06A4  CD 85 08          
    LD (4001h),A                               ; @06A7  32 01 40          
    LD A,(4002h)                               ; @06AA  3A 02 40          
    CP 27h                                     ; @06AD  FE 27             
    JR C,loc_06DA                              ; @06AF  38 29             
    XOR A                                      ; @06B1  AF                
    LD (400Ch),A                               ; @06B2  32 0C 40          
    LD B,26h                                   ; @06B5  06 26             
loc_06B7:
    LD A,(400Ch)                               ; @06B7  3A 0C 40          
    INC A                                      ; @06BA  3C                
    LD (400Ch),A                               ; @06BB  32 0C 40          
    OR 80h                                     ; @06BE  F6 80             
    CALL LCD_COMMAND                           ; @06C0  CD 60 07          
    CALL LCD_READ                              ; @06C3  CD 42 07          
    PUSH AF                                    ; @06C6  F5                
    LD A,(400Ch)                               ; @06C7  3A 0C 40          
    DEC A                                      ; @06CA  3D                
    OR 80h                                     ; @06CB  F6 80             
    CALL LCD_COMMAND                           ; @06CD  CD 60 07          
    POP AF                                     ; @06D0  F1                
    CALL loc_074A                              ; @06D1  CD 4A 07          
    OUT (4Bh),A                                ; @06D4  D3 4B             
    DJNZ loc_06B7                              ; @06D6  10 DF             
    JR loc_06DE                                ; @06D8  18 04             
loc_06DA:
    INC A                                      ; @06DA  3C                
    LD (4002h),A                               ; @06DB  32 02 40          
loc_06DE:
    POP AF                                     ; @06DE  F1                
    LD B,A                                     ; @06DF  47                
    CP 07h                                     ; @06E0  FE 07             
    JR NZ,loc_06EC                             ; @06E2  20 08             
    PUSH HL                                    ; @06E4  E5                
    LD HL,000Fh                                ; @06E5  21 0F 00          
    CALL loc_016F                              ; @06E8  CD 6F 01          
    POP HL                                     ; @06EB  E1                
loc_06EC:
    LD A,(453Fh)                               ; @06EC  3A 3F 45          
    OR A                                       ; @06EF  B7                
    JR NZ,loc_0704                             ; @06F0  20 12             
    LD A,B                                     ; @06F2  78                
    CP 7Fh                                     ; @06F3  FE 7F             
    JR Z,loc_06FB                              ; @06F5  28 04             
    CP 20h                                     ; @06F7  FE 20             
    JR NC,loc_0704                             ; @06F9  30 09             
loc_06FB:
    PUSH HL                                    ; @06FB  E5                
    RST 10h                                    ; @06FC  D7                
    BIT 0,H                                    ; @06FD  CB 44             
    POP HL                                     ; @06FF  E1                
    JR NZ,loc_0704                             ; @0700  20 02             
    LD B,20h                                   ; @0702  06 20             
loc_0704:
    LD A,B                                     ; @0704  78                
    CALL LCD_TRANSLATE_OUTPUT                  ; @0705  CD 55 07          
loc_0708:
    POP BC                                     ; @0708  C1                
    JP loc_07B6                                ; @0709  C3 B6 07          
loc_070C:
    LD A,(4507h)                               ; @070C  3A 07 45          
    CP 0Ah                                     ; @070F  FE 0A             
    LD A,08h                                   ; @0711  3E 08             
    JR NC,loc_06A3                             ; @0713  30 8E             
    LD A,(4002h)                               ; @0715  3A 02 40          
    OR A                                       ; @0718  B7                
    JR NZ,loc_071F                             ; @0719  20 04             
    POP BC                                     ; @071B  C1                
    JP LCD_MAIN_INIT                           ; @071C  C3 67 08          
loc_071F:
    DEC A                                      ; @071F  3D                
    RST 08h                                    ; @0720  CF                
    LD A,20h                                   ; @0721  3E 20             
    CALL LCD_TRANSLATE_OUTPUT                  ; @0723  CD 55 07          
    LD A,10h                                   ; @0726  3E 10             
    CALL LCD_COMMAND                           ; @0728  CD 60 07          
    JR loc_0708                                ; @072B  18 DB             
loc_072D:
    AND 0Fh                                    ; @072D  E6 0F             
    ADD A,90h                                  ; @072F  C6 90             
    DAA                                        ; @0731  27                
    ADC A,40h                                  ; @0732  CE 40             
    DAA                                        ; @0734  27                
    RET                                        ; @0735  C9                
    DB F5h,0Fh,0Fh,0Fh,0Fh,CDh,9Bh,06h,F1h,C3h,9Bh,06h ; @0736  F5 0F 0F 0F 0F CD 9B 06 F1 C3 9B 06
LCD_READ:
    LD A,30h                                   ; @0742  3E 30             
    CALL LCD_CONTROL_SHADOW                    ; @0744  CD 6C 07          
    IN A,(4Bh)                                 ; @0747  DB 4B             
    RET                                        ; @0749  C9                
loc_074A:
    PUSH AF                                    ; @074A  F5                
    CALL LCD_WAIT_READY                        ; @074B  CD 85 08          
    LD A,20h                                   ; @074E  3E 20             
    CALL LCD_CONTROL_SHADOW                    ; @0750  CD 6C 07          
    POP AF                                     ; @0753  F1                
    RET                                        ; @0754  C9                
LCD_TRANSLATE_OUTPUT:
    PUSH BC                                    ; @0755  C5                
    CALL loc_074A                              ; @0756  CD 4A 07          
    CALL LCD_TRANSLATION                       ; @0759  CD 7D 07          
    OUT (4Bh),A                                ; @075C  D3 4B             
    POP BC                                     ; @075E  C1                
    RET                                        ; @075F  C9                
LCD_COMMAND:
    ; Command transfer to HD44780-compatible LCD
    PUSH AF                                    ; @0760  F5                
    CALL LCD_WAIT_READY                        ; @0761  CD 85 08          
    XOR A                                      ; @0764  AF                
    CALL LCD_CONTROL_SHADOW                    ; @0765  CD 6C 07          
    POP AF                                     ; @0768  F1                
    OUT (4Bh),A                                ; @0769  D3 4B             
    RET                                        ; @076B  C9                
LCD_CONTROL_SHADOW:
    ; Shadow output port 47h, also touched by keyboard scanner
    PUSH BC                                    ; @076C  C5                
    LD B,A                                     ; @076D  47                
    DI                                         ; @076E  F3                
    LD A,(4000h)                               ; @076F  3A 00 40          
    AND 8Fh                                    ; @0772  E6 8F             
    OR B                                       ; @0774  B0                
    POP BC                                     ; @0775  C1                
    LD (4000h),A                               ; @0776  32 00 40          
    OUT (47h),A                                ; @0779  D3 47             
    EI                                         ; @077B  FB                
    RET                                        ; @077C  C9                
LCD_TRANSLATION:
    PUSH HL                                    ; @077D  E5                
    PUSH DE                                    ; @077E  D5                
    LD HL,0791h                                ; @077F  21 91 07          
    CALL loc_027B                              ; @0782  CD 7B 02          
    JR C,loc_078D                              ; @0785  38 06             
    CP 20h                                     ; @0787  FE 20             
    JR NC,loc_078E                             ; @0789  30 03             
    LD L,F8h                                   ; @078B  2E F8             
loc_078D:
    LD A,L                                     ; @078D  7D                
loc_078E:
    POP DE                                     ; @078E  D1                
    POP HL                                     ; @078F  E1                
    RET                                        ; @0790  C9                
    DB 02h,FCh,00h,03h,D0h,00h,0Dh,EBh,00h,1Bh,00h,00h,80h,02h,00h,5Ch ; @0791  02 FC 00 03 D0 00 0D EB 00 1B 00 00 80 02 00 5C
    DB 04h,00h,07h,06h,00h,67h,E7h,00h,6Ah,EAh,00h,70h,F0h,00h,71h,F1h ; @07A1  04 00 07 06 00 67 E7 00 6A EA 00 70 F0 00 71 F1
    DB 00h,79h,F9h,00h,00h                      ; @07B1  00 79 F9 00 00
loc_07B6:
    PUSH BC                                    ; @07B6  C5                
    LD B,A                                     ; @07B7  47                
    CALL LCD_WAIT_READY                        ; @07B8  CD 85 08          
    LD (4001h),A                               ; @07BB  32 01 40          
    CALL LCD_READ                              ; @07BE  CD 42 07          
    CP 20h                                     ; @07C1  FE 20             
    LD B,A                                     ; @07C3  47                
    JR NC,loc_07D9                             ; @07C4  30 13             
    OR A                                       ; @07C6  B7                
    LD B,1Bh                                   ; @07C7  06 1B             
    JR Z,loc_07D9                              ; @07C9  28 0E             
    CP 02h                                     ; @07CB  FE 02             
    LD B,80h                                   ; @07CD  06 80             
    JR Z,loc_07D9                              ; @07CF  28 08             
    CP 04h                                     ; @07D1  FE 04             
    LD B,5Ch                                   ; @07D3  06 5C             
    JR Z,loc_07D9                              ; @07D5  28 02             
    LD B,07h                                   ; @07D7  06 07             
loc_07D9:
    LD A,B                                     ; @07D9  78                
    LD (4003h),A                               ; @07DA  32 03 40          
    POP BC                                     ; @07DD  C1                
    LD A,(4001h)                               ; @07DE  3A 01 40          
    OR 80h                                     ; @07E1  F6 80             
    JP LCD_COMMAND                             ; @07E3  C3 60 07          
loc_07E6:
    LD (4503h),A                               ; @07E6  32 03 45          
    CALL loc_081C                              ; @07E9  CD 1C 08          
    POP HL                                     ; @07EC  E1                
    LD (44FAh),HL                              ; @07ED  22 FA 44          
    LD HL,(4006h)                              ; @07F0  2A 06 40          
    PUSH HL                                    ; @07F3  E5                
    CALL loc_0A47                              ; @07F4  CD 47 0A          
    LD A,(4507h)                               ; @07F7  3A 07 45          
    PUSH AF                                    ; @07FA  F5                
    LD A,(4503h)                               ; @07FB  3A 03 45          
    LD (4507h),A                               ; @07FE  32 07 45          
    LD A,(4002h)                               ; @0801  3A 02 40          
    PUSH AF                                    ; @0804  F5                
    LD B,13h                                   ; @0805  06 13             
    LD A,80h                                   ; @0807  3E 80             
    CALL LCD_COMMAND                           ; @0809  CD 60 07          
loc_080C:
    CALL LCD_READ                              ; @080C  CD 42 07          
    LD D,A                                     ; @080F  57                
    CALL LCD_READ                              ; @0810  CD 42 07          
    LD E,A                                     ; @0813  5F                
    PUSH DE                                    ; @0814  D5                
    DEC B                                      ; @0815  05                
    JP P,loc_080C                              ; @0816  F2 0C 08          
    RST 18h                                    ; @0819  DF                
    JR loc_0857                                ; @081A  18 3B             
loc_081C:
    LD (44FCh),HL                              ; @081C  22 FC 44          
    LD (44FEh),DE                              ; @081F  ED 53 FE 44       
    LD (4500h),BC                              ; @0823  ED 43 00 45       
    RET                                        ; @0827  C9                
loc_0828:
    CALL loc_081C                              ; @0828  CD 1C 08          
    RST 18h                                    ; @082B  DF                
    POP HL                                     ; @082C  E1                
    LD (44FAh),HL                              ; @082D  22 FA 44          
    LD B,13h                                   ; @0830  06 13             
    LD C,26h                                   ; @0832  0E 26             
loc_0834:
    POP DE                                     ; @0834  D1                
    LD A,C                                     ; @0835  79                
    RST 08h                                    ; @0836  CF                
    LD A,D                                     ; @0837  7A                
    CALL loc_074A                              ; @0838  CD 4A 07          
    OUT (4Bh),A                                ; @083B  D3 4B             
    LD A,E                                     ; @083D  7B                
    CALL loc_074A                              ; @083E  CD 4A 07          
    OUT (4Bh),A                                ; @0841  D3 4B             
    DEC C                                      ; @0843  0D                
    DEC C                                      ; @0844  0D                
    DEC B                                      ; @0845  05                
    JP P,loc_0834                              ; @0846  F2 34 08          
    POP AF                                     ; @0849  F1                
    RST 08h                                    ; @084A  CF                
    POP AF                                     ; @084B  F1                
    LD (4507h),A                               ; @084C  32 07 45          
    LD HL,FFFFh                                ; @084F  21 FF FF          
    CALL STATUS_CLEAR_MASK                     ; @0852  CD 4A 0A          
    POP HL                                     ; @0855  E1                
    RST 28h                                    ; @0856  EF                
loc_0857:
    LD HL,(44FAh)                              ; @0857  2A FA 44          
    PUSH HL                                    ; @085A  E5                
    LD BC,(4500h)                              ; @085B  ED 4B 00 45       
    LD DE,(44FEh)                              ; @085F  ED 5B FE 44       
    LD HL,(44FCh)                              ; @0863  2A FC 44          
    RET                                        ; @0866  C9                
LCD_MAIN_INIT:
    ; HD44780 driver initialization/service
    XOR A                                      ; @0867  AF                
    RST 08h                                    ; @0868  CF                
    LD A,80h                                   ; @0869  3E 80             
    CALL LCD_COMMAND                           ; @086B  CD 60 07          
    LD A,02h                                   ; @086E  3E 02             
    CALL LCD_COMMAND                           ; @0870  CD 60 07          
    LD A,01h                                   ; @0873  3E 01             
    CALL LCD_COMMAND                           ; @0875  CD 60 07          
loc_0878:
    XOR A                                      ; @0878  AF                
loc_0879:
    LD (4002h),A                               ; @0879  32 02 40          
    PUSH BC                                    ; @087C  C5                
    OR 80h                                     ; @087D  F6 80             
    CALL LCD_COMMAND                           ; @087F  CD 60 07          
    JP loc_0708                                ; @0882  C3 08 07          
LCD_WAIT_READY:
    ; Poll bit 7 through port 4Bh: consistent with HD44780 busy flag
    LD A,10h                                   ; @0885  3E 10             
    CALL LCD_CONTROL_SHADOW                    ; @0887  CD 6C 07          
loc_088A:
    IN A,(4Bh)                                 ; @088A  DB 4B             
    RLCA                                       ; @088C  07                
    JR C,loc_088A                              ; @088D  38 FB             
    IN A,(4Bh)                                 ; @088F  DB 4B             
    RLCA                                       ; @0891  07                
    JR C,loc_088A                              ; @0892  38 F6             
    RRCA                                       ; @0894  0F                
    RET                                        ; @0895  C9                
LCD_PATTERN_LOAD:
    PUSH BC                                    ; @0896  C5                
    LD C,A                                     ; @0897  4F                
    LD B,0Bh                                   ; @0898  06 0B             
loc_089A:
    LD A,C                                     ; @089A  79                
    OR 40h                                     ; @089B  F6 40             
    CALL LCD_COMMAND                           ; @089D  CD 60 07          
    CALL loc_074A                              ; @08A0  CD 4A 07          
    LD A,(HL)                                  ; @08A3  7E                
    OUT (4Bh),A                                ; @08A4  D3 4B             
    INC HL                                     ; @08A6  23                
    INC C                                      ; @08A7  0C                
    DJNZ loc_089A                              ; @08A8  10 F0             
    POP BC                                     ; @08AA  C1                
    RET                                        ; @08AB  C9                
loc_08AC:
    CALL loc_08F2                              ; @08AC  CD F2 08          
    LD A,B                                     ; @08AF  78                
    OR A                                       ; @08B0  B7                
    JR Z,loc_08C8                              ; @08B1  28 15             
    DEC B                                      ; @08B3  05                
loc_08B4:
    CALL loc_0925                              ; @08B4  CD 25 09          
    CP 0Dh                                     ; @08B7  FE 0D             
    JR C,loc_08BF                              ; @08B9  38 04             
    CALL loc_0925                              ; @08BB  CD 25 09          
    XOR A                                      ; @08BE  AF                
loc_08BF:
    CP 0Ch                                     ; @08BF  FE 0C             
    JR NZ,loc_08B4                             ; @08C1  20 F1             
    CALL loc_08EB                              ; @08C3  CD EB 08          
    JR loc_08AC                                ; @08C6  18 E4             
loc_08C8:
    CALL loc_08EB                              ; @08C8  CD EB 08          
loc_08CB:
    CALL loc_08F2                              ; @08CB  CD F2 08          
loc_08CE:
    CALL loc_0925                              ; @08CE  CD 25 09          
    CP 0Ch                                     ; @08D1  FE 0C             
    JR Z,loc_08EB                              ; @08D3  28 16             
    JR NC,loc_08F7                             ; @08D5  30 20             
    PUSH HL                                    ; @08D7  E5                
    LD HL,0939h                                ; @08D8  21 39 09          
loc_08DB:
    LD C,A                                     ; @08DB  4F                
    LD B,00h                                   ; @08DC  06 00             
    ADD HL,BC                                  ; @08DE  09                
    LD A,(HL)                                  ; @08DF  7E                
    LD (DE),A                                  ; @08E0  12                
    INC DE                                     ; @08E1  13                
loc_08E2:
    POP HL                                     ; @08E2  E1                
    JR loc_08CE                                ; @08E3  18 E9             
loc_08E5:
    ADD A,C                                    ; @08E5  81                
    LD HL,0945h                                ; @08E6  21 45 09          
    JR loc_08DB                                ; @08E9  18 F0             
loc_08EB:
    LD A,(4508h)                               ; @08EB  3A 08 45          
    OR A                                       ; @08EE  B7                
    RET Z                                      ; @08EF  C8                
    INC HL                                     ; @08F0  23                
    RET                                        ; @08F1  C9                
loc_08F2:
    XOR A                                      ; @08F2  AF                
    LD (4508h),A                               ; @08F3  32 08 45          
    RET                                        ; @08F6  C9                
loc_08F7:
    ADD A,F3h                                  ; @08F7  C6 F3             
    RLCA                                       ; @08F9  07                
    RLCA                                       ; @08FA  07                
    RLCA                                       ; @08FB  07                
    RLCA                                       ; @08FC  07                
    LD C,A                                     ; @08FD  4F                
    CALL loc_0925                              ; @08FE  CD 25 09          
    PUSH HL                                    ; @0901  E5                
    CP 07h                                     ; @0902  FE 07             
    JR C,loc_08E5                              ; @0904  38 DF             
    LD B,A                                     ; @0906  47                
    LD A,C                                     ; @0907  79                
    CP 20h                                     ; @0908  FE 20             
    LD A,B                                     ; @090A  78                
    JR NZ,loc_08E5                             ; @090B  20 D8             
    LD HL,096Ch                                ; @090D  21 6C 09          
    ADD A,F9h                                  ; @0910  C6 F9             
    JR Z,loc_091C                              ; @0912  28 08             
    LD B,A                                     ; @0914  47                
loc_0915:
    LD A,(HL)                                  ; @0915  7E                
    INC HL                                     ; @0916  23                
    OR A                                       ; @0917  B7                
    JR NZ,loc_0915                             ; @0918  20 FB             
    DJNZ loc_0915                              ; @091A  10 F9             
loc_091C:
    LD A,(HL)                                  ; @091C  7E                
    INC HL                                     ; @091D  23                
    OR A                                       ; @091E  B7                
    JR Z,loc_08E2                              ; @091F  28 C1             
    LD (DE),A                                  ; @0921  12                
    INC DE                                     ; @0922  13                
    JR loc_091C                                ; @0923  18 F7             
loc_0925:
    LD A,(4508h)                               ; @0925  3A 08 45          
    XOR FFh                                    ; @0928  EE FF             
    LD (4508h),A                               ; @092A  32 08 45          
    LD A,(HL)                                  ; @092D  7E                
    INC HL                                     ; @092E  23                
    JR Z,loc_0936                              ; @092F  28 05             
    DEC HL                                     ; @0931  2B                
    RRCA                                       ; @0932  0F                
    RRCA                                       ; @0933  0F                
    RRCA                                       ; @0934  0F                
    RRCA                                       ; @0935  0F                
loc_0936:
    AND 0Fh                                    ; @0936  E6 0F             
    RET                                        ; @0938  C9                
    DB 20h,65h,69h,74h,6Eh,72h,6Fh,6Ch,61h,64h,73h,63h,68h,66h,70h,6Dh ; @0939  20 65 69 74 6E 72 6F 6C 61 64 73 63 68 66 70 6D   | eitnroladschfpm|
    DB 75h,62h,77h,79h,3Eh,67h,28h,29h,2Dh,76h,2Ah,6Bh,78h,2Ch,22h,3Fh ; @0949  75 62 77 79 3E 67 28 29 2D 76 2A 6B 78 2C 22 3F   |ubwy>g()-v*kx,"?|
    DB 2Fh,31h,32h,23h,30h,33h,6Ah,7Ah,2Eh,3Ch,34h,35h,37h,38h,39h,71h ; @0959  2F 31 32 23 30 33 6A 7A 2E 3C 34 35 37 38 39 71   |/12#03jz.<45789q|
    DB 36h,3Dh,80h,70h,72h,65h,73h,73h,20h,58h,49h,54h,20h,77h,68h,65h ; @0969  36 3D 80 70 72 65 73 73 20 58 49 54 20 77 68 65   |6=.press XIT whe|
    DB 6Eh,20h,64h,6Fh,6Eh,65h,00h,20h,66h,72h,6Fh,6Dh,20h,63h,75h,72h ; @0979  6E 20 64 6F 6E 65 00 20 66 72 6F 6D 20 63 75 72   |n done. from cur|
    DB 72h,65h,6Eh,74h,20h,70h,6Fh,73h,69h,74h,69h,6Fh,6Eh,00h,76h,61h ; @0989  72 65 6E 74 20 70 6F 73 69 74 69 6F 6E 00 76 61   |rent position.va|
    DB 6Ch,69h,64h,20h,6Fh,6Eh,6Ch,79h,20h,69h,6Eh,20h,65h,64h,69h,74h ; @0999  6C 69 64 20 6F 6E 6C 79 20 69 6E 20 65 64 69 74   |lid only in edit|
    DB 6Fh,72h,00h,20h,66h,69h,6Ch,65h,00h,6Dh,65h,6Dh,6Fh,72h,79h,00h ; @09A9  6F 72 00 20 66 69 6C 65 00 6D 65 6D 6F 72 79 00   |or. file.memory.|
    DB 20h,63h,6Fh,6Eh,66h,69h,67h,75h,72h,61h,74h,69h,6Fh,6Eh,20h,00h ; @09B9  20 63 6F 6E 66 69 67 75 72 61 74 69 6F 6E 20 00   | configuration .|
    DB 61h,72h,72h,6Fh,77h,00h,73h,65h,6Ch,65h,63h,74h,00h,00h ; @09C9  61 72 72 6F 77 00 73 65 6C 65 63 74 00 00   |arrow.select..|
loc_09D7:
    XOR A                                      ; @09D7  AF                
    LD (DE),A                                  ; @09D8  12                
loc_09D9:
    LD HL,4013h                                ; @09D9  21 13 40          
    JR loc_09DF                                ; @09DC  18 01             
    DB CFh                                      ; @09DE  CF
loc_09DF:
    LD A,(HL)                                  ; @09DF  7E                
    OR A                                       ; @09E0  B7                
    JP Z,loc_0B35                              ; @09E1  CA 35 0B          
    CALL LCD_CHAR_OUTPUT                       ; @09E4  CD 9E 06          
    INC HL                                     ; @09E7  23                
    JR loc_09DF                                ; @09E8  18 F5             
loc_09EA:
    LD HL,4013h                                ; @09EA  21 13 40          
    RST 18h                                    ; @09ED  DF                
    JR loc_09DF                                ; @09EE  18 EF             
loc_09F0:
    LD DE,4013h                                ; @09F0  11 13 40          
    JP loc_08CB                                ; @09F3  C3 CB 08          
loc_09F6:
    LD A,02h                                   ; @09F6  3E 02             
    JR loc_09FA                                ; @09F8  18 00             
loc_09FA:
    PUSH BC                                    ; @09FA  C5                
    CPL                                        ; @09FB  2F                
    LD B,A                                     ; @09FC  47                
    LD A,(44F6h)                               ; @09FD  3A F6 44          
    AND B                                      ; @0A00  A0                
loc_0A01:
    LD (44F6h),A                               ; @0A01  32 F6 44          
    POP BC                                     ; @0A04  C1                
    JP LCD_COMMAND                             ; @0A05  C3 60 07          
loc_0A08:
    LD A,02h                                   ; @0A08  3E 02             
    JR loc_0A0C                                ; @0A0A  18 00             
loc_0A0C:
    PUSH BC                                    ; @0A0C  C5                
    LD B,A                                     ; @0A0D  47                
    LD A,(44F6h)                               ; @0A0E  3A F6 44          
    OR B                                       ; @0A11  B0                
    JR loc_0A01                                ; @0A12  18 ED             
loc_0A14:
    CALL loc_0A47                              ; @0A14  CD 47 0A          
    LD DE,0000h                                ; @0A17  11 00 00          
    LD H,E                                     ; @0A1A  63                
    LD A,B                                     ; @0A1B  78                
    CP 02h                                     ; @0A1C  FE 02             
    JR C,loc_0A22                              ; @0A1E  38 02             
    LD D,80h                                   ; @0A20  16 80             
loc_0A22:
    CP C                                       ; @0A22  B9                
    JR NC,loc_0A27                             ; @0A23  30 02             
    LD E,20h                                   ; @0A25  1E 20             
loc_0A27:
    LD A,D                                     ; @0A27  7A                
    OR E                                       ; @0A28  B3                
    LD L,A                                     ; @0A29  6F                
    JR STATUS_SET_MASK                         ; @0A2A  18 08             
    DB 21h,50h,00h,18h,03h,21h,A0h,00h          ; @0A2C  21 50 00 18 03 21 A0 00
STATUS_SET_MASK:
    ; OR H/L into shadows at 4007h/4006h; output to 4Fh/53h; status indicator candidate
    LD A,(4007h)                               ; @0A34  3A 07 40          
    OR H                                       ; @0A37  B4                
    LD (4007h),A                               ; @0A38  32 07 40          
    OUT (4Fh),A                                ; @0A3B  D3 4F             
    LD A,(4006h)                               ; @0A3D  3A 06 40          
    OR L                                       ; @0A40  B5                
loc_0A41:
    LD (4006h),A                               ; @0A41  32 06 40          
    OUT (53h),A                                ; @0A44  D3 53             
    RET                                        ; @0A46  C9                
loc_0A47:
    LD HL,00F0h                                ; @0A47  21 F0 00          
STATUS_CLEAR_MASK:
    ; Complement H/L and AND out bits from status shadow registers
    LD A,H                                     ; @0A4A  7C                
    CPL                                        ; @0A4B  2F                
    LD H,A                                     ; @0A4C  67                
    LD A,L                                     ; @0A4D  7D                
    CPL                                        ; @0A4E  2F                
    LD L,A                                     ; @0A4F  6F                
    LD A,(4007h)                               ; @0A50  3A 07 40          
    AND H                                      ; @0A53  A4                
    LD (4007h),A                               ; @0A54  32 07 40          
    OUT (4Fh),A                                ; @0A57  D3 4F             
    LD A,(4006h)                               ; @0A59  3A 06 40          
    AND L                                      ; @0A5C  A5                
    JR loc_0A41                                ; @0A5D  18 E2             
loc_0A5F:
    LD BC,5555h                                ; @0A5F  01 55 55          
    JR loc_0A67                                ; @0A62  18 03             
loc_0A64:
    LD BC,0CCCh                                ; @0A64  01 CC 0C          
loc_0A67:
    PUSH BC                                    ; @0A67  C5                
    CALL loc_0494                              ; @0A68  CD 94 04          
    POP BC                                     ; @0A6B  C1                
    JR NZ,loc_0A73                             ; @0A6C  20 05             
    DEC BC                                     ; @0A6E  0B                
    LD A,B                                     ; @0A6F  78                
    OR C                                       ; @0A70  B1                
    JR NZ,loc_0A67                             ; @0A71  20 F4             
loc_0A73:
    LD (4537h),A                               ; @0A73  32 37 45          
    RET                                        ; @0A76  C9                
STATUS_REFRESH_DOCUMENTS:
    ; Document count at 4593h governs mask 0008h; candidate MEMORY indicator
    LD A,(4593h)                               ; @0A77  3A 93 45          
    LD HL,0008h                                ; @0A7A  21 08 00          
loc_0A7D:
    OR A                                       ; @0A7D  B7                
    JR Z,STATUS_CLEAR_MASK                     ; @0A7E  28 CA             
    JR STATUS_SET_MASK                         ; @0A80  18 B2             
loc_0A82:
    LD A,(4592h)                               ; @0A82  3A 92 45          
    LD HL,0400h                                ; @0A85  21 00 04          
    JR loc_0A7D                                ; @0A88  18 F3             
loc_0A8A:
    LD A,(4514h)                               ; @0A8A  3A 14 45          
    LD HL,1000h                                ; @0A8D  21 00 10          
    JR loc_0A7D                                ; @0A90  18 EB             
loc_0A92:
    LD A,(4517h)                               ; @0A92  3A 17 45          
    LD HL,2000h                                ; @0A95  21 00 20          
    JR loc_0A7D                                ; @0A98  18 E3             
STATUS_REFRESH_ALL:
    ; Periodic refresh of firmware status indicators
    LD HL,0800h                                ; @0A9A  21 00 08          
    CALL STATUS_CLEAR_MASK                     ; @0A9D  CD 4A 0A          
    IN A,(5Fh)                                 ; @0AA0  DB 5F             
    BIT 4,A                                    ; @0AA2  CB 67             
    LD HL,0800h                                ; @0AA4  21 00 08          
    CALL Z,STATUS_SET_MASK                     ; @0AA7  CC 34 0A          
    LD HL,(405Bh)                              ; @0AAA  2A 5B 40          
    LD A,H                                     ; @0AAD  7C                
    OR L                                       ; @0AAE  B5                
    LD HL,(4464h)                              ; @0AAF  2A 64 44          
    OR H                                       ; @0AB2  B4                
    OR L                                       ; @0AB3  B5                
    JR Z,loc_0ABF                              ; @0AB4  28 09             
    LD HL,4000h                                ; @0AB6  21 00 40          
    RST 28h                                    ; @0AB9  EF                
    LD A,FFh                                   ; @0ABA  3E FF             
    LD (4516h),A                               ; @0ABC  32 16 45          
loc_0ABF:
    CALL loc_0A82                              ; @0ABF  CD 82 0A          
    CALL loc_0A8A                              ; @0AC2  CD 8A 0A          
    CALL loc_0A92                              ; @0AC5  CD 92 0A          
    CALL STATUS_REFRESH_DOCUMENTS              ; @0AC8  CD 77 0A          
    LD HL,8000h                                ; @0ACB  21 00 80          
    IN A,(43h)                                 ; @0ACE  DB 43             
    CPL                                        ; @0AD0  2F                
    AND 0Ch                                    ; @0AD1  E6 0C             
    PUSH AF                                    ; @0AD3  F5                
    CALL loc_0A7D                              ; @0AD4  CD 7D 0A          
    POP AF                                     ; @0AD7  F1                
    RET Z                                      ; @0AD8  C8                
    LD DE,44F5h                                ; @0AD9  11 F5 44          
    LD A,(DE)                                  ; @0ADC  1A                
    OR A                                       ; @0ADD  B7                
    RET NZ                                     ; @0ADE  C0                
    LD HL,4002h                                ; @0ADF  21 02 40          
    CALL RTC_READ_REGISTER                              ; @0AE2  CD CC 0B          
    AND 0Fh                                    ; @0AE5  E6 0F             
    RET NZ                                     ; @0AE7  C0                
    INC A                                      ; @0AE8  3C                
    LD (DE),A                                  ; @0AE9  12                
    JP loc_016C                                ; @0AEA  C3 6C 01          
loc_0AED:
    IN A,(4Fh)                                 ; @0AED  DB 4F             
    AND 02h                                    ; @0AEF  E6 02             
    RET                                        ; @0AF1  C9                
OUTPUT_MODE_KEY:
    DI                                         ; @0AF2  F3                
    LD HL,4012h                                ; @0AF3  21 12 40          
    LD A,(HL)                                  ; @0AF6  7E                
    CP 01h                                     ; @0AF7  FE 01             
    JR NZ,loc_0AFF                             ; @0AF9  20 04             
    LD (HL),FFh                                ; @0AFB  36 FF             
    JR loc_0B0A                                ; @0AFD  18 0B             
loc_0AFF:
    CALL loc_0AED                              ; @0AFF  CD ED 0A          
    JR NZ,loc_0B0A                             ; @0B02  20 06             
    LD (HL),01h                                ; @0B04  36 01             
    XOR A                                      ; @0B06  AF                
    LD (400Eh),A                               ; @0B07  32 0E 40          
loc_0B0A:
    EI                                         ; @0B0A  FB                
    RET                                        ; @0B0B  C9                
AUX_QUEUE_OUTPUT:
    PUSH BC                                    ; @0B0C  C5                
    LD B,A                                     ; @0B0D  47                
    LD A,(4012h)                               ; @0B0E  3A 12 40          
    OR A                                       ; @0B11  B7                
    LD A,B                                     ; @0B12  78                
    POP BC                                     ; @0B13  C1                
    RET Z                                      ; @0B14  C8                
    PUSH HL                                    ; @0B15  E5                
    PUSH BC                                    ; @0B16  C5                
    LD HL,400Eh                                ; @0B17  21 0E 40          
    LD B,A                                     ; @0B1A  47                
    LD A,(HL)                                  ; @0B1B  7E                
    LD (HL),B                                  ; @0B1C  70                
    CP 0Dh                                     ; @0B1D  FE 0D             
    LD A,B                                     ; @0B1F  78                
    INC HL                                     ; @0B20  23                
    JR NZ,loc_0B27                             ; @0B21  20 04             
    CP 0Ah                                     ; @0B23  FE 0A             
    JR Z,loc_0B30                              ; @0B25  28 09             
loc_0B27:
    LD A,(HL)                                  ; @0B27  7E                
    OR A                                       ; @0B28  B7                
    JR NZ,loc_0B27                             ; @0B29  20 FC             
    DI                                         ; @0B2B  F3                
    LD (HL),01h                                ; @0B2C  36 01             
    INC HL                                     ; @0B2E  23                
    LD (HL),B                                  ; @0B2F  70                
loc_0B30:
    EI                                         ; @0B30  FB                
    LD A,B                                     ; @0B31  78                
    POP BC                                     ; @0B32  C1                
    POP HL                                     ; @0B33  E1                
    RET                                        ; @0B34  C9                
loc_0B35:
    LD A,(4507h)                               ; @0B35  3A 07 45          
    OR A                                       ; @0B38  B7                
    RET Z                                      ; @0B39  C8                
    CP 03h                                     ; @0B3A  FE 03             
    RET Z                                      ; @0B3C  C8                
    CP 06h                                     ; @0B3D  FE 06             
    RET Z                                      ; @0B3F  C8                
    CP 09h                                     ; @0B40  FE 09             
    RET Z                                      ; @0B42  C8                
    CP 08h                                     ; @0B43  FE 08             
    RET Z                                      ; @0B45  C8                
AUX_OUTPUT_STRING:
    PUSH HL                                    ; @0B46  E5                
    LD HL,4013h                                ; @0B47  21 13 40          
loc_0B4A:
    LD A,(HL)                                  ; @0B4A  7E                
    CALL AUX_QUEUE_OUTPUT                      ; @0B4B  CD 0C 0B          
    INC HL                                     ; @0B4E  23                
    OR A                                       ; @0B4F  B7                
    JR NZ,loc_0B4A                             ; @0B50  20 F8             
    POP HL                                     ; @0B52  E1                
    LD A,0Dh                                   ; @0B53  3E 0D             
    JR AUX_QUEUE_OUTPUT                        ; @0B55  18 B5             
loc_0B57:
    CALL AUX_OUTPUT_STRING                     ; @0B57  CD 46 0B          
    INC B                                      ; @0B5A  04                
    DEC C                                      ; @0B5B  0D                
    RET                                        ; @0B5C  C9                
AUX_OUTPUT_RULE:
    ; 40 ASCII hyphens and CR emitted to auxiliary channel: printer-style formatting
    PUSH BC                                    ; @0B5D  C5                
    LD B,28h                                   ; @0B5E  06 28             
loc_0B60:
    LD A,2Dh                                   ; @0B60  3E 2D             
    CALL AUX_QUEUE_OUTPUT                      ; @0B62  CD 0C 0B          
    DJNZ loc_0B60                              ; @0B65  10 F9             
    POP BC                                     ; @0B67  C1                
    LD A,0Dh                                   ; @0B68  3E 0D             
    JR AUX_QUEUE_OUTPUT                        ; @0B6A  18 A0             
RTC_RESET_AND_INITIALIZE:
    ; RTC initialization: read interrupt status at 4010h, disable interrupts at 4011h, reset counters/RAM at 4012h/4013h, write time and GO at 4015h
    LD HL,4010h                                ; @0B6C  21 10 40          
    CALL RTC_READ_REGISTER                              ; @0B6F  CD CC 0B          
    INC HL                                     ; @0B72  23                
    LD B,00h                                   ; @0B73  06 00             
    CALL RTC_WRITE_REGISTER                              ; @0B75  CD E3 0B          
    DEC B                                      ; @0B78  05                
    INC HL                                     ; @0B79  23                
    CALL RTC_WRITE_REGISTER                              ; @0B7A  CD E3 0B          
    INC HL                                     ; @0B7D  23                
    CALL RTC_WRITE_REGISTER                              ; @0B7E  CD E3 0B          
    LD IX,0BBFh                                ; @0B81  DD 21 BF 0B       
    CALL RTC_WRITE_FIELDS                              ; @0B85  CD 2C 0C          
    LD HL,4015h                                ; @0B88  21 15 40          
    CALL RTC_WRITE_REGISTER                              ; @0B8B  CD E3 0B          
    LD B,00h                                   ; @0B8E  06 00             
    INC HL                                     ; @0B90  23                
    CALL RTC_WRITE_REGISTER                              ; @0B91  CD E3 0B          
RTC_REFRESH_DISPLAY_VALUES:
    ; Reads RTC time then formats/refreshes clock display
    CALL RTC_READ_TIME_BLOCK                              ; @0B94  CD F5 0B          
    LD A,(4664h)                               ; @0B97  3A 64 46          
    LD B,A                                     ; @0B9A  47                
    LD A,(4659h)                               ; @0B9B  3A 59 46          
    CP B                                       ; @0B9E  B8                
    JR NC,loc_0BB5                             ; @0B9F  30 14             
    LD IX,4658h                                ; @0BA1  DD 21 58 46       
    LD A,(4008h)                               ; @0BA5  3A 08 40          
    PUSH AF                                    ; @0BA8  F5                
    LD A,03h                                   ; @0BA9  3E 03             
    LD (4008h),A                               ; @0BAB  32 08 40          
    CALL loc_0D00                              ; @0BAE  CD 00 0D          
    POP AF                                     ; @0BB1  F1                
    LD (4008h),A                               ; @0BB2  32 08 40          
loc_0BB5:
    CALL NC,loc_0E75                           ; @0BB5  D4 75 0E          
    LD A,(44F9h)                               ; @0BB8  3A F9 44          
    OR A                                       ; @0BBB  B7                
    JR NZ,RTC_WRITE_TIME_BLOCK                             ; @0BBC  20 6A             
    RET                                        ; @0BBE  C9                
RTC_INITIAL_VALUES:  ; 13-byte default BCD data values for MM58167 registers, copied through 0C2Ch
    DB 07h,01h,01h,19h,83h,00h,00h,00h,01h,00h,00h,00h,01h ; @0BBF  07 01 01 19 83 00 00 00 01 00 00 00 01
RTC_READ_REGISTER:
    ; MM58167 RTC register READ (HL=4000h+register): switches bus, reads, polls 4014h bit0 for rollover, restores bank and EI
    PUSH DE                                    ; @0BCC  D5                
    PUSH BC                                    ; @0BCD  C5                
    CALL RTC_SELECT_BANK                              ; @0BCE  CD ED 0B          
    OUT (47h),A                                ; @0BD1  D3 47             
    LD DE,4014h                                ; @0BD3  11 14 40          
loc_0BD6:
    LD B,(HL)                                  ; @0BD6  46                
    LD A,(DE)                                  ; @0BD7  1A                
    RRCA                                       ; @0BD8  0F                
    JR C,loc_0BD6                              ; @0BD9  38 FB             
RTC_END_ACCESS:
    ; Restore original port 47h bus control, enable interrupts, return RTC byte in A
    LD A,C                                     ; @0BDB  79                
    OUT (47h),A                                ; @0BDC  D3 47             
    EI                                         ; @0BDE  FB                
    LD A,B                                     ; @0BDF  78                
    POP BC                                     ; @0BE0  C1                
    POP DE                                     ; @0BE1  D1                
    RET                                        ; @0BE2  C9                
RTC_WRITE_REGISTER:
    ; MM58167 RTC register WRITE (HL=4000h+register, B=value): briefly select bus then write, restore bus
    PUSH DE                                    ; @0BE3  D5                
    PUSH BC                                    ; @0BE4  C5                
    CALL RTC_SELECT_BANK                              ; @0BE5  CD ED 0B          
    OUT (47h),A                                ; @0BE8  D3 47             
    LD (HL),B                                  ; @0BEA  70                
    JR RTC_END_ACCESS                                ; @0BEB  18 EE             
RTC_SELECT_BANK:
    ; Save port 47h shadow from 4000h, OR 40h to enable RTC address window, mask interrupts during transaction
    DI                                         ; @0BED  F3                
    LD A,(4000h)                               ; @0BEE  3A 00 40          
    LD C,A                                     ; @0BF1  4F                
    OR 40h                                     ; @0BF2  F6 40             
    RET                                        ; @0BF4  C9                
RTC_READ_TIME_BLOCK:
    ; Read 13 RTC registers specified at 0C1Bh into buffer 4658h; mixed counters and alarm RAM
    LD DE,0C1Bh                                ; @0BF5  11 1B 0C          
    LD B,0Dh                                   ; @0BF8  06 0D             
    LD IX,4658h                                ; @0BFA  DD 21 58 46       
loc_0BFE:
    LD A,(DE)                                  ; @0BFE  1A                
    INC DE                                     ; @0BFF  13                
    LD H,40h                                   ; @0C00  26 40             
    LD L,A                                     ; @0C02  6F                
    CALL RTC_READ_REGISTER                              ; @0C03  CD CC 0B          
    LD (IX+0),A                                ; @0C06  DD 77 00          
    INC IX                                     ; @0C09  DD 23             
    DJNZ loc_0BFE                              ; @0C0B  10 F1             
    LD DE,3102h                                ; @0C0D  11 02 31          
    LD HL,(4659h)                              ; @0C10  2A 59 46          
    RST 38h                                    ; @0C13  FF                
    RET NZ                                     ; @0C14  C0                
    LD H,29h                                   ; @0C15  26 29             
    LD (4659h),HL                              ; @0C17  22 59 46          
    RET                                        ; @0C1A  C9                
RTC_REGISTER_LIST:  ; 13 MM58167 register offsets: 05 07 06 0A 09 04 03 02 0F 0C 0B 0D 0E
    DB 05h,07h,06h,0Ah,09h,04h,03h,02h,0Fh,0Ch,0Bh,0Dh,0Eh ; @0C1B  05 07 06 0A 09 04 03 02 0F 0C 0B 0D 0E
RTC_WRITE_TIME_BLOCK:
    ; Write clock data from RAM buffer to RTC using table at 0C1Bh
    LD IX,4658h                                ; @0C28  DD 21 58 46       
RTC_WRITE_FIELDS:
    ; Common RTC write loop through register-address table
    LD A,(4659h)                               ; @0C2C  3A 59 46          
    LD (4664h),A                               ; @0C2F  32 64 46          
    LD DE,2902h                                ; @0C32  11 02 29          
    LD HL,(4659h)                              ; @0C35  2A 59 46          
    RST 38h                                    ; @0C38  FF                
    JR NZ,loc_0C40                             ; @0C39  20 05             
    LD A,31h                                   ; @0C3B  3E 31             
    LD (4011h),A                               ; @0C3D  32 11 40          
loc_0C40:
    LD DE,0C1Bh                                ; @0C40  11 1B 0C          
    LD B,0Dh                                   ; @0C43  06 0D             
loc_0C45:
    LD A,(DE)                                  ; @0C45  1A                
    INC DE                                     ; @0C46  13                
    LD H,40h                                   ; @0C47  26 40             
    LD L,A                                     ; @0C49  6F                
    PUSH BC                                    ; @0C4A  C5                
    LD B,(IX+0)                                ; @0C4B  DD 46 00          
    INC IX                                     ; @0C4E  DD 23             
    LD A,06h                                   ; @0C50  3E 06             
    CP L                                       ; @0C52  BD                
    JR NZ,loc_0C60                             ; @0C53  20 0B             
    LD A,(4011h)                               ; @0C55  3A 11 40          
    OR A                                       ; @0C58  B7                
    JR Z,loc_0C60                              ; @0C59  28 05             
    LD B,A                                     ; @0C5B  47                
    XOR A                                      ; @0C5C  AF                
    LD (4011h),A                               ; @0C5D  32 11 40          
loc_0C60:
    CALL RTC_WRITE_REGISTER                              ; @0C60  CD E3 0B          
    POP BC                                     ; @0C63  C1                
    DJNZ loc_0C45                              ; @0C64  10 DF             
    XOR A                                      ; @0C66  AF                
    LD (44F9h),A                               ; @0C67  32 F9 44          
    RET                                        ; @0C6A  C9                
loc_0C6B:
    LD A,07h                                   ; @0C6B  3E 07             
    CALL loc_07E6                              ; @0C6D  CD E6 07          
    CALL loc_09F6                              ; @0C70  CD F6 09          
    LD A,(4008h)                               ; @0C73  3A 08 40          
    PUSH AF                                    ; @0C76  F5                
loc_0C77:
    CALL loc_0DBF                              ; @0C77  CD BF 0D          
    LD A,(44F7h)                               ; @0C7A  3A F7 44          
    LD B,A                                     ; @0C7D  47                
    LD A,(465Fh)                               ; @0C7E  3A 5F 46          
    CP B                                       ; @0C81  B8                
    JR Z,loc_0C90                              ; @0C82  28 0C             
    LD (44F7h),A                               ; @0C84  32 F7 44          
    CALL loc_0878                              ; @0C87  CD 78 08          
    CALL loc_09D7                              ; @0C8A  CD D7 09          
    CALL STATUS_DIRECTION_INDICATOR            ; @0C8D  CD 11 0F          
loc_0C90:
    LD A,(4536h)                               ; @0C90  3A 36 45          
    CP 8Bh                                     ; @0C93  FE 8B             
    JR Z,loc_0C77                              ; @0C95  28 E0             
    POP AF                                     ; @0C97  F1                
    LD (4008h),A                               ; @0C98  32 08 40          
    JR loc_0CDC                                ; @0C9B  18 3F             
loc_0C9D:
    LD A,07h                                   ; @0C9D  3E 07             
    JR loc_0CA2                                ; @0C9F  18 01             
loc_0CA1:
    XOR A                                      ; @0CA1  AF                
loc_0CA2:
    CALL loc_0D62                              ; @0CA2  CD 62 0D          
    LD A,08h                                   ; @0CA5  3E 08             
    CALL loc_07E6                              ; @0CA7  CD E6 07          
    XOR A                                      ; @0CAA  AF                
    LD (44F9h),A                               ; @0CAB  32 F9 44          
    CALL RTC_REFRESH_DISPLAY_VALUES                              ; @0CAE  CD 94 0B          
    CALL loc_0DC6                              ; @0CB1  CD C6 0D          
    CALL loc_0878                              ; @0CB4  CD 78 08          
    CALL loc_09D9                              ; @0CB7  CD D9 09          
    LD A,(400Ch)                               ; @0CBA  3A 0C 40          
    RST 08h                                    ; @0CBD  CF                
    CALL loc_0D6F                              ; @0CBE  CD 6F 0D          
loc_0CC1:
    CALL loc_0494                              ; @0CC1  CD 94 04          
    JR Z,loc_0CC1                              ; @0CC4  28 FB             
    CALL OS_COMMAND_LOOKUP                     ; @0CC6  CD 38 02          
    JR NC,loc_0CC1                             ; @0CC9  30 F6             
    LD BC,0CB1h                                ; @0CCB  01 B1 0C          
    PUSH BC                                    ; @0CCE  C5                
    LD IX,4658h                                ; @0CCF  DD 21 58 46       
    JP (HL)                                    ; @0CD3  E9                
loc_0CD4:
    ; Dispatched for keycode/mode: 8E/08
    LD A,(44F9h)                               ; @0CD4  3A F9 44          
    OR A                                       ; @0CD7  B7                
    CALL NZ,RTC_WRITE_TIME_BLOCK                           ; @0CD8  C4 28 0C          
loc_0CDB:
    ; Dispatched for keycode/mode: 8E/02, 8E/03, 8E/05
    POP HL                                     ; @0CDB  E1                
loc_0CDC:
    CALL loc_0828                              ; @0CDC  CD 28 08          
    JP loc_0A08                                ; @0CDF  C3 08 0A          
    DB 01h,07h,08h,01h,12h,12h,01h,31h,15h,80h,FFh,1Bh,00h,23h,1Eh,00h ; @0CE2  01 07 08 01 12 12 01 31 15 80 FF 1B 00 23 1E 00
    DB 59h,21h,00h,59h,24h,01h,02h,02h,00h,23h,05h,00h,59h,08h ; @0CF2  59 21 00 59 24 01 02 02 00 23 05 00 59 08   |Y!.Y$....#..Y.|
loc_0D00:
    ; Dispatched for keycode/mode: 86/08
    CALL loc_0D91                              ; @0D00  CD 91 0D          
    JP M,loc_0D0E                              ; @0D03  FA 0E 0D          
    LD A,B                                     ; @0D06  78                
    INC HL                                     ; @0D07  23                
    CP (HL)                                    ; @0D08  BE                
    RET Z                                      ; @0D09  C8                
    ADD A,01h                                  ; @0D0A  C6 01             
    JR loc_0D1A                                ; @0D0C  18 0C             
loc_0D0E:
    LD A,(IX+1)                                ; @0D0E  DD 7E 01          
    ADD A,01h                                  ; @0D11  C6 01             
    DAA                                        ; @0D13  27                
    LD (IX+1),A                                ; @0D14  DD 77 01          
    LD A,B                                     ; @0D17  78                
    ADC A,00h                                  ; @0D18  CE 00             
loc_0D1A:
    DAA                                        ; @0D1A  27                
    LD (IX+0),A                                ; @0D1B  DD 77 00          
    LD A,01h                                   ; @0D1E  3E 01             
    LD (44F9h),A                               ; @0D20  32 F9 44          
    LD A,(4008h)                               ; @0D23  3A 08 40          
    CP 03h                                     ; @0D26  FE 03             
    JP NZ,loc_0E75                             ; @0D28  C2 75 0E          
    XOR A                                      ; @0D2B  AF                
    LD (4663h),A                               ; @0D2C  32 63 46          
    JP loc_0E95                                ; @0D2F  C3 95 0E          
loc_0D32:
    ; Dispatched for keycode/mode: 85/08
    CALL loc_0D91                              ; @0D32  CD 91 0D          
    JP M,loc_0D3F                              ; @0D35  FA 3F 0D          
    LD A,B                                     ; @0D38  78                
    CP C                                       ; @0D39  B9                
    RET Z                                      ; @0D3A  C8                
    SUB 01h                                    ; @0D3B  D6 01             
    JR loc_0D1A                                ; @0D3D  18 DB             
loc_0D3F:
    LD A,(IX+1)                                ; @0D3F  DD 7E 01          
    SUB 01h                                    ; @0D42  D6 01             
    DAA                                        ; @0D44  27                
    LD (IX+1),A                                ; @0D45  DD 77 01          
    LD A,B                                     ; @0D48  78                
    SBC A,00h                                  ; @0D49  DE 00             
    JR loc_0D1A                                ; @0D4B  18 CD             
loc_0D4D:
    ; Dispatched for keycode/mode: 87/08
    LD A,(4008h)                               ; @0D4D  3A 08 40          
    OR A                                       ; @0D50  B7                
    RET Z                                      ; @0D51  C8                
    CP 07h                                     ; @0D52  FE 07             
    RET Z                                      ; @0D54  C8                
    DEC A                                      ; @0D55  3D                
    JR loc_0D62                                ; @0D56  18 0A             
loc_0D58:
    ; Dispatched for keycode/mode: 84/08
    LD A,(4008h)                               ; @0D58  3A 08 40          
    CP 06h                                     ; @0D5B  FE 06             
    RET Z                                      ; @0D5D  C8                
    CP 09h                                     ; @0D5E  FE 09             
    RET Z                                      ; @0D60  C8                
    INC A                                      ; @0D61  3C                
loc_0D62:
    LD (4008h),A                               ; @0D62  32 08 40          
    CALL loc_0D91                              ; @0D65  CD 91 0D          
    INC HL                                     ; @0D68  23                
    INC HL                                     ; @0D69  23                
    LD A,(HL)                                  ; @0D6A  7E                
    LD (400Ch),A                               ; @0D6B  32 0C 40          
    RET                                        ; @0D6E  C9                
loc_0D6F:
    CALL loc_0A47                              ; @0D6F  CD 47 0A          
    LD A,(4008h)                               ; @0D72  3A 08 40          
    OR A                                       ; @0D75  B7                
    PUSH AF                                    ; @0D76  F5                
    LD D,00h                                   ; @0D77  16 00             
    JR Z,loc_0D81                              ; @0D79  28 06             
    CP 07h                                     ; @0D7B  FE 07             
    JR Z,loc_0D81                              ; @0D7D  28 02             
    LD D,40h                                   ; @0D7F  16 40             
loc_0D81:
    POP AF                                     ; @0D81  F1                
    CP 06h                                     ; @0D82  FE 06             
    LD E,00h                                   ; @0D84  1E 00             
    JR Z,loc_0D8E                              ; @0D86  28 06             
    CP 09h                                     ; @0D88  FE 09             
    JR Z,loc_0D8E                              ; @0D8A  28 02             
    LD E,10h                                   ; @0D8C  1E 10             
loc_0D8E:
    JP loc_16AC                                ; @0D8E  C3 AC 16          
loc_0D91:
    LD A,(4008h)                               ; @0D91  3A 08 40          
    LD D,00h                                   ; @0D94  16 00             
    LD E,A                                     ; @0D96  5F                
    ADD IX,DE                                  ; @0D97  DD 19             
    EX DE,HL                                   ; @0D99  EB                
    CP 04h                                     ; @0D9A  FE 04             
    JR C,loc_0DA0                              ; @0D9C  38 02             
    INC IX                                     ; @0D9E  DD 23             
loc_0DA0:
    LD B,(IX+0)                                ; @0DA0  DD 46 00          
    LD DE,0CE2h                                ; @0DA3  11 E2 0C          
    ADD HL,HL                                  ; @0DA6  29                
    ADD A,L                                    ; @0DA7  85                
    LD L,A                                     ; @0DA8  6F                
    ADD HL,DE                                  ; @0DA9  19                
    LD C,(HL)                                  ; @0DAA  4E                
    LD A,C                                     ; @0DAB  79                
    OR A                                       ; @0DAC  B7                
    RET                                        ; @0DAD  C9                
loc_0DAE:
    RST 18h                                    ; @0DAE  DF                
loc_0DAF:
    PUSH HL                                    ; @0DAF  E5                
    PUSH BC                                    ; @0DB0  C5                
    LD HL,4013h                                ; @0DB1  21 13 40          
    LD BC,2720h                                ; @0DB4  01 20 27          
loc_0DB7:
    LD (HL),C                                  ; @0DB7  71                
    INC HL                                     ; @0DB8  23                
    DJNZ loc_0DB7                              ; @0DB9  10 FC             
    LD (HL),B                                  ; @0DBB  70                
    POP BC                                     ; @0DBC  C1                
    POP HL                                     ; @0DBD  E1                
    RET                                        ; @0DBE  C9                
loc_0DBF:
    XOR A                                      ; @0DBF  AF                
    LD (4008h),A                               ; @0DC0  32 08 40          
    CALL RTC_REFRESH_DISPLAY_VALUES                              ; @0DC3  CD 94 0B          
loc_0DC6:
    CALL loc_0DAF                              ; @0DC6  CD AF 0D          
    LD IY,0E48h                                ; @0DC9  FD 21 48 0E       
    LD IX,4658h                                ; @0DCD  DD 21 58 46       
    LD A,(4008h)                               ; @0DD1  3A 08 40          
    CP 07h                                     ; @0DD4  FE 07             
    JR C,loc_0DE0                              ; @0DD6  38 08             
    LD IY,0E60h                                ; @0DD8  FD 21 60 0E       
    LD IX,4660h                                ; @0DDC  DD 21 60 46       
loc_0DE0:
    LD DE,4013h                                ; @0DE0  11 13 40          
loc_0DE3:
    LD A,(IY+0)                                ; @0DE3  FD 7E 00          
    INC IY                                     ; @0DE6  FD 23             
    OR A                                       ; @0DE8  B7                
    JR NZ,loc_0E08                             ; @0DE9  20 1D             
    LD L,(IY+0)                                ; @0DEB  FD 6E 00          
    INC IY                                     ; @0DEE  FD 23             
    LD H,(IY+0)                                ; @0DF0  FD 66 00          
    INC IY                                     ; @0DF3  FD 23             
    LD B,(IX+0)                                ; @0DF5  DD 46 00          
    INC IX                                     ; @0DF8  DD 23             
    BIT 4,B                                    ; @0DFA  CB 60             
    JR Z,loc_0E02                              ; @0DFC  28 04             
    LD A,FAh                                   ; @0DFE  3E FA             
    ADD A,B                                    ; @0E00  80                
    LD B,A                                     ; @0E01  47                
loc_0E02:
    DEC B                                      ; @0E02  05                
    CALL loc_08AC                              ; @0E03  CD AC 08          
    JR loc_0DE3                                ; @0E06  18 DB             
loc_0E08:
    JP M,loc_0E39                              ; @0E08  FA 39 0E          
    LD B,A                                     ; @0E0B  47                
    LD C,(IX+0)                                ; @0E0C  DD 4E 00          
    INC IX                                     ; @0E0F  DD 23             
    DJNZ loc_0E33                              ; @0E11  10 20             
    LD A,(4656h)                               ; @0E13  3A 56 46          
    AND 40h                                    ; @0E16  E6 40             
    LD A,C                                     ; @0E18  79                
    LD H,20h                                   ; @0E19  26 20             
    JR NZ,loc_0E2C                             ; @0E1B  20 0F             
    LD C,12h                                   ; @0E1D  0E 12             
    CP C                                       ; @0E1F  B9                
    LD H,41h                                   ; @0E20  26 41             
    JR C,loc_0E28                              ; @0E22  38 04             
    LD H,50h                                   ; @0E24  26 50             
    SUB C                                      ; @0E26  91                
    DAA                                        ; @0E27  27                
loc_0E28:
    OR A                                       ; @0E28  B7                
    JR NZ,loc_0E2C                             ; @0E29  20 01             
    LD A,C                                     ; @0E2B  79                
loc_0E2C:
    PUSH AF                                    ; @0E2C  F5                
    LD A,H                                     ; @0E2D  7C                
    LD (4005h),A                               ; @0E2E  32 05 40          
    POP AF                                     ; @0E31  F1                
    LD C,A                                     ; @0E32  4F                
loc_0E33:
    LD A,C                                     ; @0E33  79                
    CALL loc_0F00                              ; @0E34  CD 00 0F          
    JR loc_0DE3                                ; @0E37  18 AA             
loc_0E39:
    INC A                                      ; @0E39  3C                
    JR Z,loc_0E42                              ; @0E3A  28 06             
    AND 7Fh                                    ; @0E3C  E6 7F             
    LD (DE),A                                  ; @0E3E  12                
    INC DE                                     ; @0E3F  13                
    JR loc_0DE3                                ; @0E40  18 A1             
loc_0E42:
    LD A,(4005h)                               ; @0E42  3A 05 40          
    LD (DE),A                                  ; @0E45  12                
    INC DE                                     ; @0E46  13                
    RET                                        ; @0E47  C9                
    DB 00h,4Fh,11h,E3h,E0h,F8h,9Fh,00h,6Ch,11h,9Fh,02h,ABh,9Fh,02h,02h ; @0E48  00 4F 11 E3 E0 F8 9F 00 6C 11 9F 02 AB 9F 02 02
    DB 9Fh,01h,B9h,02h,B9h,02h,9Fh,FFh,00h,8Ch,12h,9Fh,01h,B9h,02h,9Fh ; @0E58  9F 01 B9 02 B9 02 9F FF 00 8C 12 9F 01 B9 02 9F
    DB FFh,31h,29h,31h,30h,31h,30h,31h,31h,30h,31h,30h,31h ; @0E68  FF 31 29 31 30 31 30 31 31 30 31 30 31   |.1)1010110101|
loc_0E75:
    LD HL,4659h                                ; @0E75  21 59 46          
    LD C,(HL)                                  ; @0E78  4E                
    BIT 4,C                                    ; @0E79  CB 61             
    JR Z,loc_0E83                              ; @0E7B  28 06             
    LD A,C                                     ; @0E7D  79                
    ADD A,0Ah                                  ; @0E7E  C6 0A             
    AND 0Fh                                    ; @0E80  E6 0F             
    LD C,A                                     ; @0E82  4F                
loc_0E83:
    EX DE,HL                                   ; @0E83  EB                
    LD HL,0E68h                                ; @0E84  21 68 0E          
    LD B,00h                                   ; @0E87  06 00             
    ADD HL,BC                                  ; @0E89  09                
    INC DE                                     ; @0E8A  13                
    LD A,(DE)                                  ; @0E8B  1A                
    DEC A                                      ; @0E8C  3D                
    CP (HL)                                    ; @0E8D  BE                
    JR C,loc_0E95                              ; @0E8E  38 05             
    LD A,(HL)                                  ; @0E90  7E                
    LD (DE),A                                  ; @0E91  12                
    LD (44F9h),A                               ; @0E92  32 F9 44          
loc_0E95:
    LD A,(465Ch)                               ; @0E95  3A 5C 46          
    CALL loc_0EF6                              ; @0E98  CD F6 0E          
    LD HL,(4659h)                              ; @0E9B  2A 59 46          
    LD A,02h                                   ; @0E9E  3E 02             
    JR Z,loc_0EB8                              ; @0EA0  28 16             
    CP L                                       ; @0EA2  BD                
    JR NZ,loc_0EAF                             ; @0EA3  20 0A             
    LD A,28h                                   ; @0EA5  3E 28             
    CP H                                       ; @0EA7  BC                
    JR NC,loc_0EAF                             ; @0EA8  30 05             
    LD (465Ah),A                               ; @0EAA  32 5A 46          
    JR loc_0EF0                                ; @0EAD  18 41             
loc_0EAF:
    XOR A                                      ; @0EAF  AF                
    LD HL,4663h                                ; @0EB0  21 63 46          
    CP (HL)                                    ; @0EB3  BE                
    RET Z                                      ; @0EB4  C8                
    LD (HL),A                                  ; @0EB5  77                
    JR loc_0EF0                                ; @0EB6  18 38             
loc_0EB8:
    CP L                                       ; @0EB8  BD                
    JR C,loc_0ECB                              ; @0EB9  38 10             
    JR NZ,loc_0EAF                             ; @0EBB  20 F2             
    LD A,29h                                   ; @0EBD  3E 29             
    CP H                                       ; @0EBF  BC                
    JR NZ,loc_0EAF                             ; @0EC0  20 ED             
    LD HL,4663h                                ; @0EC2  21 63 46          
    XOR A                                      ; @0EC5  AF                
    CP (HL)                                    ; @0EC6  BE                
    RET NZ                                     ; @0EC7  C0                
    INC (HL)                                   ; @0EC8  34                
    JR loc_0EF0                                ; @0EC9  18 25             
loc_0ECB:
    EX DE,HL                                   ; @0ECB  EB                
    LD HL,4663h                                ; @0ECC  21 63 46          
    LD A,(HL)                                  ; @0ECF  7E                
    OR A                                       ; @0ED0  B7                
    RET NZ                                     ; @0ED1  C0                
    INC (HL)                                   ; @0ED2  34                
    LD A,(4507h)                               ; @0ED3  3A 07 45          
    CP 08h                                     ; @0ED6  FE 08             
    JR Z,loc_0EF0                              ; @0ED8  28 16             
    LD A,D                                     ; @0EDA  7A                
    SUB 01h                                    ; @0EDB  D6 01             
    DAA                                        ; @0EDD  27                
    LD D,A                                     ; @0EDE  57                
    OR A                                       ; @0EDF  B7                
    JR NZ,loc_0EEC                             ; @0EE0  20 0A             
    LD A,E                                     ; @0EE2  7B                
    SUB 01h                                    ; @0EE3  D6 01             
    DAA                                        ; @0EE5  27                
    LD E,A                                     ; @0EE6  5F                
    LD HL,0E68h                                ; @0EE7  21 68 0E          
    ADD HL,DE                                  ; @0EEA  19                
    LD D,(HL)                                  ; @0EEB  56                
loc_0EEC:
    EX DE,HL                                   ; @0EEC  EB                
    LD (4659h),HL                              ; @0EED  22 59 46          
loc_0EF0:
    LD A,01h                                   ; @0EF0  3E 01             
    LD (44F9h),A                               ; @0EF2  32 F9 44          
    RET                                        ; @0EF5  C9                
loc_0EF6:
    LD B,A                                     ; @0EF6  47                
    RRCA                                       ; @0EF7  0F                
    RRCA                                       ; @0EF8  0F                
    RRCA                                       ; @0EF9  0F                
    AND 02h                                    ; @0EFA  E6 02             
    XOR B                                      ; @0EFC  A8                
    AND 03h                                    ; @0EFD  E6 03             
    RET                                        ; @0EFF  C9                
loc_0F00:
    PUSH AF                                    ; @0F00  F5                
    RRCA                                       ; @0F01  0F                
    RRCA                                       ; @0F02  0F                
    RRCA                                       ; @0F03  0F                
    RRCA                                       ; @0F04  0F                
    CALL loc_072D                              ; @0F05  CD 2D 07          
    LD (DE),A                                  ; @0F08  12                
    INC DE                                     ; @0F09  13                
    POP AF                                     ; @0F0A  F1                
    CALL loc_072D                              ; @0F0B  CD 2D 07          
    LD (DE),A                                  ; @0F0E  12                
    INC DE                                     ; @0F0F  13                
    RET                                        ; @0F10  C9                
STATUS_DIRECTION_INDICATOR:
    LD A,(4006h)                               ; @0F11  3A 06 40          
    AND F0h                                    ; @0F14  E6 F0             
    LD L,A                                     ; @0F16  6F                
    LD H,00h                                   ; @0F17  26 00             
    CALL STATUS_CLEAR_MASK                     ; @0F19  CD 4A 0A          
    LD A,(44F7h)                               ; @0F1C  3A F7 44          
    LD B,A                                     ; @0F1F  47                
    AND 10h                                    ; @0F20  E6 10             
    RRCA                                       ; @0F22  0F                
    RRCA                                       ; @0F23  0F                
    RRCA                                       ; @0F24  0F                
    ADD A,B                                    ; @0F25  80                
    AND 03h                                    ; @0F26  E6 03             
    LD B,A                                     ; @0F28  47                
    LD HL,0008h                                ; @0F29  21 08 00          
    JR NZ,loc_0F30                             ; @0F2C  20 02             
    LD B,04h                                   ; @0F2E  06 04             
loc_0F30:
    ADD HL,HL                                  ; @0F30  29                
    DJNZ loc_0F30                              ; @0F31  10 FD             
    RST 28h                                    ; @0F33  EF                
    RET                                        ; @0F34  C9                
loc_0F35:
    LD HL,(466Eh)                              ; @0F35  2A 6E 46          
    DEC HL                                     ; @0F38  2B                
    LD (466Eh),HL                              ; @0F39  22 6E 46          
    LD A,H                                     ; @0F3C  7C                
    OR L                                       ; @0F3D  B5                
    CALL Z,RTC_REFRESH_DISPLAY_VALUES                            ; @0F3E  CC 94 0B          
    LD A,(4660h)                               ; @0F41  3A 60 46          
    DEC A                                      ; @0F44  3D                
    RET Z                                      ; @0F45  C8                
    CALL RTC_REFRESH_DISPLAY_VALUES                              ; @0F46  CD 94 0B          
    LD DE,4661h                                ; @0F49  11 61 46          
    LD HL,465Dh                                ; @0F4C  21 5D 46          
    LD B,02h                                   ; @0F4F  06 02             
loc_0F51:
    LD A,(DE)                                  ; @0F51  1A                
    CP (HL)                                    ; @0F52  BE                
    INC HL                                     ; @0F53  23                
    INC DE                                     ; @0F54  13                
    RET NZ                                     ; @0F55  C0                
    DJNZ loc_0F51                              ; @0F56  10 F9             
    INC HL                                     ; @0F58  23                
    LD (HL),01h                                ; @0F59  36 01             
    CALL RTC_WRITE_TIME_BLOCK                              ; @0F5B  CD 28 0C          
    CALL loc_07E6                              ; @0F5E  CD E6 07          
    LD HL,11BAh                                ; @0F61  21 BA 11          
    CALL loc_003F                              ; @0F64  CD 3F 00          
loc_0F67:
    CALL loc_016C                              ; @0F67  CD 6C 01          
    CALL loc_0A64                              ; @0F6A  CD 64 0A          
    CALL loc_0494                              ; @0F6D  CD 94 04          
    CP 8Eh                                     ; @0F70  FE 8E             
    JR NZ,loc_0F67                             ; @0F72  20 F3             
    LD HL,0000h                                ; @0F74  21 00 00          
    LD (4505h),HL                              ; @0F77  22 05 45          
    JP loc_0CDC                                ; @0F7A  C3 DC 0C          
COMMAND_DISPATCH_TABLE:  ; Packed keycode/mode/target records; U2/U3 boundary bisects this table
    DB 95h,02h                                  ; @0F7D  95 02  Packed keycode/mode/target records; U2/U3 boundary bisects this table COMMAND 95h: 2 mode(s)
    DB 00h,3Eh,22h                              ; @0F7F  00 3E 22   COMMAND 95h mode 00h -> loc_223E
    DB 01h,38h,22h                              ; @0F82  01 38 22   COMMAND 95h mode 01h -> loc_2238
    DB 93h,03h                                  ; @0F85  93 03   COMMAND 93h: 3 mode(s)
    DB 03h,3Eh,16h                              ; @0F87  03 3E 16   COMMAND 93h mode 03h -> loc_163E
    DB 00h,3Eh,16h                              ; @0F8A  00 3E 16   COMMAND 93h mode 00h -> loc_163E
    DB 01h,3Eh,16h                              ; @0F8D  01 3E 16   COMMAND 93h mode 01h -> loc_163E
    DB 8Fh,06h                                  ; @0F90  8F 06   COMMAND 8Fh: 6 mode(s)
    DB 00h,58h,01h                              ; @0F92  00 58 01   COMMAND 8Fh mode 00h -> loc_0158
    DB 01h,1Fh,24h                              ; @0F95  01 1F 24   COMMAND 8Fh mode 01h -> loc_241F
    DB 05h,08h,29h                              ; @0F98  05 08 29   COMMAND 8Fh mode 05h -> loc_2908
    DB 03h,46h,1Fh                              ; @0F9B  03 46 1F   COMMAND 8Fh mode 03h -> loc_1F46
    DB 0Ah,06h,28h                              ; @0F9E  0A 06 28   COMMAND 8Fh mode 0Ah -> loc_2806
    DB 0Bh,06h,28h                              ; @0FA1  0B 06 28   COMMAND 8Fh mode 0Bh -> loc_2806
    DB 99h,02h                                  ; @0FA4  99 02   COMMAND 99h: 2 mode(s)
    DB 03h,73h,19h                              ; @0FA6  03 73 19   COMMAND 99h mode 03h -> loc_1973
    DB 00h,73h,19h                              ; @0FA9  00 73 19   COMMAND 99h mode 00h -> loc_1973
    DB 96h,02h                                  ; @0FAC  96 02   COMMAND 96h: 2 mode(s)
    DB 03h,78h,19h                              ; @0FAE  03 78 19   COMMAND 96h mode 03h -> loc_1978
    DB 00h,78h,19h                              ; @0FB1  00 78 19   COMMAND 96h mode 00h -> loc_1978
    DB 97h,01h                                  ; @0FB4  97 01   COMMAND 97h: 1 mode(s)
    DB 00h,7Ch,1Ah                              ; @0FB6  00 7C 1A   COMMAND 97h mode 00h -> loc_1A7C
    DB 80h,01h                                  ; @0FB9  80 01   COMMAND 80h: 1 mode(s)
    DB 00h,C6h,04h                              ; @0FBB  00 C6 04   COMMAND 80h mode 00h -> DJ_SHORTCUT
    DB C0h,01h                                  ; @0FBE  C0 01   COMMAND C0h: 1 mode(s)
    DB 00h,C1h,04h                              ; @0FC0  00 C1 04   COMMAND C0h mode 00h -> DJ_ALT_SHORTCUT
    DB 88h,03h                                  ; @0FC3  88 03   COMMAND 88h: 3 mode(s)
    DB 00h,C2h,20h                              ; @0FC5  00 C2 20   COMMAND 88h mode 00h -> loc_20C2
    DB 01h,4Eh,26h                              ; @0FC8  01 4E 26   COMMAND 88h mode 01h -> loc_264E
    DB 04h,A9h,20h                              ; @0FCB  04 A9 20   COMMAND 88h mode 04h -> loc_20A9
    DB 91h,04h                                  ; @0FCE  91 04   COMMAND 91h: 4 mode(s)
    DB 00h,F2h,00h                              ; @0FD0  00 F2 00   COMMAND 91h mode 00h -> loc_00F2
    DB 01h,40h,25h                              ; @0FD3  01 40 25   COMMAND 91h mode 01h -> loc_2540
    DB 0Ah,C6h,27h                              ; @0FD6  0A C6 27   COMMAND 91h mode 0Ah -> loc_27C6
    DB 0Bh,C6h,27h                              ; @0FD9  0B C6 27   COMMAND 91h mode 0Bh -> loc_27C6
    DB 89h,02h                                  ; @0FDC  89 02   COMMAND 89h: 2 mode(s)
    DB 01h,F6h,26h                              ; @0FDE  01 F6 26   COMMAND 89h mode 01h -> loc_26F6
    DB 0Ah,5Eh,28h                              ; @0FE1  0A 5E 28   COMMAND 89h mode 0Ah -> loc_285E
    DB 81h,01h                                  ; @0FE4  81 01   COMMAND 81h: 1 mode(s)
    DB 01h,4Dh,25h                              ; @0FE6  01 4D 25   COMMAND 81h mode 01h -> loc_254D
    DB 82h,01h                                  ; @0FE9  82 01   COMMAND 82h: 1 mode(s)
    DB 01h,51h,25h                              ; @0FEB  01 51 25   COMMAND 82h mode 01h -> loc_2551
    DB CBh,01h                                  ; @0FEE  CB 01   COMMAND CBh: 1 mode(s)
    DB 01h,67h,26h                              ; @0FF0  01 67 26   COMMAND CBh mode 01h -> loc_2667
    DB D4h,01h                                  ; @0FF3  D4 01   COMMAND D4h: 1 mode(s)
    DB 01h,6Fh,26h                              ; @0FF5  01 6F 26   COMMAND D4h mode 01h -> loc_266F
    DB 83h,01h                                  ; @0FF8  83 01   COMMAND 83h: 1 mode(s)
    DB 01h,5Ah,26h                              ; @0FFA  01 5A 26   COMMAND 83h mode 01h -> loc_265A
    DB 8Dh,02h                                  ; @0FFD  8D 02   COMMAND 8Dh: 2 mode(s)
    DB 02h                                      ; @0FFF  02   COMMAND 8Dh mode 02h -> loc_166C


; green_u3.bin SHA256=78540723234e94119dcac9ffc6a40561abd6d21cac1457739fb1a428f4d0d253
ORG 1000h
; ---- green_u3.bin start 1000h ----

    DB 6Ch,16h                                  ; @1000  6C 16
    DB 09h,92h,17h                              ; @1002  09 92 17   COMMAND 8Dh mode 09h -> loc_1792
    DB 8Ah,02h                                  ; @1005  8A 02   COMMAND 8Ah: 2 mode(s)
    DB 00h,09h,1Fh                              ; @1007  00 09 1F   COMMAND 8Ah mode 00h -> loc_1F09
    DB 01h,1Fh,26h                              ; @100A  01 1F 26   COMMAND 8Ah mode 01h -> loc_261F
    DB 8Ch,02h                                  ; @100D  8C 02   COMMAND 8Ch: 2 mode(s)
    DB 01h,49h,26h                              ; @100F  01 49 26   COMMAND 8Ch mode 01h -> loc_2649
    DB 04h,B7h,21h                              ; @1012  04 B7 21   COMMAND 8Ch mode 04h -> loc_21B7
    DB 94h,04h                                  ; @1015  94 04   COMMAND 94h: 4 mode(s)
    DB 09h,1Ah,29h                              ; @1017  09 1A 29   COMMAND 94h mode 09h -> loc_291A
    DB 00h,1Ah,29h                              ; @101A  00 1A 29   COMMAND 94h mode 00h -> loc_291A
    DB 01h,1Ah,29h                              ; @101D  01 1A 29   COMMAND 94h mode 01h -> loc_291A
    DB 03h,1Ah,29h                              ; @1020  03 1A 29   COMMAND 94h mode 03h -> loc_291A
    DB 86h,08h                                  ; @1023  86 08   COMMAND 86h: 8 mode(s)
    DB 00h,16h,21h                              ; @1025  00 16 21   COMMAND 86h mode 00h -> loc_2116
    DB 08h,00h,0Dh                              ; @1028  08 00 0D   COMMAND 86h mode 08h -> loc_0D00
    DB 09h,74h,17h                              ; @102B  09 74 17   COMMAND 86h mode 09h -> loc_1774
    DB 03h,3Eh,1Fh                              ; @102E  03 3E 1F   COMMAND 86h mode 03h -> loc_1F3E
    DB 05h,7Ch,2Ch                              ; @1031  05 7C 2C   COMMAND 86h mode 05h -> loc_2C7C
    DB 06h,45h,20h                              ; @1034  06 45 20   COMMAND 86h mode 06h -> loc_2045
    DB 01h,D7h,25h                              ; @1037  01 D7 25   COMMAND 86h mode 01h -> loc_25D7
    DB 04h,A6h,21h                              ; @103A  04 A6 21   COMMAND 86h mode 04h -> loc_21A6
    DB 84h,07h                                  ; @103D  84 07   COMMAND 84h: 7 mode(s)
    DB 08h,58h,0Dh                              ; @103F  08 58 0D   COMMAND 84h mode 08h -> loc_0D58
    DB 02h,81h,16h                              ; @1042  02 81 16   COMMAND 84h mode 02h -> loc_1681
    DB 09h,3Fh,17h                              ; @1045  09 3F 17   COMMAND 84h mode 09h -> loc_173F
    DB 05h,6Ch,2Ch                              ; @1048  05 6C 2C   COMMAND 84h mode 05h -> loc_2C6C
    DB 01h,5Eh,24h                              ; @104B  01 5E 24   COMMAND 84h mode 01h -> loc_245E
    DB 0Ah,F0h,27h                              ; @104E  0A F0 27   COMMAND 84h mode 0Ah -> loc_27F0
    DB 0Bh,F0h,27h                              ; @1051  0B F0 27   COMMAND 84h mode 0Bh -> loc_27F0
    DB 87h,07h                                  ; @1054  87 07   COMMAND 87h: 7 mode(s)
    DB 08h,4Dh,0Dh                              ; @1056  08 4D 0D   COMMAND 87h mode 08h -> loc_0D4D
    DB 02h,79h,16h                              ; @1059  02 79 16   COMMAND 87h mode 02h -> loc_1679
    DB 09h,37h,17h                              ; @105C  09 37 17   COMMAND 87h mode 09h -> loc_1737
    DB 05h,5Ah,2Ch                              ; @105F  05 5A 2C   COMMAND 87h mode 05h -> loc_2C5A
    DB 01h,E2h,24h                              ; @1062  01 E2 24   COMMAND 87h mode 01h -> loc_24E2
    DB 0Ah,E6h,27h                              ; @1065  0A E6 27   COMMAND 87h mode 0Ah -> loc_27E6
    DB 0Bh,E6h,27h                              ; @1068  0B E6 27   COMMAND 87h mode 0Bh -> loc_27E6
    DB 85h,07h                                  ; @106B  85 07   COMMAND 85h: 7 mode(s)
    DB 08h,32h,0Dh                              ; @106D  08 32 0D   COMMAND 85h mode 08h -> loc_0D32
    DB 09h,7Ch,17h                              ; @1070  09 7C 17   COMMAND 85h mode 09h -> loc_177C
    DB 03h,34h,1Fh                              ; @1073  03 34 1F   COMMAND 85h mode 03h -> loc_1F34
    DB 05h,7Ch,2Ch                              ; @1076  05 7C 2C   COMMAND 85h mode 05h -> loc_2C7C
    DB 06h,4Eh,20h                              ; @1079  06 4E 20   COMMAND 85h mode 06h -> loc_204E
    DB 01h,91h,25h                              ; @107C  01 91 25   COMMAND 85h mode 01h -> loc_2591
    DB 04h,00h,22h                              ; @107F  04 00 22   COMMAND 85h mode 04h -> loc_2200
    DB C6h,03h                                  ; @1082  C6 03   COMMAND C6h: 3 mode(s)
    DB 09h,8Bh,17h                              ; @1084  09 8B 17   COMMAND C6h mode 09h -> loc_178B
    DB 06h,34h,20h                              ; @1087  06 34 20   COMMAND C6h mode 06h -> loc_2034
    DB 01h,34h,24h                              ; @108A  01 34 24   COMMAND C6h mode 01h -> loc_2434
    DB C5h,02h                                  ; @108D  C5 02   COMMAND C5h: 2 mode(s)
    DB 09h,8Eh,17h                              ; @108F  09 8E 17   COMMAND C5h mode 09h -> loc_178E
    DB 01h,23h,25h                              ; @1092  01 23 25   COMMAND C5h mode 01h -> loc_2523
    DB C7h,01h                                  ; @1095  C7 01   COMMAND C7h: 1 mode(s)
    DB 01h,F4h,24h                              ; @1097  01 F4 24   COMMAND C7h mode 01h -> loc_24F4
    DB C4h,01h                                  ; @109A  C4 01   COMMAND C4h: 1 mode(s)
    DB 01h,AAh,24h                              ; @109C  01 AA 24   COMMAND C4h mode 01h -> loc_24AA
    DB 8Eh,0Ah                                  ; @109F  8E 0A   COMMAND 8Eh: 10 mode(s)
    DB 08h,D4h,0Ch                              ; @10A1  08 D4 0C   COMMAND 8Eh mode 08h -> loc_0CD4
    DB 02h,DBh,0Ch                              ; @10A4  02 DB 0C   COMMAND 8Eh mode 02h -> loc_0CDB
    DB 09h,D9h,17h                              ; @10A7  09 D9 17   COMMAND 8Eh mode 09h -> loc_17D9
    DB 03h,DBh,0Ch                              ; @10AA  03 DB 0C   COMMAND 8Eh mode 03h -> loc_0CDB
    DB 06h,4Bh,20h                              ; @10AD  06 4B 20   COMMAND 8Eh mode 06h -> loc_204B
    DB 01h,00h,24h                              ; @10B0  01 00 24   COMMAND 8Eh mode 01h -> loc_2400
    DB 0Ah,2Ch,28h                              ; @10B3  0A 2C 28   COMMAND 8Eh mode 0Ah -> loc_282C
    DB 0Bh,2Ch,28h                              ; @10B6  0B 2C 28   COMMAND 8Eh mode 0Bh -> loc_282C
    DB 05h,DBh,0Ch                              ; @10B9  05 DB 0C   COMMAND 8Eh mode 05h -> loc_0CDB
    DB 04h,C0h,21h                              ; @10BC  04 C0 21   COMMAND 8Eh mode 04h -> loc_21C0
COMMAND_TABLE_TERMINATOR:  ; Zero terminator for 29 groups and 88 command-mode mappings
    DB 00h                                      ; @10BF  00  Zero terminator for 29 groups and 88 command-mode mappings
    DB 2Bh,1Ch,2Ah,2Dh,1Ch,2Ah,78h,1Ch,2Ah,FDh,1Ch,2Ah,3Dh,1Ch,2Ah,79h ; @10C0  2B 1C 2A 2D 1C 2A 78 1C 2A FD 1C 2A 3D 1C 2A 79   |+.*-.*x.*..*=.*y|
    DB E9h,29h,75h,ECh,29h,2Eh,D9h,29h,6Fh,A8h,2Ch,00h,2Bh,45h,2Ah,2Dh ; @10D0  E9 29 75 EC 29 2E D9 29 6F A8 2C 00 2B 45 2A 2D   |.)u.)..)o.,.+E*-|
    DB 43h,2Ah,78h,ADh,2Ah,FDh,61h,2Bh,00h,81h,96h,13h,82h,C5h,13h,83h ; @10E0  43 2A 78 AD 2A FD 61 2B 00 81 96 13 82 C5 13 83   |C*x.*.a+........|
    DB D0h,13h,84h,EFh,13h,85h,EFh,13h,86h,EFh,13h,87h,EFh,13h,88h,0Dh ; @10F0  D0 13 84 EF 13 85 EF 13 86 EF 13 87 EF 13 88 0D
    DB 14h,89h,53h,14h,8Ah,7Bh,14h,8Bh,ABh,14h,8Dh,C9h,14h,98h,0Dh,16h ; @1100  14 89 53 14 8A 7B 14 8B AB 14 8D C9 14 98 0D 16
    DB 8Ch,35h,14h,8Fh,D3h,14h,91h,09h,15h,80h,A9h,13h,93h,29h,15h,94h ; @1110  8C 35 14 8F D3 14 91 09 15 80 A9 13 93 29 15 94
    DB 91h,15h,95h,B0h,15h,96h,C2h,15h,97h,DEh,15h,FFh,FDh,15h,00h,DDh ; @1120  91 15 95 B0 15 96 C2 15 97 DE 15 FF FD 15 00 DD
    DB E6h,ECh,E5h,C0h,9Eh,A4h,A0h,D2h,D6h,90h,C0h,D4h,A1h,50h,D2h,D6h ; @1130  E6 EC E5 C0 9E A4 A0 D2 D6 90 C0 D4 A1 50 D2 D6
    DB 90h,C0h,A1h,85h,BDh,00h,F5h,D8h,C0h,DDh,26h,78h,32h,64h,C0h,00h ; @1140  90 C0 A1 85 BD 00 F5 D8 C0 DD 26 78 32 64 C0 00
    DB 0Ah,D4h,4Ch,00h,0Dh,36h,4Ch,00h,3Dh,41h,ACh,D6h,19h,41h,ACh,03h ; @1150  0A D4 4C 00 0D 36 4C 00 3D 41 AC D6 19 41 AC 03   |..L..6L.=A...A..|
    DB D0h,D4h,5Ah,C0h,00h,0Dh,15h,2Ch,0Ah,83h,D4h,5Ch,00h,EAh,84h,D4h ; @1160  D0 D4 5A C0 00 0D 15 2C 0A 83 D4 5C 00 EA 84 D4
    DB 85h,D7h,C0h,0Dh,11h,D5h,5Dh,48h,5Dh,7Ch,00h,00h,D3h,85h,BDh,0Ch ; @1170  85 D7 C0 0D 11 D5 5D 48 5D 7C 00 00 D3 85 BD 0C
    DB 00h,00h,8Dh,25h,27h,C0h,00h,00h,00h,D3h,8Dh,7Ch,00h,00h,0Eh,ADh ; @1180  00 00 8D 25 27 C0 00 00 00 D3 8D 7C 00 00 0E AD
    DB 44h,1Ch,00h,00h,0Eh,ADh,47h,D7h,C0h,00h,08h,D4h,D9h,D4h,A3h,C0h ; @1190  44 1C 00 00 0E AD 47 D7 C0 00 08 D4 D9 D4 A3 C0
    DB A1h,D2h,31h,D3h,D5h,15h,C0h,00h,6Bh,36h,D5h,15h,C0h,04h,6Dh,D1h ; @11A0  A1 D2 31 D3 D5 15 C0 00 6B 36 D5 15 C0 04 6D D1
    DB D3h,D5h,15h,C0h,09h,1Bh,1Dh,3Dh,51h,5Ch,D2h,51h,AAh,0Eh,2Eh,02h ; @11B0  D3 D5 15 C0 09 1B 1D 3D 51 5C D2 51 AA 0E 2E 02   |.......=Q\.Q....|
    DB 3Eh,2Ch,D1h,8Bh,36h,5Dh,70h,51h,A1h,3Ch,D5h,83h,31h,5Dh,70h,C0h ; @11C0  3E 2C D1 8B 36 5D 70 51 A1 3C D5 83 31 5D 70 C0   |>,..6]pQ.<..1]p.|
    DB 88h,07h,6Dh,6Ch,F2h,DDh,07h,6Dh,6Ch,87h,70h,76h,D6h,C0h,31h,5Dh ; @11D0  88 07 6D 6C F2 DD 07 6D 6C 87 70 76 D6 C0 31 5D   |..ml...ml.pv..1]|
    DB 32h,48h,7Fh,CCh,D2h,85h,23h,D7h,00h,00h,00h,02h,4Dh,02h,D5h,23h ; @11E0  32 48 7F CC D2 85 23 D7 00 00 00 02 4D 02 D5 23   |2H....#.....M..#|
    DB 00h,00h,01h,55h,DCh,91h,31h,B3h,C0h,BDh,08h,58h,B3h,15h,DCh,98h ; @11F0  00 00 01 55 DC 91 31 B3 C0 BD 08 58 B3 15 DC 98
    DB 38h,DCh,D5h,23h,A0h,00h,D3h,69h,1Dh,3Dh,CAh,D2h,11h,9Ch,9Dh,4Dh ; @1200  38 DC D5 23 A0 00 D3 69 1D 3D CA D2 11 9C 9D 4D   |8..#...i.=.....M|
    DB 27h,1Eh,00h,00h,00h,00h,00h,00h,B6h,43h,56h,7Dh,CBh,D0h,85h,8Bh ; @1210  27 1E 00 00 00 00 00 00 B6 43 56 7D CB D0 85 8B
    DB 31h,5Ah,C0h,87h,D2h,D0h,8Dh,CDh,F1h,D7h,D5h,68h,59h,00h,00h,00h ; @1220  31 5A C0 87 D2 D0 8D CD F1 D7 D5 68 59 00 00 00
    DB 00h,00h,00h,00h,0Dh,51h,1Dh,21h,5Ch,14h,9Dh,C6h,D1h,DCh,72h,41h ; @1230  00 00 00 00 0D 51 1D 21 5C 14 9D C6 D1 DC 72 41   |.....Q.!\.....rA|
    DB DCh,A1h,F3h,D4h,14h,B1h,C0h,35h,84h,ADh,32h,3Dh,CDh,36h,91h,C0h ; @1240  DC A1 F3 D4 14 B1 C0 35 84 AD 32 3D CD 36 91 C0
    DB 76h,D9h,24h,DCh,98h,31h,E4h,32h,D3h,10h,00h,00h,00h,08h,4Ah,D6h ; @1250  76 D9 24 DC 98 31 E4 32 D3 10 00 00 00 08 4A D6   |v.$..1.2......J.|
    DB 15h,DCh,D5h,8Bh,DFh,C0h,41h,3Dh,66h,5Dh,FDh,CFh,E0h,00h,00h,00h ; @1260  15 DC D5 8B DF C0 41 3D 66 5D FD CF E0 00 00 00
    DB 00h,B7h,6Bh,DFh,DCh,D3h,69h,10h,00h,0Dh,05h,C0h,D1h,8Bh,36h,5Dh ; @1270  00 B7 6B DF DC D3 69 10 00 0D 05 C0 D1 8B 36 5D
    DB 7Ch,BDh,4Ah,36h,D3h,0Ch,69h,90h,C0h,1Dh,D1h,4Ch,6Dh,1Dh,1Ch,64h ; @1280  7C BD 4A 36 D3 0C 69 90 C0 1D D1 4C 6D 1D 1C 64   ||.J6..i....Lm..d|
    DB 0Ch,F0h,C0h,F1h,C0h,E9h,E8h,E8h,C0h,E5h,E5h,E8h,C0h,D1h,D4h,77h ; @1290  0C F0 C0 F1 C0 E9 E8 E8 C0 E5 E5 E8 C0 D1 D4 77
    DB C0h,D0h,87h,D1h,C0h,B8h,D2h,23h,87h,C0h,46h,5Dh,38h,70h,C0h,B8h ; @12A0  C0 D0 87 D1 C0 B8 D2 23 87 C0 46 5D 38 70 C0 B8   |.......#..F]8p..|
    DB 55h,28h,D9h,1Dh,C5h,13h,D4h,54h,C0h,FBh,DCh,EBh,DCh,91h,D1h,24h ; @12B0  55 28 D9 1D C5 13 D4 54 C0 FB DC EB DC 91 D1 24
    DB 1Ch,DCh,DCh,DCh,D8h,C0h,E0h,64h,0Ch,8Dh,43h,6Ch,E0h,6Dh,1Dh,1Ch ; @12C0  1C DC DC DC D8 C0 E0 64 0C 8D 43 6C E0 6D 1D 1C
    DB 3Dh,7Dh,34h,13h,0Ch,31h,71h,41h,3Ch,E5h,E6h,C0h,E6h,EEh,C0h,19h ; @12D0  3D 7D 34 13 0C 31 71 41 3C E5 E6 C0 E6 EE C0 19   |=}4..1qA<.......|
    DB 23h,C0h,31h,E0h,3Dh,CDh,1Dh,47h,7Ch,46h,30h,D1h,6Dh,44h,9Ch,00h ; @12E0  23 C0 31 E0 3D CD 1D 47 7C 46 30 D1 6D 44 9C 00   |#.1.=..G|F0.mD..|
    DB D1h,6Dh,44h,90h,FAh,0Eh,20h,E2h,C0h,B5h,18h,31h,90h,FAh,0Eh,20h ; @12F0  D1 6D 44 90 FA 0E 20 E2 C0 B5 18 31 90 FA 0E 20   |.mD... ....1... |
    DB E2h,C0h,92h,51h,B3h,65h,D7h,0Dh,1Dh,47h,7Ch,41h,D6h,07h,8Dh,51h ; @1300  E2 C0 92 51 B3 65 D7 0D 1D 47 7C 41 D6 07 8D 51   |...Q.e...G|A...Q|
    DB 7Ch,87h,51h,89h,D7h,09h,1Dh,12h,41h,9Ch,6Dh,D1h,5Dh,17h,6Dh,6Eh ; @1310  7C 87 51 89 D7 09 1D 12 41 9C 6D D1 5D 17 6D 6E   ||.Q.....A.m.].mn|
    DB 10h,D2h,51h,AAh,0Bh,75h,C0h,85h,10h,D7h,6Dh,40h,ADh,45h,10h,DAh ; @1320  10 D2 51 AA 0B 75 C0 85 10 D7 6D 40 AD 45 10 DA   |..Q..u....m@.E..|
    DB D7h,06h,50h,4Dh,BEh,3Ch,24h,91h,E0h,F5h,F5h,D8h,07h,8Dh,51h,7Fh ; @1330  D7 06 50 4D BE 3C 24 91 E0 F5 F5 D8 07 8D 51 7F   |..PM.<$.......Q.|
    DB 50h,0Ah,2Eh,B1h,F5h,00h,00h,00h,D1h,51h,1Fh,50h,00h,00h,C0h,00h ; @1340  50 0A 2E B1 F5 00 00 00 D1 51 1F 50 00 00 C0 00
    DB 00h,00h,FBh,00h,00h,00h,0Ch,FAh,0Eh,20h,E2h,04h,63h,0Dh,16h,D4h ; @1350  00 00 FB 00 00 00 0C FA 0E 20 E2 04 63 0D 16 D4
    DB 49h,C0h,A8h,DDh,10h,51h,89h,D7h,C0h,D1h,6Dh,44h,90h,FAh,0Eh,20h ; @1360  49 C0 A8 DD 10 51 89 D7 C0 D1 6D 44 90 FA 0E 20   |I....Q....mD... |
    DB E2h,E1h,0Bh,71h,85h,0Dh,ADh,7Eh,44h,DBh,C0h,FAh,0Eh,20h,E2h,0Bh ; @1370  E2 E1 0B 71 85 0D AD 7E 44 DB C0 FA 0E 20 E2 0B
    DB 71h,85h,19h,C0h,46h,09h,83h,8Ch,87h,51h,89h,D7h,0Ah,14h,92h,4Dh ; @1380  71 85 19 C0 46 09 83 8C 87 51 89 D7 0A 14 92 4D
    DB 90h,FBh,0Eh,20h,E2h,C0h,02h,F9h,C0h,91h,71h,31h,09h,83h,80h,3Dh ; @1390  90 FB 0E 20 E2 C0 02 F9 C0 91 71 31 09 83 80 3D
    DB 05h,D4h,04h,1Eh,03h,0Eh,DBh,5Dh,8Ch,03h,A3h,6Bh,DFh,A0h,24h,0Fh ; @13A0  05 D4 04 1E 03 0E DB 5D 8C 03 A3 6B DF A0 24 0F
    DB B0h,E2h,E0h,E2h,C0h,D2h,51h,AAh,0Eh,2Fh,6Eh,2Ch,98h,38h,FAh,90h ; @13B0  B0 E2 E0 E2 C0 D2 51 AA 0E 2F 6E 2C 98 38 FA 90   |......Q../n,.8..|
    DB 24h,0Eh,2Fh,6Eh,2Ch,02h,F9h,C0h,91h,71h,31h,A0h,D6h,65h,9Ah,C0h ; @13C0  24 0E 2F 6E 2C 02 F9 C0 91 71 31 A0 D6 65 9A C0   |$./n,....q1..e..|
    DB 04h,F9h,C0h,ADh,27h,23h,AFh,8Ch,87h,70h,31h,E0h,30h,8Dh,13h,15h ; @13D0  04 F9 C0 AD 27 23 AF 8C 87 70 31 E0 30 8D 13 15   |....'#...p1.0...|
    DB 0Bh,D4h,5Ah,65h,02h,ACh,D2h,78h,B1h,90h,24h,04h,1Dh,6Fh,ACh,02h ; @13E0  0B D4 5A 65 02 AC D2 78 B1 90 24 04 1D 6F AC 02   |..Ze...x..$..o..|
    DB DDh,87h,29h,02h,D1h,0Fh,D0h,2Ah,06h,4Eh,10h,24h,02h,4Dh,16h,0Dh ; @13F0  DD 87 29 02 D1 0F D0 2A 06 4E 10 24 02 4D 16 0D   |..)....*.N.$.M..|
    DB 28h,41h,7Ch,FDh,A0h,D3h,6Dh,D1h,0Bh,D4h,5Ah,65h,C0h,03h,ADh,06h ; @1400  28 41 7C FD A0 D3 6D D1 0B D4 5A 65 C0 03 AD 06   |(A|...m...Ze....|
    DB D6h,AFh,A0h,65h,05h,1Bh,12h,DDh,19h,09h,83h,8Ch,D4h,D2h,E1h,96h ; @1410  D6 AF A0 65 05 1B 12 DD 19 09 83 8C D4 D2 E1 96
    DB D6h,40h,FDh,A0h,D1h,51h,1Eh,B1h,08h,B3h,26h,40h,D9h,60h,51h,ADh ; @1420  D6 40 FD A0 D1 51 1E B1 08 B3 26 40 D9 60 51 AD   |.@...Q....&@.`Q.|
    DB 4Dh,31h,ACh,F7h,C0h,03h,ADh,06h,D6h,AFh,A0h,65h,05h,1Bh,12h,DDh ; @1430  4D 31 AC F7 C0 03 AD 06 D6 AF A0 65 05 1B 12 DD
    DB 19h,09h,83h,8Ch,D1h,56h,D3h,0Bh,D4h,55h,14h,30h,D2h,6Ah,23h,26h ; @1440  19 09 83 8C D1 56 D3 0B D4 55 14 30 D2 6A 23 26   |.....V...U.0.j#&|
    DB 4Ch,F7h,C0h,04h,F9h,C0h,3Dh,7Dh,21h,03h,1Eh,03h,03h,60h,D5h,10h ; @1450  4C F7 C0 04 F9 C0 3D 7D 21 03 1E 03 03 60 D5 10   |L.....=}!....`..|
    DB D1h,6Dh,44h,9Ch,D2h,51h,AAh,0Ah,18h,5Bh,D0h,08h,D9h,82h,40h,36h ; @1460  D1 6D 44 9C D2 51 AA 0A 18 5B D0 08 D9 82 40 36   |.mD..Q...[....@6|
    DB C0h,A1h,85h,BDh,00h,D1h,65h,D6h,85h,9Fh,8Ch,04h,92h,ADh,27h,8Dh ; @1470  C0 A1 85 BD 00 D1 65 D6 85 9F 8C 04 92 AD 27 8D
    DB 7Ah,0Bh,64h,31h,43h,A0h,6Dh,10h,FBh,C0h,D1h,67h,76h,D6h,00h,64h ; @1480  7A 0B 64 31 43 A0 6D 10 FB C0 D1 67 76 D6 00 64   |z.d1C.m....gv..d|
    DB 00h,FDh,A0h,24h,02h,4Dh,16h,0Dh,28h,41h,7Ch,B7h,50h,09h,17h,13h ; @1490  00 FD A0 24 02 4D 16 0D 28 41 7C B7 50 09 17 13   |...$.M..(A|.P...|
    DB 1Ah,09h,2Ah,D2h,78h,D7h,19h,FAh,C0h,F7h,C0h,02h,D2h,D4h,ADh,00h ; @14A0  1A 09 2A D2 78 D7 19 FA C0 F7 C0 02 D2 D4 AD 00
    DB B7h,6Bh,DFh,0Dh,16h,50h,32h,D3h,1Ch,B3h,7Eh,4Bh,76h,BDh,F0h,D1h ; @14B0  B7 6B DF 0D 16 50 32 D3 1C B3 7E 4B 76 BD F0 D1   |.k...P2...~Kv...|
    DB 65h,01h,92h,36h,50h,24h,A1h,53h,C0h,01h,BDh,08h,4Dh,91h,06h,D2h ; @14C0  65 01 92 36 50 24 A1 53 C0 01 BD 08 4D 91 06 D2   |e..6P$.S....M...|
    DB 32h,64h,C0h,05h,15h,8Ah,1Ah,09h,2Ah,D2h,78h,D7h,C0h,24h,91h,E0h ; @14D0  32 64 C0 05 15 8A 1A 09 2A D2 78 D7 C0 24 91 E0   |2d......*.x..$..|
    DB 00h,91h,71h,31h,AFh,ACh,76h,B8h,70h,01h,58h,A1h,AFh,ACh,64h,72h ; @14E0  00 91 71 31 AF AC 76 B8 70 01 58 A1 AF AC 64 72   |..q1..v.p.X...dr|
    DB 41h,00h,15h,8Ah,1Ah,0Dh,5Dh,4Dh,1Dh,11h,5Ch,B8h,7Bh,D4h,78h,36h ; @14F0  41 00 15 8A 1A 0D 5D 4D 1D 11 5C B8 7B D4 78 36   |A.....]M..\.{.x6|
    DB 50h,01h,58h,A1h,A0h,14h,35h,D7h,C0h,02h,64h,72h,41h,00h,D5h,8Bh ; @1500  50 01 58 A1 A0 14 35 D7 C0 02 64 72 41 00 D5 8B   |P.X...5...drA...|
    DB DFh,ADh,28h,B1h,C0h,19h,23h,65h,00h,98h,38h,07h,1Dh,13h,06h,D1h ; @1510  DF AD 28 B1 C0 19 23 65 00 98 38 07 1D 13 06 D1
    DB 0Bh,D4h,5Ah,65h,09h,17h,13h,19h,C0h,0Ah,A1h,30h,D3h,69h,1Fh,5Fh ; @1520  0B D4 5A 65 09 17 13 19 C0 0A A1 30 D3 69 1F 5F   |..Ze.......0.i._|
    DB 5Dh,8Fh,C0h,B7h,6Bh,DFh,00h,87h,85h,D3h,C0h,FCh,0Dh,D2h,80h,D3h ; @1530  5D 8F C0 B7 6B DF 00 87 85 D3 C0 FC 0D D2 80 D3
    DB 14h,D4h,C0h,DDh,21h,D6h,00h,D4h,D2h,E1h,96h,D6h,40h,FDh,ACh,FEh ; @1540  14 D4 C0 DD 21 D6 00 D4 D2 E1 96 D6 40 FD AC FE
    DB 00h,71h,D1h,3Eh,15h,2Dh,9Dh,03h,0Fh,DAh,C0h,BDh,08h,4Dh,91h,00h ; @1550  00 71 D1 3E 15 2D 9D 03 0F DA C0 BD 08 4D 91 00
    DB BDh,0Dh,90h,DFh,1Dh,7Ch,F7h,C0h,A1h,30h,0Bh,76h,BDh,FEh,18h,78h ; @1560  BD 0D 90 DF 1D 7C F7 C0 A1 30 0B 76 BD FE 18 78
    DB 5Dh,3Ch,D1h,24h,90h,23h,1Dh,30h,07h,1Dh,13h,E1h,52h,D9h,D0h,30h ; @1570  5D 3C D1 24 90 23 1D 30 07 1D 13 E1 52 D9 D0 30   |]<.$.#.0....R..0|
    DB FDh,ACh,BDh,08h,4Dh,91h,00h,D4h,D2h,E1h,96h,D6h,40h,FDh,ACh,F7h ; @1580  FD AC BD 08 4D 91 00 D4 D2 E1 96 D6 40 FD AC F7
    DB C0h,03h,A2h,D3h,D2h,71h,0Dh,38h,3Dh,00h,D6h,23h,D0h,0Fh,BCh,B3h ; @1590  C0 03 A2 D3 D2 71 0D 38 3D 00 D6 23 D0 0F BC B3
    DB 7Eh,4Bh,87h,B0h,D1h,65h,01h,92h,36h,50h,24h,A1h,53h,C0h,F7h,C0h ; @15A0  7E 4B 87 B0 D1 65 01 92 36 50 24 A1 53 C0 F7 C0   |~K...e..6P$.S...|
    DB 03h,FEh,08h,FAh,C0h,36h,0Bh,51h,83h,10h,65h,0Dh,4Dh,29h,83h,1Ch ; @15B0  03 FE 08 FA C0 36 0B 51 83 10 65 0D 4D 29 83 1C   |.....6.Q..e.M)..|
    DB F7h,C0h,03h,46h,5Dh,38h,70h,2Ah,00h,A1h,49h,C0h,ADh,21h,B2h,87h ; @15C0  F7 C0 03 46 5D 38 70 2A 00 A1 49 C0 AD 21 B2 87   |...F]8p*..I..!..|
    DB 02h,A0h,0Bh,37h,DCh,A1h,49h,C0h,84h,90h,FEh,08h,FAh,C0h,02h,D2h ; @15D0  02 A0 0B 37 DC A1 49 C0 84 90 FE 08 FA C0 02 D2
    DB 51h,AAh,00h,A8h,DDh,10h,08h,49h,0Fh,E0h,8Fh,ACh,D2h,51h,AAh,00h ; @15E0  51 AA 00 A8 DD 10 08 49 0F E0 8F AC D2 51 AA 00
    DB A8h,DDh,10h,08h,D9h,82h,40h,D6h,D0h,14h,09h,64h,1Ch,01h,8Dh,56h ; @15F0  A8 DD 10 08 D9 82 40 D6 D0 14 09 64 1C 01 8D 56
    DB 53h,A0h,87h,70h,B6h,D3h,D3h,D4h,42h,B8h,32h,64h,ACh,03h,FEh,A0h ; @1600  53 A0 87 70 B6 D3 D3 D4 42 B8 32 64 AC 03 FE A0   |S..p....B.2d....|
    DB F6h,0Dh,28h,AAh,D6h,65h,9Ch,B3h,7Eh,4Dh,2Dh,60h,FEh,A0h,D2h,15h ; @1610  F6 0D 28 AA D6 65 9C B3 7E 4D 2D 60 FE A0 D2 15   |..(..e..~M-`....|
    DB A6h,48h,70h,D2h,8Ah,ADh,66h,59h,C0h,F7h,C0h,D0h,17h,D2h,0Fh,5Fh ; @1620  A6 48 70 D2 8A AD 66 59 C0 F7 C0 D0 17 D2 0F 5F   |.Hp...fY......._|
    DB 5Dh,80h,FEh,0Dh,F1h,D7h,0Fh,7Ch,98h,38h,0Dh,F1h,D7h,C0h ; @1630  5D 80 FE 0D F1 D7 0F 7C 98 38 0D F1 D7 C0
loc_163E:
    ; Dispatched for keycode/mode: 93/00, 93/01, 93/03
    LD A,02h                                   ; @163E  3E 02             
    CALL loc_07E6                              ; @1640  CD E6 07          
    CALL loc_0DAE                              ; @1643  CD AE 0D          
    LD HL,152Ah                                ; @1646  21 2A 15          
    CALL loc_003F                              ; @1649  CD 3F 00          
    XOR A                                      ; @164C  AF                
    LD (4502h),A                               ; @164D  32 02 45          
    LD A,0Ch                                   ; @1650  3E 0C             
    RST 08h                                    ; @1652  CF                
    LD HL,0011h                                ; @1653  21 11 00          
    RST 28h                                    ; @1656  EF                
loc_1657:
    CALL loc_1695                              ; @1657  CD 95 16          
    CALL loc_0491                              ; @165A  CD 91 04          
    JR Z,loc_1657                              ; @165D  28 F8             
    CALL OS_COMMAND_LOOKUP                     ; @165F  CD 38 02          
    JR NC,loc_1657                             ; @1662  30 F3             
    LD DE,1657h                                ; @1664  11 57 16          
    PUSH DE                                    ; @1667  D5                
    JP (HL)                                    ; @1668  E9                
    DB 0Ch,1Bh,22h                              ; @1669  0C 1B 22
loc_166C:
    ; Dispatched for keycode/mode: 8D/02
    LD A,(4502h)                               ; @166C  3A 02 45          
    OR A                                       ; @166F  B7                
    JR Z,loc_16B3                              ; @1670  28 41             
    DEC A                                      ; @1672  3D                
    JP Z,loc_0CA1                              ; @1673  CA A1 0C          
    JP loc_0C9D                                ; @1676  C3 9D 0C          
loc_1679:
    ; Dispatched for keycode/mode: 87/02
    LD A,(4502h)                               ; @1679  3A 02 45          
    OR A                                       ; @167C  B7                
    RET Z                                      ; @167D  C8                
    DEC A                                      ; @167E  3D                
    JR loc_1688                                ; @167F  18 07             
loc_1681:
    ; Dispatched for keycode/mode: 84/02
    LD A,(4502h)                               ; @1681  3A 02 45          
    CP 02h                                     ; @1684  FE 02             
    RET Z                                      ; @1686  C8                
    INC A                                      ; @1687  3C                
loc_1688:
    LD (4502h),A                               ; @1688  32 02 45          
    LD D,00h                                   ; @168B  16 00             
    LD HL,1669h                                ; @168D  21 69 16          
    LD E,A                                     ; @1690  5F                
    ADD HL,DE                                  ; @1691  19                
    LD A,(HL)                                  ; @1692  7E                
    RST 08h                                    ; @1693  CF                
    RET                                        ; @1694  C9                
loc_1695:
    CALL loc_0A47                              ; @1695  CD 47 0A          
    LD A,(4502h)                               ; @1698  3A 02 45          
    OR A                                       ; @169B  B7                
    PUSH AF                                    ; @169C  F5                
    LD D,40h                                   ; @169D  16 40             
    JR NZ,loc_16A3                             ; @169F  20 02             
    LD D,00h                                   ; @16A1  16 00             
loc_16A3:
    POP AF                                     ; @16A3  F1                
    CP 02h                                     ; @16A4  FE 02             
    LD E,10h                                   ; @16A6  1E 10             
    JR C,loc_16AC                              ; @16A8  38 02             
    LD E,00h                                   ; @16AA  1E 00             
loc_16AC:
    LD A,E                                     ; @16AC  7B                
loc_16AD:
    OR D                                       ; @16AD  B2                
    LD L,A                                     ; @16AE  6F                
    LD H,00h                                   ; @16AF  26 00             
    RST 28h                                    ; @16B1  EF                
    RET                                        ; @16B2  C9                
loc_16B3:
    LD A,09h                                   ; @16B3  3E 09             
    CALL loc_07E6                              ; @16B5  CD E6 07          
    CALL loc_16E6                              ; @16B8  CD E6 16          
    XOR A                                      ; @16BB  AF                
    LD (400Bh),A                               ; @16BC  32 0B 40          
    LD (4009h),A                               ; @16BF  32 09 40          
loc_16C2:
    CALL loc_1749                              ; @16C2  CD 49 17          
    LD A,(4009h)                               ; @16C5  3A 09 40          
    LD B,A                                     ; @16C8  47                
    CALL loc_1703                              ; @16C9  CD 03 17          
loc_16CC:
    RST 18h                                    ; @16CC  DF                
    CALL loc_09D9                              ; @16CD  CD D9 09          
    LD A,(400Ch)                               ; @16D0  3A 0C 40          
    RST 08h                                    ; @16D3  CF                
    CALL loc_17E6                              ; @16D4  CD E6 17          
loc_16D7:
    CALL loc_0491                              ; @16D7  CD 91 04          
    JR Z,loc_16D7                              ; @16DA  28 FB             
    CALL OS_COMMAND_LOOKUP                     ; @16DC  CD 38 02          
    JR NC,loc_16D7                             ; @16DF  30 F6             
    LD BC,16D0h                                ; @16E1  01 D0 16          
    PUSH BC                                    ; @16E4  C5                
    JP (HL)                                    ; @16E5  E9                
loc_16E6:
    LD BC,0009h                                ; @16E6  01 09 00          
    CALL AUX_OUTPUT_RULE                       ; @16E9  CD 5D 0B          
loc_16EC:
    PUSH BC                                    ; @16EC  C5                
    LD A,B                                     ; @16ED  78                
    LD (4009h),A                               ; @16EE  32 09 40          
    PUSH AF                                    ; @16F1  F5                
    XOR A                                      ; @16F2  AF                
    CALL loc_1749                              ; @16F3  CD 49 17          
    POP BC                                     ; @16F6  C1                
    CALL loc_1703                              ; @16F7  CD 03 17          
    POP BC                                     ; @16FA  C1                
    CALL loc_0B57                              ; @16FB  CD 57 0B          
    JR NZ,loc_16EC                             ; @16FE  20 EC             
    JP AUX_OUTPUT_RULE                         ; @1700  C3 5D 0B          
loc_1703:
    PUSH HL                                    ; @1703  E5                
    PUSH DE                                    ; @1704  D5                
    CALL loc_0DAF                              ; @1705  CD AF 0D          
    LD DE,4013h                                ; @1708  11 13 40          
    LD HL,11DEh                                ; @170B  21 DE 11          
    CALL loc_08AC                              ; @170E  CD AC 08          
    POP BC                                     ; @1711  C1                
    POP HL                                     ; @1712  E1                
    LD B,C                                     ; @1713  41                
loc_1714:
    LD E,(HL)                                  ; @1714  5E                
    INC HL                                     ; @1715  23                
    LD D,(HL)                                  ; @1716  56                
    INC HL                                     ; @1717  23                
    LD A,(HL)                                  ; @1718  7E                
    INC HL                                     ; @1719  23                
    PUSH HL                                    ; @171A  E5                
    PUSH BC                                    ; @171B  C5                
    CALL loc_1839                              ; @171C  CD 39 18          
    AND B                                      ; @171F  A0                
    EXX                                        ; @1720  D9                
    JR NZ,loc_1724                             ; @1721  20 01             
    INC D                                      ; @1723  14                
loc_1724:
    LD B,D                                     ; @1724  42                
    LD D,00h                                   ; @1725  16 00             
    LD HL,4013h                                ; @1727  21 13 40          
    ADD HL,DE                                  ; @172A  19                
    EX DE,HL                                   ; @172B  EB                
    LD HL,127Ch                                ; @172C  21 7C 12          
    CALL loc_08AC                              ; @172F  CD AC 08          
    POP BC                                     ; @1732  C1                
    POP HL                                     ; @1733  E1                
    DJNZ loc_1714                              ; @1734  10 DE             
    RET                                        ; @1736  C9                
loc_1737:
    ; Dispatched for keycode/mode: 87/09
    LD A,(400Ah)                               ; @1737  3A 0A 40          
    OR A                                       ; @173A  B7                
    RET Z                                      ; @173B  C8                
    DEC A                                      ; @173C  3D                
    JR loc_1749                                ; @173D  18 0A             
loc_173F:
    ; Dispatched for keycode/mode: 84/09
    CALL loc_1753                              ; @173F  CD 53 17          
    LD A,(400Ah)                               ; @1742  3A 0A 40          
    DEC E                                      ; @1745  1D                
    CP E                                       ; @1746  BB                
    RET Z                                      ; @1747  C8                
    INC A                                      ; @1748  3C                
loc_1749:
    LD (400Ah),A                               ; @1749  32 0A 40          
    CALL loc_1753                              ; @174C  CD 53 17          
    LD (400Ch),A                               ; @174F  32 0C 40          
    RET                                        ; @1752  C9                
loc_1753:
    LD HL,1855h                                ; @1753  21 55 18          
    LD A,(4009h)                               ; @1756  3A 09 40          
    LD B,A                                     ; @1759  47                
    XOR B                                      ; @175A  A8                
    OR B                                       ; @175B  B0                
    LD A,00h                                   ; @175C  3E 00             
    JR Z,loc_1764                              ; @175E  28 04             
loc_1760:
    ADD A,(HL)                                 ; @1760  86                
    INC HL                                     ; @1761  23                
    DJNZ loc_1760                              ; @1762  10 FC             
loc_1764:
    LD C,A                                     ; @1764  4F                
    LD A,(400Ah)                               ; @1765  3A 0A 40          
    ADD A,C                                    ; @1768  81                
    LD C,A                                     ; @1769  4F                
    ADD A,C                                    ; @176A  81                
    ADD A,C                                    ; @176B  81                
    LD C,A                                     ; @176C  4F                
    LD E,(HL)                                  ; @176D  5E                
    LD HL,185Eh                                ; @176E  21 5E 18          
    ADD HL,BC                                  ; @1771  09                
    LD A,(HL)                                  ; @1772  7E                
    RET                                        ; @1773  C9                
loc_1774:
    ; Dispatched for keycode/mode: 86/09
    LD A,(4009h)                               ; @1774  3A 09 40          
    OR A                                       ; @1777  B7                
    RET Z                                      ; @1778  C8                
    DEC A                                      ; @1779  3D                
    JR loc_1783                                ; @177A  18 07             
loc_177C:
    ; Dispatched for keycode/mode: 85/09
    LD A,(4009h)                               ; @177C  3A 09 40          
    CP 08h                                     ; @177F  FE 08             
    RET Z                                      ; @1781  C8                
    INC A                                      ; @1782  3C                
loc_1783:
    LD (4009h),A                               ; @1783  32 09 40          
    POP HL                                     ; @1786  E1                
    XOR A                                      ; @1787  AF                
    JP loc_16C2                                ; @1788  C3 C2 16          
loc_178B:
    ; Dispatched for keycode/mode: C6/09
    XOR A                                      ; @178B  AF                
    JR loc_1783                                ; @178C  18 F5             
loc_178E:
    ; Dispatched for keycode/mode: C5/09
    LD A,08h                                   ; @178E  3E 08             
    JR loc_1783                                ; @1790  18 F1             
loc_1792:
    ; Dispatched for keycode/mode: 8D/09
    POP HL                                     ; @1792  E1                
    LD A,(400Ah)                               ; @1793  3A 0A 40          
    PUSH AF                                    ; @1796  F5                
    CALL loc_1749                              ; @1797  CD 49 17          
    INC HL                                     ; @179A  23                
    INC HL                                     ; @179B  23                
    LD A,(HL)                                  ; @179C  7E                
    CALL loc_1839                              ; @179D  CD 39 18          
    LD (HL),A                                  ; @17A0  77                
    LD HL,4654h                                ; @17A1  21 54 46          
    LD A,(4009h)                               ; @17A4  3A 09 40          
    PUSH AF                                    ; @17A7  F5                
    OR A                                       ; @17A8  B7                
    JR NZ,loc_17B0                             ; @17A9  20 05             
    LD A,(HL)                                  ; @17AB  7E                
    RLCA                                       ; @17AC  07                
    CALL NC,loc_181C                           ; @17AD  D4 1C 18          
loc_17B0:
    LD A,80h                                   ; @17B0  3E 80             
    LD (400Bh),A                               ; @17B2  32 0B 40          
    OR (HL)                                    ; @17B5  B6                
    LD (HL),A                                  ; @17B6  77                
    CALL loc_04BA                              ; @17B7  CD BA 04          
    XOR A                                      ; @17BA  AF                
    CALL loc_1749                              ; @17BB  CD 49 17          
    POP AF                                     ; @17BE  F1                
    LD B,A                                     ; @17BF  47                
    CALL loc_1703                              ; @17C0  CD 03 17          
    POP AF                                     ; @17C3  F1                
    CALL loc_1749                              ; @17C4  CD 49 17          
    RST 10h                                    ; @17C7  D7                
    BIT 1,H                                    ; @17C8  CB 4C             
    LD A,11h                                   ; @17CA  3E 11             
    LD (4525h),A                               ; @17CC  32 25 45          
    JR NZ,loc_17D3                             ; @17CF  20 02             
    LD A,00h                                   ; @17D1  3E 00             
loc_17D3:
    LD (452Ah),A                               ; @17D3  32 2A 45          
    JP loc_16CC                                ; @17D6  C3 CC 16          
loc_17D9:
    ; Dispatched for keycode/mode: 8E/09
    CALL loc_1828                              ; @17D9  CD 28 18          
    LD A,(400Bh)                               ; @17DC  3A 0B 40          
    OR A                                       ; @17DF  B7                
    CALL NZ,loc_16E6                           ; @17E0  C4 E6 16          
    JP loc_0CDB                                ; @17E3  C3 DB 0C          
loc_17E6:
    CALL loc_0A47                              ; @17E6  CD 47 0A          
    LD A,(400Ah)                               ; @17E9  3A 0A 40          
    OR A                                       ; @17EC  B7                
    LD D,40h                                   ; @17ED  16 40             
    JR NZ,loc_17F3                             ; @17EF  20 02             
    LD D,00h                                   ; @17F1  16 00             
loc_17F3:
    PUSH AF                                    ; @17F3  F5                
    CALL loc_1749                              ; @17F4  CD 49 17          
    POP AF                                     ; @17F7  F1                
    DEC E                                      ; @17F8  1D                
    CP E                                       ; @17F9  BB                
    LD E,10h                                   ; @17FA  1E 10             
    JR C,loc_1800                              ; @17FC  38 02             
    LD E,00h                                   ; @17FE  1E 00             
loc_1800:
    LD A,D                                     ; @1800  7A                
    OR E                                       ; @1801  B3                
    PUSH AF                                    ; @1802  F5                
    LD A,(4009h)                               ; @1803  3A 09 40          
    OR A                                       ; @1806  B7                
    LD D,80h                                   ; @1807  16 80             
    JR NZ,loc_180D                             ; @1809  20 02             
    LD D,00h                                   ; @180B  16 00             
loc_180D:
    CP 08h                                     ; @180D  FE 08             
    LD E,20h                                   ; @180F  1E 20             
    JR C,loc_1815                              ; @1811  38 02             
    LD E,00h                                   ; @1813  1E 00             
loc_1815:
    LD A,D                                     ; @1815  7A                
    OR E                                       ; @1816  B3                
    LD D,A                                     ; @1817  57                
    POP AF                                     ; @1818  F1                
    JP loc_16AD                                ; @1819  C3 AD 16          
loc_181C:
    LD HL,D00Fh                                ; @181C  21 0F D0          
    LD (4654h),HL                              ; @181F  22 54 46          
    LD A,02h                                   ; @1822  3E 02             
    LD (4656h),A                               ; @1824  32 56 46          
    RET                                        ; @1827  C9                
loc_1828:
    RST 10h                                    ; @1828  D7                
    LD (466Ch),HL                              ; @1829  22 6C 46          
    LD A,L                                     ; @182C  7D                
    AND 1Fh                                    ; @182D  E6 1F             
    OUT (5Fh),A                                ; @182F  D3 5F             
    BIT 1,H                                    ; @1831  CB 4C             
    RET NZ                                     ; @1833  C0                
    XOR A                                      ; @1834  AF                
    LD (4517h),A                               ; @1835  32 17 45          
    RET                                        ; @1838  C9                
loc_1839:
    EXX                                        ; @1839  D9                
    LD B,A                                     ; @183A  47                
    RRCA                                       ; @183B  0F                
    RRCA                                       ; @183C  0F                
    RRCA                                       ; @183D  0F                
    AND 03h                                    ; @183E  E6 03             
    LD E,A                                     ; @1840  5F                
    LD D,00h                                   ; @1841  16 00             
    LD HL,4654h                                ; @1843  21 54 46          
    ADD HL,DE                                  ; @1846  19                
    LD A,B                                     ; @1847  78                
    AND 07h                                    ; @1848  E6 07             
    LD B,A                                     ; @184A  47                
    LD A,01h                                   ; @184B  3E 01             
    JR Z,loc_1852                              ; @184D  28 03             
loc_184F:
    RLCA                                       ; @184F  07                
    DJNZ loc_184F                              ; @1850  10 FD             
loc_1852:
    LD B,A                                     ; @1852  47                
    XOR (HL)                                   ; @1853  AE                
    RET                                        ; @1854  C9                
    DB 01h,03h,02h,02h,02h,01h,02h,02h,02h,18h,00h,07h,07h,02h,02h,15h ; @1855  01 03 02 02 02 01 02 02 02 18 00 07 07 02 02 15
    DB 04h,03h,24h,04h,05h,14h,06h,01h,22h,08h,04h,07h,0Ah,06h,24h,04h ; @1865  04 03 24 04 05 14 06 01 22 08 04 07 0A 06 24 04
    DB 08h,10h,0Ch,10h,24h,04h,11h,18h,0Eh,12h,14h,10h,09h,1Ah,12h,0Ah ; @1875  08 10 0C 10 24 04 11 18 0E 12 14 10 09 1A 12 0A
    DB 11h,04h,13h,24h,04h,14h,0Fh,14h,15h,22h,16h,16h ; @1885  11 04 13 24 04 14 0F 14 15 22 16 16
loc_1891:
    LD DE,(4594h)                              ; @1891  ED 5B 94 45       
    LD HL,(4665h)                              ; @1895  2A 65 46          
    RST 38h                                    ; @1898  FF                
    JR Z,loc_18A2                              ; @1899  28 07             
    LD A,(4586h)                               ; @189B  3A 86 45          
    LD (DE),A                                  ; @189E  12                
    JP loc_1CE4                                ; @189F  C3 E4 1C          
loc_18A2:
    XOR A                                      ; @18A2  AF                
    LD (4514h),A                               ; @18A3  32 14 45          
    JP loc_016C                                ; @18A6  C3 6C 01          
SERIAL_RECEIVE_SERVICE:
    LD C,7Fh                                   ; @18A9  0E 7F             
SERIAL_READ_STATUS:
    ; Communications status poll, port 5Fh; UART electrical mapping not verified
    IN A,(5Fh)                                 ; @18AB  DB 5F             
    BIT 4,A                                    ; @18AD  CB 67             
    JR NZ,loc_18C3                             ; @18AF  20 12             
    BIT 3,A                                    ; @18B1  CB 5F             
    RET Z                                      ; @18B3  C8                
    BIT 1,A                                    ; @18B4  CB 4F             
    JR Z,loc_18CD                              ; @18B6  28 15             
    RST 10h                                    ; @18B8  D7                
    BIT 5,L                                    ; @18B9  CB 6D             
    JR Z,loc_18CD                              ; @18BB  28 10             
    IN A,(5Bh)                                 ; @18BD  DB 5B             
    LD B,CEh                                   ; @18BF  06 CE             
    JR loc_18F2                                ; @18C1  18 2F             
loc_18C3:
    LD A,(4518h)                               ; @18C3  3A 18 45          
    OR A                                       ; @18C6  B7                
    JP Z,loc_0451                              ; @18C7  CA 51 04          
    JP loc_0448                                ; @18CA  C3 48 04          
loc_18CD:
    LD A,(453Fh)                               ; @18CD  3A 3F 45          
    OR A                                       ; @18D0  B7                
    JR Z,loc_18D9                              ; @18D1  28 06             
    LD HL,0005h                                ; @18D3  21 05 00          
    CALL loc_016F                              ; @18D6  CD 6F 01          
loc_18D9:
    LD HL,4586h                                ; @18D9  21 86 45          
SERIAL_READ_CHAR:
    IN A,(5Bh)                                 ; @18DC  DB 5B             
    AND C                                      ; @18DE  A1                
    LD B,A                                     ; @18DF  47                
    LD A,(4525h)                               ; @18E0  3A 25 45          
    XOR B                                      ; @18E3  A8                
    JR NZ,loc_18E9                             ; @18E4  20 03             
    LD (4517h),A                               ; @18E6  32 17 45          
loc_18E9:
    LD A,B                                     ; @18E9  78                
    CP C                                       ; @18EA  B9                
    JR Z,loc_1907                              ; @18EB  28 1A             
    ADD A,E0h                                  ; @18ED  C6 E0             
    LD A,B                                     ; @18EF  78                
    JR NC,loc_1907                             ; @18F0  30 15             
loc_18F2:
    LD A,B                                     ; @18F2  78                
    LD HL,4586h                                ; @18F3  21 86 45          
    LD (HL),A                                  ; @18F6  77                
    INC HL                                     ; @18F7  23                
    LD (HL),80h                                ; @18F8  36 80             
    LD HL,405Bh                                ; @18FA  21 5B 40          
    CALL QUEUE_HANDLER_A                       ; @18FD  CD 88 02          
    LD A,(4514h)                               ; @1900  3A 14 45          
    OR A                                       ; @1903  B7                
    JR NZ,loc_1891                             ; @1904  20 8B             
    RET                                        ; @1906  C9                
loc_1907:
    CP 1Bh                                     ; @1907  FE 1B             
    JR Z,loc_18F2                              ; @1909  28 E7             
    CP 1Eh                                     ; @190B  FE 1E             
    JR Z,loc_18F2                              ; @190D  28 E3             
    CP 08h                                     ; @190F  FE 08             
    JR Z,loc_18F2                              ; @1911  28 DF             
    CP 09h                                     ; @1913  FE 09             
    JR Z,loc_18F2                              ; @1915  28 DB             
    CP 07h                                     ; @1917  FE 07             
    JR Z,loc_18F2                              ; @1919  28 D7             
    CP 0Dh                                     ; @191B  FE 0D             
    JR Z,loc_18F2                              ; @191D  28 D3             
    CP 0Ah                                     ; @191F  FE 0A             
    JR Z,loc_18F2                              ; @1921  28 CF             
    CP 05h                                     ; @1923  FE 05             
    JR Z,loc_18F2                              ; @1925  28 CB             
    RST 10h                                    ; @1927  D7                
    BIT 1,H                                    ; @1928  CB 4C             
    JR NZ,SERIAL_XOFF_PATH                     ; @192A  20 06             
loc_192C:
    RST 10h                                    ; @192C  D7                
    BIT 0,H                                    ; @192D  CB 44             
    JR NZ,loc_18F2                             ; @192F  20 C1             
    RET                                        ; @1931  C9                
SERIAL_XOFF_PATH:
    LD A,B                                     ; @1932  78                
    CP 13h                                     ; @1933  FE 13             
    JR NZ,loc_192C                             ; @1935  20 F5             
    BIT 2,H                                    ; @1937  CB 54             
    JR Z,loc_192C                              ; @1939  28 F1             
    LD A,(4592h)                               ; @193B  3A 92 45          
    OR A                                       ; @193E  B7                
    JR Z,loc_192C                              ; @193F  28 EB             
    LD (4517h),A                               ; @1941  32 17 45          
    JR loc_192C                                ; @1944  18 E6             
loc_1946:
    CALL loc_1A06                              ; @1946  CD 06 1A          
    XOR A                                      ; @1949  AF                
    LD (451Fh),A                               ; @194A  32 1F 45          
    INC A                                      ; @194D  3C                
    LD (4517h),A                               ; @194E  32 17 45          
    LD (4518h),A                               ; @1951  32 18 45          
    LD A,1Eh                                   ; @1954  3E 1E             
    LD (4525h),A                               ; @1956  32 25 45          
    LD (452Ah),A                               ; @1959  32 2A 45          
    RST 10h                                    ; @195C  D7                
    LD (466Ch),HL                              ; @195D  22 6C 46          
    SET 1,H                                    ; @1960  CB CC             
    LD (4654h),HL                              ; @1962  22 54 46          
    PUSH BC                                    ; @1965  C5                
    CALL loc_04BA                              ; @1966  CD BA 04          
    POP BC                                     ; @1969  C1                
    JR loc_1994                                ; @196A  18 28             
loc_196C:
    XOR A                                      ; @196C  AF                
    LD (451Fh),A                               ; @196D  32 1F 45          
    JP loc_0CDC                                ; @1970  C3 DC 0C          
loc_1973:
    ; Dispatched for keycode/mode: 99/00, 99/03
    LD A,FFh                                   ; @1973  3E FF             
    LD (451Fh),A                               ; @1975  32 1F 45          
loc_1978:
    ; Dispatched for keycode/mode: 96/00, 96/03
    RST 10h                                    ; @1978  D7                
    LD (466Ch),HL                              ; @1979  22 6C 46          
    CALL loc_04BA                              ; @197C  CD BA 04          
    CALL loc_1A06                              ; @197F  CD 06 1A          
    LD A,11h                                   ; @1982  3E 11             
    LD (4525h),A                               ; @1984  32 25 45          
    CALL loc_07E6                              ; @1987  CD E6 07          
    LD HL,15B1h                                ; @198A  21 B1 15          
    RST 30h                                    ; @198D  F7                
    CALL loc_1B01                              ; @198E  CD 01 1B          
    JR Z,loc_196C                              ; @1991  28 D9             
    LD B,A                                     ; @1993  47                
loc_1994:
    IN A,(5Fh)                                 ; @1994  DB 5F             
    BIT 4,A                                    ; @1996  CB 67             
    JR Z,loc_19A0                              ; @1998  28 06             
    CALL loc_0448                              ; @199A  CD 48 04          
    JP loc_0CDC                                ; @199D  C3 DC 0C          
loc_19A0:
    LD A,B                                     ; @19A0  78                
    CALL DOCUMENT_DIRECTORY_LOOKUP             ; @19A1  CD 14 1D          
    LD B,C                                     ; @19A4  41                
    JR Z,loc_19F1                              ; @19A5  28 4A             
loc_19A7:
    PUSH BC                                    ; @19A7  C5                
    INC HL                                     ; @19A8  23                
    INC HL                                     ; @19A9  23                
    LD E,(HL)                                  ; @19AA  5E                
    INC HL                                     ; @19AB  23                
    LD D,(HL)                                  ; @19AC  56                
    INC HL                                     ; @19AD  23                
    LD A,(HL)                                  ; @19AE  7E                
    INC HL                                     ; @19AF  23                
    OR (HL)                                    ; @19B0  B6                
    JR Z,loc_19EA                              ; @19B1  28 37             
    LD B,(HL)                                  ; @19B3  46                
    DEC HL                                     ; @19B4  2B                
    LD L,(HL)                                  ; @19B5  6E                
    LD H,B                                     ; @19B6  60                
    LD A,(451Fh)                               ; @19B7  3A 1F 45          
    OR A                                       ; @19BA  B7                
    JR Z,loc_19C6                              ; @19BB  28 09             
    LD (4521h),DE                              ; @19BD  ED 53 21 45       
    LD (4523h),HL                              ; @19C1  22 23 45          
    JR loc_19D9                                ; @19C4  18 13             
loc_19C6:
    CALL loc_1A29                              ; @19C6  CD 29 1A          
    JR Z,loc_19E1                              ; @19C9  28 16             
    LD (451Bh),HL                              ; @19CB  22 1B 45          
    LD DE,(452Bh)                              ; @19CE  ED 5B 2B 45       
    EX DE,HL                                   ; @19D2  EB                
    OR A                                       ; @19D3  B7                
    SBC HL,DE                                  ; @19D4  ED 52             
    LD (451Dh),HL                              ; @19D6  22 1D 45          
loc_19D9:
    POP BC                                     ; @19D9  C1                
    LD A,C                                     ; @19DA  79                
    LD (4592h),A                               ; @19DB  32 92 45          
    JP loc_0CDC                                ; @19DE  C3 DC 0C          
loc_19E1:
    LD HL,0000h                                ; @19E1  21 00 00          
    LD (451Bh),HL                              ; @19E4  22 1B 45          
    LD (451Dh),HL                              ; @19E7  22 1D 45          
loc_19EA:
    POP BC                                     ; @19EA  C1                
    LD HL,1384h                                ; @19EB  21 84 13          
    RST 30h                                    ; @19EE  F7                
    JR loc_19FD                                ; @19EF  18 0C             
loc_19F1:
    PUSH BC                                    ; @19F1  C5                
    LD HL,1357h                                ; @19F2  21 57 13          
    RST 30h                                    ; @19F5  F7                
    LD A,07h                                   ; @19F6  3E 07             
    RST 08h                                    ; @19F8  CF                
    POP AF                                     ; @19F9  F1                
    CALL LCD_CHAR_OUTPUT                       ; @19FA  CD 9E 06          
loc_19FD:
    CALL loc_0448                              ; @19FD  CD 48 04          
    CALL loc_0A64                              ; @1A00  CD 64 0A          
    JP loc_0CDC                                ; @1A03  C3 DC 0C          
loc_1A06:
    LD A,(4592h)                               ; @1A06  3A 92 45          
    OR A                                       ; @1A09  B7                
    LD A,00h                                   ; @1A0A  3E 00             
    RET Z                                      ; @1A0C  C8                
    CALL loc_07E6                              ; @1A0D  CD E6 07          
    LD HL,1388h                                ; @1A10  21 88 13          
    RST 30h                                    ; @1A13  F7                
    LD A,18h                                   ; @1A14  3E 18             
    RST 08h                                    ; @1A16  CF                
    LD A,(4592h)                               ; @1A17  3A 92 45          
    CALL LCD_CHAR_OUTPUT                       ; @1A1A  CD 9E 06          
    XOR A                                      ; @1A1D  AF                
    LD (451Fh),A                               ; @1A1E  32 1F 45          
    CALL loc_0A64                              ; @1A21  CD 64 0A          
    CALL loc_0828                              ; @1A24  CD 28 08          
    POP AF                                     ; @1A27  F1                
    RET                                        ; @1A28  C9                
loc_1A29:
    ADD HL,DE                                  ; @1A29  19                
    LD (452Bh),HL                              ; @1A2A  22 2B 45          
    EX DE,HL                                   ; @1A2D  EB                
    LD A,(HL)                                  ; @1A2E  7E                
    CP 1Bh                                     ; @1A2F  FE 1B             
    RET NZ                                     ; @1A31  C0                
    INC HL                                     ; @1A32  23                
loc_1A33:
    CALL loc_1A66                              ; @1A33  CD 66 1A          
    CALL loc_0051                              ; @1A36  CD 51 00          
    CP 70h                                     ; @1A39  FE 70             
    JR NZ,loc_1A33                             ; @1A3B  20 F6             
    CALL loc_1A66                              ; @1A3D  CD 66 1A          
    CALL loc_0051                              ; @1A40  CD 51 00          
    LD DE,1A75h                                ; @1A43  11 75 1A          
    LD B,A                                     ; @1A46  47                
loc_1A47:
    LD A,(DE)                                  ; @1A47  1A                
    INC DE                                     ; @1A48  13                
    OR A                                       ; @1A49  B7                
    JR Z,loc_1A33                              ; @1A4A  28 E7             
    CP B                                       ; @1A4C  B8                
    JR Z,loc_1A53                              ; @1A4D  28 04             
    INC DE                                     ; @1A4F  13                
    INC DE                                     ; @1A50  13                
    JR loc_1A47                                ; @1A51  18 F4             
loc_1A53:
    EX DE,HL                                   ; @1A53  EB                
    LD C,(HL)                                  ; @1A54  4E                
    INC HL                                     ; @1A55  23                
    LD B,(HL)                                  ; @1A56  46                
    INC HL                                     ; @1A57  23                
    EX DE,HL                                   ; @1A58  EB                
    CALL loc_1A66                              ; @1A59  CD 66 1A          
    CP 3Dh                                     ; @1A5C  FE 3D             
    JR NZ,loc_1A33                             ; @1A5E  20 D3             
    CALL loc_1A66                              ; @1A60  CD 66 1A          
    LD (BC),A                                  ; @1A63  02                
    JR loc_1A33                                ; @1A64  18 CD             
loc_1A66:
    LD DE,(452Bh)                              ; @1A66  ED 5B 2B 45       
    RST 38h                                    ; @1A6A  FF                
    JR Z,loc_1A72                              ; @1A6B  28 05             
    LD A,(HL)                                  ; @1A6D  7E                
    INC HL                                     ; @1A6E  23                
    CP 0Dh                                     ; @1A6F  FE 0D             
    RET NZ                                     ; @1A71  C0                
loc_1A72:
    POP DE                                     ; @1A72  D1                
    OR A                                       ; @1A73  B7                
    RET                                        ; @1A74  C9                
    DB 78h,25h,45h,63h,26h,45h,00h              ; @1A75  78 25 45 63 26 45 00   |x%Ec&E.|
loc_1A7C:
    ; Dispatched for keycode/mode: 97/00
    LD HL,4514h                                ; @1A7C  21 14 45          
    LD A,(HL)                                  ; @1A7F  7E                
    LD (HL),00h                                ; @1A80  36 00             
    OR A                                       ; @1A82  B7                
    JP M,loc_1B1F                              ; @1A83  FA 1F 1B          
    CALL loc_1A06                              ; @1A86  CD 06 1A          
    CALL loc_07E6                              ; @1A89  CD E6 07          
    LD HL,15B1h                                ; @1A8C  21 B1 15          
    RST 30h                                    ; @1A8F  F7                
loc_1A90:
    CALL loc_1B01                              ; @1A90  CD 01 1B          
    JR C,loc_1A90                              ; @1A93  38 FB             
    JP Z,loc_0CDC                              ; @1A95  CA DC 0C          
    PUSH AF                                    ; @1A98  F5                
    CALL loc_1E05                              ; @1A99  CD 05 1E          
    OR A                                       ; @1A9C  B7                
    JP M,loc_1AE7                              ; @1A9D  FA E7 1A          
    JR Z,loc_1AF4                              ; @1AA0  28 52             
    LD HL,1369h                                ; @1AA2  21 69 13          
    RST 30h                                    ; @1AA5  F7                
    LD A,0Dh                                   ; @1AA6  3E 0D             
    RST 08h                                    ; @1AA8  CF                
    POP AF                                     ; @1AA9  F1                
    CALL LCD_CHAR_OUTPUT                       ; @1AAA  CD 9E 06          
    LD A,1Ch                                   ; @1AAD  3E 1C             
    RST 08h                                    ; @1AAF  CF                
    CALL loc_1B01                              ; @1AB0  CD 01 1B          
    JP Z,loc_0CDC                              ; @1AB3  CA DC 0C          
    CALL loc_004B                              ; @1AB6  CD 4B 00          
    JR NZ,loc_1AE1                             ; @1AB9  20 26             
    LD A,(4598h)                               ; @1ABB  3A 98 45          
    PUSH AF                                    ; @1ABE  F5                
    CALL loc_1E5A                              ; @1ABF  CD 5A 1E          
    POP AF                                     ; @1AC2  F1                
    CALL loc_1E05                              ; @1AC3  CD 05 1E          
    LD HL,137Bh                                ; @1AC6  21 7B 13          
    RST 30h                                    ; @1AC9  F7                
    LD A,07h                                   ; @1ACA  3E 07             
    RST 08h                                    ; @1ACC  CF                
    LD A,(4598h)                               ; @1ACD  3A 98 45          
    CALL LCD_CHAR_OUTPUT                       ; @1AD0  CD 9E 06          
loc_1AD3:
    CALL loc_1B1F                              ; @1AD3  CD 1F 1B          
    LD A,FFh                                   ; @1AD6  3E FF             
    LD (4514h),A                               ; @1AD8  32 14 45          
    CALL loc_0A64                              ; @1ADB  CD 64 0A          
    JP loc_0CDC                                ; @1ADE  C3 DC 0C          
loc_1AE1:
    LD HL,1362h                                ; @1AE1  21 62 13          
    RST 30h                                    ; @1AE4  F7                
    JR loc_1AD3                                ; @1AE5  18 EC             
loc_1AE7:
    POP AF                                     ; @1AE7  F1                
    CALL loc_016C                              ; @1AE8  CD 6C 01          
    LD HL,1302h                                ; @1AEB  21 02 13          
    CALL loc_0045                              ; @1AEE  CD 45 00          
    JP loc_0CDC                                ; @1AF1  C3 DC 0C          
loc_1AF4:
    LD HL,12F9h                                ; @1AF4  21 F9 12          
    RST 30h                                    ; @1AF7  F7                
    LD A,0Fh                                   ; @1AF8  3E 0F             
    RST 08h                                    ; @1AFA  CF                
    POP AF                                     ; @1AFB  F1                
    CALL LCD_CHAR_OUTPUT                       ; @1AFC  CD 9E 06          
    JR loc_1AD3                                ; @1AFF  18 D2             
loc_1B01:
    CALL loc_0491                              ; @1B01  CD 91 04          
    JR Z,loc_1B01                              ; @1B04  28 FB             
    CP 8Eh                                     ; @1B06  FE 8E             
    RET Z                                      ; @1B08  C8                
    CP 98h                                     ; @1B09  FE 98             
    SCF                                        ; @1B0B  37                
    RET Z                                      ; @1B0C  C8                
    CP D8h                                     ; @1B0D  FE D8             
    SCF                                        ; @1B0F  37                
    RET Z                                      ; @1B10  C8                
    CP 80h                                     ; @1B11  FE 80             
    JR Z,loc_1B1D                              ; @1B13  28 08             
    CP 7Fh                                     ; @1B15  FE 7F             
    JR NC,loc_1B01                             ; @1B17  30 E8             
    CP 20h                                     ; @1B19  FE 20             
    JR C,loc_1B01                              ; @1B1B  38 E4             
loc_1B1D:
    OR A                                       ; @1B1D  B7                
    RET                                        ; @1B1E  C9                
loc_1B1F:
    RST 10h                                    ; @1B1F  D7                
    BIT 3,E                                    ; @1B20  CB 5B             
    RET Z                                      ; @1B22  C8                
    CALL loc_0DBF                              ; @1B23  CD BF 0D          
    LD HL,(4596h)                              ; @1B26  2A 96 45          
    LD DE,0027h                                ; @1B29  11 27 00          
    OR A                                       ; @1B2C  B7                
    SBC HL,DE                                  ; @1B2D  ED 52             
    LD A,H                                     ; @1B2F  7C                
    OR A                                       ; @1B30  B7                
    JP M,loc_18A2                              ; @1B31  FA A2 18          
    LD DE,4013h                                ; @1B34  11 13 40          
loc_1B37:
    LD HL,(4594h)                              ; @1B37  2A 94 45          
    LD A,(DE)                                  ; @1B3A  1A                
    OR A                                       ; @1B3B  B7                
    JR Z,loc_1B45                              ; @1B3C  28 07             
    LD (HL),A                                  ; @1B3E  77                
    CALL loc_1CE4                              ; @1B3F  CD E4 1C          
    INC DE                                     ; @1B42  13                
    JR loc_1B37                                ; @1B43  18 F2             
loc_1B45:
    LD (HL),0Dh                                ; @1B45  36 0D             
    JP loc_1CE4                                ; @1B47  C3 E4 1C          
loc_1B4A:
    CALL loc_04A1                              ; @1B4A  CD A1 04          
    RET Z                                      ; @1B4D  C8                
    CALL loc_1B7A                              ; @1B4E  CD 7A 1B          
    LD B,A                                     ; @1B51  47                
    LD A,(4518h)                               ; @1B52  3A 18 45          
    OR A                                       ; @1B55  B7                
    JR NZ,loc_1B99                             ; @1B56  20 41             
loc_1B58:
    LD HL,4059h                                ; @1B58  21 59 40          
    LD A,(HL)                                  ; @1B5B  7E                
    OR A                                       ; @1B5C  B7                
    JR Z,loc_1B62                              ; @1B5D  28 03             
    LD (HL),00h                                ; @1B5F  36 00             
    RST 18h                                    ; @1B61  DF                
loc_1B62:
    LD A,B                                     ; @1B62  78                
    CP 0Dh                                     ; @1B63  FE 0D             
    JR NZ,loc_1B68                             ; @1B65  20 01             
    DEC (HL)                                   ; @1B67  35                
loc_1B68:
    LD A,(4002h)                               ; @1B68  3A 02 40          
    CP 27h                                     ; @1B6B  FE 27             
    LD A,B                                     ; @1B6D  78                
    PUSH AF                                    ; @1B6E  F5                
    CALL LCD_CHAR_OUTPUT                       ; @1B6F  CD 9E 06          
    LD A,B                                     ; @1B72  78                
    CALL AUX_QUEUE_OUTPUT                      ; @1B73  CD 0C 0B          
    POP AF                                     ; @1B76  F1                
    JR Z,loc_1BD2                              ; @1B77  28 59             
    RET                                        ; @1B79  C9                
loc_1B7A:
    CP 05h                                     ; @1B7A  FE 05             
    RET NZ                                     ; @1B7C  C0                
    RST 10h                                    ; @1B7D  D7                
    BIT 4,E                                    ; @1B7E  CB 63             
    RET Z                                      ; @1B80  C8                
    LD B,A                                     ; @1B81  47                
    LD A,(4592h)                               ; @1B82  3A 92 45          
    OR A                                       ; @1B85  B7                
    LD A,B                                     ; @1B86  78                
    RET NZ                                     ; @1B87  C0                
    LD A,59h                                   ; @1B88  3E 59             
    CALL DOCUMENT_DIRECTORY_LOOKUP             ; @1B8A  CD 14 1D          
    LD A,05h                                   ; @1B8D  3E 05             
    RET Z                                      ; @1B8F  C8                
    LD B,C                                     ; @1B90  41                
    POP AF                                     ; @1B91  F1                
    XOR A                                      ; @1B92  AF                
    CALL loc_07E6                              ; @1B93  CD E6 07          
    JP loc_19A7                                ; @1B96  C3 A7 19          
loc_1B99:
    LD HL,(451Dh)                              ; @1B99  2A 1D 45          
    LD A,H                                     ; @1B9C  7C                
    OR L                                       ; @1B9D  B5                
    JR Z,loc_1BB2                              ; @1B9E  28 12             
    LD A,B                                     ; @1BA0  78                
    CP 1Eh                                     ; @1BA1  FE 1E             
    JR NZ,loc_1B58                             ; @1BA3  20 B3             
    LD A,(4514h)                               ; @1BA5  3A 14 45          
    OR A                                       ; @1BA8  B7                
    CALL Z,loc_1B1F                            ; @1BA9  CC 1F 1B          
    LD A,FFh                                   ; @1BAC  3E FF             
    LD (4514h),A                               ; @1BAE  32 14 45          
    RET                                        ; @1BB1  C9                
loc_1BB2:
    LD A,B                                     ; @1BB2  78                
    CP 07h                                     ; @1BB3  FE 07             
    JR Z,loc_1BC8                              ; @1BB5  28 11             
    CP 1Eh                                     ; @1BB7  FE 1E             
    JR NZ,loc_1B58                             ; @1BB9  20 9D             
    LD HL,4515h                                ; @1BBB  21 15 45          
    LD A,(HL)                                  ; @1BBE  7E                
    OR A                                       ; @1BBF  B7                
    LD (HL),00h                                ; @1BC0  36 00             
    JR NZ,loc_1BC8                             ; @1BC2  20 04             
    LD (HL),01h                                ; @1BC4  36 01             
    JR loc_1B58                                ; @1BC6  18 90             
loc_1BC8:
    XOR A                                      ; @1BC8  AF                
    LD (4514h),A                               ; @1BC9  32 14 45          
    CALL loc_1B1F                              ; @1BCC  CD 1F 1B          
    JP loc_0448                                ; @1BCF  C3 48 04          
loc_1BD2:
    LD B,26h                                   ; @1BD2  06 26             
loc_1BD4:
    LD A,B                                     ; @1BD4  78                
    RST 08h                                    ; @1BD5  CF                
    LD A,(4003h)                               ; @1BD6  3A 03 40          
    CP 20h                                     ; @1BD9  FE 20             
    JR Z,loc_1BE6                              ; @1BDB  28 09             
    LD A,1Ch                                   ; @1BDD  3E 1C             
    CP B                                       ; @1BDF  B8                
    JR Z,loc_1BE4                              ; @1BE0  28 02             
    DJNZ loc_1BD4                              ; @1BE2  10 F0             
loc_1BE4:
    LD B,1Dh                                   ; @1BE4  06 1D             
loc_1BE6:
    LD A,B                                     ; @1BE6  78                
    RST 08h                                    ; @1BE7  CF                
    LD A,27h                                   ; @1BE8  3E 27             
    SUB B                                      ; @1BEA  90                
    PUSH AF                                    ; @1BEB  F5                
    LD B,A                                     ; @1BEC  47                
    LD HL,4013h                                ; @1BED  21 13 40          
loc_1BF0:
    CALL LCD_READ                              ; @1BF0  CD 42 07          
    LD (HL),A                                  ; @1BF3  77                
    INC HL                                     ; @1BF4  23                
    DJNZ loc_1BF0                              ; @1BF5  10 F9             
    LD (HL),B                                  ; @1BF7  70                
    CALL loc_09EA                              ; @1BF8  CD EA 09          
    POP AF                                     ; @1BFB  F1                
    RST 08h                                    ; @1BFC  CF                
    RET                                        ; @1BFD  C9                
loc_1BFE:
    IN A,(5Fh)                                 ; @1BFE  DB 5F             
    BIT 2,A                                    ; @1C00  CB 57             
    RET Z                                      ; @1C02  C8                
    BIT 4,A                                    ; @1C03  CB 67             
    RET NZ                                     ; @1C05  C0                
    LD A,(4517h)                               ; @1C06  3A 17 45          
    OR A                                       ; @1C09  B7                
    RET NZ                                     ; @1C0A  C0                
    LD HL,4464h                                ; @1C0B  21 64 44          
    CALL QUEUE_HANDLER_B                       ; @1C0E  CD D8 02          
    JR NZ,loc_1C6D                             ; @1C11  20 5A             
TX_DEQUEUE:
    LD HL,(4523h)                              ; @1C13  2A 23 45          
    LD A,H                                     ; @1C16  7C                
    OR L                                       ; @1C17  B5                
    JR Z,loc_1C28                              ; @1C18  28 0E             
    DEC HL                                     ; @1C1A  2B                
    LD (4523h),HL                              ; @1C1B  22 23 45          
    LD HL,(4521h)                              ; @1C1E  2A 21 45          
    LD A,(HL)                                  ; @1C21  7E                
    INC HL                                     ; @1C22  23                
    LD (4521h),HL                              ; @1C23  22 21 45          
    JR loc_1C50                                ; @1C26  18 28             
loc_1C28:
    LD HL,451Fh                                ; @1C28  21 1F 45          
    LD A,(HL)                                  ; @1C2B  7E                
    OR A                                       ; @1C2C  B7                
    JR NZ,loc_1C56                             ; @1C2D  20 27             
loc_1C2F:
    LD A,(4592h)                               ; @1C2F  3A 92 45          
    OR A                                       ; @1C32  B7                
    RET Z                                      ; @1C33  C8                
    LD HL,(451Dh)                              ; @1C34  2A 1D 45          
    LD A,H                                     ; @1C37  7C                
    OR L                                       ; @1C38  B5                
    JR NZ,loc_1C44                             ; @1C39  20 09             
    LD (4592h),A                               ; @1C3B  32 92 45          
    LD A,11h                                   ; @1C3E  3E 11             
    LD (4525h),A                               ; @1C40  32 25 45          
    RET                                        ; @1C43  C9                
loc_1C44:
    DEC HL                                     ; @1C44  2B                
    LD (451Dh),HL                              ; @1C45  22 1D 45          
    LD HL,(451Bh)                              ; @1C48  2A 1B 45          
    LD A,(HL)                                  ; @1C4B  7E                
    INC HL                                     ; @1C4C  23                
    LD (451Bh),HL                              ; @1C4D  22 1B 45          
loc_1C50:
    LD HL,4464h                                ; @1C50  21 64 44          
    JP QUEUE_HANDLER_A                         ; @1C53  C3 88 02          
loc_1C56:
    CP 01h                                     ; @1C56  FE 01             
    JR NZ,loc_1C60                             ; @1C58  20 06             
    LD (452Ah),A                               ; @1C5A  32 2A 45          
    DEC (HL)                                   ; @1C5D  35                
    JR loc_1CAE                                ; @1C5E  18 4E             
loc_1C60:
    LD HL,452Ah                                ; @1C60  21 2A 45          
    LD A,(HL)                                  ; @1C63  7E                
    OR A                                       ; @1C64  B7                
    JR Z,loc_1C2F                              ; @1C65  28 C8             
    LD (HL),00h                                ; @1C67  36 00             
    LD C,0Dh                                   ; @1C69  0E 0D             
    JR loc_1CA1                                ; @1C6B  18 34             
loc_1C6D:
    LD C,A                                     ; @1C6D  4F                
    LD A,(451Fh)                               ; @1C6E  3A 1F 45          
    OR A                                       ; @1C71  B7                
    JR NZ,loc_1C97                             ; @1C72  20 23             
    LD A,0Dh                                   ; @1C74  3E 0D             
    CP C                                       ; @1C76  B9                
    JR Z,loc_1C89                              ; @1C77  28 10             
    LD A,(4526h)                               ; @1C79  3A 26 45          
    OR A                                       ; @1C7C  B7                
    JR Z,loc_1C97                              ; @1C7D  28 18             
    CP C                                       ; @1C7F  B9                
    JR NZ,loc_1C97                             ; @1C80  20 15             
    LD HL,0271h                                ; @1C82  21 71 02          
    LD (4528h),HL                              ; @1C85  22 28 45          
    RET                                        ; @1C88  C9                
loc_1C89:
    RST 10h                                    ; @1C89  D7                
    BIT 2,E                                    ; @1C8A  CB 53             
    JR Z,loc_1C97                              ; @1C8C  28 09             
    LD A,5Ah                                   ; @1C8E  3E 5A             
    CALL DOCUMENT_DIRECTORY_LOOKUP             ; @1C90  CD 14 1D          
    LD C,0Dh                                   ; @1C93  0E 0D             
    JR NZ,loc_1CC8                             ; @1C95  20 31             
loc_1C97:
    LD A,C                                     ; @1C97  79                
SERIAL_SEND_CHAR:
    OUT (5Bh),A                                ; @1C98  D3 5B             
    LD HL,44F8h                                ; @1C9A  21 F8 44          
    XOR A                                      ; @1C9D  AF                
    CP (HL)                                    ; @1C9E  BE                
    LD (HL),A                                  ; @1C9F  77                
    RET NZ                                     ; @1CA0  C0                
loc_1CA1:
    LD A,0Dh                                   ; @1CA1  3E 0D             
    CP C                                       ; @1CA3  B9                
    JP NZ,TX_DEQUEUE                           ; @1CA4  C2 13 1C          
    LD A,(451Fh)                               ; @1CA7  3A 1F 45          
    OR A                                       ; @1CAA  B7                
    JP NZ,TX_DEQUEUE                           ; @1CAB  C2 13 1C          
loc_1CAE:
    RST 10h                                    ; @1CAE  D7                
    BIT 1,H                                    ; @1CAF  CB 4C             
    JP Z,TX_DEQUEUE                            ; @1CB1  CA 13 1C          
    BIT 2,H                                    ; @1CB4  CB 54             
    JP NZ,TX_DEQUEUE                           ; @1CB6  C2 13 1C          
    LD A,(4592h)                               ; @1CB9  3A 92 45          
    OR A                                       ; @1CBC  B7                
    RET Z                                      ; @1CBD  C8                
    LD HL,(451Dh)                              ; @1CBE  2A 1D 45          
    LD A,H                                     ; @1CC1  7C                
    OR L                                       ; @1CC2  B5                
    RET Z                                      ; @1CC3  C8                
    LD (4517h),A                               ; @1CC4  32 17 45          
    RET                                        ; @1CC7  C9                
loc_1CC8:
    XOR A                                      ; @1CC8  AF                
    LD (452Ah),A                               ; @1CC9  32 2A 45          
DOCUMENT_TX_INIT:
    ; Document transfer setup: loads data pointer and length from directory entry
    INC A                                      ; @1CCC  3C                
    LD (451Fh),A                               ; @1CCD  32 1F 45          
    INC HL                                     ; @1CD0  23                
    INC HL                                     ; @1CD1  23                
    LD E,(HL)                                  ; @1CD2  5E                
    INC HL                                     ; @1CD3  23                
    LD D,(HL)                                  ; @1CD4  56                
    LD (4521h),DE                              ; @1CD5  ED 53 21 45       
    INC HL                                     ; @1CD9  23                
    LD E,(HL)                                  ; @1CDA  5E                
    INC HL                                     ; @1CDB  23                
    LD D,(HL)                                  ; @1CDC  56                
    LD (4523h),DE                              ; @1CDD  ED 53 23 45       
    JP TX_DEQUEUE                              ; @1CE1  C3 13 1C          
loc_1CE4:
    LD HL,(459Ch)                              ; @1CE4  2A 9C 45          
    INC HL                                     ; @1CE7  23                
    LD (459Ch),HL                              ; @1CE8  22 9C 45          
    LD HL,(4594h)                              ; @1CEB  2A 94 45          
    INC HL                                     ; @1CEE  23                
    LD (4594h),HL                              ; @1CEF  22 94 45          
    LD HL,(4596h)                              ; @1CF2  2A 96 45          
    DEC HL                                     ; @1CF5  2B                
    LD (4596h),HL                              ; @1CF6  22 96 45          
    JP loc_1DFD                                ; @1CF9  C3 FD 1D          
loc_1CFC:
    LD HL,(459Ch)                              ; @1CFC  2A 9C 45          
    DEC HL                                     ; @1CFF  2B                
    LD (459Ch),HL                              ; @1D00  22 9C 45          
    LD HL,(4594h)                              ; @1D03  2A 94 45          
    DEC HL                                     ; @1D06  2B                
    LD (4594h),HL                              ; @1D07  22 94 45          
    LD HL,(4596h)                              ; @1D0A  2A 96 45          
    INC HL                                     ; @1D0D  23                
    LD (4596h),HL                              ; @1D0E  22 96 45          
    JP loc_1DFD                                ; @1D11  C3 FD 1D          
DOCUMENT_DIRECTORY_LOOKUP:
    CALL loc_0051                              ; @1D14  CD 51 00          
    LD C,A                                     ; @1D17  4F                
    LD A,(4593h)                               ; @1D18  3A 93 45          
    LD B,A                                     ; @1D1B  47                
    OR A                                       ; @1D1C  B7                
    JR Z,loc_1D2C                              ; @1D1D  28 0D             
    LD HL,4598h                                ; @1D1F  21 98 45          
    LD DE,0006h                                ; @1D22  11 06 00          
    LD A,C                                     ; @1D25  79                
loc_1D26:
    CP (HL)                                    ; @1D26  BE                
    JR Z,loc_1D2E                              ; @1D27  28 05             
    ADD HL,DE                                  ; @1D29  19                
    DJNZ loc_1D26                              ; @1D2A  10 FA             
loc_1D2C:
    XOR A                                      ; @1D2C  AF                
    RET                                        ; @1D2D  C9                
loc_1D2E:
    LD A,01h                                   ; @1D2E  3E 01             
    OR A                                       ; @1D30  B7                
    RET                                        ; @1D31  C9                
DIRECTORY_READ_ENTRY:
    LD A,(4593h)                               ; @1D32  3A 93 45          
    SUB B                                      ; @1D35  90                
    JP Z,loc_1DEA                              ; @1D36  CA EA 1D          
    LD (4573h),A                               ; @1D39  32 73 45          
    DI                                         ; @1D3C  F3                
    LD (4574h),HL                              ; @1D3D  22 74 45          
    INC HL                                     ; @1D40  23                
    INC HL                                     ; @1D41  23                
    LD E,(HL)                                  ; @1D42  5E                
    INC HL                                     ; @1D43  23                
    LD D,(HL)                                  ; @1D44  56                
    EX DE,HL                                   ; @1D45  EB                
    LD (4571h),HL                              ; @1D46  22 71 45          
    EX DE,HL                                   ; @1D49  EB                
    INC HL                                     ; @1D4A  23                
    LD E,(HL)                                  ; @1D4B  5E                
    INC HL                                     ; @1D4C  23                
    LD D,(HL)                                  ; @1D4D  56                
    EX DE,HL                                   ; @1D4E  EB                
    LD (456Fh),HL                              ; @1D4F  22 6F 45          
loc_1D52:
    LD HL,(456Fh)                              ; @1D52  2A 6F 45          
    LD A,H                                     ; @1D55  7C                
    OR L                                       ; @1D56  B5                
    JR Z,loc_1D94                              ; @1D57  28 3B             
    EX DE,HL                                   ; @1D59  EB                
    LD HL,0409h                                ; @1D5A  21 09 04          
    RST 38h                                    ; @1D5D  FF                
    JR NC,loc_1D62                             ; @1D5E  30 02             
    LD H,D                                     ; @1D60  62                
    LD L,E                                     ; @1D61  6B                
loc_1D62:
    PUSH HL                                    ; @1D62  E5                
    EX DE,HL                                   ; @1D63  EB                
    OR A                                       ; @1D64  B7                
    SBC HL,DE                                  ; @1D65  ED 52             
    LD (456Fh),HL                              ; @1D67  22 6F 45          
    LD B,D                                     ; @1D6A  42                
    LD C,E                                     ; @1D6B  4B                
    LD DE,405Ah                                ; @1D6C  11 5A 40          
    LD HL,(4571h)                              ; @1D6F  2A 71 45          
    LDIR                                       ; @1D72  ED B0             
    EX DE,HL                                   ; @1D74  EB                
    LD HL,(4665h)                              ; @1D75  2A 65 46          
    OR A                                       ; @1D78  B7                
    SBC HL,DE                                  ; @1D79  ED 52             
    LD B,H                                     ; @1D7B  44                
    LD C,L                                     ; @1D7C  4D                
    LD HL,(4571h)                              ; @1D7D  2A 71 45          
    EX DE,HL                                   ; @1D80  EB                
    LDIR                                       ; @1D81  ED B0             
    POP DE                                     ; @1D83  D1                
    LD HL,(4594h)                              ; @1D84  2A 94 45          
    OR A                                       ; @1D87  B7                
    SBC HL,DE                                  ; @1D88  ED 52             
    LD B,D                                     ; @1D8A  42                
    LD C,E                                     ; @1D8B  4B                
    EX DE,HL                                   ; @1D8C  EB                
    LD HL,405Ah                                ; @1D8D  21 5A 40          
    LDIR                                       ; @1D90  ED B0             
    JR loc_1D52                                ; @1D92  18 BE             
loc_1D94:
    CALL loc_0159                              ; @1D94  CD 59 01          
    LD HL,(4574h)                              ; @1D97  2A 74 45          
    LD B,03h                                   ; @1D9A  06 03             
loc_1D9C:
    LD D,(HL)                                  ; @1D9C  56                
    INC HL                                     ; @1D9D  23                
    LD E,(HL)                                  ; @1D9E  5E                
    INC HL                                     ; @1D9F  23                
    PUSH DE                                    ; @1DA0  D5                
    DJNZ loc_1D9C                              ; @1DA1  10 F9             
    DEC HL                                     ; @1DA3  2B                
    PUSH HL                                    ; @1DA4  E5                
    LD DE,FFFAh                                ; @1DA5  11 FA FF          
    ADD HL,DE                                  ; @1DA8  19                
    EX DE,HL                                   ; @1DA9  EB                
    POP HL                                     ; @1DAA  E1                
    LD A,(4573h)                               ; @1DAB  3A 73 45          
    LD C,A                                     ; @1DAE  4F                
loc_1DAF:
    PUSH BC                                    ; @1DAF  C5                
    LD BC,0006h                                ; @1DB0  01 06 00          
    EX DE,HL                                   ; @1DB3  EB                
    LDDR                                       ; @1DB4  ED B8             
    EX DE,HL                                   ; @1DB6  EB                
    POP BC                                     ; @1DB7  C1                
    DEC C                                      ; @1DB8  0D                
    JR NZ,loc_1DAF                             ; @1DB9  20 F4             
    LD B,03h                                   ; @1DBB  06 03             
loc_1DBD:
    POP DE                                     ; @1DBD  D1                
    LD (HL),E                                  ; @1DBE  73                
    DEC HL                                     ; @1DBF  2B                
    LD (HL),D                                  ; @1DC0  72                
    DEC HL                                     ; @1DC1  2B                
    DJNZ loc_1DBD                              ; @1DC2  10 F9             
    LD HL,(4574h)                              ; @1DC4  2A 74 45          
    LD A,(4573h)                               ; @1DC7  3A 73 45          
    LD C,A                                     ; @1DCA  4F                
    INC C                                      ; @1DCB  0C                
    EX DE,HL                                   ; @1DCC  EB                
    LD HL,(4571h)                              ; @1DCD  2A 71 45          
loc_1DD0:
    PUSH DE                                    ; @1DD0  D5                
    PUSH HL                                    ; @1DD1  E5                
    EX DE,HL                                   ; @1DD2  EB                
    INC HL                                     ; @1DD3  23                
    INC HL                                     ; @1DD4  23                
    LD (HL),E                                  ; @1DD5  73                
    INC HL                                     ; @1DD6  23                
    LD (HL),D                                  ; @1DD7  72                
    INC HL                                     ; @1DD8  23                
    LD E,(HL)                                  ; @1DD9  5E                
    INC HL                                     ; @1DDA  23                
    LD D,(HL)                                  ; @1DDB  56                
    POP HL                                     ; @1DDC  E1                
    ADD HL,DE                                  ; @1DDD  19                
    EX DE,HL                                   ; @1DDE  EB                
    POP HL                                     ; @1DDF  E1                
    PUSH BC                                    ; @1DE0  C5                
    LD BC,FFFAh                                ; @1DE1  01 FA FF          
    ADD HL,BC                                  ; @1DE4  09                
    POP BC                                     ; @1DE5  C1                
    EX DE,HL                                   ; @1DE6  EB                
    DEC C                                      ; @1DE7  0D                
    JR NZ,loc_1DD0                             ; @1DE8  20 E6             
loc_1DEA:
    XOR A                                      ; @1DEA  AF                
    INC A                                      ; @1DEB  3C                
loc_1DEC:
    PUSH AF                                    ; @1DEC  F5                
    XOR A                                      ; @1DED  AF                
    LD C,A                                     ; @1DEE  4F                
    LD (4514h),A                               ; @1DEF  32 14 45          
    LD DE,(4665h)                              ; @1DF2  ED 5B 65 46       
    LD HL,(4594h)                              ; @1DF6  2A 94 45          
    CALL loc_0306                              ; @1DF9  CD 06 03          
    POP AF                                     ; @1DFC  F1                
loc_1DFD:
    PUSH AF                                    ; @1DFD  F5                
    PUSH BC                                    ; @1DFE  C5                
    CALL loc_04AD                              ; @1DFF  CD AD 04          
    POP BC                                     ; @1E02  C1                
    POP AF                                     ; @1E03  F1                
    RET                                        ; @1E04  C9                
loc_1E05:
    CALL loc_0051                              ; @1E05  CD 51 00          
    LD C,A                                     ; @1E08  4F                
    LD HL,0000h                                ; @1E09  21 00 00          
    LD (456Fh),HL                              ; @1E0C  22 6F 45          
    LD HL,4593h                                ; @1E0F  21 93 45          
    LD B,(HL)                                  ; @1E12  46                
    LD HL,4598h                                ; @1E13  21 98 45          
    LD DE,0006h                                ; @1E16  11 06 00          
    LD A,B                                     ; @1E19  78                
    OR A                                       ; @1E1A  B7                
    JR Z,loc_1E25                              ; @1E1B  28 08             
    LD A,C                                     ; @1E1D  79                
loc_1E1E:
    CP (HL)                                    ; @1E1E  BE                
    JP Z,DIRECTORY_READ_ENTRY                  ; @1E1F  CA 32 1D          
    ADD HL,DE                                  ; @1E22  19                
    DJNZ loc_1E1E                              ; @1E23  10 F9             
loc_1E25:
    LD HL,4593h                                ; @1E25  21 93 45          
    LD A,(HL)                                  ; @1E28  7E                
    CP 14h                                     ; @1E29  FE 14             
    JR NC,loc_1E55                             ; @1E2B  30 28             
    INC (HL)                                   ; @1E2D  34                
    LD HL,0008h                                ; @1E2E  21 08 00          
    RST 28h                                    ; @1E31  EF                
    PUSH BC                                    ; @1E32  C5                
    LD BC,0072h                                ; @1E33  01 72 00          
    LD DE,460Fh                                ; @1E36  11 0F 46          
    LD HL,4609h                                ; @1E39  21 09 46          
    LDDR                                       ; @1E3C  ED B8             
    POP BC                                     ; @1E3E  C1                
    LD A,C                                     ; @1E3F  79                
    LD (4598h),A                               ; @1E40  32 98 45          
    LD HL,(456Fh)                              ; @1E43  2A 6F 45          
    LD (459Ch),HL                              ; @1E46  22 9C 45          
    XOR A                                      ; @1E49  AF                
    LD (4599h),A                               ; @1E4A  32 99 45          
    LD HL,(4594h)                              ; @1E4D  2A 94 45          
    LD (459Ah),HL                              ; @1E50  22 9A 45          
    JR loc_1DFD                                ; @1E53  18 A8             
loc_1E55:
    LD A,80h                                   ; @1E55  3E 80             
    OR A                                       ; @1E57  B7                
    JR loc_1DFD                                ; @1E58  18 A3             
loc_1E5A:
    LD HL,4593h                                ; @1E5A  21 93 45          
    LD A,(HL)                                  ; @1E5D  7E                
    OR A                                       ; @1E5E  B7                
    RET Z                                      ; @1E5F  C8                
    DEC (HL)                                   ; @1E60  35                
    LD HL,(4596h)                              ; @1E61  2A 96 45          
    EX DE,HL                                   ; @1E64  EB                
    LD HL,(459Ch)                              ; @1E65  2A 9C 45          
    ADD HL,DE                                  ; @1E68  19                
    LD (4596h),HL                              ; @1E69  22 96 45          
    LD HL,(459Ah)                              ; @1E6C  2A 9A 45          
    LD (4594h),HL                              ; @1E6F  22 94 45          
    LD HL,459Eh                                ; @1E72  21 9E 45          
    LD DE,4598h                                ; @1E75  11 98 45          
    LD BC,0072h                                ; @1E78  01 72 00          
    LDIR                                       ; @1E7B  ED B0             
    JP loc_1DEC                                ; @1E7D  C3 EC 1D          
DOCUMENT_POOL_INIT:
    ; Initialize document pool at 4800h and compute usable RAM size
    LD HL,0000h                                ; @1E80  21 00 00          
    LD (4592h),HL                              ; @1E83  22 92 45          
    LD HL,4800h                                ; @1E86  21 00 48          
    LD (4594h),HL                              ; @1E89  22 94 45          
    EX DE,HL                                   ; @1E8C  EB                
    LD HL,(4665h)                              ; @1E8D  2A 65 46          
    OR A                                       ; @1E90  B7                
    SBC HL,DE                                  ; @1E91  ED 52             
    LD (4596h),HL                              ; @1E93  22 96 45          
    CALL loc_1DEC                              ; @1E96  CD EC 1D          
    JR loc_1EBC                                ; @1E99  18 21             
loc_1E9B:
    CALL loc_181C                              ; @1E9B  CD 1C 18          
    LD HL,464Dh                                ; @1E9E  21 4D 46          
    CALL loc_2DB4                              ; @1EA1  CD B4 2D          
    CALL RTC_RESET_AND_INITIALIZE                              ; @1EA4  CD 6C 0B          
    LD HL,4611h                                ; @1EA7  21 11 46          
    LD BC,3CA0h                                ; @1EAA  01 A0 3C          
loc_1EAD:
    LD (HL),C                                  ; @1EAD  71                
    INC HL                                     ; @1EAE  23                
    DJNZ loc_1EAD                              ; @1EAF  10 FC             
    LD HL,4611h                                ; @1EB1  21 11 46          
    LD (HL),B                                  ; @1EB4  70                
    LD HL,462Fh                                ; @1EB5  21 2F 46          
    LD (HL),B                                  ; @1EB8  70                
    CALL loc_04BA                              ; @1EB9  CD BA 04          
loc_1EBC:
    LD HL,11C2h                                ; @1EBC  21 C2 11          
    JP loc_0045                                ; @1EBF  C3 45 00          
loc_1EC2:
    LD HL,130Bh                                ; @1EC2  21 0B 13          
    RST 30h                                    ; @1EC5  F7                
loc_1EC6:
    CALL loc_1B01                              ; @1EC6  CD 01 1B          
    RET Z                                      ; @1EC9  C8                
    JR C,loc_1EC6                              ; @1ECA  38 FA             
    PUSH AF                                    ; @1ECC  F5                
    CALL DOCUMENT_DIRECTORY_LOOKUP             ; @1ECD  CD 14 1D          
    JR NZ,loc_1EF5                             ; @1ED0  20 23             
    POP AF                                     ; @1ED2  F1                
    CALL loc_1E05                              ; @1ED3  CD 05 1E          
    JP M,loc_1EFF                              ; @1ED6  FA FF 1E          
    LD HL,(4669h)                              ; @1ED9  2A 69 46          
    LD (459Ah),HL                              ; @1EDC  22 9A 45          
    LD DE,(45A0h)                              ; @1EDF  ED 5B A0 45       
    OR A                                       ; @1EE3  B7                
    SBC HL,DE                                  ; @1EE4  ED 52             
    LD DE,(45A2h)                              ; @1EE6  ED 5B A2 45       
    LD (45A2h),HL                              ; @1EEA  22 A2 45          
    EX DE,HL                                   ; @1EED  EB                
    OR A                                       ; @1EEE  B7                
    SBC HL,DE                                  ; @1EEF  ED 52             
    LD (459Ch),HL                              ; @1EF1  22 9C 45          
    RET                                        ; @1EF4  C9                
loc_1EF5:
    POP AF                                     ; @1EF5  F1                
    LD HL,1311h                                ; @1EF6  21 11 13          
    RST 30h                                    ; @1EF9  F7                
    CALL loc_0A64                              ; @1EFA  CD 64 0A          
    JR loc_1EC2                                ; @1EFD  18 C3             
loc_1EFF:
    LD HL,1302h                                ; @1EFF  21 02 13          
    RST 30h                                    ; @1F02  F7                
    CALL loc_016C                              ; @1F03  CD 6C 01          
    JP loc_0A64                                ; @1F06  C3 64 0A          
loc_1F09:
    ; Dispatched for keycode/mode: 8A/00
    LD A,03h                                   ; @1F09  3E 03             
    CALL loc_07E6                              ; @1F0B  CD E6 07          
loc_1F0E:
    LD A,(4593h)                               ; @1F0E  3A 93 45          
    OR A                                       ; @1F11  B7                
    JR Z,loc_1F19                              ; @1F12  28 05             
    CALL loc_1F6C                              ; @1F14  CD 6C 1F          
    LD A,01h                                   ; @1F17  3E 01             
loc_1F19:
    LD (456Eh),A                               ; @1F19  32 6E 45          
    CALL loc_1F83                              ; @1F1C  CD 83 1F          
    CALL loc_09EA                              ; @1F1F  CD EA 09          
loc_1F22:
    CALL loc_0491                              ; @1F22  CD 91 04          
    JR Z,loc_1F22                              ; @1F25  28 FB             
    CALL OS_COMMAND_LOOKUP                     ; @1F27  CD 38 02          
    JR NC,loc_1F22                             ; @1F2A  30 F6             
    LD BC,1F1Ch                                ; @1F2C  01 1C 1F          
    PUSH BC                                    ; @1F2F  C5                
    LD A,(456Eh)                               ; @1F30  3A 6E 45          
    JP (HL)                                    ; @1F33  E9                
loc_1F34:
    ; Dispatched for keycode/mode: 85/03
    LD HL,4593h                                ; @1F34  21 93 45          
    CP (HL)                                    ; @1F37  BE                
    RET NC                                     ; @1F38  D0                
    INC A                                      ; @1F39  3C                
loc_1F3A:
    LD (456Eh),A                               ; @1F3A  32 6E 45          
    RET                                        ; @1F3D  C9                
loc_1F3E:
    ; Dispatched for keycode/mode: 86/03
    OR A                                       ; @1F3E  B7                
    RET Z                                      ; @1F3F  C8                
    DEC A                                      ; @1F40  3D                
    JR NZ,loc_1F3A                             ; @1F41  20 F7             
    INC A                                      ; @1F43  3C                
    JR loc_1F3A                                ; @1F44  18 F4             
loc_1F46:
    ; Dispatched for keycode/mode: 8F/03
    OR A                                       ; @1F46  B7                
    JR Z,loc_1F5C                              ; @1F47  28 13             
    LD B,A                                     ; @1F49  47                
    CALL loc_1A06                              ; @1F4A  CD 06 1A          
    CALL loc_0470                              ; @1F4D  CD 70 04          
    JR NZ,loc_1F5C                             ; @1F50  20 0A             
    LD A,B                                     ; @1F52  78                
    CALL DIRECTORY_INDEX_TO_ADDRESS            ; @1F53  CD 5F 1F          
    CALL loc_1E05                              ; @1F56  CD 05 1E          
    CALL loc_1E5A                              ; @1F59  CD 5A 1E          
loc_1F5C:
    POP BC                                     ; @1F5C  C1                
    JR loc_1F0E                                ; @1F5D  18 AF             
DIRECTORY_INDEX_TO_ADDRESS:
    ADD A,A                                    ; @1F5F  87                
    LD B,A                                     ; @1F60  47                
    ADD A,A                                    ; @1F61  87                
    ADD A,B                                    ; @1F62  80                
    LD E,A                                     ; @1F63  5F                
    LD D,00h                                   ; @1F64  16 00             
    LD HL,4592h                                ; @1F66  21 92 45          
    ADD HL,DE                                  ; @1F69  19                
    LD A,(HL)                                  ; @1F6A  7E                
    RET                                        ; @1F6B  C9                
loc_1F6C:
    LD C,A                                     ; @1F6C  4F                
    LD B,01h                                   ; @1F6D  06 01             
    CALL AUX_OUTPUT_RULE                       ; @1F6F  CD 5D 0B          
loc_1F72:
    LD A,B                                     ; @1F72  78                
    LD (456Eh),A                               ; @1F73  32 6E 45          
    PUSH BC                                    ; @1F76  C5                
    CALL loc_1F83                              ; @1F77  CD 83 1F          
    POP BC                                     ; @1F7A  C1                
    CALL loc_0B57                              ; @1F7B  CD 57 0B          
    JR NZ,loc_1F72                             ; @1F7E  20 F2             
    JP AUX_OUTPUT_RULE                         ; @1F80  C3 5D 0B          
loc_1F83:
    CALL loc_0A47                              ; @1F83  CD 47 0A          
    LD DE,4013h                                ; @1F86  11 13 40          
    LD HL,1336h                                ; @1F89  21 36 13          
    CALL loc_08CB                              ; @1F8C  CD CB 08          
    XOR A                                      ; @1F8F  AF                
    LD (DE),A                                  ; @1F90  12                
    LD A,(456Eh)                               ; @1F91  3A 6E 45          
    OR A                                       ; @1F94  B7                
    JP NZ,loc_1FA3                             ; @1F95  C2 A3 1F          
    LD DE,401Ch                                ; @1F98  11 1C 40          
    LD HL,134Fh                                ; @1F9B  21 4F 13          
    CALL loc_08CB                              ; @1F9E  CD CB 08          
    JR loc_1FBA                                ; @1FA1  18 17             
loc_1FA3:
    CALL DIRECTORY_INDEX_TO_ADDRESS            ; @1FA3  CD 5F 1F          
    LD (4022h),A                               ; @1FA6  32 22 40          
    INC HL                                     ; @1FA9  23                
    INC HL                                     ; @1FAA  23                
    INC HL                                     ; @1FAB  23                
    INC HL                                     ; @1FAC  23                
    LD E,(HL)                                  ; @1FAD  5E                
    INC HL                                     ; @1FAE  23                
    LD D,(HL)                                  ; @1FAF  56                
    EX DE,HL                                   ; @1FB0  EB                
    CALL loc_030D                              ; @1FB1  CD 0D 03          
    LD DE,4029h                                ; @1FB4  11 29 40          
    CALL loc_1FD1                              ; @1FB7  CD D1 1F          
loc_1FBA:
    LD HL,(4596h)                              ; @1FBA  2A 96 45          
    CALL loc_030D                              ; @1FBD  CD 0D 03          
    LD DE,4034h                                ; @1FC0  11 34 40          
    CALL loc_1FD1                              ; @1FC3  CD D1 1F          
    LD A,(456Eh)                               ; @1FC6  3A 6E 45          
    LD B,A                                     ; @1FC9  47                
    LD A,(4593h)                               ; @1FCA  3A 93 45          
    LD C,A                                     ; @1FCD  4F                
    JP loc_0A14                                ; @1FCE  C3 14 0A          
loc_1FD1:
    LD HL,457Eh                                ; @1FD1  21 7E 45          
    LD B,03h                                   ; @1FD4  06 03             
    JR loc_1FDC                                ; @1FD6  18 04             
loc_1FD8:
    INC HL                                     ; @1FD8  23                
    CALL loc_005A                              ; @1FD9  CD 5A 00          
loc_1FDC:
    LD A,(HL)                                  ; @1FDC  7E                
    CALL loc_072D                              ; @1FDD  CD 2D 07          
    LD (DE),A                                  ; @1FE0  12                
    INC DE                                     ; @1FE1  13                
    DJNZ loc_1FD8                              ; @1FE2  10 F4             
    RET                                        ; @1FE4  C9                
loc_1FE5:
    LD A,06h                                   ; @1FE5  3E 06             
    CALL loc_07E6                              ; @1FE7  CD E6 07          
    CALL loc_2072                              ; @1FEA  CD 72 20          
loc_1FED:
    CALL loc_0DAE                              ; @1FED  CD AE 0D          
    LD HL,162Bh                                ; @1FF0  21 2B 16          
    CALL loc_003F                              ; @1FF3  CD 3F 00          
    CALL loc_0A47                              ; @1FF6  CD 47 0A          
loc_1FF9:
    CALL loc_0491                              ; @1FF9  CD 91 04          
    JR Z,loc_1FF9                              ; @1FFC  28 FB             
    CP 8Eh                                     ; @1FFE  FE 8E             


; white_u4.bin SHA256=3fa98fd04a6a2cabcae2c99b295f7d42374a4a1602d259771b2e5fbc7576d53a
ORG 2000h
; ---- white_u4.bin start 2000h ----

    JP Z,loc_0CDC                              ; @2000  CA DC 0C          
    LD HL,10E9h                                ; @2003  21 E9 10          
    CALL loc_027B                              ; @2006  CD 7B 02          
    JR NC,loc_2037                             ; @2009  30 2C             
    LD C,(HL)                                  ; @200B  4E                
    INC HL                                     ; @200C  23                
    LD (4503h),HL                              ; @200D  22 03 45          
    CALL loc_2055                              ; @2010  CD 55 20          
loc_2013:
    LD B,01h                                   ; @2013  06 01             
loc_2015:
    PUSH BC                                    ; @2015  C5                
    RST 18h                                    ; @2016  DF                
    LD HL,(4503h)                              ; @2017  2A 03 45          
    LD DE,4013h                                ; @201A  11 13 40          
    DEC B                                      ; @201D  05                
    CALL loc_08AC                              ; @201E  CD AC 08          
    CALL loc_09D7                              ; @2021  CD D7 09          
    POP BC                                     ; @2024  C1                
    PUSH BC                                    ; @2025  C5                
    CALL loc_0A14                              ; @2026  CD 14 0A          
loc_2029:
    CALL loc_0491                              ; @2029  CD 91 04          
    JR Z,loc_2029                              ; @202C  28 FB             
    CALL OS_COMMAND_LOOKUP                     ; @202E  CD 38 02          
    JR NC,loc_2029                             ; @2031  30 F6             
    JP (HL)                                    ; @2033  E9                
loc_2034:
    ; Dispatched for keycode/mode: C6/06
    POP BC                                     ; @2034  C1                
    JR loc_2013                                ; @2035  18 DC             
loc_2037:
    CALL loc_0DAE                              ; @2037  CD AE 0D          
    LD HL,1638h                                ; @203A  21 38 16          
    CALL loc_003F                              ; @203D  CD 3F 00          
    CALL loc_0A64                              ; @2040  CD 64 0A          
    JR loc_1FED                                ; @2043  18 A8             
loc_2045:
    ; Dispatched for keycode/mode: 86/06
    POP BC                                     ; @2045  C1                
    DJNZ loc_2015                              ; @2046  10 CD             
loc_2048:
    INC B                                      ; @2048  04                
    JR loc_2015                                ; @2049  18 CA             
loc_204B:
    ; Dispatched for keycode/mode: 8E/06
    POP BC                                     ; @204B  C1                
    JR loc_1FED                                ; @204C  18 9F             
loc_204E:
    ; Dispatched for keycode/mode: 85/06
    POP BC                                     ; @204E  C1                
    LD A,B                                     ; @204F  78                
    CP C                                       ; @2050  B9                
    JR Z,loc_2015                              ; @2051  28 C2             
    JR loc_2048                                ; @2053  18 F3             
loc_2055:
    PUSH BC                                    ; @2055  C5                
    CALL AUX_OUTPUT_RULE                       ; @2056  CD 5D 0B          
    LD B,00h                                   ; @2059  06 00             
loc_205B:
    PUSH BC                                    ; @205B  C5                
    CALL loc_0DAF                              ; @205C  CD AF 0D          
    LD HL,(4503h)                              ; @205F  2A 03 45          
    LD DE,4013h                                ; @2062  11 13 40          
    CALL loc_08AC                              ; @2065  CD AC 08          
    POP BC                                     ; @2068  C1                
    CALL loc_0B57                              ; @2069  CD 57 0B          
    JR NZ,loc_205B                             ; @206C  20 ED             
    POP BC                                     ; @206E  C1                
    JP AUX_OUTPUT_RULE                         ; @206F  C3 5D 0B          
loc_2072:
    IN A,(43h)                                 ; @2072  DB 43             
    CPL                                        ; @2074  2F                
    AND 0Ch                                    ; @2075  E6 0C             
    RRCA                                       ; @2077  0F                
    RRCA                                       ; @2078  0F                
    OR A                                       ; @2079  B7                
    RET Z                                      ; @207A  C8                
    DEC A                                      ; @207B  3D                
    LD B,A                                     ; @207C  47                
    PUSH BC                                    ; @207D  C5                
    CALL loc_016C                              ; @207E  CD 6C 01          
    CALL loc_0DAE                              ; @2081  CD AE 0D          
    LD HL,11CAh                                ; @2084  21 CA 11          
    CALL loc_09F0                              ; @2087  CD F0 09          
    LD HL,11D0h                                ; @208A  21 D0 11          
    POP BC                                     ; @208D  C1                
    CALL loc_08AC                              ; @208E  CD AC 08          
    CALL loc_09D7                              ; @2091  CD D7 09          
    CALL loc_0494                              ; @2094  CD 94 04          
    POP HL                                     ; @2097  E1                
    JP loc_1FF9                                ; @2098  C3 F9 1F          
loc_209B:
    LD DE,(459Ah)                              ; @209B  ED 5B 9A 45       
    LD HL,(4669h)                              ; @209F  2A 69 46          
    OR A                                       ; @20A2  B7                
    SBC HL,DE                                  ; @20A3  ED 52             
    LD B,H                                     ; @20A5  44                
    LD C,L                                     ; @20A6  4D                
    JR loc_20B7                                ; @20A7  18 0E             
loc_20A9:
    ; Dispatched for keycode/mode: 88/04
    POP HL                                     ; @20A9  E1                
    POP HL                                     ; @20AA  E1                
    CALL loc_0828                              ; @20AB  CD 28 08          
    LD A,(4509h)                               ; @20AE  3A 09 45          
    OR A                                       ; @20B1  B7                
    JR Z,loc_20C2                              ; @20B2  28 0E             
loc_20B4:
    LD BC,0000h                                ; @20B4  01 00 00          
loc_20B7:
    LD DE,(459Ah)                              ; @20B7  ED 5B 9A 45       
    LD HL,(459Ch)                              ; @20BB  2A 9C 45          
    LD A,FFh                                   ; @20BE  3E FF             
    JR loc_20CF                                ; @20C0  18 0D             
loc_20C2:
    ; Dispatched for keycode/mode: 88/00
    LD BC,0000h                                ; @20C2  01 00 00          
loc_20C5:
    LD DE,4063h                                ; @20C5  11 63 40          
    LD HL,(405Dh)                              ; @20C8  2A 5D 40          
    LD A,H                                     ; @20CB  7C                
    LD H,L                                     ; @20CC  65                
    LD L,A                                     ; @20CD  6F                
    XOR A                                      ; @20CE  AF                
loc_20CF:
    LD (450Eh),HL                              ; @20CF  22 0E 45          
    LD (4509h),A                               ; @20D2  32 09 45          
    LD (450Ah),DE                              ; @20D5  ED 53 0A 45       
    XOR A                                      ; @20D9  AF                
    LD (4510h),A                               ; @20DA  32 10 45          
    LD (450Ch),BC                              ; @20DD  ED 43 0C 45       
    LD A,04h                                   ; @20E1  3E 04             
    CALL loc_07E6                              ; @20E3  CD E6 07          
loc_20E6:
    CALL loc_2125                              ; @20E6  CD 25 21          
    LD A,(4512h)                               ; @20E9  3A 12 45          
    OR A                                       ; @20EC  B7                
    JR Z,loc_20F6                              ; @20ED  28 07             
    LD A,(4012h)                               ; @20EF  3A 12 40          
    OR A                                       ; @20F2  B7                
    CALL Z,loc_0A64                            ; @20F3  CC 64 0A          
loc_20F6:
    CALL loc_0494                              ; @20F6  CD 94 04          
    CALL NZ,loc_2171                           ; @20F9  C4 71 21          
    LD A,(4511h)                               ; @20FC  3A 11 45          
    OR A                                       ; @20FF  B7                
    JR NZ,loc_20E6                             ; @2100  20 E4             
loc_2102:
    LD A,(4509h)                               ; @2102  3A 09 45          
    OR A                                       ; @2105  B7                
    JR Z,loc_2113                              ; @2106  28 0B             
    LD DE,(450Ch)                              ; @2108  ED 5B 0C 45       
    LD HL,(450Ah)                              ; @210C  2A 0A 45          
    ADD HL,DE                                  ; @210F  19                
    LD (4669h),HL                              ; @2110  22 69 46          
loc_2113:
    JP loc_0CDC                                ; @2113  C3 DC 0C          
loc_2116:
    ; Dispatched for keycode/mode: 86/00
    DI                                         ; @2116  F3                
    LD A,86h                                   ; @2117  3E 86             
    LD HL,44ADh                                ; @2119  21 AD 44          
    CALL QUEUE_HANDLER_A                       ; @211C  CD 88 02          
    EI                                         ; @211F  FB                
    LD BC,03FFh                                ; @2120  01 FF 03          
    JR loc_20C5                                ; @2123  18 A0             
loc_2125:
    XOR A                                      ; @2125  AF                
    LD (4512h),A                               ; @2126  32 12 45          
    INC A                                      ; @2129  3C                
    LD (4511h),A                               ; @212A  32 11 45          
loc_212D:
    CALL loc_219A                              ; @212D  CD 9A 21          
    CALL loc_21C5                              ; @2130  CD C5 21          
    OR A                                       ; @2133  B7                
    JR Z,loc_2185                              ; @2134  28 4F             
    CP 0Dh                                     ; @2136  FE 0D             
    JR Z,loc_2192                              ; @2138  28 58             
    PUSH AF                                    ; @213A  F5                
    LD A,(4512h)                               ; @213B  3A 12 45          
    OR A                                       ; @213E  B7                
    CALL Z,LCD_MAIN_INIT                       ; @213F  CC 67 08          
    POP AF                                     ; @2142  F1                
    CALL LCD_CHAR_OUTPUT                       ; @2143  CD 9E 06          
    LD A,(4512h)                               ; @2146  3A 12 45          
    INC A                                      ; @2149  3C                
    LD (4512h),A                               ; @214A  32 12 45          
    CP 27h                                     ; @214D  FE 27             
    LD B,A                                     ; @214F  47                
    JR C,loc_212D                              ; @2150  38 DB             
    LD A,(4012h)                               ; @2152  3A 12 40          
    OR A                                       ; @2155  B7                
    JR NZ,loc_2161                             ; @2156  20 09             
    LD A,B                                     ; @2158  78                
    CP 27h                                     ; @2159  FE 27             
    CALL Z,loc_0A64                            ; @215B  CC 64 0A          
    CALL loc_26EC                              ; @215E  CD EC 26          
loc_2161:
    CALL loc_219A                              ; @2161  CD 9A 21          
    CALL loc_0491                              ; @2164  CD 91 04          
    JR NZ,loc_2171                             ; @2167  20 08             
    LD A,(4510h)                               ; @2169  3A 10 45          
    OR A                                       ; @216C  B7                
    JR Z,loc_212D                              ; @216D  28 BE             
    JR loc_2161                                ; @216F  18 F0             
loc_2171:
    PUSH AF                                    ; @2171  F5                
    LD A,03h                                   ; @2172  3E 03             
    LD (4513h),A                               ; @2174  32 13 45          
    LD (4510h),A                               ; @2177  32 10 45          
    POP AF                                     ; @217A  F1                
    CALL OS_COMMAND_LOOKUP                     ; @217B  CD 38 02          
    LD BC,2125h                                ; @217E  01 25 21          
    PUSH BC                                    ; @2181  C5                
    JR NC,loc_21BD                             ; @2182  30 39             
    JP (HL)                                    ; @2184  E9                
loc_2185:
    XOR A                                      ; @2185  AF                
    LD (4511h),A                               ; @2186  32 11 45          
    CPL                                        ; @2189  2F                
    LD (4510h),A                               ; @218A  32 10 45          
    LD A,0Dh                                   ; @218D  3E 0D             
    CALL AUX_QUEUE_OUTPUT                      ; @218F  CD 0C 0B          
loc_2192:
    LD A,(4510h)                               ; @2192  3A 10 45          
    OR A                                       ; @2195  B7                
    RET Z                                      ; @2196  C8                
    JP loc_2161                                ; @2197  C3 61 21          
loc_219A:
    CALL RTC_READ_TIME_BLOCK                              ; @219A  CD F5 0B          
    LD A,(465Fh)                               ; @219D  3A 5F 46          
    LD (44F7h),A                               ; @21A0  32 F7 44          
    JP STATUS_DIRECTION_INDICATOR              ; @21A3  C3 11 0F          
loc_21A6:
    ; Dispatched for keycode/mode: 86/04
    CALL loc_2214                              ; @21A6  CD 14 22          
    OR A                                       ; @21A9  B7                
    RET Z                                      ; @21AA  C8                
    CP 0Dh                                     ; @21AB  FE 0D             
    JR NZ,loc_21A6                             ; @21AD  20 F7             
    LD HL,4513h                                ; @21AF  21 13 45          
    DEC (HL)                                   ; @21B2  35                
    JR NZ,loc_21A6                             ; @21B3  20 F1             
    JR loc_21C5                                ; @21B5  18 0E             
loc_21B7:
    ; Dispatched for keycode/mode: 8C/04
    XOR A                                      ; @21B7  AF                
    LD (4510h),A                               ; @21B8  32 10 45          
    POP HL                                     ; @21BB  E1                
    RET                                        ; @21BC  C9                
loc_21BD:
    LD (4537h),A                               ; @21BD  32 37 45          
loc_21C0:
    ; Dispatched for keycode/mode: 8E/04
    POP HL                                     ; @21C0  E1                
    POP HL                                     ; @21C1  E1                
    JP loc_2102                                ; @21C2  C3 02 21          
loc_21C5:
    LD HL,(450Eh)                              ; @21C5  2A 0E 45          
    EX DE,HL                                   ; @21C8  EB                
    LD HL,(450Ch)                              ; @21C9  2A 0C 45          
    LD A,(4509h)                               ; @21CC  3A 09 45          
    OR A                                       ; @21CF  B7                
    JR Z,loc_21EF                              ; @21D0  28 1D             
    RST 38h                                    ; @21D2  FF                
    JR Z,loc_21FF                              ; @21D3  28 2A             
    INC HL                                     ; @21D5  23                
    LD (450Ch),HL                              ; @21D6  22 0C 45          
    DEC HL                                     ; @21D9  2B                
    EX DE,HL                                   ; @21DA  EB                
loc_21DB:
    LD HL,(450Ah)                              ; @21DB  2A 0A 45          
    ADD HL,DE                                  ; @21DE  19                
AUX_OUTPUT_MEMORY:
    LD A,(HL)                                  ; @21DF  7E                
    CALL AUX_QUEUE_OUTPUT                      ; @21E0  CD 0C 0B          
    CP 0Dh                                     ; @21E3  FE 0D             
    RET Z                                      ; @21E5  C8                
    CP 20h                                     ; @21E6  FE 20             
    JR C,loc_21C5                              ; @21E8  38 DB             
    OR A                                       ; @21EA  B7                
    JP M,loc_21C5                              ; @21EB  FA C5 21          
    RET                                        ; @21EE  C9                
loc_21EF:
    LD A,H                                     ; @21EF  7C                
    CP 04h                                     ; @21F0  FE 04             
    JR NC,loc_21FF                             ; @21F2  30 0B             
    INC HL                                     ; @21F4  23                
    LD (450Ch),HL                              ; @21F5  22 0C 45          
    DEC HL                                     ; @21F8  2B                
    CALL loc_2201                              ; @21F9  CD 01 22          
    EX DE,HL                                   ; @21FC  EB                
    JR loc_21DB                                ; @21FD  18 DC             
loc_21FF:
    XOR A                                      ; @21FF  AF                
loc_2200:
    ; Dispatched for keycode/mode: 85/04
    RET                                        ; @2200  C9                
loc_2201:
    EX DE,HL                                   ; @2201  EB                
    LD HL,(4061h)                              ; @2202  2A 61 40          
    LD A,H                                     ; @2205  7C                
    LD H,L                                     ; @2206  65                
    LD L,A                                     ; @2207  6F                
    ADD HL,DE                                  ; @2208  19                
    EX DE,HL                                   ; @2209  EB                
    LD HL,(450Eh)                              ; @220A  2A 0E 45          
    EX DE,HL                                   ; @220D  EB                
    ADD HL,DE                                  ; @220E  19                
    RET C                                      ; @220F  D8                
    OR A                                       ; @2210  B7                
    SBC HL,DE                                  ; @2211  ED 52             
    RET                                        ; @2213  C9                
loc_2214:
    LD HL,(450Ch)                              ; @2214  2A 0C 45          
    LD A,H                                     ; @2217  7C                
    OR L                                       ; @2218  B5                
    JR Z,loc_21FF                              ; @2219  28 E4             
    DEC HL                                     ; @221B  2B                
    LD (450Ch),HL                              ; @221C  22 0C 45          
    LD A,(4509h)                               ; @221F  3A 09 45          
    OR A                                       ; @2222  B7                
    CALL Z,loc_2201                            ; @2223  CC 01 22          
    EX DE,HL                                   ; @2226  EB                
    LD HL,(450Ah)                              ; @2227  2A 0A 45          
    ADD HL,DE                                  ; @222A  19                
    LD A,(HL)                                  ; @222B  7E                
    CP 0Dh                                     ; @222C  FE 0D             
    RET Z                                      ; @222E  C8                
    CP 20h                                     ; @222F  FE 20             
    JR C,loc_2214                              ; @2231  38 E1             
    OR A                                       ; @2233  B7                
    JP M,loc_2214                              ; @2234  FA 14 22          
    RET                                        ; @2237  C9                
loc_2238:
    ; Dispatched for keycode/mode: 95/01
    CALL loc_240D                              ; @2238  CD 0D 24          
    POP HL                                     ; @223B  E1                
    JR loc_2246                                ; @223C  18 08             
loc_223E:
    ; Dispatched for keycode/mode: 95/00
    CALL loc_1A06                              ; @223E  CD 06 1A          
    LD A,01h                                   ; @2241  3E 01             
    CALL loc_07E6                              ; @2243  CD E6 07          
loc_2246:
    CALL loc_0A47                              ; @2246  CD 47 0A          
    LD HL,0004h                                ; @2249  21 04 00          
    RST 28h                                    ; @224C  EF                
    LD HL,0002h                                ; @224D  21 02 00          
    CALL STATUS_CLEAR_MASK                     ; @2250  CD 4A 0A          
    LD HL,15B1h                                ; @2253  21 B1 15          
    RST 30h                                    ; @2256  F7                
    CALL loc_1B01                              ; @2257  CD 01 1B          
    JP C,loc_28C9                              ; @225A  DA C9 28          
    JP Z,loc_2404                              ; @225D  CA 04 24          
    PUSH AF                                    ; @2260  F5                
    CALL loc_1E05                              ; @2261  CD 05 1E          
    OR A                                       ; @2264  B7                
    JR Z,loc_2283                              ; @2265  28 1C             
    JP M,loc_2288                              ; @2267  FA 88 22          
    LD HL,12EFh                                ; @226A  21 EF 12          
loc_226D:
    RST 30h                                    ; @226D  F7                
    LD A,0Fh                                   ; @226E  3E 0F             
    RST 08h                                    ; @2270  CF                
    POP AF                                     ; @2271  F1                
    CALL LCD_CHAR_OUTPUT                       ; @2272  CD 9E 06          
    LD HL,4514h                                ; @2275  21 14 45          
    XOR A                                      ; @2278  AF                
    CP (HL)                                    ; @2279  BE                
    LD (HL),A                                  ; @227A  77                
    CALL NZ,loc_1B1F                           ; @227B  C4 1F 1B          
    CALL loc_0A64                              ; @227E  CD 64 0A          
    JR loc_2295                                ; @2281  18 12             
loc_2283:
    LD HL,12F9h                                ; @2283  21 F9 12          
    JR loc_226D                                ; @2286  18 E5             
loc_2288:
    POP AF                                     ; @2288  F1                
    LD HL,1302h                                ; @2289  21 02 13          
    RST 30h                                    ; @228C  F7                
    CALL loc_016C                              ; @228D  CD 6C 01          
    CALL loc_0A64                              ; @2290  CD 64 0A          
    JR loc_2246                                ; @2293  18 B1             
loc_2295:
    LD HL,12DFh                                ; @2295  21 DF 12          
    CALL loc_0045                              ; @2298  CD 45 00          
    CALL loc_26E5                              ; @229B  CD E5 26          
    LD (4667h),HL                              ; @229E  22 67 46          
    CALL loc_247A                              ; @22A1  CD 7A 24          
    LD (458Fh),HL                              ; @22A4  22 8F 45          
    LD HL,22CBh                                ; @22A7  21 CB 22          
    PUSH HL                                    ; @22AA  E5                
    LD HL,(459Ch)                              ; @22AB  2A 9C 45          
    LD A,H                                     ; @22AE  7C                
    OR L                                       ; @22AF  B5                
    JP Z,loc_2423                              ; @22B0  CA 23 24          
    JP loc_2523                                ; @22B3  C3 23 25          
loc_22B6:
    LD HL,(4583h)                              ; @22B6  2A 83 45          
    LD (458Fh),HL                              ; @22B9  22 8F 45          
    LD A,(4004h)                               ; @22BC  3A 04 40          
    LD (4591h),A                               ; @22BF  32 91 45          
    LD A,H                                     ; @22C2  7C                
    OR L                                       ; @22C3  B5                
    RET NZ                                     ; @22C4  C0                
    LD A,01h                                   ; @22C5  3E 01             
    LD (4591h),A                               ; @22C7  32 91 45          
    RET                                        ; @22CA  C9                
    DB CDh,B6h,22h                              ; @22CB  CD B6 22
loc_22CE:
    CALL loc_233B                              ; @22CE  CD 3B 23          
    CALL loc_22FF                              ; @22D1  CD FF 22          
    LD HL,(459Ch)                              ; @22D4  2A 9C 45          
    LD A,H                                     ; @22D7  7C                
    OR L                                       ; @22D8  B5                
    JR Z,loc_22E4                              ; @22D9  28 09             
    LD HL,0000h                                ; @22DB  21 00 00          
    CALL loc_2689                              ; @22DE  CD 89 26          
    CALL loc_26B3                              ; @22E1  CD B3 26          
loc_22E4:
    PUSH HL                                    ; @22E4  E5                
    RST 28h                                    ; @22E5  EF                
    POP HL                                     ; @22E6  E1                
    LD A,L                                     ; @22E7  7D                
    CPL                                        ; @22E8  2F                
    AND F0h                                    ; @22E9  E6 F0             
    LD L,A                                     ; @22EB  6F                
    CALL STATUS_CLEAR_MASK                     ; @22EC  CD 4A 0A          
loc_22EF:
    CALL loc_0491                              ; @22EF  CD 91 04          
    JR Z,loc_22EF                              ; @22F2  28 FB             
    LD HL,22CBh                                ; @22F4  21 CB 22          
    PUSH HL                                    ; @22F7  E5                
    CALL OS_COMMAND_LOOKUP                     ; @22F8  CD 38 02          
    JP NC,loc_2392                             ; @22FB  D2 92 23          
    JP (HL)                                    ; @22FE  E9                
loc_22FF:
    LD HL,(459Ah)                              ; @22FF  2A 9A 45          
    LD A,1Bh                                   ; @2302  3E 1B             
    CP (HL)                                    ; @2304  BE                
    LD DE,FF00h                                ; @2305  11 00 FF          
    JR NZ,loc_2322                             ; @2308  20 18             
    INC HL                                     ; @230A  23                
loc_230B:
    LD A,(HL)                                  ; @230B  7E                
    CP 30h                                     ; @230C  FE 30             
    JR C,loc_2322                              ; @230E  38 12             
    CP 3Ah                                     ; @2310  FE 3A             
    JR NC,loc_2322                             ; @2312  30 0E             
    INC HL                                     ; @2314  23                
    AND 0Fh                                    ; @2315  E6 0F             
    LD B,A                                     ; @2317  47                
    LD A,E                                     ; @2318  7B                
    ADD A,A                                    ; @2319  87                
    LD E,A                                     ; @231A  5F                
    ADD A,A                                    ; @231B  87                
    ADD A,A                                    ; @231C  87                
    ADD A,E                                    ; @231D  83                
    ADD A,B                                    ; @231E  80                
    LD E,A                                     ; @231F  5F                
    JR loc_230B                                ; @2320  18 E9             
loc_2322:
    LD A,E                                     ; @2322  7B                
    OR A                                       ; @2323  B7                
    JR NZ,loc_2328                             ; @2324  20 02             
    LD E,48h                                   ; @2326  1E 48             
loc_2328:
    LD A,E                                     ; @2328  7B                
    CPL                                        ; @2329  2F                
    INC A                                      ; @232A  3C                
    LD E,A                                     ; @232B  5F                
    LD HL,(4583h)                              ; @232C  2A 83 45          
loc_232F:
    ADD HL,DE                                  ; @232F  19                
    RET NC                                     ; @2330  D0                
    LD A,H                                     ; @2331  7C                
    OR L                                       ; @2332  B5                
    JP NZ,loc_232F                             ; @2333  C2 2F 23          
    LD L,7Fh                                   ; @2336  2E 7F             
    JP loc_016F                                ; @2338  C3 6F 01          
loc_233B:
    LD HL,(4669h)                              ; @233B  2A 69 46          
    LD D,00h                                   ; @233E  16 00             
    LD A,(4004h)                               ; @2340  3A 04 40          
    LD E,A                                     ; @2343  5F                
    LD B,A                                     ; @2344  47                
    OR A                                       ; @2345  B7                
    SBC HL,DE                                  ; @2346  ED 52             
    INC HL                                     ; @2348  23                
    XOR A                                      ; @2349  AF                
    RST 08h                                    ; @234A  CF                
    LD A,B                                     ; @234B  78                
    DEC A                                      ; @234C  3D                
    JR Z,loc_235B                              ; @234D  28 0C             
    DEC B                                      ; @234F  05                
loc_2350:
    LD A,(HL)                                  ; @2350  7E                
    CALL LCD_TRANSLATE_OUTPUT                  ; @2351  CD 55 07          
    INC HL                                     ; @2354  23                
    DJNZ loc_2350                              ; @2355  10 F9             
    LD A,(4004h)                               ; @2357  3A 04 40          
    LD B,A                                     ; @235A  47                
loc_235B:
    LD A,20h                                   ; @235B  3E 20             
    CALL LCD_TRANSLATE_OUTPUT                  ; @235D  CD 55 07          
    LD A,28h                                   ; @2360  3E 28             
    SUB B                                      ; @2362  90                
    LD B,A                                     ; @2363  47                
    JR Z,loc_237F                              ; @2364  28 19             
loc_2366:
    LD DE,(4594h)                              ; @2366  ED 5B 94 45       
    RST 38h                                    ; @236A  FF                
    JR Z,loc_237F                              ; @236B  28 12             
    LD A,(4539h)                               ; @236D  3A 39 45          
    OR A                                       ; @2370  B7                
    JR NZ,loc_237F                             ; @2371  20 0C             
    LD A,(HL)                                  ; @2373  7E                
    CALL LCD_TRANSLATE_OUTPUT                  ; @2374  CD 55 07          
    LD A,0Dh                                   ; @2377  3E 0D             
    CP (HL)                                    ; @2379  BE                
    JR Z,loc_237F                              ; @237A  28 03             
    INC HL                                     ; @237C  23                
    DJNZ loc_2366                              ; @237D  10 E7             
loc_237F:
    LD A,B                                     ; @237F  78                
    OR A                                       ; @2380  B7                
    CALL NZ,loc_238A                           ; @2381  C4 8A 23          
    LD A,(4004h)                               ; @2384  3A 04 40          
    DEC A                                      ; @2387  3D                
    RST 08h                                    ; @2388  CF                
    RET                                        ; @2389  C9                
loc_238A:
    LD A,20h                                   ; @238A  3E 20             
    CALL LCD_TRANSLATE_OUTPUT                  ; @238C  CD 55 07          
    DJNZ loc_238A                              ; @238F  10 F9             
    RET                                        ; @2391  C9                
loc_2392:
    CP 80h                                     ; @2392  FE 80             
    RET NC                                     ; @2394  D0                
    LD B,A                                     ; @2395  47                
    CALL loc_250C                              ; @2396  CD 0C 25          
    LD A,(4539h)                               ; @2399  3A 39 45          
    OR A                                       ; @239C  B7                
    JR Z,loc_23AB                              ; @239D  28 0C             
    CALL LCD_MAIN_INIT                         ; @239F  CD 67 08          
    LD A,01h                                   ; @23A2  3E 01             
    LD (4004h),A                               ; @23A4  32 04 40          
    XOR A                                      ; @23A7  AF                
    LD (4539h),A                               ; @23A8  32 39 45          
loc_23AB:
    PUSH BC                                    ; @23AB  C5                
    CALL loc_250C                              ; @23AC  CD 0C 25          
    RST 20h                                    ; @23AF  E7                
    RST 38h                                    ; @23B0  FF                
    JR Z,loc_23C0                              ; @23B1  28 0D             
    EX DE,HL                                   ; @23B3  EB                
    OR A                                       ; @23B4  B7                
    SBC HL,DE                                  ; @23B5  ED 52             
    LD B,H                                     ; @23B7  44                
    LD C,L                                     ; @23B8  4D                
    RST 20h                                    ; @23B9  E7                
    LD H,D                                     ; @23BA  62                
    LD L,E                                     ; @23BB  6B                
    DEC HL                                     ; @23BC  2B                
    LDDR                                       ; @23BD  ED B8             
    INC HL                                     ; @23BF  23                
loc_23C0:
    POP AF                                     ; @23C0  F1                
    CP 09h                                     ; @23C1  FE 09             
    JR Z,loc_23F3                              ; @23C3  28 2E             
    CP 0Dh                                     ; @23C5  FE 0D             
    LD (HL),A                                  ; @23C7  77                
    JR NZ,loc_23D0                             ; @23C8  20 06             
    CALL loc_23D0                              ; @23CA  CD D0 23          
    JP loc_2466                                ; @23CD  C3 66 24          
loc_23D0:
    CALL loc_1CE4                              ; @23D0  CD E4 1C          
loc_23D3:
    LD HL,4004h                                ; @23D3  21 04 40          
    LD A,28h                                   ; @23D6  3E 28             
    CP (HL)                                    ; @23D8  BE                
    JR Z,loc_23DC                              ; @23D9  28 01             
    INC (HL)                                   ; @23DB  34                
loc_23DC:
    LD HL,(4583h)                              ; @23DC  2A 83 45          
    INC HL                                     ; @23DF  23                
    LD (4583h),HL                              ; @23E0  22 83 45          
    LD HL,4582h                                ; @23E3  21 82 45          
    DEC (HL)                                   ; @23E6  35                
    JR NZ,loc_23EB                             ; @23E7  20 02             
    LD (HL),05h                                ; @23E9  36 05             
loc_23EB:
    LD HL,(4669h)                              ; @23EB  2A 69 46          
    INC HL                                     ; @23EE  23                
    LD (4669h),HL                              ; @23EF  22 69 46          
    RET                                        ; @23F2  C9                
loc_23F3:
    LD (HL),20h                                ; @23F3  36 20             
    CALL loc_23D0                              ; @23F5  CD D0 23          
    LD A,(4582h)                               ; @23F8  3A 82 45          
    RET Z                                      ; @23FB  C8                
    LD B,09h                                   ; @23FC  06 09             
    JR loc_23AB                                ; @23FE  18 AB             
loc_2400:
    ; Dispatched for keycode/mode: 8E/01
    POP HL                                     ; @2400  E1                
    CALL loc_240D                              ; @2401  CD 0D 24          
loc_2404:
    LD HL,112Fh                                ; @2404  21 2F 11          
    CALL loc_0045                              ; @2407  CD 45 00          
    JP loc_0CDC                                ; @240A  C3 DC 0C          
loc_240D:
    XOR A                                      ; @240D  AF                
    LD (453Fh),A                               ; @240E  32 3F 45          
    LD HL,(459Ch)                              ; @2411  2A 9C 45          
    LD A,H                                     ; @2414  7C                
    OR L                                       ; @2415  B5                
    CALL Z,loc_1E5A                            ; @2416  CC 5A 1E          
    LD HL,00F4h                                ; @2419  21 F4 00          
    JP STATUS_CLEAR_MASK                       ; @241C  C3 4A 0A          
loc_241F:
    ; Dispatched for keycode/mode: 8F/01
    CALL loc_0470                              ; @241F  CD 70 04          
    RET NZ                                     ; @2422  C0                
loc_2423:
    LD A,(4598h)                               ; @2423  3A 98 45          
    PUSH AF                                    ; @2426  F5                
    CALL loc_1E5A                              ; @2427  CD 5A 1E          
    POP AF                                     ; @242A  F1                
    CALL loc_1E05                              ; @242B  CD 05 1E          
    CALL loc_26E5                              ; @242E  CD E5 26          
    LD (4667h),HL                              ; @2431  22 67 46          
loc_2434:
    ; Dispatched for keycode/mode: C6/01
    LD A,01h                                   ; @2434  3E 01             
    LD (4004h),A                               ; @2436  32 04 40          
    CALL loc_247A                              ; @2439  CD 7A 24          
    LD HL,(459Ch)                              ; @243C  2A 9C 45          
    LD A,H                                     ; @243F  7C                
    OR L                                       ; @2440  B5                
    RET Z                                      ; @2441  C8                
    LD HL,(459Ah)                              ; @2442  2A 9A 45          
    LD (4669h),HL                              ; @2445  22 69 46          
    RET                                        ; @2448  C9                
loc_2449:
    DEC HL                                     ; @2449  2B                
    LD (4669h),HL                              ; @244A  22 69 46          
    CALL loc_24FE                              ; @244D  CD FE 24          
    CALL loc_247A                              ; @2450  CD 7A 24          
    LD A,01h                                   ; @2453  3E 01             
    LD (4004h),A                               ; @2455  32 04 40          
loc_2458:
    CALL loc_249B                              ; @2458  CD 9B 24          
    JR NZ,loc_2458                             ; @245B  20 FB             
    RET                                        ; @245D  C9                
loc_245E:
    ; Dispatched for keycode/mode: 84/01
    CALL loc_2481                              ; @245E  CD 81 24          
    CALL loc_249B                              ; @2461  CD 9B 24          
    RET NC                                     ; @2464  D0                
    RET NZ                                     ; @2465  C0                
loc_2466:
    LD HL,0000h                                ; @2466  21 00 00          
    LD (4583h),HL                              ; @2469  22 83 45          
    LD A,05h                                   ; @246C  3E 05             
    LD (4582h),A                               ; @246E  32 82 45          
    LD (4539h),A                               ; @2471  32 39 45          
    LD (453Fh),A                               ; @2474  32 3F 45          
    LD A,00h                                   ; @2477  3E 00             
    RET                                        ; @2479  C9                
loc_247A:
    CALL loc_2466                              ; @247A  CD 66 24          
    LD (4539h),A                               ; @247D  32 39 45          
    RET                                        ; @2480  C9                
loc_2481:
    LD HL,(4583h)                              ; @2481  2A 83 45          
    LD A,H                                     ; @2484  7C                
    OR L                                       ; @2485  B5                
    RET NZ                                     ; @2486  C0                
    RST 20h                                    ; @2487  E7                
    RST 38h                                    ; @2488  FF                
    JR Z,loc_2499                              ; @2489  28 0E             
    LD HL,4539h                                ; @248B  21 39 45          
    LD A,(HL)                                  ; @248E  7E                
    OR A                                       ; @248F  B7                
    LD (HL),00h                                ; @2490  36 00             
    RET Z                                      ; @2492  C8                
    XOR A                                      ; @2493  AF                
    LD A,01h                                   ; @2494  3E 01             
    LD (4004h),A                               ; @2496  32 04 40          
loc_2499:
    POP HL                                     ; @2499  E1                
    RET                                        ; @249A  C9                
loc_249B:
    RST 20h                                    ; @249B  E7                
    RST 38h                                    ; @249C  FF                
    SCF                                        ; @249D  37                
    CCF                                        ; @249E  3F                
    RET Z                                      ; @249F  C8                
    LD A,(HL)                                  ; @24A0  7E                
    XOR 0Dh                                    ; @24A1  EE 0D             
    PUSH AF                                    ; @24A3  F5                
    CALL loc_23D3                              ; @24A4  CD D3 23          
    POP AF                                     ; @24A7  F1                
    SCF                                        ; @24A8  37                
    RET                                        ; @24A9  C9                
loc_24AA:
    ; Dispatched for keycode/mode: C4/01
    CALL loc_245E                              ; @24AA  CD 5E 24          
    JR NZ,loc_24AA                             ; @24AD  20 FB             
    RET                                        ; @24AF  C9                
EDITOR_UPDATE_POSITION:
    LD HL,(4669h)                              ; @24B0  2A 69 46          
    LD DE,(459Ah)                              ; @24B3  ED 5B 9A 45       
    RST 38h                                    ; @24B7  FF                
    SCF                                        ; @24B8  37                
    RET Z                                      ; @24B9  C8                
    DEC HL                                     ; @24BA  2B                
    LD A,(HL)                                  ; @24BB  7E                
    CP 0Dh                                     ; @24BC  FE 0D             
    JR Z,loc_2466                              ; @24BE  28 A6             
loc_24C0:
    LD (4669h),HL                              ; @24C0  22 69 46          
    LD HL,4004h                                ; @24C3  21 04 40          
    LD A,01h                                   ; @24C6  3E 01             
    CP (HL)                                    ; @24C8  BE                
    JR Z,loc_24CC                              ; @24C9  28 01             
    DEC (HL)                                   ; @24CB  35                
loc_24CC:
    LD HL,(4583h)                              ; @24CC  2A 83 45          
    DEC HL                                     ; @24CF  2B                
    LD (4583h),HL                              ; @24D0  22 83 45          
    LD A,(4582h)                               ; @24D3  3A 82 45          
    INC A                                      ; @24D6  3C                
    CP 06h                                     ; @24D7  FE 06             
    JR C,loc_24DD                              ; @24D9  38 02             
    LD A,01h                                   ; @24DB  3E 01             
loc_24DD:
    LD (4582h),A                               ; @24DD  32 82 45          
    OR A                                       ; @24E0  B7                
    RET                                        ; @24E1  C9                
loc_24E2:
    ; Dispatched for keycode/mode: 87/01
    CALL EDITOR_UPDATE_POSITION                ; @24E2  CD B0 24          
    RET NZ                                     ; @24E5  C0                
    RET C                                      ; @24E6  D8                
    LD HL,(4669h)                              ; @24E7  2A 69 46          
    CALL loc_2449                              ; @24EA  CD 49 24          
    LD HL,(4669h)                              ; @24ED  2A 69 46          
    DEC HL                                     ; @24F0  2B                
    JP loc_24C0                                ; @24F1  C3 C0 24          
loc_24F4:
    ; Dispatched for keycode/mode: C7/01
    LD HL,4539h                                ; @24F4  21 39 45          
    LD A,(HL)                                  ; @24F7  7E                
    OR A                                       ; @24F8  B7                
    LD (HL),00h                                ; @24F9  36 00             
    CALL NZ,loc_24E2                           ; @24FB  C4 E2 24          
loc_24FE:
    CALL EDITOR_UPDATE_POSITION                ; @24FE  CD B0 24          
    JR NZ,loc_24FE                             ; @2501  20 FB             
    RET C                                      ; @2503  D8                
    LD A,01h                                   ; @2504  3E 01             
    LD (4004h),A                               ; @2506  32 04 40          
    JP loc_247A                                ; @2509  C3 7A 24          
loc_250C:
    LD HL,(4596h)                              ; @250C  2A 96 45          
    LD A,H                                     ; @250F  7C                
    OR L                                       ; @2510  B5                
    RET NZ                                     ; @2511  C0                
    POP HL                                     ; @2512  E1                
    CALL loc_07E6                              ; @2513  CD E6 07          
    LD HL,12E2h                                ; @2516  21 E2 12          
    RST 30h                                    ; @2519  F7                
    CALL loc_016C                              ; @251A  CD 6C 01          
    CALL loc_0A64                              ; @251D  CD 64 0A          
    JP loc_0CDC                                ; @2520  C3 DC 0C          
loc_2523:
    ; Dispatched for keycode/mode: C5/01
    LD A,01h                                   ; @2523  3E 01             
    LD (4004h),A                               ; @2525  32 04 40          
    CALL loc_26E5                              ; @2528  CD E5 26          
    LD DE,(459Ah)                              ; @252B  ED 5B 9A 45       
    RST 38h                                    ; @252F  FF                
    RET Z                                      ; @2530  C8                
    DEC HL                                     ; @2531  2B                
    LD A,(HL)                                  ; @2532  7E                
    CP 0Dh                                     ; @2533  FE 0D             
    JR NZ,loc_253A                             ; @2535  20 03             
    LD (4669h),HL                              ; @2537  22 69 46          
loc_253A:
    LD HL,(4669h)                              ; @253A  2A 69 46          
    JP loc_2651                                ; @253D  C3 51 26          
loc_2540:
    ; Dispatched for keycode/mode: 91/01
    CALL loc_24E2                              ; @2540  CD E2 24          
    RET C                                      ; @2543  D8                
    CALL loc_22B6                              ; @2544  CD B6 22          
    LD HL,(4669h)                              ; @2547  2A 69 46          
    LD C,(HL)                                  ; @254A  4E                
    JR loc_2553                                ; @254B  18 06             
loc_254D:
    ; Dispatched for keycode/mode: 81/01
    LD C,0Dh                                   ; @254D  0E 0D             
    JR loc_2553                                ; @254F  18 02             
loc_2551:
    ; Dispatched for keycode/mode: 82/01
    LD C,20h                                   ; @2551  0E 20             
loc_2553:
    RST 20h                                    ; @2553  E7                
    RST 38h                                    ; @2554  FF                
    RET Z                                      ; @2555  C8                
    EX DE,HL                                   ; @2556  EB                
    OR A                                       ; @2557  B7                
    SBC HL,DE                                  ; @2558  ED 52             
    EX DE,HL                                   ; @255A  EB                
    PUSH HL                                    ; @255B  E5                
    LD HL,0000h                                ; @255C  21 00 00          
    EX (SP),HL                                 ; @255F  E3                
loc_2560:
    EX (SP),HL                                 ; @2560  E3                
    INC HL                                     ; @2561  23                
    EX (SP),HL                                 ; @2562  E3                
    LD A,(HL)                                  ; @2563  7E                
    INC HL                                     ; @2564  23                
    CP C                                       ; @2565  B9                
    JR Z,loc_2573                              ; @2566  28 0B             
    CP 0Dh                                     ; @2568  FE 0D             
    JR Z,loc_2573                              ; @256A  28 07             
    DEC DE                                     ; @256C  1B                
    LD A,D                                     ; @256D  7A                
    OR E                                       ; @256E  B3                
    JR NZ,loc_2560                             ; @256F  20 EF             
    JR loc_2587                                ; @2571  18 14             
loc_2573:
    LD DE,(4594h)                              ; @2573  ED 5B 94 45       
    EX DE,HL                                   ; @2577  EB                
    RST 38h                                    ; @2578  FF                
    JR Z,loc_2587                              ; @2579  28 0C             
    OR A                                       ; @257B  B7                
    SBC HL,DE                                  ; @257C  ED 52             
    LD B,H                                     ; @257E  44                
    LD C,L                                     ; @257F  4D                
    EX DE,HL                                   ; @2580  EB                
    LD DE,(4669h)                              ; @2581  ED 5B 69 46       
    LDIR                                       ; @2585  ED B0             
loc_2587:
    POP BC                                     ; @2587  C1                
loc_2588:
    CALL loc_1CFC                              ; @2588  CD FC 1C          
    DEC BC                                     ; @258B  0B                
    LD A,B                                     ; @258C  78                
    OR C                                       ; @258D  B1                
    JR NZ,loc_2588                             ; @258E  20 F8             
    RET                                        ; @2590  C9                
loc_2591:
    ; Dispatched for keycode/mode: 85/01
    RST 20h                                    ; @2591  E7                
    RST 38h                                    ; @2592  FF                
    JR Z,loc_25BE                              ; @2593  28 29             
    LD A,(4539h)                               ; @2595  3A 39 45          
    OR A                                       ; @2598  B7                
    JR NZ,loc_25CC                             ; @2599  20 31             
loc_259B:
    CALL loc_249B                              ; @259B  CD 9B 24          
    JR NZ,loc_259B                             ; @259E  20 FB             
    JR NC,loc_25BE                             ; @25A0  30 1C             
loc_25A2:
    LD A,01h                                   ; @25A2  3E 01             
    LD (4004h),A                               ; @25A4  32 04 40          
    CALL loc_247A                              ; @25A7  CD 7A 24          
loc_25AA:
    LD HL,(4583h)                              ; @25AA  2A 83 45          
    LD DE,(458Fh)                              ; @25AD  ED 5B 8F 45       
    RST 38h                                    ; @25B1  FF                
    JR Z,loc_25BE                              ; @25B2  28 0A             
    CALL loc_245E                              ; @25B4  CD 5E 24          
    JR NZ,loc_25AA                             ; @25B7  20 F1             
    LD A,01h                                   ; @25B9  3E 01             
    LD (453Bh),A                               ; @25BB  32 3B 45          
loc_25BE:
    POP HL                                     ; @25BE  E1                
    JP loc_22CE                                ; @25BF  C3 CE 22          
loc_25C2:
    LD A,01h                                   ; @25C2  3E 01             
    LD (4004h),A                               ; @25C4  32 04 40          
    CALL loc_247A                              ; @25C7  CD 7A 24          
    JR loc_25BE                                ; @25CA  18 F2             
loc_25CC:
    LD HL,453Bh                                ; @25CC  21 3B 45          
    LD A,(HL)                                  ; @25CF  7E                
    OR A                                       ; @25D0  B7                
    LD (HL),00h                                ; @25D1  36 00             
    JR NZ,loc_25A2                             ; @25D3  20 CD             
    JR loc_25C2                                ; @25D5  18 EB             
loc_25D7:
    ; Dispatched for keycode/mode: 86/01
    LD HL,4539h                                ; @25D7  21 39 45          
    LD A,(HL)                                  ; @25DA  7E                
    OR A                                       ; @25DB  B7                
    LD (HL),00h                                ; @25DC  36 00             
    JR Z,loc_260D                              ; @25DE  28 2D             
loc_25E0:
    LD HL,(4669h)                              ; @25E0  2A 69 46          
    LD DE,(459Ah)                              ; @25E3  ED 5B 9A 45       
    RST 38h                                    ; @25E7  FF                
    JR Z,loc_25BE                              ; @25E8  28 D4             
    DEC HL                                     ; @25EA  2B                
    LD A,(HL)                                  ; @25EB  7E                
    CP 0Dh                                     ; @25EC  FE 0D             
    JR NZ,loc_25F3                             ; @25EE  20 03             
    LD (4669h),HL                              ; @25F0  22 69 46          
loc_25F3:
    LD HL,(4669h)                              ; @25F3  2A 69 46          
    LD DE,(459Ah)                              ; @25F6  ED 5B 9A 45       
    RST 38h                                    ; @25FA  FF                
    JR Z,loc_25C2                              ; @25FB  28 C5             
    CALL loc_24FE                              ; @25FD  CD FE 24          
    JR C,loc_25C2                              ; @2600  38 C0             
    LD HL,453Bh                                ; @2602  21 3B 45          
    LD A,(HL)                                  ; @2605  7E                
    OR A                                       ; @2606  B7                
    LD (HL),00h                                ; @2607  36 00             
    JR NZ,loc_25E0                             ; @2609  20 D5             
    JR loc_25A2                                ; @260B  18 95             
loc_260D:
    CALL loc_24FE                              ; @260D  CD FE 24          
    JR C,loc_25C2                              ; @2610  38 B0             
    LD HL,(4669h)                              ; @2612  2A 69 46          
    DEC HL                                     ; @2615  2B                
    LD (4669h),HL                              ; @2616  22 69 46          
    CALL loc_24FE                              ; @2619  CD FE 24          
    JP loc_25A2                                ; @261C  C3 A2 25          
loc_261F:
    ; Dispatched for keycode/mode: 8A/01
    LD DE,(459Ah)                              ; @261F  ED 5B 9A 45       
    LD HL,(4669h)                              ; @2623  2A 69 46          
    OR A                                       ; @2626  B7                
    SBC HL,DE                                  ; @2627  ED 52             
    PUSH HL                                    ; @2629  E5                
    LD A,(4598h)                               ; @262A  3A 98 45          
    PUSH AF                                    ; @262D  F5                
    CALL loc_1F09                              ; @262E  CD 09 1F          
    POP AF                                     ; @2631  F1                
    CALL DOCUMENT_DIRECTORY_LOOKUP             ; @2632  CD 14 1D          
    POP HL                                     ; @2635  E1                
    POP DE                                     ; @2636  D1                
    JR Z,loc_2660                              ; @2637  28 27             
    PUSH DE                                    ; @2639  D5                
    LD A,C                                     ; @263A  79                
    PUSH HL                                    ; @263B  E5                
    CALL loc_1E05                              ; @263C  CD 05 1E          
    POP HL                                     ; @263F  E1                
    EX DE,HL                                   ; @2640  EB                
    LD HL,(459Ah)                              ; @2641  2A 9A 45          
    ADD HL,DE                                  ; @2644  19                
    LD (4669h),HL                              ; @2645  22 69 46          
    RET                                        ; @2648  C9                
loc_2649:
    ; Dispatched for keycode/mode: 8C/01
    CALL loc_209B                              ; @2649  CD 9B 20          
    JR loc_2651                                ; @264C  18 03             
loc_264E:
    ; Dispatched for keycode/mode: 88/01
    CALL loc_20B4                              ; @264E  CD B4 20          
loc_2651:
    CALL loc_24FE                              ; @2651  CD FE 24          
    CALL loc_247A                              ; @2654  CD 7A 24          
    JP loc_24AA                                ; @2657  C3 AA 24          
loc_265A:
    ; Dispatched for keycode/mode: 83/01
    CALL loc_1EC2                              ; @265A  CD C2 1E          
    JP loc_2434                                ; @265D  C3 34 24          
loc_2660:
    XOR A                                      ; @2660  AF                
    LD (453Fh),A                               ; @2661  32 3F 45          
    JP loc_2246                                ; @2664  C3 46 22          
loc_2667:
    ; Dispatched for keycode/mode: CB/01
    CALL loc_0DBF                              ; @2667  CD BF 0D          
    XOR A                                      ; @266A  AF                
    LD (DE),A                                  ; @266B  12                
loc_266C:
    JP loc_2674                                ; @266C  C3 74 26          
loc_266F:
    ; Dispatched for keycode/mode: D4/01
    CALL loc_2CC4                              ; @266F  CD C4 2C          
    JR loc_266C                                ; @2672  18 F8             
loc_2674:
    LD DE,4013h                                ; @2674  11 13 40          
    LD A,(DE)                                  ; @2677  1A                
    INC DE                                     ; @2678  13                
loc_2679:
    DI                                         ; @2679  F3                
    PUSH DE                                    ; @267A  D5                
    LD HL,44ADh                                ; @267B  21 AD 44          
    CALL QUEUE_HANDLER_A                       ; @267E  CD 88 02          
    EI                                         ; @2681  FB                
    POP DE                                     ; @2682  D1                
    LD A,(DE)                                  ; @2683  1A                
    OR A                                       ; @2684  B7                
    INC DE                                     ; @2685  13                
    JR NZ,loc_2679                             ; @2686  20 F1             
    RET                                        ; @2688  C9                
loc_2689:
    PUSH HL                                    ; @2689  E5                
    LD DE,(4669h)                              ; @268A  ED 5B 69 46       
    LD HL,(459Ah)                              ; @268E  2A 9A 45          
    RST 38h                                    ; @2691  FF                
    POP HL                                     ; @2692  E1                
    RET Z                                      ; @2693  C8                
    PUSH HL                                    ; @2694  E5                
    LD HL,(459Ah)                              ; @2695  2A 9A 45          
    DEC DE                                     ; @2698  1B                
    LD A,(DE)                                  ; @2699  1A                
    CP 0Dh                                     ; @269A  FE 0D             
    JR Z,loc_26AB                              ; @269C  28 0D             
loc_269E:
    RST 38h                                    ; @269E  FF                
    JR Z,loc_26AF                              ; @269F  28 0E             
    DEC DE                                     ; @26A1  1B                
    LD A,(DE)                                  ; @26A2  1A                
    CP 0Dh                                     ; @26A3  FE 0D             
    JR NZ,loc_269E                             ; @26A5  20 F7             
    POP HL                                     ; @26A7  E1                
    LD L,C0h                                   ; @26A8  2E C0             
    RET                                        ; @26AA  C9                
loc_26AB:
    POP HL                                     ; @26AB  E1                
    LD L,80h                                   ; @26AC  2E 80             
    RET                                        ; @26AE  C9                
loc_26AF:
    POP HL                                     ; @26AF  E1                
    LD L,40h                                   ; @26B0  2E 40             
    RET                                        ; @26B2  C9                
loc_26B3:
    PUSH HL                                    ; @26B3  E5                
    LD DE,(4669h)                              ; @26B4  ED 5B 69 46       
    LD HL,(4594h)                              ; @26B8  2A 94 45          
    RST 38h                                    ; @26BB  FF                
    POP HL                                     ; @26BC  E1                
    RET Z                                      ; @26BD  C8                
    PUSH HL                                    ; @26BE  E5                
    PUSH DE                                    ; @26BF  D5                
    LD HL,(4594h)                              ; @26C0  2A 94 45          
    POP DE                                     ; @26C3  D1                
    LD A,(DE)                                  ; @26C4  1A                
    CP 0Dh                                     ; @26C5  FE 0D             
    JR Z,loc_26DD                              ; @26C7  28 14             
    RST 38h                                    ; @26C9  FF                
    JR NZ,loc_26CE                             ; @26CA  20 02             
    POP HL                                     ; @26CC  E1                
    RET                                        ; @26CD  C9                
loc_26CE:
    RST 38h                                    ; @26CE  FF                
    JR Z,loc_26E1                              ; @26CF  28 10             
    INC DE                                     ; @26D1  13                
    LD A,(DE)                                  ; @26D2  1A                
    CP 0Dh                                     ; @26D3  FE 0D             
    JR NZ,loc_26CE                             ; @26D5  20 F7             
    POP HL                                     ; @26D7  E1                
    LD A,30h                                   ; @26D8  3E 30             
    OR L                                       ; @26DA  B5                
    LD L,A                                     ; @26DB  6F                
    RET                                        ; @26DC  C9                
loc_26DD:
    POP HL                                     ; @26DD  E1                
    SET 5,L                                    ; @26DE  CB ED             
    RET                                        ; @26E0  C9                
loc_26E1:
    POP HL                                     ; @26E1  E1                
    SET 4,L                                    ; @26E2  CB E5             
    RET                                        ; @26E4  C9                
loc_26E5:
    LD HL,(4594h)                              ; @26E5  2A 94 45          
    LD (4669h),HL                              ; @26E8  22 69 46          
    RET                                        ; @26EB  C9                
loc_26EC:
    LD HL,3000h                                ; @26EC  21 00 30          
loc_26EF:
    DEC L                                      ; @26EF  2D                
    JR NZ,loc_26EF                             ; @26F0  20 FD             
    DEC H                                      ; @26F2  25                
    JR NZ,loc_26EF                             ; @26F3  20 FA             
    RET                                        ; @26F5  C9                
loc_26F6:
    ; Dispatched for keycode/mode: 89/01
    LD A,0Ah                                   ; @26F6  3E 0A             
    LD (4507h),A                               ; @26F8  32 07 45          
loc_26FB:
    RST 18h                                    ; @26FB  DF                
    LD B,27h                                   ; @26FC  06 27             
loc_26FE:
    LD A,A0h                                   ; @26FE  3E A0             
    CALL LCD_TRANSLATE_OUTPUT                  ; @2700  CD 55 07          
    DJNZ loc_26FE                              ; @2703  10 F9             
    CALL loc_0878                              ; @2705  CD 78 08          
    LD A,(4538h)                               ; @2708  3A 38 45          
    OR A                                       ; @270B  B7                
    JR Z,loc_2731                              ; @270C  28 23             
    INC A                                      ; @270E  3C                
    JR Z,loc_271C                              ; @270F  28 0B             
    LD HL,1134h                                ; @2711  21 34 11          
    CALL loc_003F                              ; @2714  CD 3F 00          
    LD DE,4611h                                ; @2717  11 11 46          
    JR loc_2725                                ; @271A  18 09             
loc_271C:
    LD HL,113Bh                                ; @271C  21 3B 11          
    CALL loc_003F                              ; @271F  CD 3F 00          
    LD DE,462Fh                                ; @2722  11 2F 46          
loc_2725:
    LD HL,403Bh                                ; @2725  21 3B 40          
loc_2728:
    LD A,(DE)                                  ; @2728  1A                
    OR A                                       ; @2729  B7                
    LD (HL),A                                  ; @272A  77                
    JR Z,loc_2737                              ; @272B  28 0A             
    INC DE                                     ; @272D  13                
    INC HL                                     ; @272E  23                
    JR loc_2728                                ; @272F  18 F7             
loc_2731:
    LD HL,1142h                                ; @2731  21 42 11          
    CALL loc_003F                              ; @2734  CD 3F 00          
loc_2737:
    LD HL,4058h                                ; @2737  21 58 40          
    XOR A                                      ; @273A  AF                
    LD (HL),A                                  ; @273B  77                
    DEC HL                                     ; @273C  2B                
    LD (HL),A                                  ; @273D  77                
    LD HL,403Bh                                ; @273E  21 3B 40          
    CALL loc_09DF                              ; @2741  CD DF 09          
    LD DE,4057h                                ; @2744  11 57 40          
    LD C,A0h                                   ; @2747  0E A0             
    CALL loc_0306                              ; @2749  CD 06 03          
loc_274C:
    CALL loc_0491                              ; @274C  CD 91 04          
    JR Z,loc_274C                              ; @274F  28 FB             
    LD DE,274Ch                                ; @2751  11 4C 27          
    PUSH DE                                    ; @2754  D5                
    CALL OS_COMMAND_LOOKUP                     ; @2755  CD 38 02          
    JR C,loc_2763                              ; @2758  38 09             
    OR A                                       ; @275A  B7                
    RET Z                                      ; @275B  C8                
    RET M                                      ; @275C  F8                
    CP 0Dh                                     ; @275D  FE 0D             
    RET Z                                      ; @275F  C8                
    LD B,A                                     ; @2760  47                
    JR loc_2764                                ; @2761  18 01             
loc_2763:
    JP (HL)                                    ; @2763  E9                
loc_2764:
    LD A,(4002h)                               ; @2764  3A 02 40          
    SUB 09h                                    ; @2767  D6 09             
    LD DE,0000h                                ; @2769  11 00 00          
    LD E,A                                     ; @276C  5F                
    LD HL,403Bh                                ; @276D  21 3B 40          
    ADD HL,DE                                  ; @2770  19                
    PUSH HL                                    ; @2771  E5                
    EX DE,HL                                   ; @2772  EB                
    POP HL                                     ; @2773  E1                
loc_2774:
    LD A,(HL)                                  ; @2774  7E                
    CP A0h                                     ; @2775  FE A0             
    INC HL                                     ; @2777  23                
    JR NZ,loc_2774                             ; @2778  20 FA             
    PUSH DE                                    ; @277A  D5                
    LD DE,4057h                                ; @277B  11 57 40          
    RST 38h                                    ; @277E  FF                
    POP DE                                     ; @277F  D1                
    RET Z                                      ; @2780  C8                
    LD A,(HL)                                  ; @2781  7E                
loc_2782:
    LD (HL),A                                  ; @2782  77                
    DEC HL                                     ; @2783  2B                
    RST 38h                                    ; @2784  FF                
    JR Z,loc_278C                              ; @2785  28 05             
    DEC HL                                     ; @2787  2B                
    LD A,(HL)                                  ; @2788  7E                
    INC HL                                     ; @2789  23                
    JR loc_2782                                ; @278A  18 F6             
loc_278C:
    LD A,B                                     ; @278C  78                
    LD (HL),A                                  ; @278D  77                
    LD A,(4002h)                               ; @278E  3A 02 40          
    INC A                                      ; @2791  3C                
    LD B,A                                     ; @2792  47                
loc_2793:
    LD HL,403Bh                                ; @2793  21 3B 40          
    LD A,09h                                   ; @2796  3E 09             
    CP B                                       ; @2798  B8                
    JR Z,loc_27A7                              ; @2799  28 0C             
    RST 08h                                    ; @279B  CF                
loc_279C:
    LD A,(HL)                                  ; @279C  7E                
    INC HL                                     ; @279D  23                
    CALL LCD_CHAR_OUTPUT                       ; @279E  CD 9E 06          
    LD A,(4002h)                               ; @27A1  3A 02 40          
    CP B                                       ; @27A4  B8                
    JR NZ,loc_279C                             ; @27A5  20 F5             
loc_27A7:
    RST 08h                                    ; @27A7  CF                
    LD A,20h                                   ; @27A8  3E 20             
loc_27AA:
    CALL LCD_CHAR_OUTPUT                       ; @27AA  CD 9E 06          
    LD A,(HL)                                  ; @27AD  7E                
    CP A0h                                     ; @27AE  FE A0             
    JR Z,loc_27B5                              ; @27B0  28 03             
    INC HL                                     ; @27B2  23                
    JR loc_27AA                                ; @27B3  18 F5             
loc_27B5:
    LD A,(4002h)                               ; @27B5  3A 02 40          
    CP 25h                                     ; @27B8  FE 25             
    JR Z,loc_27C3                              ; @27BA  28 07             
    LD A,A0h                                   ; @27BC  3E A0             
    CALL LCD_CHAR_OUTPUT                       ; @27BE  CD 9E 06          
    JR loc_27B5                                ; @27C1  18 F2             
loc_27C3:
    LD A,B                                     ; @27C3  78                
    RST 08h                                    ; @27C4  CF                
    RET                                        ; @27C5  C9                
loc_27C6:
    ; Dispatched for keycode/mode: 91/0A, 91/0B
    LD A,(4002h)                               ; @27C6  3A 02 40          
    CP 09h                                     ; @27C9  FE 09             
    RET Z                                      ; @27CB  C8                
    DEC A                                      ; @27CC  3D                
    LD B,A                                     ; @27CD  47                
    SUB 09h                                    ; @27CE  D6 09             
    LD DE,0000h                                ; @27D0  11 00 00          
    LD E,A                                     ; @27D3  5F                
    LD HL,403Bh                                ; @27D4  21 3B 40          
    ADD HL,DE                                  ; @27D7  19                
    PUSH HL                                    ; @27D8  E5                
    EX DE,HL                                   ; @27D9  EB                
    POP HL                                     ; @27DA  E1                
    INC HL                                     ; @27DB  23                
loc_27DC:
    LD A,(HL)                                  ; @27DC  7E                
    LD (DE),A                                  ; @27DD  12                
    INC DE                                     ; @27DE  13                
    INC HL                                     ; @27DF  23                
    CP A0h                                     ; @27E0  FE A0             
    JR NZ,loc_27DC                             ; @27E2  20 F8             
    JR loc_2793                                ; @27E4  18 AD             
loc_27E6:
    ; Dispatched for keycode/mode: 87/0A, 87/0B
    LD A,(4002h)                               ; @27E6  3A 02 40          
    CP 09h                                     ; @27E9  FE 09             
    RET Z                                      ; @27EB  C8                
    DEC A                                      ; @27EC  3D                
    LD B,A                                     ; @27ED  47                
    JR loc_2793                                ; @27EE  18 A3             
loc_27F0:
    ; Dispatched for keycode/mode: 84/0A, 84/0B
    LD A,(4002h)                               ; @27F0  3A 02 40          
    INC A                                      ; @27F3  3C                
    CP 26h                                     ; @27F4  FE 26             
    RET NC                                     ; @27F6  D0                
    LD B,A                                     ; @27F7  47                
    RST 08h                                    ; @27F8  CF                
    LD A,(4003h)                               ; @27F9  3A 03 40          
    LD C,A                                     ; @27FC  4F                
    LD A,B                                     ; @27FD  78                
    DEC A                                      ; @27FE  3D                
    RST 08h                                    ; @27FF  CF                
    LD A,C                                     ; @2800  79                
    CP A0h                                     ; @2801  FE A0             
    RET Z                                      ; @2803  C8                
    JR loc_2793                                ; @2804  18 8D             
loc_2806:
    ; Dispatched for keycode/mode: 8F/0A, 8F/0B
    LD HL,403Bh                                ; @2806  21 3B 40          
    LD DE,4057h                                ; @2809  11 57 40          
    LD C,A0h                                   ; @280C  0E A0             
    LD A,(4538h)                               ; @280E  3A 38 45          
    OR A                                       ; @2811  B7                
    JR Z,loc_2823                              ; @2812  28 0F             
    LD HL,462Fh                                ; @2814  21 2F 46          
    LD DE,464Bh                                ; @2817  11 4B 46          
    INC A                                      ; @281A  3C                
    JR Z,loc_2823                              ; @281B  28 06             
    LD HL,4611h                                ; @281D  21 11 46          
    LD DE,462Dh                                ; @2820  11 2D 46          
loc_2823:
    CALL loc_0306                              ; @2823  CD 06 03          
    LD (HL),00h                                ; @2826  36 00             
    POP HL                                     ; @2828  E1                
    JP loc_26FB                                ; @2829  C3 FB 26          
loc_282C:
    ; Dispatched for keycode/mode: 8E/0A, 8E/0B
    POP HL                                     ; @282C  E1                
loc_282D:
    LD BC,1E01h                                ; @282D  01 01 1E          
    LD HL,403Bh                                ; @2830  21 3B 40          
    LD A,A0h                                   ; @2833  3E A0             
loc_2835:
    CP (HL)                                    ; @2835  BE                
    JR Z,loc_283C                              ; @2836  28 04             
    INC C                                      ; @2838  0C                
    INC HL                                     ; @2839  23                
    DJNZ loc_2835                              ; @283A  10 F9             
loc_283C:
    XOR A                                      ; @283C  AF                
    LD B,A                                     ; @283D  47                
    LD (HL),A                                  ; @283E  77                
    LD A,(4538h)                               ; @283F  3A 38 45          
    OR A                                       ; @2842  B7                
    JR Z,loc_2858                              ; @2843  28 13             
    INC A                                      ; @2845  3C                
    LD DE,462Fh                                ; @2846  11 2F 46          
    JR Z,loc_284E                              ; @2849  28 03             
    LD DE,4611h                                ; @284B  11 11 46          
loc_284E:
    LD HL,403Bh                                ; @284E  21 3B 40          
    LDIR                                       ; @2851  ED B0             
    XOR A                                      ; @2853  AF                
    LD (DE),A                                  ; @2854  12                
    JP loc_28ED                                ; @2855  C3 ED 28          
loc_2858:
    LD A,01h                                   ; @2858  3E 01             
    LD (4507h),A                               ; @285A  32 07 45          
    RET                                        ; @285D  C9                
loc_285E:
    ; Dispatched for keycode/mode: 89/0A
    POP HL                                     ; @285E  E1                
    LD A,(4002h)                               ; @285F  3A 02 40          
    SUB 09h                                    ; @2862  D6 09             
    LD D,00h                                   ; @2864  16 00             
    LD E,A                                     ; @2866  5F                
    LD HL,403Bh                                ; @2867  21 3B 40          
    ADD HL,DE                                  ; @286A  19                
    LD (HL),00h                                ; @286B  36 00             
    RST 20h                                    ; @286D  E7                
    RST 38h                                    ; @286E  FF                
    JR Z,loc_2884                              ; @286F  28 13             
loc_2871:
    LD BC,403Bh                                ; @2871  01 3B 40          
loc_2874:
    LD A,(BC)                                  ; @2874  0A                
    OR A                                       ; @2875  B7                
    JR Z,loc_2884                              ; @2876  28 0C             
    CP (HL)                                    ; @2878  BE                
    JR Z,loc_2891                              ; @2879  28 16             
    INC HL                                     ; @287B  23                
    RST 38h                                    ; @287C  FF                
    JR NZ,loc_2874                             ; @287D  20 F5             
    INC BC                                     ; @287F  03                
    LD A,(BC)                                  ; @2880  0A                
    JP M,loc_28A5                              ; @2881  FA A5 28          
loc_2884:
    RST 18h                                    ; @2884  DF                
    LD HL,12E9h                                ; @2885  21 E9 12          
    RST 30h                                    ; @2888  F7                
    CALL loc_0A64                              ; @2889  CD 64 0A          
    JR loc_282D                                ; @288C  18 9F             
loc_288E:
    POP HL                                     ; @288E  E1                
    JR loc_2884                                ; @288F  18 F3             
loc_2891:
    PUSH HL                                    ; @2891  E5                
loc_2892:
    INC BC                                     ; @2892  03                
    LD A,(BC)                                  ; @2893  0A                
    OR A                                       ; @2894  B7                
    JR Z,loc_28A3                              ; @2895  28 0C             
    INC HL                                     ; @2897  23                
    RST 38h                                    ; @2898  FF                
    JR Z,loc_288E                              ; @2899  28 F3             
    LD A,(BC)                                  ; @289B  0A                
    CP (HL)                                    ; @289C  BE                
    JR Z,loc_2892                              ; @289D  28 F3             
    POP HL                                     ; @289F  E1                
    INC HL                                     ; @28A0  23                
    JR loc_2871                                ; @28A1  18 CE             
loc_28A3:
    INC HL                                     ; @28A3  23                
    POP DE                                     ; @28A4  D1                
loc_28A5:
    LD (4669h),HL                              ; @28A5  22 69 46          
    PUSH HL                                    ; @28A8  E5                
    CALL loc_24FE                              ; @28A9  CD FE 24          
    LD A,01h                                   ; @28AC  3E 01             
    LD (4004h),A                               ; @28AE  32 04 40          
    CALL loc_247A                              ; @28B1  CD 7A 24          
loc_28B4:
    LD DE,(4669h)                              ; @28B4  ED 5B 69 46       
    EX (SP),HL                                 ; @28B8  E3                
    RST 38h                                    ; @28B9  FF                
    JR Z,loc_28C2                              ; @28BA  28 06             
    EX (SP),HL                                 ; @28BC  E3                
    CALL loc_249B                              ; @28BD  CD 9B 24          
    JR loc_28B4                                ; @28C0  18 F2             
loc_28C2:
    POP HL                                     ; @28C2  E1                
    LD A,01h                                   ; @28C3  3E 01             
    LD (4507h),A                               ; @28C5  32 07 45          
    RET                                        ; @28C8  C9                
loc_28C9:
    CP 98h                                     ; @28C9  FE 98             
    JR Z,loc_28D1                              ; @28CB  28 04             
    LD A,FFh                                   ; @28CD  3E FF             
    JR loc_28D3                                ; @28CF  18 02             
loc_28D1:
    LD A,01h                                   ; @28D1  3E 01             
loc_28D3:
    LD (4538h),A                               ; @28D3  32 38 45          
    LD A,(4507h)                               ; @28D6  3A 07 45          
    PUSH AF                                    ; @28D9  F5                
    LD A,0Bh                                   ; @28DA  3E 0B             
    LD (4507h),A                               ; @28DC  32 07 45          
    LD HL,403Bh                                ; @28DF  21 3B 40          
    LD DE,4057h                                ; @28E2  11 57 40          
    LD C,A0h                                   ; @28E5  0E A0             
    CALL loc_0306                              ; @28E7  CD 06 03          
    JP loc_26FB                                ; @28EA  C3 FB 26          
loc_28ED:
    CALL loc_04BA                              ; @28ED  CD BA 04          
    XOR A                                      ; @28F0  AF                
    LD (4538h),A                               ; @28F1  32 38 45          
    POP AF                                     ; @28F4  F1                
    LD (4507h),A                               ; @28F5  32 07 45          
    LD HL,403Bh                                ; @28F8  21 3B 40          
    LD DE,4057h                                ; @28FB  11 57 40          
    LD C,A0h                                   ; @28FE  0E A0             
    CALL loc_0306                              ; @2900  CD 06 03          
    XOR A                                      ; @2903  AF                
    LD (HL),A                                  ; @2904  77                
    JP loc_2246                                ; @2905  C3 46 22          
loc_2908:
    ; Dispatched for keycode/mode: 8F/05
    POP HL                                     ; @2908  E1                
    LD A,(4547h)                               ; @2909  3A 47 45          
    OR A                                       ; @290C  B7                
    JR Z,loc_291F                              ; @290D  28 10             
    LD HL,4566h                                ; @290F  21 66 45          
    LD DE,455Fh                                ; @2912  11 5F 45          
    CALL loc_2C66                              ; @2915  CD 66 2C          
    JR loc_2931                                ; @2918  18 17             
loc_291A:
    ; Dispatched for keycode/mode: 94/00, 94/01, 94/03, 94/09
    LD A,05h                                   ; @291A  3E 05             
    CALL loc_07E6                              ; @291C  CD E6 07          
loc_291F:
    LD HL,0100h                                ; @291F  21 00 01          
    RST 28h                                    ; @2922  EF                
    LD HL,4566h                                ; @2923  21 66 45          
    CALL loc_2DB4                              ; @2926  CD B4 2D          
    CALL loc_2DA2                              ; @2929  CD A2 2D          
    LD A,3Dh                                   ; @292C  3E 3D             
    LD (4548h),A                               ; @292E  32 48 45          
loc_2931:
    CALL loc_04BA                              ; @2931  CD BA 04          
    XOR A                                      ; @2934  AF                
    LD (4547h),A                               ; @2935  32 47 45          
    CALL loc_2DBC                              ; @2938  CD BC 2D          
    LD HL,464Dh                                ; @293B  21 4D 46          
    CALL loc_2DBF                              ; @293E  CD BF 2D          
    CALL loc_0DAF                              ; @2941  CD AF 0D          
    CALL loc_2CC4                              ; @2944  CD C4 2C          
    LD A,20h                                   ; @2947  3E 20             
    LD (401Fh),A                               ; @2949  32 1F 40          
    LD A,(4548h)                               ; @294C  3A 48 45          
    LD (4024h),A                               ; @294F  32 24 40          
    LD HL,455Fh                                ; @2952  21 5F 45          
    LD BC,0014h                                ; @2955  01 14 00          
    CALL loc_2CCA                              ; @2958  CD CA 2C          
    CALL loc_09EA                              ; @295B  CD EA 09          
loc_295E:
    CALL loc_0491                              ; @295E  CD 91 04          
    JR Z,loc_295E                              ; @2961  28 FB             
    LD HL,295Eh                                ; @2963  21 5E 29          
    PUSH HL                                    ; @2966  E5                
    CP 30h                                     ; @2967  FE 30             
    JR C,loc_2972                              ; @2969  38 07             
    CP 3Ah                                     ; @296B  FE 3A             
    JR C,loc_299B                              ; @296D  38 2C             
    CALL loc_0051                              ; @296F  CD 51 00          
loc_2972:
    LD HL,298Eh                                ; @2972  21 8E 29          
    LD B,(HL)                                  ; @2975  46                
    INC HL                                     ; @2976  23                
loc_2977:
    CP (HL)                                    ; @2977  BE                
    INC HL                                     ; @2978  23                
    LD C,(HL)                                  ; @2979  4E                
    INC HL                                     ; @297A  23                
    JR Z,loc_2980                              ; @297B  28 03             
    LD C,A                                     ; @297D  4F                
    DJNZ loc_2977                              ; @297E  10 F7             
loc_2980:
    LD A,C                                     ; @2980  79                
    CALL OS_COMMAND_LOOKUP                     ; @2981  CD 38 02          
    JR C,loc_298D                              ; @2984  38 07             
    LD HL,10C0h                                ; @2986  21 C0 10          
    CALL loc_027B                              ; @2989  CD 7B 02          
    RET NC                                     ; @298C  D0                
loc_298D:
    JP (HL)                                    ; @298D  E9                
    DB 06h,71h,2Bh,77h,2Dh,65h,78h,72h,FDh,69h,2Eh,74h,3Dh ; @298E  06 71 2B 77 2D 65 78 72 FD 69 2E 74 3D   |.q+w-exr.i.t=|
loc_299B:
    PUSH AF                                    ; @299B  F5                
    LD HL,4547h                                ; @299C  21 47 45          
    LD A,(HL)                                  ; @299F  7E                
    CP 0Ah                                     ; @29A0  FE 0A             
    JR Z,loc_29C0                              ; @29A2  28 1C             
    CALL loc_29C2                              ; @29A4  CD C2 29          
    LD HL,4547h                                ; @29A7  21 47 45          
    INC (HL)                                   ; @29AA  34                
    LD HL,4565h                                ; @29AB  21 65 45          
    LD A,(HL)                                  ; @29AE  7E                
    AND 40h                                    ; @29AF  E6 40             
    JR Z,loc_29B4                              ; @29B1  28 01             
    INC (HL)                                   ; @29B3  34                
loc_29B4:
    POP AF                                     ; @29B4  F1                
    PUSH AF                                    ; @29B5  F5                
    CALL LCD_CHAR_OUTPUT                       ; @29B6  CD 9E 06          
    POP AF                                     ; @29B9  F1                
    LD HL,455Fh                                ; @29BA  21 5F 45          
    JP loc_2D78                                ; @29BD  C3 78 2D          
loc_29C0:
    POP AF                                     ; @29C0  F1                
    RET                                        ; @29C1  C9                
loc_29C2:
    LD A,(4547h)                               ; @29C2  3A 47 45          
    OR A                                       ; @29C5  B7                
    RET NZ                                     ; @29C6  C0                
    LD A,(4565h)                               ; @29C7  3A 65 45          
    AND 40h                                    ; @29CA  E6 40             
    RET NZ                                     ; @29CC  C0                
    LD HL,455Fh                                ; @29CD  21 5F 45          
    LD DE,4566h                                ; @29D0  11 66 45          
    CALL loc_2C66                              ; @29D3  CD 66 2C          
    JP loc_2DA2                                ; @29D6  C3 A2 2D          
    DB CDh,C2h,29h,21h,65h,45h,CBh,76h,C0h,CBh,F6h,3Eh,2Eh,C3h,9Eh,06h ; @29D9  CD C2 29 21 65 45 CB 76 C0 CB F6 3E 2E C3 9E 06   |..)!eE.v...>....|
    DB AFh,18h,02h,3Eh,80h,21h,A1h,2Ah,E3h,F5h,21h,5Fh,45h,11h,49h,45h ; @29E9  AF 18 02 3E 80 21 A1 2A E3 F5 21 5F 45 11 49 45   |...>.!.*..!_E.IE|
    DB D5h,CDh,66h,2Ch,D1h,21h,4Dh,46h,D5h,E5h,CDh,9Ch,2Ch,E1h,D1h,AFh ; @29F9  D5 CD 66 2C D1 21 4D 46 D5 E5 CD 9C 2C E1 D1 AF   |..f,.!MF....,...|
    DB 32h,5Ch,45h,32h,5Dh,45h,32h,5Eh,45h,F1h,22h,45h,45h,EDh,53h,43h ; @2A09  32 5C 45 32 5D 45 32 5E 45 F1 22 45 45 ED 53 43   |2\E2]E2^E."EE.SC|
    DB 45h,18h,29h,21h,A1h,2Ah,E3h,21h,48h,45h,47h,7Eh,70h,FEh,3Dh,C8h ; @2A19  45 18 29 21 A1 2A E3 21 48 45 47 7E 70 FE 3D C8   |E.)!.*.!HEG~p.=.|
    DB 21h,DCh,10h,CDh,7Bh,02h,E5h,06h,16h,21h,49h,45h,CDh,B6h,2Dh,11h ; @2A29  21 DC 10 CD 7B 02 E5 06 16 21 49 45 CD B6 2D 11   |!...{....!IE..-.|
    DB 66h,45h,22h,45h,45h,EDh,53h,43h,45h,C9h,3Eh,80h,F5h,CDh,02h,2Eh ; @2A39  66 45 22 45 45 ED 53 43 45 C9 3E 80 F5 CD 02 2E   |fE"EE.SCE.>.....|
    DB CDh,E5h,2Dh,28h,1Ch,F1h,E5h,D5h,11h,06h,00h,19h,AEh,E1h,E5h,19h ; @2A49  CD E5 2D 28 1C F1 E5 D5 11 06 00 19 AE E1 E5 19
    DB AEh,32h,5Bh,45h,07h,2Ah,45h,45h,DCh,62h,2Eh,D1h,E1h,CDh,4Ah,2Eh ; @2A59  AE 32 5B 45 07 2A 45 45 DC 62 2E D1 E1 CD 4A 2E   |.2[E.*EE.b....J.|
    DB F5h,F1h,2Ah,43h,45h,CDh,62h,2Ch,2Ah,45h,45h,01h,05h,00h,09h,3Ah ; @2A69  F5 F1 2A 43 45 CD 62 2C 2A 45 45 01 05 00 09 3A   |..*CE.b,*EE....:|
    DB 5Bh,45h,07h,7Eh,36h,00h,30h,08h,B7h,2Ah,45h,45h,CCh,62h,2Eh,C9h ; @2A79  5B 45 07 7E 36 00 30 08 B7 2A 45 45 CC 62 2E C9   |[E.~6.0..*EE.b..|
    DB B7h,C8h,77h,23h,7Eh,E6h,0Fh,CAh,46h,2Ch,35h,2Ah,45h,45h,7Eh,32h ; @2A89  B7 C8 77 23 7E E6 0F CA 46 2C 35 2A 45 45 7E 32   |..w#~...F,5*EE~2|
    DB 5Ch,45h,CDh,8Dh,2Dh,C3h,34h,2Ch,2Ah,45h,45h,11h,05h,00h,19h,36h ; @2A99  5C 45 CD 8D 2D C3 34 2C 2A 45 45 11 05 00 19 36   |\E..-.4,*EE....6|
    DB 00h,C3h,31h,29h,D5h,CDh,82h,2Eh,32h,5Bh,45h,21h,4Ah,45h,22h,43h ; @2AA9  00 C3 31 29 D5 CD 82 2E 32 5B 45 21 4A 45 22 43   |..1)....2[E!JE"C|
    DB 45h,18h,03h,CDh,46h,2Bh,3Ah,5Ah,45h,FEh,0Ah,28h,1Bh,3Ch,32h,5Ah ; @2AB9  45 18 03 CD 46 2B 3A 5A 45 FE 0A 28 1B 3C 32 5A   |E...F+:ZE..(.<2Z|
    DB 45h,3Dh,2Ah,45h,45h,CDh,45h,2Dh,28h,E9h,2Ah,43h,45h,EBh,E1h,E5h ; @2AC9  45 3D 2A 45 45 CD 45 2D 28 E9 2A 43 45 EB E1 E5   |E=*EE.E-(.*CE...|
    DB F5h,CDh,4Ah,2Eh,F1h,3Dh,18h,F0h,21h,5Bh,45h,7Eh,0Fh,30h,0Ch,34h ; @2AD9  F5 CD 4A 2E F1 3D 18 F0 21 5B 45 7E 0F 30 0C 34   |..J..=..![E~.0.4|
    DB E5h,06h,0Eh,21h,4Ah,45h,AFh,CDh,7Ah,2Dh,E1h,7Eh,E6h,3Fh,0Fh,C6h ; @2AE9  E5 06 0E 21 4A 45 AF CD 7A 2D E1 7E E6 3F 0F C6   |...!JE..z-.~.?..|
    DB 05h,5Fh,16h,00h,21h,4Ah,45h,19h,7Eh,B7h,28h,04h,D1h,C3h,46h,2Ch ; @2AF9  05 5F 16 00 21 4A 45 19 7E B7 28 04 D1 C3 46 2C   |._..!JE.~.(...F,|
    DB 11h,05h,00h,21h,4Ah,45h,19h,CDh,E5h,2Dh,28h,12h,21h,4Ah,45h,7Eh ; @2B09  11 05 00 21 4A 45 19 CD E5 2D 28 12 21 4A 45 7E   |...!JE...-(.!JE~|
    DB 32h,5Ch,45h,06h,0Eh,CDh,8Fh,2Dh,21h,5Bh,45h,35h,18h,E2h,21h,5Bh ; @2B19  32 5C 45 06 0E CD 8F 2D 21 5B 45 35 18 E2 21 5B   |2\E....-![E5..![|
    DB 45h,7Eh,E6h,3Fh,FEh,0Bh,30h,E4h,21h,4Ah,45h,CDh,62h,2Ch,E1h,11h ; @2B29  45 7E E6 3F FE 0B 30 E4 21 4A 45 CD 62 2C E1 11   |E~.?..0.!JE.b,..|
    DB 06h,00h,2Ah,45h,45h,19h,3Ah,5Bh,45h,77h,C3h,34h,2Ch,06h,0Bh,11h ; @2B39  06 00 2A 45 45 19 3A 5B 45 77 C3 34 2C 06 0B 11   |..*EE.:[Ew.4,...|
    DB 49h,45h,3Ah,5Ah,45h,0Fh,38h,0Ch,2Ah,43h,45h,23h,22h,43h,45h,EBh ; @2B49  49 45 3A 5A 45 0F 38 0C 2A 43 45 23 22 43 45 EB   |IE:ZE.8.*CE#"CE.|
    DB AFh,C3h,7Ah,2Dh,EBh,C3h,8Fh,2Dh,E5h,CDh,82h,2Eh,E1h,CDh,E5h,2Dh ; @2B59  AF C3 7A 2D EB C3 8F 2D E5 CD 82 2E E1 CD E5 2D   |..z-...-.......-|
    DB CAh,46h,2Ch,EBh,CDh,E5h,2Dh,CAh,42h,2Ch,2Ah,45h,45h,54h,5Dh,01h ; @2B69  CA 46 2C EB CD E5 2D CA 42 2C 2A 45 45 54 5D 01   |.F,...-.B,*EET].|
    DB 04h,00h,09h,7Eh,E6h,F0h,20h,0Ah,21h,5Ah,45h,34h,EBh,CDh,78h,2Dh ; @2B79  04 00 09 7E E6 F0 20 0A 21 5A 45 34 EB CD 78 2D   |...~.. .!ZE4..x-|
    DB 18h,E8h,21h,4Dh,45h,7Eh,E6h,F0h,20h,63h,21h,5Ch,45h,7Eh,36h,00h ; @2B89  18 E8 21 4D 45 7E E6 F0 20 63 21 5C 45 7E 36 00   |..!ME~.. c!\E~6.|
    DB 21h,49h,45h,CDh,78h,2Dh,2Ah,43h,45h,E5h,EBh,2Ah,45h,45h,CDh,56h ; @2B99  21 49 45 CD 78 2D 2A 43 45 E5 EB 2A 45 45 CD 56   |!IE.x-*CE..*EE.V|
    DB 2Eh,E1h,11h,05h,00h,19h,7Eh,E6h,F0h,20h,15h,21h,5Ch,45h,34h,21h ; @2BA9  2E E1 11 05 00 19 7E E6 F0 20 15 21 5C 45 34 21   |......~.. .!\E4!|
    DB 5Eh,45h,7Eh,B7h,20h,E0h,36h,FFh,3Ah,5Ah,45h,32h,5Dh,45h,18h,D6h ; @2BB9  5E 45 7E B7 20 E0 36 FF 3A 5A 45 32 5D 45 18 D6   |^E~. .6.:ZE2]E..|
    DB 2Ah,43h,45h,EBh,2Ah,45h,45h,CDh,4Ah,2Eh,21h,5Ah,45h,7Eh,B7h,28h ; @2BC9  2A 43 45 EB 2A 45 45 CD 4A 2E 21 5A 45 7E B7 28   |*CE.*EE.J.!ZE~.(|
    DB 09h,35h,2Ah,45h,45h,CDh,8Dh,2Dh,18h,A8h,2Ah,43h,45h,AFh,CDh,78h ; @2BD9  09 35 2A 45 45 CD 8D 2D 18 A8 2A 43 45 AF CD 78   |.5*EE..-..*CE..x|
    DB 2Dh,3Ah,5Eh,45h,B7h,20h,9Bh,21h,59h,45h,34h,18h,95h,21h,49h,45h ; @2BE9  2D 3A 5E 45 B7 20 9B 21 59 45 34 18 95 21 49 45   |-:^E. .!YE4..!IE|
    DB CDh,62h,2Ch,3Ah,5Bh,45h,21h,59h,45h,86h,21h,5Dh,45h,96h,38h,3Dh ; @2BF9  CD 62 2C 3A 5B 45 21 59 45 86 21 5D 45 96 38 3D   |.b,:[E!YE.!]E.8=|
    DB 2Ah,45h,45h,11h,06h,00h,19h,77h,E6h,3Fh,FEh,0Bh,38h,1Dh,FEh,15h ; @2C09  2A 45 45 11 06 00 19 77 E6 3F FE 0B 38 1D FE 15   |*EE....w.?..8...|
    DB 30h,27h,D6h,0Ah,47h,7Eh,E6h,80h,F6h,0Ah,77h,2Ah,45h,45h,C5h,E5h ; @2C19  30 27 D6 0A 47 7E E6 80 F6 0A 77 2A 45 45 C5 E5   |0'..G~....w*EE..|
    DB 7Eh,32h,5Ch,45h,CDh,8Dh,2Dh,E1h,C1h,10h,F3h,2Ah,45h,45h,3Ah,5Ch ; @2C29  7E 32 5C 45 CD 8D 2D E1 C1 10 F3 2A 45 45 3A 5C   |~2\E..-....*EE:\|
    DB 45h,E6h,0Fh,FEh,05h,D4h,75h,2Eh,C9h,E1h,C3h,29h,29h,21h,1Ah,13h ; @2C39  45 E6 0F FE 05 D4 75 2E C9 E1 C3 29 29 21 1A 13   |E.....u....))!..|
    DB CDh,3Fh,00h,AFh,32h,47h,45h,CDh,91h,04h,FEh,8Fh,20h,F9h,C3h,08h ; @2C49  CD 3F 00 AF 32 47 45 CD 91 04 FE 8F 20 F9 C3 08   |.?..2GE..... ...|
    DB 29h                                      ; @2C59  29
loc_2C5A:
    ; Dispatched for keycode/mode: 87/05
    LD HL,455Fh                                ; @2C5A  21 5F 45          
    LD DE,464Dh                                ; @2C5D  11 4D 46          
    JR loc_2C75                                ; @2C60  18 13             
    DB EDh,5Bh,45h,45h                          ; @2C62  ED 5B 45 45
loc_2C66:
    LD BC,0007h                                ; @2C66  01 07 00          
    LDIR                                       ; @2C69  ED B0             
    RET                                        ; @2C6B  C9                
loc_2C6C:
    ; Dispatched for keycode/mode: 84/05
    CALL loc_29C2                              ; @2C6C  CD C2 29          
    LD HL,464Dh                                ; @2C6F  21 4D 46          
    LD DE,455Fh                                ; @2C72  11 5F 45          
loc_2C75:
    CALL loc_2C66                              ; @2C75  CD 66 2C          
loc_2C78:
    POP HL                                     ; @2C78  E1                
    JP loc_2931                                ; @2C79  C3 31 29          
loc_2C7C:
    ; Dispatched for keycode/mode: 85/05, 86/05
    LD HL,455Fh                                ; @2C7C  21 5F 45          
    LD DE,4549h                                ; @2C7F  11 49 45          
    CALL loc_2C66                              ; @2C82  CD 66 2C          
    CALL loc_29C2                              ; @2C85  CD C2 29          
    LD HL,4549h                                ; @2C88  21 49 45          
    LD DE,455Fh                                ; @2C8B  11 5F 45          
    CALL loc_2C66                              ; @2C8E  CD 66 2C          
    LD DE,455Fh                                ; @2C91  11 5F 45          
    LD HL,464Dh                                ; @2C94  21 4D 46          
    CALL loc_2C9C                              ; @2C97  CD 9C 2C          
    JR loc_2C78                                ; @2C9A  18 DC             
loc_2C9C:
    LD B,07h                                   ; @2C9C  06 07             
loc_2C9E:
    LD A,(DE)                                  ; @2C9E  1A                
    LD C,(HL)                                  ; @2C9F  4E                
    LD (HL),A                                  ; @2CA0  77                
    LD A,C                                     ; @2CA1  79                
    LD (DE),A                                  ; @2CA2  12                
    INC DE                                     ; @2CA3  13                
    INC HL                                     ; @2CA4  23                
    DJNZ loc_2C9E                              ; @2CA5  10 F7             
    RET                                        ; @2CA7  C9                
    DB 21h,65h,45h,7Eh,EEh,80h,77h,3Ah,02h,40h,F5h,3Eh,1Fh,CFh,3Eh,20h ; @2CA8  21 65 45 7E EE 80 77 3A 02 40 F5 3E 1F CF 3E 20   |!eE~..w:.@.>..> |
    DB CBh,7Eh,28h,02h,3Eh,2Dh,CDh,9Eh,06h,F1h,CFh,C9h ; @2CB8  CB 7E 28 02 3E 2D CD 9E 06 F1 CF C9
loc_2CC4:
    LD HL,464Dh                                ; @2CC4  21 4D 46          
    LD BC,0000h                                ; @2CC7  01 00 00          
loc_2CCA:
    LD DE,4013h                                ; @2CCA  11 13 40          
    PUSH HL                                    ; @2CCD  E5                
    EX DE,HL                                   ; @2CCE  EB                
    ADD HL,BC                                  ; @2CCF  09                
    LD (4545h),HL                              ; @2CD0  22 45 45          
    LD HL,0006h                                ; @2CD3  21 06 00          
    ADD HL,DE                                  ; @2CD6  19                
    LD A,(HL)                                  ; @2CD7  7E                
    RLCA                                       ; @2CD8  07                
    LD A,20h                                   ; @2CD9  3E 20             
    JR NC,loc_2CDF                             ; @2CDB  30 02             
    LD A,2Dh                                   ; @2CDD  3E 2D             
loc_2CDF:
    LD (455Bh),A                               ; @2CDF  32 5B 45          
    XOR A                                      ; @2CE2  AF                
    LD (455Ah),A                               ; @2CE3  32 5A 45          
    LD A,(HL)                                  ; @2CE6  7E                
    AND 0Fh                                    ; @2CE7  E6 0F             
    LD B,0Ah                                   ; @2CE9  06 0A             
    CP B                                       ; @2CEB  B8                
    JR Z,loc_2D11                              ; @2CEC  28 23             
    CPL                                        ; @2CEE  2F                
    INC A                                      ; @2CEF  3C                
    ADD A,B                                    ; @2CF0  80                
    LD (4559h),A                               ; @2CF1  32 59 45          
loc_2CF4:
    LD A,B                                     ; @2CF4  78                
    DEC A                                      ; @2CF5  3D                
    JR NZ,loc_2CFF                             ; @2CF6  20 07             
    PUSH AF                                    ; @2CF8  F5                
    LD A,FFh                                   ; @2CF9  3E FF             
    LD (455Ah),A                               ; @2CFB  32 5A 45          
    POP AF                                     ; @2CFE  F1                
loc_2CFF:
    POP HL                                     ; @2CFF  E1                
    PUSH HL                                    ; @2D00  E5                
    CALL loc_2D45                              ; @2D01  CD 45 2D          
    CALL loc_2D62                              ; @2D04  CD 62 2D          
    DEC B                                      ; @2D07  05                
    LD A,(4559h)                               ; @2D08  3A 59 45          
    DEC A                                      ; @2D0B  3D                
    LD (4559h),A                               ; @2D0C  32 59 45          
    JR NZ,loc_2CF4                             ; @2D0F  20 E3             
loc_2D11:
    POP HL                                     ; @2D11  E1                
    PUSH HL                                    ; @2D12  E5                
    LD DE,0006h                                ; @2D13  11 06 00          
    ADD HL,DE                                  ; @2D16  19                
    LD A,(HL)                                  ; @2D17  7E                
    AND 7Fh                                    ; @2D18  E6 7F             
    LD A,2Eh                                   ; @2D1A  3E 2E             
    JR NZ,loc_2D20                             ; @2D1C  20 02             
    LD A,20h                                   ; @2D1E  3E 20             
loc_2D20:
    CALL loc_2D57                              ; @2D20  CD 57 2D          
    LD A,(HL)                                  ; @2D23  7E                
    AND 0Fh                                    ; @2D24  E6 0F             
    LD B,A                                     ; @2D26  47                
    JR Z,loc_2D39                              ; @2D27  28 10             
    LD HL,455Ah                                ; @2D29  21 5A 45          
    DEC (HL)                                   ; @2D2C  35                
loc_2D2D:
    POP HL                                     ; @2D2D  E1                
    PUSH HL                                    ; @2D2E  E5                
    LD A,B                                     ; @2D2F  78                
    DEC A                                      ; @2D30  3D                
    CALL loc_2D45                              ; @2D31  CD 45 2D          
    CALL loc_2D62                              ; @2D34  CD 62 2D          
    DJNZ loc_2D2D                              ; @2D37  10 F4             
loc_2D39:
    LD A,(455Bh)                               ; @2D39  3A 5B 45          
    CALL loc_2D57                              ; @2D3C  CD 57 2D          
    XOR A                                      ; @2D3F  AF                
    CALL loc_2D57                              ; @2D40  CD 57 2D          
    POP HL                                     ; @2D43  E1                
    RET                                        ; @2D44  C9                
loc_2D45:
    OR A                                       ; @2D45  B7                
    RRA                                        ; @2D46  1F                
    LD E,A                                     ; @2D47  5F                
    LD D,00h                                   ; @2D48  16 00             
    PUSH AF                                    ; @2D4A  F5                
    ADD HL,DE                                  ; @2D4B  19                
    POP AF                                     ; @2D4C  F1                
    LD A,(HL)                                  ; @2D4D  7E                
    JR NC,loc_2D54                             ; @2D4E  30 04             
    RRCA                                       ; @2D50  0F                
    RRCA                                       ; @2D51  0F                
    RRCA                                       ; @2D52  0F                
    RRCA                                       ; @2D53  0F                
loc_2D54:
    AND 0Fh                                    ; @2D54  E6 0F             
    RET                                        ; @2D56  C9                
loc_2D57:
    PUSH HL                                    ; @2D57  E5                
    LD HL,(4545h)                              ; @2D58  2A 45 45          
    LD (HL),A                                  ; @2D5B  77                
    INC HL                                     ; @2D5C  23                
    LD (4545h),HL                              ; @2D5D  22 45 45          
    POP HL                                     ; @2D60  E1                
    RET                                        ; @2D61  C9                
loc_2D62:
    LD C,A                                     ; @2D62  4F                
    LD HL,455Ah                                ; @2D63  21 5A 45          
    JR NZ,loc_2D71                             ; @2D66  20 09             
    LD A,(HL)                                  ; @2D68  7E                
    OR A                                       ; @2D69  B7                
    JR NZ,loc_2D71                             ; @2D6A  20 05             
    LD A,20h                                   ; @2D6C  3E 20             
    JP loc_2D57                                ; @2D6E  C3 57 2D          
loc_2D71:
    DEC (HL)                                   ; @2D71  35                
    LD A,C                                     ; @2D72  79                
    CALL loc_072D                              ; @2D73  CD 2D 07          
    JR loc_2D57                                ; @2D76  18 DF             
loc_2D78:
    LD B,06h                                   ; @2D78  06 06             
    PUSH HL                                    ; @2D7A  E5                
    EX DE,HL                                   ; @2D7B  EB                
    LD H,A                                     ; @2D7C  67                
loc_2D7D:
    LD A,(DE)                                  ; @2D7D  1A                
    LD L,A                                     ; @2D7E  6F                
    LD A,H                                     ; @2D7F  7C                
    ADD HL,HL                                  ; @2D80  29                
    ADD HL,HL                                  ; @2D81  29                
    ADD HL,HL                                  ; @2D82  29                
    ADD HL,HL                                  ; @2D83  29                
    AND 0Fh                                    ; @2D84  E6 0F             
    OR L                                       ; @2D86  B5                
    LD (DE),A                                  ; @2D87  12                
    INC DE                                     ; @2D88  13                
    DJNZ loc_2D7D                              ; @2D89  10 F2             
    POP HL                                     ; @2D8B  E1                
    RET                                        ; @2D8C  C9                
loc_2D8D:
    LD B,05h                                   ; @2D8D  06 05             
    PUSH HL                                    ; @2D8F  E5                
    EX DE,HL                                   ; @2D90  EB                
loc_2D91:
    INC DE                                     ; @2D91  13                
    LD A,(DE)                                  ; @2D92  1A                
    DEC DE                                     ; @2D93  1B                
    LD H,A                                     ; @2D94  67                
    LD A,(DE)                                  ; @2D95  1A                
    LD L,A                                     ; @2D96  6F                
    ADD HL,HL                                  ; @2D97  29                
    ADD HL,HL                                  ; @2D98  29                
    ADD HL,HL                                  ; @2D99  29                
    ADD HL,HL                                  ; @2D9A  29                
    LD A,H                                     ; @2D9B  7C                
    LD (DE),A                                  ; @2D9C  12                
    INC DE                                     ; @2D9D  13                
    DJNZ loc_2D91                              ; @2D9E  10 F1             
    POP HL                                     ; @2DA0  E1                
    RET                                        ; @2DA1  C9                
loc_2DA2:
    LD A,14h                                   ; @2DA2  3E 14             
    RST 08h                                    ; @2DA4  CF                
    LD B,0Dh                                   ; @2DA5  06 0D             
loc_2DA7:
    LD A,20h                                   ; @2DA7  3E 20             
    CALL LCD_CHAR_OUTPUT                       ; @2DA9  CD 9E 06          
    DJNZ loc_2DA7                              ; @2DAC  10 F9             
    LD A,14h                                   ; @2DAE  3E 14             
    RST 08h                                    ; @2DB0  CF                
    LD HL,455Fh                                ; @2DB1  21 5F 45          
loc_2DB4:
    LD B,07h                                   ; @2DB4  06 07             
    XOR A                                      ; @2DB6  AF                
loc_2DB7:
    LD (HL),A                                  ; @2DB7  77                
    INC HL                                     ; @2DB8  23                
    DJNZ loc_2DB7                              ; @2DB9  10 FC             
    RET                                        ; @2DBB  C9                
loc_2DBC:
    LD HL,455Fh                                ; @2DBC  21 5F 45          
loc_2DBF:
    CALL loc_2DE5                              ; @2DBF  CD E5 2D          
    PUSH HL                                    ; @2DC2  E5                
    LD BC,0006h                                ; @2DC3  01 06 00          
    ADD HL,BC                                  ; @2DC6  09                
    LD A,(HL)                                  ; @2DC7  7E                
    AND BFh                                    ; @2DC8  E6 BF             
    LD (HL),A                                  ; @2DCA  77                
    EX (SP),HL                                 ; @2DCB  E3                
    AND 7Fh                                    ; @2DCC  E6 7F             
    LD B,A                                     ; @2DCE  47                
    JR Z,loc_2DE3                              ; @2DCF  28 12             
loc_2DD1:
    LD A,(HL)                                  ; @2DD1  7E                
    AND 0Fh                                    ; @2DD2  E6 0F             
    JP NZ,loc_2DE3                             ; @2DD4  C2 E3 2D          
    EX (SP),HL                                 ; @2DD7  E3                
    DEC (HL)                                   ; @2DD8  35                
    EX (SP),HL                                 ; @2DD9  E3                
    PUSH BC                                    ; @2DDA  C5                
    PUSH HL                                    ; @2DDB  E5                
    CALL loc_2D8D                              ; @2DDC  CD 8D 2D          
    POP HL                                     ; @2DDF  E1                
    POP BC                                     ; @2DE0  C1                
    DJNZ loc_2DD1                              ; @2DE1  10 EE             
loc_2DE3:
    POP DE                                     ; @2DE3  D1                
    RET                                        ; @2DE4  C9                
loc_2DE5:
    PUSH HL                                    ; @2DE5  E5                
    XOR A                                      ; @2DE6  AF                
    LD B,06h                                   ; @2DE7  06 06             
loc_2DE9:
    OR (HL)                                    ; @2DE9  B6                
    INC HL                                     ; @2DEA  23                
    DJNZ loc_2DE9                              ; @2DEB  10 FC             
    OR A                                       ; @2DED  B7                
    JR NZ,loc_2DF1                             ; @2DEE  20 01             
    LD (HL),A                                  ; @2DF0  77                
loc_2DF1:
    POP HL                                     ; @2DF1  E1                
    RET                                        ; @2DF2  C9                
    DB EBh,35h,09h,22h,5Dh,45h,7Eh,32h,5Ch,45h,CDh,8Dh,2Dh,E1h,D1h,D5h ; @2DF3  EB 35 09 22 5D 45 7E 32 5C 45 CD 8D 2D E1 D1 D5   |.5."]E~2\E..-...|
    DB E5h,01h,06h,00h,09h,EBh,09h,7Eh,E6h,0Fh,47h,1Ah,E6h,0Fh,B8h,28h ; @2E03  E5 01 06 00 09 EB 09 7E E6 0F 47 1A E6 0F B8 28
    DB 16h,30h,01h,EBh,01h,FAh,FFh,2Bh,2Bh,7Eh,23h,23h,E6h,F0h,20h,D0h ; @2E13  16 30 01 EB 01 FA FF 2B 2B 7E 23 23 E6 F0 20 D0   |.0.....++~##.. .|
    DB 34h,09h,CDh,78h,2Dh,18h,D6h,3Ah,5Ch,45h,E6h,0Fh,FEh,05h,38h,14h ; @2E23  34 09 CD 78 2D 18 D6 3A 5C 45 E6 0F FE 05 38 14   |4..x-..:\E....8.|
    DB 2Ah,5Dh,45h,CDh,75h,2Eh,30h,0Ch,7Eh,E6h,0Fh,28h,07h,35h,2Bh,36h ; @2E33  2A 5D 45 CD 75 2E 30 0C 7E E6 0F 28 07 35 2B 36   |*]E.u.0.~..(.5+6|
    DB 00h,2Bh,36h,10h,E1h,D1h,C9h,06h,06h,AFh,1Ah,8Eh,27h,12h,13h,23h ; @2E43  00 2B 36 10 E1 D1 C9 06 06 AF 1A 8E 27 12 13 23
    DB 10h,F8h,C9h,06h,06h,AFh,1Ah,9Eh,27h,12h,23h,13h,10h,F8h,C9h,06h ; @2E53  10 F8 C9 06 06 AF 1A 9E 27 12 23 13 10 F8 C9 06
    DB 05h,B7h,3Eh,00h,9Eh,27h,77h,23h,10h,F8h,36h,00h,23h,7Eh,EEh,80h ; @2E63  05 B7 3E 00 9E 27 77 23 10 F8 36 00 23 7E EE 80   |..>..'w#..6.#~..|
    DB 77h,C9h,06h,05h,AFh,3Ch,8Eh,27h,77h,3Eh,00h,23h,10h,F8h,C9h,01h ; @2E73  77 C9 06 05 AF 3C 8E 27 77 3E 00 23 10 F8 C9 01   |w....<.'w>.#....|
    DB 06h,00h,09h,7Eh,EBh,09h,F5h,E6h,3Fh,47h,F1h,E6h,80h,AEh,E6h,BFh ; @2E83  06 00 09 7E EB 09 F5 E6 3F 47 F1 E6 80 AE E6 BF
    DB 4Fh,C6h,09h,90h,32h,5Bh,45h,79h,80h,C9h,00h,00h,00h,00h,00h,00h ; @2E93  4F C6 09 90 32 5B 45 79 80 C9 00 00 00 00 00 00   |O...2[Ey........|
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2EA3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2EB3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2EC3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2ED3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2EE3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2EF3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F03  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F13  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F23  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F33  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F43  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F53  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F63  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F73  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F83  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2F93  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FA3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FB3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FC3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FD3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FE3  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    DB 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; @2FF3  00 00 00 00 00 00 00 00 00 00 00 00 00

