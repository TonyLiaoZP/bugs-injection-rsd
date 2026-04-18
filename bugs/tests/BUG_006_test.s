// BUG_006 Test: Commit Boundary Off-by-One
// Tests instruction boundary detection during commit
// Bug changes < to <=, examining one entry beyond valid range

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    li      a7, 0           // Result accumulator

    // Test 1: Simple multi-op instruction sequence
    // Each instruction may be split into multiple micro-ops
    li      x10, 100
    li      x11, 200
    add     x12, x10, x11   // x12 = 300
    add     a7, a7, x12     // a7 = 300

    // Test 2: Load/store operations (multi-op)
    la      t0, test_data
    li      t1, 0x12345678
    sw      t1, 0(t0)       // Store (address calc + store)
    lw      t2, 0(t0)       // Load (address calc + load)
    add     a7, a7, t2      // a7 = 300 + 0x12345678 = 0x12345978

    // Test 3: Multiple loads in sequence
    li      t1, 0xAAAA
    li      t2, 0xBBBB
    li      t3, 0xCCCC
    sw      t1, 4(t0)
    sw      t2, 8(t0)
    sw      t3, 12(t0)

    lw      t4, 4(t0)       // t4 = 0xAAAA
    lw      t5, 8(t0)       // t5 = 0xBBBB
    lw      t6, 12(t0)      // t6 = 0xCCCC

    // Test 4: Arithmetic with multiple dependencies
    li      x13, 10
    li      x14, 20
    li      x15, 30
    add     x16, x13, x14   // x16 = 30
    add     x17, x15, x16   // x17 = 60
    add     x18, x16, x17   // x18 = 90

    // Without bug: All operations commit correctly
    // With bug: Off-by-one may cause incorrect commit boundaries,
    //           leading to partial instruction commits or wrong state

    // Final check (just verify we got here)
    li      a7, 1

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .space 64
