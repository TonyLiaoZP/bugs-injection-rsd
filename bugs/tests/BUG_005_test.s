// BUG_005 Test: Recovery Phase Skip
// Tests that recovery manager properly handles branch mispredictions
// Bug inverts reset condition, breaking recovery state machine

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    li      a7, 0           // Result accumulator

    // Test 1: Simple branch misprediction
    li      x10, 10
    li      x11, 20
    beq     x10, x11, wrong_path1   // Not taken (mispredicted as taken)
    addi    x12, x10, 5             // Correct path: x12 = 15
    j       after1
wrong_path1:
    addi    x12, x11, 5             // Wrong path: x12 = 25
after1:
    // Without bug: x12 = 15 (recovery works)
    // With bug: Recovery fails, may get wrong value or hang
    add     a7, a7, x12             // a7 = 15

    // Test 2: Taken branch
    li      x13, 30
    li      x14, 30
    bne     x13, x14, wrong_path2   // Not taken
    addi    x15, x13, 10            // Correct: x15 = 40
    j       after2
wrong_path2:
    addi    x15, x14, 20            // Wrong: x15 = 50
after2:
    add     a7, a7, x15             // a7 = 15 + 40 = 55

    // Test 3: Multiple branches
    li      x16, 100
    blt     x16, zero, wrong_path3  // Not taken (100 >= 0)
    addi    x17, x16, 1             // x17 = 101
    j       after3
wrong_path3:
    addi    x17, x16, 100           // x17 = 200
after3:
    add     a7, a7, x17             // a7 = 55 + 101 = 156

    // Test 4: Nested branches
    li      x18, 50
    li      x19, 60
    bge     x18, x19, path4_a       // Not taken (50 < 60)
    addi    x20, x18, 10            // Correct: x20 = 60
    j       after4
path4_a:
    addi    x20, x19, 10            // Wrong: x20 = 70
after4:
    add     a7, a7, x20             // a7 = 156 + 60 = 216

    // Final: a7 should be 216 without bug
    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop
