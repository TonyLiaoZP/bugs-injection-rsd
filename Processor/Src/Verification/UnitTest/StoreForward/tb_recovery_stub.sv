// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

import LoadStoreUnitTypes::*;

module TbRecoveryStub( RecoveryManagerIF rec );
    assign rec.toRecoveryPhase = FALSE;
    assign rec.storeQueueRecoveryTailPtr = '0;
endmodule
