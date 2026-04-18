# Incremental-friendly Verilator makefile.
# This file does NOT modify the original Makefile.verilator.mk flow.

# Specify test code and simulation cycles
MAX_TEST_CYCLES = 100000
SHOW_SERIAL_OUT = 1
ENABLE_PC_GOAL = 1
TEST_CODE = Verification/TestCode/Asm/BugTest
#TEST_CODE = Verification/TestCode/Asm/FP
#TEST_CODE = Verification/TestCode/C/HelloWorld

ifndef RSD_VERILATOR_BIN
VERILATOR_BIN = verilator
else
VERILATOR_BIN = $(RSD_VERILATOR_BIN)
endif

SOURCE_ROOT  = ./
TOOLS_ROOT   = ../Tools/
PROJECT_WORK = ../Project/Verilator
LIBRARY_WORK_RTL = $(PROJECT_WORK)/obj_dir

TOP_MODULE = Main_Zynq_Wrapper
VERILATED_TOP_MODULE_NAME = V$(TOP_MODULE)
VERILATED_MK = $(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME).mk
VERILATOR_GEN_STAMP = $(LIBRARY_WORK_RTL)/.verilator_gen.stamp

# Convert a RSD log to a Kanata log.
KANATA_CONVERTER = python3 ../Tools/KanataConverter/KanataConverter.py
RSD_LOG_FILE_RTL = RSD.log
KANATA_LOG_FILE_RTL = Kanata.log

# Include core source code definition
include Makefiles/CoreSources.inc.mk

DEBUG_HELPERS = \
	SysDeps/Verilator/VerilatorHelper.sv

DEPS_RTL = \
	$(TYPES:%=$(SOURCE_ROOT)%) \
	$(MODULES:%=$(SOURCE_ROOT)%) \
	$(DEBUG_HELPERS:%=$(SOURCE_ROOT)%) \
	# $(TEST_MODULES:%=$(SOURCE_ROOT)%) \

# Temporally disabled warnings
VERILATOR_DISABLED_WARNING = \
	-Wno-WIDTH \
	-Wno-INITIALDLY \
	-Wno-UNOPTFLAT \

# RSD specific constants
# RSD_SRC_CFG is defined in Makefiles/CoreSources.inc.mk
RSD_VERILATOR_DEFINITION = \
	+define+RSD_FUNCTIONAL_SIMULATION \
	+define+RSD_FUNCTIONAL_SIMULATION_VERILATOR \
	$(RSD_SRC_CFG) \

VERILATOR_OPTION = \
	--cc \
	--assert \
	-sv \
	--exe ./SysDeps/Verilator/TestMain.cpp \
	--top-module $(TOP_MODULE) \
	$(VERILATOR_DISABLED_WARNING) \
	$(RSD_VERILATOR_DEFINITION) \
	--Mdir $(LIBRARY_WORK_RTL) \
	+incdir+. \
	--trace \
	-CFLAGS "-Os -include limits" \
	-output-split 15000 \

VERILATOR_TARGET_CXXFLAGS = \
	-D RSD_FUNCTIONAL_SIMULATION_VERILATOR \
	-D RSD_FUNCTIONAL_SIMULATION \
	-D RSD_VERILATOR_TRACE \
	-D RSD_MARCH_FP_PIPE \
	-Wno-attributes \

# Use parallel build mode for finer-grained C++ incrementality.
VERILATOR_SUBMAKE_ARGS ?= \
	CXX=g++ \
	LINK=g++ \
	PERL=perl \
	PYTHON3=python3 \
	VM_PARALLEL_BUILDS=1

.PHONY: default all gen build run kanata dump clean clean-gen help

default: all

all: build

help:
	@echo "Targets:"
	@echo "  gen     : Run Verilator code generation if sources changed"
	@echo "  build   : Build simulator incrementally (gen + C++ build)"
	@echo "  run     : Run simulation"
	@echo "  kanata  : Run simulation and generate Kanata.log"
	@echo "  dump    : Run simulation and generate dump files"
	@echo "  clean   : Remove whole obj_dir"
	@echo "  clean-gen: Remove generated Verilator files but keep folder"

$(LIBRARY_WORK_RTL):
	mkdir -p $(PROJECT_WORK)

# Regenerate only when source or make settings changed.
$(VERILATOR_GEN_STAMP): $(DEPS_RTL) Makefiles/CoreSources.inc.mk Makefile.verilator.incremental.mk | $(LIBRARY_WORK_RTL)
	$(VERILATOR_BIN) $(VERILATOR_OPTION) $(DEPS_RTL)
	touch $(VERILATOR_GEN_STAMP)

gen: $(VERILATOR_GEN_STAMP)

build: gen
	$(MAKE) -C $(LIBRARY_WORK_RTL) -f $(VERILATED_TOP_MODULE_NAME).mk \
		VPATH=../../../Src \
		CXXFLAGS="$(VERILATOR_TARGET_CXXFLAGS)" \
		$(VERILATOR_SUBMAKE_ARGS)
	@echo "==== Incremental Build Successful ===="

run: build
	$(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME) \
		MAX_TEST_CYCLES=$(MAX_TEST_CYCLES) \
		TEST_CODE=$(TEST_CODE) ENABLE_PC_GOAL=$(ENABLE_PC_GOAL) SHOW_SERIAL_OUT=$(SHOW_SERIAL_OUT)

kanata: build
	$(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME) \
		MAX_TEST_CYCLES=$(MAX_TEST_CYCLES) \
		TEST_CODE=$(TEST_CODE) ENABLE_PC_GOAL=$(ENABLE_PC_GOAL) SHOW_SERIAL_OUT=$(SHOW_SERIAL_OUT) \
		REG_CSV_FILE=Register.csv \
		RSD_LOG_FILE=RSD.log
	$(KANATA_CONVERTER) $(RSD_LOG_FILE_RTL) $(KANATA_LOG_FILE_RTL)

dump: build
	$(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME) \
		MAX_TEST_CYCLES=$(MAX_TEST_CYCLES) \
		TEST_CODE=$(TEST_CODE) ENABLE_PC_GOAL=$(ENABLE_PC_GOAL) SHOW_SERIAL_OUT=$(SHOW_SERIAL_OUT) \
		REG_CSV_FILE=Register.csv \
		RSD_LOG_FILE=RSD.log \
		WAVE_LOG_FILE=simx.vcd
	$(KANATA_CONVERTER) $(RSD_LOG_FILE_RTL) $(KANATA_LOG_FILE_RTL)

clean-gen:
	rm -f $(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME).mk
	rm -f $(LIBRARY_WORK_RTL)/$(VERILATED_TOP_MODULE_NAME)__*
	rm -f $(VERILATOR_GEN_STAMP)
	rm -f $(LIBRARY_WORK_RTL)/*.cpp $(LIBRARY_WORK_RTL)/*.h $(LIBRARY_WORK_RTL)/*.o $(LIBRARY_WORK_RTL)/*.d
	rm -f $(LIBRARY_WORK_RTL)/*.a

clean:
	rm -rf $(LIBRARY_WORK_RTL)
