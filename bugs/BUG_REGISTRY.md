# Bug Registry

This file catalogs all bugs available for injection into the RSD processor.

## Bug List

| ID | Name | Category | File | Description | Severity |
|----|------|----------|------|-------------|----------|
| BUG_001 | EXAMPLE_BUG | Pipeline | IntegerExecutionStage.sv | Example bug for demonstration | Medium |

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
