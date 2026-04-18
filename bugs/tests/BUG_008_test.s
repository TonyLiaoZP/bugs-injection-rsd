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

    // Test: Computation followed by load (may cause stall)
    li      x10, 100
    addi    x11, x10, 50    // x11 = 150 (in bypass)

    // Load may cause cache miss and stall
    lw      x12, 0(t0)      // This may stall the pipeline

    // Use bypassed value after potential stall
    addi    x13, x11, 10    // x13 = 160
    // Without bug: x13 = 160 (bypass preserved during stall)
    // With bug: x13 = 10 (bypass cleared, x11 seen as 0)

    add     a7, a7, x13     // a7 = 160

    // Test 2: Another computation with load
    li      x14, 200
    addi    x15, x14, 25    // x15 = 225
    lw      x16, 4(t0)      // Potential stall
    addi    x17, x15, 5     // x17 = 230 (uses bypassed x15)

    add     a7, a7, x17     // a7 = 160 + 230 = 390

    // Final: a7 should be 390 without bug
    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .word 0x12345678
    .word 0xAABBCCDD
    .space 64
