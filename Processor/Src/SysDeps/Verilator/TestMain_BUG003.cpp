// Pure-Verilator test for BUG_003 (StoreQueue + LoadStoreUnit forwarding).
// No Questa/SV testbench sequence required.

#include "VTestStoreForwardTop.h"
#include <cstdio>
#include <cstdint>
#include <verilated.h>

static unsigned int main_time = 0;

double sc_time_stamp()
{
    return main_time;
}

static void eval(VTestStoreForwardTop* top)
{
    top->eval();
}

// Rising edge: clk low -> high (signals must be stable before call).
static void posedge(VTestStoreForwardTop* top, int half_ns)
{
    top->clk = 0;
    eval(top);
    main_time += static_cast<unsigned int>(half_ns);

    top->clk = 1;
    eval(top);
    main_time += static_cast<unsigned int>(half_ns);
}

static void drive_idle(VTestStoreForwardTop* top)
{
    top->vl_allocateStoreQueue = 0;
    top->vl_executeStore = 0;
    top->vl_executeLoad = 0;
    top->vl_executedStoreCondEnabled = 0;
    top->vl_executedStoreRegValid = 0;
    top->vl_executedStoreAddr = 0;
    top->vl_executedStoreData = 0;
    top->vl_executedLoadAddr = 0;
    top->vl_executedStoreMemAccessMode = 0;
    top->vl_executedLoadMemAccessMode = 0;
    top->vl_executedStoreQueuePtrByStore = 0;
    top->vl_executedStoreQueuePtrByLoad = 0;
}

static void reset_dut(VTestStoreForwardTop* top, int half_ns, int cycles)
{
    top->rst = 1;
    drive_idle(top);
    for (int i = 0; i < cycles; i++) {
        posedge(top, half_ns);
    }
    top->rst = 0;
    drive_idle(top);
    posedge(top, half_ns);
}

// MemAccessMode is packed { isSigned, size[1:0] } in RTL. Verilator case checks (3 & mode),
// which equals size only when isSigned=0. Use size in bits [2:1] (WORD=2, BYTE=0).
static constexpr uint32_t kMemWordUnsigned = 2u; // MEM_ACCESS_SIZE_WORD (size in [2:1], isSigned=0)
static constexpr uint32_t kMemByteUnsigned = 0u; // MEM_ACCESS_SIZE_BYTE
// BYTE with isSigned in bit 2: (3&mode)==0 for match, ExtendLoadData uses upper bit for sign.
static constexpr uint32_t kMemByteSigned   = 4u;

// Match Questa TestBUG_003: integer literal assigned to packed PhyAddrPath (22 bits).
static uint32_t phy_addr_from_logical(uint32_t logical_addr)
{
    return logical_addr & ((1u << 22) - 1u);
}

static uint32_t ref_forward_byte_load(
    uint32_t storeData,
    uint32_t storeAddr,
    uint32_t loadAddr,
    bool signedLoad)
{
    const unsigned blockByteOffSt = (storeAddr >> 0) & 0x3u;
    const unsigned blockByteOffLd = (loadAddr >> 0) & 0x3u;

    uint32_t block = storeData << (blockByteOffSt * 8u);
    uint32_t shifted = block >> (blockByteOffLd * 8u);
    uint8_t byteVal = static_cast<uint8_t>(shifted & 0xFFu);

    if (signedLoad) {
        return static_cast<uint32_t>(static_cast<int32_t>(static_cast<int8_t>(byteVal)));
    }
    return static_cast<uint32_t>(byteVal);
}

struct CaseSpec {
    const char* name;
    uint32_t storeAddr;
    uint32_t loadAddr;
    uint32_t storeData;
    bool signedLoad;
};

static int run_case(VTestStoreForwardTop* top, const CaseSpec& c, int half_ns)
{
    const uint32_t expected = ref_forward_byte_load(
        c.storeData, c.storeAddr, c.loadAddr, c.signedLoad);

    reset_dut(top, half_ns, 8);

    if (top->vl_storeQueueCount != 0) {
        fprintf(stderr, "%s: store queue not empty after reset (count=%u)\n",
            c.name, top->vl_storeQueueCount);
        return 1;
    }

    // --- Allocate one SQ entry (posedge capture in RTL) ---
    drive_idle(top);
    top->vl_allocateStoreQueue = 1;
    posedge(top, half_ns);
    const uint32_t sqIdx = top->vl_cap_allocatedSqIdx;
    top->vl_allocateStoreQueue = 0;
    drive_idle(top);
    posedge(top, half_ns);

    // --- Execute store into SQ[sqIdx] ---
    top->vl_executedStoreQueuePtrByStore = sqIdx;
    top->vl_executedStoreAddr = phy_addr_from_logical(c.storeAddr);
    top->vl_executedStoreData = c.storeData;
    top->vl_executedStoreCondEnabled = 1;
    top->vl_executedStoreRegValid = 1;
    top->vl_executedStoreMemAccessMode = kMemWordUnsigned;
    top->vl_executeStore = 1;
    posedge(top, half_ns);
    top->vl_executeStore = 0;
    drive_idle(top);
    posedge(top, half_ns);
    posedge(top, half_ns);

    // --- Execute load; load's SQ bound = tail after alloc (sqIdx + 1) ---
    const uint32_t sqTail = (sqIdx + 1u) & 0xFu;
    top->vl_executedLoadAddr = phy_addr_from_logical(c.loadAddr);
    top->vl_executedLoadMemMapType = 0u; // MMT_MEMORY
    top->vl_executedLoadMemAccessMode =
        c.signedLoad ? kMemByteSigned : kMemByteUnsigned;
    top->vl_executedLoadRegValid = 1;
    top->vl_executedStoreQueuePtrByLoad = sqTail;
    top->vl_executeLoad = 1;
    // Sample comb forwarding before load posedge (same as TestBUG_003 #HOLD before @(posedge)).
    top->clk = 0;
    eval(top);
    const bool forwarded = top->vl_storeLoadForwarded;
    const bool forwardMiss = top->vl_forwardMiss;
    posedge(top, half_ns);
    top->vl_executeLoad = 0;
    drive_idle(top);
    eval(top);

    // LSU latches at load posedge; comb output may need one more eval/edge in Verilator.
    uint32_t actual = top->vl_executedLoadData;
    if (actual == 0u) {
        posedge(top, half_ns);
        eval(top);
        actual = top->vl_executedLoadData;
    }

    if (!forwarded || forwardMiss) {
        fprintf(stderr, "%s: FAIL forwarding (fwd=%d miss=%d sqIdx=%u sqTail=%u)\n",
            c.name, forwarded, forwardMiss, sqIdx, sqTail);
        return 1;
    }
    if (actual != expected) {
        fprintf(stderr, "%s: FAIL expected=0x%08x actual=0x%08x\n",
            c.name, expected, actual);
        return 1;
    }
    printf("%s: PASS (0x%08x)\n", c.name, actual);
    return 0;
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);
    auto* top = new VTestStoreForwardTop;

    const int HALF_NS = 5;
    top->clk = 0;
    drive_idle(top);
    eval(top);

    printf("=== BUG_003 store-forward unit test (Verilator) ===\n");

    const CaseSpec cases[] = {
        { "byte_offset_1", 0x80000000u, 0x80000001u, 0x11223344u, true },
        { "byte_offset_2", 0x80000004u, 0x80000006u, 0x55667788u, true },
        { "byte_offset_3", 0x80000008u, 0x8000000Bu, 0x99AABBCCu, true },
        { "byte_offset_0_unsigned", 0x80000010u, 0x80000010u, 0xAABBCCDDu, false },
    };

    int fail = 0;
    for (const auto& spec : cases) {
        fail += run_case(top, spec, HALF_NS);
    }

    printf("=== Summary: %s ===\n", fail ? "FAILED" : "PASSED");
    delete top;
    return fail ? 1 : 0;
}
