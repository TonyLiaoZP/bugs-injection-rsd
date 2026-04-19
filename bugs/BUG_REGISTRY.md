# Bug Registry

This file catalogs all bugs available for injection into the RSD processor.

## Bug Types

- **Functional**: Causes incorrect architectural state (wrong register values, memory corruption). Detectable by comparing register dumps against golden values.
- **Microarchitectural**: Only manifests under specific pipeline timing conditions. May be functional when triggered, but hard to trigger from software. Best tested with UVM/directed RTL tests.

## Bug List

| ID | Name | Type | Category | File | Description | Severity |
|----|------|------|----------|------|-------------|----------|
| BUG_001 | ALU_SUB_BUG | Functional | IntegerExec | IntALU.sv | Missing add-one in subtraction | High |
| BUG_002 | BYPASS_PRIORITY_INVERSION | Functional | Bypass | BypassNetwork.sv | Stale data forwarded (EX/WB priority swap) | High |
| BUG_003 | STORE_FORWARD_SHIFT_ERROR | Microarchitectural | Memory | LoadStoreUnit.sv | Wrong bit shift in store-to-load forwarding | Critical |
| BUG_004 | SLT_SIGN_CONDITIONAL_SWAP | Functional | IntegerExec | IntALU.sv | SLT swaps operands when both have same sign | High |
| BUG_005 | COMMIT_BOUNDARY_OFF_BY_ONE | Functional | Commit | CommitStage.sv | Off-by-one in instruction boundary detection | High |
| BUG_006 | STORE_QUEUE_WRAP_AROUND | Microarchitectural | Memory | StoreQueue.sv | Pointer wrap-around off-by-one, entry leak | Medium |

## Summary

- **Total**: 6 bugs
- **Functional**: 4 (BUG_001, 002, 004, 005) — testable with assembly + register comparison
- **Microarchitectural**: 2 (BUG_003, 006) — needs UVM unit tests or specific pipeline timing

## Notes

- BUG_003: `ShiftForwardedData` only called during store-to-load forwarding. Back-to-back sw/lb in assembly doesn't reliably trigger it because stores may commit to cache before loads execute. Needs LSU UVM test.
- BUG_004: SLT comparison inverts when both operands have same sign bit. Same-sign comparisons fail, mixed-sign work correctly. Subtle conditional bug.
- BUG_006: Pointer off-by-one on wrap-around. Only triggers when store queue wraps, which requires enough in-flight stores. May cause functional errors if triggered.

## Removed Bugs

- BUG_004 (old): READY_BIT_BYPASS_RACE - Performance only, no functional impact
- BUG_008 (old): BYPASS_CLEAR_ON_STALL - Performance only, triggers replay but no wrong data

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
