// Minimal PipelineTypes for StoreForward Verilator unit test only.
// Do not use in Questa flow (full Processor/Src/Pipeline/PipelineTypes.sv is used there).

package PipelineTypes;

import BasicTypes::*;

typedef struct packed
{
    logic stall;
    logic clear;
} PipelineControll;

endpackage : PipelineTypes
