// Minimal ControllerIF for StoreForward Verilator unit test only.

import PipelineTypes::*;

interface ControllerIF(
    input logic clk,
    input logic rst
);
    PipelineControll backEnd;

    modport LoadStoreUnit( input backEnd );
endinterface : ControllerIF
