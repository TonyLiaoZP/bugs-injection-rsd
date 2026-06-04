// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
//
// Minimal DUT for BUG_006: StoreQueue allocation / wrap-around pointers only.

`timescale 1ns/1ps

import BasicTypes::*;
import MemoryMapTypes::*;
import LoadStoreUnitTypes::*;

`ifdef RSD_FUNCTIONAL_SIMULATION_VERILATOR
module TestStoreQueueWrapTop (
    input  logic clk,
    input  logic rst,
    input  logic [RENAME_WIDTH-1:0] vl_allocateStoreQueue,
    input  logic vl_releaseStoreQueueHead,
    input  CommitLaneCountPath vl_releaseStoreQueueHeadEntryNum,
    output logic vl_storeQueueAllocatable,
    output StoreQueueCountPath vl_storeQueueCount,
    output StoreQueueIndexPath vl_storeQueueHeadPtr,
    output StoreQueueIndexPath vl_cap_allocPtr0,
    output StoreQueueIndexPath vl_cap_allocPtr1
);
    logic clk_p, clk_n;
    assign clk_p = clk;
    assign clk_n = ~clk;
`else
module TestStoreQueueWrapTop (
    input  logic clk_p,
    input  logic clk_n,
    input  logic rst
);
    logic clk;
    assign clk = clk_p;
`endif
    logic rstStart;
    assign rstStart = rst;

    LoadStoreUnitIF     lsu_if( clk, rst, rstStart );
    RecoveryManagerIF   rec_if( clk, rst );

    TbRecoveryStub      rec_stub( rec_if );
    StoreQueue          sq( lsu_if, rec_if );

    assign lsu_if.loadQueueAllocatable = TRUE;

    always_comb begin
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            lsu_if.allocateStoreQueue[i] = vl_allocateStoreQueue[i];
        end
        for (int i = 0; i < LOAD_ISSUE_WIDTH; i++) begin
            lsu_if.executeLoad[i] = FALSE;
            lsu_if.executedLoadAddr[i] = '0;
            lsu_if.executedLoadMemMapType[i] = MMT_MEMORY;
            lsu_if.executedLoadMemAccessMode[i] = '0;
            lsu_if.executedLoadRegValid[i] = FALSE;
            lsu_if.executedStoreQueuePtrByLoad[i] = '0;
        end
        for (int i = 0; i < STORE_ISSUE_WIDTH; i++) begin
            lsu_if.executeStore[i] = FALSE;
            lsu_if.executedStoreAddr[i] = '0;
            lsu_if.executedStoreData[i] = '0;
            lsu_if.executedStoreVectorData[i] = '0;
            lsu_if.executedStoreCondEnabled[i] = FALSE;
            lsu_if.executedStoreRegValid[i] = FALSE;
            lsu_if.executedStoreMemAccessMode[i] = '0;
            lsu_if.executedStoreQueuePtrByStore[i] = '0;
        end
        lsu_if.commitStore = FALSE;
        lsu_if.commitStoreNum = '0;
        lsu_if.releaseLoadQueue = FALSE;
        lsu_if.releaseLoadQueueEntryNum = '0;
        lsu_if.releaseStoreQueueHead = vl_releaseStoreQueueHead;
        lsu_if.releaseStoreQueueHeadEntryNum = vl_releaseStoreQueueHeadEntryNum;
        lsu_if.retiredStoreQueuePtr = '0;
        lsu_if.busyInRecovery = FALSE;
    end

`ifdef RSD_FUNCTIONAL_SIMULATION_VERILATOR
    assign vl_storeQueueAllocatable = lsu_if.storeQueueAllocatable;
    assign vl_storeQueueCount = lsu_if.storeQueueCount;
    assign vl_storeQueueHeadPtr = lsu_if.storeQueueHeadPtr;

    always_ff @(posedge clk) begin
        if (rst) begin
            vl_cap_allocPtr0 <= '0;
            vl_cap_allocPtr1 <= '0;
        end
        else if (|vl_allocateStoreQueue) begin
            vl_cap_allocPtr0 <= lsu_if.allocatedStoreQueuePtr[0];
            vl_cap_allocPtr1 <= lsu_if.allocatedStoreQueuePtr[1];
        end
    end
`endif

endmodule : TestStoreQueueWrapTop
