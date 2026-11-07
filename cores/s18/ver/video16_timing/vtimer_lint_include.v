// simunit's Verilator lint pass does not append the common timer source,
// whereas its Icarus run does. Include the production implementation only
// for lint to avoid duplicate module declarations during simulation.
`ifdef VERILATOR
`include "../../../../modules/jtframe/hdl/video/jtframe_vtimer.v"
`endif
