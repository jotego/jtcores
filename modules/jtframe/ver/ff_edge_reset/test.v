/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2026-11-09 */

`timescale 1ns/1ps

module test;

reg clk=0;
always #5 clk=~clk;

reg rst=1, cen=1;
reg [31:0] din=0, set_bits=0, clr_bits=0, edges=0;
wire q_def1, qn_def1, q_edge1, qn_edge1;
wire [7:0] q_def8, qn_def8, q_edge8, qn_edge8;
wire [31:0] q_def32, qn_def32, q_edge32, qn_edge32;

reg [31:0] model_q_def1=0, model_qn_def1=0, model_edge_def1=0;
reg [31:0] model_q_edge1=0, model_qn_edge1=0, model_edge_edge1=0;
reg [31:0] model_q_def8=0, model_qn_def8=0, model_edge_def8=0;
reg [31:0] model_q_edge8=0, model_qn_edge8=0, model_edge_edge8=0;
reg [31:0] model_q_def32=0, model_qn_def32=0, model_edge_def32=0;
reg [31:0] model_q_edge32=0, model_qn_edge32=0, model_edge_edge32=0;

jtframe_ff #(.W(1)) uut_def1(
    .clk(clk), .rst(rst), .cen(cen), .din(din[0]), .q(q_def1), .qn(qn_def1),
    .set(set_bits[0]), .clr(clr_bits[0]), .sigedge(edges[0])
);
jtframe_ff #(.W(1), .EDGE_RESET(1'b1)) uut_edge1(
    .clk(clk), .rst(rst), .cen(cen), .din(din[0]), .q(q_edge1), .qn(qn_edge1),
    .set(set_bits[0]), .clr(clr_bits[0]), .sigedge(edges[0])
);
jtframe_ff #(.W(8)) uut_def8(
    .clk(clk), .rst(rst), .cen(cen), .din(din[7:0]), .q(q_def8), .qn(qn_def8),
    .set(set_bits[7:0]), .clr(clr_bits[7:0]), .sigedge(edges[7:0])
);
jtframe_ff #(.W(8), .EDGE_RESET(1'b1)) uut_edge8(
    .clk(clk), .rst(rst), .cen(cen), .din(din[7:0]), .q(q_edge8), .qn(qn_edge8),
    .set(set_bits[7:0]), .clr(clr_bits[7:0]), .sigedge(edges[7:0])
);
jtframe_ff #(.W(32)) uut_def32(
    .clk(clk), .rst(rst), .cen(cen), .din(din), .q(q_def32), .qn(qn_def32),
    .set(set_bits), .clr(clr_bits), .sigedge(edges)
);
jtframe_ff #(.W(32), .EDGE_RESET(1'b1)) uut_edge32(
    .clk(clk), .rst(rst), .cen(cen), .din(din), .q(q_edge32), .qn(qn_edge32),
    .set(set_bits), .clr(clr_bits), .sigedge(edges)
);

task model_step;
    input integer width;
    input integer reset_edge;
    input reset_in, cen_in;
    input [31:0] data_in, set_in, clear_in, edge_in;
    inout [31:0] q_model, qn_model, history_model;
    reg [31:0] mask, old_history;
    integer b;
    begin
        mask = width == 32 ? 32'hffff_ffff : ((32'h1 << width) - 1);
        if(reset_in) begin
            q_model = 0;
            qn_model = mask;
            history_model = reset_edge ? mask : 0;
        end else begin
            old_history = history_model;
            history_model = edge_in & mask;
            for(b=0; b<width; b=b+1) begin
                if(cen_in && clear_in[b]) begin
                    q_model[b] = 1'b0;
                    qn_model[b] = 1'b1;
                end else if(cen_in && set_in[b]) begin
                    q_model[b] = 1'b1;
                    qn_model[b] = 1'b0;
                end else if(edge_in[b] && !old_history[b]) begin
                    q_model[b] = data_in[b];
                    qn_model[b] = ~data_in[b];
                end
            end
        end
    end
endtask

always @(posedge clk) begin
    model_step(1,0,rst,cen,din,set_bits,clr_bits,edges,model_q_def1,model_qn_def1,model_edge_def1);
    model_step(1,1,rst,cen,din,set_bits,clr_bits,edges,model_q_edge1,model_qn_edge1,model_edge_edge1);
    model_step(8,0,rst,cen,din,set_bits,clr_bits,edges,model_q_def8,model_qn_def8,model_edge_def8);
    model_step(8,1,rst,cen,din,set_bits,clr_bits,edges,model_q_edge8,model_qn_edge8,model_edge_edge8);
    model_step(32,0,rst,cen,din,set_bits,clr_bits,edges,model_q_def32,model_qn_def32,model_edge_def32);
    model_step(32,1,rst,cen,din,set_bits,clr_bits,edges,model_q_edge32,model_qn_edge32,model_edge_edge32);
end

reg eq_rst=1, eq_trigger=1;
reg [31:0] eq_data=0;
wire [7:0] eq_edge8;
wire [31:0] eq_edge32;
assign eq_edge8 = {8{eq_trigger}};
assign eq_edge32 = {32{eq_trigger}};
wire eq_q_old1, eq_qn_old1, eq_q_new1, eq_qn_new1;
wire [7:0] eq_q_old8, eq_qn_old8, eq_q_new8, eq_qn_new8;
wire [31:0] eq_q_old32, eq_qn_old32, eq_q_new32, eq_qn_new32;
legacy_bus_ff #(.W(1)) legacy_reset1(eq_rst,clk,eq_trigger,eq_data[0],eq_q_old1,eq_qn_old1);
legacy_bus_ff #(.W(8)) legacy_reset8(eq_rst,clk,eq_trigger,eq_data[7:0],eq_q_old8,eq_qn_old8);
legacy_bus_ff #(.W(32)) legacy_reset32(eq_rst,clk,eq_trigger,eq_data,eq_q_old32,eq_qn_old32);
jtframe_ff #(.W(1),.EDGE_RESET(1'b1)) replacement_reset1(
    .clk(clk),.rst(eq_rst),.cen(1'b1),.din(eq_data[0]),.q(eq_q_new1),.qn(eq_qn_new1),
    .set(1'b0),.clr(1'b0),.sigedge(eq_trigger)
);
jtframe_ff #(.W(8),.EDGE_RESET(1'b1)) replacement_reset8(
    .clk(clk),.rst(eq_rst),.cen(1'b1),.din(eq_data[7:0]),.q(eq_q_new8),.qn(eq_qn_new8),
    .set(8'd0),.clr(8'd0),.sigedge(eq_edge8)
);
jtframe_ff #(.W(32),.EDGE_RESET(1'b1)) replacement_reset32(
    .clk(clk),.rst(eq_rst),.cen(1'b1),.din(eq_data),.q(eq_q_new32),.qn(eq_qn_new32),
    .set(32'd0),.clr(32'd0),.sigedge(eq_edge32)
);

reg [31:0] free_data=0;
reg free_trigger=0, free_defined=0;
wire free_q_old1, free_qn_old1, free_q_new1, free_qn_new1;
wire [7:0] free_edge8;
wire [31:0] free_edge32;
assign free_edge8 = {8{free_trigger}};
assign free_edge32 = {32{free_trigger}};
wire [7:0] free_q_old8, free_qn_old8, free_q_new8, free_qn_new8;
wire [31:0] free_q_old32, free_qn_old32, free_q_new32, free_qn_new32;
legacy_bus_ff #(.W(1)) legacy_free1(1'b0,clk,free_trigger,free_data[0],free_q_old1,free_qn_old1);
legacy_bus_ff #(.W(8)) legacy_free8(1'b0,clk,free_trigger,free_data[7:0],free_q_old8,free_qn_old8);
legacy_bus_ff #(.W(32)) legacy_free32(1'b0,clk,free_trigger,free_data,free_q_old32,free_qn_old32);
jtframe_ff #(.W(1),.EDGE_RESET(1'b1)) replacement_free1(
    .clk(clk),.rst(1'b0),.cen(1'b1),.din(free_data[0]),.q(free_q_new1),.qn(free_qn_new1),
    .set(1'b0),.clr(1'b0),.sigedge(free_trigger)
);
jtframe_ff #(.W(8),.EDGE_RESET(1'b1)) replacement_free8(
    .clk(clk),.rst(1'b0),.cen(1'b1),.din(free_data[7:0]),.q(free_q_new8),.qn(free_qn_new8),
    .set(8'd0),.clr(8'd0),.sigedge(free_edge8)
);
jtframe_ff #(.W(32),.EDGE_RESET(1'b1)) replacement_free32(
    .clk(clk),.rst(1'b0),.cen(1'b1),.din(free_data),.q(free_q_new32),.qn(free_qn_new32),
    .set(32'd0),.clr(32'd0),.sigedge(free_edge32)
);

reg eq_valid=0;
integer cycles=0;
integer i;
reg [31:0] prng=32'h5a17_c3e9;
reg [31:0] prng_set=32'h319a_5e27;
reg [31:0] prng_clear=32'hcafe_8123;

task check_model;
    begin
        if(q_def1 !== model_q_def1[0] || qn_def1 !== model_qn_def1[0] ||
           q_edge1 !== model_q_edge1[0] || qn_edge1 !== model_qn_edge1[0]) begin
            $display("FAIL: width-1 model mismatch cycle=%0d",cycles); $fatal(1);
        end
        if(q_def8 !== model_q_def8[7:0] || qn_def8 !== model_qn_def8[7:0] ||
           q_edge8 !== model_q_edge8[7:0] || qn_edge8 !== model_qn_edge8[7:0]) begin
            $display("FAIL: width-8 model mismatch cycle=%0d",cycles); $fatal(1);
        end
        if(q_def32 !== model_q_def32 || qn_def32 !== model_qn_def32 ||
           q_edge32 !== model_q_edge32 || qn_edge32 !== model_qn_edge32) begin
            $display("FAIL: width-32 model mismatch cycle=%0d",cycles); $fatal(1);
        end
    end
endtask

task check_equivalence;
    begin
        if(eq_q_old1 !== eq_q_new1 || eq_qn_old1 !== eq_qn_new1 ||
           eq_q_old8 !== eq_q_new8 || eq_qn_old8 !== eq_qn_new8 ||
           eq_q_old32 !== eq_q_new32 || eq_qn_old32 !== eq_qn_new32) begin
            $display("FAIL: old/new resettable helper mismatch cycle=%0d",cycles); $fatal(1);
        end
    end
endtask

task check_free_equivalence;
    begin
        if(free_q_old1 !== free_q_new1 || free_qn_old1 !== free_qn_new1 ||
           free_q_old8 !== free_q_new8 || free_qn_old8 !== free_qn_new8 ||
           free_q_old32 !== free_q_new32 || free_qn_old32 !== free_qn_new32) begin
            $display("FAIL: old/new reset-free helper mismatch cycle=%0d",cycles); $fatal(1);
        end
    end
endtask

task step;
    begin
        @(posedge clk);
        #1;
        cycles=cycles+1;
        check_model;
        if(eq_valid) check_equivalence;
        if(free_defined) check_free_equivalence;
        if(eq_rst) eq_valid=1;
    end
endtask

initial begin
    rst=1; cen=1; din=32'h8123_4567; edges=32'hffff_ffff; set_bits=0; clr_bits=0;
    eq_rst=1; eq_trigger=1; eq_data=32'hfedc_ba98;
    free_trigger=0; free_data=32'h1234_5678;

    // Repeated reset with held-high triggers exercises the EDGE_RESET=1 behavior.
    step;
    step;
    rst=0; eq_rst=0; din=32'hffff_ffff; eq_data=32'hffff_ffff; step;
    if(q_def1 !== 1'b1 || q_edge1 !== 1'b0 || q_def8 !== 8'hff || q_edge8 !== 8'h00 ||
       q_def32 !== 32'hffff_ffff || q_edge32 !== 32'h0000_0000) begin
        $display("FAIL: expected default-reset negative control to capture held-high edge"); $fatal(1);
    end

    // Return low, then rise to capture identically in both history modes.
    edges=0; eq_trigger=0; din=32'h1357_9bdf; eq_data=32'h2468_ace0; step;
    edges=32'hffff_ffff; eq_trigger=1; din=32'h0f0f_a5a5; eq_data=32'h55aa_33cc; step;
    din=32'hdead_beef; eq_data=32'hcafe_babe; step; // data changes without an edge

    // Hold the trigger low throughout reset and release, then capture on its rise.
    rst=1; eq_rst=1; edges=0; eq_trigger=0; step;
    rst=0; din=32'h8765_4321; eq_data=32'h0123_4567; step;
    edges=32'hffff_ffff; eq_trigger=1; din=32'h55aa_0ff0; eq_data=32'hf00f_aa55; step;

    // Reset-free legacy and replacement instances become comparable after a low sample then a rising capture.
    free_trigger=0; free_data=32'h1020_3040; step;
    free_trigger=1; free_data=32'h89ab_cdef; step;
    free_defined=1;
    check_free_equivalence;

    // Set wins over an edge carrying zero, including the width-1 bit.
    edges=0; eq_trigger=0; set_bits=0; clr_bits=0; cen=1; step;
    edges=32'h0000_0001; eq_trigger=1; din=0; eq_data=0;
    set_bits=32'h0000_0001; clr_bits=0; step;

    // Clear wins when clear, set, and a data-one rising edge coincide.
    edges=0; eq_trigger=0; set_bits=0; clr_bits=0; step;
    edges=32'h0000_0001; eq_trigger=1; din=32'h0000_0001; eq_data=32'h0000_0001;
    set_bits=32'h0000_0001; clr_bits=32'h0000_0001; step;

    // Exercise the wider register bits: bit 3 clears over data one; bits 1/2 set over data zero.
    edges=0; eq_trigger=0; set_bits=0; clr_bits=0; step;
    edges=32'h0000_000f; eq_trigger=1; din=32'h0000_0008; eq_data=32'hffff_ffff;
    set_bits=32'h0000_0007; clr_bits=32'h0000_0008; step;

    // Clear/set are inactive at cen=0, but rising edges still capture.
    set_bits=0; clr_bits=0; edges=0; eq_trigger=0; cen=0; step;
    set_bits=32'hffff_ffff; clr_bits=32'hffff_ffff;
    edges=32'h5555_5555; eq_trigger=1; din=32'h5aa5_c33c; eq_data=32'h5aa5_c33c; step;
    set_bits=0; clr_bits=0; edges=32'hffff_ffff; eq_trigger=1;
    din=32'h1357_9bdf; eq_data=32'heca8_6420; cen=1; step;

    // Deterministic varied data/edge/reset/set/clear sequence checks every bus bit.
    for(i=0;i<96;i=i+1) begin
        prng={prng[30:0],prng[31]^prng[21]^prng[1]^prng[0]};
        prng_set={prng_set[30:0],prng_set[31]^prng_set[21]^prng_set[1]^prng_set[0]};
        prng_clear={prng_clear[30:0],prng_clear[31]^prng_clear[21]^prng_clear[1]^prng_clear[0]};
        din=prng; eq_data=~prng; free_data=prng ^ 32'h55aa_00ff;
        edges=prng ^ {prng[14:0],prng[31:15]}; eq_trigger=prng[0]; free_trigger=prng[3];
        set_bits=prng_set; clr_bits=prng_clear;
        cen=prng[5]; rst=(i==31 || i==32 || i==77); eq_rst=rst;
        step;
    end

    $display("PASS: jtframe_ff widths 1/8/32; edge reset, priority, CEN, legacy equivalence");
    $finish;
end

endmodule

// Behavioral reference copied from the pre-migration Nemesis helper snapshot.
module legacy_bus_ff #(parameter W=1) (
    input rst,
    input clk,
    input trig,
    input [W-1:0] d,
    output [W-1:0] q,
    output [W-1:0] q_n
);
reg trig_prev;
reg [W-1:0] state;
assign q=state;
assign q_n=~state;
always @(posedge clk) begin
    if(rst) begin
        state <= {W{1'b0}};
        trig_prev <= 1'b1;
    end else begin
        if(trig & ~trig_prev) state <= d;
        trig_prev <= trig;
    end
end
endmodule
