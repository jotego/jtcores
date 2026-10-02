localparam [15:0] XORM0 = 16'hd556;
localparam [15:0] XORM1 = 16'h73cb;
localparam [15:0] XORM2 = 16'h2963;
localparam [15:0] XORM3 = 16'h4b9a;
localparam [15:0] XORM4 = 16'hb3bc;
localparam [15:0] XORM5 = 16'hbc73;
localparam [15:0] XORM6 = 16'hcbc9;
localparam [15:0] XORM7 = 16'haeb5;
localparam [15:0] XORM8 = 16'h1e6d;
localparam [15:0] XORM9 = 16'hd5b5;
localparam [15:0] XORM10 = 16'he676;
localparam [15:0] XORM11 = 16'h5cc5;
localparam [15:0] XORM12 = 16'h395a;
localparam [15:0] XORM13 = 16'hdaae;
localparam [15:0] XORM14 = 16'h2629;
localparam [15:0] XORM15 = 16'he59e;
`define SWAP0(v) {v[15],v[8],v[9],v[12],v[10],v[13],v[11],v[14],v[2],v[7],v[4],v[3],v[1],v[5],v[6],v[0]}
`define SWAP1(v) {v[12],v[10],v[11],v[9],v[8],v[15],v[14],v[13],v[6],v[0],v[3],v[5],v[7],v[4],v[2],v[1]}
`define SWAP2(v) {v[8],v[12],v[11],v[9],v[13],v[14],v[15],v[10],v[4],v[6],v[5],v[0],v[3],v[1],v[7],v[2]}
`define SWAP3(v) {v[8],v[9],v[10],v[13],v[11],v[15],v[14],v[12],v[5],v[4],v[0],v[7],v[2],v[6],v[1],v[3]}
`define SWAP4(v) {v[12],v[13],v[14],v[15],v[8],v[9],v[10],v[11],v[1],v[5],v[0],v[3],v[2],v[7],v[6],v[4]}
`define SWAP5(v) {v[14],v[15],v[13],v[8],v[12],v[10],v[11],v[9],v[1],v[2],v[7],v[6],v[4],v[3],v[0],v[5]}
`define SWAP6(v) {v[13],v[14],v[10],v[11],v[9],v[8],v[12],v[15],v[3],v[1],v[7],v[4],v[5],v[0],v[2],v[6]}
`define SWAP7(v) {v[9],v[8],v[14],v[10],v[15],v[11],v[13],v[12],v[6],v[0],v[5],v[2],v[4],v[1],v[3],v[7]}
