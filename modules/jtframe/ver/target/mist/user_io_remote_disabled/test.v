`timescale 1ns/1ps

module test;
wire done_zero, done_other;
remote_disabled_case #(.FEATURES(32'd0)) zero(
    .done(done_zero)
);
remote_disabled_case #(.FEATURES(32'h00004004)) other(
    .done(done_other)
);

initial begin
    wait(done_zero && done_other);
    $display("PASS remote_disabled");
    $finish;
end
endmodule
