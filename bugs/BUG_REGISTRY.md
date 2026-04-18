# Bug Registry

This file catalogs all bugs available for injection into the RSD processor.

## Bug List

| ID | Name | Category | File | Description | Severity |
|----|------|----------|------|-------------|----------|
| BUG_001 | ALU_SUB_BUG | IntegerExecutionStage | IntALU.sv | Missing add one to subtraction result | High |
| BUG_002 | BYPASS_PRIORITY_INVERSION | Bypass | BypassNetwork.sv | Incorrect bypass stage priority causes stale data forwarding | High |
| BUG_003 | STORE_FORWARD_SHIFT_ERROR | Memory | LoadStoreUnit.sv | Wrong bit shift in store-to-load forwarding | Critical |
| BUG_004 | READY_BIT_BYPASS_RACE | Scheduler | ReadyBitTable.sv | Missing ready bit bypass for last wakeup port | Medium |
| BUG_005 | RECOVERY_PHASE_SKIP | Control | RecoveryManager.sv | Inverted reset condition breaks recovery state machine | Critical |
| BUG_006 | COMMIT_BOUNDARY_OFF_BY_ONE | Commit | CommitStage.sv | Off-by-one in instruction boundary detection | High |
| BUG_007 | STORE_QUEUE_WRAP_AROUND | Memory | StoreQueue.sv | Incorrect pointer wrap-around calculation | Medium |
| BUG_008 | BYPASS_CLEAR_ON_STALL | Bypass | BypassNetwork.sv | Bypass data incorrectly cleared during stalls | High |

## Categories

- **Pipeline**: Issues in pipeline stages (fetch, decode, execute, etc.)
- **Memory**: Load/store unit, cache, memory ordering bugs
- **Control**: Branch prediction, recovery, flush logic
- **Bypass**: Register bypass network issues
- **Scheduler**: Instruction scheduling bugs
- **Commit**: Commit stage and retirement logic

## Usage

```bash
# Inject single bug
python bugs/inject.py --bugs BUG_001

# Inject multiple bugs
python bugs/inject.py --bugs BUG_001 BUG_002

# List all available bugs
python bugs/inject.py --list

# Restore clean files
python bugs/inject.py --restore
```

## Adding New Bugs

1. Create a new bug definition file: `bugs/BUG_XXX.json`
2. Add entry to this registry
3. Test the bug injection: `python bugs/inject.py --bugs BUG_XXX --dry-run`
