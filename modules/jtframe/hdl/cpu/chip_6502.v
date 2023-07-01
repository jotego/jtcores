// Direct conversion of the MOS6502 to
// a verilog netlist by Andrew Holme
// http://www.aholme.co.uk/6502/Main.htm
// Used with the author permission

// Modified to be a bit friendlier with Verilator sims
// - Consolidated in a single file
// - Macros undefined at the end of the file
// - Verilator warnings waived

/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNOPTFLAT */

`define NUM_NODES 1725

`define NODE_vcc 657
`define NODE_vss 558
`define NODE_cp1 710
`define NODE_cp2 943

`define NODE_res 159
`define NODE_rw 1156
`define NODE_db0 1005
`define NODE_db1 82
`define NODE_db3 650
`define NODE_db2 945
`define NODE_db5 175
`define NODE_db4 1393
`define NODE_db7 1349
`define NODE_db6 1591
`define NODE_ab0 268
`define NODE_ab1 451
`define NODE_ab2 1340
`define NODE_ab3 211
`define NODE_ab4 435
`define NODE_ab5 736
`define NODE_ab6 887
`define NODE_ab7 1493
`define NODE_ab8 230
`define NODE_ab9 148
`define NODE_ab12 1237
`define NODE_ab13 349
`define NODE_ab10 1443
`define NODE_ab11 399
`define NODE_ab14 672
`define NODE_ab15 195
`define NODE_sync 539
`define NODE_so 1672
`define NODE_clk0 1171
`define NODE_clk1out 1163
`define NODE_clk2out 421
`define NODE_rdy 89
`define NODE_nmi 1297
`define NODE_irq 103

`define NODE_dpc11_SBADD 549
`define NODE_dpc9_DBADD 859

`define NODE_a0 737
`define NODE_a1 1234
`define NODE_a2 978
`define NODE_a3 162
`define NODE_a4 727
`define NODE_a5 858
`define NODE_a6 1136
`define NODE_a7 1653

`define NODE_y0 64
`define NODE_y1 1148
`define NODE_y2 573
`define NODE_y3 305
`define NODE_y4 989
`define NODE_y5 615
`define NODE_y6 115
`define NODE_y7 843

`define NODE_x0 1216
`define NODE_x1 98
`define NODE_x2 1
`define NODE_x3 1648
`define NODE_x4 85
`define NODE_x5 589
`define NODE_x6 448
`define NODE_x7 777

`define NODE_pcl0 1139
`define NODE_pcl1 1022
`define NODE_pcl2 655
`define NODE_pcl3 1359
`define NODE_pcl4 900
`define NODE_pcl5 622
`define NODE_pcl6 377
`define NODE_pcl7 1611
`define NODE_pch0 1670
`define NODE_pch1 292
`define NODE_pch2 502
`define NODE_pch3 584
`define NODE_pch4 948
`define NODE_pch5 49
`define NODE_pch6 1551
`define NODE_pch7 205

`define NODE_Reset0 67
`define NODE_C1x5Reset 926

`define NODE_idl0 1597     // datapath signal internal data latch (driven output)
`define NODE_idl1 870
`define NODE_idl2 1066
`define NODE_idl3 464
`define NODE_idl4 1306
`define NODE_idl5 240
`define NODE_idl6 1116
`define NODE_idl7 391

`define NODE_sb0 54        // datapath bus special bus
`define NODE_sb1 1150
`define NODE_sb2 1287
`define NODE_sb3 1188
`define NODE_sb4 1405
`define NODE_sb5 166
`define NODE_sb6 1336
`define NODE_sb7 1001

`define NODE_adl0 413      // internal bus address low
`define NODE_adl1 1282
`define NODE_adl2 1242
`define NODE_adl3 684
`define NODE_adl4 1437
`define NODE_adl5 1630
`define NODE_adl6 121
`define NODE_adl7 1299

`define NODE_adh0 407      // internal bus address high
`define NODE_adh1 52
`define NODE_adh2 1651
`define NODE_adh3 315
`define NODE_adh4 1160
`define NODE_adh5 483
`define NODE_adh6 13
`define NODE_adh7 1539

`define NODE_idb0 1108     // internal bus data bus
`define NODE_idb1 991
`define NODE_idb2 1473
`define NODE_idb3 1302
`define NODE_idb4 892
`define NODE_idb5 1503
`define NODE_idb6 833
`define NODE_idb7 493

`define NODE_abl0 1096     // internal bus address bus low latched data out (inverse of inverted storage node)
`define NODE_abl1 376
`define NODE_abl2 1502
`define NODE_abl3 1250
`define NODE_abl4 1232
`define NODE_abl5 234
`define NODE_abl6 178
`define NODE_abl7 567

`define NODE_abh0 1429     // internal bus address bus high latched data out (inverse of inverted storage node)
`define NODE_abh1 713
`define NODE_abh2 287
`define NODE_abh3 422
`define NODE_abh4 1143
`define NODE_abh5 775
`define NODE_abh6 997
`define NODE_abh7 489

`define NODE_s0 1403       // machine state stack pointer
`define NODE_s1 183
`define NODE_s2 81
`define NODE_s3 1532
`define NODE_s4 1702
`define NODE_s5 1098
`define NODE_s6 1212
`define NODE_s7 1435

`define NODE_ir0 328       // internal state instruction register
`define NODE_ir1 1626
`define NODE_ir2 1384
`define NODE_ir3 1576
`define NODE_ir4 1112
`define NODE_ir5 1329      // ir5 distinguishes branch set from branch clear
`define NODE_ir6 337
`define NODE_ir7 1328

`define NODE_clock1 1536   // internal state timing control aka #T0
`define NODE_clock2 156    // internal state timing control aka #T+
`define NODE_t2 971        // internal state timing control
`define NODE_t3 1567
`define NODE_t4 690
`define NODE_t5 909

`define NODE_alu0 401
`define NODE_alu1 872
`define NODE_alu2 1637
`define NODE_alu3 1414
`define NODE_alu4 606
`define NODE_alu5 314
`define NODE_alu6 331
`define NODE_alu7 765

`define NODE_alua0 1167
`define NODE_alua1 1248
`define NODE_alua2 1332
`define NODE_alua3 1680
`define NODE_alua4 1142
`define NODE_alua5 530
`define NODE_alua6 1627
`define NODE_alua7 1522

`define NODE_alub0 977
`define NODE_alub1 1432
`define NODE_alub2 704
`define NODE_alub3 96
`define NODE_alub4 1645
`define NODE_alub5 1678
`define NODE_alub6 235
`define NODE_alub7 1535

module MUX6502 #(
    parameter N=1
) (
    output wire o,
    input  wire i,
    input  wire [N-1:0] s,
    input  wire [N-1:0] d);

    assign o = (|s) ? &(d|(~s)) : i;
endmodule

module LOGIC (
    input  [`NUM_NODES-1:0] i,
    output [`NUM_NODES-1:0] o);

    assign o[674] = i[192]|i[256];
    assign o[928] = i[1077]|i[829];
    assign o[522] = i[197]|i[403];
    assign o[1117] = i[1134]|i[717];
    assign o[876] = i[276]|i[697];
    assign o[1448] = ~i[636]|i[660];
    assign o[996] = ~i[310]|~i[119];
    assign o[1018] = i[893]|i[68];
    assign o[1688] = i[787]|i[673];
    assign o[1309] = i[1077]|i[1669];
    assign o[1228] = i[303]|i[1504];
    assign o[125] = i[1410]|i[809]|i[540];
    assign o[1081] = i[1055]|i[1337]|i[1355];
    assign o[925] = ~i[1675]|i[541]|~i[1609];
    assign o[544] = i[1609]|i[1675]|~i[541]|i[119];
    assign o[630] = i[0]|i[1210]|i[461]|i[677];
    assign o[664] = i[1620]|~i[310]|i[1050]|~i[1300];
    assign o[837] = i[310]|i[1675]|i[1536]|~i[541]|~i[1609];
    assign o[636] = ~i[1620]|~i[1575]|~i[1300]|i[927]|i[996];
    assign o[218] = i[309]|i[528]|i[932]|i[1589]|i[446]|i[1430];
    assign o[847] = i[1382]|i[712]|~i[1107]|i[1259]|i[857]|i[342];
    assign o[980] = i[1620]|i[1675]|~i[927]|~i[541]|i[1300]|~i[678]|i[996];
    assign o[1065] = i[1620]|i[1675]|i[1536]|~i[1300]|~i[541]|i[927]|i[996];
    assign o[889] = i[1620]|~i[1675]|i[1536]|~i[1300]|~i[541]|i[927]|i[996];
    assign o[1379] = i[1609]|~i[1675]|i[1536]|~i[927]|~i[541]|i[1300]|i[996];
    assign o[774] = i[1620]|i[1675]|i[1536]|~i[1300]|i[541]|i[927]|i[996];
    assign o[340] = i[1620]|i[1609]|~i[1675]|~i[1300]|i[541]|i[927]|i[996];
    assign o[1268] = i[1503]|i[493]|i[1473]|i[1108]|i[991]|i[1302]|i[892]|i[833];
    assign o[1586] = i[1620]|i[1609]|~i[1675]|i[1536]|~i[1300]|i[541]|i[119]|i[927];
    assign o[1219] = ~i[1620]|i[1609]|~i[378]|~i[1675]|~i[927]|~i[1300]|~i[541]|i[996];
    assign o[979] = ~i[24]&i[546];
    assign o[19] = ~(~i[660]|~i[559]);
    assign o[36] = ~(~i[1341]|i[393]);
    assign o[46] = ~(i[197]|~i[595]);
    assign o[53] = ~(i[1675]|i[119]);
    assign o[65] = ~(~i[1425]|i[308]);
    assign o[80] = ~(i[1130]|i[267]);
    assign o[160] = ~(i[781]|~i[366]);
    assign o[169] = ~(i[1624]|i[366]);
    assign o[174] = ~(~i[427]|i[1459]);
    assign o[176] = ~(i[10]|i[660]);
    assign o[180] = ~(i[197]|i[1716]);
    assign o[188] = ~(i[1606]|~i[223]);
    assign o[193] = ~(~i[1122]|i[701]);
    assign o[200] = ~(~i[292]|i[919]);
    assign o[204] = ~(~i[1620]|~i[1575]);
    assign o[251] = ~(i[1035]|~i[1579]);
    assign o[260] = ~(i[1205]|~i[1001]);
    assign o[261] = ~(i[447]|i[461]);
    assign o[264] = ~(i[1312]|i[1149]);
    assign o[269] = ~(i[1241]|~i[336]);
    assign o[275] = ~(i[773]|~i[664]);
    assign o[295] = ~(i[425]|~i[1285]);
    assign o[327] = ~(i[1226]|i[1569]);
    assign o[334] = ~(i[1382]|i[1553]);
    assign o[335] = ~(i[347]|i[925]);
    assign o[378] = ~(~i[223]|i[18]);
    assign o[385] = ~(i[604]|~i[857]);
    assign o[410] = ~(i[1184]|~i[900]);
    assign o[412] = ~(i[164]|i[560]);
    assign o[425] = ~(i[155]|~i[841]);
    assign o[467] = ~(i[134]|i[17]);
    assign o[479] = ~(i[739]|~i[1336]);
    assign o[506] = ~(i[192]|i[660]);
    assign o[516] = ~(i[1691]|~i[681]);
    assign o[540] = ~(i[1077]|i[369]);
    assign o[550] = ~(i[384]|i[1228]);
    assign o[553] = ~(i[781]|~i[1124]);
    assign o[555] = ~(i[1525]|~i[590]);
    assign o[595] = ~(i[354]|i[1168]);
    assign o[637] = ~(i[1318]|i[1314]);
    assign o[640] = ~(i[649]|~i[350]);
    assign o[678] = ~(~i[223]|i[644]);
    assign o[717] = ~(i[1132]|i[1036]);
    assign o[720] = ~(i[197]|i[56]);
    assign o[735] = ~(~i[1150]|i[36]);
    assign o[743] = ~(i[523]|~i[49]);
    assign o[753] = ~(i[1257]|i[811]);
    assign o[773] = ~(~i[17]|i[273]);
    assign o[781] = ~(i[197]|i[199]);
    assign o[790] = ~(i[53]|i[691]);
    assign o[809] = ~(i[1077]|i[361]);
    assign o[810] = ~(~i[584]|i[293]);
    assign o[811] = ~(~i[412]|~i[581]);
    assign o[812] = ~(~i[17]|~i[24]);
    assign o[813] = ~(i[653]|~i[24]);
    assign o[817] = ~(i[1220]|~i[142]);
    assign o[819] = ~(i[449]|i[596]);
    assign o[824] = ~(i[487]|i[579]);
    assign o[827] = ~(~i[717]|i[1350]);
    assign o[860] = ~(~i[1023]|i[640]);
    assign o[877] = ~(i[506]|i[933]);
    assign o[879] = ~(i[197]|~i[1011]);
    assign o[882] = ~(i[597]|i[1252]);
    assign o[917] = ~(i[197]|~i[712]);
    assign o[930] = ~(i[134]|i[1276]);
    assign o[944] = ~(i[89]|i[759]);
    assign o[959] = ~(i[430]|i[294]);
    assign o[964] = ~(i[554]|i[1533]);
    assign o[1044] = ~(~i[32]|i[812]);
    assign o[1055] = ~(~i[660]|i[756]);
    assign o[1069] = ~(~i[94]|i[1274]);
    assign o[1087] = ~(i[1382]|i[717]);
    assign o[1090] = ~(~i[1225]|i[157]);
    assign o[1097] = ~(i[345]|~i[1188]);
    assign o[1109] = ~(i[1464]|i[902]);
    assign o[1115] = ~(i[1609]|i[620]);
    assign o[1134] = ~(i[1465]|~i[698]);
    assign o[1154] = ~(i[197]|i[959]);
    assign o[1159] = ~(i[613]|~i[1287]);
    assign o[1170] = ~(i[781]|~i[443]);
    assign o[1179] = ~(~i[1425]|~i[599]);
    assign o[1180] = ~(i[197]|i[554]);
    assign o[1213] = ~(~i[205]|i[609]);
    assign o[1217] = ~(i[1241]|~i[1314]);
    assign o[1220] = ~(i[1632]|~i[477]);
    assign o[1225] = ~(i[285]|i[1524]);
    assign o[1241] = ~(~i[1318]|i[1398]);
    assign o[1253] = ~(~i[655]|i[1542]);
    assign o[1257] = ~(i[412]|~i[1565]);
    assign o[1286] = ~(i[17]|i[930]);
    assign o[1312] = ~(i[1693]|i[1291]);
    assign o[1316] = ~(i[344]|~i[377]);
    assign o[1342] = ~(i[310]|i[1536]);
    assign o[1343] = ~(i[197]|i[152]);
    assign o[1345] = ~(i[379]|~i[1139]);
    assign o[1350] = ~(i[1382]|i[760]);
    assign o[1374] = ~(i[562]|i[882]);
    assign o[1380] = ~(i[819]|i[1154]);
    assign o[1382] = ~(i[197]|~i[1452]);
    assign o[1391] = ~(i[352]|i[750]);
    assign o[1410] = ~(i[1077]|i[1690]);
    assign o[1457] = ~(i[781]|~i[974]);
    assign o[1465] = ~(i[197]|~i[370]);
    assign o[1517] = ~(~i[1176]|i[559]);
    assign o[1575] = ~(~i[223]|i[1360]);
    assign o[1587] = ~(i[1077]|i[894]);
    assign o[1610] = ~(i[640]|~i[681]);
    assign o[1619] = ~(i[1448]|i[182]);
    assign o[1622] = ~(i[1077]|i[758]);
    assign o[1629] = ~(~i[166]|i[753]);
    assign o[1671] = ~(i[1077]|i[955]);
    assign o[1705] = ~(i[467]|i[630]);
    assign o[10] = ~(i[467]|i[1721]|i[1211]);
    assign o[14] = ~(~i[1395]|i[323]|i[671]);
    assign o[58] = ~(i[927]|i[1620]|~i[678]);
    assign o[134] = ~(i[1557]|i[259]|i[1052]);
    assign o[187] = ~(i[197]|~i[717]|i[1131]);
    assign o[191] = ~(i[347]|i[197]|i[790]);
    assign o[258] = ~(i[1300]|~i[1575]|i[927]);
    assign o[267] = ~(i[544]|i[785]|~i[1447]);
    assign o[273] = ~(~i[1575]|i[1620]|i[791]);
    assign o[279] = ~(~i[1104]|~i[338]|~i[1049]);
    assign o[281] = ~(i[927]|i[1620]|~i[188]);
    assign o[285] = ~(~i[1575]|~i[1620]|i[1300]);
    assign o[307] = ~(i[541]|~i[32]|~i[1675]);
    assign o[354] = ~(i[927]|i[1620]|~i[188]);
    assign o[447] = ~(i[927]|i[1620]|~i[678]);
    assign o[501] = ~(i[819]|~i[1395]|i[180]);
    assign o[510] = ~(i[347]|i[1052]|~i[790]);
    assign o[513] = ~(i[1646]|~i[338]|~i[384]);
    assign o[546] = ~(~i[1675]|~i[541]|i[119]);
    assign o[616] = ~(i[1482]|i[286]|i[665]);
    assign o[677] = ~(i[791]|i[1620]|~i[678]);
    assign o[691] = ~(~i[1675]|~i[541]|i[119]);
    assign o[844] = ~(i[786]|i[985]|i[1664]);
    assign o[1019] = ~(i[1622]|~i[1587]|i[1671]);
    assign o[1215] = ~(i[1382]|i[1185]|~i[1713]);
    assign o[1243] = ~(~i[541]|i[310]|~i[1533]);
    assign o[1246] = ~(~i[541]|i[1675]|i[119]);
    assign o[1275] = ~(i[832]|i[197]|i[1019]);
    assign o[1293] = ~(i[541]|i[1675]|~i[627]);
    assign o[1358] = ~(i[917]|i[1109]|i[245]);
    assign o[1368] = ~(i[1374]|~i[1431]|~i[1032]);
    assign o[1371] = ~(~i[69]|~i[541]|~i[1675]);
    assign o[1433] = ~(~i[541]|i[1675]|~i[1625]);
    assign o[1562] = ~(~i[1675]|i[541]|i[119]);
    assign o[1614] = ~(i[1177]|i[1111]|i[1436]);
    assign o[1712] = ~(i[1134]|i[264]|~i[717]);
    assign o[145] = ~(~i[1675]|i[541]|i[310]|~i[1609]);
    assign o[152] = ~(~i[272]|i[630]|~i[1219]|i[1575]);
    assign o[219] = ~(~i[1575]|~i[927]|~i[1620]|i[1300]);
    assign o[302] = ~(~i[1622]|~i[1587]|i[1671]|i[540]);
    assign o[324] = ~(i[1675]|i[541]|i[1609]|i[119]);
    assign o[384] = ~(i[946]|i[1228]|i[653]|~i[1455]);
    assign o[388] = ~(i[425]|i[623]|i[516]|~i[841]);
    assign o[570] = ~(~i[477]|i[1220]|i[142]|~i[1459]);
    assign o[575] = ~(i[310]|i[1675]|i[1609]|i[1536]);
    assign o[607] = ~(~i[927]|i[1300]|i[1620]|~i[678]);
    assign o[620] = ~(i[307]|i[1433]|i[1371]|i[1293]);
    assign o[822] = ~(i[310]|i[1675]|i[1609]|~i[1533]);
    assign o[904] = ~(i[1300]|i[927]|~i[1620]|~i[678]);
    assign o[1031] = ~(~i[927]|~i[541]|~i[678]|i[996]);
    assign o[1057] = ~(~i[1575]|~i[927]|i[1620]|i[1300]);
    assign o[1155] = ~(i[310]|i[1675]|i[1609]|~i[1533]);
    assign o[1178] = ~(i[960]|i[614]|i[848]|i[1652]);
    assign o[1185] = ~(i[729]|i[916]|i[197]|i[1137]);
    assign o[1196] = ~(i[522]|i[1228]|~i[837]|~i[366]);
    assign o[1385] = ~(~i[1620]|i[310]|~i[378]|~i[1300]);
    assign o[1466] = ~(~i[1675]|~i[541]|i[1609]|i[119]);
    assign o[1524] = ~(~i[1575]|i[310]|~i[1620]|~i[1300]);
    assign o[1540] = ~(~i[1675]|i[541]|i[119]|~i[1609]);
    assign o[1716] = ~(i[510]|i[653]|i[218]|i[660]);
    assign o[60] = ~(i[310]|~i[1620]|i[927]|~i[1300]|~i[678]);
    assign o[84] = ~(i[310]|~i[1575]|~i[927]|~i[1620]|~i[1300]);
    assign o[104] = ~(~i[636]|~i[24]|i[1589]|i[275]|i[847]);
    assign o[157] = ~(~i[927]|~i[1575]|~i[541]|~i[1300]|i[996]);
    assign o[301] = ~(~i[1533]|i[310]|i[541]|i[1675]|~i[1609]);
    assign o[342] = ~(i[310]|~i[1620]|i[927]|~i[1300]|~i[678]);
    assign o[347] = ~(i[281]|i[219]|i[1385]|i[607]|i[904]);
    assign o[403] = ~(i[1536]|~i[1675]|~i[541]|i[310]|~i[1609]);
    assign o[461] = ~(i[310]|~i[1620]|i[927]|~i[1300]|~i[188]);
    assign o[492] = ~(i[310]|~i[1620]|i[927]|~i[1300]|~i[188]);
    assign o[660] = ~(i[927]|~i[1620]|~i[678]|~i[1300]|i[996]);
    assign o[787] = ~(i[310]|i[1675]|i[1536]|i[1609]|i[541]);
    assign o[791] = ~(~i[927]|i[1620]|~i[541]|~i[1300]|i[996]);
    assign o[985] = ~(i[1536]|~i[1675]|i[541]|i[1609]|i[119]);
    assign o[1050] = ~(~i[927]|i[1620]|~i[541]|~i[1300]|i[996]);
    assign o[1130] = ~(~i[1219]|i[192]|i[1109]|i[653]|~i[666]);
    assign o[1168] = ~(i[310]|~i[1620]|~i[378]|~i[1300]|i[927]);
    assign o[1204] = ~(~i[1575]|~i[1620]|i[310]|~i[1300]|i[927]);
    assign o[1210] = ~(i[310]|~i[1620]|~i[927]|~i[378]|~i[1300]);
    assign o[1211] = ~(~i[636]|i[273]|~i[666]|~i[1219]|i[1286]);
    assign o[1259] = ~(i[310]|~i[1620]|~i[927]|~i[1300]|~i[188]);
    assign o[1294] = ~(i[1587]|i[1622]|i[1671]|~i[1410]|i[540]);
    assign o[1334] = ~(~i[292]|~i[1670]|~i[1704]|~i[584]|~i[502]);
    assign o[1337] = ~(i[1536]|~i[927]|i[541]|i[1675]|i[996]);
    assign o[1355] = ~(i[1536]|i[310]|i[541]|i[1675]|~i[1609]);
    assign o[1420] = ~(~i[1675]|i[310]|i[1536]|i[1609]|i[541]);
    assign o[1428] = ~(i[310]|~i[1620]|~i[927]|~i[1300]|~i[678]);
    assign o[1504] = ~(~i[1675]|i[310]|i[1536]|i[1609]|~i[541]);
    assign o[1512] = ~(~i[1575]|i[1620]|i[310]|~i[1300]|i[927]);
    assign o[1582] = ~(~i[927]|~i[1575]|~i[541]|~i[1300]|i[996]);
    assign o[1601] = ~(~i[1675]|i[1300]|i[541]|~i[1609]|i[996]);
    assign o[272] = ~(~i[17]|i[273]|~i[636]|i[660]|i[0]|~i[666]);
    assign o[286] = ~(~i[1675]|i[1536]|~i[927]|i[541]|i[1609]|i[996]);
    assign o[665] = ~(~i[1675]|i[1536]|i[1300]|i[541]|i[1609]|i[996]);
    assign o[764] = ~(~i[927]|~i[541]|i[1675]|i[1300]|i[1620]|i[996]);
    assign o[857] = ~(i[1675]|~i[927]|~i[1620]|~i[541]|~i[1300]|i[996]);
    assign o[1052] = ~(~i[927]|~i[541]|i[1675]|i[1300]|i[1620]|i[996]);
    assign o[1233] = ~(i[1536]|~i[927]|i[1675]|i[541]|~i[1609]|i[996]);
    assign o[1324] = ~(~i[927]|~i[541]|i[1620]|~i[1533]|~i[1300]|i[119]);
    assign o[1347] = ~(~i[636]|i[1396]|i[979]|i[550]|~i[666]|i[782]);
    assign o[1352] = ~(i[653]|~i[24]|i[335]|i[352]|i[1642]|i[932]);
    assign o[1396] = ~(i[1536]|~i[927]|i[1620]|~i[541]|~i[1300]|i[119]);
    assign o[1464] = ~(i[370]|i[784]|i[271]|i[552]|i[1612]|i[1487]);
    assign o[1520] = ~(i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[1557] = ~(~i[927]|~i[541]|~i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[1658] = ~(i[1536]|~i[927]|i[1675]|i[541]|i[1609]|i[996]);
    assign o[1710] = ~(~i[927]|~i[1533]|i[1675]|i[541]|~i[1620]|i[996]);
    assign o[1721] = ~(i[1536]|i[927]|~i[1620]|~i[47]|~i[1300]|i[996]);
    assign o[256] = ~(i[784]|i[0]|i[1478]|i[594]|i[188]|i[1210]|i[678]);
    assign o[259] = ~(~i[1675]|~i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[303] = ~(i[1536]|~i[1675]|~i[927]|~i[541]|i[1300]|i[1609]|i[996]);
    assign o[382] = ~(i[1536]|~i[927]|i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[446] = ~(i[1675]|~i[1620]|~i[927]|~i[378]|~i[541]|~i[1300]|i[996]);
    assign o[552] = ~(i[1536]|~i[927]|~i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[594] = ~(i[1536]|~i[927]|~i[541]|i[1675]|i[1300]|i[1620]|i[996]);
    assign o[804] = ~(~i[1675]|~i[927]|~i[541]|~i[1620]|~i[188]|~i[1300]|i[996]);
    assign o[932] = ~(~i[927]|~i[1575]|~i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[950] = ~(~i[927]|~i[1533]|i[1300]|i[1675]|i[541]|i[1620]|i[996]);
    assign o[1074] = ~(i[1536]|i[1675]|~i[927]|i[1620]|~i[541]|~i[1300]|i[119]);
    assign o[1430] = ~(~i[927]|i[1620]|~i[541]|i[1609]|~i[678]|~i[1300]|i[996]);
    assign o[1455] = ~(i[1420]|i[179]|i[131]|i[1324]|i[1243]|i[257]|i[822]);
    assign o[1478] = ~(i[1536]|~i[927]|~i[541]|~i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[1482] = ~(~i[927]|~i[1533]|i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[1487] = ~(~i[927]|i[1620]|~i[541]|i[1609]|~i[678]|~i[1300]|i[996]);
    assign o[1589] = ~(~i[927]|~i[541]|i[1300]|i[1675]|~i[188]|i[1620]|i[996]);
    assign o[1646] = ~(~i[1675]|~i[927]|~i[541]|~i[1533]|i[1300]|i[1609]|i[996]);
    assign o[1665] = ~(~i[1675]|~i[927]|~i[541]|i[1620]|~i[1533]|~i[1300]|i[119]);
    assign o[0] = ~(~i[1620]|i[1675]|~i[378]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[4] = ~(~i[1675]|i[1536]|i[1620]|~i[927]|i[1609]|i[541]|~i[1300]|i[996]);
    assign o[76] = ~(i[1536]|~i[927]|i[1675]|i[541]|i[1620]|i[119]|~i[1300]|~i[1609]);
    assign o[131] = ~(i[1675]|i[1536]|i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[167] = ~(~i[1675]|i[1536]|i[1620]|~i[927]|i[1609]|i[541]|~i[1300]|i[119]);
    assign o[179] = ~(~i[1675]|i[1536]|~i[927]|i[541]|i[1620]|i[119]|~i[1300]|~i[1609]);
    assign o[245] = ~(~i[1675]|i[1536]|i[541]|i[119]|i[1620]|i[927]|~i[1300]|~i[1609]);
    assign o[257] = ~(~i[1675]|i[1536]|i[541]|i[927]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[271] = ~(~i[1675]|i[1536]|~i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[309] = ~(~i[1575]|~i[927]|i[1675]|~i[541]|i[1620]|i[1300]|~i[1609]|i[996]);
    assign o[352] = ~(~i[1675]|~i[927]|~i[1620]|~i[541]|~i[1609]|~i[188]|~i[1300]|i[996]);
    assign o[370] = ~(~i[1675]|~i[927]|~i[1620]|~i[541]|~i[378]|~i[1609]|~i[1300]|i[996]);
    assign o[487] = ~(~i[1675]|~i[927]|~i[1575]|~i[541]|~i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[528] = ~(~i[1620]|~i[1675]|~i[378]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[579] = ~(~i[1675]|~i[927]|~i[1620]|~i[541]|i[1609]|~i[678]|~i[1300]|i[996]);
    assign o[712] = ~(~i[1575]|~i[1675]|~i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[750] = ~(~i[1675]|~i[927]|~i[1575]|~i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[784] = ~(i[1675]|~i[927]|~i[1620]|~i[541]|~i[378]|~i[1609]|~i[1300]|i[996]);
    assign o[786] = ~(~i[927]|~i[1533]|i[1675]|i[541]|i[1620]|i[119]|~i[1300]|~i[1609]);
    assign o[1086] = ~(~i[1575]|~i[927]|i[1675]|~i[541]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[1173] = ~(~i[1675]|i[1536]|i[541]|i[927]|i[1620]|~i[1609]|~i[1300]|i[996]);
    assign o[1226] = ~(~i[1675]|i[1536]|i[1620]|~i[927]|i[1609]|~i[541]|~i[1300]|i[996]);
    assign o[1311] = ~(~i[927]|i[1675]|~i[1620]|~i[541]|~i[1609]|~i[188]|~i[1300]|i[996]);
    assign o[1543] = ~(~i[1675]|i[1536]|~i[927]|i[541]|i[1620]|i[119]|~i[1300]|~i[1609]);
    assign o[1569] = ~(i[1675]|~i[927]|~i[1620]|~i[541]|~i[1609]|~i[188]|~i[1300]|i[996]);
    assign o[1612] = ~(i[1675]|~i[927]|~i[1620]|~i[541]|i[1609]|~i[188]|~i[1300]|i[996]);
    assign o[1664] = ~(i[1675]|~i[927]|i[1620]|~i[1533]|i[1609]|i[541]|~i[1300]|i[996]);
    assign o[1649] = ~(i[764]|i[197]|i[1109]|i[1382]|i[1057]|~i[1107]|i[1259]|i[712]|i[857]);
    assign o[1704] = ~(~i[655]|i[379]|~i[1611]|~i[1359]|~i[377]|~i[622]|~i[1139]|~i[1022]|~i[900]);
    assign o[919] = ~(i[1704]&i[1670]);
    assign o[1137] = ~(i[790]&i[925]);
    assign o[1386] = ~(i[1316]&i[1611]);
    assign o[1101] = ~(i[813]&i[46]);
    assign o[1077] = ~(i[879]&i[827]);
    assign o[757] = ~(i[142]&~i[477]);
    assign o[1594] = ~(i[779]&i[604]);
    assign o[523] = ~(i[948]&i[1334]);
    assign o[473] = ~(i[980]&i[1408]);
    assign o[1642] = ~(i[824]&~i[1338]);
    assign o[29] = ~(i[787]&i[348]);
    assign o[293] = ~(i[200]&i[502]);
    assign o[986] = ~(i[276]&i[697]);
    assign o[782] = ~(i[1303]&~i[712]);
    assign o[673] = ~(i[575]&i[348]);
    assign o[504] = ~(~i[24]&~i[197]);
    assign o[319] = ~(i[623]&~i[841]);
    assign o[701] = ~(~i[1691]&i[681]);
    assign o[1525] = ~(~i[143]&i[1628]);
    assign o[308] = ~(i[1063]&~i[404]);
    assign o[946] = ~(i[844]&i[616]);
    assign o[1184] = ~(i[1253]&i[1359]);
    assign o[933] = ~(~i[1679]&~i[1176]);
    assign o[233] = ~(i[893]&i[68]);
    assign o[192] = ~(~i[1721]&i[595]);
    assign o[609] = ~(i[743]&i[1551]);
    assign o[1459] = ~(i[336]&~i[1084]);
    assign o[695] = ~(~i[1425]&i[1450]);
    assign o[1542] = ~(i[1345]&i[1022]);
    assign o[344] = ~(i[410]&i[622]);
    assign o[1111] = ~(i[215]&i[199]);
    assign o[651] = ~(~i[1425]&i[308]|i[65]);
    assign o[274] = ~(~i[1023]&i[640]|i[860]);
    assign o[515] = ~(i[1542]&~i[655]|i[1253]);
    assign o[1209] = ~(i[609]&~i[205]|i[1213]);
    assign o[1500] = ~(i[379]&~i[1139]|i[1345]);
    assign o[263] = ~(i[753]&~i[166]|i[1629]);
    assign o[371] = ~(~i[590]&i[1525]|i[555]);
    assign o[486] = ~(~i[142]&i[1220]|i[817]);
    assign o[1314] = ~(i[427]&i[336]|i[1084]);
    assign o[366] = ~(~i[24]&i[1246]|i[1074]);
    assign o[1285] = ~(i[1628]&i[590]|i[143]);
    assign o[754] = ~(i[443]&i[199]|i[1673]);
    assign o[207] = ~(i[293]&~i[584]|i[810]);
    assign o[916] = ~(i[412]&i[559]|i[1517]);
    assign o[22] = ~(~i[1122]&i[701]|i[193]);
    assign o[427] = ~(i[142]&~i[1632]|~i[477]);
    assign o[1486] = ~(i[919]&~i[292]|i[200]);
    assign o[586] = ~(i[1544]&~i[636]|i[1619]);
    assign o[142] = ~(i[1425]&i[1063]|i[404]);
    assign o[532] = ~(~i[1314]&i[1241]|i[1217]);
    assign o[1475] = ~(i[345]&~i[1188]|i[1097]);
    assign o[1308] = ~(i[1314]&i[1398]|i[637]);
    assign o[965] = ~(~i[1285]&i[425]|i[295]);
    assign o[1039] = ~(i[197]&i[151]|i[456]);
    assign o[1327] = ~(i[1314]&~i[1398]|~i[1318]);
    assign o[1023] = ~(i[681]&i[1122]|i[1691]);
    assign o[732] = ~(i[792]&i[1528]|i[1161]);
    assign o[1009] = ~(i[36]&~i[1150]|i[735]);
    assign o[1494] = ~(i[1205]&~i[1001]|i[260]);
    assign o[450] = ~(i[613]&~i[1287]|i[1159]);
    assign o[623] = ~(i[1628]&i[590]|i[143]);
    assign o[20] = ~(i[344]&~i[377]|i[1316]);
    assign o[1544] = ~(i[1609]&i[620]|i[1115]);
    assign o[1290] = ~(i[197]&~i[698]|i[1126]);
    assign o[875] = ~(i[523]&~i[49]|i[743]);
    assign o[1197] = ~(~i[427]&i[1459]|i[174]);
    assign o[632] = ~(~i[902]&i[271]|i[1582]);
    assign o[1122] = ~(i[1285]&~i[155]|~i[841]);
    assign o[679] = ~(i[739]&~i[1336]|i[479]);
    assign o[1037] = ~(i[145]&i[335]|i[1086]);
    assign o[474] = ~(i[1184]&~i[900]|i[410]);
    assign o[1425] = ~(i[1023]&~i[649]|i[1372]|~i[350]);
    assign o[851] = ~(i[1019]&i[125]|i[1294]|i[302]);
    assign o[182] = ~(i[660]&~i[1679]|i[0]|~i[17]|~i[1211]);
    assign o[11] = ~(~i[1420]&i[1342]|i[4]|i[167]|i[1396]|i[1228]);
    assign o[1107] = ~(i[324]&~i[24]|i[1520]|i[1428]|i[1204]|i[492]|i[58]);
    assign o[252] = ~(i[691]&i[653]|i[1710]|i[1665]|i[1155]|i[950]|i[301]);
    assign o[604] = ~(i[1536]&i[204]|i[197]|i[1582]|i[804]|i[1311]|i[1031]|i[1428]);
    assign o[472] = ~(~i[197]&i[706]|i[197]&i[1373]);
    assign o[428] = ~(~i[197]&i[40]|i[197]&i[706]);
    assign o[613] = ~(~i[697]&i[393]|~i[1341]&i[697]);
    assign o[262] = ~(~i[1008]&i[685]|~i[1321]&i[1008]);
    assign o[468] = ~(~i[197]&i[1373]|i[197]&i[940]);
    assign o[1091] = ~(~i[197]&i[537]|i[197]&i[40]);
    assign o[626] = ~(~i[493]&i[1269]|~i[1269]&i[1530]);
    assign o[345] = ~(i[986]&~i[1341]|i[393]&i[876]);
    assign o[1181] = ~(i[754]&~i[493]|~i[754]&i[1442]);
    assign o[739] = ~(~i[893]&i[811]|i[893]&i[1257]);
    assign o[1205] = ~(i[811]&i[1018]|i[233]&i[1257]);
    assign o[1106] = ~(i[258]&~i[1562]|i[335]&i[1540]|i[76]|i[1543]|i[1658]|i[245]|i[84]);
    assign o[1717] = ~(i[258]&i[1562]|i[335]&i[1601]|i[1173]|i[1233]|i[60]|i[382]|i[1512]);
    assign o[1495] = ~(~i[1302]&i[781]|i[1457]&i[99]|i[1609]&~i[974]);
    assign o[566] = ~(i[1170]&i[1607]|~i[991]&i[781]|~i[443]&i[1268]);
    assign o[845] = ~(~i[1473]&i[781]|~i[1124]&i[1609]|i[553]&i[1078]);
    assign o[299] = ~(i[408]&i[1436]|i[1614]&i[44]|~i[833]&i[1111]|~i[1283]);
    assign o[1082] = ~(~i[1049]&~i[1108]|i[412]&~i[338]|i[1051]&i[279]|i[1609]&~i[1104]);
    wire sb_local_1287 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_1473 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_1651 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1287 = idb_local_1473 & ~i[1527];
    wire sb2db_1473 = sb_local_1287 & ~i[1527];
    wire adh2sb_1287 = adh_local_1651 & ~i[1602];
    wire sb2adh_1651 = sb_local_1287 & ~i[1602];
    MUX6502 #(8) mux_sb_1287 (.o(o[1287]), .i(i[1287]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_1287,adh2sb_1287}), .d({i[657],i[573],i[1],~i[752],~i[276],i[978],i[1473],i[1651]}));
    MUX6502 #(7) mux_idb_1473 (.o(o[1473]), .i(i[1473]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_1473,~i[1577]}), .d({i[657],i[978],~i[114],i[1411],~i[1485],i[1287],~i[334]}));
    MUX6502 #(6) mux_adl_1242 (.o(o[1242]), .i(i[1242]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[45]}), .d({i[657],~i[752],~i[276],i[1411],~i[1485],i[558]}));
    MUX6502 #(5) mux_adh_1651 (.o(o[1651]), .i(i[1651]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_1651}), .d({i[657],i[558],~i[114],~i[1485],i[1287]}));
    MUX6502 #(2) mux_pcl_655 (.o(o[655]), .i(i[655]), .s({i[898],i[414]}), .d({i[1411],i[1242]}));
    MUX6502 #(2) mux_pch_502 (.o(o[502]), .i(i[502]), .s({i[48],i[741]}), .d({i[1651],~i[114]}));
    wire sb_local_54 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_1108 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_407 = ~i[683]|~i[598]|i[710]&~i[1020];
    wire db2sb_54 = idb_local_1108 & ~i[1527];
    wire sb2db_1108 = sb_local_54 & ~i[1527];
    wire adh2sb_54 = adh_local_407 & ~i[1602];
    wire sb2adh_407 = sb_local_54 & ~i[1602];
    MUX6502 #(8) mux_sb_54 (.o(o[54]), .i(i[54]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_54,adh2sb_54}), .d({i[657],i[64],i[1216],~i[418],~i[394],i[737],i[1108],i[407]}));
    MUX6502 #(7) mux_idb_1108 (.o(o[1108]), .i(i[1108]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_1108,~i[1577]}), .d({i[657],i[737],~i[780],i[526],~i[116],i[54],i[32]}));
    MUX6502 #(6) mux_adl_413 (.o(o[413]), .i(i[413]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],~i[357]}), .d({i[657],~i[418],~i[394],i[526],~i[116],i[558]}));
    MUX6502 #(5) mux_adh_407 (.o(o[407]), .i(i[407]), .s({i[943],~i[683],~i[598],i[710]&~i[1020], sb2adh_407}), .d({i[657],i[558],~i[780],~i[116],i[54]}));
    MUX6502 #(2) mux_pcl_1139 (.o(o[1139]), .i(i[1139]), .s({i[898],i[414]}), .d({i[526],i[413]}));
    MUX6502 #(2) mux_pch_1670 (.o(o[1670]), .i(i[1670]), .s({i[48],i[741]}), .d({i[407],~i[780]}));
    wire sb_local_1150 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_991 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_52 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1150 = idb_local_991 & ~i[1527];
    wire sb2db_991 = sb_local_1150 & ~i[1527];
    wire adh2sb_1150 = adh_local_52 & ~i[1602];
    wire sb2adh_52 = sb_local_1150 & ~i[1602];
    MUX6502 #(8) mux_sb_1150 (.o(o[1150]), .i(i[1150]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_1150,adh2sb_1150}), .d({i[657],i[1148],i[98],~i[1064],~i[697],i[1234],i[991],i[52]}));
    MUX6502 #(7) mux_idb_991 (.o(o[991]), .i(i[991]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_991,~i[1577]}), .d({i[657],i[1234],i[126],~i[1102],~i[576],i[1150],i[627]}));
    MUX6502 #(6) mux_adl_1282 (.o(o[1282]), .i(i[1282]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],~i[170]}), .d({i[657],~i[1064],~i[697],~i[1102],~i[576],i[558]}));
    MUX6502 #(5) mux_adh_52 (.o(o[52]), .i(i[52]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_52}), .d({i[657],i[558],i[126],~i[576],i[1150]}));
    MUX6502 #(2) mux_pcl_1022 (.o(o[1022]), .i(i[1022]), .s({i[898],i[414]}), .d({~i[1102],i[1282]}));
    MUX6502 #(2) mux_pch_292 (.o(o[292]), .i(i[292]), .s({i[48],i[741]}), .d({i[52],i[126]}));
    wire sb_local_1188 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_1302 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_315 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1188 = idb_local_1302 & ~i[1527];
    wire sb2db_1302 = sb_local_1188 & ~i[1527];
    wire adh2sb_1188 = adh_local_315 & ~i[1602];
    wire sb2adh_315 = sb_local_1188 & ~i[1602];
    MUX6502 #(8) mux_sb_1188 (.o(o[1188]), .i(i[1188]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_1188,adh2sb_1188}), .d({i[657],i[305],i[1648],~i[828],~i[495],i[162],i[1302],i[315]}));
    MUX6502 #(7) mux_idb_1302 (.o(o[1302]), .i(i[1302]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_1302,~i[1577]}), .d({i[657],i[162],i[1061],~i[868],~i[1284],i[1188],i[348]}));
    MUX6502 #(6) mux_adl_684 (.o(o[684]), .i(i[684]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[558]}), .d({i[657],~i[828],~i[495],~i[868],~i[1284],i[558]}));
    MUX6502 #(5) mux_adh_315 (.o(o[315]), .i(i[315]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_315}), .d({i[657],i[558],i[1061],~i[1284],i[1188]}));
    MUX6502 #(2) mux_pcl_1359 (.o(o[1359]), .i(i[1359]), .s({i[898],i[414]}), .d({~i[868],i[684]}));
    MUX6502 #(2) mux_pch_584 (.o(o[584]), .i(i[584]), .s({i[48],i[741]}), .d({i[315],i[1061]}));
    wire sb_local_1405 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_892 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_1160 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1405 = idb_local_892 & ~i[1527];
    wire sb2db_892 = sb_local_1405 & ~i[1527];
    wire adh2sb_1405 = adh_local_1160 & ~i[1602];
    wire sb2adh_1160 = sb_local_1405 & ~i[1602];
    MUX6502 #(8) mux_sb_1405 (.o(o[1405]), .i(i[1405]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_1405,adh2sb_1405}), .d({i[657],i[989],i[85],~i[1603],~i[1490],i[727],i[892],i[1160]}));
    MUX6502 #(7) mux_idb_892 (.o(o[892]), .i(i[892]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_892,~i[1577]}), .d({i[657],i[727],~i[820],i[15],~i[1516],i[1405],i[827]}));
    MUX6502 #(6) mux_adl_1437 (.o(o[1437]), .i(i[1437]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[558]}), .d({i[657],~i[1603],~i[1490],i[15],~i[1516],i[558]}));
    MUX6502 #(5) mux_adh_1160 (.o(o[1160]), .i(i[1160]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_1160}), .d({i[657],i[558],~i[820],~i[1516],i[1405]}));
    MUX6502 #(2) mux_pcl_900 (.o(o[900]), .i(i[900]), .s({i[898],i[414]}), .d({i[15],i[1437]}));
    MUX6502 #(2) mux_pch_948 (.o(o[948]), .i(i[948]), .s({i[48],i[741]}), .d({i[1160],~i[820]}));
    wire sb_local_166 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_1503 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|i[558];
    wire adh_local_483 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_166 = idb_local_1503 & ~i[1527];
    wire sb2db_1503 = sb_local_166 & ~i[1527];
    wire adh2sb_166 = adh_local_483 & ~i[1602];
    wire sb2adh_483 = sb_local_166 & ~i[1602];
    MUX6502 #(8) mux_sb_166 (.o(o[166]), .i(i[166]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_166,adh2sb_166}), .d({i[657],i[615],i[589],~i[601],~i[893],i[858],i[1503],i[483]}));
    MUX6502 #(7) mux_idb_1503 (.o(o[1503]), .i(i[1503]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_1503,i[558]}), .d({i[657],i[858],i[469],~i[1326],~i[498],i[166],i[558]}));
    MUX6502 #(6) mux_adl_1630 (.o(o[1630]), .i(i[1630]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[558]}), .d({i[657],~i[601],~i[893],~i[1326],~i[498],i[558]}));
    MUX6502 #(5) mux_adh_483 (.o(o[483]), .i(i[483]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_483}), .d({i[657],i[558],i[469],~i[498],i[166]}));
    MUX6502 #(2) mux_pcl_622 (.o(o[622]), .i(i[622]), .s({i[898],i[414]}), .d({~i[1326],i[1630]}));
    MUX6502 #(2) mux_pch_49 (.o(o[49]), .i(i[49]), .s({i[48],i[741]}), .d({i[483],i[469]}));
    wire sb_local_1336 = i[801]|i[1263]|~i[621]|~i[512]|i[1698];
    wire idb_local_833 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_13 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1336 = idb_local_833 & ~i[1527];
    wire sb2db_833 = sb_local_1336 & ~i[1527];
    wire adh2sb_1336 = adh_local_13 & ~i[1602];
    wire sb2adh_13 = sb_local_1336 & ~i[1602];
    MUX6502 #(8) mux_sb_1336 (.o(o[1336]), .i(i[1336]), .s({i[943],i[801],i[1263],~i[621],~i[512],i[1698],db2sb_1336,adh2sb_1336}), .d({i[657],i[115],i[448],~i[1029],~i[68],i[1136],i[833],i[13]}));
    MUX6502 #(7) mux_idb_833 (.o(o[833]), .i(i[833]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_833,~i[1577]}), .d({i[657],i[1136],~i[751],i[993],~i[1537],i[1336],i[1625]}));
    MUX6502 #(6) mux_adl_121 (.o(o[121]), .i(i[121]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[558]}), .d({i[657],~i[1029],~i[68],i[993],~i[1537],i[558]}));
    MUX6502 #(5) mux_adh_13 (.o(o[13]), .i(i[13]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_13}), .d({i[657],i[558],~i[751],~i[1537],i[1336]}));
    MUX6502 #(2) mux_pcl_377 (.o(o[377]), .i(i[377]), .s({i[898],i[414]}), .d({i[993],i[121]}));
    MUX6502 #(2) mux_pch_1551 (.o(o[1551]), .i(i[1551]), .s({i[48],i[741]}), .d({i[13],~i[751]}));
    wire sb_local_1001 = i[801]|i[1263]|~i[621]|i[1333]|i[1698];
    wire idb_local_493 = i[1331]|~i[398]|~i[878]|i[710]&~i[1221]|~i[1577];
    wire adh_local_1539 = ~i[1683]|~i[598]|i[710]&~i[1020];
    wire db2sb_1001 = idb_local_493 & ~i[1527];
    wire sb2db_493 = sb_local_1001 & ~i[1527];
    wire adh2sb_1001 = adh_local_1539 & ~i[1602];
    wire sb2adh_1539 = sb_local_1001 & ~i[1602];
    MUX6502 #(8) mux_sb_1001 (.o(o[1001]), .i(i[1001]), .s({i[943],i[801],i[1263],~i[621],i[1333],i[1698],db2sb_1001,adh2sb_1001}), .d({i[657],i[843],i[777],~i[181],~i[1123],i[1653],i[493],i[1539]}));
    MUX6502 #(7) mux_idb_493 (.o(o[493]), .i(i[493]), .s({i[943],i[1331],~i[398],~i[878],i[710]&~i[1221],sb2db_493,~i[1577]}), .d({i[657],i[1653],i[663],~i[536],~i[529],i[1001],i[69]}));
    MUX6502 #(6) mux_adl_1299 (.o(o[1299]), .i(i[1299]), .s({i[943],~i[339],~i[745],~i[897],i[710]&~i[1121],i[558]}), .d({i[657],~i[181],~i[1123],~i[536],~i[529],i[558]}));
    MUX6502 #(5) mux_adh_1539 (.o(o[1539]), .i(i[1539]), .s({i[943],~i[1683],~i[598],i[710]&~i[1020], sb2adh_1539}), .d({i[657],i[558],i[663],~i[529],i[1001]}));
    MUX6502 #(2) mux_pcl_1611 (.o(o[1611]), .i(i[1611]), .s({i[898],i[414]}), .d({~i[536],i[1299]}));
    MUX6502 #(2) mux_pch_205 (.o(o[205]), .i(i[205]), .s({i[48],i[741]}), .d({i[1539],i[663]}));
    assign o[430] = (i[756]^i[412]) & i[899];
    assign o[1536] = ~(i[964]|i[732]);
    assign o[17] = ~(i[964]|i[732]);
    assign o[779] = ~((i[787]|i[1081]|~i[1219])&~i[197]);
    assign o[1035] = ~(i[943]|i[943]);
    assign o[1085] = ~(~i[197]&(~i[17]|~i[636]&i[1544])|~i[666]&i[197]);
    assign o[379] = ~((i[1581]|i[1570])&i[1472]);
    assign o[480] = ~((~i[334]|~i[675])&i[264]);
    assign o[1229] = ~((i[1670]|i[1704])&i[919]);
    assign o[484] = ~((i[1611]|i[1316])&i[1386]);
    assign o[1408] = ~((i[575]|i[1466])&i[1044]);
    assign o[1657] = ~((i[1334]|i[948])&i[523]);
    assign o[1402] = ~((i[502]|i[200])&i[293]);
    assign o[1631] = ~((i[1359]|i[1253])&i[1184]);
    assign o[1192] = ~((i[1551]|i[743])&i[609]);
    assign o[1073] = ~((i[410]|i[622])&i[344]);
    assign o[1099] = ~((i[1345]|i[1022])&i[1542]);
    assign o[629] = ~((~i[636]|~i[17])&i[480]|i[50]);
    assign o[696] = ~((i[1343]|i[877])&~i[660]|~i[357]);
    assign o[1372] = ~((i[1691]|i[319])&(i[1610]|i[388])|~i[1450]);
    assign o[333] = ~((i[757]|i[1459])&(i[570]|i[269])|~i[1450]);
    assign o[1303] = ~((i[1601]|i[1540])&i[335]);
    assign o[1393] = ~i[873];
    assign o[945] = ~i[1288];
    assign o[1591] = ~i[1418];
    assign o[650] = ~i[823];
    assign o[175] = ~i[1266];
    assign o[82] = ~i[527];
    assign o[1005] = ~i[222];
    assign o[1349] = ~i[158];
    assign o[1331] = ~i[266]&i[710]&~i[943];
    assign o[1698] = ~i[55]&i[710]&~i[943];
    assign o[1263] = ~i[1404]&i[710]&~i[943];
    assign o[801] = ~i[1113]&i[710]&~i[943];
    assign o[414] = ~i[265]&i[710]&~i[943];
    assign o[654] = ~i[796]&i[710]&~i[943];
    assign o[859] = ~i[688]&i[710]&~i[943];
    assign o[325] = ~i[460]&i[710]&~i[943];
    assign o[984] = ~i[1027]&i[710]&~i[943];
    assign o[549] = ~i[360]&i[710]&~i[943];
    assign o[1068] = ~i[805]&i[710]&~i[943];
    assign o[437] = ~i[1477]&i[710]&~i[943];
    assign o[1186] = ~i[459]&i[710]&~i[943];
    assign o[48] = ~i[1162]&i[710]&~i[943];
    assign o[741] = ~i[1509]&i[710]&~i[943];
    assign o[534] = ~i[1505]&i[710]&~i[943];
    assign o[898] = ~i[509]&i[710]&~i[943];
    assign o[874] = ~i[521]&i[710]&~i[943];
    assign o[710] = ~i[1171];
    assign o[943] =  i[1171];
    assign o[297] = ~(i[1032]|~i[1297]&i[943]);
    assign o[1032] = ~(i[297]|i[1297]&i[943]);
    assign o[854] = ~(i[975]|~i[159]&i[943]);
    assign o[330] = ~(i[807]|i[103]&i[943]);
    assign o[807] = ~(i[330]|~i[103]&i[943]);
    assign o[975] = ~(i[854]|i[159]&i[943]);
    assign o[539] = ~i[666];
    assign o[1156] = ~i[402];
    assign o[736] = i[710]&~i[190]? i[1630] : i[736];
    assign o[148] = i[710]&~i[610]? i[52] : i[148];
    assign o[451] = i[710]&~i[190]? i[1282] : i[451];
    assign o[1340] = i[710]&~i[190]? i[1242] : i[1340];
    assign o[211] = i[710]&~i[190]? i[684] : i[211];
    assign o[1493] = i[710]&~i[190]? i[1299] : i[1493];
    assign o[1443] = i[710]&~i[610]? i[1651] : i[1443];
    assign o[195] = i[710]&~i[610]? i[1539] : i[195];
    assign o[887] = i[710]&~i[190]? i[121] : i[887];
    assign o[230] = i[710]&~i[610]? i[407] : i[230];
    assign o[399] = i[710]&~i[610]? i[315] : i[399];
    assign o[349] = i[710]&~i[610]? i[483] : i[349];
    assign o[672] = i[710]&~i[610]? i[13] : i[672];
    assign o[268] = i[710]&~i[190]? i[413] : i[268];
    assign o[435] = i[710]&~i[190]? i[1437] : i[435];
    assign o[1237] = i[710]&~i[610]? i[1160] : i[1237];
    assign o[1532] = i[874]? i[1188] : i[654]? ~i[828] : i[1532];
    assign o[828] = i[943]? ~i[1532] : i[828];
    assign o[1098] = i[874]? i[166] : i[654]? ~i[601] : i[1098];
    assign o[601] = i[943]? ~i[1098] : i[601];
    assign o[1435] = i[874]? i[1001] : i[654]? ~i[181] : i[1435];
    assign o[181] = i[943]? ~i[1435] : i[181];
    assign o[1702] = i[874]? i[1405] : i[654]? ~i[1603] : i[1702];
    assign o[1603] = i[943]? ~i[1702] : i[1603];
    assign o[1403] = i[874]? i[54] : i[654]? ~i[418] : i[1403];
    assign o[418] = i[943]? ~i[1403] : i[418];
    assign o[1212] = i[874]? i[1336] : i[654]? ~i[1029] : i[1212];
    assign o[1029] = i[943]? ~i[1212] : i[1029];
    assign o[81] = i[874]? i[1287] : i[654]? ~i[752] : i[81];
    assign o[752] = i[943]? ~i[81] : i[752];
    assign o[183] = i[874]? i[1150] : i[654]? ~i[1064] : i[183];
    assign o[1064] = i[943]? ~i[183] : i[1064];
    assign o[737] = i[534]? i[54] : i[737];
    assign o[1653] = i[534]? i[1494] : i[1653];
    assign o[305] = i[325]? i[1188] : i[305];
    assign o[978] = i[534]? i[450] : i[978];
    assign o[85] = i[1186]? i[1405] : i[85];
    assign o[727] = i[534]? i[1405] : i[727];
    assign o[989] = i[325]? i[1405] : i[989];
    assign o[448] = i[1186]? i[1336] : i[448];
    assign o[1] = i[1186]? i[1287] : i[1];
    assign o[162] = i[534]? i[1475] : i[162];
    assign o[615] = i[325]? i[166] : i[615];
    assign o[1216] = i[1186]? i[54] : i[1216];
    assign o[589] = i[1186]? i[166] : i[589];
    assign o[64] = i[325]? i[54] : i[64];
    assign o[1148] = i[325]? i[1150] : i[1148];
    assign o[1136] = i[534]? i[679] : i[1136];
    assign o[98] = i[1186]? i[1150] : i[98];
    assign o[115] = i[325]? i[1336] : i[115];
    assign o[573] = i[325]? i[1287] : i[573];
    assign o[1648] = i[1186]? i[1188] : i[1648];
    assign o[1234] = i[534]? i[1009] : i[1234];
    assign o[777] = i[1186]? i[1001] : i[777];
    assign o[843] = i[325]? i[1001] : i[843];
    assign o[858] = i[534]? i[263] : i[858];
    assign o[1609] = i[710]&i[879]? i[928] : i[1609];
    assign o[1675] = i[710]&i[879]? i[1309] : i[1675];
    assign o[1620] = i[710]&i[879]? ~i[1587] : i[1620];
    assign o[541] = i[710]&i[879]? ~i[1410] : i[541];
    assign o[1300] = i[710]&i[879]? ~i[1671] : i[1300];
    assign o[119] = i[710]&i[879]? ~i[809] : i[119];
    assign o[310] = i[710]&i[879]? ~i[1622] : i[310];
    assign o[927] = i[710]&i[879]? ~i[540] : i[927];
    MUX6502 #(5) mux_alu_out_68 (.o(o[68]), .i(i[68]), .s({~i[226]&i[943],~i[1674]&i[943],~i[95]&i[943],~i[101]&i[943],~i[1529]&i[943]}), .d({i[1318],i[1197],i[1084],i[1459],i[336]}));
    MUX6502 #(5) mux_alu_out_276 (.o(o[276]), .i(i[276]), .s({~i[1674]&i[943],~i[95]&i[943],~i[101]&i[943],~i[1529]&i[943],~i[226]&i[943]}), .d({i[22],i[1691],i[701],i[681],i[350]}));
    MUX6502 #(5) mux_alu_out_495 (.o(o[495]), .i(i[495]), .s({~i[1674]&i[943],~i[95]&i[943],~i[101]&i[943],~i[226]&i[943],~i[1529]&i[943]}), .d({i[274],i[649],~i[640],i[1063],i[350]}));
    MUX6502 #(5) mux_alu_out_893 (.o(o[893]), .i(i[893]), .s({~i[1674]&i[943],~i[226]&i[943],~i[95]&i[943],~i[101]&i[943],~i[1529]&i[943]}), .d({i[486],i[336],i[1632],~i[1220],i[477]}));
    MUX6502 #(5) mux_alu_out_394 (.o(o[394]), .i(i[394]), .s({~i[1674]&i[943],~i[1529]&i[943],~i[95]&i[943],~i[101]&i[943],~i[226]&i[943]}), .d({i[371],i[1628],i[143],i[1525],i[841]}));
    MUX6502 #(5) mux_alu_out_697 (.o(o[697]), .i(i[697]), .s({~i[95]&i[943],~i[101]&i[943],~i[1674]&i[943],~i[226]&i[943],~i[1529]&i[943]}), .d({i[155],~i[425],i[965],i[681],i[841]}));
    MUX6502 #(5) mux_alu_out_1490 (.o(o[1490]), .i(i[1490]), .s({~i[226]&i[943],~i[1674]&i[943],~i[101]&i[943],~i[1529]&i[943],~i[95]&i[943]}), .d({i[477],i[651],i[308],i[1063],i[404]}));
    MUX6502 #(5) mux_alu_out_1123 (.o(o[1123]), .i(i[1123]), .s({~i[1529]&i[943],~i[101]&i[943],~i[95]&i[943],~i[1674]&i[943],~i[226]&i[943]}), .d({i[1318],~i[1241],i[1398],i[532],i[657]}));
    MUX6502 #(2) mux_alua_1627 (.o(o[1627]), .i(i[1627]), .s({i[549],i[984]}), .d({i[1336],i[558]}));
    MUX6502 #(3) mux_alub_235 (.o(o[235]), .i(i[235]), .s({ i[1068],i[859],i[437]}), .d({~i[833],i[833],i[121]}));
    assign o[1084] = ~(i[235]|i[1627]);
    assign o[336] = ~(i[235]&i[1627]);
    MUX6502 #(2) mux_alua_1522 (.o(o[1522]), .i(i[1522]), .s({i[549],i[984]}), .d({i[1001],i[558]}));
    MUX6502 #(3) mux_alub_1535 (.o(o[1535]), .i(i[1535]), .s({ i[1068],i[859],i[437]}), .d({~i[493],i[493],i[1299]}));
    assign o[1398] = ~(i[1535]|i[1522]);
    assign o[1318] = ~(i[1535]&i[1522]);
    MUX6502 #(2) mux_alua_1332 (.o(o[1332]), .i(i[1332]), .s({i[549],i[984]}), .d({i[1287],i[558]}));
    MUX6502 #(3) mux_alub_704 (.o(o[704]), .i(i[704]), .s({ i[1068],i[859],i[437]}), .d({~i[1473],i[1473],i[1242]}));
    assign o[1691] = ~(i[704]|i[1332]);
    assign o[681] = ~(i[704]&i[1332]);
    MUX6502 #(2) mux_alua_1142 (.o(o[1142]), .i(i[1142]), .s({i[549],i[984]}), .d({i[1405],i[558]}));
    MUX6502 #(3) mux_alub_1645 (.o(o[1645]), .i(i[1645]), .s({ i[1068],i[859],i[437]}), .d({~i[892],i[892],i[1437]}));
    assign o[404] = ~(i[1645]|i[1142]);
    assign o[1063] = ~(i[1645]&i[1142]);
    MUX6502 #(2) mux_alua_1248 (.o(o[1248]), .i(i[1248]), .s({i[549],i[984]}), .d({i[1150],i[558]}));
    MUX6502 #(3) mux_alub_1432 (.o(o[1432]), .i(i[1432]), .s({ i[1068],i[859],i[437]}), .d({~i[991],i[991],i[1282]}));
    assign o[155] = ~(i[1432]|i[1248]);
    assign o[841] = ~(i[1432]&i[1248]);
    MUX6502 #(2) mux_alua_1167 (.o(o[1167]), .i(i[1167]), .s({i[549],i[984]}), .d({i[54],i[558]}));
    MUX6502 #(3) mux_alub_977 (.o(o[977]), .i(i[977]), .s({ i[1068],i[859],i[437]}), .d({~i[1108],i[1108],i[413]}));
    assign o[143] = ~(i[977]|i[1167]);
    assign o[1628] = ~(i[977]&i[1167]);
    MUX6502 #(2) mux_alua_530 (.o(o[530]), .i(i[530]), .s({i[549],i[984]}), .d({i[166],i[558]}));
    MUX6502 #(3) mux_alub_1678 (.o(o[1678]), .i(i[1678]), .s({ i[1068],i[859],i[437]}), .d({~i[1503],i[1503],i[1630]}));
    assign o[1632] = ~(i[1678]|i[530]);
    assign o[477] = ~(i[1678]&i[530]);
    MUX6502 #(2) mux_alua_1680 (.o(o[1680]), .i(i[1680]), .s({i[549],i[984]}), .d({i[1188],i[558]}));
    MUX6502 #(3) mux_alub_96 (.o(o[96]), .i(i[96]), .s({ i[1068],i[859],i[437]}), .d({~i[1302],i[1302],i[684]}));
    assign o[649] = ~(i[96]|i[1680]);
    assign o[350] = ~(i[96]&i[1680]);
    assign o[758] = i[943] ? ~i[1005] : i[758];
    assign o[361] = i[943] ? ~i[82] : i[361];
    assign o[688] = i[943] ? i[1594] : i[688];
    assign o[1565] = i[943] ? i[1450] : i[1565];
    assign o[1027] = i[943] ? i[1649] : i[1027];
    assign o[760] = i[943] ? i[629] : i[760];
    assign o[610] = i[943] ? i[696] : i[610];
    assign o[1436] = i[943] ? i[1155] : i[1436];
    assign o[1078] = i[943] ? i[334] : i[1078];
    assign o[1341] = i[943] ? i[695] : i[1341];
    assign o[56] = i[943] ? i[824] : i[56];
    assign o[1485] = i[943] ? ~i[945] : i[1485];
    assign o[1338] = i[710] ? i[720] : i[1338];
    assign o[449] = i[943] ? ~i[1395] : i[449];
    assign o[45] = i[943] ? i[1712] : i[45];
    assign o[1252] = i[943] ? i[1374] : i[1252];
    assign o[899] = i[943] ? i[19] : i[899];
    assign o[1126] = i[943] ? i[1465] : i[1126];
    assign o[680] = i[943] ? i[1688] : i[680];
    assign o[415] = i[943] ? i[1196] : i[415];
    assign o[968] = i[943] ? ~i[366] : i[968];
    assign o[974] = i[943] ? i[774] : i[974];
    assign o[1404] = i[943] ? i[1106] : i[1404];
    assign o[1577] = i[943] ? i[1391] : i[1577];
    assign o[339] = i[943] ? i[632] : i[339];
    assign o[685] = i[943] ? ~i[1447] : i[685];
    assign o[596] = i[943] ? i[1085] : i[596];
    assign o[1291] = i[710] ? i[1382] : i[1291];
    assign o[527] = i[710] ? ~i[991] : i[527];
    assign o[666] = i[710] ? i[1380] : i[666];
    assign o[47] = i[710] ? ~i[865] : i[47];
    assign o[1221] = i[943] ? i[104] : i[1221];
    assign o[215] = i[943] ? i[1379] : i[215];
    assign o[759] = i[710] ? i[187] : i[759];
    assign o[1693] = i[943] ? i[264] : i[1693];
    assign o[799] = i[943] ? i[264] : i[799];
    assign o[40] = i[943] ? i[1575] : i[40];
    assign o[1602] = i[943] ? i[506] : i[1602];
    assign o[94] = i[710] ? ~i[1672] : i[94];
    assign o[456] = i[943] ? i[191] : i[456];
    assign o[1121] = i[943] ? i[1225] : i[1121];
    assign o[1530] = i[943] ? ~i[756] : i[1530];
    assign o[780] = i[943] ? i[1229] : i[780];
    assign o[554] = i[943] ? i[17] : i[554];
    assign o[581] = i[943] ? i[599] : i[581];
    assign o[627] = i[710] ? i[566] : i[627];
    assign o[1579] = i[710] ? i[187] : i[1579];
    assign o[338] = i[943] ? i[252] : i[338];
    assign o[199] = i[943] ? i[327] : i[199];
    assign o[1269] = i[943] ? ~i[636] : i[1269];
    assign o[158] = i[710] ? ~i[493] : i[158];
    assign o[537] = i[943] ? ~i[666] : i[537];
    assign o[576] = i[943] ? ~i[82] : i[576];
    assign o[18] = i[710] ? i[468] : i[18];
    assign o[1699] = i[943] ? ~i[94] : i[1699];
    assign o[706] = i[943] ? i[678] : i[706];
    assign o[536] = i[943] ? i[484] : i[536];
    assign o[940] = i[943] ? i[378] : i[940];
    assign o[126] = i[943] ? i[1486] : i[126];
    assign o[1411] = i[943] ? i[515] : i[1411];
    assign o[751] = i[943] ? i[1192] : i[751];
    assign o[590] = i[710] ? i[1178] : i[590];
    assign o[868] = i[943] ? i[1631] : i[868];
    assign o[360] = i[943] ? ~i[1649] : i[360];
    assign o[1505] = i[943] ? i[1455] : i[1505];
    assign o[460] = i[943] ? i[616] : i[460];
    assign o[151] = i[943] ? ~i[24] : i[151];
    assign o[526] = i[943] ? i[1500] : i[526];
    assign o[1533] = i[710] ? i[1180] : i[1533];
    assign o[529] = i[943] ? ~i[1349] : i[529];
    assign o[1509] = i[943] ? ~i[272] : i[1509];
    assign o[1266] = i[710] ? ~i[1503] : i[1266];
    assign o[1176] = i[943] ? ~i[1409] : i[1176];
    assign o[671] = i[710] ? ~i[197] : i[671];
    assign o[99] = i[943] ? ~i[348] : i[99];
    assign o[1652] = i[943] ? i[385] : i[1652];
    assign o[357] = i[943] ? ~i[1465] : i[357];
    assign o[1442] = i[943] ? ~i[69] : i[1442];
    assign o[1177] = i[943] ? i[1069] : i[1177];
    assign o[993] = i[943] ? i[20] : i[993];
    assign o[190] = i[943] ? i[1101] : i[190];
    assign o[24] = i[710] ? i[1039] : i[24];
    assign o[1333] = i[943] ? i[80] : i[1333];
    assign o[1409] = i[710] ? i[916] : i[1409];
    assign o[1020] = i[943] ? i[1705] : i[1020];
    assign o[1274] = i[710] ? ~i[1699] : i[1274];
    assign o[55] = i[943] ? i[11] : i[55];
    assign o[644] = i[710] ? i[428] : i[644];
    assign o[521] = i[943] ? i[1358] : i[521];
    assign o[1326] = i[943] ? i[1073] : i[1326];
    assign o[69] = i[710] ? i[1181] : i[69];
    assign o[663] = i[943] ? i[1209] : i[663];
    assign o[398] = i[943] ? i[824] : i[398];
    assign o[1124] = i[943] ? i[1065] : i[1124];
    assign o[1272] = i[710] ? i[197] : i[1272];
    assign o[1574] = i[943] ? i[1228] : i[1574];
    assign o[1438] = i[943] ? i[504] : i[1438];
    assign o[1360] = i[710] ? i[1091] : i[1360];
    assign o[1713] = i[943] ? i[501] : i[1713];
    assign o[1276] = i[710] ? i[197] : i[1276];
    assign o[1049] = i[943] ? i[160] : i[1049];
    assign o[73] = i[943] ? ~i[366] : i[73];
    assign o[1102] = i[943] ? i[1099] : i[1102];
    assign o[512] = i[943] ? i[1130] : i[512];
    assign o[745] = i[943] ? i[674] : i[745];
    assign o[114] = i[943] ? i[1402] : i[114];
    assign o[897] = i[943] ? i[1211] : i[897];
    assign o[265] = i[943] ? i[182] : i[265];
    assign o[1161] = i[710] ? ~i[1380] : i[1161];
    assign o[1528] = i[710] ? i[1215] : i[1528];
    assign o[50] = i[710] ? i[1350] : i[50];
    assign o[1581] = i[710] ? i[1275] : i[1581];
    assign o[1472] = i[710] ? i[827] : i[1472];
    assign o[226] = i[710] ? ~i[968] : i[226];
    assign o[621] = i[943] ? i[1586] : i[621];
    assign o[266] = i[943] ? i[1037] : i[266];
    assign o[1149] = i[710] ? i[1368] : i[1149];
    assign o[1051] = i[943] ? ~i[32] : i[1051];
    assign o[1321] = i[943] ? i[32] : i[1321];
    assign o[1284] = i[943] ? ~i[650] : i[1284];
    assign o[560] = i[943] ? ~i[1327] : i[560];
    assign o[1452] = i[943] ? ~i[698] : i[1452];
    assign o[469] = i[943] ? i[875] : i[469];
    assign o[559] = i[943] ? ~i[1272] : i[559];
    assign o[44] = i[943] ? ~i[1625] : i[44];
    assign o[1606] = i[710] ? i[472] : i[1606];
    assign o[1624] = i[710] ? i[197] : i[1624];
    assign o[88] = i[943] ? i[522] : i[88];
    assign o[982] = i[943] ? ~i[837] : i[982];
    assign o[865] = i[943] ? ~i[89] : i[865];
    assign o[1431] = i[943] ? i[1134] : i[1431];
    assign o[832] = i[943] ? i[586] : i[832];
    assign o[294] = i[943] ? i[14] : i[294];
    assign o[675] = i[710] ? i[330] : i[675];
    assign o[599] = i[710] ? ~i[561] : i[599];
    assign o[1669] = i[943] ? ~i[1591] : i[1669];
    assign o[1690] = i[943] ? ~i[1349] : i[1690];
    assign o[955] = i[943] ? ~i[945] : i[955];
    assign o[698] = i[710] ? i[1290] : i[698];
    assign o[796] = i[943] ? ~i[1358] : i[796];
    assign o[1104] = i[943] ? i[889] : i[1104];
    assign o[1283] = i[943] ? i[340] : i[1283];
    assign o[1008] = i[943] ? i[169] : i[1008];
    assign o[1625] = i[710] ? i[299] : i[1625];
    assign o[222] = i[710] ? ~i[1108] : i[222];
    assign o[1011] = i[943] ? ~i[666] : i[1011];
    assign o[1036] = i[943] ? ~i[1395] : i[1036];
    assign o[598] = i[943] ? i[176] : i[598];
    assign o[820] = i[943] ? i[1657] : i[820];
    assign o[1529] = i[710] ? ~i[1574] : i[1529];
    assign o[95] = i[710] ? ~i[88] : i[95];
    assign o[1131] = i[943] ? i[1352] : i[1131];
    assign o[1418] = i[710] ? ~i[833] : i[1418];
    assign o[197] = i[943] ? i[944] : i[197];
    assign o[562] = i[710] ? ~i[1032] : i[562];
    assign o[509] = i[943] ? ~i[182] : i[509];
    assign o[597] = i[710] ? ~i[799] : i[597];
    assign o[1288] = i[710] ? ~i[1473] : i[1288];
    assign o[792] = i[710] ? i[851] : i[792];
    assign o[1447] = i[710] ? i[262] : i[1447];
    assign o[1537] = i[943] ? ~i[1591] : i[1537];
    assign o[369] = i[943] ? ~i[1393] : i[369];
    assign o[894] = i[943] ? ~i[650] : i[894];
    assign o[829] = i[943] ? ~i[175] : i[829];
    assign o[902] = i[710] ? i[197] : i[902];
    assign o[823] = i[710] ? ~i[1302] : i[823];
    assign o[756] = i[710] ? i[626] : i[756];
    assign o[683] = i[943] ? i[1225] : i[683];
    assign o[1373] = i[943] ? i[188] : i[1373];
    assign o[1132] = i[710] ? i[1087] : i[1132];
    assign o[1607] = i[943] ? ~i[627] : i[1607];
    assign o[1395] = i[710] ? i[854] : i[1395];
    assign o[960] = i[943] ? i[1081] : i[960];
    assign o[614] = i[943] ? ~i[1107] : i[614];
    assign o[848] = i[943] ? i[473] : i[848];
    assign o[223] = i[710] ? i[1215] : i[223];
    assign o[1679] = i[710] ? i[197] : i[1679];
    assign o[116] = i[943] ? ~i[1005] : i[116];
    assign o[459] = i[943] ? i[844] : i[459];
    assign o[164] = i[943] ? i[333] : i[164];
    assign o[1061] = i[943] ? i[207] : i[1061];
    assign o[498] = i[943] ? ~i[175] : i[498];
    assign o[1113] = i[943] ? i[1717] : i[1113];
    assign o[402] = i[710] ? i[187] : i[402];
    assign o[15] = i[943] ? i[474] : i[15];
    assign o[1683] = i[943] ? i[1090] : i[1683];
    assign o[878] = i[943] ? ~i[1338] : i[878];
    assign o[1553] = i[710] ? i[845] : i[1553];
    assign o[323] = i[710] ? i[959] : i[323];
    assign o[729] = i[943] ? i[261] : i[729];
    assign o[1477] = i[943] ? i[604] : i[1477];
    assign o[1450] = i[710] ? ~i[680] : i[1450];
    assign o[1674] = i[710] ? ~i[415] : i[1674];
    assign o[873] = i[710] ? ~i[892] : i[873];
    assign o[170] = i[943] ? i[1117] : i[170];
    assign o[561] = i[943] ? i[29] : i[561];
    assign o[408] = i[943] ? i[1308] : i[408];
    assign o[101] = i[710] ? ~i[982] : i[101];
    assign o[805] = i[943] ? i[779] : i[805];
    assign o[393] = i[943] ? i[1179] : i[393];
    assign o[1570] = i[710] ? i[430] : i[1570];
    assign o[653] = i[710] ? ~i[1438] : i[653];
    assign o[1516] = i[943] ? ~i[1393] : i[1516];
    assign o[1673] = i[943] ? i[1646] : i[1673];
    assign o[443] = i[943] ? i[513] : i[443];
    assign o[785] = i[710] ? ~i[73] : i[785];
    assign o[1527] = i[943] ? i[1347] : i[1527];
    assign o[348] = i[710] ? i[1495] : i[348];
    assign o[1162] = i[943] ? i[272] : i[1162];
    assign o[32] = i[710] ? i[1082] : i[32];
    // Unused nets
    assign o[1724:1722] = 0;
    assign o[1720:1718] = 0;
    assign o[1715:1714] = 0;
    assign o[1711]      = 0;
    assign o[1709:1706] = 0;
    assign o[1703]      = 0;
    assign o[1701:1700] = 0;
    assign o[1697:1694] = 0;
    assign o[1692]      = 0;
    assign o[1689]      = 0;
    assign o[1687:1684] = 0;
    assign o[1682:1681] = 0;
    assign o[1677:1676] = 0;
    assign o[1672]      = 0;
    assign o[1668:1666] = 0;
    assign o[1663:1659] = 0;
    assign o[1656:1654] = 0;
    assign o[1650]      = 0;
    assign o[1647]      = 0;
    assign o[1644:1643] = 0;
    assign o[1641:1633] = 0;
    assign o[1626]      = 0;
    assign o[1623]      = 0;
    assign o[1621]      = 0;
    assign o[1618:1615] = 0;
    assign o[1613]      = 0;
    assign o[1608]      = 0;
    assign o[1605:1604] = 0;
    assign o[1600:1595] = 0;
    assign o[1593:1592] = 0;
    assign o[1590]      = 0;
    assign o[1588]      = 0;
    assign o[1585:1583] = 0;
    assign o[1580]      = 0;
    assign o[1578]      = 0;
    assign o[1576]      = 0;
    assign o[1573:1571] = 0;
    assign o[1568:1566] = 0;
    assign o[1564:1563] = 0;
    assign o[1561:1558] = 0;
    assign o[1556:1554] = 0;
    assign o[1552]      = 0;
    assign o[1550:1545] = 0;
    assign o[1541]      = 0;
    assign o[1538]      = 0;
    assign o[1534]      = 0;
    assign o[1531]      = 0;
    assign o[1526]      = 0;
    assign o[1523]      = 0;
    assign o[1521]      = 0;
    assign o[1519:1518] = 0;
    assign o[1515:1513] = 0;
    assign o[1511:1510] = 0;
    assign o[1508:1506] = 0;
    assign o[1502:1501] = 0;
    assign o[1499:1496] = 0;
    assign o[1492:1491] = 0;
    assign o[1489:1488] = 0;
    assign o[1484:1483] = 0;
    assign o[1481:1479] = 0;
    assign o[1476]      = 0;
    assign o[1474]      = 0;
    assign o[1471:1467] = 0;
    assign o[1463:1460] = 0;
    assign o[1458]      = 0;
    assign o[1456]      = 0;
    assign o[1454:1453] = 0;
    assign o[1451]      = 0;
    assign o[1449]      = 0;
    assign o[1446:1444] = 0;
    assign o[1441:1439] = 0;
    assign o[1434]      = 0;
    assign o[1429]      = 0;
    assign o[1427:1426] = 0;
    assign o[1424:1421] = 0;
    assign o[1419]      = 0;
    assign o[1417:1412] = 0;
    assign o[1407:1406] = 0;
    assign o[1401:1399] = 0;
    assign o[1397]      = 0;
    assign o[1394]      = 0;
    assign o[1392]      = 0;
    assign o[1390:1387] = 0;
    assign o[1384:1383] = 0;
    assign o[1381]      = 0;
    assign o[1378:1375] = 0;
    assign o[1370:1369] = 0;
    assign o[1367:1361] = 0;
    assign o[1357:1356] = 0;
    assign o[1354:1353] = 0;
    assign o[1351]      = 0;
    assign o[1348]      = 0;
    assign o[1346]      = 0;
    assign o[1344]      = 0;
    assign o[1339]      = 0;
    assign o[1335]      = 0;
    assign o[1330:1328] = 0;
    assign o[1325]      = 0;
    assign o[1323:1322] = 0;
    assign o[1320:1319] = 0;
    assign o[1317]      = 0;
    assign o[1315]      = 0;
    assign o[1313]      = 0;
    assign o[1310]      = 0;
    assign o[1307:1304] = 0;
    assign o[1301]      = 0;
    assign o[1298:1295] = 0;
    assign o[1292]      = 0;
    assign o[1289]      = 0;
    assign o[1281:1277] = 0;
    assign o[1273]      = 0;
    assign o[1271:1270] = 0;
    assign o[1267]      = 0;
    assign o[1265:1264] = 0;
    assign o[1262:1260] = 0;
    assign o[1258]      = 0;
    assign o[1256:1254] = 0;
    assign o[1251:1249] = 0;
    assign o[1247]      = 0;
    assign o[1245:1244] = 0;
    assign o[1240:1238] = 0;
    assign o[1236:1235] = 0;
    assign o[1232:1230] = 0;
    assign o[1227]      = 0;
    assign o[1224:1222] = 0;
    assign o[1218]      = 0;
    assign o[1214]      = 0;
    assign o[1208:1206] = 0;
    assign o[1203:1198] = 0;
    assign o[1195:1193] = 0;
    assign o[1191:1189] = 0;
    assign o[1187]      = 0;
    assign o[1183:1182] = 0;
    assign o[1175:1174] = 0;
    assign o[1172:1171] = 0;
    assign o[1169]      = 0;
    assign o[1166:1163] = 0;
    assign o[1158:1157] = 0;
    assign o[1153:1151] = 0;
    assign o[1147:1143] = 0;
    assign o[1141:1140] = 0;
    assign o[1138]      = 0;
    assign o[1135]      = 0;
    assign o[1133]      = 0;
    assign o[1129:1127] = 0;
    assign o[1125]      = 0;
    assign o[1120:1118] = 0;
    assign o[1116]      = 0;
    assign o[1114]      = 0;
    assign o[1112]      = 0;
    assign o[1110]      = 0;
    assign o[1105]      = 0;
    assign o[1103]      = 0;
    assign o[1100]      = 0;
    assign o[1096:1092] = 0;
    assign o[1089:1088] = 0;
    assign o[1083]      = 0;
    assign o[1080:1079] = 0;
    assign o[1076:1075] = 0;
    assign o[1072:1070] = 0;
    assign o[1067:1066] = 0;
    assign o[1062]      = 0;
    assign o[1060:1058] = 0;
    assign o[1056]      = 0;
    assign o[1054:1053] = 0;
    assign o[1048:1045] = 0;
    assign o[1043:1040] = 0;
    assign o[1038]      = 0;
    assign o[1034:1033] = 0;
    assign o[1030]      = 0;
    assign o[1028]      = 0;
    assign o[1026:1024] = 0;
    assign o[1021]      = 0;
    assign o[1017:1012] = 0;
    assign o[1010]      = 0;
    assign o[1007:1006] = 0;
    assign o[1004:1002] = 0;
    assign o[1000:997]  = 0;
    assign o[995:994]   = 0;
    assign o[992]       = 0;
    assign o[990]       = 0;
    assign o[988:987]   = 0;
    assign o[983]       = 0;
    assign o[981]       = 0;
    assign o[976]       = 0;
    assign o[973:969]   = 0;
    assign o[967:966]   = 0;
    assign o[963:961]   = 0;
    assign o[958:956]   = 0;
    assign o[954:951]   = 0;
    assign o[949]       = 0;
    assign o[947]       = 0;
    assign o[942:941]   = 0;
    assign o[939:934]   = 0;
    assign o[931]       = 0;
    assign o[929]       = 0;
    assign o[926]       = 0;
    assign o[924:920]   = 0;
    assign o[918]       = 0;
    assign o[915:905]   = 0;
    assign o[903]       = 0;
    assign o[901]       = 0;
    assign o[896:895]   = 0;
    assign o[891:890]   = 0;
    assign o[888]       = 0;
    assign o[886:883]   = 0;
    assign o[881:880]   = 0;
    assign o[872:869]   = 0;
    assign o[867:866]   = 0;
    assign o[864:861]   = 0;
    assign o[856:855]   = 0;
    assign o[853:852]   = 0;
    assign o[850:849]   = 0;
    assign o[846]       = 0;
    assign o[842]       = 0;
    assign o[840:838]   = 0;
    assign o[836:834]   = 0;
    assign o[831:830]   = 0;
    assign o[826:825]   = 0;
    assign o[821]       = 0;
    assign o[818]       = 0;
    assign o[816:814]   = 0;
    assign o[808]       = 0;
    assign o[806]       = 0;
    assign o[803:802]   = 0;
    assign o[800]       = 0;
    assign o[798:797]   = 0;
    assign o[795:793]   = 0;
    assign o[789:788]   = 0;
    assign o[783]       = 0;
    assign o[778]       = 0;
    assign o[776:775]   = 0;
    assign o[772:765]   = 0;
    assign o[763:761]   = 0;
    assign o[755]       = 0;
    assign o[749:746]   = 0;
    assign o[744]       = 0;
    assign o[742]       = 0;
    assign o[740]       = 0;
    assign o[738]       = 0;
    assign o[734:733]   = 0;
    assign o[731:730]   = 0;
    assign o[728]       = 0;
    assign o[726:721]   = 0;
    assign o[719:718]   = 0;
    assign o[716:713]   = 0;
    assign o[711]       = 0;
    assign o[709:707]   = 0;
    assign o[705]       = 0;
    assign o[703:702]   = 0;
    assign o[700:699]   = 0;
    assign o[694:692]   = 0;
    assign o[690:689]   = 0;
    assign o[687:686]   = 0;
    assign o[682]       = 0;
    assign o[676]       = 0;
    assign o[670:667]   = 0;
    assign o[662:661]   = 0;
    assign o[659:656]   = 0;
    assign o[652]       = 0;
    assign o[648:645]   = 0;
    assign o[643:641]   = 0;
    assign o[639:638]   = 0;
    assign o[635:633]   = 0;
    assign o[631]       = 0;
    assign o[628]       = 0;
    assign o[625:624]   = 0;
    assign o[619:617]   = 0;
    assign o[612:611]   = 0;
    assign o[608]       = 0;
    assign o[606:605]   = 0;
    assign o[603:602]   = 0;
    assign o[600]       = 0;
    assign o[593:591]   = 0;
    assign o[588:587]   = 0;
    assign o[585]       = 0;
    assign o[583:582]   = 0;
    assign o[580]       = 0;
    assign o[578:577]   = 0;
    assign o[574]       = 0;
    assign o[572:571]   = 0;
    assign o[569:567]   = 0;
    assign o[565:563]   = 0;
    assign o[558:556]   = 0;
    assign o[551]       = 0;
    assign o[548:547]   = 0;
    assign o[545]       = 0;
    assign o[543:542]   = 0;
    assign o[538]       = 0;
    assign o[535]       = 0;
    assign o[533]       = 0;
    assign o[531]       = 0;
    assign o[525:524]   = 0;
    assign o[520:517]   = 0;
    assign o[514]       = 0;
    assign o[511]       = 0;
    assign o[508:507]   = 0;
    assign o[505]       = 0;
    assign o[503]       = 0;
    assign o[500:499]   = 0;
    assign o[497:496]   = 0;
    assign o[494]       = 0;
    assign o[491:488]   = 0;
    assign o[485]       = 0;
    assign o[482:481]   = 0;
    assign o[478]       = 0;
    assign o[476:475]   = 0;
    assign o[471:470]   = 0;
    assign o[466:462]   = 0;
    assign o[458:457]   = 0;
    assign o[455:452]   = 0;
    assign o[445:444]   = 0;
    assign o[442:438]   = 0;
    assign o[436]       = 0;
    assign o[434:431]   = 0;
    assign o[429]       = 0;
    assign o[426]       = 0;
    assign o[424:419]   = 0;
    assign o[417:416]   = 0;
    assign o[411]       = 0;
    assign o[409]       = 0;
    assign o[406:405]   = 0;
    assign o[401:400]   = 0;
    assign o[397:395]   = 0;
    assign o[392:389]   = 0;
    assign o[387:386]   = 0;
    assign o[383]       = 0;
    assign o[381:380]   = 0;
    assign o[376:372]   = 0;
    assign o[368:367]   = 0;
    assign o[365:362]   = 0;
    assign o[359:358]   = 0;
    assign o[356:355]   = 0;
    assign o[353]       = 0;
    assign o[351]       = 0;
    assign o[346]       = 0;
    assign o[343]       = 0;
    assign o[341]       = 0;
    assign o[337]       = 0;
    assign o[332:331]   = 0;
    assign o[329:328]   = 0;
    assign o[326]       = 0;
    assign o[322:320]   = 0;
    assign o[318:316]   = 0;
    assign o[314:311]   = 0;
    assign o[306]       = 0;
    assign o[304]       = 0;
    assign o[300]       = 0;
    assign o[298]       = 0;
    assign o[296]       = 0;
    assign o[291:287]   = 0;
    assign o[284:282]   = 0;
    assign o[280]       = 0;
    assign o[278:277]   = 0;
    assign o[270]       = 0;
    assign o[255:253]   = 0;
    assign o[250:246]   = 0;
    assign o[244:236]   = 0;
    assign o[234]       = 0;
    assign o[232:231]   = 0;
    assign o[229:227]   = 0;
    assign o[225:224]   = 0;
    assign o[221:220]   = 0;
    assign o[217:216]   = 0;
    assign o[214:212]   = 0;
    assign o[210:208]   = 0;
    assign o[206]       = 0;
    assign o[203:201]   = 0;
    assign o[198]       = 0;
    assign o[196]       = 0;
    assign o[194]       = 0;
    assign o[189]       = 0;
    assign o[186:184]   = 0;
    assign o[178:177]   = 0;
    assign o[173:171]   = 0;
    assign o[168]       = 0;
    assign o[165]       = 0;
    assign o[163]       = 0;
    assign o[161]       = 0;
    assign o[159]       = 0;
    assign o[156]       = 0;
    assign o[154:153]   = 0;
    assign o[150:149]   = 0;
    assign o[147:146]   = 0;
    assign o[144]       = 0;
    assign o[141:135]   = 0;
    assign o[133:132]   = 0;
    assign o[130:127]   = 0;
    assign o[124:122]   = 0;
    assign o[120]       = 0;
    assign o[118:117]   = 0;
    assign o[113:105]   = 0;
    assign o[103:102]   = 0;
    assign o[100]       = 0;
    assign o[97]        = 0;
    assign o[93:89]     = 0;
    assign o[87:86]     = 0;
    assign o[83]        = 0;
    assign o[79:77]     = 0;
    assign o[75:74]     = 0;
    assign o[72:70]     = 0;
    assign o[67:66]     = 0;
    assign o[63:61]     = 0;
    assign o[59]        = 0;
    assign o[57]        = 0;
    assign o[51]        = 0;
    assign o[43:41]     = 0;
    assign o[39:37]     = 0;
    assign o[35:33]     = 0;
    assign o[31:30]     = 0;
    assign o[28:25]     = 0;
    assign o[23]        = 0;
    assign o[21]        = 0;
    assign o[16]        = 0;
    assign o[12]        = 0;
    assign o[9:5]       = 0;
    assign o[3:2]       = 0;
endmodule


module chip_6502 (
    input           clk,    // FPGA clock
    input           phi,    // 6502 clock
    input           res,
    input           so,
    input           rdy,
    input           nmi,
    input           irq,
    input     [7:0] dbi,
    output    [7:0] dbo,
    output          rw,
    output          sync,
    output   [15:0] ab);

    // Node states
    wire [`NUM_NODES-1:0] no;
    reg  [`NUM_NODES-1:0] ni, q;

    initial q = `NUM_NODES'b0;

    LOGIC logic_00 (.i(ni), .o(no));

    always @ (posedge clk)
        q <= no;

    always @* begin
        ni = q;

        ni[`NODE_vcc ]  = 1'b1;
        ni[`NODE_vss ]  = 1'b0;
        ni[`NODE_res ]  = res;
        ni[`NODE_clk0]  = phi;
        ni[`NODE_so  ]  = so;
        ni[`NODE_rdy ]  = rdy;
        ni[`NODE_nmi ]  = nmi;
        ni[`NODE_irq ]  = irq;

       {ni[`NODE_db7],ni[`NODE_db6],ni[`NODE_db5],ni[`NODE_db4],
        ni[`NODE_db3],ni[`NODE_db2],ni[`NODE_db1],ni[`NODE_db0]} = dbi[7:0];
    end

    assign dbo[7:0] = {
        no[`NODE_db7],no[`NODE_db6],no[`NODE_db5],no[`NODE_db4],
        no[`NODE_db3],no[`NODE_db2],no[`NODE_db1],no[`NODE_db0]
    };

    assign ab[15:0] = {
        no[`NODE_ab15], no[`NODE_ab14], no[`NODE_ab13], no[`NODE_ab12],
        no[`NODE_ab11], no[`NODE_ab10], no[`NODE_ab9],  no[`NODE_ab8],
        no[`NODE_ab7],  no[`NODE_ab6],  no[`NODE_ab5],  no[`NODE_ab4],
        no[`NODE_ab3],  no[`NODE_ab2],  no[`NODE_ab1],  no[`NODE_ab0]
    };

    assign rw   = no[`NODE_rw];
    assign sync = no[`NODE_sync];

endmodule


`undef NUM_NODES

`undef NODE_vcc
`undef NODE_vss
`undef NODE_cp1
`undef NODE_cp2

`undef NODE_res
`undef NODE_rw
`undef NODE_db0
`undef NODE_db1
`undef NODE_db3
`undef NODE_db2
`undef NODE_db5
`undef NODE_db4
`undef NODE_db7
`undef NODE_db6
`undef NODE_ab0
`undef NODE_ab1
`undef NODE_ab2
`undef NODE_ab3
`undef NODE_ab4
`undef NODE_ab5
`undef NODE_ab6
`undef NODE_ab7
`undef NODE_ab8
`undef NODE_ab9
`undef NODE_ab12
`undef NODE_ab13
`undef NODE_ab10
`undef NODE_ab11
`undef NODE_ab14
`undef NODE_ab15
`undef NODE_sync
`undef NODE_so
`undef NODE_clk0
`undef NODE_clk1out
`undef NODE_clk2out
`undef NODE_rdy
`undef NODE_nmi
`undef NODE_irq

`undef NODE_dpc11_SBADD
`undef NODE_dpc9_DBADD

`undef NODE_a0
`undef NODE_a1
`undef NODE_a2
`undef NODE_a3
`undef NODE_a4
`undef NODE_a5
`undef NODE_a6
`undef NODE_a7

`undef NODE_y0
`undef NODE_y1
`undef NODE_y2
`undef NODE_y3
`undef NODE_y4
`undef NODE_y5
`undef NODE_y6
`undef NODE_y7

`undef NODE_x0
`undef NODE_x1
`undef NODE_x2
`undef NODE_x3
`undef NODE_x4
`undef NODE_x5
`undef NODE_x6
`undef NODE_x7

`undef NODE_pcl0
`undef NODE_pcl1
`undef NODE_pcl2
`undef NODE_pcl3
`undef NODE_pcl4
`undef NODE_pcl5
`undef NODE_pcl6
`undef NODE_pcl7
`undef NODE_pch0
`undef NODE_pch1
`undef NODE_pch2
`undef NODE_pch3
`undef NODE_pch4
`undef NODE_pch5
`undef NODE_pch6
`undef NODE_pch7

`undef NODE_Reset0
`undef NODE_C1x5Reset

`undef NODE_idl0
`undef NODE_idl1
`undef NODE_idl2
`undef NODE_idl3
`undef NODE_idl4
`undef NODE_idl5
`undef NODE_idl6
`undef NODE_idl7

`undef NODE_sb0
`undef NODE_sb1
`undef NODE_sb2
`undef NODE_sb3
`undef NODE_sb4
`undef NODE_sb5
`undef NODE_sb6
`undef NODE_sb7

`undef NODE_adl0
`undef NODE_adl1
`undef NODE_adl2
`undef NODE_adl3
`undef NODE_adl4
`undef NODE_adl5
`undef NODE_adl6
`undef NODE_adl7

`undef NODE_adh0
`undef NODE_adh1
`undef NODE_adh2
`undef NODE_adh3
`undef NODE_adh4
`undef NODE_adh5
`undef NODE_adh6
`undef NODE_adh7

`undef NODE_idb0
`undef NODE_idb1
`undef NODE_idb2
`undef NODE_idb3
`undef NODE_idb4
`undef NODE_idb5
`undef NODE_idb6
`undef NODE_idb7

`undef NODE_abl0
`undef NODE_abl1
`undef NODE_abl2
`undef NODE_abl3
`undef NODE_abl4
`undef NODE_abl5
`undef NODE_abl6
`undef NODE_abl7

`undef NODE_abh0
`undef NODE_abh1
`undef NODE_abh2
`undef NODE_abh3
`undef NODE_abh4
`undef NODE_abh5
`undef NODE_abh6
`undef NODE_abh7

`undef NODE_s0
`undef NODE_s1
`undef NODE_s2
`undef NODE_s3
`undef NODE_s4
`undef NODE_s5
`undef NODE_s6
`undef NODE_s7

`undef NODE_ir0
`undef NODE_ir1
`undef NODE_ir2
`undef NODE_ir3
`undef NODE_ir4
`undef NODE_ir5
`undef NODE_ir6
`undef NODE_ir7

`undef NODE_clock1
`undef NODE_clock2
`undef NODE_t2
`undef NODE_t3
`undef NODE_t4
`undef NODE_t5

`undef NODE_alu0
`undef NODE_alu1
`undef NODE_alu2
`undef NODE_alu3
`undef NODE_alu4
`undef NODE_alu5
`undef NODE_alu6
`undef NODE_alu7

`undef NODE_alua0
`undef NODE_alua1
`undef NODE_alua2
`undef NODE_alua3
`undef NODE_alua4
`undef NODE_alua5
`undef NODE_alua6
`undef NODE_alua7

`undef NODE_alub0
`undef NODE_alub1
`undef NODE_alub2
`undef NODE_alub3
`undef NODE_alub4
`undef NODE_alub5
`undef NODE_alub6
`undef NODE_alub7

/* verilator lint_on UNDRIVEN */
/* verilator lint_on UNOPTFLAT */
