#!/usr/bin/env python3
"""
Directed test for BUG_003: STORE_FORWARD_SHIFT_ERROR
Tests the ShiftForwardedData function logic in Python
"""

def shift_forwarded_data_correct(src_line, addr):
    """Correct implementation: shift by offset * 8"""
    offset = addr & 0xF  # LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE = 4
    shift_amount = offset * 8
    result = (src_line >> shift_amount) & 0xFFFFFFFF
    return result

def shift_forwarded_data_buggy(src_line, addr):
    """Buggy implementation: shift by offset * 4 (BUG!)"""
    offset = addr & 0xF
    shift_amount = offset * 4  # BUG: should be * 8
    result = (src_line >> shift_amount) & 0xFFFFFFFF
    return result

def test_bug003():
    print("=" * 60)
    print("BUG_003: Store-to-Load Forwarding Shift Error Test")
    print("=" * 60)
    print()

    pass_count = 0
    fail_count = 0

    # Test 1: Load byte at offset 1 from 0x11223344
    print("Test 1: Store 0x11223344, load byte at offset 1")
    store_data = 0x11223344
    load_addr = 0x00000001

    result_correct = shift_forwarded_data_correct(store_data, load_addr)
    result_buggy = shift_forwarded_data_buggy(store_data, load_addr)

    # After shifting right by 8 bits (1 byte), we get 0x00112233
    # The lowest byte is 0x33
    expected_byte = 0x33
    actual_byte = result_correct & 0xFF
    buggy_byte = result_buggy & 0xFF

    print(f"  Correct result: 0x{result_correct:08x} (byte = 0x{actual_byte:02x})")
    print(f"  Buggy result:   0x{result_buggy:08x} (byte = 0x{buggy_byte:02x})")
    print(f"  Expected: 0x{expected_byte:02x}")

    if actual_byte == expected_byte:
        print("  ✓ PASS: Correct implementation")
        pass_count += 1
    else:
        print("  ✗ FAIL: Correct implementation wrong")
        fail_count += 1

    if buggy_byte != expected_byte:
        print(f"  ✓ Bug detected: extracts 0x{buggy_byte:02x} instead of 0x{expected_byte:02x}")
    print()

    # Test 2: Load byte at offset 2 from 0x55667788
    print("Test 2: Store 0x55667788, load byte at offset 2")
    store_data = 0x55667788
    load_addr = 0x00000002

    result_correct = shift_forwarded_data_correct(store_data, load_addr)
    result_buggy = shift_forwarded_data_buggy(store_data, load_addr)

    # After shifting right by 16 bits (2 bytes), we get 0x00005566
    # The lowest byte is 0x66
    expected_byte = 0x66
    actual_byte = result_correct & 0xFF
    buggy_byte = result_buggy & 0xFF

    print(f"  Correct result: 0x{result_correct:08x} (byte = 0x{actual_byte:02x})")
    print(f"  Buggy result:   0x{result_buggy:08x} (byte = 0x{buggy_byte:02x})")
    print(f"  Expected: 0x{expected_byte:02x}")

    if actual_byte == expected_byte:
        print("  ✓ PASS: Correct implementation")
        pass_count += 1
    else:
        print("  ✗ FAIL: Correct implementation wrong")
        fail_count += 1

    if buggy_byte != expected_byte:
        print(f"  ✓ Bug detected: extracts 0x{buggy_byte:02x} instead of 0x{expected_byte:02x}")
    print()

    # Test 3: Load byte at offset 3 from 0x99AABBCC
    print("Test 3: Store 0x99AABBCC, load byte at offset 3")
    store_data = 0x99AABBCC
    load_addr = 0x00000003

    result_correct = shift_forwarded_data_correct(store_data, load_addr)
    result_buggy = shift_forwarded_data_buggy(store_data, load_addr)

    # After shifting right by 24 bits (3 bytes), we get 0x00000099
    # The lowest byte is 0x99
    expected_byte = 0x99
    actual_byte = result_correct & 0xFF
    buggy_byte = result_buggy & 0xFF

    print(f"  Correct result: 0x{result_correct:08x} (byte = 0x{actual_byte:02x})")
    print(f"  Buggy result:   0x{result_buggy:08x} (byte = 0x{buggy_byte:02x})")
    print(f"  Expected: 0x{expected_byte:02x}")

    if actual_byte == expected_byte:
        print("  ✓ PASS: Correct implementation")
        pass_count += 1
    else:
        print("  ✗ FAIL: Correct implementation wrong")
        fail_count += 1

    if buggy_byte != expected_byte:
        print(f"  ✓ Bug detected: extracts 0x{buggy_byte:02x} instead of 0x{expected_byte:02x}")
    print()

    # Summary
    print("=" * 60)
    print("Test Summary:")
    print(f"  Passed: {pass_count}")
    print(f"  Failed: {fail_count}")
    print()

    if fail_count == 0:
        print("  Result: ALL TESTS PASSED ✓")
        print()
        print("This test demonstrates the BUG_003 shift error.")
        print("The buggy version uses *4 instead of *8 for bit shift,")
        print("causing wrong bytes to be extracted during store-to-load")
        print("forwarding.")
    else:
        print("  Result: SOME TESTS FAILED ✗")

    print("=" * 60)

    return fail_count == 0

if __name__ == "__main__":
    success = test_bug003()
    exit(0 if success else 1)
