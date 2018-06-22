; Program to illustrate high-speed text-drawing operation of write mode 3 of the VGA.
;  Draws a string of 8x14 characters at arbitrary locations without disturbing the background, 
; using VGA's 8x14 ROM font.
;  Designed for use with modes 0Dh, 0Eh, 0Fh, 10h, and 12h.
; Runs only on VGAs (in Models 50 & up and IBM Display Adapter and 100% compatibles).
; By Michael Abrash
;
global start
%include 'common.inc'

section .data data
SCREEN_WIDTH_IN_BYTES   equ     044ah   ;offset of BIOS variable
FONT_CHARACTER_SIZE     equ     14
TEST_TEXT_ROW   equ     69      ;row to display test text at
TEST_TEXT_COL   equ     17      ;column to display test text at
TEST_TEXT_COLOR equ     0fh
TestString db 'Hello, world!',0 ;test string to print.
FontPointer  resd 1             ;font offset

section .code code
start:
    cld
    mov ax, data
    mov ds, ax

    SET_VIDEO_MODE MODE_V640x480x16

    GET_GC GC_SET_RESET
    and al, 0f0h
    or al, 1
    out dx, al
    dec dx
    
    GET_GC GC_ENABLE_SET_RESET
    and al, 0f0h
    or al, 0fh
    out dx, al

    mov dx, VGA_VIDEO_SEGMENT
    mov es, dx
    xor di, di
    mov cx, 8000h   ;fill all 32k words
    mov ax, 0FFFFh  ;because of set/reset, the value written actually doesn't matter
    rep stosw       ;fill with blue
; Set driver to use the 8x8 font.
    mov     ah,11h          ;VGA BIOS character generator function,
    mov     al,30h          ; return info subfunction
    mov     bh,2            ;get 8x14 font pointer
    int     10h
    call    SelectFont

; Print the test string, cycling through colors.
    mov si, TestString
    mov bx, TEST_TEXT_ROW
    mov cx, TEST_TEXT_COL
    mov ah, TEST_TEXT_COLOR            ; initial color
    call DrawString
.StringOutDone:
    PAUSE_BEFORE_EXIT

DrawString:
    multipush ax, bx, cx, dx, si, di, bp, ds
; Set up set/reset to produce character color, using the readability
; of VGA register to preserve the setting of reserved bits 7-4.
    GET_GC GC_SET_RESET
    and al, 0f0h
    and ah, 0fh
    or al, ah
    out dx, al
; Select write mode 3, using the readability of VGA registers
; to leave bits other than the write mode bits unchanged.
    GET_GC GC_MODE
    or al, 3
    out dx, al

    mov dx, VGA_VIDEO_SEGMENT
    mov es, dx

; Calculate screen address of byte character starts in.
    push ds
    xor dx, dx
    mov ds, dx
    mov di, [ds:SCREEN_WIDTH_IN_BYTES]
    pop ds

    mov ax, bx      ; row
    mul di
    push di
    mov di, cx
    and cl, 0111b
    times 3 shr di, 1
    add di, ax

; Set up the GC rotation. In write mode 3, this is the rotation
; of CPU data before it is ANDed with the Bit Mask register to
; form the bit mask. Force the ALU function to "move". Uses the
; readability of VGA registers to leave reserved bits unchanged.
    GET_GC GC_ROTATE
    and al, 0e0h
    or al, cl
    out dx, al
; Set up BH as bit mask for left half, BL as rotation for right half.
    mov     bx,0ffffh
    shr     bh,cl
    neg     cl
    add     cl,8
    shl     bl,cl

    pop cx
    
    push si
    push di
    push bx

    SET_GC GC_BIT_MASK, bh

.LeftHalfLoop:
    lodsb
    test al, al
    jz .LeftHalfLoopDone
    call CharacterUp
    inc di
    jmp .LeftHalfLoop
.LeftHalfLoopDone:
    pop bx
    pop di
    pop si

    inc di  ; right portion of each character is across byte boundary
; Set the bit mask for the right half of the character.
    SET_GC GC_BIT_MASK, bl
.RightHalfLoop:
    lodsb
    test al, al    
    jz .RightHalfLoopDone
    call CharacterUp
    inc di
    jmp .RightHalfLoop
.RightHalfLoopDone:

.Done:
    multipop ax, bx, cx, dx, si, di, bp, ds
    ret

CharacterUp:
    multipush cx, si, di, ds
    
    lds si, [FontPointer]
; Calculate font address of character.
    mov bl, FONT_CHARACTER_SIZE
    mul bl
    add si, ax

    mov bp, FONT_CHARACTER_SIZE
    dec cx  ; one byte per char
.CharacterLoop:
    lodsb
    mov ah, [es:di]
    stosb

    add di, cx

    dec bp
    jnz .CharacterLoop

.Done:
    multipop cx, si, di, ds
    ret

; Set the pointer to the font to draw from to ES:BP.
SelectFont:
    mov     word [FontPointer], bp       ;save pointer
    mov     word [FontPointer+2], es
    ret

section .stack stack
    resb 256