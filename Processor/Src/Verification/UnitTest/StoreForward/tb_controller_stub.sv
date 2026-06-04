// Copyright 2019- RSD contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.

import PipelineTypes::*;

module TbControllerStub( ControllerIF ctrl );
    assign ctrl.backEnd = '{ stall: FALSE, clear: FALSE };
endmodule
