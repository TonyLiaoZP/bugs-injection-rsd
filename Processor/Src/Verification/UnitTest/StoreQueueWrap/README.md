# BUG_006 — Store Queue Wrap-Around Unit Test

Directed RTL test for **BUG_006** (`STORE_QUEUE_WRAP_AROUND`): an extra `+ 1` in the
wrap-around branch of `allocatedStoreQueuePtr` in `StoreQueue.sv` when
`tailPtr + pushCount >= STORE_QUEUE_ENTRY_NUM` during a dual-rename allocation.

## DUT

- **StoreQueue only** (no LoadStoreUnit / forwarding).
- `TbRecoveryStub` ties recovery inactive.
- Head release via `releaseStoreQueueHead` simulates commit pop without executing stores.

## Run

From repo root (after `source SetEnv.sh` if you use a custom Verilator):

```bash
./bugs/run_bug006_unit_test.sh
./bugs/run_bug006_unit_test.sh --with-bug   # must FAIL, then restores RTL
```

Or from this directory:

```bash
make -f Makefile.verilator.mk run
```

Build artifacts: `Processor/Project/Verilator/StoreQueueWrap/obj_dir/`.

## Test cases (C++ `TestMain_BUG006.cpp`)

| Case | What it checks |
|------|----------------|
| `dual_alloc_no_wrap` | After reset, allocate 2 lanes at empty SQ → pointers **0**, **1**. |
| `wrap_second_lane` | Minimal directed wrap: dual-alloc at **tail=15** → lane1 must be **0** (white-box / golden scenario). |
| `wrap_stress_slot_invariant` | **Functional / ref-FIFO**: 32× (fill with dual alloc → release 2 → optional single alloc). Each allocate compares hardware indices to a **spec FIFO model** (“new entries” for this push). Also checks no **phantom** allocate (marked slot not in ring) or **missing** allocate (in ring but never marked). Does not assert a fixed `ptr1==0`; mismatch messages use `{ref-FIFO new entries}` vs `{hardware}`. |

### Stimulus outline for `wrap_second_lane`

1. Seven cycles of dual allocate (2×7 entries) until `storeQueueAllocatable` is false and count=14 (tail=14).
2. Release one head entry (count=13).
3. Allocate lane 0 only → index 14 (tail→15).
4. Release one head entry (count=13, tail still 15).
5. Dual allocate → second lane must wrap to index **0**.

With **BUG_006** injected, `wrap_second_lane` and `wrap_stress_slot_invariant` fail (stress often first at `ref-FIFO new entries {15,0} vs hardware {15,1}`).

## Files

| File | Role |
|------|------|
| `tb_sq_wrap.sv` | `TestStoreQueueWrapTop` wrapper |
| `tb_recovery_stub.sv` | Recovery IF stub |
| `Makefile.verilator.mk` | Verilator build |
| `../../../SysDeps/Verilator/TestMain_BUG006.cpp` | Test stimulus |
| `../../../bugs/run_bug006_unit_test.sh` | Runner + optional inject |

Stubs under `../StoreForward/verilator_stubs/` are reused (RecoveryManagerIF, etc.).
