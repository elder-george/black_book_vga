; Program to illustrate one use of write mode 2 of the VGA and EGA by
; animating the image of an "A" drawn by copying it from a chunky
; bit-map in system memory to a planar bit-map in VGA or EGA memory.
;
; By Michael Abrash
global start

%include 'common.inc'

section .data data
SCREEN_WIDTH_IN_BYTES   equ     80
CurrentX            resw 1
CurrentY            resw 1
RemainingLength     resw 1
; Chunky bit-map image of a yellow "A" on a bright blue background
AImage:
        dw      13, 13          ;width, height in pixels
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h
        db      009h, 099h, 099h, 099h, 099h, 099h, 000h
        db      009h, 099h, 099h, 099h, 099h, 099h, 000h
        db      009h, 099h, 099h, 0e9h, 099h, 099h, 000h
        db      009h, 099h, 09eh, 0eeh, 099h, 099h, 000h
        db      009h, 099h, 0eeh, 09eh, 0e9h, 099h, 000h
        db      009h, 09eh, 0e9h, 099h, 0eeh, 099h, 000h
        db      009h, 09eh, 0eeh, 0eeh, 0eeh, 099h, 000h
        db      009h, 09eh, 0e9h, 099h, 0eeh, 099h, 000h
        db      009h, 09eh, 0e9h, 099h, 0eeh, 099h, 000h
        db      009h, 099h, 099h, 099h, 099h, 099h, 000h
        db      009h, 099h, 099h, 099h, 099h, 099h, 000h
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h

section .code code
start:
    mov ax, data
    mov ds, ax
    mov ax, 10h
    int 10h

    mov word [CurrentX], 0
    mov word [CurrentY], 200
    mov word [RemainingLength], 50

; Animate, repeating RemainingLength times. It's unnecessary to erase
; the old image, since the one pixel of blank fringe around the image
; erases the part of the old image not overlapped by the new image.
.AnimationLoop:
    mov bx, [CurrentX]
    mov cx, [CurrentY]
    mov si, AImage
    call DrawFromChunkyBitmap
    inc word[CurrentX]
    mov cx, 0
.DelayLoop:
    loop .DelayLoop

    dec word[RemainingLength]
    jnz .AnimationLoop

    PAUSE_BEFORE_EXIT

; Draw an image stored in a chunky-bit map into planar VGA/EGA memory
; at the specified location.
;
; Input:
;       BX = X screen location at which to draw the upper-left corner
;               of the image
;       CX = Y screen location at which to draw the upper-left corner
;               of the image
;       DS:SI = pointer to chunky image to draw, as follows:
;               word at 0: width of image, in pixels
;               word at 2: height of image, in pixels
;               byte at 4: msb/lsb = first & second chunky pixels,
;                       repeating for the remainder of the scan line
;                       of the image, then for all scan lines. Images
;                       with odd widths have an unused null nibble
;                       padding each scan line out to a byte width
;
; AX, BX, CX, DX, SI, DI, ES destroyed
DrawFromChunkyBitmap:
    cld
; Select write mode 2
    SET_GC GC_MODE, 2

; Enable writes to all 4 planes.
    SET_SC SC_MAP_MASK, PLANE_ALL
; Point ES:DI to the display memory byte in which the first pixel
; of the image goes, with AH set up as the bit mask to access that
; pixel within the addressed byte.
    mov ax, SCREEN_WIDTH_IN_BYTES
    mul cx
    mov di, ax   ; di = offset of start of top scan line
    mov cl, bl
    and cl, 111b
    mov ah, 80h         ; set AH to the bit mask for the
    shr ah, cl          ; initial pixel
    times 3 shr bx, 1   ; bx = X in bytes
    add di, bx
    mov bx, VGA_VIDEO_SEGMENT
    mov es, bx
; Get the width and height of the image.
    mov cx, [si]    ; cx = AImage.width
    times 2 inc si
    mov bx, [si]    ; bx = AImage.height
    times 2 inc si
    mov dx, GC_INDEX
    mov al, GC_BIT_MASK
    out dx, al      ;leave the GC Index register pointing
    inc dx          ; to the Bit Mask register
.RowLoop:
    push ax         ; ah = bit mask for initial pixel
    push cx         ; image.width
    push di         ; first pixel of current line
.ColumnLoop:
    mov al, ah
    out dx, al      ; set the bit mask for this pixel
    mov al, [es:di] ; load latches
    mov al, [si]    ; get next two pixels
    times 4 shr al, 1
    stosb           ; draw first pixel
    ror ah, 1       ; move mask to next pixel pos
    jc .CheckMorePixels1 ; is next pixel in the adjacent byte?
    dec di          ; no
.CheckMorePixels1:
    dec cx
    jz .AdvanceToNextScanLine
    mov al, ah
    out dx, al
    mov al, [es:di]
    lodsb ;get the same two chunky pixels again and advance pointer to the next pair
    stosb           ; draw second pixel
    ror ah, 1       ; move mask
    jc .CheckMorePixels2
    dec di
.CheckMorePixels2:
    loop .ColumnLoop
    jmp short .CheckMoreScanLines
.AdvanceToNextScanLine:
    inc si
.CheckMoreScanLines:
    pop di          ; first pixel of previous line
    pop cx          ; image.width
    pop ax          ; ah = bit mask for initial pixel

    add di, SCREEN_WIDTH_IN_BYTES ; move to next scan line
    dec bx
    jnz .RowLoop
.Done:
    ret

section .stack stack
    resb 256