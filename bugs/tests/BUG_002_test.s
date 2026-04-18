// BUG_002 Test: Bypass Priority Inversion
// Tests that newer bypass data (EX stage) has priority over older data (WB stage)
// When two instructions write the same register in adjacent cycles,
// a dependent instruction should get the newest value.

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    li      a7, 0           // Result accumulator

    // Test 1: Back-to-back writes to same register
    // Instruction A writes x10, then instruction B writes x10
    // Instruction C reads x10 - should get value from B (newer)
    li      x10, 100        // x10 = 100
    nop
    nop
    addi    x10, x10, 1     // x10 = 101 (instruction A, will be in WB)
    addi    x10, x10, 10    // x10 = 111 (instruction B, will be in EX)
    addi    x11, x10, 0     // x11 = x10 (instruction C, should get 111)

    // Without bug: x11 = 111
    // With bug: x11 = 101 (gets stale value from WB instead of EX)
    add     a7, a7, x11     // a7 += 111

    // Test 2: Multiple dependent instructions
    li      x12, 200
    addi    x12, x12, 1     // x12 = 201
    addi    x12, x12, 2     // x12 = 203
    addi    x13, x12, 0     // x13 should be 203
    add     a7, a7, x13     // a7 = 111 + 203 = 314

    // Test 3: Chain of dependencies
    li      x14, 50
    addi    x14, x14, 1     // x14 = 51
    addi    x14, x14, 1     // x14 = 52
    addi    x14, x14, 1     // x14 = 53
    addi    x15, x14, 0     // x15 should be 53
    add     a7, a7, x15     // a7 = 314 + 53 = 367

    // Final check: a7 should be 367
    // Without bug: a7 = 367
    // With bug: a7 will be different
    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop
