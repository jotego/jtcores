///////////////////////////////////////////////////////////////////////////////
// ./src/artix7/transceiver.v : 
//
// Author: Mike Field <hamster@snap.net.nz>
//
// Part of the DisplayPort_Verlog project - an open implementation of the 
// DisplayPort protocol for FPGA boards. 
//
// See https://github.com/hamsternz/DisplayPort_Verilog for latest versions.
//
///////////////////////////////////////////////////////////////////////////////
// Version |  Notes
// ----------------------------------------------------------------------------
//   1.0   | Initial Release
//
///////////////////////////////////////////////////////////////////////////////
//
// MIT License
// 
// Copyright (c) 2019 Mike Field
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////
//
// Want to say thanks?
//
// This design has taken many hours - 3 months of work for the initial VHDL
// design, and another month or so to convert it to Verilog for this release.
//
// I'm more than happy to share it if you can make use of it. It is released
// under the MIT license, so you are not under any onus to say thanks, but....
//
// If you what to say thanks for this design either drop me an email, or how about
// trying PayPal to my email (hamster@snap.net.nz)?
//
//  Educational use - Enough for a beer
//  Hobbyist use    - Enough for a pizza
//  Research use    - Enough to take the family out to dinner
//  Commercial use  - A weeks pay for an engineer (I wish!)
//
///////////////////////////////////////////////////////////////////////////////
module transceiver(
    input wire         mgmt_clk,
    input wire         powerup_channel,

    input wire   [4:0] preemp_level,
    input wire   [3:0] swing_level,

    output wire        tx_running,

    input wire         pll0clk,
    input wire         pll0refclk,
           
    output wire        pll_pd ,
    output wire        pll_reset,
    output wire        pll_locken,
    input wire         pll_lock,

    input wire         pll1clk,
    input wire         pll1refclk,

    output wire        tx_out_clk,
    input wire         tx_symbol_clk,
    input wire  [19:0] tx_symbol,
           
    output wire        gtptx_p,
    output wire        gtptx_n);

parameter [26:0] CLKPERMICROSECOND = 27'd28; 

wire  [3:0] txchardispmode;
wire  [3:0] txchardispval;
wire [31:0] txdata_for_tx;
wire  [3:0] txdata_iskchark;

wire ref_clk_fabric;
wire txreset;
wire txresetdone;
wire txpcsreset;
wire txpmareset;
wire txuserrdy;
wire resetsel;

wire txusrclk;
wire txusrclk2;


wire [15:0] ignore_DRPDO;
wire        ignore_DRPRDY;
wire        ignore_PHYSTATUS;
wire        ignore_RXVALID;
wire        ignore_EYESCANDATAERROR;
wire        ignore_RXPMARESETDONE;
wire        ignore_RXCDRLOCK;
wire        ignore_RXOSINTDONE;
wire        ignore_RXOSINTSTARTED;
wire        ignore_RXOSINTSTROBESTARTED;
wire  [1:0] ignore_RXCLKCORCNT;
wire [31:0] ignore_RXDATA;
wire        ignore_RXPRBSERR;
wire  [3:0] ignore_RXCHARISCOMMA;
wire  [3:0] ignore_RXCHARISK;
wire  [3:0] ignore_RXDISPERR;
wire  [3:0] ignore_RXNOTINTABLE;
wire        ignore_PMARSVDOUT0;
wire        ignore_PMARSVDOUT1;
wire  [2:0] ignore_RXBUFSTATUS;
wire        ignore_RXDLYSRESETDONE;
wire        ignore_RXPHALIGNDONE;
wire  [4:0] ignore_RXPHMONITOR;
wire  [4:0] ignore_RXPHSLIPMONITOR;
wire  [2:0] ignore_RXSTATUS;
wire        ignore_RXSYNCDONE;
wire        ignore_RXSYNCOUT;
wire        ignore_RXBYTEISALIGNED;
wire        ignore_RXBYTEREALIGN;
wire        ignore_RXCOMMADET;
wire        ignore_RXCHANBONDSEQ;
wire  [3:0] ignore_RXCHBONDO;
wire        ignore_RXCHANISALIGNED;
wire        ignore_RXCHANREALIGN;
wire [14:0] ignore_DMONITOROUT;
wire        ignore_RXOSINTSTROBEDONE;
wire        ignore_RXRATEDONE;
wire        ignore_RXOUTCLK;
wire        ignore_RXOUTCLKFABRIC;
wire        ignore_RXOUTCLKPCS;
wire  [1:0] ignore_RXDATAVALID;
wire  [2:0] ignore_RXHEADER;
wire        ignore_RXHEADERVALID;
wire  [1:0] ignore_RXSTARTOFSEQ;
wire        ignore_RXCOMSASDET;
wire        ignore_RXCOMWAKEDET;
wire        ignore_RXCOMINITDET;
wire        ignore_RXELECIDLE;
wire        ignore_RXRESETDONE;
wire [15:0] ignore_PCSRSVDOUT;
wire        ignore_TXPMARESETDONE;
wire        ignore_TXDLYSRESETDONE;
wire        ignore_TXPHALIGNDONE;
wire        ignore_TXPHINITDONE;
wire  [1:0] ignore_TXBUFSTATUS;
wire        ignore_TXSYNCDONE;
wire        ignore_TXSYNCOUT;
wire        ignore_TXOUTCLKPCS;
wire        ignore_TXRATEDONE;
wire        ignore_TXGEARBOXREADY;
wire        ignore_TXCOMFINISH;
       
assign txusrclk       = tx_symbol_clk;
assign txusrclk2      = tx_symbol_clk;

assign   txdata_for_tx[7:0]  = tx_symbol[7:0];
assign   txdata_iskchark[0]  = tx_symbol[8];
assign   txchardispval[0]    = 1'b0;
assign   txchardispmode[0]   = tx_symbol[9];

assign   txdata_for_tx[15:8] = tx_symbol[17:10];
assign   txdata_iskchark[1]  = tx_symbol[18];
assign   txchardispval[1]    = 1'b0;
assign   txchardispmode[1]   = tx_symbol[19];

gtx_tx_reset_controller #(.CLKPERMICROSECOND(CLKPERMICROSECOND)) i_gtx_tx_reset_controller(
               .clk             (mgmt_clk),
               .ref_clk         (ref_clk_fabric),

               .powerup_channel (powerup_channel),
               .tx_running      (tx_running),

               .pllpd           (pll_pd),
               .pllreset        (pll_reset),
               .plllocken       (pll_locken),
               .plllock         (pll_lock),

               .txreset         (txreset),
               .txpmareset      (txpmareset),
               .txpcsreset      (txpcsreset),
               .txuserrdy       (txuserrdy),
               .resetsel        (resetsel),
               .txresetdone     (txresetdone));
 
GTPE2_CHANNEL #(
        // Simulation-Only Attributes

        .SIM_RECEIVER_DETECT_PASS         ("TRUE"),
        .SIM_RESET_SPEEDUP                ("TRUE"),
        .SIM_TX_EIDLE_DRIVE_LEVEL         ("X"),
        .SIM_VERSION                      ("2.0"),

        // RX Byte and Word Alignment Attributes
        .ALIGN_COMMA_DOUBLE              ("FALSE"),
        .ALIGN_COMMA_ENABLE              (10'b1111111111),
        .ALIGN_COMMA_WORD                (1),
        .ALIGN_MCOMMA_DET                ("TRUE"),
        .ALIGN_MCOMMA_VALUE              (10'b1010000011),
        .ALIGN_PCOMMA_DET                ("TRUE"),
        .ALIGN_PCOMMA_VALUE              (10'b0101111100),
        .SHOW_REALIGN_COMMA              ("TRUE"),
        .RXSLIDE_AUTO_WAIT               (7),
        .RXSLIDE_MODE                    ("OFF"),
        .RX_SIG_VALID_DLY                (10),

        // RX 8B/10B Decoder Attributes
        .RX_DISPERR_SEQ_MATCH            ("FALSE"),
        .DEC_MCOMMA_DETECT               ("FALSE"),
        .DEC_PCOMMA_DETECT               ("FALSE"),
        .DEC_VALID_COMMA_ONLY            ("FALSE"),

       // RX Clock Correction Attributes
        .CBCC_DATA_SOURCE_SEL            ("ENCODED"),
        .CLK_COR_SEQ_2_USE               ("FALSE"),
        .CLK_COR_KEEP_IDLE               ("FALSE"),
        .CLK_COR_MAX_LAT                 (9),
        .CLK_COR_MIN_LAT                 (7),
        .CLK_COR_PRECEDENCE              ("TRUE"),
        .CLK_COR_REPEAT_WAIT             (0),
        .CLK_COR_SEQ_LEN                 (1),
        .CLK_COR_SEQ_1_ENABLE            (4'b1111),
        .CLK_COR_SEQ_1_1                 (10'b0100000000),
        .CLK_COR_SEQ_1_2                 (10'b0000000000),
        .CLK_COR_SEQ_1_3                 (10'b0000000000),
        .CLK_COR_SEQ_1_4                 (10'b0000000000),
        .CLK_CORRECT_USE                 ("FALSE"),
        .CLK_COR_SEQ_2_ENABLE            (4'b1111),
        .CLK_COR_SEQ_2_1                 (10'b0100000000),
        .CLK_COR_SEQ_2_2                 (10'b0000000000),
        .CLK_COR_SEQ_2_3                 (10'b0000000000),
        .CLK_COR_SEQ_2_4                 (10'b0000000000),

       // RX Channel Bonding Attributes
        .CHAN_BOND_KEEP_ALIGN            ("FALSE"),
        .CHAN_BOND_MAX_SKEW              (1),
        .CHAN_BOND_SEQ_LEN               (1),
        .CHAN_BOND_SEQ_1_1               (10'b0000000000),
        .CHAN_BOND_SEQ_1_2               (10'b0000000000),
        .CHAN_BOND_SEQ_1_3               (10'b0000000000),
        .CHAN_BOND_SEQ_1_4               (10'b0000000000),
        .CHAN_BOND_SEQ_1_ENABLE          (4'b1111),
        .CHAN_BOND_SEQ_2_1               (10'b0000000000),
        .CHAN_BOND_SEQ_2_2               (10'b0000000000),
        .CHAN_BOND_SEQ_2_3               (10'b0000000000),
        .CHAN_BOND_SEQ_2_4               (10'b0000000000),
        .CHAN_BOND_SEQ_2_ENABLE          (4'b1111),
        .CHAN_BOND_SEQ_2_USE             ("FALSE"),
        .FTS_DESKEW_SEQ_ENABLE           (4'b1111),
        .FTS_LANE_DESKEW_CFG             (4'b1111),
        .FTS_LANE_DESKEW_EN              ("FALSE"),

       // RX Margin Analysis Attributes
        .ES_CONTROL                      (6'b000000),
        .ES_ERRDET_EN                    ("FALSE"),
        .ES_EYE_SCAN_EN                  ("FALSE"),
        .ES_HORZ_OFFSET                  (3'b010),
        .ES_PMA_CFG                      (10'b0000000000),
        .ES_PRESCALE                     (5'b00000),
        .ES_QUALIFIER                    (64'h00000000000000000000),
        .ES_QUAL_MASK                    (64'h00000000000000000000),
        .ES_SDATA_MASK                   (64'h00000000000000000000),
        .ES_VERT_OFFSET                  (9'b000000000),

       // FPGA RX Interface Attributes
        .RX_DATA_WIDTH                   (20),

       // PMA Attributes
        .OUTREFCLK_SEL_INV               (2'b11),
        .PMA_RSV                         (32'h00000333),
        .PMA_RSV2                        (32'h00002040),
        .PMA_RSV3                        (2'b00),
        .PMA_RSV4                        (4'b0000),
        .RX_BIAS_CFG                     (16'b0000111100110011),
        .DMONITOR_CFG                    (24'h000A00),
        .RX_CM_SEL                       (2'h01),
        .RX_CM_TRIM                      (4'h0000),
        .RX_DEBUG_CFG                    (56'h00000000000000),
        .RX_OS_CFG                       (13'b0000010000000),
        .TERM_RCAL_CFG                   (15'b100001000010000),
        .TERM_RCAL_OVRD                  (3'h000),
        .TST_RSV                         (32'h00000000),
        .RX_CLK25_DIV                    (6),
        .TX_CLK25_DIV                    (6),
        .UCODEER_CLR                     (1'b0),

       // PCI Express Attributes
        .PCS_PCIE_EN                     ("FALSE"),

       // PCS Attributes
        .PCS_RSVD_ATTR                   (48'h000000000000),

       // RX Buffer Attributes
        .RXBUF_ADDR_MODE                 ("FAST"),
        .RXBUF_EIDLE_HI_CNT              (4'b1000),
        .RXBUF_EIDLE_LO_CNT              (4'b0000),
        .RXBUF_EN                        ("TRUE"),
        .RX_BUFFER_CFG                   (6'b000000),
        .RXBUF_RESET_ON_CB_CHANGE        ("TRUE"),
        .RXBUF_RESET_ON_COMMAALIGN       ("FALSE"),
        .RXBUF_RESET_ON_EIDLE            ("FALSE"),
        .RXBUF_RESET_ON_RATE_CHANGE      ("TRUE"),
        .RXBUFRESET_TIME                 (5'b00001),
        .RXBUF_THRESH_OVFLW              (61),
        .RXBUF_THRESH_OVRD               ("FALSE"),
        .RXBUF_THRESH_UNDFLW             (4),
        .RXDLY_CFG                       (16'h001F),
        .RXDLY_LCFG                      (12'h030),
        .RXDLY_TAP_CFG                   (16'h0000),
        .RXPH_CFG                        (24'hC00002),
        .RXPHDLY_CFG                     (24'h084020),
        .RXPH_MONITOR_SEL                (5'b00000),
        .RX_XCLK_SEL                     ("RXREC"),
        .RX_DDI_SEL                      (6'b000000),
        .RX_DEFER_RESET_BUF_EN           ("TRUE"),

        // CDR Attributes
        .RXCDR_CFG                       (84'h0001107FE206021081010),
        .RXCDR_FR_RESET_ON_EIDLE         (1'b0),
        .RXCDR_HOLD_DURING_EIDLE         (1'b0),
        .RXCDR_PH_RESET_ON_EIDLE         (1'b0),
        .RXCDR_LOCK_CFG                  (6'b001001),

       // RX Initialization and Reset Attributes
        .RXCDRFREQRESET_TIME             (5'b00001),
        .RXCDRPHRESET_TIME               (5'b00001),
        .RXISCANRESET_TIME               (5'b00001),
        .RXPCSRESET_TIME                 (5'b00001),
        .RXPMARESET_TIME                 (5'b00011),

       // RX OOB Signaling Attributes
        .RXOOB_CFG                       (7'b0000110),

       // RX Gearbox Attributes
        .RXGEARBOX_EN                    ("FALSE"),
        .GEARBOX_MODE                    (3'b000),

       // PRBS Detection Attribute
        .RXPRBS_ERR_LOOPBACK             (1'b0),

       // Power-Down Attributes
        .PD_TRANS_TIME_FROM_P2           (12'h03c),
        .PD_TRANS_TIME_NONE_P2           (8'h3c),
        .PD_TRANS_TIME_TO_P2             (8'h64),

       // RX OOB Signaling Attributes
        .SAS_MAX_COM                     (64),
        .SAS_MIN_COM                     (36),
        .SATA_BURST_SEQ_LEN              (4'b0101),
        .SATA_BURST_VAL                  (3'b100),
        .SATA_EIDLE_VAL                  (3'b100),
        .SATA_MAX_BURST                  (8),
        .SATA_MAX_INIT                   (21),
        .SATA_MAX_WAKE                   (7),
        .SATA_MIN_BURST                  (4),
        .SATA_MIN_INIT                   (12),
        .SATA_MIN_WAKE                   (4),

       // RX Fabric Clock Output Control Attributes
        .TRANS_TIME_RATE                 (8'h0E),

       // TX Buffer Attributes
        .TXBUF_EN                        ("TRUE"),
        .TXBUF_RESET_ON_RATE_CHANGE      ("TRUE"),
        .TXDLY_CFG                       (16'h001F),
        .TXDLY_LCFG                      (12'h030),
        .TXDLY_TAP_CFG                   (16'h0000),
        .TXPH_CFG                        (16'h0780),
        .TXPHDLY_CFG                     (24'h084020),
        .TXPH_MONITOR_SEL                (5'b00000),
        .TX_XCLK_SEL                     ("TXOUT"),

       // FPGA TX Interface Attributes
        .TX_DATA_WIDTH                   (20),

       // TX Configurable Driver Attributes
        .TX_DEEMPH0                      (6'b000000),
        .TX_DEEMPH1                      (6'b000000),
        .TX_EIDLE_ASSERT_DELAY           (3'b110),
        .TX_EIDLE_DEASSERT_DELAY         (3'b100),
        .TX_LOOPBACK_DRIVE_HIZ           ("FALSE"),
        .TX_MAINCURSOR_SEL               (1'b0),
        .TX_DRIVE_MODE                   ("DIRECT"),
        .TX_MARGIN_FULL_0                (7'b1001110),
        .TX_MARGIN_FULL_1                (7'b1001001),
        .TX_MARGIN_FULL_2                (7'b1000101),
        .TX_MARGIN_FULL_3                (7'b1000010),
        .TX_MARGIN_FULL_4                (7'b1000000),
        .TX_MARGIN_LOW_0                 (7'b1000110),
        .TX_MARGIN_LOW_1                 (7'b1000100),
        .TX_MARGIN_LOW_2                 (7'b1000010),
        .TX_MARGIN_LOW_3                 (7'b1000000),
        .TX_MARGIN_LOW_4                 (7'b1000000),

       // TX Gearbox Attributes
        .TXGEARBOX_EN                    ("FALSE"),

       // TX Initialization and Reset Attributes
        .TXPCSRESET_TIME                 (5'b00001),
        .TXPMARESET_TIME                 (5'b00001),

       // TX Receiver Detection Attributes
        .TX_RXDETECT_CFG                 (16'h1832),
        .TX_RXDETECT_REF                 (3'b100),

       // JTAG Attributes 
        .ACJTAG_DEBUG_MODE               (1'b0),
        .ACJTAG_MODE                     (1'b0),
        .ACJTAG_RESET                    (1'b0),

       // CDR Attributes
        .CFOK_CFG                        (44'h49000040E80),
        .CFOK_CFG2                       (7'b0100000),
        .CFOK_CFG3                       (7'b0100000),
        .CFOK_CFG4                       (1'b0),
        .CFOK_CFG5                       (4'h0),
        .CFOK_CFG6                       (4'b0000),
        .RXOSCALRESET_TIME               (5'b00011),
        .RXOSCALRESET_TIMEOUT            (5'b00000),

       // PMA Attributes 
        .CLK_COMMON_SWING                (1'b0),
        .RX_CLKMUX_EN                    (1'b1),
        .TX_CLKMUX_EN                    (1'b1),
        .ES_CLK_PHASE_SEL                (1'b0),
        .USE_PCS_CLK_PHASE_SEL           (1'b0),
        .PMA_RSV6                        (1'b0),
        .PMA_RSV7                        (1'b0),

       // TX Configuration Driver Attributes
        .TX_PREDRIVER_MODE               (1'b0),
        .PMA_RSV5                        (1'b0),
        .SATA_PLL_CFG                    ("VCO_3000MHZ"),

       // RX Fabric Clock Outpu:t Control Attributes
        .RXOUT_DIV                       (2),

       // TX Fabric Clock Output Control Attributes
        .TXOUT_DIV                       (2),

       // RX Phase Interpolator Attributes
        .RXPI_CFG0                       (3'b000),
        .RXPI_CFG1                       (1'b1),
        .RXPI_CFG2                       (1'b1),

       // RX Equalizer Attributes
        .ADAPT_CFG0                      (20'h00000),
        .RXLPMRESET_TIME                 (7'b0001111),
        .RXLPM_BIAS_STARTUP_DISABLE      (1'b0),
        .RXLPM_CFG                       (4'b0110),
        .RXLPM_CFG1                      (1'b0),
        .RXLPM_CM_CFG                                 (1'b0),
        .RXLPM_GC_CFG                                 (9'b111100010),
        .RXLPM_GC_CFG2                                (3'b001),
        .RXLPM_HF_CFG                                 (14'b00001111110000),
        .RXLPM_HF_CFG2                                (5'b01010),
        .RXLPM_HF_CFG3                                (4'b0000),
        .RXLPM_HOLD_DURING_EIDLE                      (1'b0),
        .RXLPM_INCM_CFG                               (1'b0),
        .RXLPM_IPCM_CFG                               (1'b1),
        .RXLPM_LF_CFG                                 (18'b000000001111110000),
        .RXLPM_LF_CFG2                                (5'b01010),
        .RXLPM_OSINT_CFG                              (3'b100),

       // TX Phase Interpolator PPM Controller Attributes
        .TXPI_CFG0                                    (2'b00),
        .TXPI_CFG1                                    (2'b00),
        .TXPI_CFG2                                    (2'b00),
        .TXPI_CFG3                                    (1'b0),
        .TXPI_CFG4                                    (1'b0),
        .TXPI_CFG5                                    (3'b000),
        .TXPI_GREY_SEL                                (1'b0),
        .TXPI_INVSTROBE_SEL                           (1'b0),
        .TXPI_PPMCLK_SEL                              ("TXUSRCLK2"),
        .TXPI_PPM_CFG                                 (8'h00),
        .TXPI_SYNFREQ_PPM                             (3'b000),

       // LOOPBACK Attributes
        .LOOPBACK_CFG                                 (1'b0),
        .PMA_LOOPBACK_CFG                             (1'b0),

       // RX OOB Signalling Attributes
        .RXOOB_CLK_CFG                                ("PMA"),

       // TX OOB Signalling Attributes
        .TXOOB_CFG                                    (1'b0),

       // RX Buffer Attributes
        .RXSYNC_MULTILANE                             (1'b1),
        .RXSYNC_OVRD                                  (1'b0),
        .RXSYNC_SKIP_DA                               (1'b0),

       // TX Buffer Attribute
        .TXSYNC_MULTILANE                             (1'b0),
        .TXSYNC_OVRD                                  (1'b0),
        .TXSYNC_SKIP_DA                               (1'b0)
    ) 
    i_gtpe2 (
        // CPLL Ports
        .GTRSVD                           (16'b0000000000000000),
        .PCSRSVDIN                        (16'b0000000000000000),
        .TSTIN                            (20'b11111111111111111111),
        // Channel - DRP Ports 
        .DRPADDR                          (9'b0),
        .DRPCLK                           (1'b0),
        .DRPDI                            (16'h0000),
        .DRPDO                            (ignore_DRPDO),
        .DRPEN                            (1'b0),
        .DRPRDY                           (ignore_DRPRDY),
        .DRPWE                            (1'b0),
        // Clocking Ports
        .RXSYSCLKSEL                      (2'b11),
        .TXSYSCLKSEL                      (2'b00),
        // FPGA TX Interface Datapath Configuration 
        .TX8B10BEN                        (1'b1),
        // GTPE2_CHANNEL Clocking Ports
        .PLL0CLK                          (pll0clk),
        .PLL0REFCLK                       (pll0refclk),
        .PLL1CLK                          (pll1clk),
        .PLL1REFCLK                       (pll1refclk),
        // Loopback Ports
        .LOOPBACK                         (3'b000),
        // PCI Express Ports
        .PHYSTATUS                        (ignore_PHYSTATUS),
        .RXRATE                           (3'b000),
        .RXVALID                          (ignore_RXVALID),
        // PMA Reserved Ports
        .PMARSVDIN3                            (1'b0),
        .PMARSVDIN4                            (1'b0),
        // Power-Down Ports
        .RXPD                                  (2'b11),
        .TXPD                                  (2'b00),
        // RX 8B/10B Decoder Ports
        .SETERRSTATUS                          (1'b0),
        // RX Initialization and Reset Ports
        .EYESCANRESET                          (1'b0),
        .RXUSERRDY                             (1'b0),
        // RX Margin Analysis Ports
        .EYESCANDATAERROR                      (ignore_EYESCANDATAERROR),
        .EYESCANMODE                           (1'b0),
        .EYESCANTRIGGER                        (1'b0),
        // Receive Ports
        .CLKRSVD0                              (1'b0),
        .CLKRSVD1                              (1'b0),
        .DMONFIFORESET                         (1'b0),
        .DMONITORCLK                           (1'b0),
        .RXPMARESETDONE                        (ignore_RXPMARESETDONE),
        .SIGVALIDCLK                           (1'b0),
        // Receive Ports - CDR Ports
        .RXCDRFREQRESET                        (1'b0),
        .RXCDRHOLD                             (1'b0),
        .RXCDRLOCK                             (ignore_RXCDRLOCK),
        .RXCDROVRDEN                           (1'b0),
        .RXCDRRESET                            (1'b0),
        .RXCDRRESETRSV                         (1'b0),
        .RXOSCALRESET                          (1'b0),
        .RXOSINTCFG                            (4'b0010),
        .RXOSINTDONE                           (ignore_RXOSINTDONE),
        .RXOSINTHOLD                           (1'b0),
        .RXOSINTOVRDEN                         (1'b0),
        .RXOSINTPD                             (1'b0),
        .RXOSINTSTARTED                        (ignore_RXOSINTSTARTED),
        .RXOSINTSTROBE                         (1'b0),
        .RXOSINTSTROBESTARTED                  (ignore_RXOSINTSTROBESTARTED),
        .RXOSINTTESTOVRDEN                     (1'b0),
        // Receive Ports - Clock Correction Ports
        .RXCLKCORCNT                           (ignore_RXCLKCORCNT),
        // Receive Ports - FPGA RX Interface Datapath Configuration
        .RX8B10BEN                             (1'b0),
        // Receive Ports - FPGA RX Interface Ports
        .RXDATA                                (ignore_RXDATA),
        .RXUSRCLK                              (1'b0),
        .RXUSRCLK2                             (1'b0),
        // Receive Ports - Pattern Checker Ports
        .RXPRBSERR                             (ignore_RXPRBSERR),
        .RXPRBSSEL                             (3'b000),
        // Receive Ports - Pattern Checker ports
        .RXPRBSCNTRESET                        (1'b0),
        // Receive Ports - RX 8B/10B Decoder Ports
        .RXCHARISCOMMA                         (ignore_RXCHARISCOMMA),
        .RXCHARISK                             (ignore_RXCHARISK),
        .RXDISPERR                             (ignore_RXDISPERR),
        .RXNOTINTABLE                          (ignore_RXNOTINTABLE),
        // Receive Ports - RX AFE Ports
        .GTPRXN                                (1'b0),
        .GTPRXP                                (1'b0),
        .PMARSVDIN2                            (1'b0),
        .PMARSVDOUT0                           (ignore_PMARSVDOUT0),
        .PMARSVDOUT1                           (ignore_PMARSVDOUT1),
        // Receive Ports - RX Buffer Bypass Ports
        .RXBUFRESET                            (1'b0),
        .RXBUFSTATUS                           (ignore_RXBUFSTATUS),
        .RXDDIEN                               (1'b0),
        .RXDLYBYPASS                           (1'b1),
        .RXDLYEN                               (1'b0),
        .RXDLYOVRDEN                           (1'b0),
        .RXDLYSRESET                           (1'b0),
        .RXDLYSRESETDONE                       (ignore_RXDLYSRESETDONE),
        .RXPHALIGN                             (1'b0),
        .RXPHALIGNDONE                         (ignore_RXPHALIGNDONE),
        .RXPHALIGNEN                           (1'b0),
        .RXPHDLYPD                             (1'b1),
        .RXPHDLYRESET                          (1'b0),
        .RXPHMONITOR                           (ignore_RXPHMONITOR),
        .RXPHOVRDEN                            (1'b0),
        .RXPHSLIPMONITOR                       (ignore_RXPHSLIPMONITOR),
        .RXSTATUS                              (ignore_RXSTATUS),
        .RXSYNCALLIN                           (1'b0),
        .RXSYNCDONE                            (ignore_RXSYNCDONE),
        .RXSYNCIN                              (1'b0),
        .RXSYNCMODE                            (1'b0),
        .RXSYNCOUT                             (ignore_RXSYNCOUT),
        // Receive Ports - RX Byte and Word Alignment Ports
        .RXBYTEISALIGNED                       (ignore_RXBYTEISALIGNED),
        .RXBYTEREALIGN                         (ignore_RXBYTEREALIGN),
        .RXCOMMADET                            (ignore_RXCOMMADET),
        .RXCOMMADETEN                          (1'b0),
        .RXMCOMMAALIGNEN                       (1'b0),
        .RXPCOMMAALIGNEN                       (1'b0),
        .RXSLIDE                               (1'b0),
        // Receive Ports - RX Channel Bonding Ports
        .RXCHANBONDSEQ                         (ignore_RXCHANBONDSEQ),
        .RXCHBONDEN                            (1'b0),
        .RXCHBONDI                             (4'b0000),
        .RXCHBONDLEVEL                         (3'b000),
        .RXCHBONDMASTER                        (1'b0),
        .RXCHBONDO                             (ignore_RXCHBONDO),
        .RXCHBONDSLAVE                         (1'b0),
        // Receive Ports - RX Channel Bonding Ports 
        .RXCHANISALIGNED                       (ignore_RXCHANISALIGNED),
        .RXCHANREALIGN                         (ignore_RXCHANREALIGN),
        // Receive Ports - RX Decision Feedback Equalizer(DFE)
        .DMONITOROUT                           (ignore_DMONITOROUT),
        .RXADAPTSELTEST                        (14'b00000000000000),
        .RXDFEXYDEN                            (1'b0),
        .RXOSINTEN                             (1'b1),
        .RXOSINTID0                            (4'b0000),
        .RXOSINTNTRLEN                         (1'b0),
        .RXOSINTSTROBEDONE                     (ignore_RXOSINTSTROBEDONE),
        // Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR
        .RXLPMLFOVRDEN                         (1'b0),
        .RXLPMOSINTNTRLEN                      (1'b0),
        // Receive Ports - RX Equailizer Ports
        .RXLPMHFHOLD                           (1'b0),
        .RXLPMHFOVRDEN                         (1'b0),
        .RXLPMLFHOLD                           (1'b0),
        // Receive Ports - RX Equalizer Ports
        .RXOSHOLD                              (1'b0),
        .RXOSOVRDEN                            (1'b0),
        // Receive Ports - RX Fabric ClocK Output Control Ports
        .RXRATEDONE                            (ignore_RXRATEDONE),
        // Receive Ports - RX Fabric Clock Output Control Ports 
        .RXRATEMODE                            (1'b0),
        // Receive Ports - RX Fabric Output Control Ports
        .RXOUTCLK                              (ignore_RXOUTCLK),
        .RXOUTCLKFABRIC                        (ignore_RXOUTCLKFABRIC),
        .RXOUTCLKPCS                           (ignore_RXOUTCLKPCS),
        .RXOUTCLKSEL                           (3'b010),
        // Receive Ports - RX Gearbox Ports
        .RXDATAVALID                           (ignore_RXDATAVALID),
        .RXHEADER                              (ignore_RXHEADER),
        .RXHEADERVALID                         (ignore_RXHEADERVALID),
        .RXSTARTOFSEQ                          (ignore_RXSTARTOFSEQ),
        // Receive Ports - RX Gearbox Ports 
        .RXGEARBOXSLIP                         (1'b0),
        // Receive Ports - RX Initialization and Reset Ports
        .GTRXRESET                             (1'b1),
        .RXLPMRESET                            (1'b1),
        .RXOOBRESET                            (1'b0),
        .RXPCSRESET                            (1'b0),
        .RXPMARESET                            (1'b0),
        // Receive Ports - RX OOB Signaling ports
        .RXCOMSASDET                           (ignore_RXCOMSASDET),
        .RXCOMWAKEDET                          (ignore_RXCOMWAKEDET),
        // Receive Ports - RX OOB Signaling ports 
        .RXCOMINITDET                          (ignore_RXCOMINITDET),
        // Receive Ports - RX OOB signalling Ports
        .RXELECIDLE                            (ignore_RXELECIDLE),
        .RXELECIDLEMODE                        (2'b11),
        // Receive Ports - RX Polarity Control Ports
        .RXPOLARITY                            (1'b0),
        // Receive Ports -RX Initialization and Reset Ports
        .RXRESETDONE                           (ignore_RXRESETDONE),
        // TX Buffer Bypass Ports
        .TXPHDLYTSTCLK                         (1'b0),
        // TX Configurable Driver Ports
        .TXPOSTCURSOR                          (5'b00000),
        .TXPOSTCURSORINV                       (1'b0),
        .TXPRECURSOR                           (preemp_level),
        .TXPRECURSORINV                        (1'b0),
        // TX Fabric Clock Output Control Ports
        .TXRATEMODE                            (1'b0),
        // TX Initialization and Reset Ports
        .CFGRESET                              (1'b0),
        .GTTXRESET                             (txreset),
        .PCSRSVDOUT                            (ignore_PCSRSVDOUT),
        .TXUSERRDY                             (txuserrdy),
        // TX Phase Interpolator PPM Controller Ports
        .TXPIPPMEN                             (1'b0),
        .TXPIPPMOVRDEN                         (1'b0),
        .TXPIPPMPD                             (1'b0),
        .TXPIPPMSEL                            (1'b1),
        .TXPIPPMSTEPSIZE                       (5'b00000),
        // Transceiver Reset Mode Operation
        .GTRESETSEL                            (resetsel),
        .RESETOVRD                             (1'b0),
        // Transmit Ports
        .TXPMARESETDONE                        (ignore_TXPMARESETDONE),
        // Transmit Ports - Configurable Driver Ports
        .PMARSVDIN0                            (1'b0),
        .PMARSVDIN1                            (1'b0),
        // Transmit Ports - FPGA TX Interface Ports
        .TXDATA                                (txdata_for_tx[31:0]),
        .TXUSRCLK                              (txusrclk),
        .TXUSRCLK2                             (txusrclk2),
        // Transmit Ports - PCI Express Ports
        .TXELECIDLE                            (1'b0),
        .TXMARGIN                              (3'b000),
        .TXRATE                                (3'b000),
        .TXSWING                               (1'b0),
        // Transmit Ports - Pattern Generator Ports
        .TXPRBSFORCEERR                        (1'b0),
        // Transmit Ports - TX 8B/10B Encoder Ports
        .TX8B10BBYPASS                         (4'b0000),
        .TXCHARDISPMODE                        (txchardispmode[3:0]),
        .TXCHARDISPVAL                         (txchardispval[3:0]),
        .TXCHARISK                             (txdata_iskchark[3:0]),
        // Transmit Ports - TX Buffer Bypass Ports
        .TXDLYBYPASS                           (1'b1),
        .TXDLYEN                               (1'b0),
        .TXDLYHOLD                             (1'b0),
        .TXDLYOVRDEN                           (1'b0),
        .TXDLYSRESET                           (1'b0),
        .TXDLYSRESETDONE                       (ignore_TXDLYSRESETDONE),
        .TXDLYUPDOWN                           (1'b0),
        .TXPHALIGN                             (1'b0),
        .TXPHALIGNDONE                         (ignore_TXPHALIGNDONE),
        .TXPHALIGNEN                           (1'b0),
        .TXPHDLYPD                             (1'b0),
        .TXPHDLYRESET                          (1'b0),
        .TXPHINIT                              (1'b0),
        .TXPHINITDONE                          (ignore_TXPHINITDONE),
        .TXPHOVRDEN                            (1'b0),
        // Transmit Ports - TX Buffer Ports
        .TXBUFSTATUS                           (ignore_TXBUFSTATUS),
        // Transmit Ports - TX Buffer and Phase Alignment Ports
        .TXSYNCALLIN                           (1'b0),
        .TXSYNCDONE                            (ignore_TXSYNCDONE),
        .TXSYNCIN                              (1'b0),
        .TXSYNCMODE                            (1'b0),
        .TXSYNCOUT                             (ignore_TXSYNCOUT),
        // Transmit Ports - TX Configurable Driver Ports
        .GTPTXN                                (gtptx_n),
        .GTPTXP                                (gtptx_p),
        .TXBUFDIFFCTRL                         (3'b100),
        .TXDEEMPH                              (1'b0),
        .TXDIFFCTRL                            (swing_level),
        .TXDIFFPD                              (1'b0),
        .TXINHIBIT                             (1'b0),
        .TXMAINCURSOR                          (7'b0000000),
        .TXPISOPD                              (1'b0),
        // Transmit Ports - TX Fabric Clock Output Control Ports
        .TXOUTCLK                              (tx_out_clk),
        .TXOUTCLKFABRIC                        (ref_clk_fabric),
        .TXOUTCLKPCS                           (ignore_TXOUTCLKPCS),
        .TXOUTCLKSEL                           (3'b010),
        .TXRATEDONE                            (ignore_TXRATEDONE),
        // Transmit Ports - TX Gearbox Ports
        .TXGEARBOXREADY                        (ignore_TXGEARBOXREADY),
        .TXHEADER                              (3'b000),
        .TXSEQUENCE                            (7'b0000000),
        .TXSTARTSEQ                            (1'b0),
        // Transmit Ports - TX Initialization and Reset Ports
        .TXPCSRESET                            (txpcsreset),
        .TXPMARESET                            (txpmareset),
        .TXRESETDONE                           (txresetdone),
        // Transmit Ports - TX OOB signalling Ports
        .TXCOMFINISH                           (ignore_TXCOMFINISH),
        .TXCOMINIT                             (1'b0),
        .TXCOMSAS                              (1'b0),
        .TXCOMWAKE                             (1'b0),
        .TXPDELECIDLEMODE                      (1'b0),
        // Transmit Ports - TX Polarity Control Ports
        .TXPOLARITY                            (1'b0),
        // Transmit Ports - TX Receiver Detection Ports
        .TXDETECTRX                            (1'b0),
        // Transmit Ports - pattern Generator Ports
        .TXPRBSSEL                             (3'b000)
);

endmodule
