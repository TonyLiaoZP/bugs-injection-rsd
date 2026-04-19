// BUG_005 Test: SLT Sign-Conditional Swap Bug
// Tests SLT instruction with various operand combinations
// Bug: swaps operands when both have same sign bit

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    // Test 1: Both positive (same sign) - BUG TRIGGERS
    li      t0, 10
    li      t1, 20
    slt     a0, t0, t1          // 10 < 20 -> should be 1
                                // With bug: 20 < 10 -> 0 (WRONG)

    // Test 2: Both negative (same sign) - BUG TRIGGERS
    li      t2, -20
    li      t3, -10
    slt     a1, t2, t3          // -20 < -10 -> should be 1
                                // With bug: -10 < -20 -> 0 (WRONG)

    // Test 3: Positive < Negative (different signs) - works correctly
    li      t4, 5
    li      t5, -5
    slt     a2, t4, t5          // 5 < -5 -> should be 0
                                // With bug: still 0 (correct)

    // Test 4: Negative < Positive (different signs) - works correctly
    li      t6, -15
    li      s0, 15
    slt     a3, t6, s0          // -15 < 15 -> should be 1
                                // With bug: still 1 (correct)

    // Test 5: Both positive, reversed (same sign) - BUG TRIGGERS
    li      s1, 100
    li      s2, 50
    slt     a4, s1, s2          // 100 < 50 -> should be 0
                                // With bug: 50 < 100 -> 1 (WRONG)

    li      a7, 1

end:
end_loop:
    j       end_loop
