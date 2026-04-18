// BUG_004 Test: Ready Bit Bypass Race
// Tests that all wakeup ports are checked for bypass
// Bug reduces loop from WAKEUP_WIDTH to WAKEUP_WIDTH-1, missing last port

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    li      a7, 0           // Result accumulator

    // Generate many parallel operations to stress wakeup ports
    // The goal is to have the last wakeup port active when a dependent
    // instruction is dispatched

    // Test 1: Create many independent operations
    li      x10, 10
    li      x11, 20
    li      x12, 30
    li      x13, 40
    li      x14, 50
    li      x15, 60

    // Parallel adds (may use multiple issue lanes)
    addi    x10, x10, 1     // x10 = 11
    addi    x11, x11, 1     // x11 = 21
    addi    x12, x12, 1     // x12 = 31
    addi    x13, x13, 1     // x13 = 41
    addi    x14, x14, 1     // x14 = 51
    addi    x15, x15, 1     // x15 = 61

    // Immediately use results (tests wakeup bypass)
    add     x16, x10, x11   // x16 = 11 + 21 = 32
    add     x17, x12, x13   // x17 = 31 + 41 = 72
    add     x18, x14, x15   // x18 = 51 + 61 = 112

    // Without bug: All values correct
    // With bug: If last wakeup port is missed, dependent instruction stalls unnecessarily
    RSD_ASSERT_GPR_EQ(x16, 32)
    RSD_ASSERT_GPR_EQ(x17, 72)
    RSD_ASSERT_GPR_EQ(x18, 112)

    add     a7, x16, x17    // a7 = 32 + 72 = 104
    add     a7, a7, x18     // a7 = 104 + 112 = 216

    // Test 2: More complex dependency chain
    li      x20, 100
    li      x21, 200
    li      x22, 300
    li      x23, 400

    addi    x20, x20, 5     // x20 = 105
    addi    x21, x21, 5     // x21 = 205
    addi    x22, x22, 5     // x22 = 305
    addi    x23, x23, 5     // x23 = 405

    add     x24, x20, x21   // x24 = 310
    add     x25, x22, x23   // x25 = 710
    add     x26, x24, x25   // x26 = 1020

    RSD_ASSERT_GPR_EQ(x26, 1020)
    add     a7, a7, x26     // a7 = 216 + 1020 = 1236

    // Final check
    RSD_ASSERT_GPR_EQ(a7, 1236)

end:
    li      a7, 1           // Success marker
end_loop:
    j       end_loop
