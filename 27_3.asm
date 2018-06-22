global start

%include 'common.inc'

section code
start:
    mov ax, data
    mov ds, ax
    SET_VIDEO_MODE MODE_V640x350x16
; Colored pattern
    cld
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    mov ah, 3   ; initial pattern
    mov cx, 4   ; number of planes
    WITH_PORT SC, SC_MAP_MASK
.FillBitMap:
    mov al, 10h
    shr al, cl      ; generate map mask for this plane
    out dx, al      ; set map mask for this plane
    xor di, di
    mov al, ah
    push cx
    mov cx, 8000h   ; 32K words 
    rep stosw
    pop cx
    times 2 shl ah, 2
    loop .FillBitMap

; Show message
    SHOW_MESSAGE data, GStrikeAnyKeyMsg0
    WAIT_FOR_KEYPRESS
; save 8k of plane 2 that'll be used by the font
    SET_GC GC_READ_MAP, 2
    xor si, si
    MEMCPY data, Plane2Save, VGA_VIDEO_SEGMENT, si, Plane2Save.Size
; Switch to text mode preserving video memory
    SET_VIDEO_MODE (MODE_T80x50 | 080h)
;save the text mode bitmap
    xor si, si
    MEMCPY data, CharAttSave, TEXT_SEGMENT, si, TEXT_BUFFER_SIZE
; fill text mode screen with dots and show message
    xor di, di
    MEMSET_W TEXT_SEGMENT, di, (7 << 8)|'.', TEXT_BUFFER_SIZE

    SHOW_MESSAGE data, TStrikeAnyKeyMsg
    WAIT_FOR_KEYPRESS
; restore text mode screen
    xor di, di
    MEMCPY TEXT_SEGMENT, di, data, CharAttSave, TEXT_BUFFER_SIZE
; Return to mode 10h without clearing display memory.
    SET_VIDEO_MODE (MODE_V640x350x16 | 080h)    
; Restore the portion of plane 2 that was wiped out by the font.
    SET_SC SC_MAP_MASK, 4
    xor di, di
    MEMCPY VGA_VIDEO_SEGMENT, di, data, Plane2Save, Plane2Save.Size
; show message and exit
    SHOW_MESSAGE data, GStrikeAnyKeyMsg1
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50 
    EXIT 0

section data
GStrikeAnyKeyMsg0   db 0dh, 0ah, 'Graphics mode', 0dh, 0ah
                    db 'Strike any key to continue...', 0dh, 0ah, '$'
GStrikeAnyKeyMsg1   db 0dh, 0ah, 'Graphics mode again', 0dh, 0ah
                    db 'Strike any key to continue...', 0dh, 0ah, '$'
TStrikeAnyKeyMsg    db 0dh, 0ah, 'Text mode', 0dh, 0ah
                    db 'Strike any key to continue...', 0dh, 0ah,'$'
Plane2Save resb 2000h
Plane2Save.Size equ $-Plane2Save
TEXT_BUFFER_SIZE equ 80 * 50
CharAttSave resb TEXT_BUFFER_SIZE
CharAttSave.Size equ $-CharAttSave

section stack stack
    resb 256