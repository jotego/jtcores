`timescale 1ns/1ps

module test;

reg clk=0;
always #10 clk = ~clk;

reg [1:0] div=0;
reg [5:0] x=0;
reg [7:0] line=0;
wire ce = div==0;
wire hs = x>=48 && x<56;
wire vs = (line==20 && x>=16) || (line==21 && x<16) ||
          (line==100 && x>=48) || (line==101 && x<48) ||
          (line==181 && x>=16) || (line==182 && x<16);
wire [7:0] r,g,b;
wire out_hs, out_vs, out_de, out_ce;
wire osd_hs, osd_vs, osd_de, retime_hs, retime_vs, retime_de;
wire final_hs, final_vs, final_de, final_cs;
wire [23:0] osd_rgb, retime_rgb, final_rgb;
tri [21:0] gamma_bus;
reg prev_vs=0, prev_out_vs=0, prev_prog_vs=0, prev_final_vs=0;
integer seen=0, seen_out=0, seen_prog=0, seen_final=0, errors=0;
integer pixel_count=0, last_src_edge=0, last_final_edge=0;

always @(posedge clk) begin
    div <= div + 2'd1;
    if( ce ) begin
        pixel_count=pixel_count+1;
        x <= x + 6'd1;
        if( x==63 ) line <= line + 8'd1;
    end
    prev_vs <= uut.VS;
    prev_out_vs <= out_vs;
    prev_prog_vs <= uut_prog.VS;
    prev_final_vs <= final_vs;
    if( uut.VS && !prev_vs ) begin
        if( seen>=1 && pixel_count-last_src_edge!=5152 ) begin
            $display("source field length changed: %0d", pixel_count-last_src_edge);
            errors=errors+1;
        end
        last_src_edge=pixel_count;
        case( seen )
            0,2: if( x<14 || x>22 ) begin
                $display("internal VSync lost half-line phase: x=%0d event=%0d",x,seen);
                errors = errors+1;
            end
            1: if( x<46 || x>54 ) begin
                $display("internal VSync shifted from HSync: x=%0d",x);
                errors = errors+1;
            end
        endcase
        seen = seen+1;
    end
    if( out_vs && !prev_out_vs ) begin
        case( seen_out )
            0,2: if( x<14 || x>27 ) begin
                $display("output VSync lost half-line phase: x=%0d event=%0d",x,seen_out);
                errors = errors+1;
            end
            1: if( x<46 || x>59 ) begin
                $display("output VSync shifted from HSync: x=%0d",x);
                errors = errors+1;
            end
        endcase
        seen_out = seen_out+1;
    end
    if( uut_prog.VS && !prev_prog_vs ) begin
        if( x<46 || x>54 ) begin
            $display("progressive VSync no longer aligned to HSync: x=%0d",x);
            errors = errors+1;
        end
        seen_prog = seen_prog+1;
    end
    if( final_vs && !prev_final_vs ) begin
        if( seen_final>=1 && pixel_count-last_final_edge!=5152 ) begin
            $display("final VGA field length changed: %0d", pixel_count-last_final_edge);
            errors=errors+1;
        end
        last_final_edge=pixel_count;
        case( seen_final )
            0,2: if( x<14 || x>29 ) begin
                $display("final VGA VSync lost half-line phase: x=%0d event=%0d",x,seen_final);
                errors=errors+1;
            end
            1: if( x<46 || x>61 ) begin
                $display("final VGA VSync shifted from HSync: x=%0d",x);
                errors=errors+1;
            end
        endcase
        seen_final=seen_final+1;
    end
end

arcade_video #(.WIDTH(32),.DW(9),.GAMMA(1),.INTERLACED(1)) uut(
    .clk_video(clk), .ce_pix(ce),
    .RGB_in(9'h1ff), .HBlank(x>=32), .VBlank(1'b0),
    .HSync(hs), .VSync(vs),
    .CLK_VIDEO(), .CE_PIXEL(out_ce),
    .VGA_R(r), .VGA_G(g), .VGA_B(b),
    .VGA_HS(out_hs), .VGA_VS(out_vs), .VGA_DE(out_de), .VGA_SL(),
    .fx(3'd0), .forced_scandoubler(1'b0), .gamma_bus(gamma_bus)
);

arcade_video #(.WIDTH(32),.DW(9),.GAMMA(1)) uut_prog(
    .clk_video(clk), .ce_pix(ce),
    .RGB_in(9'h1ff), .HBlank(x>=32), .VBlank(1'b0),
    .HSync(hs), .VSync(vs),
    .CLK_VIDEO(), .CE_PIXEL(),
    .VGA_R(), .VGA_G(), .VGA_B(),
    .VGA_HS(), .VGA_VS(), .VGA_DE(), .VGA_SL(),
    .fx(3'd0), .forced_scandoubler(1'b0), .gamma_bus()
);

osd #(.NATIVE_PIXEL(1)) uut_osd(
    .clk_sys(clk), .io_osd(1'b0), .io_strobe(1'b0), .io_din(16'd0),
    .clk_video(clk), .ce_in(out_ce), .din({r,g,b}),
    .hs_in(out_hs), .vs_in(out_vs), .de_in(out_de),
    .dout(osd_rgb), .hs_out(osd_hs), .vs_out(osd_vs), .de_out(osd_de),
    .osd_status()
);

jtframe_hretime #(.DIV(4)) uut_hretime(
    .clk(clk), .ce_in(out_ce), .enable(1'b0), .div_alt(1'b0), .scale(4'd0),
    .din(osd_rgb), .hs_in(osd_hs), .vs_in(osd_vs), .de_in(osd_de),
    .ce_out(), .dout(retime_rgb), .hs_out(retime_hs),
    .vs_out(retime_vs), .de_out(retime_de)
);

vga_out uut_vga_out(
    .clk(clk), .ypbpr_en(1'b0), .hsync(retime_hs), .vsync(retime_vs),
    .csync(1'b0), .de(retime_de), .din(retime_rgb),
    .dout(final_rgb), .hsync_o(final_hs), .vsync_o(final_vs),
    .csync_o(final_cs), .de_o(final_de)
);

initial begin
    wait(line==190);
    repeat(20) @(posedge clk);
    if( seen!=3 || seen_out!=3 || seen_prog!=3 || seen_final!=3 ) begin
        $display("VSync edge count: internal=%0d output=%0d progressive=%0d final=%0d", seen, seen_out, seen_prog, seen_final);
        errors=errors+1;
    end
    if( errors==0 ) $display("PASS: both half-line VSync phases preserved");
    else $display("FAIL: %0d interlace timing errors",errors);
    $finish;
end

endmodule
