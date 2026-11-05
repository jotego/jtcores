`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer SETS = 3;
localparam integer WAYS = 4;
localparam integer BW   = 4;
localparam integer WAYW = 2;
localparam integer SETW = 2;
localparam integer TAGW = 8;

reg             rst = 1'b1;
reg             clk = 1'b0;
reg  [SETW-1:0] rd_set = {SETW{1'b0}};
reg  [SETW-1:0] lookup_set = {SETW{1'b0}};
reg  [TAGW-1:0] lookup_tag = {TAGW{1'b0}};
reg             clear_en = 1'b0;
reg  [SETW-1:0] clear_set = {SETW{1'b0}};
reg             update_en = 1'b0;
reg  [SETW-1:0] update_set = {SETW{1'b0}};
reg  [WAYW-1:0] update_way = {WAYW{1'b0}};
reg             update_valid = 1'b0;
reg             update_dirty = 1'b0;
reg  [TAGW-1:0] update_tag = {TAGW{1'b0}};
reg             advance_en = 1'b0;
reg  [SETW-1:0] advance_set = {SETW{1'b0}};
reg  [WAYW-1:0] advance_way = {WAYW{1'b0}};
reg  [WAYW-1:0] scan_way = {WAYW{1'b0}};
wire            hit;
wire [WAYW-1:0] hit_way;
wire [BW-1:0]   hit_blk;
wire [WAYW-1:0] victim_way;
wire [BW-1:0]   victim_blk;
wire            victim_invalid;
wire            victim_dirty;
wire [TAGW-1:0] victim_tag;
wire            scan_valid;
wire            scan_dirty;
wire [TAGW-1:0] scan_tag;
wire [BW-1:0]   scan_blk;

integer set_idx, way_idx;

always #5 clk = ~clk;

jtframe_cache_tags #(
    .BLOCKS ( SETS * WAYS ),
    .WAYS   ( WAYS        ),
    .SETS   ( SETS        ),
    .BW     ( BW          ),
    .WAYW   ( WAYW        ),
    .SETW   ( SETW        ),
    .TAGW   ( TAGW        )
) uut (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .rd_set         ( rd_set         ),
    .lookup_set     ( lookup_set     ),
    .lookup_tag     ( lookup_tag     ),
    .clear_en       ( clear_en       ),
    .clear_set      ( clear_set      ),
    .update_en      ( update_en      ),
    .update_set     ( update_set     ),
    .update_way     ( update_way     ),
    .update_valid   ( update_valid   ),
    .update_dirty   ( update_dirty   ),
    .update_tag     ( update_tag     ),
    .advance_en     ( advance_en     ),
    .advance_set    ( advance_set    ),
    .advance_way    ( advance_way    ),
    .scan_way       ( scan_way       ),
    .hit            ( hit            ),
    .hit_way        ( hit_way        ),
    .hit_blk        ( hit_blk        ),
    .victim_way     ( victim_way     ),
    .victim_blk     ( victim_blk     ),
    .victim_invalid ( victim_invalid ),
    .victim_dirty   ( victim_dirty   ),
    .victim_tag     ( victim_tag     ),
    .scan_valid     ( scan_valid     ),
    .scan_dirty     ( scan_dirty     ),
    .scan_tag       ( scan_tag       ),
    .scan_blk       ( scan_blk       )
);

function automatic [TAGW-1:0] tag_for(input integer set, input integer way);
    tag_for = TAGW'(8'h40 + set * WAYS + way);
endfunction

function automatic [BW-1:0] blk_for(input integer set, input integer way);
    blk_for = BW'(way * SETS + set);
endfunction

task automatic write_tag(input integer set, input integer way);
    begin
        @(negedge clk);
        update_set   = SETW'(set);
        update_way   = WAYW'(way);
        update_tag   = tag_for(set, way);
        update_valid = 1'b1;
        update_dirty = way[0];
        update_en    = 1'b1;
        @(negedge clk);
        update_en    = 1'b0;
        update_valid = 1'b0;
        update_dirty = 1'b0;
    end
endtask

task automatic read_set(input integer set);
    begin
        @(negedge clk);
        rd_set     = SETW'(set);
        lookup_set = SETW'(set);
        @(posedge clk);
        #1;
    end
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;

    repeat(2) @(negedge clk);
    rst = 1'b0;

    for( set_idx=0; set_idx<SETS; set_idx=set_idx+1 ) begin
        for( way_idx=0; way_idx<WAYS; way_idx=way_idx+1 ) begin
            write_tag(set_idx, way_idx);
        end
    end

    for( set_idx=0; set_idx<SETS; set_idx=set_idx+1 ) begin
        read_set(set_idx);
        for( way_idx=0; way_idx<WAYS; way_idx=way_idx+1 ) begin
            lookup_tag = tag_for(set_idx, way_idx);
            scan_way   = WAYW'(way_idx);
            #1;
            assert_msg(hit, "expected tag hit");
            assert_msg(hit_way == WAYW'(way_idx), "wrong hit way");
            assert_msg(hit_blk == blk_for(set_idx, way_idx), "wrong hit block index");
            assert_msg(scan_valid, "expected valid scan entry");
            assert_msg(scan_tag == tag_for(set_idx, way_idx), "wrong scan tag");
            assert_msg(scan_blk == blk_for(set_idx, way_idx), "wrong scan block index");
        end
        assert_msg(victim_blk == blk_for(set_idx, 0), "wrong victim block index");
    end

    pass();
end

endmodule
