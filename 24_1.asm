; Program to illustrate operation of ALUs and latches of the VGA's
;  Graphics Controller.  Draws a variety of patterns against
;  a horizontally striped background, using each of the 4 available
;  logical functions (data unmodified, AND, OR, XOR) in turn to combine
;  the images with the background.
global start

VGA_VIDEO_SEGMENT       equ     0a000h  ;VGA display memory segment
SCREEN_HEIGHT           equ     350
SCREEN_WIDTH_IN_BYTES   equ     80
DEMO_AREA_HEIGHT        equ     336     ;# of scan lines in area
                                        ; logical function operation
                                        ; is demonstrated in
DEMO_AREA_WIDTH_IN_BYTES equ    40      ;width in bytes of area
                                        ; logical function operation
                                        ; is demonstrated in
VERTICAL_BOX_WIDTH_IN_BYTES equ 10      ;width in bytes of the box used to
                                        ; demonstrate each logical function
;
; VGA register equates.
;
GC_INDEX        equ     3ceh    ;GC index register
GC_ROTATE       equ     3       ;GC data rotate/logical function
                                ; register index
GC_MODE         equ     5       ;GC mode register index

section .data data
; String used to label logical functions.
LabelString db      'UNMODIFIED    AND       OR        XOR   '
LABEL_STRING_LENGTH     equ     $-LabelString
; Strings used to label fill patterns.
FillPatternFF   db      'Fill Pattern: 0FFh'
FILL_PATTERN_FF_LENGTH  equ     $ - FillPatternFF
FillPattern00   db      'Fill Pattern: 000h'
FILL_PATTERN_00_LENGTH  equ     $ - FillPattern00
FillPatternVert db      'Fill Pattern: Vertical Bar'
FILL_PATTERN_VERT_LENGTH        equ     $ - FillPatternVert
FillPatternHorz db      'Fill Pattern: Horizontal Bar'
FILL_PATTERN_HORZ_LENGTH equ    $ - FillPatternHorz

; Macro to set indexed register INDEX of GC chip to SETTING.
%macro SET_GC 2
%define INDEX %1
%define SETTING %2
    mov dx, GC_INDEX
    mov ax, ((SETTING << 8) | INDEX)
    out dx, ax
%endm

%define OP_NOP 0
%define OP_AND 08h
%define OP_OR  10h
%define OP_XOR 18h

; Macro to call BIOS write string function to display text string
;  TEXT_STRING, of length TEXT_LENGTH, at location ROW,COLUMN.
%macro TEXT_UP 4
%define TEXT_STRING %1
%define TEXT_LENGTH %2
%define ROW         %3
%define COLUMN      %4
    mov ah, 13h
    mov bp, TEXT_STRING
    mov cx, TEXT_LENGTH
    mov dx, (ROW<<8)|COLUMN
    xor al, al  ;string is chars only, cursor not moved
    mov bl, 7   ;text attribute is white (light gray)
    int 10h
%endm



section .code
start:
    cld
    mov ax, data
    mov ds, ax

    mov ax, 010h
    int 10h

    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
; Draw background of horizontal bars.
    mov dx, SCREEN_HEIGHT/4 ;# of bars to draw (each 4 pixels high)
    xor di, di              ;start at offset 0 in display memory
    mov ax, 0ffffh          ;fill pattern for light areas of bars
    mov bx, DEMO_AREA_WIDTH_IN_BYTES / 2 ;length of each bar
    mov si,SCREEN_WIDTH_IN_BYTES - DEMO_AREA_WIDTH_IN_BYTES
    mov     bp,(SCREEN_WIDTH_IN_BYTES * 3) - DEMO_AREA_WIDTH_IN_BYTES
.BackgroundLoop:
    mov cx,bx               ;length of bar
    rep stosw               ;draw top half of bar
    add di, si              ;point to start of bottom half of bar
    mov cx, bx              ;length of bar
    rep stosw               ;draw bottom half of bar
    add di, bp              ;point to start of top of next bar
    dec dx
    jnz .BackgroundLoop

; Draw vertical boxes filled with a variety of fill patterns
;  using each of the 4 logical functions in turn.
    SET_GC GC_ROTATE, OP_NOP ;select data unmodified
    mov di, 0
    call DrawVerticalBox

    SET_GC GC_ROTATE, OP_AND ; &
    mov di, 10
    call DrawVerticalBox

    SET_GC GC_ROTATE, OP_OR   ; |
    mov di, 20
    call DrawVerticalBox

    SET_GC GC_ROTATE, OP_XOR ; ^
    mov di, 30
    call DrawVerticalBox

; Reset the logical function to data unmodified, the default state.
    SET_GC GC_ROTATE, OP_NOP ;select data unmodified    

    push ds
    pop es

    TEXT_UP LabelString, LABEL_STRING_LENGTH, 24, 0
    TEXT_UP FillPatternFF, FILL_PATTERN_FF_LENGTH, 3, 42
    TEXT_UP FillPattern00, FILL_PATTERN_00_LENGTH, 9, 42
    TEXT_UP FillPatternVert, FILL_PATTERN_VERT_LENGTH, 15, 42
    TEXT_UP FillPatternHorz, FILL_PATTERN_HORZ_LENGTH, 21, 42

.WaitForKey:
    mov     ah,1
    int     16h
    jz      .WaitForKey

.exit:
    mov     ah,0    ;clear key that we just detected
    int     16h
;
    mov     ax,3    ;reset to text mode
    int     10h
;
    mov     ah,4ch  ;exit to DOS
    int     21h



%macro DRAW_BOX_QUARTER 2
    %define FILL    %1
    %define WIDTH   %2
    mov al, FILL
    mov dx, DEMO_AREA_HEIGHT /4
%%RowLoop:
    mov cx, WIDTH
%%ColLoop:
    mov ah, [es:di] ;load display memory contents into GC latches 
                    ; (we don't actually care about value read into AH)
    stosb
    loop %%ColLoop
    add di, SCREEN_WIDTH_IN_BYTES - WIDTH
    dec     dx
    jnz %%RowLoop
%endm   

DrawVerticalBox:
    DRAW_BOX_QUARTER 0ffh, VERTICAL_BOX_WIDTH_IN_BYTES  ; first fill pattern: solid fill
    DRAW_BOX_QUARTER 0, VERTICAL_BOX_WIDTH_IN_BYTES     ; second fill pattern: empty fill
    DRAW_BOX_QUARTER 033h, VERTICAL_BOX_WIDTH_IN_BYTES  ; third fill pattern: double-pixel wide vertical bars
    
    mov dx,DEMO_AREA_HEIGHT / (4 * 4)
    xor ax,ax
    mov si,VERTICAL_BOX_WIDTH_IN_BYTES  ;width of fill area
.HorzBarLoop:
    dec     ax              ;0ffh fill (smaller to do word than byte DEC)
    mov     cx,si           ;width to fill
.HBLoop1:
    mov bl, byte [es:di]      ;load latches (don't care about value)
    stosb                   ;write solid pattern, through ALUs
    loop    .HBLoop1

    add     di,SCREEN_WIDTH_IN_BYTES - VERTICAL_BOX_WIDTH_IN_BYTES
    mov     cx,si           ;width to fill
.HBLoop2:
    mov bl, byte [es:di]    ;load latches (don't care about value)
    stosb                   ;write solid pattern, through ALUs
    loop    .HBLoop2

    add di,SCREEN_WIDTH_IN_BYTES - VERTICAL_BOX_WIDTH_IN_BYTES          
    inc     ax              ;0 fill (smaller to do word than byte DEC)
    mov     cx,si           ;width to fill
.HBLoop3:
    mov bl, byte [es:di]    ;load latches (don't care about value)
    stosb                   ;write empty pattern, through ALUs
    loop    .HBLoop3

    add     di,SCREEN_WIDTH_IN_BYTES - VERTICAL_BOX_WIDTH_IN_BYTES
    mov     cx,si           ;width to fill
.HBLoop4:
    mov     bl,[es:di]      ;load latches
    stosb                   ;write empty pattern, through ALUs
    loop    .HBLoop4
    add     di,SCREEN_WIDTH_IN_BYTES - VERTICAL_BOX_WIDTH_IN_BYTES
    dec     dx
    jnz     .HorzBarLoop
    ret

section .stack stack
    resb 512
