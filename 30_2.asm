; Demonstrates the interaction of the split screen and
; horizontal pel panning. On a VGA, first pans right in the top
; half while the split screen jerks around, because split screen
; pel panning suppression is disabled, then enables split screen
; pel panning suppression and pans right in the top half while the
; split screen remains stable. On an EGA, the split screen jerks
; around in both cases, because the EGA doesn't support split
; screen pel panning suppression.
;
; The jerking in the split screen occurs because the split screen
; is being pel panned (panned by single pixels--intrabyte panning),
; but is not and cannot be byte panned (panned by single bytes--
; "extrabyte" panning) because the start address of the split screen
; is forever fixed at 0.
;*********************************************************************
global start
%include 'common.inc'
IS_VGA                  equ    1            ;set to 0 to assemble for EGA

LOGICAL_SCREEN_WIDTH    equ    1024         ;# of pixels across virtual
                                            ; screen that we'll pan across
SCREEN_HEIGHT           equ    350
SPLIT_SCREEN_START      equ    200          ;start scan line for split screen
SPLIT_SCREEN_HEIGHT     equ    SCREEN_HEIGHT-SPLIT_SCREEN_START-1

section code
start:
    mov ax, data
    mov ds, ax
    SET_VIDEO_MODE MODE_V640x350x16
; Set the Offset register to make the offset from the start of one
; scan line to the start of the next the desired number of pixels.
; This gives us a virtual screen wider than the actual screen to
; pan across.
; Note that the Offset register is programmed with the logical
; screen width in words, not bytes, hence the final division by 2.
    SET_PORT CRTC, CRTC_HOFFSET, (LOGICAL_SCREEN_WIDTH/8/2)

; Set the start address to display the memory just past the split
; screen memory.
    mov    word [StartAddress],SPLIT_SCREEN_HEIGHT*(LOGICAL_SCREEN_WIDTH/8)
    call    SetStartAddress

; Set the split screen start scan line.
    mov    word [SplitScreenLine],SPLIT_SCREEN_START
    call   SetSplitScreenScanLine

; Fill the split screen portion of display memory (starting at
; offset 0) with a choppy diagonal pattern sloping left.
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    xor di, di
    mov dx, SPLIT_SCREEN_HEIGHT ; fill all lines in the split screen
    mov ax, 0000111111110000b   ; starting pattern
    cld
.RowLoop:
    mov cx, LOGICAL_SCREEN_WIDTH/8/4;fill 1 scan line
.ColumnLoop:
    stosw                           ; draw part of a diagonal line
    mov word[es:di], 0              ; make vertical blank spaces so panning effects can be seen easily
    times 2 inc di
    loop .ColumnLoop
    rol ax, 1
    dec dx
    jnz .RowLoop

; Fill the portion of display memory that will be displayed in the
; normal screen (the non-split screen part of the display) with a
; choppy diagonal pattern sloping right.
    mov di,SPLIT_SCREEN_HEIGHT*(LOGICAL_SCREEN_WIDTH/8)
    mov dx, SCREEN_HEIGHT
    mov ax, 1010010100010000b   ; starting pattern
    cld
.RowLoop2:
    mov cx, LOGICAL_SCREEN_WIDTH/8/4;fill 1 scan line
.ColumnLoop2:
    stosw
    mov word[es:di], 0
    times 2 inc di
    loop .ColumnLoop2
    ror ax, 1
    dec dx
    jnz .RowLoop2

; Pel pan the non-split screen portion of the display; because
; split screen pel panning suppression is not turned on, the split
; screen jerks back and forth as the pel panning setting cycles.
    mov cx, 200
    call PanRight
    WAIT_FOR_KEYPRESS
; Return to the original screen location, with pel panning turned off.
    mov     word [StartAddress],SPLIT_SCREEN_HEIGHT*(LOGICAL_SCREEN_WIDTH/8)
    call    SetStartAddress
    mov     byte[PelPan],0
    call    SetPelPan
; Turn on split screen pel panning suppression, so the split screen
; won't be affected by pel panning. Not done on EGA because both
; readable registers and the split screen pel panning suppression bit
; aren't supported by EGAs.
%if IS_VGA
    mov dx, INPUT_STATUS_0
    in al, dx               ;reset the AC Index/Data toggle to Index state
    
    GET_PORT AC, 20h|AC_MODE_CONTROL  ; bit 5 set to 1 to keep video on
    or al, 20h                        ; enable split screen pel panning suppression

    dec dx
    out dx, al  ;write the new AC Mode Control setting with 
                ; split screen pel panning suppression turned on
%else
    ; not done for EGA
%endif
; Pel pan the non-split screen portion of the display; because
; split screen pel panning suppression is turned on, the split
; screen will not move as the pel panning setting cycles.
    mov cx, 200
    call PanRight
.exit:
    WAIT_FOR_KEYPRESS
    SET_VIDEO_MODE MODE_T80x50
    EXIT 0



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

; Sets the horizontal pel panning setting to the value specified
; by PelPan. Waits until the start of vertical sync to do so, so
; the new pel pan setting can be loaded during non-display time
; and can be ready by the start of the next frame.
SetPelPan:
    call WaitForVerticalSyncStart ; also resets the AC Index/Data toggle to Index state
    SET_PORT AC, (AC_PEL_PANNING|20h), byte [PelPan]
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

; Pan horizontally to the right the number of pixels specified by CX.
; Input: CX = # of pixels by which to pan horizontally
PanRight:
.Loop:
    inc byte[PelPan]
    and byte[PelPan], 07h
    jnz .SetStartAddress
    inc word[StartAddress]
.SetStartAddress:
    call SetStartAddress
    call SetPelPan
    loop .Loop
    ret

section data
SplitScreenLine resw 1  ; line the split screen currently starts after 
StartAddress    resw 1  ; display memory offset at which scanning for video data starts
PelPan          resb 1  ; current intrabyte horizontal pel panning setting

section stack stack
    resb 512