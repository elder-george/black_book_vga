; Program to illustrate operation of data rotate and bit mask
;  features of Graphics Controller. Draws 8x8 character at
;  specified location, using VGA's 8x8 ROM font. Designed
;  for use with modes 0Dh, 0Eh, 0Fh, 10h, and 12h.
; By Michael Abrash.
;
global start

%include 'common.inc'

SCREEN_WIDTH_IN_BYTES   equ     044ah   ;offset of BIOS variable
FONT_CHARACTER_SIZE     equ     8       ;# bytes in each font char

section .data data
TEST_TEXT_ROW   equ     69      ;row to display test text at
TEST_TEXT_COL   equ     17      ;column to display test text at
TEST_TEXT_WIDTH equ     8       ;width of a character in pixels

TestString db 'Hello, world!',0 ;test string to print.
FontPointer  resd 1             ;font offset

section .code code
start:
    mov ax, data
    mov ds, ax

    SET_VIDEO_MODE MODE_V640x480x16
; Set driver to use the 8x8 font.
    mov ax, 01130h
    mov bh, 3
    int 10h
    call SelectFont

    mov si, TestString
    mov bx, TEST_TEXT_ROW
    mov cx, TEST_TEXT_COL
.StringOutLoop:
    lodsb
    test al, al                             
    jz .StringOutDone
    call DrawChar
    add cx, TEST_TEXT_WIDTH
    jmp .StringOutLoop
.StringOutDone:

    SET_GC GC_ROTATE, 0
    SET_GC GC_BIT_MASK, 0ffh

    PAUSE_BEFORE_EXIT
    ret

SelectFont:
    mov word[FontPointer], bp
    mov word[FontPointer+2], es
    ret

DrawChar: ; al - character, bx - row, cx - col
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds

    lds si, [FontPointer]
    mov dx, VGA_VIDEO_SEGMENT
    mov es, dx

; Calculate screen address of byte character starts in.
    push ds
    xor dx, dx
    mov ds,dx
    xchg ax, bx
    mov di, [ds:SCREEN_WIDTH_IN_BYTES]   ; BIOS screen width
    pop ds

    mul di              ; offset of start of a row
    push di             ; stack[top] = screen width
    mov di, cx          ; di = column
    and cl, 0111b       ; cl = cl % 8 - column in-byte address
    times 3 shr di, 1   ; di = cx / 8 - byte address
    add di, ax          ; point to a byte
    
; Calculate font address of character.
    xor bh, bh
    times 3 shl bx, 1   ; bx = bx*8, for 8bytes per character
    add si, bx

; Set up the GC rotation.
    SET_GC GC_ROTATE, cl

; Set up BH as bit mask for left half,
; BL as rotation for right half.
    mov bx, 0ffffh
    shr bh, cl      ; bh = 0ffh >> in-byte column
    neg cl          ; cl = -(in-byte column)
    add cl, 8       ;  ... + 8 = 8 - (in-byte-column)
    shl bl, cl      ; bl = 0ffh << (8 - in-byte column)

; Draw the character, left half first, then right half in the
; succeeding byte, using the data rotation to position the character
; across the byte boundary and then using the bit mask to get the
; proper portion of the character into each byte.
; Does not check for case where character is byte-aligned and
; no rotation and only one write is required.
    mov bp, FONT_CHARACTER_SIZE
    mov dx, GC_INDEX
    pop cx              ; cx = SCREEN_WIDTH_IN_BYTES
    times 2 dec cx      ; -2 because do two bytes for each char

.CharacterLoop:
; Set the bit mask for the left half of the character.
    mov al, GC_BIT_MASK
    mov ah, bh
    out dx, ax
; Get the next character byte & write it to display memory.
; (Left half of character.)
    mov al, [si]
    mov ah, [es:di]     ; load latches
    stosb           ; vmem[di++] = [si] & (0ffh >> in-byte column)
; Set the bit mask for the right half of the character.
    mov al, GC_BIT_MASK
    mov ah, bl
    out dx, ax
; Get the character byte again & write it to display memory.
; (Right half of character.)
    lodsb           ; al = [si++]
    mov ah, [es:di] ; load latches
    stosb           ; vmem[di++] = [si] & (0ffh << (8 - in-byte column))

; Point to next line of character in display memory.
    add di, cx
    dec bp
    jnz .CharacterLoop

.done:
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

section .stack stack
    resb 256