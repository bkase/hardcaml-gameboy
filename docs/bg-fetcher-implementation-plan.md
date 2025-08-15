# Implementation Plan: Minimal Background Fetcher for HardCaml GameBoy

## Overview
Replace the synthetic checkerboard pattern generator with a minimal background fetcher that produces the same checkerboard output by walking the tilemap + tiledata path, matching real PPU behavior. This uses HardCaml's `Always.State_machine` API for clean state machine implementation.

## Phase 1: Create Failing Test (Test-Driven Development) ✅ COMPLETED

**✅ Created test/test_bg_fetcher.ml**
- ✅ Comprehensive test suite with 7 test functions covering:
  - ✅ Tilemap addressing (32-tile stride validation) 
  - ✅ Tile data extraction (2BPP format, bit ordering)
  - ✅ BGP palette application (0xE4 mapping)
  - ✅ State machine progression through fetch states
  - ✅ Fetch timing (6-cycle fetch + 12-cycle initial delay)
  - ✅ Full frame checkerboard pattern verification
  - ✅ Control signals (reset, start, busy, done)
- ✅ Test framework validates PPU fundamentals and guides implementation
- ✅ Tests pass for core PPU logic, appropriately skip implementation-dependent tests

**✅ Updated test/dune**
- ✅ Added test stanza with proper dependencies and warning flags
- ✅ Test compiles and runs successfully

**Test Results:**
```
✅ test_tilemap_addressing() - Core PPU addressing logic verified
✅ test_tile_data_decoding() - 2BPP implementation ready  
✅ test_bgp_palette() - Color mapping validated
✅ test_state_transitions() - Framework verified with current implementation
❌ test_fetch_timing() - Expected failure (needs real bg_fetcher_dmg)
❌ test_checkerboard_output() - Expected failure (needs real bg_fetcher_dmg)  
❌ test_control_signals() - Expected failure (needs real bg_fetcher_dmg)
```

## Phase 2: Create BG Fetcher Module Using HardCaml State Machine API 🚧 NEXT

**src/ppu/bg_fetcher_dmg.mli** - Interface matching Checker_fill exactly:
```ocaml
module I : sig
  type 'a t = { clock : 'a; reset : 'a; start : 'a }
  [@@deriving hardcaml]
end

module O : sig  
  type 'a t = {
    busy : 'a;
    done_ : 'a;
    fb_a_addr : 'a [@bits Constants.pixel_addr_width];
    fb_a_wdata : 'a [@bits Constants.pixel_data_width];
    fb_a_we : 'a
  }
  [@@deriving hardcaml]
end

val create : Scope.t -> Signal.t I.t -> Signal.t O.t
```

**src/ppu/bg_fetcher_dmg.ml** - Implementation using Always.State_machine:

```ocaml
module State = struct
  type t =
    | Idle
    | Fetch_tile_no
    | Fetch_tile_low  
    | Fetch_tile_high
    | Push_pixels
  [@@deriving sexp_of, compare ~localize, enumerate]
end
```

Key implementation details:
1. **State Machine using Always API**:
   - Use `Always.State_machine.create (module State) spec`
   - Use `sm.switch` for state transitions
   - Use `sm.set_next` to change states
   - Use `sm.is` to check current state

2. **Fixed VRAM contents** (hardcoded for now):
   - Tile 0: All 0xFF (black pixels, color index 3)
   - Tile 1: All 0x00 (white pixels, color index 0)
   - Tilemap: XOR checkerboard in 32x32 grid

3. **Fetcher Logic**:
   ```ocaml
   let sm = Always.State_machine.create (module State) spec in
   let tile_x = Always.Variable.reg spec ~width:5 in
   let pixel_in_tile = Always.Variable.reg spec ~width:3 in
   
   Always.(compile [
     sm.switch [
       Idle, [
         when_ i.start [
           tile_x <--. 0;
           pixel_in_tile <--. 0;
           sm.set_next Fetch_tile_no
         ]
       ];
       
       Fetch_tile_no, [
         (* Calculate tilemap address *)
         (* tile_y * 32 + tile_x *)
         sm.set_next Fetch_tile_low
       ];
       
       Fetch_tile_low, [
         (* Get low byte of tile row *)
         sm.set_next Fetch_tile_high
       ];
       
       Fetch_tile_high, [
         (* Get high byte of tile row *)
         sm.set_next Push_pixels
       ];
       
       Push_pixels, [
         (* Output 8 pixels one at a time *)
         (* Extract bit 7-pixel_in_tile from tile data *)
         (* Apply BGP palette *)
         pixel_in_tile <-- pixel_in_tile.value +:. 1;
         when_ (pixel_in_tile.value ==:. 7) [
           tile_x <-- tile_x.value +:. 1;
           sm.set_next (if at_end then Idle else Fetch_tile_no)
         ]
       ]
     ]
   ])
   ```

4. **Key PPU details to get right**:
   - Tilemap stride is 32, not 20
   - Bit 7 is leftmost pixel in tile data
   - Use mux to simulate VRAM reads from hardcoded data
   - BGP=0xE4: map color 0→0x7FFF (white), 3→0x0000 (black)

## Phase 3: Integration Changes

**Modify src/ppu/top_checker_to_framebuf.ml**:
```ocaml
(* Change from: *)
let checker_out = Checker_fill.create scope ...

(* To: *)
let checker_out = Bg_fetcher_dmg.create scope ...
```

## Phase 4: Verify Tests Pass

1. **Run new test**: `dune test test_bg_fetcher`
   - Verify state transitions are correct
   - Verify pixel output matches expected pattern

2. **Run oracle test**: `dune test oracle_lockstep`
   - Must report "✓ All pixels match! (full frame, 23040 pixels)"

3. **Run existing tests**: `make test`
   - All tests should still pass

## Phase 5: Clean Up Old Implementation

**Files to remove after verification**:
- `src/ppu/checker_fill.ml`
- `src/ppu/checker_fill.mli`
- `test/test_checker_fill_reset_start.ml` (or adapt it for bg_fetcher)

**Update test/dune**:
- Remove or update the test_checker_fill_reset_start stanza

## Key Implementation Guidelines

**State Machine Best Practices (from HardCaml docs)**:
- States must derive `sexp_of`, `compare ~localize`, and `enumerate`
- Use `Always.State_machine.create` with proper module signature
- Use `sm.switch` for clean state transition logic
- Use `sm.set_next` to transition states
- Use `sm.is` to check current state
- Compile with `Always.compile`

**Testing Strategy**:
- Test real PPU behaviors that will remain constant
- Use waveforms to verify state transitions
- Keep tests that validate PPU fundamentals
- Remove tests specific to the synthetic implementation

## Success Criteria

### Phase 1 ✅ COMPLETED
✅ New test_bg_fetcher.ml validates PPU addressing and pixel generation  
✅ Test framework compiles and runs successfully  
✅ Core PPU logic tests pass (tilemap, 2BPP, BGP palette)  
✅ State machine framework validated with existing implementation  

### Phase 2-5 🚧 REMAINING  
⏳ bg_fetcher_dmg.ml uses proper HardCaml Always API  
⏳ oracle_lockstep.ml reports "✓ All pixels match! (full frame, 23040 pixels)"  
⏳ All tests pass with `make test`  
⏳ Old synthetic implementation removed cleanly

## Future Extensions (Not This Step)
- Replace hardcoded VRAM with real memory
- Implement proper pixel FIFO timing
- Add scrolling support (SCX/SCY)
- Add window layer support
- Add sprite support
- Implement proper PPU timing modes

## References
- [minimal-bg-fetch.md](./minimal-bg-fetch.md) - Original requirements
- [ppu.md](./ppu.md) - PPU technical documentation
- HardCaml documentation for state machine implementation patterns