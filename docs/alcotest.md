# Alcotest Testing Guide

## Overview

Alcotest is a lightweight, colorful test framework for OCaml that provides clear test output and good integration with dune.

## Basic Structure

### Test Modules

```ocaml
(* Basic test structure *)
let test_addition () =
  Alcotest.(check int) "same ints" 4 (2 + 2)

let test_string () =
  Alcotest.(check string) "same strings" "hello" "hello"

(* Tests are grouped into test cases *)
let arithmetic_tests = [
  ("addition", `Quick, test_addition);
  ("string equality", `Quick, test_string);
]

(* Run tests *)
let () =
  Alcotest.run "My Test Suite"
    [
      ("arithmetic", arithmetic_tests);
    ]
```

## Testable Types

Alcotest needs to know how to compare and display values:

```ocaml
(* Built-in testables *)
Alcotest.int      (* for integers *)
Alcotest.string   (* for strings *)
Alcotest.bool     (* for booleans *)
Alcotest.float    (* for floats *)
Alcotest.list     (* for lists *)
Alcotest.array    (* for arrays *)
Alcotest.option   (* for options *)
Alcotest.result   (* for results *)

(* Custom testable *)
let rgb555 = Alcotest.testable 
  (fun ppf x -> Format.fprintf ppf "0x%04x" x)  (* pp function *)
  (=)                                             (* equal function *)
```

## Check Functions

```ocaml
(* Basic check *)
Alcotest.(check int) "description" expected actual

(* Check with custom testable *)
Alcotest.(check (array rgb555)) "framebuffer" expected_fb actual_fb

(* Other assertions *)
Alcotest.fail "This test always fails"
Alcotest.check_raises "raises exception" 
  (Invalid_argument "foo") 
  (fun () -> invalid_arg "foo")
```

## Test Speed Levels

- `` `Quick`` - Always run (default)
- `` `Slow`` - Skipped with `-q` flag  

## Test Organization

```ocaml
(* Individual test function *)
let test_checkerboard () =
  let expected = create_expected_pattern () in
  let actual = Phase1_checker_spec.render () in
  Alcotest.(check (array int)) "checkerboard pattern" expected actual

(* Group related tests *)
let spec_tests = [
  ("checkerboard generation", `Quick, test_checkerboard);
  ("rgb555 packing", `Quick, test_rgb555_pack);
  ("ppm writing", `Quick, test_ppm_write);
]

let oracle_tests = [
  ("sameboy comparison", `Quick, test_vs_sameboy);
]

(* Run all test groups *)
let () =
  Alcotest.run "PPU Spec Tests"
    [
      ("spec", spec_tests);
      ("oracle", oracle_tests);
    ]
```

## File I/O in Tests

```ocaml
let test_file_output () =
  (* Generate test data *)
  let data = generate_test_data () in
  
  (* Write to file *)
  let path = "_build/test_output.bin" in
  write_file path data;
  
  (* Read back and verify *)
  let read_data = read_file path in
  Alcotest.(check string) "file contents" data read_data
```

## Comparing Binary Data

```ocaml
(* For binary comparison with detailed mismatch reporting *)
let test_binary_equality () =
  let expected = load_expected_binary () in
  let actual = generate_actual_binary () in
  
  (* Compare arrays element by element *)
  match Array.length expected = Array.length actual with
  | false -> 
    Alcotest.fail (Printf.sprintf "Length mismatch: %d vs %d" 
      (Array.length expected) (Array.length actual))
  | true ->
    Array.iteri (fun i exp_val ->
      let act_val = actual.(i) in
      if exp_val <> act_val then begin
        (* Report first mismatch with detail *)
        let x = i mod 160 in
        let y = i / 160 in
        Alcotest.fail (Printf.sprintf 
          "Mismatch at pixel (%d,%d): expected=0x%04x actual=0x%04x"
          x y exp_val act_val)
      end
    ) expected
```

## Artifacts on Test Failure

```ocaml
let test_with_artifacts () =
  let expected = load_oracle_data () in
  let actual = run_spec () in
  
  if expected <> actual then begin
    (* Save artifacts for debugging *)
    save_artifact "_artifacts/expected.ppm" expected;
    save_artifact "_artifacts/actual.ppm" actual;
    save_artifact "_artifacts/diff.ppm" (compute_diff expected actual);
    
    (* Log mismatches *)
    let mismatches = find_mismatches expected actual in
    List.iter (fun (x, y, exp, act) ->
      Printf.printf "(%d,%d): exp=0x%04x act=0x%04x\n" x y exp act
    ) (List.take mismatches 10);
    
    Alcotest.fail "Frame comparison failed - see _artifacts/"
  end
```

## Integration with Dune

```lisp
;; test/dune
(test
 (name my_test)
 (libraries alcotest my_lib)
 (deps
  (source_tree ../data)    ; Test data dependencies
  ../roms/test.gb)          ; ROM dependencies
 (action
  (run %{test} -v)))        ; Run with verbose output
```

## Running Tests

```bash
# Run all tests
dune test

# Run specific test executable
dune exec test/my_test.exe

# Run with options
dune exec test/my_test.exe -- --verbose
dune exec test/my_test.exe -- --compact
dune exec test/my_test.exe -- test "spec"  # Run only "spec" suite
```

## Best Practices

1. **Descriptive Names**: Use clear test and assertion descriptions
2. **Small Tests**: Keep individual tests focused on one thing
3. **Deterministic**: Ensure tests always produce same results
4. **Fast by Default**: Mark slow tests with `` `Slow``
5. **Meaningful Failures**: Include context in failure messages
6. **Save Artifacts**: For visual tests, save output on failure

## Example: RGB555 Test

```ocaml
let test_rgb555_operations () =
  (* Test packing *)
  let packed = Rgb.pack_rgb555 ~r5:31 ~g5:0 ~b5:0 in
  Alcotest.(check int) "red packed correctly" 0x7C00 packed;
  
  (* Test unpacking *)
  let r5, g5, b5 = Rgb.unpack_rgb555 0x03E0 in
  Alcotest.(check int) "green channel" 31 g5;
  Alcotest.(check int) "red channel" 0 r5;
  Alcotest.(check int) "blue channel" 0 b5;
  
  (* Test conversion to RGB888 *)
  let r8, g8, b8 = Rgb.to_rgb888 ~rgb555:0x7FFF in
  Alcotest.(check int) "white R8" 255 r8;
  Alcotest.(check int) "white G8" 255 g8;
  Alcotest.(check int) "white B8" 255 b8
```