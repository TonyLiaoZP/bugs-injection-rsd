// BUG_003 Test: Store-to-Load Forwarding Shift Error
// Simple test with back-to-back store/load at byte offsets
// Bug uses *4 instead of *8 for bit shift

#include "../rsd-asm-macros.h"

    .file    "code.s"
    .option nopic
    .text
    .align    2
    .globl    main
    .type     main, @function

main:
    la      t0, test_data

    // Test 1: Store word, immediate load byte at offset 1
    li      t1, 0x11223344
    sw      t1, 0(t0)
    lb      a1, 1(t0)       // Should get 0x33 (byte 1)
                            // With bug: shift by 1*4=4 instead of 1*8=8

    // Test 2: Store word, immediate load byte at offset 2
    li      t1, 0x55667788
    sw      t1, 4(t0)
    lb      a2, 6(t0)       // Should get 0x77 (byte 2)
                            // With bug: shift by 2*4=8 instead of 2*8=16

    // Test 3: Store word, immediate load byte at offset 3
    li      t1, 0x99AABBCC
    sw      t1, 8(t0)
    lb      a3, 11(t0)      // Should get 0x99 (byte 3)
                            // With bug: shift by 3*4=12 instead of 3*8=24

    li      a7, 1

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .space 64
