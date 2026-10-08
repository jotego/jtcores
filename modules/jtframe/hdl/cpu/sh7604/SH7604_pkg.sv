package SH7604_PKG;

	//INTC
	typedef struct packed		//R/W;FFFFFEE2
	{
		bit [ 3: 0] DIVUIP;		//R/W
		bit [ 3: 0] DMACIP;		//R/W
		bit [ 3: 0] WDTIP;		//R/W
		bit [ 3: 0] UNUSED;
	} IPRA_t;
	parameter bit [15:0] IPRA_WMASK = 16'hFFF0;
	parameter bit [15:0] IPRA_RMASK = 16'hFFF0;
	parameter bit [15:0] IPRA_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFE60
	{
		bit [ 3: 0] SCIIP;		//R/W
		bit [ 3: 0] FRTIP;		//R/W
		bit [ 7: 0] UNUSED;
	} IPRB_t;
	parameter bit [15:0] IPRB_WMASK = 16'hFF00;
	parameter bit [15:0] IPRB_RMASK = 16'hFF00;
	parameter bit [15:0] IPRB_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFEE4
	{
		bit         UNUSED;
		bit [ 6: 0] WITV;			//R/W
		bit         UNUSED2;
		bit [ 6: 0] BCMV;			//R/W
	} VCRWDT_t;
	parameter bit [15:0] VCRWDT_WMASK = 16'h7F7F;
	parameter bit [15:0] VCRWDT_RMASK = 16'h7F7F;
	parameter bit [15:0] VCRWDT_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFE62
	{
		bit         UNUSED;
		bit [ 6: 0] SERV;			//R/W
		bit         UNUSED2;
		bit [ 6: 0] SRXV;			//R/W
	} VCRA_t;
	parameter bit [15:0] VCRA_WMASK = 16'h7F7F;
	parameter bit [15:0] VCRA_RMASK = 16'h7F7F;
	parameter bit [15:0] VCRA_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFE64
	{
		bit         UNUSED;
		bit [ 6: 0] STXV;			//R/W
		bit         UNUSED2;
		bit [ 6: 0] STEV;			//R/W
	} VCRB_t;
	parameter bit [15:0] VCRB_WMASK = 16'h7F7F;
	parameter bit [15:0] VCRB_RMASK = 16'h7F7F;
	parameter bit [15:0] VCRB_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFE66
	{
		bit         UNUSED;
		bit [ 6: 0] FICV;			//R/W
		bit         UNUSED2;
		bit [ 6: 0] FOCV;			//R/W
	} VCRC_t;
	parameter bit [15:0] VCRC_WMASK = 16'h7F7F;
	parameter bit [15:0] VCRC_RMASK = 16'h7F7F;
	parameter bit [15:0] VCRC_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFE68
	{
		bit         UNUSED;
		bit [ 6: 0] FOVV;			//R/W
		bit [ 7: 0] UNUSED2;
	} VCRD_t;
	parameter bit [15:0] VCRD_WMASK = 16'h7F00;
	parameter bit [15:0] VCRD_RMASK = 16'h7F00;
	parameter bit [15:0] VCRD_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFEE0
	{
		bit         NMIL;			//R
		bit [ 5: 0] UNUSED;
		bit         NMIE;			//R/W
		bit [ 6: 0] UNUSED2;
		bit         VECMD;		//R/W
	} ICR_t;
	parameter bit [15:0] ICR_WMASK = 16'h0101;
	parameter bit [15:0] ICR_RMASK = 16'h8101;
	parameter bit [15:0] ICR_INIT = 16'h0000;
	
	//Cache
	typedef struct packed		//R/W;FFFFFE92
	{
		bit [ 1: 0] W;				//R/W
		bit         UNUSED;
		bit         CP;			//R/W
		bit         TW;			//R/W
		bit         OD;			//R/W
		bit         ID;			//R/W
		bit         CE;			//R/W
	} CCR_t;
	parameter bit [7:0] CCR_WMASK = 8'hDF;
	parameter bit [7:0] CCR_RMASK = 8'hDF;
	parameter bit [7:0] CCR_INIT = 8'h00;
	
	//BSC
	typedef struct packed		//R/W;FFFFFFE2/FFFFFFE0
	{
		bit         MASTER;		//R
		bit [ 1: 0] UNUSED;
		bit         ENDIAN;		//R/W
		bit         BSTROM;		//R/W
		bit         PSHR;			//R/W
		bit [ 1: 0] AHLW;			//R/W
		bit [ 1: 0] A1LW;			//R/W
		bit [ 1: 0] A0LW;			//R/W
		bit         UNUSED2;
		bit [ 2: 0] DRAM;			//R/W
	} BCR1_t;
	parameter bit [15:0] BCR1_WMASK = 16'h1FF7;
	parameter bit [15:0] BCR1_RMASK = 16'h9FF7;
	parameter bit [15:0] BCR1_INIT = 16'h03F0;
	
	typedef struct packed		//R/W;FFFFFFE6/FFFFFFE4
	{
		bit [ 7: 0] UNUSED;
		bit [ 1: 0] A3SZ;			//R/W
		bit [ 1: 0] A2SZ;			//R/W
		bit [ 1: 0] A1SZ;			//R/W
		bit [ 1: 0] UNUSED2;
	} BCR2_t;
	parameter bit [15:0] BCR2_WMASK = 16'h00FC;
	parameter bit [15:0] BCR2_RMASK = 16'h00FC;
	parameter bit [15:0] BCR2_INIT = 16'h00FC;
	
	typedef struct packed		//R/W;FFFFFFEA/FFFFFFE8
	{
		bit [ 1: 0] IW3;			//R/W
		bit [ 1: 0] IW2;			//R/W
		bit [ 1: 0] IW1;			//R/W
		bit [ 1: 0] IW0;			//R/W
		bit [ 1: 0] W3;			//R/W
		bit [ 1: 0] W2;			//R/W
		bit [ 1: 0] W1;			//R/W
		bit [ 1: 0] W0;			//R/W
	} WCR_t;
	parameter bit [15:0] WCR_WMASK = 16'hFFFF;
	parameter bit [15:0] WCR_RMASK = 16'hFFFF;
	parameter bit [15:0] WCR_INIT = 16'hAAFF;
	
	typedef struct packed		//R/W;FFFFFFEE/FFFFFFEC
	{
		bit         TRP;			//R/W
		bit         RCD;			//R/W
		bit         TRWL;			//R/W
		bit [ 1: 0] TRAS;			//R/W
		bit         BE;			//R/W
		bit         RASD;			//R/W
		bit         UNUSED;
		bit         AMX2;			//R/W
		bit         SZ;			//R/W
		bit [ 1: 0] AMX;			//R/W
		bit         RFSH;			//R/W
		bit         RMD;			//R/W
		bit [ 1: 0] UNUSED2;
	} MCR_t;
	parameter bit [15:0] MCR_WMASK = 16'hFEFC;
	parameter bit [15:0] MCR_RMASK = 16'hFEFC;
	parameter bit [15:0] MCR_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFFF2/FFFFFFF0
	{
		bit [ 7: 0] UNUSED;
		bit         CMF;
		bit         CMIE;
		bit [ 2: 0] CKS;
		bit [ 2: 0] UNUSED2;
	} RTCSR_t;
	parameter bit [15:0] RTCSR_WMASK = 16'h00F8;
	parameter bit [15:0] RTCSR_RMASK = 16'h00F8;
	parameter bit [15:0] RTCSR_INIT = 16'h0000;
	
	typedef bit [7:0] RTCNT_t;	//R/W;FFFFFFF6/FFFFFFF4
	parameter bit [7:0] RTCNT_WMASK = 8'hFF;
	parameter bit [7:0] RTCNT_RMASK = 8'hFF;
	parameter bit [7:0] RTCNT_INIT = 8'h00;
	
	typedef bit [7:0] RTCOR_t;	//R/W;FFFFFFFA/FFFFFFF8
	parameter bit [7:0] RTCOR_WMASK = 8'hFF;
	parameter bit [7:0] RTCOR_RMASK = 8'hFF;
	parameter bit [7:0] RTCOR_INIT = 8'h00;
	
	//SCI
	typedef struct packed		//R/W;FFFFFE00
	{
		bit         CA;			//R/W
		bit         CHR;			//R/W
		bit         PE;			//R/W
		bit         OE;			//R/W
		bit         STOP;			//R/W
		bit         MP;			//R/W
		bit [ 1: 0] CKS;			//R/W
	} SMR_t;
	parameter bit [7:0] SMR_WMASK = 8'hFF;
	parameter bit [7:0] SMR_RMASK = 8'hFF;
	parameter bit [7:0] SMR_INIT = 8'h00;
	
	typedef bit [7:0] BRR_t;	//R/W;FFFFFE01
	parameter bit [7:0] BRR_WMASK = 8'hFF;
	parameter bit [7:0] BRR_RMASK = 8'hFF;
	parameter bit [7:0] BRR_INIT = 8'hFF;
	
	typedef struct packed		//R/W;FFFFFE02
	{
		bit         TIE;			//R/W
		bit         RIE;			//R/W
		bit         TE;			//R/W
		bit         RE;			//R/W
		bit         MPIE;			//R/W
		bit         TEIE;			//R/W
		bit [ 1: 0] CKE;			//R/W
	} SCR_t;
	parameter bit [7:0] SCR_WMASK = 8'hFF;
	parameter bit [7:0] SCR_RMASK = 8'hFF;
	parameter bit [7:0] SCR_INIT = 8'h00;
	
	typedef bit [7:0] TDR_t;	//R/W;FFFFFE03
	parameter bit [7:0] TDR_WMASK = 8'hFF;
	parameter bit [7:0] TDR_RMASK = 8'hFF;
	parameter bit [7:0] TDR_INIT = 8'hFF;
	
	typedef struct packed		//R/W;FFFFFE04
	{
		bit         TDRE;			//R/W
		bit         RDRF;			//R/W
		bit         ORER;			//R/W
		bit         FER;			//R/W
		bit         PER;			//R/W
		bit         TEND;			//R
		bit         MPB;			//R
		bit         MPBT;			//R/W
	} SSR_t;
	parameter bit [7:0] SSR_WMASK = 8'hF9;
	parameter bit [7:0] SSR_RMASK = 8'hFF;
	parameter bit [7:0] SSR_INIT = 8'h84;
	
	typedef bit [7:0] RDR_t;	//R;FFFFFE05
	parameter bit [7:0] RDR_WMASK = 8'h00;
	parameter bit [7:0] RDR_RMASK = 8'hFF;
	parameter bit [7:0] RDR_INIT = 8'h00;

	//FRT
	typedef struct packed		//R/W;FFFFFE10
	{
		bit         ICIE;			//R/W
		bit [ 2: 0] UNUSED;
		bit         OCIAE;		//R/W
		bit         OCIBE;		//R/W
		bit         OVIE;			//R/W
		bit         UNUSED2;
	} TIER_t;
	parameter bit [7:0] TIER_WMASK = 8'hFE;
	parameter bit [7:0] TIER_RMASK = 8'hFF;
	parameter bit [7:0] TIER_INIT = 8'h00;
	
	typedef struct packed		//R/W;FFFFFE11
	{
		bit         ICF;			//R/W
		bit [ 2: 0] UNUSED;
		bit         OCFA;			//R/W
		bit         OCFB;			//R/W
		bit         OVF;			//R/W
		bit         CCLRA;		//R/W
	} FTCSR_t;
	parameter bit [7:0] FTCSR_WMASK = 8'h8F;
	parameter bit [7:0] FTCSR_RMASK = 8'h8F;
	parameter bit [7:0] FTCSR_INIT = 8'h00;
	
	typedef bit [15:0] FRC_t;	//R/W;FFFFFE12-FFFFFE13
	parameter bit [15:0] FRC_WMASK = 16'hFFFF;
	parameter bit [15:0] FRC_RMASK = 16'hFFFF;
	parameter bit [15:0] FRC_INIT = 16'h0000;
	
	typedef bit [15:0] OCR_t;	//R/W;FFFFFE14-FFFFFE15
	parameter bit [15:0] OCR_WMASK = 16'hFFFF;
	parameter bit [15:0] OCR_RMASK = 16'hFFFF;
	parameter bit [15:0] OCR_INIT = 16'hFFFF;
	
	typedef struct packed		//R/W;FFFFFE16
	{
		bit         IEDG;			//R/W
		bit [ 4: 0] UNUSED;
		bit [ 1: 0] CKS;			//R/W
	} TCR_t;
	parameter bit [7:0] TCR_WMASK = 8'h83;
	parameter bit [7:0] TCR_RMASK = 8'h83;
	parameter bit [7:0] TCR_INIT = 8'h00;
	
	typedef struct packed		//R/W;FFFFFE17
	{
		bit [ 2: 0] UNUSED;
		bit         OCRS;			//R/W
		bit [ 1: 0] UNUSED2;
		bit         OLVLA;		//R/W
		bit         OLVLB;		//R/W
	} TOCR_t;
	parameter bit [7:0] TOCR_WMASK = 8'h1F;
	parameter bit [7:0] TOCR_RMASK = 8'hFF;
	parameter bit [7:0] TOCR_INIT = 8'h00;
	
	typedef bit [15:0] FICR_t;	//R;FFFFFE18-FFFFFE19
	parameter bit [15:0] FICR_WMASK = 16'h0000;
	parameter bit [15:0] FICR_RMASK = 16'hFFFF;
	parameter bit [15:0] FICR_INIT = 16'h0000;

	//WDT
	typedef bit [7:0] WTCNT_t;	//R;FFFFFE81/W;FFFFFE80
	parameter bit [7:0] WTCNT_WMASK = 8'hFF;
	parameter bit [7:0] WTCNT_RMASK = 8'hFF;
	parameter bit [7:0] WTCNT_INIT = 8'h00;
	
	typedef struct packed		//R;FFFFFE80/W;FFFFFE80
	{
		bit         OVF;			//R/W0
		bit         WTIT;			//R/W
		bit         TME;			//R/W
		bit [ 1: 0] UNUSED;
		bit [ 2: 0] CKS;			//R/W
	} WTCSR_t;
	parameter bit [7:0] WTCSR_WMASK = 8'hE7;
	parameter bit [7:0] WTCSR_RMASK = 8'hFF;
	parameter bit [7:0] WTCSR_INIT = 8'h18;
	
	typedef struct packed		//R;FFFFFE83/W;FFFFFE82
	{
		bit         WOVF;			//R/W0
		bit         RSTE;			//R/W
		bit         RSTS;			//R/W
		bit [ 4: 0] UNUSED;
	} RSTCSR_t;
	parameter bit [7:0] RSTCSR_WMASK = 8'hE0;
	parameter bit [7:0] RSTCSR_RMASK = 8'hFF;
	parameter bit [7:0] RSTCSR_INIT = 8'h1F;
	
	//DIVU
	typedef bit [31:0] DVSR_t;	//R/W;FFFFFF00
	parameter bit [31:0] DVSR_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DVSR_RMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DVSR_INIT = 32'h00000000;
	
	typedef bit [31:0] DVDNT_t;	//R/W;FFFFFF04,FFFFFF10,FFFFFF14
	parameter bit [31:0] DVDNT_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DVDNT_RMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DVDNT_INIT = 32'h00000000;
	
	typedef struct packed		//R/W;FFFFFF08
	{
		bit [29: 0] UNUSED;
		bit         OVFIE;		//R/W
		bit         OVF;			//R/W
	} DVCR_t;
	parameter bit [31:0] DVCR_WMASK = 32'h00000003;
	parameter bit [31:0] DVCR_RMASK = 32'h00000003;
	parameter bit [31:0] DVCR_INIT = 32'h00000000;
	
	typedef bit [15:0] VCRDIV_t;	//R/W;FFFFFF0C
	parameter bit [31:0] VCRDIV_WMASK = 32'h0000FFFF;
	parameter bit [31:0] VCRDIV_RMASK = 32'h0000FFFF;
	parameter bit [15:0] VCRDIV_INIT = 16'h0000;
	
	//DMAC
	typedef bit [31:0] SARx_t;	//R/W;FFFFFF80,FFFFFF90
	parameter bit [31:0] SARx_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] SARx_RMASK = 32'hFFFFFFFF;
	parameter bit [31:0] SARx_INIT = 32'h00000000;
	
	typedef bit [31:0] DARx_t;	//R/W;FFFFFF84,FFFFFF94
	parameter bit [31:0] DARx_WMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DARx_RMASK = 32'hFFFFFFFF;
	parameter bit [31:0] DARx_INIT = 32'h00000000;
	
	typedef bit [23:0] TCRx_t;	//R/W;FFFFFF88,FFFFFF98
	parameter bit [23:0] TCRx_WMASK = 24'hFFFFFF;
	parameter bit [23:0] TCRx_RMASK = 24'hFFFFFF;
	parameter bit [23:0] TCRx_INIT = 24'h000000;
	
	typedef struct packed		//R/W;FFFFFF8C,FFFFFF9C
	{
		bit [15: 0] UNUSED;
		bit [ 1: 0] DM;			//R/W
		bit [ 1: 0] SM;			//R/W
		bit [ 1: 0] TS;			//R/W
		bit         AR;			//R/W
		bit         AM;			//R/W
		bit         AL;			//R/W
		bit         DS;			//R/W
		bit         DL;			//R/W
		bit         TB;			//R/W
		bit         TA;			//R/W
		bit         IE;			//R/W
		bit         TE;			//R/W0
		bit         DE;			//R/W
	} CHCRx_t;
	parameter bit [31:0] CHCRx_WMASK = 32'h0000FFFF;
	parameter bit [31:0] CHCRx_RMASK = 32'h0000FFFF;
	parameter bit [31:0] CHCRx_INIT = 32'h00000000;
	
	typedef struct packed		//R/W;FFFFFFA0,FFFFFFA8
	{
		bit [23: 0] UNUSED;
		bit [ 7: 0] VC;			//R/W
	}  VCRDMAx_t;
	parameter bit [31:0] VCRDMAx_WMASK = 32'h000000FF;
	parameter bit [31:0] VCRDMAx_RMASK = 32'h000000FF;
	parameter bit [31:0] VCRDMAx_INIT = 32'h00000000;
	
	typedef struct packed		//R/W;FFFFFFB0
	{
		bit [27: 0] UNUSED;
		bit         PR;			//R/W
		bit         AE;			//R/W0
		bit         NMIF;			//R/W0
		bit         DME;			//R/W
	} DMAOR_t;
	parameter bit [31:0] DMAOR_WMASK = 32'h0000000F;
	parameter bit [31:0] DMAOR_RMASK = 32'h0000000F;
	parameter bit [31:0] DMAOR_INIT = 32'h00000000;
	
	typedef struct packed		//R/W;FFFFFE71,FFFFFE72
	{
		bit [ 5: 0] UNUSED;
		bit [ 1: 0] RS;			//R/W
	} DRCRx_t;
	parameter bit [7:0] DRCRx_WMASK = 8'h03;
	parameter bit [7:0] DRCRx_RMASK = 8'h03;
	parameter bit [7:0] DRCRx_INIT = 8'h00;
	
	//UBC
	typedef bit [15:0] BARx_t;	//R/W;FFFFFF40,FFFFFF42,FFFFFF60,FFFFFF62
	parameter bit [15:0] BARx_WMASK = 16'hFFFF;
	parameter bit [15:0] BARx_RMASK = 16'hFFFF;
	parameter bit [15:0] BARx_INIT = 16'h0000;
	
	typedef bit [15:0] BAMRx_t;	//R/W;FFFFFF44,FFFFFF46,FFFFFF64,FFFFFF66
	parameter bit [15:0] BAMRx_WMASK = 16'hFFFF;
	parameter bit [15:0] BAMRx_RMASK = 16'hFFFF;
	parameter bit [15:0] BAMRx_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFF48,FFFFFF68
	{
		bit [ 7: 0] UNUSED;
		bit [ 1: 0] CP;			//R/W
		bit [ 1: 0] ID;			//R/W
		bit [ 1: 0] RW;			//R/W
		bit [ 1: 0] SZ;			//R/W
	} BBRx_t;
	parameter bit [15:0] BBRx_WMASK = 16'h00FF;
	parameter bit [15:0] BBRx_RMASK = 16'h00FF;
	parameter bit [15:0] BBRx_INIT = 16'h0000;
	
	typedef bit [15:0] BDRB_t;	//R/W;FFFFFF70,FFFFFF72
	parameter bit [15:0] BDRB_WMASK = 16'hFFFF;
	parameter bit [15:0] BDRB_RMASK = 16'hFFFF;
	parameter bit [15:0] BDRB_INIT = 16'h0000;
	
	typedef bit [15:0] BDMRB_t;	//R/W;FFFFFF74,FFFFFF76
	parameter bit [15:0] BDMRB_WMASK = 16'hFFFF;
	parameter bit [15:0] BDMRB_RMASK = 16'hFFFF;
	parameter bit [15:0] BDMRB_INIT = 16'h0000;
	
	typedef struct packed		//R/W;FFFFFF78
	{
		bit         CMFCA;		//R/W
		bit         CMFPA;		//R/W
		bit         EBBE;			//R/W
		bit         UMD;			//R/W
		bit         UNUSED;
		bit         PCBA;			//R/W
		bit [ 1: 0] UNUSED2;
		bit         CMFCB;		//R/W
		bit         CMFPB;		//R/W
		bit         UNUSED3;
		bit         SEQ;			//R/W
		bit         DBEB;			//R
		bit         PCBB;			//R/W
		bit [ 1: 0] UNUSED4;
	} BRCR_t;
	parameter bit [15:0] BRCR_WMASK = 16'hF4D4;
	parameter bit [15:0] BRCR_RMASK = 16'hF4DC;
	parameter bit [15:0] BRCR_INIT = 16'h0000;
	
	//MSBY
	typedef struct packed		//R/W;FFFFFE91
	{
		bit         SBY;			//R/W
		bit         HIZ;			//R/W
		bit         UNUSED;
		bit [ 4: 0] MSTP;			//R/W
	} SBYCR_t;
	parameter bit [7:0] SBYCR_WMASK = 8'hDF;
	parameter bit [7:0] SBYCR_RMASK = 8'hDF;
	parameter bit [7:0] SBYCR_INIT = 8'h00;
	
endpackage
