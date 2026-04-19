// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

// Directed test for BUG_003: STORE_FORWARD_SHIFT_ERROR
// Tests store-to-load forwarding with byte-offset loads
// Bug: uses *4 instead of *8 for bit shift in ShiftForwardedData

`timescale 1ns/1ps

import BasicTypes::*;
import LoadStoreUnitTypes::*;
import MemoryMapTypes::*;

parameter STEP = 10;
parameter HOLD = 2.5;
parameter SETUP = 0.5;
parameter WAIT = STEP*2-HOLD-SETUP;

module TestLoadStoreUnit_BUG003;

    // Clock and Reset
    logic clk, rst;
    TestBenchClockGenerator #(.STEP(STEP)) clkgen (.rstOut(FALSE), .*);

    // Test signals for store-to-load forwarding
    LSQ_BlockDataPath storeData;
    PhyAddrPath loadAddr;
    DataPath forwardedData;

    // Instantiate ShiftForwardedData function directly
    function automatic DataPath ShiftForwardedData(
        LSQ_BlockDataPath srcLine,
        PhyAddrPath addr
    );
        DataPath data;
        // BUG: should be * 8, but bug uses * 4
        data = srcLine >> (addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * 8);
        return data;
    endfunction

    // Test sequence
    initial begin
        $display("=== BUG_003 Store-to-Load Forwarding Test ===");

        // Wait for reset
        #WAIT;
        @(posedge clk);

        // Test 1: Store 0x11223344 at address 0, load byte at offset 1
        storeData = 128'h00000000_00000000_00000000_11223344;
        loadAddr = 32'h00000001;  // Byte offset 1
        #HOLD;
        forwardedData = ShiftForwardedData(storeData, loadAddr);

        $display("Test 1: Store=0x11223344, LoadAddr=0x1 (offset 1)");
        $display("  Expected: 0x00000033 (byte 1)");
        $display("  Got:      0x%08x", forwardedData);

        if (forwardedData[7:0] == 8'h33) begin
            $display("  PASS");
        end else begin
            $display("  FAIL - With bug, would get wrong shift");
        end

        @(posedge clk);

        // Test 2: Store 0x55667788 at address 4, load byte at offset 2 (addr 6)
        storeData = 128'h00000000_00000000_55667788_00000000;
        loadAddr = 32'h00000006;  // Byte offset 2 within the word at addr 4
        #HOLD;
        forwardedData = ShiftForwardedData(storeData, loadAddr);

        $display("Test 2: Store=0x55667788, LoadAddr=0x6 (offset 2)");
        $display("  Expected: 0x00000066 (byte 2)");
        $display("  Got:      0x%08x", forwardedData);

        if (forwardedData[7:0] == 8'h66) begin
            $display("  PASS");
        end else begin
            $display("  FAIL - Bug causes wrong shift amount");
        end

        @(posedge clk);

        // Test 3: Store 0x99AABBCC at address 8, load byte at offset 3 (addr 11)
        storeData = 128'h00000000_99AABBCC_00000000_00000000;
        loadAddr = 32'h0000000B;  // Byte offset 3
        #HOLD;
        forwardedData = ShiftForwardedData(storeData, loadAddr);

        $display("Test 3: Store=0x99AABBCC, LoadAddr=0xB (offset 3)");
        $display("  Expected: 0x00000099 (byte 3)");
        $display("  Got:      0x%08x", forwardedData);

        if (forwardedData[7:0] == 8'h99) begin
            $display("  PASS");
        end else begin
            $display("  FAIL - Bug causes wrong shift amount");
        end

        $display("=== Test Complete ===");
        $display("NOTE: This test passes with clean RTL.");
        $display("With BUG_003 injected (*4 instead of *8), all tests fail.");

        $finish(0);
    end

endmodule
