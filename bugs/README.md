# Bug Injection System for RSD Processor

This directory contains the bug injection infrastructure for the RSD processor. It allows you to inject known bugs into the RTL for testing bug detection methods, verification tools, or LLM-based code analysis.

## Design Philosophy

- **Clean master branch**: The master branch contains no bug injection code or hints
- **Separate bug definitions**: Each bug is defined in a JSON file with precise patch locations
- **No LLM hints**: The injected code contains no `ifdef` markers or comments that would hint at bugs
- **Scriptable injection**: Bugs are applied programmatically before compilation
- **Easy restoration**: Original files can be restored with a single command

## Directory Structure

```
bugs/
├── README.md              # This file
├── BUG_REGISTRY.md        # Catalog of all available bugs
├── inject.py              # Bug injection script
├── definitions/           # Bug definition files
│   ├── BUG_001.json
│   ├── BUG_002.json
│   └── ...
├── tests/                 # Assembly test files
│   ├── BUG_001_test.s
│   ├── BUG_001_test_cfg.xml
│   └── ...
├── run_test.sh            # Single test runner
├── run_all_tests.sh       # Run all tests
├── generate_cfg.sh        # Generate single golden cfg
└── generate_all_cfg.sh    # Generate all golden cfgs
```

## Quick Start

### List available bugs
```bash
python bugs/inject.py --list
```

### Inject a single bug
```bash
python bugs/inject.py --bugs BUG_001
```

### Inject multiple bugs
```bash
python bugs/inject.py --bugs BUG_001 BUG_002 BUG_003
```

### Preview changes (dry run)
```bash
python bugs/inject.py --bugs BUG_001 --dry-run
```

### Restore original files
```bash
python bugs/inject.py --restore
```

## Workflow

### 1. Inject bugs before compilation
```bash
cd /path/to/rsd
python bugs/inject.py --bugs BUG_001 --rsd-root ..
cd Processor/Src
make -f Makefile.verilator.mk
```

### 2. Test your bug detection method
The RTL now contains the injected bug(s) with no hints or markers.

Run the assembly test to verify the bug is caught:
```bash
cd bugs
./run_test.sh BUG_001_test
```

Expected output:
- **Without bug**: `OK ... registers have correct values`
- **With bug injected**: `NG ... some registers have incorrect values`

For reliably testable bugs (BUG_001, 002, 004, 005), the test will fail (NG).
For demonstration-only bugs (BUG_003, 006), the test may pass even with bug injected.

### 3. Restore clean files
```bash
python bugs/inject.py --restore --rsd-root ..
```

## Bug Definition Format

Each bug is defined in a JSON file (`bugs/BUG_XXX.json`):

```json
{
  "id": "BUG_001",
  "name": "BYPASS_HAZARD",
  "category": "Bypass",
  "description": "Missing bypass check causes data hazard",
  "severity": "High",
  "file": "Processor/Src/BypassNetwork.sv",
  "patches": [
    {
      "line": 123,
      "original": "    assign dataReady = bypassValid && !stall;",
      "buggy": "    assign dataReady = 1'b1;"
    }
  ],
  "notes": "This bug causes incorrect data forwarding when pipeline stalls"
}
```

### Fields:
- **id**: Unique bug identifier (BUG_XXX)
- **name**: Short descriptive name
- **category**: Bug category (Pipeline, Memory, Control, Bypass, Scheduler, Commit)
- **description**: Brief description of the bug
- **severity**: Low, Medium, High, Critical
- **file**: Path to the file to modify (relative to RSD root)
- **patches**: Array of line-by-line changes
  - **line**: Line number to modify (1-indexed)
  - **original**: Original line content (used for verification)
  - **buggy**: Buggy line content to inject
- **notes**: Additional information about the bug

## Adding New Bugs

1. **Identify the bug location**
   ```bash
   # Find the file and line number
   grep -n "pattern" Processor/Src/*.sv
   ```

2. **Create bug definition**
   ```bash
   cp bugs/BUG_001.json bugs/BUG_XXX.json
   # Edit the new file with your bug details
   ```

3. **Test the injection**
   ```bash
   python bugs/inject.py --bugs BUG_XXX --dry-run
   ```

4. **Update the registry**
   Add an entry to `bugs/BUG_REGISTRY.md`

5. **Verify the bug**
   ```bash
   python bugs/inject.py --bugs BUG_XXX --rsd-root ..
   cd Processor/Src
   make -f Makefile.verilator.mk
   cd ../../bugs
   ./run_test.sh BUG_XXX_test
   # Verify the bug is caught (test should fail with NG)
   python bugs/inject.py --restore --rsd-root ..
   ```

## Best Practices

1. **Always restore after testing**: Don't leave bugs injected in your working directory
2. **Use dry-run first**: Preview changes before applying them
3. **One bug at a time initially**: Test each bug individually before combining
4. **Document bug behavior**: Add notes about how the bug manifests
5. **Version control**: Keep bug definitions in the bug-injection branch
6. **Test combinations carefully**: Some bugs may interact in unexpected ways

## Backup and Safety

- Original files are backed up to `.bug_backups/` before modification
- Injection state is tracked in `.bug_backups/injection_state.json`
- The `.bug_backups/` directory is git-ignored
- Always use `--restore` to ensure clean state

## Troubleshooting

### "File not found" error
- Check that the file path in the bug definition is correct
- Ensure you're running from the RSD root directory

### "Line doesn't match expected content"
- The original line may have changed since the bug was defined
- Update the bug definition with the current line content

### Bugs not manifesting
- Verify the bug was actually injected (check the file)
- Ensure you recompiled after injection
- Check simulation logs for expected behavior

## Notes for LLM Testing

When using this system to test LLM-based bug detection:

1. The injected code contains no hints (no `ifdef`, no special comments)
2. LLMs see only the buggy code, not the injection mechanism
3. Multiple bugs can be combined to test detection of interacting issues
4. The bug registry is separate from the code, preventing information leakage

## License

Same as the RSD processor (Apache License 2.0)
