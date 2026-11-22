// GHDL 4.1.0 output for T80_MCode.vhd from T80s synthesis with -gMode=2.
// Copyright (c) 2018 Sorgelig
//  Test passed: ZEXDOC, ZEXALL, Z80Full(*), Z80memptr
//  (*) Currently only SCF and CCF instructions aren't passed X/Y flags check as
//      correct implementation is still unclear.
//
// ****
// T80(b) core. In an effort to merge and maintain bug fixes ....
//
// Ver 303 add undocumented DDCB and FDCB opcodes by TobiFlex 20.04.2010
// Ver 300 started tidyup
// MikeJ March 2005
// Latest version from www.fpgaarcade.com (original www.opencores.org)
//
// ****
// Z80 compatible microprocessor core
//
// Version : 0242
// Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

/* verilator coverage_off */
module t80_8080_mcode
  (input  [7:0] ir,
   input  [1:0] iset,
   input  [2:0] mcycle,
   input  [7:0] f,
   input  nmicycle,
   input  intcycle,
   input  [1:0] xy_state,
   output [2:0] mcycles,
   output [2:0] tstates,
   output [1:0] prefix,
   output inc_pc,
   output inc_wz,
   output [3:0] incdec_16,
   output read_to_reg,
   output read_to_acc,
   output [3:0] set_busa_to,
   output [3:0] set_busb_to,
   output [3:0] alu_op,
   output save_alu,
   output preservec,
   output arith16,
   output [2:0] set_addr_to,
   output iorq,
   output jump,
   output jumpe,
   output jumpxy,
   output call,
   output rstp,
   output ldz,
   output ldw,
   output ldsphl,
   output [2:0] special_ld,
   output exchangedh,
   output exchangerp,
   output exchangeaf,
   output exchangers,
   output i_djnz,
   output i_cpl,
   output i_ccf,
   output i_scf,
   output i_retn,
   output i_bt,
   output i_bc,
   output i_btr,
   output i_rld,
   output i_rrd,
   output i_inrc,
   output [1:0] setwz,
   output setdi,
   output setei,
   output [1:0] imode,
   output halt,
   output noread,
   output write,
   output xybit_undoc);
  wire [2:0] n2172_o;
  wire [2:0] n2173_o;
  wire [1:0] n2174_o;
  wire n2176_o;
  wire [2:0] n2179_o;
  wire [2:0] n2180_o;
  wire [3:0] n2182_o;
  wire n2184_o;
  wire n2186_o;
  wire n2187_o;
  wire n2189_o;
  wire n2190_o;
  wire n2192_o;
  wire n2193_o;
  wire n2195_o;
  wire n2196_o;
  wire n2198_o;
  wire n2199_o;
  wire n2201_o;
  wire n2202_o;
  wire n2204_o;
  wire n2205_o;
  wire n2207_o;
  wire n2208_o;
  wire n2210_o;
  wire n2211_o;
  wire n2213_o;
  wire n2214_o;
  wire n2216_o;
  wire n2217_o;
  wire n2219_o;
  wire n2220_o;
  wire n2222_o;
  wire n2223_o;
  wire n2225_o;
  wire n2226_o;
  wire n2228_o;
  wire n2229_o;
  wire n2231_o;
  wire n2232_o;
  wire n2234_o;
  wire n2235_o;
  wire n2237_o;
  wire n2238_o;
  wire n2240_o;
  wire n2241_o;
  wire n2243_o;
  wire n2244_o;
  wire n2246_o;
  wire n2247_o;
  wire n2249_o;
  wire n2250_o;
  wire n2252_o;
  wire n2253_o;
  wire n2255_o;
  wire n2256_o;
  wire n2258_o;
  wire n2259_o;
  wire n2261_o;
  wire n2262_o;
  wire n2264_o;
  wire n2265_o;
  wire n2267_o;
  wire n2268_o;
  wire n2270_o;
  wire n2271_o;
  wire n2273_o;
  wire n2274_o;
  wire n2276_o;
  wire n2277_o;
  wire n2279_o;
  wire n2280_o;
  wire n2282_o;
  wire n2283_o;
  wire n2285_o;
  wire n2286_o;
  wire n2288_o;
  wire n2289_o;
  wire n2291_o;
  wire n2292_o;
  wire n2294_o;
  wire n2295_o;
  wire n2297_o;
  wire n2298_o;
  wire n2300_o;
  wire n2301_o;
  wire n2303_o;
  wire n2304_o;
  wire n2306_o;
  wire n2307_o;
  wire n2309_o;
  wire n2310_o;
  wire n2312_o;
  wire n2313_o;
  wire n2315_o;
  wire n2316_o;
  wire n2318_o;
  wire n2319_o;
  wire n2321_o;
  wire n2322_o;
  wire n2324_o;
  wire n2325_o;
  wire n2327_o;
  wire n2328_o;
  wire [30:0] n2329_o;
  wire n2331_o;
  reg n2334_o;
  reg n2337_o;
  reg [2:0] n2339_o;
  wire n2341_o;
  wire n2343_o;
  wire n2344_o;
  wire n2346_o;
  wire n2347_o;
  wire n2349_o;
  wire n2350_o;
  wire n2352_o;
  wire n2353_o;
  wire n2355_o;
  wire n2356_o;
  wire n2358_o;
  wire n2359_o;
  wire [30:0] n2360_o;
  wire n2362_o;
  wire n2364_o;
  wire [1:0] n2365_o;
  reg n2368_o;
  reg [2:0] n2370_o;
  reg [2:0] n2373_o;
  wire n2375_o;
  wire n2377_o;
  wire n2378_o;
  wire n2380_o;
  wire n2381_o;
  wire n2383_o;
  wire n2384_o;
  wire n2386_o;
  wire n2387_o;
  wire n2389_o;
  wire n2390_o;
  wire n2392_o;
  wire n2393_o;
  wire [30:0] n2394_o;
  wire n2397_o;
  wire n2399_o;
  wire [1:0] n2400_o;
  reg [2:0] n2402_o;
  reg n2404_o;
  reg [2:0] n2407_o;
  reg n2410_o;
  wire n2412_o;
  wire n2414_o;
  wire n2415_o;
  wire n2417_o;
  wire n2418_o;
  wire n2420_o;
  wire n2421_o;
  wire n2423_o;
  wire n2424_o;
  wire n2426_o;
  wire n2427_o;
  wire n2429_o;
  wire n2430_o;
  wire [30:0] n2431_o;
  wire n2434_o;
  wire n2436_o;
  wire [1:0] n2437_o;
  reg n2440_o;
  reg [2:0] n2442_o;
  reg n2444_o;
  reg [2:0] n2447_o;
  reg n2450_o;
  wire n2452_o;
  wire [30:0] n2453_o;
  wire n2455_o;
  wire n2457_o;
  wire [1:0] n2458_o;
  reg n2461_o;
  reg [2:0] n2464_o;
  wire n2466_o;
  wire [30:0] n2467_o;
  wire n2469_o;
  wire n2471_o;
  wire [1:0] n2472_o;
  reg n2475_o;
  reg [2:0] n2478_o;
  wire n2480_o;
  wire [30:0] n2481_o;
  wire n2483_o;
  wire n2485_o;
  wire n2487_o;
  wire [2:0] n2488_o;
  reg n2492_o;
  reg n2495_o;
  reg [2:0] n2498_o;
  reg n2501_o;
  wire n2503_o;
  wire [30:0] n2504_o;
  wire n2506_o;
  wire n2508_o;
  wire [1:0] n2509_o;
  reg [3:0] n2512_o;
  reg [2:0] n2515_o;
  reg [1:0] n2518_o;
  reg n2521_o;
  wire n2523_o;
  wire [30:0] n2524_o;
  wire n2526_o;
  wire n2528_o;
  wire [1:0] n2529_o;
  reg [3:0] n2532_o;
  reg [2:0] n2535_o;
  reg [1:0] n2538_o;
  reg n2541_o;
  wire n2543_o;
  wire [30:0] n2544_o;
  wire n2546_o;
  wire n2548_o;
  wire n2550_o;
  wire [2:0] n2551_o;
  reg n2555_o;
  reg [3:0] n2558_o;
  reg [2:0] n2561_o;
  reg n2564_o;
  reg [1:0] n2567_o;
  reg n2570_o;
  wire n2572_o;
  wire [30:0] n2573_o;
  wire n2575_o;
  wire [2:0] n2577_o;
  wire [2:0] n2579_o;
  wire n2582_o;
  wire n2584_o;
  wire n2586_o;
  wire [2:0] n2588_o;
  wire [2:0] n2590_o;
  wire n2593_o;
  wire n2595_o;
  wire [1:0] n2596_o;
  reg n2600_o;
  reg n2604_o;
  reg [2:0] n2606_o;
  reg n2608_o;
  wire n2610_o;
  wire n2612_o;
  wire n2613_o;
  wire n2615_o;
  wire n2616_o;
  wire n2618_o;
  wire n2619_o;
  wire [30:0] n2620_o;
  wire n2622_o;
  wire n2624_o;
  wire n2627_o;
  wire n2630_o;
  wire [3:0] n2631_o;
  reg n2635_o;
  reg n2638_o;
  reg n2642_o;
  reg [2:0] n2644_o;
  reg [2:0] n2648_o;
  reg n2651_o;
  reg n2654_o;
  wire n2656_o;
  wire [30:0] n2657_o;
  wire n2659_o;
  wire n2661_o;
  wire n2663_o;
  wire n2665_o;
  wire [3:0] n2666_o;
  reg n2670_o;
  reg n2673_o;
  reg [3:0] n2677_o;
  reg [2:0] n2681_o;
  reg n2684_o;
  reg n2687_o;
  reg n2691_o;
  wire n2693_o;
  wire n2695_o;
  wire [30:0] n2696_o;
  wire n2698_o;
  wire [3:0] n2701_o;
  wire [3:0] n2703_o;
  wire n2705_o;
  wire n2707_o;
  wire [3:0] n2710_o;
  wire [3:0] n2712_o;
  wire n2714_o;
  wire n2716_o;
  wire [2:0] n2717_o;
  reg [2:0] n2719_o;
  reg [3:0] n2723_o;
  reg [3:0] n2725_o;
  reg [2:0] n2729_o;
  reg n2733_o;
  wire n2735_o;
  wire n2737_o;
  wire n2738_o;
  wire n2740_o;
  wire n2741_o;
  wire n2743_o;
  wire n2744_o;
  wire [30:0] n2745_o;
  wire n2747_o;
  wire n2749_o;
  wire [2:0] n2751_o;
  wire [2:0] n2753_o;
  wire n2756_o;
  wire n2758_o;
  wire n2760_o;
  wire [2:0] n2762_o;
  wire [2:0] n2764_o;
  wire n2767_o;
  wire n2769_o;
  wire [2:0] n2770_o;
  reg [3:0] n2774_o;
  reg n2778_o;
  reg [2:0] n2780_o;
  reg n2782_o;
  reg [2:0] n2786_o;
  wire n2788_o;
  wire n2790_o;
  wire n2791_o;
  wire n2793_o;
  wire n2794_o;
  wire n2796_o;
  wire n2797_o;
  wire n2799_o;
  wire n2801_o;
  wire n2803_o;
  wire [30:0] n2804_o;
  wire n2806_o;
  wire n2808_o;
  wire n2810_o;
  wire n2812_o;
  wire n2814_o;
  wire [4:0] n2815_o;
  reg [2:0] n2818_o;
  reg [3:0] n2822_o;
  reg n2826_o;
  reg [3:0] n2830_o;
  reg [3:0] n2834_o;
  reg [2:0] n2840_o;
  reg n2843_o;
  reg n2846_o;
  reg n2850_o;
  wire n2852_o;
  wire n2855_o;
  wire n2857_o;
  wire n2858_o;
  wire n2860_o;
  wire n2861_o;
  wire n2863_o;
  wire n2864_o;
  wire n2866_o;
  wire n2867_o;
  wire n2869_o;
  wire n2870_o;
  wire n2872_o;
  wire n2873_o;
  wire n2875_o;
  wire n2876_o;
  wire n2878_o;
  wire n2879_o;
  wire n2881_o;
  wire n2882_o;
  wire n2884_o;
  wire n2885_o;
  wire n2887_o;
  wire n2888_o;
  wire n2890_o;
  wire n2891_o;
  wire n2893_o;
  wire n2894_o;
  wire n2896_o;
  wire n2897_o;
  wire n2899_o;
  wire n2900_o;
  wire n2902_o;
  wire n2903_o;
  wire n2905_o;
  wire n2906_o;
  wire n2908_o;
  wire n2909_o;
  wire n2911_o;
  wire n2912_o;
  wire n2914_o;
  wire n2915_o;
  wire n2917_o;
  wire n2918_o;
  wire n2920_o;
  wire n2921_o;
  wire n2923_o;
  wire n2924_o;
  wire n2926_o;
  wire n2927_o;
  wire n2929_o;
  wire n2930_o;
  wire n2932_o;
  wire n2933_o;
  wire n2935_o;
  wire n2936_o;
  wire n2938_o;
  wire n2939_o;
  wire n2941_o;
  wire n2942_o;
  wire n2944_o;
  wire n2945_o;
  wire n2947_o;
  wire n2948_o;
  wire n2950_o;
  wire n2951_o;
  wire n2953_o;
  wire n2954_o;
  wire n2956_o;
  wire n2957_o;
  wire n2959_o;
  wire n2960_o;
  wire n2962_o;
  wire n2963_o;
  wire n2965_o;
  wire n2966_o;
  wire n2968_o;
  wire n2969_o;
  wire n2971_o;
  wire n2972_o;
  wire n2974_o;
  wire n2975_o;
  wire n2977_o;
  wire n2978_o;
  wire n2980_o;
  wire n2981_o;
  wire n2983_o;
  wire n2984_o;
  wire n2986_o;
  wire n2987_o;
  wire n2989_o;
  wire n2990_o;
  wire n2992_o;
  wire n2993_o;
  wire n2995_o;
  wire n2996_o;
  wire n2998_o;
  wire n2999_o;
  wire n3001_o;
  wire n3002_o;
  wire n3004_o;
  wire n3005_o;
  wire n3007_o;
  wire n3008_o;
  wire n3010_o;
  wire n3011_o;
  wire n3013_o;
  wire n3014_o;
  wire n3016_o;
  wire n3017_o;
  wire n3019_o;
  wire n3020_o;
  wire [30:0] n3021_o;
  wire n3023_o;
  wire n3026_o;
  wire [1:0] n3027_o;
  reg n3030_o;
  reg [2:0] n3032_o;
  reg [2:0] n3034_o;
  reg n3037_o;
  reg [2:0] n3040_o;
  wire n3042_o;
  wire n3044_o;
  wire n3045_o;
  wire n3047_o;
  wire n3048_o;
  wire n3050_o;
  wire n3051_o;
  wire n3053_o;
  wire n3054_o;
  wire n3056_o;
  wire n3057_o;
  wire n3059_o;
  wire n3060_o;
  wire n3062_o;
  wire n3063_o;
  wire n3065_o;
  wire n3069_o;
  wire n3072_o;
  wire [2:0] n3074_o;
  wire [2:0] n3076_o;
  wire n3079_o;
  wire n3081_o;
  wire n3083_o;
  wire n3084_o;
  wire n3086_o;
  wire n3087_o;
  wire n3089_o;
  wire n3090_o;
  wire n3092_o;
  wire n3093_o;
  wire n3095_o;
  wire n3096_o;
  wire n3098_o;
  wire n3099_o;
  wire n3101_o;
  wire n3102_o;
  wire n3104_o;
  wire n3106_o;
  wire n3107_o;
  wire n3109_o;
  wire n3110_o;
  wire n3112_o;
  wire n3113_o;
  wire n3115_o;
  wire n3116_o;
  wire n3118_o;
  wire n3119_o;
  wire n3121_o;
  wire n3122_o;
  wire [30:0] n3123_o;
  wire n3125_o;
  wire n3127_o;
  wire n3129_o;
  wire [2:0] n3130_o;
  reg [2:0] n3132_o;
  reg n3135_o;
  reg [2:0] n3137_o;
  reg [3:0] n3140_o;
  reg [3:0] n3142_o;
  reg n3145_o;
  reg n3148_o;
  reg [2:0] n3152_o;
  reg n3155_o;
  wire n3157_o;
  wire n3159_o;
  wire n3161_o;
  wire n3162_o;
  wire n3164_o;
  wire n3165_o;
  wire n3167_o;
  wire n3168_o;
  wire n3170_o;
  wire n3171_o;
  wire n3173_o;
  wire n3174_o;
  wire n3176_o;
  wire n3177_o;
  wire [30:0] n3178_o;
  wire n3180_o;
  wire n3182_o;
  wire n3184_o;
  wire [2:0] n3185_o;
  reg [2:0] n3187_o;
  reg n3190_o;
  reg [2:0] n3192_o;
  reg [3:0] n3195_o;
  reg [3:0] n3197_o;
  reg n3200_o;
  reg n3203_o;
  reg [2:0] n3207_o;
  reg n3210_o;
  wire n3212_o;
  wire n3215_o;
  wire n3217_o;
  wire n3219_o;
  wire n3221_o;
  wire [30:0] n3222_o;
  wire n3224_o;
  wire n3226_o;
  wire n3228_o;
  wire [2:0] n3229_o;
  reg [2:0] n3231_o;
  reg [3:0] n3235_o;
  reg [3:0] n3239_o;
  reg [2:0] n3243_o;
  reg n3247_o;
  wire [30:0] n3248_o;
  wire n3250_o;
  wire n3252_o;
  wire n3254_o;
  wire n3256_o;
  wire n3258_o;
  wire [4:0] n3259_o;
  reg [2:0] n3261_o;
  reg n3264_o;
  reg [3:0] n3268_o;
  reg [3:0] n3272_o;
  reg [2:0] n3276_o;
  reg n3279_o;
  reg n3283_o;
  reg n3287_o;
  wire [2:0] n3290_o;
  wire [2:0] n3291_o;
  wire n3293_o;
  wire [3:0] n3295_o;
  wire [3:0] n3297_o;
  wire [2:0] n3299_o;
  wire n3301_o;
  wire n3303_o;
  wire n3305_o;
  wire [2:0] n3307_o;
  wire [2:0] n3308_o;
  wire n3310_o;
  wire [3:0] n3311_o;
  wire [3:0] n3312_o;
  wire [2:0] n3313_o;
  wire n3315_o;
  wire n3317_o;
  wire n3318_o;
  wire n3320_o;
  wire n3322_o;
  wire n3324_o;
  wire n3326_o;
  wire [30:0] n3327_o;
  wire [1:0] n3329_o;
  wire [30:0] n3330_o;
  wire [1:0] n3331_o;
  wire n3334_o;
  wire n3336_o;
  wire n3337_o;
  wire n3339_o;
  wire n3340_o;
  reg n3342_o;
  reg [1:0] n3344_o;
  reg n3347_o;
  wire n3349_o;
  wire [1:0] n3351_o;
  wire [30:0] n3352_o;
  wire [1:0] n3353_o;
  wire n3355_o;
  wire n3357_o;
  wire n3358_o;
  wire n3360_o;
  wire n3361_o;
  reg n3364_o;
  reg [1:0] n3366_o;
  reg n3369_o;
  wire n3371_o;
  wire [1:0] n3372_o;
  reg [2:0] n3374_o;
  reg n3378_o;
  reg [2:0] n3380_o;
  reg n3382_o;
  reg [1:0] n3384_o;
  reg n3386_o;
  reg [3:0] n3389_o;
  reg n3393_o;
  reg n3397_o;
  reg [1:0] n3400_o;
  reg n3404_o;
  wire n3406_o;
  wire n3408_o;
  wire n3409_o;
  wire n3411_o;
  wire n3412_o;
  wire n3414_o;
  wire n3415_o;
  wire n3418_o;
  wire n3420_o;
  wire n3421_o;
  wire n3423_o;
  wire n3424_o;
  wire n3426_o;
  wire n3427_o;
  wire n3430_o;
  wire n3432_o;
  wire n3433_o;
  wire n3435_o;
  wire n3436_o;
  wire n3438_o;
  wire n3439_o;
  wire n3442_o;
  wire n3444_o;
  wire n3445_o;
  wire n3447_o;
  wire n3448_o;
  wire n3450_o;
  wire n3451_o;
  wire [30:0] n3452_o;
  wire n3454_o;
  wire n3456_o;
  wire [1:0] n3457_o;
  reg n3461_o;
  reg n3464_o;
  reg n3467_o;
  reg n3470_o;
  wire n3472_o;
  wire [30:0] n3474_o;
  wire n3476_o;
  wire [2:0] n3478_o;
  wire n3483_o;
  wire n3484_o;
  wire n3486_o;
  wire n3487_o;
  wire n3489_o;
  wire n3490_o;
  wire n3491_o;
  wire n3493_o;
  wire n3494_o;
  wire n3496_o;
  wire n3497_o;
  wire n3498_o;
  wire n3500_o;
  wire n3501_o;
  wire n3503_o;
  wire n3504_o;
  wire n3505_o;
  wire n3507_o;
  wire n3508_o;
  wire n3510_o;
  wire [7:0] n3511_o;
  reg n3513_o;
  wire n3516_o;
  wire n3518_o;
  wire [1:0] n3519_o;
  reg n3523_o;
  reg n3525_o;
  reg n3528_o;
  reg n3531_o;
  wire n3533_o;
  wire n3535_o;
  wire n3536_o;
  wire n3538_o;
  wire n3539_o;
  wire n3541_o;
  wire n3542_o;
  wire n3544_o;
  wire n3545_o;
  wire n3547_o;
  wire n3548_o;
  wire n3550_o;
  wire n3551_o;
  wire n3553_o;
  wire n3554_o;
  wire n3556_o;
  wire n3558_o;
  wire n3560_o;
  wire n3562_o;
  wire n3564_o;
  wire n3566_o;
  wire n3568_o;
  wire [30:0] n3569_o;
  wire n3571_o;
  wire n3573_o;
  wire n3575_o;
  wire n3577_o;
  wire [3:0] n3578_o;
  reg [2:0] n3580_o;
  reg n3584_o;
  reg [3:0] n3588_o;
  reg [3:0] n3592_o;
  reg [2:0] n3596_o;
  reg n3599_o;
  reg n3602_o;
  reg n3605_o;
  reg n3609_o;
  wire n3611_o;
  wire [30:0] n3614_o;
  wire n3616_o;
  wire [2:0] n3618_o;
  wire n3623_o;
  wire n3624_o;
  wire n3626_o;
  wire n3627_o;
  wire n3629_o;
  wire n3630_o;
  wire n3631_o;
  wire n3633_o;
  wire n3634_o;
  wire n3636_o;
  wire n3637_o;
  wire n3638_o;
  wire n3640_o;
  wire n3641_o;
  wire n3643_o;
  wire n3644_o;
  wire n3645_o;
  wire n3647_o;
  wire n3648_o;
  wire n3650_o;
  wire [7:0] n3651_o;
  reg n3653_o;
  wire [2:0] n3656_o;
  wire [2:0] n3658_o;
  wire [3:0] n3661_o;
  wire [3:0] n3664_o;
  wire [2:0] n3667_o;
  wire n3669_o;
  wire n3671_o;
  wire n3673_o;
  wire [3:0] n3674_o;
  reg [2:0] n3676_o;
  reg [2:0] n3678_o;
  reg n3682_o;
  reg [3:0] n3685_o;
  reg [3:0] n3688_o;
  reg [2:0] n3691_o;
  reg n3694_o;
  reg n3697_o;
  reg n3700_o;
  reg n3704_o;
  wire n3706_o;
  wire n3708_o;
  wire n3709_o;
  wire n3711_o;
  wire n3712_o;
  wire n3714_o;
  wire n3715_o;
  wire n3717_o;
  wire n3718_o;
  wire n3720_o;
  wire n3721_o;
  wire n3723_o;
  wire n3724_o;
  wire n3726_o;
  wire n3727_o;
  wire [30:0] n3728_o;
  wire n3730_o;
  wire n3732_o;
  wire n3734_o;
  wire [2:0] n3735_o;
  reg [3:0] n3739_o;
  reg [2:0] n3743_o;
  reg n3746_o;
  reg n3749_o;
  wire n3751_o;
  wire [30:0] n3753_o;
  wire [2:0] n3755_o;
  wire n3760_o;
  wire n3761_o;
  wire n3763_o;
  wire n3764_o;
  wire n3766_o;
  wire n3767_o;
  wire n3768_o;
  wire n3770_o;
  wire n3771_o;
  wire n3773_o;
  wire n3774_o;
  wire n3775_o;
  wire n3777_o;
  wire n3778_o;
  wire n3780_o;
  wire n3781_o;
  wire n3782_o;
  wire n3784_o;
  wire n3785_o;
  wire n3787_o;
  wire [7:0] n3788_o;
  reg n3790_o;
  wire [2:0] n3793_o;
  wire [2:0] n3796_o;
  wire n3798_o;
  wire n3800_o;
  wire n3802_o;
  wire [2:0] n3803_o;
  reg [2:0] n3805_o;
  reg [2:0] n3808_o;
  reg [3:0] n3812_o;
  reg [2:0] n3815_o;
  reg n3818_o;
  reg n3821_o;
  wire n3823_o;
  wire n3825_o;
  wire n3826_o;
  wire n3828_o;
  wire n3829_o;
  wire n3831_o;
  wire n3832_o;
  wire n3834_o;
  wire n3835_o;
  wire n3837_o;
  wire n3838_o;
  wire n3840_o;
  wire n3841_o;
  wire n3843_o;
  wire n3844_o;
  wire [30:0] n3845_o;
  wire n3847_o;
  wire n3849_o;
  wire n3851_o;
  wire [2:0] n3852_o;
  reg [2:0] n3854_o;
  reg [3:0] n3858_o;
  reg [3:0] n3862_o;
  reg [2:0] n3866_o;
  reg n3869_o;
  reg n3873_o;
  wire n3875_o;
  wire n3877_o;
  wire n3878_o;
  wire n3880_o;
  wire n3881_o;
  wire n3883_o;
  wire n3884_o;
  wire n3886_o;
  wire n3887_o;
  wire n3889_o;
  wire n3890_o;
  wire n3892_o;
  wire n3893_o;
  wire n3895_o;
  wire n3896_o;
  wire [30:0] n3897_o;
  wire n3899_o;
  wire n3901_o;
  wire [1:0] n3902_o;
  reg n3905_o;
  reg n3908_o;
  reg [2:0] n3911_o;
  reg n3914_o;
  wire n3916_o;
  wire [30:0] n3917_o;
  wire n3919_o;
  wire n3921_o;
  wire [1:0] n3922_o;
  reg n3925_o;
  reg [3:0] n3928_o;
  reg [2:0] n3931_o;
  reg n3934_o;
  reg n3937_o;
  wire n3939_o;
  wire n3941_o;
  wire n3943_o;
  wire n3945_o;
  wire n3947_o;
  wire n3948_o;
  wire [58:0] n3949_o;
  reg [2:0] n3980_o;
  reg [2:0] n3985_o;
  reg n3988_o;
  reg n3991_o;
  wire [1:0] n3992_o;
  wire [1:0] n3993_o;
  wire [1:0] n3994_o;
  wire [1:0] n3995_o;
  wire [1:0] n3996_o;
  wire [1:0] n3997_o;
  wire [1:0] n3998_o;
  wire [1:0] n3999_o;
  wire [1:0] n4000_o;
  reg [1:0] n4003_o;
  wire [1:0] n4004_o;
  wire [1:0] n4005_o;
  wire [1:0] n4006_o;
  wire [1:0] n4007_o;
  wire [1:0] n4008_o;
  wire [1:0] n4009_o;
  wire [1:0] n4010_o;
  wire [1:0] n4011_o;
  wire [1:0] n4012_o;
  reg [1:0] n4015_o;
  reg n4024_o;
  reg n4027_o;
  wire [2:0] n4028_o;
  reg [2:0] n4031_o;
  wire n4032_o;
  reg n4035_o;
  wire n4036_o;
  wire n4037_o;
  wire n4038_o;
  wire n4039_o;
  wire n4040_o;
  wire n4041_o;
  wire n4042_o;
  wire n4043_o;
  wire n4044_o;
  wire n4045_o;
  wire n4046_o;
  wire n4047_o;
  wire n4049_o;
  wire n4051_o;
  wire n4052_o;
  wire n4053_o;
  wire n4054_o;
  wire n4055_o;
  wire n4056_o;
  reg n4059_o;
  wire [1:0] n4060_o;
  wire [1:0] n4061_o;
  wire [1:0] n4062_o;
  wire [1:0] n4063_o;
  wire [1:0] n4064_o;
  wire [1:0] n4065_o;
  wire [1:0] n4066_o;
  wire [1:0] n4067_o;
  wire [1:0] n4068_o;
  wire [1:0] n4069_o;
  wire [1:0] n4070_o;
  wire [1:0] n4071_o;
  wire [1:0] n4073_o;
  wire [1:0] n4075_o;
  wire [1:0] n4076_o;
  wire [1:0] n4077_o;
  wire [1:0] n4078_o;
  wire [1:0] n4079_o;
  wire [1:0] n4080_o;
  reg [1:0] n4083_o;
  wire n4084_o;
  wire n4085_o;
  wire n4086_o;
  wire n4087_o;
  wire n4088_o;
  wire n4089_o;
  wire n4091_o;
  wire n4093_o;
  wire n4094_o;
  wire n4095_o;
  wire n4096_o;
  wire n4097_o;
  wire n4098_o;
  reg n4101_o;
  reg [3:0] n4107_o;
  reg n4115_o;
  reg n4120_o;
  reg n4123_o;
  reg [2:0] n4126_o;
  reg n4129_o;
  reg n4132_o;
  reg n4136_o;
  reg n4139_o;
  reg n4142_o;
  reg n4145_o;
  reg n4148_o;
  reg n4152_o;
  reg n4156_o;
  reg n4160_o;
  reg n4164_o;
  reg n4168_o;
  reg n4172_o;
  reg [1:0] n4175_o;
  reg n4179_o;
  reg n4183_o;
  reg n4187_o;
  reg n4190_o;
  reg n4193_o;
  wire n4195_o;
  wire [2:0] n4196_o;
  wire [2:0] n4197_o;
  wire n4199_o;
  wire n4201_o;
  wire n4204_o;
  wire [3:0] n4206_o;
  wire n4209_o;
  wire [30:0] n4210_o;
  wire n4212_o;
  wire n4214_o;
  wire n4215_o;
  wire n4217_o;
  wire n4219_o;
  wire [2:0] n4220_o;
  reg [2:0] n4222_o;
  reg n4225_o;
  reg [3:0] n4227_o;
  reg n4230_o;
  reg [2:0] n4234_o;
  reg n4237_o;
  wire [2:0] n4240_o;
  wire [2:0] n4241_o;
  wire n4242_o;
  wire [3:0] n4243_o;
  wire n4244_o;
  wire [2:0] n4246_o;
  wire n4248_o;
  wire n4251_o;
  wire n4253_o;
  wire n4255_o;
  wire n4256_o;
  wire n4258_o;
  wire n4259_o;
  wire n4261_o;
  wire n4262_o;
  wire n4264_o;
  wire n4265_o;
  wire n4267_o;
  wire n4268_o;
  wire n4270_o;
  wire n4271_o;
  wire n4273_o;
  wire n4274_o;
  wire n4276_o;
  wire n4277_o;
  wire n4279_o;
  wire n4280_o;
  wire n4282_o;
  wire n4283_o;
  wire n4285_o;
  wire n4286_o;
  wire n4288_o;
  wire n4289_o;
  wire n4291_o;
  wire n4292_o;
  wire n4294_o;
  wire n4295_o;
  wire n4297_o;
  wire n4298_o;
  wire n4300_o;
  wire n4301_o;
  wire n4303_o;
  wire n4304_o;
  wire n4306_o;
  wire n4307_o;
  wire n4309_o;
  wire n4310_o;
  wire n4312_o;
  wire n4313_o;
  wire n4315_o;
  wire n4316_o;
  wire n4318_o;
  wire n4319_o;
  wire n4321_o;
  wire n4322_o;
  wire n4324_o;
  wire n4325_o;
  wire n4327_o;
  wire n4328_o;
  wire n4330_o;
  wire n4331_o;
  wire n4333_o;
  wire n4334_o;
  wire n4336_o;
  wire n4337_o;
  wire n4339_o;
  wire n4340_o;
  wire n4342_o;
  wire n4343_o;
  wire n4345_o;
  wire n4346_o;
  wire n4348_o;
  wire n4349_o;
  wire n4351_o;
  wire n4352_o;
  wire n4354_o;
  wire n4355_o;
  wire n4357_o;
  wire n4358_o;
  wire n4360_o;
  wire n4361_o;
  wire n4363_o;
  wire n4364_o;
  wire n4366_o;
  wire n4367_o;
  wire n4369_o;
  wire n4370_o;
  wire n4372_o;
  wire n4373_o;
  wire n4375_o;
  wire n4376_o;
  wire n4378_o;
  wire n4379_o;
  wire n4381_o;
  wire n4382_o;
  wire n4384_o;
  wire n4385_o;
  wire n4387_o;
  wire n4388_o;
  wire n4390_o;
  wire n4391_o;
  wire n4393_o;
  wire n4394_o;
  wire n4396_o;
  wire n4397_o;
  wire n4399_o;
  wire n4400_o;
  wire n4402_o;
  wire n4403_o;
  wire n4405_o;
  wire n4406_o;
  wire n4408_o;
  wire n4409_o;
  wire n4411_o;
  wire n4412_o;
  wire n4414_o;
  wire n4415_o;
  wire n4417_o;
  wire n4418_o;
  wire [30:0] n4419_o;
  wire n4421_o;
  wire n4423_o;
  wire n4424_o;
  wire n4426_o;
  wire n4428_o;
  wire [2:0] n4429_o;
  reg [2:0] n4431_o;
  reg n4434_o;
  reg [3:0] n4436_o;
  reg n4439_o;
  reg [2:0] n4443_o;
  reg n4446_o;
  wire n4448_o;
  wire n4450_o;
  wire n4451_o;
  wire n4453_o;
  wire n4454_o;
  wire n4456_o;
  wire n4457_o;
  wire n4459_o;
  wire n4460_o;
  wire n4462_o;
  wire n4463_o;
  wire n4465_o;
  wire n4466_o;
  wire n4468_o;
  wire n4469_o;
  wire n4471_o;
  wire n4473_o;
  wire [2:0] n4474_o;
  wire [2:0] n4475_o;
  wire [3:0] n4477_o;
  wire [30:0] n4478_o;
  wire n4480_o;
  wire n4482_o;
  wire n4483_o;
  wire n4485_o;
  wire [1:0] n4486_o;
  reg [2:0] n4488_o;
  reg [3:0] n4490_o;
  reg [2:0] n4493_o;
  wire [2:0] n4496_o;
  wire [2:0] n4497_o;
  wire n4498_o;
  wire [3:0] n4499_o;
  wire [2:0] n4501_o;
  wire n4504_o;
  wire n4506_o;
  wire n4508_o;
  wire n4509_o;
  wire n4511_o;
  wire n4512_o;
  wire n4514_o;
  wire n4515_o;
  wire n4517_o;
  wire n4518_o;
  wire n4520_o;
  wire n4521_o;
  wire n4523_o;
  wire n4524_o;
  wire n4526_o;
  wire n4527_o;
  wire n4529_o;
  wire n4530_o;
  wire n4532_o;
  wire n4533_o;
  wire n4535_o;
  wire n4536_o;
  wire n4538_o;
  wire n4539_o;
  wire n4541_o;
  wire n4542_o;
  wire n4544_o;
  wire n4545_o;
  wire n4547_o;
  wire n4548_o;
  wire n4550_o;
  wire n4551_o;
  wire n4553_o;
  wire n4554_o;
  wire n4556_o;
  wire n4557_o;
  wire n4559_o;
  wire n4560_o;
  wire n4562_o;
  wire n4563_o;
  wire n4565_o;
  wire n4566_o;
  wire n4568_o;
  wire n4569_o;
  wire n4571_o;
  wire n4572_o;
  wire n4574_o;
  wire n4575_o;
  wire n4577_o;
  wire n4578_o;
  wire n4580_o;
  wire n4581_o;
  wire n4583_o;
  wire n4584_o;
  wire n4586_o;
  wire n4587_o;
  wire n4589_o;
  wire n4590_o;
  wire n4592_o;
  wire n4593_o;
  wire n4595_o;
  wire n4596_o;
  wire n4598_o;
  wire n4599_o;
  wire n4601_o;
  wire n4602_o;
  wire n4604_o;
  wire n4605_o;
  wire n4607_o;
  wire n4608_o;
  wire n4610_o;
  wire n4611_o;
  wire n4613_o;
  wire n4614_o;
  wire n4616_o;
  wire n4617_o;
  wire n4619_o;
  wire n4620_o;
  wire n4622_o;
  wire n4623_o;
  wire n4625_o;
  wire n4626_o;
  wire n4628_o;
  wire n4629_o;
  wire n4631_o;
  wire n4632_o;
  wire n4634_o;
  wire n4635_o;
  wire n4637_o;
  wire n4638_o;
  wire n4640_o;
  wire n4641_o;
  wire n4643_o;
  wire n4644_o;
  wire n4646_o;
  wire n4647_o;
  wire n4649_o;
  wire n4650_o;
  wire n4652_o;
  wire n4653_o;
  wire n4655_o;
  wire n4656_o;
  wire n4658_o;
  wire n4659_o;
  wire n4661_o;
  wire n4662_o;
  wire n4664_o;
  wire n4665_o;
  wire n4667_o;
  wire n4668_o;
  wire n4670_o;
  wire n4671_o;
  wire [30:0] n4672_o;
  wire n4674_o;
  wire n4676_o;
  wire n4677_o;
  wire n4679_o;
  wire [1:0] n4680_o;
  reg [2:0] n4682_o;
  reg [3:0] n4684_o;
  reg [2:0] n4687_o;
  wire n4689_o;
  wire n4691_o;
  wire n4692_o;
  wire n4694_o;
  wire n4695_o;
  wire n4697_o;
  wire n4698_o;
  wire n4700_o;
  wire n4701_o;
  wire n4703_o;
  wire n4704_o;
  wire n4706_o;
  wire n4707_o;
  wire n4709_o;
  wire n4710_o;
  wire n4712_o;
  wire n4714_o;
  wire n4717_o;
  wire [3:0] n4719_o;
  wire n4722_o;
  wire [30:0] n4723_o;
  wire n4725_o;
  wire n4727_o;
  wire n4728_o;
  wire n4730_o;
  wire n4732_o;
  wire [2:0] n4733_o;
  reg [2:0] n4735_o;
  reg n4738_o;
  reg [3:0] n4740_o;
  reg n4743_o;
  reg [2:0] n4747_o;
  reg n4750_o;
  wire [2:0] n4753_o;
  wire [2:0] n4754_o;
  wire n4755_o;
  wire [3:0] n4756_o;
  wire n4757_o;
  wire [2:0] n4759_o;
  wire n4761_o;
  wire n4764_o;
  wire n4766_o;
  wire n4768_o;
  wire n4769_o;
  wire n4771_o;
  wire n4772_o;
  wire n4774_o;
  wire n4775_o;
  wire n4777_o;
  wire n4778_o;
  wire n4780_o;
  wire n4781_o;
  wire n4783_o;
  wire n4784_o;
  wire n4786_o;
  wire n4787_o;
  wire n4789_o;
  wire n4790_o;
  wire n4792_o;
  wire n4793_o;
  wire n4795_o;
  wire n4796_o;
  wire n4798_o;
  wire n4799_o;
  wire n4801_o;
  wire n4802_o;
  wire n4804_o;
  wire n4805_o;
  wire n4807_o;
  wire n4808_o;
  wire n4810_o;
  wire n4811_o;
  wire n4813_o;
  wire n4814_o;
  wire n4816_o;
  wire n4817_o;
  wire n4819_o;
  wire n4820_o;
  wire n4822_o;
  wire n4823_o;
  wire n4825_o;
  wire n4826_o;
  wire n4828_o;
  wire n4829_o;
  wire n4831_o;
  wire n4832_o;
  wire n4834_o;
  wire n4835_o;
  wire n4837_o;
  wire n4838_o;
  wire n4840_o;
  wire n4841_o;
  wire n4843_o;
  wire n4844_o;
  wire n4846_o;
  wire n4847_o;
  wire n4849_o;
  wire n4850_o;
  wire n4852_o;
  wire n4853_o;
  wire n4855_o;
  wire n4856_o;
  wire n4858_o;
  wire n4859_o;
  wire n4861_o;
  wire n4862_o;
  wire n4864_o;
  wire n4865_o;
  wire n4867_o;
  wire n4868_o;
  wire n4870_o;
  wire n4871_o;
  wire n4873_o;
  wire n4874_o;
  wire n4876_o;
  wire n4877_o;
  wire n4879_o;
  wire n4880_o;
  wire n4882_o;
  wire n4883_o;
  wire n4885_o;
  wire n4886_o;
  wire n4888_o;
  wire n4889_o;
  wire n4891_o;
  wire n4892_o;
  wire n4894_o;
  wire n4895_o;
  wire n4897_o;
  wire n4898_o;
  wire n4900_o;
  wire n4901_o;
  wire n4903_o;
  wire n4904_o;
  wire n4906_o;
  wire n4907_o;
  wire n4909_o;
  wire n4910_o;
  wire n4912_o;
  wire n4913_o;
  wire n4915_o;
  wire n4916_o;
  wire n4918_o;
  wire n4919_o;
  wire n4921_o;
  wire n4922_o;
  wire n4924_o;
  wire n4925_o;
  wire n4927_o;
  wire n4928_o;
  wire n4930_o;
  wire n4931_o;
  wire [30:0] n4932_o;
  wire n4934_o;
  wire n4936_o;
  wire n4937_o;
  wire n4939_o;
  wire n4941_o;
  wire [2:0] n4942_o;
  reg [2:0] n4944_o;
  reg n4947_o;
  reg [3:0] n4949_o;
  reg n4952_o;
  reg [2:0] n4956_o;
  reg n4959_o;
  wire n4961_o;
  wire n4963_o;
  wire n4964_o;
  wire n4966_o;
  wire n4967_o;
  wire n4969_o;
  wire n4970_o;
  wire n4972_o;
  wire n4973_o;
  wire n4975_o;
  wire n4976_o;
  wire n4978_o;
  wire n4979_o;
  wire n4981_o;
  wire n4982_o;
  wire n4984_o;
  wire n4986_o;
  wire n4989_o;
  wire [3:0] n4991_o;
  wire n4994_o;
  wire [30:0] n4995_o;
  wire n4997_o;
  wire n4999_o;
  wire n5000_o;
  wire n5002_o;
  wire n5004_o;
  wire [2:0] n5005_o;
  reg [2:0] n5007_o;
  reg n5010_o;
  reg [3:0] n5012_o;
  reg n5015_o;
  reg [2:0] n5019_o;
  reg n5022_o;
  wire [2:0] n5025_o;
  wire [2:0] n5026_o;
  wire n5027_o;
  wire [3:0] n5028_o;
  wire n5029_o;
  wire [2:0] n5031_o;
  wire n5033_o;
  wire n5036_o;
  wire n5038_o;
  wire n5040_o;
  wire n5041_o;
  wire n5043_o;
  wire n5044_o;
  wire n5046_o;
  wire n5047_o;
  wire n5049_o;
  wire n5050_o;
  wire n5052_o;
  wire n5053_o;
  wire n5055_o;
  wire n5056_o;
  wire n5058_o;
  wire n5059_o;
  wire n5061_o;
  wire n5062_o;
  wire n5064_o;
  wire n5065_o;
  wire n5067_o;
  wire n5068_o;
  wire n5070_o;
  wire n5071_o;
  wire n5073_o;
  wire n5074_o;
  wire n5076_o;
  wire n5077_o;
  wire n5079_o;
  wire n5080_o;
  wire n5082_o;
  wire n5083_o;
  wire n5085_o;
  wire n5086_o;
  wire n5088_o;
  wire n5089_o;
  wire n5091_o;
  wire n5092_o;
  wire n5094_o;
  wire n5095_o;
  wire n5097_o;
  wire n5098_o;
  wire n5100_o;
  wire n5101_o;
  wire n5103_o;
  wire n5104_o;
  wire n5106_o;
  wire n5107_o;
  wire n5109_o;
  wire n5110_o;
  wire n5112_o;
  wire n5113_o;
  wire n5115_o;
  wire n5116_o;
  wire n5118_o;
  wire n5119_o;
  wire n5121_o;
  wire n5122_o;
  wire n5124_o;
  wire n5125_o;
  wire n5127_o;
  wire n5128_o;
  wire n5130_o;
  wire n5131_o;
  wire n5133_o;
  wire n5134_o;
  wire n5136_o;
  wire n5137_o;
  wire n5139_o;
  wire n5140_o;
  wire n5142_o;
  wire n5143_o;
  wire n5145_o;
  wire n5146_o;
  wire n5148_o;
  wire n5149_o;
  wire n5151_o;
  wire n5152_o;
  wire n5154_o;
  wire n5155_o;
  wire n5157_o;
  wire n5158_o;
  wire n5160_o;
  wire n5161_o;
  wire n5163_o;
  wire n5164_o;
  wire n5166_o;
  wire n5167_o;
  wire n5169_o;
  wire n5170_o;
  wire n5172_o;
  wire n5173_o;
  wire n5175_o;
  wire n5176_o;
  wire n5178_o;
  wire n5179_o;
  wire n5181_o;
  wire n5182_o;
  wire n5184_o;
  wire n5185_o;
  wire n5187_o;
  wire n5188_o;
  wire n5190_o;
  wire n5191_o;
  wire n5193_o;
  wire n5194_o;
  wire n5196_o;
  wire n5197_o;
  wire n5199_o;
  wire n5200_o;
  wire n5202_o;
  wire n5203_o;
  wire [30:0] n5204_o;
  wire n5206_o;
  wire n5208_o;
  wire n5209_o;
  wire n5211_o;
  wire n5213_o;
  wire [2:0] n5214_o;
  reg [2:0] n5216_o;
  reg n5219_o;
  reg [3:0] n5221_o;
  reg n5224_o;
  reg [2:0] n5228_o;
  reg n5231_o;
  wire n5233_o;
  wire n5235_o;
  wire n5236_o;
  wire n5238_o;
  wire n5239_o;
  wire n5241_o;
  wire n5242_o;
  wire n5244_o;
  wire n5245_o;
  wire n5247_o;
  wire n5248_o;
  wire n5250_o;
  wire n5251_o;
  wire n5253_o;
  wire n5254_o;
  wire [7:0] n5255_o;
  reg [2:0] n5261_o;
  reg [2:0] n5263_o;
  reg n5266_o;
  reg [2:0] n5268_o;
  reg [3:0] n5270_o;
  reg n5273_o;
  reg [2:0] n5275_o;
  reg n5278_o;
  reg n5281_o;
  wire n5283_o;
  wire n5285_o;
  wire n5287_o;
  wire n5288_o;
  wire n5290_o;
  wire n5291_o;
  wire n5293_o;
  wire n5294_o;
  wire n5296_o;
  wire n5297_o;
  wire n5299_o;
  wire n5300_o;
  wire n5302_o;
  wire n5303_o;
  wire n5305_o;
  wire n5306_o;
  wire n5308_o;
  wire n5309_o;
  wire n5311_o;
  wire n5312_o;
  wire n5314_o;
  wire n5315_o;
  wire n5317_o;
  wire n5318_o;
  wire n5320_o;
  wire n5321_o;
  wire n5323_o;
  wire n5324_o;
  wire n5326_o;
  wire n5327_o;
  wire n5329_o;
  wire n5330_o;
  wire n5332_o;
  wire n5333_o;
  wire n5335_o;
  wire n5336_o;
  wire n5338_o;
  wire n5339_o;
  wire n5341_o;
  wire n5342_o;
  wire n5344_o;
  wire n5345_o;
  wire n5347_o;
  wire n5348_o;
  wire n5350_o;
  wire n5351_o;
  wire n5353_o;
  wire n5354_o;
  wire n5356_o;
  wire n5357_o;
  wire n5359_o;
  wire n5360_o;
  wire n5362_o;
  wire n5363_o;
  wire n5365_o;
  wire n5366_o;
  wire n5368_o;
  wire n5369_o;
  wire n5371_o;
  wire n5372_o;
  wire n5374_o;
  wire n5375_o;
  wire n5377_o;
  wire n5378_o;
  wire n5380_o;
  wire n5381_o;
  wire n5383_o;
  wire n5384_o;
  wire n5386_o;
  wire n5387_o;
  wire n5389_o;
  wire n5390_o;
  wire n5392_o;
  wire n5393_o;
  wire n5395_o;
  wire n5396_o;
  wire n5398_o;
  wire n5399_o;
  wire n5401_o;
  wire n5402_o;
  wire n5404_o;
  wire n5405_o;
  wire n5407_o;
  wire n5408_o;
  wire n5410_o;
  wire n5411_o;
  wire n5413_o;
  wire n5414_o;
  wire n5416_o;
  wire n5417_o;
  wire n5419_o;
  wire n5420_o;
  wire n5422_o;
  wire n5423_o;
  wire n5425_o;
  wire n5426_o;
  wire n5428_o;
  wire n5429_o;
  wire n5431_o;
  wire n5432_o;
  wire n5434_o;
  wire n5435_o;
  wire n5437_o;
  wire n5438_o;
  wire n5440_o;
  wire n5441_o;
  wire n5443_o;
  wire n5444_o;
  wire n5446_o;
  wire n5447_o;
  wire n5449_o;
  wire n5450_o;
  wire n5452_o;
  wire n5453_o;
  wire n5455_o;
  wire n5456_o;
  wire n5458_o;
  wire n5459_o;
  wire n5461_o;
  wire n5462_o;
  wire n5464_o;
  wire n5465_o;
  wire n5467_o;
  wire n5468_o;
  wire n5470_o;
  wire n5471_o;
  wire n5473_o;
  wire n5474_o;
  wire n5476_o;
  wire n5477_o;
  wire n5479_o;
  wire n5480_o;
  wire n5482_o;
  wire n5483_o;
  wire n5485_o;
  wire n5486_o;
  wire n5488_o;
  wire n5489_o;
  wire n5491_o;
  wire n5492_o;
  wire n5494_o;
  wire n5495_o;
  wire n5497_o;
  wire n5498_o;
  wire n5500_o;
  wire n5501_o;
  wire n5503_o;
  wire n5504_o;
  wire n5506_o;
  wire n5507_o;
  wire n5509_o;
  wire n5510_o;
  wire n5512_o;
  wire n5513_o;
  wire n5515_o;
  wire n5516_o;
  wire n5518_o;
  wire n5519_o;
  wire n5521_o;
  wire n5522_o;
  wire n5524_o;
  wire n5525_o;
  wire n5527_o;
  wire n5528_o;
  wire n5530_o;
  wire n5531_o;
  wire n5533_o;
  wire n5534_o;
  wire n5536_o;
  wire n5537_o;
  wire n5539_o;
  wire n5540_o;
  wire n5542_o;
  wire n5543_o;
  wire n5545_o;
  wire n5546_o;
  wire n5548_o;
  wire n5549_o;
  wire n5551_o;
  wire n5552_o;
  wire n5554_o;
  wire n5555_o;
  wire n5557_o;
  wire n5558_o;
  wire n5560_o;
  wire n5561_o;
  wire n5563_o;
  wire n5564_o;
  wire n5566_o;
  wire n5567_o;
  wire n5569_o;
  wire n5570_o;
  wire n5572_o;
  wire n5573_o;
  wire n5575_o;
  wire n5576_o;
  wire n5578_o;
  wire n5579_o;
  wire n5581_o;
  wire n5582_o;
  wire n5584_o;
  wire n5585_o;
  wire n5587_o;
  wire n5588_o;
  wire n5590_o;
  wire n5591_o;
  wire n5593_o;
  wire n5594_o;
  wire n5596_o;
  wire n5597_o;
  wire n5599_o;
  wire n5600_o;
  wire n5602_o;
  wire n5603_o;
  wire n5605_o;
  wire n5606_o;
  wire n5608_o;
  wire n5609_o;
  wire n5611_o;
  wire n5612_o;
  wire n5614_o;
  wire n5615_o;
  wire n5617_o;
  wire n5618_o;
  wire n5620_o;
  wire n5621_o;
  wire n5623_o;
  wire n5624_o;
  wire n5626_o;
  wire n5627_o;
  wire n5629_o;
  wire n5630_o;
  wire n5632_o;
  wire n5633_o;
  wire n5635_o;
  wire n5636_o;
  wire n5638_o;
  wire n5639_o;
  wire n5641_o;
  wire n5642_o;
  wire n5644_o;
  wire n5645_o;
  wire n5647_o;
  wire n5648_o;
  wire n5650_o;
  wire n5651_o;
  wire n5653_o;
  wire n5654_o;
  wire n5656_o;
  wire n5657_o;
  wire n5659_o;
  wire n5660_o;
  wire n5662_o;
  wire n5663_o;
  wire n5665_o;
  wire n5666_o;
  wire n5668_o;
  wire n5669_o;
  wire n5671_o;
  wire n5672_o;
  wire n5674_o;
  wire n5675_o;
  wire n5677_o;
  wire n5678_o;
  wire n5680_o;
  wire n5681_o;
  wire n5683_o;
  wire n5684_o;
  wire n5686_o;
  wire n5687_o;
  wire n5689_o;
  wire n5690_o;
  wire n5692_o;
  wire n5693_o;
  wire n5695_o;
  wire n5696_o;
  wire n5698_o;
  wire n5699_o;
  wire n5701_o;
  wire n5702_o;
  wire n5704_o;
  wire n5705_o;
  wire n5707_o;
  wire n5708_o;
  wire n5710_o;
  wire n5711_o;
  wire n5713_o;
  wire n5714_o;
  wire n5716_o;
  wire n5717_o;
  wire n5719_o;
  wire n5720_o;
  wire n5722_o;
  wire n5723_o;
  wire n5725_o;
  wire n5726_o;
  wire n5728_o;
  wire n5729_o;
  wire n5731_o;
  wire n5732_o;
  wire n5734_o;
  wire n5735_o;
  wire n5737_o;
  wire n5738_o;
  wire n5740_o;
  wire n5741_o;
  wire n5743_o;
  wire n5744_o;
  wire n5746_o;
  wire n5747_o;
  wire n5749_o;
  wire n5750_o;
  wire n5752_o;
  wire n5753_o;
  wire n5755_o;
  wire n5756_o;
  wire n5758_o;
  wire n5759_o;
  wire n5761_o;
  wire n5762_o;
  wire n5764_o;
  wire n5765_o;
  wire n5767_o;
  wire n5768_o;
  wire n5770_o;
  wire n5771_o;
  wire n5773_o;
  wire n5774_o;
  wire n5776_o;
  wire n5777_o;
  wire n5779_o;
  wire n5780_o;
  wire n5782_o;
  wire n5783_o;
  wire n5785_o;
  wire n5786_o;
  wire n5788_o;
  wire n5789_o;
  wire n5791_o;
  wire n5792_o;
  wire n5794_o;
  wire n5795_o;
  wire n5797_o;
  wire n5798_o;
  wire n5800_o;
  wire n5801_o;
  wire n5803_o;
  wire n5804_o;
  wire n5806_o;
  wire n5807_o;
  wire n5809_o;
  wire n5810_o;
  wire n5812_o;
  wire n5814_o;
  wire n5815_o;
  wire n5817_o;
  wire n5819_o;
  wire n5821_o;
  wire n5823_o;
  wire [30:0] n5824_o;
  wire n5826_o;
  wire n5828_o;
  wire [1:0] n5829_o;
  wire n5831_o;
  wire [1:0] n5832_o;
  wire [2:0] n5834_o;
  wire [2:0] n5836_o;
  wire n5839_o;
  wire n5841_o;
  wire [1:0] n5842_o;
  wire n5844_o;
  wire [1:0] n5845_o;
  wire [2:0] n5847_o;
  wire [2:0] n5849_o;
  wire n5852_o;
  wire n5854_o;
  wire [3:0] n5855_o;
  reg n5859_o;
  reg n5862_o;
  reg n5866_o;
  reg [2:0] n5868_o;
  reg n5870_o;
  reg [2:0] n5874_o;
  reg n5877_o;
  reg n5880_o;
  wire n5882_o;
  wire n5884_o;
  wire n5885_o;
  wire n5887_o;
  wire n5888_o;
  wire n5890_o;
  wire n5891_o;
  wire [30:0] n5892_o;
  wire n5894_o;
  wire [1:0] n5895_o;
  wire n5897_o;
  wire [1:0] n5898_o;
  wire [3:0] n5901_o;
  wire [3:0] n5903_o;
  wire n5905_o;
  wire [1:0] n5906_o;
  wire n5908_o;
  wire [1:0] n5909_o;
  wire [3:0] n5912_o;
  wire [3:0] n5914_o;
  wire n5916_o;
  wire n5918_o;
  wire [3:0] n5919_o;
  reg n5923_o;
  reg n5926_o;
  reg [3:0] n5928_o;
  reg [2:0] n5932_o;
  reg n5935_o;
  reg n5938_o;
  reg n5942_o;
  wire n5944_o;
  wire n5946_o;
  wire n5947_o;
  wire n5949_o;
  wire n5950_o;
  wire n5952_o;
  wire n5953_o;
  wire [30:0] n5954_o;
  wire n5956_o;
  wire n5958_o;
  wire n5959_o;
  wire [3:0] n5962_o;
  wire n5964_o;
  wire n5965_o;
  wire n5966_o;
  wire [3:0] n5969_o;
  wire n5971_o;
  wire n5973_o;
  wire [3:0] n5974_o;
  reg [2:0] n5977_o;
  reg [3:0] n5980_o;
  reg [2:0] n5982_o;
  reg [3:0] n5985_o;
  reg [3:0] n5987_o;
  reg [2:0] n5991_o;
  reg n5994_o;
  reg n5997_o;
  reg n6000_o;
  wire n6002_o;
  wire n6004_o;
  wire n6005_o;
  wire n6007_o;
  wire n6008_o;
  wire n6010_o;
  wire n6011_o;
  wire [30:0] n6012_o;
  wire n6014_o;
  wire n6016_o;
  wire n6017_o;
  wire [3:0] n6020_o;
  wire n6022_o;
  wire n6024_o;
  wire n6026_o;
  wire [3:0] n6027_o;
  reg [2:0] n6030_o;
  reg [3:0] n6033_o;
  reg [2:0] n6035_o;
  reg [3:0] n6038_o;
  reg [3:0] n6040_o;
  reg n6043_o;
  reg n6046_o;
  reg [2:0] n6049_o;
  reg n6052_o;
  reg n6056_o;
  wire n6058_o;
  wire n6060_o;
  wire n6061_o;
  wire n6063_o;
  wire n6064_o;
  wire n6066_o;
  wire n6067_o;
  wire n6069_o;
  wire n6071_o;
  wire n6072_o;
  wire n6074_o;
  wire n6075_o;
  wire n6077_o;
  wire n6078_o;
  wire n6080_o;
  wire n6081_o;
  wire n6083_o;
  wire n6084_o;
  wire n6086_o;
  wire n6087_o;
  wire n6089_o;
  wire n6090_o;
  wire n6092_o;
  wire n6094_o;
  wire n6095_o;
  wire n6097_o;
  wire n6098_o;
  wire n6100_o;
  wire n6101_o;
  wire n6103_o;
  wire n6105_o;
  wire n6106_o;
  wire n6108_o;
  wire n6110_o;
  wire n6111_o;
  wire [30:0] n6112_o;
  wire [1:0] n6114_o;
  wire [30:0] n6115_o;
  wire [1:0] n6116_o;
  wire n6119_o;
  wire n6121_o;
  wire n6122_o;
  wire n6124_o;
  wire n6125_o;
  reg n6127_o;
  reg [1:0] n6129_o;
  reg n6132_o;
  wire n6134_o;
  wire [1:0] n6136_o;
  wire [30:0] n6137_o;
  wire [1:0] n6138_o;
  wire n6141_o;
  wire n6143_o;
  wire n6144_o;
  wire n6146_o;
  wire n6147_o;
  reg n6149_o;
  reg [1:0] n6151_o;
  reg n6154_o;
  wire n6156_o;
  wire [1:0] n6157_o;
  reg [2:0] n6159_o;
  reg n6163_o;
  reg [2:0] n6165_o;
  reg n6167_o;
  reg [1:0] n6169_o;
  reg n6171_o;
  reg [3:0] n6174_o;
  reg n6178_o;
  reg [1:0] n6181_o;
  reg n6185_o;
  wire n6187_o;
  wire n6189_o;
  wire n6190_o;
  wire n6192_o;
  wire n6193_o;
  wire n6195_o;
  wire n6196_o;
  wire [30:0] n6197_o;
  wire [1:0] n6199_o;
  wire [30:0] n6200_o;
  wire [1:0] n6201_o;
  wire n6204_o;
  wire n6206_o;
  wire n6207_o;
  wire n6209_o;
  wire n6210_o;
  reg n6212_o;
  reg [1:0] n6214_o;
  reg n6217_o;
  wire n6219_o;
  wire [1:0] n6221_o;
  wire [30:0] n6222_o;
  wire [1:0] n6223_o;
  wire n6225_o;
  wire n6227_o;
  wire n6228_o;
  wire n6230_o;
  wire n6231_o;
  reg n6234_o;
  reg [1:0] n6236_o;
  reg n6239_o;
  wire n6241_o;
  wire [1:0] n6242_o;
  reg [2:0] n6244_o;
  reg n6248_o;
  reg [2:0] n6250_o;
  reg n6252_o;
  reg [1:0] n6254_o;
  reg n6256_o;
  reg [3:0] n6259_o;
  reg n6263_o;
  reg [1:0] n6266_o;
  reg n6270_o;
  wire n6272_o;
  wire n6274_o;
  wire n6275_o;
  wire n6277_o;
  wire n6278_o;
  wire n6280_o;
  wire n6281_o;
  wire [30:0] n6282_o;
  wire n6284_o;
  wire n6288_o;
  wire n6290_o;
  wire n6292_o;
  wire [3:0] n6293_o;
  reg [2:0] n6295_o;
  reg n6298_o;
  reg [2:0] n6300_o;
  reg [2:0] n6302_o;
  reg [3:0] n6304_o;
  reg n6307_o;
  reg [2:0] n6311_o;
  reg n6314_o;
  reg n6317_o;
  reg n6320_o;
  wire n6322_o;
  wire [30:0] n6323_o;
  wire n6325_o;
  wire n6329_o;
  wire n6331_o;
  wire n6333_o;
  wire [3:0] n6334_o;
  reg [2:0] n6336_o;
  reg n6339_o;
  reg [2:0] n6341_o;
  reg [2:0] n6343_o;
  reg [3:0] n6345_o;
  reg n6348_o;
  reg [2:0] n6352_o;
  reg n6355_o;
  reg n6358_o;
  reg n6361_o;
  wire n6363_o;
  wire [30:0] n6364_o;
  wire n6366_o;
  wire n6368_o;
  wire n6370_o;
  wire [2:0] n6371_o;
  reg [3:0] n6375_o;
  reg [2:0] n6379_o;
  reg n6382_o;
  reg n6385_o;
  reg n6388_o;
  reg n6391_o;
  wire n6393_o;
  wire n6395_o;
  wire n6396_o;
  wire n6398_o;
  wire n6399_o;
  wire n6401_o;
  wire n6402_o;
  wire n6404_o;
  wire n6405_o;
  wire n6407_o;
  wire n6408_o;
  wire n6410_o;
  wire n6411_o;
  wire n6413_o;
  wire n6414_o;
  wire [30:0] n6415_o;
  wire n6417_o;
  wire [2:0] n6418_o;
  wire n6420_o;
  wire [2:0] n6421_o;
  wire n6424_o;
  wire [2:0] n6426_o;
  wire n6428_o;
  wire [1:0] n6429_o;
  reg n6431_o;
  reg [2:0] n6433_o;
  reg [2:0] n6436_o;
  reg n6439_o;
  reg n6442_o;
  reg [1:0] n6445_o;
  wire n6447_o;
  wire n6449_o;
  wire n6450_o;
  wire n6452_o;
  wire n6453_o;
  wire n6455_o;
  wire n6456_o;
  wire n6458_o;
  wire n6459_o;
  wire n6461_o;
  wire n6462_o;
  wire n6464_o;
  wire n6465_o;
  wire n6467_o;
  wire n6468_o;
  wire [30:0] n6469_o;
  wire [2:0] n6470_o;
  wire [2:0] n6471_o;
  wire n6473_o;
  wire n6476_o;
  wire n6478_o;
  wire n6480_o;
  wire [1:0] n6481_o;
  reg [2:0] n6483_o;
  reg n6485_o;
  reg [2:0] n6488_o;
  reg n6491_o;
  reg [1:0] n6494_o;
  reg n6497_o;
  wire n6499_o;
  wire n6501_o;
  wire n6502_o;
  wire n6504_o;
  wire n6505_o;
  wire n6507_o;
  wire n6508_o;
  wire n6510_o;
  wire n6511_o;
  wire n6513_o;
  wire n6514_o;
  wire n6516_o;
  wire n6517_o;
  wire n6519_o;
  wire n6520_o;
  wire [30:0] n6521_o;
  wire n6522_o;
  wire n6524_o;
  wire n6526_o;
  wire n6527_o;
  wire n6528_o;
  wire [3:0] n6531_o;
  wire n6533_o;
  wire n6535_o;
  wire [3:0] n6536_o;
  reg [2:0] n6539_o;
  wire [2:0] n6540_o;
  reg [2:0] n6542_o;
  wire n6543_o;
  reg n6545_o;
  reg n6548_o;
  reg [3:0] n6551_o;
  reg [3:0] n6555_o;
  reg [3:0] n6557_o;
  reg n6560_o;
  reg [2:0] n6564_o;
  reg n6567_o;
  reg n6570_o;
  reg [1:0] n6573_o;
  reg n6576_o;
  reg n6579_o;
  wire n6581_o;
  wire n6583_o;
  wire n6584_o;
  wire n6586_o;
  wire n6587_o;
  wire n6589_o;
  wire n6590_o;
  wire [30:0] n6591_o;
  wire n6593_o;
  wire n6594_o;
  wire n6596_o;
  wire n6597_o;
  wire n6598_o;
  wire [3:0] n6601_o;
  wire n6603_o;
  wire n6605_o;
  wire [3:0] n6606_o;
  reg [2:0] n6609_o;
  wire [2:0] n6610_o;
  reg [2:0] n6612_o;
  wire n6613_o;
  reg n6615_o;
  reg n6618_o;
  reg [3:0] n6621_o;
  reg [3:0] n6625_o;
  reg [3:0] n6627_o;
  reg n6630_o;
  reg [2:0] n6634_o;
  reg n6637_o;
  reg n6640_o;
  reg [1:0] n6643_o;
  reg n6646_o;
  reg n6649_o;
  wire n6651_o;
  wire n6653_o;
  wire n6654_o;
  wire n6656_o;
  wire n6657_o;
  wire n6659_o;
  wire n6660_o;
  wire [22:0] n6661_o;
  reg [2:0] n6677_o;
  reg [2:0] n6683_o;
  reg n6686_o;
  reg n6689_o;
  wire [2:0] n6690_o;
  wire [2:0] n6691_o;
  wire [2:0] n6692_o;
  reg [2:0] n6695_o;
  wire n6696_o;
  wire n6697_o;
  wire n6698_o;
  reg n6701_o;
  reg n6704_o;
  reg n6708_o;
  wire [2:0] n6710_o;
  wire [2:0] n6711_o;
  reg [2:0] n6714_o;
  wire n6716_o;
  wire n6717_o;
  reg n6720_o;
  wire n6721_o;
  wire n6722_o;
  wire n6723_o;
  wire n6725_o;
  wire n6726_o;
  wire n6727_o;
  wire n6728_o;
  wire n6729_o;
  reg n6732_o;
  wire [1:0] n6733_o;
  wire [1:0] n6734_o;
  wire [1:0] n6735_o;
  wire [1:0] n6737_o;
  wire [1:0] n6738_o;
  wire [1:0] n6739_o;
  wire [1:0] n6740_o;
  wire [1:0] n6741_o;
  reg [1:0] n6744_o;
  wire n6745_o;
  wire n6746_o;
  wire n6747_o;
  wire n6749_o;
  wire n6750_o;
  reg n6753_o;
  reg [3:0] n6756_o;
  reg n6760_o;
  reg n6763_o;
  reg [2:0] n6766_o;
  reg n6769_o;
  reg n6772_o;
  reg n6775_o;
  reg n6778_o;
  reg [2:0] n6785_o;
  reg n6788_o;
  reg n6791_o;
  reg n6794_o;
  reg n6797_o;
  reg n6800_o;
  reg n6803_o;
  reg n6806_o;
  reg [1:0] n6809_o;
  reg [1:0] n6815_o;
  reg n6818_o;
  reg n6821_o;
  wire [1:0] n6822_o;
  reg [2:0] n6823_o;
  reg [2:0] n6825_o;
  reg n6827_o;
  reg n6830_o;
  wire [1:0] n6832_o;
  reg [1:0] n6834_o;
  wire n6835_o;
  wire n6836_o;
  reg n6838_o;
  wire n6839_o;
  reg n6841_o;
  reg n6845_o;
  reg n6848_o;
  reg [2:0] n6850_o;
  reg n6852_o;
  wire n6855_o;
  reg n6856_o;
  wire [1:0] n6857_o;
  reg [1:0] n6858_o;
  reg n6860_o;
  reg [3:0] n6864_o;
  reg n6865_o;
  reg n6868_o;
  reg n6871_o;
  reg [2:0] n6873_o;
  reg n6876_o;
  reg n6879_o;
  reg n6882_o;
  reg n6885_o;
  reg n6888_o;
  reg n6891_o;
  reg n6894_o;
  reg n6897_o;
  reg [2:0] n6900_o;
  reg n6903_o;
  reg n6906_o;
  reg n6909_o;
  reg n6912_o;
  reg n6915_o;
  reg n6918_o;
  reg n6921_o;
  reg n6924_o;
  reg n6927_o;
  reg n6930_o;
  reg n6933_o;
  reg n6936_o;
  reg [1:0] n6939_o;
  reg n6942_o;
  reg n6945_o;
  reg [1:0] n6948_o;
  reg n6951_o;
  reg n6954_o;
  reg n6956_o;
  reg n6959_o;
  localparam [1:0] n6962_o = 2'b00;
  localparam n6963_o = 1'b0;
  localparam n6964_o = 1'b0;
  localparam n6965_o = 1'b0;
  localparam n6966_o = 1'b0;
  wire [3:0] n6967_o;
  wire [3:0] n6968_o;
  wire [3:0] n6969_o;
  assign mcycles = n6823_o;
  assign tstates = n6825_o;
  assign prefix = n6962_o;
  assign inc_pc = n6827_o;
  assign inc_wz = n6830_o;
  assign incdec_16 = n6967_o;
  assign read_to_reg = n6845_o;
  assign read_to_acc = n6848_o;
  assign set_busa_to = n6968_o;
  assign set_busb_to = n6969_o;
  assign alu_op = n6864_o;
  assign save_alu = n6865_o;
  assign preservec = n6868_o;
  assign arith16 = n6871_o;
  assign set_addr_to = n6873_o;
  assign iorq = n6876_o;
  assign jump = n6879_o;
  assign jumpe = n6963_o;
  assign jumpxy = n6882_o;
  assign call = n6885_o;
  assign rstp = n6888_o;
  assign ldz = n6891_o;
  assign ldw = n6894_o;
  assign ldsphl = n6897_o;
  assign special_ld = n6900_o;
  assign exchangedh = n6903_o;
  assign exchangerp = n6906_o;
  assign exchangeaf = n6964_o;
  assign exchangers = n6965_o;
  assign i_djnz = n6966_o;
  assign i_cpl = n6909_o;
  assign i_ccf = n6912_o;
  assign i_scf = n6915_o;
  assign i_retn = n6918_o;
  assign i_bt = n6921_o;
  assign i_bc = n6924_o;
  assign i_btr = n6927_o;
  assign i_rld = n6930_o;
  assign i_rrd = n6933_o;
  assign i_inrc = n6936_o;
  assign setwz = n6939_o;
  assign setdi = n6942_o;
  assign setei = n6945_o;
  assign imode = n6948_o;
  assign halt = n6951_o;
  assign noread = n6954_o;
  assign write = n6956_o;
  assign xybit_undoc = n6959_o;
  /* T80_MCode.vhd:198:26  */
  assign n2172_o = ir[5:3];
  /* T80_MCode.vhd:199:26  */
  assign n2173_o = ir[2:0];
  /* T80_MCode.vhd:200:28  */
  assign n2174_o = ir[5:4];
  /* T80_MCode.vhd:204:27  */
  assign n2176_o = mcycle == 3'b001;
  /* T80_MCode.vhd:204:17  */
  assign n2179_o = n2176_o ? 3'b100 : 3'b011;
  /* T80_MCode.vhd:217:35  */
  assign n2180_o = ir[5:3];
  /* T80_MCode.vhd:217:31  */
  assign n2182_o = {1'b0, n2180_o};
  /* T80_MCode.vhd:267:17  */
  assign n2184_o = ir == 8'b01000000;
  /* T80_MCode.vhd:267:32  */
  assign n2186_o = ir == 8'b01000001;
  /* T80_MCode.vhd:267:32  */
  assign n2187_o = n2184_o | n2186_o;
  /* T80_MCode.vhd:267:43  */
  assign n2189_o = ir == 8'b01000010;
  /* T80_MCode.vhd:267:43  */
  assign n2190_o = n2187_o | n2189_o;
  /* T80_MCode.vhd:267:54  */
  assign n2192_o = ir == 8'b01000011;
  /* T80_MCode.vhd:267:54  */
  assign n2193_o = n2190_o | n2192_o;
  /* T80_MCode.vhd:267:65  */
  assign n2195_o = ir == 8'b01000100;
  /* T80_MCode.vhd:267:65  */
  assign n2196_o = n2193_o | n2195_o;
  /* T80_MCode.vhd:267:76  */
  assign n2198_o = ir == 8'b01000101;
  /* T80_MCode.vhd:267:76  */
  assign n2199_o = n2196_o | n2198_o;
  /* T80_MCode.vhd:267:87  */
  assign n2201_o = ir == 8'b01000111;
  /* T80_MCode.vhd:267:87  */
  assign n2202_o = n2199_o | n2201_o;
  /* T80_MCode.vhd:268:25  */
  assign n2204_o = ir == 8'b01001000;
  /* T80_MCode.vhd:268:25  */
  assign n2205_o = n2202_o | n2204_o;
  /* T80_MCode.vhd:268:36  */
  assign n2207_o = ir == 8'b01001001;
  /* T80_MCode.vhd:268:36  */
  assign n2208_o = n2205_o | n2207_o;
  /* T80_MCode.vhd:268:47  */
  assign n2210_o = ir == 8'b01001010;
  /* T80_MCode.vhd:268:47  */
  assign n2211_o = n2208_o | n2210_o;
  /* T80_MCode.vhd:268:58  */
  assign n2213_o = ir == 8'b01001011;
  /* T80_MCode.vhd:268:58  */
  assign n2214_o = n2211_o | n2213_o;
  /* T80_MCode.vhd:268:69  */
  assign n2216_o = ir == 8'b01001100;
  /* T80_MCode.vhd:268:69  */
  assign n2217_o = n2214_o | n2216_o;
  /* T80_MCode.vhd:268:80  */
  assign n2219_o = ir == 8'b01001101;
  /* T80_MCode.vhd:268:80  */
  assign n2220_o = n2217_o | n2219_o;
  /* T80_MCode.vhd:268:91  */
  assign n2222_o = ir == 8'b01001111;
  /* T80_MCode.vhd:268:91  */
  assign n2223_o = n2220_o | n2222_o;
  /* T80_MCode.vhd:269:25  */
  assign n2225_o = ir == 8'b01010000;
  /* T80_MCode.vhd:269:25  */
  assign n2226_o = n2223_o | n2225_o;
  /* T80_MCode.vhd:269:36  */
  assign n2228_o = ir == 8'b01010001;
  /* T80_MCode.vhd:269:36  */
  assign n2229_o = n2226_o | n2228_o;
  /* T80_MCode.vhd:269:47  */
  assign n2231_o = ir == 8'b01010010;
  /* T80_MCode.vhd:269:47  */
  assign n2232_o = n2229_o | n2231_o;
  /* T80_MCode.vhd:269:58  */
  assign n2234_o = ir == 8'b01010011;
  /* T80_MCode.vhd:269:58  */
  assign n2235_o = n2232_o | n2234_o;
  /* T80_MCode.vhd:269:69  */
  assign n2237_o = ir == 8'b01010100;
  /* T80_MCode.vhd:269:69  */
  assign n2238_o = n2235_o | n2237_o;
  /* T80_MCode.vhd:269:80  */
  assign n2240_o = ir == 8'b01010101;
  /* T80_MCode.vhd:269:80  */
  assign n2241_o = n2238_o | n2240_o;
  /* T80_MCode.vhd:269:91  */
  assign n2243_o = ir == 8'b01010111;
  /* T80_MCode.vhd:269:91  */
  assign n2244_o = n2241_o | n2243_o;
  /* T80_MCode.vhd:270:25  */
  assign n2246_o = ir == 8'b01011000;
  /* T80_MCode.vhd:270:25  */
  assign n2247_o = n2244_o | n2246_o;
  /* T80_MCode.vhd:270:36  */
  assign n2249_o = ir == 8'b01011001;
  /* T80_MCode.vhd:270:36  */
  assign n2250_o = n2247_o | n2249_o;
  /* T80_MCode.vhd:270:47  */
  assign n2252_o = ir == 8'b01011010;
  /* T80_MCode.vhd:270:47  */
  assign n2253_o = n2250_o | n2252_o;
  /* T80_MCode.vhd:270:58  */
  assign n2255_o = ir == 8'b01011011;
  /* T80_MCode.vhd:270:58  */
  assign n2256_o = n2253_o | n2255_o;
  /* T80_MCode.vhd:270:69  */
  assign n2258_o = ir == 8'b01011100;
  /* T80_MCode.vhd:270:69  */
  assign n2259_o = n2256_o | n2258_o;
  /* T80_MCode.vhd:270:80  */
  assign n2261_o = ir == 8'b01011101;
  /* T80_MCode.vhd:270:80  */
  assign n2262_o = n2259_o | n2261_o;
  /* T80_MCode.vhd:270:91  */
  assign n2264_o = ir == 8'b01011111;
  /* T80_MCode.vhd:270:91  */
  assign n2265_o = n2262_o | n2264_o;
  /* T80_MCode.vhd:271:25  */
  assign n2267_o = ir == 8'b01100000;
  /* T80_MCode.vhd:271:25  */
  assign n2268_o = n2265_o | n2267_o;
  /* T80_MCode.vhd:271:36  */
  assign n2270_o = ir == 8'b01100001;
  /* T80_MCode.vhd:271:36  */
  assign n2271_o = n2268_o | n2270_o;
  /* T80_MCode.vhd:271:47  */
  assign n2273_o = ir == 8'b01100010;
  /* T80_MCode.vhd:271:47  */
  assign n2274_o = n2271_o | n2273_o;
  /* T80_MCode.vhd:271:58  */
  assign n2276_o = ir == 8'b01100011;
  /* T80_MCode.vhd:271:58  */
  assign n2277_o = n2274_o | n2276_o;
  /* T80_MCode.vhd:271:69  */
  assign n2279_o = ir == 8'b01100100;
  /* T80_MCode.vhd:271:69  */
  assign n2280_o = n2277_o | n2279_o;
  /* T80_MCode.vhd:271:80  */
  assign n2282_o = ir == 8'b01100101;
  /* T80_MCode.vhd:271:80  */
  assign n2283_o = n2280_o | n2282_o;
  /* T80_MCode.vhd:271:91  */
  assign n2285_o = ir == 8'b01100111;
  /* T80_MCode.vhd:271:91  */
  assign n2286_o = n2283_o | n2285_o;
  /* T80_MCode.vhd:272:25  */
  assign n2288_o = ir == 8'b01101000;
  /* T80_MCode.vhd:272:25  */
  assign n2289_o = n2286_o | n2288_o;
  /* T80_MCode.vhd:272:36  */
  assign n2291_o = ir == 8'b01101001;
  /* T80_MCode.vhd:272:36  */
  assign n2292_o = n2289_o | n2291_o;
  /* T80_MCode.vhd:272:47  */
  assign n2294_o = ir == 8'b01101010;
  /* T80_MCode.vhd:272:47  */
  assign n2295_o = n2292_o | n2294_o;
  /* T80_MCode.vhd:272:58  */
  assign n2297_o = ir == 8'b01101011;
  /* T80_MCode.vhd:272:58  */
  assign n2298_o = n2295_o | n2297_o;
  /* T80_MCode.vhd:272:69  */
  assign n2300_o = ir == 8'b01101100;
  /* T80_MCode.vhd:272:69  */
  assign n2301_o = n2298_o | n2300_o;
  /* T80_MCode.vhd:272:80  */
  assign n2303_o = ir == 8'b01101101;
  /* T80_MCode.vhd:272:80  */
  assign n2304_o = n2301_o | n2303_o;
  /* T80_MCode.vhd:272:91  */
  assign n2306_o = ir == 8'b01101111;
  /* T80_MCode.vhd:272:91  */
  assign n2307_o = n2304_o | n2306_o;
  /* T80_MCode.vhd:273:25  */
  assign n2309_o = ir == 8'b01111000;
  /* T80_MCode.vhd:273:25  */
  assign n2310_o = n2307_o | n2309_o;
  /* T80_MCode.vhd:273:36  */
  assign n2312_o = ir == 8'b01111001;
  /* T80_MCode.vhd:273:36  */
  assign n2313_o = n2310_o | n2312_o;
  /* T80_MCode.vhd:273:47  */
  assign n2315_o = ir == 8'b01111010;
  /* T80_MCode.vhd:273:47  */
  assign n2316_o = n2313_o | n2315_o;
  /* T80_MCode.vhd:273:58  */
  assign n2318_o = ir == 8'b01111011;
  /* T80_MCode.vhd:273:58  */
  assign n2319_o = n2316_o | n2318_o;
  /* T80_MCode.vhd:273:69  */
  assign n2321_o = ir == 8'b01111100;
  /* T80_MCode.vhd:273:69  */
  assign n2322_o = n2319_o | n2321_o;
  /* T80_MCode.vhd:273:80  */
  assign n2324_o = ir == 8'b01111101;
  /* T80_MCode.vhd:273:80  */
  assign n2325_o = n2322_o | n2324_o;
  /* T80_MCode.vhd:273:91  */
  assign n2327_o = ir == 8'b01111111;
  /* T80_MCode.vhd:273:91  */
  assign n2328_o = n2325_o | n2327_o;
  /* T80_MCode.vhd:282:30  */
  assign n2329_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:283:25  */
  assign n2331_o = n2329_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2334_o = 1'b1;
      default: n2334_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2337_o = 1'b1;
      default: n2337_o = 1'b0;
    endcase
  /* T80_MCode.vhd:282:25  */
  always @*
    case (n2331_o)
      1'b1: n2339_o = n2172_o;
      default: n2339_o = 3'b000;
    endcase
  /* T80_MCode.vhd:279:17  */
  assign n2341_o = ir == 8'b00000110;
  /* T80_MCode.vhd:279:32  */
  assign n2343_o = ir == 8'b00001110;
  /* T80_MCode.vhd:279:32  */
  assign n2344_o = n2341_o | n2343_o;
  /* T80_MCode.vhd:279:43  */
  assign n2346_o = ir == 8'b00010110;
  /* T80_MCode.vhd:279:43  */
  assign n2347_o = n2344_o | n2346_o;
  /* T80_MCode.vhd:279:54  */
  assign n2349_o = ir == 8'b00011110;
  /* T80_MCode.vhd:279:54  */
  assign n2350_o = n2347_o | n2349_o;
  /* T80_MCode.vhd:279:65  */
  assign n2352_o = ir == 8'b00100110;
  /* T80_MCode.vhd:279:65  */
  assign n2353_o = n2350_o | n2352_o;
  /* T80_MCode.vhd:279:76  */
  assign n2355_o = ir == 8'b00101110;
  /* T80_MCode.vhd:279:76  */
  assign n2356_o = n2353_o | n2355_o;
  /* T80_MCode.vhd:279:87  */
  assign n2358_o = ir == 8'b00111110;
  /* T80_MCode.vhd:279:87  */
  assign n2359_o = n2356_o | n2358_o;
  /* T80_MCode.vhd:292:30  */
  assign n2360_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:293:25  */
  assign n2362_o = n2360_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:295:25  */
  assign n2364_o = n2360_o == 31'b0000000000000000000000000000010;
  assign n2365_o = {n2364_o, n2362_o};
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2368_o = 1'b1;
      2'b01: n2368_o = 1'b0;
      default: n2368_o = 1'b0;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2370_o = n2172_o;
      2'b01: n2370_o = 3'b000;
      default: n2370_o = 3'b000;
    endcase
  /* T80_MCode.vhd:292:25  */
  always @*
    case (n2365_o)
      2'b10: n2373_o = 3'b111;
      2'b01: n2373_o = 3'b010;
      default: n2373_o = 3'b111;
    endcase
  /* T80_MCode.vhd:289:17  */
  assign n2375_o = ir == 8'b01000110;
  /* T80_MCode.vhd:289:32  */
  assign n2377_o = ir == 8'b01001110;
  /* T80_MCode.vhd:289:32  */
  assign n2378_o = n2375_o | n2377_o;
  /* T80_MCode.vhd:289:43  */
  assign n2380_o = ir == 8'b01010110;
  /* T80_MCode.vhd:289:43  */
  assign n2381_o = n2378_o | n2380_o;
  /* T80_MCode.vhd:289:54  */
  assign n2383_o = ir == 8'b01011110;
  /* T80_MCode.vhd:289:54  */
  assign n2384_o = n2381_o | n2383_o;
  /* T80_MCode.vhd:289:65  */
  assign n2386_o = ir == 8'b01100110;
  /* T80_MCode.vhd:289:65  */
  assign n2387_o = n2384_o | n2386_o;
  /* T80_MCode.vhd:289:76  */
  assign n2389_o = ir == 8'b01101110;
  /* T80_MCode.vhd:289:76  */
  assign n2390_o = n2387_o | n2389_o;
  /* T80_MCode.vhd:289:87  */
  assign n2392_o = ir == 8'b01111110;
  /* T80_MCode.vhd:289:87  */
  assign n2393_o = n2390_o | n2392_o;
  /* T80_MCode.vhd:303:30  */
  assign n2394_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:304:25  */
  assign n2397_o = n2394_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:308:25  */
  assign n2399_o = n2394_o == 31'b0000000000000000000000000000010;
  assign n2400_o = {n2399_o, n2397_o};
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2402_o = 3'b000;
      2'b01: n2402_o = n2173_o;
      default: n2402_o = 3'b000;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2404_o = 1'b0;
      2'b01: n2404_o = 1'b0;
      default: n2404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2407_o = 3'b111;
      2'b01: n2407_o = 3'b010;
      default: n2407_o = 3'b111;
    endcase
  /* T80_MCode.vhd:303:25  */
  always @*
    case (n2400_o)
      2'b10: n2410_o = 1'b1;
      2'b01: n2410_o = 1'b0;
      default: n2410_o = 1'b0;
    endcase
  /* T80_MCode.vhd:300:17  */
  assign n2412_o = ir == 8'b01110000;
  /* T80_MCode.vhd:300:32  */
  assign n2414_o = ir == 8'b01110001;
  /* T80_MCode.vhd:300:32  */
  assign n2415_o = n2412_o | n2414_o;
  /* T80_MCode.vhd:300:43  */
  assign n2417_o = ir == 8'b01110010;
  /* T80_MCode.vhd:300:43  */
  assign n2418_o = n2415_o | n2417_o;
  /* T80_MCode.vhd:300:54  */
  assign n2420_o = ir == 8'b01110011;
  /* T80_MCode.vhd:300:54  */
  assign n2421_o = n2418_o | n2420_o;
  /* T80_MCode.vhd:300:65  */
  assign n2423_o = ir == 8'b01110100;
  /* T80_MCode.vhd:300:65  */
  assign n2424_o = n2421_o | n2423_o;
  /* T80_MCode.vhd:300:76  */
  assign n2426_o = ir == 8'b01110101;
  /* T80_MCode.vhd:300:76  */
  assign n2427_o = n2424_o | n2426_o;
  /* T80_MCode.vhd:300:87  */
  assign n2429_o = ir == 8'b01110111;
  /* T80_MCode.vhd:300:87  */
  assign n2430_o = n2427_o | n2429_o;
  /* T80_MCode.vhd:315:30  */
  assign n2431_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:316:25  */
  assign n2434_o = n2431_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:321:25  */
  assign n2436_o = n2431_o == 31'b0000000000000000000000000000011;
  assign n2437_o = {n2436_o, n2434_o};
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2440_o = 1'b0;
      2'b01: n2440_o = 1'b1;
      default: n2440_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2442_o = 3'b000;
      2'b01: n2442_o = n2173_o;
      default: n2442_o = 3'b000;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2444_o = 1'b0;
      2'b01: n2444_o = 1'b0;
      default: n2444_o = 1'b0;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2447_o = 3'b111;
      2'b01: n2447_o = 3'b010;
      default: n2447_o = 3'b111;
    endcase
  /* T80_MCode.vhd:315:25  */
  always @*
    case (n2437_o)
      2'b10: n2450_o = 1'b1;
      2'b01: n2450_o = 1'b0;
      default: n2450_o = 1'b0;
    endcase
  /* T80_MCode.vhd:312:17  */
  assign n2452_o = ir == 8'b00110110;
  /* T80_MCode.vhd:328:30  */
  assign n2453_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:329:25  */
  assign n2455_o = n2453_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:331:25  */
  assign n2457_o = n2453_o == 31'b0000000000000000000000000000010;
  assign n2458_o = {n2457_o, n2455_o};
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2458_o)
      2'b10: n2461_o = 1'b1;
      2'b01: n2461_o = 1'b0;
      default: n2461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:328:25  */
  always @*
    case (n2458_o)
      2'b10: n2464_o = 3'b111;
      2'b01: n2464_o = 3'b000;
      default: n2464_o = 3'b111;
    endcase
  /* T80_MCode.vhd:325:17  */
  assign n2466_o = ir == 8'b00001010;
  /* T80_MCode.vhd:338:30  */
  assign n2467_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:339:25  */
  assign n2469_o = n2467_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:341:25  */
  assign n2471_o = n2467_o == 31'b0000000000000000000000000000010;
  assign n2472_o = {n2471_o, n2469_o};
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2472_o)
      2'b10: n2475_o = 1'b1;
      2'b01: n2475_o = 1'b0;
      default: n2475_o = 1'b0;
    endcase
  /* T80_MCode.vhd:338:25  */
  always @*
    case (n2472_o)
      2'b10: n2478_o = 3'b111;
      2'b01: n2478_o = 3'b001;
      default: n2478_o = 3'b111;
    endcase
  /* T80_MCode.vhd:335:17  */
  assign n2480_o = ir == 8'b00011010;
  /* T80_MCode.vhd:360:38  */
  assign n2481_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:361:33  */
  assign n2483_o = n2481_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:364:33  */
  assign n2485_o = n2481_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:367:33  */
  assign n2487_o = n2481_o == 31'b0000000000000000000000000000100;
  assign n2488_o = {n2487_o, n2485_o, n2483_o};
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2492_o = 1'b0;
      3'b010: n2492_o = 1'b1;
      3'b001: n2492_o = 1'b1;
      default: n2492_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2495_o = 1'b1;
      3'b010: n2495_o = 1'b0;
      3'b001: n2495_o = 1'b0;
      default: n2495_o = 1'b0;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2498_o = 3'b111;
      3'b010: n2498_o = 3'b110;
      3'b001: n2498_o = 3'b111;
      default: n2498_o = 3'b111;
    endcase
  /* T80_MCode.vhd:360:33  */
  always @*
    case (n2488_o)
      3'b100: n2501_o = 1'b0;
      3'b010: n2501_o = 1'b0;
      3'b001: n2501_o = 1'b1;
      default: n2501_o = 1'b0;
    endcase
  /* T80_MCode.vhd:345:17  */
  assign n2503_o = ir == 8'b00111010;
  /* T80_MCode.vhd:375:30  */
  assign n2504_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:376:25  */
  assign n2506_o = n2504_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:380:25  */
  assign n2508_o = n2504_o == 31'b0000000000000000000000000000010;
  assign n2509_o = {n2508_o, n2506_o};
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2512_o = 4'b0000;
      2'b01: n2512_o = 4'b0111;
      default: n2512_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2515_o = 3'b111;
      2'b01: n2515_o = 3'b000;
      default: n2515_o = 3'b111;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2518_o = 2'b00;
      2'b01: n2518_o = 2'b10;
      default: n2518_o = 2'b00;
    endcase
  /* T80_MCode.vhd:375:25  */
  always @*
    case (n2509_o)
      2'b10: n2521_o = 1'b1;
      2'b01: n2521_o = 1'b0;
      default: n2521_o = 1'b0;
    endcase
  /* T80_MCode.vhd:372:17  */
  assign n2523_o = ir == 8'b00000010;
  /* T80_MCode.vhd:387:30  */
  assign n2524_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:388:25  */
  assign n2526_o = n2524_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:392:25  */
  assign n2528_o = n2524_o == 31'b0000000000000000000000000000010;
  assign n2529_o = {n2528_o, n2526_o};
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2532_o = 4'b0000;
      2'b01: n2532_o = 4'b0111;
      default: n2532_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2535_o = 3'b111;
      2'b01: n2535_o = 3'b001;
      default: n2535_o = 3'b111;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2538_o = 2'b00;
      2'b01: n2538_o = 2'b10;
      default: n2538_o = 2'b00;
    endcase
  /* T80_MCode.vhd:387:25  */
  always @*
    case (n2529_o)
      2'b10: n2541_o = 1'b1;
      2'b01: n2541_o = 1'b0;
      default: n2541_o = 1'b0;
    endcase
  /* T80_MCode.vhd:384:17  */
  assign n2543_o = ir == 8'b00010010;
  /* T80_MCode.vhd:412:38  */
  assign n2544_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:413:33  */
  assign n2546_o = n2544_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:416:33  */
  assign n2548_o = n2544_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:421:33  */
  assign n2550_o = n2544_o == 31'b0000000000000000000000000000100;
  assign n2551_o = {n2550_o, n2548_o, n2546_o};
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2555_o = 1'b0;
      3'b010: n2555_o = 1'b1;
      3'b001: n2555_o = 1'b1;
      default: n2555_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2558_o = 4'b0000;
      3'b010: n2558_o = 4'b0111;
      3'b001: n2558_o = 4'b0000;
      default: n2558_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2561_o = 3'b111;
      3'b010: n2561_o = 3'b110;
      3'b001: n2561_o = 3'b111;
      default: n2561_o = 3'b111;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2564_o = 1'b0;
      3'b010: n2564_o = 1'b0;
      3'b001: n2564_o = 1'b1;
      default: n2564_o = 1'b0;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2567_o = 2'b00;
      3'b010: n2567_o = 2'b10;
      3'b001: n2567_o = 2'b00;
      default: n2567_o = 2'b00;
    endcase
  /* T80_MCode.vhd:412:33  */
  always @*
    case (n2551_o)
      3'b100: n2570_o = 1'b1;
      3'b010: n2570_o = 1'b0;
      3'b001: n2570_o = 1'b0;
      default: n2570_o = 1'b0;
    endcase
  /* T80_MCode.vhd:396:17  */
  assign n2572_o = ir == 8'b00110010;
  /* T80_MCode.vhd:431:30  */
  assign n2573_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:435:42  */
  assign n2575_o = n2174_o == 2'b11;
  assign n2577_o = {n2174_o, 1'b1};
  /* T80_MCode.vhd:435:33  */
  assign n2579_o = n2575_o ? 3'b000 : n2577_o;
  /* T80_MCode.vhd:435:33  */
  assign n2582_o = n2575_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:432:25  */
  assign n2584_o = n2573_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:444:42  */
  assign n2586_o = n2174_o == 2'b11;
  assign n2588_o = {n2174_o, 1'b0};
  /* T80_MCode.vhd:444:33  */
  assign n2590_o = n2586_o ? 3'b001 : n2588_o;
  /* T80_MCode.vhd:444:33  */
  assign n2593_o = n2586_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:441:25  */
  assign n2595_o = n2573_o == 31'b0000000000000000000000000000011;
  assign n2596_o = {n2595_o, n2584_o};
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2600_o = 1'b1;
      2'b01: n2600_o = 1'b1;
      default: n2600_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2604_o = 1'b1;
      2'b01: n2604_o = 1'b1;
      default: n2604_o = 1'b0;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2606_o = n2590_o;
      2'b01: n2606_o = n2579_o;
      default: n2606_o = 3'b000;
    endcase
  /* T80_MCode.vhd:431:25  */
  always @*
    case (n2596_o)
      2'b10: n2608_o = n2593_o;
      2'b01: n2608_o = n2582_o;
      default: n2608_o = 1'b0;
    endcase
  /* T80_MCode.vhd:428:17  */
  assign n2610_o = ir == 8'b00000001;
  /* T80_MCode.vhd:428:32  */
  assign n2612_o = ir == 8'b00010001;
  /* T80_MCode.vhd:428:32  */
  assign n2613_o = n2610_o | n2612_o;
  /* T80_MCode.vhd:428:43  */
  assign n2615_o = ir == 8'b00100001;
  /* T80_MCode.vhd:428:43  */
  assign n2616_o = n2613_o | n2615_o;
  /* T80_MCode.vhd:428:54  */
  assign n2618_o = ir == 8'b00110001;
  /* T80_MCode.vhd:428:54  */
  assign n2619_o = n2616_o | n2618_o;
  /* T80_MCode.vhd:467:38  */
  assign n2620_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:468:33  */
  assign n2622_o = n2620_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:471:33  */
  assign n2624_o = n2620_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:475:33  */
  assign n2627_o = n2620_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:480:33  */
  assign n2630_o = n2620_o == 31'b0000000000000000000000000000101;
  assign n2631_o = {n2630_o, n2627_o, n2624_o, n2622_o};
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2635_o = 1'b0;
      4'b0100: n2635_o = 1'b0;
      4'b0010: n2635_o = 1'b1;
      4'b0001: n2635_o = 1'b1;
      default: n2635_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2638_o = 1'b0;
      4'b0100: n2638_o = 1'b1;
      4'b0010: n2638_o = 1'b0;
      4'b0001: n2638_o = 1'b0;
      default: n2638_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2642_o = 1'b1;
      4'b0100: n2642_o = 1'b1;
      4'b0010: n2642_o = 1'b0;
      4'b0001: n2642_o = 1'b0;
      default: n2642_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2644_o = 3'b100;
      4'b0100: n2644_o = 3'b101;
      4'b0010: n2644_o = 3'b000;
      4'b0001: n2644_o = 3'b000;
      default: n2644_o = 3'b000;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2648_o = 3'b111;
      4'b0100: n2648_o = 3'b110;
      4'b0010: n2648_o = 3'b110;
      4'b0001: n2648_o = 3'b111;
      default: n2648_o = 3'b111;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2651_o = 1'b0;
      4'b0100: n2651_o = 1'b0;
      4'b0010: n2651_o = 1'b0;
      4'b0001: n2651_o = 1'b1;
      default: n2651_o = 1'b0;
    endcase
  /* T80_MCode.vhd:467:33  */
  always @*
    case (n2631_o)
      4'b1000: n2654_o = 1'b0;
      4'b0100: n2654_o = 1'b0;
      4'b0010: n2654_o = 1'b1;
      4'b0001: n2654_o = 1'b0;
      default: n2654_o = 1'b0;
    endcase
  /* T80_MCode.vhd:452:17  */
  assign n2656_o = ir == 8'b00101010;
  /* T80_MCode.vhd:502:38  */
  assign n2657_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:503:33  */
  assign n2659_o = n2657_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:506:33  */
  assign n2661_o = n2657_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:511:33  */
  assign n2663_o = n2657_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:516:33  */
  assign n2665_o = n2657_o == 31'b0000000000000000000000000000101;
  assign n2666_o = {n2665_o, n2663_o, n2661_o, n2659_o};
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2670_o = 1'b0;
      4'b0100: n2670_o = 1'b0;
      4'b0010: n2670_o = 1'b1;
      4'b0001: n2670_o = 1'b1;
      default: n2670_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2673_o = 1'b0;
      4'b0100: n2673_o = 1'b1;
      4'b0010: n2673_o = 1'b0;
      4'b0001: n2673_o = 1'b0;
      default: n2673_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2677_o = 4'b0000;
      4'b0100: n2677_o = 4'b0100;
      4'b0010: n2677_o = 4'b0101;
      4'b0001: n2677_o = 4'b0000;
      default: n2677_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2681_o = 3'b111;
      4'b0100: n2681_o = 3'b110;
      4'b0010: n2681_o = 3'b110;
      4'b0001: n2681_o = 3'b111;
      default: n2681_o = 3'b111;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2684_o = 1'b0;
      4'b0100: n2684_o = 1'b0;
      4'b0010: n2684_o = 1'b0;
      4'b0001: n2684_o = 1'b1;
      default: n2684_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2687_o = 1'b0;
      4'b0100: n2687_o = 1'b0;
      4'b0010: n2687_o = 1'b1;
      4'b0001: n2687_o = 1'b0;
      default: n2687_o = 1'b0;
    endcase
  /* T80_MCode.vhd:502:33  */
  always @*
    case (n2666_o)
      4'b1000: n2691_o = 1'b1;
      4'b0100: n2691_o = 1'b1;
      4'b0010: n2691_o = 1'b0;
      4'b0001: n2691_o = 1'b0;
      default: n2691_o = 1'b0;
    endcase
  /* T80_MCode.vhd:486:17  */
  assign n2693_o = ir == 8'b00100010;
  /* T80_MCode.vhd:521:17  */
  assign n2695_o = ir == 8'b11111001;
  /* T80_MCode.vhd:528:30  */
  assign n2696_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:533:42  */
  assign n2698_o = n2174_o == 2'b11;
  assign n2701_o = {1'b0, n2174_o, 1'b0};
  /* T80_MCode.vhd:533:33  */
  assign n2703_o = n2698_o ? 4'b0111 : n2701_o;
  /* T80_MCode.vhd:529:25  */
  assign n2705_o = n2696_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:543:42  */
  assign n2707_o = n2174_o == 2'b11;
  assign n2710_o = {1'b0, n2174_o, 1'b1};
  /* T80_MCode.vhd:543:33  */
  assign n2712_o = n2707_o ? 4'b1011 : n2710_o;
  /* T80_MCode.vhd:540:25  */
  assign n2714_o = n2696_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:551:25  */
  assign n2716_o = n2696_o == 31'b0000000000000000000000000000011;
  assign n2717_o = {n2716_o, n2714_o, n2705_o};
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2719_o = n2179_o;
      3'b010: n2719_o = n2179_o;
      3'b001: n2719_o = 3'b101;
      default: n2719_o = n2179_o;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2723_o = 4'b0000;
      3'b010: n2723_o = 4'b1111;
      3'b001: n2723_o = 4'b1111;
      default: n2723_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2725_o = 4'b0000;
      3'b010: n2725_o = n2712_o;
      3'b001: n2725_o = n2703_o;
      default: n2725_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2729_o = 3'b111;
      3'b010: n2729_o = 3'b101;
      3'b001: n2729_o = 3'b101;
      default: n2729_o = 3'b111;
    endcase
  /* T80_MCode.vhd:528:25  */
  always @*
    case (n2717_o)
      3'b100: n2733_o = 1'b1;
      3'b010: n2733_o = 1'b1;
      3'b001: n2733_o = 1'b0;
      default: n2733_o = 1'b0;
    endcase
  /* T80_MCode.vhd:525:17  */
  assign n2735_o = ir == 8'b11000101;
  /* T80_MCode.vhd:525:32  */
  assign n2737_o = ir == 8'b11010101;
  /* T80_MCode.vhd:525:32  */
  assign n2738_o = n2735_o | n2737_o;
  /* T80_MCode.vhd:525:43  */
  assign n2740_o = ir == 8'b11100101;
  /* T80_MCode.vhd:525:43  */
  assign n2741_o = n2738_o | n2740_o;
  /* T80_MCode.vhd:525:54  */
  assign n2743_o = ir == 8'b11110101;
  /* T80_MCode.vhd:525:54  */
  assign n2744_o = n2741_o | n2743_o;
  /* T80_MCode.vhd:558:30  */
  assign n2745_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:559:25  */
  assign n2747_o = n2745_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:565:42  */
  assign n2749_o = n2174_o == 2'b11;
  assign n2751_o = {n2174_o, 1'b1};
  /* T80_MCode.vhd:565:33  */
  assign n2753_o = n2749_o ? 3'b011 : n2751_o;
  /* T80_MCode.vhd:565:33  */
  assign n2756_o = n2749_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:561:25  */
  assign n2758_o = n2745_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:574:42  */
  assign n2760_o = n2174_o == 2'b11;
  assign n2762_o = {n2174_o, 1'b0};
  /* T80_MCode.vhd:574:33  */
  assign n2764_o = n2760_o ? 3'b111 : n2762_o;
  /* T80_MCode.vhd:574:33  */
  assign n2767_o = n2760_o ? 1'b0 : 1'b0;
  /* T80_MCode.vhd:571:25  */
  assign n2769_o = n2745_o == 31'b0000000000000000000000000000011;
  assign n2770_o = {n2769_o, n2758_o, n2747_o};
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2774_o = 4'b0111;
      3'b010: n2774_o = 4'b0111;
      3'b001: n2774_o = 4'b0000;
      default: n2774_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2778_o = 1'b1;
      3'b010: n2778_o = 1'b1;
      3'b001: n2778_o = 1'b0;
      default: n2778_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2780_o = n2764_o;
      3'b010: n2780_o = n2753_o;
      3'b001: n2780_o = 3'b000;
      default: n2780_o = 3'b000;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2782_o = n2767_o;
      3'b010: n2782_o = n2756_o;
      3'b001: n2782_o = 1'b0;
      default: n2782_o = 1'b0;
    endcase
  /* T80_MCode.vhd:558:25  */
  always @*
    case (n2770_o)
      3'b100: n2786_o = 3'b111;
      3'b010: n2786_o = 3'b101;
      3'b001: n2786_o = 3'b101;
      default: n2786_o = 3'b111;
    endcase
  /* T80_MCode.vhd:555:17  */
  assign n2788_o = ir == 8'b11000001;
  /* T80_MCode.vhd:555:32  */
  assign n2790_o = ir == 8'b11010001;
  /* T80_MCode.vhd:555:32  */
  assign n2791_o = n2788_o | n2790_o;
  /* T80_MCode.vhd:555:43  */
  assign n2793_o = ir == 8'b11100001;
  /* T80_MCode.vhd:555:43  */
  assign n2794_o = n2791_o | n2793_o;
  /* T80_MCode.vhd:555:54  */
  assign n2796_o = ir == 8'b11110001;
  /* T80_MCode.vhd:555:54  */
  assign n2797_o = n2794_o | n2796_o;
  /* T80_MCode.vhd:584:17  */
  assign n2799_o = ir == 8'b11101011;
  /* T80_MCode.vhd:589:17  */
  assign n2801_o = ir == 8'b00001000;
  /* T80_MCode.vhd:615:17  */
  assign n2803_o = ir == 8'b11011001;
  /* T80_MCode.vhd:641:38  */
  assign n2804_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:642:33  */
  assign n2806_o = n2804_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:644:33  */
  assign n2808_o = n2804_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:650:33  */
  assign n2810_o = n2804_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:655:33  */
  assign n2812_o = n2804_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:661:33  */
  assign n2814_o = n2804_o == 31'b0000000000000000000000000000101;
  assign n2815_o = {n2814_o, n2812_o, n2810_o, n2808_o, n2806_o};
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2818_o = 3'b101;
      5'b01000: n2818_o = n2179_o;
      5'b00100: n2818_o = 3'b100;
      5'b00010: n2818_o = n2179_o;
      5'b00001: n2818_o = n2179_o;
      default: n2818_o = n2179_o;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2822_o = 4'b1111;
      5'b01000: n2822_o = 4'b0000;
      5'b00100: n2822_o = 4'b0111;
      5'b00010: n2822_o = 4'b0000;
      5'b00001: n2822_o = 4'b0000;
      default: n2822_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2826_o = 1'b0;
      5'b01000: n2826_o = 1'b1;
      5'b00100: n2826_o = 1'b0;
      5'b00010: n2826_o = 1'b1;
      5'b00001: n2826_o = 1'b0;
      default: n2826_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2830_o = 4'b0000;
      5'b01000: n2830_o = 4'b0100;
      5'b00100: n2830_o = 4'b0000;
      5'b00010: n2830_o = 4'b0101;
      5'b00001: n2830_o = 4'b0000;
      default: n2830_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2834_o = 4'b0000;
      5'b01000: n2834_o = 4'b0100;
      5'b00100: n2834_o = 4'b0000;
      5'b00010: n2834_o = 4'b0101;
      5'b00001: n2834_o = 4'b0000;
      default: n2834_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2840_o = 3'b111;
      5'b01000: n2840_o = 3'b101;
      5'b00100: n2840_o = 3'b101;
      5'b00010: n2840_o = 3'b101;
      5'b00001: n2840_o = 3'b101;
      default: n2840_o = 3'b111;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2843_o = 1'b0;
      5'b01000: n2843_o = 1'b0;
      5'b00100: n2843_o = 1'b0;
      5'b00010: n2843_o = 1'b1;
      5'b00001: n2843_o = 1'b0;
      default: n2843_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2846_o = 1'b0;
      5'b01000: n2846_o = 1'b1;
      5'b00100: n2846_o = 1'b0;
      5'b00010: n2846_o = 1'b0;
      5'b00001: n2846_o = 1'b0;
      default: n2846_o = 1'b0;
    endcase
  /* T80_MCode.vhd:641:33  */
  always @*
    case (n2815_o)
      5'b10000: n2850_o = 1'b1;
      5'b01000: n2850_o = 1'b0;
      5'b00100: n2850_o = 1'b1;
      5'b00010: n2850_o = 1'b0;
      5'b00001: n2850_o = 1'b0;
      default: n2850_o = 1'b0;
    endcase
  /* T80_MCode.vhd:637:17  */
  assign n2852_o = ir == 8'b11100011;
  /* T80_MCode.vhd:670:17  */
  assign n2855_o = ir == 8'b10000000;
  /* T80_MCode.vhd:670:32  */
  assign n2857_o = ir == 8'b10000001;
  /* T80_MCode.vhd:670:32  */
  assign n2858_o = n2855_o | n2857_o;
  /* T80_MCode.vhd:670:43  */
  assign n2860_o = ir == 8'b10000010;
  /* T80_MCode.vhd:670:43  */
  assign n2861_o = n2858_o | n2860_o;
  /* T80_MCode.vhd:670:54  */
  assign n2863_o = ir == 8'b10000011;
  /* T80_MCode.vhd:670:54  */
  assign n2864_o = n2861_o | n2863_o;
  /* T80_MCode.vhd:670:65  */
  assign n2866_o = ir == 8'b10000100;
  /* T80_MCode.vhd:670:65  */
  assign n2867_o = n2864_o | n2866_o;
  /* T80_MCode.vhd:670:76  */
  assign n2869_o = ir == 8'b10000101;
  /* T80_MCode.vhd:670:76  */
  assign n2870_o = n2867_o | n2869_o;
  /* T80_MCode.vhd:670:87  */
  assign n2872_o = ir == 8'b10000111;
  /* T80_MCode.vhd:670:87  */
  assign n2873_o = n2870_o | n2872_o;
  /* T80_MCode.vhd:671:25  */
  assign n2875_o = ir == 8'b10001000;
  /* T80_MCode.vhd:671:25  */
  assign n2876_o = n2873_o | n2875_o;
  /* T80_MCode.vhd:671:36  */
  assign n2878_o = ir == 8'b10001001;
  /* T80_MCode.vhd:671:36  */
  assign n2879_o = n2876_o | n2878_o;
  /* T80_MCode.vhd:671:47  */
  assign n2881_o = ir == 8'b10001010;
  /* T80_MCode.vhd:671:47  */
  assign n2882_o = n2879_o | n2881_o;
  /* T80_MCode.vhd:671:58  */
  assign n2884_o = ir == 8'b10001011;
  /* T80_MCode.vhd:671:58  */
  assign n2885_o = n2882_o | n2884_o;
  /* T80_MCode.vhd:671:69  */
  assign n2887_o = ir == 8'b10001100;
  /* T80_MCode.vhd:671:69  */
  assign n2888_o = n2885_o | n2887_o;
  /* T80_MCode.vhd:671:80  */
  assign n2890_o = ir == 8'b10001101;
  /* T80_MCode.vhd:671:80  */
  assign n2891_o = n2888_o | n2890_o;
  /* T80_MCode.vhd:671:91  */
  assign n2893_o = ir == 8'b10001111;
  /* T80_MCode.vhd:671:91  */
  assign n2894_o = n2891_o | n2893_o;
  /* T80_MCode.vhd:672:25  */
  assign n2896_o = ir == 8'b10010000;
  /* T80_MCode.vhd:672:25  */
  assign n2897_o = n2894_o | n2896_o;
  /* T80_MCode.vhd:672:36  */
  assign n2899_o = ir == 8'b10010001;
  /* T80_MCode.vhd:672:36  */
  assign n2900_o = n2897_o | n2899_o;
  /* T80_MCode.vhd:672:47  */
  assign n2902_o = ir == 8'b10010010;
  /* T80_MCode.vhd:672:47  */
  assign n2903_o = n2900_o | n2902_o;
  /* T80_MCode.vhd:672:58  */
  assign n2905_o = ir == 8'b10010011;
  /* T80_MCode.vhd:672:58  */
  assign n2906_o = n2903_o | n2905_o;
  /* T80_MCode.vhd:672:69  */
  assign n2908_o = ir == 8'b10010100;
  /* T80_MCode.vhd:672:69  */
  assign n2909_o = n2906_o | n2908_o;
  /* T80_MCode.vhd:672:80  */
  assign n2911_o = ir == 8'b10010101;
  /* T80_MCode.vhd:672:80  */
  assign n2912_o = n2909_o | n2911_o;
  /* T80_MCode.vhd:672:91  */
  assign n2914_o = ir == 8'b10010111;
  /* T80_MCode.vhd:672:91  */
  assign n2915_o = n2912_o | n2914_o;
  /* T80_MCode.vhd:673:25  */
  assign n2917_o = ir == 8'b10011000;
  /* T80_MCode.vhd:673:25  */
  assign n2918_o = n2915_o | n2917_o;
  /* T80_MCode.vhd:673:36  */
  assign n2920_o = ir == 8'b10011001;
  /* T80_MCode.vhd:673:36  */
  assign n2921_o = n2918_o | n2920_o;
  /* T80_MCode.vhd:673:47  */
  assign n2923_o = ir == 8'b10011010;
  /* T80_MCode.vhd:673:47  */
  assign n2924_o = n2921_o | n2923_o;
  /* T80_MCode.vhd:673:58  */
  assign n2926_o = ir == 8'b10011011;
  /* T80_MCode.vhd:673:58  */
  assign n2927_o = n2924_o | n2926_o;
  /* T80_MCode.vhd:673:69  */
  assign n2929_o = ir == 8'b10011100;
  /* T80_MCode.vhd:673:69  */
  assign n2930_o = n2927_o | n2929_o;
  /* T80_MCode.vhd:673:80  */
  assign n2932_o = ir == 8'b10011101;
  /* T80_MCode.vhd:673:80  */
  assign n2933_o = n2930_o | n2932_o;
  /* T80_MCode.vhd:673:91  */
  assign n2935_o = ir == 8'b10011111;
  /* T80_MCode.vhd:673:91  */
  assign n2936_o = n2933_o | n2935_o;
  /* T80_MCode.vhd:674:25  */
  assign n2938_o = ir == 8'b10100000;
  /* T80_MCode.vhd:674:25  */
  assign n2939_o = n2936_o | n2938_o;
  /* T80_MCode.vhd:674:36  */
  assign n2941_o = ir == 8'b10100001;
  /* T80_MCode.vhd:674:36  */
  assign n2942_o = n2939_o | n2941_o;
  /* T80_MCode.vhd:674:47  */
  assign n2944_o = ir == 8'b10100010;
  /* T80_MCode.vhd:674:47  */
  assign n2945_o = n2942_o | n2944_o;
  /* T80_MCode.vhd:674:58  */
  assign n2947_o = ir == 8'b10100011;
  /* T80_MCode.vhd:674:58  */
  assign n2948_o = n2945_o | n2947_o;
  /* T80_MCode.vhd:674:69  */
  assign n2950_o = ir == 8'b10100100;
  /* T80_MCode.vhd:674:69  */
  assign n2951_o = n2948_o | n2950_o;
  /* T80_MCode.vhd:674:80  */
  assign n2953_o = ir == 8'b10100101;
  /* T80_MCode.vhd:674:80  */
  assign n2954_o = n2951_o | n2953_o;
  /* T80_MCode.vhd:674:91  */
  assign n2956_o = ir == 8'b10100111;
  /* T80_MCode.vhd:674:91  */
  assign n2957_o = n2954_o | n2956_o;
  /* T80_MCode.vhd:675:25  */
  assign n2959_o = ir == 8'b10101000;
  /* T80_MCode.vhd:675:25  */
  assign n2960_o = n2957_o | n2959_o;
  /* T80_MCode.vhd:675:36  */
  assign n2962_o = ir == 8'b10101001;
  /* T80_MCode.vhd:675:36  */
  assign n2963_o = n2960_o | n2962_o;
  /* T80_MCode.vhd:675:47  */
  assign n2965_o = ir == 8'b10101010;
  /* T80_MCode.vhd:675:47  */
  assign n2966_o = n2963_o | n2965_o;
  /* T80_MCode.vhd:675:58  */
  assign n2968_o = ir == 8'b10101011;
  /* T80_MCode.vhd:675:58  */
  assign n2969_o = n2966_o | n2968_o;
  /* T80_MCode.vhd:675:69  */
  assign n2971_o = ir == 8'b10101100;
  /* T80_MCode.vhd:675:69  */
  assign n2972_o = n2969_o | n2971_o;
  /* T80_MCode.vhd:675:80  */
  assign n2974_o = ir == 8'b10101101;
  /* T80_MCode.vhd:675:80  */
  assign n2975_o = n2972_o | n2974_o;
  /* T80_MCode.vhd:675:91  */
  assign n2977_o = ir == 8'b10101111;
  /* T80_MCode.vhd:675:91  */
  assign n2978_o = n2975_o | n2977_o;
  /* T80_MCode.vhd:676:25  */
  assign n2980_o = ir == 8'b10110000;
  /* T80_MCode.vhd:676:25  */
  assign n2981_o = n2978_o | n2980_o;
  /* T80_MCode.vhd:676:36  */
  assign n2983_o = ir == 8'b10110001;
  /* T80_MCode.vhd:676:36  */
  assign n2984_o = n2981_o | n2983_o;
  /* T80_MCode.vhd:676:47  */
  assign n2986_o = ir == 8'b10110010;
  /* T80_MCode.vhd:676:47  */
  assign n2987_o = n2984_o | n2986_o;
  /* T80_MCode.vhd:676:58  */
  assign n2989_o = ir == 8'b10110011;
  /* T80_MCode.vhd:676:58  */
  assign n2990_o = n2987_o | n2989_o;
  /* T80_MCode.vhd:676:69  */
  assign n2992_o = ir == 8'b10110100;
  /* T80_MCode.vhd:676:69  */
  assign n2993_o = n2990_o | n2992_o;
  /* T80_MCode.vhd:676:80  */
  assign n2995_o = ir == 8'b10110101;
  /* T80_MCode.vhd:676:80  */
  assign n2996_o = n2993_o | n2995_o;
  /* T80_MCode.vhd:676:91  */
  assign n2998_o = ir == 8'b10110111;
  /* T80_MCode.vhd:676:91  */
  assign n2999_o = n2996_o | n2998_o;
  /* T80_MCode.vhd:677:25  */
  assign n3001_o = ir == 8'b10111000;
  /* T80_MCode.vhd:677:25  */
  assign n3002_o = n2999_o | n3001_o;
  /* T80_MCode.vhd:677:36  */
  assign n3004_o = ir == 8'b10111001;
  /* T80_MCode.vhd:677:36  */
  assign n3005_o = n3002_o | n3004_o;
  /* T80_MCode.vhd:677:47  */
  assign n3007_o = ir == 8'b10111010;
  /* T80_MCode.vhd:677:47  */
  assign n3008_o = n3005_o | n3007_o;
  /* T80_MCode.vhd:677:58  */
  assign n3010_o = ir == 8'b10111011;
  /* T80_MCode.vhd:677:58  */
  assign n3011_o = n3008_o | n3010_o;
  /* T80_MCode.vhd:677:69  */
  assign n3013_o = ir == 8'b10111100;
  /* T80_MCode.vhd:677:69  */
  assign n3014_o = n3011_o | n3013_o;
  /* T80_MCode.vhd:677:80  */
  assign n3016_o = ir == 8'b10111101;
  /* T80_MCode.vhd:677:80  */
  assign n3017_o = n3014_o | n3016_o;
  /* T80_MCode.vhd:677:91  */
  assign n3019_o = ir == 8'b10111111;
  /* T80_MCode.vhd:677:91  */
  assign n3020_o = n3017_o | n3019_o;
  /* T80_MCode.vhd:700:30  */
  assign n3021_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:701:25  */
  assign n3023_o = n3021_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:703:25  */
  assign n3026_o = n3021_o == 31'b0000000000000000000000000000010;
  assign n3027_o = {n3026_o, n3023_o};
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3030_o = 1'b1;
      2'b01: n3030_o = 1'b0;
      default: n3030_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3032_o = 3'b111;
      2'b01: n3032_o = 3'b000;
      default: n3032_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3034_o = n2173_o;
      2'b01: n3034_o = 3'b000;
      default: n3034_o = 3'b000;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3037_o = 1'b1;
      2'b01: n3037_o = 1'b0;
      default: n3037_o = 1'b0;
    endcase
  /* T80_MCode.vhd:700:25  */
  always @*
    case (n3027_o)
      2'b10: n3040_o = 3'b111;
      2'b01: n3040_o = 3'b010;
      default: n3040_o = 3'b111;
    endcase
  /* T80_MCode.vhd:690:17  */
  assign n3042_o = ir == 8'b10000110;
  /* T80_MCode.vhd:690:32  */
  assign n3044_o = ir == 8'b10001110;
  /* T80_MCode.vhd:690:32  */
  assign n3045_o = n3042_o | n3044_o;
  /* T80_MCode.vhd:690:43  */
  assign n3047_o = ir == 8'b10010110;
  /* T80_MCode.vhd:690:43  */
  assign n3048_o = n3045_o | n3047_o;
  /* T80_MCode.vhd:690:54  */
  assign n3050_o = ir == 8'b10011110;
  /* T80_MCode.vhd:690:54  */
  assign n3051_o = n3048_o | n3050_o;
  /* T80_MCode.vhd:690:65  */
  assign n3053_o = ir == 8'b10100110;
  /* T80_MCode.vhd:690:65  */
  assign n3054_o = n3051_o | n3053_o;
  /* T80_MCode.vhd:690:76  */
  assign n3056_o = ir == 8'b10101110;
  /* T80_MCode.vhd:690:76  */
  assign n3057_o = n3054_o | n3056_o;
  /* T80_MCode.vhd:690:87  */
  assign n3059_o = ir == 8'b10110110;
  /* T80_MCode.vhd:690:87  */
  assign n3060_o = n3057_o | n3059_o;
  /* T80_MCode.vhd:690:98  */
  assign n3062_o = ir == 8'b10111110;
  /* T80_MCode.vhd:690:98  */
  assign n3063_o = n3060_o | n3062_o;
  /* T80_MCode.vhd:720:35  */
  assign n3065_o = mcycle == 3'b010;
  /* T80_MCode.vhd:720:25  */
  assign n3069_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3072_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:720:25  */
  assign n3074_o = n3065_o ? 3'b111 : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3076_o = n3065_o ? n2173_o : 3'b000;
  /* T80_MCode.vhd:720:25  */
  assign n3079_o = n3065_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:710:17  */
  assign n3081_o = ir == 8'b11000110;
  /* T80_MCode.vhd:710:32  */
  assign n3083_o = ir == 8'b11001110;
  /* T80_MCode.vhd:710:32  */
  assign n3084_o = n3081_o | n3083_o;
  /* T80_MCode.vhd:710:43  */
  assign n3086_o = ir == 8'b11010110;
  /* T80_MCode.vhd:710:43  */
  assign n3087_o = n3084_o | n3086_o;
  /* T80_MCode.vhd:710:54  */
  assign n3089_o = ir == 8'b11011110;
  /* T80_MCode.vhd:710:54  */
  assign n3090_o = n3087_o | n3089_o;
  /* T80_MCode.vhd:710:65  */
  assign n3092_o = ir == 8'b11100110;
  /* T80_MCode.vhd:710:65  */
  assign n3093_o = n3090_o | n3092_o;
  /* T80_MCode.vhd:710:76  */
  assign n3095_o = ir == 8'b11101110;
  /* T80_MCode.vhd:710:76  */
  assign n3096_o = n3093_o | n3095_o;
  /* T80_MCode.vhd:710:87  */
  assign n3098_o = ir == 8'b11110110;
  /* T80_MCode.vhd:710:87  */
  assign n3099_o = n3096_o | n3098_o;
  /* T80_MCode.vhd:710:98  */
  assign n3101_o = ir == 8'b11111110;
  /* T80_MCode.vhd:710:98  */
  assign n3102_o = n3099_o | n3101_o;
  /* T80_MCode.vhd:727:17  */
  assign n3104_o = ir == 8'b00000100;
  /* T80_MCode.vhd:727:32  */
  assign n3106_o = ir == 8'b00001100;
  /* T80_MCode.vhd:727:32  */
  assign n3107_o = n3104_o | n3106_o;
  /* T80_MCode.vhd:727:43  */
  assign n3109_o = ir == 8'b00010100;
  /* T80_MCode.vhd:727:43  */
  assign n3110_o = n3107_o | n3109_o;
  /* T80_MCode.vhd:727:54  */
  assign n3112_o = ir == 8'b00011100;
  /* T80_MCode.vhd:727:54  */
  assign n3113_o = n3110_o | n3112_o;
  /* T80_MCode.vhd:727:65  */
  assign n3115_o = ir == 8'b00100100;
  /* T80_MCode.vhd:727:65  */
  assign n3116_o = n3113_o | n3115_o;
  /* T80_MCode.vhd:727:76  */
  assign n3118_o = ir == 8'b00101100;
  /* T80_MCode.vhd:727:76  */
  assign n3119_o = n3116_o | n3118_o;
  /* T80_MCode.vhd:727:87  */
  assign n3121_o = ir == 8'b00111100;
  /* T80_MCode.vhd:727:87  */
  assign n3122_o = n3119_o | n3121_o;
  /* T80_MCode.vhd:738:30  */
  assign n3123_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:739:25  */
  assign n3125_o = n3123_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:741:25  */
  assign n3127_o = n3123_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:750:25  */
  assign n3129_o = n3123_o == 31'b0000000000000000000000000000011;
  assign n3130_o = {n3129_o, n3127_o, n3125_o};
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3132_o = n2179_o;
      3'b010: n3132_o = 3'b100;
      3'b001: n3132_o = n2179_o;
      default: n3132_o = n2179_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3135_o = 1'b0;
      3'b010: n3135_o = 1'b1;
      3'b001: n3135_o = 1'b0;
      default: n3135_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3137_o = 3'b000;
      3'b010: n3137_o = n2172_o;
      3'b001: n3137_o = 3'b000;
      default: n3137_o = 3'b000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3140_o = 4'b0000;
      3'b010: n3140_o = 4'b1010;
      3'b001: n3140_o = 4'b0000;
      default: n3140_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3142_o = n2182_o;
      3'b010: n3142_o = 4'b0000;
      3'b001: n3142_o = n2182_o;
      default: n3142_o = n2182_o;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3145_o = 1'b0;
      3'b010: n3145_o = 1'b1;
      3'b001: n3145_o = 1'b0;
      default: n3145_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3148_o = 1'b0;
      3'b010: n3148_o = 1'b1;
      3'b001: n3148_o = 1'b0;
      default: n3148_o = 1'b0;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3152_o = 3'b111;
      3'b010: n3152_o = 3'b010;
      3'b001: n3152_o = 3'b010;
      default: n3152_o = 3'b111;
    endcase
  /* T80_MCode.vhd:738:25  */
  always @*
    case (n3130_o)
      3'b100: n3155_o = 1'b1;
      3'b010: n3155_o = 1'b0;
      3'b001: n3155_o = 1'b0;
      default: n3155_o = 1'b0;
    endcase
  /* T80_MCode.vhd:735:17  */
  assign n3157_o = ir == 8'b00110100;
  /* T80_MCode.vhd:754:17  */
  assign n3159_o = ir == 8'b00000101;
  /* T80_MCode.vhd:754:32  */
  assign n3161_o = ir == 8'b00001101;
  /* T80_MCode.vhd:754:32  */
  assign n3162_o = n3159_o | n3161_o;
  /* T80_MCode.vhd:754:43  */
  assign n3164_o = ir == 8'b00010101;
  /* T80_MCode.vhd:754:43  */
  assign n3165_o = n3162_o | n3164_o;
  /* T80_MCode.vhd:754:54  */
  assign n3167_o = ir == 8'b00011101;
  /* T80_MCode.vhd:754:54  */
  assign n3168_o = n3165_o | n3167_o;
  /* T80_MCode.vhd:754:65  */
  assign n3170_o = ir == 8'b00100101;
  /* T80_MCode.vhd:754:65  */
  assign n3171_o = n3168_o | n3170_o;
  /* T80_MCode.vhd:754:76  */
  assign n3173_o = ir == 8'b00101101;
  /* T80_MCode.vhd:754:76  */
  assign n3174_o = n3171_o | n3173_o;
  /* T80_MCode.vhd:754:87  */
  assign n3176_o = ir == 8'b00111101;
  /* T80_MCode.vhd:754:87  */
  assign n3177_o = n3174_o | n3176_o;
  /* T80_MCode.vhd:765:30  */
  assign n3178_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:766:25  */
  assign n3180_o = n3178_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:768:25  */
  assign n3182_o = n3178_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:777:25  */
  assign n3184_o = n3178_o == 31'b0000000000000000000000000000011;
  assign n3185_o = {n3184_o, n3182_o, n3180_o};
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3187_o = n2179_o;
      3'b010: n3187_o = 3'b100;
      3'b001: n3187_o = n2179_o;
      default: n3187_o = n2179_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3190_o = 1'b0;
      3'b010: n3190_o = 1'b1;
      3'b001: n3190_o = 1'b0;
      default: n3190_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3192_o = 3'b000;
      3'b010: n3192_o = n2172_o;
      3'b001: n3192_o = 3'b000;
      default: n3192_o = 3'b000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3195_o = 4'b0000;
      3'b010: n3195_o = 4'b1010;
      3'b001: n3195_o = 4'b0000;
      default: n3195_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3197_o = n2182_o;
      3'b010: n3197_o = 4'b0010;
      3'b001: n3197_o = n2182_o;
      default: n3197_o = n2182_o;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3200_o = 1'b0;
      3'b010: n3200_o = 1'b1;
      3'b001: n3200_o = 1'b0;
      default: n3200_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3203_o = 1'b0;
      3'b010: n3203_o = 1'b1;
      3'b001: n3203_o = 1'b0;
      default: n3203_o = 1'b0;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3207_o = 3'b111;
      3'b010: n3207_o = 3'b010;
      3'b001: n3207_o = 3'b010;
      default: n3207_o = 3'b111;
    endcase
  /* T80_MCode.vhd:765:25  */
  always @*
    case (n3185_o)
      3'b100: n3210_o = 1'b1;
      3'b010: n3210_o = 1'b0;
      3'b001: n3210_o = 1'b0;
      default: n3210_o = 1'b0;
    endcase
  /* T80_MCode.vhd:762:17  */
  assign n3212_o = ir == 8'b00110101;
  /* T80_MCode.vhd:783:17  */
  assign n3215_o = ir == 8'b00100111;
  /* T80_MCode.vhd:789:17  */
  assign n3217_o = ir == 8'b00101111;
  /* T80_MCode.vhd:792:17  */
  assign n3219_o = ir == 8'b00111111;
  /* T80_MCode.vhd:795:17  */
  assign n3221_o = ir == 8'b00110111;
  /* T80_MCode.vhd:802:38  */
  assign n3222_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:803:33  */
  assign n3224_o = n3222_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:808:33  */
  assign n3226_o = n3222_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:813:33  */
  assign n3228_o = n3222_o == 31'b0000000000000000000000000000011;
  assign n3229_o = {n3228_o, n3226_o, n3224_o};
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3231_o = n2179_o;
      3'b010: n3231_o = n2179_o;
      3'b001: n3231_o = 3'b101;
      default: n3231_o = n2179_o;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3235_o = 4'b0000;
      3'b010: n3235_o = 4'b1111;
      3'b001: n3235_o = 4'b1111;
      default: n3235_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3239_o = 4'b0000;
      3'b010: n3239_o = 4'b1100;
      3'b001: n3239_o = 4'b1101;
      default: n3239_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3243_o = 3'b111;
      3'b010: n3243_o = 3'b101;
      3'b001: n3243_o = 3'b101;
      default: n3243_o = 3'b111;
    endcase
  /* T80_MCode.vhd:802:33  */
  always @*
    case (n3229_o)
      3'b100: n3247_o = 1'b1;
      3'b010: n3247_o = 1'b1;
      3'b001: n3247_o = 1'b0;
      default: n3247_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:38  */
  assign n3248_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:821:33  */
  assign n3250_o = n3248_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:827:33  */
  assign n3252_o = n3248_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:833:33  */
  assign n3254_o = n3248_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:836:33  */
  assign n3256_o = n3248_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:839:33  */
  assign n3258_o = n3248_o == 31'b0000000000000000000000000000101;
  assign n3259_o = {n3258_o, n3256_o, n3254_o, n3252_o, n3250_o};
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3261_o = n2179_o;
      5'b01000: n3261_o = n2179_o;
      5'b00100: n3261_o = n2179_o;
      5'b00010: n3261_o = n2179_o;
      5'b00001: n3261_o = 3'b101;
      default: n3261_o = n2179_o;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3264_o = 1'b0;
      5'b01000: n3264_o = 1'b1;
      5'b00100: n3264_o = 1'b0;
      5'b00010: n3264_o = 1'b0;
      5'b00001: n3264_o = 1'b0;
      default: n3264_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3268_o = 4'b0000;
      5'b01000: n3268_o = 4'b0000;
      5'b00100: n3268_o = 4'b0000;
      5'b00010: n3268_o = 4'b1111;
      5'b00001: n3268_o = 4'b1111;
      default: n3268_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3272_o = 4'b0000;
      5'b01000: n3272_o = 4'b0000;
      5'b00100: n3272_o = 4'b0000;
      5'b00010: n3272_o = 4'b1100;
      5'b00001: n3272_o = 4'b1101;
      default: n3272_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3276_o = 3'b111;
      5'b01000: n3276_o = 3'b111;
      5'b00100: n3276_o = 3'b111;
      5'b00010: n3276_o = 3'b101;
      5'b00001: n3276_o = 3'b101;
      default: n3276_o = 3'b111;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3279_o = 1'b1;
      5'b01000: n3279_o = 1'b0;
      5'b00100: n3279_o = 1'b0;
      5'b00010: n3279_o = 1'b0;
      5'b00001: n3279_o = 1'b0;
      default: n3279_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3283_o = 1'b0;
      5'b01000: n3283_o = 1'b1;
      5'b00100: n3283_o = 1'b0;
      5'b00010: n3283_o = 1'b0;
      5'b00001: n3283_o = 1'b1;
      default: n3283_o = 1'b0;
    endcase
  /* T80_MCode.vhd:820:33  */
  always @*
    case (n3259_o)
      5'b10000: n3287_o = 1'b0;
      5'b01000: n3287_o = 1'b0;
      5'b00100: n3287_o = 1'b1;
      5'b00010: n3287_o = 1'b1;
      5'b00001: n3287_o = 1'b0;
      default: n3287_o = 1'b0;
    endcase
  /* T80_MCode.vhd:817:25  */
  assign n3290_o = intcycle ? 3'b101 : 3'b001;
  /* T80_MCode.vhd:817:25  */
  assign n3291_o = intcycle ? n3261_o : n2179_o;
  /* T80_MCode.vhd:817:25  */
  assign n3293_o = intcycle ? n3264_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3295_o = intcycle ? n3268_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3297_o = intcycle ? n3272_o : 4'b0000;
  /* T80_MCode.vhd:817:25  */
  assign n3299_o = intcycle ? n3276_o : 3'b111;
  /* T80_MCode.vhd:817:25  */
  assign n3301_o = intcycle ? n3279_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3303_o = intcycle ? n3283_o : 1'b0;
  /* T80_MCode.vhd:817:25  */
  assign n3305_o = intcycle ? n3287_o : 1'b0;
  /* T80_MCode.vhd:799:25  */
  assign n3307_o = nmicycle ? 3'b011 : n3290_o;
  /* T80_MCode.vhd:799:25  */
  assign n3308_o = nmicycle ? n3231_o : n3291_o;
  /* T80_MCode.vhd:799:25  */
  assign n3310_o = nmicycle ? 1'b0 : n3293_o;
  /* T80_MCode.vhd:799:25  */
  assign n3311_o = nmicycle ? n3235_o : n3295_o;
  /* T80_MCode.vhd:799:25  */
  assign n3312_o = nmicycle ? n3239_o : n3297_o;
  /* T80_MCode.vhd:799:25  */
  assign n3313_o = nmicycle ? n3243_o : n3299_o;
  /* T80_MCode.vhd:799:25  */
  assign n3315_o = nmicycle ? 1'b0 : n3301_o;
  /* T80_MCode.vhd:799:25  */
  assign n3317_o = nmicycle ? 1'b0 : n3303_o;
  /* T80_MCode.vhd:799:25  */
  assign n3318_o = nmicycle ? n3247_o : n3305_o;
  /* T80_MCode.vhd:798:17  */
  assign n3320_o = ir == 8'b00000000;
  /* T80_MCode.vhd:846:17  */
  assign n3322_o = ir == 8'b01110110;
  /* T80_MCode.vhd:849:17  */
  assign n3324_o = ir == 8'b11110011;
  /* T80_MCode.vhd:852:17  */
  assign n3326_o = ir == 8'b11111011;
  /* T80_MCode.vhd:860:30  */
  assign n3327_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:867:60  */
  assign n3329_o = ir[5:4];
  /* T80_MCode.vhd:867:38  */
  assign n3330_o = {29'b0, n3329_o};  //  uext
  /* T80_MCode.vhd:869:70  */
  assign n3331_o = ir[5:4];
  /* T80_MCode.vhd:868:33  */
  assign n3334_o = n3330_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:868:39  */
  assign n3336_o = n3330_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:868:39  */
  assign n3337_o = n3334_o | n3336_o;
  /* T80_MCode.vhd:868:41  */
  assign n3339_o = n3330_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:868:41  */
  assign n3340_o = n3337_o | n3339_o;
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3342_o = 1'b1;
      default: n3342_o = 1'b0;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3344_o = n3331_o;
      default: n3344_o = 2'b00;
    endcase
  /* T80_MCode.vhd:867:33  */
  always @*
    case (n3340_o)
      1'b1: n3347_o = 1'b0;
      default: n3347_o = 1'b1;
    endcase
  /* T80_MCode.vhd:861:25  */
  assign n3349_o = n3327_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:883:60  */
  assign n3351_o = ir[5:4];
  /* T80_MCode.vhd:883:38  */
  assign n3352_o = {29'b0, n3351_o};  //  uext
  /* T80_MCode.vhd:885:70  */
  assign n3353_o = ir[5:4];
  /* T80_MCode.vhd:884:33  */
  assign n3355_o = n3352_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:884:39  */
  assign n3357_o = n3352_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:884:39  */
  assign n3358_o = n3355_o | n3357_o;
  /* T80_MCode.vhd:884:41  */
  assign n3360_o = n3352_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:884:41  */
  assign n3361_o = n3358_o | n3360_o;
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3364_o = 1'b0;
      default: n3364_o = 1'b1;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3366_o = n3353_o;
      default: n3366_o = 2'b00;
    endcase
  /* T80_MCode.vhd:883:33  */
  always @*
    case (n3361_o)
      1'b1: n3369_o = 1'b0;
      default: n3369_o = 1'b1;
    endcase
  /* T80_MCode.vhd:877:25  */
  assign n3371_o = n3327_o == 31'b0000000000000000000000000000011;
  assign n3372_o = {n3371_o, n3349_o};
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3374_o = n2179_o;
      2'b01: n3374_o = 3'b100;
      default: n3374_o = n2179_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3378_o = 1'b1;
      2'b01: n3378_o = 1'b1;
      default: n3378_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3380_o = 3'b100;
      2'b01: n3380_o = 3'b101;
      default: n3380_o = 3'b000;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3382_o = n3364_o;
      2'b01: n3382_o = n3342_o;
      default: n3382_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3384_o = n3366_o;
      2'b01: n3384_o = n3344_o;
      default: n3384_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3386_o = n3369_o;
      2'b01: n3386_o = n3347_o;
      default: n3386_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3389_o = 4'b0001;
      2'b01: n3389_o = 4'b0000;
      default: n3389_o = n2182_o;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3393_o = 1'b1;
      2'b01: n3393_o = 1'b1;
      default: n3393_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3397_o = 1'b1;
      2'b01: n3397_o = 1'b1;
      default: n3397_o = 1'b0;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3400_o = 2'b00;
      2'b01: n3400_o = 2'b11;
      default: n3400_o = 2'b00;
    endcase
  /* T80_MCode.vhd:860:25  */
  always @*
    case (n3372_o)
      2'b10: n3404_o = 1'b1;
      2'b01: n3404_o = 1'b1;
      default: n3404_o = 1'b0;
    endcase
  /* T80_MCode.vhd:857:17  */
  assign n3406_o = ir == 8'b00001001;
  /* T80_MCode.vhd:857:32  */
  assign n3408_o = ir == 8'b00011001;
  /* T80_MCode.vhd:857:32  */
  assign n3409_o = n3406_o | n3408_o;
  /* T80_MCode.vhd:857:43  */
  assign n3411_o = ir == 8'b00101001;
  /* T80_MCode.vhd:857:43  */
  assign n3412_o = n3409_o | n3411_o;
  /* T80_MCode.vhd:857:54  */
  assign n3414_o = ir == 8'b00111001;
  /* T80_MCode.vhd:857:54  */
  assign n3415_o = n3412_o | n3414_o;
  /* T80_MCode.vhd:892:17  */
  assign n3418_o = ir == 8'b00000011;
  /* T80_MCode.vhd:892:32  */
  assign n3420_o = ir == 8'b00010011;
  /* T80_MCode.vhd:892:32  */
  assign n3421_o = n3418_o | n3420_o;
  /* T80_MCode.vhd:892:43  */
  assign n3423_o = ir == 8'b00100011;
  /* T80_MCode.vhd:892:43  */
  assign n3424_o = n3421_o | n3423_o;
  /* T80_MCode.vhd:892:54  */
  assign n3426_o = ir == 8'b00110011;
  /* T80_MCode.vhd:892:54  */
  assign n3427_o = n3424_o | n3426_o;
  /* T80_MCode.vhd:897:17  */
  assign n3430_o = ir == 8'b00001011;
  /* T80_MCode.vhd:897:32  */
  assign n3432_o = ir == 8'b00011011;
  /* T80_MCode.vhd:897:32  */
  assign n3433_o = n3430_o | n3432_o;
  /* T80_MCode.vhd:897:43  */
  assign n3435_o = ir == 8'b00101011;
  /* T80_MCode.vhd:897:43  */
  assign n3436_o = n3433_o | n3435_o;
  /* T80_MCode.vhd:897:54  */
  assign n3438_o = ir == 8'b00111011;
  /* T80_MCode.vhd:897:54  */
  assign n3439_o = n3436_o | n3438_o;
  /* T80_MCode.vhd:904:17  */
  assign n3442_o = ir == 8'b00000111;
  /* T80_MCode.vhd:906:25  */
  assign n3444_o = ir == 8'b00010111;
  /* T80_MCode.vhd:906:25  */
  assign n3445_o = n3442_o | n3444_o;
  /* T80_MCode.vhd:908:25  */
  assign n3447_o = ir == 8'b00001111;
  /* T80_MCode.vhd:908:25  */
  assign n3448_o = n3445_o | n3447_o;
  /* T80_MCode.vhd:910:25  */
  assign n3450_o = ir == 8'b00011111;
  /* T80_MCode.vhd:910:25  */
  assign n3451_o = n3448_o | n3450_o;
  /* T80_MCode.vhd:921:30  */
  assign n3452_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:922:25  */
  assign n3454_o = n3452_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:925:25  */
  assign n3456_o = n3452_o == 31'b0000000000000000000000000000011;
  assign n3457_o = {n3456_o, n3454_o};
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3461_o = 1'b1;
      2'b01: n3461_o = 1'b1;
      default: n3461_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3464_o = 1'b1;
      2'b01: n3464_o = 1'b0;
      default: n3464_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3467_o = 1'b0;
      2'b01: n3467_o = 1'b1;
      default: n3467_o = 1'b0;
    endcase
  /* T80_MCode.vhd:921:25  */
  always @*
    case (n3457_o)
      2'b10: n3470_o = 1'b1;
      2'b01: n3470_o = 1'b0;
      default: n3470_o = 1'b0;
    endcase
  /* T80_MCode.vhd:918:17  */
  assign n3472_o = ir == 8'b11000011;
  /* T80_MCode.vhd:990:38  */
  assign n3474_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:991:33  */
  assign n3476_o = n3474_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:997:73  */
  assign n3478_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3483_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3484_o = ~n3483_o;
  /* T80_MCode.vhd:178:25  */
  assign n3486_o = n3478_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3487_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3489_o = n3478_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3490_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3491_o = ~n3490_o;
  /* T80_MCode.vhd:180:25  */
  assign n3493_o = n3478_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3494_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3496_o = n3478_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3497_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3498_o = ~n3497_o;
  /* T80_MCode.vhd:182:25  */
  assign n3500_o = n3478_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3501_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3503_o = n3478_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3504_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3505_o = ~n3504_o;
  /* T80_MCode.vhd:184:25  */
  assign n3507_o = n3478_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3508_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3510_o = n3478_o == 3'b111;
  assign n3511_o = {n3510_o, n3507_o, n3503_o, n3500_o, n3496_o, n3493_o, n3489_o, n3486_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3511_o)
      8'b10000000: n3513_o = n3508_o;
      8'b01000000: n3513_o = n3505_o;
      8'b00100000: n3513_o = n3501_o;
      8'b00010000: n3513_o = n3498_o;
      8'b00001000: n3513_o = n3494_o;
      8'b00000100: n3513_o = n3491_o;
      8'b00000010: n3513_o = n3487_o;
      8'b00000001: n3513_o = n3484_o;
      default: n3513_o = 1'bX;
    endcase
  /* T80_MCode.vhd:997:41  */
  assign n3516_o = n3513_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:994:33  */
  assign n3518_o = n3474_o == 31'b0000000000000000000000000000011;
  assign n3519_o = {n3518_o, n3476_o};
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3523_o = 1'b1;
      2'b01: n3523_o = 1'b1;
      default: n3523_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3525_o = n3516_o;
      2'b01: n3525_o = 1'b0;
      default: n3525_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3528_o = 1'b0;
      2'b01: n3528_o = 1'b1;
      default: n3528_o = 1'b0;
    endcase
  /* T80_MCode.vhd:990:33  */
  always @*
    case (n3519_o)
      2'b10: n3531_o = 1'b1;
      2'b01: n3531_o = 1'b0;
      default: n3531_o = 1'b0;
    endcase
  /* T80_MCode.vhd:931:17  */
  assign n3533_o = ir == 8'b11000010;
  /* T80_MCode.vhd:931:32  */
  assign n3535_o = ir == 8'b11001010;
  /* T80_MCode.vhd:931:32  */
  assign n3536_o = n3533_o | n3535_o;
  /* T80_MCode.vhd:931:43  */
  assign n3538_o = ir == 8'b11010010;
  /* T80_MCode.vhd:931:43  */
  assign n3539_o = n3536_o | n3538_o;
  /* T80_MCode.vhd:931:54  */
  assign n3541_o = ir == 8'b11011010;
  /* T80_MCode.vhd:931:54  */
  assign n3542_o = n3539_o | n3541_o;
  /* T80_MCode.vhd:931:65  */
  assign n3544_o = ir == 8'b11100010;
  /* T80_MCode.vhd:931:65  */
  assign n3545_o = n3542_o | n3544_o;
  /* T80_MCode.vhd:931:76  */
  assign n3547_o = ir == 8'b11101010;
  /* T80_MCode.vhd:931:76  */
  assign n3548_o = n3545_o | n3547_o;
  /* T80_MCode.vhd:931:87  */
  assign n3550_o = ir == 8'b11110010;
  /* T80_MCode.vhd:931:87  */
  assign n3551_o = n3548_o | n3550_o;
  /* T80_MCode.vhd:931:98  */
  assign n3553_o = ir == 8'b11111010;
  /* T80_MCode.vhd:931:98  */
  assign n3554_o = n3551_o | n3553_o;
  /* T80_MCode.vhd:1003:17  */
  assign n3556_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1017:17  */
  assign n3558_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1034:17  */
  assign n3560_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1051:17  */
  assign n3562_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1068:17  */
  assign n3564_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1085:17  */
  assign n3566_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1088:17  */
  assign n3568_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1118:30  */
  assign n3569_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1119:25  */
  assign n3571_o = n3569_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1122:25  */
  assign n3573_o = n3569_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1129:25  */
  assign n3575_o = n3569_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1134:25  */
  assign n3577_o = n3569_o == 31'b0000000000000000000000000000101;
  assign n3578_o = {n3577_o, n3575_o, n3573_o, n3571_o};
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3580_o = n2179_o;
      4'b0100: n3580_o = n2179_o;
      4'b0010: n3580_o = 3'b100;
      4'b0001: n3580_o = n2179_o;
      default: n3580_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3584_o = 1'b0;
      4'b0100: n3584_o = 1'b0;
      4'b0010: n3584_o = 1'b1;
      4'b0001: n3584_o = 1'b1;
      default: n3584_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3588_o = 4'b0000;
      4'b0100: n3588_o = 4'b1111;
      4'b0010: n3588_o = 4'b1111;
      4'b0001: n3588_o = 4'b0000;
      default: n3588_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3592_o = 4'b0000;
      4'b0100: n3592_o = 4'b1100;
      4'b0010: n3592_o = 4'b1101;
      4'b0001: n3592_o = 4'b0000;
      default: n3592_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3596_o = 3'b111;
      4'b0100: n3596_o = 3'b101;
      4'b0010: n3596_o = 3'b101;
      4'b0001: n3596_o = 3'b111;
      default: n3596_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3599_o = 1'b1;
      4'b0100: n3599_o = 1'b0;
      4'b0010: n3599_o = 1'b0;
      4'b0001: n3599_o = 1'b0;
      default: n3599_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3602_o = 1'b0;
      4'b0100: n3602_o = 1'b0;
      4'b0010: n3602_o = 1'b0;
      4'b0001: n3602_o = 1'b1;
      default: n3602_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3605_o = 1'b0;
      4'b0100: n3605_o = 1'b0;
      4'b0010: n3605_o = 1'b1;
      4'b0001: n3605_o = 1'b0;
      default: n3605_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1118:25  */
  always @*
    case (n3578_o)
      4'b1000: n3609_o = 1'b1;
      4'b0100: n3609_o = 1'b1;
      4'b0010: n3609_o = 1'b0;
      4'b0001: n3609_o = 1'b0;
      default: n3609_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1115:17  */
  assign n3611_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1143:38  */
  assign n3614_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1144:33  */
  assign n3616_o = n3614_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1150:73  */
  assign n3618_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3623_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3624_o = ~n3623_o;
  /* T80_MCode.vhd:178:25  */
  assign n3626_o = n3618_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3627_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3629_o = n3618_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3630_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3631_o = ~n3630_o;
  /* T80_MCode.vhd:180:25  */
  assign n3633_o = n3618_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3634_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3636_o = n3618_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3637_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3638_o = ~n3637_o;
  /* T80_MCode.vhd:182:25  */
  assign n3640_o = n3618_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3641_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3643_o = n3618_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3644_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3645_o = ~n3644_o;
  /* T80_MCode.vhd:184:25  */
  assign n3647_o = n3618_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3648_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3650_o = n3618_o == 3'b111;
  assign n3651_o = {n3650_o, n3647_o, n3643_o, n3640_o, n3636_o, n3633_o, n3629_o, n3626_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3651_o)
      8'b10000000: n3653_o = n3648_o;
      8'b01000000: n3653_o = n3645_o;
      8'b00100000: n3653_o = n3641_o;
      8'b00010000: n3653_o = n3638_o;
      8'b00001000: n3653_o = n3634_o;
      8'b00000100: n3653_o = n3631_o;
      8'b00000010: n3653_o = n3627_o;
      8'b00000001: n3653_o = n3624_o;
      default: n3653_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1150:41  */
  assign n3656_o = n3653_o ? 3'b101 : 3'b011;
  /* T80_MCode.vhd:1150:41  */
  assign n3658_o = n3653_o ? 3'b100 : n2179_o;
  /* T80_MCode.vhd:1150:41  */
  assign n3661_o = n3653_o ? 4'b1111 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3664_o = n3653_o ? 4'b1101 : 4'b0000;
  /* T80_MCode.vhd:1150:41  */
  assign n3667_o = n3653_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1147:33  */
  assign n3669_o = n3614_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1158:33  */
  assign n3671_o = n3614_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1163:33  */
  assign n3673_o = n3614_o == 31'b0000000000000000000000000000101;
  assign n3674_o = {n3673_o, n3671_o, n3669_o, n3616_o};
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3676_o = 3'b101;
      4'b0100: n3676_o = 3'b101;
      4'b0010: n3676_o = n3656_o;
      4'b0001: n3676_o = 3'b101;
      default: n3676_o = 3'b101;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3678_o = n2179_o;
      4'b0100: n3678_o = n2179_o;
      4'b0010: n3678_o = n3658_o;
      4'b0001: n3678_o = n2179_o;
      default: n3678_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3682_o = 1'b0;
      4'b0100: n3682_o = 1'b0;
      4'b0010: n3682_o = 1'b1;
      4'b0001: n3682_o = 1'b1;
      default: n3682_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3685_o = 4'b0000;
      4'b0100: n3685_o = 4'b1111;
      4'b0010: n3685_o = n3661_o;
      4'b0001: n3685_o = 4'b0000;
      default: n3685_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3688_o = 4'b0000;
      4'b0100: n3688_o = 4'b1100;
      4'b0010: n3688_o = n3664_o;
      4'b0001: n3688_o = 4'b0000;
      default: n3688_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3691_o = 3'b111;
      4'b0100: n3691_o = 3'b101;
      4'b0010: n3691_o = n3667_o;
      4'b0001: n3691_o = 3'b111;
      default: n3691_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3694_o = 1'b1;
      4'b0100: n3694_o = 1'b0;
      4'b0010: n3694_o = 1'b0;
      4'b0001: n3694_o = 1'b0;
      default: n3694_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3697_o = 1'b0;
      4'b0100: n3697_o = 1'b0;
      4'b0010: n3697_o = 1'b0;
      4'b0001: n3697_o = 1'b1;
      default: n3697_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3700_o = 1'b0;
      4'b0100: n3700_o = 1'b0;
      4'b0010: n3700_o = 1'b1;
      4'b0001: n3700_o = 1'b0;
      default: n3700_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1143:33  */
  always @*
    case (n3674_o)
      4'b1000: n3704_o = 1'b1;
      4'b0100: n3704_o = 1'b1;
      4'b0010: n3704_o = 1'b0;
      4'b0001: n3704_o = 1'b0;
      default: n3704_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1139:17  */
  assign n3706_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1139:32  */
  assign n3708_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1139:32  */
  assign n3709_o = n3706_o | n3708_o;
  /* T80_MCode.vhd:1139:43  */
  assign n3711_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1139:43  */
  assign n3712_o = n3709_o | n3711_o;
  /* T80_MCode.vhd:1139:54  */
  assign n3714_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1139:54  */
  assign n3715_o = n3712_o | n3714_o;
  /* T80_MCode.vhd:1139:65  */
  assign n3717_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1139:65  */
  assign n3718_o = n3715_o | n3717_o;
  /* T80_MCode.vhd:1139:76  */
  assign n3720_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1139:76  */
  assign n3721_o = n3718_o | n3720_o;
  /* T80_MCode.vhd:1139:87  */
  assign n3723_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1139:87  */
  assign n3724_o = n3721_o | n3723_o;
  /* T80_MCode.vhd:1139:98  */
  assign n3726_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1139:98  */
  assign n3727_o = n3724_o | n3726_o;
  /* T80_MCode.vhd:1172:30  */
  assign n3728_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1173:25  */
  assign n3730_o = n3728_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1176:25  */
  assign n3732_o = n3728_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1180:25  */
  assign n3734_o = n3728_o == 31'b0000000000000000000000000000011;
  assign n3735_o = {n3734_o, n3732_o, n3730_o};
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3739_o = 4'b0111;
      3'b010: n3739_o = 4'b0111;
      3'b001: n3739_o = 4'b0000;
      default: n3739_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3743_o = 3'b111;
      3'b010: n3743_o = 3'b101;
      3'b001: n3743_o = 3'b101;
      default: n3743_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3746_o = 1'b1;
      3'b010: n3746_o = 1'b0;
      3'b001: n3746_o = 1'b0;
      default: n3746_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1172:25  */
  always @*
    case (n3735_o)
      3'b100: n3749_o = 1'b0;
      3'b010: n3749_o = 1'b1;
      3'b001: n3749_o = 1'b0;
      default: n3749_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1169:17  */
  assign n3751_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1256:38  */
  assign n3753_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1258:73  */
  assign n3755_o = ir[5:3];
  /* T80_MCode.vhd:178:47  */
  assign n3760_o = f[6];
  /* T80_MCode.vhd:178:56  */
  assign n3761_o = ~n3760_o;
  /* T80_MCode.vhd:178:25  */
  assign n3763_o = n3755_o == 3'b000;
  /* T80_MCode.vhd:179:47  */
  assign n3764_o = f[6];
  /* T80_MCode.vhd:179:25  */
  assign n3766_o = n3755_o == 3'b001;
  /* T80_MCode.vhd:180:47  */
  assign n3767_o = f[0];
  /* T80_MCode.vhd:180:56  */
  assign n3768_o = ~n3767_o;
  /* T80_MCode.vhd:180:25  */
  assign n3770_o = n3755_o == 3'b010;
  /* T80_MCode.vhd:181:47  */
  assign n3771_o = f[0];
  /* T80_MCode.vhd:181:25  */
  assign n3773_o = n3755_o == 3'b011;
  /* T80_MCode.vhd:182:47  */
  assign n3774_o = f[2];
  /* T80_MCode.vhd:182:56  */
  assign n3775_o = ~n3774_o;
  /* T80_MCode.vhd:182:25  */
  assign n3777_o = n3755_o == 3'b100;
  /* T80_MCode.vhd:183:47  */
  assign n3778_o = f[2];
  /* T80_MCode.vhd:183:25  */
  assign n3780_o = n3755_o == 3'b101;
  /* T80_MCode.vhd:184:47  */
  assign n3781_o = f[7];
  /* T80_MCode.vhd:184:56  */
  assign n3782_o = ~n3781_o;
  /* T80_MCode.vhd:184:25  */
  assign n3784_o = n3755_o == 3'b110;
  /* T80_MCode.vhd:185:47  */
  assign n3785_o = f[7];
  /* T80_MCode.vhd:185:25  */
  assign n3787_o = n3755_o == 3'b111;
  assign n3788_o = {n3787_o, n3784_o, n3780_o, n3777_o, n3773_o, n3770_o, n3766_o, n3763_o};
  /* T80_MCode.vhd:177:25  */
  always @*
    case (n3788_o)
      8'b10000000: n3790_o = n3785_o;
      8'b01000000: n3790_o = n3782_o;
      8'b00100000: n3790_o = n3778_o;
      8'b00010000: n3790_o = n3775_o;
      8'b00001000: n3790_o = n3771_o;
      8'b00000100: n3790_o = n3768_o;
      8'b00000010: n3790_o = n3764_o;
      8'b00000001: n3790_o = n3761_o;
      default: n3790_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1258:41  */
  assign n3793_o = n3790_o ? 3'b011 : 3'b001;
  /* T80_MCode.vhd:1258:41  */
  assign n3796_o = n3790_o ? 3'b101 : 3'b111;
  /* T80_MCode.vhd:1257:33  */
  assign n3798_o = n3753_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1264:33  */
  assign n3800_o = n3753_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1268:33  */
  assign n3802_o = n3753_o == 31'b0000000000000000000000000000011;
  assign n3803_o = {n3802_o, n3800_o, n3798_o};
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3805_o = 3'b011;
      3'b010: n3805_o = 3'b011;
      3'b001: n3805_o = n3793_o;
      default: n3805_o = 3'b011;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3808_o = n2179_o;
      3'b010: n3808_o = n2179_o;
      3'b001: n3808_o = 3'b101;
      default: n3808_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3812_o = 4'b0111;
      3'b010: n3812_o = 4'b0111;
      3'b001: n3812_o = 4'b0000;
      default: n3812_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3815_o = 3'b111;
      3'b010: n3815_o = 3'b101;
      3'b001: n3815_o = n3796_o;
      default: n3815_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3818_o = 1'b1;
      3'b010: n3818_o = 1'b0;
      3'b001: n3818_o = 1'b0;
      default: n3818_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1256:33  */
  always @*
    case (n3803_o)
      3'b100: n3821_o = 1'b0;
      3'b010: n3821_o = 1'b1;
      3'b001: n3821_o = 1'b0;
      default: n3821_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1185:17  */
  assign n3823_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1185:32  */
  assign n3825_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1185:32  */
  assign n3826_o = n3823_o | n3825_o;
  /* T80_MCode.vhd:1185:43  */
  assign n3828_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1185:43  */
  assign n3829_o = n3826_o | n3828_o;
  /* T80_MCode.vhd:1185:54  */
  assign n3831_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1185:54  */
  assign n3832_o = n3829_o | n3831_o;
  /* T80_MCode.vhd:1185:65  */
  assign n3834_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1185:65  */
  assign n3835_o = n3832_o | n3834_o;
  /* T80_MCode.vhd:1185:76  */
  assign n3837_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1185:76  */
  assign n3838_o = n3835_o | n3837_o;
  /* T80_MCode.vhd:1185:87  */
  assign n3840_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1185:87  */
  assign n3841_o = n3838_o | n3840_o;
  /* T80_MCode.vhd:1185:98  */
  assign n3843_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1185:98  */
  assign n3844_o = n3841_o | n3843_o;
  /* T80_MCode.vhd:1277:30  */
  assign n3845_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1278:25  */
  assign n3847_o = n3845_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1283:25  */
  assign n3849_o = n3845_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1288:25  */
  assign n3851_o = n3845_o == 31'b0000000000000000000000000000011;
  assign n3852_o = {n3851_o, n3849_o, n3847_o};
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3854_o = n2179_o;
      3'b010: n3854_o = n2179_o;
      3'b001: n3854_o = 3'b101;
      default: n3854_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3858_o = 4'b0000;
      3'b010: n3858_o = 4'b1111;
      3'b001: n3858_o = 4'b1111;
      default: n3858_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3862_o = 4'b0000;
      3'b010: n3862_o = 4'b1100;
      3'b001: n3862_o = 4'b1101;
      default: n3862_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3866_o = 3'b111;
      3'b010: n3866_o = 3'b101;
      3'b001: n3866_o = 3'b101;
      default: n3866_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3869_o = 1'b1;
      3'b010: n3869_o = 1'b0;
      3'b001: n3869_o = 1'b0;
      default: n3869_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1277:25  */
  always @*
    case (n3852_o)
      3'b100: n3873_o = 1'b1;
      3'b010: n3873_o = 1'b1;
      3'b001: n3873_o = 1'b0;
      default: n3873_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1274:17  */
  assign n3875_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1274:32  */
  assign n3877_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1274:32  */
  assign n3878_o = n3875_o | n3877_o;
  /* T80_MCode.vhd:1274:43  */
  assign n3880_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1274:43  */
  assign n3881_o = n3878_o | n3880_o;
  /* T80_MCode.vhd:1274:54  */
  assign n3883_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1274:54  */
  assign n3884_o = n3881_o | n3883_o;
  /* T80_MCode.vhd:1274:65  */
  assign n3886_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1274:65  */
  assign n3887_o = n3884_o | n3886_o;
  /* T80_MCode.vhd:1274:76  */
  assign n3889_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1274:76  */
  assign n3890_o = n3887_o | n3889_o;
  /* T80_MCode.vhd:1274:87  */
  assign n3892_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1274:87  */
  assign n3893_o = n3890_o | n3892_o;
  /* T80_MCode.vhd:1274:98  */
  assign n3895_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1274:98  */
  assign n3896_o = n3893_o | n3895_o;
  /* T80_MCode.vhd:1299:38  */
  assign n3897_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1300:33  */
  assign n3899_o = n3897_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1303:33  */
  assign n3901_o = n3897_o == 31'b0000000000000000000000000000011;
  assign n3902_o = {n3901_o, n3899_o};
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3905_o = 1'b0;
      2'b01: n3905_o = 1'b1;
      default: n3905_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3908_o = 1'b1;
      2'b01: n3908_o = 1'b0;
      default: n3908_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3911_o = 3'b111;
      2'b01: n3911_o = 3'b100;
      default: n3911_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1299:33  */
  always @*
    case (n3902_o)
      2'b10: n3914_o = 1'b1;
      2'b01: n3914_o = 1'b0;
      default: n3914_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1295:17  */
  assign n3916_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1313:38  */
  assign n3917_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1314:33  */
  assign n3919_o = n3917_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1318:33  */
  assign n3921_o = n3917_o == 31'b0000000000000000000000000000011;
  assign n3922_o = {n3921_o, n3919_o};
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3925_o = 1'b0;
      2'b01: n3925_o = 1'b1;
      default: n3925_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3928_o = 4'b0000;
      2'b01: n3928_o = 4'b0111;
      default: n3928_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3931_o = 3'b111;
      2'b01: n3931_o = 3'b100;
      default: n3931_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3934_o = 1'b1;
      2'b01: n3934_o = 1'b0;
      default: n3934_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1313:33  */
  always @*
    case (n3922_o)
      2'b10: n3937_o = 1'b1;
      2'b01: n3937_o = 1'b0;
      default: n3937_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1309:17  */
  assign n3939_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1331:17  */
  assign n3941_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1336:17  */
  assign n3943_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1341:17  */
  assign n3945_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1341:32  */
  assign n3947_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1341:32  */
  assign n3948_o = n3945_o | n3947_o;
  assign n3949_o = {n3948_o, n3943_o, n3941_o, n3939_o, n3916_o, n3896_o, n3844_o, n3751_o, n3727_o, n3611_o, n3568_o, n3566_o, n3564_o, n3562_o, n3560_o, n3558_o, n3556_o, n3554_o, n3472_o, n3451_o, n3439_o, n3427_o, n3415_o, n3326_o, n3324_o, n3322_o, n3320_o, n3221_o, n3219_o, n3217_o, n3215_o, n3212_o, n3177_o, n3157_o, n3122_o, n3102_o, n3063_o, n3020_o, n2852_o, n2803_o, n2801_o, n2799_o, n2797_o, n2744_o, n2695_o, n2693_o, n2656_o, n2619_o, n2572_o, n2543_o, n2523_o, n2503_o, n2480_o, n2466_o, n2452_o, n2430_o, n2393_o, n2359_o, n2328_o};
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b01000000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00100000000000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00010000000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00001000000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000100000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000010000000000000000000000000000000000000000000000000000: n3980_o = n3805_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000100000000000000000000000000000000000000000000000000: n3980_o = n3676_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3980_o = 3'b101;
      59'b00000000001000000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000100000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000010000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000001000000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000100000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000010000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000001000000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000100000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000010000000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000001000000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000100000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000010000000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000001000000000000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000100000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000010000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000001000000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000100000000000000000000000000000000: n3980_o = n3307_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000001000000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000100000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000010000000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000001000000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000100000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000010000000000000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000001000000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000100000000000000000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000010000000000000000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000001000000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000100000000000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000010000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000001000000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000100000000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000010000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000001000000000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000100000000000000: n3980_o = 3'b001;
      59'b00000000000000000000000000000000000000000000010000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000000000001000000000000: n3980_o = 3'b101;
      59'b00000000000000000000000000000000000000000000000100000000000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000010000000000: n3980_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000001000000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000100000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000010000000: n3980_o = 3'b100;
      59'b00000000000000000000000000000000000000000000000000001000000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000100000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000010000: n3980_o = 3'b011;
      59'b00000000000000000000000000000000000000000000000000000001000: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000100: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000010: n3980_o = 3'b010;
      59'b00000000000000000000000000000000000000000000000000000000001: n3980_o = 3'b001;
      default: n3980_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n3985_o = n3854_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n3985_o = n3808_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n3985_o = n3678_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3985_o = n3580_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000100000000000000000000000000000000000000: n3985_o = 3'b110;
      59'b00000000000000000000010000000000000000000000000000000000000: n3985_o = 3'b110;
      59'b00000000000000000000001000000000000000000000000000000000000: n3985_o = n3374_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n3985_o = n3308_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000001000000000000000000000000000: n3985_o = n3187_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n3985_o = n3132_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n3985_o = n2818_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n3985_o = n2719_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n3985_o = 3'b110;
      59'b00000000000000000000000000000000000000000000010000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n3985_o = n2179_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n3985_o = n2179_o;
      default: n3985_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n3988_o = n3925_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n3988_o = n3905_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n3988_o = n3682_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n3988_o = n3584_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n3988_o = n3523_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n3988_o = n3461_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n3988_o = n3310_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n3988_o = n3069_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n3988_o = n2670_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3988_o = n2635_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3988_o = n2600_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n3988_o = n2555_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n3988_o = n2492_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n3988_o = n2440_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n3988_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n3988_o = n2334_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n3988_o = 1'b0;
      default: n3988_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n3991_o = n2673_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n3991_o = n2638_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n3991_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n3991_o = 1'b0;
      default: n3991_o = 1'bX;
    endcase
  assign n3992_o = n2723_o[1:0];
  assign n3993_o = n2774_o[1:0];
  assign n3994_o = n2822_o[1:0];
  assign n3995_o = n3311_o[1:0];
  assign n3996_o = n3588_o[1:0];
  assign n3997_o = n3685_o[1:0];
  assign n3998_o = n3739_o[1:0];
  assign n3999_o = n3812_o[1:0];
  assign n4000_o = n3858_o[1:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4003_o = n4000_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4003_o = n3999_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4003_o = n3998_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4003_o = n3997_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4003_o = n3996_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4003_o = n2174_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4003_o = n2174_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4003_o = n3995_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4003_o = n3994_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4003_o = n3993_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4003_o = n3992_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4003_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4003_o = 2'b00;
      default: n4003_o = 2'bX;
    endcase
  assign n4004_o = n2723_o[3:2];
  assign n4005_o = n2774_o[3:2];
  assign n4006_o = n2822_o[3:2];
  assign n4007_o = n3311_o[3:2];
  assign n4008_o = n3588_o[3:2];
  assign n4009_o = n3685_o[3:2];
  assign n4010_o = n3739_o[3:2];
  assign n4011_o = n3812_o[3:2];
  assign n4012_o = n3858_o[3:2];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4015_o = n4012_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4015_o = n4011_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4015_o = n4010_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4015_o = n4009_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4015_o = n4008_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4015_o = 2'b11;
      59'b00000000000000000000010000000000000000000000000000000000000: n4015_o = 2'b01;
      59'b00000000000000000000001000000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000100000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4015_o = n4007_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4015_o = n4006_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4015_o = n4005_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4015_o = n4004_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000001000000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000100000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000010000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4015_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4015_o = 2'b00;
      default: n4015_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4024_o = n3378_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4024_o = n3190_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4024_o = n3135_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4024_o = n3072_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4024_o = n3030_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4024_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4024_o = n2826_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4024_o = n2778_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4024_o = n2642_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4024_o = n2604_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4024_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4024_o = n2368_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4024_o = n2337_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4024_o = 1'b1;
      default: n4024_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4027_o = n3908_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4027_o = n2495_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4027_o = n2475_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4027_o = n2461_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4027_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4027_o = 1'b0;
      default: n4027_o = 1'bX;
    endcase
  assign n4028_o = n2830_o[2:0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b01000000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00100000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00010000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00001000000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000100000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000010000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000001000000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000100000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000010000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000001000000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000100000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000010000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000001000000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000100000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000010000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000001000000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000100000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000010000000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000001000000000000000000000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000010000000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000001000000000000000000000000000000000000: n4031_o = n3380_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000010000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000001000000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000100000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000010000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000001000000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000100000000000000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000010000000000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4031_o = n3192_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4031_o = n2172_o;
      59'b00000000000000000000000000000000010000000000000000000000000: n4031_o = n3137_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4031_o = n2172_o;
      59'b00000000000000000000000000000000000100000000000000000000000: n4031_o = n3074_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4031_o = n3032_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4031_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4031_o = n4028_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000001000000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000100000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000010000000000000000: n4031_o = n2780_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000100000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000010000000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000001000000000000: n4031_o = n2644_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4031_o = n2606_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000001000000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000100000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000010000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000001000000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000100000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000010000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000001000: n4031_o = 3'b000;
      59'b00000000000000000000000000000000000000000000000000000000100: n4031_o = n2370_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4031_o = n2339_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4031_o = n2172_o;
      default: n4031_o = 3'bX;
    endcase
  assign n4032_o = n2830_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4035_o = n4032_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4035_o = n2782_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4035_o = n2608_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4035_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4035_o = 1'b0;
      default: n4035_o = 1'bX;
    endcase
  assign n4036_o = n2173_o[0];
  assign n4037_o = n2402_o[0];
  assign n4038_o = n2442_o[0];
  assign n4039_o = n2512_o[0];
  assign n4040_o = n2532_o[0];
  assign n4041_o = n2558_o[0];
  assign n4042_o = n2677_o[0];
  assign n4043_o = n2725_o[0];
  assign n4044_o = n2834_o[0];
  assign n4045_o = n2173_o[0];
  assign n4046_o = n3034_o[0];
  assign n4047_o = n3076_o[0];
  assign n4049_o = n3140_o[0];
  assign n4051_o = n3195_o[0];
  assign n4052_o = n3312_o[0];
  assign n4053_o = n3592_o[0];
  assign n4054_o = n3688_o[0];
  assign n4055_o = n3862_o[0];
  assign n4056_o = n3928_o[0];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4059_o = n4056_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4059_o = n4055_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4059_o = n4054_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4059_o = n4053_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4059_o = n3382_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4059_o = n4052_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4059_o = n4051_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4059_o = n4049_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4059_o = n4047_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4059_o = n4046_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4059_o = n4045_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4059_o = n4044_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4059_o = n4043_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4059_o = n4042_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4059_o = n4041_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4059_o = n4040_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4059_o = n4039_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4059_o = n4038_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4059_o = n4037_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4059_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4059_o = n4036_o;
      default: n4059_o = 1'bX;
    endcase
  assign n4060_o = n2173_o[2:1];
  assign n4061_o = n2402_o[2:1];
  assign n4062_o = n2442_o[2:1];
  assign n4063_o = n2512_o[2:1];
  assign n4064_o = n2532_o[2:1];
  assign n4065_o = n2558_o[2:1];
  assign n4066_o = n2677_o[2:1];
  assign n4067_o = n2725_o[2:1];
  assign n4068_o = n2834_o[2:1];
  assign n4069_o = n2173_o[2:1];
  assign n4070_o = n3034_o[2:1];
  assign n4071_o = n3076_o[2:1];
  assign n4073_o = n3140_o[2:1];
  assign n4075_o = n3195_o[2:1];
  assign n4076_o = n3312_o[2:1];
  assign n4077_o = n3592_o[2:1];
  assign n4078_o = n3688_o[2:1];
  assign n4079_o = n3862_o[2:1];
  assign n4080_o = n3928_o[2:1];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4083_o = n4080_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4083_o = n4079_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4083_o = n4078_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4083_o = n4077_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4083_o = n3384_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4083_o = n4076_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4083_o = n4075_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4083_o = 2'b01;
      59'b00000000000000000000000000000000010000000000000000000000000: n4083_o = n4073_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4083_o = 2'b01;
      59'b00000000000000000000000000000000000100000000000000000000000: n4083_o = n4071_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4083_o = n4070_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4083_o = n4069_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4083_o = n4068_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4083_o = n4067_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4083_o = n4066_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4083_o = n4065_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4083_o = n4064_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4083_o = n4063_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4083_o = n4062_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4083_o = n4061_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4083_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4083_o = n4060_o;
      default: n4083_o = 2'bX;
    endcase
  assign n4084_o = n2512_o[3];
  assign n4085_o = n2532_o[3];
  assign n4086_o = n2558_o[3];
  assign n4087_o = n2677_o[3];
  assign n4088_o = n2725_o[3];
  assign n4089_o = n2834_o[3];
  assign n4091_o = n3140_o[3];
  assign n4093_o = n3195_o[3];
  assign n4094_o = n3312_o[3];
  assign n4095_o = n3592_o[3];
  assign n4096_o = n3688_o[3];
  assign n4097_o = n3862_o[3];
  assign n4098_o = n3928_o[3];
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4101_o = n4098_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4101_o = n4097_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4101_o = n4096_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4101_o = n4095_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4101_o = n3386_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4101_o = n4094_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4101_o = n4093_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4101_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4101_o = n4091_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4101_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4101_o = n4089_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4101_o = n4088_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4101_o = n4087_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4101_o = n4086_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4101_o = n4085_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4101_o = n4084_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4101_o = n2444_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4101_o = n2404_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4101_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4101_o = 1'b0;
      default: n4101_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b01000000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00100000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00010000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000100000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000010000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000001000000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000100000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000010000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000001000000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000100000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4107_o = 4'b1000;
      59'b00000000000000000000100000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000010000000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000001000000000000000000000000000000000000: n4107_o = n3389_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000010000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000001000000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000100000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000001000000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000100000000000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000010000000000000000000000000000: n4107_o = 4'b1100;
      59'b00000000000000000000000000000001000000000000000000000000000: n4107_o = n3197_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4107_o = 4'b0010;
      59'b00000000000000000000000000000000010000000000000000000000000: n4107_o = n3142_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4107_o = 4'b0000;
      59'b00000000000000000000000000000000000100000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000100000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000001000000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000100000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000010000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000010000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000010000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4107_o = n2182_o;
      59'b00000000000000000000000000000000000000000000000000000000001: n4107_o = n2182_o;
      default: n4107_o = 4'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000100000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4115_o = n3393_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000001000000000000000000000000000: n4115_o = n3200_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4115_o = n3145_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4115_o = n3079_o;
      59'b00000000000000000000000000000000000010000000000000000000000: n4115_o = n3037_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4115_o = 1'b1;
      59'b00000000000000000000000000000000000000100000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4115_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4115_o = 1'b0;
      default: n4115_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4120_o = n3203_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4120_o = 1'b1;
      59'b00000000000000000000000000000000010000000000000000000000000: n4120_o = n3148_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4120_o = 1'b1;
      59'b00000000000000000000000000000000000100000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4120_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4120_o = 1'b0;
      default: n4120_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4123_o = n3397_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4123_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4123_o = 1'b0;
      default: n4123_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b01000000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00100000000000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00010000000000000000000000000000000000000000000000000000000: n4126_o = n3931_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4126_o = n3911_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4126_o = n3866_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4126_o = n3815_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4126_o = n3743_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4126_o = n3691_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4126_o = n3596_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000100000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000010000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000001000000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000100000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000010000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000001000000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000100000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000010000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000001000000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000100000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000010000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000001000000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000100000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000010000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000001000000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000100000000000000000000000000000000: n4126_o = n3313_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000001000000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000100000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000010000000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000001000000000000000000000000000: n4126_o = n3207_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000010000000000000000000000000: n4126_o = n3152_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000100000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000010000000000000000000000: n4126_o = n3040_o;
      59'b00000000000000000000000000000000000001000000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000100000000000000000000: n4126_o = n2840_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000001000000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000100000000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000010000000000000000: n4126_o = n2786_o;
      59'b00000000000000000000000000000000000000000001000000000000000: n4126_o = n2729_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000010000000000000: n4126_o = n2681_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4126_o = n2648_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000010000000000: n4126_o = n2561_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4126_o = n2535_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4126_o = n2515_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4126_o = n2498_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4126_o = n2478_o;
      59'b00000000000000000000000000000000000000000000000000000100000: n4126_o = n2464_o;
      59'b00000000000000000000000000000000000000000000000000000010000: n4126_o = n2447_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4126_o = n2407_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4126_o = n2373_o;
      59'b00000000000000000000000000000000000000000000000000000000010: n4126_o = 3'b111;
      59'b00000000000000000000000000000000000000000000000000000000001: n4126_o = 3'b111;
      default: n4126_o = 3'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4129_o = n3934_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4129_o = n3914_o;
      59'b00000100000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4129_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4129_o = 1'b0;
      default: n4129_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4132_o = n3818_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4132_o = n3746_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4132_o = n3525_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4132_o = n3464_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4132_o = n3315_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4132_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4132_o = 1'b0;
      default: n4132_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4136_o = 1'b1;
      59'b00000000000010000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4136_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4136_o = 1'b0;
      default: n4136_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4139_o = n3694_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4139_o = n3599_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4139_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4139_o = 1'b0;
      default: n4139_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4142_o = n3869_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4142_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4142_o = 1'b0;
      default: n4142_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4145_o = n3821_o;
      59'b00000001000000000000000000000000000000000000000000000000000: n4145_o = n3749_o;
      59'b00000000100000000000000000000000000000000000000000000000000: n4145_o = n3697_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4145_o = n3602_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4145_o = n3528_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4145_o = n3467_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4145_o = n3317_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4145_o = n2843_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4145_o = n2684_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4145_o = n2651_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4145_o = n2564_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4145_o = n2501_o;
      59'b00000000000000000000000000000000000000000000000000001000000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4145_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4145_o = 1'b0;
      default: n4145_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4148_o = n3700_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4148_o = n3605_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4148_o = n3531_o;
      59'b00000000000000000010000000000000000000000000000000000000000: n4148_o = n3470_o;
      59'b00000000000000000001000000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4148_o = n2846_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4148_o = n2687_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4148_o = n2654_o;
      59'b00000000000000000000000000000000000000000000000100000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4148_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4148_o = 1'b0;
      default: n4148_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4152_o = 1'b1;
      59'b00000000000000000000000000000000000000000000010000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4152_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4152_o = 1'b0;
      default: n4152_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4156_o = 1'b1;
      59'b00000000000000000000000000000000000000000010000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4156_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4156_o = 1'b0;
      default: n4156_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4160_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4160_o = 1'b1;
      default: n4160_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4164_o = 1'b1;
      59'b00000000000000000000000000000010000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4164_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4164_o = 1'b0;
      default: n4164_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4168_o = 1'b1;
      59'b00000000000000000000000000000100000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4168_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4168_o = 1'b0;
      default: n4168_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4172_o = 1'b1;
      59'b00000000000000000000000000001000000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4172_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4172_o = 1'b0;
      default: n4172_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b01000000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00100000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00010000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00001000000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000100000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000010000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000001000000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000100000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000010000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000001000000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000100000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000010000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000001000000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000100000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000010000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000001000000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000100000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000010000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000001000000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000100000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000010000000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000001000000000000000000000000000000000000: n4175_o = n3400_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000010000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000001000000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000100000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000010000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000001000000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000100000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000010000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000001000000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000100000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000010000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000001000000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000100000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000010000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000001000000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000100000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000010000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000001000000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000100000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000010000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000001000000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000100000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000010000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000001000000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000100000000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000010000000000: n4175_o = n2567_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4175_o = n2538_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4175_o = n2518_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000001000000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000100000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000010000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000001000: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000100: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000010: n4175_o = 2'b00;
      59'b00000000000000000000000000000000000000000000000000000000001: n4175_o = 2'b00;
      default: n4175_o = 2'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4179_o = 1'b1;
      59'b00000000000000000000000001000000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4179_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4179_o = 1'b0;
      default: n4179_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4183_o = 1'b1;
      59'b00000000000000000000000010000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4183_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4183_o = 1'b0;
      default: n4183_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4187_o = 1'b1;
      59'b00000000000000000000000000100000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4187_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4187_o = 1'b0;
      default: n4187_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00001000000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000010000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000010000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000001000000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4190_o = n3404_o;
      59'b00000000000000000000000100000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000010000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000100000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000001000000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000010000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000100000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000001000000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000001000000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000100000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000010000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000001000: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000100: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4190_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4190_o = 1'b0;
      default: n4190_o = 1'bX;
    endcase
  /* T80_MCode.vhd:265:17  */
  always @*
    case (n3949_o)
      59'b10000000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b01000000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00100000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00010000000000000000000000000000000000000000000000000000000: n4193_o = n3937_o;
      59'b00001000000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000100000000000000000000000000000000000000000000000000000: n4193_o = n3873_o;
      59'b00000010000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000001000000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000100000000000000000000000000000000000000000000000000: n4193_o = n3704_o;
      59'b00000000010000000000000000000000000000000000000000000000000: n4193_o = n3609_o;
      59'b00000000001000000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000100000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000010000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000001000000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000100000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000010000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000001000000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000100000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000010000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000001000000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000100000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000010000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000001000000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000100000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000010000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000001000000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000100000000000000000000000000000000: n4193_o = n3318_o;
      59'b00000000000000000000000000010000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000001000000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000100000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000010000000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000001000000000000000000000000000: n4193_o = n3210_o;
      59'b00000000000000000000000000000000100000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000010000000000000000000000000: n4193_o = n3155_o;
      59'b00000000000000000000000000000000001000000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000100000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000010000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000001000000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000100000000000000000000: n4193_o = n2850_o;
      59'b00000000000000000000000000000000000000010000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000001000000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000100000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000010000000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000001000000000000000: n4193_o = n2733_o;
      59'b00000000000000000000000000000000000000000000100000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000010000000000000: n4193_o = n2691_o;
      59'b00000000000000000000000000000000000000000000001000000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000100000000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000010000000000: n4193_o = n2570_o;
      59'b00000000000000000000000000000000000000000000000001000000000: n4193_o = n2541_o;
      59'b00000000000000000000000000000000000000000000000000100000000: n4193_o = n2521_o;
      59'b00000000000000000000000000000000000000000000000000010000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000001000000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000100000: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000010000: n4193_o = n2450_o;
      59'b00000000000000000000000000000000000000000000000000000001000: n4193_o = n2410_o;
      59'b00000000000000000000000000000000000000000000000000000000100: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000010: n4193_o = 1'b0;
      59'b00000000000000000000000000000000000000000000000000000000001: n4193_o = 1'b0;
      default: n4193_o = 1'bX;
    endcase
  /* T80_MCode.vhd:257:17  */
  assign n4195_o = iset == 2'b00;
  /* T80_MCode.vhd:1356:54  */
  assign n4196_o = ir[2:0];
  /* T80_MCode.vhd:1357:54  */
  assign n4197_o = ir[2:0];
  /* T80_MCode.vhd:1376:44  */
  assign n4199_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1377:51  */
  assign n4201_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1377:41  */
  assign n4204_o = n4201_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1377:41  */
  assign n4206_o = n4201_o ? 4'b1000 : n2182_o;
  /* T80_MCode.vhd:1377:41  */
  assign n4209_o = n4201_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1386:46  */
  assign n4210_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1387:41  */
  assign n4212_o = n4210_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1387:48  */
  assign n4214_o = n4210_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1387:48  */
  assign n4215_o = n4212_o | n4214_o;
  /* T80_MCode.vhd:1389:41  */
  assign n4217_o = n4210_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1395:41  */
  assign n4219_o = n4210_o == 31'b0000000000000000000000000000011;
  assign n4220_o = {n4219_o, n4217_o, n4215_o};
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4222_o = n2179_o;
      3'b010: n4222_o = 3'b100;
      3'b001: n4222_o = n2179_o;
      default: n4222_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4225_o = 1'b0;
      3'b010: n4225_o = 1'b1;
      3'b001: n4225_o = 1'b0;
      default: n4225_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4227_o = n2182_o;
      3'b010: n4227_o = 4'b1000;
      3'b001: n4227_o = n2182_o;
      default: n4227_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4230_o = 1'b0;
      3'b010: n4230_o = 1'b1;
      3'b001: n4230_o = 1'b0;
      default: n4230_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4234_o = 3'b111;
      3'b010: n4234_o = 3'b010;
      3'b001: n4234_o = 3'b010;
      default: n4234_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1386:41  */
  always @*
    case (n4220_o)
      3'b100: n4237_o = 1'b1;
      3'b010: n4237_o = 1'b0;
      3'b001: n4237_o = 1'b0;
      default: n4237_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1376:33  */
  assign n4240_o = n4199_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1376:33  */
  assign n4241_o = n4199_o ? n2179_o : n4222_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4242_o = n4199_o ? n4204_o : n4225_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4243_o = n4199_o ? n4206_o : n4227_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4244_o = n4199_o ? n4209_o : n4230_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4246_o = n4199_o ? 3'b111 : n4234_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4248_o = n4199_o ? 1'b0 : n4237_o;
  /* T80_MCode.vhd:1376:33  */
  assign n4251_o = n4199_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1360:25  */
  assign n4253_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1360:40  */
  assign n4255_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1360:40  */
  assign n4256_o = n4253_o | n4255_o;
  /* T80_MCode.vhd:1360:51  */
  assign n4258_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1360:51  */
  assign n4259_o = n4256_o | n4258_o;
  /* T80_MCode.vhd:1360:62  */
  assign n4261_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1360:62  */
  assign n4262_o = n4259_o | n4261_o;
  /* T80_MCode.vhd:1360:73  */
  assign n4264_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1360:73  */
  assign n4265_o = n4262_o | n4264_o;
  /* T80_MCode.vhd:1360:84  */
  assign n4267_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1360:84  */
  assign n4268_o = n4265_o | n4267_o;
  /* T80_MCode.vhd:1360:95  */
  assign n4270_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1360:95  */
  assign n4271_o = n4268_o | n4270_o;
  /* T80_MCode.vhd:1361:33  */
  assign n4273_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1361:33  */
  assign n4274_o = n4271_o | n4273_o;
  /* T80_MCode.vhd:1361:44  */
  assign n4276_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1361:44  */
  assign n4277_o = n4274_o | n4276_o;
  /* T80_MCode.vhd:1361:55  */
  assign n4279_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1361:55  */
  assign n4280_o = n4277_o | n4279_o;
  /* T80_MCode.vhd:1361:66  */
  assign n4282_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1361:66  */
  assign n4283_o = n4280_o | n4282_o;
  /* T80_MCode.vhd:1361:77  */
  assign n4285_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1361:77  */
  assign n4286_o = n4283_o | n4285_o;
  /* T80_MCode.vhd:1361:88  */
  assign n4288_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1361:88  */
  assign n4289_o = n4286_o | n4288_o;
  /* T80_MCode.vhd:1361:99  */
  assign n4291_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1361:99  */
  assign n4292_o = n4289_o | n4291_o;
  /* T80_MCode.vhd:1362:33  */
  assign n4294_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1362:33  */
  assign n4295_o = n4292_o | n4294_o;
  /* T80_MCode.vhd:1362:44  */
  assign n4297_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1362:44  */
  assign n4298_o = n4295_o | n4297_o;
  /* T80_MCode.vhd:1362:55  */
  assign n4300_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1362:55  */
  assign n4301_o = n4298_o | n4300_o;
  /* T80_MCode.vhd:1362:66  */
  assign n4303_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1362:66  */
  assign n4304_o = n4301_o | n4303_o;
  /* T80_MCode.vhd:1362:77  */
  assign n4306_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1362:77  */
  assign n4307_o = n4304_o | n4306_o;
  /* T80_MCode.vhd:1362:88  */
  assign n4309_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1362:88  */
  assign n4310_o = n4307_o | n4309_o;
  /* T80_MCode.vhd:1362:99  */
  assign n4312_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1362:99  */
  assign n4313_o = n4310_o | n4312_o;
  /* T80_MCode.vhd:1363:33  */
  assign n4315_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1363:33  */
  assign n4316_o = n4313_o | n4315_o;
  /* T80_MCode.vhd:1363:44  */
  assign n4318_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1363:44  */
  assign n4319_o = n4316_o | n4318_o;
  /* T80_MCode.vhd:1363:55  */
  assign n4321_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1363:55  */
  assign n4322_o = n4319_o | n4321_o;
  /* T80_MCode.vhd:1363:66  */
  assign n4324_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1363:66  */
  assign n4325_o = n4322_o | n4324_o;
  /* T80_MCode.vhd:1363:77  */
  assign n4327_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1363:77  */
  assign n4328_o = n4325_o | n4327_o;
  /* T80_MCode.vhd:1363:88  */
  assign n4330_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1363:88  */
  assign n4331_o = n4328_o | n4330_o;
  /* T80_MCode.vhd:1363:99  */
  assign n4333_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1363:99  */
  assign n4334_o = n4331_o | n4333_o;
  /* T80_MCode.vhd:1364:33  */
  assign n4336_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1364:33  */
  assign n4337_o = n4334_o | n4336_o;
  /* T80_MCode.vhd:1364:44  */
  assign n4339_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1364:44  */
  assign n4340_o = n4337_o | n4339_o;
  /* T80_MCode.vhd:1364:55  */
  assign n4342_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1364:55  */
  assign n4343_o = n4340_o | n4342_o;
  /* T80_MCode.vhd:1364:66  */
  assign n4345_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1364:66  */
  assign n4346_o = n4343_o | n4345_o;
  /* T80_MCode.vhd:1364:77  */
  assign n4348_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1364:77  */
  assign n4349_o = n4346_o | n4348_o;
  /* T80_MCode.vhd:1364:88  */
  assign n4351_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1364:88  */
  assign n4352_o = n4349_o | n4351_o;
  /* T80_MCode.vhd:1364:99  */
  assign n4354_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1364:99  */
  assign n4355_o = n4352_o | n4354_o;
  /* T80_MCode.vhd:1365:33  */
  assign n4357_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1365:33  */
  assign n4358_o = n4355_o | n4357_o;
  /* T80_MCode.vhd:1365:44  */
  assign n4360_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1365:44  */
  assign n4361_o = n4358_o | n4360_o;
  /* T80_MCode.vhd:1365:55  */
  assign n4363_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1365:55  */
  assign n4364_o = n4361_o | n4363_o;
  /* T80_MCode.vhd:1365:66  */
  assign n4366_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1365:66  */
  assign n4367_o = n4364_o | n4366_o;
  /* T80_MCode.vhd:1365:77  */
  assign n4369_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1365:77  */
  assign n4370_o = n4367_o | n4369_o;
  /* T80_MCode.vhd:1365:88  */
  assign n4372_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1365:88  */
  assign n4373_o = n4370_o | n4372_o;
  /* T80_MCode.vhd:1365:99  */
  assign n4375_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1365:99  */
  assign n4376_o = n4373_o | n4375_o;
  /* T80_MCode.vhd:1366:33  */
  assign n4378_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1366:33  */
  assign n4379_o = n4376_o | n4378_o;
  /* T80_MCode.vhd:1366:44  */
  assign n4381_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1366:44  */
  assign n4382_o = n4379_o | n4381_o;
  /* T80_MCode.vhd:1366:55  */
  assign n4384_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1366:55  */
  assign n4385_o = n4382_o | n4384_o;
  /* T80_MCode.vhd:1366:66  */
  assign n4387_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1366:66  */
  assign n4388_o = n4385_o | n4387_o;
  /* T80_MCode.vhd:1366:77  */
  assign n4390_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1366:77  */
  assign n4391_o = n4388_o | n4390_o;
  /* T80_MCode.vhd:1366:88  */
  assign n4393_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1366:88  */
  assign n4394_o = n4391_o | n4393_o;
  /* T80_MCode.vhd:1366:99  */
  assign n4396_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1366:99  */
  assign n4397_o = n4394_o | n4396_o;
  /* T80_MCode.vhd:1367:33  */
  assign n4399_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1367:33  */
  assign n4400_o = n4397_o | n4399_o;
  /* T80_MCode.vhd:1367:44  */
  assign n4402_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1367:44  */
  assign n4403_o = n4400_o | n4402_o;
  /* T80_MCode.vhd:1367:55  */
  assign n4405_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1367:55  */
  assign n4406_o = n4403_o | n4405_o;
  /* T80_MCode.vhd:1367:66  */
  assign n4408_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1367:66  */
  assign n4409_o = n4406_o | n4408_o;
  /* T80_MCode.vhd:1367:77  */
  assign n4411_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1367:77  */
  assign n4412_o = n4409_o | n4411_o;
  /* T80_MCode.vhd:1367:88  */
  assign n4414_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1367:88  */
  assign n4415_o = n4412_o | n4414_o;
  /* T80_MCode.vhd:1367:99  */
  assign n4417_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1367:99  */
  assign n4418_o = n4415_o | n4417_o;
  /* T80_MCode.vhd:1411:38  */
  assign n4419_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1412:33  */
  assign n4421_o = n4419_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1412:40  */
  assign n4423_o = n4419_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1412:40  */
  assign n4424_o = n4421_o | n4423_o;
  /* T80_MCode.vhd:1414:33  */
  assign n4426_o = n4419_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1420:33  */
  assign n4428_o = n4419_o == 31'b0000000000000000000000000000011;
  assign n4429_o = {n4428_o, n4426_o, n4424_o};
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4431_o = n2179_o;
      3'b010: n4431_o = 3'b100;
      3'b001: n4431_o = n2179_o;
      default: n4431_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4434_o = 1'b0;
      3'b010: n4434_o = 1'b1;
      3'b001: n4434_o = 1'b0;
      default: n4434_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4436_o = n2182_o;
      3'b010: n4436_o = 4'b1000;
      3'b001: n4436_o = n2182_o;
      default: n4436_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4439_o = 1'b0;
      3'b010: n4439_o = 1'b1;
      3'b001: n4439_o = 1'b0;
      default: n4439_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4443_o = 3'b111;
      3'b010: n4443_o = 3'b010;
      3'b001: n4443_o = 3'b010;
      default: n4443_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1411:33  */
  always @*
    case (n4429_o)
      3'b100: n4446_o = 1'b1;
      3'b010: n4446_o = 1'b0;
      3'b001: n4446_o = 1'b0;
      default: n4446_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1401:25  */
  assign n4448_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1401:40  */
  assign n4450_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1401:40  */
  assign n4451_o = n4448_o | n4450_o;
  /* T80_MCode.vhd:1401:51  */
  assign n4453_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1401:51  */
  assign n4454_o = n4451_o | n4453_o;
  /* T80_MCode.vhd:1401:62  */
  assign n4456_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1401:62  */
  assign n4457_o = n4454_o | n4456_o;
  /* T80_MCode.vhd:1401:73  */
  assign n4459_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1401:73  */
  assign n4460_o = n4457_o | n4459_o;
  /* T80_MCode.vhd:1401:84  */
  assign n4462_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1401:84  */
  assign n4463_o = n4460_o | n4462_o;
  /* T80_MCode.vhd:1401:95  */
  assign n4465_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1401:95  */
  assign n4466_o = n4463_o | n4465_o;
  /* T80_MCode.vhd:1401:106  */
  assign n4468_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1401:106  */
  assign n4469_o = n4466_o | n4468_o;
  /* T80_MCode.vhd:1433:44  */
  assign n4471_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1434:51  */
  assign n4473_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1435:72  */
  assign n4474_o = ir[2:0];
  /* T80_MCode.vhd:1433:33  */
  assign n4475_o = n4498_o ? n4474_o : n4197_o;
  /* T80_MCode.vhd:1434:41  */
  assign n4477_o = n4473_o ? 4'b1001 : n2182_o;
  /* T80_MCode.vhd:1442:46  */
  assign n4478_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1443:41  */
  assign n4480_o = n4478_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1443:48  */
  assign n4482_o = n4478_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1443:48  */
  assign n4483_o = n4480_o | n4482_o;
  /* T80_MCode.vhd:1445:41  */
  assign n4485_o = n4478_o == 31'b0000000000000000000000000000010;
  assign n4486_o = {n4485_o, n4483_o};
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4488_o = 3'b100;
      2'b01: n4488_o = n2179_o;
      default: n4488_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4490_o = 4'b1001;
      2'b01: n4490_o = n2182_o;
      default: n4490_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1442:41  */
  always @*
    case (n4486_o)
      2'b10: n4493_o = 3'b111;
      2'b01: n4493_o = 3'b010;
      default: n4493_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1433:33  */
  assign n4496_o = n4471_o ? 3'b001 : 3'b010;
  /* T80_MCode.vhd:1433:33  */
  assign n4497_o = n4471_o ? n2179_o : n4488_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4498_o = n4473_o & n4471_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4499_o = n4471_o ? n4477_o : n4490_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4501_o = n4471_o ? 3'b111 : n4493_o;
  /* T80_MCode.vhd:1433:33  */
  assign n4504_o = n4471_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1424:25  */
  assign n4506_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1424:40  */
  assign n4508_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1424:40  */
  assign n4509_o = n4506_o | n4508_o;
  /* T80_MCode.vhd:1424:51  */
  assign n4511_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1424:51  */
  assign n4512_o = n4509_o | n4511_o;
  /* T80_MCode.vhd:1424:62  */
  assign n4514_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1424:62  */
  assign n4515_o = n4512_o | n4514_o;
  /* T80_MCode.vhd:1424:73  */
  assign n4517_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1424:73  */
  assign n4518_o = n4515_o | n4517_o;
  /* T80_MCode.vhd:1424:84  */
  assign n4520_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1424:84  */
  assign n4521_o = n4518_o | n4520_o;
  /* T80_MCode.vhd:1424:95  */
  assign n4523_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1424:95  */
  assign n4524_o = n4521_o | n4523_o;
  /* T80_MCode.vhd:1425:33  */
  assign n4526_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1425:33  */
  assign n4527_o = n4524_o | n4526_o;
  /* T80_MCode.vhd:1425:44  */
  assign n4529_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1425:44  */
  assign n4530_o = n4527_o | n4529_o;
  /* T80_MCode.vhd:1425:55  */
  assign n4532_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1425:55  */
  assign n4533_o = n4530_o | n4532_o;
  /* T80_MCode.vhd:1425:66  */
  assign n4535_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1425:66  */
  assign n4536_o = n4533_o | n4535_o;
  /* T80_MCode.vhd:1425:77  */
  assign n4538_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1425:77  */
  assign n4539_o = n4536_o | n4538_o;
  /* T80_MCode.vhd:1425:88  */
  assign n4541_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1425:88  */
  assign n4542_o = n4539_o | n4541_o;
  /* T80_MCode.vhd:1425:99  */
  assign n4544_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1425:99  */
  assign n4545_o = n4542_o | n4544_o;
  /* T80_MCode.vhd:1426:33  */
  assign n4547_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1426:33  */
  assign n4548_o = n4545_o | n4547_o;
  /* T80_MCode.vhd:1426:44  */
  assign n4550_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1426:44  */
  assign n4551_o = n4548_o | n4550_o;
  /* T80_MCode.vhd:1426:55  */
  assign n4553_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1426:55  */
  assign n4554_o = n4551_o | n4553_o;
  /* T80_MCode.vhd:1426:66  */
  assign n4556_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1426:66  */
  assign n4557_o = n4554_o | n4556_o;
  /* T80_MCode.vhd:1426:77  */
  assign n4559_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1426:77  */
  assign n4560_o = n4557_o | n4559_o;
  /* T80_MCode.vhd:1426:88  */
  assign n4562_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1426:88  */
  assign n4563_o = n4560_o | n4562_o;
  /* T80_MCode.vhd:1426:99  */
  assign n4565_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1426:99  */
  assign n4566_o = n4563_o | n4565_o;
  /* T80_MCode.vhd:1427:33  */
  assign n4568_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1427:33  */
  assign n4569_o = n4566_o | n4568_o;
  /* T80_MCode.vhd:1427:44  */
  assign n4571_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1427:44  */
  assign n4572_o = n4569_o | n4571_o;
  /* T80_MCode.vhd:1427:55  */
  assign n4574_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1427:55  */
  assign n4575_o = n4572_o | n4574_o;
  /* T80_MCode.vhd:1427:66  */
  assign n4577_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1427:66  */
  assign n4578_o = n4575_o | n4577_o;
  /* T80_MCode.vhd:1427:77  */
  assign n4580_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1427:77  */
  assign n4581_o = n4578_o | n4580_o;
  /* T80_MCode.vhd:1427:88  */
  assign n4583_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1427:88  */
  assign n4584_o = n4581_o | n4583_o;
  /* T80_MCode.vhd:1427:99  */
  assign n4586_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1427:99  */
  assign n4587_o = n4584_o | n4586_o;
  /* T80_MCode.vhd:1428:33  */
  assign n4589_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1428:33  */
  assign n4590_o = n4587_o | n4589_o;
  /* T80_MCode.vhd:1428:44  */
  assign n4592_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1428:44  */
  assign n4593_o = n4590_o | n4592_o;
  /* T80_MCode.vhd:1428:55  */
  assign n4595_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1428:55  */
  assign n4596_o = n4593_o | n4595_o;
  /* T80_MCode.vhd:1428:66  */
  assign n4598_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1428:66  */
  assign n4599_o = n4596_o | n4598_o;
  /* T80_MCode.vhd:1428:77  */
  assign n4601_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1428:77  */
  assign n4602_o = n4599_o | n4601_o;
  /* T80_MCode.vhd:1428:88  */
  assign n4604_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1428:88  */
  assign n4605_o = n4602_o | n4604_o;
  /* T80_MCode.vhd:1428:99  */
  assign n4607_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1428:99  */
  assign n4608_o = n4605_o | n4607_o;
  /* T80_MCode.vhd:1429:33  */
  assign n4610_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1429:33  */
  assign n4611_o = n4608_o | n4610_o;
  /* T80_MCode.vhd:1429:44  */
  assign n4613_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1429:44  */
  assign n4614_o = n4611_o | n4613_o;
  /* T80_MCode.vhd:1429:55  */
  assign n4616_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1429:55  */
  assign n4617_o = n4614_o | n4616_o;
  /* T80_MCode.vhd:1429:66  */
  assign n4619_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1429:66  */
  assign n4620_o = n4617_o | n4619_o;
  /* T80_MCode.vhd:1429:77  */
  assign n4622_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1429:77  */
  assign n4623_o = n4620_o | n4622_o;
  /* T80_MCode.vhd:1429:88  */
  assign n4625_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1429:88  */
  assign n4626_o = n4623_o | n4625_o;
  /* T80_MCode.vhd:1429:99  */
  assign n4628_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1429:99  */
  assign n4629_o = n4626_o | n4628_o;
  /* T80_MCode.vhd:1430:33  */
  assign n4631_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1430:33  */
  assign n4632_o = n4629_o | n4631_o;
  /* T80_MCode.vhd:1430:44  */
  assign n4634_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1430:44  */
  assign n4635_o = n4632_o | n4634_o;
  /* T80_MCode.vhd:1430:55  */
  assign n4637_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1430:55  */
  assign n4638_o = n4635_o | n4637_o;
  /* T80_MCode.vhd:1430:66  */
  assign n4640_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1430:66  */
  assign n4641_o = n4638_o | n4640_o;
  /* T80_MCode.vhd:1430:77  */
  assign n4643_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1430:77  */
  assign n4644_o = n4641_o | n4643_o;
  /* T80_MCode.vhd:1430:88  */
  assign n4646_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1430:88  */
  assign n4647_o = n4644_o | n4646_o;
  /* T80_MCode.vhd:1430:99  */
  assign n4649_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1430:99  */
  assign n4650_o = n4647_o | n4649_o;
  /* T80_MCode.vhd:1431:33  */
  assign n4652_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1431:33  */
  assign n4653_o = n4650_o | n4652_o;
  /* T80_MCode.vhd:1431:44  */
  assign n4655_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1431:44  */
  assign n4656_o = n4653_o | n4655_o;
  /* T80_MCode.vhd:1431:55  */
  assign n4658_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1431:55  */
  assign n4659_o = n4656_o | n4658_o;
  /* T80_MCode.vhd:1431:66  */
  assign n4661_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1431:66  */
  assign n4662_o = n4659_o | n4661_o;
  /* T80_MCode.vhd:1431:77  */
  assign n4664_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1431:77  */
  assign n4665_o = n4662_o | n4664_o;
  /* T80_MCode.vhd:1431:88  */
  assign n4667_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1431:88  */
  assign n4668_o = n4665_o | n4667_o;
  /* T80_MCode.vhd:1431:99  */
  assign n4670_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1431:99  */
  assign n4671_o = n4668_o | n4670_o;
  /* T80_MCode.vhd:1455:38  */
  assign n4672_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1456:33  */
  assign n4674_o = n4672_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1456:40  */
  assign n4676_o = n4672_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1456:40  */
  assign n4677_o = n4674_o | n4676_o;
  /* T80_MCode.vhd:1458:33  */
  assign n4679_o = n4672_o == 31'b0000000000000000000000000000010;
  assign n4680_o = {n4679_o, n4677_o};
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4682_o = 3'b100;
      2'b01: n4682_o = n2179_o;
      default: n4682_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4684_o = 4'b1001;
      2'b01: n4684_o = n2182_o;
      default: n4684_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1455:33  */
  always @*
    case (n4680_o)
      2'b10: n4687_o = 3'b111;
      2'b01: n4687_o = 3'b010;
      default: n4687_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1452:25  */
  assign n4689_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1452:40  */
  assign n4691_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1452:40  */
  assign n4692_o = n4689_o | n4691_o;
  /* T80_MCode.vhd:1452:51  */
  assign n4694_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1452:51  */
  assign n4695_o = n4692_o | n4694_o;
  /* T80_MCode.vhd:1452:62  */
  assign n4697_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1452:62  */
  assign n4698_o = n4695_o | n4697_o;
  /* T80_MCode.vhd:1452:73  */
  assign n4700_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1452:73  */
  assign n4701_o = n4698_o | n4700_o;
  /* T80_MCode.vhd:1452:84  */
  assign n4703_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1452:84  */
  assign n4704_o = n4701_o | n4703_o;
  /* T80_MCode.vhd:1452:95  */
  assign n4706_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1452:95  */
  assign n4707_o = n4704_o | n4706_o;
  /* T80_MCode.vhd:1452:106  */
  assign n4709_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1452:106  */
  assign n4710_o = n4707_o | n4709_o;
  /* T80_MCode.vhd:1472:44  */
  assign n4712_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1473:51  */
  assign n4714_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1473:41  */
  assign n4717_o = n4714_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1473:41  */
  assign n4719_o = n4714_o ? 4'b1010 : n2182_o;
  /* T80_MCode.vhd:1473:41  */
  assign n4722_o = n4714_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1482:46  */
  assign n4723_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1483:41  */
  assign n4725_o = n4723_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1483:48  */
  assign n4727_o = n4723_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1483:48  */
  assign n4728_o = n4725_o | n4727_o;
  /* T80_MCode.vhd:1485:41  */
  assign n4730_o = n4723_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1491:41  */
  assign n4732_o = n4723_o == 31'b0000000000000000000000000000011;
  assign n4733_o = {n4732_o, n4730_o, n4728_o};
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4735_o = n2179_o;
      3'b010: n4735_o = 3'b100;
      3'b001: n4735_o = n2179_o;
      default: n4735_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4738_o = 1'b0;
      3'b010: n4738_o = 1'b1;
      3'b001: n4738_o = 1'b0;
      default: n4738_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4740_o = n2182_o;
      3'b010: n4740_o = 4'b1010;
      3'b001: n4740_o = n2182_o;
      default: n4740_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4743_o = 1'b0;
      3'b010: n4743_o = 1'b1;
      3'b001: n4743_o = 1'b0;
      default: n4743_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4747_o = 3'b111;
      3'b010: n4747_o = 3'b010;
      3'b001: n4747_o = 3'b010;
      default: n4747_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1482:41  */
  always @*
    case (n4733_o)
      3'b100: n4750_o = 1'b1;
      3'b010: n4750_o = 1'b0;
      3'b001: n4750_o = 1'b0;
      default: n4750_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1472:33  */
  assign n4753_o = n4712_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1472:33  */
  assign n4754_o = n4712_o ? n2179_o : n4735_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4755_o = n4712_o ? n4717_o : n4738_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4756_o = n4712_o ? n4719_o : n4740_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4757_o = n4712_o ? n4722_o : n4743_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4759_o = n4712_o ? 3'b111 : n4747_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4761_o = n4712_o ? 1'b0 : n4750_o;
  /* T80_MCode.vhd:1472:33  */
  assign n4764_o = n4712_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1463:25  */
  assign n4766_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1463:40  */
  assign n4768_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1463:40  */
  assign n4769_o = n4766_o | n4768_o;
  /* T80_MCode.vhd:1463:51  */
  assign n4771_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1463:51  */
  assign n4772_o = n4769_o | n4771_o;
  /* T80_MCode.vhd:1463:62  */
  assign n4774_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1463:62  */
  assign n4775_o = n4772_o | n4774_o;
  /* T80_MCode.vhd:1463:73  */
  assign n4777_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1463:73  */
  assign n4778_o = n4775_o | n4777_o;
  /* T80_MCode.vhd:1463:84  */
  assign n4780_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1463:84  */
  assign n4781_o = n4778_o | n4780_o;
  /* T80_MCode.vhd:1463:95  */
  assign n4783_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1463:95  */
  assign n4784_o = n4781_o | n4783_o;
  /* T80_MCode.vhd:1464:33  */
  assign n4786_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1464:33  */
  assign n4787_o = n4784_o | n4786_o;
  /* T80_MCode.vhd:1464:44  */
  assign n4789_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1464:44  */
  assign n4790_o = n4787_o | n4789_o;
  /* T80_MCode.vhd:1464:55  */
  assign n4792_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1464:55  */
  assign n4793_o = n4790_o | n4792_o;
  /* T80_MCode.vhd:1464:66  */
  assign n4795_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1464:66  */
  assign n4796_o = n4793_o | n4795_o;
  /* T80_MCode.vhd:1464:77  */
  assign n4798_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1464:77  */
  assign n4799_o = n4796_o | n4798_o;
  /* T80_MCode.vhd:1464:88  */
  assign n4801_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1464:88  */
  assign n4802_o = n4799_o | n4801_o;
  /* T80_MCode.vhd:1464:99  */
  assign n4804_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1464:99  */
  assign n4805_o = n4802_o | n4804_o;
  /* T80_MCode.vhd:1465:33  */
  assign n4807_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1465:33  */
  assign n4808_o = n4805_o | n4807_o;
  /* T80_MCode.vhd:1465:44  */
  assign n4810_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1465:44  */
  assign n4811_o = n4808_o | n4810_o;
  /* T80_MCode.vhd:1465:55  */
  assign n4813_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1465:55  */
  assign n4814_o = n4811_o | n4813_o;
  /* T80_MCode.vhd:1465:66  */
  assign n4816_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1465:66  */
  assign n4817_o = n4814_o | n4816_o;
  /* T80_MCode.vhd:1465:77  */
  assign n4819_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1465:77  */
  assign n4820_o = n4817_o | n4819_o;
  /* T80_MCode.vhd:1465:88  */
  assign n4822_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1465:88  */
  assign n4823_o = n4820_o | n4822_o;
  /* T80_MCode.vhd:1465:99  */
  assign n4825_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1465:99  */
  assign n4826_o = n4823_o | n4825_o;
  /* T80_MCode.vhd:1466:33  */
  assign n4828_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1466:33  */
  assign n4829_o = n4826_o | n4828_o;
  /* T80_MCode.vhd:1466:44  */
  assign n4831_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1466:44  */
  assign n4832_o = n4829_o | n4831_o;
  /* T80_MCode.vhd:1466:55  */
  assign n4834_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1466:55  */
  assign n4835_o = n4832_o | n4834_o;
  /* T80_MCode.vhd:1466:66  */
  assign n4837_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1466:66  */
  assign n4838_o = n4835_o | n4837_o;
  /* T80_MCode.vhd:1466:77  */
  assign n4840_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1466:77  */
  assign n4841_o = n4838_o | n4840_o;
  /* T80_MCode.vhd:1466:88  */
  assign n4843_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1466:88  */
  assign n4844_o = n4841_o | n4843_o;
  /* T80_MCode.vhd:1466:99  */
  assign n4846_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1466:99  */
  assign n4847_o = n4844_o | n4846_o;
  /* T80_MCode.vhd:1467:33  */
  assign n4849_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1467:33  */
  assign n4850_o = n4847_o | n4849_o;
  /* T80_MCode.vhd:1467:44  */
  assign n4852_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1467:44  */
  assign n4853_o = n4850_o | n4852_o;
  /* T80_MCode.vhd:1467:55  */
  assign n4855_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1467:55  */
  assign n4856_o = n4853_o | n4855_o;
  /* T80_MCode.vhd:1467:66  */
  assign n4858_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1467:66  */
  assign n4859_o = n4856_o | n4858_o;
  /* T80_MCode.vhd:1467:77  */
  assign n4861_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1467:77  */
  assign n4862_o = n4859_o | n4861_o;
  /* T80_MCode.vhd:1467:88  */
  assign n4864_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1467:88  */
  assign n4865_o = n4862_o | n4864_o;
  /* T80_MCode.vhd:1467:99  */
  assign n4867_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1467:99  */
  assign n4868_o = n4865_o | n4867_o;
  /* T80_MCode.vhd:1468:33  */
  assign n4870_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1468:33  */
  assign n4871_o = n4868_o | n4870_o;
  /* T80_MCode.vhd:1468:44  */
  assign n4873_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1468:44  */
  assign n4874_o = n4871_o | n4873_o;
  /* T80_MCode.vhd:1468:55  */
  assign n4876_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1468:55  */
  assign n4877_o = n4874_o | n4876_o;
  /* T80_MCode.vhd:1468:66  */
  assign n4879_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1468:66  */
  assign n4880_o = n4877_o | n4879_o;
  /* T80_MCode.vhd:1468:77  */
  assign n4882_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1468:77  */
  assign n4883_o = n4880_o | n4882_o;
  /* T80_MCode.vhd:1468:88  */
  assign n4885_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1468:88  */
  assign n4886_o = n4883_o | n4885_o;
  /* T80_MCode.vhd:1468:99  */
  assign n4888_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1468:99  */
  assign n4889_o = n4886_o | n4888_o;
  /* T80_MCode.vhd:1469:33  */
  assign n4891_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1469:33  */
  assign n4892_o = n4889_o | n4891_o;
  /* T80_MCode.vhd:1469:44  */
  assign n4894_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1469:44  */
  assign n4895_o = n4892_o | n4894_o;
  /* T80_MCode.vhd:1469:55  */
  assign n4897_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1469:55  */
  assign n4898_o = n4895_o | n4897_o;
  /* T80_MCode.vhd:1469:66  */
  assign n4900_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1469:66  */
  assign n4901_o = n4898_o | n4900_o;
  /* T80_MCode.vhd:1469:77  */
  assign n4903_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1469:77  */
  assign n4904_o = n4901_o | n4903_o;
  /* T80_MCode.vhd:1469:88  */
  assign n4906_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1469:88  */
  assign n4907_o = n4904_o | n4906_o;
  /* T80_MCode.vhd:1469:99  */
  assign n4909_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1469:99  */
  assign n4910_o = n4907_o | n4909_o;
  /* T80_MCode.vhd:1470:33  */
  assign n4912_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1470:33  */
  assign n4913_o = n4910_o | n4912_o;
  /* T80_MCode.vhd:1470:44  */
  assign n4915_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1470:44  */
  assign n4916_o = n4913_o | n4915_o;
  /* T80_MCode.vhd:1470:55  */
  assign n4918_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1470:55  */
  assign n4919_o = n4916_o | n4918_o;
  /* T80_MCode.vhd:1470:66  */
  assign n4921_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1470:66  */
  assign n4922_o = n4919_o | n4921_o;
  /* T80_MCode.vhd:1470:77  */
  assign n4924_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1470:77  */
  assign n4925_o = n4922_o | n4924_o;
  /* T80_MCode.vhd:1470:88  */
  assign n4927_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1470:88  */
  assign n4928_o = n4925_o | n4927_o;
  /* T80_MCode.vhd:1470:99  */
  assign n4930_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1470:99  */
  assign n4931_o = n4928_o | n4930_o;
  /* T80_MCode.vhd:1500:38  */
  assign n4932_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1501:33  */
  assign n4934_o = n4932_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1501:40  */
  assign n4936_o = n4932_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1501:40  */
  assign n4937_o = n4934_o | n4936_o;
  /* T80_MCode.vhd:1503:33  */
  assign n4939_o = n4932_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1509:33  */
  assign n4941_o = n4932_o == 31'b0000000000000000000000000000011;
  assign n4942_o = {n4941_o, n4939_o, n4937_o};
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4944_o = n2179_o;
      3'b010: n4944_o = 3'b100;
      3'b001: n4944_o = n2179_o;
      default: n4944_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4947_o = 1'b0;
      3'b010: n4947_o = 1'b1;
      3'b001: n4947_o = 1'b0;
      default: n4947_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4949_o = n2182_o;
      3'b010: n4949_o = 4'b1010;
      3'b001: n4949_o = n2182_o;
      default: n4949_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4952_o = 1'b0;
      3'b010: n4952_o = 1'b1;
      3'b001: n4952_o = 1'b0;
      default: n4952_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4956_o = 3'b111;
      3'b010: n4956_o = 3'b010;
      3'b001: n4956_o = 3'b010;
      default: n4956_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1500:33  */
  always @*
    case (n4942_o)
      3'b100: n4959_o = 1'b1;
      3'b010: n4959_o = 1'b0;
      3'b001: n4959_o = 1'b0;
      default: n4959_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1497:25  */
  assign n4961_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1497:40  */
  assign n4963_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1497:40  */
  assign n4964_o = n4961_o | n4963_o;
  /* T80_MCode.vhd:1497:51  */
  assign n4966_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1497:51  */
  assign n4967_o = n4964_o | n4966_o;
  /* T80_MCode.vhd:1497:62  */
  assign n4969_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1497:62  */
  assign n4970_o = n4967_o | n4969_o;
  /* T80_MCode.vhd:1497:73  */
  assign n4972_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1497:73  */
  assign n4973_o = n4970_o | n4972_o;
  /* T80_MCode.vhd:1497:84  */
  assign n4975_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1497:84  */
  assign n4976_o = n4973_o | n4975_o;
  /* T80_MCode.vhd:1497:95  */
  assign n4978_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1497:95  */
  assign n4979_o = n4976_o | n4978_o;
  /* T80_MCode.vhd:1497:106  */
  assign n4981_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1497:106  */
  assign n4982_o = n4979_o | n4981_o;
  /* T80_MCode.vhd:1522:44  */
  assign n4984_o = xy_state == 2'b00;
  /* T80_MCode.vhd:1523:51  */
  assign n4986_o = mcycle == 3'b001;
  /* T80_MCode.vhd:1523:41  */
  assign n4989_o = n4986_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1523:41  */
  assign n4991_o = n4986_o ? 4'b1011 : n2182_o;
  /* T80_MCode.vhd:1523:41  */
  assign n4994_o = n4986_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1532:46  */
  assign n4995_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1533:41  */
  assign n4997_o = n4995_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1533:48  */
  assign n4999_o = n4995_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1533:48  */
  assign n5000_o = n4997_o | n4999_o;
  /* T80_MCode.vhd:1535:41  */
  assign n5002_o = n4995_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1541:41  */
  assign n5004_o = n4995_o == 31'b0000000000000000000000000000011;
  assign n5005_o = {n5004_o, n5002_o, n5000_o};
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5007_o = n2179_o;
      3'b010: n5007_o = 3'b100;
      3'b001: n5007_o = n2179_o;
      default: n5007_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5010_o = 1'b0;
      3'b010: n5010_o = 1'b1;
      3'b001: n5010_o = 1'b0;
      default: n5010_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5012_o = n2182_o;
      3'b010: n5012_o = 4'b1011;
      3'b001: n5012_o = n2182_o;
      default: n5012_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5015_o = 1'b0;
      3'b010: n5015_o = 1'b1;
      3'b001: n5015_o = 1'b0;
      default: n5015_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5019_o = 3'b111;
      3'b010: n5019_o = 3'b010;
      3'b001: n5019_o = 3'b010;
      default: n5019_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1532:41  */
  always @*
    case (n5005_o)
      3'b100: n5022_o = 1'b1;
      3'b010: n5022_o = 1'b0;
      3'b001: n5022_o = 1'b0;
      default: n5022_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1522:33  */
  assign n5025_o = n4984_o ? 3'b001 : 3'b011;
  /* T80_MCode.vhd:1522:33  */
  assign n5026_o = n4984_o ? n2179_o : n5007_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5027_o = n4984_o ? n4989_o : n5010_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5028_o = n4984_o ? n4991_o : n5012_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5029_o = n4984_o ? n4994_o : n5015_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5031_o = n4984_o ? 3'b111 : n5019_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5033_o = n4984_o ? 1'b0 : n5022_o;
  /* T80_MCode.vhd:1522:33  */
  assign n5036_o = n4984_o ? 1'b0 : 1'b1;
  /* T80_MCode.vhd:1513:25  */
  assign n5038_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1513:40  */
  assign n5040_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1513:40  */
  assign n5041_o = n5038_o | n5040_o;
  /* T80_MCode.vhd:1513:51  */
  assign n5043_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1513:51  */
  assign n5044_o = n5041_o | n5043_o;
  /* T80_MCode.vhd:1513:62  */
  assign n5046_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1513:62  */
  assign n5047_o = n5044_o | n5046_o;
  /* T80_MCode.vhd:1513:73  */
  assign n5049_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1513:73  */
  assign n5050_o = n5047_o | n5049_o;
  /* T80_MCode.vhd:1513:84  */
  assign n5052_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1513:84  */
  assign n5053_o = n5050_o | n5052_o;
  /* T80_MCode.vhd:1513:95  */
  assign n5055_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1513:95  */
  assign n5056_o = n5053_o | n5055_o;
  /* T80_MCode.vhd:1514:33  */
  assign n5058_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1514:33  */
  assign n5059_o = n5056_o | n5058_o;
  /* T80_MCode.vhd:1514:44  */
  assign n5061_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1514:44  */
  assign n5062_o = n5059_o | n5061_o;
  /* T80_MCode.vhd:1514:55  */
  assign n5064_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1514:55  */
  assign n5065_o = n5062_o | n5064_o;
  /* T80_MCode.vhd:1514:66  */
  assign n5067_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1514:66  */
  assign n5068_o = n5065_o | n5067_o;
  /* T80_MCode.vhd:1514:77  */
  assign n5070_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1514:77  */
  assign n5071_o = n5068_o | n5070_o;
  /* T80_MCode.vhd:1514:88  */
  assign n5073_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1514:88  */
  assign n5074_o = n5071_o | n5073_o;
  /* T80_MCode.vhd:1514:99  */
  assign n5076_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1514:99  */
  assign n5077_o = n5074_o | n5076_o;
  /* T80_MCode.vhd:1515:33  */
  assign n5079_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1515:33  */
  assign n5080_o = n5077_o | n5079_o;
  /* T80_MCode.vhd:1515:44  */
  assign n5082_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1515:44  */
  assign n5083_o = n5080_o | n5082_o;
  /* T80_MCode.vhd:1515:55  */
  assign n5085_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1515:55  */
  assign n5086_o = n5083_o | n5085_o;
  /* T80_MCode.vhd:1515:66  */
  assign n5088_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1515:66  */
  assign n5089_o = n5086_o | n5088_o;
  /* T80_MCode.vhd:1515:77  */
  assign n5091_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1515:77  */
  assign n5092_o = n5089_o | n5091_o;
  /* T80_MCode.vhd:1515:88  */
  assign n5094_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1515:88  */
  assign n5095_o = n5092_o | n5094_o;
  /* T80_MCode.vhd:1515:99  */
  assign n5097_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1515:99  */
  assign n5098_o = n5095_o | n5097_o;
  /* T80_MCode.vhd:1516:33  */
  assign n5100_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1516:33  */
  assign n5101_o = n5098_o | n5100_o;
  /* T80_MCode.vhd:1516:44  */
  assign n5103_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1516:44  */
  assign n5104_o = n5101_o | n5103_o;
  /* T80_MCode.vhd:1516:55  */
  assign n5106_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1516:55  */
  assign n5107_o = n5104_o | n5106_o;
  /* T80_MCode.vhd:1516:66  */
  assign n5109_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1516:66  */
  assign n5110_o = n5107_o | n5109_o;
  /* T80_MCode.vhd:1516:77  */
  assign n5112_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1516:77  */
  assign n5113_o = n5110_o | n5112_o;
  /* T80_MCode.vhd:1516:88  */
  assign n5115_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1516:88  */
  assign n5116_o = n5113_o | n5115_o;
  /* T80_MCode.vhd:1516:99  */
  assign n5118_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1516:99  */
  assign n5119_o = n5116_o | n5118_o;
  /* T80_MCode.vhd:1517:33  */
  assign n5121_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1517:33  */
  assign n5122_o = n5119_o | n5121_o;
  /* T80_MCode.vhd:1517:44  */
  assign n5124_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1517:44  */
  assign n5125_o = n5122_o | n5124_o;
  /* T80_MCode.vhd:1517:55  */
  assign n5127_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1517:55  */
  assign n5128_o = n5125_o | n5127_o;
  /* T80_MCode.vhd:1517:66  */
  assign n5130_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1517:66  */
  assign n5131_o = n5128_o | n5130_o;
  /* T80_MCode.vhd:1517:77  */
  assign n5133_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1517:77  */
  assign n5134_o = n5131_o | n5133_o;
  /* T80_MCode.vhd:1517:88  */
  assign n5136_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1517:88  */
  assign n5137_o = n5134_o | n5136_o;
  /* T80_MCode.vhd:1517:99  */
  assign n5139_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1517:99  */
  assign n5140_o = n5137_o | n5139_o;
  /* T80_MCode.vhd:1518:33  */
  assign n5142_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1518:33  */
  assign n5143_o = n5140_o | n5142_o;
  /* T80_MCode.vhd:1518:44  */
  assign n5145_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1518:44  */
  assign n5146_o = n5143_o | n5145_o;
  /* T80_MCode.vhd:1518:55  */
  assign n5148_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1518:55  */
  assign n5149_o = n5146_o | n5148_o;
  /* T80_MCode.vhd:1518:66  */
  assign n5151_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1518:66  */
  assign n5152_o = n5149_o | n5151_o;
  /* T80_MCode.vhd:1518:77  */
  assign n5154_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1518:77  */
  assign n5155_o = n5152_o | n5154_o;
  /* T80_MCode.vhd:1518:88  */
  assign n5157_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1518:88  */
  assign n5158_o = n5155_o | n5157_o;
  /* T80_MCode.vhd:1518:99  */
  assign n5160_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1518:99  */
  assign n5161_o = n5158_o | n5160_o;
  /* T80_MCode.vhd:1519:33  */
  assign n5163_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1519:33  */
  assign n5164_o = n5161_o | n5163_o;
  /* T80_MCode.vhd:1519:44  */
  assign n5166_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1519:44  */
  assign n5167_o = n5164_o | n5166_o;
  /* T80_MCode.vhd:1519:55  */
  assign n5169_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1519:55  */
  assign n5170_o = n5167_o | n5169_o;
  /* T80_MCode.vhd:1519:66  */
  assign n5172_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1519:66  */
  assign n5173_o = n5170_o | n5172_o;
  /* T80_MCode.vhd:1519:77  */
  assign n5175_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1519:77  */
  assign n5176_o = n5173_o | n5175_o;
  /* T80_MCode.vhd:1519:88  */
  assign n5178_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1519:88  */
  assign n5179_o = n5176_o | n5178_o;
  /* T80_MCode.vhd:1519:99  */
  assign n5181_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1519:99  */
  assign n5182_o = n5179_o | n5181_o;
  /* T80_MCode.vhd:1520:33  */
  assign n5184_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1520:33  */
  assign n5185_o = n5182_o | n5184_o;
  /* T80_MCode.vhd:1520:44  */
  assign n5187_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1520:44  */
  assign n5188_o = n5185_o | n5187_o;
  /* T80_MCode.vhd:1520:55  */
  assign n5190_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1520:55  */
  assign n5191_o = n5188_o | n5190_o;
  /* T80_MCode.vhd:1520:66  */
  assign n5193_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1520:66  */
  assign n5194_o = n5191_o | n5193_o;
  /* T80_MCode.vhd:1520:77  */
  assign n5196_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1520:77  */
  assign n5197_o = n5194_o | n5196_o;
  /* T80_MCode.vhd:1520:88  */
  assign n5199_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1520:88  */
  assign n5200_o = n5197_o | n5199_o;
  /* T80_MCode.vhd:1520:99  */
  assign n5202_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1520:99  */
  assign n5203_o = n5200_o | n5202_o;
  /* T80_MCode.vhd:1550:38  */
  assign n5204_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1551:33  */
  assign n5206_o = n5204_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1551:40  */
  assign n5208_o = n5204_o == 31'b0000000000000000000000000000111;
  /* T80_MCode.vhd:1551:40  */
  assign n5209_o = n5206_o | n5208_o;
  /* T80_MCode.vhd:1553:33  */
  assign n5211_o = n5204_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1559:33  */
  assign n5213_o = n5204_o == 31'b0000000000000000000000000000011;
  assign n5214_o = {n5213_o, n5211_o, n5209_o};
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5216_o = n2179_o;
      3'b010: n5216_o = 3'b100;
      3'b001: n5216_o = n2179_o;
      default: n5216_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5219_o = 1'b0;
      3'b010: n5219_o = 1'b1;
      3'b001: n5219_o = 1'b0;
      default: n5219_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5221_o = n2182_o;
      3'b010: n5221_o = 4'b1011;
      3'b001: n5221_o = n2182_o;
      default: n5221_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5224_o = 1'b0;
      3'b010: n5224_o = 1'b1;
      3'b001: n5224_o = 1'b0;
      default: n5224_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5228_o = 3'b111;
      3'b010: n5228_o = 3'b010;
      3'b001: n5228_o = 3'b010;
      default: n5228_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1550:33  */
  always @*
    case (n5214_o)
      3'b100: n5231_o = 1'b1;
      3'b010: n5231_o = 1'b0;
      3'b001: n5231_o = 1'b0;
      default: n5231_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1547:25  */
  assign n5233_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1547:40  */
  assign n5235_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1547:40  */
  assign n5236_o = n5233_o | n5235_o;
  /* T80_MCode.vhd:1547:51  */
  assign n5238_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1547:51  */
  assign n5239_o = n5236_o | n5238_o;
  /* T80_MCode.vhd:1547:62  */
  assign n5241_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1547:62  */
  assign n5242_o = n5239_o | n5241_o;
  /* T80_MCode.vhd:1547:73  */
  assign n5244_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1547:73  */
  assign n5245_o = n5242_o | n5244_o;
  /* T80_MCode.vhd:1547:84  */
  assign n5247_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1547:84  */
  assign n5248_o = n5245_o | n5247_o;
  /* T80_MCode.vhd:1547:95  */
  assign n5250_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1547:95  */
  assign n5251_o = n5248_o | n5250_o;
  /* T80_MCode.vhd:1547:106  */
  assign n5253_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1547:106  */
  assign n5254_o = n5251_o | n5253_o;
  assign n5255_o = {n5254_o, n5203_o, n4982_o, n4931_o, n4710_o, n4671_o, n4469_o, n4418_o};
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5261_o = 3'b011;
      8'b01000000: n5261_o = n5025_o;
      8'b00100000: n5261_o = 3'b011;
      8'b00010000: n5261_o = n4753_o;
      8'b00001000: n5261_o = 3'b010;
      8'b00000100: n5261_o = n4496_o;
      8'b00000010: n5261_o = 3'b011;
      8'b00000001: n5261_o = n4240_o;
      default: n5261_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5263_o = n5216_o;
      8'b01000000: n5263_o = n5026_o;
      8'b00100000: n5263_o = n4944_o;
      8'b00010000: n5263_o = n4754_o;
      8'b00001000: n5263_o = n4682_o;
      8'b00000100: n5263_o = n4497_o;
      8'b00000010: n5263_o = n4431_o;
      8'b00000001: n5263_o = n4241_o;
      default: n5263_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5266_o = n5219_o;
      8'b01000000: n5266_o = n5027_o;
      8'b00100000: n5266_o = n4947_o;
      8'b00010000: n5266_o = n4755_o;
      8'b00001000: n5266_o = 1'b0;
      8'b00000100: n5266_o = 1'b0;
      8'b00000010: n5266_o = n4434_o;
      8'b00000001: n5266_o = n4242_o;
      default: n5266_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5268_o = n4197_o;
      8'b01000000: n5268_o = n4197_o;
      8'b00100000: n5268_o = n4197_o;
      8'b00010000: n5268_o = n4197_o;
      8'b00001000: n5268_o = n4197_o;
      8'b00000100: n5268_o = n4475_o;
      8'b00000010: n5268_o = n4197_o;
      8'b00000001: n5268_o = n4197_o;
      default: n5268_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5270_o = n5221_o;
      8'b01000000: n5270_o = n5028_o;
      8'b00100000: n5270_o = n4949_o;
      8'b00010000: n5270_o = n4756_o;
      8'b00001000: n5270_o = n4684_o;
      8'b00000100: n5270_o = n4499_o;
      8'b00000010: n5270_o = n4436_o;
      8'b00000001: n5270_o = n4243_o;
      default: n5270_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5273_o = n5224_o;
      8'b01000000: n5273_o = n5029_o;
      8'b00100000: n5273_o = n4952_o;
      8'b00010000: n5273_o = n4757_o;
      8'b00001000: n5273_o = 1'b0;
      8'b00000100: n5273_o = 1'b0;
      8'b00000010: n5273_o = n4439_o;
      8'b00000001: n5273_o = n4244_o;
      default: n5273_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5275_o = n5228_o;
      8'b01000000: n5275_o = n5031_o;
      8'b00100000: n5275_o = n4956_o;
      8'b00010000: n5275_o = n4759_o;
      8'b00001000: n5275_o = n4687_o;
      8'b00000100: n5275_o = n4501_o;
      8'b00000010: n5275_o = n4443_o;
      8'b00000001: n5275_o = n4246_o;
      default: n5275_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5278_o = n5231_o;
      8'b01000000: n5278_o = n5033_o;
      8'b00100000: n5278_o = n4959_o;
      8'b00010000: n5278_o = n4761_o;
      8'b00001000: n5278_o = 1'b0;
      8'b00000100: n5278_o = 1'b0;
      8'b00000010: n5278_o = n4446_o;
      8'b00000001: n5278_o = n4248_o;
      default: n5278_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1359:25  */
  always @*
    case (n5255_o)
      8'b10000000: n5281_o = 1'b0;
      8'b01000000: n5281_o = n5036_o;
      8'b00100000: n5281_o = 1'b0;
      8'b00010000: n5281_o = n4764_o;
      8'b00001000: n5281_o = 1'b0;
      8'b00000100: n5281_o = n4504_o;
      8'b00000010: n5281_o = 1'b0;
      8'b00000001: n5281_o = n4251_o;
      default: n5281_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1348:17  */
  assign n5283_o = iset == 2'b01;
  /* T80_MCode.vhd:1574:25  */
  assign n5285_o = ir == 8'b00000000;
  /* T80_MCode.vhd:1574:40  */
  assign n5287_o = ir == 8'b00000001;
  /* T80_MCode.vhd:1574:40  */
  assign n5288_o = n5285_o | n5287_o;
  /* T80_MCode.vhd:1574:51  */
  assign n5290_o = ir == 8'b00000010;
  /* T80_MCode.vhd:1574:51  */
  assign n5291_o = n5288_o | n5290_o;
  /* T80_MCode.vhd:1574:62  */
  assign n5293_o = ir == 8'b00000011;
  /* T80_MCode.vhd:1574:62  */
  assign n5294_o = n5291_o | n5293_o;
  /* T80_MCode.vhd:1574:73  */
  assign n5296_o = ir == 8'b00000100;
  /* T80_MCode.vhd:1574:73  */
  assign n5297_o = n5294_o | n5296_o;
  /* T80_MCode.vhd:1574:84  */
  assign n5299_o = ir == 8'b00000101;
  /* T80_MCode.vhd:1574:84  */
  assign n5300_o = n5297_o | n5299_o;
  /* T80_MCode.vhd:1574:95  */
  assign n5302_o = ir == 8'b00000110;
  /* T80_MCode.vhd:1574:95  */
  assign n5303_o = n5300_o | n5302_o;
  /* T80_MCode.vhd:1574:106  */
  assign n5305_o = ir == 8'b00000111;
  /* T80_MCode.vhd:1574:106  */
  assign n5306_o = n5303_o | n5305_o;
  /* T80_MCode.vhd:1575:33  */
  assign n5308_o = ir == 8'b00001000;
  /* T80_MCode.vhd:1575:33  */
  assign n5309_o = n5306_o | n5308_o;
  /* T80_MCode.vhd:1575:44  */
  assign n5311_o = ir == 8'b00001001;
  /* T80_MCode.vhd:1575:44  */
  assign n5312_o = n5309_o | n5311_o;
  /* T80_MCode.vhd:1575:55  */
  assign n5314_o = ir == 8'b00001010;
  /* T80_MCode.vhd:1575:55  */
  assign n5315_o = n5312_o | n5314_o;
  /* T80_MCode.vhd:1575:66  */
  assign n5317_o = ir == 8'b00001011;
  /* T80_MCode.vhd:1575:66  */
  assign n5318_o = n5315_o | n5317_o;
  /* T80_MCode.vhd:1575:77  */
  assign n5320_o = ir == 8'b00001100;
  /* T80_MCode.vhd:1575:77  */
  assign n5321_o = n5318_o | n5320_o;
  /* T80_MCode.vhd:1575:88  */
  assign n5323_o = ir == 8'b00001101;
  /* T80_MCode.vhd:1575:88  */
  assign n5324_o = n5321_o | n5323_o;
  /* T80_MCode.vhd:1575:99  */
  assign n5326_o = ir == 8'b00001110;
  /* T80_MCode.vhd:1575:99  */
  assign n5327_o = n5324_o | n5326_o;
  /* T80_MCode.vhd:1575:110  */
  assign n5329_o = ir == 8'b00001111;
  /* T80_MCode.vhd:1575:110  */
  assign n5330_o = n5327_o | n5329_o;
  /* T80_MCode.vhd:1576:33  */
  assign n5332_o = ir == 8'b00010000;
  /* T80_MCode.vhd:1576:33  */
  assign n5333_o = n5330_o | n5332_o;
  /* T80_MCode.vhd:1576:44  */
  assign n5335_o = ir == 8'b00010001;
  /* T80_MCode.vhd:1576:44  */
  assign n5336_o = n5333_o | n5335_o;
  /* T80_MCode.vhd:1576:55  */
  assign n5338_o = ir == 8'b00010010;
  /* T80_MCode.vhd:1576:55  */
  assign n5339_o = n5336_o | n5338_o;
  /* T80_MCode.vhd:1576:66  */
  assign n5341_o = ir == 8'b00010011;
  /* T80_MCode.vhd:1576:66  */
  assign n5342_o = n5339_o | n5341_o;
  /* T80_MCode.vhd:1576:77  */
  assign n5344_o = ir == 8'b00010100;
  /* T80_MCode.vhd:1576:77  */
  assign n5345_o = n5342_o | n5344_o;
  /* T80_MCode.vhd:1576:88  */
  assign n5347_o = ir == 8'b00010101;
  /* T80_MCode.vhd:1576:88  */
  assign n5348_o = n5345_o | n5347_o;
  /* T80_MCode.vhd:1576:99  */
  assign n5350_o = ir == 8'b00010110;
  /* T80_MCode.vhd:1576:99  */
  assign n5351_o = n5348_o | n5350_o;
  /* T80_MCode.vhd:1576:110  */
  assign n5353_o = ir == 8'b00010111;
  /* T80_MCode.vhd:1576:110  */
  assign n5354_o = n5351_o | n5353_o;
  /* T80_MCode.vhd:1577:33  */
  assign n5356_o = ir == 8'b00011000;
  /* T80_MCode.vhd:1577:33  */
  assign n5357_o = n5354_o | n5356_o;
  /* T80_MCode.vhd:1577:44  */
  assign n5359_o = ir == 8'b00011001;
  /* T80_MCode.vhd:1577:44  */
  assign n5360_o = n5357_o | n5359_o;
  /* T80_MCode.vhd:1577:55  */
  assign n5362_o = ir == 8'b00011010;
  /* T80_MCode.vhd:1577:55  */
  assign n5363_o = n5360_o | n5362_o;
  /* T80_MCode.vhd:1577:66  */
  assign n5365_o = ir == 8'b00011011;
  /* T80_MCode.vhd:1577:66  */
  assign n5366_o = n5363_o | n5365_o;
  /* T80_MCode.vhd:1577:77  */
  assign n5368_o = ir == 8'b00011100;
  /* T80_MCode.vhd:1577:77  */
  assign n5369_o = n5366_o | n5368_o;
  /* T80_MCode.vhd:1577:88  */
  assign n5371_o = ir == 8'b00011101;
  /* T80_MCode.vhd:1577:88  */
  assign n5372_o = n5369_o | n5371_o;
  /* T80_MCode.vhd:1577:99  */
  assign n5374_o = ir == 8'b00011110;
  /* T80_MCode.vhd:1577:99  */
  assign n5375_o = n5372_o | n5374_o;
  /* T80_MCode.vhd:1577:110  */
  assign n5377_o = ir == 8'b00011111;
  /* T80_MCode.vhd:1577:110  */
  assign n5378_o = n5375_o | n5377_o;
  /* T80_MCode.vhd:1578:33  */
  assign n5380_o = ir == 8'b00100000;
  /* T80_MCode.vhd:1578:33  */
  assign n5381_o = n5378_o | n5380_o;
  /* T80_MCode.vhd:1578:44  */
  assign n5383_o = ir == 8'b00100001;
  /* T80_MCode.vhd:1578:44  */
  assign n5384_o = n5381_o | n5383_o;
  /* T80_MCode.vhd:1578:55  */
  assign n5386_o = ir == 8'b00100010;
  /* T80_MCode.vhd:1578:55  */
  assign n5387_o = n5384_o | n5386_o;
  /* T80_MCode.vhd:1578:66  */
  assign n5389_o = ir == 8'b00100011;
  /* T80_MCode.vhd:1578:66  */
  assign n5390_o = n5387_o | n5389_o;
  /* T80_MCode.vhd:1578:77  */
  assign n5392_o = ir == 8'b00100100;
  /* T80_MCode.vhd:1578:77  */
  assign n5393_o = n5390_o | n5392_o;
  /* T80_MCode.vhd:1578:88  */
  assign n5395_o = ir == 8'b00100101;
  /* T80_MCode.vhd:1578:88  */
  assign n5396_o = n5393_o | n5395_o;
  /* T80_MCode.vhd:1578:99  */
  assign n5398_o = ir == 8'b00100110;
  /* T80_MCode.vhd:1578:99  */
  assign n5399_o = n5396_o | n5398_o;
  /* T80_MCode.vhd:1578:110  */
  assign n5401_o = ir == 8'b00100111;
  /* T80_MCode.vhd:1578:110  */
  assign n5402_o = n5399_o | n5401_o;
  /* T80_MCode.vhd:1579:33  */
  assign n5404_o = ir == 8'b00101000;
  /* T80_MCode.vhd:1579:33  */
  assign n5405_o = n5402_o | n5404_o;
  /* T80_MCode.vhd:1579:44  */
  assign n5407_o = ir == 8'b00101001;
  /* T80_MCode.vhd:1579:44  */
  assign n5408_o = n5405_o | n5407_o;
  /* T80_MCode.vhd:1579:55  */
  assign n5410_o = ir == 8'b00101010;
  /* T80_MCode.vhd:1579:55  */
  assign n5411_o = n5408_o | n5410_o;
  /* T80_MCode.vhd:1579:66  */
  assign n5413_o = ir == 8'b00101011;
  /* T80_MCode.vhd:1579:66  */
  assign n5414_o = n5411_o | n5413_o;
  /* T80_MCode.vhd:1579:77  */
  assign n5416_o = ir == 8'b00101100;
  /* T80_MCode.vhd:1579:77  */
  assign n5417_o = n5414_o | n5416_o;
  /* T80_MCode.vhd:1579:88  */
  assign n5419_o = ir == 8'b00101101;
  /* T80_MCode.vhd:1579:88  */
  assign n5420_o = n5417_o | n5419_o;
  /* T80_MCode.vhd:1579:99  */
  assign n5422_o = ir == 8'b00101110;
  /* T80_MCode.vhd:1579:99  */
  assign n5423_o = n5420_o | n5422_o;
  /* T80_MCode.vhd:1579:110  */
  assign n5425_o = ir == 8'b00101111;
  /* T80_MCode.vhd:1579:110  */
  assign n5426_o = n5423_o | n5425_o;
  /* T80_MCode.vhd:1580:33  */
  assign n5428_o = ir == 8'b00110000;
  /* T80_MCode.vhd:1580:33  */
  assign n5429_o = n5426_o | n5428_o;
  /* T80_MCode.vhd:1580:44  */
  assign n5431_o = ir == 8'b00110001;
  /* T80_MCode.vhd:1580:44  */
  assign n5432_o = n5429_o | n5431_o;
  /* T80_MCode.vhd:1580:55  */
  assign n5434_o = ir == 8'b00110010;
  /* T80_MCode.vhd:1580:55  */
  assign n5435_o = n5432_o | n5434_o;
  /* T80_MCode.vhd:1580:66  */
  assign n5437_o = ir == 8'b00110011;
  /* T80_MCode.vhd:1580:66  */
  assign n5438_o = n5435_o | n5437_o;
  /* T80_MCode.vhd:1580:77  */
  assign n5440_o = ir == 8'b00110100;
  /* T80_MCode.vhd:1580:77  */
  assign n5441_o = n5438_o | n5440_o;
  /* T80_MCode.vhd:1580:88  */
  assign n5443_o = ir == 8'b00110101;
  /* T80_MCode.vhd:1580:88  */
  assign n5444_o = n5441_o | n5443_o;
  /* T80_MCode.vhd:1580:99  */
  assign n5446_o = ir == 8'b00110110;
  /* T80_MCode.vhd:1580:99  */
  assign n5447_o = n5444_o | n5446_o;
  /* T80_MCode.vhd:1580:110  */
  assign n5449_o = ir == 8'b00110111;
  /* T80_MCode.vhd:1580:110  */
  assign n5450_o = n5447_o | n5449_o;
  /* T80_MCode.vhd:1581:33  */
  assign n5452_o = ir == 8'b00111000;
  /* T80_MCode.vhd:1581:33  */
  assign n5453_o = n5450_o | n5452_o;
  /* T80_MCode.vhd:1581:44  */
  assign n5455_o = ir == 8'b00111001;
  /* T80_MCode.vhd:1581:44  */
  assign n5456_o = n5453_o | n5455_o;
  /* T80_MCode.vhd:1581:55  */
  assign n5458_o = ir == 8'b00111010;
  /* T80_MCode.vhd:1581:55  */
  assign n5459_o = n5456_o | n5458_o;
  /* T80_MCode.vhd:1581:66  */
  assign n5461_o = ir == 8'b00111011;
  /* T80_MCode.vhd:1581:66  */
  assign n5462_o = n5459_o | n5461_o;
  /* T80_MCode.vhd:1581:77  */
  assign n5464_o = ir == 8'b00111100;
  /* T80_MCode.vhd:1581:77  */
  assign n5465_o = n5462_o | n5464_o;
  /* T80_MCode.vhd:1581:88  */
  assign n5467_o = ir == 8'b00111101;
  /* T80_MCode.vhd:1581:88  */
  assign n5468_o = n5465_o | n5467_o;
  /* T80_MCode.vhd:1581:99  */
  assign n5470_o = ir == 8'b00111110;
  /* T80_MCode.vhd:1581:99  */
  assign n5471_o = n5468_o | n5470_o;
  /* T80_MCode.vhd:1581:110  */
  assign n5473_o = ir == 8'b00111111;
  /* T80_MCode.vhd:1581:110  */
  assign n5474_o = n5471_o | n5473_o;
  /* T80_MCode.vhd:1584:33  */
  assign n5476_o = ir == 8'b10000000;
  /* T80_MCode.vhd:1584:33  */
  assign n5477_o = n5474_o | n5476_o;
  /* T80_MCode.vhd:1584:44  */
  assign n5479_o = ir == 8'b10000001;
  /* T80_MCode.vhd:1584:44  */
  assign n5480_o = n5477_o | n5479_o;
  /* T80_MCode.vhd:1584:55  */
  assign n5482_o = ir == 8'b10000010;
  /* T80_MCode.vhd:1584:55  */
  assign n5483_o = n5480_o | n5482_o;
  /* T80_MCode.vhd:1584:66  */
  assign n5485_o = ir == 8'b10000011;
  /* T80_MCode.vhd:1584:66  */
  assign n5486_o = n5483_o | n5485_o;
  /* T80_MCode.vhd:1584:77  */
  assign n5488_o = ir == 8'b10000100;
  /* T80_MCode.vhd:1584:77  */
  assign n5489_o = n5486_o | n5488_o;
  /* T80_MCode.vhd:1584:88  */
  assign n5491_o = ir == 8'b10000101;
  /* T80_MCode.vhd:1584:88  */
  assign n5492_o = n5489_o | n5491_o;
  /* T80_MCode.vhd:1584:99  */
  assign n5494_o = ir == 8'b10000110;
  /* T80_MCode.vhd:1584:99  */
  assign n5495_o = n5492_o | n5494_o;
  /* T80_MCode.vhd:1584:110  */
  assign n5497_o = ir == 8'b10000111;
  /* T80_MCode.vhd:1584:110  */
  assign n5498_o = n5495_o | n5497_o;
  /* T80_MCode.vhd:1585:33  */
  assign n5500_o = ir == 8'b10001000;
  /* T80_MCode.vhd:1585:33  */
  assign n5501_o = n5498_o | n5500_o;
  /* T80_MCode.vhd:1585:44  */
  assign n5503_o = ir == 8'b10001001;
  /* T80_MCode.vhd:1585:44  */
  assign n5504_o = n5501_o | n5503_o;
  /* T80_MCode.vhd:1585:55  */
  assign n5506_o = ir == 8'b10001010;
  /* T80_MCode.vhd:1585:55  */
  assign n5507_o = n5504_o | n5506_o;
  /* T80_MCode.vhd:1585:66  */
  assign n5509_o = ir == 8'b10001011;
  /* T80_MCode.vhd:1585:66  */
  assign n5510_o = n5507_o | n5509_o;
  /* T80_MCode.vhd:1585:77  */
  assign n5512_o = ir == 8'b10001100;
  /* T80_MCode.vhd:1585:77  */
  assign n5513_o = n5510_o | n5512_o;
  /* T80_MCode.vhd:1585:88  */
  assign n5515_o = ir == 8'b10001101;
  /* T80_MCode.vhd:1585:88  */
  assign n5516_o = n5513_o | n5515_o;
  /* T80_MCode.vhd:1585:99  */
  assign n5518_o = ir == 8'b10001110;
  /* T80_MCode.vhd:1585:99  */
  assign n5519_o = n5516_o | n5518_o;
  /* T80_MCode.vhd:1585:110  */
  assign n5521_o = ir == 8'b10001111;
  /* T80_MCode.vhd:1585:110  */
  assign n5522_o = n5519_o | n5521_o;
  /* T80_MCode.vhd:1586:33  */
  assign n5524_o = ir == 8'b10010000;
  /* T80_MCode.vhd:1586:33  */
  assign n5525_o = n5522_o | n5524_o;
  /* T80_MCode.vhd:1586:44  */
  assign n5527_o = ir == 8'b10010001;
  /* T80_MCode.vhd:1586:44  */
  assign n5528_o = n5525_o | n5527_o;
  /* T80_MCode.vhd:1586:55  */
  assign n5530_o = ir == 8'b10010010;
  /* T80_MCode.vhd:1586:55  */
  assign n5531_o = n5528_o | n5530_o;
  /* T80_MCode.vhd:1586:66  */
  assign n5533_o = ir == 8'b10010011;
  /* T80_MCode.vhd:1586:66  */
  assign n5534_o = n5531_o | n5533_o;
  /* T80_MCode.vhd:1586:77  */
  assign n5536_o = ir == 8'b10010100;
  /* T80_MCode.vhd:1586:77  */
  assign n5537_o = n5534_o | n5536_o;
  /* T80_MCode.vhd:1586:88  */
  assign n5539_o = ir == 8'b10010101;
  /* T80_MCode.vhd:1586:88  */
  assign n5540_o = n5537_o | n5539_o;
  /* T80_MCode.vhd:1586:99  */
  assign n5542_o = ir == 8'b10010110;
  /* T80_MCode.vhd:1586:99  */
  assign n5543_o = n5540_o | n5542_o;
  /* T80_MCode.vhd:1586:110  */
  assign n5545_o = ir == 8'b10010111;
  /* T80_MCode.vhd:1586:110  */
  assign n5546_o = n5543_o | n5545_o;
  /* T80_MCode.vhd:1587:33  */
  assign n5548_o = ir == 8'b10011000;
  /* T80_MCode.vhd:1587:33  */
  assign n5549_o = n5546_o | n5548_o;
  /* T80_MCode.vhd:1587:44  */
  assign n5551_o = ir == 8'b10011001;
  /* T80_MCode.vhd:1587:44  */
  assign n5552_o = n5549_o | n5551_o;
  /* T80_MCode.vhd:1587:55  */
  assign n5554_o = ir == 8'b10011010;
  /* T80_MCode.vhd:1587:55  */
  assign n5555_o = n5552_o | n5554_o;
  /* T80_MCode.vhd:1587:66  */
  assign n5557_o = ir == 8'b10011011;
  /* T80_MCode.vhd:1587:66  */
  assign n5558_o = n5555_o | n5557_o;
  /* T80_MCode.vhd:1587:77  */
  assign n5560_o = ir == 8'b10011100;
  /* T80_MCode.vhd:1587:77  */
  assign n5561_o = n5558_o | n5560_o;
  /* T80_MCode.vhd:1587:88  */
  assign n5563_o = ir == 8'b10011101;
  /* T80_MCode.vhd:1587:88  */
  assign n5564_o = n5561_o | n5563_o;
  /* T80_MCode.vhd:1587:99  */
  assign n5566_o = ir == 8'b10011110;
  /* T80_MCode.vhd:1587:99  */
  assign n5567_o = n5564_o | n5566_o;
  /* T80_MCode.vhd:1587:110  */
  assign n5569_o = ir == 8'b10011111;
  /* T80_MCode.vhd:1587:110  */
  assign n5570_o = n5567_o | n5569_o;
  /* T80_MCode.vhd:1588:33  */
  assign n5572_o = ir == 8'b10100100;
  /* T80_MCode.vhd:1588:33  */
  assign n5573_o = n5570_o | n5572_o;
  /* T80_MCode.vhd:1588:88  */
  assign n5575_o = ir == 8'b10100101;
  /* T80_MCode.vhd:1588:88  */
  assign n5576_o = n5573_o | n5575_o;
  /* T80_MCode.vhd:1588:99  */
  assign n5578_o = ir == 8'b10100110;
  /* T80_MCode.vhd:1588:99  */
  assign n5579_o = n5576_o | n5578_o;
  /* T80_MCode.vhd:1588:110  */
  assign n5581_o = ir == 8'b10100111;
  /* T80_MCode.vhd:1588:110  */
  assign n5582_o = n5579_o | n5581_o;
  /* T80_MCode.vhd:1589:33  */
  assign n5584_o = ir == 8'b10101100;
  /* T80_MCode.vhd:1589:33  */
  assign n5585_o = n5582_o | n5584_o;
  /* T80_MCode.vhd:1589:88  */
  assign n5587_o = ir == 8'b10101101;
  /* T80_MCode.vhd:1589:88  */
  assign n5588_o = n5585_o | n5587_o;
  /* T80_MCode.vhd:1589:99  */
  assign n5590_o = ir == 8'b10101110;
  /* T80_MCode.vhd:1589:99  */
  assign n5591_o = n5588_o | n5590_o;
  /* T80_MCode.vhd:1589:110  */
  assign n5593_o = ir == 8'b10101111;
  /* T80_MCode.vhd:1589:110  */
  assign n5594_o = n5591_o | n5593_o;
  /* T80_MCode.vhd:1590:33  */
  assign n5596_o = ir == 8'b10110100;
  /* T80_MCode.vhd:1590:33  */
  assign n5597_o = n5594_o | n5596_o;
  /* T80_MCode.vhd:1590:88  */
  assign n5599_o = ir == 8'b10110101;
  /* T80_MCode.vhd:1590:88  */
  assign n5600_o = n5597_o | n5599_o;
  /* T80_MCode.vhd:1590:99  */
  assign n5602_o = ir == 8'b10110110;
  /* T80_MCode.vhd:1590:99  */
  assign n5603_o = n5600_o | n5602_o;
  /* T80_MCode.vhd:1590:110  */
  assign n5605_o = ir == 8'b10110111;
  /* T80_MCode.vhd:1590:110  */
  assign n5606_o = n5603_o | n5605_o;
  /* T80_MCode.vhd:1591:33  */
  assign n5608_o = ir == 8'b10111100;
  /* T80_MCode.vhd:1591:33  */
  assign n5609_o = n5606_o | n5608_o;
  /* T80_MCode.vhd:1591:88  */
  assign n5611_o = ir == 8'b10111101;
  /* T80_MCode.vhd:1591:88  */
  assign n5612_o = n5609_o | n5611_o;
  /* T80_MCode.vhd:1591:99  */
  assign n5614_o = ir == 8'b10111110;
  /* T80_MCode.vhd:1591:99  */
  assign n5615_o = n5612_o | n5614_o;
  /* T80_MCode.vhd:1591:110  */
  assign n5617_o = ir == 8'b10111111;
  /* T80_MCode.vhd:1591:110  */
  assign n5618_o = n5615_o | n5617_o;
  /* T80_MCode.vhd:1592:33  */
  assign n5620_o = ir == 8'b11000000;
  /* T80_MCode.vhd:1592:33  */
  assign n5621_o = n5618_o | n5620_o;
  /* T80_MCode.vhd:1592:44  */
  assign n5623_o = ir == 8'b11000001;
  /* T80_MCode.vhd:1592:44  */
  assign n5624_o = n5621_o | n5623_o;
  /* T80_MCode.vhd:1592:55  */
  assign n5626_o = ir == 8'b11000010;
  /* T80_MCode.vhd:1592:55  */
  assign n5627_o = n5624_o | n5626_o;
  /* T80_MCode.vhd:1592:66  */
  assign n5629_o = ir == 8'b11000011;
  /* T80_MCode.vhd:1592:66  */
  assign n5630_o = n5627_o | n5629_o;
  /* T80_MCode.vhd:1592:77  */
  assign n5632_o = ir == 8'b11000100;
  /* T80_MCode.vhd:1592:77  */
  assign n5633_o = n5630_o | n5632_o;
  /* T80_MCode.vhd:1592:88  */
  assign n5635_o = ir == 8'b11000101;
  /* T80_MCode.vhd:1592:88  */
  assign n5636_o = n5633_o | n5635_o;
  /* T80_MCode.vhd:1592:99  */
  assign n5638_o = ir == 8'b11000110;
  /* T80_MCode.vhd:1592:99  */
  assign n5639_o = n5636_o | n5638_o;
  /* T80_MCode.vhd:1592:110  */
  assign n5641_o = ir == 8'b11000111;
  /* T80_MCode.vhd:1592:110  */
  assign n5642_o = n5639_o | n5641_o;
  /* T80_MCode.vhd:1593:33  */
  assign n5644_o = ir == 8'b11001000;
  /* T80_MCode.vhd:1593:33  */
  assign n5645_o = n5642_o | n5644_o;
  /* T80_MCode.vhd:1593:44  */
  assign n5647_o = ir == 8'b11001001;
  /* T80_MCode.vhd:1593:44  */
  assign n5648_o = n5645_o | n5647_o;
  /* T80_MCode.vhd:1593:55  */
  assign n5650_o = ir == 8'b11001010;
  /* T80_MCode.vhd:1593:55  */
  assign n5651_o = n5648_o | n5650_o;
  /* T80_MCode.vhd:1593:66  */
  assign n5653_o = ir == 8'b11001011;
  /* T80_MCode.vhd:1593:66  */
  assign n5654_o = n5651_o | n5653_o;
  /* T80_MCode.vhd:1593:77  */
  assign n5656_o = ir == 8'b11001100;
  /* T80_MCode.vhd:1593:77  */
  assign n5657_o = n5654_o | n5656_o;
  /* T80_MCode.vhd:1593:88  */
  assign n5659_o = ir == 8'b11001101;
  /* T80_MCode.vhd:1593:88  */
  assign n5660_o = n5657_o | n5659_o;
  /* T80_MCode.vhd:1593:99  */
  assign n5662_o = ir == 8'b11001110;
  /* T80_MCode.vhd:1593:99  */
  assign n5663_o = n5660_o | n5662_o;
  /* T80_MCode.vhd:1593:110  */
  assign n5665_o = ir == 8'b11001111;
  /* T80_MCode.vhd:1593:110  */
  assign n5666_o = n5663_o | n5665_o;
  /* T80_MCode.vhd:1594:33  */
  assign n5668_o = ir == 8'b11010000;
  /* T80_MCode.vhd:1594:33  */
  assign n5669_o = n5666_o | n5668_o;
  /* T80_MCode.vhd:1594:44  */
  assign n5671_o = ir == 8'b11010001;
  /* T80_MCode.vhd:1594:44  */
  assign n5672_o = n5669_o | n5671_o;
  /* T80_MCode.vhd:1594:55  */
  assign n5674_o = ir == 8'b11010010;
  /* T80_MCode.vhd:1594:55  */
  assign n5675_o = n5672_o | n5674_o;
  /* T80_MCode.vhd:1594:66  */
  assign n5677_o = ir == 8'b11010011;
  /* T80_MCode.vhd:1594:66  */
  assign n5678_o = n5675_o | n5677_o;
  /* T80_MCode.vhd:1594:77  */
  assign n5680_o = ir == 8'b11010100;
  /* T80_MCode.vhd:1594:77  */
  assign n5681_o = n5678_o | n5680_o;
  /* T80_MCode.vhd:1594:88  */
  assign n5683_o = ir == 8'b11010101;
  /* T80_MCode.vhd:1594:88  */
  assign n5684_o = n5681_o | n5683_o;
  /* T80_MCode.vhd:1594:99  */
  assign n5686_o = ir == 8'b11010110;
  /* T80_MCode.vhd:1594:99  */
  assign n5687_o = n5684_o | n5686_o;
  /* T80_MCode.vhd:1594:110  */
  assign n5689_o = ir == 8'b11010111;
  /* T80_MCode.vhd:1594:110  */
  assign n5690_o = n5687_o | n5689_o;
  /* T80_MCode.vhd:1595:33  */
  assign n5692_o = ir == 8'b11011000;
  /* T80_MCode.vhd:1595:33  */
  assign n5693_o = n5690_o | n5692_o;
  /* T80_MCode.vhd:1595:44  */
  assign n5695_o = ir == 8'b11011001;
  /* T80_MCode.vhd:1595:44  */
  assign n5696_o = n5693_o | n5695_o;
  /* T80_MCode.vhd:1595:55  */
  assign n5698_o = ir == 8'b11011010;
  /* T80_MCode.vhd:1595:55  */
  assign n5699_o = n5696_o | n5698_o;
  /* T80_MCode.vhd:1595:66  */
  assign n5701_o = ir == 8'b11011011;
  /* T80_MCode.vhd:1595:66  */
  assign n5702_o = n5699_o | n5701_o;
  /* T80_MCode.vhd:1595:77  */
  assign n5704_o = ir == 8'b11011100;
  /* T80_MCode.vhd:1595:77  */
  assign n5705_o = n5702_o | n5704_o;
  /* T80_MCode.vhd:1595:88  */
  assign n5707_o = ir == 8'b11011101;
  /* T80_MCode.vhd:1595:88  */
  assign n5708_o = n5705_o | n5707_o;
  /* T80_MCode.vhd:1595:99  */
  assign n5710_o = ir == 8'b11011110;
  /* T80_MCode.vhd:1595:99  */
  assign n5711_o = n5708_o | n5710_o;
  /* T80_MCode.vhd:1595:110  */
  assign n5713_o = ir == 8'b11011111;
  /* T80_MCode.vhd:1595:110  */
  assign n5714_o = n5711_o | n5713_o;
  /* T80_MCode.vhd:1596:33  */
  assign n5716_o = ir == 8'b11100000;
  /* T80_MCode.vhd:1596:33  */
  assign n5717_o = n5714_o | n5716_o;
  /* T80_MCode.vhd:1596:44  */
  assign n5719_o = ir == 8'b11100001;
  /* T80_MCode.vhd:1596:44  */
  assign n5720_o = n5717_o | n5719_o;
  /* T80_MCode.vhd:1596:55  */
  assign n5722_o = ir == 8'b11100010;
  /* T80_MCode.vhd:1596:55  */
  assign n5723_o = n5720_o | n5722_o;
  /* T80_MCode.vhd:1596:66  */
  assign n5725_o = ir == 8'b11100011;
  /* T80_MCode.vhd:1596:66  */
  assign n5726_o = n5723_o | n5725_o;
  /* T80_MCode.vhd:1596:77  */
  assign n5728_o = ir == 8'b11100100;
  /* T80_MCode.vhd:1596:77  */
  assign n5729_o = n5726_o | n5728_o;
  /* T80_MCode.vhd:1596:88  */
  assign n5731_o = ir == 8'b11100101;
  /* T80_MCode.vhd:1596:88  */
  assign n5732_o = n5729_o | n5731_o;
  /* T80_MCode.vhd:1596:99  */
  assign n5734_o = ir == 8'b11100110;
  /* T80_MCode.vhd:1596:99  */
  assign n5735_o = n5732_o | n5734_o;
  /* T80_MCode.vhd:1596:110  */
  assign n5737_o = ir == 8'b11100111;
  /* T80_MCode.vhd:1596:110  */
  assign n5738_o = n5735_o | n5737_o;
  /* T80_MCode.vhd:1597:33  */
  assign n5740_o = ir == 8'b11101000;
  /* T80_MCode.vhd:1597:33  */
  assign n5741_o = n5738_o | n5740_o;
  /* T80_MCode.vhd:1597:44  */
  assign n5743_o = ir == 8'b11101001;
  /* T80_MCode.vhd:1597:44  */
  assign n5744_o = n5741_o | n5743_o;
  /* T80_MCode.vhd:1597:55  */
  assign n5746_o = ir == 8'b11101010;
  /* T80_MCode.vhd:1597:55  */
  assign n5747_o = n5744_o | n5746_o;
  /* T80_MCode.vhd:1597:66  */
  assign n5749_o = ir == 8'b11101011;
  /* T80_MCode.vhd:1597:66  */
  assign n5750_o = n5747_o | n5749_o;
  /* T80_MCode.vhd:1597:77  */
  assign n5752_o = ir == 8'b11101100;
  /* T80_MCode.vhd:1597:77  */
  assign n5753_o = n5750_o | n5752_o;
  /* T80_MCode.vhd:1597:88  */
  assign n5755_o = ir == 8'b11101101;
  /* T80_MCode.vhd:1597:88  */
  assign n5756_o = n5753_o | n5755_o;
  /* T80_MCode.vhd:1597:99  */
  assign n5758_o = ir == 8'b11101110;
  /* T80_MCode.vhd:1597:99  */
  assign n5759_o = n5756_o | n5758_o;
  /* T80_MCode.vhd:1597:110  */
  assign n5761_o = ir == 8'b11101111;
  /* T80_MCode.vhd:1597:110  */
  assign n5762_o = n5759_o | n5761_o;
  /* T80_MCode.vhd:1598:33  */
  assign n5764_o = ir == 8'b11110000;
  /* T80_MCode.vhd:1598:33  */
  assign n5765_o = n5762_o | n5764_o;
  /* T80_MCode.vhd:1598:44  */
  assign n5767_o = ir == 8'b11110001;
  /* T80_MCode.vhd:1598:44  */
  assign n5768_o = n5765_o | n5767_o;
  /* T80_MCode.vhd:1598:55  */
  assign n5770_o = ir == 8'b11110010;
  /* T80_MCode.vhd:1598:55  */
  assign n5771_o = n5768_o | n5770_o;
  /* T80_MCode.vhd:1598:66  */
  assign n5773_o = ir == 8'b11110011;
  /* T80_MCode.vhd:1598:66  */
  assign n5774_o = n5771_o | n5773_o;
  /* T80_MCode.vhd:1598:77  */
  assign n5776_o = ir == 8'b11110100;
  /* T80_MCode.vhd:1598:77  */
  assign n5777_o = n5774_o | n5776_o;
  /* T80_MCode.vhd:1598:88  */
  assign n5779_o = ir == 8'b11110101;
  /* T80_MCode.vhd:1598:88  */
  assign n5780_o = n5777_o | n5779_o;
  /* T80_MCode.vhd:1598:99  */
  assign n5782_o = ir == 8'b11110110;
  /* T80_MCode.vhd:1598:99  */
  assign n5783_o = n5780_o | n5782_o;
  /* T80_MCode.vhd:1598:110  */
  assign n5785_o = ir == 8'b11110111;
  /* T80_MCode.vhd:1598:110  */
  assign n5786_o = n5783_o | n5785_o;
  /* T80_MCode.vhd:1599:33  */
  assign n5788_o = ir == 8'b11111000;
  /* T80_MCode.vhd:1599:33  */
  assign n5789_o = n5786_o | n5788_o;
  /* T80_MCode.vhd:1599:44  */
  assign n5791_o = ir == 8'b11111001;
  /* T80_MCode.vhd:1599:44  */
  assign n5792_o = n5789_o | n5791_o;
  /* T80_MCode.vhd:1599:55  */
  assign n5794_o = ir == 8'b11111010;
  /* T80_MCode.vhd:1599:55  */
  assign n5795_o = n5792_o | n5794_o;
  /* T80_MCode.vhd:1599:66  */
  assign n5797_o = ir == 8'b11111011;
  /* T80_MCode.vhd:1599:66  */
  assign n5798_o = n5795_o | n5797_o;
  /* T80_MCode.vhd:1599:77  */
  assign n5800_o = ir == 8'b11111100;
  /* T80_MCode.vhd:1599:77  */
  assign n5801_o = n5798_o | n5800_o;
  /* T80_MCode.vhd:1599:88  */
  assign n5803_o = ir == 8'b11111101;
  /* T80_MCode.vhd:1599:88  */
  assign n5804_o = n5801_o | n5803_o;
  /* T80_MCode.vhd:1599:99  */
  assign n5806_o = ir == 8'b11111110;
  /* T80_MCode.vhd:1599:99  */
  assign n5807_o = n5804_o | n5806_o;
  /* T80_MCode.vhd:1599:110  */
  assign n5809_o = ir == 8'b11111111;
  /* T80_MCode.vhd:1599:110  */
  assign n5810_o = n5807_o | n5809_o;
  /* T80_MCode.vhd:1601:25  */
  assign n5812_o = ir == 8'b01111110;
  /* T80_MCode.vhd:1601:40  */
  assign n5814_o = ir == 8'b01111111;
  /* T80_MCode.vhd:1601:40  */
  assign n5815_o = n5812_o | n5814_o;
  /* T80_MCode.vhd:1605:25  */
  assign n5817_o = ir == 8'b01010111;
  /* T80_MCode.vhd:1609:25  */
  assign n5819_o = ir == 8'b01011111;
  /* T80_MCode.vhd:1613:25  */
  assign n5821_o = ir == 8'b01000111;
  /* T80_MCode.vhd:1617:25  */
  assign n5823_o = ir == 8'b01001111;
  /* T80_MCode.vhd:1625:38  */
  assign n5824_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1626:33  */
  assign n5826_o = n5824_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1629:33  */
  assign n5828_o = n5824_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1635:46  */
  assign n5829_o = ir[5:4];
  /* T80_MCode.vhd:1635:59  */
  assign n5831_o = n5829_o == 2'b11;
  /* T80_MCode.vhd:1638:78  */
  assign n5832_o = ir[5:4];
  assign n5834_o = {n5832_o, 1'b1};
  /* T80_MCode.vhd:1635:41  */
  assign n5836_o = n5831_o ? 3'b000 : n5834_o;
  /* T80_MCode.vhd:1635:41  */
  assign n5839_o = n5831_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1633:33  */
  assign n5841_o = n5824_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1645:46  */
  assign n5842_o = ir[5:4];
  /* T80_MCode.vhd:1645:59  */
  assign n5844_o = n5842_o == 2'b11;
  /* T80_MCode.vhd:1648:78  */
  assign n5845_o = ir[5:4];
  assign n5847_o = {n5845_o, 1'b0};
  /* T80_MCode.vhd:1645:41  */
  assign n5849_o = n5844_o ? 3'b001 : n5847_o;
  /* T80_MCode.vhd:1645:41  */
  assign n5852_o = n5844_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1643:33  */
  assign n5854_o = n5824_o == 31'b0000000000000000000000000000101;
  assign n5855_o = {n5854_o, n5841_o, n5828_o, n5826_o};
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5859_o = 1'b0;
      4'b0100: n5859_o = 1'b0;
      4'b0010: n5859_o = 1'b1;
      4'b0001: n5859_o = 1'b1;
      default: n5859_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5862_o = 1'b0;
      4'b0100: n5862_o = 1'b1;
      4'b0010: n5862_o = 1'b0;
      4'b0001: n5862_o = 1'b0;
      default: n5862_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5866_o = 1'b1;
      4'b0100: n5866_o = 1'b1;
      4'b0010: n5866_o = 1'b0;
      4'b0001: n5866_o = 1'b0;
      default: n5866_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5868_o = n5849_o;
      4'b0100: n5868_o = n5836_o;
      4'b0010: n5868_o = 3'b000;
      4'b0001: n5868_o = 3'b000;
      default: n5868_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5870_o = n5852_o;
      4'b0100: n5870_o = n5839_o;
      4'b0010: n5870_o = 1'b0;
      4'b0001: n5870_o = 1'b0;
      default: n5870_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5874_o = 3'b111;
      4'b0100: n5874_o = 3'b110;
      4'b0010: n5874_o = 3'b110;
      4'b0001: n5874_o = 3'b111;
      default: n5874_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5877_o = 1'b0;
      4'b0100: n5877_o = 1'b0;
      4'b0010: n5877_o = 1'b0;
      4'b0001: n5877_o = 1'b1;
      default: n5877_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1625:33  */
  always @*
    case (n5855_o)
      4'b1000: n5880_o = 1'b0;
      4'b0100: n5880_o = 1'b0;
      4'b0010: n5880_o = 1'b1;
      4'b0001: n5880_o = 1'b0;
      default: n5880_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1622:25  */
  assign n5882_o = ir == 8'b01001011;
  /* T80_MCode.vhd:1622:40  */
  assign n5884_o = ir == 8'b01011011;
  /* T80_MCode.vhd:1622:40  */
  assign n5885_o = n5882_o | n5884_o;
  /* T80_MCode.vhd:1622:51  */
  assign n5887_o = ir == 8'b01101011;
  /* T80_MCode.vhd:1622:51  */
  assign n5888_o = n5885_o | n5887_o;
  /* T80_MCode.vhd:1622:62  */
  assign n5890_o = ir == 8'b01111011;
  /* T80_MCode.vhd:1622:62  */
  assign n5891_o = n5888_o | n5890_o;
  /* T80_MCode.vhd:1656:38  */
  assign n5892_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1657:33  */
  assign n5894_o = n5892_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1664:46  */
  assign n5895_o = ir[5:4];
  /* T80_MCode.vhd:1664:59  */
  assign n5897_o = n5895_o == 2'b11;
  /* T80_MCode.vhd:1667:78  */
  assign n5898_o = ir[5:4];
  assign n5901_o = {1'b0, n5898_o, 1'b1};
  /* T80_MCode.vhd:1664:41  */
  assign n5903_o = n5897_o ? 4'b1000 : n5901_o;
  /* T80_MCode.vhd:1660:33  */
  assign n5905_o = n5892_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1675:46  */
  assign n5906_o = ir[5:4];
  /* T80_MCode.vhd:1675:59  */
  assign n5908_o = n5906_o == 2'b11;
  /* T80_MCode.vhd:1678:78  */
  assign n5909_o = ir[5:4];
  assign n5912_o = {1'b0, n5909_o, 1'b0};
  /* T80_MCode.vhd:1675:41  */
  assign n5914_o = n5908_o ? 4'b1001 : n5912_o;
  /* T80_MCode.vhd:1671:33  */
  assign n5916_o = n5892_o == 31'b0000000000000000000000000000100;
  /* T80_MCode.vhd:1682:33  */
  assign n5918_o = n5892_o == 31'b0000000000000000000000000000101;
  assign n5919_o = {n5918_o, n5916_o, n5905_o, n5894_o};
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5923_o = 1'b0;
      4'b0100: n5923_o = 1'b0;
      4'b0010: n5923_o = 1'b1;
      4'b0001: n5923_o = 1'b1;
      default: n5923_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5926_o = 1'b0;
      4'b0100: n5926_o = 1'b1;
      4'b0010: n5926_o = 1'b0;
      4'b0001: n5926_o = 1'b0;
      default: n5926_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5928_o = 4'b0000;
      4'b0100: n5928_o = n5914_o;
      4'b0010: n5928_o = n5903_o;
      4'b0001: n5928_o = 4'b0000;
      default: n5928_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5932_o = 3'b111;
      4'b0100: n5932_o = 3'b110;
      4'b0010: n5932_o = 3'b110;
      4'b0001: n5932_o = 3'b111;
      default: n5932_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5935_o = 1'b0;
      4'b0100: n5935_o = 1'b0;
      4'b0010: n5935_o = 1'b0;
      4'b0001: n5935_o = 1'b1;
      default: n5935_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5938_o = 1'b0;
      4'b0100: n5938_o = 1'b0;
      4'b0010: n5938_o = 1'b1;
      4'b0001: n5938_o = 1'b0;
      default: n5938_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1656:33  */
  always @*
    case (n5919_o)
      4'b1000: n5942_o = 1'b1;
      4'b0100: n5942_o = 1'b1;
      4'b0010: n5942_o = 1'b0;
      4'b0001: n5942_o = 1'b0;
      default: n5942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1653:25  */
  assign n5944_o = ir == 8'b01000011;
  /* T80_MCode.vhd:1653:40  */
  assign n5946_o = ir == 8'b01010011;
  /* T80_MCode.vhd:1653:40  */
  assign n5947_o = n5944_o | n5946_o;
  /* T80_MCode.vhd:1653:51  */
  assign n5949_o = ir == 8'b01100011;
  /* T80_MCode.vhd:1653:51  */
  assign n5950_o = n5947_o | n5949_o;
  /* T80_MCode.vhd:1653:62  */
  assign n5952_o = ir == 8'b01110011;
  /* T80_MCode.vhd:1653:62  */
  assign n5953_o = n5950_o | n5952_o;
  /* T80_MCode.vhd:1689:38  */
  assign n5954_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1690:33  */
  assign n5956_o = n5954_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1698:46  */
  assign n5958_o = ir[3];
  /* T80_MCode.vhd:1698:50  */
  assign n5959_o = ~n5958_o;
  /* T80_MCode.vhd:1698:41  */
  assign n5962_o = n5959_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1693:33  */
  assign n5964_o = n5954_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1707:46  */
  assign n5965_o = ir[3];
  /* T80_MCode.vhd:1707:50  */
  assign n5966_o = ~n5965_o;
  /* T80_MCode.vhd:1707:41  */
  assign n5969_o = n5966_o ? 4'b0101 : 4'b1101;
  /* T80_MCode.vhd:1703:33  */
  assign n5971_o = n5954_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1712:33  */
  assign n5973_o = n5954_o == 31'b0000000000000000000000000000100;
  assign n5974_o = {n5973_o, n5971_o, n5964_o, n5956_o};
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5977_o = 3'b101;
      4'b0100: n5977_o = 3'b101;
      4'b0010: n5977_o = n2179_o;
      4'b0001: n5977_o = n2179_o;
      default: n5977_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5980_o = 4'b0000;
      4'b0100: n5980_o = n5969_o;
      4'b0010: n5980_o = n5962_o;
      4'b0001: n5980_o = 4'b1100;
      default: n5980_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5982_o = 3'b000;
      4'b0100: n5982_o = 3'b000;
      4'b0010: n5982_o = 3'b111;
      4'b0001: n5982_o = 3'b000;
      default: n5982_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5985_o = 4'b0000;
      4'b0100: n5985_o = 4'b0000;
      4'b0010: n5985_o = 4'b0110;
      4'b0001: n5985_o = 4'b0000;
      default: n5985_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5987_o = n2182_o;
      4'b0100: n5987_o = n2182_o;
      4'b0010: n5987_o = 4'b0000;
      4'b0001: n5987_o = n2182_o;
      default: n5987_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5991_o = 3'b111;
      4'b0100: n5991_o = 3'b111;
      4'b0010: n5991_o = 3'b001;
      4'b0001: n5991_o = 3'b010;
      default: n5991_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5994_o = 1'b0;
      4'b0100: n5994_o = 1'b1;
      4'b0010: n5994_o = 1'b0;
      4'b0001: n5994_o = 1'b0;
      default: n5994_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n5997_o = 1'b1;
      4'b0100: n5997_o = 1'b0;
      4'b0010: n5997_o = 1'b0;
      4'b0001: n5997_o = 1'b0;
      default: n5997_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1689:33  */
  always @*
    case (n5974_o)
      4'b1000: n6000_o = 1'b0;
      4'b0100: n6000_o = 1'b1;
      4'b0010: n6000_o = 1'b0;
      4'b0001: n6000_o = 1'b0;
      default: n6000_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1686:25  */
  assign n6002_o = ir == 8'b10100000;
  /* T80_MCode.vhd:1686:41  */
  assign n6004_o = ir == 8'b10101000;
  /* T80_MCode.vhd:1686:41  */
  assign n6005_o = n6002_o | n6004_o;
  /* T80_MCode.vhd:1686:54  */
  assign n6007_o = ir == 8'b10110000;
  /* T80_MCode.vhd:1686:54  */
  assign n6008_o = n6005_o | n6007_o;
  /* T80_MCode.vhd:1686:67  */
  assign n6010_o = ir == 8'b10111000;
  /* T80_MCode.vhd:1686:67  */
  assign n6011_o = n6008_o | n6010_o;
  /* T80_MCode.vhd:1720:38  */
  assign n6012_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1721:33  */
  assign n6014_o = n6012_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1730:46  */
  assign n6016_o = ir[3];
  /* T80_MCode.vhd:1730:50  */
  assign n6017_o = ~n6016_o;
  /* T80_MCode.vhd:1730:41  */
  assign n6020_o = n6017_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1724:33  */
  assign n6022_o = n6012_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1735:33  */
  assign n6024_o = n6012_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1739:33  */
  assign n6026_o = n6012_o == 31'b0000000000000000000000000000100;
  assign n6027_o = {n6026_o, n6024_o, n6022_o, n6014_o};
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6030_o = 3'b101;
      4'b0100: n6030_o = 3'b101;
      4'b0010: n6030_o = n2179_o;
      4'b0001: n6030_o = n2179_o;
      default: n6030_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6033_o = 4'b0000;
      4'b0100: n6033_o = 4'b0000;
      4'b0010: n6033_o = n6020_o;
      4'b0001: n6033_o = 4'b1100;
      default: n6033_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6035_o = 3'b000;
      4'b0100: n6035_o = 3'b000;
      4'b0010: n6035_o = 3'b111;
      4'b0001: n6035_o = 3'b000;
      default: n6035_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6038_o = 4'b0000;
      4'b0100: n6038_o = 4'b0000;
      4'b0010: n6038_o = 4'b0110;
      4'b0001: n6038_o = 4'b0000;
      default: n6038_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6040_o = n2182_o;
      4'b0100: n6040_o = n2182_o;
      4'b0010: n6040_o = 4'b0111;
      4'b0001: n6040_o = n2182_o;
      default: n6040_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6043_o = 1'b0;
      4'b0100: n6043_o = 1'b0;
      4'b0010: n6043_o = 1'b1;
      4'b0001: n6043_o = 1'b0;
      default: n6043_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6046_o = 1'b0;
      4'b0100: n6046_o = 1'b0;
      4'b0010: n6046_o = 1'b1;
      4'b0001: n6046_o = 1'b0;
      default: n6046_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6049_o = 3'b111;
      4'b0100: n6049_o = 3'b111;
      4'b0010: n6049_o = 3'b111;
      4'b0001: n6049_o = 3'b010;
      default: n6049_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6052_o = 1'b0;
      4'b0100: n6052_o = 1'b1;
      4'b0010: n6052_o = 1'b0;
      4'b0001: n6052_o = 1'b0;
      default: n6052_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1720:33  */
  always @*
    case (n6027_o)
      4'b1000: n6056_o = 1'b1;
      4'b0100: n6056_o = 1'b1;
      4'b0010: n6056_o = 1'b0;
      4'b0001: n6056_o = 1'b0;
      default: n6056_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1717:25  */
  assign n6058_o = ir == 8'b10100001;
  /* T80_MCode.vhd:1717:41  */
  assign n6060_o = ir == 8'b10101001;
  /* T80_MCode.vhd:1717:41  */
  assign n6061_o = n6058_o | n6060_o;
  /* T80_MCode.vhd:1717:54  */
  assign n6063_o = ir == 8'b10110001;
  /* T80_MCode.vhd:1717:54  */
  assign n6064_o = n6061_o | n6063_o;
  /* T80_MCode.vhd:1717:67  */
  assign n6066_o = ir == 8'b10111001;
  /* T80_MCode.vhd:1717:67  */
  assign n6067_o = n6064_o | n6066_o;
  /* T80_MCode.vhd:1744:25  */
  assign n6069_o = ir == 8'b01000100;
  /* T80_MCode.vhd:1744:40  */
  assign n6071_o = ir == 8'b01001100;
  /* T80_MCode.vhd:1744:40  */
  assign n6072_o = n6069_o | n6071_o;
  /* T80_MCode.vhd:1744:51  */
  assign n6074_o = ir == 8'b01010100;
  /* T80_MCode.vhd:1744:51  */
  assign n6075_o = n6072_o | n6074_o;
  /* T80_MCode.vhd:1744:62  */
  assign n6077_o = ir == 8'b01011100;
  /* T80_MCode.vhd:1744:62  */
  assign n6078_o = n6075_o | n6077_o;
  /* T80_MCode.vhd:1744:73  */
  assign n6080_o = ir == 8'b01100100;
  /* T80_MCode.vhd:1744:73  */
  assign n6081_o = n6078_o | n6080_o;
  /* T80_MCode.vhd:1744:84  */
  assign n6083_o = ir == 8'b01101100;
  /* T80_MCode.vhd:1744:84  */
  assign n6084_o = n6081_o | n6083_o;
  /* T80_MCode.vhd:1744:95  */
  assign n6086_o = ir == 8'b01110100;
  /* T80_MCode.vhd:1744:95  */
  assign n6087_o = n6084_o | n6086_o;
  /* T80_MCode.vhd:1744:106  */
  assign n6089_o = ir == 8'b01111100;
  /* T80_MCode.vhd:1744:106  */
  assign n6090_o = n6087_o | n6089_o;
  /* T80_MCode.vhd:1751:25  */
  assign n6092_o = ir == 8'b01000110;
  /* T80_MCode.vhd:1751:40  */
  assign n6094_o = ir == 8'b01001110;
  /* T80_MCode.vhd:1751:40  */
  assign n6095_o = n6092_o | n6094_o;
  /* T80_MCode.vhd:1751:51  */
  assign n6097_o = ir == 8'b01100110;
  /* T80_MCode.vhd:1751:51  */
  assign n6098_o = n6095_o | n6097_o;
  /* T80_MCode.vhd:1751:62  */
  assign n6100_o = ir == 8'b01101110;
  /* T80_MCode.vhd:1751:62  */
  assign n6101_o = n6098_o | n6100_o;
  /* T80_MCode.vhd:1754:25  */
  assign n6103_o = ir == 8'b01010110;
  /* T80_MCode.vhd:1754:40  */
  assign n6105_o = ir == 8'b01110110;
  /* T80_MCode.vhd:1754:40  */
  assign n6106_o = n6103_o | n6105_o;
  /* T80_MCode.vhd:1757:25  */
  assign n6108_o = ir == 8'b01011110;
  /* T80_MCode.vhd:1757:40  */
  assign n6110_o = ir == 8'b01110111;
  /* T80_MCode.vhd:1757:40  */
  assign n6111_o = n6108_o | n6110_o;
  /* T80_MCode.vhd:1764:38  */
  assign n6112_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1771:68  */
  assign n6114_o = ir[5:4];
  /* T80_MCode.vhd:1771:46  */
  assign n6115_o = {29'b0, n6114_o};  //  uext
  /* T80_MCode.vhd:1773:78  */
  assign n6116_o = ir[5:4];
  /* T80_MCode.vhd:1772:41  */
  assign n6119_o = n6115_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1772:47  */
  assign n6121_o = n6115_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1772:47  */
  assign n6122_o = n6119_o | n6121_o;
  /* T80_MCode.vhd:1772:49  */
  assign n6124_o = n6115_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1772:49  */
  assign n6125_o = n6122_o | n6124_o;
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6127_o = 1'b1;
      default: n6127_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6129_o = n6116_o;
      default: n6129_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1771:41  */
  always @*
    case (n6125_o)
      1'b1: n6132_o = 1'b0;
      default: n6132_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1765:33  */
  assign n6134_o = n6112_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1786:68  */
  assign n6136_o = ir[5:4];
  /* T80_MCode.vhd:1786:46  */
  assign n6137_o = {29'b0, n6136_o};  //  uext
  /* T80_MCode.vhd:1788:78  */
  assign n6138_o = ir[5:4];
  /* T80_MCode.vhd:1787:41  */
  assign n6141_o = n6137_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1787:47  */
  assign n6143_o = n6137_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1787:47  */
  assign n6144_o = n6141_o | n6143_o;
  /* T80_MCode.vhd:1787:49  */
  assign n6146_o = n6137_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1787:49  */
  assign n6147_o = n6144_o | n6146_o;
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6149_o = 1'b0;
      default: n6149_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6151_o = n6138_o;
      default: n6151_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1786:41  */
  always @*
    case (n6147_o)
      1'b1: n6154_o = 1'b0;
      default: n6154_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1780:33  */
  assign n6156_o = n6112_o == 31'b0000000000000000000000000000011;
  assign n6157_o = {n6156_o, n6134_o};
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6159_o = n2179_o;
      2'b01: n6159_o = 3'b100;
      default: n6159_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6163_o = 1'b1;
      2'b01: n6163_o = 1'b1;
      default: n6163_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6165_o = 3'b100;
      2'b01: n6165_o = 3'b101;
      default: n6165_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6167_o = n6149_o;
      2'b01: n6167_o = n6127_o;
      default: n6167_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6169_o = n6151_o;
      2'b01: n6169_o = n6129_o;
      default: n6169_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6171_o = n6154_o;
      2'b01: n6171_o = n6132_o;
      default: n6171_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6174_o = 4'b0001;
      2'b01: n6174_o = 4'b0001;
      default: n6174_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6178_o = 1'b1;
      2'b01: n6178_o = 1'b1;
      default: n6178_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6181_o = 2'b00;
      2'b01: n6181_o = 2'b11;
      default: n6181_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1764:33  */
  always @*
    case (n6157_o)
      2'b10: n6185_o = 1'b1;
      2'b01: n6185_o = 1'b1;
      default: n6185_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1761:25  */
  assign n6187_o = ir == 8'b01001010;
  /* T80_MCode.vhd:1761:40  */
  assign n6189_o = ir == 8'b01011010;
  /* T80_MCode.vhd:1761:40  */
  assign n6190_o = n6187_o | n6189_o;
  /* T80_MCode.vhd:1761:51  */
  assign n6192_o = ir == 8'b01101010;
  /* T80_MCode.vhd:1761:51  */
  assign n6193_o = n6190_o | n6192_o;
  /* T80_MCode.vhd:1761:62  */
  assign n6195_o = ir == 8'b01111010;
  /* T80_MCode.vhd:1761:62  */
  assign n6196_o = n6193_o | n6195_o;
  /* T80_MCode.vhd:1798:38  */
  assign n6197_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1805:68  */
  assign n6199_o = ir[5:4];
  /* T80_MCode.vhd:1805:46  */
  assign n6200_o = {29'b0, n6199_o};  //  uext
  /* T80_MCode.vhd:1807:78  */
  assign n6201_o = ir[5:4];
  /* T80_MCode.vhd:1806:41  */
  assign n6204_o = n6200_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1806:47  */
  assign n6206_o = n6200_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1806:47  */
  assign n6207_o = n6204_o | n6206_o;
  /* T80_MCode.vhd:1806:49  */
  assign n6209_o = n6200_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1806:49  */
  assign n6210_o = n6207_o | n6209_o;
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6212_o = 1'b1;
      default: n6212_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6214_o = n6201_o;
      default: n6214_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1805:41  */
  always @*
    case (n6210_o)
      1'b1: n6217_o = 1'b0;
      default: n6217_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1799:33  */
  assign n6219_o = n6197_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1820:68  */
  assign n6221_o = ir[5:4];
  /* T80_MCode.vhd:1820:46  */
  assign n6222_o = {29'b0, n6221_o};  //  uext
  /* T80_MCode.vhd:1822:78  */
  assign n6223_o = ir[5:4];
  /* T80_MCode.vhd:1821:41  */
  assign n6225_o = n6222_o == 31'b0000000000000000000000000000000;
  /* T80_MCode.vhd:1821:47  */
  assign n6227_o = n6222_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1821:47  */
  assign n6228_o = n6225_o | n6227_o;
  /* T80_MCode.vhd:1821:49  */
  assign n6230_o = n6222_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1821:49  */
  assign n6231_o = n6228_o | n6230_o;
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6234_o = 1'b0;
      default: n6234_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6236_o = n6223_o;
      default: n6236_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1820:41  */
  always @*
    case (n6231_o)
      1'b1: n6239_o = 1'b0;
      default: n6239_o = 1'b1;
    endcase
  /* T80_MCode.vhd:1814:33  */
  assign n6241_o = n6197_o == 31'b0000000000000000000000000000011;
  assign n6242_o = {n6241_o, n6219_o};
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6244_o = n2179_o;
      2'b01: n6244_o = 3'b100;
      default: n6244_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6248_o = 1'b1;
      2'b01: n6248_o = 1'b1;
      default: n6248_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6250_o = 3'b100;
      2'b01: n6250_o = 3'b101;
      default: n6250_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6252_o = n6234_o;
      2'b01: n6252_o = n6212_o;
      default: n6252_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6254_o = n6236_o;
      2'b01: n6254_o = n6214_o;
      default: n6254_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6256_o = n6239_o;
      2'b01: n6256_o = n6217_o;
      default: n6256_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6259_o = 4'b0011;
      2'b01: n6259_o = 4'b0011;
      default: n6259_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6263_o = 1'b1;
      2'b01: n6263_o = 1'b1;
      default: n6263_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6266_o = 2'b00;
      2'b01: n6266_o = 2'b11;
      default: n6266_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1798:33  */
  always @*
    case (n6242_o)
      2'b10: n6270_o = 1'b1;
      2'b01: n6270_o = 1'b1;
      default: n6270_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1795:25  */
  assign n6272_o = ir == 8'b01000010;
  /* T80_MCode.vhd:1795:40  */
  assign n6274_o = ir == 8'b01010010;
  /* T80_MCode.vhd:1795:40  */
  assign n6275_o = n6272_o | n6274_o;
  /* T80_MCode.vhd:1795:51  */
  assign n6277_o = ir == 8'b01100010;
  /* T80_MCode.vhd:1795:51  */
  assign n6278_o = n6275_o | n6277_o;
  /* T80_MCode.vhd:1795:62  */
  assign n6280_o = ir == 8'b01110010;
  /* T80_MCode.vhd:1795:62  */
  assign n6281_o = n6278_o | n6280_o;
  /* T80_MCode.vhd:1831:38  */
  assign n6282_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1832:33  */
  assign n6284_o = n6282_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1834:33  */
  assign n6288_o = n6282_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1840:33  */
  assign n6290_o = n6282_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1845:33  */
  assign n6292_o = n6282_o == 31'b0000000000000000000000000000100;
  assign n6293_o = {n6292_o, n6290_o, n6288_o, n6284_o};
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6295_o = n2179_o;
      4'b0100: n6295_o = 3'b100;
      4'b0010: n6295_o = n2179_o;
      4'b0001: n6295_o = n2179_o;
      default: n6295_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6298_o = 1'b0;
      4'b0100: n6298_o = 1'b0;
      4'b0010: n6298_o = 1'b1;
      4'b0001: n6298_o = 1'b0;
      default: n6298_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6300_o = 3'b000;
      4'b0100: n6300_o = 3'b000;
      4'b0010: n6300_o = 3'b111;
      4'b0001: n6300_o = 3'b000;
      default: n6300_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6302_o = 3'b000;
      4'b0100: n6302_o = 3'b000;
      4'b0010: n6302_o = 3'b110;
      4'b0001: n6302_o = 3'b000;
      default: n6302_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6304_o = n2182_o;
      4'b0100: n6304_o = n2182_o;
      4'b0010: n6304_o = 4'b1101;
      4'b0001: n6304_o = n2182_o;
      default: n6304_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6307_o = 1'b0;
      4'b0100: n6307_o = 1'b0;
      4'b0010: n6307_o = 1'b1;
      4'b0001: n6307_o = 1'b0;
      default: n6307_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6311_o = 3'b111;
      4'b0100: n6311_o = 3'b010;
      4'b0010: n6311_o = 3'b111;
      4'b0001: n6311_o = 3'b010;
      default: n6311_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6314_o = 1'b0;
      4'b0100: n6314_o = 1'b1;
      4'b0010: n6314_o = 1'b0;
      4'b0001: n6314_o = 1'b0;
      default: n6314_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6317_o = 1'b0;
      4'b0100: n6317_o = 1'b1;
      4'b0010: n6317_o = 1'b0;
      4'b0001: n6317_o = 1'b0;
      default: n6317_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1831:33  */
  always @*
    case (n6293_o)
      4'b1000: n6320_o = 1'b1;
      4'b0100: n6320_o = 1'b0;
      4'b0010: n6320_o = 1'b0;
      4'b0001: n6320_o = 1'b0;
      default: n6320_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1828:25  */
  assign n6322_o = ir == 8'b01101111;
  /* T80_MCode.vhd:1852:38  */
  assign n6323_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1853:33  */
  assign n6325_o = n6323_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1855:33  */
  assign n6329_o = n6323_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1861:33  */
  assign n6331_o = n6323_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1866:33  */
  assign n6333_o = n6323_o == 31'b0000000000000000000000000000100;
  assign n6334_o = {n6333_o, n6331_o, n6329_o, n6325_o};
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6336_o = n2179_o;
      4'b0100: n6336_o = 3'b100;
      4'b0010: n6336_o = n2179_o;
      4'b0001: n6336_o = n2179_o;
      default: n6336_o = n2179_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6339_o = 1'b0;
      4'b0100: n6339_o = 1'b0;
      4'b0010: n6339_o = 1'b1;
      4'b0001: n6339_o = 1'b0;
      default: n6339_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6341_o = 3'b000;
      4'b0100: n6341_o = 3'b000;
      4'b0010: n6341_o = 3'b111;
      4'b0001: n6341_o = 3'b000;
      default: n6341_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6343_o = 3'b000;
      4'b0100: n6343_o = 3'b000;
      4'b0010: n6343_o = 3'b110;
      4'b0001: n6343_o = 3'b000;
      default: n6343_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6345_o = n2182_o;
      4'b0100: n6345_o = n2182_o;
      4'b0010: n6345_o = 4'b1110;
      4'b0001: n6345_o = n2182_o;
      default: n6345_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6348_o = 1'b0;
      4'b0100: n6348_o = 1'b0;
      4'b0010: n6348_o = 1'b1;
      4'b0001: n6348_o = 1'b0;
      default: n6348_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6352_o = 3'b111;
      4'b0100: n6352_o = 3'b010;
      4'b0010: n6352_o = 3'b111;
      4'b0001: n6352_o = 3'b010;
      default: n6352_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6355_o = 1'b0;
      4'b0100: n6355_o = 1'b1;
      4'b0010: n6355_o = 1'b0;
      4'b0001: n6355_o = 1'b0;
      default: n6355_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6358_o = 1'b0;
      4'b0100: n6358_o = 1'b1;
      4'b0010: n6358_o = 1'b0;
      4'b0001: n6358_o = 1'b0;
      default: n6358_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1852:33  */
  always @*
    case (n6334_o)
      4'b1000: n6361_o = 1'b1;
      4'b0100: n6361_o = 1'b0;
      4'b0010: n6361_o = 1'b0;
      4'b0001: n6361_o = 1'b0;
      default: n6361_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1849:25  */
  assign n6363_o = ir == 8'b01100111;
  /* T80_MCode.vhd:1873:38  */
  assign n6364_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1874:33  */
  assign n6366_o = n6364_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1876:33  */
  assign n6368_o = n6364_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1880:33  */
  assign n6370_o = n6364_o == 31'b0000000000000000000000000000011;
  assign n6371_o = {n6370_o, n6368_o, n6366_o};
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6375_o = 4'b0111;
      3'b010: n6375_o = 4'b0111;
      3'b001: n6375_o = 4'b0000;
      default: n6375_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6379_o = 3'b111;
      3'b010: n6379_o = 3'b101;
      3'b001: n6379_o = 3'b101;
      default: n6379_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6382_o = 1'b1;
      3'b010: n6382_o = 1'b0;
      3'b001: n6382_o = 1'b0;
      default: n6382_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6385_o = 1'b0;
      3'b010: n6385_o = 1'b1;
      3'b001: n6385_o = 1'b0;
      default: n6385_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6388_o = 1'b1;
      3'b010: n6388_o = 1'b0;
      3'b001: n6388_o = 1'b0;
      default: n6388_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1873:33  */
  always @*
    case (n6371_o)
      3'b100: n6391_o = 1'b1;
      3'b010: n6391_o = 1'b0;
      3'b001: n6391_o = 1'b0;
      default: n6391_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1870:25  */
  assign n6393_o = ir == 8'b01000101;
  /* T80_MCode.vhd:1870:40  */
  assign n6395_o = ir == 8'b01001101;
  /* T80_MCode.vhd:1870:40  */
  assign n6396_o = n6393_o | n6395_o;
  /* T80_MCode.vhd:1870:51  */
  assign n6398_o = ir == 8'b01010101;
  /* T80_MCode.vhd:1870:51  */
  assign n6399_o = n6396_o | n6398_o;
  /* T80_MCode.vhd:1870:62  */
  assign n6401_o = ir == 8'b01011101;
  /* T80_MCode.vhd:1870:62  */
  assign n6402_o = n6399_o | n6401_o;
  /* T80_MCode.vhd:1870:73  */
  assign n6404_o = ir == 8'b01100101;
  /* T80_MCode.vhd:1870:73  */
  assign n6405_o = n6402_o | n6404_o;
  /* T80_MCode.vhd:1870:84  */
  assign n6407_o = ir == 8'b01101101;
  /* T80_MCode.vhd:1870:84  */
  assign n6408_o = n6405_o | n6407_o;
  /* T80_MCode.vhd:1870:95  */
  assign n6410_o = ir == 8'b01110101;
  /* T80_MCode.vhd:1870:95  */
  assign n6411_o = n6408_o | n6410_o;
  /* T80_MCode.vhd:1870:106  */
  assign n6413_o = ir == 8'b01111101;
  /* T80_MCode.vhd:1870:106  */
  assign n6414_o = n6411_o | n6413_o;
  /* T80_MCode.vhd:1890:38  */
  assign n6415_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1891:33  */
  assign n6417_o = n6415_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1896:46  */
  assign n6418_o = ir[5:3];
  /* T80_MCode.vhd:1896:59  */
  assign n6420_o = n6418_o != 3'b110;
  /* T80_MCode.vhd:1898:78  */
  assign n6421_o = ir[5:3];
  /* T80_MCode.vhd:1896:41  */
  assign n6424_o = n6420_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1896:41  */
  assign n6426_o = n6420_o ? n6421_o : 3'b000;
  /* T80_MCode.vhd:1894:33  */
  assign n6428_o = n6415_o == 31'b0000000000000000000000000000010;
  assign n6429_o = {n6428_o, n6417_o};
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6431_o = n6424_o;
      2'b01: n6431_o = 1'b0;
      default: n6431_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6433_o = n6426_o;
      2'b01: n6433_o = 3'b000;
      default: n6433_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6436_o = 3'b111;
      2'b01: n6436_o = 3'b000;
      default: n6436_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6439_o = 1'b1;
      2'b01: n6439_o = 1'b0;
      default: n6439_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6442_o = 1'b1;
      2'b01: n6442_o = 1'b0;
      default: n6442_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1890:33  */
  always @*
    case (n6429_o)
      2'b10: n6445_o = 2'b00;
      2'b01: n6445_o = 2'b01;
      default: n6445_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1887:25  */
  assign n6447_o = ir == 8'b01000000;
  /* T80_MCode.vhd:1887:40  */
  assign n6449_o = ir == 8'b01001000;
  /* T80_MCode.vhd:1887:40  */
  assign n6450_o = n6447_o | n6449_o;
  /* T80_MCode.vhd:1887:51  */
  assign n6452_o = ir == 8'b01010000;
  /* T80_MCode.vhd:1887:51  */
  assign n6453_o = n6450_o | n6452_o;
  /* T80_MCode.vhd:1887:62  */
  assign n6455_o = ir == 8'b01011000;
  /* T80_MCode.vhd:1887:62  */
  assign n6456_o = n6453_o | n6455_o;
  /* T80_MCode.vhd:1887:73  */
  assign n6458_o = ir == 8'b01100000;
  /* T80_MCode.vhd:1887:73  */
  assign n6459_o = n6456_o | n6458_o;
  /* T80_MCode.vhd:1887:84  */
  assign n6461_o = ir == 8'b01101000;
  /* T80_MCode.vhd:1887:84  */
  assign n6462_o = n6459_o | n6461_o;
  /* T80_MCode.vhd:1887:95  */
  assign n6464_o = ir == 8'b01110000;
  /* T80_MCode.vhd:1887:95  */
  assign n6465_o = n6462_o | n6464_o;
  /* T80_MCode.vhd:1887:106  */
  assign n6467_o = ir == 8'b01111000;
  /* T80_MCode.vhd:1887:106  */
  assign n6468_o = n6465_o | n6467_o;
  /* T80_MCode.vhd:1907:38  */
  assign n6469_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1911:78  */
  assign n6470_o = ir[5:3];
  /* T80_MCode.vhd:1912:46  */
  assign n6471_o = ir[5:3];
  /* T80_MCode.vhd:1912:59  */
  assign n6473_o = n6471_o == 3'b110;
  /* T80_MCode.vhd:1912:41  */
  assign n6476_o = n6473_o ? 1'b1 : 1'b0;
  /* T80_MCode.vhd:1908:33  */
  assign n6478_o = n6469_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1915:33  */
  assign n6480_o = n6469_o == 31'b0000000000000000000000000000010;
  assign n6481_o = {n6480_o, n6478_o};
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6483_o = 3'b000;
      2'b01: n6483_o = n6470_o;
      default: n6483_o = 3'b000;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6485_o = 1'b0;
      2'b01: n6485_o = n6476_o;
      default: n6485_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6488_o = 3'b111;
      2'b01: n6488_o = 3'b000;
      default: n6488_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6491_o = 1'b1;
      2'b01: n6491_o = 1'b0;
      default: n6491_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6494_o = 2'b00;
      2'b01: n6494_o = 2'b01;
      default: n6494_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1907:33  */
  always @*
    case (n6481_o)
      2'b10: n6497_o = 1'b1;
      2'b01: n6497_o = 1'b0;
      default: n6497_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1903:25  */
  assign n6499_o = ir == 8'b01000001;
  /* T80_MCode.vhd:1903:40  */
  assign n6501_o = ir == 8'b01001001;
  /* T80_MCode.vhd:1903:40  */
  assign n6502_o = n6499_o | n6501_o;
  /* T80_MCode.vhd:1903:51  */
  assign n6504_o = ir == 8'b01010001;
  /* T80_MCode.vhd:1903:51  */
  assign n6505_o = n6502_o | n6504_o;
  /* T80_MCode.vhd:1903:62  */
  assign n6507_o = ir == 8'b01011001;
  /* T80_MCode.vhd:1903:62  */
  assign n6508_o = n6505_o | n6507_o;
  /* T80_MCode.vhd:1903:73  */
  assign n6510_o = ir == 8'b01100001;
  /* T80_MCode.vhd:1903:73  */
  assign n6511_o = n6508_o | n6510_o;
  /* T80_MCode.vhd:1903:84  */
  assign n6513_o = ir == 8'b01101001;
  /* T80_MCode.vhd:1903:84  */
  assign n6514_o = n6511_o | n6513_o;
  /* T80_MCode.vhd:1903:95  */
  assign n6516_o = ir == 8'b01110001;
  /* T80_MCode.vhd:1903:95  */
  assign n6517_o = n6514_o | n6516_o;
  /* T80_MCode.vhd:1903:106  */
  assign n6519_o = ir == 8'b01111001;
  /* T80_MCode.vhd:1903:106  */
  assign n6520_o = n6517_o | n6519_o;
  /* T80_MCode.vhd:1923:38  */
  assign n6521_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1933:59  */
  assign n6522_o = ir[3];
  /* T80_MCode.vhd:1924:33  */
  assign n6524_o = n6521_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1934:33  */
  assign n6526_o = n6521_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1939:46  */
  assign n6527_o = ir[3];
  /* T80_MCode.vhd:1939:50  */
  assign n6528_o = ~n6527_o;
  /* T80_MCode.vhd:1939:41  */
  assign n6531_o = n6528_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1938:33  */
  assign n6533_o = n6521_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1946:33  */
  assign n6535_o = n6521_o == 31'b0000000000000000000000000000100;
  assign n6536_o = {n6535_o, n6533_o, n6526_o, n6524_o};
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6539_o = 3'b101;
      4'b0100: n6539_o = n2179_o;
      4'b0010: n6539_o = n2179_o;
      4'b0001: n6539_o = 3'b101;
      default: n6539_o = n2179_o;
    endcase
  assign n6540_o = n6531_o[2:0];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6542_o = 3'b000;
      4'b0100: n6542_o = n6540_o;
      4'b0010: n6542_o = 3'b000;
      4'b0001: n6542_o = 3'b000;
      default: n6542_o = 3'b000;
    endcase
  assign n6543_o = n6531_o[3];
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6545_o = 1'b0;
      4'b0100: n6545_o = n6543_o;
      4'b0010: n6545_o = 1'b0;
      4'b0001: n6545_o = n6522_o;
      default: n6545_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6548_o = 1'b0;
      4'b0100: n6548_o = 1'b0;
      4'b0010: n6548_o = 1'b0;
      4'b0001: n6548_o = 1'b1;
      default: n6548_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6551_o = 4'b0000;
      4'b0100: n6551_o = 4'b0000;
      4'b0010: n6551_o = 4'b0000;
      4'b0001: n6551_o = 4'b0000;
      default: n6551_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6555_o = 4'b0000;
      4'b0100: n6555_o = 4'b0000;
      4'b0010: n6555_o = 4'b0110;
      4'b0001: n6555_o = 4'b1010;
      default: n6555_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6557_o = n2182_o;
      4'b0100: n6557_o = n2182_o;
      4'b0010: n6557_o = n2182_o;
      4'b0001: n6557_o = 4'b0010;
      default: n6557_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6560_o = 1'b0;
      4'b0100: n6560_o = 1'b0;
      4'b0010: n6560_o = 1'b0;
      4'b0001: n6560_o = 1'b1;
      default: n6560_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6564_o = 3'b111;
      4'b0100: n6564_o = 3'b111;
      4'b0010: n6564_o = 3'b010;
      4'b0001: n6564_o = 3'b000;
      default: n6564_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6567_o = 1'b0;
      4'b0100: n6567_o = 1'b0;
      4'b0010: n6567_o = 1'b1;
      4'b0001: n6567_o = 1'b0;
      default: n6567_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6570_o = 1'b0;
      4'b0100: n6570_o = 1'b1;
      4'b0010: n6570_o = 1'b0;
      4'b0001: n6570_o = 1'b0;
      default: n6570_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6573_o = 2'b00;
      4'b0100: n6573_o = 2'b00;
      4'b0010: n6573_o = 2'b00;
      4'b0001: n6573_o = 2'b11;
      default: n6573_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6576_o = 1'b1;
      4'b0100: n6576_o = 1'b0;
      4'b0010: n6576_o = 1'b0;
      4'b0001: n6576_o = 1'b0;
      default: n6576_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1923:33  */
  always @*
    case (n6536_o)
      4'b1000: n6579_o = 1'b0;
      4'b0100: n6579_o = 1'b1;
      4'b0010: n6579_o = 1'b0;
      4'b0001: n6579_o = 1'b0;
      default: n6579_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1920:25  */
  assign n6581_o = ir == 8'b10100010;
  /* T80_MCode.vhd:1920:41  */
  assign n6583_o = ir == 8'b10101010;
  /* T80_MCode.vhd:1920:41  */
  assign n6584_o = n6581_o | n6583_o;
  /* T80_MCode.vhd:1920:54  */
  assign n6586_o = ir == 8'b10110010;
  /* T80_MCode.vhd:1920:54  */
  assign n6587_o = n6584_o | n6586_o;
  /* T80_MCode.vhd:1920:67  */
  assign n6589_o = ir == 8'b10111010;
  /* T80_MCode.vhd:1920:67  */
  assign n6590_o = n6587_o | n6589_o;
  /* T80_MCode.vhd:1954:38  */
  assign n6591_o = {28'b0, mcycle};  //  uext
  /* T80_MCode.vhd:1955:33  */
  assign n6593_o = n6591_o == 31'b0000000000000000000000000000001;
  /* T80_MCode.vhd:1967:59  */
  assign n6594_o = ir[3];
  /* T80_MCode.vhd:1963:33  */
  assign n6596_o = n6591_o == 31'b0000000000000000000000000000010;
  /* T80_MCode.vhd:1969:46  */
  assign n6597_o = ir[3];
  /* T80_MCode.vhd:1969:50  */
  assign n6598_o = ~n6597_o;
  /* T80_MCode.vhd:1969:41  */
  assign n6601_o = n6598_o ? 4'b0110 : 4'b1110;
  /* T80_MCode.vhd:1968:33  */
  assign n6603_o = n6591_o == 31'b0000000000000000000000000000011;
  /* T80_MCode.vhd:1977:33  */
  assign n6605_o = n6591_o == 31'b0000000000000000000000000000100;
  assign n6606_o = {n6605_o, n6603_o, n6596_o, n6593_o};
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6609_o = 3'b101;
      4'b0100: n6609_o = n2179_o;
      4'b0010: n6609_o = n2179_o;
      4'b0001: n6609_o = 3'b101;
      default: n6609_o = n2179_o;
    endcase
  assign n6610_o = n6601_o[2:0];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6612_o = 3'b000;
      4'b0100: n6612_o = n6610_o;
      4'b0010: n6612_o = 3'b000;
      4'b0001: n6612_o = 3'b000;
      default: n6612_o = 3'b000;
    endcase
  assign n6613_o = n6601_o[3];
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6615_o = 1'b0;
      4'b0100: n6615_o = n6613_o;
      4'b0010: n6615_o = n6594_o;
      4'b0001: n6615_o = 1'b0;
      default: n6615_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6618_o = 1'b0;
      4'b0100: n6618_o = 1'b0;
      4'b0010: n6618_o = 1'b0;
      4'b0001: n6618_o = 1'b1;
      default: n6618_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6621_o = 4'b0000;
      4'b0100: n6621_o = 4'b0000;
      4'b0010: n6621_o = 4'b0000;
      4'b0001: n6621_o = 4'b0000;
      default: n6621_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6625_o = 4'b0000;
      4'b0100: n6625_o = 4'b0000;
      4'b0010: n6625_o = 4'b0110;
      4'b0001: n6625_o = 4'b1010;
      default: n6625_o = 4'b0000;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6627_o = n2182_o;
      4'b0100: n6627_o = n2182_o;
      4'b0010: n6627_o = n2182_o;
      4'b0001: n6627_o = 4'b0010;
      default: n6627_o = n2182_o;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6630_o = 1'b0;
      4'b0100: n6630_o = 1'b0;
      4'b0010: n6630_o = 1'b0;
      4'b0001: n6630_o = 1'b1;
      default: n6630_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6634_o = 3'b111;
      4'b0100: n6634_o = 3'b111;
      4'b0010: n6634_o = 3'b000;
      4'b0001: n6634_o = 3'b010;
      default: n6634_o = 3'b111;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6637_o = 1'b0;
      4'b0100: n6637_o = 1'b1;
      4'b0010: n6637_o = 1'b0;
      4'b0001: n6637_o = 1'b0;
      default: n6637_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6640_o = 1'b0;
      4'b0100: n6640_o = 1'b1;
      4'b0010: n6640_o = 1'b0;
      4'b0001: n6640_o = 1'b0;
      default: n6640_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6643_o = 2'b00;
      4'b0100: n6643_o = 2'b00;
      4'b0010: n6643_o = 2'b11;
      4'b0001: n6643_o = 2'b00;
      default: n6643_o = 2'b00;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6646_o = 1'b1;
      4'b0100: n6646_o = 1'b0;
      4'b0010: n6646_o = 1'b0;
      4'b0001: n6646_o = 1'b0;
      default: n6646_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1954:33  */
  always @*
    case (n6606_o)
      4'b1000: n6649_o = 1'b0;
      4'b0100: n6649_o = 1'b1;
      4'b0010: n6649_o = 1'b0;
      4'b0001: n6649_o = 1'b0;
      default: n6649_o = 1'b0;
    endcase
  /* T80_MCode.vhd:1951:25  */
  assign n6651_o = ir == 8'b10100011;
  /* T80_MCode.vhd:1951:41  */
  assign n6653_o = ir == 8'b10101011;
  /* T80_MCode.vhd:1951:41  */
  assign n6654_o = n6651_o | n6653_o;
  /* T80_MCode.vhd:1951:54  */
  assign n6656_o = ir == 8'b10110011;
  /* T80_MCode.vhd:1951:54  */
  assign n6657_o = n6654_o | n6656_o;
  /* T80_MCode.vhd:1951:67  */
  assign n6659_o = ir == 8'b10111011;
  /* T80_MCode.vhd:1951:67  */
  assign n6660_o = n6657_o | n6659_o;
  assign n6661_o = {n6660_o, n6590_o, n6520_o, n6468_o, n6414_o, n6363_o, n6322_o, n6281_o, n6196_o, n6111_o, n6106_o, n6101_o, n6090_o, n6067_o, n6011_o, n5953_o, n5891_o, n5823_o, n5821_o, n5819_o, n5817_o, n5815_o, n5810_o};
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6677_o = 3'b100;
      23'b01000000000000000000000: n6677_o = 3'b100;
      23'b00100000000000000000000: n6677_o = 3'b010;
      23'b00010000000000000000000: n6677_o = 3'b010;
      23'b00001000000000000000000: n6677_o = 3'b011;
      23'b00000100000000000000000: n6677_o = 3'b100;
      23'b00000010000000000000000: n6677_o = 3'b100;
      23'b00000001000000000000000: n6677_o = 3'b011;
      23'b00000000100000000000000: n6677_o = 3'b011;
      23'b00000000010000000000000: n6677_o = 3'b001;
      23'b00000000001000000000000: n6677_o = 3'b001;
      23'b00000000000100000000000: n6677_o = 3'b001;
      23'b00000000000010000000000: n6677_o = 3'b001;
      23'b00000000000001000000000: n6677_o = 3'b100;
      23'b00000000000000100000000: n6677_o = 3'b100;
      23'b00000000000000010000000: n6677_o = 3'b101;
      23'b00000000000000001000000: n6677_o = 3'b101;
      23'b00000000000000000100000: n6677_o = 3'b001;
      23'b00000000000000000010000: n6677_o = 3'b001;
      23'b00000000000000000001000: n6677_o = 3'b001;
      23'b00000000000000000000100: n6677_o = 3'b001;
      23'b00000000000000000000010: n6677_o = 3'b001;
      23'b00000000000000000000001: n6677_o = 3'b001;
      default: n6677_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6683_o = n6609_o;
      23'b01000000000000000000000: n6683_o = n6539_o;
      23'b00100000000000000000000: n6683_o = n2179_o;
      23'b00010000000000000000000: n6683_o = n2179_o;
      23'b00001000000000000000000: n6683_o = n2179_o;
      23'b00000100000000000000000: n6683_o = n6336_o;
      23'b00000010000000000000000: n6683_o = n6295_o;
      23'b00000001000000000000000: n6683_o = n6244_o;
      23'b00000000100000000000000: n6683_o = n6159_o;
      23'b00000000010000000000000: n6683_o = n2179_o;
      23'b00000000001000000000000: n6683_o = n2179_o;
      23'b00000000000100000000000: n6683_o = n2179_o;
      23'b00000000000010000000000: n6683_o = n2179_o;
      23'b00000000000001000000000: n6683_o = n6030_o;
      23'b00000000000000100000000: n6683_o = n5977_o;
      23'b00000000000000010000000: n6683_o = n2179_o;
      23'b00000000000000001000000: n6683_o = n2179_o;
      23'b00000000000000000100000: n6683_o = 3'b101;
      23'b00000000000000000010000: n6683_o = 3'b101;
      23'b00000000000000000001000: n6683_o = 3'b101;
      23'b00000000000000000000100: n6683_o = 3'b101;
      23'b00000000000000000000010: n6683_o = n2179_o;
      23'b00000000000000000000001: n6683_o = n2179_o;
      default: n6683_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6686_o = 1'b0;
      23'b01000000000000000000000: n6686_o = 1'b0;
      23'b00100000000000000000000: n6686_o = 1'b0;
      23'b00010000000000000000000: n6686_o = 1'b0;
      23'b00001000000000000000000: n6686_o = 1'b0;
      23'b00000100000000000000000: n6686_o = 1'b0;
      23'b00000010000000000000000: n6686_o = 1'b0;
      23'b00000001000000000000000: n6686_o = 1'b0;
      23'b00000000100000000000000: n6686_o = 1'b0;
      23'b00000000010000000000000: n6686_o = 1'b0;
      23'b00000000001000000000000: n6686_o = 1'b0;
      23'b00000000000100000000000: n6686_o = 1'b0;
      23'b00000000000010000000000: n6686_o = 1'b0;
      23'b00000000000001000000000: n6686_o = 1'b0;
      23'b00000000000000100000000: n6686_o = 1'b0;
      23'b00000000000000010000000: n6686_o = n5923_o;
      23'b00000000000000001000000: n6686_o = n5859_o;
      23'b00000000000000000100000: n6686_o = 1'b0;
      23'b00000000000000000010000: n6686_o = 1'b0;
      23'b00000000000000000001000: n6686_o = 1'b0;
      23'b00000000000000000000100: n6686_o = 1'b0;
      23'b00000000000000000000010: n6686_o = 1'b0;
      23'b00000000000000000000001: n6686_o = 1'b0;
      default: n6686_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6689_o = 1'b0;
      23'b01000000000000000000000: n6689_o = 1'b0;
      23'b00100000000000000000000: n6689_o = 1'b0;
      23'b00010000000000000000000: n6689_o = 1'b0;
      23'b00001000000000000000000: n6689_o = 1'b0;
      23'b00000100000000000000000: n6689_o = 1'b0;
      23'b00000010000000000000000: n6689_o = 1'b0;
      23'b00000001000000000000000: n6689_o = 1'b0;
      23'b00000000100000000000000: n6689_o = 1'b0;
      23'b00000000010000000000000: n6689_o = 1'b0;
      23'b00000000001000000000000: n6689_o = 1'b0;
      23'b00000000000100000000000: n6689_o = 1'b0;
      23'b00000000000010000000000: n6689_o = 1'b0;
      23'b00000000000001000000000: n6689_o = 1'b0;
      23'b00000000000000100000000: n6689_o = 1'b0;
      23'b00000000000000010000000: n6689_o = n5926_o;
      23'b00000000000000001000000: n6689_o = n5862_o;
      23'b00000000000000000100000: n6689_o = 1'b0;
      23'b00000000000000000010000: n6689_o = 1'b0;
      23'b00000000000000000001000: n6689_o = 1'b0;
      23'b00000000000000000000100: n6689_o = 1'b0;
      23'b00000000000000000000010: n6689_o = 1'b0;
      23'b00000000000000000000001: n6689_o = 1'b0;
      default: n6689_o = 1'bX;
    endcase
  assign n6690_o = n5980_o[2:0];
  assign n6691_o = n6033_o[2:0];
  assign n6692_o = n6375_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6695_o = n6612_o;
      23'b01000000000000000000000: n6695_o = n6542_o;
      23'b00100000000000000000000: n6695_o = 3'b000;
      23'b00010000000000000000000: n6695_o = 3'b000;
      23'b00001000000000000000000: n6695_o = n6692_o;
      23'b00000100000000000000000: n6695_o = 3'b000;
      23'b00000010000000000000000: n6695_o = 3'b000;
      23'b00000001000000000000000: n6695_o = 3'b000;
      23'b00000000100000000000000: n6695_o = 3'b000;
      23'b00000000010000000000000: n6695_o = 3'b000;
      23'b00000000001000000000000: n6695_o = 3'b000;
      23'b00000000000100000000000: n6695_o = 3'b000;
      23'b00000000000010000000000: n6695_o = 3'b000;
      23'b00000000000001000000000: n6695_o = n6691_o;
      23'b00000000000000100000000: n6695_o = n6690_o;
      23'b00000000000000010000000: n6695_o = 3'b000;
      23'b00000000000000001000000: n6695_o = 3'b000;
      23'b00000000000000000100000: n6695_o = 3'b000;
      23'b00000000000000000010000: n6695_o = 3'b000;
      23'b00000000000000000001000: n6695_o = 3'b000;
      23'b00000000000000000000100: n6695_o = 3'b000;
      23'b00000000000000000000010: n6695_o = 3'b000;
      23'b00000000000000000000001: n6695_o = 3'b000;
      default: n6695_o = 3'bX;
    endcase
  assign n6696_o = n5980_o[3];
  assign n6697_o = n6033_o[3];
  assign n6698_o = n6375_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6701_o = n6615_o;
      23'b01000000000000000000000: n6701_o = n6545_o;
      23'b00100000000000000000000: n6701_o = 1'b0;
      23'b00010000000000000000000: n6701_o = 1'b0;
      23'b00001000000000000000000: n6701_o = n6698_o;
      23'b00000100000000000000000: n6701_o = 1'b0;
      23'b00000010000000000000000: n6701_o = 1'b0;
      23'b00000001000000000000000: n6701_o = 1'b0;
      23'b00000000100000000000000: n6701_o = 1'b0;
      23'b00000000010000000000000: n6701_o = 1'b0;
      23'b00000000001000000000000: n6701_o = 1'b0;
      23'b00000000000100000000000: n6701_o = 1'b0;
      23'b00000000000010000000000: n6701_o = 1'b0;
      23'b00000000000001000000000: n6701_o = n6697_o;
      23'b00000000000000100000000: n6701_o = n6696_o;
      23'b00000000000000010000000: n6701_o = 1'b0;
      23'b00000000000000001000000: n6701_o = 1'b0;
      23'b00000000000000000100000: n6701_o = 1'b0;
      23'b00000000000000000010000: n6701_o = 1'b0;
      23'b00000000000000000001000: n6701_o = 1'b0;
      23'b00000000000000000000100: n6701_o = 1'b0;
      23'b00000000000000000000010: n6701_o = 1'b0;
      23'b00000000000000000000001: n6701_o = 1'b0;
      default: n6701_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6704_o = n6618_o;
      23'b01000000000000000000000: n6704_o = n6548_o;
      23'b00100000000000000000000: n6704_o = 1'b0;
      23'b00010000000000000000000: n6704_o = n6431_o;
      23'b00001000000000000000000: n6704_o = 1'b0;
      23'b00000100000000000000000: n6704_o = n6339_o;
      23'b00000010000000000000000: n6704_o = n6298_o;
      23'b00000001000000000000000: n6704_o = n6248_o;
      23'b00000000100000000000000: n6704_o = n6163_o;
      23'b00000000010000000000000: n6704_o = 1'b0;
      23'b00000000001000000000000: n6704_o = 1'b0;
      23'b00000000000100000000000: n6704_o = 1'b0;
      23'b00000000000010000000000: n6704_o = 1'b0;
      23'b00000000000001000000000: n6704_o = 1'b0;
      23'b00000000000000100000000: n6704_o = 1'b0;
      23'b00000000000000010000000: n6704_o = 1'b0;
      23'b00000000000000001000000: n6704_o = n5866_o;
      23'b00000000000000000100000: n6704_o = 1'b0;
      23'b00000000000000000010000: n6704_o = 1'b0;
      23'b00000000000000000001000: n6704_o = 1'b0;
      23'b00000000000000000000100: n6704_o = 1'b0;
      23'b00000000000000000000010: n6704_o = 1'b0;
      23'b00000000000000000000001: n6704_o = 1'b0;
      default: n6704_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6708_o = 1'b0;
      23'b01000000000000000000000: n6708_o = 1'b0;
      23'b00100000000000000000000: n6708_o = 1'b0;
      23'b00010000000000000000000: n6708_o = 1'b0;
      23'b00001000000000000000000: n6708_o = 1'b0;
      23'b00000100000000000000000: n6708_o = 1'b0;
      23'b00000010000000000000000: n6708_o = 1'b0;
      23'b00000001000000000000000: n6708_o = 1'b0;
      23'b00000000100000000000000: n6708_o = 1'b0;
      23'b00000000010000000000000: n6708_o = 1'b0;
      23'b00000000001000000000000: n6708_o = 1'b0;
      23'b00000000000100000000000: n6708_o = 1'b0;
      23'b00000000000010000000000: n6708_o = 1'b1;
      23'b00000000000001000000000: n6708_o = 1'b0;
      23'b00000000000000100000000: n6708_o = 1'b0;
      23'b00000000000000010000000: n6708_o = 1'b0;
      23'b00000000000000001000000: n6708_o = 1'b0;
      23'b00000000000000000100000: n6708_o = 1'b0;
      23'b00000000000000000010000: n6708_o = 1'b0;
      23'b00000000000000000001000: n6708_o = 1'b0;
      23'b00000000000000000000100: n6708_o = 1'b0;
      23'b00000000000000000000010: n6708_o = 1'b0;
      23'b00000000000000000000001: n6708_o = 1'b0;
      default: n6708_o = 1'bX;
    endcase
  assign n6710_o = n6551_o[2:0];
  assign n6711_o = n6621_o[2:0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6714_o = n6711_o;
      23'b01000000000000000000000: n6714_o = n6710_o;
      23'b00100000000000000000000: n6714_o = 3'b000;
      23'b00010000000000000000000: n6714_o = n6433_o;
      23'b00001000000000000000000: n6714_o = 3'b000;
      23'b00000100000000000000000: n6714_o = n6341_o;
      23'b00000010000000000000000: n6714_o = n6300_o;
      23'b00000001000000000000000: n6714_o = n6250_o;
      23'b00000000100000000000000: n6714_o = n6165_o;
      23'b00000000010000000000000: n6714_o = 3'b000;
      23'b00000000001000000000000: n6714_o = 3'b000;
      23'b00000000000100000000000: n6714_o = 3'b000;
      23'b00000000000010000000000: n6714_o = 3'b010;
      23'b00000000000001000000000: n6714_o = n6035_o;
      23'b00000000000000100000000: n6714_o = n5982_o;
      23'b00000000000000010000000: n6714_o = 3'b000;
      23'b00000000000000001000000: n6714_o = n5868_o;
      23'b00000000000000000100000: n6714_o = 3'b000;
      23'b00000000000000000010000: n6714_o = 3'b000;
      23'b00000000000000000001000: n6714_o = 3'b000;
      23'b00000000000000000000100: n6714_o = 3'b000;
      23'b00000000000000000000010: n6714_o = 3'b000;
      23'b00000000000000000000001: n6714_o = 3'b000;
      default: n6714_o = 3'bX;
    endcase
  assign n6716_o = n6551_o[3];
  assign n6717_o = n6621_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6720_o = n6717_o;
      23'b01000000000000000000000: n6720_o = n6716_o;
      23'b00100000000000000000000: n6720_o = 1'b0;
      23'b00010000000000000000000: n6720_o = 1'b0;
      23'b00001000000000000000000: n6720_o = 1'b0;
      23'b00000100000000000000000: n6720_o = 1'b0;
      23'b00000010000000000000000: n6720_o = 1'b0;
      23'b00000001000000000000000: n6720_o = 1'b0;
      23'b00000000100000000000000: n6720_o = 1'b0;
      23'b00000000010000000000000: n6720_o = 1'b0;
      23'b00000000001000000000000: n6720_o = 1'b0;
      23'b00000000000100000000000: n6720_o = 1'b0;
      23'b00000000000010000000000: n6720_o = 1'b1;
      23'b00000000000001000000000: n6720_o = 1'b0;
      23'b00000000000000100000000: n6720_o = 1'b0;
      23'b00000000000000010000000: n6720_o = 1'b0;
      23'b00000000000000001000000: n6720_o = n5870_o;
      23'b00000000000000000100000: n6720_o = 1'b0;
      23'b00000000000000000010000: n6720_o = 1'b0;
      23'b00000000000000000001000: n6720_o = 1'b0;
      23'b00000000000000000000100: n6720_o = 1'b0;
      23'b00000000000000000000010: n6720_o = 1'b0;
      23'b00000000000000000000001: n6720_o = 1'b0;
      default: n6720_o = 1'bX;
    endcase
  assign n6721_o = n5928_o[0];
  assign n6722_o = n5985_o[0];
  assign n6723_o = n6038_o[0];
  assign n6725_o = n6302_o[0];
  assign n6726_o = n6343_o[0];
  assign n6727_o = n6483_o[0];
  assign n6728_o = n6555_o[0];
  assign n6729_o = n6625_o[0];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6732_o = n6729_o;
      23'b01000000000000000000000: n6732_o = n6728_o;
      23'b00100000000000000000000: n6732_o = n6727_o;
      23'b00010000000000000000000: n6732_o = 1'b0;
      23'b00001000000000000000000: n6732_o = 1'b0;
      23'b00000100000000000000000: n6732_o = n6726_o;
      23'b00000010000000000000000: n6732_o = n6725_o;
      23'b00000001000000000000000: n6732_o = n6252_o;
      23'b00000000100000000000000: n6732_o = n6167_o;
      23'b00000000010000000000000: n6732_o = 1'b0;
      23'b00000000001000000000000: n6732_o = 1'b0;
      23'b00000000000100000000000: n6732_o = 1'b0;
      23'b00000000000010000000000: n6732_o = 1'b1;
      23'b00000000000001000000000: n6732_o = n6723_o;
      23'b00000000000000100000000: n6732_o = n6722_o;
      23'b00000000000000010000000: n6732_o = n6721_o;
      23'b00000000000000001000000: n6732_o = 1'b0;
      23'b00000000000000000100000: n6732_o = 1'b0;
      23'b00000000000000000010000: n6732_o = 1'b0;
      23'b00000000000000000001000: n6732_o = 1'b0;
      23'b00000000000000000000100: n6732_o = 1'b0;
      23'b00000000000000000000010: n6732_o = 1'b0;
      23'b00000000000000000000001: n6732_o = 1'b0;
      default: n6732_o = 1'bX;
    endcase
  assign n6733_o = n5928_o[2:1];
  assign n6734_o = n5985_o[2:1];
  assign n6735_o = n6038_o[2:1];
  assign n6737_o = n6302_o[2:1];
  assign n6738_o = n6343_o[2:1];
  assign n6739_o = n6483_o[2:1];
  assign n6740_o = n6555_o[2:1];
  assign n6741_o = n6625_o[2:1];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6744_o = n6741_o;
      23'b01000000000000000000000: n6744_o = n6740_o;
      23'b00100000000000000000000: n6744_o = n6739_o;
      23'b00010000000000000000000: n6744_o = 2'b00;
      23'b00001000000000000000000: n6744_o = 2'b00;
      23'b00000100000000000000000: n6744_o = n6738_o;
      23'b00000010000000000000000: n6744_o = n6737_o;
      23'b00000001000000000000000: n6744_o = n6254_o;
      23'b00000000100000000000000: n6744_o = n6169_o;
      23'b00000000010000000000000: n6744_o = 2'b00;
      23'b00000000001000000000000: n6744_o = 2'b00;
      23'b00000000000100000000000: n6744_o = 2'b00;
      23'b00000000000010000000000: n6744_o = 2'b11;
      23'b00000000000001000000000: n6744_o = n6735_o;
      23'b00000000000000100000000: n6744_o = n6734_o;
      23'b00000000000000010000000: n6744_o = n6733_o;
      23'b00000000000000001000000: n6744_o = 2'b00;
      23'b00000000000000000100000: n6744_o = 2'b00;
      23'b00000000000000000010000: n6744_o = 2'b00;
      23'b00000000000000000001000: n6744_o = 2'b00;
      23'b00000000000000000000100: n6744_o = 2'b00;
      23'b00000000000000000000010: n6744_o = 2'b00;
      23'b00000000000000000000001: n6744_o = 2'b00;
      default: n6744_o = 2'bX;
    endcase
  assign n6745_o = n5928_o[3];
  assign n6746_o = n5985_o[3];
  assign n6747_o = n6038_o[3];
  assign n6749_o = n6555_o[3];
  assign n6750_o = n6625_o[3];
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6753_o = n6750_o;
      23'b01000000000000000000000: n6753_o = n6749_o;
      23'b00100000000000000000000: n6753_o = n6485_o;
      23'b00010000000000000000000: n6753_o = 1'b0;
      23'b00001000000000000000000: n6753_o = 1'b0;
      23'b00000100000000000000000: n6753_o = 1'b0;
      23'b00000010000000000000000: n6753_o = 1'b0;
      23'b00000001000000000000000: n6753_o = n6256_o;
      23'b00000000100000000000000: n6753_o = n6171_o;
      23'b00000000010000000000000: n6753_o = 1'b0;
      23'b00000000001000000000000: n6753_o = 1'b0;
      23'b00000000000100000000000: n6753_o = 1'b0;
      23'b00000000000010000000000: n6753_o = 1'b0;
      23'b00000000000001000000000: n6753_o = n6747_o;
      23'b00000000000000100000000: n6753_o = n6746_o;
      23'b00000000000000010000000: n6753_o = n6745_o;
      23'b00000000000000001000000: n6753_o = 1'b0;
      23'b00000000000000000100000: n6753_o = 1'b0;
      23'b00000000000000000010000: n6753_o = 1'b0;
      23'b00000000000000000001000: n6753_o = 1'b0;
      23'b00000000000000000000100: n6753_o = 1'b0;
      23'b00000000000000000000010: n6753_o = 1'b0;
      23'b00000000000000000000001: n6753_o = 1'b0;
      default: n6753_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6756_o = n6627_o;
      23'b01000000000000000000000: n6756_o = n6557_o;
      23'b00100000000000000000000: n6756_o = n2182_o;
      23'b00010000000000000000000: n6756_o = n2182_o;
      23'b00001000000000000000000: n6756_o = n2182_o;
      23'b00000100000000000000000: n6756_o = n6345_o;
      23'b00000010000000000000000: n6756_o = n6304_o;
      23'b00000001000000000000000: n6756_o = n6259_o;
      23'b00000000100000000000000: n6756_o = n6174_o;
      23'b00000000010000000000000: n6756_o = n2182_o;
      23'b00000000001000000000000: n6756_o = n2182_o;
      23'b00000000000100000000000: n6756_o = n2182_o;
      23'b00000000000010000000000: n6756_o = 4'b0010;
      23'b00000000000001000000000: n6756_o = n6040_o;
      23'b00000000000000100000000: n6756_o = n5987_o;
      23'b00000000000000010000000: n6756_o = n2182_o;
      23'b00000000000000001000000: n6756_o = n2182_o;
      23'b00000000000000000100000: n6756_o = n2182_o;
      23'b00000000000000000010000: n6756_o = n2182_o;
      23'b00000000000000000001000: n6756_o = n2182_o;
      23'b00000000000000000000100: n6756_o = n2182_o;
      23'b00000000000000000000010: n6756_o = n2182_o;
      23'b00000000000000000000001: n6756_o = n2182_o;
      default: n6756_o = 4'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6760_o = n6630_o;
      23'b01000000000000000000000: n6760_o = n6560_o;
      23'b00100000000000000000000: n6760_o = 1'b0;
      23'b00010000000000000000000: n6760_o = 1'b0;
      23'b00001000000000000000000: n6760_o = 1'b0;
      23'b00000100000000000000000: n6760_o = n6348_o;
      23'b00000010000000000000000: n6760_o = n6307_o;
      23'b00000001000000000000000: n6760_o = n6263_o;
      23'b00000000100000000000000: n6760_o = n6178_o;
      23'b00000000010000000000000: n6760_o = 1'b0;
      23'b00000000001000000000000: n6760_o = 1'b0;
      23'b00000000000100000000000: n6760_o = 1'b0;
      23'b00000000000010000000000: n6760_o = 1'b1;
      23'b00000000000001000000000: n6760_o = n6043_o;
      23'b00000000000000100000000: n6760_o = 1'b0;
      23'b00000000000000010000000: n6760_o = 1'b0;
      23'b00000000000000001000000: n6760_o = 1'b0;
      23'b00000000000000000100000: n6760_o = 1'b0;
      23'b00000000000000000010000: n6760_o = 1'b0;
      23'b00000000000000000001000: n6760_o = 1'b0;
      23'b00000000000000000000100: n6760_o = 1'b0;
      23'b00000000000000000000010: n6760_o = 1'b0;
      23'b00000000000000000000001: n6760_o = 1'b0;
      default: n6760_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6763_o = 1'b0;
      23'b01000000000000000000000: n6763_o = 1'b0;
      23'b00100000000000000000000: n6763_o = 1'b0;
      23'b00010000000000000000000: n6763_o = 1'b0;
      23'b00001000000000000000000: n6763_o = 1'b0;
      23'b00000100000000000000000: n6763_o = 1'b0;
      23'b00000010000000000000000: n6763_o = 1'b0;
      23'b00000001000000000000000: n6763_o = 1'b0;
      23'b00000000100000000000000: n6763_o = 1'b0;
      23'b00000000010000000000000: n6763_o = 1'b0;
      23'b00000000001000000000000: n6763_o = 1'b0;
      23'b00000000000100000000000: n6763_o = 1'b0;
      23'b00000000000010000000000: n6763_o = 1'b0;
      23'b00000000000001000000000: n6763_o = n6046_o;
      23'b00000000000000100000000: n6763_o = 1'b0;
      23'b00000000000000010000000: n6763_o = 1'b0;
      23'b00000000000000001000000: n6763_o = 1'b0;
      23'b00000000000000000100000: n6763_o = 1'b0;
      23'b00000000000000000010000: n6763_o = 1'b0;
      23'b00000000000000000001000: n6763_o = 1'b0;
      23'b00000000000000000000100: n6763_o = 1'b0;
      23'b00000000000000000000010: n6763_o = 1'b0;
      23'b00000000000000000000001: n6763_o = 1'b0;
      default: n6763_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6766_o = n6634_o;
      23'b01000000000000000000000: n6766_o = n6564_o;
      23'b00100000000000000000000: n6766_o = n6488_o;
      23'b00010000000000000000000: n6766_o = n6436_o;
      23'b00001000000000000000000: n6766_o = n6379_o;
      23'b00000100000000000000000: n6766_o = n6352_o;
      23'b00000010000000000000000: n6766_o = n6311_o;
      23'b00000001000000000000000: n6766_o = 3'b111;
      23'b00000000100000000000000: n6766_o = 3'b111;
      23'b00000000010000000000000: n6766_o = 3'b111;
      23'b00000000001000000000000: n6766_o = 3'b111;
      23'b00000000000100000000000: n6766_o = 3'b111;
      23'b00000000000010000000000: n6766_o = 3'b111;
      23'b00000000000001000000000: n6766_o = n6049_o;
      23'b00000000000000100000000: n6766_o = n5991_o;
      23'b00000000000000010000000: n6766_o = n5932_o;
      23'b00000000000000001000000: n6766_o = n5874_o;
      23'b00000000000000000100000: n6766_o = 3'b111;
      23'b00000000000000000010000: n6766_o = 3'b111;
      23'b00000000000000000001000: n6766_o = 3'b111;
      23'b00000000000000000000100: n6766_o = 3'b111;
      23'b00000000000000000000010: n6766_o = 3'b111;
      23'b00000000000000000000001: n6766_o = 3'b111;
      default: n6766_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6769_o = n6637_o;
      23'b01000000000000000000000: n6769_o = n6567_o;
      23'b00100000000000000000000: n6769_o = n6491_o;
      23'b00010000000000000000000: n6769_o = n6439_o;
      23'b00001000000000000000000: n6769_o = 1'b0;
      23'b00000100000000000000000: n6769_o = 1'b0;
      23'b00000010000000000000000: n6769_o = 1'b0;
      23'b00000001000000000000000: n6769_o = 1'b0;
      23'b00000000100000000000000: n6769_o = 1'b0;
      23'b00000000010000000000000: n6769_o = 1'b0;
      23'b00000000001000000000000: n6769_o = 1'b0;
      23'b00000000000100000000000: n6769_o = 1'b0;
      23'b00000000000010000000000: n6769_o = 1'b0;
      23'b00000000000001000000000: n6769_o = 1'b0;
      23'b00000000000000100000000: n6769_o = 1'b0;
      23'b00000000000000010000000: n6769_o = 1'b0;
      23'b00000000000000001000000: n6769_o = 1'b0;
      23'b00000000000000000100000: n6769_o = 1'b0;
      23'b00000000000000000010000: n6769_o = 1'b0;
      23'b00000000000000000001000: n6769_o = 1'b0;
      23'b00000000000000000000100: n6769_o = 1'b0;
      23'b00000000000000000000010: n6769_o = 1'b0;
      23'b00000000000000000000001: n6769_o = 1'b0;
      default: n6769_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6772_o = 1'b0;
      23'b01000000000000000000000: n6772_o = 1'b0;
      23'b00100000000000000000000: n6772_o = 1'b0;
      23'b00010000000000000000000: n6772_o = 1'b0;
      23'b00001000000000000000000: n6772_o = n6382_o;
      23'b00000100000000000000000: n6772_o = 1'b0;
      23'b00000010000000000000000: n6772_o = 1'b0;
      23'b00000001000000000000000: n6772_o = 1'b0;
      23'b00000000100000000000000: n6772_o = 1'b0;
      23'b00000000010000000000000: n6772_o = 1'b0;
      23'b00000000001000000000000: n6772_o = 1'b0;
      23'b00000000000100000000000: n6772_o = 1'b0;
      23'b00000000000010000000000: n6772_o = 1'b0;
      23'b00000000000001000000000: n6772_o = 1'b0;
      23'b00000000000000100000000: n6772_o = 1'b0;
      23'b00000000000000010000000: n6772_o = 1'b0;
      23'b00000000000000001000000: n6772_o = 1'b0;
      23'b00000000000000000100000: n6772_o = 1'b0;
      23'b00000000000000000010000: n6772_o = 1'b0;
      23'b00000000000000000001000: n6772_o = 1'b0;
      23'b00000000000000000000100: n6772_o = 1'b0;
      23'b00000000000000000000010: n6772_o = 1'b0;
      23'b00000000000000000000001: n6772_o = 1'b0;
      default: n6772_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6775_o = 1'b0;
      23'b01000000000000000000000: n6775_o = 1'b0;
      23'b00100000000000000000000: n6775_o = 1'b0;
      23'b00010000000000000000000: n6775_o = 1'b0;
      23'b00001000000000000000000: n6775_o = n6385_o;
      23'b00000100000000000000000: n6775_o = 1'b0;
      23'b00000010000000000000000: n6775_o = 1'b0;
      23'b00000001000000000000000: n6775_o = 1'b0;
      23'b00000000100000000000000: n6775_o = 1'b0;
      23'b00000000010000000000000: n6775_o = 1'b0;
      23'b00000000001000000000000: n6775_o = 1'b0;
      23'b00000000000100000000000: n6775_o = 1'b0;
      23'b00000000000010000000000: n6775_o = 1'b0;
      23'b00000000000001000000000: n6775_o = 1'b0;
      23'b00000000000000100000000: n6775_o = 1'b0;
      23'b00000000000000010000000: n6775_o = n5935_o;
      23'b00000000000000001000000: n6775_o = n5877_o;
      23'b00000000000000000100000: n6775_o = 1'b0;
      23'b00000000000000000010000: n6775_o = 1'b0;
      23'b00000000000000000001000: n6775_o = 1'b0;
      23'b00000000000000000000100: n6775_o = 1'b0;
      23'b00000000000000000000010: n6775_o = 1'b0;
      23'b00000000000000000000001: n6775_o = 1'b0;
      default: n6775_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6778_o = 1'b0;
      23'b01000000000000000000000: n6778_o = 1'b0;
      23'b00100000000000000000000: n6778_o = 1'b0;
      23'b00010000000000000000000: n6778_o = 1'b0;
      23'b00001000000000000000000: n6778_o = n6388_o;
      23'b00000100000000000000000: n6778_o = 1'b0;
      23'b00000010000000000000000: n6778_o = 1'b0;
      23'b00000001000000000000000: n6778_o = 1'b0;
      23'b00000000100000000000000: n6778_o = 1'b0;
      23'b00000000010000000000000: n6778_o = 1'b0;
      23'b00000000001000000000000: n6778_o = 1'b0;
      23'b00000000000100000000000: n6778_o = 1'b0;
      23'b00000000000010000000000: n6778_o = 1'b0;
      23'b00000000000001000000000: n6778_o = 1'b0;
      23'b00000000000000100000000: n6778_o = 1'b0;
      23'b00000000000000010000000: n6778_o = n5938_o;
      23'b00000000000000001000000: n6778_o = n5880_o;
      23'b00000000000000000100000: n6778_o = 1'b0;
      23'b00000000000000000010000: n6778_o = 1'b0;
      23'b00000000000000000001000: n6778_o = 1'b0;
      23'b00000000000000000000100: n6778_o = 1'b0;
      23'b00000000000000000000010: n6778_o = 1'b0;
      23'b00000000000000000000001: n6778_o = 1'b0;
      default: n6778_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6785_o = 3'b000;
      23'b01000000000000000000000: n6785_o = 3'b000;
      23'b00100000000000000000000: n6785_o = 3'b000;
      23'b00010000000000000000000: n6785_o = 3'b000;
      23'b00001000000000000000000: n6785_o = 3'b000;
      23'b00000100000000000000000: n6785_o = 3'b000;
      23'b00000010000000000000000: n6785_o = 3'b000;
      23'b00000001000000000000000: n6785_o = 3'b000;
      23'b00000000100000000000000: n6785_o = 3'b000;
      23'b00000000010000000000000: n6785_o = 3'b000;
      23'b00000000001000000000000: n6785_o = 3'b000;
      23'b00000000000100000000000: n6785_o = 3'b000;
      23'b00000000000010000000000: n6785_o = 3'b000;
      23'b00000000000001000000000: n6785_o = 3'b000;
      23'b00000000000000100000000: n6785_o = 3'b000;
      23'b00000000000000010000000: n6785_o = 3'b000;
      23'b00000000000000001000000: n6785_o = 3'b000;
      23'b00000000000000000100000: n6785_o = 3'b111;
      23'b00000000000000000010000: n6785_o = 3'b110;
      23'b00000000000000000001000: n6785_o = 3'b101;
      23'b00000000000000000000100: n6785_o = 3'b100;
      23'b00000000000000000000010: n6785_o = 3'b000;
      23'b00000000000000000000001: n6785_o = 3'b000;
      default: n6785_o = 3'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6788_o = 1'b0;
      23'b01000000000000000000000: n6788_o = 1'b0;
      23'b00100000000000000000000: n6788_o = 1'b0;
      23'b00010000000000000000000: n6788_o = 1'b0;
      23'b00001000000000000000000: n6788_o = n6391_o;
      23'b00000100000000000000000: n6788_o = 1'b0;
      23'b00000010000000000000000: n6788_o = 1'b0;
      23'b00000001000000000000000: n6788_o = 1'b0;
      23'b00000000100000000000000: n6788_o = 1'b0;
      23'b00000000010000000000000: n6788_o = 1'b0;
      23'b00000000001000000000000: n6788_o = 1'b0;
      23'b00000000000100000000000: n6788_o = 1'b0;
      23'b00000000000010000000000: n6788_o = 1'b0;
      23'b00000000000001000000000: n6788_o = 1'b0;
      23'b00000000000000100000000: n6788_o = 1'b0;
      23'b00000000000000010000000: n6788_o = 1'b0;
      23'b00000000000000001000000: n6788_o = 1'b0;
      23'b00000000000000000100000: n6788_o = 1'b0;
      23'b00000000000000000010000: n6788_o = 1'b0;
      23'b00000000000000000001000: n6788_o = 1'b0;
      23'b00000000000000000000100: n6788_o = 1'b0;
      23'b00000000000000000000010: n6788_o = 1'b0;
      23'b00000000000000000000001: n6788_o = 1'b0;
      default: n6788_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6791_o = 1'b0;
      23'b01000000000000000000000: n6791_o = 1'b0;
      23'b00100000000000000000000: n6791_o = 1'b0;
      23'b00010000000000000000000: n6791_o = 1'b0;
      23'b00001000000000000000000: n6791_o = 1'b0;
      23'b00000100000000000000000: n6791_o = 1'b0;
      23'b00000010000000000000000: n6791_o = 1'b0;
      23'b00000001000000000000000: n6791_o = 1'b0;
      23'b00000000100000000000000: n6791_o = 1'b0;
      23'b00000000010000000000000: n6791_o = 1'b0;
      23'b00000000001000000000000: n6791_o = 1'b0;
      23'b00000000000100000000000: n6791_o = 1'b0;
      23'b00000000000010000000000: n6791_o = 1'b0;
      23'b00000000000001000000000: n6791_o = 1'b0;
      23'b00000000000000100000000: n6791_o = n5994_o;
      23'b00000000000000010000000: n6791_o = 1'b0;
      23'b00000000000000001000000: n6791_o = 1'b0;
      23'b00000000000000000100000: n6791_o = 1'b0;
      23'b00000000000000000010000: n6791_o = 1'b0;
      23'b00000000000000000001000: n6791_o = 1'b0;
      23'b00000000000000000000100: n6791_o = 1'b0;
      23'b00000000000000000000010: n6791_o = 1'b0;
      23'b00000000000000000000001: n6791_o = 1'b0;
      default: n6791_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6794_o = 1'b0;
      23'b01000000000000000000000: n6794_o = 1'b0;
      23'b00100000000000000000000: n6794_o = 1'b0;
      23'b00010000000000000000000: n6794_o = 1'b0;
      23'b00001000000000000000000: n6794_o = 1'b0;
      23'b00000100000000000000000: n6794_o = 1'b0;
      23'b00000010000000000000000: n6794_o = 1'b0;
      23'b00000001000000000000000: n6794_o = 1'b0;
      23'b00000000100000000000000: n6794_o = 1'b0;
      23'b00000000010000000000000: n6794_o = 1'b0;
      23'b00000000001000000000000: n6794_o = 1'b0;
      23'b00000000000100000000000: n6794_o = 1'b0;
      23'b00000000000010000000000: n6794_o = 1'b0;
      23'b00000000000001000000000: n6794_o = n6052_o;
      23'b00000000000000100000000: n6794_o = 1'b0;
      23'b00000000000000010000000: n6794_o = 1'b0;
      23'b00000000000000001000000: n6794_o = 1'b0;
      23'b00000000000000000100000: n6794_o = 1'b0;
      23'b00000000000000000010000: n6794_o = 1'b0;
      23'b00000000000000000001000: n6794_o = 1'b0;
      23'b00000000000000000000100: n6794_o = 1'b0;
      23'b00000000000000000000010: n6794_o = 1'b0;
      23'b00000000000000000000001: n6794_o = 1'b0;
      default: n6794_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6797_o = n6640_o;
      23'b01000000000000000000000: n6797_o = n6570_o;
      23'b00100000000000000000000: n6797_o = 1'b0;
      23'b00010000000000000000000: n6797_o = 1'b0;
      23'b00001000000000000000000: n6797_o = 1'b0;
      23'b00000100000000000000000: n6797_o = 1'b0;
      23'b00000010000000000000000: n6797_o = 1'b0;
      23'b00000001000000000000000: n6797_o = 1'b0;
      23'b00000000100000000000000: n6797_o = 1'b0;
      23'b00000000010000000000000: n6797_o = 1'b0;
      23'b00000000001000000000000: n6797_o = 1'b0;
      23'b00000000000100000000000: n6797_o = 1'b0;
      23'b00000000000010000000000: n6797_o = 1'b0;
      23'b00000000000001000000000: n6797_o = 1'b0;
      23'b00000000000000100000000: n6797_o = 1'b0;
      23'b00000000000000010000000: n6797_o = 1'b0;
      23'b00000000000000001000000: n6797_o = 1'b0;
      23'b00000000000000000100000: n6797_o = 1'b0;
      23'b00000000000000000010000: n6797_o = 1'b0;
      23'b00000000000000000001000: n6797_o = 1'b0;
      23'b00000000000000000000100: n6797_o = 1'b0;
      23'b00000000000000000000010: n6797_o = 1'b0;
      23'b00000000000000000000001: n6797_o = 1'b0;
      default: n6797_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6800_o = 1'b0;
      23'b01000000000000000000000: n6800_o = 1'b0;
      23'b00100000000000000000000: n6800_o = 1'b0;
      23'b00010000000000000000000: n6800_o = 1'b0;
      23'b00001000000000000000000: n6800_o = 1'b0;
      23'b00000100000000000000000: n6800_o = 1'b0;
      23'b00000010000000000000000: n6800_o = n6314_o;
      23'b00000001000000000000000: n6800_o = 1'b0;
      23'b00000000100000000000000: n6800_o = 1'b0;
      23'b00000000010000000000000: n6800_o = 1'b0;
      23'b00000000001000000000000: n6800_o = 1'b0;
      23'b00000000000100000000000: n6800_o = 1'b0;
      23'b00000000000010000000000: n6800_o = 1'b0;
      23'b00000000000001000000000: n6800_o = 1'b0;
      23'b00000000000000100000000: n6800_o = 1'b0;
      23'b00000000000000010000000: n6800_o = 1'b0;
      23'b00000000000000001000000: n6800_o = 1'b0;
      23'b00000000000000000100000: n6800_o = 1'b0;
      23'b00000000000000000010000: n6800_o = 1'b0;
      23'b00000000000000000001000: n6800_o = 1'b0;
      23'b00000000000000000000100: n6800_o = 1'b0;
      23'b00000000000000000000010: n6800_o = 1'b0;
      23'b00000000000000000000001: n6800_o = 1'b0;
      default: n6800_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6803_o = 1'b0;
      23'b01000000000000000000000: n6803_o = 1'b0;
      23'b00100000000000000000000: n6803_o = 1'b0;
      23'b00010000000000000000000: n6803_o = 1'b0;
      23'b00001000000000000000000: n6803_o = 1'b0;
      23'b00000100000000000000000: n6803_o = n6355_o;
      23'b00000010000000000000000: n6803_o = 1'b0;
      23'b00000001000000000000000: n6803_o = 1'b0;
      23'b00000000100000000000000: n6803_o = 1'b0;
      23'b00000000010000000000000: n6803_o = 1'b0;
      23'b00000000001000000000000: n6803_o = 1'b0;
      23'b00000000000100000000000: n6803_o = 1'b0;
      23'b00000000000010000000000: n6803_o = 1'b0;
      23'b00000000000001000000000: n6803_o = 1'b0;
      23'b00000000000000100000000: n6803_o = 1'b0;
      23'b00000000000000010000000: n6803_o = 1'b0;
      23'b00000000000000001000000: n6803_o = 1'b0;
      23'b00000000000000000100000: n6803_o = 1'b0;
      23'b00000000000000000010000: n6803_o = 1'b0;
      23'b00000000000000000001000: n6803_o = 1'b0;
      23'b00000000000000000000100: n6803_o = 1'b0;
      23'b00000000000000000000010: n6803_o = 1'b0;
      23'b00000000000000000000001: n6803_o = 1'b0;
      default: n6803_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6806_o = 1'b0;
      23'b01000000000000000000000: n6806_o = 1'b0;
      23'b00100000000000000000000: n6806_o = 1'b0;
      23'b00010000000000000000000: n6806_o = n6442_o;
      23'b00001000000000000000000: n6806_o = 1'b0;
      23'b00000100000000000000000: n6806_o = 1'b0;
      23'b00000010000000000000000: n6806_o = 1'b0;
      23'b00000001000000000000000: n6806_o = 1'b0;
      23'b00000000100000000000000: n6806_o = 1'b0;
      23'b00000000010000000000000: n6806_o = 1'b0;
      23'b00000000001000000000000: n6806_o = 1'b0;
      23'b00000000000100000000000: n6806_o = 1'b0;
      23'b00000000000010000000000: n6806_o = 1'b0;
      23'b00000000000001000000000: n6806_o = 1'b0;
      23'b00000000000000100000000: n6806_o = 1'b0;
      23'b00000000000000010000000: n6806_o = 1'b0;
      23'b00000000000000001000000: n6806_o = 1'b0;
      23'b00000000000000000100000: n6806_o = 1'b0;
      23'b00000000000000000010000: n6806_o = 1'b0;
      23'b00000000000000000001000: n6806_o = 1'b0;
      23'b00000000000000000000100: n6806_o = 1'b0;
      23'b00000000000000000000010: n6806_o = 1'b0;
      23'b00000000000000000000001: n6806_o = 1'b0;
      default: n6806_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6809_o = n6643_o;
      23'b01000000000000000000000: n6809_o = n6573_o;
      23'b00100000000000000000000: n6809_o = n6494_o;
      23'b00010000000000000000000: n6809_o = n6445_o;
      23'b00001000000000000000000: n6809_o = 2'b00;
      23'b00000100000000000000000: n6809_o = 2'b00;
      23'b00000010000000000000000: n6809_o = 2'b00;
      23'b00000001000000000000000: n6809_o = n6266_o;
      23'b00000000100000000000000: n6809_o = n6181_o;
      23'b00000000010000000000000: n6809_o = 2'b00;
      23'b00000000001000000000000: n6809_o = 2'b00;
      23'b00000000000100000000000: n6809_o = 2'b00;
      23'b00000000000010000000000: n6809_o = 2'b00;
      23'b00000000000001000000000: n6809_o = 2'b00;
      23'b00000000000000100000000: n6809_o = 2'b00;
      23'b00000000000000010000000: n6809_o = 2'b00;
      23'b00000000000000001000000: n6809_o = 2'b00;
      23'b00000000000000000100000: n6809_o = 2'b00;
      23'b00000000000000000010000: n6809_o = 2'b00;
      23'b00000000000000000001000: n6809_o = 2'b00;
      23'b00000000000000000000100: n6809_o = 2'b00;
      23'b00000000000000000000010: n6809_o = 2'b00;
      23'b00000000000000000000001: n6809_o = 2'b00;
      default: n6809_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6815_o = 2'b11;
      23'b01000000000000000000000: n6815_o = 2'b11;
      23'b00100000000000000000000: n6815_o = 2'b11;
      23'b00010000000000000000000: n6815_o = 2'b11;
      23'b00001000000000000000000: n6815_o = 2'b11;
      23'b00000100000000000000000: n6815_o = 2'b11;
      23'b00000010000000000000000: n6815_o = 2'b11;
      23'b00000001000000000000000: n6815_o = 2'b11;
      23'b00000000100000000000000: n6815_o = 2'b11;
      23'b00000000010000000000000: n6815_o = 2'b10;
      23'b00000000001000000000000: n6815_o = 2'b01;
      23'b00000000000100000000000: n6815_o = 2'b00;
      23'b00000000000010000000000: n6815_o = 2'b11;
      23'b00000000000001000000000: n6815_o = 2'b11;
      23'b00000000000000100000000: n6815_o = 2'b11;
      23'b00000000000000010000000: n6815_o = 2'b11;
      23'b00000000000000001000000: n6815_o = 2'b11;
      23'b00000000000000000100000: n6815_o = 2'b11;
      23'b00000000000000000010000: n6815_o = 2'b11;
      23'b00000000000000000001000: n6815_o = 2'b11;
      23'b00000000000000000000100: n6815_o = 2'b11;
      23'b00000000000000000000010: n6815_o = 2'b11;
      23'b00000000000000000000001: n6815_o = 2'b11;
      default: n6815_o = 2'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6818_o = n6646_o;
      23'b01000000000000000000000: n6818_o = n6576_o;
      23'b00100000000000000000000: n6818_o = 1'b0;
      23'b00010000000000000000000: n6818_o = 1'b0;
      23'b00001000000000000000000: n6818_o = 1'b0;
      23'b00000100000000000000000: n6818_o = n6358_o;
      23'b00000010000000000000000: n6818_o = n6317_o;
      23'b00000001000000000000000: n6818_o = n6270_o;
      23'b00000000100000000000000: n6818_o = n6185_o;
      23'b00000000010000000000000: n6818_o = 1'b0;
      23'b00000000001000000000000: n6818_o = 1'b0;
      23'b00000000000100000000000: n6818_o = 1'b0;
      23'b00000000000010000000000: n6818_o = 1'b0;
      23'b00000000000001000000000: n6818_o = n6056_o;
      23'b00000000000000100000000: n6818_o = n5997_o;
      23'b00000000000000010000000: n6818_o = 1'b0;
      23'b00000000000000001000000: n6818_o = 1'b0;
      23'b00000000000000000100000: n6818_o = 1'b0;
      23'b00000000000000000010000: n6818_o = 1'b0;
      23'b00000000000000000001000: n6818_o = 1'b0;
      23'b00000000000000000000100: n6818_o = 1'b0;
      23'b00000000000000000000010: n6818_o = 1'b0;
      23'b00000000000000000000001: n6818_o = 1'b0;
      default: n6818_o = 1'bX;
    endcase
  /* T80_MCode.vhd:1573:25  */
  always @*
    case (n6661_o)
      23'b10000000000000000000000: n6821_o = n6649_o;
      23'b01000000000000000000000: n6821_o = n6579_o;
      23'b00100000000000000000000: n6821_o = n6497_o;
      23'b00010000000000000000000: n6821_o = 1'b0;
      23'b00001000000000000000000: n6821_o = 1'b0;
      23'b00000100000000000000000: n6821_o = n6361_o;
      23'b00000010000000000000000: n6821_o = n6320_o;
      23'b00000001000000000000000: n6821_o = 1'b0;
      23'b00000000100000000000000: n6821_o = 1'b0;
      23'b00000000010000000000000: n6821_o = 1'b0;
      23'b00000000001000000000000: n6821_o = 1'b0;
      23'b00000000000100000000000: n6821_o = 1'b0;
      23'b00000000000010000000000: n6821_o = 1'b0;
      23'b00000000000001000000000: n6821_o = 1'b0;
      23'b00000000000000100000000: n6821_o = n6000_o;
      23'b00000000000000010000000: n6821_o = n5942_o;
      23'b00000000000000001000000: n6821_o = 1'b0;
      23'b00000000000000000100000: n6821_o = 1'b0;
      23'b00000000000000000010000: n6821_o = 1'b0;
      23'b00000000000000000001000: n6821_o = 1'b0;
      23'b00000000000000000000100: n6821_o = 1'b0;
      23'b00000000000000000000010: n6821_o = 1'b0;
      23'b00000000000000000000001: n6821_o = 1'b0;
      default: n6821_o = 1'bX;
    endcase
  assign n6822_o = {n5283_o, n4195_o};
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6823_o = n5261_o;
      2'b01: n6823_o = n3980_o;
      default: n6823_o = n6677_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6825_o = n5263_o;
      2'b01: n6825_o = n3985_o;
      default: n6825_o = n6683_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6827_o = 1'b0;
      2'b01: n6827_o = n3988_o;
      default: n6827_o = n6686_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6830_o = 1'b0;
      2'b01: n6830_o = n3991_o;
      default: n6830_o = n6689_o;
    endcase
  assign n6832_o = n6695_o[1:0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6834_o = 2'b00;
      2'b01: n6834_o = n4003_o;
      default: n6834_o = n6832_o;
    endcase
  assign n6835_o = n4015_o[0];
  assign n6836_o = n6695_o[2];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6838_o = 1'b0;
      2'b01: n6838_o = n6835_o;
      default: n6838_o = n6836_o;
    endcase
  assign n6839_o = n4015_o[1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6841_o = 1'b0;
      2'b01: n6841_o = n6839_o;
      default: n6841_o = n6701_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6845_o = n5266_o;
      2'b01: n6845_o = n4024_o;
      default: n6845_o = n6704_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6848_o = 1'b0;
      2'b01: n6848_o = n4027_o;
      default: n6848_o = n6708_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6850_o = n4196_o;
      2'b01: n6850_o = n4031_o;
      default: n6850_o = n6714_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6852_o = 1'b0;
      2'b01: n6852_o = n4035_o;
      default: n6852_o = n6720_o;
    endcase
  assign n6855_o = n5268_o[0];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6856_o = n6855_o;
      2'b01: n6856_o = n4059_o;
      default: n6856_o = n6732_o;
    endcase
  assign n6857_o = n5268_o[2:1];
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6858_o = n6857_o;
      2'b01: n6858_o = n4083_o;
      default: n6858_o = n6744_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6860_o = 1'b0;
      2'b01: n6860_o = n4101_o;
      default: n6860_o = n6753_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6864_o = n5270_o;
      2'b01: n6864_o = n4107_o;
      default: n6864_o = n6756_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6865_o = n5273_o;
      2'b01: n6865_o = n4115_o;
      default: n6865_o = n6760_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6868_o = 1'b0;
      2'b01: n6868_o = n4120_o;
      default: n6868_o = n6763_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6871_o = 1'b0;
      2'b01: n6871_o = n4123_o;
      default: n6871_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6873_o = n5275_o;
      2'b01: n6873_o = n4126_o;
      default: n6873_o = n6766_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6876_o = 1'b0;
      2'b01: n6876_o = n4129_o;
      default: n6876_o = n6769_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6879_o = 1'b0;
      2'b01: n6879_o = n4132_o;
      default: n6879_o = n6772_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6882_o = 1'b0;
      2'b01: n6882_o = n4136_o;
      default: n6882_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6885_o = 1'b0;
      2'b01: n6885_o = n4139_o;
      default: n6885_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6888_o = 1'b0;
      2'b01: n6888_o = n4142_o;
      default: n6888_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6891_o = 1'b0;
      2'b01: n6891_o = n4145_o;
      default: n6891_o = n6775_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6894_o = 1'b0;
      2'b01: n6894_o = n4148_o;
      default: n6894_o = n6778_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6897_o = 1'b0;
      2'b01: n6897_o = n4152_o;
      default: n6897_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6900_o = 3'b000;
      2'b01: n6900_o = 3'b000;
      default: n6900_o = n6785_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6903_o = 1'b0;
      2'b01: n6903_o = n4156_o;
      default: n6903_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6906_o = 1'b0;
      2'b01: n6906_o = n4160_o;
      default: n6906_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6909_o = 1'b0;
      2'b01: n6909_o = n4164_o;
      default: n6909_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6912_o = 1'b0;
      2'b01: n6912_o = n4168_o;
      default: n6912_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6915_o = 1'b0;
      2'b01: n6915_o = n4172_o;
      default: n6915_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6918_o = 1'b0;
      2'b01: n6918_o = 1'b0;
      default: n6918_o = n6788_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6921_o = 1'b0;
      2'b01: n6921_o = 1'b0;
      default: n6921_o = n6791_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6924_o = 1'b0;
      2'b01: n6924_o = 1'b0;
      default: n6924_o = n6794_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6927_o = 1'b0;
      2'b01: n6927_o = 1'b0;
      default: n6927_o = n6797_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6930_o = 1'b0;
      2'b01: n6930_o = 1'b0;
      default: n6930_o = n6800_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6933_o = 1'b0;
      2'b01: n6933_o = 1'b0;
      default: n6933_o = n6803_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6936_o = 1'b0;
      2'b01: n6936_o = 1'b0;
      default: n6936_o = n6806_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6939_o = 2'b00;
      2'b01: n6939_o = n4175_o;
      default: n6939_o = n6809_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6942_o = 1'b0;
      2'b01: n6942_o = n4179_o;
      default: n6942_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6945_o = 1'b0;
      2'b01: n6945_o = n4183_o;
      default: n6945_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6948_o = 2'b11;
      2'b01: n6948_o = 2'b11;
      default: n6948_o = n6815_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6951_o = 1'b0;
      2'b01: n6951_o = n4187_o;
      default: n6951_o = 1'b0;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6954_o = 1'b0;
      2'b01: n6954_o = n4190_o;
      default: n6954_o = n6818_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6956_o = n5278_o;
      2'b01: n6956_o = n4193_o;
      default: n6956_o = n6821_o;
    endcase
  /* T80_MCode.vhd:256:17  */
  always @*
    case (n6822_o)
      2'b10: n6959_o = n5281_o;
      2'b01: n6959_o = 1'b0;
      default: n6959_o = 1'b0;
    endcase
  assign n6967_o = {n6841_o, n6838_o, n6834_o};
  assign n6968_o = {n6852_o, n6850_o};
  assign n6969_o = {n6860_o, n6858_o, n6856_o};
endmodule
