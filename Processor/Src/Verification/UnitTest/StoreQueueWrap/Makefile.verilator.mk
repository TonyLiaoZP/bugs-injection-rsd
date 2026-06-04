# Verilator flow for BUG_006 StoreQueue wrap-around unit test
# Usage (from this directory):
#   make -f Makefile.verilator.mk run
#   RSD_VERILATOR_BIN=/path/to/verilator make -f Makefile.verilator.mk run

UNIT_DIR     := $(abspath .)
STORE_FWD    := $(abspath ../StoreForward)
SRC_ROOT     := $(abspath ../../../)
PROJECT_WORK := $(abspath ../../../../Project/Verilator/StoreQueueWrap)
TOP_MODULE   := TestStoreQueueWrapTop
VERILATED    := V$(TOP_MODULE)

ifndef RSD_VERILATOR_BIN
RSD_VERILATOR_BIN := verilator
endif

VERILATOR := $(RSD_VERILATOR_BIN)

VERILATOR_FLAGS := \
	--cc --exe --build \
	--top-module $(TOP_MODULE) \
	-sv \
	+define+RSD_FUNCTIONAL_SIMULATION \
	+define+RSD_FUNCTIONAL_SIMULATION_VERILATOR \
	-Wno-DECLFILENAME -Wno-IMPORTSTAR -Wno-TIMESCALEMOD -Wno-VARHIDDEN \
	-Wno-WIDTH -Wno-INITIALDLY -Wno-UNOPTFLAT -Wno-UNUSED \
	+incdir+$(SRC_ROOT) \
	+incdir+$(UNIT_DIR) \
	+incdir+$(STORE_FWD)/verilator_stubs \
	--Mdir $(PROJECT_WORK)/obj_dir \
	-CFLAGS "-Os -std=c++14" \
	-o $(VERILATED)_sim

VL_SOURCES := \
	$(SRC_ROOT)/MicroArchConf.sv \
	$(SRC_ROOT)/BasicTypes.sv \
	$(SRC_ROOT)/Memory/MemoryMapTypes.sv \
	$(SRC_ROOT)/RenameLogic/ActiveListIndexTypes.sv \
	$(SRC_ROOT)/Decoder/OpFormat.sv \
	$(SRC_ROOT)/Decoder/MicroOp.sv \
	$(SRC_ROOT)/Cache/CacheSystemTypes.sv \
	$(SRC_ROOT)/LoadStoreUnit/LoadStoreUnitTypes.sv \
	$(STORE_FWD)/verilator_stubs/DebugTypes.sv \
	$(STORE_FWD)/verilator_stubs/PipelineTypes.sv \
	$(STORE_FWD)/verilator_stubs/RecoveryManagerIF.sv \
	$(SRC_ROOT)/LoadStoreUnit/LoadStoreUnitIF.sv \
	$(SRC_ROOT)/Primitives/RAM.sv \
	$(SRC_ROOT)/Primitives/Picker.sv \
	$(SRC_ROOT)/Primitives/Queue.sv \
	$(SRC_ROOT)/LoadStoreUnit/StoreQueue.sv \
	$(UNIT_DIR)/tb_recovery_stub.sv \
	$(UNIT_DIR)/tb_sq_wrap.sv \
	$(SRC_ROOT)/SysDeps/Verilator/TestMain_BUG006.cpp

.PHONY: all build run clean

all: build

build:
	mkdir -p $(PROJECT_WORK)/obj_dir
	$(VERILATOR) $(VERILATOR_FLAGS) $(VL_SOURCES)

run: build
	$(PROJECT_WORK)/obj_dir/$(VERILATED)_sim

clean:
	rm -rf $(PROJECT_WORK)/obj_dir
