module test;

reg [7:0] aux;
integer cnt;
/*
function [7:0] hwchamp_handle( input [7:0] anain );
    hwchamp_handle = anain[7] ? { 3'd0, anain[6:2]} :
        {1'b0, anain[6:0]} + {2'b0,anain[6:1]} + {3'b0,anain[6:2]} + 8'h20;
endfunction
*/

function [7:0] hwchamp_handle( input [7:0] anain );
    hwchamp_handle = !anain[7] ? 8'h20-{ 3'd0, anain[6:2]} :
        ~({1'b0, anain[6:0]} + {2'b0,anain[6:1]} + {3'b0,anain[6:2]});
endfunction

initial begin
    for( cnt=0; cnt<127;cnt=cnt+1) begin
        $display("%X -> %X", cnt[7:0], hwchamp_handle(cnt[7:0]));
    end
    $display("Negative --- ");
    for( cnt=255; cnt>127;cnt=cnt-1) begin
        $display("%X -> %X", cnt[7:0], hwchamp_handle(cnt[7:0]));
    end
    $finish;
end

endmodule : test