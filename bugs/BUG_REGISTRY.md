# Bug Registry

This file catalogs all bugs available for injection into the RSD processor.

## Bug Types

- **Functional**: Causes incorrect architectural state (wrong register values, memory corruption). Detectable by comparing register dumps against golden values.
- **Performance**: Causes stalls or reduced IPC but produces correct final results. Detectable only by performance counters or cycle-level analysis.
- **Microarchitectural**: Only manifests under specific pipeline timing conditions. May be functional when triggered, but hard to trigger from software. Best tested with UVM/directed RTL tests.

## Bug List

| ID | Name | Type | Category | File | Description | Severity |
|----|------|------|----------|------|-------------|----------|
| BUG_001 | ALU_SUB_BUG | Functional | IntegerExec | IntALU.sv | Missing add-one in subtraction | High |
| BUG_002 | BYPASS_PRIORITY_INVERSION | Functional | Bypass | BypassNetwork.sv | Stale data forwarded (EX/WB priority swap) | High |
| BUG_003 | STORE_FORWARD_SHIFT_ERROR | Microarchitectural | Memory | LoadStoreUnit.sv | Wrong bit shift in store-to-load forwarding | Critical |
| BUG_004 | READY_BIT_BYPASS_RACE | Performance | Scheduler | ReadyBitTable.sv | Misses last wakeup port bypass, 1-cycle stall | Medium |
| BUG_005 | SHIFTER_ASR_OFF_BY_ONE | Functional | Execution | Shifter.sv | Arithmetic shift right off-by-one error | High |
| BUG_006 | COMMIT_BOUNDARY_OFF_BY_ONE | Functional | Commit | CommitStage.sv | Off-by-one in instruction boundary detection | High |
| BUG_007 | STORE_QUEUE_WRAP_AROUND | Microarchitectural | Memory | StoreQueue.sv | Pointer wrap-around off-by-one, entry leak | Medium |
| BUG_008 | BYPASS_CLEAR_ON_STALL | Functional | Bypass | BypassNetwork.sv | Bypass data cleared during stalls | High |

## Summary

- **Total**: 8 bugs
- **Functional**: 6 (BUG_001, 002, 005, 006, 008) — testable with assembly + register comparison
- **Performance**: 1 (BUG_004) — requires IPC/cycle-count comparison
- **Microarchitectural**: 1 (BUG_003, 007) — needs UVM unit tests or specific pipeline timing

## Notes

- BUG_003: `ShiftForwardedData` only called during store-to-load forwarding. Back-to-back sw/lb in assembly doesn't reliably trigger it because stores may commit to cache before loads execute. Needs LSU UVM test.
- BUG_004: Loop bound `WAKEUP_WIDTH-1` misses last wakeup port. Instruction still wakes up next cycle via ready bit table update. No register difference, only IPC degradation.
- BUG_007: Pointer off-by-one on wrap-around. Only triggers when store queue wraps, which requires enough in-flight stores. May cause functional errors if triggered.

## Usage

```bash
# Inject single bug
python bugs/inject.py --bugs BUG_001 --rsd-root ..

# Inject multiple bugs
python bugs/inject.py --bugs BUG_001 BUG_002 --rsd-root ..

# List all available bugs
python bugs/inject.py --list

# Restore clean files
python bugs/inject.py --restore --rsd-root ..
```

## Adding New Bugs

1. Create a new bug definition file: `bugs/BUG_XXX.json`
2. Add entry to this registry
3. Test the bug injection: `python bugs/inject.py --bugs BUG_XXX --dry-run`
