# Store-to-load forwarding unit test (BUG_003)

Directed testbench for **BUG_003** (`LoadStoreUnit.sv` forwarding shift).  
DUT: `StoreQueue` + `LoadStoreUnit` (no DCache, no full core).

## Why this exists

Assembly `bugs/tests/BUG_003_test.s` does not reliably exercise SQ forwarding: stores often commit before the dependent load executes. This bench **keeps the store in the SQ** and runs a dependent **byte load before commit**, so the path must use store-to-load forwarding instead of the DCache.

**BUG_003** changes `ShiftForwardedData` in `LoadStoreUnit.sv` from `*8` (bytes) to `*4`, misaligning forwarded data. Without the bug, all four directed cases pass; with `--with-bug` injection they should fail on `executedLoadData`.

## Test structure

Two drivers share the same DUT (`TestStoreForwardTop` in `tb_sq_lsu_wrap.sv`):

| Layer | File | Role |
|-------|------|------|
| **DUT** | `StoreQueue.sv`, `LoadStoreUnit.sv` | Forwarding match, data read, `*8` shift, sign/zero extend |
| **Wrapper** | `tb_sq_lsu_wrap.sv` | Minimal LSU environment: no LoadQueue/D$; **no SQ commit/release** |
| **Golden model** | `rsd_store_forward_ref_pkg.sv` (Questa), `ref_forward_byte_load()` in C++ (Verilator) | Correct block shift + `*8` byte extract + extend |
| **Questa driver** | `TestBUG_003.sv` | `run_forward_case` task, `#(posedge)` timing |
| **Verilator driver** | `SysDeps/Verilator/TestMain_BUG003.cpp` | C++ clock steps, flat `vl_*` ports (recommended) |
| **Stubs** | `tb_controller_stub.sv`, `tb_recovery_stub.sv`, `verilator_stubs/` | `stall=0`, recovery idle |

```
  TestMain_BUG003.cpp  or  TestBUG_003.sv
              |
              v
       TestStoreForwardTop (tb_sq_lsu_wrap.sv)
       +-- TbControllerStub / TbRecoveryStub
       +-- StoreQueue  <---LoadStoreUnitIF--->  LoadStoreUnit
```

Verilator builds only `TestStoreForwardTop` + C++ (`+define+RSD_FUNCTIONAL_SIMULATION_VERILATOR`). Questa additionally compiles `TestBUG_003.sv` with a clock generator.

## Per-case sequence

Each case runs the same four phases (`run_forward_case` / `run_case`):

| Phase | Action | Notes |
|-------|--------|-------|
| 1. Reset | Hold `rst` for several cycles | Expect `storeQueueCount == 0` |
| 2. Allocate | Pulse `allocateStoreQueue[0]` | Capture `sqIdx` (usually `0`); `sqTail = sqIdx + 1` for load bound |
| 3. Execute store | Pulse `executeStore` (word) into `SQ[sqIdx]` | Sets `finished`; **no** `commitStore` |
| 4. Execute load | Pulse `executeLoad` (byte), same LSQ block | `executedStoreQueuePtrByLoad = sqTail`; check forward + data |

Wrapper ties off commit/release so the store stays in the SQ until the load forwards from it.

## What is checked

Each case is judged twice:

1. **Forwarding (StoreQueue)**  
   - `storeLoadForwarded[0] == 1`  
   - `forwardMiss[0] == 0`

2. **Data (LoadStoreUnit)**  
   - `executedLoadData[0]` matches the reference model (including sign extension)

With BUG_003 injected, forwarding may still succeed, but data will be wrong (e.g. expected `0x33`, actual `0x34`).

## Test cases

Aligned with `bugs/tests/BUG_003_test.s`. Base address `TEST_BLOCK_BASE = 0x8000_0000`.  
Every case: **store = 32-bit word**, **load = byte**. Addresses are driven as 22-bit `PhyAddrPath` (logical address truncated), matching Questa integer-to-packed assignment.

| Case | Store addr | Load addr | Store data | Load mode | Expected `executedLoadData` | Intent |
|------|------------|-----------|------------|-----------|----------------------------|--------|
| `byte_offset_1` | `0x8000_0000` | `0x8000_0001` | `0x11223344` | signed byte | `0x00000033` | Byte 1 of word, sign-extended |
| `byte_offset_2` | `0x8000_0004` | `0x8000_0006` | `0x55667788` | signed byte | `0x00000066` | Byte at offset 6 in block |
| `byte_offset_3` | `0x8000_0008` | `0x8000_000B` | `0x99AABBCC` | signed byte | `0xFFFFFF99` | Byte `0x99`, sign-extended |
| `byte_offset_0_unsigned` | `0x8000_0010` | `0x8000_0010` | `0xAABBCCDD` | unsigned byte | `0x000000DD` | Same-address byte 0, zero-extended |

Example (`byte_offset_1`):

```
Word in memory:  [44][33][22][11]  @ 0x8000_0000
Store:           word 0x11223344 into SQ
Load:            byte @ +1 → 0x33 → sign extend → 0x00000033
```

Reference model steps (see `rsd_store_forward_ref_pkg.sv`):

1. Shift store data into LSQ block layout (`ref_generate_store_block`, same idea as `GenerateStoreData`)
2. Shift block by load byte offset with `*8` per byte (`ref_shift_forwarded_data`)
3. Apply `ref_extend_load_data` (signed or unsigned byte)

## BUG_003 mapping

| Stage | Module | Covered by this test? |
|-------|--------|------------------------|
| Addr/byte match, picker | `StoreQueue` | Exercised; not the injected bug |
| Block byte shift | `LoadStoreUnit::ShiftForwardedData` | **BUG_003 target** (`*8` vs `*4`) |
| Sign/zero extend | `LoadStoreUnit::ExtendLoadData` | Case 3 / case 4 |

Definition: `bugs/definitions/BUG_003.json`.

## Run with Verilator (recommended, no Questa)

Verilator 4.x cannot compile `TestBUG_003.sv` tasks with multiple `@(posedge)`.  
The pure-Verilator flow uses:

- Top: `TestStoreForwardTop` with flat `vl_*` ports (`RSD_FUNCTIONAL_SIMULATION_VERILATOR`)
- Driver: `Processor/Src/SysDeps/Verilator/TestMain_BUG003.cpp`
- Stubs: `verilator_stubs/` (`ControllerIF` / `RecoveryManagerIF` / `PipelineTypes`)

```bash
source SetEnv.sh   # optional: sets RSD_VERILATOR_BIN
cd Processor/Src/Verification/UnitTest/StoreForward
make -f Makefile.verilator.mk run
```

Or from repo root:

```bash
./bugs/run_bug003_unit_test.sh
```

Build output: `Processor/Project/Verilator/StoreForward/obj_dir/VTestStoreForwardTop_sim`

Requires Verilator **4.x** (tested with 4.228). Set `RSD_VERILATOR_BIN` if `verilator` is not on `PATH`.

Cycle-sim notes: `StoreQueue` mirrors addr fields under `RSD_FUNCTIONAL_SIMULATION_VERILATOR` (Verilator packed-struct quirk); `CircularRangePicker` and `LSQ_ToWordByteEnable` were corrected for single-entry SQ forwarding.

## Run with Questa / ModelSim (optional)

```bash
source SetEnv.sh    # RSD_QUESTASIM_PATH required
cd Processor/Src/Verification/UnitTest/StoreForward
make run
```

Or:

```bash
./bugs/run_bug003_unit_test.sh --questa
```

## Regression with bug injected (should fail)

```bash
./bugs/run_bug003_unit_test.sh --with-bug
```

## Files

| File | Role |
|------|------|
| `tb_sq_lsu_wrap.sv` | `TestStoreForwardTop` — DUT wrapper (+ `vl_*` ports for Verilator) |
| `TestBUG_003.sv` | Questa test (tasks + `@(posedge)`) |
| `rsd_store_forward_ref_pkg.sv` | Golden model (*8 shift) |
| `Makefile` | Questa |
| `Makefile.verilator.mk` | Verilator |
| `SysDeps/Verilator/TestMain_BUG003.cpp` | Verilator test driver |
| `bugs/run_bug003_unit_test.sh` | One-shot run (default: Verilator) |
| `bugs/definitions/BUG_003.json` | Bug injection spec |
