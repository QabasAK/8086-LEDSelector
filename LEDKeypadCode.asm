DATA SEGMENT
    portA     EQU 48H     ; LEDs (PA0-PA7)
    portB     EQU 4AH     ; Keypad rows (PB0-PB3)
    portC     EQU 4CH     ; Keypad cols (PC0-PC3) + Buzzer (PC7)
    CWR       EQU 4EH     ; 8255 Control Register

    pswd      DB 8,6,4,9
    buzzer    DB 0        ; 00h = off, 80h = on
    buffer    DB 4 DUP (0)
DATA ENDS

CODE SEGMENT PUBLIC 'CODE'
    ASSUME CS:CODE, DS:DATA

START:
    MOV AX, DATA
    MOV DS, AX

    CALL initialise
    CALL auth

MAIN_LOOP:
    CALL keypad
    JMP MAIN_LOOP

; ----------------------------
; Initialize 8255
; ----------------------------
initialise PROC
    MOV AL, 10000010B      ; Set 8255 control word
    OUT CWR, AL
    RET
initialise ENDP

; ----------------------------
; Authentication routine
; ----------------------------
auth PROC NEAR
RETRY:
    MOV SI, 0

GET_DIG:
    CALL getkey            ; Blocking read
    MOV [buffer + SI], AL
    INC SI
    CMP SI, 4
    JL  GET_DIG

    MOV SI, 0
    MOV CX, 4

CHK:
    MOV AL, [buffer + SI]
    CMP AL, [pswd + SI]
    JNE BADPASS
    INC SI
    LOOP CHK

    CALL buzzer_off        ; Password correct
    RET

BADPASS:
    CALL buzzer_on
    JMP RETRY
auth ENDP

; ----------------------------
; Buzzer ON
; ----------------------------
buzzer_on PROC NEAR
    MOV buzzer, 80H
    MOV AL, 8FH            ; Rows high + buzzer on
    OUT portC, AL
    RET
buzzer_on ENDP

; ----------------------------
; Buzzer OFF
; ----------------------------
buzzer_off PROC NEAR
    MOV buzzer, 0
    MOV AL, 0FH            ; Rows high, buzzer off
    OUT portC, AL
    RET
buzzer_off ENDP

; ----------------------------
; Key debounce handling
; ----------------------------
getkey PROC
press:
    CALL scankey
    CMP AL, 0FFH
    JE  press
    MOV BL, AL

release:
    CALL scankey
    CMP AL, 0FFH
    JNE release

    MOV AL, BL
    RET
getkey ENDP

; ----------------------------
; Delay loop
; ----------------------------
delay PROC
    MOV CX, 0FFFFH
d1:
    NOP
    LOOP d1
    RET
delay ENDP

; ----------------------------
; Key scanning routine
; ----------------------------
scankey PROC NEAR
; Row 0 (PC0 low): 1 2 3
    MOV AL, 0EH
    OR  AL, buzzer
    OUT portC, AL
    IN  AL, portB
    AND AL, 7
    CMP AL, 7
    JZ  row1
    TEST AL, 1
    JZ  k1
    TEST AL, 2
    JZ  k2
    MOV AL, 3
    RET
k1: MOV AL, 1
    RET
k2: MOV AL, 2
    RET

; Row 1 (PC1 low): 4 5 6
row1:
    MOV AL, 0DH
    OR  AL, buzzer
    OUT portC, AL
    IN  AL, portB
    AND AL, 7
    CMP AL, 7
    JZ  row2
    TEST AL, 1
    JZ  k4
    TEST AL, 2
    JZ  k5
    MOV AL, 6
    RET
k4: MOV AL, 4
    RET
k5: MOV AL, 5
    RET

; Row 2 (PC2 low): 7 8 9
row2:
    MOV AL, 0BH
    OR  AL, buzzer
    OUT portC, AL
    IN  AL, portB
    AND AL, 7
    CMP AL, 7
    JZ  row3
    TEST AL, 1
    JZ  k7
    TEST AL, 2
    JZ  k8
    MOV AL, 9
    RET
k7: MOV AL, 7
    RET
k8: MOV AL, 8
    RET

; Row 3 (PC3 low): * 0 #
row3:
    MOV AL, 07H
    OR  AL, buzzer
    OUT portC, AL
    IN  AL, portB
    AND AL, 7
    CMP AL, 7
    JZ  none
    TEST AL, 1
    JZ  kstar
    TEST AL, 2
    JZ  k0
    MOV AL, 0BH
    RET
kstar:
    MOV AL, 0AH
    RET
k0:
    MOV AL, 0
    RET
none:
    MOV AL, 0FFH
    RET
scankey ENDP

; ----------------------------
; Pattern selection via keypad
; ----------------------------
keypad PROC NEAR
    CALL getkey
    CMP AL, 1
    JE  p_l2r
    CMP AL, 2
    JE  p_alt
    CMP AL, 3
    JE  p_cnt
    CMP AL, 6
    JE  p_png
    ; Other keys do nothing
    RET

p_l2r: CALL pattern1
       RET
p_alt: CALL pattern2
       RET
p_cnt: CALL pattern3
       RET
p_png: CALL pattern6
       RET
keypad ENDP

; ----------------------------
; Pattern 1: Left to Right
; ----------------------------
pattern1 PROC
    PUSH AX
    PUSH CX
    MOV CX, 8
    MOV AL, 1
l2:
    OUT portA, AL
    CALL delay
    SHL AL, 1
    LOOP l2
    POP CX
    POP AX
    RET
pattern1 ENDP

; ----------------------------
; Pattern 2: Alternating bits
; ----------------------------
pattern2 PROC
    PUSH AX
    PUSH BX
    PUSH CX
    MOV CX, 8
    MOV AL, 01010101B
p2:
    OUT portA, AL
    CALL delay
    NOT AL
    LOOP p2
    POP CX
    POP BX
    POP AX
    RET
pattern2 ENDP

; ----------------------------
; Pattern 3: Counting up
; ----------------------------
pattern3 PROC
    PUSH AX
    PUSH BX
    PUSH CX
    MOV AL, 0
    MOV CX, 256
p3:
    OUT portA, AL
    CALL delay
    INC AL
    LOOP p3
    POP CX
    POP BX
    POP AX
    RET
pattern3 ENDP

; ----------------------------
; Pattern 6: Ping-Pong
; ----------------------------
pattern6 PROC
    PUSH AX
    PUSH BX
    PUSH CX
    MOV AL, 00000001B
    MOV BL, 1           ; left=1, right=0
p6:
    OUT portA, AL
    CALL delay
    CMP BL, 1
    JE  left

right:
    SHR AL, 1
    CMP AL, 01H
    JNE p6
    MOV BL, 1
    JMP p6

left:
    SHL AL, 1
    CMP AL, 80H
    JNE p6
    MOV BL, 0
    JMP p6

    POP CX
    POP BX
    POP AX
    RET
pattern6 ENDP

CODE ENDS
END START
