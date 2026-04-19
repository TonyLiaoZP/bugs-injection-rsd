#!/bin/bash
# Simple test runner for BUG_003 directed test

echo "Running BUG_003 directed test..."
echo ""

# Try iverilog first (most common)
if command -v iverilog &> /dev/null; then
    echo "Using iverilog..."
    iverilog -o test_bug003 TestBUG003.sv && vvp test_bug003
    exit $?
fi

# Try verilator with simple wrapper
if command -v verilator &> /dev/null; then
    echo "Using verilator..."
    verilator --binary --timing -Wall TestBUG003.sv
    if [ -f obj_dir/VTestBUG003 ]; then
        ./obj_dir/VTestBUG003
        exit $?
    fi
fi

echo "Error: No Verilog simulator found (iverilog or verilator)"
echo "Please install iverilog: sudo apt-get install iverilog"
exit 1
