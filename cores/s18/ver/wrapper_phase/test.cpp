#include "Vtest.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    Vtest top{&context};
    while (!context.gotFinish() && !context.gotError()) {
        top.eval();
        if (!top.eventsPending()) break;
        context.time(top.nextTimeSlot());
    }
    top.final();
    return context.gotFinish() && !context.gotError() ? 0 : 1;
}
