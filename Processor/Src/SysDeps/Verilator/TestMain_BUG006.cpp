// Pure-Verilator test for BUG_006 (StoreQueue wrap-around allocation pointers).

#include "VTestStoreQueueWrapTop.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <verilated.h>

static constexpr uint32_t kSqSize = 16u;
static constexpr uint32_t kRenameWidth = 2u;
static constexpr uint32_t kMaxCountForDualAlloc = kSqSize - kRenameWidth - 1u; // 13

static unsigned int main_time = 0;

double sc_time_stamp()
{
    return main_time;
}

static void eval(VTestStoreQueueWrapTop* top)
{
    top->eval();
}

static void posedge(VTestStoreQueueWrapTop* top, int half_ns)
{
    top->clk = 0;
    eval(top);
    main_time += static_cast<unsigned int>(half_ns);

    top->clk = 1;
    eval(top);
    main_time += static_cast<unsigned int>(half_ns);
}

static void drive_idle(VTestStoreQueueWrapTop* top)
{
    top->vl_allocateStoreQueue = 0;
    top->vl_releaseStoreQueueHead = 0;
    top->vl_releaseStoreQueueHeadEntryNum = 0;
}

static void reset_dut(VTestStoreQueueWrapTop* top, int half_ns, int cycles)
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

// Golden FIFO (head/tail/count) — same rules as SetTailMultiWidthQueuePointer + correct ptr math.
struct FifoModel {
    uint32_t head = 0;
    uint32_t tail = 0;
    uint32_t count = 0;

    void reset()
    {
        head = 0;
        tail = 0;
        count = 0;
    }

    bool allocatable() const
    {
        return count <= kMaxCountForDualAlloc;
    }

    void release(uint32_t num)
    {
        if (num == 0u) {
            return;
        }
        head = (head + num) % kSqSize;
        count -= num;
    }

    // Indices of entries this allocate would add (spec-correct), before updating tail/count.
    uint32_t expected_new_slots(uint32_t mask, uint32_t slots[2]) const
    {
        uint32_t n = 0;
        uint32_t pushCount = 0;
        for (uint32_t lane = 0; lane < kRenameWidth; lane++) {
            if ((mask & (1u << lane)) == 0u) {
                continue;
            }
            const uint32_t t = tail + pushCount;
            slots[n++] = (t < kSqSize) ? t : (t - kSqSize);
            pushCount++;
        }
        return n;
    }

    void apply_allocate(uint32_t mask)
    {
        uint32_t pushCount = 0;
        for (uint32_t lane = 0; lane < kRenameWidth; lane++) {
            pushCount += (mask & (1u << lane)) ? 1u : 0u;
        }
        if (pushCount == 0u) {
            return;
        }
        uint32_t nextTail = tail + pushCount;
        if (nextTail >= kSqSize) {
            nextTail -= kSqSize;
        }
        tail = nextTail;
        count += pushCount;
    }

    void ring_occupancy(bool occ[kSqSize]) const
    {
        for (uint32_t i = 0; i < kSqSize; i++) {
            occ[i] = false;
        }
        for (uint32_t i = 0; i < count; i++) {
            occ[(head + i) % kSqSize] = true;
        }
    }
};

static void slots_to_string(
    const uint32_t* slots,
    uint32_t n,
    char* buf,
    size_t buf_len)
{
    buf[0] = '\0';
    size_t off = 0;
    for (uint32_t i = 0; i < n; i++) {
        const int w = snprintf(
            buf + off,
            (off < buf_len) ? (buf_len - off) : 0,
            "%s%u",
            (i == 0u) ? "" : ",",
            slots[i]);
        if (w < 0 || off + static_cast<size_t>(w) >= buf_len) {
            break;
        }
        off += static_cast<size_t>(w);
    }
}

static bool slot_sets_equal(
    const uint32_t* a,
    uint32_t na,
    const uint32_t* b,
    uint32_t nb)
{
    if (na != nb) {
        return false;
    }
    for (uint32_t i = 0; i < na; i++) {
        bool found = false;
        for (uint32_t j = 0; j < nb; j++) {
            if (a[i] == b[j]) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
    }
    return true;
}

static uint32_t dut_captured_slots(
    uint32_t mask,
    uint32_t cap0,
    uint32_t cap1,
    uint32_t slots[2])
{
    uint32_t n = 0;
    if (mask & 0x1u) {
        slots[n++] = cap0;
    }
    if (mask & 0x2u) {
        slots[n++] = cap1;
    }
    return n;
}

static int sync_fifo_metadata(
    VTestStoreQueueWrapTop* top,
    const FifoModel& model,
    const char* where)
{
    if (top->vl_storeQueueCount != model.count) {
        fprintf(stderr,
            "%s: FAIL count mismatch (DUT=%u ref-FIFO=%u)\n",
            where, top->vl_storeQueueCount, model.count);
        return 1;
    }
    if (top->vl_storeQueueHeadPtr != model.head) {
        fprintf(stderr,
            "%s: FAIL head mismatch (DUT=%u ref-FIFO=%u)\n",
            where, top->vl_storeQueueHeadPtr, model.head);
        return 1;
    }
    const bool dut_alloc = top->vl_storeQueueAllocatable;
    const bool ref_alloc = model.allocatable();
    if (dut_alloc != ref_alloc) {
        fprintf(stderr,
            "%s: FAIL allocatable mismatch (DUT=%d ref-FIFO=%d count=%u)\n",
            where, dut_alloc, ref_alloc, model.count);
        return 1;
    }
    return 0;
}

static void alloc_posedge(
    VTestStoreQueueWrapTop* top,
    int half_ns,
    uint32_t mask,
    uint32_t* cap0,
    uint32_t* cap1)
{
    top->vl_allocateStoreQueue = mask & 0x3u;
    posedge(top, half_ns);
    if (cap0) {
        *cap0 = top->vl_cap_allocPtr0;
    }
    if (cap1) {
        *cap1 = top->vl_cap_allocPtr1;
    }
    top->vl_allocateStoreQueue = 0;
    drive_idle(top);
    posedge(top, half_ns);
}

static void release_head(VTestStoreQueueWrapTop* top, int half_ns, uint32_t num)
{
    top->vl_releaseStoreQueueHead = 1;
    top->vl_releaseStoreQueueHeadEntryNum = num;
    posedge(top, half_ns);
    top->vl_releaseStoreQueueHead = 0;
    top->vl_releaseStoreQueueHeadEntryNum = 0;
    drive_idle(top);
    posedge(top, half_ns);
}

static int fill_store_queue(VTestStoreQueueWrapTop* top, int half_ns)
{
    int rounds = 0;
    while (top->vl_storeQueueAllocatable) {
        alloc_posedge(top, half_ns, 0x3u, nullptr, nullptr);
        rounds++;
        if (rounds > 32) {
            fprintf(stderr, "fill_store_queue: alloc loop did not terminate\n");
            return 1;
        }
    }
    if (top->vl_storeQueueCount != 14u) {
        fprintf(stderr,
            "fill_store_queue: expected count=14 got %u (rounds=%d)\n",
            top->vl_storeQueueCount, rounds);
        return 1;
    }
    return 0;
}

static int test_dual_alloc_no_wrap(VTestStoreQueueWrapTop* top, int half_ns)
{
    const char* name = "dual_alloc_no_wrap";
    reset_dut(top, half_ns, 4);

    uint32_t p0 = 0, p1 = 0;
    alloc_posedge(top, half_ns, 0x3u, &p0, &p1);

    if (p0 != 0u || p1 != 1u) {
        fprintf(stderr, "%s: FAIL ptr0=%u ptr1=%u (expected 0,1)\n",
            name, p0, p1);
        return 1;
    }
    if (top->vl_storeQueueCount != 2u) {
        fprintf(stderr, "%s: FAIL count=%u (expected 2)\n",
            name, top->vl_storeQueueCount);
        return 1;
    }
    printf("%s: PASS (ptr0=%u ptr1=%u)\n", name, p0, p1);
    return 0;
}

static int test_wrap_second_lane(VTestStoreQueueWrapTop* top, int half_ns)
{
    const char* name = "wrap_second_lane";
    reset_dut(top, half_ns, 4);

    if (fill_store_queue(top, half_ns) != 0) {
        return 1;
    }

    release_head(top, half_ns, 1u);
    if (top->vl_storeQueueCount != 13u) {
        fprintf(stderr, "%s: FAIL count after release1=%u (expected 13)\n",
            name, top->vl_storeQueueCount);
        return 1;
    }

    uint32_t p0 = 0, p1 = 0;
    alloc_posedge(top, half_ns, 0x1u, &p0, &p1);
    if (p0 != 14u) {
        fprintf(stderr, "%s: FAIL single alloc ptr0=%u (expected 14)\n",
            name, p0);
        return 1;
    }
    if (top->vl_storeQueueCount != 14u) {
        fprintf(stderr, "%s: FAIL count after single alloc=%u (expected 14)\n",
            name, top->vl_storeQueueCount);
        return 1;
    }

    release_head(top, half_ns, 1u);
    if (top->vl_storeQueueCount != 13u) {
        fprintf(stderr, "%s: FAIL count after release2=%u (expected 13)\n",
            name, top->vl_storeQueueCount);
        return 1;
    }

    alloc_posedge(top, half_ns, 0x3u, &p0, &p1);
    if (p0 != 15u || p1 != 0u) {
        fprintf(stderr,
            "%s: FAIL ptr0=%u ptr1=%u (expected 15,0; BUG_006 often gives ptr1=1)\n",
            name, p0, p1);
        return 1;
    }
    if (top->vl_storeQueueCount != 15u) {
        fprintf(stderr, "%s: FAIL count after wrap alloc=%u (expected 15)\n",
            name, top->vl_storeQueueCount);
        return 1;
    }

    printf("%s: PASS (ptr0=%u ptr1=%u count=%u)\n",
        name, p0, p1, top->vl_storeQueueCount);
    return 0;
}

// Functional / black-box style: compare hardware alloc indices to ref-FIFO "new entry"
// indices (spec model), plus ring vs allocate-mark consistency after stress.
static int test_wrap_stress_slot_invariant(VTestStoreQueueWrapTop* top, int half_ns)
{
    static const char* name = "wrap_stress_slot_invariant";
    static const int kStressIters = 32;

    FifoModel model;
    bool hw_marked[kSqSize];
    bool in_ring[kSqSize];

    reset_dut(top, half_ns, 4);
    model.reset();
    memset(hw_marked, 0, sizeof(hw_marked));

    if (sync_fifo_metadata(top, model, name) != 0) {
        return 1;
    }

    for (int iter = 0; iter < kStressIters; iter++) {
        char where[64];
        snprintf(where, sizeof(where), "%s iter=%d fill", name, iter);

        while (model.allocatable()) {
            const uint32_t mask = 0x3u;
            uint32_t exp_slots[2];
            const uint32_t nexp = model.expected_new_slots(mask, exp_slots);

            uint32_t cap0 = 0, cap1 = 0;
            alloc_posedge(top, half_ns, mask, &cap0, &cap1);

            uint32_t got_slots[2];
            const uint32_t ngot = dut_captured_slots(mask, cap0, cap1, got_slots);

            if (!slot_sets_equal(exp_slots, nexp, got_slots, ngot)) {
                char exp_buf[64];
                char got_buf[64];
                slots_to_string(exp_slots, nexp, exp_buf, sizeof(exp_buf));
                slots_to_string(got_slots, ngot, got_buf, sizeof(got_buf));
                fprintf(stderr,
                    "%s: FAIL allocate indices mismatch at iter=%d fill: "
                    "ref-FIFO new entries {%s} vs hardware {%s} "
                    "(count=%u head=%u)\n",
                    name, iter, exp_buf, got_buf, model.count, model.head);
                return 1;
            }

            for (uint32_t s = 0; s < ngot; s++) {
                hw_marked[got_slots[s]] = true;
            }

            model.apply_allocate(mask);

            snprintf(where, sizeof(where), "%s iter=%d after-alloc", name, iter);
            if (sync_fifo_metadata(top, model, where) != 0) {
                return 1;
            }
        }

        snprintf(where, sizeof(where), "%s iter=%d release", name, iter);
        const uint32_t release_num = (model.count >= 2u) ? 2u : model.count;
        if (release_num > 0u) {
            release_head(top, half_ns, release_num);
            model.release(release_num);
            if (sync_fifo_metadata(top, model, where) != 0) {
                return 1;
            }
        }

        model.ring_occupancy(in_ring);
        for (uint32_t i = 0; i < kSqSize; i++) {
            if (!in_ring[i]) {
                hw_marked[i] = false;
            }
        }

        if (model.allocatable()) {
            const uint32_t mask = 0x1u;
            uint32_t exp_slots[2];
            const uint32_t nexp = model.expected_new_slots(mask, exp_slots);

            uint32_t cap0 = 0, cap1 = 0;
            alloc_posedge(top, half_ns, mask, &cap0, &cap1);

            uint32_t got_slots[2];
            const uint32_t ngot = dut_captured_slots(mask, cap0, cap1, got_slots);

            if (!slot_sets_equal(exp_slots, nexp, got_slots, ngot)) {
                char exp_buf[64];
                char got_buf[64];
                slots_to_string(exp_slots, nexp, exp_buf, sizeof(exp_buf));
                slots_to_string(got_slots, ngot, got_buf, sizeof(got_buf));
                fprintf(stderr,
                    "%s: FAIL allocate indices mismatch at iter=%d tail-push: "
                    "ref-FIFO new entries {%s} vs hardware {%s}\n",
                    name, iter, exp_buf, got_buf);
                return 1;
            }

            for (uint32_t s = 0; s < ngot; s++) {
                hw_marked[got_slots[s]] = true;
            }

            model.apply_allocate(mask);
            snprintf(where, sizeof(where), "%s iter=%d after-tail-push", name, iter);
            if (sync_fifo_metadata(top, model, where) != 0) {
                return 1;
            }
        }

        model.ring_occupancy(in_ring);
        uint32_t phantom = 0;
        uint32_t missing = 0;
        for (uint32_t i = 0; i < kSqSize; i++) {
            if (in_ring[i] && !hw_marked[i]) {
                missing++;
            }
            if (!in_ring[i] && hw_marked[i]) {
                phantom++;
            }
        }
        if (phantom > 0u || missing > 0u) {
            fprintf(stderr,
                "%s: FAIL ring/mark inconsistency at iter=%d: "
                "%u in-ring slot(s) never got allocate, %u phantom allocate(s) "
                "(count=%u head=%u)\n",
                name, iter, missing, phantom, model.count, model.head);
            return 1;
        }
    }

    printf("%s: PASS (%d stress iterations, FIFO/allocate consistency)\n",
        name, kStressIters);
    return 0;
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);
    auto* top = new VTestStoreQueueWrapTop;

    const int HALF_NS = 5;
    top->clk = 0;
    drive_idle(top);
    eval(top);

    printf("=== BUG_006 store-queue wrap unit test (Verilator) ===\n");

    int fail = 0;
    fail += test_dual_alloc_no_wrap(top, HALF_NS);
    fail += test_wrap_second_lane(top, HALF_NS);
    fail += test_wrap_stress_slot_invariant(top, HALF_NS);

    printf("=== Summary: %s ===\n", fail ? "FAILED" : "PASSED");
    delete top;
    return fail ? 1 : 0;
}
