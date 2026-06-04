// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
//
// Directed unit test for BUG_003 (store-to-load forwarding shift in LoadStoreUnit).

`timescale 1ns/1ps

import BasicTypes::*;
import OpFormatTypes::*;
import MemoryMapTypes::*;
import LoadStoreUnitTypes::*;
import rsd_store_forward_ref_pkg::*;

parameter STEP = 10;
parameter HOLD = 2.5;
parameter WAIT = STEP * 2 - HOLD - 0.5;

localparam PhyAddrPath TEST_BLOCK_BASE = 32'h8000_0000;

module TestBUG_003;

    logic clk, rst;
    TestBenchClockGenerator #( .STEP( STEP ) ) clkgen( .rstOut( FALSE ), .* );

    TestStoreForwardTop dut (
        .clk_p( clk ),
        .clk_n( ~clk ),
        .rst( rst )
    );

    int passCount;
    int failCount;

    task automatic drive_idle();
        int i;
        for (i = 0; i < RENAME_WIDTH; i++) begin
            dut.lsu_if.allocateStoreQueue[i] = FALSE;
            dut.lsu_if.allocateLoadQueue[i] = FALSE;
        end
        for (i = 0; i < STORE_ISSUE_WIDTH; i++) begin
            dut.lsu_if.executeStore[i] = FALSE;
            dut.lsu_if.executedStoreAddr[i] = '0;
            dut.lsu_if.executedStoreData[i] = '0;
            dut.lsu_if.executedStoreVectorData[i] = '0;
            dut.lsu_if.executedStoreCondEnabled[i] = FALSE;
            dut.lsu_if.executedStoreRegValid[i] = FALSE;
            dut.lsu_if.executedStoreMemAccessMode[i] = '0;
            dut.lsu_if.executedStoreQueuePtrByStore[i] = '0;
        end
        for (i = 0; i < LOAD_ISSUE_WIDTH; i++) begin
            dut.lsu_if.executeLoad[i] = FALSE;
            dut.lsu_if.executedLoadAddr[i] = '0;
            dut.lsu_if.executedLoadMemMapType[i] = MMT_ILLEGAL;
            dut.lsu_if.executedLoadMemAccessMode[i] = '0;
            dut.lsu_if.executedLoadRegValid[i] = FALSE;
            dut.lsu_if.executedLoadPC[i] = '0;
            dut.lsu_if.executedLoadQueuePtrByLoad[i] = '0;
            dut.lsu_if.executedStoreQueuePtrByLoad[i] = '0;
        end
    endtask

    function automatic StoreQueueIndexPath sq_tail_after_alloc(input StoreQueueIndexPath sqIdx);
        StoreQueueIndexPath t;
        t = sqIdx + 1;
        if (t >= STORE_QUEUE_ENTRY_NUM)
            t = t - STORE_QUEUE_ENTRY_NUM;
        return t;
    endfunction

    task automatic check_result(
        input string testName,
        input DataPath expectedData,
        input logic forwarded,
        input logic forwardMiss
    );
        DataPath actual;
        if (!forwarded || forwardMiss) begin
            $error("%s: forwarding did not occur (forwarded=%0d miss=%0d)",
                testName, forwarded, forwardMiss);
            failCount++;
            return;
        end
        actual = dut.lsu_if.executedLoadData[0];
        if (actual !== expectedData) begin
            $error("%s: FAIL expected=0x%08x actual=0x%08x",
                testName, expectedData, actual);
            failCount++;
        end
        else begin
            $display("%s: PASS (0x%08x)", testName, actual);
            passCount++;
        end
    endtask

`ifndef RSD_FUNCTIONAL_SIMULATION_VERILATOR
    task automatic run_forward_case(
        input string testName,
        input PhyAddrPath storeAddr,
        input PhyAddrPath loadAddr,
        input DataPath storeData,
        input MemAccessMode ldMode
    );
        StoreQueueIndexPath sqIdx;
        StoreQueueIndexPath sqTail;
        logic forwarded;
        logic forwardMiss;
        MemAccessMode stMode;
        DataPath expectedData;

        stMode = make_word_mode();
        expectedData = ref_forwarded_load_result(storeData, storeAddr, loadAddr, ldMode);

        drive_idle();
        dut.lsu_if.allocateStoreQueue[0] = TRUE;
        #HOLD;
        @(posedge clk);
        sqIdx = dut.lsu_if.allocatedStoreQueuePtr[0];
        #WAIT;
        drive_idle();
        #HOLD;
        @(posedge clk);

        dut.lsu_if.executeStore[0] = TRUE;
        dut.lsu_if.executedStoreQueuePtrByStore[0] = sqIdx;
        dut.lsu_if.executedStoreAddr[0] = storeAddr;
        dut.lsu_if.executedStoreData[0] = storeData;
        dut.lsu_if.executedStoreCondEnabled[0] = TRUE;
        dut.lsu_if.executedStoreRegValid[0] = TRUE;
        dut.lsu_if.executedStoreMemAccessMode[0] = stMode;
        #HOLD;
        @(posedge clk);
        #WAIT;
        drive_idle();
        #HOLD;
        @(posedge clk);

        sqTail = sq_tail_after_alloc(sqIdx);
        dut.lsu_if.executeLoad[0] = TRUE;
        dut.lsu_if.executedLoadAddr[0] = loadAddr;
        dut.lsu_if.executedLoadMemMapType[0] = MMT_MEMORY;
        dut.lsu_if.executedLoadMemAccessMode[0] = ldMode;
        dut.lsu_if.executedLoadRegValid[0] = TRUE;
        dut.lsu_if.executedStoreQueuePtrByLoad[0] = sqTail;
        forwarded = dut.lsu_if.storeLoadForwarded[0];
        forwardMiss = dut.lsu_if.forwardMiss[0];
        #HOLD;
        @(posedge clk);
        #WAIT;
        drive_idle();
        #HOLD;
        @(posedge clk);

        check_result(testName, expectedData, forwarded, forwardMiss);
    endtask

    initial begin
        passCount = 0;
        failCount = 0;
        drive_idle();
        while (rst) @(posedge clk);

        $display("=== BUG_003 store-forward unit test (StoreQueue + LoadStoreUnit) ===");

        run_forward_case("byte_offset_1",
            TEST_BLOCK_BASE, TEST_BLOCK_BASE + 1, 32'h1122_3344, make_byte_mode(TRUE));
        run_forward_case("byte_offset_2",
            TEST_BLOCK_BASE + 4, TEST_BLOCK_BASE + 6, 32'h5566_7788, make_byte_mode(TRUE));
        run_forward_case("byte_offset_3",
            TEST_BLOCK_BASE + 8, TEST_BLOCK_BASE + 11, 32'h99AA_BBCC, make_byte_mode(TRUE));
        run_forward_case("byte_offset_0_unsigned",
            TEST_BLOCK_BASE + 16, TEST_BLOCK_BASE + 16, 32'hAABB_CCDD, make_byte_mode(FALSE));

        $display("=== Summary: %0d passed, %0d failed ===", passCount, failCount);
        if (failCount != 0)
            $fatal(1, "BUG_003 unit test failed");
        $finish;
    end
`endif

endmodule : TestBUG_003
