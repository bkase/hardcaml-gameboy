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

SECTION "Main", ROM0

Start:
    ; Wait for VBlank before turning off LCD
    ld a, [$FF44]  ; LY register
    cp 144
    jr c, Start

    ; Turn off LCD
    xor a
    ld [$FF40], a  ; LCDC = 0

    ; Create checkerboard tile at $8000
    ; Tile data: alternating pixels (0b10101010, 0b01010101)
    ld hl, $8000
    ld b, 8        ; 8 rows per tile
.tile_loop:
    ld a, $AA      ; 10101010 - pixels 0,2,4,6 are color 2, 1,3,5,7 are color 0
    ld [hl+], a
    ld a, $55      ; 01010101 - pixels 0,2,4,6 are color 1, 1,3,5,7 are color 0
    ld [hl+], a
    dec b
    jr nz, .tile_loop

    ; Fill background tilemap at $9800 with tile 0
    ld hl, $9800
    ld bc, 32*32   ; Full tilemap
    xor a          ; Tile index 0
.map_loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .map_loop

    ; Set palette (BGP)
    ; 11 10 01 00 = white, light gray, dark gray, black
    ld a, %11100100
    ld [$FF47], a  ; BGP

    ; Reset scroll
    xor a
    ld [$FF42], a  ; SCY = 0
    ld [$FF43], a  ; SCX = 0

    ; Turn on LCD with BG enabled
    ld a, %10000001  ; LCD on, BG on, BG tilemap at $9800, BG tiles at $8000
    ld [$FF40], a    ; LCDC

    ; Infinite loop
.halt_loop:
    halt
    jr .halt_loop