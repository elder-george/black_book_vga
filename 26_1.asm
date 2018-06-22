; Program to illustrate operation of write mode 3 of the VGA.
;  Draws 8x8 characters at arbitrary locations without disturbing
;  the background, using VGA's 8x8 ROM font.  Designed
;  for use with modes 0Dh, 0Eh, 0Fh, 10h, and 12h.
; Runs only on VGAs (in Models 50 & up and IBM Display Adapter
;  and 100% compatibles).
; By Michael Abrash

global start
%include 'common.inc'

section .data data
SCREEN_WIDTH_IN_BYTES   equ     044ah   ;offset of BIOS variable
FONT_CHARACTER_SIZE     equ     8
TEST_TEXT_ROW   equ     69      ;row to display test text at
TEST_TEXT_COL   equ     17      ;column to display test text at
TEST_TEXT_WIDTH equ     8       ;width of a character in pixels
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
    mov ax, 0deadh  ;because of set/reset, the value written actually doesn't matter
    rep stosw       ;fill with blue
; Set driver to use the 8x8 font.
    mov     ah,11h          ;VGA BIOS character generator function,
    mov     al,30h          ; return info subfunction
    mov     bh,3            ;get 8x8 font pointer
    int     10h
    call    SelectFont

; Print the test string, cycling through colors.
    mov si, TestString
    mov bx, TEST_TEXT_ROW
    mov cx, TEST_TEXT_COL
    mov ah, 0               ; initial color
.StringOutLoop:
    lodsb
    test al, al
    jz .StringOutDone
    push ax
    call DrawChar
    pop ax
    inc ah
    and ah, 0fh             ; colors range from 0 to 15
    add cx, TEST_TEXT_WIDTH
    jmp .StringOutLoop
.StringOutDone:
    PAUSE_BEFORE_EXIT

; Draw a text character
; Input:
;  AL = character to draw
;  AH = color to draw character in (0-15)
;  BX = row to draw text character at
;  CX = column to draw text character at
;
;  Forces ALU function to "move".
;  Forces write mode 3.
DrawChar:
    multipush ax, bx, cx, dx, si, di, bp, ds

    push ax  ; preserve character to draw
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

    lds si, [FontPointer]
    mov dx, VGA_VIDEO_SEGMENT
    mov es, dx

; Calculate screen address of byte character starts in.
    pop ax
    
    push ds
    xor dx, dx
    mov ds, dx
    xchg ax, bx
    mov di, [ds:SCREEN_WIDTH_IN_BYTES]
    pop ds

    mul di
    push di
    mov di, cx
    and cl, 0111b
    times 3 shr di,1
    add di, ax
; Calculate font address of character.
    xor bh, bh
    times 3 shl bx,1
    add si, bx      ; offset in font segment of character
; Set up the GC rotation. In write mode 3, this is the rotation
; of CPU data before it is ANDed with the Bit Mask register to
; form the bit mask. Force the ALU function to "move". Uses the
; readability of VGA registers to leave reserved bits unchanged.
    GET_GC GC_ROTATE
    and al, 0e0h
    or al, cl
    out dx, al

; Set up BH as bit mask for left half, BL as rotation for right half.
    mov bx, 0ffffh
    shr bh, cl
    neg cl
    add cl, 8
    shl bl, cl
; Draw the character, left half first, then right half in the
; succeeding byte, using the data rotation to position the character
; across the byte boundary and then using write mode 3 to combine the
; character data with the bit mask to allow the set/reset value (the
; character color) through only for the proper portion (where the
; font bits for the character are 1) of the character for each byte.
; Wherever the font bits for the character are 0, the background
; color is preserved               
    mov bp, FONT_CHARACTER_SIZE
    mov dx, GC_INDEX
    pop cx              ; cx = screen width
    times 2 dec cx
.CharacterLoop:
    mov al, GC_BIT_MASK
    mov ah, bh
    out dx, ax

    mov al, [si]
    mov ah, [es:di] ; load latches
    stosb
; Set the bit mask for the right half of the character.
    mov al, GC_BIT_MASK
    mov ah, bl
    out dx, ax

    lodsb
    mov ah, [es:di] ; load latches
    stosb
; Point to next line of character in display memory.
    add di, cx

    dec bp
    jnz .CharacterLoop
.done:
    multipop ax, bx, cx, dx, si, di, bp, ds
    ret

; Set the pointer to the font to draw from to ES:BP.
SelectFont:
    mov     word [FontPointer], bp       ;save pointer
    mov     word [FontPointer+2], es
    ret

section .stack stack
    resb 256