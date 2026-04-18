// BUG_008 Test: Bypass Clear on Stall
// Tests that bypass data is preserved during pipeline stalls
// Bug clears bypass registers when pipeline stalls (e.g., cache miss)

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    li      a7, 0           // Result accumulator
    la      t0, test_data   // Base address

    // Test 1: Computation followed by load (may cause stall)
    li      x10, 100
    addi    x11, x10, 50    // x11 = 150 (in bypass)

    // Load may cause cache miss and stall
    lw      x12, 0(t0)      // This may stall the pipeline

    // Use bypassed value after potential stall
    addi    x13, x11, 10    // x13 = 160
    // Without bug: x13 = 160 (bypass preserved during stall)
    // With bug: x13 = 10 (bypass cleared, x11 seen as 0)

    add     a7, a7, x13     // a7 = 160

    // Test 2: Multiple computations with load in between
    li      x14, 200
    addi    x15, x14, 25    // x15 = 225
    lw      x16, 4(t0)      // Potential stall
    addi    x17, x15, 5     // x17 = 230 (uses bypassed x15)

    add     a7, a7, x17     // a7 = 160 + 230 = 390

    // Test 3: Chain of dependencies with loads
    li      x18, 50
    addi    x19, x18, 10    // x19 = 60
    lw      x20, 8(t0)      // Stall
    addi    x21, x19, 5     // x21 = 65 (depends on bypassed x19)
    lw      x22, 12(t0)     // Another stall
    addi    x23, x21, 3     // x23 = 68 (depends on bypassed x21)

    add     a7, a7, x23     // a7 = 390 + 68 = 458

    // Test 4: Store followed by dependent computation
    li      x24, 300
    sw      x24, 16(t0)     // Store may cause stall
    addi    x25, x24, 7     // x25 = 307 (uses bypassed x24)

    add     a7, a7, x25     // a7 = 458 + 307 = 765

    // Final: a7 should be 765 without bug
    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .word 0x12345678
    .word 0xAABBCCDD
    .word 0x11223344
    .word 0x55667788
    .space 64
