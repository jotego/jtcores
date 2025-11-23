module t65_alu
  (input  [1:0] mode,
   input  [3:0] op,
   input  [7:0] busa,
   input  [7:0] busb,
   input  [7:0] p_in,
   output [7:0] p_out,
   output [7:0] q);
  wire adc_z;
  wire adc_c;
  wire adc_v;
  wire adc_n;
  wire [7:0] adc_q;
  wire sbc_z;
  wire sbc_c;
  wire sbc_v;
  wire sbc_n;
  wire [7:0] sbc_q;
  wire [3:0] n2535_o;
  wire n2536_o;
  wire [4:0] n2537_o;
  wire [6:0] n2538_o;
  wire [3:0] n2539_o;
  wire [4:0] n2541_o;
  wire [6:0] n2542_o;
  wire [6:0] n2543_o;
  wire [3:0] n2544_o;
  wire n2545_o;
  wire [4:0] n2546_o;
  wire [6:0] n2547_o;
  wire [3:0] n2548_o;
  wire [4:0] n2550_o;
  wire [6:0] n2551_o;
  wire [6:0] n2552_o;
  wire [3:0] n2553_o;
  wire n2555_o;
  wire [3:0] n2556_o;
  wire n2558_o;
  wire n2559_o;
  wire n2562_o;
  wire [4:0] n2563_o;
  wire n2565_o;
  wire n2566_o;
  wire n2567_o;
  wire [5:0] n2568_o;
  wire [5:0] n2570_o;
  wire [5:0] n2571_o;
  wire [5:0] n2572_o;
  wire n2573_o;
  wire [6:0] n2574_o;
  wire n2575_o;
  wire [6:0] n2576_o;
  wire n2577_o;
  wire n2578_o;
  wire [3:0] n2579_o;
  wire [4:0] n2580_o;
  wire [6:0] n2581_o;
  wire [3:0] n2582_o;
  wire [4:0] n2584_o;
  wire [6:0] n2585_o;
  wire [6:0] n2586_o;
  wire n2587_o;
  wire n2588_o;
  wire n2589_o;
  wire n2590_o;
  wire n2591_o;
  wire n2592_o;
  wire n2593_o;
  wire n2594_o;
  wire n2595_o;
  wire [4:0] n2596_o;
  wire n2598_o;
  wire n2599_o;
  wire n2600_o;
  wire [5:0] n2601_o;
  wire [5:0] n2603_o;
  wire [5:0] n2604_o;
  wire [5:0] n2605_o;
  wire n2606_o;
  wire [6:0] n2607_o;
  wire n2608_o;
  wire [6:0] n2609_o;
  wire n2610_o;
  wire n2611_o;
  wire [6:0] n2612_o;
  wire [3:0] n2613_o;
  wire [6:0] n2614_o;
  wire [3:0] n2615_o;
  wire [7:0] n2616_o;
  wire n2625_o;
  wire n2626_o;
  wire n2627_o;
  wire n2628_o;
  wire [3:0] n2629_o;
  wire [4:0] n2630_o;
  wire [6:0] n2631_o;
  wire [3:0] n2632_o;
  wire [4:0] n2634_o;
  wire [5:0] n2635_o;
  wire [6:0] n2636_o;
  wire [6:0] n2637_o;
  wire [3:0] n2638_o;
  wire [4:0] n2640_o;
  wire [5:0] n2641_o;
  wire [3:0] n2642_o;
  wire n2643_o;
  wire [4:0] n2644_o;
  wire [5:0] n2645_o;
  wire [5:0] n2646_o;
  wire [3:0] n2647_o;
  wire n2649_o;
  wire [3:0] n2650_o;
  wire n2652_o;
  wire n2653_o;
  wire n2656_o;
  wire n2657_o;
  wire n2658_o;
  wire n2659_o;
  wire n2660_o;
  wire n2661_o;
  wire n2662_o;
  wire n2663_o;
  wire n2664_o;
  wire n2665_o;
  wire n2666_o;
  wire n2667_o;
  wire n2668_o;
  wire [4:0] n2669_o;
  wire [4:0] n2671_o;
  wire [4:0] n2672_o;
  wire [4:0] n2673_o;
  wire [3:0] n2674_o;
  wire [4:0] n2676_o;
  wire [5:0] n2677_o;
  wire [3:0] n2678_o;
  wire n2679_o;
  wire n2680_o;
  wire [6:0] n2681_o;
  wire n2682_o;
  wire [4:0] n2683_o;
  wire [5:0] n2684_o;
  wire [5:0] n2685_o;
  wire n2686_o;
  wire [4:0] n2687_o;
  wire [4:0] n2689_o;
  wire [4:0] n2690_o;
  wire [4:0] n2691_o;
  wire n2692_o;
  wire [4:0] n2693_o;
  wire [4:0] n2694_o;
  wire n2695_o;
  wire n2696_o;
  wire [5:0] n2697_o;
  wire [5:0] n2698_o;
  wire [3:0] n2699_o;
  wire [6:0] n2700_o;
  wire [3:0] n2701_o;
  wire [7:0] n2702_o;
  wire [7:0] n2708_o;
  wire n2710_o;
  wire [7:0] n2711_o;
  wire n2713_o;
  wire [7:0] n2714_o;
  wire n2716_o;
  wire n2718_o;
  wire n2720_o;
  wire n2722_o;
  wire n2723_o;
  wire n2725_o;
  wire n2727_o;
  wire [6:0] n2728_o;
  wire [7:0] n2730_o;
  wire n2731_o;
  wire n2733_o;
  wire [6:0] n2734_o;
  wire n2735_o;
  wire [7:0] n2736_o;
  wire n2737_o;
  wire n2739_o;
  wire [6:0] n2740_o;
  wire [7:0] n2742_o;
  wire n2743_o;
  wire n2745_o;
  wire n2746_o;
  wire [6:0] n2747_o;
  wire [7:0] n2748_o;
  wire n2749_o;
  wire n2751_o;
  wire n2752_o;
  wire n2754_o;
  wire [7:0] n2756_o;
  wire n2758_o;
  wire [7:0] n2760_o;
  wire n2762_o;
  wire [13:0] n2763_o;
  wire n2764_o;
  reg n2765_o;
  wire n2766_o;
  reg n2767_o;
  wire n2769_o;
  reg [7:0] n2771_o;
  wire n2773_o;
  wire n2775_o;
  wire n2777_o;
  wire n2778_o;
  wire n2780_o;
  wire n2781_o;
  wire [7:0] n2782_o;
  wire n2784_o;
  wire n2787_o;
  wire n2789_o;
  wire n2790_o;
  wire n2792_o;
  wire n2795_o;
  wire [3:0] n2796_o;
  wire n2797_o;
  reg n2798_o;
  reg n2799_o;
  wire [3:0] n2800_o;
  wire [7:0] n2802_o;
  assign p_out = n2802_o;
  assign q = n2771_o;
  /* T65_ALU.vhd:79:21  */
  assign adc_z = n2562_o; // (signal)
  /* T65_ALU.vhd:80:21  */
  assign adc_c = n2611_o; // (signal)
  /* T65_ALU.vhd:81:21  */
  assign adc_v = n2595_o; // (signal)
  /* T65_ALU.vhd:82:21  */
  assign adc_n = n2587_o; // (signal)
  /* T65_ALU.vhd:83:21  */
  assign adc_q = n2616_o; // (signal)
  /* T65_ALU.vhd:84:21  */
  assign sbc_z = n2656_o; // (signal)
  /* T65_ALU.vhd:85:21  */
  assign sbc_c = n2658_o; // (signal)
  /* T65_ALU.vhd:86:21  */
  assign sbc_v = n2665_o; // (signal)
  /* T65_ALU.vhd:87:21  */
  assign sbc_n = n2666_o; // (signal)
  /* T65_ALU.vhd:88:21  */
  assign sbc_q = n2702_o; // (signal)
  /* T65_ALU.vhd:97:43  */
  assign n2535_o = busa[3:0];
  /* T65_ALU.vhd:97:62  */
  assign n2536_o = p_in[0];
  /* T65_ALU.vhd:97:56  */
  assign n2537_o = {n2535_o, n2536_o};
  /* T65_ALU.vhd:97:23  */
  assign n2538_o = {2'b0, n2537_o};  //  uext
  /* T65_ALU.vhd:97:98  */
  assign n2539_o = busb[3:0];
  /* T65_ALU.vhd:97:111  */
  assign n2541_o = {n2539_o, 1'b1};
  /* T65_ALU.vhd:97:78  */
  assign n2542_o = {2'b0, n2541_o};  //  uext
  /* T65_ALU.vhd:97:76  */
  assign n2543_o = n2538_o + n2542_o;
  /* T65_ALU.vhd:98:43  */
  assign n2544_o = busa[7:4];
  /* T65_ALU.vhd:98:60  */
  assign n2545_o = n2543_o[5];
  /* T65_ALU.vhd:98:56  */
  assign n2546_o = {n2544_o, n2545_o};
  /* T65_ALU.vhd:98:23  */
  assign n2547_o = {2'b0, n2546_o};  //  uext
  /* T65_ALU.vhd:98:91  */
  assign n2548_o = busb[7:4];
  /* T65_ALU.vhd:98:104  */
  assign n2550_o = {n2548_o, 1'b1};
  /* T65_ALU.vhd:98:71  */
  assign n2551_o = {2'b0, n2550_o};  //  uext
  /* T65_ALU.vhd:98:69  */
  assign n2552_o = n2547_o + n2551_o;
  /* T65_ALU.vhd:105:22  */
  assign n2553_o = n2543_o[4:1];
  /* T65_ALU.vhd:105:35  */
  assign n2555_o = n2553_o == 4'b0000;
  /* T65_ALU.vhd:105:45  */
  assign n2556_o = n2552_o[4:1];
  /* T65_ALU.vhd:105:58  */
  assign n2558_o = n2556_o == 4'b0000;
  /* T65_ALU.vhd:105:39  */
  assign n2559_o = n2558_o & n2555_o;
  /* T65_ALU.vhd:105:17  */
  assign n2562_o = n2559_o ? 1'b1 : 1'b0;
  /* T65_ALU.vhd:111:22  */
  assign n2563_o = n2543_o[5:1];
  /* T65_ALU.vhd:111:35  */
  assign n2565_o = $unsigned(n2563_o) > $unsigned(5'b01001);
  /* T65_ALU.vhd:111:47  */
  assign n2566_o = p_in[3];
  /* T65_ALU.vhd:111:39  */
  assign n2567_o = n2566_o & n2565_o;
  /* T65_ALU.vhd:112:45  */
  assign n2568_o = n2543_o[6:1];
  /* T65_ALU.vhd:112:58  */
  assign n2570_o = n2568_o + 6'b000110;
  assign n2571_o = n2543_o[6:1];
  /* T65_ALU.vhd:111:17  */
  assign n2572_o = n2567_o ? n2570_o : n2571_o;
  assign n2573_o = n2543_o[0];
  /* T65_MCode.vhd:408:33  */
  assign n2574_o = {n2572_o, n2573_o};
  /* T65_ALU.vhd:115:24  */
  assign n2575_o = n2574_o[6];
  /* T65_MCode.vhd:407:38  */
  assign n2576_o = {n2572_o, n2573_o};
  /* T65_ALU.vhd:115:33  */
  assign n2577_o = n2576_o[5];
  /* T65_ALU.vhd:115:28  */
  assign n2578_o = n2575_o | n2577_o;
  /* T65_ALU.vhd:116:43  */
  assign n2579_o = busa[7:4];
  /* T65_ALU.vhd:116:56  */
  assign n2580_o = {n2579_o, n2578_o};
  /* T65_ALU.vhd:116:23  */
  assign n2581_o = {2'b0, n2580_o};  //  uext
  /* T65_ALU.vhd:116:87  */
  assign n2582_o = busb[7:4];
  /* T65_ALU.vhd:116:100  */
  assign n2584_o = {n2582_o, 1'b1};
  /* T65_ALU.vhd:116:67  */
  assign n2585_o = {2'b0, n2584_o};  //  uext
  /* T65_ALU.vhd:116:65  */
  assign n2586_o = n2581_o + n2585_o;
  /* T65_ALU.vhd:118:28  */
  assign n2587_o = n2586_o[4];
  /* T65_ALU.vhd:119:29  */
  assign n2588_o = n2586_o[4];
  /* T65_ALU.vhd:119:41  */
  assign n2589_o = busa[7];
  /* T65_ALU.vhd:119:33  */
  assign n2590_o = n2588_o ^ n2589_o;
  /* T65_ALU.vhd:119:59  */
  assign n2591_o = busa[7];
  /* T65_ALU.vhd:119:71  */
  assign n2592_o = busb[7];
  /* T65_ALU.vhd:119:63  */
  assign n2593_o = n2591_o ^ n2592_o;
  /* T65_ALU.vhd:119:50  */
  assign n2594_o = ~n2593_o;
  /* T65_ALU.vhd:119:46  */
  assign n2595_o = n2590_o & n2594_o;
  /* T65_ALU.vhd:125:22  */
  assign n2596_o = n2586_o[5:1];
  /* T65_ALU.vhd:125:35  */
  assign n2598_o = $unsigned(n2596_o) > $unsigned(5'b01001);
  /* T65_ALU.vhd:125:47  */
  assign n2599_o = p_in[3];
  /* T65_ALU.vhd:125:39  */
  assign n2600_o = n2599_o & n2598_o;
  /* T65_ALU.vhd:126:45  */
  assign n2601_o = n2586_o[6:1];
  /* T65_ALU.vhd:126:58  */
  assign n2603_o = n2601_o + 6'b000110;
  assign n2604_o = n2586_o[6:1];
  /* T65_ALU.vhd:125:17  */
  assign n2605_o = n2600_o ? n2603_o : n2604_o;
  assign n2606_o = n2586_o[0];
  assign n2607_o = {n2605_o, n2606_o};
  /* T65_ALU.vhd:129:28  */
  assign n2608_o = n2607_o[6];
  assign n2609_o = {n2605_o, n2606_o};
  /* T65_ALU.vhd:129:37  */
  assign n2610_o = n2609_o[5];
  /* T65_ALU.vhd:129:32  */
  assign n2611_o = n2608_o | n2610_o;
  assign n2612_o = {n2605_o, n2606_o};
  /* T65_ALU.vhd:131:45  */
  assign n2613_o = n2612_o[4:1];
  assign n2614_o = {n2572_o, n2573_o};
  /* T65_ALU.vhd:131:62  */
  assign n2615_o = n2614_o[4:1];
  /* T65_ALU.vhd:131:58  */
  assign n2616_o = {n2613_o, n2615_o};
  /* T65_ALU.vhd:139:26  */
  assign n2625_o = p_in[0];
  /* T65_ALU.vhd:139:44  */
  assign n2626_o = op[0];
  /* T65_ALU.vhd:139:38  */
  assign n2627_o = ~n2626_o;
  /* T65_ALU.vhd:139:35  */
  assign n2628_o = n2625_o | n2627_o;
  /* T65_ALU.vhd:140:43  */
  assign n2629_o = busa[3:0];
  /* T65_ALU.vhd:140:56  */
  assign n2630_o = {n2629_o, n2628_o};
  /* T65_ALU.vhd:140:23  */
  assign n2631_o = {2'b0, n2630_o};  //  uext
  /* T65_ALU.vhd:140:87  */
  assign n2632_o = busb[3:0];
  /* T65_ALU.vhd:140:100  */
  assign n2634_o = {n2632_o, 1'b1};
  /* T65_ALU.vhd:140:67  */
  assign n2635_o = {1'b0, n2634_o};  //  uext
  /* T65_ALU.vhd:140:65  */
  assign n2636_o = {1'b0, n2635_o};  //  uext
  /* T65_ALU.vhd:140:65  */
  assign n2637_o = n2631_o - n2636_o;
  /* T65_ALU.vhd:141:43  */
  assign n2638_o = busa[7:4];
  /* T65_ALU.vhd:141:56  */
  assign n2640_o = {n2638_o, 1'b0};
  /* T65_ALU.vhd:141:23  */
  assign n2641_o = {1'b0, n2640_o};  //  uext
  /* T65_ALU.vhd:141:89  */
  assign n2642_o = busb[7:4];
  /* T65_ALU.vhd:141:106  */
  assign n2643_o = n2637_o[5];
  /* T65_ALU.vhd:141:102  */
  assign n2644_o = {n2642_o, n2643_o};
  /* T65_ALU.vhd:141:69  */
  assign n2645_o = {1'b0, n2644_o};  //  uext
  /* T65_ALU.vhd:141:67  */
  assign n2646_o = n2641_o - n2645_o;
  /* T65_ALU.vhd:148:22  */
  assign n2647_o = n2637_o[4:1];
  /* T65_ALU.vhd:148:35  */
  assign n2649_o = n2647_o == 4'b0000;
  /* T65_ALU.vhd:148:45  */
  assign n2650_o = n2646_o[4:1];
  /* T65_ALU.vhd:148:58  */
  assign n2652_o = n2650_o == 4'b0000;
  /* T65_ALU.vhd:148:39  */
  assign n2653_o = n2652_o & n2649_o;
  /* T65_ALU.vhd:148:17  */
  assign n2656_o = n2653_o ? 1'b1 : 1'b0;
  /* T65_ALU.vhd:154:32  */
  assign n2657_o = n2646_o[5];
  /* T65_ALU.vhd:154:26  */
  assign n2658_o = ~n2657_o;
  /* T65_ALU.vhd:155:29  */
  assign n2659_o = n2646_o[4];
  /* T65_ALU.vhd:155:41  */
  assign n2660_o = busa[7];
  /* T65_ALU.vhd:155:33  */
  assign n2661_o = n2659_o ^ n2660_o;
  /* T65_ALU.vhd:155:55  */
  assign n2662_o = busa[7];
  /* T65_ALU.vhd:155:67  */
  assign n2663_o = busb[7];
  /* T65_ALU.vhd:155:59  */
  assign n2664_o = n2662_o ^ n2663_o;
  /* T65_ALU.vhd:155:46  */
  assign n2665_o = n2661_o & n2664_o;
  /* T65_ALU.vhd:156:28  */
  assign n2666_o = n2646_o[4];
  /* T65_ALU.vhd:158:24  */
  assign n2667_o = p_in[3];
  /* T65_ALU.vhd:159:30  */
  assign n2668_o = n2637_o[5];
  /* T65_ALU.vhd:160:53  */
  assign n2669_o = n2637_o[5:1];
  /* T65_ALU.vhd:160:66  */
  assign n2671_o = n2669_o - 5'b00110;
  assign n2672_o = n2637_o[5:1];
  /* T65_ALU.vhd:159:25  */
  assign n2673_o = n2668_o ? n2671_o : n2672_o;
  /* T65_ALU.vhd:162:51  */
  assign n2674_o = busa[7:4];
  /* T65_ALU.vhd:162:64  */
  assign n2676_o = {n2674_o, 1'b0};
  /* T65_ALU.vhd:162:31  */
  assign n2677_o = {1'b0, n2676_o};  //  uext
  /* T65_ALU.vhd:162:97  */
  assign n2678_o = busb[7:4];
  assign n2679_o = n2637_o[0];
  assign n2680_o = n2637_o[6];
  assign n2681_o = {n2680_o, n2673_o, n2679_o};
  /* T65_ALU.vhd:162:114  */
  assign n2682_o = n2681_o[6];
  /* T65_ALU.vhd:162:110  */
  assign n2683_o = {n2678_o, n2682_o};
  /* T65_ALU.vhd:162:77  */
  assign n2684_o = {1'b0, n2683_o};  //  uext
  /* T65_ALU.vhd:162:75  */
  assign n2685_o = n2677_o - n2684_o;
  /* T65_ALU.vhd:163:30  */
  assign n2686_o = n2685_o[5];
  /* T65_ALU.vhd:164:53  */
  assign n2687_o = n2685_o[5:1];
  /* T65_ALU.vhd:164:66  */
  assign n2689_o = n2687_o - 5'b00110;
  assign n2690_o = n2685_o[5:1];
  /* T65_ALU.vhd:163:25  */
  assign n2691_o = n2686_o ? n2689_o : n2690_o;
  assign n2692_o = n2685_o[0];
  assign n2693_o = n2637_o[5:1];
  /* T65_ALU.vhd:158:17  */
  assign n2694_o = n2667_o ? n2673_o : n2693_o;
  assign n2695_o = n2637_o[6];
  assign n2696_o = n2637_o[0];
  assign n2697_o = {n2691_o, n2692_o};
  /* T65_ALU.vhd:158:17  */
  assign n2698_o = n2667_o ? n2697_o : n2646_o;
  /* T65_ALU.vhd:168:45  */
  assign n2699_o = n2698_o[4:1];
  assign n2700_o = {n2695_o, n2694_o, n2696_o};
  /* T65_ALU.vhd:168:62  */
  assign n2701_o = n2700_o[4:1];
  /* T65_ALU.vhd:168:58  */
  assign n2702_o = {n2699_o, n2701_o};
  /* T65_ALU.vhd:183:37  */
  assign n2708_o = busa | busb;
  /* T65_ALU.vhd:181:17  */
  assign n2710_o = op == 4'b0000;
  /* T65_ALU.vhd:186:37  */
  assign n2711_o = busa & busb;
  /* T65_ALU.vhd:184:17  */
  assign n2713_o = op == 4'b0001;
  /* T65_ALU.vhd:189:37  */
  assign n2714_o = busa ^ busb;
  /* T65_ALU.vhd:187:17  */
  assign n2716_o = op == 4'b0010;
  /* T65_ALU.vhd:190:17  */
  assign n2718_o = op == 4'b0011;
  /* T65_ALU.vhd:195:17  */
  assign n2720_o = op == 4'b0101;
  /* T65_ALU.vhd:195:29  */
  assign n2722_o = op == 4'b1101;
  /* T65_ALU.vhd:195:29  */
  assign n2723_o = n2720_o | n2722_o;
  /* T65_ALU.vhd:197:17  */
  assign n2725_o = op == 4'b0110;
  /* T65_ALU.vhd:200:17  */
  assign n2727_o = op == 4'b0111;
  /* T65_ALU.vhd:207:36  */
  assign n2728_o = busa[6:0];
  /* T65_ALU.vhd:207:49  */
  assign n2730_o = {n2728_o, 1'b0};
  /* T65_ALU.vhd:208:46  */
  assign n2731_o = busa[7];
  /* T65_ALU.vhd:205:17  */
  assign n2733_o = op == 4'b1000;
  /* T65_ALU.vhd:211:36  */
  assign n2734_o = busa[6:0];
  /* T65_ALU.vhd:211:55  */
  assign n2735_o = p_in[0];
  /* T65_ALU.vhd:211:49  */
  assign n2736_o = {n2734_o, n2735_o};
  /* T65_ALU.vhd:212:46  */
  assign n2737_o = busa[7];
  /* T65_ALU.vhd:209:17  */
  assign n2739_o = op == 4'b1001;
  /* T65_ALU.vhd:215:42  */
  assign n2740_o = busa[7:1];
  /* T65_ALU.vhd:215:36  */
  assign n2742_o = {1'b0, n2740_o};
  /* T65_ALU.vhd:216:46  */
  assign n2743_o = busa[0];
  /* T65_ALU.vhd:213:17  */
  assign n2745_o = op == 4'b1010;
  /* T65_ALU.vhd:219:36  */
  assign n2746_o = p_in[0];
  /* T65_ALU.vhd:219:51  */
  assign n2747_o = busa[7:1];
  /* T65_ALU.vhd:219:45  */
  assign n2748_o = {n2746_o, n2747_o};
  /* T65_ALU.vhd:220:46  */
  assign n2749_o = busa[0];
  /* T65_ALU.vhd:217:17  */
  assign n2751_o = op == 4'b1011;
  /* T65_ALU.vhd:223:46  */
  assign n2752_o = busb[6];
  /* T65_ALU.vhd:221:17  */
  assign n2754_o = op == 4'b1100;
  /* T65_ALU.vhd:226:64  */
  assign n2756_o = busa - 8'b00000001;
  /* T65_ALU.vhd:224:17  */
  assign n2758_o = op == 4'b1110;
  /* T65_ALU.vhd:229:64  */
  assign n2760_o = busa + 8'b00000001;
  /* T65_ALU.vhd:227:17  */
  assign n2762_o = op == 4'b1111;
  assign n2763_o = {n2762_o, n2758_o, n2754_o, n2751_o, n2745_o, n2739_o, n2733_o, n2727_o, n2725_o, n2723_o, n2718_o, n2716_o, n2713_o, n2710_o};
  assign n2764_o = p_in[0];
  /* T65_ALU.vhd:180:17  */
  always @*
    case (n2763_o)
      14'b10000000000000: n2765_o = n2764_o;
      14'b01000000000000: n2765_o = n2764_o;
      14'b00100000000000: n2765_o = n2764_o;
      14'b00010000000000: n2765_o = n2749_o;
      14'b00001000000000: n2765_o = n2743_o;
      14'b00000100000000: n2765_o = n2737_o;
      14'b00000010000000: n2765_o = n2731_o;
      14'b00000001000000: n2765_o = sbc_c;
      14'b00000000100000: n2765_o = sbc_c;
      14'b00000000010000: n2765_o = n2764_o;
      14'b00000000001000: n2765_o = adc_c;
      14'b00000000000100: n2765_o = n2764_o;
      14'b00000000000010: n2765_o = n2764_o;
      14'b00000000000001: n2765_o = n2764_o;
      default: n2765_o = n2764_o;
    endcase
  assign n2766_o = p_in[6];
  /* T65_ALU.vhd:180:17  */
  always @*
    case (n2763_o)
      14'b10000000000000: n2767_o = n2766_o;
      14'b01000000000000: n2767_o = n2766_o;
      14'b00100000000000: n2767_o = n2752_o;
      14'b00010000000000: n2767_o = n2766_o;
      14'b00001000000000: n2767_o = n2766_o;
      14'b00000100000000: n2767_o = n2766_o;
      14'b00000010000000: n2767_o = n2766_o;
      14'b00000001000000: n2767_o = sbc_v;
      14'b00000000100000: n2767_o = n2766_o;
      14'b00000000010000: n2767_o = n2766_o;
      14'b00000000001000: n2767_o = adc_v;
      14'b00000000000100: n2767_o = n2766_o;
      14'b00000000000010: n2767_o = n2766_o;
      14'b00000000000001: n2767_o = n2766_o;
      default: n2767_o = n2766_o;
    endcase
  assign n2769_o = p_in[7];
  /* T65_ALU.vhd:180:17  */
  always @*
    case (n2763_o)
      14'b10000000000000: n2771_o = n2760_o;
      14'b01000000000000: n2771_o = n2756_o;
      14'b00100000000000: n2771_o = busa;
      14'b00010000000000: n2771_o = n2748_o;
      14'b00001000000000: n2771_o = n2742_o;
      14'b00000100000000: n2771_o = n2736_o;
      14'b00000010000000: n2771_o = n2730_o;
      14'b00000001000000: n2771_o = sbc_q;
      14'b00000000100000: n2771_o = busa;
      14'b00000000010000: n2771_o = busa;
      14'b00000000001000: n2771_o = adc_q;
      14'b00000000000100: n2771_o = n2714_o;
      14'b00000000000010: n2771_o = n2711_o;
      14'b00000000000001: n2771_o = n2708_o;
      default: n2771_o = busa;
    endcase
  /* T65_ALU.vhd:234:17  */
  assign n2773_o = op == 4'b0011;
  /* T65_ALU.vhd:237:17  */
  assign n2775_o = op == 4'b0110;
  /* T65_ALU.vhd:237:29  */
  assign n2777_o = op == 4'b0111;
  /* T65_ALU.vhd:237:29  */
  assign n2778_o = n2775_o | n2777_o;
  /* T65_ALU.vhd:240:17  */
  assign n2780_o = op == 4'b0100;
  /* T65_ALU.vhd:242:46  */
  assign n2781_o = busb[7];
  /* T65_ALU.vhd:243:34  */
  assign n2782_o = busa & busb;
  /* T65_ALU.vhd:243:44  */
  assign n2784_o = n2782_o == 8'b00000000;
  /* T65_ALU.vhd:243:25  */
  assign n2787_o = n2784_o ? 1'b1 : 1'b0;
  /* T65_ALU.vhd:241:17  */
  assign n2789_o = op == 4'b1100;
  /* T65_ALU.vhd:249:45  */
  assign n2790_o = n2771_o[7];
  /* T65_ALU.vhd:250:32  */
  assign n2792_o = n2771_o == 8'b00000000;
  /* T65_ALU.vhd:250:25  */
  assign n2795_o = n2792_o ? 1'b1 : 1'b0;
  assign n2796_o = {n2789_o, n2780_o, n2778_o, n2773_o};
  assign n2797_o = p_in[1];
  /* T65_ALU.vhd:233:17  */
  always @*
    case (n2796_o)
      4'b1000: n2798_o = n2787_o;
      4'b0100: n2798_o = n2797_o;
      4'b0010: n2798_o = sbc_z;
      4'b0001: n2798_o = adc_z;
      default: n2798_o = n2795_o;
    endcase
  /* T65_ALU.vhd:233:17  */
  always @*
    case (n2796_o)
      4'b1000: n2799_o = n2781_o;
      4'b0100: n2799_o = n2769_o;
      4'b0010: n2799_o = sbc_n;
      4'b0001: n2799_o = adc_n;
      default: n2799_o = n2790_o;
    endcase
  assign n2800_o = p_in[5:2];
  assign n2802_o = {n2799_o, n2767_o, n2800_o, n2798_o, n2765_o};
endmodule

module t65_mcode
  (input  [1:0] mode,
   input  [7:0] ir,
   input  [2:0] mcycle,
   input  [7:0] p,
   output [2:0] lcycle,
   output [3:0] alu_op,
   output [2:0] set_busa_to,
   output [1:0] set_addr_to,
   output [2:0] write_data,
   output [1:0] jump,
   output [1:0] baadd,
   output breakatna,
   output adadd,
   output addy,
   output pcadd,
   output inc_s,
   output dec_s,
   output lda,
   output ldp,
   output ldx,
   output ldy,
   output lds,
   output lddi,
   output ldalu,
   output ldad,
   output ldbal,
   output ldbah,
   output savep,
   output write);
  wire branch;
  wire [2:0] n909_o;
  wire n910_o;
  wire n911_o;
  wire n913_o;
  wire n914_o;
  wire n916_o;
  wire n917_o;
  wire n918_o;
  wire n920_o;
  wire n921_o;
  wire n923_o;
  wire n924_o;
  wire n925_o;
  wire n927_o;
  wire n928_o;
  wire n930_o;
  wire n931_o;
  wire n932_o;
  wire n934_o;
  wire n935_o;
  wire [6:0] n936_o;
  reg n937_o;
  wire [2:0] n940_o;
  wire [1:0] n941_o;
  wire n943_o;
  wire n945_o;
  wire [1:0] n946_o;
  reg [2:0] n950_o;
  reg [2:0] n954_o;
  wire n956_o;
  wire [1:0] n957_o;
  wire n958_o;
  wire n960_o;
  wire n961_o;
  wire n963_o;
  wire n964_o;
  wire n967_o;
  wire n969_o;
  wire n971_o;
  wire [1:0] n972_o;
  reg n975_o;
  reg n978_o;
  reg n980_o;
  wire n982_o;
  wire [1:0] n983_o;
  wire n984_o;
  wire n985_o;
  wire n988_o;
  wire n990_o;
  reg [2:0] n993_o;
  reg n995_o;
  wire n997_o;
  wire [1:0] n998_o;
  wire n999_o;
  wire n1000_o;
  wire n1003_o;
  wire n1005_o;
  reg [2:0] n1008_o;
  reg n1010_o;
  wire n1012_o;
  wire [3:0] n1013_o;
  reg [2:0] n1016_o;
  reg [2:0] n1019_o;
  reg n1022_o;
  reg n1025_o;
  reg n1028_o;
  wire [1:0] n1030_o;
  wire n1032_o;
  wire [1:0] n1033_o;
  wire n1035_o;
  wire n1036_o;
  wire [2:0] n1038_o;
  wire [4:0] n1039_o;
  wire [30:0] n1040_o;
  wire n1042_o;
  wire n1044_o;
  wire n1046_o;
  wire n1048_o;
  wire n1050_o;
  wire n1052_o;
  wire [5:0] n1053_o;
  reg [1:0] n1060_o;
  reg [2:0] n1064_o;
  reg [1:0] n1067_o;
  reg n1072_o;
  reg n1075_o;
  reg n1080_o;
  wire n1082_o;
  wire [30:0] n1083_o;
  wire n1085_o;
  wire n1087_o;
  wire n1089_o;
  wire n1091_o;
  wire n1093_o;
  wire [4:0] n1094_o;
  reg [1:0] n1099_o;
  reg [2:0] n1102_o;
  reg [1:0] n1106_o;
  reg n1110_o;
  reg n1113_o;
  reg n1117_o;
  wire n1119_o;
  wire [30:0] n1120_o;
  wire n1122_o;
  wire n1124_o;
  wire n1126_o;
  wire n1128_o;
  wire n1130_o;
  wire [4:0] n1131_o;
  reg [2:0] n1133_o;
  reg [1:0] n1139_o;
  reg [1:0] n1142_o;
  reg n1147_o;
  reg n1150_o;
  reg n1153_o;
  wire n1155_o;
  wire [30:0] n1156_o;
  wire n1158_o;
  wire n1160_o;
  wire n1162_o;
  wire n1164_o;
  wire n1166_o;
  wire [4:0] n1167_o;
  reg [1:0] n1172_o;
  reg [1:0] n1176_o;
  reg n1180_o;
  reg n1183_o;
  wire n1185_o;
  wire n1187_o;
  wire n1188_o;
  wire n1189_o;
  wire [2:0] n1192_o;
  wire [30:0] n1194_o;
  wire [3:0] n1195_o;
  wire n1197_o;
  wire n1199_o;
  wire n1201_o;
  wire n1203_o;
  wire [3:0] n1204_o;
  reg [2:0] n1209_o;
  wire n1211_o;
  wire n1213_o;
  wire [1:0] n1214_o;
  reg [1:0] n1217_o;
  reg [2:0] n1218_o;
  reg n1221_o;
  reg n1224_o;
  wire n1226_o;
  wire n1228_o;
  wire n1229_o;
  wire n1231_o;
  wire n1232_o;
  wire n1234_o;
  wire n1235_o;
  wire n1237_o;
  wire n1238_o;
  wire n1239_o;
  wire [2:0] n1242_o;
  wire [3:0] n1244_o;
  wire n1246_o;
  wire n1248_o;
  wire n1250_o;
  wire n1252_o;
  wire n1254_o;
  wire n1256_o;
  wire n1258_o;
  wire n1260_o;
  wire [3:0] n1261_o;
  reg n1263_o;
  reg n1266_o;
  reg n1267_o;
  reg n1268_o;
  wire [30:0] n1269_o;
  wire n1271_o;
  wire n1273_o;
  wire n1275_o;
  wire n1277_o;
  wire [3:0] n1278_o;
  reg [2:0] n1280_o;
  reg [1:0] n1284_o;
  reg n1287_o;
  reg n1290_o;
  wire n1292_o;
  wire n1294_o;
  wire n1295_o;
  wire n1297_o;
  wire n1298_o;
  wire n1300_o;
  wire n1301_o;
  wire [30:0] n1302_o;
  wire n1304_o;
  wire n1306_o;
  wire [1:0] n1307_o;
  reg [1:0] n1310_o;
  wire n1312_o;
  wire n1314_o;
  wire n1315_o;
  wire n1317_o;
  wire n1318_o;
  wire [30:0] n1319_o;
  wire n1321_o;
  wire n1323_o;
  wire [1:0] n1324_o;
  reg [2:0] n1326_o;
  wire n1328_o;
  wire [30:0] n1329_o;
  wire n1331_o;
  wire n1333_o;
  wire [1:0] n1334_o;
  reg [2:0] n1336_o;
  wire n1338_o;
  wire n1340_o;
  wire n1342_o;
  wire n1344_o;
  wire [30:0] n1345_o;
  wire n1347_o;
  wire n1349_o;
  wire [1:0] n1350_o;
  reg [2:0] n1352_o;
  wire [2:0] n1354_o;
  wire n1356_o;
  wire n1358_o;
  wire n1359_o;
  wire n1367_o;
  wire n1369_o;
  wire n1370_o;
  wire n1372_o;
  wire n1373_o;
  wire n1375_o;
  wire n1376_o;
  wire n1384_o;
  wire n1386_o;
  wire n1387_o;
  wire [30:0] n1388_o;
  wire n1390_o;
  wire n1392_o;
  wire [1:0] n1393_o;
  reg [2:0] n1395_o;
  wire n1397_o;
  wire n1399_o;
  wire n1400_o;
  wire [30:0] n1401_o;
  wire n1403_o;
  wire n1405_o;
  wire [1:0] n1406_o;
  reg n1409_o;
  wire n1411_o;
  wire [30:0] n1412_o;
  wire n1414_o;
  wire n1416_o;
  wire [1:0] n1417_o;
  reg [2:0] n1419_o;
  wire n1421_o;
  wire [14:0] n1425_o;
  reg [2:0] n1431_o;
  reg [2:0] n1433_o;
  reg [1:0] n1435_o;
  reg [2:0] n1436_o;
  reg [1:0] n1438_o;
  reg n1440_o;
  reg n1442_o;
  reg n1445_o;
  reg n1447_o;
  reg n1450_o;
  reg n1452_o;
  reg n1454_o;
  reg n1456_o;
  reg n1458_o;
  reg n1460_o;
  wire n1462_o;
  wire n1464_o;
  wire n1465_o;
  wire n1467_o;
  wire n1468_o;
  wire n1470_o;
  wire n1471_o;
  wire n1473_o;
  wire n1474_o;
  wire [1:0] n1475_o;
  wire n1477_o;
  wire n1479_o;
  wire [30:0] n1480_o;
  wire n1482_o;
  wire n1484_o;
  wire n1486_o;
  wire n1488_o;
  wire [2:0] n1489_o;
  wire n1491_o;
  wire n1494_o;
  wire n1496_o;
  wire n1498_o;
  wire [5:0] n1499_o;
  reg [1:0] n1505_o;
  reg [1:0] n1508_o;
  reg [1:0] n1511_o;
  reg n1514_o;
  reg n1517_o;
  reg n1520_o;
  reg n1523_o;
  reg n1525_o;
  wire n1527_o;
  wire n1529_o;
  wire n1530_o;
  wire [30:0] n1531_o;
  wire n1533_o;
  wire n1535_o;
  wire [1:0] n1536_o;
  reg [1:0] n1539_o;
  wire n1541_o;
  wire n1543_o;
  wire n1544_o;
  wire [30:0] n1545_o;
  wire n1547_o;
  wire n1549_o;
  wire [1:0] n1552_o;
  wire n1554_o;
  wire [1:0] n1555_o;
  reg [1:0] n1557_o;
  wire n1559_o;
  wire n1561_o;
  wire n1562_o;
  wire [30:0] n1563_o;
  wire [2:0] n1564_o;
  wire n1566_o;
  wire n1569_o;
  wire n1571_o;
  wire [2:0] n1572_o;
  wire n1574_o;
  wire n1577_o;
  wire n1579_o;
  wire n1581_o;
  wire [2:0] n1582_o;
  reg [1:0] n1585_o;
  reg [1:0] n1588_o;
  reg n1591_o;
  reg n1593_o;
  reg n1595_o;
  wire n1597_o;
  wire [1:0] n1598_o;
  wire n1600_o;
  wire [1:0] n1601_o;
  wire n1603_o;
  wire n1604_o;
  wire [30:0] n1605_o;
  wire n1607_o;
  wire n1609_o;
  wire n1611_o;
  wire n1613_o;
  wire [3:0] n1614_o;
  reg [1:0] n1619_o;
  reg [1:0] n1622_o;
  reg n1625_o;
  reg n1628_o;
  reg n1631_o;
  reg n1634_o;
  reg n1638_o;
  wire [1:0] n1639_o;
  wire n1641_o;
  wire n1643_o;
  wire [30:0] n1644_o;
  wire n1646_o;
  wire [2:0] n1647_o;
  wire n1649_o;
  wire n1652_o;
  wire n1654_o;
  wire n1656_o;
  wire [2:0] n1657_o;
  reg [1:0] n1660_o;
  reg [1:0] n1663_o;
  reg n1666_o;
  reg n1668_o;
  wire [2:0] n1671_o;
  wire [1:0] n1672_o;
  wire [1:0] n1673_o;
  wire n1674_o;
  wire n1676_o;
  wire n1678_o;
  wire n1679_o;
  wire n1681_o;
  wire n1682_o;
  wire n1684_o;
  wire n1686_o;
  wire n1687_o;
  wire n1689_o;
  wire n1690_o;
  wire [1:0] n1691_o;
  wire n1693_o;
  wire [4:0] n1694_o;
  wire n1696_o;
  wire n1697_o;
  wire n1698_o;
  wire n1699_o;
  wire [30:0] n1700_o;
  wire n1702_o;
  wire n1704_o;
  wire [1:0] n1705_o;
  reg [1:0] n1709_o;
  reg n1712_o;
  wire [30:0] n1713_o;
  wire n1715_o;
  wire n1717_o;
  wire [1:0] n1720_o;
  wire n1722_o;
  wire [1:0] n1725_o;
  wire n1727_o;
  wire n1729_o;
  wire [1:0] n1732_o;
  wire [1:0] n1735_o;
  wire [1:0] n1738_o;
  wire n1740_o;
  wire n1742_o;
  wire [3:0] n1743_o;
  reg [1:0] n1745_o;
  reg [1:0] n1749_o;
  reg [1:0] n1751_o;
  reg n1755_o;
  reg n1758_o;
  reg n1761_o;
  wire [2:0] n1764_o;
  wire [1:0] n1766_o;
  wire [1:0] n1767_o;
  wire [1:0] n1769_o;
  wire n1770_o;
  wire n1772_o;
  wire n1774_o;
  wire [30:0] n1775_o;
  wire [2:0] n1776_o;
  wire n1778_o;
  wire n1781_o;
  wire n1783_o;
  wire n1785_o;
  wire [2:0] n1786_o;
  wire n1788_o;
  wire n1791_o;
  wire n1793_o;
  wire n1795_o;
  wire [3:0] n1796_o;
  reg [1:0] n1799_o;
  reg [1:0] n1803_o;
  reg n1806_o;
  reg n1809_o;
  reg n1811_o;
  reg n1813_o;
  wire [2:0] n1815_o;
  wire [1:0] n1816_o;
  wire [1:0] n1817_o;
  wire [1:0] n1819_o;
  wire n1821_o;
  wire n1822_o;
  wire n1823_o;
  wire n1825_o;
  wire n1827_o;
  wire n1829_o;
  wire [1:0] n1830_o;
  wire n1832_o;
  wire [1:0] n1833_o;
  wire n1835_o;
  wire n1836_o;
  wire [30:0] n1837_o;
  wire n1839_o;
  wire n1841_o;
  wire n1843_o;
  wire n1845_o;
  wire n1847_o;
  wire [4:0] n1848_o;
  reg [1:0] n1853_o;
  reg [1:0] n1857_o;
  reg n1860_o;
  reg n1863_o;
  reg n1866_o;
  reg n1869_o;
  reg n1873_o;
  reg n1877_o;
  wire [1:0] n1878_o;
  wire n1880_o;
  wire n1882_o;
  wire [30:0] n1883_o;
  wire n1885_o;
  wire n1887_o;
  wire [2:0] n1888_o;
  wire n1890_o;
  wire n1893_o;
  wire n1895_o;
  wire n1897_o;
  wire [3:0] n1898_o;
  reg [1:0] n1901_o;
  reg [1:0] n1905_o;
  reg n1908_o;
  reg n1911_o;
  reg n1913_o;
  wire [2:0] n1916_o;
  wire [1:0] n1917_o;
  wire [1:0] n1918_o;
  wire n1919_o;
  wire n1921_o;
  wire n1923_o;
  wire n1924_o;
  wire n1925_o;
  wire n1927_o;
  wire n1928_o;
  wire n1930_o;
  wire n1932_o;
  wire n1933_o;
  wire n1935_o;
  wire n1936_o;
  wire [2:0] n1939_o;
  wire [30:0] n1940_o;
  wire n1942_o;
  wire n1944_o;
  wire n1946_o;
  wire [2:0] n1947_o;
  reg [1:0] n1951_o;
  reg n1954_o;
  reg n1957_o;
  wire n1959_o;
  wire [1:0] n1960_o;
  wire n1962_o;
  wire n1964_o;
  wire [30:0] n1965_o;
  wire n1967_o;
  wire n1969_o;
  wire n1971_o;
  wire n1973_o;
  wire [2:0] n1974_o;
  wire n1976_o;
  wire n1979_o;
  wire n1982_o;
  wire n1984_o;
  wire n1986_o;
  wire [5:0] n1987_o;
  reg [2:0] n1989_o;
  reg [1:0] n1995_o;
  reg [1:0] n1998_o;
  reg [1:0] n2003_o;
  reg n2005_o;
  reg n2008_o;
  reg n2011_o;
  reg n2014_o;
  reg n2016_o;
  wire n2018_o;
  wire n2020_o;
  wire n2021_o;
  wire [1:0] n2022_o;
  wire n2024_o;
  wire [1:0] n2025_o;
  wire n2027_o;
  wire n2028_o;
  wire [30:0] n2029_o;
  wire n2031_o;
  wire n2033_o;
  wire n2035_o;
  wire n2037_o;
  wire n2039_o;
  wire [4:0] n2040_o;
  reg [1:0] n2046_o;
  reg [1:0] n2049_o;
  reg n2052_o;
  reg n2055_o;
  reg n2058_o;
  reg n2061_o;
  reg n2064_o;
  reg n2068_o;
  wire [1:0] n2069_o;
  wire n2071_o;
  wire n2073_o;
  wire [30:0] n2074_o;
  wire n2076_o;
  wire n2078_o;
  wire [3:0] n2079_o;
  wire n2081_o;
  wire n2084_o;
  wire [2:0] n2085_o;
  wire n2087_o;
  wire n2090_o;
  wire n2092_o;
  wire n2094_o;
  wire [3:0] n2095_o;
  reg [1:0] n2099_o;
  reg [1:0] n2102_o;
  reg n2105_o;
  reg n2107_o;
  reg n2110_o;
  reg n2112_o;
  wire [2:0] n2115_o;
  wire [1:0] n2116_o;
  wire [1:0] n2117_o;
  wire n2118_o;
  wire n2120_o;
  wire n2121_o;
  wire n2123_o;
  wire n2125_o;
  wire n2126_o;
  wire n2128_o;
  wire n2129_o;
  wire n2131_o;
  wire n2133_o;
  wire n2134_o;
  wire n2136_o;
  wire n2137_o;
  wire n2139_o;
  wire n2140_o;
  wire [1:0] n2141_o;
  wire n2143_o;
  wire n2145_o;
  wire [30:0] n2146_o;
  wire n2148_o;
  wire n2150_o;
  wire n2152_o;
  wire [2:0] n2153_o;
  wire n2155_o;
  wire n2158_o;
  wire n2161_o;
  wire n2163_o;
  wire n2165_o;
  wire [4:0] n2166_o;
  reg [2:0] n2168_o;
  reg [1:0] n2172_o;
  reg [1:0] n2176_o;
  reg [1:0] n2180_o;
  reg n2182_o;
  reg n2185_o;
  reg n2188_o;
  reg n2190_o;
  wire n2192_o;
  wire n2194_o;
  wire n2195_o;
  wire [1:0] n2196_o;
  wire n2198_o;
  wire [1:0] n2199_o;
  wire n2201_o;
  wire n2202_o;
  wire [30:0] n2203_o;
  wire n2205_o;
  wire n2207_o;
  wire n2209_o;
  wire n2211_o;
  wire n2213_o;
  wire n2215_o;
  wire [5:0] n2216_o;
  reg [2:0] n2218_o;
  reg [1:0] n2224_o;
  reg [1:0] n2228_o;
  reg [1:0] n2232_o;
  reg n2235_o;
  reg n2238_o;
  reg n2241_o;
  reg n2244_o;
  reg n2247_o;
  reg n2251_o;
  wire [1:0] n2252_o;
  wire n2254_o;
  wire n2256_o;
  wire [30:0] n2257_o;
  wire n2259_o;
  wire n2261_o;
  wire n2263_o;
  wire [2:0] n2266_o;
  wire n2268_o;
  wire [2:0] n2269_o;
  wire n2271_o;
  wire n2274_o;
  wire n2277_o;
  wire n2279_o;
  wire n2281_o;
  wire [4:0] n2282_o;
  reg [2:0] n2283_o;
  reg [1:0] n2287_o;
  reg [1:0] n2291_o;
  reg [1:0] n2295_o;
  reg n2297_o;
  reg n2300_o;
  reg n2303_o;
  reg n2305_o;
  wire [2:0] n2308_o;
  wire [2:0] n2309_o;
  wire [1:0] n2310_o;
  wire [1:0] n2311_o;
  wire [1:0] n2312_o;
  wire n2314_o;
  wire n2315_o;
  wire n2317_o;
  wire n2319_o;
  wire n2320_o;
  wire n2321_o;
  wire n2323_o;
  wire n2324_o;
  wire n2326_o;
  wire n2328_o;
  wire n2329_o;
  wire n2331_o;
  wire n2332_o;
  wire n2334_o;
  wire n2335_o;
  wire [12:0] n2336_o;
  reg [2:0] n2342_o;
  reg [2:0] n2344_o;
  reg [1:0] n2346_o;
  reg [2:0] n2348_o;
  reg [1:0] n2350_o;
  reg [1:0] n2353_o;
  reg n2356_o;
  reg n2359_o;
  reg n2362_o;
  reg n2365_o;
  reg n2368_o;
  reg n2371_o;
  reg n2374_o;
  reg n2376_o;
  reg n2379_o;
  reg n2380_o;
  reg n2382_o;
  reg n2385_o;
  reg n2388_o;
  reg n2391_o;
  reg n2394_o;
  reg n2397_o;
  reg n2400_o;
  reg n2403_o;
  wire [1:0] n2408_o;
  wire [2:0] n2409_o;
  wire [2:0] n2410_o;
  wire n2412_o;
  wire n2414_o;
  wire n2415_o;
  wire n2417_o;
  wire n2419_o;
  wire [2:0] n2420_o;
  reg [3:0] n2425_o;
  wire n2427_o;
  wire n2429_o;
  wire n2430_o;
  wire n2432_o;
  wire n2433_o;
  wire [2:0] n2434_o;
  wire n2436_o;
  wire n2438_o;
  wire n2439_o;
  wire n2441_o;
  wire [1:0] n2442_o;
  reg [3:0] n2446_o;
  wire n2448_o;
  wire [2:0] n2449_o;
  wire n2451_o;
  reg [3:0] n2454_o;
  wire n2456_o;
  wire [2:0] n2457_o;
  wire n2459_o;
  reg [3:0] n2462_o;
  wire [2:0] n2463_o;
  reg [3:0] n2464_o;
  wire n2466_o;
  wire [2:0] n2468_o;
  wire n2470_o;
  wire [2:0] n2472_o;
  wire [2:0] n2473_o;
  wire [2:0] n2474_o;
  wire n2476_o;
  wire [3:0] n2478_o;
  wire [3:0] n2479_o;
  wire n2481_o;
  wire [2:0] n2482_o;
  wire n2484_o;
  wire [3:0] n2486_o;
  wire [3:0] n2487_o;
  wire n2489_o;
  wire [2:0] n2490_o;
  wire n2492_o;
  wire [3:0] n2495_o;
  wire n2497_o;
  wire [2:0] n2498_o;
  wire [3:0] n2499_o;
  reg [3:0] n2500_o;
  wire n2502_o;
  wire [2:0] n2503_o;
  wire n2505_o;
  wire n2507_o;
  wire [2:0] n2509_o;
  wire [2:0] n2511_o;
  wire [3:0] n2512_o;
  wire [3:0] n2513_o;
  wire [3:0] n2514_o;
  reg [3:0] n2516_o;
  wire [2:0] n2517_o;
  wire [2:0] n2518_o;
  wire [2:0] n2519_o;
  wire [2:0] n2520_o;
  reg [2:0] n2521_o;
  wire n2522_o;
  wire n2523_o;
  wire n2524_o;
  reg n2525_o;
  wire [3:0] n2527_o;
  assign lcycle = n2342_o;
  assign alu_op = n2527_o;
  assign set_busa_to = n2344_o;
  assign set_addr_to = n2346_o;
  assign write_data = n2348_o;
  assign jump = n2350_o;
  assign baadd = n2353_o;
  assign breakatna = n2356_o;
  assign adadd = n2359_o;
  assign addy = n2362_o;
  assign pcadd = n2365_o;
  assign inc_s = n2368_o;
  assign dec_s = n2371_o;
  assign lda = n2374_o;
  assign ldp = n2376_o;
  assign ldx = n2379_o;
  assign ldy = n2380_o;
  assign lds = n2382_o;
  assign lddi = n2385_o;
  assign ldalu = n2388_o;
  assign ldad = n2391_o;
  assign ldbal = n2394_o;
  assign ldbah = n2397_o;
  assign savep = n2400_o;
  assign write = n2403_o;
  /* T65_MCode.vhd:106:16  */
  assign branch = n937_o; // (signal)
  /* T65_MCode.vhd:110:16  */
  assign n909_o = ir[7:5];
  /* T65_MCode.vhd:111:32  */
  assign n910_o = p[7];
  /* T65_MCode.vhd:111:27  */
  assign n911_o = ~n910_o;
  /* T65_MCode.vhd:111:41  */
  assign n913_o = n909_o == 3'b000;
  /* T65_MCode.vhd:112:44  */
  assign n914_o = p[7];
  /* T65_MCode.vhd:112:53  */
  assign n916_o = n909_o == 3'b001;
  /* T65_MCode.vhd:113:40  */
  assign n917_o = p[6];
  /* T65_MCode.vhd:113:35  */
  assign n918_o = ~n917_o;
  /* T65_MCode.vhd:113:49  */
  assign n920_o = n909_o == 3'b010;
  /* T65_MCode.vhd:114:44  */
  assign n921_o = p[6];
  /* T65_MCode.vhd:114:53  */
  assign n923_o = n909_o == 3'b011;
  /* T65_MCode.vhd:115:40  */
  assign n924_o = p[0];
  /* T65_MCode.vhd:115:35  */
  assign n925_o = ~n924_o;
  /* T65_MCode.vhd:115:49  */
  assign n927_o = n909_o == 3'b100;
  /* T65_MCode.vhd:116:44  */
  assign n928_o = p[0];
  /* T65_MCode.vhd:116:53  */
  assign n930_o = n909_o == 3'b101;
  /* T65_MCode.vhd:117:40  */
  assign n931_o = p[1];
  /* T65_MCode.vhd:117:35  */
  assign n932_o = ~n931_o;
  /* T65_MCode.vhd:117:49  */
  assign n934_o = n909_o == 3'b110;
  /* T65_MCode.vhd:118:44  */
  assign n935_o = p[1];
  /* T65.vhd:93:17  */
  assign n936_o = {n934_o, n930_o, n927_o, n923_o, n920_o, n916_o, n913_o};
  /* T65_MCode.vhd:110:9  */
  always @*
    case (n936_o)
      7'b1000000: n937_o = n932_o;
      7'b0100000: n937_o = n928_o;
      7'b0010000: n937_o = n925_o;
      7'b0001000: n937_o = n921_o;
      7'b0000100: n937_o = n918_o;
      7'b0000010: n937_o = n914_o;
      7'b0000001: n937_o = n911_o;
      default: n937_o = n935_o;
    endcase
  /* T65_MCode.vhd:147:24  */
  assign n940_o = ir[7:5];
  /* T65_MCode.vhd:150:32  */
  assign n941_o = ir[1:0];
  /* T65_MCode.vhd:151:25  */
  assign n943_o = n941_o == 2'b00;
  /* T65_MCode.vhd:154:25  */
  assign n945_o = n941_o == 2'b10;
  /* T65.vhd:83:17  */
  assign n946_o = {n945_o, n943_o};
  /* T65_MCode.vhd:150:25  */
  always @*
    case (n946_o)
      2'b10: n950_o = 3'b010;
      2'b01: n950_o = 3'b011;
      default: n950_o = 3'b001;
    endcase
  /* T65_MCode.vhd:150:25  */
  always @*
    case (n946_o)
      2'b10: n954_o = 3'b010;
      2'b01: n954_o = 3'b011;
      default: n954_o = 3'b001;
    endcase
  /* T65_MCode.vhd:148:17  */
  assign n956_o = n940_o == 3'b100;
  /* T65_MCode.vhd:163:32  */
  assign n957_o = ir[1:0];
  /* T65_MCode.vhd:165:38  */
  assign n958_o = ir[4];
  /* T65_MCode.vhd:165:42  */
  assign n960_o = n958_o != 1'b1;
  /* T65_MCode.vhd:165:54  */
  assign n961_o = ir[2];
  /* T65_MCode.vhd:165:58  */
  assign n963_o = n961_o != 1'b0;
  /* T65_MCode.vhd:165:49  */
  assign n964_o = n960_o | n963_o;
  /* T65_MCode.vhd:165:33  */
  assign n967_o = n964_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:164:25  */
  assign n969_o = n957_o == 2'b00;
  /* T65_MCode.vhd:168:25  */
  assign n971_o = n957_o == 2'b10;
  assign n972_o = {n971_o, n969_o};
  /* T65_MCode.vhd:163:25  */
  always @*
    case (n972_o)
      2'b10: n975_o = 1'b0;
      2'b01: n975_o = 1'b0;
      default: n975_o = 1'b1;
    endcase
  /* T65_MCode.vhd:163:25  */
  always @*
    case (n972_o)
      2'b10: n978_o = 1'b1;
      2'b01: n978_o = 1'b0;
      default: n978_o = 1'b0;
    endcase
  /* T65_MCode.vhd:163:25  */
  always @*
    case (n972_o)
      2'b10: n980_o = 1'b0;
      2'b01: n980_o = n967_o;
      default: n980_o = 1'b0;
    endcase
  /* T65_MCode.vhd:161:17  */
  assign n982_o = n940_o == 3'b101;
  /* T65_MCode.vhd:177:32  */
  assign n983_o = ir[1:0];
  /* T65_MCode.vhd:179:38  */
  assign n984_o = ir[4];
  /* T65_MCode.vhd:179:42  */
  assign n985_o = ~n984_o;
  /* T65_MCode.vhd:179:33  */
  assign n988_o = n985_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:178:25  */
  assign n990_o = n983_o == 2'b00;
  /* T65_MCode.vhd:177:25  */
  always @*
    case (n990_o)
      1'b1: n993_o = 3'b011;
      default: n993_o = 3'b001;
    endcase
  /* T65_MCode.vhd:177:25  */
  always @*
    case (n990_o)
      1'b1: n995_o = n988_o;
      default: n995_o = 1'b0;
    endcase
  /* T65_MCode.vhd:175:17  */
  assign n997_o = n940_o == 3'b110;
  /* T65_MCode.vhd:189:32  */
  assign n998_o = ir[1:0];
  /* T65_MCode.vhd:191:38  */
  assign n999_o = ir[4];
  /* T65_MCode.vhd:191:42  */
  assign n1000_o = ~n999_o;
  /* T65_MCode.vhd:191:33  */
  assign n1003_o = n1000_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:190:25  */
  assign n1005_o = n998_o == 2'b00;
  /* T65_MCode.vhd:189:25  */
  always @*
    case (n1005_o)
      1'b1: n1008_o = 3'b010;
      default: n1008_o = 3'b001;
    endcase
  /* T65_MCode.vhd:189:25  */
  always @*
    case (n1005_o)
      1'b1: n1010_o = n1003_o;
      default: n1010_o = 1'b0;
    endcase
  /* T65_MCode.vhd:187:17  */
  assign n1012_o = n940_o == 3'b111;
  assign n1013_o = {n1012_o, n997_o, n982_o, n956_o};
  /* T65_MCode.vhd:147:17  */
  always @*
    case (n1013_o)
      4'b1000: n1016_o = n1008_o;
      4'b0100: n1016_o = n993_o;
      4'b0010: n1016_o = 3'b000;
      4'b0001: n1016_o = n950_o;
      default: n1016_o = 3'b001;
    endcase
  /* T65_MCode.vhd:147:17  */
  always @*
    case (n1013_o)
      4'b1000: n1019_o = 3'b000;
      4'b0100: n1019_o = 3'b000;
      4'b0010: n1019_o = 3'b000;
      4'b0001: n1019_o = n954_o;
      default: n1019_o = 3'b000;
    endcase
  /* T65_MCode.vhd:147:17  */
  always @*
    case (n1013_o)
      4'b1000: n1022_o = 1'b0;
      4'b0100: n1022_o = 1'b0;
      4'b0010: n1022_o = n975_o;
      4'b0001: n1022_o = 1'b0;
      default: n1022_o = 1'b0;
    endcase
  /* T65_MCode.vhd:147:17  */
  always @*
    case (n1013_o)
      4'b1000: n1025_o = n1010_o;
      4'b0100: n1025_o = 1'b0;
      4'b0010: n1025_o = n978_o;
      4'b0001: n1025_o = 1'b0;
      default: n1025_o = 1'b0;
    endcase
  /* T65_MCode.vhd:147:17  */
  always @*
    case (n1013_o)
      4'b1000: n1028_o = 1'b0;
      4'b0100: n1028_o = n995_o;
      4'b0010: n1028_o = n980_o;
      4'b0001: n1028_o = 1'b0;
      default: n1028_o = 1'b0;
    endcase
  /* T65_MCode.vhd:202:22  */
  assign n1030_o = ir[7:6];
  /* T65_MCode.vhd:202:35  */
  assign n1032_o = n1030_o != 2'b10;
  /* T65_MCode.vhd:202:49  */
  assign n1033_o = ir[1:0];
  /* T65_MCode.vhd:202:62  */
  assign n1035_o = n1033_o == 2'b10;
  /* T65_MCode.vhd:202:43  */
  assign n1036_o = n1035_o & n1032_o;
  /* T65_MCode.vhd:202:17  */
  assign n1038_o = n1036_o ? 3'b000 : n1016_o;
  /* T65_MCode.vhd:206:24  */
  assign n1039_o = ir[4:0];
  /* T65_MCode.vhd:214:38  */
  assign n1040_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:215:33  */
  assign n1042_o = n1040_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:219:33  */
  assign n1044_o = n1040_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:224:33  */
  assign n1046_o = n1040_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:229:33  */
  assign n1048_o = n1040_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:232:33  */
  assign n1050_o = n1040_o == 31'b0000000000000000000000000000101;
  /* T65_MCode.vhd:235:33  */
  assign n1052_o = n1040_o == 31'b0000000000000000000000000000110;
  /* T65.vhd:252:17  */
  assign n1053_o = {n1052_o, n1050_o, n1048_o, n1046_o, n1044_o, n1042_o};
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1060_o = 2'b00;
      6'b010000: n1060_o = 2'b11;
      6'b001000: n1060_o = 2'b11;
      6'b000100: n1060_o = 2'b01;
      6'b000010: n1060_o = 2'b01;
      6'b000001: n1060_o = 2'b01;
      default: n1060_o = 2'b00;
    endcase
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1064_o = n1019_o;
      6'b010000: n1064_o = n1019_o;
      6'b001000: n1064_o = n1019_o;
      6'b000100: n1064_o = 3'b101;
      6'b000010: n1064_o = 3'b110;
      6'b000001: n1064_o = 3'b111;
      default: n1064_o = n1019_o;
    endcase
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1067_o = 2'b10;
      6'b010000: n1067_o = 2'b00;
      6'b001000: n1067_o = 2'b00;
      6'b000100: n1067_o = 2'b00;
      6'b000010: n1067_o = 2'b00;
      6'b000001: n1067_o = 2'b00;
      default: n1067_o = 2'b00;
    endcase
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1072_o = 1'b0;
      6'b010000: n1072_o = 1'b0;
      6'b001000: n1072_o = 1'b1;
      6'b000100: n1072_o = 1'b1;
      6'b000010: n1072_o = 1'b1;
      6'b000001: n1072_o = 1'b0;
      default: n1072_o = 1'b0;
    endcase
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1075_o = 1'b0;
      6'b010000: n1075_o = 1'b1;
      6'b001000: n1075_o = 1'b0;
      6'b000100: n1075_o = 1'b0;
      6'b000010: n1075_o = 1'b0;
      6'b000001: n1075_o = 1'b0;
      default: n1075_o = 1'b0;
    endcase
  /* T65_MCode.vhd:214:33  */
  always @*
    case (n1053_o)
      6'b100000: n1080_o = 1'b0;
      6'b010000: n1080_o = 1'b0;
      6'b001000: n1080_o = 1'b0;
      6'b000100: n1080_o = 1'b1;
      6'b000010: n1080_o = 1'b1;
      6'b000001: n1080_o = 1'b1;
      default: n1080_o = 1'b0;
    endcase
  /* T65_MCode.vhd:211:25  */
  assign n1082_o = ir == 8'b00000000;
  /* T65_MCode.vhd:242:38  */
  assign n1083_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:243:33  */
  assign n1085_o = n1083_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:247:33  */
  assign n1087_o = n1083_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:251:33  */
  assign n1089_o = n1083_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:256:33  */
  assign n1091_o = n1083_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:258:33  */
  assign n1093_o = n1083_o == 31'b0000000000000000000000000000101;
  assign n1094_o = {n1093_o, n1091_o, n1089_o, n1087_o, n1085_o};
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1099_o = 2'b00;
      5'b01000: n1099_o = 2'b00;
      5'b00100: n1099_o = 2'b01;
      5'b00010: n1099_o = 2'b01;
      5'b00001: n1099_o = 2'b01;
      default: n1099_o = 2'b00;
    endcase
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1102_o = n1019_o;
      5'b01000: n1102_o = n1019_o;
      5'b00100: n1102_o = 3'b110;
      5'b00010: n1102_o = 3'b111;
      5'b00001: n1102_o = n1019_o;
      default: n1102_o = n1019_o;
    endcase
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1106_o = 2'b10;
      5'b01000: n1106_o = 2'b00;
      5'b00100: n1106_o = 2'b00;
      5'b00010: n1106_o = 2'b00;
      5'b00001: n1106_o = 2'b01;
      default: n1106_o = 2'b00;
    endcase
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1110_o = 1'b0;
      5'b01000: n1110_o = 1'b1;
      5'b00100: n1110_o = 1'b1;
      5'b00010: n1110_o = 1'b0;
      5'b00001: n1110_o = 1'b0;
      default: n1110_o = 1'b0;
    endcase
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1113_o = 1'b0;
      5'b01000: n1113_o = 1'b0;
      5'b00100: n1113_o = 1'b0;
      5'b00010: n1113_o = 1'b0;
      5'b00001: n1113_o = 1'b1;
      default: n1113_o = 1'b0;
    endcase
  /* T65_MCode.vhd:242:33  */
  always @*
    case (n1094_o)
      5'b10000: n1117_o = 1'b0;
      5'b01000: n1117_o = 1'b0;
      5'b00100: n1117_o = 1'b1;
      5'b00010: n1117_o = 1'b1;
      5'b00001: n1117_o = 1'b0;
      default: n1117_o = 1'b0;
    endcase
  /* T65_MCode.vhd:239:25  */
  assign n1119_o = ir == 8'b00100000;
  /* T65_MCode.vhd:265:38  */
  assign n1120_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:266:33  */
  assign n1122_o = n1120_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:268:33  */
  assign n1124_o = n1120_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:271:33  */
  assign n1126_o = n1120_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:275:33  */
  assign n1128_o = n1120_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:280:33  */
  assign n1130_o = n1120_o == 31'b0000000000000000000000000000101;
  assign n1131_o = {n1130_o, n1128_o, n1126_o, n1124_o, n1122_o};
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1133_o = n1038_o;
      5'b01000: n1133_o = n1038_o;
      5'b00100: n1133_o = 3'b000;
      5'b00010: n1133_o = n1038_o;
      5'b00001: n1133_o = n1038_o;
      default: n1133_o = n1038_o;
    endcase
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1139_o = 2'b00;
      5'b01000: n1139_o = 2'b01;
      5'b00100: n1139_o = 2'b01;
      5'b00010: n1139_o = 2'b01;
      5'b00001: n1139_o = 2'b01;
      default: n1139_o = 2'b00;
    endcase
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1142_o = 2'b10;
      5'b01000: n1142_o = 2'b00;
      5'b00100: n1142_o = 2'b00;
      5'b00010: n1142_o = 2'b00;
      5'b00001: n1142_o = 2'b00;
      default: n1142_o = 2'b00;
    endcase
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1147_o = 1'b0;
      5'b01000: n1147_o = 1'b1;
      5'b00100: n1147_o = 1'b1;
      5'b00010: n1147_o = 1'b1;
      5'b00001: n1147_o = 1'b0;
      default: n1147_o = 1'b0;
    endcase
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1150_o = 1'b0;
      5'b01000: n1150_o = 1'b1;
      5'b00100: n1150_o = 1'b0;
      5'b00010: n1150_o = 1'b0;
      5'b00001: n1150_o = 1'b0;
      default: n1150_o = 1'b0;
    endcase
  /* T65_MCode.vhd:265:33  */
  always @*
    case (n1131_o)
      5'b10000: n1153_o = 1'b0;
      5'b01000: n1153_o = 1'b1;
      5'b00100: n1153_o = 1'b0;
      5'b00010: n1153_o = 1'b0;
      5'b00001: n1153_o = 1'b0;
      default: n1153_o = 1'b0;
    endcase
  /* T65_MCode.vhd:262:25  */
  assign n1155_o = ir == 8'b01000000;
  /* T65_MCode.vhd:287:38  */
  assign n1156_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:288:33  */
  assign n1158_o = n1156_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:290:33  */
  assign n1160_o = n1156_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:293:33  */
  assign n1162_o = n1156_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:297:33  */
  assign n1164_o = n1156_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:299:33  */
  assign n1166_o = n1156_o == 31'b0000000000000000000000000000101;
  assign n1167_o = {n1166_o, n1164_o, n1162_o, n1160_o, n1158_o};
  /* T65_MCode.vhd:287:33  */
  always @*
    case (n1167_o)
      5'b10000: n1172_o = 2'b00;
      5'b01000: n1172_o = 2'b00;
      5'b00100: n1172_o = 2'b01;
      5'b00010: n1172_o = 2'b01;
      5'b00001: n1172_o = 2'b01;
      default: n1172_o = 2'b00;
    endcase
  /* T65_MCode.vhd:287:33  */
  always @*
    case (n1167_o)
      5'b10000: n1176_o = 2'b01;
      5'b01000: n1176_o = 2'b10;
      5'b00100: n1176_o = 2'b00;
      5'b00010: n1176_o = 2'b00;
      5'b00001: n1176_o = 2'b00;
      default: n1176_o = 2'b00;
    endcase
  /* T65_MCode.vhd:287:33  */
  always @*
    case (n1167_o)
      5'b10000: n1180_o = 1'b0;
      5'b01000: n1180_o = 1'b0;
      5'b00100: n1180_o = 1'b1;
      5'b00010: n1180_o = 1'b1;
      5'b00001: n1180_o = 1'b0;
      default: n1180_o = 1'b0;
    endcase
  /* T65_MCode.vhd:287:33  */
  always @*
    case (n1167_o)
      5'b10000: n1183_o = 1'b0;
      5'b01000: n1183_o = 1'b0;
      5'b00100: n1183_o = 1'b1;
      5'b00010: n1183_o = 1'b0;
      5'b00001: n1183_o = 1'b0;
      default: n1183_o = 1'b0;
    endcase
  /* T65_MCode.vhd:284:25  */
  assign n1185_o = ir == 8'b01100000;
  /* T65_MCode.vhd:306:41  */
  assign n1187_o = mode == 2'b00;
  /* T65_MCode.vhd:306:54  */
  assign n1188_o = ir[1];
  /* T65_MCode.vhd:306:48  */
  assign n1189_o = n1188_o & n1187_o;
  /* T65_MCode.vhd:306:33  */
  assign n1192_o = n1189_o ? 3'b001 : 3'b010;
  /* T65_MCode.vhd:309:38  */
  assign n1194_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:311:48  */
  assign n1195_o = ir[7:4];
  /* T65_MCode.vhd:312:41  */
  assign n1197_o = n1195_o == 4'b0000;
  /* T65_MCode.vhd:314:41  */
  assign n1199_o = n1195_o == 4'b0100;
  /* T65_MCode.vhd:316:41  */
  assign n1201_o = n1195_o == 4'b0101;
  /* T65_MCode.vhd:318:41  */
  assign n1203_o = n1195_o == 4'b1101;
  assign n1204_o = {n1203_o, n1201_o, n1199_o, n1197_o};
  /* T65_MCode.vhd:311:41  */
  always @*
    case (n1204_o)
      4'b1000: n1209_o = 3'b010;
      4'b0100: n1209_o = 3'b011;
      4'b0010: n1209_o = 3'b001;
      4'b0001: n1209_o = 3'b101;
      default: n1209_o = n1019_o;
    endcase
  /* T65_MCode.vhd:310:33  */
  assign n1211_o = n1194_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:324:33  */
  assign n1213_o = n1194_o == 31'b0000000000000000000000000000010;
  assign n1214_o = {n1213_o, n1211_o};
  /* T65_MCode.vhd:309:33  */
  always @*
    case (n1214_o)
      2'b10: n1217_o = 2'b00;
      2'b01: n1217_o = 2'b01;
      default: n1217_o = 2'b00;
    endcase
  /* T65_MCode.vhd:309:33  */
  always @*
    case (n1214_o)
      2'b10: n1218_o = n1019_o;
      2'b01: n1218_o = n1209_o;
      default: n1218_o = n1019_o;
    endcase
  /* T65_MCode.vhd:309:33  */
  always @*
    case (n1214_o)
      2'b10: n1221_o = 1'b1;
      2'b01: n1221_o = 1'b0;
      default: n1221_o = 1'b0;
    endcase
  /* T65_MCode.vhd:309:33  */
  always @*
    case (n1214_o)
      2'b10: n1224_o = 1'b0;
      2'b01: n1224_o = 1'b1;
      default: n1224_o = 1'b0;
    endcase
  /* T65_MCode.vhd:303:25  */
  assign n1226_o = ir == 8'b00001000;
  /* T65_MCode.vhd:303:41  */
  assign n1228_o = ir == 8'b01001000;
  /* T65_MCode.vhd:303:41  */
  assign n1229_o = n1226_o | n1228_o;
  /* T65_MCode.vhd:303:54  */
  assign n1231_o = ir == 8'b01011010;
  /* T65_MCode.vhd:303:54  */
  assign n1232_o = n1229_o | n1231_o;
  /* T65_MCode.vhd:303:67  */
  assign n1234_o = ir == 8'b11011010;
  /* T65_MCode.vhd:303:67  */
  assign n1235_o = n1232_o | n1234_o;
  /* T65_MCode.vhd:331:41  */
  assign n1237_o = mode == 2'b00;
  /* T65_MCode.vhd:331:54  */
  assign n1238_o = ir[1];
  /* T65_MCode.vhd:331:48  */
  assign n1239_o = n1238_o & n1237_o;
  /* T65_MCode.vhd:331:33  */
  assign n1242_o = n1239_o ? 3'b001 : 3'b011;
  /* T65_MCode.vhd:334:40  */
  assign n1244_o = ir[7:4];
  /* T65_MCode.vhd:335:33  */
  assign n1246_o = n1244_o == 4'b0010;
  /* T65_MCode.vhd:337:33  */
  assign n1248_o = n1244_o == 4'b0110;
  /* T65_MCode.vhd:340:49  */
  assign n1250_o = mode != 2'b00;
  /* T65_MCode.vhd:340:41  */
  assign n1252_o = n1250_o ? 1'b1 : n1028_o;
  /* T65_MCode.vhd:339:33  */
  assign n1254_o = n1244_o == 4'b0111;
  /* T65_MCode.vhd:344:49  */
  assign n1256_o = mode != 2'b00;
  /* T65_MCode.vhd:344:41  */
  assign n1258_o = n1256_o ? 1'b1 : n1025_o;
  /* T65_MCode.vhd:343:33  */
  assign n1260_o = n1244_o == 4'b1111;
  assign n1261_o = {n1260_o, n1254_o, n1248_o, n1246_o};
  /* T65_MCode.vhd:334:33  */
  always @*
    case (n1261_o)
      4'b1000: n1263_o = n1022_o;
      4'b0100: n1263_o = n1022_o;
      4'b0010: n1263_o = 1'b1;
      4'b0001: n1263_o = n1022_o;
      default: n1263_o = n1022_o;
    endcase
  /* T65_MCode.vhd:334:33  */
  always @*
    case (n1261_o)
      4'b1000: n1266_o = 1'b0;
      4'b0100: n1266_o = 1'b0;
      4'b0010: n1266_o = 1'b0;
      4'b0001: n1266_o = 1'b1;
      default: n1266_o = 1'b0;
    endcase
  /* T65_MCode.vhd:334:33  */
  always @*
    case (n1261_o)
      4'b1000: n1267_o = n1258_o;
      4'b0100: n1267_o = n1025_o;
      4'b0010: n1267_o = n1025_o;
      4'b0001: n1267_o = n1025_o;
      default: n1267_o = n1025_o;
    endcase
  /* T65_MCode.vhd:334:33  */
  always @*
    case (n1261_o)
      4'b1000: n1268_o = n1028_o;
      4'b0100: n1268_o = n1252_o;
      4'b0010: n1268_o = n1028_o;
      4'b0001: n1268_o = n1028_o;
      default: n1268_o = n1028_o;
    endcase
  /* T65_MCode.vhd:349:38  */
  assign n1269_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:350:33  */
  assign n1271_o = n1269_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:352:33  */
  assign n1273_o = n1269_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:354:33  */
  assign n1275_o = n1269_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:357:33  */
  assign n1277_o = n1269_o == 31'b0000000000000000000000000000011;
  assign n1278_o = {n1277_o, n1275_o, n1273_o, n1271_o};
  /* T65_MCode.vhd:349:33  */
  always @*
    case (n1278_o)
      4'b1000: n1280_o = 3'b000;
      4'b0100: n1280_o = n1038_o;
      4'b0010: n1280_o = n1038_o;
      4'b0001: n1280_o = n1038_o;
      default: n1280_o = n1038_o;
    endcase
  /* T65_MCode.vhd:349:33  */
  always @*
    case (n1278_o)
      4'b1000: n1284_o = 2'b00;
      4'b0100: n1284_o = 2'b01;
      4'b0010: n1284_o = 2'b01;
      4'b0001: n1284_o = 2'b00;
      default: n1284_o = 2'b00;
    endcase
  /* T65_MCode.vhd:349:33  */
  always @*
    case (n1278_o)
      4'b1000: n1287_o = 1'b0;
      4'b0100: n1287_o = 1'b1;
      4'b0010: n1287_o = 1'b0;
      4'b0001: n1287_o = 1'b0;
      default: n1287_o = 1'b0;
    endcase
  /* T65_MCode.vhd:349:33  */
  always @*
    case (n1278_o)
      4'b1000: n1290_o = 1'b0;
      4'b0100: n1290_o = 1'b0;
      4'b0010: n1290_o = 1'b0;
      4'b0001: n1290_o = 1'b1;
      default: n1290_o = 1'b0;
    endcase
  /* T65_MCode.vhd:328:25  */
  assign n1292_o = ir == 8'b00101000;
  /* T65_MCode.vhd:328:41  */
  assign n1294_o = ir == 8'b01101000;
  /* T65_MCode.vhd:328:41  */
  assign n1295_o = n1292_o | n1294_o;
  /* T65_MCode.vhd:328:54  */
  assign n1297_o = ir == 8'b01111010;
  /* T65_MCode.vhd:328:54  */
  assign n1298_o = n1295_o | n1297_o;
  /* T65_MCode.vhd:328:67  */
  assign n1300_o = ir == 8'b11111010;
  /* T65_MCode.vhd:328:67  */
  assign n1301_o = n1298_o | n1300_o;
  /* T65_MCode.vhd:364:38  */
  assign n1302_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:365:33  */
  assign n1304_o = n1302_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:366:33  */
  assign n1306_o = n1302_o == 31'b0000000000000000000000000000001;
  assign n1307_o = {n1306_o, n1304_o};
  /* T65_MCode.vhd:364:33  */
  always @*
    case (n1307_o)
      2'b10: n1310_o = 2'b01;
      2'b01: n1310_o = 2'b00;
      default: n1310_o = 2'b00;
    endcase
  /* T65_MCode.vhd:361:25  */
  assign n1312_o = ir == 8'b10100000;
  /* T65_MCode.vhd:361:41  */
  assign n1314_o = ir == 8'b11000000;
  /* T65_MCode.vhd:361:41  */
  assign n1315_o = n1312_o | n1314_o;
  /* T65_MCode.vhd:361:54  */
  assign n1317_o = ir == 8'b11100000;
  /* T65_MCode.vhd:361:54  */
  assign n1318_o = n1315_o | n1317_o;
  /* T65_MCode.vhd:373:38  */
  assign n1319_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:374:33  */
  assign n1321_o = n1319_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:375:33  */
  assign n1323_o = n1319_o == 31'b0000000000000000000000000000001;
  assign n1324_o = {n1323_o, n1321_o};
  /* T65_MCode.vhd:373:33  */
  always @*
    case (n1324_o)
      2'b10: n1326_o = 3'b011;
      2'b01: n1326_o = n1038_o;
      default: n1326_o = n1038_o;
    endcase
  /* T65_MCode.vhd:370:25  */
  assign n1328_o = ir == 8'b10001000;
  /* T65_MCode.vhd:382:38  */
  assign n1329_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:383:33  */
  assign n1331_o = n1329_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:384:33  */
  assign n1333_o = n1329_o == 31'b0000000000000000000000000000001;
  assign n1334_o = {n1333_o, n1331_o};
  /* T65_MCode.vhd:382:33  */
  always @*
    case (n1334_o)
      2'b10: n1336_o = 3'b010;
      2'b01: n1336_o = n1038_o;
      default: n1336_o = n1038_o;
    endcase
  /* T65_MCode.vhd:379:25  */
  assign n1338_o = ir == 8'b11001010;
  /* T65_MCode.vhd:390:41  */
  assign n1340_o = mode != 2'b00;
  /* T65_MCode.vhd:390:33  */
  assign n1342_o = n1340_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:393:39  */
  assign n1344_o = ir == 8'b00011010;
  /* T65_MCode.vhd:396:46  */
  assign n1345_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:397:41  */
  assign n1347_o = n1345_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:398:41  */
  assign n1349_o = n1345_o == 31'b0000000000000000000000000000001;
  assign n1350_o = {n1349_o, n1347_o};
  /* T65_MCode.vhd:396:41  */
  always @*
    case (n1350_o)
      2'b10: n1352_o = 3'b100;
      2'b01: n1352_o = n1038_o;
      default: n1352_o = n1038_o;
    endcase
  /* T65_MCode.vhd:393:33  */
  assign n1354_o = n1344_o ? 3'b001 : n1352_o;
  /* T65_MCode.vhd:388:25  */
  assign n1356_o = ir == 8'b00011010;
  /* T65_MCode.vhd:388:41  */
  assign n1358_o = ir == 8'b00111010;
  /* T65_MCode.vhd:388:41  */
  assign n1359_o = n1356_o | n1358_o;
  /* T65_MCode.vhd:403:25  */
  assign n1367_o = ir == 8'b00001010;
  /* T65_MCode.vhd:403:41  */
  assign n1369_o = ir == 8'b00101010;
  /* T65_MCode.vhd:403:41  */
  assign n1370_o = n1367_o | n1369_o;
  /* T65_MCode.vhd:403:54  */
  assign n1372_o = ir == 8'b01001010;
  /* T65_MCode.vhd:403:54  */
  assign n1373_o = n1370_o | n1372_o;
  /* T65_MCode.vhd:403:67  */
  assign n1375_o = ir == 8'b01101010;
  /* T65_MCode.vhd:403:67  */
  assign n1376_o = n1373_o | n1375_o;
  /* T65_MCode.vhd:412:25  */
  assign n1384_o = ir == 8'b10001010;
  /* T65_MCode.vhd:412:41  */
  assign n1386_o = ir == 8'b10011000;
  /* T65_MCode.vhd:412:41  */
  assign n1387_o = n1384_o | n1386_o;
  /* T65_MCode.vhd:422:38  */
  assign n1388_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:423:33  */
  assign n1390_o = n1388_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:424:33  */
  assign n1392_o = n1388_o == 31'b0000000000000000000000000000001;
  assign n1393_o = {n1392_o, n1390_o};
  /* T65_MCode.vhd:422:33  */
  always @*
    case (n1393_o)
      2'b10: n1395_o = 3'b001;
      2'b01: n1395_o = n1038_o;
      default: n1395_o = n1038_o;
    endcase
  /* T65_MCode.vhd:420:25  */
  assign n1397_o = ir == 8'b10101010;
  /* T65_MCode.vhd:420:41  */
  assign n1399_o = ir == 8'b10101000;
  /* T65_MCode.vhd:420:41  */
  assign n1400_o = n1397_o | n1399_o;
  /* T65_MCode.vhd:430:38  */
  assign n1401_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:431:33  */
  assign n1403_o = n1401_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:433:33  */
  assign n1405_o = n1401_o == 31'b0000000000000000000000000000001;
  assign n1406_o = {n1405_o, n1403_o};
  /* T65_MCode.vhd:430:33  */
  always @*
    case (n1406_o)
      2'b10: n1409_o = 1'b0;
      2'b01: n1409_o = 1'b1;
      default: n1409_o = 1'b0;
    endcase
  /* T65_MCode.vhd:428:25  */
  assign n1411_o = ir == 8'b10011010;
  /* T65_MCode.vhd:439:38  */
  assign n1412_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:440:33  */
  assign n1414_o = n1412_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:441:33  */
  assign n1416_o = n1412_o == 31'b0000000000000000000000000000001;
  assign n1417_o = {n1416_o, n1414_o};
  /* T65_MCode.vhd:439:33  */
  always @*
    case (n1417_o)
      2'b10: n1419_o = 3'b100;
      2'b01: n1419_o = n1038_o;
      default: n1419_o = n1038_o;
    endcase
  /* T65_MCode.vhd:436:25  */
  assign n1421_o = ir == 8'b10111010;
  assign n1425_o = {n1421_o, n1411_o, n1400_o, n1387_o, n1376_o, n1359_o, n1338_o, n1328_o, n1318_o, n1301_o, n1235_o, n1185_o, n1155_o, n1119_o, n1082_o};
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1431_o = 3'b001;
      15'b010000000000000: n1431_o = 3'b001;
      15'b001000000000000: n1431_o = 3'b001;
      15'b000100000000000: n1431_o = 3'b001;
      15'b000010000000000: n1431_o = 3'b001;
      15'b000001000000000: n1431_o = 3'b001;
      15'b000000100000000: n1431_o = 3'b001;
      15'b000000010000000: n1431_o = 3'b001;
      15'b000000001000000: n1431_o = 3'b001;
      15'b000000000100000: n1431_o = n1242_o;
      15'b000000000010000: n1431_o = n1192_o;
      15'b000000000001000: n1431_o = 3'b101;
      15'b000000000000100: n1431_o = 3'b101;
      15'b000000000000010: n1431_o = 3'b101;
      15'b000000000000001: n1431_o = 3'b110;
      default: n1431_o = 3'b001;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1433_o = n1419_o;
      15'b010000000000000: n1433_o = n1038_o;
      15'b001000000000000: n1433_o = n1395_o;
      15'b000100000000000: n1433_o = n1038_o;
      15'b000010000000000: n1433_o = 3'b001;
      15'b000001000000000: n1433_o = n1354_o;
      15'b000000100000000: n1433_o = n1336_o;
      15'b000000010000000: n1433_o = n1326_o;
      15'b000000001000000: n1433_o = n1038_o;
      15'b000000000100000: n1433_o = n1280_o;
      15'b000000000010000: n1433_o = n1038_o;
      15'b000000000001000: n1433_o = n1038_o;
      15'b000000000000100: n1433_o = n1133_o;
      15'b000000000000010: n1433_o = n1038_o;
      15'b000000000000001: n1433_o = n1038_o;
      default: n1433_o = n1038_o;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1435_o = 2'b00;
      15'b010000000000000: n1435_o = 2'b00;
      15'b001000000000000: n1435_o = 2'b00;
      15'b000100000000000: n1435_o = 2'b00;
      15'b000010000000000: n1435_o = 2'b00;
      15'b000001000000000: n1435_o = 2'b00;
      15'b000000100000000: n1435_o = 2'b00;
      15'b000000010000000: n1435_o = 2'b00;
      15'b000000001000000: n1435_o = 2'b00;
      15'b000000000100000: n1435_o = n1284_o;
      15'b000000000010000: n1435_o = n1217_o;
      15'b000000000001000: n1435_o = n1172_o;
      15'b000000000000100: n1435_o = n1139_o;
      15'b000000000000010: n1435_o = n1099_o;
      15'b000000000000001: n1435_o = n1060_o;
      default: n1435_o = 2'b00;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1436_o = n1019_o;
      15'b010000000000000: n1436_o = n1019_o;
      15'b001000000000000: n1436_o = n1019_o;
      15'b000100000000000: n1436_o = n1019_o;
      15'b000010000000000: n1436_o = n1019_o;
      15'b000001000000000: n1436_o = n1019_o;
      15'b000000100000000: n1436_o = n1019_o;
      15'b000000010000000: n1436_o = n1019_o;
      15'b000000001000000: n1436_o = n1019_o;
      15'b000000000100000: n1436_o = n1019_o;
      15'b000000000010000: n1436_o = n1218_o;
      15'b000000000001000: n1436_o = n1019_o;
      15'b000000000000100: n1436_o = n1019_o;
      15'b000000000000010: n1436_o = n1102_o;
      15'b000000000000001: n1436_o = n1064_o;
      default: n1436_o = n1019_o;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1438_o = 2'b00;
      15'b010000000000000: n1438_o = 2'b00;
      15'b001000000000000: n1438_o = 2'b00;
      15'b000100000000000: n1438_o = 2'b00;
      15'b000010000000000: n1438_o = 2'b00;
      15'b000001000000000: n1438_o = 2'b00;
      15'b000000100000000: n1438_o = 2'b00;
      15'b000000010000000: n1438_o = 2'b00;
      15'b000000001000000: n1438_o = n1310_o;
      15'b000000000100000: n1438_o = 2'b00;
      15'b000000000010000: n1438_o = 2'b00;
      15'b000000000001000: n1438_o = n1176_o;
      15'b000000000000100: n1438_o = n1142_o;
      15'b000000000000010: n1438_o = n1106_o;
      15'b000000000000001: n1438_o = n1067_o;
      default: n1438_o = 2'b00;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1440_o = 1'b0;
      15'b010000000000000: n1440_o = 1'b0;
      15'b001000000000000: n1440_o = 1'b0;
      15'b000100000000000: n1440_o = 1'b0;
      15'b000010000000000: n1440_o = 1'b0;
      15'b000001000000000: n1440_o = 1'b0;
      15'b000000100000000: n1440_o = 1'b0;
      15'b000000010000000: n1440_o = 1'b0;
      15'b000000001000000: n1440_o = 1'b0;
      15'b000000000100000: n1440_o = n1287_o;
      15'b000000000010000: n1440_o = 1'b0;
      15'b000000000001000: n1440_o = n1180_o;
      15'b000000000000100: n1440_o = n1147_o;
      15'b000000000000010: n1440_o = 1'b0;
      15'b000000000000001: n1440_o = 1'b0;
      default: n1440_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1442_o = 1'b0;
      15'b010000000000000: n1442_o = 1'b0;
      15'b001000000000000: n1442_o = 1'b0;
      15'b000100000000000: n1442_o = 1'b0;
      15'b000010000000000: n1442_o = 1'b0;
      15'b000001000000000: n1442_o = 1'b0;
      15'b000000100000000: n1442_o = 1'b0;
      15'b000000010000000: n1442_o = 1'b0;
      15'b000000001000000: n1442_o = 1'b0;
      15'b000000000100000: n1442_o = 1'b0;
      15'b000000000010000: n1442_o = n1221_o;
      15'b000000000001000: n1442_o = 1'b0;
      15'b000000000000100: n1442_o = 1'b0;
      15'b000000000000010: n1442_o = n1110_o;
      15'b000000000000001: n1442_o = n1072_o;
      default: n1442_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1445_o = n1022_o;
      15'b010000000000000: n1445_o = n1022_o;
      15'b001000000000000: n1445_o = n1022_o;
      15'b000100000000000: n1445_o = 1'b1;
      15'b000010000000000: n1445_o = 1'b1;
      15'b000001000000000: n1445_o = n1342_o;
      15'b000000100000000: n1445_o = n1022_o;
      15'b000000010000000: n1445_o = n1022_o;
      15'b000000001000000: n1445_o = n1022_o;
      15'b000000000100000: n1445_o = n1263_o;
      15'b000000000010000: n1445_o = n1022_o;
      15'b000000000001000: n1445_o = n1022_o;
      15'b000000000000100: n1445_o = n1022_o;
      15'b000000000000010: n1445_o = n1022_o;
      15'b000000000000001: n1445_o = n1022_o;
      default: n1445_o = n1022_o;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1447_o = 1'b0;
      15'b010000000000000: n1447_o = 1'b0;
      15'b001000000000000: n1447_o = 1'b0;
      15'b000100000000000: n1447_o = 1'b0;
      15'b000010000000000: n1447_o = 1'b0;
      15'b000001000000000: n1447_o = 1'b0;
      15'b000000100000000: n1447_o = 1'b0;
      15'b000000010000000: n1447_o = 1'b0;
      15'b000000001000000: n1447_o = 1'b0;
      15'b000000000100000: n1447_o = n1266_o;
      15'b000000000010000: n1447_o = 1'b0;
      15'b000000000001000: n1447_o = 1'b0;
      15'b000000000000100: n1447_o = n1150_o;
      15'b000000000000010: n1447_o = 1'b0;
      15'b000000000000001: n1447_o = 1'b0;
      default: n1447_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1450_o = 1'b1;
      15'b010000000000000: n1450_o = n1025_o;
      15'b001000000000000: n1450_o = n1025_o;
      15'b000100000000000: n1450_o = n1025_o;
      15'b000010000000000: n1450_o = n1025_o;
      15'b000001000000000: n1450_o = n1025_o;
      15'b000000100000000: n1450_o = 1'b1;
      15'b000000010000000: n1450_o = n1025_o;
      15'b000000001000000: n1450_o = n1025_o;
      15'b000000000100000: n1450_o = n1267_o;
      15'b000000000010000: n1450_o = n1025_o;
      15'b000000000001000: n1450_o = n1025_o;
      15'b000000000000100: n1450_o = n1025_o;
      15'b000000000000010: n1450_o = n1025_o;
      15'b000000000000001: n1450_o = n1025_o;
      default: n1450_o = n1025_o;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1452_o = n1028_o;
      15'b010000000000000: n1452_o = n1028_o;
      15'b001000000000000: n1452_o = n1028_o;
      15'b000100000000000: n1452_o = n1028_o;
      15'b000010000000000: n1452_o = n1028_o;
      15'b000001000000000: n1452_o = n1028_o;
      15'b000000100000000: n1452_o = n1028_o;
      15'b000000010000000: n1452_o = 1'b1;
      15'b000000001000000: n1452_o = n1028_o;
      15'b000000000100000: n1452_o = n1268_o;
      15'b000000000010000: n1452_o = n1028_o;
      15'b000000000001000: n1452_o = n1028_o;
      15'b000000000000100: n1452_o = n1028_o;
      15'b000000000000010: n1452_o = n1028_o;
      15'b000000000000001: n1452_o = n1028_o;
      default: n1452_o = n1028_o;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1454_o = 1'b0;
      15'b010000000000000: n1454_o = n1409_o;
      15'b001000000000000: n1454_o = 1'b0;
      15'b000100000000000: n1454_o = 1'b0;
      15'b000010000000000: n1454_o = 1'b0;
      15'b000001000000000: n1454_o = 1'b0;
      15'b000000100000000: n1454_o = 1'b0;
      15'b000000010000000: n1454_o = 1'b0;
      15'b000000001000000: n1454_o = 1'b0;
      15'b000000000100000: n1454_o = 1'b0;
      15'b000000000010000: n1454_o = 1'b0;
      15'b000000000001000: n1454_o = 1'b0;
      15'b000000000000100: n1454_o = 1'b0;
      15'b000000000000010: n1454_o = 1'b0;
      15'b000000000000001: n1454_o = 1'b0;
      default: n1454_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1456_o = 1'b0;
      15'b010000000000000: n1456_o = 1'b0;
      15'b001000000000000: n1456_o = 1'b0;
      15'b000100000000000: n1456_o = 1'b0;
      15'b000010000000000: n1456_o = 1'b0;
      15'b000001000000000: n1456_o = 1'b0;
      15'b000000100000000: n1456_o = 1'b0;
      15'b000000010000000: n1456_o = 1'b0;
      15'b000000001000000: n1456_o = 1'b0;
      15'b000000000100000: n1456_o = 1'b0;
      15'b000000000010000: n1456_o = 1'b0;
      15'b000000000001000: n1456_o = n1183_o;
      15'b000000000000100: n1456_o = n1153_o;
      15'b000000000000010: n1456_o = n1113_o;
      15'b000000000000001: n1456_o = n1075_o;
      default: n1456_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1458_o = 1'b0;
      15'b010000000000000: n1458_o = 1'b0;
      15'b001000000000000: n1458_o = 1'b0;
      15'b000100000000000: n1458_o = 1'b0;
      15'b000010000000000: n1458_o = 1'b0;
      15'b000001000000000: n1458_o = 1'b0;
      15'b000000100000000: n1458_o = 1'b0;
      15'b000000010000000: n1458_o = 1'b0;
      15'b000000001000000: n1458_o = 1'b0;
      15'b000000000100000: n1458_o = n1290_o;
      15'b000000000010000: n1458_o = 1'b0;
      15'b000000000001000: n1458_o = 1'b0;
      15'b000000000000100: n1458_o = 1'b0;
      15'b000000000000010: n1458_o = 1'b0;
      15'b000000000000001: n1458_o = 1'b0;
      default: n1458_o = 1'b0;
    endcase
  /* T65_MCode.vhd:210:25  */
  always @*
    case (n1425_o)
      15'b100000000000000: n1460_o = 1'b0;
      15'b010000000000000: n1460_o = 1'b0;
      15'b001000000000000: n1460_o = 1'b0;
      15'b000100000000000: n1460_o = 1'b0;
      15'b000010000000000: n1460_o = 1'b0;
      15'b000001000000000: n1460_o = 1'b0;
      15'b000000100000000: n1460_o = 1'b0;
      15'b000000010000000: n1460_o = 1'b0;
      15'b000000001000000: n1460_o = 1'b0;
      15'b000000000100000: n1460_o = 1'b0;
      15'b000000000010000: n1460_o = n1224_o;
      15'b000000000001000: n1460_o = 1'b0;
      15'b000000000000100: n1460_o = 1'b0;
      15'b000000000000010: n1460_o = n1117_o;
      15'b000000000000001: n1460_o = n1080_o;
      default: n1460_o = 1'b0;
    endcase
  /* T65_MCode.vhd:207:17  */
  assign n1462_o = n1039_o == 5'b00000;
  /* T65_MCode.vhd:207:30  */
  assign n1464_o = n1039_o == 5'b01000;
  /* T65_MCode.vhd:207:30  */
  assign n1465_o = n1462_o | n1464_o;
  /* T65_MCode.vhd:207:40  */
  assign n1467_o = n1039_o == 5'b01010;
  /* T65_MCode.vhd:207:40  */
  assign n1468_o = n1465_o | n1467_o;
  /* T65_MCode.vhd:207:50  */
  assign n1470_o = n1039_o == 5'b11000;
  /* T65_MCode.vhd:207:50  */
  assign n1471_o = n1468_o | n1470_o;
  /* T65_MCode.vhd:207:60  */
  assign n1473_o = n1039_o == 5'b11010;
  /* T65_MCode.vhd:207:60  */
  assign n1474_o = n1471_o | n1473_o;
  /* T65_MCode.vhd:464:30  */
  assign n1475_o = ir[7:6];
  /* T65_MCode.vhd:464:43  */
  assign n1477_o = n1475_o != 2'b10;
  /* T65_MCode.vhd:464:25  */
  assign n1479_o = n1477_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:467:30  */
  assign n1480_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:468:25  */
  assign n1482_o = n1480_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:469:25  */
  assign n1484_o = n1480_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:473:25  */
  assign n1486_o = n1480_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:476:25  */
  assign n1488_o = n1480_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:482:38  */
  assign n1489_o = ir[7:5];
  /* T65_MCode.vhd:482:51  */
  assign n1491_o = n1489_o == 3'b100;
  /* T65_MCode.vhd:482:33  */
  assign n1494_o = n1491_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:480:25  */
  assign n1496_o = n1480_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:486:25  */
  assign n1498_o = n1480_o == 31'b0000000000000000000000000000101;
  assign n1499_o = {n1498_o, n1496_o, n1488_o, n1486_o, n1484_o, n1482_o};
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1505_o = 2'b00;
      6'b010000: n1505_o = 2'b11;
      6'b001000: n1505_o = 2'b10;
      6'b000100: n1505_o = 2'b10;
      6'b000010: n1505_o = 2'b10;
      6'b000001: n1505_o = 2'b00;
      default: n1505_o = 2'b00;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1508_o = 2'b00;
      6'b010000: n1508_o = 2'b00;
      6'b001000: n1508_o = 2'b00;
      6'b000100: n1508_o = 2'b00;
      6'b000010: n1508_o = 2'b01;
      6'b000001: n1508_o = 2'b00;
      default: n1508_o = 2'b00;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1511_o = 2'b00;
      6'b010000: n1511_o = 2'b00;
      6'b001000: n1511_o = 2'b01;
      6'b000100: n1511_o = 2'b00;
      6'b000010: n1511_o = 2'b00;
      6'b000001: n1511_o = 2'b00;
      default: n1511_o = 2'b00;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1514_o = 1'b0;
      6'b010000: n1514_o = 1'b0;
      6'b001000: n1514_o = 1'b0;
      6'b000100: n1514_o = 1'b1;
      6'b000010: n1514_o = 1'b0;
      6'b000001: n1514_o = 1'b0;
      default: n1514_o = 1'b0;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1517_o = 1'b0;
      6'b010000: n1517_o = 1'b0;
      6'b001000: n1517_o = 1'b0;
      6'b000100: n1517_o = 1'b0;
      6'b000010: n1517_o = 1'b1;
      6'b000001: n1517_o = 1'b0;
      default: n1517_o = 1'b0;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1520_o = 1'b0;
      6'b010000: n1520_o = 1'b0;
      6'b001000: n1520_o = 1'b1;
      6'b000100: n1520_o = 1'b0;
      6'b000010: n1520_o = 1'b0;
      6'b000001: n1520_o = 1'b0;
      default: n1520_o = 1'b0;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1523_o = 1'b0;
      6'b010000: n1523_o = 1'b1;
      6'b001000: n1523_o = 1'b0;
      6'b000100: n1523_o = 1'b0;
      6'b000010: n1523_o = 1'b0;
      6'b000001: n1523_o = 1'b0;
      default: n1523_o = 1'b0;
    endcase
  /* T65_MCode.vhd:467:25  */
  always @*
    case (n1499_o)
      6'b100000: n1525_o = 1'b0;
      6'b010000: n1525_o = n1494_o;
      6'b001000: n1525_o = 1'b0;
      6'b000100: n1525_o = 1'b0;
      6'b000010: n1525_o = 1'b0;
      6'b000001: n1525_o = 1'b0;
      default: n1525_o = 1'b0;
    endcase
  /* T65_MCode.vhd:460:17  */
  assign n1527_o = n1039_o == 5'b00001;
  /* T65_MCode.vhd:460:30  */
  assign n1529_o = n1039_o == 5'b00011;
  /* T65_MCode.vhd:460:30  */
  assign n1530_o = n1527_o | n1529_o;
  /* T65_MCode.vhd:495:30  */
  assign n1531_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:496:25  */
  assign n1533_o = n1531_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:497:25  */
  assign n1535_o = n1531_o == 31'b0000000000000000000000000000001;
  assign n1536_o = {n1535_o, n1533_o};
  /* T65_MCode.vhd:495:25  */
  always @*
    case (n1536_o)
      2'b10: n1539_o = 2'b01;
      2'b01: n1539_o = 2'b00;
      default: n1539_o = 2'b00;
    endcase
  /* T65_MCode.vhd:491:17  */
  assign n1541_o = n1039_o == 5'b01001;
  /* T65_MCode.vhd:491:30  */
  assign n1543_o = n1039_o == 5'b01011;
  /* T65_MCode.vhd:491:30  */
  assign n1544_o = n1541_o | n1543_o;
  /* T65_MCode.vhd:508:30  */
  assign n1545_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:509:25  */
  assign n1547_o = n1545_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:511:39  */
  assign n1549_o = ir == 8'b10100010;
  /* T65_MCode.vhd:511:33  */
  assign n1552_o = n1549_o ? 2'b01 : 2'b00;
  /* T65_MCode.vhd:510:25  */
  assign n1554_o = n1545_o == 31'b0000000000000000000000000000001;
  assign n1555_o = {n1554_o, n1547_o};
  /* T65_MCode.vhd:508:25  */
  always @*
    case (n1555_o)
      2'b10: n1557_o = n1552_o;
      2'b01: n1557_o = 2'b00;
      default: n1557_o = 2'b00;
    endcase
  /* T65_MCode.vhd:504:17  */
  assign n1559_o = n1039_o == 5'b00010;
  /* T65_MCode.vhd:504:30  */
  assign n1561_o = n1039_o == 5'b10010;
  /* T65_MCode.vhd:504:30  */
  assign n1562_o = n1559_o | n1561_o;
  /* T65_MCode.vhd:525:30  */
  assign n1563_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:527:38  */
  assign n1564_o = ir[7:5];
  /* T65_MCode.vhd:527:51  */
  assign n1566_o = n1564_o == 3'b001;
  /* T65_MCode.vhd:527:33  */
  assign n1569_o = n1566_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:526:25  */
  assign n1571_o = n1563_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:533:38  */
  assign n1572_o = ir[7:5];
  /* T65_MCode.vhd:533:51  */
  assign n1574_o = n1572_o == 3'b100;
  /* T65_MCode.vhd:533:33  */
  assign n1577_o = n1574_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:530:25  */
  assign n1579_o = n1563_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:537:25  */
  assign n1581_o = n1563_o == 31'b0000000000000000000000000000010;
  assign n1582_o = {n1581_o, n1579_o, n1571_o};
  /* T65_MCode.vhd:525:25  */
  always @*
    case (n1582_o)
      3'b100: n1585_o = 2'b00;
      3'b010: n1585_o = 2'b10;
      3'b001: n1585_o = 2'b00;
      default: n1585_o = 2'b00;
    endcase
  /* T65_MCode.vhd:525:25  */
  always @*
    case (n1582_o)
      3'b100: n1588_o = 2'b00;
      3'b010: n1588_o = 2'b01;
      3'b001: n1588_o = 2'b00;
      default: n1588_o = 2'b00;
    endcase
  /* T65_MCode.vhd:525:25  */
  always @*
    case (n1582_o)
      3'b100: n1591_o = 1'b0;
      3'b010: n1591_o = 1'b1;
      3'b001: n1591_o = 1'b0;
      default: n1591_o = 1'b0;
    endcase
  /* T65_MCode.vhd:525:25  */
  always @*
    case (n1582_o)
      3'b100: n1593_o = 1'b0;
      3'b010: n1593_o = 1'b0;
      3'b001: n1593_o = n1569_o;
      default: n1593_o = 1'b0;
    endcase
  /* T65_MCode.vhd:525:25  */
  always @*
    case (n1582_o)
      3'b100: n1595_o = 1'b0;
      3'b010: n1595_o = n1577_o;
      3'b001: n1595_o = 1'b0;
      default: n1595_o = 1'b0;
    endcase
  /* T65_MCode.vhd:521:17  */
  assign n1597_o = n1039_o == 5'b00100;
  /* T65_MCode.vhd:545:30  */
  assign n1598_o = ir[7:6];
  /* T65_MCode.vhd:545:43  */
  assign n1600_o = n1598_o != 2'b10;
  /* T65_MCode.vhd:545:57  */
  assign n1601_o = ir[1:0];
  /* T65_MCode.vhd:545:70  */
  assign n1603_o = n1601_o == 2'b10;
  /* T65_MCode.vhd:545:51  */
  assign n1604_o = n1603_o & n1600_o;
  /* T65_MCode.vhd:548:38  */
  assign n1605_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:549:33  */
  assign n1607_o = n1605_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:553:33  */
  assign n1609_o = n1605_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:557:33  */
  assign n1611_o = n1605_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:562:33  */
  assign n1613_o = n1605_o == 31'b0000000000000000000000000000100;
  assign n1614_o = {n1613_o, n1611_o, n1609_o, n1607_o};
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1619_o = 2'b00;
      4'b0100: n1619_o = 2'b10;
      4'b0010: n1619_o = 2'b10;
      4'b0001: n1619_o = 2'b10;
      default: n1619_o = 2'b00;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1622_o = 2'b00;
      4'b0100: n1622_o = 2'b00;
      4'b0010: n1622_o = 2'b00;
      4'b0001: n1622_o = 2'b01;
      default: n1622_o = 2'b00;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1625_o = 1'b0;
      4'b0100: n1625_o = 1'b0;
      4'b0010: n1625_o = 1'b1;
      4'b0001: n1625_o = 1'b0;
      default: n1625_o = 1'b0;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1628_o = 1'b0;
      4'b0100: n1628_o = 1'b1;
      4'b0010: n1628_o = 1'b0;
      4'b0001: n1628_o = 1'b0;
      default: n1628_o = 1'b0;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1631_o = 1'b0;
      4'b0100: n1631_o = 1'b0;
      4'b0010: n1631_o = 1'b0;
      4'b0001: n1631_o = 1'b1;
      default: n1631_o = 1'b0;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1634_o = 1'b0;
      4'b0100: n1634_o = 1'b1;
      4'b0010: n1634_o = 1'b0;
      4'b0001: n1634_o = 1'b0;
      default: n1634_o = 1'b0;
    endcase
  /* T65_MCode.vhd:548:33  */
  always @*
    case (n1614_o)
      4'b1000: n1638_o = 1'b0;
      4'b0100: n1638_o = 1'b1;
      4'b0010: n1638_o = 1'b1;
      4'b0001: n1638_o = 1'b0;
      default: n1638_o = 1'b0;
    endcase
  /* T65_MCode.vhd:567:38  */
  assign n1639_o = ir[7:6];
  /* T65_MCode.vhd:567:51  */
  assign n1641_o = n1639_o != 2'b10;
  /* T65_MCode.vhd:567:33  */
  assign n1643_o = n1641_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:570:38  */
  assign n1644_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:571:33  */
  assign n1646_o = n1644_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:575:46  */
  assign n1647_o = ir[7:5];
  /* T65_MCode.vhd:575:59  */
  assign n1649_o = n1647_o == 3'b100;
  /* T65_MCode.vhd:575:41  */
  assign n1652_o = n1649_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:572:33  */
  assign n1654_o = n1644_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:579:33  */
  assign n1656_o = n1644_o == 31'b0000000000000000000000000000010;
  assign n1657_o = {n1656_o, n1654_o, n1646_o};
  /* T65_MCode.vhd:570:33  */
  always @*
    case (n1657_o)
      3'b100: n1660_o = 2'b00;
      3'b010: n1660_o = 2'b10;
      3'b001: n1660_o = 2'b00;
      default: n1660_o = 2'b00;
    endcase
  /* T65_MCode.vhd:570:33  */
  always @*
    case (n1657_o)
      3'b100: n1663_o = 2'b00;
      3'b010: n1663_o = 2'b01;
      3'b001: n1663_o = 2'b00;
      default: n1663_o = 2'b00;
    endcase
  /* T65_MCode.vhd:570:33  */
  always @*
    case (n1657_o)
      3'b100: n1666_o = 1'b0;
      3'b010: n1666_o = 1'b1;
      3'b001: n1666_o = 1'b0;
      default: n1666_o = 1'b0;
    endcase
  /* T65_MCode.vhd:570:33  */
  always @*
    case (n1657_o)
      3'b100: n1668_o = 1'b0;
      3'b010: n1668_o = n1652_o;
      3'b001: n1668_o = 1'b0;
      default: n1668_o = 1'b0;
    endcase
  /* T65_MCode.vhd:545:25  */
  assign n1671_o = n1604_o ? 3'b100 : 3'b010;
  /* T65_MCode.vhd:545:25  */
  assign n1672_o = n1604_o ? n1619_o : n1660_o;
  /* T65_MCode.vhd:545:25  */
  assign n1673_o = n1604_o ? n1622_o : n1663_o;
  /* T65_MCode.vhd:545:25  */
  assign n1674_o = n1604_o ? n1022_o : n1643_o;
  /* T65_MCode.vhd:545:25  */
  assign n1676_o = n1604_o ? n1625_o : 1'b0;
  /* T65_MCode.vhd:545:25  */
  assign n1678_o = n1604_o ? n1628_o : 1'b0;
  /* T65_MCode.vhd:545:25  */
  assign n1679_o = n1604_o ? n1631_o : n1666_o;
  /* T65_MCode.vhd:545:25  */
  assign n1681_o = n1604_o ? n1634_o : 1'b0;
  /* T65_MCode.vhd:545:25  */
  assign n1682_o = n1604_o ? n1638_o : n1668_o;
  /* T65_MCode.vhd:542:17  */
  assign n1684_o = n1039_o == 5'b00101;
  /* T65_MCode.vhd:542:30  */
  assign n1686_o = n1039_o == 5'b00110;
  /* T65_MCode.vhd:542:30  */
  assign n1687_o = n1684_o | n1686_o;
  /* T65_MCode.vhd:542:40  */
  assign n1689_o = n1039_o == 5'b00111;
  /* T65_MCode.vhd:542:40  */
  assign n1690_o = n1687_o | n1689_o;
  /* T65_MCode.vhd:588:30  */
  assign n1691_o = ir[7:6];
  /* T65_MCode.vhd:588:43  */
  assign n1693_o = n1691_o == 2'b01;
  /* T65_MCode.vhd:588:56  */
  assign n1694_o = ir[4:0];
  /* T65_MCode.vhd:588:69  */
  assign n1696_o = n1694_o == 5'b01100;
  /* T65_MCode.vhd:588:50  */
  assign n1697_o = n1696_o & n1693_o;
  /* T65_MCode.vhd:590:38  */
  assign n1698_o = ir[5];
  /* T65_MCode.vhd:590:42  */
  assign n1699_o = ~n1698_o;
  /* T65_MCode.vhd:593:46  */
  assign n1700_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:594:41  */
  assign n1702_o = n1700_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:597:41  */
  assign n1704_o = n1700_o == 31'b0000000000000000000000000000010;
  assign n1705_o = {n1704_o, n1702_o};
  /* T65_MCode.vhd:593:41  */
  always @*
    case (n1705_o)
      2'b10: n1709_o = 2'b10;
      2'b01: n1709_o = 2'b01;
      default: n1709_o = 2'b00;
    endcase
  /* T65_MCode.vhd:593:41  */
  always @*
    case (n1705_o)
      2'b10: n1712_o = 1'b0;
      2'b01: n1712_o = 1'b1;
      default: n1712_o = 1'b0;
    endcase
  /* T65_MCode.vhd:604:46  */
  assign n1713_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:605:41  */
  assign n1715_o = n1713_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:611:57  */
  assign n1717_o = mode != 2'b00;
  /* T65_MCode.vhd:611:49  */
  assign n1720_o = n1717_o ? 2'b10 : 2'b00;
  /* T65_MCode.vhd:614:57  */
  assign n1722_o = mode == 2'b00;
  /* T65_MCode.vhd:614:49  */
  assign n1725_o = n1722_o ? 2'b11 : 2'b00;
  /* T65_MCode.vhd:609:41  */
  assign n1727_o = n1713_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:619:57  */
  assign n1729_o = mode == 2'b00;
  /* T65_MCode.vhd:619:49  */
  assign n1732_o = n1729_o ? 2'b11 : 2'b00;
  /* T65_MCode.vhd:619:49  */
  assign n1735_o = n1729_o ? 2'b00 : 2'b01;
  /* T65_MCode.vhd:619:49  */
  assign n1738_o = n1729_o ? 2'b01 : 2'b00;
  /* T65_MCode.vhd:617:41  */
  assign n1740_o = n1713_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:625:41  */
  assign n1742_o = n1713_o == 31'b0000000000000000000000000000100;
  assign n1743_o = {n1742_o, n1740_o, n1727_o, n1715_o};
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1745_o = 2'b00;
      4'b0100: n1745_o = n1732_o;
      4'b0010: n1745_o = n1725_o;
      4'b0001: n1745_o = 2'b00;
      default: n1745_o = 2'b00;
    endcase
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1749_o = 2'b10;
      4'b0100: n1749_o = n1735_o;
      4'b0010: n1749_o = n1720_o;
      4'b0001: n1749_o = 2'b01;
      default: n1749_o = 2'b00;
    endcase
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1751_o = 2'b00;
      4'b0100: n1751_o = n1738_o;
      4'b0010: n1751_o = 2'b00;
      4'b0001: n1751_o = 2'b00;
      default: n1751_o = 2'b00;
    endcase
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1755_o = 1'b0;
      4'b0100: n1755_o = 1'b1;
      4'b0010: n1755_o = 1'b0;
      4'b0001: n1755_o = 1'b1;
      default: n1755_o = 1'b0;
    endcase
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1758_o = 1'b0;
      4'b0100: n1758_o = 1'b0;
      4'b0010: n1758_o = 1'b0;
      4'b0001: n1758_o = 1'b1;
      default: n1758_o = 1'b0;
    endcase
  /* T65_MCode.vhd:604:41  */
  always @*
    case (n1743_o)
      4'b1000: n1761_o = 1'b0;
      4'b0100: n1761_o = 1'b0;
      4'b0010: n1761_o = 1'b1;
      4'b0001: n1761_o = 1'b0;
      default: n1761_o = 1'b0;
    endcase
  /* T65_MCode.vhd:590:33  */
  assign n1764_o = n1699_o ? 3'b010 : 3'b100;
  /* T65_MCode.vhd:590:33  */
  assign n1766_o = n1699_o ? 2'b00 : n1745_o;
  /* T65_MCode.vhd:590:33  */
  assign n1767_o = n1699_o ? n1709_o : n1749_o;
  /* T65_MCode.vhd:590:33  */
  assign n1769_o = n1699_o ? 2'b00 : n1751_o;
  /* T65_MCode.vhd:590:33  */
  assign n1770_o = n1699_o ? n1712_o : n1755_o;
  /* T65_MCode.vhd:590:33  */
  assign n1772_o = n1699_o ? 1'b0 : n1758_o;
  /* T65_MCode.vhd:590:33  */
  assign n1774_o = n1699_o ? 1'b0 : n1761_o;
  /* T65_MCode.vhd:632:38  */
  assign n1775_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:634:46  */
  assign n1776_o = ir[7:5];
  /* T65_MCode.vhd:634:59  */
  assign n1778_o = n1776_o == 3'b001;
  /* T65_MCode.vhd:634:41  */
  assign n1781_o = n1778_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:633:33  */
  assign n1783_o = n1775_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:637:33  */
  assign n1785_o = n1775_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:643:46  */
  assign n1786_o = ir[7:5];
  /* T65_MCode.vhd:643:59  */
  assign n1788_o = n1786_o == 3'b100;
  /* T65_MCode.vhd:643:41  */
  assign n1791_o = n1788_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:640:33  */
  assign n1793_o = n1775_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:647:33  */
  assign n1795_o = n1775_o == 31'b0000000000000000000000000000011;
  assign n1796_o = {n1795_o, n1793_o, n1785_o, n1783_o};
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1799_o = 2'b00;
      4'b0100: n1799_o = 2'b11;
      4'b0010: n1799_o = 2'b00;
      4'b0001: n1799_o = 2'b00;
      default: n1799_o = 2'b00;
    endcase
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1803_o = 2'b00;
      4'b0100: n1803_o = 2'b01;
      4'b0010: n1803_o = 2'b01;
      4'b0001: n1803_o = 2'b00;
      default: n1803_o = 2'b00;
    endcase
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1806_o = 1'b0;
      4'b0100: n1806_o = 1'b0;
      4'b0010: n1806_o = 1'b1;
      4'b0001: n1806_o = 1'b0;
      default: n1806_o = 1'b0;
    endcase
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1809_o = 1'b0;
      4'b0100: n1809_o = 1'b1;
      4'b0010: n1809_o = 1'b0;
      4'b0001: n1809_o = 1'b0;
      default: n1809_o = 1'b0;
    endcase
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1811_o = 1'b0;
      4'b0100: n1811_o = 1'b0;
      4'b0010: n1811_o = 1'b0;
      4'b0001: n1811_o = n1781_o;
      default: n1811_o = 1'b0;
    endcase
  /* T65_MCode.vhd:632:33  */
  always @*
    case (n1796_o)
      4'b1000: n1813_o = 1'b0;
      4'b0100: n1813_o = n1791_o;
      4'b0010: n1813_o = 1'b0;
      4'b0001: n1813_o = 1'b0;
      default: n1813_o = 1'b0;
    endcase
  /* T65_MCode.vhd:588:25  */
  assign n1815_o = n1697_o ? n1764_o : 3'b011;
  /* T65_MCode.vhd:588:25  */
  assign n1816_o = n1697_o ? n1766_o : n1799_o;
  /* T65_MCode.vhd:588:25  */
  assign n1817_o = n1697_o ? n1767_o : n1803_o;
  /* T65_MCode.vhd:588:25  */
  assign n1819_o = n1697_o ? n1769_o : 2'b00;
  /* T65_MCode.vhd:588:25  */
  assign n1821_o = n1697_o ? n1770_o : 1'b0;
  /* T65_MCode.vhd:588:25  */
  assign n1822_o = n1697_o ? n1772_o : n1806_o;
  /* T65_MCode.vhd:588:25  */
  assign n1823_o = n1697_o ? n1774_o : n1809_o;
  /* T65_MCode.vhd:588:25  */
  assign n1825_o = n1697_o ? 1'b0 : n1811_o;
  /* T65_MCode.vhd:588:25  */
  assign n1827_o = n1697_o ? 1'b0 : n1813_o;
  /* T65_MCode.vhd:585:17  */
  assign n1829_o = n1039_o == 5'b01100;
  /* T65_MCode.vhd:656:30  */
  assign n1830_o = ir[7:6];
  /* T65_MCode.vhd:656:43  */
  assign n1832_o = n1830_o != 2'b10;
  /* T65_MCode.vhd:656:57  */
  assign n1833_o = ir[1:0];
  /* T65_MCode.vhd:656:70  */
  assign n1835_o = n1833_o == 2'b10;
  /* T65_MCode.vhd:656:51  */
  assign n1836_o = n1835_o & n1832_o;
  /* T65_MCode.vhd:659:38  */
  assign n1837_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:660:33  */
  assign n1839_o = n1837_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:663:33  */
  assign n1841_o = n1837_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:667:33  */
  assign n1843_o = n1837_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:671:33  */
  assign n1845_o = n1837_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:676:33  */
  assign n1847_o = n1837_o == 31'b0000000000000000000000000000101;
  assign n1848_o = {n1847_o, n1845_o, n1843_o, n1841_o, n1839_o};
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1853_o = 2'b00;
      5'b01000: n1853_o = 2'b11;
      5'b00100: n1853_o = 2'b11;
      5'b00010: n1853_o = 2'b11;
      5'b00001: n1853_o = 2'b00;
      default: n1853_o = 2'b00;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1857_o = 2'b00;
      5'b01000: n1857_o = 2'b00;
      5'b00100: n1857_o = 2'b00;
      5'b00010: n1857_o = 2'b01;
      5'b00001: n1857_o = 2'b01;
      default: n1857_o = 2'b00;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1860_o = 1'b0;
      5'b01000: n1860_o = 1'b0;
      5'b00100: n1860_o = 1'b1;
      5'b00010: n1860_o = 1'b0;
      5'b00001: n1860_o = 1'b0;
      default: n1860_o = 1'b0;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1863_o = 1'b0;
      5'b01000: n1863_o = 1'b1;
      5'b00100: n1863_o = 1'b0;
      5'b00010: n1863_o = 1'b0;
      5'b00001: n1863_o = 1'b0;
      default: n1863_o = 1'b0;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1866_o = 1'b0;
      5'b01000: n1866_o = 1'b0;
      5'b00100: n1866_o = 1'b0;
      5'b00010: n1866_o = 1'b0;
      5'b00001: n1866_o = 1'b1;
      default: n1866_o = 1'b0;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1869_o = 1'b0;
      5'b01000: n1869_o = 1'b0;
      5'b00100: n1869_o = 1'b0;
      5'b00010: n1869_o = 1'b1;
      5'b00001: n1869_o = 1'b0;
      default: n1869_o = 1'b0;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1873_o = 1'b0;
      5'b01000: n1873_o = 1'b1;
      5'b00100: n1873_o = 1'b0;
      5'b00010: n1873_o = 1'b0;
      5'b00001: n1873_o = 1'b0;
      default: n1873_o = 1'b0;
    endcase
  /* T65_MCode.vhd:659:33  */
  always @*
    case (n1848_o)
      5'b10000: n1877_o = 1'b0;
      5'b01000: n1877_o = 1'b1;
      5'b00100: n1877_o = 1'b1;
      5'b00010: n1877_o = 1'b0;
      5'b00001: n1877_o = 1'b0;
      default: n1877_o = 1'b0;
    endcase
  /* T65_MCode.vhd:682:38  */
  assign n1878_o = ir[7:6];
  /* T65_MCode.vhd:682:51  */
  assign n1880_o = n1878_o != 2'b10;
  /* T65_MCode.vhd:682:33  */
  assign n1882_o = n1880_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:685:38  */
  assign n1883_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:686:33  */
  assign n1885_o = n1883_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:687:33  */
  assign n1887_o = n1883_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:693:46  */
  assign n1888_o = ir[7:5];
  /* T65_MCode.vhd:693:59  */
  assign n1890_o = n1888_o == 3'b100;
  /* T65_MCode.vhd:693:41  */
  assign n1893_o = n1890_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:690:33  */
  assign n1895_o = n1883_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:697:33  */
  assign n1897_o = n1883_o == 31'b0000000000000000000000000000011;
  assign n1898_o = {n1897_o, n1895_o, n1887_o, n1885_o};
  /* T65_MCode.vhd:685:33  */
  always @*
    case (n1898_o)
      4'b1000: n1901_o = 2'b00;
      4'b0100: n1901_o = 2'b11;
      4'b0010: n1901_o = 2'b00;
      4'b0001: n1901_o = 2'b00;
      default: n1901_o = 2'b00;
    endcase
  /* T65_MCode.vhd:685:33  */
  always @*
    case (n1898_o)
      4'b1000: n1905_o = 2'b00;
      4'b0100: n1905_o = 2'b01;
      4'b0010: n1905_o = 2'b01;
      4'b0001: n1905_o = 2'b00;
      default: n1905_o = 2'b00;
    endcase
  /* T65_MCode.vhd:685:33  */
  always @*
    case (n1898_o)
      4'b1000: n1908_o = 1'b0;
      4'b0100: n1908_o = 1'b0;
      4'b0010: n1908_o = 1'b1;
      4'b0001: n1908_o = 1'b0;
      default: n1908_o = 1'b0;
    endcase
  /* T65_MCode.vhd:685:33  */
  always @*
    case (n1898_o)
      4'b1000: n1911_o = 1'b0;
      4'b0100: n1911_o = 1'b1;
      4'b0010: n1911_o = 1'b0;
      4'b0001: n1911_o = 1'b0;
      default: n1911_o = 1'b0;
    endcase
  /* T65_MCode.vhd:685:33  */
  always @*
    case (n1898_o)
      4'b1000: n1913_o = 1'b0;
      4'b0100: n1913_o = n1893_o;
      4'b0010: n1913_o = 1'b0;
      4'b0001: n1913_o = 1'b0;
      default: n1913_o = 1'b0;
    endcase
  /* T65_MCode.vhd:656:25  */
  assign n1916_o = n1836_o ? 3'b101 : 3'b011;
  /* T65_MCode.vhd:656:25  */
  assign n1917_o = n1836_o ? n1853_o : n1901_o;
  /* T65_MCode.vhd:656:25  */
  assign n1918_o = n1836_o ? n1857_o : n1905_o;
  /* T65_MCode.vhd:656:25  */
  assign n1919_o = n1836_o ? n1022_o : n1882_o;
  /* T65_MCode.vhd:656:25  */
  assign n1921_o = n1836_o ? n1860_o : 1'b0;
  /* T65_MCode.vhd:656:25  */
  assign n1923_o = n1836_o ? n1863_o : 1'b0;
  /* T65_MCode.vhd:656:25  */
  assign n1924_o = n1836_o ? n1866_o : n1908_o;
  /* T65_MCode.vhd:656:25  */
  assign n1925_o = n1836_o ? n1869_o : n1911_o;
  /* T65_MCode.vhd:656:25  */
  assign n1927_o = n1836_o ? n1873_o : 1'b0;
  /* T65_MCode.vhd:656:25  */
  assign n1928_o = n1836_o ? n1877_o : n1913_o;
  /* T65_MCode.vhd:653:17  */
  assign n1930_o = n1039_o == 5'b01101;
  /* T65_MCode.vhd:653:30  */
  assign n1932_o = n1039_o == 5'b01110;
  /* T65_MCode.vhd:653:30  */
  assign n1933_o = n1930_o | n1932_o;
  /* T65_MCode.vhd:653:40  */
  assign n1935_o = n1039_o == 5'b01111;
  /* T65_MCode.vhd:653:40  */
  assign n1936_o = n1933_o | n1935_o;
  /* T65_MCode.vhd:711:25  */
  assign n1939_o = branch ? 3'b011 : 3'b001;
  /* T65_MCode.vhd:724:30  */
  assign n1940_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:730:33  */
  assign n1942_o = n1940_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:744:33  */
  assign n1944_o = n1940_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:756:33  */
  assign n1946_o = n1940_o == 31'b0000000000000000000000000000011;
  assign n1947_o = {n1946_o, n1944_o, n1942_o};
  /* T65_MCode.vhd:724:25  */
  always @*
    case (n1947_o)
      3'b100: n1951_o = 2'b00;
      3'b010: n1951_o = 2'b11;
      3'b001: n1951_o = 2'b01;
      default: n1951_o = 2'b00;
    endcase
  /* T65_MCode.vhd:724:25  */
  always @*
    case (n1947_o)
      3'b100: n1954_o = 1'b0;
      3'b010: n1954_o = 1'b1;
      3'b001: n1954_o = 1'b0;
      default: n1954_o = 1'b0;
    endcase
  /* T65_MCode.vhd:724:25  */
  always @*
    case (n1947_o)
      3'b100: n1957_o = 1'b0;
      3'b010: n1957_o = 1'b0;
      3'b001: n1957_o = 1'b1;
      default: n1957_o = 1'b0;
    endcase
  /* T65_MCode.vhd:703:17  */
  assign n1959_o = n1039_o == 5'b10000;
  /* T65_MCode.vhd:768:30  */
  assign n1960_o = ir[7:6];
  /* T65_MCode.vhd:768:43  */
  assign n1962_o = n1960_o != 2'b10;
  /* T65_MCode.vhd:768:25  */
  assign n1964_o = n1962_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:771:30  */
  assign n1965_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:772:25  */
  assign n1967_o = n1965_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:773:25  */
  assign n1969_o = n1965_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:777:25  */
  assign n1971_o = n1965_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:781:25  */
  assign n1973_o = n1965_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:788:38  */
  assign n1974_o = ir[7:5];
  /* T65_MCode.vhd:788:51  */
  assign n1976_o = n1974_o == 3'b100;
  /* T65_MCode.vhd:788:33  */
  assign n1979_o = n1976_o ? 1'b0 : 1'b1;
  /* T65_MCode.vhd:788:33  */
  assign n1982_o = n1976_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:786:25  */
  assign n1984_o = n1965_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:794:25  */
  assign n1986_o = n1965_o == 31'b0000000000000000000000000000101;
  assign n1987_o = {n1986_o, n1984_o, n1973_o, n1971_o, n1969_o, n1967_o};
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n1989_o = n1038_o;
      6'b010000: n1989_o = n1038_o;
      6'b001000: n1989_o = 3'b011;
      6'b000100: n1989_o = n1038_o;
      6'b000010: n1989_o = n1038_o;
      6'b000001: n1989_o = n1038_o;
      default: n1989_o = n1038_o;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n1995_o = 2'b00;
      6'b010000: n1995_o = 2'b11;
      6'b001000: n1995_o = 2'b11;
      6'b000100: n1995_o = 2'b10;
      6'b000010: n1995_o = 2'b10;
      6'b000001: n1995_o = 2'b00;
      default: n1995_o = 2'b00;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n1998_o = 2'b00;
      6'b010000: n1998_o = 2'b00;
      6'b001000: n1998_o = 2'b00;
      6'b000100: n1998_o = 2'b00;
      6'b000010: n1998_o = 2'b01;
      6'b000001: n1998_o = 2'b00;
      default: n1998_o = 2'b00;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2003_o = 2'b00;
      6'b010000: n2003_o = 2'b11;
      6'b001000: n2003_o = 2'b10;
      6'b000100: n2003_o = 2'b01;
      6'b000010: n2003_o = 2'b00;
      6'b000001: n2003_o = 2'b00;
      default: n2003_o = 2'b00;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2005_o = 1'b0;
      6'b010000: n2005_o = n1979_o;
      6'b001000: n2005_o = 1'b0;
      6'b000100: n2005_o = 1'b0;
      6'b000010: n2005_o = 1'b0;
      6'b000001: n2005_o = 1'b0;
      default: n2005_o = 1'b0;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2008_o = 1'b0;
      6'b010000: n2008_o = 1'b0;
      6'b001000: n2008_o = 1'b0;
      6'b000100: n2008_o = 1'b0;
      6'b000010: n2008_o = 1'b1;
      6'b000001: n2008_o = 1'b0;
      default: n2008_o = 1'b0;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2011_o = 1'b0;
      6'b010000: n2011_o = 1'b0;
      6'b001000: n2011_o = 1'b0;
      6'b000100: n2011_o = 1'b1;
      6'b000010: n2011_o = 1'b0;
      6'b000001: n2011_o = 1'b0;
      default: n2011_o = 1'b0;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2014_o = 1'b0;
      6'b010000: n2014_o = 1'b0;
      6'b001000: n2014_o = 1'b1;
      6'b000100: n2014_o = 1'b0;
      6'b000010: n2014_o = 1'b0;
      6'b000001: n2014_o = 1'b0;
      default: n2014_o = 1'b0;
    endcase
  /* T65_MCode.vhd:771:25  */
  always @*
    case (n1987_o)
      6'b100000: n2016_o = 1'b0;
      6'b010000: n2016_o = n1982_o;
      6'b001000: n2016_o = 1'b0;
      6'b000100: n2016_o = 1'b0;
      6'b000010: n2016_o = 1'b0;
      6'b000001: n2016_o = 1'b0;
      default: n2016_o = 1'b0;
    endcase
  /* T65_MCode.vhd:764:17  */
  assign n2018_o = n1039_o == 5'b10001;
  /* T65_MCode.vhd:764:30  */
  assign n2020_o = n1039_o == 5'b10011;
  /* T65_MCode.vhd:764:30  */
  assign n2021_o = n2018_o | n2020_o;
  /* T65_MCode.vhd:802:30  */
  assign n2022_o = ir[7:6];
  /* T65_MCode.vhd:802:43  */
  assign n2024_o = n2022_o != 2'b10;
  /* T65_MCode.vhd:802:57  */
  assign n2025_o = ir[1:0];
  /* T65_MCode.vhd:802:70  */
  assign n2027_o = n2025_o == 2'b10;
  /* T65_MCode.vhd:802:51  */
  assign n2028_o = n2027_o & n2024_o;
  /* T65_MCode.vhd:805:38  */
  assign n2029_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:806:33  */
  assign n2031_o = n2029_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:810:33  */
  assign n2033_o = n2029_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:813:33  */
  assign n2035_o = n2029_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:817:33  */
  assign n2037_o = n2029_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:822:33  */
  assign n2039_o = n2029_o == 31'b0000000000000000000000000000101;
  assign n2040_o = {n2039_o, n2037_o, n2035_o, n2033_o, n2031_o};
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2046_o = 2'b00;
      5'b01000: n2046_o = 2'b10;
      5'b00100: n2046_o = 2'b10;
      5'b00010: n2046_o = 2'b10;
      5'b00001: n2046_o = 2'b10;
      default: n2046_o = 2'b00;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2049_o = 2'b00;
      5'b01000: n2049_o = 2'b00;
      5'b00100: n2049_o = 2'b00;
      5'b00010: n2049_o = 2'b00;
      5'b00001: n2049_o = 2'b01;
      default: n2049_o = 2'b00;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2052_o = 1'b0;
      5'b01000: n2052_o = 1'b0;
      5'b00100: n2052_o = 1'b0;
      5'b00010: n2052_o = 1'b1;
      5'b00001: n2052_o = 1'b0;
      default: n2052_o = 1'b0;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2055_o = 1'b0;
      5'b01000: n2055_o = 1'b0;
      5'b00100: n2055_o = 1'b1;
      5'b00010: n2055_o = 1'b0;
      5'b00001: n2055_o = 1'b0;
      default: n2055_o = 1'b0;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2058_o = 1'b0;
      5'b01000: n2058_o = 1'b1;
      5'b00100: n2058_o = 1'b0;
      5'b00010: n2058_o = 1'b0;
      5'b00001: n2058_o = 1'b0;
      default: n2058_o = 1'b0;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2061_o = 1'b0;
      5'b01000: n2061_o = 1'b0;
      5'b00100: n2061_o = 1'b0;
      5'b00010: n2061_o = 1'b0;
      5'b00001: n2061_o = 1'b1;
      default: n2061_o = 1'b0;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2064_o = 1'b0;
      5'b01000: n2064_o = 1'b1;
      5'b00100: n2064_o = 1'b0;
      5'b00010: n2064_o = 1'b0;
      5'b00001: n2064_o = 1'b0;
      default: n2064_o = 1'b0;
    endcase
  /* T65_MCode.vhd:805:33  */
  always @*
    case (n2040_o)
      5'b10000: n2068_o = 1'b0;
      5'b01000: n2068_o = 1'b1;
      5'b00100: n2068_o = 1'b1;
      5'b00010: n2068_o = 1'b0;
      5'b00001: n2068_o = 1'b0;
      default: n2068_o = 1'b0;
    endcase
  /* T65_MCode.vhd:827:38  */
  assign n2069_o = ir[7:6];
  /* T65_MCode.vhd:827:51  */
  assign n2071_o = n2069_o != 2'b10;
  /* T65_MCode.vhd:827:33  */
  assign n2073_o = n2071_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:830:38  */
  assign n2074_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:831:33  */
  assign n2076_o = n2074_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:832:33  */
  assign n2078_o = n2074_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:839:47  */
  assign n2079_o = ir[3:0];
  /* T65_MCode.vhd:839:60  */
  assign n2081_o = n2079_o == 4'b0110;
  /* T65_MCode.vhd:839:41  */
  assign n2084_o = n2081_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:843:46  */
  assign n2085_o = ir[7:5];
  /* T65_MCode.vhd:843:59  */
  assign n2087_o = n2085_o == 3'b100;
  /* T65_MCode.vhd:843:41  */
  assign n2090_o = n2087_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:836:33  */
  assign n2092_o = n2074_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:847:33  */
  assign n2094_o = n2074_o == 31'b0000000000000000000000000000011;
  assign n2095_o = {n2094_o, n2092_o, n2078_o, n2076_o};
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2099_o = 2'b00;
      4'b0100: n2099_o = 2'b10;
      4'b0010: n2099_o = 2'b10;
      4'b0001: n2099_o = 2'b00;
      default: n2099_o = 2'b00;
    endcase
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2102_o = 2'b00;
      4'b0100: n2102_o = 2'b00;
      4'b0010: n2102_o = 2'b01;
      4'b0001: n2102_o = 2'b00;
      default: n2102_o = 2'b00;
    endcase
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2105_o = 1'b0;
      4'b0100: n2105_o = 1'b1;
      4'b0010: n2105_o = 1'b0;
      4'b0001: n2105_o = 1'b0;
      default: n2105_o = 1'b0;
    endcase
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2107_o = 1'b0;
      4'b0100: n2107_o = n2084_o;
      4'b0010: n2107_o = 1'b0;
      4'b0001: n2107_o = 1'b0;
      default: n2107_o = 1'b0;
    endcase
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2110_o = 1'b0;
      4'b0100: n2110_o = 1'b0;
      4'b0010: n2110_o = 1'b1;
      4'b0001: n2110_o = 1'b0;
      default: n2110_o = 1'b0;
    endcase
  /* T65_MCode.vhd:830:33  */
  always @*
    case (n2095_o)
      4'b1000: n2112_o = 1'b0;
      4'b0100: n2112_o = n2090_o;
      4'b0010: n2112_o = 1'b0;
      4'b0001: n2112_o = 1'b0;
      default: n2112_o = 1'b0;
    endcase
  /* T65_MCode.vhd:802:25  */
  assign n2115_o = n2028_o ? 3'b101 : 3'b011;
  /* T65_MCode.vhd:802:25  */
  assign n2116_o = n2028_o ? n2046_o : n2099_o;
  /* T65_MCode.vhd:802:25  */
  assign n2117_o = n2028_o ? n2049_o : n2102_o;
  /* T65_MCode.vhd:802:25  */
  assign n2118_o = n2028_o ? n2052_o : n2105_o;
  /* T65_MCode.vhd:802:25  */
  assign n2120_o = n2028_o ? 1'b0 : n2107_o;
  /* T65_MCode.vhd:802:25  */
  assign n2121_o = n2028_o ? n1022_o : n2073_o;
  /* T65_MCode.vhd:802:25  */
  assign n2123_o = n2028_o ? n2055_o : 1'b0;
  /* T65_MCode.vhd:802:25  */
  assign n2125_o = n2028_o ? n2058_o : 1'b0;
  /* T65_MCode.vhd:802:25  */
  assign n2126_o = n2028_o ? n2061_o : n2110_o;
  /* T65_MCode.vhd:802:25  */
  assign n2128_o = n2028_o ? n2064_o : 1'b0;
  /* T65_MCode.vhd:802:25  */
  assign n2129_o = n2028_o ? n2068_o : n2112_o;
  /* T65_MCode.vhd:799:17  */
  assign n2131_o = n1039_o == 5'b10100;
  /* T65_MCode.vhd:799:30  */
  assign n2133_o = n1039_o == 5'b10101;
  /* T65_MCode.vhd:799:30  */
  assign n2134_o = n2131_o | n2133_o;
  /* T65_MCode.vhd:799:40  */
  assign n2136_o = n1039_o == 5'b10110;
  /* T65_MCode.vhd:799:40  */
  assign n2137_o = n2134_o | n2136_o;
  /* T65_MCode.vhd:799:50  */
  assign n2139_o = n1039_o == 5'b10111;
  /* T65_MCode.vhd:799:50  */
  assign n2140_o = n2137_o | n2139_o;
  /* T65_MCode.vhd:857:30  */
  assign n2141_o = ir[7:6];
  /* T65_MCode.vhd:857:43  */
  assign n2143_o = n2141_o != 2'b10;
  /* T65_MCode.vhd:857:25  */
  assign n2145_o = n2143_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:860:30  */
  assign n2146_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:861:25  */
  assign n2148_o = n2146_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:862:25  */
  assign n2150_o = n2146_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:865:25  */
  assign n2152_o = n2146_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:873:38  */
  assign n2153_o = ir[7:5];
  /* T65_MCode.vhd:873:51  */
  assign n2155_o = n2153_o == 3'b100;
  /* T65_MCode.vhd:873:33  */
  assign n2158_o = n2155_o ? 1'b0 : 1'b1;
  /* T65_MCode.vhd:873:33  */
  assign n2161_o = n2155_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:871:25  */
  assign n2163_o = n2146_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:879:25  */
  assign n2165_o = n2146_o == 31'b0000000000000000000000000000100;
  assign n2166_o = {n2165_o, n2163_o, n2152_o, n2150_o, n2148_o};
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2168_o = n1038_o;
      5'b01000: n2168_o = n1038_o;
      5'b00100: n2168_o = 3'b011;
      5'b00010: n2168_o = n1038_o;
      5'b00001: n2168_o = n1038_o;
      default: n2168_o = n1038_o;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2172_o = 2'b00;
      5'b01000: n2172_o = 2'b11;
      5'b00100: n2172_o = 2'b11;
      5'b00010: n2172_o = 2'b00;
      5'b00001: n2172_o = 2'b00;
      default: n2172_o = 2'b00;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2176_o = 2'b00;
      5'b01000: n2176_o = 2'b00;
      5'b00100: n2176_o = 2'b01;
      5'b00010: n2176_o = 2'b01;
      5'b00001: n2176_o = 2'b00;
      default: n2176_o = 2'b00;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2180_o = 2'b00;
      5'b01000: n2180_o = 2'b11;
      5'b00100: n2180_o = 2'b10;
      5'b00010: n2180_o = 2'b00;
      5'b00001: n2180_o = 2'b00;
      default: n2180_o = 2'b00;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2182_o = 1'b0;
      5'b01000: n2182_o = n2158_o;
      5'b00100: n2182_o = 1'b0;
      5'b00010: n2182_o = 1'b0;
      5'b00001: n2182_o = 1'b0;
      default: n2182_o = 1'b0;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2185_o = 1'b0;
      5'b01000: n2185_o = 1'b0;
      5'b00100: n2185_o = 1'b0;
      5'b00010: n2185_o = 1'b1;
      5'b00001: n2185_o = 1'b0;
      default: n2185_o = 1'b0;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2188_o = 1'b0;
      5'b01000: n2188_o = 1'b0;
      5'b00100: n2188_o = 1'b1;
      5'b00010: n2188_o = 1'b0;
      5'b00001: n2188_o = 1'b0;
      default: n2188_o = 1'b0;
    endcase
  /* T65_MCode.vhd:860:25  */
  always @*
    case (n2166_o)
      5'b10000: n2190_o = 1'b0;
      5'b01000: n2190_o = n2161_o;
      5'b00100: n2190_o = 1'b0;
      5'b00010: n2190_o = 1'b0;
      5'b00001: n2190_o = 1'b0;
      default: n2190_o = 1'b0;
    endcase
  /* T65_MCode.vhd:853:17  */
  assign n2192_o = n1039_o == 5'b11001;
  /* T65_MCode.vhd:853:30  */
  assign n2194_o = n1039_o == 5'b11011;
  /* T65_MCode.vhd:853:30  */
  assign n2195_o = n2192_o | n2194_o;
  /* T65_MCode.vhd:888:30  */
  assign n2196_o = ir[7:6];
  /* T65_MCode.vhd:888:43  */
  assign n2198_o = n2196_o != 2'b10;
  /* T65_MCode.vhd:888:57  */
  assign n2199_o = ir[1:0];
  /* T65_MCode.vhd:888:70  */
  assign n2201_o = n2199_o == 2'b10;
  /* T65_MCode.vhd:888:51  */
  assign n2202_o = n2201_o & n2198_o;
  /* T65_MCode.vhd:891:38  */
  assign n2203_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:892:33  */
  assign n2205_o = n2203_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:895:33  */
  assign n2207_o = n2203_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:901:33  */
  assign n2209_o = n2203_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:904:33  */
  assign n2211_o = n2203_o == 31'b0000000000000000000000000000100;
  /* T65_MCode.vhd:908:33  */
  assign n2213_o = n2203_o == 31'b0000000000000000000000000000101;
  /* T65_MCode.vhd:913:33  */
  assign n2215_o = n2203_o == 31'b0000000000000000000000000000110;
  assign n2216_o = {n2215_o, n2213_o, n2211_o, n2209_o, n2207_o, n2205_o};
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2218_o = n1038_o;
      6'b010000: n2218_o = n1038_o;
      6'b001000: n2218_o = n1038_o;
      6'b000100: n2218_o = n1038_o;
      6'b000010: n2218_o = 3'b010;
      6'b000001: n2218_o = n1038_o;
      default: n2218_o = n1038_o;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2224_o = 2'b00;
      6'b010000: n2224_o = 2'b11;
      6'b001000: n2224_o = 2'b11;
      6'b000100: n2224_o = 2'b11;
      6'b000010: n2224_o = 2'b11;
      6'b000001: n2224_o = 2'b00;
      default: n2224_o = 2'b00;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2228_o = 2'b00;
      6'b010000: n2228_o = 2'b00;
      6'b001000: n2228_o = 2'b00;
      6'b000100: n2228_o = 2'b00;
      6'b000010: n2228_o = 2'b01;
      6'b000001: n2228_o = 2'b01;
      default: n2228_o = 2'b00;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2232_o = 2'b00;
      6'b010000: n2232_o = 2'b00;
      6'b001000: n2232_o = 2'b00;
      6'b000100: n2232_o = 2'b11;
      6'b000010: n2232_o = 2'b10;
      6'b000001: n2232_o = 2'b00;
      default: n2232_o = 2'b00;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2235_o = 1'b0;
      6'b010000: n2235_o = 1'b0;
      6'b001000: n2235_o = 1'b1;
      6'b000100: n2235_o = 1'b0;
      6'b000010: n2235_o = 1'b0;
      6'b000001: n2235_o = 1'b0;
      default: n2235_o = 1'b0;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2238_o = 1'b0;
      6'b010000: n2238_o = 1'b1;
      6'b001000: n2238_o = 1'b0;
      6'b000100: n2238_o = 1'b0;
      6'b000010: n2238_o = 1'b0;
      6'b000001: n2238_o = 1'b0;
      default: n2238_o = 1'b0;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2241_o = 1'b0;
      6'b010000: n2241_o = 1'b0;
      6'b001000: n2241_o = 1'b0;
      6'b000100: n2241_o = 1'b0;
      6'b000010: n2241_o = 1'b0;
      6'b000001: n2241_o = 1'b1;
      default: n2241_o = 1'b0;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2244_o = 1'b0;
      6'b010000: n2244_o = 1'b0;
      6'b001000: n2244_o = 1'b0;
      6'b000100: n2244_o = 1'b0;
      6'b000010: n2244_o = 1'b1;
      6'b000001: n2244_o = 1'b0;
      default: n2244_o = 1'b0;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2247_o = 1'b0;
      6'b010000: n2247_o = 1'b1;
      6'b001000: n2247_o = 1'b0;
      6'b000100: n2247_o = 1'b0;
      6'b000010: n2247_o = 1'b0;
      6'b000001: n2247_o = 1'b0;
      default: n2247_o = 1'b0;
    endcase
  /* T65_MCode.vhd:891:33  */
  always @*
    case (n2216_o)
      6'b100000: n2251_o = 1'b0;
      6'b010000: n2251_o = 1'b1;
      6'b001000: n2251_o = 1'b1;
      6'b000100: n2251_o = 1'b0;
      6'b000010: n2251_o = 1'b0;
      6'b000001: n2251_o = 1'b0;
      default: n2251_o = 1'b0;
    endcase
  /* T65_MCode.vhd:918:38  */
  assign n2252_o = ir[7:6];
  /* T65_MCode.vhd:918:51  */
  assign n2254_o = n2252_o != 2'b10;
  /* T65_MCode.vhd:918:33  */
  assign n2256_o = n2254_o ? 1'b1 : n1022_o;
  /* T65_MCode.vhd:921:38  */
  assign n2257_o = {28'b0, mcycle};  //  uext
  /* T65_MCode.vhd:922:33  */
  assign n2259_o = n2257_o == 31'b0000000000000000000000000000000;
  /* T65_MCode.vhd:923:33  */
  assign n2261_o = n2257_o == 31'b0000000000000000000000000000001;
  /* T65_MCode.vhd:930:48  */
  assign n2263_o = ir == 8'b10111110;
  /* T65_MCode.vhd:930:41  */
  assign n2266_o = n2263_o ? 3'b011 : 3'b010;
  /* T65_MCode.vhd:926:33  */
  assign n2268_o = n2257_o == 31'b0000000000000000000000000000010;
  /* T65_MCode.vhd:940:46  */
  assign n2269_o = ir[7:5];
  /* T65_MCode.vhd:940:59  */
  assign n2271_o = n2269_o == 3'b100;
  /* T65_MCode.vhd:940:41  */
  assign n2274_o = n2271_o ? 1'b0 : 1'b1;
  /* T65_MCode.vhd:940:41  */
  assign n2277_o = n2271_o ? 1'b1 : 1'b0;
  /* T65_MCode.vhd:938:33  */
  assign n2279_o = n2257_o == 31'b0000000000000000000000000000011;
  /* T65_MCode.vhd:946:33  */
  assign n2281_o = n2257_o == 31'b0000000000000000000000000000100;
  assign n2282_o = {n2281_o, n2279_o, n2268_o, n2261_o, n2259_o};
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2283_o = n1038_o;
      5'b01000: n2283_o = n1038_o;
      5'b00100: n2283_o = n2266_o;
      5'b00010: n2283_o = n1038_o;
      5'b00001: n2283_o = n1038_o;
      default: n2283_o = n1038_o;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2287_o = 2'b00;
      5'b01000: n2287_o = 2'b11;
      5'b00100: n2287_o = 2'b11;
      5'b00010: n2287_o = 2'b00;
      5'b00001: n2287_o = 2'b00;
      default: n2287_o = 2'b00;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2291_o = 2'b00;
      5'b01000: n2291_o = 2'b00;
      5'b00100: n2291_o = 2'b01;
      5'b00010: n2291_o = 2'b01;
      5'b00001: n2291_o = 2'b00;
      default: n2291_o = 2'b00;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2295_o = 2'b00;
      5'b01000: n2295_o = 2'b11;
      5'b00100: n2295_o = 2'b10;
      5'b00010: n2295_o = 2'b00;
      5'b00001: n2295_o = 2'b00;
      default: n2295_o = 2'b00;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2297_o = 1'b0;
      5'b01000: n2297_o = n2274_o;
      5'b00100: n2297_o = 1'b0;
      5'b00010: n2297_o = 1'b0;
      5'b00001: n2297_o = 1'b0;
      default: n2297_o = 1'b0;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2300_o = 1'b0;
      5'b01000: n2300_o = 1'b0;
      5'b00100: n2300_o = 1'b0;
      5'b00010: n2300_o = 1'b1;
      5'b00001: n2300_o = 1'b0;
      default: n2300_o = 1'b0;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2303_o = 1'b0;
      5'b01000: n2303_o = 1'b0;
      5'b00100: n2303_o = 1'b1;
      5'b00010: n2303_o = 1'b0;
      5'b00001: n2303_o = 1'b0;
      default: n2303_o = 1'b0;
    endcase
  /* T65_MCode.vhd:921:33  */
  always @*
    case (n2282_o)
      5'b10000: n2305_o = 1'b0;
      5'b01000: n2305_o = n2277_o;
      5'b00100: n2305_o = 1'b0;
      5'b00010: n2305_o = 1'b0;
      5'b00001: n2305_o = 1'b0;
      default: n2305_o = 1'b0;
    endcase
  /* T65_MCode.vhd:888:25  */
  assign n2308_o = n2202_o ? 3'b110 : 3'b100;
  /* T65_MCode.vhd:888:25  */
  assign n2309_o = n2202_o ? n2218_o : n2283_o;
  /* T65_MCode.vhd:888:25  */
  assign n2310_o = n2202_o ? n2224_o : n2287_o;
  /* T65_MCode.vhd:888:25  */
  assign n2311_o = n2202_o ? n2228_o : n2291_o;
  /* T65_MCode.vhd:888:25  */
  assign n2312_o = n2202_o ? n2232_o : n2295_o;
  /* T65_MCode.vhd:888:25  */
  assign n2314_o = n2202_o ? 1'b0 : n2297_o;
  /* T65_MCode.vhd:888:25  */
  assign n2315_o = n2202_o ? n1022_o : n2256_o;
  /* T65_MCode.vhd:888:25  */
  assign n2317_o = n2202_o ? n2235_o : 1'b0;
  /* T65_MCode.vhd:888:25  */
  assign n2319_o = n2202_o ? n2238_o : 1'b0;
  /* T65_MCode.vhd:888:25  */
  assign n2320_o = n2202_o ? n2241_o : n2300_o;
  /* T65_MCode.vhd:888:25  */
  assign n2321_o = n2202_o ? n2244_o : n2303_o;
  /* T65_MCode.vhd:888:25  */
  assign n2323_o = n2202_o ? n2247_o : 1'b0;
  /* T65_MCode.vhd:888:25  */
  assign n2324_o = n2202_o ? n2251_o : n2305_o;
  /* T65_MCode.vhd:884:17  */
  assign n2326_o = n1039_o == 5'b11100;
  /* T65_MCode.vhd:884:30  */
  assign n2328_o = n1039_o == 5'b11101;
  /* T65_MCode.vhd:884:30  */
  assign n2329_o = n2326_o | n2328_o;
  /* T65_MCode.vhd:884:40  */
  assign n2331_o = n1039_o == 5'b11110;
  /* T65_MCode.vhd:884:40  */
  assign n2332_o = n2329_o | n2331_o;
  /* T65_MCode.vhd:884:50  */
  assign n2334_o = n1039_o == 5'b11111;
  /* T65_MCode.vhd:884:50  */
  assign n2335_o = n2332_o | n2334_o;
  assign n2336_o = {n2335_o, n2195_o, n2140_o, n2021_o, n1959_o, n1936_o, n1829_o, n1690_o, n1597_o, n1562_o, n1544_o, n1530_o, n1474_o};
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2342_o = n2308_o;
      13'b0100000000000: n2342_o = 3'b100;
      13'b0010000000000: n2342_o = n2115_o;
      13'b0001000000000: n2342_o = 3'b101;
      13'b0000100000000: n2342_o = n1939_o;
      13'b0000010000000: n2342_o = n1916_o;
      13'b0000001000000: n2342_o = n1815_o;
      13'b0000000100000: n2342_o = n1671_o;
      13'b0000000010000: n2342_o = 3'b010;
      13'b0000000001000: n2342_o = 3'b001;
      13'b0000000000100: n2342_o = 3'b001;
      13'b0000000000010: n2342_o = 3'b101;
      13'b0000000000001: n2342_o = n1431_o;
      default: n2342_o = 3'b001;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2344_o = n2309_o;
      13'b0100000000000: n2344_o = n2168_o;
      13'b0010000000000: n2344_o = n1038_o;
      13'b0001000000000: n2344_o = n1989_o;
      13'b0000100000000: n2344_o = n1038_o;
      13'b0000010000000: n2344_o = n1038_o;
      13'b0000001000000: n2344_o = n1038_o;
      13'b0000000100000: n2344_o = n1038_o;
      13'b0000000010000: n2344_o = n1038_o;
      13'b0000000001000: n2344_o = n1038_o;
      13'b0000000000100: n2344_o = n1038_o;
      13'b0000000000010: n2344_o = n1038_o;
      13'b0000000000001: n2344_o = n1433_o;
      default: n2344_o = n1038_o;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2346_o = n2310_o;
      13'b0100000000000: n2346_o = n2172_o;
      13'b0010000000000: n2346_o = n2116_o;
      13'b0001000000000: n2346_o = n1995_o;
      13'b0000100000000: n2346_o = 2'b00;
      13'b0000010000000: n2346_o = n1917_o;
      13'b0000001000000: n2346_o = n1816_o;
      13'b0000000100000: n2346_o = n1672_o;
      13'b0000000010000: n2346_o = n1585_o;
      13'b0000000001000: n2346_o = 2'b00;
      13'b0000000000100: n2346_o = 2'b00;
      13'b0000000000010: n2346_o = n1505_o;
      13'b0000000000001: n2346_o = n1435_o;
      default: n2346_o = 2'b00;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2348_o = n1019_o;
      13'b0100000000000: n2348_o = n1019_o;
      13'b0010000000000: n2348_o = n1019_o;
      13'b0001000000000: n2348_o = n1019_o;
      13'b0000100000000: n2348_o = n1019_o;
      13'b0000010000000: n2348_o = n1019_o;
      13'b0000001000000: n2348_o = n1019_o;
      13'b0000000100000: n2348_o = n1019_o;
      13'b0000000010000: n2348_o = n1019_o;
      13'b0000000001000: n2348_o = n1019_o;
      13'b0000000000100: n2348_o = n1019_o;
      13'b0000000000010: n2348_o = n1019_o;
      13'b0000000000001: n2348_o = n1436_o;
      default: n2348_o = n1019_o;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2350_o = n2311_o;
      13'b0100000000000: n2350_o = n2176_o;
      13'b0010000000000: n2350_o = n2117_o;
      13'b0001000000000: n2350_o = n1998_o;
      13'b0000100000000: n2350_o = n1951_o;
      13'b0000010000000: n2350_o = n1918_o;
      13'b0000001000000: n2350_o = n1817_o;
      13'b0000000100000: n2350_o = n1673_o;
      13'b0000000010000: n2350_o = n1588_o;
      13'b0000000001000: n2350_o = n1557_o;
      13'b0000000000100: n2350_o = n1539_o;
      13'b0000000000010: n2350_o = n1508_o;
      13'b0000000000001: n2350_o = n1438_o;
      default: n2350_o = 2'b00;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2353_o = n2312_o;
      13'b0100000000000: n2353_o = n2180_o;
      13'b0010000000000: n2353_o = 2'b00;
      13'b0001000000000: n2353_o = n2003_o;
      13'b0000100000000: n2353_o = 2'b00;
      13'b0000010000000: n2353_o = 2'b00;
      13'b0000001000000: n2353_o = n1819_o;
      13'b0000000100000: n2353_o = 2'b00;
      13'b0000000010000: n2353_o = 2'b00;
      13'b0000000001000: n2353_o = 2'b00;
      13'b0000000000100: n2353_o = 2'b00;
      13'b0000000000010: n2353_o = n1511_o;
      13'b0000000000001: n2353_o = 2'b00;
      default: n2353_o = 2'b00;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2356_o = n2314_o;
      13'b0100000000000: n2356_o = n2182_o;
      13'b0010000000000: n2356_o = 1'b0;
      13'b0001000000000: n2356_o = n2005_o;
      13'b0000100000000: n2356_o = 1'b0;
      13'b0000010000000: n2356_o = 1'b0;
      13'b0000001000000: n2356_o = 1'b0;
      13'b0000000100000: n2356_o = 1'b0;
      13'b0000000010000: n2356_o = 1'b0;
      13'b0000000001000: n2356_o = 1'b0;
      13'b0000000000100: n2356_o = 1'b0;
      13'b0000000000010: n2356_o = 1'b0;
      13'b0000000000001: n2356_o = 1'b0;
      default: n2356_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2359_o = 1'b0;
      13'b0100000000000: n2359_o = 1'b0;
      13'b0010000000000: n2359_o = n2118_o;
      13'b0001000000000: n2359_o = 1'b0;
      13'b0000100000000: n2359_o = 1'b0;
      13'b0000010000000: n2359_o = 1'b0;
      13'b0000001000000: n2359_o = 1'b0;
      13'b0000000100000: n2359_o = 1'b0;
      13'b0000000010000: n2359_o = 1'b0;
      13'b0000000001000: n2359_o = 1'b0;
      13'b0000000000100: n2359_o = 1'b0;
      13'b0000000000010: n2359_o = n1514_o;
      13'b0000000000001: n2359_o = 1'b0;
      default: n2359_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2362_o = 1'b0;
      13'b0100000000000: n2362_o = 1'b0;
      13'b0010000000000: n2362_o = n2120_o;
      13'b0001000000000: n2362_o = 1'b0;
      13'b0000100000000: n2362_o = 1'b0;
      13'b0000010000000: n2362_o = 1'b0;
      13'b0000001000000: n2362_o = 1'b0;
      13'b0000000100000: n2362_o = 1'b0;
      13'b0000000010000: n2362_o = 1'b0;
      13'b0000000001000: n2362_o = 1'b0;
      13'b0000000000100: n2362_o = 1'b0;
      13'b0000000000010: n2362_o = 1'b0;
      13'b0000000000001: n2362_o = 1'b0;
      default: n2362_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2365_o = 1'b0;
      13'b0100000000000: n2365_o = 1'b0;
      13'b0010000000000: n2365_o = 1'b0;
      13'b0001000000000: n2365_o = 1'b0;
      13'b0000100000000: n2365_o = n1954_o;
      13'b0000010000000: n2365_o = 1'b0;
      13'b0000001000000: n2365_o = 1'b0;
      13'b0000000100000: n2365_o = 1'b0;
      13'b0000000010000: n2365_o = 1'b0;
      13'b0000000001000: n2365_o = 1'b0;
      13'b0000000000100: n2365_o = 1'b0;
      13'b0000000000010: n2365_o = 1'b0;
      13'b0000000000001: n2365_o = 1'b0;
      default: n2365_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2368_o = 1'b0;
      13'b0100000000000: n2368_o = 1'b0;
      13'b0010000000000: n2368_o = 1'b0;
      13'b0001000000000: n2368_o = 1'b0;
      13'b0000100000000: n2368_o = 1'b0;
      13'b0000010000000: n2368_o = 1'b0;
      13'b0000001000000: n2368_o = 1'b0;
      13'b0000000100000: n2368_o = 1'b0;
      13'b0000000010000: n2368_o = 1'b0;
      13'b0000000001000: n2368_o = 1'b0;
      13'b0000000000100: n2368_o = 1'b0;
      13'b0000000000010: n2368_o = 1'b0;
      13'b0000000000001: n2368_o = n1440_o;
      default: n2368_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2371_o = 1'b0;
      13'b0100000000000: n2371_o = 1'b0;
      13'b0010000000000: n2371_o = 1'b0;
      13'b0001000000000: n2371_o = 1'b0;
      13'b0000100000000: n2371_o = 1'b0;
      13'b0000010000000: n2371_o = 1'b0;
      13'b0000001000000: n2371_o = 1'b0;
      13'b0000000100000: n2371_o = 1'b0;
      13'b0000000010000: n2371_o = 1'b0;
      13'b0000000001000: n2371_o = 1'b0;
      13'b0000000000100: n2371_o = 1'b0;
      13'b0000000000010: n2371_o = 1'b0;
      13'b0000000000001: n2371_o = n1442_o;
      default: n2371_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2374_o = n2315_o;
      13'b0100000000000: n2374_o = n2145_o;
      13'b0010000000000: n2374_o = n2121_o;
      13'b0001000000000: n2374_o = n1964_o;
      13'b0000100000000: n2374_o = n1022_o;
      13'b0000010000000: n2374_o = n1919_o;
      13'b0000001000000: n2374_o = n1022_o;
      13'b0000000100000: n2374_o = n1674_o;
      13'b0000000010000: n2374_o = n1022_o;
      13'b0000000001000: n2374_o = n1022_o;
      13'b0000000000100: n2374_o = 1'b1;
      13'b0000000000010: n2374_o = n1479_o;
      13'b0000000000001: n2374_o = n1445_o;
      default: n2374_o = n1022_o;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2376_o = 1'b0;
      13'b0100000000000: n2376_o = 1'b0;
      13'b0010000000000: n2376_o = 1'b0;
      13'b0001000000000: n2376_o = 1'b0;
      13'b0000100000000: n2376_o = 1'b0;
      13'b0000010000000: n2376_o = 1'b0;
      13'b0000001000000: n2376_o = 1'b0;
      13'b0000000100000: n2376_o = 1'b0;
      13'b0000000010000: n2376_o = 1'b0;
      13'b0000000001000: n2376_o = 1'b0;
      13'b0000000000100: n2376_o = 1'b0;
      13'b0000000000010: n2376_o = 1'b0;
      13'b0000000000001: n2376_o = n1447_o;
      default: n2376_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2379_o = n1025_o;
      13'b0100000000000: n2379_o = n1025_o;
      13'b0010000000000: n2379_o = n1025_o;
      13'b0001000000000: n2379_o = n1025_o;
      13'b0000100000000: n2379_o = n1025_o;
      13'b0000010000000: n2379_o = n1025_o;
      13'b0000001000000: n2379_o = n1025_o;
      13'b0000000100000: n2379_o = n1025_o;
      13'b0000000010000: n2379_o = n1025_o;
      13'b0000000001000: n2379_o = 1'b1;
      13'b0000000000100: n2379_o = n1025_o;
      13'b0000000000010: n2379_o = n1025_o;
      13'b0000000000001: n2379_o = n1450_o;
      default: n2379_o = n1025_o;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2380_o = n1028_o;
      13'b0100000000000: n2380_o = n1028_o;
      13'b0010000000000: n2380_o = n1028_o;
      13'b0001000000000: n2380_o = n1028_o;
      13'b0000100000000: n2380_o = n1028_o;
      13'b0000010000000: n2380_o = n1028_o;
      13'b0000001000000: n2380_o = n1028_o;
      13'b0000000100000: n2380_o = n1028_o;
      13'b0000000010000: n2380_o = n1028_o;
      13'b0000000001000: n2380_o = n1028_o;
      13'b0000000000100: n2380_o = n1028_o;
      13'b0000000000010: n2380_o = n1028_o;
      13'b0000000000001: n2380_o = n1452_o;
      default: n2380_o = n1028_o;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2382_o = 1'b0;
      13'b0100000000000: n2382_o = 1'b0;
      13'b0010000000000: n2382_o = 1'b0;
      13'b0001000000000: n2382_o = 1'b0;
      13'b0000100000000: n2382_o = 1'b0;
      13'b0000010000000: n2382_o = 1'b0;
      13'b0000001000000: n2382_o = 1'b0;
      13'b0000000100000: n2382_o = 1'b0;
      13'b0000000010000: n2382_o = 1'b0;
      13'b0000000001000: n2382_o = 1'b0;
      13'b0000000000100: n2382_o = 1'b0;
      13'b0000000000010: n2382_o = 1'b0;
      13'b0000000000001: n2382_o = n1454_o;
      default: n2382_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2385_o = n2317_o;
      13'b0100000000000: n2385_o = 1'b0;
      13'b0010000000000: n2385_o = n2123_o;
      13'b0001000000000: n2385_o = 1'b0;
      13'b0000100000000: n2385_o = n1957_o;
      13'b0000010000000: n2385_o = n1921_o;
      13'b0000001000000: n2385_o = n1821_o;
      13'b0000000100000: n2385_o = n1676_o;
      13'b0000000010000: n2385_o = 1'b0;
      13'b0000000001000: n2385_o = 1'b0;
      13'b0000000000100: n2385_o = 1'b0;
      13'b0000000000010: n2385_o = 1'b0;
      13'b0000000000001: n2385_o = n1456_o;
      default: n2385_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2388_o = n2319_o;
      13'b0100000000000: n2388_o = 1'b0;
      13'b0010000000000: n2388_o = n2125_o;
      13'b0001000000000: n2388_o = 1'b0;
      13'b0000100000000: n2388_o = 1'b0;
      13'b0000010000000: n2388_o = n1923_o;
      13'b0000001000000: n2388_o = 1'b0;
      13'b0000000100000: n2388_o = n1678_o;
      13'b0000000010000: n2388_o = 1'b0;
      13'b0000000001000: n2388_o = 1'b0;
      13'b0000000000100: n2388_o = 1'b0;
      13'b0000000000010: n2388_o = 1'b0;
      13'b0000000000001: n2388_o = 1'b0;
      default: n2388_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2391_o = 1'b0;
      13'b0100000000000: n2391_o = 1'b0;
      13'b0010000000000: n2391_o = n2126_o;
      13'b0001000000000: n2391_o = n2008_o;
      13'b0000100000000: n2391_o = 1'b0;
      13'b0000010000000: n2391_o = 1'b0;
      13'b0000001000000: n2391_o = 1'b0;
      13'b0000000100000: n2391_o = n1679_o;
      13'b0000000010000: n2391_o = n1591_o;
      13'b0000000001000: n2391_o = 1'b0;
      13'b0000000000100: n2391_o = 1'b0;
      13'b0000000000010: n2391_o = n1517_o;
      13'b0000000000001: n2391_o = 1'b0;
      default: n2391_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2394_o = n2320_o;
      13'b0100000000000: n2394_o = n2185_o;
      13'b0010000000000: n2394_o = 1'b0;
      13'b0001000000000: n2394_o = n2011_o;
      13'b0000100000000: n2394_o = 1'b0;
      13'b0000010000000: n2394_o = n1924_o;
      13'b0000001000000: n2394_o = n1822_o;
      13'b0000000100000: n2394_o = 1'b0;
      13'b0000000010000: n2394_o = 1'b0;
      13'b0000000001000: n2394_o = 1'b0;
      13'b0000000000100: n2394_o = 1'b0;
      13'b0000000000010: n2394_o = n1520_o;
      13'b0000000000001: n2394_o = 1'b0;
      default: n2394_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2397_o = n2321_o;
      13'b0100000000000: n2397_o = n2188_o;
      13'b0010000000000: n2397_o = 1'b0;
      13'b0001000000000: n2397_o = n2014_o;
      13'b0000100000000: n2397_o = 1'b0;
      13'b0000010000000: n2397_o = n1925_o;
      13'b0000001000000: n2397_o = n1823_o;
      13'b0000000100000: n2397_o = 1'b0;
      13'b0000000010000: n2397_o = 1'b0;
      13'b0000000001000: n2397_o = 1'b0;
      13'b0000000000100: n2397_o = 1'b0;
      13'b0000000000010: n2397_o = n1523_o;
      13'b0000000000001: n2397_o = 1'b0;
      default: n2397_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2400_o = n2323_o;
      13'b0100000000000: n2400_o = 1'b0;
      13'b0010000000000: n2400_o = n2128_o;
      13'b0001000000000: n2400_o = 1'b0;
      13'b0000100000000: n2400_o = 1'b0;
      13'b0000010000000: n2400_o = n1927_o;
      13'b0000001000000: n2400_o = n1825_o;
      13'b0000000100000: n2400_o = n1681_o;
      13'b0000000010000: n2400_o = n1593_o;
      13'b0000000001000: n2400_o = 1'b0;
      13'b0000000000100: n2400_o = 1'b0;
      13'b0000000000010: n2400_o = 1'b0;
      13'b0000000000001: n2400_o = n1458_o;
      default: n2400_o = 1'b0;
    endcase
  /* T65_MCode.vhd:206:17  */
  always @*
    case (n2336_o)
      13'b1000000000000: n2403_o = n2324_o;
      13'b0100000000000: n2403_o = n2190_o;
      13'b0010000000000: n2403_o = n2129_o;
      13'b0001000000000: n2403_o = n2016_o;
      13'b0000100000000: n2403_o = 1'b0;
      13'b0000010000000: n2403_o = n1928_o;
      13'b0000001000000: n2403_o = n1827_o;
      13'b0000000100000: n2403_o = n1682_o;
      13'b0000000010000: n2403_o = n1595_o;
      13'b0000000001000: n2403_o = 1'b0;
      13'b0000000000100: n2403_o = 1'b0;
      13'b0000000000010: n2403_o = n1525_o;
      13'b0000000000001: n2403_o = n1460_o;
      default: n2403_o = 1'b0;
    endcase
  /* T65_MCode.vhd:959:24  */
  assign n2408_o = ir[1:0];
  /* T65_MCode.vhd:962:32  */
  assign n2409_o = ir[4:2];
  /* T65_MCode.vhd:964:40  */
  assign n2410_o = ir[7:5];
  /* T65_MCode.vhd:965:33  */
  assign n2412_o = n2410_o == 3'b110;
  /* T65_MCode.vhd:965:44  */
  assign n2414_o = n2410_o == 3'b111;
  /* T65_MCode.vhd:965:44  */
  assign n2415_o = n2412_o | n2414_o;
  /* T65_MCode.vhd:968:33  */
  assign n2417_o = n2410_o == 3'b101;
  /* T65_MCode.vhd:971:33  */
  assign n2419_o = n2410_o == 3'b001;
  assign n2420_o = {n2419_o, n2417_o, n2415_o};
  /* T65_MCode.vhd:964:33  */
  always @*
    case (n2420_o)
      3'b100: n2425_o = 4'b1100;
      3'b010: n2425_o = 4'b0101;
      3'b001: n2425_o = 4'b0110;
      default: n2425_o = 4'b0100;
    endcase
  /* T65_MCode.vhd:963:25  */
  assign n2427_o = n2409_o == 3'b000;
  /* T65_MCode.vhd:963:36  */
  assign n2429_o = n2409_o == 3'b001;
  /* T65_MCode.vhd:963:36  */
  assign n2430_o = n2427_o | n2429_o;
  /* T65_MCode.vhd:963:44  */
  assign n2432_o = n2409_o == 3'b011;
  /* T65_MCode.vhd:963:44  */
  assign n2433_o = n2430_o | n2432_o;
  /* T65_MCode.vhd:979:40  */
  assign n2434_o = ir[7:5];
  /* T65_MCode.vhd:980:33  */
  assign n2436_o = n2434_o == 3'b111;
  /* T65_MCode.vhd:980:44  */
  assign n2438_o = n2434_o == 3'b110;
  /* T65_MCode.vhd:980:44  */
  assign n2439_o = n2436_o | n2438_o;
  /* T65_MCode.vhd:983:33  */
  assign n2441_o = n2434_o == 3'b100;
  assign n2442_o = {n2441_o, n2439_o};
  /* T65_MCode.vhd:979:33  */
  always @*
    case (n2442_o)
      2'b10: n2446_o = 4'b1110;
      2'b01: n2446_o = 4'b1111;
      default: n2446_o = 4'b1101;
    endcase
  /* T65_MCode.vhd:978:25  */
  assign n2448_o = n2409_o == 3'b010;
  /* T65_MCode.vhd:991:40  */
  assign n2449_o = ir[7:5];
  /* T65_MCode.vhd:992:33  */
  assign n2451_o = n2449_o == 3'b100;
  /* T65_MCode.vhd:991:33  */
  always @*
    case (n2451_o)
      1'b1: n2454_o = 4'b1101;
      default: n2454_o = 4'bX;
    endcase
  /* T65_MCode.vhd:990:25  */
  assign n2456_o = n2409_o == 3'b110;
  /* T65_MCode.vhd:999:40  */
  assign n2457_o = ir[7:5];
  /* T65_MCode.vhd:1000:33  */
  assign n2459_o = n2457_o == 3'b101;
  /* T65_MCode.vhd:999:33  */
  always @*
    case (n2459_o)
      1'b1: n2462_o = 4'b1101;
      default: n2462_o = 4'b0100;
    endcase
  assign n2463_o = {n2456_o, n2448_o, n2433_o};
  /* T65_MCode.vhd:962:25  */
  always @*
    case (n2463_o)
      3'b100: n2464_o = n2454_o;
      3'b010: n2464_o = n2446_o;
      3'b001: n2464_o = n2425_o;
      default: n2464_o = n2462_o;
    endcase
  /* T65_MCode.vhd:960:17  */
  assign n2466_o = n2408_o == 2'b00;
  /* T65_MCode.vhd:1011:49  */
  assign n2468_o = ir[7:5];
  /* T65_MCode.vhd:1008:17  */
  assign n2470_o = n2408_o == 2'b01;
  /* T65_MCode.vhd:1016:49  */
  assign n2472_o = ir[7:5];
  /* T65_MCode.vhd:1017:32  */
  assign n2473_o = ir[7:5];
  /* T65_MCode.vhd:1019:38  */
  assign n2474_o = ir[4:2];
  /* T65_MCode.vhd:1019:51  */
  assign n2476_o = n2474_o == 3'b110;
  assign n2478_o = {1'b1, n2472_o};
  /* T65_MCode.vhd:1019:33  */
  assign n2479_o = n2476_o ? 4'b1111 : n2478_o;
  /* T65_MCode.vhd:1018:25  */
  assign n2481_o = n2473_o == 3'b000;
  /* T65_MCode.vhd:1024:38  */
  assign n2482_o = ir[4:2];
  /* T65_MCode.vhd:1024:51  */
  assign n2484_o = n2482_o == 3'b110;
  assign n2486_o = {1'b1, n2472_o};
  /* T65_MCode.vhd:1024:33  */
  assign n2487_o = n2484_o ? 4'b1110 : n2486_o;
  /* T65_MCode.vhd:1023:25  */
  assign n2489_o = n2473_o == 3'b001;
  /* T65_MCode.vhd:1029:38  */
  assign n2490_o = ir[4:2];
  /* T65_MCode.vhd:1029:51  */
  assign n2492_o = n2490_o == 3'b010;
  /* T65_MCode.vhd:1029:33  */
  assign n2495_o = n2492_o ? 4'b0101 : 4'b0100;
  /* T65_MCode.vhd:1028:25  */
  assign n2497_o = n2473_o == 3'b100;
  assign n2498_o = {n2497_o, n2489_o, n2481_o};
  assign n2499_o = {1'b1, n2472_o};
  /* T65_MCode.vhd:1017:25  */
  always @*
    case (n2498_o)
      3'b100: n2500_o = n2495_o;
      3'b010: n2500_o = n2487_o;
      3'b001: n2500_o = n2479_o;
      default: n2500_o = n2499_o;
    endcase
  /* T65_MCode.vhd:1013:17  */
  assign n2502_o = n2408_o == 2'b10;
  /* T65_MCode.vhd:1040:32  */
  assign n2503_o = ir[7:5];
  /* T65_MCode.vhd:1041:25  */
  assign n2505_o = n2503_o == 3'b100;
  /* T65_MCode.vhd:1044:43  */
  assign n2507_o = mcycle == 3'b000;
  /* T65_MCode.vhd:1046:65  */
  assign n2509_o = ir[7:5];
  /* T65_MCode.vhd:1049:65  */
  assign n2511_o = ir[7:5];
  assign n2512_o = {1'b1, n2511_o};
  assign n2513_o = {1'b0, n2509_o};
  /* T65_MCode.vhd:1044:33  */
  assign n2514_o = n2507_o ? n2513_o : n2512_o;
  /* T65_MCode.vhd:1040:25  */
  always @*
    case (n2505_o)
      1'b1: n2516_o = 4'b0100;
      default: n2516_o = n2514_o;
    endcase
  assign n2517_o = {n2502_o, n2470_o, n2466_o};
  assign n2518_o = n2464_o[2:0];
  assign n2519_o = n2500_o[2:0];
  assign n2520_o = n2516_o[2:0];
  /* T65_MCode.vhd:959:17  */
  always @*
    case (n2517_o)
      3'b100: n2521_o = n2519_o;
      3'b010: n2521_o = n2468_o;
      3'b001: n2521_o = n2518_o;
      default: n2521_o = n2520_o;
    endcase
  assign n2522_o = n2464_o[3];
  assign n2523_o = n2500_o[3];
  assign n2524_o = n2516_o[3];
  /* T65_MCode.vhd:959:17  */
  always @*
    case (n2517_o)
      3'b100: n2525_o = n2523_o;
      3'b010: n2525_o = 1'b0;
      3'b001: n2525_o = n2522_o;
      default: n2525_o = n2524_o;
    endcase
  assign n2527_o = {n2525_o, n2521_o};
endmodule

module T65
  (input  [1:0] Mode,
   input  Res_n,
   input  Enable,
   input  Clk,
   input  Rdy,
   input  Abort_n,
   input  IRQ_n,
   input  NMI_n,
   input  SO_n,
   input  [7:0] DI,
   output R_W_n,
   output Sync,
   output EF,
   output MF,
   output XF,
   output ML_n,
   output VP_n,
   output VDA,
   output VPA,
   output [23:0] A,
   output [7:0] DO);
  // non standard register names
  wire [15:0] s;
`ifdef VERILATOR_KEEP_CPU
/* verilator tracing_on */
`endif
  wire [15:0] abc;
  wire [15:0] x;
  wire [15:0] y;
  reg [7:0] p;
  reg [7:0] ad;
  reg [7:0] dl;
  wire [7:0] bah;
  wire [8:0] bal;
  wire [7:0] pbr;
  wire [7:0] dbr;
  wire [15:0] pc;
  wire ef_i;
  wire mf_i;
  wire xf_i;
  wire [7:0] ir;
  wire [2:0] mcycle;
  wire [1:0] mode_r;
  wire [3:0] alu_op_r;
  wire [2:0] write_data_r;
  wire [1:0] set_addr_to_r;
  wire [8:0] pcadder;
  wire rstcycle;
  wire irqcycle;
  wire nmicycle;
`ifdef VERILATOR_KEEP_CPU
  // regular register names for debugging
  wire [7:0]  a = abc[7:0];
  wire [7:0] sp = s[7:0];
`endif
/* verilator tracing_off */
  wire so_n_o;
  wire irq_n_o;
  wire nmi_n_o;
  wire nmiact;
  wire brk;
  wire [7:0] busa;
  wire [7:0] busa_r;
  wire [7:0] busb;
  wire [7:0] alu_q;
  wire [7:0] p_out;
  wire [2:0] lcycle;
  wire [3:0] alu_op;
  wire [2:0] set_busa_to;
  wire [1:0] set_addr_to;
  wire [2:0] write_data;
  wire [1:0] jump;
  wire [1:0] baadd;
  wire breakatna;
  wire adadd;
  wire addy;
  wire pcadd;
  wire inc_s;
  wire dec_s;
  wire lda;
  wire ldp;
  wire ldx;
  wire ldy;
  wire lds;
  wire lddi;
  wire ldalu;
  wire ldad;
  wire ldbal;
  wire ldbah;
  wire savep;
  wire write;
  wire really_rdy;
  wire r_w_n_i;
  wire n14_o;
  wire n15_o;
  wire n18_o;
  wire n19_o;
  wire [1:0] n22_o;
  wire n24_o;
  wire [1:0] n25_o;
  wire n27_o;
  wire n28_o;
  wire [1:0] n29_o;
  wire n31_o;
  wire n32_o;
  wire n33_o;
  wire n37_o;
  wire n39_o;
  wire n40_o;
  wire n41_o;
  wire n42_o;
  wire n46_o;
  wire n47_o;
  wire n50_o;
  wire n51_o;
  wire n52_o;
  wire [2:0] mcode_n54;
  wire [3:0] mcode_n55;
  wire [2:0] mcode_n56;
  wire [1:0] mcode_n57;
  wire [2:0] mcode_n58;
  wire [1:0] mcode_n59;
  wire [1:0] mcode_n60;
  wire mcode_n61;
  wire mcode_n62;
  wire mcode_n63;
  wire mcode_n64;
  wire mcode_n65;
  wire mcode_n66;
  wire mcode_n67;
  wire mcode_n68;
  wire mcode_n69;
  wire mcode_n70;
  wire mcode_n71;
  wire mcode_n72;
  wire mcode_n73;
  wire mcode_n74;
  wire mcode_n75;
  wire mcode_n76;
  wire mcode_n77;
  wire mcode_n78;
  wire [2:0] mcode_lcycle;
  wire [3:0] mcode_alu_op;
  wire [2:0] mcode_set_busa_to;
  wire [1:0] mcode_set_addr_to;
  wire [2:0] mcode_write_data;
  wire [1:0] mcode_jump;
  wire [1:0] mcode_baadd;
  wire mcode_breakatna;
  wire mcode_adadd;
  wire mcode_addy;
  wire mcode_pcadd;
  wire mcode_inc_s;
  wire mcode_dec_s;
  wire mcode_lda;
  wire mcode_ldp;
  wire mcode_ldx;
  wire mcode_ldy;
  wire mcode_lds;
  wire mcode_lddi;
  wire mcode_ldalu;
  wire mcode_ldad;
  wire mcode_ldbal;
  wire mcode_ldbah;
  wire mcode_savep;
  wire mcode_write;
  wire [7:0] inst_alu_n129;
  wire [7:0] inst_alu_n130;
  wire [7:0] inst_alu_p_out;
  wire [7:0] inst_alu_q;
  wire n137_o;
  wire n139_o;
  wire n140_o;
  wire n142_o;
  wire n143_o;
  wire n144_o;
  wire n145_o;
  wire [15:0] n147_o;
  wire n149_o;
  wire [7:0] n151_o;
  wire n152_o;
  wire [1:0] n156_o;
  wire [15:0] n158_o;
  wire n160_o;
  wire n161_o;
  wire [15:0] n163_o;
  wire [7:0] n165_o;
  wire [7:0] n166_o;
  wire [7:0] n167_o;
  wire [7:0] n168_o;
  wire [7:0] n169_o;
  wire [7:0] n170_o;
  wire [7:0] n171_o;
  wire [7:0] n172_o;
  wire [7:0] n173_o;
  wire [7:0] n174_o;
  wire [7:0] n175_o;
  wire n177_o;
  wire n179_o;
  wire n180_o;
  wire n181_o;
  wire n182_o;
  wire n183_o;
  wire n184_o;
  wire [15:0] n186_o;
  wire [15:0] n189_o;
  wire n191_o;
  wire [15:0] n192_o;
  wire n194_o;
  wire n195_o;
  wire n196_o;
  wire n197_o;
  wire [7:0] n198_o;
  wire [7:0] n200_o;
  wire [7:0] n201_o;
  wire [7:0] n203_o;
  wire [7:0] n204_o;
  wire [7:0] n205_o;
  wire [7:0] n206_o;
  wire [7:0] n207_o;
  wire [7:0] n208_o;
  wire [7:0] n209_o;
  wire [7:0] n210_o;
  wire [7:0] n211_o;
  wire n213_o;
  wire [2:0] n214_o;
  wire [7:0] n215_o;
  wire [7:0] n216_o;
  wire [7:0] n217_o;
  wire [7:0] n218_o;
  wire [7:0] n219_o;
  wire [7:0] n220_o;
  wire [7:0] n221_o;
  reg [7:0] n222_o;
  wire [7:0] n223_o;
  wire [7:0] n224_o;
  wire [7:0] n225_o;
  wire [7:0] n226_o;
  wire [7:0] n227_o;
  wire [7:0] n228_o;
  wire [7:0] n229_o;
  reg [7:0] n230_o;
  wire [15:0] n242_o;
  wire [15:0] n244_o;
  wire n252_o;
  wire n253_o;
  wire n259_o;
  wire n260_o;
  wire n261_o;
  wire n262_o;
  wire n263_o;
  wire n264_o;
  wire n265_o;
  wire n266_o;
  wire n267_o;
  wire n268_o;
  wire n269_o;
  wire n270_o;
  wire n271_o;
  wire [7:0] n315_o;
  wire [8:0] n316_o;
  wire n317_o;
  wire [8:0] n318_o;
  wire [8:0] n319_o;
  wire [8:0] n320_o;
  wire [7:0] n321_o;
  wire [8:0] n323_o;
  wire n328_o;
  wire n335_o;
  wire n336_o;
  wire n339_o;
  wire n341_o;
  wire n343_o;
  wire n344_o;
  wire [4:0] n347_o;
  wire n349_o;
  wire [2:0] n350_o;
  wire n353_o;
  wire n356_o;
  wire n359_o;
  wire n362_o;
  wire n365_o;
  wire n368_o;
  wire n371_o;
  wire [6:0] n372_o;
  wire n373_o;
  wire n374_o;
  wire n375_o;
  wire n376_o;
  wire n377_o;
  wire n378_o;
  wire n379_o;
  reg n380_o;
  wire n381_o;
  wire n382_o;
  wire n383_o;
  wire n384_o;
  wire n385_o;
  wire n386_o;
  wire n387_o;
  reg n388_o;
  wire n389_o;
  wire n390_o;
  wire n391_o;
  wire n392_o;
  wire n393_o;
  wire n394_o;
  wire n395_o;
  reg n396_o;
  wire n397_o;
  wire n398_o;
  wire n399_o;
  wire n400_o;
  wire n401_o;
  wire n402_o;
  wire n403_o;
  reg n404_o;
  wire [1:0] n405_o;
  wire n406_o;
  wire n407_o;
  wire n408_o;
  wire n409_o;
  wire n410_o;
  wire n411_o;
  wire n412_o;
  wire n413_o;
  wire n422_o;
  wire n423_o;
  wire n424_o;
  wire n425_o;
  wire n426_o;
  wire n427_o;
  wire n428_o;
  wire n429_o;
  wire n444_o;
  wire n445_o;
  wire n446_o;
  wire n447_o;
  wire n448_o;
  wire n449_o;
  wire n450_o;
  wire n451_o;
  wire n452_o;
  wire n453_o;
  wire n454_o;
  wire n455_o;
  wire n456_o;
  wire n457_o;
  wire n474_o;
  wire n475_o;
  wire n476_o;
  wire n477_o;
  wire n478_o;
  wire n480_o;
  wire n483_o;
  wire n485_o;
  wire n486_o;
  wire n487_o;
  wire n488_o;
  wire n489_o;
  wire n490_o;
  wire n491_o;
  wire n492_o;
  wire n493_o;
  wire n494_o;
  wire n495_o;
  wire n496_o;
  wire n497_o;
  wire n498_o;
  wire n499_o;
  wire n500_o;
  wire n501_o;
  wire n502_o;
  wire n503_o;
  wire n504_o;
  wire n505_o;
  wire n506_o;
  wire n507_o;
  wire n508_o;
  wire n509_o;
  wire n510_o;
  wire n511_o;
  wire n512_o;
  wire n513_o;
  wire n514_o;
  wire n515_o;
  wire n516_o;
  wire n517_o;
  wire n518_o;
  wire n519_o;
  wire n520_o;
  wire n521_o;
  wire n522_o;
  wire n523_o;
  wire n524_o;
  wire n525_o;
  wire n526_o;
  wire n527_o;
  wire n529_o;
  wire n531_o;
  wire n532_o;
  wire [1:0] n536_o;
  wire [1:0] n537_o;
  wire [1:0] n538_o;
  wire n543_o;
  wire n545_o;
  wire n547_o;
  wire [7:0] n548_o;
  wire n555_o;
  wire n557_o;
  wire n559_o;
  wire n560_o;
  wire n562_o;
  wire n563_o;
  wire n564_o;
  wire n579_o;
  wire [7:0] n582_o;
  wire [8:0] n584_o;
  wire n586_o;
  wire [7:0] n587_o;
  wire [8:0] n588_o;
  wire [8:0] n589_o;
  wire [8:0] n590_o;
  wire n592_o;
  wire n593_o;
  wire [7:0] n595_o;
  wire [7:0] n596_o;
  wire n598_o;
  wire [2:0] n599_o;
  reg [7:0] n600_o;
  reg [7:0] n601_o;
  reg [8:0] n602_o;
  wire [7:0] n603_o;
  wire [7:0] n604_o;
  wire [7:0] n605_o;
  wire [7:0] n606_o;
  wire [7:0] n607_o;
  wire [7:0] n608_o;
  wire n610_o;
  localparam [2:0] n611_o = 3'b100;
  localparam [2:0] n612_o = 3'b010;
  localparam [2:0] n613_o = 3'b110;
  localparam [8:0] n616_o = 9'b111111111;
  wire [5:0] n617_o;
  wire n619_o;
  wire n621_o;
  wire n622_o;
  wire n623_o;
  wire n624_o;
  wire n625_o;
  wire n626_o;
  wire [1:0] n627_o;
  wire [1:0] n628_o;
  wire [1:0] n629_o;
  wire [1:0] n630_o;
  wire [1:0] n631_o;
  wire [7:0] n633_o;
  wire [8:0] n634_o;
  wire [7:0] n636_o;
  wire [7:0] n637_o;
  wire [7:0] n638_o;
  wire [7:0] n639_o;
  wire [7:0] n640_o;
  wire [7:0] n641_o;
  wire [7:0] n642_o;
  wire n643_o;
  wire n644_o;
  wire n645_o;
  wire [7:0] n646_o;
  wire [8:0] n650_o;
  wire n654_o;
  wire n655_o;
  wire n656_o;
  wire n657_o;
  wire n658_o;
  wire n659_o;
  wire n679_o;
  wire n680_o;
  wire n681_o;
  wire n682_o;
  wire n683_o;
  wire n684_o;
  wire n685_o;
  wire n687_o;
  wire [7:0] n688_o;
  wire n690_o;
  wire [7:0] n691_o;
  wire n693_o;
  wire [7:0] n694_o;
  wire n696_o;
  wire [7:0] n697_o;
  wire n699_o;
  wire n701_o;
  wire [5:0] n703_o;
  reg [7:0] n704_o;
  wire [7:0] n705_o;
  wire [23:0] n707_o;
  wire n709_o;
  wire [15:0] n711_o;
  wire [23:0] n712_o;
  wire n714_o;
  wire [15:0] n716_o;
  wire [7:0] n717_o;
  wire [23:0] n718_o;
  wire n720_o;
  wire [7:0] n721_o;
  wire [15:0] n722_o;
  wire [7:0] n723_o;
  wire [23:0] n724_o;
  wire [2:0] n725_o;
  reg [23:0] n726_o;
  wire n728_o;
  wire [7:0] n729_o;
  wire n731_o;
  wire [7:0] n732_o;
  wire n734_o;
  wire [7:0] n735_o;
  wire n737_o;
  wire [7:0] n738_o;
  wire n740_o;
  wire n742_o;
  wire [7:0] n743_o;
  wire n745_o;
  wire [7:0] n746_o;
  wire [6:0] n747_o;
  reg [7:0] n748_o;
  wire n751_o;
  wire n753_o;
  wire n754_o;
  wire n755_o;
  wire n756_o;
  wire n757_o;
  wire n758_o;
  wire n761_o;
  wire n763_o;
  wire n767_o;
  wire [2:0] n770_o;
  wire [2:0] n772_o;
  wire n778_o;
  wire n779_o;
  wire n780_o;
  wire n782_o;
  wire n784_o;
  wire n785_o;
  wire n786_o;
  wire n788_o;
  wire n789_o;
  wire n790_o;
  wire n791_o;
  wire n792_o;
  wire [7:0] n809_o;
  wire [7:0] n810_o;
  reg [7:0] n811_q;
  wire [15:0] n813_o;
  wire [7:0] n814_o;
  wire [7:0] n815_o;
  reg [7:0] n816_q;
  wire [15:0] n818_o;
  wire [7:0] n819_o;
  wire [7:0] n820_o;
  reg [7:0] n821_q;
  wire [15:0] n823_o;
  wire [7:0] n826_o;
  reg [7:0] n827_q;
  wire [7:0] n828_o;
  reg [7:0] n829_q;
  wire [7:0] n830_o;
  reg [7:0] n831_q;
  wire [7:0] n832_o;
  reg [7:0] n833_q;
  wire [8:0] n834_o;
  reg [8:0] n835_q;
  wire [7:0] n836_o;
  reg [7:0] n837_q;
  wire [7:0] n838_o;
  reg [7:0] n839_q;
  wire [15:0] n840_o;
  reg [15:0] n841_q;
  wire [15:0] n842_o;
  reg [15:0] n843_q;
  wire n844_o;
  reg n845_q;
  wire n846_o;
  reg n847_q;
  wire n848_o;
  reg n849_q;
  wire [7:0] n850_o;
  reg [7:0] n851_q;
  wire [2:0] n852_o;
  reg [2:0] n853_q;
  wire [1:0] n854_o;
  reg [1:0] n855_q;
  wire [3:0] n856_o;
  reg [3:0] n857_q;
  wire [2:0] n858_o;
  reg [2:0] n859_q;
  wire [1:0] n860_o;
  reg [1:0] n861_q;
  wire n862_o;
  reg n863_q;
  wire n864_o;
  reg n865_q;
  wire n866_o;
  reg n867_q;
  wire n870_o;
  reg n871_q;
  wire n872_o;
  reg n873_q;
  wire n874_o;
  reg n875_q;
  wire n876_o;
  reg n877_q;
  wire [7:0] n878_o;
  reg [7:0] n879_q;
  wire [7:0] n880_o;
  reg [7:0] n881_q;
  wire n882_o;
  reg n883_q;
  assign R_W_n = r_w_n_i;
  assign Sync = n19_o;
  assign EF = ef_i;
  assign MF = mf_i;
  assign XF = xf_i;
  assign ML_n = n33_o;
  assign VP_n = n42_o;
  assign VDA = n47_o;
  assign VPA = n52_o;
  assign A = n726_o;
  assign DO = n748_o;
  /* T65.vhd:100:16  */
  assign abc = n813_o; // (signal)
  /* T65.vhd:100:21  */
  assign x = n818_o; // (signal)
  /* T65.vhd:100:24  */
  assign y = n823_o; // (signal)
  /* T65.vhd:101:16  */
  always @*
    p = n827_q; // (isignal)
  initial
    p = 8'b00000000;
  /* T65.vhd:101:19  */
  always @*
    ad = n829_q; // (isignal)
  initial
    ad = 8'b00000000;
  /* T65.vhd:101:23  */
  always @*
    dl = n831_q; // (isignal)
  initial
    dl = 8'b00000000;
  /* T65.vhd:102:16  */
  assign bah = n833_q; // (signal)
  /* T65.vhd:103:16  */
  assign bal = n835_q; // (signal)
  /* T65.vhd:104:16  */
  assign pbr = n837_q; // (signal)
  /* T65.vhd:105:16  */
  assign dbr = n839_q; // (signal)
  /* T65.vhd:106:16  */
  assign pc = n841_q; // (signal)
  /* T65.vhd:107:16  */
  assign s = n843_q; // (signal)
  /* T65.vhd:108:16  */
  assign ef_i = n845_q; // (signal)
  /* T65.vhd:109:16  */
  assign mf_i = n847_q; // (signal)
  /* T65.vhd:110:16  */
  assign xf_i = n849_q; // (signal)
  /* T65.vhd:112:16  */
  assign ir = n851_q; // (signal)
  /* T65.vhd:113:16  */
  assign mcycle = n853_q; // (signal)
  /* T65.vhd:115:16  */
  assign mode_r = n855_q; // (signal)
  /* T65.vhd:116:16  */
  assign alu_op_r = n857_q; // (signal)
  /* T65.vhd:117:16  */
  assign write_data_r = n859_q; // (signal)
  /* T65.vhd:118:16  */
  assign set_addr_to_r = n861_q; // (signal)
  /* T65.vhd:119:16  */
  assign pcadder = n320_o; // (signal)
  /* T65.vhd:121:16  */
  assign rstcycle = n863_q; // (signal)
  /* T65.vhd:122:16  */
  assign irqcycle = n865_q; // (signal)
  /* T65.vhd:123:16  */
  assign nmicycle = n867_q; // (signal)
  /* T65.vhd:126:16  */
  assign so_n_o = n871_q; // (signal)
  /* T65.vhd:127:16  */
  assign irq_n_o = n873_q; // (signal)
  /* T65.vhd:128:16  */
  assign nmi_n_o = n875_q; // (signal)
  /* T65.vhd:129:16  */
  assign nmiact = n877_q; // (signal)
  /* T65.vhd:131:16  */
  assign brk = n685_o; // (signal)
  /* T65.vhd:134:16  */
  assign busa = n704_o; // (signal)
  /* T65.vhd:135:16  */
  assign busa_r = n879_q; // (signal)
  /* T65.vhd:136:16  */
  assign busb = n881_q; // (signal)
  /* T65.vhd:137:16  */
  assign alu_q = inst_alu_n130; // (signal)
  /* T65.vhd:138:16  */
  assign p_out = inst_alu_n129; // (signal)
  /* T65.vhd:141:16  */
  assign lcycle = mcode_n54; // (signal)
  /* T65.vhd:142:16  */
  assign alu_op = mcode_n55; // (signal)
  /* T65.vhd:143:16  */
  assign set_busa_to = mcode_n56; // (signal)
  /* T65.vhd:144:16  */
  assign set_addr_to = mcode_n57; // (signal)
  /* T65.vhd:145:16  */
  assign write_data = mcode_n58; // (signal)
  /* T65.vhd:146:16  */
  assign jump = mcode_n59; // (signal)
  /* T65.vhd:147:16  */
  assign baadd = mcode_n60; // (signal)
  /* T65.vhd:148:16  */
  assign breakatna = mcode_n61; // (signal)
  /* T65.vhd:149:16  */
  assign adadd = mcode_n62; // (signal)
  /* T65.vhd:150:16  */
  assign addy = mcode_n63; // (signal)
  /* T65.vhd:151:16  */
  assign pcadd = mcode_n64; // (signal)
  /* T65.vhd:152:16  */
  assign inc_s = mcode_n65; // (signal)
  /* T65.vhd:153:16  */
  assign dec_s = mcode_n66; // (signal)
  /* T65.vhd:154:16  */
  assign lda = mcode_n67; // (signal)
  /* T65.vhd:155:16  */
  assign ldp = mcode_n68; // (signal)
  /* T65.vhd:156:16  */
  assign ldx = mcode_n69; // (signal)
  /* T65.vhd:157:16  */
  assign ldy = mcode_n70; // (signal)
  /* T65.vhd:158:16  */
  assign lds = mcode_n71; // (signal)
  /* T65.vhd:159:16  */
  assign lddi = mcode_n72; // (signal)
  /* T65.vhd:160:16  */
  assign ldalu = mcode_n73; // (signal)
  /* T65.vhd:161:16  */
  assign ldad = mcode_n74; // (signal)
  /* T65.vhd:162:16  */
  assign ldbal = mcode_n75; // (signal)
  /* T65.vhd:163:16  */
  assign ldbah = mcode_n76; // (signal)
  /* T65.vhd:164:16  */
  assign savep = mcode_n77; // (signal)
  /* T65.vhd:165:16  */
  assign write = mcode_n78; // (signal)
  /* T65.vhd:167:16  */
  assign really_rdy = n15_o; // (signal)
  /* T65.vhd:168:16  */
  assign r_w_n_i = n883_q; // (signal)
  /* T65.vhd:174:30  */
  assign n14_o = ~r_w_n_i;
  /* T65.vhd:174:27  */
  assign n15_o = Rdy | n14_o;
  /* T65.vhd:179:33  */
  assign n18_o = mcycle == 3'b000;
  /* T65.vhd:179:21  */
  assign n19_o = n18_o ? 1'b1 : 1'b0;
  /* T65.vhd:183:28  */
  assign n22_o = ir[7:6];
  /* T65.vhd:183:41  */
  assign n24_o = n22_o != 2'b10;
  /* T65.vhd:183:55  */
  assign n25_o = ir[2:1];
  /* T65.vhd:183:68  */
  assign n27_o = n25_o == 2'b11;
  /* T65.vhd:183:49  */
  assign n28_o = n27_o & n24_o;
  /* T65.vhd:183:85  */
  assign n29_o = mcycle[2:1];
  /* T65.vhd:183:98  */
  assign n31_o = n29_o != 2'b00;
  /* T65.vhd:183:75  */
  assign n32_o = n31_o & n28_o;
  /* T65.vhd:183:21  */
  assign n33_o = n32_o ? 1'b0 : 1'b1;
  /* T65.vhd:184:53  */
  assign n37_o = mcycle == 3'b101;
  /* T65.vhd:184:71  */
  assign n39_o = mcycle == 3'b110;
  /* T65.vhd:184:61  */
  assign n40_o = n37_o | n39_o;
  /* T65.vhd:184:41  */
  assign n41_o = n40_o & irqcycle;
  /* T65.vhd:184:21  */
  assign n42_o = n41_o ? 1'b0 : 1'b1;
  /* T65.vhd:185:39  */
  assign n46_o = set_addr_to_r != 2'b00;
  /* T65.vhd:185:20  */
  assign n47_o = n46_o ? 1'b1 : 1'b0;
  /* T65.vhd:186:29  */
  assign n50_o = jump[1];
  /* T65.vhd:186:33  */
  assign n51_o = ~n50_o;
  /* T65.vhd:186:20  */
  assign n52_o = n51_o ? 1'b1 : 1'b0;
  /* T65.vhd:194:40  */
  assign mcode_n54 = mcode_lcycle; // (signal)
  /* T65.vhd:195:40  */
  assign mcode_n55 = mcode_alu_op; // (signal)
  /* T65.vhd:196:40  */
  assign mcode_n56 = mcode_set_busa_to; // (signal)
  /* T65.vhd:197:40  */
  assign mcode_n57 = mcode_set_addr_to; // (signal)
  /* T65.vhd:198:40  */
  assign mcode_n58 = mcode_write_data; // (signal)
  /* T65.vhd:199:40  */
  assign mcode_n59 = mcode_jump; // (signal)
  /* T65.vhd:200:40  */
  assign mcode_n60 = mcode_baadd; // (signal)
  /* T65.vhd:201:40  */
  assign mcode_n61 = mcode_breakatna; // (signal)
  /* T65.vhd:202:40  */
  assign mcode_n62 = mcode_adadd; // (signal)
  /* T65.vhd:203:40  */
  assign mcode_n63 = mcode_addy; // (signal)
  /* T65.vhd:204:40  */
  assign mcode_n64 = mcode_pcadd; // (signal)
  /* T65.vhd:205:40  */
  assign mcode_n65 = mcode_inc_s; // (signal)
  /* T65.vhd:206:40  */
  assign mcode_n66 = mcode_dec_s; // (signal)
  /* T65.vhd:207:40  */
  assign mcode_n67 = mcode_lda; // (signal)
  /* T65.vhd:208:40  */
  assign mcode_n68 = mcode_ldp; // (signal)
  /* T65.vhd:209:40  */
  assign mcode_n69 = mcode_ldx; // (signal)
  /* T65.vhd:210:40  */
  assign mcode_n70 = mcode_ldy; // (signal)
  /* T65.vhd:211:40  */
  assign mcode_n71 = mcode_lds; // (signal)
  /* T65.vhd:212:40  */
  assign mcode_n72 = mcode_lddi; // (signal)
  /* T65.vhd:213:40  */
  assign mcode_n73 = mcode_ldalu; // (signal)
  /* T65.vhd:214:40  */
  assign mcode_n74 = mcode_ldad; // (signal)
  /* T65.vhd:215:40  */
  assign mcode_n75 = mcode_ldbal; // (signal)
  /* T65.vhd:216:40  */
  assign mcode_n76 = mcode_ldbah; // (signal)
  /* T65.vhd:217:40  */
  assign mcode_n77 = mcode_savep; // (signal)
  /* T65.vhd:218:40  */
  assign mcode_n78 = mcode_write; // (signal)
  /* T65.vhd:188:9  */
  t65_mcode mcode (
    .mode(mode_r),
    .ir(ir),
    .mcycle(mcycle),
    .p(p),
    .lcycle(mcode_lcycle),
    .alu_op(mcode_alu_op),
    .set_busa_to(mcode_set_busa_to),
    .set_addr_to(mcode_set_addr_to),
    .write_data(mcode_write_data),
    .jump(mcode_jump),
    .baadd(mcode_baadd),
    .breakatna(mcode_breakatna),
    .adadd(mcode_adadd),
    .addy(mcode_addy),
    .pcadd(mcode_pcadd),
    .inc_s(mcode_inc_s),
    .dec_s(mcode_dec_s),
    .lda(mcode_lda),
    .ldp(mcode_ldp),
    .ldx(mcode_ldx),
    .ldy(mcode_ldy),
    .lds(mcode_lds),
    .lddi(mcode_lddi),
    .ldalu(mcode_ldalu),
    .ldad(mcode_ldad),
    .ldbal(mcode_ldbal),
    .ldbah(mcode_ldbah),
    .savep(mcode_savep),
    .write(mcode_write));
  /* T65.vhd:228:34  */
  assign inst_alu_n129 = inst_alu_p_out; // (signal)
  /* T65.vhd:229:30  */
  assign inst_alu_n130 = inst_alu_q; // (signal)
  /* T65.vhd:221:9  */
  t65_alu inst_alu (
    .mode(mode_r),
    .op(alu_op_r),
    .busa(busa_r),
    .busb(busb),
    .p_in(p),
    .p_out(inst_alu_p_out),
    .q(inst_alu_q));
  /* T65.vhd:234:26  */
  assign n137_o = ~Res_n;
  /* T65.vhd:255:44  */
  assign n139_o = ~write;
  /* T65.vhd:255:54  */
  assign n140_o = n139_o | rstcycle;
  /* T65.vhd:264:44  */
  assign n142_o = mcycle == 3'b000;
  /* T65.vhd:267:53  */
  assign n143_o = ~irqcycle;
  /* T65.vhd:267:72  */
  assign n144_o = ~nmicycle;
  /* T65.vhd:267:59  */
  assign n145_o = n144_o & n143_o;
  /* T65.vhd:268:58  */
  assign n147_o = pc + 16'b0000000000000001;
  /* T65.vhd:271:59  */
  assign n149_o = irqcycle | nmicycle;
  /* T65.vhd:271:41  */
  assign n151_o = n149_o ? 8'b00000000 : DI;
  /* T65.vhd:264:33  */
  assign n152_o = n145_o & n142_o;
  /* T65.vhd:280:33  */
  assign n156_o = brk ? 2'b00 : set_addr_to;
  /* T65.vhd:287:48  */
  assign n158_o = s + 16'b0000000000000001;
  /* T65.vhd:289:61  */
  assign n160_o = ~rstcycle;
  /* T65.vhd:289:48  */
  assign n161_o = n160_o & dec_s;
  /* T65.vhd:290:48  */
  assign n163_o = s - 16'b0000000000000001;
  assign n165_o = n163_o[7:0];
  assign n166_o = n158_o[7:0];
  assign n167_o = s[7:0];
  /* T65.vhd:286:33  */
  assign n168_o = inc_s ? n166_o : n167_o;
  /* T65.vhd:289:33  */
  assign n169_o = n161_o ? n165_o : n168_o;
  /* T65.vhd:292:33  */
  assign n170_o = lds ? alu_q : n169_o;
  assign n171_o = n163_o[15:8];
  assign n172_o = n158_o[15:8];
  assign n173_o = s[15:8];
  /* T65.vhd:286:33  */
  assign n174_o = inc_s ? n172_o : n173_o;
  /* T65.vhd:289:33  */
  assign n175_o = n161_o ? n171_o : n174_o;
  /* T65.vhd:296:39  */
  assign n177_o = ir == 8'b00000000;
  /* T65.vhd:296:63  */
  assign n179_o = mcycle == 3'b001;
  /* T65.vhd:296:52  */
  assign n180_o = n179_o & n177_o;
  /* T65.vhd:296:84  */
  assign n181_o = ~irqcycle;
  /* T65.vhd:296:71  */
  assign n182_o = n181_o & n180_o;
  /* T65.vhd:296:103  */
  assign n183_o = ~nmicycle;
  /* T65.vhd:296:90  */
  assign n184_o = n183_o & n182_o;
  /* T65.vhd:297:50  */
  assign n186_o = pc + 16'b0000000000000001;
  /* T65.vhd:304:52  */
  assign n189_o = pc + 16'b0000000000000001;
  /* T65.vhd:303:35  */
  assign n191_o = jump == 2'b01;
  /* T65.vhd:307:61  */
  assign n192_o = {DI, dl};
  /* T65.vhd:306:35  */
  assign n194_o = jump == 2'b10;
  /* T65.vhd:310:53  */
  assign n195_o = pcadder[8];
  /* T65.vhd:311:56  */
  assign n196_o = dl[7];
  /* T65.vhd:311:60  */
  assign n197_o = ~n196_o;
  /* T65.vhd:312:80  */
  assign n198_o = pc[15:8];
  /* T65.vhd:312:94  */
  assign n200_o = n198_o + 8'b00000001;
  /* T65.vhd:314:80  */
  assign n201_o = pc[15:8];
  /* T65.vhd:314:94  */
  assign n203_o = n201_o - 8'b00000001;
  /* T65.vhd:311:51  */
  assign n204_o = n197_o ? n200_o : n203_o;
  assign n205_o = n186_o[15:8];
  assign n206_o = n147_o[15:8];
  assign n207_o = pc[15:8];
  /* T65.vhd:264:33  */
  assign n208_o = n152_o ? n206_o : n207_o;
  /* T65.vhd:296:33  */
  assign n209_o = n184_o ? n205_o : n208_o;
  /* T65.vhd:310:43  */
  assign n210_o = n195_o ? n204_o : n209_o;
  /* T65.vhd:317:68  */
  assign n211_o = pcadder[7:0];
  /* T65.vhd:309:35  */
  assign n213_o = jump == 2'b11;
  assign n214_o = {n213_o, n194_o, n191_o};
  assign n215_o = n189_o[7:0];
  assign n216_o = n192_o[7:0];
  assign n217_o = n186_o[7:0];
  assign n218_o = n147_o[7:0];
  assign n219_o = pc[7:0];
  /* T65.vhd:264:33  */
  assign n220_o = n152_o ? n218_o : n219_o;
  /* T65.vhd:296:33  */
  assign n221_o = n184_o ? n217_o : n220_o;
  /* T65.vhd:302:33  */
  always @*
    case (n214_o)
      3'b100: n222_o = n211_o;
      3'b010: n222_o = n216_o;
      3'b001: n222_o = n215_o;
      default: n222_o = n221_o;
    endcase
  assign n223_o = n189_o[15:8];
  assign n224_o = n192_o[15:8];
  assign n225_o = n186_o[15:8];
  assign n226_o = n147_o[15:8];
  assign n227_o = pc[15:8];
  /* T65.vhd:264:33  */
  assign n228_o = n152_o ? n226_o : n227_o;
  /* T65.vhd:296:33  */
  assign n229_o = n184_o ? n225_o : n228_o;
  /* T65.vhd:302:33  */
  always @*
    case (n214_o)
      3'b100: n230_o = n210_o;
      3'b010: n230_o = n224_o;
      3'b001: n230_o = n223_o;
      default: n230_o = n229_o;
    endcase
  assign n242_o = {n230_o, n222_o};
  assign n244_o = {n175_o, n170_o};
  /* T65.vhd:254:25  */
  assign n252_o = n142_o & really_rdy;
  /* T65.vhd:254:25  */
  assign n253_o = n142_o & really_rdy;
  /* T65.vhd:253:19  */
  assign n259_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n260_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n261_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n262_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n263_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n264_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n265_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n266_o = n252_o & Enable;
  /* T65.vhd:253:19  */
  assign n267_o = n253_o & Enable;
  /* T65.vhd:253:19  */
  assign n268_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n269_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n270_o = really_rdy & Enable;
  /* T65.vhd:253:19  */
  assign n271_o = really_rdy & Enable;
  /* T65.vhd:326:29  */
  assign n315_o = pc[7:0];
  /* T65.vhd:326:20  */
  assign n316_o = {1'b0, n315_o};  //  uext
  /* T65.vhd:326:65  */
  assign n317_o = dl[7];
  /* T65.vhd:326:69  */
  assign n318_o = {n317_o, dl};
  /* T65.vhd:326:45  */
  assign n319_o = n316_o + n318_o;
  /* T65.vhd:326:78  */
  assign n320_o = pcadd ? n319_o : n323_o;
  /* T65.vhd:327:41  */
  assign n321_o = pc[7:0];
  /* T65.vhd:327:37  */
  assign n323_o = {1'b0, n321_o};
  /* T65.vhd:334:43  */
  assign n328_o = mcycle == 3'b000;
  /* T65.vhd:344:49  */
  assign n335_o = lda | ldx;
  /* T65.vhd:344:56  */
  assign n336_o = n335_o | ldy;
  /* T65.vhd:334:33  */
  assign n339_o = lda & n328_o;
  /* T65.vhd:334:33  */
  assign n341_o = ldx & n328_o;
  /* T65.vhd:334:33  */
  assign n343_o = ldy & n328_o;
  /* T65.vhd:334:33  */
  assign n344_o = n336_o & n328_o;
  /* T65.vhd:354:38  */
  assign n347_o = ir[4:0];
  /* T65.vhd:354:51  */
  assign n349_o = n347_o == 5'b11000;
  /* T65.vhd:355:48  */
  assign n350_o = ir[7:5];
  /* T65.vhd:356:41  */
  assign n353_o = n350_o == 3'b000;
  /* T65.vhd:358:41  */
  assign n356_o = n350_o == 3'b001;
  /* T65.vhd:360:41  */
  assign n359_o = n350_o == 3'b010;
  /* T65.vhd:362:41  */
  assign n362_o = n350_o == 3'b011;
  /* T65.vhd:364:41  */
  assign n365_o = n350_o == 3'b101;
  /* T65.vhd:366:41  */
  assign n368_o = n350_o == 3'b110;
  /* T65.vhd:368:41  */
  assign n371_o = n350_o == 3'b111;
  assign n372_o = {n371_o, n368_o, n365_o, n362_o, n359_o, n356_o, n353_o};
  assign n373_o = alu_q[0];
  assign n374_o = p_out[0];
  assign n375_o = p_out[0];
  assign n376_o = p[0];
  /* T65.vhd:334:33  */
  assign n377_o = n344_o ? n375_o : n376_o;
  /* T65.vhd:348:33  */
  assign n378_o = savep ? n374_o : n377_o;
  /* T65.vhd:351:33  */
  assign n379_o = ldp ? n373_o : n378_o;
  /* T65.vhd:355:41  */
  always @*
    case (n372_o)
      7'b1000000: n380_o = n379_o;
      7'b0100000: n380_o = n379_o;
      7'b0010000: n380_o = n379_o;
      7'b0001000: n380_o = n379_o;
      7'b0000100: n380_o = n379_o;
      7'b0000010: n380_o = 1'b1;
      7'b0000001: n380_o = 1'b0;
      default: n380_o = n379_o;
    endcase
  assign n381_o = alu_q[2];
  assign n382_o = p_out[2];
  assign n383_o = p_out[2];
  assign n384_o = p[2];
  /* T65.vhd:334:33  */
  assign n385_o = n344_o ? n383_o : n384_o;
  /* T65.vhd:348:33  */
  assign n386_o = savep ? n382_o : n385_o;
  /* T65.vhd:351:33  */
  assign n387_o = ldp ? n381_o : n386_o;
  /* T65.vhd:355:41  */
  always @*
    case (n372_o)
      7'b1000000: n388_o = n387_o;
      7'b0100000: n388_o = n387_o;
      7'b0010000: n388_o = n387_o;
      7'b0001000: n388_o = 1'b1;
      7'b0000100: n388_o = 1'b0;
      7'b0000010: n388_o = n387_o;
      7'b0000001: n388_o = n387_o;
      default: n388_o = n387_o;
    endcase
  assign n389_o = alu_q[3];
  assign n390_o = p_out[3];
  assign n391_o = p_out[3];
  assign n392_o = p[3];
  /* T65.vhd:334:33  */
  assign n393_o = n344_o ? n391_o : n392_o;
  /* T65.vhd:348:33  */
  assign n394_o = savep ? n390_o : n393_o;
  /* T65.vhd:351:33  */
  assign n395_o = ldp ? n389_o : n394_o;
  /* T65.vhd:355:41  */
  always @*
    case (n372_o)
      7'b1000000: n396_o = 1'b1;
      7'b0100000: n396_o = 1'b0;
      7'b0010000: n396_o = n395_o;
      7'b0001000: n396_o = n395_o;
      7'b0000100: n396_o = n395_o;
      7'b0000010: n396_o = n395_o;
      7'b0000001: n396_o = n395_o;
      default: n396_o = n395_o;
    endcase
  assign n397_o = alu_q[6];
  assign n398_o = p_out[6];
  assign n399_o = p_out[6];
  assign n400_o = p[6];
  /* T65.vhd:334:33  */
  assign n401_o = n344_o ? n399_o : n400_o;
  /* T65.vhd:348:33  */
  assign n402_o = savep ? n398_o : n401_o;
  /* T65.vhd:351:33  */
  assign n403_o = ldp ? n397_o : n402_o;
  /* T65.vhd:355:41  */
  always @*
    case (n372_o)
      7'b1000000: n404_o = n403_o;
      7'b0100000: n404_o = n403_o;
      7'b0010000: n404_o = 1'b0;
      7'b0001000: n404_o = n403_o;
      7'b0000100: n404_o = n403_o;
      7'b0000010: n404_o = n403_o;
      7'b0000001: n404_o = n403_o;
      default: n404_o = n403_o;
    endcase
  assign n405_o = {n396_o, n388_o};
  assign n406_o = alu_q[0];
  assign n407_o = p_out[0];
  assign n408_o = p_out[0];
  assign n409_o = p[0];
  /* T65.vhd:334:33  */
  assign n410_o = n344_o ? n408_o : n409_o;
  /* T65.vhd:348:33  */
  assign n411_o = savep ? n407_o : n410_o;
  /* T65.vhd:351:33  */
  assign n412_o = ldp ? n406_o : n411_o;
  /* T65.vhd:354:33  */
  assign n413_o = n349_o ? n380_o : n412_o;
  assign n422_o = alu_q[6];
  assign n423_o = p_out[6];
  assign n424_o = p_out[6];
  assign n425_o = p[6];
  /* T65.vhd:334:33  */
  assign n426_o = n344_o ? n424_o : n425_o;
  /* T65.vhd:348:33  */
  assign n427_o = savep ? n423_o : n426_o;
  /* T65.vhd:351:33  */
  assign n428_o = ldp ? n422_o : n427_o;
  /* T65.vhd:354:33  */
  assign n429_o = n349_o ? n404_o : n428_o;
  assign n444_o = alu_q[1];
  assign n445_o = p_out[1];
  assign n446_o = p_out[1];
  assign n447_o = p[1];
  /* T65.vhd:334:33  */
  assign n448_o = n344_o ? n446_o : n447_o;
  /* T65.vhd:348:33  */
  assign n449_o = savep ? n445_o : n448_o;
  /* T65.vhd:351:33  */
  assign n450_o = ldp ? n444_o : n449_o;
  assign n451_o = alu_q[7];
  assign n452_o = p_out[7];
  assign n453_o = p_out[7];
  assign n454_o = p[7];
  /* T65.vhd:334:33  */
  assign n455_o = n344_o ? n453_o : n454_o;
  /* T65.vhd:348:33  */
  assign n456_o = savep ? n452_o : n455_o;
  /* T65.vhd:351:33  */
  assign n457_o = ldp ? n451_o : n456_o;
  /* T65.vhd:384:39  */
  assign n474_o = ir == 8'b00000000;
  /* T65.vhd:384:65  */
  assign n475_o = ~rstcycle;
  /* T65.vhd:384:52  */
  assign n476_o = n475_o & n474_o;
  /* T65.vhd:384:91  */
  assign n477_o = nmicycle | irqcycle;
  /* T65.vhd:384:71  */
  assign n478_o = n477_o & n476_o;
  /* T65.vhd:385:21  */
  assign n480_o = mcycle == 3'b011;
  /* T65.vhd:388:24  */
  assign n483_o = mcycle == 3'b100;
  assign n485_o = n405_o[0];
  assign n486_o = alu_q[2];
  assign n487_o = p_out[2];
  assign n488_o = p_out[2];
  assign n489_o = p[2];
  /* T65.vhd:334:33  */
  assign n490_o = n344_o ? n488_o : n489_o;
  /* T65.vhd:348:33  */
  assign n491_o = savep ? n487_o : n490_o;
  /* T65.vhd:351:33  */
  assign n492_o = ldp ? n486_o : n491_o;
  /* T65.vhd:354:33  */
  assign n493_o = n349_o ? n485_o : n492_o;
  /* T65.vhd:388:11  */
  assign n494_o = n483_o ? 1'b1 : n493_o;
  assign n495_o = n405_o[0];
  assign n496_o = alu_q[2];
  assign n497_o = p_out[2];
  assign n498_o = p_out[2];
  assign n499_o = p[2];
  /* T65.vhd:334:33  */
  assign n500_o = n344_o ? n498_o : n499_o;
  /* T65.vhd:348:33  */
  assign n501_o = savep ? n497_o : n500_o;
  /* T65.vhd:351:33  */
  assign n502_o = ldp ? n496_o : n501_o;
  /* T65.vhd:354:33  */
  assign n503_o = n349_o ? n495_o : n502_o;
  /* T65.vhd:385:11  */
  assign n504_o = n480_o ? n503_o : n494_o;
  /* T65.vhd:384:33  */
  assign n505_o = n516_o ? 1'b0 : 1'b1;
  assign n506_o = n405_o[0];
  assign n507_o = alu_q[2];
  assign n508_o = p_out[2];
  assign n509_o = p_out[2];
  assign n510_o = p[2];
  /* T65.vhd:334:33  */
  assign n511_o = n344_o ? n509_o : n510_o;
  /* T65.vhd:348:33  */
  assign n512_o = savep ? n508_o : n511_o;
  /* T65.vhd:351:33  */
  assign n513_o = ldp ? n507_o : n512_o;
  /* T65.vhd:354:33  */
  assign n514_o = n349_o ? n506_o : n513_o;
  /* T65.vhd:384:33  */
  assign n515_o = n478_o ? n504_o : n514_o;
  /* T65.vhd:384:33  */
  assign n516_o = n480_o & n478_o;
  assign n517_o = n405_o[1];
  assign n518_o = alu_q[3];
  assign n519_o = p_out[3];
  assign n520_o = p_out[3];
  assign n521_o = p[3];
  /* T65.vhd:334:33  */
  assign n522_o = n344_o ? n520_o : n521_o;
  /* T65.vhd:348:33  */
  assign n523_o = savep ? n519_o : n522_o;
  /* T65.vhd:351:33  */
  assign n524_o = ldp ? n518_o : n523_o;
  /* T65.vhd:354:33  */
  assign n525_o = n349_o ? n517_o : n524_o;
  /* T65.vhd:393:58  */
  assign n526_o = ~SO_n;
  /* T65.vhd:393:49  */
  assign n527_o = n526_o & so_n_o;
  /* T65.vhd:393:33  */
  assign n529_o = n527_o ? 1'b1 : n429_o;
  /* T65.vhd:396:62  */
  assign n531_o = mode_r != 2'b00;
  /* T65.vhd:396:51  */
  assign n532_o = n531_o & rstcycle;
  assign n536_o = {1'b0, 1'b1};
  assign n537_o = {n525_o, n515_o};
  /* T65.vhd:396:33  */
  assign n538_o = n532_o ? n536_o : n537_o;
  /* T65.vhd:333:25  */
  assign n543_o = n339_o & really_rdy;
  /* T65.vhd:333:25  */
  assign n545_o = n341_o & really_rdy;
  /* T65.vhd:333:25  */
  assign n547_o = n343_o & really_rdy;
  assign n548_o = {n457_o, n529_o, 1'b1, n505_o, n538_o, n450_o, n413_o};
  /* T65.vhd:332:19  */
  assign n555_o = n543_o & Enable;
  /* T65.vhd:332:19  */
  assign n557_o = n545_o & Enable;
  /* T65.vhd:332:19  */
  assign n559_o = n547_o & Enable;
  /* T65.vhd:332:19  */
  assign n560_o = really_rdy & Enable;
  /* T65.vhd:332:19  */
  assign n562_o = really_rdy & Enable;
  /* T65.vhd:332:19  */
  assign n563_o = really_rdy & Enable;
  /* T65.vhd:332:19  */
  assign n564_o = really_rdy & Enable;
  /* T65.vhd:420:26  */
  assign n579_o = ~Res_n;
  /* T65.vhd:436:77  */
  assign n582_o = ad + 8'b00000001;
  /* T65.vhd:437:79  */
  assign n584_o = bal + 9'b000000001;
  /* T65.vhd:434:33  */
  assign n586_o = baadd == 2'b01;
  /* T65.vhd:440:84  */
  assign n587_o = bal[7:0];
  /* T65.vhd:440:65  */
  assign n588_o = {1'b0, n587_o};  //  uext
  /* T65.vhd:440:103  */
  assign n589_o = {1'b0, busa};  //  uext
  /* T65.vhd:440:101  */
  assign n590_o = n588_o + n589_o;
  /* T65.vhd:438:33  */
  assign n592_o = baadd == 2'b10;
  /* T65.vhd:443:47  */
  assign n593_o = bal[8];
  /* T65.vhd:444:87  */
  assign n595_o = bah + 8'b00000001;
  /* T65.vhd:443:41  */
  assign n596_o = n593_o ? n595_o : bah;
  /* T65.vhd:441:33  */
  assign n598_o = baadd == 2'b11;
  assign n599_o = {n598_o, n592_o, n586_o};
  /* T65.vhd:433:33  */
  always @*
    case (n599_o)
      3'b100: n600_o = ad;
      3'b010: n600_o = ad;
      3'b001: n600_o = n582_o;
      default: n600_o = ad;
    endcase
  /* T65.vhd:433:33  */
  always @*
    case (n599_o)
      3'b100: n601_o = n596_o;
      3'b010: n601_o = bah;
      3'b001: n601_o = bah;
      default: n601_o = bah;
    endcase
  /* T65.vhd:433:33  */
  always @*
    case (n599_o)
      3'b100: n602_o = bal;
      3'b010: n602_o = n590_o;
      3'b001: n602_o = n584_o;
      default: n602_o = bal;
    endcase
  /* T65.vhd:452:89  */
  assign n603_o = y[7:0];
  /* T65.vhd:452:77  */
  assign n604_o = ad + n603_o;
  /* T65.vhd:454:89  */
  assign n605_o = x[7:0];
  /* T65.vhd:454:77  */
  assign n606_o = ad + n605_o;
  /* T65.vhd:451:35  */
  assign n607_o = addy ? n604_o : n606_o;
  /* T65.vhd:450:33  */
  assign n608_o = adadd ? n607_o : n600_o;
  /* T65.vhd:458:39  */
  assign n610_o = ir == 8'b00000000;
  assign n617_o = n616_o[8:3];
  /* T65.vhd:468:58  */
  assign n619_o = set_addr_to_r == 2'b11;
  assign n621_o = n611_o[0];
  assign n622_o = n612_o[0];
  assign n623_o = n613_o[0];
  /* T65.vhd:463:41  */
  assign n624_o = nmicycle ? n622_o : n623_o;
  /* T65.vhd:461:41  */
  assign n625_o = rstcycle ? n621_o : n624_o;
  /* T65.vhd:468:41  */
  assign n626_o = n619_o ? 1'b1 : n625_o;
  assign n627_o = n611_o[2:1];
  assign n628_o = n612_o[2:1];
  assign n629_o = n613_o[2:1];
  /* T65.vhd:463:41  */
  assign n630_o = nmicycle ? n628_o : n629_o;
  /* T65.vhd:461:41  */
  assign n631_o = rstcycle ? n627_o : n630_o;
  /* T65.vhd:458:33  */
  assign n633_o = n610_o ? 8'b11111111 : n601_o;
  assign n634_o = {n617_o, n631_o, n626_o};
  /* T65.vhd:474:33  */
  assign n636_o = lddi ? DI : dl;
  /* T65.vhd:477:33  */
  assign n637_o = ldalu ? alu_q : n636_o;
  /* T65.vhd:480:33  */
  assign n638_o = ldad ? DI : n608_o;
  assign n639_o = n634_o[7:0];
  assign n640_o = n602_o[7:0];
  /* T65.vhd:458:33  */
  assign n641_o = n610_o ? n639_o : n640_o;
  /* T65.vhd:483:33  */
  assign n642_o = ldbal ? DI : n641_o;
  assign n643_o = n634_o[8];
  assign n644_o = n602_o[8];
  /* T65.vhd:458:33  */
  assign n645_o = n610_o ? n643_o : n644_o;
  /* T65.vhd:486:33  */
  assign n646_o = ldbah ? DI : n633_o;
  assign n650_o = {n645_o, n642_o};
  /* T65.vhd:428:19  */
  assign n654_o = Rdy & Enable;
  /* T65.vhd:428:19  */
  assign n655_o = Rdy & Enable;
  /* T65.vhd:428:19  */
  assign n656_o = Rdy & Enable;
  /* T65.vhd:428:19  */
  assign n657_o = Rdy & Enable;
  /* T65.vhd:428:19  */
  assign n658_o = Rdy & Enable;
  /* T65.vhd:428:19  */
  assign n659_o = Rdy & Enable;
  /* T65.vhd:494:40  */
  assign n679_o = bal[8];
  /* T65.vhd:494:33  */
  assign n680_o = ~n679_o;
  /* T65.vhd:494:29  */
  assign n681_o = breakatna & n680_o;
  /* T65.vhd:494:70  */
  assign n682_o = pcadder[8];
  /* T65.vhd:494:59  */
  assign n683_o = ~n682_o;
  /* T65.vhd:494:55  */
  assign n684_o = pcadd & n683_o;
  /* T65.vhd:494:45  */
  assign n685_o = n681_o | n684_o;
  /* T65.vhd:498:28  */
  assign n687_o = set_busa_to == 3'b000;
  /* T65.vhd:499:28  */
  assign n688_o = abc[7:0];
  /* T65.vhd:499:41  */
  assign n690_o = set_busa_to == 3'b001;
  /* T65.vhd:500:26  */
  assign n691_o = x[7:0];
  /* T65.vhd:500:39  */
  assign n693_o = set_busa_to == 3'b010;
  /* T65.vhd:501:26  */
  assign n694_o = y[7:0];
  /* T65.vhd:501:39  */
  assign n696_o = set_busa_to == 3'b011;
  /* T65.vhd:502:43  */
  assign n697_o = s[7:0];
  /* T65.vhd:502:57  */
  assign n699_o = set_busa_to == 3'b100;
  /* T65.vhd:503:27  */
  assign n701_o = set_busa_to == 3'b101;
  assign n703_o = {n701_o, n699_o, n696_o, n693_o, n690_o, n687_o};
  /* T65.vhd:497:9  */
  always @*
    case (n703_o)
      6'b100000: n704_o = p;
      6'b010000: n704_o = n697_o;
      6'b001000: n704_o = n694_o;
      6'b000100: n704_o = n691_o;
      6'b000010: n704_o = n688_o;
      6'b000001: n704_o = DI;
      default: n704_o = 8'bX;
    endcase
  /* T65.vhd:507:61  */
  assign n705_o = s[7:0];
  /* T65.vhd:507:41  */
  assign n707_o = {16'b0000000000000001, n705_o};
  /* T65.vhd:507:75  */
  assign n709_o = set_addr_to_r == 2'b01;
  /* T65.vhd:508:29  */
  assign n711_o = {dbr, 8'b00000000};
  /* T65.vhd:508:42  */
  assign n712_o = {n711_o, ad};
  /* T65.vhd:508:47  */
  assign n714_o = set_addr_to_r == 2'b10;
  /* T65.vhd:509:36  */
  assign n716_o = {8'b00000000, bah};
  /* T65.vhd:509:47  */
  assign n717_o = bal[7:0];
  /* T65.vhd:509:42  */
  assign n718_o = {n716_o, n717_o};
  /* T65.vhd:509:60  */
  assign n720_o = set_addr_to_r == 2'b11;
  /* T65.vhd:510:50  */
  assign n721_o = pc[15:8];
  /* T65.vhd:510:29  */
  assign n722_o = {pbr, n721_o};
  /* T65.vhd:510:91  */
  assign n723_o = pcadder[7:0];
  /* T65.vhd:510:65  */
  assign n724_o = {n722_o, n723_o};
  assign n725_o = {n720_o, n714_o, n709_o};
  /* T65.vhd:506:9  */
  always @*
    case (n725_o)
      3'b100: n726_o = n718_o;
      3'b010: n726_o = n712_o;
      3'b001: n726_o = n707_o;
      default: n726_o = n724_o;
    endcase
  /* T65.vhd:513:26  */
  assign n728_o = write_data_r == 3'b000;
  /* T65.vhd:514:28  */
  assign n729_o = abc[7:0];
  /* T65.vhd:514:41  */
  assign n731_o = write_data_r == 3'b001;
  /* T65.vhd:515:26  */
  assign n732_o = x[7:0];
  /* T65.vhd:515:39  */
  assign n734_o = write_data_r == 3'b010;
  /* T65.vhd:516:26  */
  assign n735_o = y[7:0];
  /* T65.vhd:516:39  */
  assign n737_o = write_data_r == 3'b011;
  /* T65.vhd:517:43  */
  assign n738_o = s[7:0];
  /* T65.vhd:517:57  */
  assign n740_o = write_data_r == 3'b100;
  /* T65.vhd:518:27  */
  assign n742_o = write_data_r == 3'b101;
  /* T65.vhd:519:44  */
  assign n743_o = pc[7:0];
  /* T65.vhd:519:58  */
  assign n745_o = write_data_r == 3'b110;
  /* T65.vhd:520:44  */
  assign n746_o = pc[15:8];
  assign n747_o = {n745_o, n742_o, n740_o, n737_o, n734_o, n731_o, n728_o};
  /* T65.vhd:512:9  */
  always @*
    case (n747_o)
      7'b1000000: n748_o = n743_o;
      7'b0100000: n748_o = p;
      7'b0010000: n748_o = n738_o;
      7'b0001000: n748_o = n735_o;
      7'b0000100: n748_o = n732_o;
      7'b0000010: n748_o = n729_o;
      7'b0000001: n748_o = dl;
      default: n748_o = n746_o;
    endcase
  /* T65.vhd:530:26  */
  assign n751_o = ~Res_n;
  /* T65.vhd:539:43  */
  assign n753_o = mcycle == lcycle;
  /* T65.vhd:539:52  */
  assign n754_o = n753_o | brk;
  /* T65.vhd:546:55  */
  assign n755_o = ~irq_n_o;
  /* T65.vhd:546:66  */
  assign n756_o = p[2];
  /* T65.vhd:546:75  */
  assign n757_o = ~n756_o;
  /* T65.vhd:546:61  */
  assign n758_o = n757_o & n755_o;
  /* T65.vhd:546:41  */
  assign n761_o = n758_o ? 1'b1 : 1'b0;
  /* T65.vhd:544:41  */
  assign n763_o = nmiact ? 1'b0 : n761_o;
  /* T65.vhd:544:41  */
  assign n767_o = nmiact ? 1'b1 : 1'b0;
  /* T65.vhd:550:85  */
  assign n770_o = mcycle + 3'b001;
  /* T65.vhd:539:33  */
  assign n772_o = n754_o ? 3'b000 : n770_o;
  /* T65.vhd:553:33  */
  assign n778_o = nmicycle ? 1'b0 : nmiact;
  /* T65.vhd:556:60  */
  assign n779_o = ~NMI_n;
  /* T65.vhd:556:50  */
  assign n780_o = n779_o & nmi_n_o;
  /* T65.vhd:556:33  */
  assign n782_o = n780_o ? 1'b1 : n778_o;
  /* T65.vhd:538:25  */
  assign n784_o = n754_o & really_rdy;
  /* T65.vhd:538:25  */
  assign n785_o = n754_o & really_rdy;
  /* T65.vhd:538:25  */
  assign n786_o = n754_o & really_rdy;
  /* T65.vhd:537:19  */
  assign n788_o = really_rdy & Enable;
  /* T65.vhd:537:19  */
  assign n789_o = n784_o & Enable;
  /* T65.vhd:537:19  */
  assign n790_o = n785_o & Enable;
  /* T65.vhd:537:19  */
  assign n791_o = n786_o & Enable;
  /* T65.vhd:537:19  */
  assign n792_o = really_rdy & Enable;
  assign n809_o = abc[7:0];
  /* T65.vhd:331:17  */
  assign n810_o = n555_o ? alu_q : n809_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n811_q <= n810_o;
  assign n813_o = {8'bZ, n811_q};
  assign n814_o = x[7:0];
  /* T65.vhd:331:17  */
  assign n815_o = n557_o ? alu_q : n814_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n816_q <= n815_o;
  assign n818_o = {8'bZ, n816_q};
  assign n819_o = y[7:0];
  /* T65.vhd:331:17  */
  assign n820_o = n559_o ? alu_q : n819_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n821_q <= n820_o;
  assign n823_o = {8'bZ, n821_q};
  /* T65.vhd:331:17  */
  assign n826_o = n560_o ? n548_o : p;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n827_q <= n826_o;
  initial
    n827_q = 8'b00000000;
  /* T65.vhd:427:17  */
  assign n828_o = n654_o ? n638_o : ad;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n829_q <= 8'b00000000;
    else
      n829_q <= n828_o;
  /* T65.vhd:427:17  */
  assign n830_o = n655_o ? n637_o : dl;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n831_q <= 8'b00000000;
    else
      n831_q <= n830_o;
  /* T65.vhd:427:17  */
  assign n832_o = n656_o ? n646_o : bah;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n833_q <= 8'b00000000;
    else
      n833_q <= n832_o;
  /* T65.vhd:427:17  */
  assign n834_o = n657_o ? n650_o : bal;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n835_q <= 9'b000000000;
    else
      n835_q <= n834_o;
  /* T65.vhd:252:17  */
  assign n836_o = n259_o ? 8'b11111111 : pbr;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n837_q <= 8'b00000000;
    else
      n837_q <= n836_o;
  /* T65.vhd:252:17  */
  assign n838_o = n260_o ? 8'b11111111 : dbr;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n839_q <= 8'b00000000;
    else
      n839_q <= n838_o;
  /* T65.vhd:252:17  */
  assign n840_o = n261_o ? n242_o : pc;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n841_q <= 16'b0000000000000000;
    else
      n841_q <= n840_o;
  /* T65.vhd:252:17  */
  assign n842_o = n262_o ? n244_o : s;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n843_q <= 16'b0000000000000000;
    else
      n843_q <= n842_o;
  /* T65.vhd:252:17  */
  assign n844_o = n263_o ? 1'b0 : ef_i;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n845_q <= 1'b1;
    else
      n845_q <= n844_o;
  /* T65.vhd:252:17  */
  assign n846_o = n264_o ? 1'b0 : mf_i;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n847_q <= 1'b1;
    else
      n847_q <= n846_o;
  /* T65.vhd:252:17  */
  assign n848_o = n265_o ? 1'b0 : xf_i;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n849_q <= 1'b1;
    else
      n849_q <= n848_o;
  /* T65.vhd:252:17  */
  assign n850_o = n266_o ? n151_o : ir;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n851_q <= 8'b00000000;
    else
      n851_q <= n850_o;
  /* T65.vhd:536:17  */
  assign n852_o = n788_o ? n772_o : mcycle;
  /* T65.vhd:536:17  */
  always @(posedge Clk or posedge n751_o)
    if (n751_o)
      n853_q <= 3'b001;
    else
      n853_q <= n852_o;
  /* T65.vhd:252:17  */
  assign n854_o = n267_o ? Mode : mode_r;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n855_q <= 2'b00;
    else
      n855_q <= n854_o;
  /* T65.vhd:252:17  */
  assign n856_o = n268_o ? alu_op : alu_op_r;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n857_q <= 4'b1100;
    else
      n857_q <= n856_o;
  /* T65.vhd:252:17  */
  assign n858_o = n269_o ? write_data : write_data_r;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n859_q <= 3'b000;
    else
      n859_q <= n858_o;
  /* T65.vhd:252:17  */
  assign n860_o = n270_o ? n156_o : set_addr_to_r;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n861_q <= 2'b00;
    else
      n861_q <= n860_o;
  /* T65.vhd:536:17  */
  assign n862_o = n789_o ? 1'b0 : rstcycle;
  /* T65.vhd:536:17  */
  always @(posedge Clk or posedge n751_o)
    if (n751_o)
      n863_q <= 1'b1;
    else
      n863_q <= n862_o;
  /* T65.vhd:536:17  */
  assign n864_o = n790_o ? n763_o : irqcycle;
  /* T65.vhd:536:17  */
  always @(posedge Clk or posedge n751_o)
    if (n751_o)
      n865_q <= 1'b0;
    else
      n865_q <= n864_o;
  /* T65.vhd:536:17  */
  assign n866_o = n791_o ? n767_o : nmicycle;
  /* T65.vhd:536:17  */
  always @(posedge Clk or posedge n751_o)
    if (n751_o)
      n867_q <= 1'b0;
    else
      n867_q <= n866_o;
  /* T65.vhd:331:17  */
  assign n870_o = n562_o ? SO_n : so_n_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n871_q <= n870_o;
  /* T65.vhd:331:17  */
  assign n872_o = n563_o ? IRQ_n : irq_n_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n873_q <= n872_o;
  /* T65.vhd:331:17  */
  assign n874_o = n564_o ? NMI_n : nmi_n_o;
  /* T65.vhd:331:17  */
  always @(posedge Clk)
    n875_q <= n874_o;
  /* T65.vhd:536:17  */
  assign n876_o = n792_o ? n782_o : nmiact;
  /* T65.vhd:536:17  */
  always @(posedge Clk or posedge n751_o)
    if (n751_o)
      n877_q <= 1'b0;
    else
      n877_q <= n876_o;
  /* T65.vhd:427:17  */
  assign n878_o = n658_o ? busa : busa_r;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n879_q <= 8'b00000000;
    else
      n879_q <= n878_o;
  /* T65.vhd:427:17  */
  assign n880_o = n659_o ? DI : busb;
  /* T65.vhd:427:17  */
  always @(posedge Clk or posedge n579_o)
    if (n579_o)
      n881_q <= 8'b00000000;
    else
      n881_q <= n880_o;
  /* T65.vhd:252:17  */
  assign n882_o = n271_o ? n140_o : r_w_n_i;
  /* T65.vhd:252:17  */
  always @(posedge Clk or posedge n137_o)
    if (n137_o)
      n883_q <= 1'b1;
    else
      n883_q <= n882_o;
endmodule

