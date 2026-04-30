module jtargus_8x8x4_packed_msb(
    input  [31:0] raw,
    output [31:0] sorted
);

assign sorted = {
    raw[ 7],raw[ 3],raw[15],raw[11],raw[23],raw[19],raw[31],raw[27],
    raw[ 6],raw[ 2],raw[14],raw[10],raw[22],raw[18],raw[30],raw[26],
    raw[ 5],raw[ 1],raw[13],raw[ 9],raw[21],raw[17],raw[29],raw[25],
    raw[ 4],raw[ 0],raw[12],raw[ 8],raw[20],raw[16],raw[28],raw[24]
};

endmodule

module jtargus_obj_8x8x4_packed_msb(
    input  [31:0] raw,
    output [31:0] sorted
);

assign sorted = {
    raw[27],raw[31],raw[19],raw[23],raw[11],raw[15],raw[ 3],raw[ 7],
    raw[26],raw[30],raw[18],raw[22],raw[10],raw[14],raw[ 2],raw[ 6],
    raw[25],raw[29],raw[17],raw[21],raw[ 9],raw[13],raw[ 1],raw[ 5],
    raw[24],raw[28],raw[16],raw[20],raw[ 8],raw[12],raw[ 0],raw[ 4]
};

endmodule
