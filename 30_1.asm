global start

%include 'common.inc'

IS_VGA          equ 1   ;set to 0 to assemble for EGA
WORD_OUTS_OK    equ 1   ;set to 0 to assemble for
                        ; computers that can't handle
                        ; word outs to indexed VGA registers




SCREEN_WIDTH    equ 640
SCREEN_HEIGHT   equ 350

TEXT_LINE_NUM   equ 25

BACKGROUND_PATTER_START equ 8000h

section code
start:
    mov ax, data
    mov ds, ax
    SET_VIDEO_MODE MODE_V640x350x16
; Put text into display memory starting at offset 0, with each row
; labelled as to number. This is the part of memory that will be
; displayed in the split screen portion of the display.
    mov cx, TEXT_LINE_NUM  ; number of lines of text to draw
.FillSplitScreenLoop:
    mov dh, TEXT_LINE_NUM
    sub dh, cl
    xor dl, dl
    SET_CURSOR_POS dl, dh
    mov al, TEXT_LINE_NUM
    sub al, cl
    aam         ; ah = al / 10, al = al % 10
    xchg al, ah
    add ax, '00'
    mov [DigitInsert], ax
    SHOW_MESSAGE data, SplitScreenMsg
    loop .FillSplitScreenLoop

; Fill display memory starting at 8000h with a diagonally striped
; pattern.
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    mov di, BACKGROUND_PATTER_START
    mov dx, SCREEN_HEIGHT
    mov ax, 1000100010001000b  ; starting pattern
    cld
.RowLoop:
    mov cx, SCREEN_WIDTH/8/2    ; fill one scan line a word at a time
    rep stosw
    ror ax, 1
    dec dx
    jnz .RowLoop

; Set the start address to 8000h and display that part of memory.
    mov word [StartAddress], BACKGROUND_PATTER_START
    call SetStartAddress

; Slide the split screen half way up the screen and then back down
; a quarter of the screen.
    mov word [SplitScreenLine], SCREEN_HEIGHT-1 ;set the initial line just off the bottom of the screen
    mov cx, SCREEN_HEIGHT/2
    call SplitScreenUp
    mov cx, SCREEN_HEIGHT/4
    call SplitScreenDown
; Now move up another half a screen and then back down a quarter.
    mov cx, SCREEN_HEIGHT/2
    call SplitScreenUp
    mov cx, SCREEN_HEIGHT/4
    call SplitScreenDown
; Finally move up to the top of the screen.
    mov    cx,SCREEN_HEIGHT/2-2
    call   SplitScreenUp
    WAIT_FOR_KEYPRESS

; Turn the split screen off.
    mov word [SplitScreenLine], 0ffffh

    call SetSplitScreenScanLine
    WAIT_FOR_KEYPRESS

; Display the memory at 0 (the same memory the split screen displays).
    mov    word [StartAddress],0
    call SetStartAddress
; Flip between the split screen and the normal screen every 10th
; frame until a key is pressed.
.FlipFlop:
    xor  word [SplitScreenLine],0ffffh
    call SetSplitScreenScanLine
    mov cx, 10
.CountVerticalSyncsLoop:
    call WaitForVerticalSyncEnd
    loop .CountVerticalSyncsLoop
    CHECK_KEYPRESS
    test al, al
    jz .FlipFlop
    WAIT_FOR_KEYPRESS   ; clear character

.exit:
    ;WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0

; Waits for the leading edge of the vertical sync pulse.
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

; Sets the start address to the value specifed by StartAddress.
SetStartAddress:
    call WaitForVerticalSyncEnd
    cli
    WITH_PORT CRTC, CRTC_START_ADDRESS_HIGH
    mov al, byte [StartAddress+1]
    out dx, al
    WITH_PORT CRTC, CRTC_START_ADDRESS_LOW
    mov al, byte[StartAddress]
    out dx, al
    sti
    ret

SetSplitScreenScanLine:
    push ax
    push cx
    push dx
; Wait for the trailing edge of vertical sync before setting so that
; one half of the address isn't loaded before the start of the frame
; and the other half after, resulting in flicker as one frame is
; displayed with mismatched halves. The new start address won't be
; loaded until the start of the next frame; that is, one full frame
; will be displayed before the new start address takes effect.
    call WaitForVerticalSyncEnd
    cli
    WITH_PORT CRTC, CRTC_LINE_COMPARE
    mov al, byte[SplitScreenLine]
    out dx, al

    mov ah, byte[SplitScreenLine+1]
    and ah, 1
    mov cl, 4
    shl ah, cl
%if IS_VGA
    WITH_PORT CRTC, CRTC_OVERFLOW
    in al, dx       ;get the current Overflow reg setting
    and al, ~10h    ;turn off split screen bit 8
    or al, ah       ; new split screen bit 8
    out dx, al
    dec dx
    mov ah, byte[SplitScreenLine+1]
    and ah, 2
    mov cl, 3
    ror ah, cl      ; move bit 9 of the split split screen scan line 
                    ; into position for the Maximum Scan Line register
    WITH_PORT CRTC, CRTC_MAX_SCAN_LINE
    in al, dx
    and al, ~40h
    or al, ah
    out dx, al
%else
    WITH_PORT CRTC, CRTC_OVERFLOW
    or ah, 0fh
    out dx, ah
%endif
    sti

    pop dx
    pop cx
    pop ax
    ret

SplitScreenUp:
.Loop:
    dec word[SplitScreenLine]
    call SetSplitScreenScanLine
    loop .Loop
    ret

SplitScreenDown:
.Loop:
    inc word[SplitScreenLine]
    call SetSplitScreenScanLine
    loop .Loop
    ret


section data
SplitScreenLine resw 1
StartAddress    resw 1

SplitScreenMsg db 'Split screen text row #'
DigitInsert    resw 1
               db '...$',0

section stack stack
    resb 256