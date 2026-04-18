# Bug Test Suite

This directory contains targeted assembly tests for each bug in the bug injection system.

## Test Structure

Each test is designed to trigger a specific bug and verify incorrect behavior when the bug is injected.

## Running Tests

1. **Inject the bug:**
   ```bash
   python bugs/inject.py --bugs BUG_XXX
   ```

2. **Copy test to test directory:**
   ```bash
   cp bugs/tests/BUG_XXX_test.s Processor/Src/Verification/TestCode/Asm/BugTest/code.s
   ```

3. **Run simulation:**
   ```bash
   cd Processor/Src
   make run
   ```

4. **Check results:**
   - With bug: Test should fail (assertion violation or wrong result)
   - Without bug: Test should pass

5. **Restore clean code:**
   ```bash
   python bugs/inject.py --restore
   ```

## Test Descriptions

| Bug ID | Test File | Description |
|--------|-----------|-------------|
| BUG_001 | BUG_001_test.s | Tests ALU subtraction - skipped (use IntRegImm) |
| BUG_002 | BUG_002_test.s | Tests bypass priority with back-to-back register writes |
| BUG_003 | BUG_003_test.s | Tests store-to-load forwarding with byte/halfword stores |
| BUG_004 | BUG_004_test.s | Tests ready bit bypass with maximum wakeup ports |
| BUG_005 | BUG_005_test.s | Tests recovery from branch misprediction |
| BUG_006 | BUG_006_test.s | Tests commit of multi-op instructions |
| BUG_007 | BUG_007_test.s | Tests store queue wrap-around behavior |
| BUG_008 | BUG_008_test.s | Tests bypass during pipeline stalls (cache miss) |

## Expected Behavior

- **Without bug:** All assertions pass, final result in a7 is correct
- **With bug:** Assertion fails or final result is incorrect
