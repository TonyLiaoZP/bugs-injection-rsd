# Store-to-load forwarding unit test (BUG_003)
UNIT_NAME         = StoreForward

TEST_BENCH_MODULE = TestBUG_003

SOURCE_ROOT  = ../../../
TOOLS_ROOT   = ../../../../Tools/
PROJECT_WORK = ../../../../Project/ModelSim

TYPES = \
	BasicTypes.sv \
	MicroArchConf.sv \
	Memory/MemoryMapTypes.sv \
	Cache/CacheSystemTypes.sv \
	Decoder/OpFormat.sv \
	LoadStoreUnit/LoadStoreUnitTypes.sv \
	RenameLogic/ActiveListIndexTypes.sv \
	RenameLogic/RenameLogicTypes.sv \
	Scheduler/SchedulerTypes.sv \
	Pipeline/PipelineTypes.sv \
	Verification/UnitTest/StoreForward/rsd_store_forward_ref_pkg.sv \

TEST_MODULES = \
	Verification/TestBenchClockGenerator.sv \
	Verification/UnitTest/StoreForward/TestBUG_003.sv \

MODULES = \
	Primitives/RAM.sv \
	Primitives/Picker.sv \
	ControllerIF.sv \
	Recovery/RecoveryManagerIF.sv \
	LoadStoreUnit/LoadStoreUnitIF.sv \
	LoadStoreUnit/StoreQueue.sv \
	LoadStoreUnit/LoadStoreUnit.sv \
	Verification/UnitTest/StoreForward/tb_controller_stub.sv \
	Verification/UnitTest/StoreForward/tb_recovery_stub.sv \
	Verification/UnitTest/StoreForward/tb_sq_lsu_wrap.sv \

VLOG_OPTIONS = \
	-suppress 2605 \

VSIM_OPTIONS = \
	-suppress 2605 \
	-suppress 8233 \

include ../../../Makefile.inc
