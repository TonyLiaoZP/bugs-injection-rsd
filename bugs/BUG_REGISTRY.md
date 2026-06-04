# Bug Registry

This file catalogs all bugs available for injection into the RSD processor.

## Bug Types

- **Functional**: Causes incorrect architectural state (wrong register values, memory corruption). Detectable by comparing register dumps against golden values.
- **Microarchitectural (Demonstration Only)**: Only manifests under specific pipeline timing conditions that cannot be reliably triggered from software. Assembly tests serve as demonstrations but do not reliably catch these bugs. Requires UVM/directed RTL tests or formal verification.

## Bug List

| ID | Name | Type | Category | File | Description | Severity | Testable |
|----|------|------|----------|------|-------------|----------|----------|
| BUG_001 | ALU_SUB_BUG | Functional | IntegerExec | IntALU.sv | Missing add-one in subtraction | High | ✓ |
| BUG_002 | BYPASS_PRIORITY_INVERSION | Functional | Bypass | BypassNetwork.sv | Stale data forwarded (EX/WB priority swap) | High | ✓ |
| BUG_003 | STORE_FORWARD_SHIFT_ERROR | Microarchitectural | Memory | LoadStoreUnit.sv | Wrong bit shift in store-to-load forwarding | Critical | ✗ Demo only |
| BUG_004 | SLT_SIGN_CONDITIONAL_SWAP | Functional | IntegerExec | IntALU.sv | SLT swaps operands when both have same sign | High | ✓ |
| BUG_005 | COMMIT_BOUNDARY_OFF_BY_ONE | Functional | Commit | CommitStage.sv | Off-by-one in instruction boundary detection | High | ✓ |
| BUG_006 | STORE_QUEUE_WRAP_AROUND | Microarchitectural | Memory | StoreQueue.sv | Pointer wrap-around off-by-one, entry leak | Medium | ✗ Demo only |

## Summary

- **Total**: 6 bugs
- **Reliably Testable**: 4 (BUG_001, 002, 004, 005) — caught by assembly tests with register comparison
- **Demonstration Only**: 2 (BUG_003, 006) — require UVM/RTL tests, assembly tests demonstrate concept only

## Bug Details

### Reliably Testable Bugs (✓)

These bugs are **caught by assembly tests** and produce wrong register values:

- **BUG_001**: Subtraction always wrong (missing +1 in two's complement)
- **BUG_002**: Stale data forwarded (wrong bypass priority)
- **BUG_004**: SLT comparison inverted for same-sign operands
- **BUG_005**: Commits wrong number of instructions (off-by-one)

### Demonstration Only Bugs (✗)

These bugs **cannot be reliably caught** by assembly tests due to timing dependencies:

#### BUG_003: Store-to-Load Forwarding Shift Error
- **Why not testable**: Only triggers when store is in queue AND load forwards from it
- **Problem**: In assembly tests, stores commit to cache before loads execute
- **Result**: Forwarding path never used, bug never triggered
- **Assembly test**: Demonstrates the intended test scenario but doesn't catch the bug
- **To actually test**: Requires UVM testbench that controls store queue commit timing

#### BUG_006: Store Queue Wrap-Around
- **Why not testable**: Only triggers when store queue fills and wraps around
- **Problem**: Assembly tests don't generate enough store pressure
- **Result**: Queue never fills, wrap-around never happens
- **Assembly test**: Demonstrates store-heavy code but doesn't fill the queue
- **To actually test**: Requires directed RTL test that fills queue to capacity

## Verification Requirements

### For Testable Bugs (BUG_001, 002, 004, 005)
```bash
# Inject bug
python bugs/inject.py --bugs BUG_001 --rsd-root ..

# Run test (will fail with NG)
./run_test.sh BUG_001_test

# Restore
python bugs/inject.py --restore --rsd-root ..
```

### For Demonstration Bugs (BUG_003, 006)

**Assembly tests demonstrate the concept but do NOT catch the bugs.**

To actually verify these bugs, you need:

1. **Directed RTL unit test (BUG_003)**
   - `Processor/Src/Verification/UnitTest/StoreForward/` — StoreQueue + LoadStoreUnit
   - Run: `./bugs/run_bug003_unit_test.sh` (Verilator by default; `--questa` for ModelSim/Questa)

2. **UVM Testbench** (optional, broader coverage)
   - Control pipeline timing
   - Force specific microarchitectural states
   - Monitor internal signals

2. **Directed RTL Tests**
   - Constrained random testing
   - Coverage-driven verification
   - Specific scenario generation

3. **Formal Verification**
   - Prove correctness of forwarding logic
   - Verify pointer arithmetic
   - Check all corner cases

## Usage

```bash
# List all bugs
python bugs/inject.py --list

# Inject single bug
python bugs/inject.py --bugs BUG_001 --rsd-root ..

# Inject multiple bugs
python bugs/inject.py --bugs BUG_001 BUG_002 --rsd-root ..

# Test a bug (only works for testable bugs)
cd bugs
./run_test.sh BUG_001_test

# Restore clean files
python bugs/inject.py --restore --rsd-root ..
```

## Adding New Bugs

1. Create bug definition: `bugs/BUG_XXX.json`
2. Create assembly test: `bugs/tests/BUG_XXX_test.s`
3. Generate golden cfg: `./generate_cfg.sh BUG_XXX_test.s`
4. Test injection: `python bugs/inject.py --bugs BUG_XXX --dry-run`
5. Verify detection: `./run_test.sh BUG_XXX_test`
6. Update this registry

**Important**: Mark as "Demonstration Only" if the bug requires specific timing conditions that assembly tests cannot reliably create.
