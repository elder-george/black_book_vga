; Program to illustrate use of read mode 1 (color compare mode)
; to detect collisions in display memory. Draws a yellow line on a
; blue background, then draws a perpendicular green line until the
; yellow line is reached.
;
; By Michael Abrash
global start
%include 'common.inc'

COLOR_BLUE      equ 1
COLOR_YELLOW    equ 14
COLOR_GREEN     equ 2

SCREEN_WIDTH    equ 640
SCREEN_HEIGHT   equ 350

section code
start:
    cld
    SET_VIDEO_MODE MODE_V640x350x16
; fill screen with blue
    mov al, COLOR_BLUE
    call SelectSetResetColor
    xor di, di
    MEMSET_W VGA_VIDEO_SEGMENT, di, 0, 7000h  ; the value written actually doesn't matter:
                                              ; the data is provided by set/reset
    mov al, COLOR_YELLOW
    call SelectSetResetColor
    SET_GC GC_BIT_MASK, 10h
    mov di, 40
    mov cx, SCREEN_HEIGHT
.VLineLoop:
    mov al, byte [es:di]    ; Load the latches
    stosb                   ; write pixel with set/reset (al is ignored)
    add di, (SCREEN_WIDTH/8)-1
    loop .VLineLoop
; Select write mode 0 and read mode 1
    SET_GC GC_MODE, 00001000b  ; bit 3=1 is read mode 1, bits 1 & 0=00 is write mode 0
; Draw a horizontal green line, one pixel at a time, from left
; to right until color compare reports a yellow pixel is encountered.
    mov al, COLOR_GREEN
    call SelectSetResetColor
    SET_GC GC_COLOR_COMPARE, COLOR_YELLOW
    WITH_GC GC_BIT_MASK
    mov al, 80h             ; initial mask
    mov di, 100*SCREEN_WIDTH/8
.HLineLoop:
    mov ah, byte [es:di]; "color compare" read + latches load
    and ah, al          ; is the pixel of current interest yellow?
    jnz .exit
    out dx, al          ; set the Bit Mask register so that we modify only the pixel of interest
    mov [es:di], al     ; draw the pixel with set/reset value
    ror al, 1           ; sift pixel mask to the next pixel
    adc di, 0           ; if the pixel mask wrapped, advance the display memory offset

; delay
;    mov cx, 0
;.DelayLoop:
;    loop .DelayLoop
    jmp .HLineLoop

.exit:
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0

; Enables set/reset for all planes, and sets the set/reset color
; to AL.
SelectSetResetColor:
    push ax
    WITH_GC GC_SET_RESET
    pop ax
    out dx, al
    SET_GC GC_ENABLE_SET_RESET, PLANE_ALL
    ret

section stack stack
    resb 256