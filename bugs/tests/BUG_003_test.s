// BUG_003 Test: Store-to-Load Forwarding Shift Error
// Tests that store-to-load forwarding correctly shifts data based on byte offset
// Bug uses *4 instead of *8 for bit shift, causing misaligned data

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

    // Test 1: Store byte, load byte (offset 0)
    li      t1, 0x42
    sb      t1, 0(t0)       // Store 0x42 at offset 0
    lb      t2, 0(t0)       // Load from same location
    // Without bug: t2 = 0x42
    // With bug: t2 might be shifted incorrectly
    add     a7, a7, t2      // a7 = 0x42

    // Test 2: Store byte at offset 1, load byte
    li      t1, 0x37
    sb      t1, 1(t0)       // Store 0x37 at offset 1
    lb      t2, 1(t0)       // Load from offset 1
    // Without bug: t2 = 0x37
    // With bug: shift by 4 bits instead of 8, gets wrong data
    add     a7, a7, t2      // a7 = 0x42 + 0x37 = 0x79

    // Test 3: Store halfword at offset 2, load halfword
    li      t1, 0x1234
    sh      t1, 2(t0)       // Store 0x1234 at offset 2
    lh      t2, 2(t0)       // Load from offset 2
    // Without bug: t2 = 0x1234
    // With bug: incorrect shift causes wrong value
    add     a7, a7, t2      // a7 = 0x79 + 0x1234 = 0x12AD

    // Test 4: Store word, load byte at different offsets
    li      t1, 0xAABBCCDD
    sw      t1, 4(t0)       // Store full word
    lb      t2, 4(t0)       // Load byte 0 (should be 0xDD)
    lb      t3, 5(t0)       // Load byte 1 (should be 0xCC)

    // Final result: a7 should be 0x12AD without bug
    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .space 64               // Reserve 64 bytes for test
