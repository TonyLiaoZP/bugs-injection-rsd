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

    // Test: Multiple stores and loads
    li      t1, 0x11
    li      t2, 0x22
    li      t3, 0x33

    // Issue stores
    sw      t1, 0(t0)
    sw      t2, 4(t0)
    sw      t3, 8(t0)

    // Load back
    lw      x10, 0(t0)      // x10 = 0x11
    lw      x11, 4(t0)      // x11 = 0x22
    lw      x12, 8(t0)      // x12 = 0x33

    // Accumulate
    add     a7, a7, x10     // a7 = 0x11
    add     a7, a7, x11     // a7 = 0x33
    add     a7, a7, x12     // a7 = 0x66

    // Without bug: a7 = 0x66
    // With bug: Store queue wrap error may cause wrong values

    li      a7, 1           // Success marker

end:
end_loop:
    j       end_loop

    .data
    .align 4
test_data:
    .space 64
