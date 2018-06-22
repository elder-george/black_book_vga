; Program to demonstrate pixel drawing in 320x400 256-color
; mode on the VGA. Draws 8 lines to form an octagon, a pixel
; at a time. Draws 8 octagons in all, one on top of the other,
; each in a different color set. Although it's not used, a
; pixel read function is also provided.

global start
%include 'common.inc'

SCREEN_WIDTH             equ        320         ;# of pixels across screen
SCREEN_HEIGHT            equ        400         ;# of scan lines on screen

section code
start:
    mov ax, data
    mov ds, ax
    call Set320By400Mode   
; We're in 320x400 256-color mode. Draw each line in turn.
.ColorLoop:
    mov si, LineList
.LineLoop:
    mov cx, [si+LineControl.StartX]
    cmp cx, -1
    jz .LinesDone
    mov dx, [si+LineControl.StartY]
    mov bl, [si+LineControl.LineColor]
    mov bp, [si+LineControl.BaseLength]
    add bl, byte[BaseColor] ;adjust the line color according to BaseColor
.PixelLoop:
    push cx
    push dx
    call WritePixel.320x400
    pop dx
    pop cx
    add cx, [si+LineControl.LineXInc]
    add dx, [si+LineControl.LineYInc]
    dec bp  ; any more points?
    jnz .PixelLoop
    add si, LineControl.SIZE
    jmp .LineLoop
.LinesDone:
    WAIT_FOR_KEYPRESS
    inc byte[BaseColor]
    cmp byte[BaseColor], 8
    jb .ColorLoop
.exit:
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0

Set320By400Mode:
; First, go to normal 320x200 256-color mode, which is really a
; 320x400 256-color mode with each line scanned twice.
    SET_VIDEO_MODE MODE_V320x200x256
; Change CPU addressing of video memory to linear (not odd/even, chain, or chain 4), 
; to allow us to access all 256K of display memory. When this is done, VGA memory will look
; just like memory in modes 10h and 12h, except that each byte of display memory will control
; one 256-color pixel, with 4 adjacent pixels at any given address, one pixel per plane.
    GET_PORT SC, SC_MEMORY_MODE
    and al, ~08h    ; turn off chain 4
    or al,  04h     ; turn odd/even
    out dx, al
    GET_PORT GC, GC_MODE
    and al, ~10h    ; turn off odd/even
    out dx, al
    GET_PORT GC, GC_MISC
    and al, ~02h    ; turn off chain
    out dx, al
; Now clear the whole screen, since the mode 13h mode set only cleared 64K out of the 256K 
; of display memory. Do this before we switch the CRTC out of mode 13h, so we don't see 
; garbage on the screen when we make the switch.
    SET_PORT SC, SC_MAP_MASK, 0fh   ; enable write to all planes, to clear 4 pixels at a time
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    xor di, di
    mov ax, di
    mov cx, 8000h   ; number of words in 64k
    cld
    rep stosw
; Tweak the mode to 320x400 256-color mode by not scanning each
; line twice.
    GET_PORT CRTC, CRTC_MAX_SCAN_LINE
    and al, ~1fh    ; set max scan line = 0
    out dx, al
    GET_PORT CRTC, CRTC_UNDERLINE
    and al, ~40h            ; turn off doubleword
    out dx, al
    GET_PORT CRTC, CRTC_MODE_CONTROL
    or al, 40h  ; turn on the byte mode bit, so memory is scanned for video data in a purely
                ; linear way, just as in modes 10h and 12h
    out dx, al
    ret

; Draws a pixel in the specified color at the specified
; location in 320x400 256-color mode.
; Input:
;    CX = X coordinate of pixel
;    DX = Y coordinate of pixel
;    BL = pixel color
WritePixel.320x400:
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    mov ax, SCREEN_WIDTH/4  ; there are 4 pixels at each address, so each 320-pixel row
                            ; is 80 bytes wide in each plane.
    mul dx                  ; point to start of desired row
    push cx
    times 2 shr cx, 1       ; there're 4 pixels at each address, so divide X by 4
    add ax, cx
    mov di, ax
    pop cx
    and cl, 3              ; get the plane # of the pixel
    mov ah,1 
    shl ah, cl             ; set the bit corresponding to the plane
    SET_PORT SC, SC_MAP_MASK, ah
    mov [es:di], bl
    ret
; Reads the color of the pixel at the specified location in 320x400
; 256-color mode.
ReadPixel.320x400:
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    mov ax, SCREEN_WIDTH/4  ; there are 4 pixels at each address, so each 320-pixel row
                            ; is 80 bytes wide in each plane.
    mul dx                  ; point to start of desired row
    push cx
    times 2 shr cx, 1       ; there're 4 pixels at each address, so divide X by 4
    add ax, cx
    mov si, ax
    pop ax
    and al, 3
    mov ah, al
    SET_PORT GC, GC_READ_MAP, ah
    lodsb
    ret 

section data
BaseColor   db 0

STRUC LineControl
.StartX:    resw 1
.StartY:    resw 1
.LineXInc:  resw 1
.LineYInc:  resw 1
.BaseLength:resw 1
.LineColor: resb 1
.SIZE:
ENDSTRUC
; NASM's support for structures is surprisingly verbose, so making an ad hoc macro "ctor"
%macro aLineControl 6
istruc LineControl
    at LineControl.StartX,      dw %1
    at LineControl.StartY,      dw %2
    at LineControl.LineXInc,    dw %3
    at LineControl.LineYInc,    dw %4
    at LineControl.BaseLength,  dw %5
    at LineControl.LineColor,   db %6
iend
%endm
LineList:
    aLineControl 130, 110, 1,  0, 60, 0
    aLineControl 190, 110, 1,  1, 60, 1
    aLineControl 250, 170, 0,  1, 60, 2
    aLineControl 250, 230,-1,  1, 60, 3
    aLineControl 190, 290,-1,  0, 60, 4
    aLineControl 130, 290,-1, -1, 60, 5
    aLineControl  70, 230, 0, -1, 60, 6
    aLineControl  70, 170, 1, -1, 60, 7
    aLineControl  -1,   0, 0,  0,  0, 0

section stack stack
    resb 256