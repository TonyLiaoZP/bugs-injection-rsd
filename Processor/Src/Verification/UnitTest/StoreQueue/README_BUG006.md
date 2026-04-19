# Directed Test for BUG_006: STORE_QUEUE_WRAP_AROUND

## Bug Description
Store queue pointer wrap-around calculation has an off-by-one error (`+1` added incorrectly), causing the pointer to skip an entry when wrapping around. This leads to store queue entry leaks and potential memory ordering violations.

## Location
- File: `Processor/Src/LoadStoreUnit/StoreQueue.sv`
- Lines: 82-83
- Bug: Adds `+1` to wrap-around calculation

```systemverilog
// Buggy code:
port.allocatedStoreQueuePtr[i] = 
    tailPtr + pushCount - STORE_QUEUE_ENTRY_NUM + 1;  // +1 is wrong

// Correct code:
port.allocatedStoreQueuePtr[i] = 
    tailPtr + pushCount - STORE_QUEUE_ENTRY_NUM;
```

## Why Assembly Tests Don't Reliably Trigger This Bug

The bug only manifests when:
1. Store queue fills up and wraps around (tailPtr + pushCount >= STORE_QUEUE_ENTRY_NUM)
2. Multiple stores are allocated in the same cycle
3. The wrap-around calculation is used

In typical assembly tests:
- Store queue rarely fills completely
- Stores commit before queue wraps
- Simple programs don't generate enough store pressure

## Directed Test Approach

### Test Scenario
Create a test that fills the store queue to force wrap-around:

```systemverilog
// Pseudo-code for directed test
initial begin
    // Fill store queue to near capacity
    for (int i = 0; i < STORE_QUEUE_ENTRY_NUM - 2; i++) begin
        allocate_store(addr: base + i*4, data: pattern[i]);
    end
    
    // Allocate multiple stores in one cycle to trigger wrap-around
    // tailPtr is near STORE_QUEUE_ENTRY_NUM
    allocate_stores_parallel(count: 3);
    
    // Check allocated pointers
    // Without bug: pointers wrap correctly (0, 1, 2)
    // With bug: pointers skip entry (1, 2, 3) - entry 0 leaked
    
    assert(allocatedPtr[0] == 0);  // Should wrap to 0
    assert(allocatedPtr[1] == 1);
    assert(allocatedPtr[2] == 2);
    
    // Verify no entry leak
    assert(all_entries_accounted_for());
end
```

### Expected Results

**Scenario**: Store queue has 16 entries, tailPtr = 15, allocate 2 stores

| Calculation | Without Bug | With Bug |
|-------------|-------------|----------|
| Store 0 ptr | 15 + 0 - 16 = -1 → 15 | 15 + 0 - 16 + 1 = 0 |
| Store 1 ptr | 15 + 1 - 16 = 0 | 15 + 1 - 16 + 1 = 1 |

**Problem**: With bug, entry 15 is skipped, causing:
- Entry leak (entry 15 never used)
- Potential memory ordering violation
- Store queue capacity reduced by 1 each wrap

### Test Data

```
Initial state:
  tailPtr = 14
  headPtr = 0
  Queue entries: [0..13] occupied, [14..15] free

Allocate 3 stores:
  pushCount = 0: ptr = 14 (no wrap)
  pushCount = 1: ptr = 15 (no wrap)
  pushCount = 2: ptr = 16 - 16 = 0 (wrap, should be 0)
                      With bug: 16 - 16 + 1 = 1 (WRONG, skips entry 0)

Result with bug:
  - Entry 0 is leaked (never allocated)
  - Next allocation starts at entry 1
  - Store queue effectively loses one entry
```

## Implementation Options

### Option 1: SystemVerilog Testbench

```systemverilog
module TestStoreQueue_BUG006;
    // Instantiate StoreQueue
    StoreQueue sq(...);
    
    initial begin
        // Fill queue to capacity - 2
        for (int i = 0; i < STORE_QUEUE_ENTRY_NUM - 2; i++) begin
            @(posedge clk);
            allocateStore[0] = 1;
            // Wait for allocation
        end
        
        // Trigger wrap-around with multiple allocations
        @(posedge clk);
        allocateStore[0] = 1;
        allocateStore[1] = 1;
        
        // Check allocated pointers
        @(posedge clk);
        if (allocatedStoreQueuePtr[1] != 0) begin
            $display("FAIL: Entry skipped due to +1 bug");
            $display("Expected ptr[1] = 0, got %d", allocatedStoreQueuePtr[1]);
        end else begin
            $display("PASS: Wrap-around correct");
        end
        
        $finish;
    end
endmodule
```

### Option 2: Constrained Random Testing

Use SystemVerilog constraints to:
- Generate store allocation patterns
- Force queue fill and wrap scenarios
- Monitor pointer allocation
- Detect entry leaks

### Option 3: Formal Verification

Prove wrap-around correctness:

```systemverilog
property wrap_around_correctness;
  @(posedge clk)
  (tailPtr + pushCount >= STORE_QUEUE_ENTRY_NUM)
  |->
  (allocatedPtr == (tailPtr + pushCount - STORE_QUEUE_ENTRY_NUM));
endproperty

assert property (wrap_around_correctness);
```

## Manual Verification Steps

1. **Inject the bug**:
   ```bash
   cd bugs
   python3 inject.py --bugs BUG_006 --rsd-root ..
   ```

2. **Add debug prints** to `StoreQueue.sv`:
   ```systemverilog
   // Around line 82-83
   if (tailPtr + pushCount >= STORE_QUEUE_ENTRY_NUM) begin
       $display("WRAP: tailPtr=%d pushCount=%d allocated=%d", 
                tailPtr, pushCount, 
                tailPtr + pushCount - STORE_QUEUE_ENTRY_NUM);
   end
   ```

3. **Create assembly test with many stores**:
   ```assembly
   // Generate 20+ stores to fill queue
   li t0, 0x80000000
   sw x1, 0(t0)
   sw x2, 4(t0)
   sw x3, 8(t0)
   // ... repeat 20+ times
   ```

4. **Check for wrap-around** in simulation log:
   ```bash
   ./run_test.sh BUG_006_test 2>&1 | grep "WRAP:"
   ```

## Detection Strategy

### Symptom 1: Entry Leak
- Store queue appears full but has unused entries
- Capacity reduced after each wrap-around
- Eventually causes false "queue full" stalls

### Symptom 2: Memory Ordering Violation
- Stores execute out of order
- Load reads stale data
- Memory consistency errors

### Symptom 3: Pointer Collision
- Multiple stores allocated to same entry
- Data corruption in store queue
- Assertion failures in RTL

## Verification Checklist

- [ ] Test with queue size = 8, 16, 32
- [ ] Test single and multiple allocations per cycle
- [ ] Test wrap-around at different tailPtr values
- [ ] Verify all entries are used (no leaks)
- [ ] Check pointer monotonicity (no skips)
- [ ] Stress test with continuous store stream

## Conclusion

BUG_006 is a **microarchitectural bug** that requires:
- Store queue to fill and wrap around
- Multiple stores allocated in same cycle
- Careful pointer tracking to detect leaks

Assembly tests can trigger it with store-heavy code, but comprehensive verification requires:
- Directed testbench with queue fill control
- Pointer allocation monitoring
- Entry leak detection
- Formal verification of wrap-around logic

The bug is subtle but serious - it causes resource leaks and potential memory ordering violations.
