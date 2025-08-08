; flat_bg.asm - Simple checkerboard pattern test ROM
; This ROM displays a checkerboard pattern using the background layer

SECTION "Header", ROM0[$100]
    ; Entry point
    nop
    jp Start

    ; Nintendo Logo - Required for boot
    DB $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
    DB $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    DB $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

    ; Title
    DB "FLAT_BG",0,0,0,0,0,0,0,0,0 ; 16 bytes

    ; Manufacturer code
    DB 0,0,0,0

    ; Color GB flag
    DB 0

    ; New licensee code
    DB 0,0

    ; SGB flag
    DB 0

    ; Cartridge type
    DB 0

    ; ROM size
    DB 0

    ; RAM size
    DB 0

    ; Destination code
    DB 0

    ; Old licensee code
    DB $33

    ; ROM version
    DB 0

    ; Header checksum (will be fixed by rgbfix)
    DB 0

    ; Global checksum (will be fixed by rgbfix)
    DW 0

Start:
    ; Disable interrupts first
    di
    
    ; Wait for VBlank before turning off LCD
.wait_vblank:
    ld a, [$FF44]  ; Read LY
    cp 144         ; Check if in VBlank (LY >= 144)
    jr c, .wait_vblank
    
    ; Now safe to turn off LCD
    xor a
    ld [$FF40], a  ; LCDC = 0
    
    ; Small delay to ensure LCD is fully off
    ld b, 200
.lcd_wait:
    dec b
    jr nz, .lcd_wait
    
    ; Create solid black tile at $8000
    ; Black = color 3 (both bits set for all pixels)
    ld hl, $8000
    ld b, 16       ; 16 bytes (8 rows * 2 bytes/row)
    ld a, $FF      ; All bits set
.tile_loop:
    ld [hl+], a
    dec b
    jr nz, .tile_loop
    
    ; Create solid white tile at $8010  
    ; White = color 0 (all bits clear)
    ld hl, $8010   ; Explicitly set HL to tile 1 location
    ld b, 16
    xor a          ; A = 0
.tile_loop2:
    ld [hl+], a
    dec b
    jr nz, .tile_loop2
    
    ; Fill background tilemap at $9800 with checkerboard pattern
    ; Alternating tiles 0 (black) and 1 (white)
    ld hl, $9800
    ld d, 0        ; Row counter (0-17)
.row_loop:
    ld e, 0        ; Column counter (0-19)
.tile_loop_map:
    ld a, d
    and 1          ; Check if row is odd/even
    ld b, a        ; Save row parity
    ld a, e
    and 1          ; Check if column is odd/even
    xor b          ; XOR with row parity for checkerboard
    ld [hl+], a    ; Write tile index (0 or 1)
    inc e
    ld a, e
    cp 20          ; Check if we've done 20 tiles
    jr nz, .tile_loop_map
    
    ; Skip to next row (32 - 20 = 12 tiles)
    push bc
    ld bc, 12
    add hl, bc
    pop bc
    
    inc d
    ld a, d
    cp 18          ; Check if we've done 18 rows
    jr nz, .row_loop

    ; Set palette (BGP)
    ; 11 10 01 00 = black, dark gray, light gray, white
    ld a, %11100100
    ld [$FF47], a  ; BGP

    ; Reset scroll
    xor a
    ld [$FF42], a  ; SCY = 0
    ld [$FF43], a  ; SCX = 0

    ; Turn on LCD with BG enabled
    ld a, %10010001  ; LCD on, BG tiles at $8000, BG on, BG tilemap at $9800
    ld [$FF40], a    ; LCDC
    
    ; Infinite loop
.halt_loop:
    halt
    jr .halt_loop