; Program to illustrate operation of Map Mask register when drawing
;  to memory that already contains data.
; By Michael Abrash.
global start

%include 'common.inc'

section .data data

section .code code
start:
    mov ax, data
    mov ds, ax
    mov ax, EGA_VIDEO_SEGMENT
    mov es, ax
    mov ax, 012h    ; 640x480
    int 10h

; Draw 24 10-scan-line high horizontal bars in green, 10 scan lines apart.
    SET_SC SC_MAP_MASK, 02h ; green plane only
    xor di, di
    mov al, 0ffh
    mov bp, 24              ; # bars to draw
.HorzBarLoop:
    mov cx, 80*10
    rep stosb
    add di, 80*10           ; next bar
    dec bp
    jnz .HorzBarLoop

; Fill screen with blue, using Map Mask register to enable writes
; to blue plane only.
    SET_SC SC_MAP_MASK, 01h ; blue plane only
    xor di, di
    mov cx, 80*480
    mov al, 0ffh
    rep stosb

    PAUSE_BEFORE_EXIT

section .stack stack
    resb 256
