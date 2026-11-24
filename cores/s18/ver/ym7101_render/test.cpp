#include <memory>
#include <cstdio>
#include <string>

#include "Vtest.h"
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    // Keep Verilog $display acquisition milestones visible while long runs
    // are still in progress, including when the runner redirects its output.
    std::setvbuf(stdout, nullptr, _IOLBF, 0);
    std::setvbuf(stderr, nullptr, _IOLBF, 0);

    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);

    bool keep_trace = false;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--keep") keep_trace = true;
    }

    Vtest top(context.get());
    std::unique_ptr<VerilatedFstC> trace;
    if (keep_trace) {
        context->traceEverOn(true);
        trace = std::make_unique<VerilatedFstC>();
        top.trace(trace.get(), 99);
        trace->open("test.fst");
    }

    while (!context->gotFinish() && !context->gotError()) {
        top.eval();
        if (trace) trace->dump(context->time());
        if (!top.eventsPending()) break;
        context->time(top.nextTimeSlot());
    }

    top.final();
    if (trace) trace->close();
    return context->gotFinish() && !context->gotError() ? 0 : 1;
}
