// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
//
// Minimal DUT for store-to-load forwarding: StoreQueue + LoadStoreUnit.

`timescale 1ns/1ps

import BasicTypes::*;
import OpFormatTypes::*;
import MemoryMapTypes::*;
import LoadStoreUnitTypes::*;

`ifdef RSD_FUNCTIONAL_SIMULATION_VERILATOR
module TestStoreForwardTop (
    input  logic clk,
    input  logic rst,
    // Flat test ports for C++ (lane 0)
    input  logic vl_allocateStoreQueue,
    input  logic vl_executeStore,
    input  logic vl_executeLoad,
    input  StoreQueueIndexPath vl_executedStoreQueuePtrByStore,
    input  PhyAddrPath vl_executedStoreAddr,
    input  DataPath vl_executedStoreData,
    input  logic vl_executedStoreCondEnabled,
    input  logic vl_executedStoreRegValid,
    input  MemAccessMode vl_executedStoreMemAccessMode,
    input  StoreQueueIndexPath vl_executedStoreQueuePtrByLoad,
    input  PhyAddrPath vl_executedLoadAddr,
    input  MemoryMapType vl_executedLoadMemMapType,
    input  MemAccessMode vl_executedLoadMemAccessMode,
    input  logic vl_executedLoadRegValid,
    output StoreQueueIndexPath vl_allocatedStoreQueuePtr,
    output logic vl_storeLoadForwarded,
    output logic vl_forwardMiss,
    output DataPath vl_executedLoadData,
    output StoreQueueCountPath vl_storeQueueCount,
    // Posedge captures for C++ (avoid comb/NBA sampling races)
    output StoreQueueIndexPath vl_cap_allocatedSqIdx,
    output logic vl_cap_forwarded,
    output logic vl_cap_forwardMiss
);
    logic clk_p, clk_n;
    assign clk_p = clk;
    assign clk_n = ~clk;
`else
module TestStoreForwardTop (
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
    ControllerIF        ctrl_if( clk, rst );
    RecoveryManagerIF   rec_if( clk, rst );

    TbControllerStub    ctrl_stub( ctrl_if );
    TbRecoveryStub      rec_stub( rec_if );

    StoreQueue          sq( lsu_if, rec_if );
    LoadStoreUnit       loadStoreUnit( lsu_if, ctrl_if );

    // No LoadQueue in this bench — allocation is always available.
    assign lsu_if.loadQueueAllocatable = TRUE;

    // Keep store in SQ: no commit / release.
    assign lsu_if.commitStore = FALSE;
    assign lsu_if.commitStoreNum = '0;
    assign lsu_if.releaseLoadQueue = FALSE;
    assign lsu_if.releaseLoadQueueEntryNum = '0;
    assign lsu_if.releaseStoreQueueHead = FALSE;
    assign lsu_if.releaseStoreQueueHeadEntryNum = '0;
    assign lsu_if.retiredStoreQueuePtr = '0;

    // DCache / MSHR paths unused when forwarding hits.
    always_comb begin
        for (int i = 0; i < LOAD_ISSUE_WIDTH; i++) begin
            lsu_if.dcReadData[i] = '0;
            lsu_if.mshrReadHit[i] = FALSE;
            lsu_if.mshrReadData[i] = '0;
        end
        lsu_if.busyInRecovery = FALSE;
    end

`ifdef RSD_FUNCTIONAL_SIMULATION_VERILATOR
    always_comb begin
        for (int i = 0; i < RENAME_WIDTH; i++) begin
            lsu_if.allocateStoreQueue[i] = (i == 0) ? vl_allocateStoreQueue : FALSE;
        end
    end
    assign lsu_if.executeStore[0] = vl_executeStore;
    assign lsu_if.executeLoad[0] = vl_executeLoad;
    assign lsu_if.executedStoreQueuePtrByStore[0] = vl_executedStoreQueuePtrByStore;
    assign lsu_if.executedStoreAddr[0] = vl_executedStoreAddr;
    assign lsu_if.executedStoreData[0] = vl_executedStoreData;
    assign lsu_if.executedStoreCondEnabled[0] = vl_executedStoreCondEnabled;
    assign lsu_if.executedStoreRegValid[0] = vl_executedStoreRegValid;
    assign lsu_if.executedStoreMemAccessMode[0] = vl_executedStoreMemAccessMode;
    assign lsu_if.executedStoreQueuePtrByLoad[0] = vl_executedStoreQueuePtrByLoad;
    assign lsu_if.executedLoadAddr[0] = vl_executedLoadAddr;
    assign lsu_if.executedLoadMemMapType[0] = vl_executedLoadMemMapType;
    assign lsu_if.executedLoadMemAccessMode[0] = vl_executedLoadMemAccessMode;
    assign lsu_if.executedLoadRegValid[0] = vl_executedLoadRegValid;

    assign vl_allocatedStoreQueuePtr = lsu_if.allocatedStoreQueuePtr[0];
    assign vl_storeLoadForwarded = lsu_if.storeLoadForwarded[0];
    assign vl_forwardMiss = lsu_if.forwardMiss[0];
    assign vl_executedLoadData = lsu_if.executedLoadData[0];
    assign vl_storeQueueCount = lsu_if.storeQueueCount;

    always_ff @(posedge clk) begin
        if (rst) begin
            vl_cap_allocatedSqIdx <= '0;
            vl_cap_forwarded      <= FALSE;
            vl_cap_forwardMiss    <= FALSE;
        end
        else begin
            if (vl_allocateStoreQueue) begin
                vl_cap_allocatedSqIdx <= lsu_if.allocatedStoreQueuePtr[0];
            end
            if (vl_executeLoad) begin
                vl_cap_forwarded   <= lsu_if.storeLoadForwarded[0];
                vl_cap_forwardMiss <= lsu_if.forwardMiss[0];
            end
        end
    end
`endif

endmodule : TestStoreForwardTop
