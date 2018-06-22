EGA_VIDEO_SEGMENT       equ     0a000h  ;EGA display memory segment
VGA_VIDEO_SEGMENT       equ     EGA_VIDEO_SEGMENT  ;VGA display memory segment
TEXT_SEGMENT            equ     0b800h

; VGA register equates.
SC_INDEX        equ     3c4h    ;SC index register
SC_MAP_MASK     equ     2       ;SC map mask register
SC_MEMORY_MODE  equ     4


GC_INDEX        equ     3ceh    ;GC index register
GC_SET_RESET    equ     0
GC_ENABLE_SET_RESET equ 1       ;GC enable set/reset register
GC_COLOR_COMPARE    equ 2       ; Color Compare register index in GC
GC_ROTATE       equ     3       ;GC data rotate/logical function register index
GC_READ_MAP     equ     4
GC_MODE         equ     5       ;GC Mode register index
GC_MISC         equ     6
GC_BIT_MASK     equ     8       ;GC bit mask register index

INPUT_STATUS_0          equ     3dah
DE_MASK                 equ     01h
VSYNC_MASK              equ     08h

CRTC_INDEX              equ     3d4h
CRTC_MAP_MASK           equ     2
CRTC_MEMORY_MODE        equ     4
CRTC_OVERFLOW           equ     7
CRTC_MAX_SCAN_LINE      equ     9
CRTC_START_ADDRESS_HIGH equ     0ch
CRTC_START_ADDRESS_LOW  equ     0dh
CRTC_HOFFSET            equ     13h
CRTC_UNDERLINE          equ     14h
CRTC_MODE_CONTROL       equ     17h
CRTC_LINE_COMPARE       equ     18h

AC_INDEX                equ    3c0h         ;Attribute Controller Index reg
AC_MODE_CONTROL         equ    10h          ;index of Mode Control reg in AC
AC_PEL_PANNING          equ    13h          ;index of Pel Panning reg in AC
AC_PRESERVE_COLOR       equ    20h          ; OR with a value to not turn off video memory

%macro WITH_PORT 2
%define PRT %{1}_INDEX
%define INDEX %2
    mov dx, PRT
    mov al, INDEX
    out dx, al
    inc dx
%endm

%macro SET_PORT 3
%define PREFIX %1
%define INDEX %2
%define SETTING %3
    WITH_PORT PREFIX, INDEX
    mov al, SETTING
    out dx, al
    dec dx
%endm

%macro GET_PORT 2
%define PREFIX %1
%define INDEX %2
%define SETTING %3
    WITH_PORT PREFIX, INDEX
    jmp $+2
    in al, dx
%endm

%macro SET_SC 2
%define INDEX %1
%define SETTING %2
    WITH_PORT SC, INDEX
    mov al, SETTING
    out dx, al
    dec dx
%endm

%macro SET_GC 2
%define INDEX %1
%define SETTING %2
    WITH_PORT GC, INDEX
    mov al, SETTING
    out dx, al
    dec dx
%endm

%macro GET_GC 1
%define INDEX %1
    WITH_PORT GC, INDEX
    in al, dx
%endm

PLANE_NONE  EQU 0
PLANE_BLUE  EQU 01
PLANE_GREEN EQU 02
PLANE_RED   EQU 04
PLANE_INTENS EQU 08
PLANE_ALL   EQU 0fh

%macro ENABLE_PLANE 1
%define PLANE %1
    SET_SC SC_MAP_MASK, PLANE
%endm

MODE_V640x350x16    equ 10h
MODE_V320x200x256   equ 13h
MODE_T80x50         equ 03h

; Waits for the leading edge of the vertical sync pulse.
WaitForVerticalSyncStart:
     mov     dx,INPUT_STATUS_0
.WaitNoSync:
     in      al,dx
     test    al,08h
     jnz     .WaitNoSync
.WaitSync:
     in      al,dx
     test    al,08h
     jz      .WaitSync
     ret
; Waits for the trailing edge of the vertical sync pulse.
WaitForVerticalSyncEnd:
    mov dx, INPUT_STATUS_0
.WaitSync:
    in al, dx
    test al, 08h
    jz .WaitSync
.WaitSyncEnd:
    in al, dx
    test al, 08h
    jnz  .WaitSyncEnd
    ret

WaitDisplayEnable:
        mov     dx,INPUT_STATUS_0
.WaitDELoop:
        in      al,dx
        and     al,DE_MASK
        jnz     .WaitDELoop
        ret


%macro MEMCPY 5
%define DST_SEG %1
%define DST_OFF %2
%define SRC_SEG %3
%define SRC_OFF %4
%define SIZE_IN_BYTES %5
    mov ax, DST_SEG
    mov es, ax
    mov ax, SRC_SEG
    mov ds, ax
    mov si, SRC_OFF
    mov di, DST_OFF
    mov cx, SIZE_IN_BYTES /2
    rep movsw
%endmacro

%macro MEMSET_W 4
    %define DST_SEG %1
    %define DST_OFF %2
    %define VAL     %3
    %define SIZE_IN_BYTES %4
    mov ax, DST_SEG
    mov es, ax
    mov di, DST_OFF
    mov ax, VAL
    mov cx, SIZE_IN_BYTES/2
    rep stosw
%endmacro

%macro SET_VIDEO_MODE 1
%define MODE %1
    mov ax, (MODE & 00ffh)
    int 10h
%endmacro

%macro SET_CURSOR_POS 2
%define X %1
%define Y %2
    mov ah, 2
    xor bh, bh
    mov dh, Y
    mov dl, X
    int 10h
%endmacro

%macro CHECK_KEYPRESS 0
    mov ah, 0bh
    int 21h
%endm

%macro WAIT_FOR_KEYPRESS 0
    mov ah, 01h
    int 21h
%endmacro


%macro SHOW_MESSAGE 2
%define MSG_SEG %1
%define MSG_OFF %2
    mov ax, MSG_SEG
    mov ds, ax
    mov dx, MSG_OFF
    mov ah, 09h
    int 21h
%endmacro

%macro EXIT 1
    mov ax, (4ch<<8 | %1)
    int 21h
%endmacro

%macro PAUSE_BEFORE_EXIT 0
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0
%endmacro