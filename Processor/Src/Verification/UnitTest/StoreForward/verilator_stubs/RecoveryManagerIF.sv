// Minimal RecoveryManagerIF for StoreForward Verilator unit test only.

import LoadStoreUnitTypes::*;

interface RecoveryManagerIF( input logic clk, input logic rst );

    logic toRecoveryPhase;
    StoreQueueIndexPath storeQueueRecoveryTailPtr;
    StoreQueueIndexPath storeQueueHeadPtr;

    modport StoreQueue(
        input  toRecoveryPhase,
               storeQueueRecoveryTailPtr,
        output storeQueueHeadPtr
    );
endinterface : RecoveryManagerIF
