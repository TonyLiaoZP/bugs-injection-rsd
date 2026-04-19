# Makefile for BUG_003 directed test

# Verilator settings
VERILATOR = verilator
VERILATOR_FLAGS = -Wall -Wno-fatal --trace --cc --exe --build

# Source files
TEST_SV = TestBUG003.sv

# Output
TARGET = obj_dir/VTestBUG003

.PHONY: all run clean

all: $(TARGET)

$(TARGET): $(TEST_SV)
	$(VERILATOR) $(VERILATOR_FLAGS) $(TEST_SV) --top-module TestBUG003

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf obj_dir *.vcd

help:
	@echo "Makefile for BUG_003 directed test"
	@echo ""
	@echo "Targets:"
	@echo "  all   - Build the test (default)"
	@echo "  run   - Build and run the test"
	@echo "  clean - Remove build artifacts"
	@echo ""
	@echo "Usage:"
	@echo "  make run    # Build and run test"
