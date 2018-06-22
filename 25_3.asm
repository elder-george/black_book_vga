; Program to illustrate operation of set/reset circuitry to force
;  setting of memory that already contains data.
; By Michael Abrash.
global start

%include 'common.inc'

NUMBER_OF_BARS  EQU 24
BYTES_PER_BAR   EQU 80*10

BYTES_PER_SCREEN EQU 480*80


section .stack stack
    resb 256

section .data data

section .code code
start:
    mov ax, data
    mov ds, ax

    mov ax, 012h
    int 10h

    mov ax, EGA_VIDEO_SEGMENT
    mov es, ax

; Draw 24 10-scan-line high horizontal bars in green, 10 scan lines apart.
    ENABLE_PLANE PLANE_GREEN
    xor di, di
    mov al, 0ffh
    mov bp, NUMBER_OF_BARS

.HorzBarLoop:
    mov cx, BYTES_PER_BAR
    rep stosb
    add di, BYTES_PER_BAR
    dec bp
    jnz .HorzBarLoop

; Fill screen with blue, using set/reset to force plane 0 to 1's and all other plane to 0's.
    ENABLE_PLANE PLANE_ALL
    SET_GC GC_ENABLE_SET_RESET, PLANE_ALL  ; CPU data to all planes will be
                                            ; replaced by set/reset value
    SET_GC GC_SET_RESET, PLANE_BLUE ;set/reset value is 0ffh for plane 0
                                ; (the blue plane) and 0 for other planes
    xor di, di
    mov cx, BYTES_PER_SCREEN
    mov al, 0ffh                ;since set/reset is enabled for all planes, 
                                ; the CPU data is ignored - only the act of 
                                ; writing is important
    rep stosb                   ; fill all planes

; Turn off set/reset.
    SET_GC GC_ENABLE_SET_RESET, PLANE_NONE

    PAUSE_BEFORE_EXIT
    ret