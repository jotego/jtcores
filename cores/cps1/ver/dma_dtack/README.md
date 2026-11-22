# CPS1 DTACK recovery during DMA

Run with `simunit.sh --run cores/cps1/ver/dma_dtack`. A delayed memory
response creates CPU recovery debt. A DMA request then receives the bus while
debt remains, and the test checks that the debt does not drain during DMA
ownership. The CPU and arbitration use the CPS1 RTL; memory responses are
modeled by the test.
