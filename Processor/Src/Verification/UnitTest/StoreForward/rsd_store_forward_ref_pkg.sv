// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
//
// Reference model for store-to-load forwarding (LoadStoreUnit + StoreQueue).

`ifndef RSD_STORE_FORWARD_REF_PKG_SV
`define RSD_STORE_FORWARD_REF_PKG_SV

package rsd_store_forward_ref_pkg;

import BasicTypes::*;
import OpFormatTypes::*;
import MemoryMapTypes::*;
import LoadStoreUnitTypes::*;

// Mirror StoreQueue::GenerateStoreData
function automatic LSQ_BlockDataPath ref_generate_store_block(
    input DataPath dataIn,
    input PhyAddrPath addr
);
    LSQ_BlockDataPath dataOut;
    dataOut = dataIn;
    dataOut = dataOut << (addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * BYTE_WIDTH);
    return dataOut;
endfunction

// Correct LoadStoreUnit::ShiftForwardedData (*8)
function automatic DataPath ref_shift_forwarded_data(
    input LSQ_BlockDataPath srcLine,
    input PhyAddrPath addr
);
    DataPath data;
    data = srcLine >> (addr[LSQ_BLOCK_BYTE_WIDTH_BIT_SIZE-1:0] * 8);
    return data;
endfunction

// Mirror LoadStoreUnit::ExtendLoadData
function automatic DataPath ref_extend_load_data(
    input DataPath loadData,
    input MemAccessMode mode
);
    case (mode.size)
        MEM_ACCESS_SIZE_BYTE:
            return mode.isSigned ?
                { { 24{ loadData[7] } }, loadData[7:0] } :
                { { 24{ 1'b0 } }, loadData[7:0] };
        MEM_ACCESS_SIZE_HALF_WORD:
            return mode.isSigned ?
                { { 16{ loadData[15] } }, loadData[15:0] } :
                { { 16{ 1'b0 } }, loadData[15:0] };
        default:
            return loadData;
    endcase
endfunction

function automatic MemAccessMode make_byte_mode(input logic isSigned);
    MemAccessMode mode;
    mode.size = MEM_ACCESS_SIZE_BYTE;
    mode.isSigned = isSigned;
    return mode;
endfunction

function automatic MemAccessMode make_word_mode();
    MemAccessMode mode;
    mode.size = MEM_ACCESS_SIZE_WORD;
    mode.isSigned = FALSE;
    return mode;
endfunction

function automatic DataPath ref_forwarded_load_result(
    input DataPath storeData,
    input PhyAddrPath storeAddr,
    input PhyAddrPath loadAddr,
    input MemAccessMode loadMode
);
    LSQ_BlockDataPath block;
    DataPath shifted;
    block = ref_generate_store_block(storeData, storeAddr);
    shifted = ref_shift_forwarded_data(block, loadAddr);
    return ref_extend_load_data(shifted, loadMode);
endfunction

endpackage : rsd_store_forward_ref_pkg

`endif
