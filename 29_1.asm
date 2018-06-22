; Program to put up a mode 10h EGA graphics screen, then save it
; to the file SNAPSHOT.SCR.
global start

%include 'common.inc'
%include 'dos_api.inc'

DISPLAYED_SCREEN_SIZE equ 640/8*350

section stack stack
    resb 256

section data
SampleText       db    'This is bit-mapped text, drawn in hi-res '
                 db    'EGA graphics mode 10h.', 0dh, 0ah, 0ah
                 db    'Saving the screen (including this text)...'
                 db    0dh, 0ah, '$'
Filename         db    'SNAPSHOT.SCR',0   ;name of file we're saving to
Dir              db    'tst',0
ErrMsg1          db    '*** Could not open SNAPSHOT.SCR ***',0dh,0ah,'$'
ErrMsg2          db    '*** Error writing to SNAPSHOT.SCR ***',0dh,0ah,'$'
WaitKeyMsg       db    0dh, 0ah, 'Done. Press any key to end...',0dh,0ah,'$'
Handle           resw  1                           ;handle of file we're saving to
Plane            resb  1                           ;plane being read


section code
start:
    mov ax, data
    mov ds, ax

    SET_VIDEO_MODE MODE_V640x350x16

    SHOW_MESSAGE data, SampleText
    WAIT_FOR_KEYPRESS
    FILE_DELETE Filename
    ;xor cx, cx          ; default attributes
    mov cx, 2
    FILE_CREATE Filename, cx
    mov word[Handle], ax
    jnc .SaveTheScreen
    SHOW_MESSAGE data, ErrMsg1
    jmp .exit
.SaveTheScreen:
    mov byte[Plane], 0
.SaveLoop:
    SET_GC GC_READ_MAP, [Plane]
    xor dx,dx
    push ds
    FILE_WRITE [Handle], VGA_VIDEO_SEGMENT, dx, DISPLAYED_SCREEN_SIZE  
    pop ds
    cmp ax, DISPLAYED_SCREEN_SIZE
    je .SaveLoopBottom
    SHOW_MESSAGE data, ErrMsg2
    jmp .CloseFile
.SaveLoopBottom:
    mov al, [Plane]
    inc al
    mov [Plane], al
    cmp al, 3
    jbe .SaveLoop
.CloseFile:
    FILE_CLOSE [Handle]
.exit:
    SHOW_MESSAGE data, WaitKeyMsg
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0
