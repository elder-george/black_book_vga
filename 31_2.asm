; Program to demonstrate the two pages available in 320x400
; 256-color modes on a VGA.  Draws diagonal color bars in all
; 256 colors in page 0, then does the same in page 1 (but with
; the bars tilted the other way), and finally draws vertical
; color bars in page 0.

global start
%include 'common.inc'

SCREEN_WIDTH    equ 320
SCREEN_HEIGHT   equ 400

section code
start:
    call Set320By400Mode
; We're in 320x400 256-color mode, with page 0 displayed.
; Let's fill page 0 with color bars slanting down and to the right.
    xor di, di      ; page 0 starts at address 0
    mov bl, 1       ; make color bars slant down and to the right
    call ColorBarsUp
; Now do the same for page 1, but with the color bars
; tilting the other way.
    mov di, 8000h   ; page 1 starts at address 8000h
    mov bl, -1      ; make color bars slant down and to the left
    call ColorBarsUp
; Wait for a key and flip to page 1 when one is pressed.
    WAIT_FOR_KEYPRESS
    SET_PORT CRTC, CRTC_START_ADDRESS_HIGH, 80h ; set the Start Address High register
                                                ; to 80h, for a start address of 8000h
; Draw vertical bars in page 0 while page 1 is displayed.
    xor di, di      ; page 0 starts at address 0
    xor bl, bl      ; make color bars vertical
    call ColorBarsUp

; Wait for another key and flip back to page 0 when one is pressed.
    WAIT_FOR_KEYPRESS
    SET_PORT CRTC, CRTC_START_ADDRESS_HIGH, 00h ; set the Start Address High register
                                                ; to 00h, for a start address of 0000h
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

ColorBarsUp:
    mov ax, VGA_VIDEO_SEGMENT
    mov es, ax
    xor bh, bh  ; start with color 0
    mov si, SCREEN_HEIGHT   ; number of rows
    WITH_PORT SC, SC_MAP_MASK
.RowLoop:
    mov cx, SCREEN_WIDTH/4 ; 4 pixels at each address, so 80 bytes per 320-pixel row
    push bx
.ColumnLoop:
%assign MAP_SELECT 1
%rep 4
    mov al, MAP_SELECT
    out dx, al
    mov [es:di], bh
    inc bh
%assign MAP_SELECT (MAP_SELECT << 1)
%endrep
    inc di      ;point to the address containing the next 4 pixels
    loop .ColumnLoop
    pop bx
    add bh, bl  ;select next row-start color (controls slanting of color bars)
    dec si
    jnz .RowLoop
    ret
section data

section stack stack
    resb 256