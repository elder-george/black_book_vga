; Program to restore a mode 10h EGA graphics screen from
; the file SNAPSHOT.SCR.
global start
%include 'common.inc'
%include 'dos_api.inc'

section stack stack
    resb 256

DISPLAYED_SCREEN_SIZE       equ  (640/8)*350

section data
    Filename         db          'SNAPSHOT.SCR',0   ;name of file we're restoring from
    ErrMsg1          db          '*** Could not open SNAPSHOT.SCR ***',0dh,0ah,'$'
    ErrMsg2          db          '*** Error reading from SNAPSHOT.SCR ***',0dh,0ah,'$'
    WaitKeyMsg       db          0dh, 0ah, 'Done. Press any key to end...',0dh,0ah,'$'
    Handle           resw 1     ;handle of file we're restoring from
    Plane            resb 1     ;plane being written

section code
start:
    mov ax, data
    mov ds, ax
    SET_VIDEO_MODE MODE_V640x350x16
    FILE_OPEN Filename, 0
    mov [Handle], ax
    jnc .RestoreTheScreen
    SHOW_MESSAGE data, ErrMsg1
    jmp .exit
.RestoreTheScreen:
    mov byte[Plane], 0
.RestoreLoop:
    mov cl, [Plane]
    mov al, 1
    shl al, cl
    SET_SC SC_MAP_MASK, al
    xor dx, dx
    push ds
    FILE_READ [Handle], VGA_VIDEO_SEGMENT, dx, DISPLAYED_SCREEN_SIZE
    pop ds
    jc .ReadError
    cmp ax, DISPLAYED_SCREEN_SIZE
    je .RestoreLoopBottom
.ReadError:
    SHOW_MESSAGE data, ErrMsg2
    jmp .CloseFile
.RestoreLoopBottom:
    mov al, [Plane]
    inc al
    mov [Plane], al
    cmp al, 3
    jbe .RestoreLoop
.CloseFile:
    FILE_CLOSE [Handle]
.exit:
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0