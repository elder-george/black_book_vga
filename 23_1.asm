; Listing 23.1 is a sample VGA program that pans around an animated 16-color medium-resolution (640x350) playfield.

global start

AC_index_data   equ 3C0H
AC_index        equ 3C0H
AC_data         equ AC_index+1

HPELPAN         equ     20h | 13h   ;AC horizontal pel panning register
                                     ; (bit 7 is high to keep palette RAM
                                     ; addressing on)

Misc_out_Write  EQU 3C2H 
Misc_out_Read   EQU 3CCH

Inp_Status0     EQU 3C2H  ; read

Inp_Status1_Clr EQU 3DAH  ; read
Inp_Status1_Mc  EQU 3BAH  ; read
VSYNC_MASK      equ     08h     ;vertical sync bit in status register 1
DE_MASK         equ     01h     ;display enable bit in status register 1

SC_index        equ 3C4H
SC_data         equ SC_index+1
SC_MAP_MASK     EQU 2

GC_index        equ 3CEH
GC_data         equ GC_index+1
GC_MODE         EQU 5

CRTC_index_Mc   equ 3B4h
CRTC_data_Mc    equ CRTC_index_Mc+1

CRTC_index_Clr  equ 3D4h
CRTC_data_Clr   equ CRTC_index_Clr+1
CRTC_START_ADDRESS_HIGH equ  0ch     ;CRTC start address high byte
CRTC_START_ADDRESS_LOW equ   0dh     ;CRTC start address low byte
CRTC_OFFSET     equ     13h     ;CRTC offset register

CRTC_index EQU CRTC_index_Clr
Inp_Status1 EQU Inp_Status1_Clr



Video_Seg       equ 0a000h

MEDRES_VIDEO_MODE       equ     0 ; define for 640x350 video mode
LOGICAL_SCREEN_WIDTH    equ     672/8
LOGICAL_SCREEN_HEIGHT   equ     384

PAGE0           equ     0       ;flag for page 0 when page flipping
PAGE1           equ     1       ;flag for page 1 when page flipping
PAGE0_OFFSET    equ     0       ;start offset of page 0 in VGA memory
PAGE1_OFFSET    equ     LOGICAL_SCREEN_WIDTH * LOGICAL_SCREEN_HEIGHT
                                ;start offset of page 1 (both pages
                                ; are 672x384 virtual screens) 

BALL_WIDTH      equ     24/8    ;width of ball in display memory bytes
BALL_HEIGHT     equ     24      ;height of ball in scan lines
BLANK_OFFSET    equ     PAGE1_OFFSET * 2        ;start of blank image
                                                ; in VGA memory
BALL_OFFSET     equ     BLANK_OFFSET + (BALL_WIDTH * BALL_HEIGHT)
                                ;start offset of ball image in VGA memory
NUM_BALLS       equ     4       ;number of balls to animate




%macro out_vga 3
%define __ctrl %1
%define __mask %2
%define __val %3
    mov dx, __ctrl%+_index
    mov ah, __mask
    mov al, __val
    out dx, ax
%endm


section .code
start:
    cld
    mov ax, data
    mov ds, ax
.set_video_mode:
%ifdef MEDRES_VIDEO_MODE
    mov     ax,010h
%else
    mov     ax,0eh
%endif
    int     10h
    mov     ax,Video_Seg
    mov     es,ax
.draw_borders:
    mov     di,PAGE0_OFFSET
    call    DrawBorder      ;page 0 border
    mov     di,PAGE1_OFFSET
    call    DrawBorder      ;page 1 border
; Draw all four plane's worth of the ball to undisplayed VGA memory.
    out_vga SC,01, SC_MAP_MASK  ;enable plane 0
    mov     si, BallPlane0Image
    mov     di,BALL_OFFSET
    mov     cx,BALL_WIDTH * BALL_HEIGHT
    rep movsb
    out_vga SC,02, SC_MAP_MASK  ;enable plane 1
    mov     si, BallPlane1Image
    mov     di,BALL_OFFSET
    mov     cx,BALL_WIDTH * BALL_HEIGHT
    rep movsb
    out_vga SC,04, SC_MAP_MASK  ;enable plane 2
    mov     si, BallPlane2Image
    mov     di,BALL_OFFSET
    mov     cx,BALL_WIDTH * BALL_HEIGHT
    rep movsb
    out_vga SC,08, SC_MAP_MASK  ;enable plane 3
    mov     si, BallPlane3Image
    mov     di,BALL_OFFSET
    mov     cx,BALL_WIDTH * BALL_HEIGHT
    rep movsb
; Draw a blank image the size of the ball to undisplayed VGA memory.
    out_vga SC,0ffh, SC_MAP_MASK  ;enable all planes
    mov     di,BLANK_OFFSET
    mov     cx,BALL_WIDTH * BALL_HEIGHT
    xor     al,al
    rep stosb
; Set VGA to write mode 1, for block copying ball and blank images.
    mov     dx,GC_index
    mov     al,GC_MODE
    out     dx,al           ;point GC Index to GC Mode register
    inc     dx              ;point to GC Data register
    jmp     $+2             ;delay to let bus settle
    in      al,dx           ;get current state of GC Mode
    and     al, ~3          ;clear the write mode bits
    or      al,1            ;set the write mode field to 1
    jmp     $+2             ;delay to let bus settle
    out     dx,al

; Set VGA offset register in words to define logical screen width.
    out_vga CRTC, LOGICAL_SCREEN_WIDTH / 2, CRTC_OFFSET
;
; Move the balls by erasing each ball, moving it, and
; redrawing it, then switching pages when they're all moved.
;
.BallAnimationLoop:
    mov     bx,( NUM_BALLS * 2 ) - 2
.EachBallLoop:
; Erase old image of ball in this page (at location from one more earlier).
    mov     si,BLANK_OFFSET ;point to blank image
    mov     cx,[LastBallX+bx]
    mov     dx,[LastBallY+bx]
    call    DrawBall
; Set new last ball location.
    mov     ax,[BallX+bx]
    mov     [LastBallX+bx],ax
    mov     ax,[BallY+bx]
    mov     [LastBallY+bx],ax
; Change the ball movement values if it's time to do so.
;
    dec     word [BallRep+bx]           ;has current repeat factor run out?
    jnz     .MoveBall
    mov     si,[BallControl+bx]    ;it's time to change movement values
    lodsw                          ;get new repeat factor from
                                   ; control string
    and     ax,ax                  ;at end of control string?
    jnz     .SetNewMove
    mov     si,[BallControlString+bx]       ;reset control string
    lodsw                           ;get new repeat factor
.SetNewMove:
    mov     [BallRep+bx],ax         ;set new movement repeat factor
    lodsw                           ;set new x movement increment
    mov     [BallXInc+bx],ax
    lodsw                           ;set new y movement increment
    mov     [BallYInc+bx],ax
    mov     [BallControl+bx],si     ;save new control string pointer
; Move the ball.
.MoveBall:
    mov     ax,[BallXInc+bx]
    add     [BallX+bx],ax           ;move in x direction
    mov     ax,[BallYInc+bx]
    add     [BallY+bx],ax           ;move in y direction
; Draw ball at new location.
    mov     si,BALL_OFFSET  ;point to ball's image
    mov     cx,[BallX+bx]
    mov     dx,[BallY+bx]
    call    DrawBall
;
    dec     bx
    dec     bx
    jns     .EachBallLoop
.DoneWithBalls:
; Set up the next panning state (but don't program it into the ; VGA yet).
    call AdjustPanning
; Wait for display enable (pixel data being displayed) so we know
; we're nowhere near vertical sync, where the start address gets
; latched and used.
    call    WaitDisplayEnable
; Flip to the new page by changing the start address.
    mov     ax,[CurrentPageOffset]
    add     ax,[PanningStartOffset]
    push    ax
    out_vga CRTC, al, CRTC_START_ADDRESS_LOW
    ;mov     al,byte [CurrentPageOffset+1]
    pop     ax
    mov     al,ah
    out_vga CRTC, al, CRTC_START_ADDRESS_HIGH
; Wait for vertical sync so the new start address has a chance to take effect.
    call    WaitVSync
; Set horizontal panning now, just as new start address takes effect.
;
    mov     al,[HPan]
    mov     dx,Inp_Status1
    in      al,dx                   ;reset AC addressing to index reg
    mov     dx,AC_index
    mov     al,HPELPAN
    out     dx,al                   ;set AC index to pel pan reg
    mov     al,[HPan]
    out     dx,al                   ;set new pel panning
; Flip the page to draw to to the undisplayed page.
    xor     byte [CurrentPage],1
    jnz     .IsPage1
    mov     word [CurrentPageOffset],PAGE0_OFFSET
    jmp     short .EndFlipPage
.IsPage1:
    mov     word [CurrentPageOffset],PAGE1_OFFSET
.EndFlipPage:
;
; Exit if a key's been hit.
;
    mov     ah,1
    int     16h
    jnz     .Done
    jmp     .BallAnimationLoop
.Done:
    mov ah, 0
    int 16h
    mov ax,3
    int 10h
.exit:
    mov ax, 4c00h
    int 21h
    ret

DrawBorder:
        push    di
        mov     cx,LOGICAL_SCREEN_HEIGHT / 16
.DrawLeftBorderLoop:
        mov     al,0ch          ;select red color for block
        call    DrawBorderBlock
        add     di,LOGICAL_SCREEN_WIDTH * 8
        mov     al,0eh          ;select yellow color for block
        call    DrawBorderBlock
        add     di,LOGICAL_SCREEN_WIDTH * 8
        loop    .DrawLeftBorderLoop
        pop     di
;
; Draw the right border.
;
        push    di
        add     di,LOGICAL_SCREEN_WIDTH - 1
        mov     cx,LOGICAL_SCREEN_HEIGHT / 16
.DrawRightBorderLoop:
        mov     al,0eh          ;select yellow color for block
        call    DrawBorderBlock
        add     di,LOGICAL_SCREEN_WIDTH * 8
        mov     al,0ch          ;select red color for block
        call    DrawBorderBlock
        add     di,LOGICAL_SCREEN_WIDTH * 8
        loop    .DrawRightBorderLoop
        pop     di
;
; Draw the top border.
;
        push    di
        mov     cx,(LOGICAL_SCREEN_WIDTH - 2) / 2
.DrawTopBorderLoop:
        inc     di
        mov     al,0eh          ;select yellow color for block
        call    DrawBorderBlock
        inc     di
        mov     al,0ch          ;select red color for block
        call    DrawBorderBlock
        loop    .DrawTopBorderLoop
        pop     di
;
; Draw the bottom border.
;
        add     di,(LOGICAL_SCREEN_HEIGHT - 8) * LOGICAL_SCREEN_WIDTH
        mov     cx,(LOGICAL_SCREEN_WIDTH - 2) / 2
.DrawBottomBorderLoop:
        inc     di
        mov     al,0ch          ;select red color for block
        call    DrawBorderBlock
        inc     di
        mov     al,0eh          ;select yellow color for block
        call    DrawBorderBlock
        loop    .DrawBottomBorderLoop
        ret

DrawBorderBlock:
    push    di
    out_vga  SC, al, SC_MAP_MASK
    mov     al,0ffh
    %rep 8
    stosb
    add     di,LOGICAL_SCREEN_WIDTH - 1
    %endrep
    pop     di
    ret

DrawBall:
    mov     ax,LOGICAL_SCREEN_WIDTH
    mul     dx      ;offset of start of top image scan line
    add     ax,cx   ;offset of upper left of image
    add     ax,[CurrentPageOffset]  ;offset of start of page
    mov     di,ax
    mov     bp,BALL_HEIGHT
    push    ds
    push    es
    pop     ds      ;move from VGA memory to VGA memory
.DrawBallLoop:
    push    di
    mov     cx,BALL_WIDTH
    rep movsb       ;draw a scan line of image
    pop     di
    add     di,LOGICAL_SCREEN_WIDTH ;point to next destination scan line
    dec     bp
    jnz     .DrawBallLoop
    pop     ds
    ret

AdjustPanning:
    dec     word [PanningRep]    ;time to get new panning values?
    jnz     .DoPan
    mov     si,[PanningControl]     ;point to current location in
                                    ; panning control string
    lodsw                           ;get panning repeat factor
    and     ax,ax                   ;at end of panning control string?
    jnz     .SetNewPanValues
    mov     si, PanningControlString  ;reset to start of string
    lodsw                           ;get panning repeat factor
.SetNewPanValues:
    mov     [PanningRep],ax         ;set new panning repeat value
    lodsw
    mov     [PanningXInc],ax        ;horizontal panning value
    lodsw
    mov     [PanningYInc],ax        ;vertical panning value
    mov     [PanningControl],si     ;save current location in panning
                                    ; control string
;
; Pan according to panning values.
;
.DoPan:
    mov     ax,[PanningXInc]        ;horizontal panning
    and     ax,ax
    js      .PanLeft                 ;negative means pan left
    jz      .CheckVerticalPan
    mov     al,[HPan]
    inc     al                      ;pan right; if pel pan reaches
    cmp     al,8                    ; 8, it's time to move to the
    jb      .SetHPan                 ; next byte with a pel pan of 0
    sub     al,al                   ; and a start offset that's one
    inc     word [PanningStartOffset]    ; higher
    jmp     short .SetHPan
.PanLeft:
    mov     al,[HPan]
    dec     al                      ;pan left; if pel pan reaches -1,
    jns     .SetHPan                 ; it's time to move to the next
    mov     al,7                    ; byte with a pel pan of 7 and a
    dec     word [PanningStartOffset]    ; start offset that's one lower
.SetHPan:
    mov     [HPan],al               ;save new pel pan value
.CheckVerticalPan:
    mov     ax,[PanningYInc]        ;vertical panning
    and     ax,ax
    js      .PanUp                   ;negative means pan up
    jz      .EndPan
    add     word [PanningStartOffset],LOGICAL_SCREEN_WIDTH
                                    ;pan down by advancing the start
                                    ; address by a scan line
    jmp     short .EndPan
.PanUp:
    sub     word [PanningStartOffset],LOGICAL_SCREEN_WIDTH
                                    ;pan up by retarding the start
                                    ; address by a scan line
.EndPan:
    ret

WaitDisplayEnable:
        mov     dx,Inp_Status1
.WaitDELoop:
        in      al,dx
        and     al,DE_MASK
        jnz     .WaitDELoop
        ret

WaitVSync:
    mov     dx,Inp_Status1
.WaitNotVSyncLoop:
    in      al,dx
    and     al,VSYNC_MASK
    jnz     .WaitNotVSyncLoop
.WaitVSyncLoop:
    in      al,dx
    and     al,VSYNC_MASK
    jz      .WaitVSyncLoop
    ret

section .data data
CurrentPage             db      PAGE1           ;page to draw to
CurrentPageOffset       dw      PAGE1_OFFSET
;
; Four plane's worth of multicolored ball image.
;
BallPlane0Image:            ;blue plane image
        db      000h, 03ch, 000h, 001h, 0ffh, 080h
        db      007h, 0ffh, 0e0h, 00fh, 0ffh, 0f0h
        times (4 * 3) db (00h)
        db      07fh, 0ffh, 0feh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        times (4 * 3) db (00h)
        db      07fh, 0ffh, 0feh, 03fh, 0ffh, 0fch
        db      03fh, 0ffh, 0fch, 01fh, 0ffh, 0f8h
        times (4 * 3) db (00h)
BallPlane1Image:            ;green plane image
        times (4 * 3) db (00h)
        db      01fh, 0ffh, 0f8h, 03fh, 0ffh, 0fch
        db      03fh, 0ffh, 0fch, 07fh, 0ffh, 0feh
        db      07fh, 0ffh, 0feh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        times (8 * 3) db (00h)
        db      00fh, 0ffh, 0f0h, 007h, 0ffh, 0e0h
        db      001h, 0ffh, 080h, 000h, 03ch, 000h
BallPlane2Image:            ;red plane image
        times (12 * 3) db (00h)
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 07fh, 0ffh, 0feh
        db      07fh, 0ffh, 0feh, 03fh, 0ffh, 0fch
        db      03fh, 0ffh, 0fch, 01fh, 0ffh, 0f8h
        db      00fh, 0ffh, 0f0h, 007h, 0ffh, 0e0h
        db      001h, 0ffh, 080h, 000h, 03ch, 000h
BallPlane3Image:            ;intensity on for all planes,
                            ; to produce high-intensity colors
        db      000h, 03ch, 000h, 001h, 0ffh, 080h
        db      007h, 0ffh, 0e0h, 00fh, 0ffh, 0f0h
        db      01fh, 0ffh, 0f8h, 03fh, 0ffh, 0fch
        db      03fh, 0ffh, 0fch, 07fh, 0ffh, 0feh
        db      07fh, 0ffh, 0feh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 0ffh, 0ffh, 0ffh
        db      0ffh, 0ffh, 0ffh, 07fh, 0ffh, 0feh
        db      07fh, 0ffh, 0feh, 03fh, 0ffh, 0fch
        db      03fh, 0ffh, 0fch, 01fh, 0ffh, 0f8h
        db      00fh, 0ffh, 0f0h, 007h, 0ffh, 0e0h
        db      001h, 0ffh, 080h, 000h, 03ch, 000h

BallX           dw      15, 50, 40, 70          ;array of ball x coords
BallY           dw      40, 200, 110, 300       ;array of ball y coords
LastBallX       dw      15, 50, 40, 70          ;previous ball x coords
LastBallY       dw      40, 100, 160, 30        ;previous ball y coords
BallXInc        dw      1, 1, 1, 1              ;x move factors for ball
BallYInc        dw      8, 8, 8, 8              ;y move factors for ball
BallRep         dw      1, 1, 1, 1              ;# times to keep moving
                                                ; ball according to current
                                                ; increments
BallControl     dw      Ball0Control, Ball1Control     ;pointers to current
                dw      Ball2Control, Ball3Control     ; locations in ball
                                                       ; control strings
BallControlString     dw    Ball0Control, Ball1Control ;pointers to
                      dw    Ball2Control, Ball3Control ; start of ball
                                                       ; control strings

Ball0Control:
        dw      10, 1, 4, 10, -1, 4, 10, -1, -4, 10, 1, -4, 0
Ball1Control:
        dw      12, -1, 1, 28, -1, -1, 12, 1, -1, 28, 1, 1, 0
Ball2Control:
        dw      20, 0, -1, 40, 0, 1, 20, 0, -1, 0
Ball3Control:
        dw      8, 1, 0, 52, -1, 0, 44, 1, 0, 0

%ifdef MEDRES_VIDEO_MODE
PanningControlString    dw      32, 1, 0, 34, 0, 1, 32, -1, 0, 34, 0, -1, 0
%else
PanningControlString    dw      32, 1, 0, 184, 0, 1, 32, -1, 0, 184, 0, -1, 0
%endif
PanningControl  dw      PanningControlString   ;pointer to current location
                                               ; in panning control string
PanningRep      dw      1      ;# times to pan according to current
                               ; panning increments
PanningXInc     dw      1      ;x panning factor
PanningYInc     dw      0      ;y panning factor
HPan            db      0      ;horizontal pel panning setting
PanningStartOffset dw   0      ;start offset adjustment to produce vertical
                               ; panning & coarse horizontal panning

section .stack stack
    resb 256
