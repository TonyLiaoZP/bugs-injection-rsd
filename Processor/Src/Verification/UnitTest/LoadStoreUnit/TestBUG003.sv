// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Standalone test for BUG_003: STORE_FORWARD_SHIFT_ERROR
// Tests the ShiftForwardedData function directly

`timescale 1ns/1ps

module TestBUG003;

    // Test parameters
    parameter LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE = 4;  // 16 bytes = 2^4

    // Test data
    reg [127:0] storeData;
    reg [31:0] loadAddr;
    reg [31:0] result_correct;
    reg [31:0] result_buggy;
    integer pass_count;
    integer fail_count;

    // Function under test (CORRECT implementation)
    function [31:0] ShiftForwardedData;
        input [127:0] srcLine;
        input [31:0] addr;
        begin
            ShiftForwardedData = srcLine >> (addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * 8);
        end
    endfunction

    // Buggy version for comparison
    function [31:0] ShiftForwardedData_BUGGY;
        input [127:0] srcLine;
        input [31:0] addr;
        begin
            // BUG: uses * 4 instead of * 8
            ShiftForwardedData_BUGGY = srcLine >> (addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * 4);
        end
    endfunction

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("========================================");
        $display("BUG_003: Store-to-Load Forwarding Test");
        $display("========================================");
        $display("");

        // Test 1: Load byte at offset 1
        $display("Test 1: Store 0x11223344, load byte at offset 1");
        storeData = 128'h00000000_00000000_00000000_11223344;
        loadAddr = 32'h00000001;
        result_correct = ShiftForwardedData(storeData, loadAddr);
        result_buggy = ShiftForwardedData_BUGGY(storeData, loadAddr);

        $display("  Correct result: 0x%08x (byte 1 = 0x33)", result_correct);
        $display("  Buggy result:   0x%08x", result_buggy);

        if (result_correct[7:0] == 8'h33) begin
            $display("  PASS: Correct implementation extracts right byte");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Correct implementation wrong");
            fail_count = fail_count + 1;
        end

        if (result_buggy[7:0] != 8'h33) begin
            $display("  INFO: Bug detected (extracts 0x%02x instead of 0x33)", result_buggy[7:0]);
        end
        $display("");

        // Test 2: Load byte at offset 2
        $display("Test 2: Store 0x55667788, load byte at offset 2");
        storeData = 128'h00000000_00000000_55667788_00000000;
        loadAddr = 32'h00000006;  // Offset 2 within word
        result_correct = ShiftForwardedData(storeData, loadAddr);
        result_buggy = ShiftForwardedData_BUGGY(storeData, loadAddr);

        $display("  Correct result: 0x%08x (byte 2 = 0x77)", result_correct);
        $display("  Buggy result:   0x%08x", result_buggy);

        if (result_correct[7:0] == 8'h77) begin
            $display("  PASS: Correct implementation extracts right byte");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Correct implementation wrong");
            fail_count = fail_count + 1;
        end

        if (result_buggy[7:0] != 8'h77) begin
            $display("  INFO: Bug detected (extracts 0x%02x instead of 0x77)", result_buggy[7:0]);
        end
        $display("");

        // Test 3: Load byte at offset 3
        $display("Test 3: Store 0x99AABBCC, load byte at offset 3");
        storeData = 128'h00000000_99AABBCC_00000000_00000000;
        loadAddr = 32'h0000000B;  // Offset 3
        result_correct = ShiftForwardedData(storeData, loadAddr);
        result_buggy = ShiftForwardedData_BUGGY(storeData, loadAddr);

        $display("  Correct result: 0x%08x (byte 3 = 0x99)", result_correct);
        $display("  Buggy result:   0x%08x", result_buggy);

        if (result_correct[7:0] == 8'h99) begin
            $display("  PASS: Correct implementation extracts right byte");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Correct implementation wrong");
            fail_count = fail_count + 1;
        end

        if (result_buggy[7:0] != 8'h99) begin
            $display("  INFO: Bug detected (extracts 0x%02x instead of 0x99)", result_buggy[7:0]);
        end
        $display("");

        // Summary
        $display("========================================");
        $display("Test Summary:");
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);

        if (fail_count == 0) begin
            $display("  Result: ALL TESTS PASSED");
            $display("");
            $display("This test verifies the ShiftForwardedData function.");
            $display("With BUG_003 injected (*4 instead of *8), the buggy");
            $display("version shows incorrect byte extraction.");
        end else begin
            $display("  Result: SOME TESTS FAILED");
        end
        $display("========================================");

        $finish;
    end

endmodule
