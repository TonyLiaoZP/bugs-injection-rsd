// BUG_005 Test: Arithmetic Shift Right Off-by-One
// Tests ASR instruction with various shift amounts
// Bug adds +1 to shift amount, causing wrong results

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    // Test 1: ASR with positive number
    li      t0, 0x00000080      // 128
    srai    a0, t0, 2           // ASR by 2 -> should be 32
                                // With bug: shifts by 3 -> 16

    // Test 2: ASR with negative number (sign extension)
    li      t1, 0xFFFFFF00      // -256
    srai    a1, t1, 4           // ASR by 4 -> should be -16 (0xFFFFFFF0)
                                // With bug: shifts by 5 -> -8 (0xFFFFFFF8)

    // Test 3: ASR by 1
    li      t2, 0x00000010      // 16
    srai    a2, t2, 1           // ASR by 1 -> should be 8
                                // With bug: shifts by 2 -> 4

    // Test 4: ASR with large negative
    li      t3, 0x80000000      // -2147483648 (most negative)
    srai    a3, t3, 8           // ASR by 8 -> should be 0xFF800000
                                // With bug: shifts by 9 -> 0xFFC00000

    li      a7, 1

end:
end_loop:
    j       end_loop
