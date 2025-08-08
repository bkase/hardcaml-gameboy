Love it. Here’s a **from-repo to tight feedback loop** plan that (a) keeps it minimal, (b) uses **Jane Street Core**/Base throughout, and (c) gets you a **SameBoy-vs-DUT differential test** you can run with one command. No code—just exact changes, file adds, and why.

---

# Where we’re starting (summary)

* Dune project with a demo Hardcaml counter in `src/`.
* Nix flake dev shell (opam, z3, build tools).
* No tests, no ROMs, no oracle, no lockstep harness.

We’ll add just enough structure to:

1. build a tiny homebrew ROM (`flat_bg.gb`),
2. run **SameBoy** headlessly to produce pixels,
3. run your **DUT** (initially: a trivially-correct spec model stub) to produce the same pixels,
4. compare **visible pixel streams for 2 lines** and fail on first diff, dumping artifacts.

Keep the “guard golden” (one optional frame) for later; the core loop is **live differential**—fastest iteration.

---

# Step 1 — Align the OCaml stack on Jane Street Core

**Why:** you said we’re a Jane Street stack shop; let’s keep `Core` as our standard lib for tests, tools, and the spec model. It also gives us `Command`, `Or_error`, `Expect_test_helpers` if we want.

**What to change**

* `dune-project`: ensure dependencies on `core`, `base`, `stdio`, `hardcaml`, `alcotest`, and `digestif` (for hashing logs/artifacts).
* `src/dune`: keep linking against `core`/`base` already (looks fine).
* Add a `test/` dune stanza that links against `core`, `alcotest`, `digestif.unix`.

**Why no `Stdlib` vendoring:** Core subsumes what we need; we’ll avoid mixing `Stdlib` APIs in tests.

---

# Step 2 — Expand the dev shell so everything builds reproducibly

**Why:** we need to compile one tiny ROM and build the SameBoy library. That’s `rgbds`, `make`, a C compiler, and optionally ImageMagick for pretty diffs.

**Add to `flake.nix` devShell buildInputs**

* `rgbds` (assembler toolchain),
* `clang` (or `gcc`),
* `gnumake`,
* `pkg-config`,
* `imagemagick` (optional, for PNG previews of diffs),
* (Optional) `jq` if we keep small JSON meta.

**Result:** `nix develop` puts all needed tools on PATH so both engineers and CI are in the same world.

---

# Step 3 — Vendor SameBoy (oracle) and set a single build target

**Why:** we want an **in-process** oracle we can call from tests without GUI. SameBoy’s **`lib`** target is stable for this.

**Actions**

* `git submodule add https://github.com/LIJI32/SameBoy vendor/SameBoy`
* Pin to a known tag (e.g., `v1.0.2`) for stability.
* We’ll **not** write the C runner here (your team will), but plan the build:

  * `make -C vendor/SameBoy lib` produces `build/include` & `build/bin/libsameboy.a`.
* Add `tools/Makefile` with a `sameboy_headless` target that links against the lib.

  * The tool takes: `rom`, `frames`, `out_dir`, and emits:

    * a raw `frame_0001.rgba` (160×144×4), and
    * (optional) a `frame_0001.ppm` you can preview.

**Why a submodule vs package manager?** Determinism, single source of truth, easy to bump and re-run “guard golden.”

---

# Step 4 — Create a *single tiny* homebrew ROM for day one

**Why:** skip the boot ROM licensing and complexity. A homebrew **deterministic** ROM means you control VRAM/tilemap and guarantee easy-to-verify visuals.

**Add**

* `roms/flat_bg.asm` (RGBDS):

  * LCD off, write a single checkerboard tile at `$8000`,
  * Fill BG map `$9800` with tile index 0,
  * Set palette and `SCX=SCY=0`,
  * LCD on, halt loop.
* `roms/Makefile` with three rules: `flat_bg.gb`, `clean`, and a phony `all`.

  * Build recipe: `rgbasm`, `rgblink`, `rgbfix -p 0xFF`.

**Outcome:** `make -C roms` yields `roms/flat_bg.gb` in milliseconds.

---

# Step 5 — Define the **comparison unit** and artifacts

**Why:** agree on the minimal signal we compare right now to keep tests blazing fast.

**Unit:** **visible pixel stream for 2 scanlines**

* For `LY=0` and `LY=1`, collect `160` pixels each from both:

  * **SameBoy oracle**: `[(y, x, r, g, b)]`
  * **DUT (spec stub at first)**: same tuple.
* Compare **in order**; stop at the **first mismatch**.

**Artifacts to write on mismatch**

* `_artifacts/<rom>/trace.expected.csv` and `trace.actual.csv` (two lines of triples),
* `_artifacts/<rom>/line0.diff.ppm` and `line1.diff.ppm` (abs per-channel delta),
* If ImageMagick exists: `_artifacts/<rom>/side_by_side.png`.

**Why 2 lines, not a frame?** Faster iteration, clearer diffs while you bring up timing/FIFO/SCX. We can add a frame-level test as a second (slower) case.

---

# Step 6 — Add the test harness (Alcotest) and wire the steps

**Why:** one command: `ROM=roms/flat_bg.gb dune test` runs the whole lockstep and fails fast with good artifacts.

**Test flow**

1. **Pre-build hooks**

   * `dune` test rule runs:

     * `make -C vendor/SameBoy lib` (idempotent),
     * `make -C tools` (builds `sameboy_headless`),
     * `make -C roms` (makes `flat_bg.gb`).
2. **Oracle run**

   * Execute `./tools/sameboy_headless roms/flat_bg.gb 1 _build/_oracle/flat_bg/`
   * This dumps `frame_0001.rgba` (and optionally `.ppm`).
3. **DUT run (initially a spec stub)**

   * Execute your **OCaml spec tool** (to be implemented by your team) that, with no ROM knowledge, **replays the same scenario deterministically** and produces:

     * `_build/_dut/flat_bg/visible_stream.csv` for lines 0–1,
     * (Optionally) a partial-frame RGBA to make visual diffs trivial later.
   * For day zero, the spec can simply **read the same VRAM bytes** from a sidecar, or you can make a “scripted background” version that doesn’t even load a ROM—either is fine. The key is the **visible stream API** and determinism.
4. **Compare**

   * Read oracle visible pixels (from its RGBA: line slicing is trivial).
   * Read DUT visible pixels (from CSV or RGBA).
   * Compare tuple-by-tuple; if mismatch:

     * Write artifacts (CSV, PPM/PNG),
     * Print the first \~10 mismatches `(ly, x): exp rgb -> act rgb (Δ)`,
     * Fail.
   * If match: print a short success with a content hash for traceability.

**Dune + env**

* The test binary reads `ROM` env var (default to `roms/flat_bg.gb`).
* Keep an env flag (e.g., `ALCOTEST_SLOW=1`) to also run a **frame-level** compare and dump `expected/actual/diff` images—off by default.

---

# Step 7 — (Optional) Add one **tiny guard golden**

**Why:** catches accidental drift if someone bumps `vendor/SameBoy` or changes harness math.

**What**

* After you trust the loop, **capture SameBoy’s `frame_0001.rgba`** for `flat_bg.gb`,
* Commit **just that one file** to `test/golden/flat_bg/`,
* Add a small test that **re-runs SameBoy** and compares bytes to the golden.
* Use this test in CI or pre-merge (not your default quick loop).

**Why not more?** Keep repo lean; one guard is enough to detect harness/oracle drift. Real coverage comes from live differential tests.

---

# Step 8 — CI wiring (lightweight)

**Why:** ensure the same loop runs in CI and keeps “it works on my machine” under control.

**Actions**

* Ensure CI uses `nix develop` (or `nix build` + `nix develop`-like shell) so `rgbds`, `make`, `clang`, `imagemagick` are present.
* `git submodule update --init --recursive` before `dune test`.
* Cache `_build/` between runs (optional).
* Keep `ALCOTEST_SLOW=0` in PR checks; run slow frame compare and guard golden in nightly or pre-merge.

---

# Step 9 — Developer workflow (what engineers will actually type)

1. `nix develop`
2. First-time opam: `opam init --disable-sandboxing` and `opam install core hardcaml alcotest digestif --yes`
3. `git submodule update --init --recursive`
4. `ROM=roms/flat_bg.gb dune test`

* On failure, open `_artifacts/flat_bg/side_by_side.png` or `line*.diff.ppm`, and fix.
* When you intentionally change expected behavior **of the guard golden**:

  * Re-run oracle, inspect, then **promote** the new `frame_0001.rgba` into `test/golden/flat_bg/` (add a tiny `tools/promote_golden.sh` later if you want handrails).

---

# Step 10 — File/dir diff you’ll implement (no code here—just structure)

**New/changed**

```
vendor/
  SameBoy/                 # git submodule (pinned tag), built with `make lib`

tools/
  Makefile                 # builds sameboy_headless (links libsameboy.a)
  sameboy_headless         # built artifact (ignored by git)
  # (engineers implement the C file; we already defined the interface)

roms/
  flat_bg.asm              # tiny checkerboard ROM
  Makefile                 # rgbasm/rgblink/rgbfix targets

test/
  dune                     # test stanza; pre-build rules (make vendor lib, tools, rom)
  oracle_lockstep.ml       # Alcotest runner (SameBoy vs DUT visible-stream 2 lines)
  # (engineers implement OCaml test runner; uses Core)

_build/
  _oracle/flat_bg/         # SameBoy outputs (ignored by git)
  _dut/flat_bg/            # DUT outputs (ignored by git)

_artifacts/
  flat_bg/                 # diffs & traces on failure (ignored by git)

test/golden/ (optional later)
  flat_bg/
    frame_0001.rgba        # guard golden
    meta.json              # width/height/format
```

**Minor edits**

* `dune-project`: add `alcotest` and `digestif` dependencies to the package.
* `flake.nix`: add `rgbds`, `clang (or gcc)`, `gnumake`, `pkg-config`, `imagemagick` to `buildInputs`.
* `.gitignore`: ensure `_artifacts/`, `vendor/SameBoy/build/`, `tools/sameboy_headless` are ignored.

---

# Step 11 — Why this sequence works (and what to defer)

* **Start with ownable ROM** → instant pixels, no legal/boot weirdness.
* **Compare 2 lines** → super fast, easy to understand diffs while you bring up timing and the BG path.
* **Live differential vs SameBoy** → no golden churn while you’re still changing things daily.
* **One guard golden** (later) → catches harness/oracle drift with negligible repo bloat.
* **Defer cgb-acid2/mooneye** until BG/window are stable; they’re perfect when your spec model + RTL can already draw robustly.

---

# Step 12 — Next milestones (after day-one loop is green)

* Add **spec model** implementation for BG path (SCX=0 first) that emits the same visible stream; keep SameBoy as truth.
* Add **SCX fine scroll**; extend the ROM to program `SCX=1…7`.
* Add **window**; make a second ROM with `WX/WY` toggled mid-line.
* Only after BG/window correctness feels solid, widen the comparison to a **full frame** and eventually bring in **sprites**.

---

If you want, I’ll turn this into a **checklist PR template** (with the exact file adds/edits listed as tasks) so your team can parallelize: one person vendors SameBoy, one wires the ROM build, one writes the lockstep harness, and one stubs the spec model.
