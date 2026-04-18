// BUG_007 Test: Store Queue Wrap-Around
// Tests store queue pointer wrap-around when queue is nearly full
// Bug adds +1 to wrap calculation, causing pointer to skip an entry

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

    // Test 1: Fill store queue with many stores
    // This tests wrap-around behavior when queue fills up
    li      t1, 0x11
    li      t2, 0x22
    li      t3, 0x33
    li      t4, 0x44
    li      t5, 0x55
    li      t6, 0x66

    // Issue many stores to fill the store queue
    sw      t1, 0(t0)
    sw      t2, 4(t0)
    sw      t3, 8(t0)
    sw      t4, 12(t0)
    sw      t5, 16(t0)
    sw      t6, 20(t0)
    sw      t1, 24(t0)
    sw      t2, 28(t0)
    sw      t3, 32(t0)
    sw      t4, 36(t0)
    sw      t5, 40(t0)
    sw      t6, 44(t0)

    // Now load back and verify
    lw      x10, 0(t0)
    lw      x11, 4(t0)
    lw      x12, 8(t0)
    lw      x13, 12(t0)
    lw      x14, 16(t0)
    lw      x15, 20(t0)

    // Without bug: All values correct
    // With bug: Wrap-around error may cause stores to wrong addresses
    //           or store queue entry leaks
    RSD_ASSERT_GPR_EQ(x10, 0x11)
    RSD_ASSERT_GPR_EQ(x11, 0x22)
    RSD_ASSERT_GPR_EQ(x12, 0x33)
    RSD_ASSERT_GPR_EQ(x13, 0x44)
    RSD_ASSERT_GPR_EQ(x14, 0x55)
    RSD_ASSERT_GPR_EQ(x15, 0x66)

    // Test 2: More stores to force wrap-around
    li      t1, 0xAA
    li      t2, 0xBB
    li      t3, 0xCC

    sw      t1, 48(t0)
    sw      t2, 52(t0)
    sw      t3, 56(t0)
    sw      t1, 60(t0)

    lw      x16, 48(t0)
    lw      x17, 52(t0)
    lw      x18, 56(t0)
    lw      x19, 60(t0)

    RSD_ASSERT_GPR_EQ(x16, 0xAA)
    RSD_ASSERT_GPR_EQ(x17, 0xBB)
    RSD_ASSERT_GPR_EQ(x18, 0xCC)
    RSD_ASSERT_GPR_EQ(x19, 0xAA)

    // Accumulate results
    add     a7, x10, x11    // 0x11 + 0x22 = 0x33
    add     a7, a7, x12     // 0x33 + 0x33 = 0x66

    RSD_ASSERT_GPR_EQ(a7, 0x66)

end:
    li      a7, 1           // Success marker
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .space 128              // Reserve 128 bytes
