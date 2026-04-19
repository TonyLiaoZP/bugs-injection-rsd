# Directed Test for BUG_003: STORE_FORWARD_SHIFT_ERROR

## Bug Description
Store-to-load forwarding uses incorrect bit shift calculation (`*4` instead of `*8`), causing wrong data alignment when loads forward from the store queue.

## Location
- File: `Processor/Src/LoadStoreUnit/LoadStoreUnit.sv`
- Function: `ShiftForwardedData` (line 29-33)
- Bug: Line 31 uses `* 4` instead of `* 8`

## Why Assembly Tests Don't Reliably Trigger This Bug

The bug only manifests when:
1. A store is in the store queue (not yet committed to cache)
2. A load executes and matches the store address
3. Store-to-load forwarding occurs (load reads from store queue)

In simple assembly tests, stores often commit to cache before loads execute, so the forwarding path is never used. The load reads from cache instead, bypassing the buggy `ShiftForwardedData` function.

## Directed Test Approach

### Test Scenario
Create a test that forces store queue pressure to keep stores in the queue longer:

```systemverilog
// Pseudo-code for directed test
initial begin
    // Fill store queue with multiple stores
    for (int i = 0; i < STORE_QUEUE_ENTRY_NUM-1; i++) begin
        issue_store(addr: base + i*4, data: test_pattern[i]);
    end
    
    // Immediately issue loads that must forward
    // (stores still in queue, not committed)
    issue_load(addr: base + 1);  // Byte offset 1
    issue_load(addr: base + 6);  // Byte offset 2
    issue_load(addr: base + 11); // Byte offset 3
    
    // Check forwarded data
    assert(load_result[0][7:0] == expected_byte_1);
    assert(load_result[1][7:0] == expected_byte_2);
    assert(load_result[2][7:0] == expected_byte_3);
end
```

### Expected Results
- **Without bug**: Correct bytes extracted based on offset
- **With bug**: Wrong bytes due to incorrect shift (offset * 4 instead of offset * 8)

### Test Data
```
Store at addr 0x1000: 0x11223344
Load from addr 0x1001 (offset 1):
  - Expected: 0x33 (byte 1)
  - With bug: 0x44 (shifted by 4 bits instead of 8)

Store at addr 0x1004: 0x55667788  
Load from addr 0x1006 (offset 2):
  - Expected: 0x77 (byte 2)
  - With bug: 0x66 (shifted by 8 bits instead of 16)
```

## Implementation Options

### Option 1: UVM Testbench
Create a UVM environment that:
- Controls store queue commit timing
- Issues back-to-back stores and loads
- Monitors forwarding path activation
- Checks forwarded data correctness

### Option 2: Constrained Random Testing
Use SystemVerilog constraints to:
- Generate store/load sequences with address overlaps
- Vary timing to hit forwarding window
- Check data consistency

### Option 3: Formal Verification
Use formal tools to prove:
```systemverilog
property store_forward_correctness;
  @(posedge clk)
  (store_in_queue && load_matches_store && forwarding_occurs)
  |->
  (forwarded_data == expected_data_at_offset);
endproperty
```

## Manual Verification Steps

1. **Inject the bug**:
   ```bash
   cd bugs
   python3 inject.py --bugs BUG_003 --rsd-root ..
   ```

2. **Add debug prints** to `LoadStoreUnit.sv`:
   ```systemverilog
   // In ShiftForwardedData function
   $display("Forward: addr=%h offset=%d shift=%d data=%h", 
            addr, addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0],
            addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * 8, data);
   ```

3. **Run assembly test** and check if forwarding occurs:
   ```bash
   ./run_test.sh BUG_003_test 2>&1 | grep "Forward:"
   ```

4. **If no forwarding**, modify test to increase store queue pressure

## Conclusion

BUG_003 is a **microarchitectural bug** that requires specific timing conditions. Assembly tests serve as smoke tests, but comprehensive verification requires:
- UVM testbench with store queue control
- Directed scenarios that guarantee forwarding
- Formal verification of forwarding correctness

The bug is real and critical (wrong data forwarded), but triggering it reliably from software is difficult.
