# Phase 1 — Concrete Spec (no code sharing)

**Goal:** Build a _pure OCaml executable spec_ that generates the same 160×144 RGB555 checkerboard you expect from Phase 1, dump artifacts (raw + PPM), and compare against a SameBoy capture of the ROM at frame 300. No reuse from `src/ppu/*`—the spec stands alone for now.

## Why this step

- Gives you a fast, deterministic “golden intent” independent of RTL.
- Locks the artifact pipeline (raw RGB555 + PPM + diff) before wiring more PPU realism.
- Sets up the exact SameBoy oracle loop you’ll reuse in later phases.

---

## Repository integration (new files & where)

Create a **new, spec-only** subtree so the team can iterate without touching RTL:

```
spec/
  ppu/
    phase1_checker_spec.ml        (* pure generator: 160×144 RGB555 checkerboard *)
    ppm.ml                        (* tiny writer: P6 PPM from RGB555 buffer *)
    rgb.ml                        (* helpers: RGB555 pack/unpack, 5→8-bit, etc. *)
  dune
test/
  spec_phase1_vs_sameboy.ml       (* Alcotest: Spec ↔ SameBoy at frame 300 *)
```

- Keep _all_ spec logic in `spec/`—no `open src/ppu/*`.
- Tests live in `test/` next to your existing suites; they can reuse the SameBoy tooling you already have. (You’re already building SameBoy and using a headless runner with artifacts. )

---

## External tools you already have

- **SameBoy headless** in `tools/` (built via `make tools`).
- **ROM(s)** in `roms/` (e.g., `flat_bg.asm` → `flat_bg.gb`) built via `make roms`.
- CI calls `make tools roms` and runs `make test` already.

We’ll hook the new spec test into the same flow.

---

## Target behavior (spec)

**Image:** 160×144 pixels, **RGB555** (16-bit), little-endian per pixel.
**Pattern:** 8×8 tile-aligned checkerboard.

- Block parity: `((x >> 3) ^ (y >> 3)) & 1`
- Colors (DMG-style but rendered in RGB555):
  - **White** = `0x7FFF`
  - **Black** = `0x0000`
    **Layout:** row-major; pixel index = `y*160 + x` → word address.
    **Artifacts:**

- Raw framebuffer: `*_dut/phase1_checker.rgb555` (46,080 bytes).
- PPM view: `*_dut/phase1_checker.ppm` (P6, 160×144).

(These choices match the existing constants & framebuffer contracts used by your RTL: 160×144, word-address = pixel index, RGB555. )

---

## Oracle behavior (SameBoy)

- Run `roms/flat_bg.gb` (DMG) to **frame 300** so content is settled. (This frame number aligns with your existing headless tooling.)
- Capture a 160×144 **RGBA8888** frame: `*_oracle/phase1_checker/frame_0300.rgba`.
- Convert oracle RGBA8888 → RGB555 (truncate 8→5 bits; pack little-endian):
  - `R5=R8>>3; G5=G8>>3; B5=B8>>3; rgb555=(R5<<10)|(G5<<5)|B5`.

Also dump `_oracle/phase1_checker.ppm` for human inspection.

---

## Spec module APIs (simple & concrete)

### `spec/ppu/rgb.ml`

- `val pack_rgb555 : r5:int -> g5:int -> b5:int -> int`
- `val unpack_rgb555 : int -> int * int * int`
- `val to_rgb888 : rgb555:int -> r8:int * g8:int * b8:int`
  - `c8 = (c5 * 255) / 31` (integer).

### `spec/ppu/ppm.ml`

- `val write_ppm_rgb555 : path:string -> width:int -> height:int -> buf:int array -> unit`
  - Writes P6 header then RGB888 bytes from `rgb555`.

### `spec/ppu/phase1_checker_spec.ml`

- `val render : unit -> int array`
  - Returns an `int array` of length 160\*144; each entry is **RGB555** (OCaml `int`).
  - Algorithm (straight-line):

    ```
    let w=160, h=144 in
    for y=0..h-1:
      for x=0..w-1:
        let sel = ((x lsr 3) lxor (y lsr 3)) land 1 in
        buf.(y*w + x) <- if sel=0 then 0x7FFF else 0x0000
    ```

---

## New test (Alcotest) — `test/spec_phase1_vs_sameboy.ml`

**Purpose:** End-to-end, spec ↔ SameBoy (frame 300).
**Steps:**

1. **Build oracle artifacts**
   - Ensure `make tools roms` run (CI already does this).
   - Use `tools/sameboy_headless` to render frame 300 of `roms/flat_bg.gb` to RGBA and place under `_build/_oracle/phase1_checker/frame_0300.rgba`. (Your repo already uses a headless runner pattern. )
   - Convert to RGB555 raw + PPM: `_build/_oracle/phase1_checker.rgb555`, `_build/_oracle/phase1_checker.ppm`.

2. **Run spec**
   - `let fb = Phase1_checker_spec.render ()`
   - Write raw: `_build/_dut/phase1_checker.rgb555` (LE 16-bit words).
   - Write PPM: `_build/_dut/phase1_checker.ppm`.

3. **Compare**
   - Byte-for-byte equality on `.rgb555`. If equal → **PASS** (print SHA-256 of file).
   - On mismatch:
     - Emit `expected.ppm`, `actual.ppm`, `diff.ppm` into `_artifacts/phase1_checker/`.
     - Log first \~10 mismatches with `(x,y): exp=0xHHHH act=0xHHHH | ΔR,ΔG,ΔB`.

> This mirrors the artifact style you already document (expected/actual/diff) for test failures.

**Alcotest registration:** add the test into `test/dune` so `make test` picks it up (CI already runs `make test`).

---

## Exact file outputs (paths)

- **DUT (spec)**
  - `_build/_dut/phase1_checker.rgb555` (46,080 bytes)
  - `_build/_dut/phase1_checker.ppm`

- **Oracle (SameBoy)**
  - `_build/_oracle/phase1_checker/frame_0300.rgba`
  - `_build/_oracle/phase1_checker.rgb555`
  - `_build/_oracle/phase1_checker.ppm`

- **On diff**
  - `_artifacts/phase1_checker/{expected,actual,diff}.ppm`
  - (optional) PNGs via ImageMagick if available.

---

## Dune stanzas (sketch)

### `spec/dune`

```lisp
(library
 (name gbc_spec)
 (public_name gbc_spec)
 (libraries core)
 (flags (:standard -w -9-27))
 (preprocess (pps ppx_let ppx_sexp_conv)))
```

### `test/dune` (add a stanza)

```lisp
(test
 (name spec_phase1_vs_sameboy)
 (libraries alcotest core gbc_spec)
 (flags (:standard -w -9-27)))
```

_(Your repo already has a `test` dune file and pattern; mirror it. )_

---

## Acceptance criteria

- **Equality:** `_build/_dut/phase1_checker.rgb555` === `_build/_oracle/phase1_checker.rgb555` (byte-for-byte).
- **Artifacts on failure:** expected/actual/diff PPMs and short mismatch log.
- **Runtime:** Test should complete well under a second on dev machines (spec is O(23k) simple integer ops).

---

## “What about the RTL in this repo right now?”

- You have `src/ppu/framebuf.ml` with word-addressed 160×144 RGB555 and a 1-cycle Port-B read latency (already matches our artifact format).
- You also have `src/ppu/top_checker_to_framebuf.ml` (Phase 1 style top) and an early `bg_fetcher_dmg.ml`. For this **Phase 1 spec**, we **do not** call into RTL; the point is an **independent executable intent**.
- Your CI already builds tools/ROMs/tests in order. This new test will slot into the existing `make test` pipeline.

If you _optionally_ want an RTL sanity in this phase, you can add a second test `spec_phase1_vs_rtl.ml` that:

- simulates `top_checker_to_framebuf` filling an RTL framebuffer,
- dumps `_build/_rtl/phase1_checker.rgb555`,
- compares **spec ↔ RTL**.
  But that’s strictly optional for the Phase 1 “spec only” milestone.

---

## Risks / gotchas (and how we avoid them)

- **Endianness mismatches:** Always write RGB555 **little-endian** (low byte first). Centralize pack/unpack in `spec/ppu/rgb.ml`. (Matches RTL and your constants.)
- **5→8-bit scaling for PPM:** Use `(c5*255)/31` (not `<<3`) so whites are truly 255.
- **Oracle channel order:** SameBoy RGBA is R,G, B, A in that byte order—pick bytes 0..2.
- **Frame number:** lock to **300** as you specified to avoid boot transients.

---

## Work breakdown (engineers’ checklist)

1. **Create modules**: `rgb.ml`, `ppm.ml`, `phase1_checker_spec.ml` under `spec/ppu/`.
2. **Implement `render()`**: fill array with checkerboard (8×8 blocks), RGB555 white/black.
3. **Write dump helpers**: raw RGB555 writer (LE), PPM writer (P6).
4. **SameBoy runner**: reuse existing headless tool invocation to frame 300; add RGBA→RGB555 converter in the test (or a small helper in `test/`, your call).
5. **Alcotest**: implement compare with artifacts on mismatch.
6. **Dune**: add `spec/` library + test stanza; ensure `make test` includes it (CI already runs `make test`).
7. **Docs**: add one paragraph to `README.md` under “Development Workflow” explaining `spec_phase1_vs_sameboy` and artifact paths. (Your README already documents the workflow shape. )
