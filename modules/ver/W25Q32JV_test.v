/******************************************************************************
 Winbond Electronics Corporation
 Verilog TestBench for W25Q32JV series Serial Flash Memory

 V0.1

 Copyright (c) 2001-2016 Winbond Electronics Corporation
 All Rights Reserved.

 Versions:
	10/12/2016 	Initial Version

******************************************************************************/

/******************************************************************************
 TEST VECTORS
******************************************************************************/

module test_25Q32JV;


W25Q32JV dut(CSn, CLK, DIO, DO, WPn, HOLDn);

reg  CSn_Reg, CLK_Reg;

parameter PAGESIZE = 256;
parameter NUM_PAGES = 16384;

parameter Tcss = 100;				         // CSn setup time in ns.
parameter Tcsh = 100;      	    		// CSn hold time in ns.
parameter Tcs  = 100;				         // CSn Deselect Time
parameter Thov = 5;	 				         // Host output to valid delay in ns.
parameter Freq = 33;				          // Frequency in Megahertz
`define   Fdut   (1.0/2.0)  			   // High time to low time

parameter CLKper = ((1.0 / (Freq * 1e6)) * 1E9);
parameter CLKhi = `Fdut * CLKper;
parameter CLKlo = CLKper - CLKhi;

// Registers for driving outputs

reg			DIO_Reg,temp_DIO_Reg;
reg			DO_Reg,temp_DO_Reg;
reg			WPn_Reg,temp_WPn_Reg;
reg			HOLDn_Reg,temp_HOLDn_Reg;

reg [63:0]	unique_id;
reg [23:0]	status;
reg [7:0]		null_reg;
reg [7:0] 	test_buf [(PAGESIZE*64)-1:0];
reg [15:0]	test_reg;
reg	reading_reg;
wire reading = reading_reg;

reg    qpi_mode;
reg 			host_timing_error;		// Host timing error signal

integer		x;


specify

// Host input timing checks

specparam	Thsu = 1;			// Host Data input setup time 5ns
specparam	Thhl = 5;			// Host Data input hold time 5ns
$setup(DO, posedge CLK, Thsu, host_timing_error);
$hold(posedge CLK &&& reading, DO, Thhl, host_timing_error);
endspecify


assign CLK = CLK_Reg;
assign CSn = CSn_Reg;
assign DIO = DIO_Reg;
assign DO = DO_Reg;
assign WPn = WPn_Reg;
assign HOLDn = HOLDn_Reg;


initial
begin

// Initialize all registers
	DIO_Reg = 1'bz;
	DO_Reg = 1'bz;
	WPn_Reg = 1'b1;
	HOLDn_Reg = 1'b1;
// The following temp variables need to be setup the same as the previous initialization. Change 1....Change both...
// When the model starts, CSn below is set to 1 from the x state.  This sets off the always @ (posedge CSn) statement which undoes any initialization
// done on the previous lines.  In essence, the real initialization for these variables comes from the temp variables below and not the statements above.
// Refer to the always @ (posedge/negedge CSn) for more info.
	temp_DIO_Reg = 1'bz;
	temp_DO_Reg = 1'bz;
	temp_WPn_Reg = 1'b1;
	temp_HOLDn_Reg = 1'b1;


	CSn_Reg = 1'b1;
	CLK_Reg = 1'b1;
	null_reg = 0;
	qpi_mode = 0;

	#200



	$display("Read Manufacturer's ID");
	spi_rd_id(0,null_reg);
	spi_rd_id(1,null_reg);

	$display("Read Manufacturer's ID Dual");
	spi_rd_id_dual(0,null_reg);
	spi_rd_id_dual(1,null_reg);

	$display("Read Manufacturer's ID Quad");
	spi_rd_id_quad(0,null_reg);
	spi_rd_id_quad(1,null_reg);
	$display("Should fail with 'zz'.");

  $display("Test read status register by Setting WEL");
	spi_sr(status);
	spi_sr2(status);

  $display("QE=1 is the power up default");

	// $stop;

	spi_we;
	spi_sr(status);
	spi_wd;
	spi_sr(status);
	WPn_Reg = 0;
	$display("Write Enable while WPn = 0");
	spi_we;
	spi_sr(status);

	WPn_Reg = 1;

// QPI Mode

	spi_we;
	status[`QE] = 1;
	spi_wsr(status);

	// Test whether chip ignores reset during status register write.
	#10000
	spi_enable_reset;
	spi_chip_reset;
	spi_wait_busy(1000000);
   $display("Should execute wait busy loop until end. Chip ignores reset.");


	// Now that quad mode is set, tri-state the WPn and HOLDn pins.
	WPn_Reg = 1'bz;
	HOLDn_Reg = 1'bz;

 	$display("Read Manufacturer's ID Quad");
	spi_rd_id_quad(0,null_reg);
	spi_rd_id_quad(1,null_reg);
	$display("Should succeed.");



	$display("Enable QPI Mode.");
	spi_enable_QPI();

  spi_sr(status);



	spi_we;
	status[`QE] = 1;
	spi_wsr(status);
 	spi_wait_busy(1000000);



  $display("Read with Quad Output - QPI");
	spi_rs_fast_qpi(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE, PAGESIZE);
	$display("Should be all FF");



	uniq_test_buf;
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);

   $display("Read Sector Fast - QPI");
	spi_rs_fast_qpi(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE, PAGESIZE);



   spi_set_qpi_param(0);         // Set wrap bits

   $display("Read Sector with Wrap QPI");
	spi_rs_quad_wrap_qpi(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE, PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 repeated.");

	spi_rs_quad_wrap_qpi(8'h0b, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 08 09 0a repeated.");

   spi_set_qpi_param(8'h01);

	spi_rs_quad_wrap_qpi(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f repeated.");

	spi_rs_quad_wrap_qpi(8'h0b,PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 00 01 02 03 04 05 06 08 09 0a repeated.");

   spi_set_qpi_param(8'h02);

	spi_rs_quad_wrap_qpi(0,PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f");
	$display("Should see 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f repeated.");

	spi_rs_quad_wrap_qpi(8'h0b,PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a");
	$display("Should see 1b 1c 1d 1e 1f 00 01 02 03 04 05 06 07 08 09 0a repeated.");

   spi_set_qpi_param(8'h03);

	spi_rs_quad_wrap_qpi(8'h0,PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f");
	$display("Should see 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f");
	$display("Should see 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f");
	$display("Should see 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f repeated.");

	spi_rs_quad_wrap_qpi(8'h0b,PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a");
	$display("Should see 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a");
	$display("Should see 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a");
	$display("Should see 3b 3c 3d 3e 3f 00 01 02 03 04 05 06 07 08 09 0a repeated.");

   spi_set_qpi_param(0);



	$display("Disable QPI Mode.");
	spi_disable_QPI();

	spi_sr(status);

  $display("Read SFDP Parameters");
	spi_r_sfdp(0,PAGESIZE,0);
	display_test_buf(0,PAGESIZE);

	 uniq_test_buf;
	 spi_we;
  	spi_ws(32'h01ffff00,PAGESIZE,0);
   spi_wait_busy(1000000);


  spi_we;
	status[`QE] = 1;
	spi_wsr(status);
	spi_wait_busy(1000000);

	// Now that quad mode is set, tri-state the WPn and HOLDn pins.
	WPn_Reg = 1'bz;
	HOLDn_Reg = 1'bz;


	$display("Enable QPI Mode.");
	spi_enable_QPI();

  spi_sr(status);

  $display("Read quad with 3 byte address - QPI.");
  pattern_test_buf(0,PAGESIZE,32'hff00ff00);
  spi_rs_fast_qpi(32'h01ffff00,PAGESIZE,0);
	display_test_buf(0,PAGESIZE);

  $display("Disable QPI Mode.");
	spi_disable_QPI();


  spi_we;
	status[`QE] = 0;
	spi_wsr(status);
	spi_wait_busy(1000000);

	WPn_Reg = 1'b1;
	HOLDn_Reg = 1'b1;

	$display("Write status register SRP=1 and BP0=1, WPn = 1");
	spi_we;
	spi_sr(status);
	status[`BP0] = 1;
	status[`SRP] = 1;
	spi_wsr(status);
	spi_wait_busy(1000000);

	$display("Write status register SRP=0, WPn = 0");

	WPn_Reg = 0;
	status[`SRP] = 0;
	spi_we;
	spi_wsr(status);
	spi_wait_busy(1000000);
	$display("Should Fail.\n");

	$display("Write status register BP0=0, WPn=1");

	WPn_Reg = 1;
	spi_we;
	spi_sr(status);
	status[`BP0] = 0;
	status[`SRP] = 0;
	spi_wsr(status);
	spi_wait_busy(1000000);

// Test Security Register


   spi_read_security_page(1,PAGESIZE,0);
  	display_test_buf(0,PAGESIZE);

	 uniq_test_buf;
	 spi_we;
  	spi_write_security_page(1,PAGESIZE,0);
   spi_wait_busy(1000000);

   spi_we;
  	spi_write_security_page(2,PAGESIZE,0);
   spi_wait_busy(1000000);

   spi_read_security_page(1,PAGESIZE,0);
  	display_test_buf(0,PAGESIZE);

   spi_read_security_page(2,PAGESIZE,0);
  	display_test_buf(0,PAGESIZE);

   spi_we;
   spi_erase_security_page(1);
   spi_wait_busy(1000000);

   spi_read_security_page(1,PAGESIZE,0);
  	display_test_buf(0,PAGESIZE);


	spi_we;
	spi_sr(status);
   status[`LB1] = 1;
	spi_wsr(status);
	spi_wait_busy(1000000);

	spi_sr2(status);

	spi_we;
	spi_write_security_page(1,PAGESIZE,0);
	spi_wait_busy(1000000);

	spi_we;
	spi_sr(status);
  status[`LB1] = 0;
	spi_wsr(status);
	spi_wait_busy(1000000);

	spi_sr2(status);

  spi_sr3(status);



// Test for erase bulk
	$display("Erase Bulk, then reset");
	spi_we;
	spi_eb;

	#20000;
	spi_enable_reset;
	spi_chip_reset;
	spi_wait_busy(200000000);
	$display("Loop should drop out within 1 busy loop iteration.");

	$display("Erase Bulk");
	spi_we;
	spi_eb;

	spi_wait_busy(200000000);


// Test HOLDn pin
  $display("Test HOLDn");
	read_with_holdn(0,PAGESIZE,0);
	display_test_buf(0,PAGESIZE);
	spi_sr(status);
	$display("Output should be all FF. If test failed, output will be a copy of the status register.\n");



// Test for write protected write
	$display("Write Page while WEL=0");
	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should never report busy.");

	// Test for write protected write WPn = 0
	$display("Write Page while WPn=0");
	WPn_Reg = 0;
	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should never report busy.");
   WPn_Reg = 1;

// Test for normal write
	$display("Write Page WEL=1");
	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	display_test_buf(0,PAGESIZE);
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	spi_rs(0,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

// Test for read and read with offset
	$display("Read Data from offset 0,1,2");

	spi_we;
	spi_es(0);
	spi_wait_busy(1000000);

	uniq_test_buf;
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	spi_rs(0,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);
	spi_rs(1,PAGESIZE,PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	spi_rs(2,PAGESIZE,PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

// Power Down
	$display("Power Down Chip, execute read status");
	spi_pd;
	spi_sr(status);

	$display("Wait 3 seconds, read status");
	#1000000000
	#1000000000
	#1000000000
	spi_sr(status);

	$display("Read Signature, Release from Power Down, Read Status");
	spi_rsig(status);
	spi_sr(status);

	$display("Wait 3 seconds, read status");
	#1000000000
	#1000000000
	#1000000000
	spi_sr(status);


// Test for erase sector with Suspend / Resume
   $display("Erase Sector 0, with Suspend / Resume");
   test_erase_suspend(0);

   $display("Program Sector 0, with Suspend / Resume");
   test_program_suspend(0);

// Test for erase sector
	$display("Erase Sector 0, wait busy, Read Page 0 and status");
	spi_we;
	spi_es(0);
	spi_wait_busy(20000000);
	spi_rs(0,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

// Test write protect
	$display("\nSet WPS bit for write protect modes.");
	spi_we;
	spi_sr(status);
	status[`WPS] = 1;
	spi_wsr3(status[23:16]);
	spi_wait_busy(1000000);
	spi_sr3(status);
	uniq_test_buf;

	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should fail\n");

  spi_global_unlock();

	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should succeed\n");


  // Test write protect
	$display("\nReset WPS bit for write SEC,TB,BPx protect modes.");
	spi_we;
	spi_sr(status);
	status[`WPS] = 0;
	spi_wsr3(status[23:16]);
	spi_wait_busy(1000000);
	spi_sr3(status);
	uniq_test_buf;


// Test write protect
	$display("\nWrite to page with SEC=0 TB=0 BP2=0 BP1=0 BP0=1");
	spi_we;
	spi_sr(status);
	status[`SEC] = 0;
	status[`TB] = 0;
	status[`BP2] = 0;
	status[`BP1] = 0;
	status[`BP0] = 1;
	spi_wsr(status);
	spi_wait_busy(1000000);
	uniq_test_buf;

	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should succeed\n");

	spi_we;
	spi_ws(NUM_PAGES/2 * PAGESIZE, PAGESIZE, 0);
	spi_wait_busy(1000000);
	$display("Should succeed\n");

	spi_we;
	spi_ws(NUM_PAGES*63/64 * PAGESIZE, PAGESIZE, 0);
	spi_wait_busy(1000000);
	$display("Should fail\n\n");



// Read 64-bit unique ID

	spi_runiqid(unique_id);


// Test Dual Output Function

	$display("Read with Dual output");
	uniq_test_buf;
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	spi_rs(0,PAGESIZE,PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	spi_sr(status);

	spi_rs_dual(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);


	spi_rs_dualio(0, PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

// Now do test for next sector I/O without command.

	spi_rs_dualio(0,PAGESIZE, 8'hA0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

	spi_rs_dualio(0,PAGESIZE, 8'h0, 1, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);


// Test Quad Output Function
// Enable QE bit in the volatile SR
	spi_we_vsr;
	status[`QE] = 1;
	spi_wsr(status);
	spi_wait_busy(1000000);


	$display("Read ID with Quad Output");
	spi_rd_id_quad(0,null_reg);
	spi_rd_id_quad(1,null_reg);

  $display("Read with Quad Output");
	spi_rs_quad(0, PAGESIZE, PAGESIZE);
	display_test_buf(PAGESIZE, PAGESIZE);

	$display("Test Burst Wrap Feature");

	spi_set_wrap(0);


	spi_rs_quadio(8'h0,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 repeated.");

	spi_rs_quadio(8'h0b,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 08 09 0a repeated.");

   spi_set_wrap(8'h20);

	spi_rs_quadio(8'h0,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f repeated.");

	spi_rs_quadio(8'h0b,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 00 01 02 03 04 05 06 08 09 0a repeated.");

  spi_set_wrap(8'h40);

	spi_rs_quadio(8'h0,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f");
	$display("Should see 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f repeated.");

	spi_rs_quadio(8'h0b,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a");
	$display("Should see 1b 1c 1d 1e 1f 00 01 02 03 04 05 06 07 08 09 0a repeated.");

  spi_set_wrap(8'h60);

	spi_rs_quadio(8'h0,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f");
	$display("Should see 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f");
	$display("Should see 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f");
	$display("Should see 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f repeated.");

	spi_rs_quadio(8'h0b,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);
	$display("Should see 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a");
	$display("Should see 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a");
	$display("Should see 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a");
	$display("Should see 3b 3c 3d 3e 3f 00 01 02 03 04 05 06 07 08 09 0a repeated.");

  spi_set_wrap(8'h10);

	spi_rs_quadio(0,PAGESIZE, 8'h0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

// Now do test for next sector I/O without command.

	spi_rs_quadio(0,PAGESIZE, 8'hA0, 0, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

	spi_rs_quadio(0,PAGESIZE, 8'h0, 1, PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

// Now test for Quad program page
	spi_we;
	spi_es(0);
	spi_wait_busy(1000000);


	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	spi_we;
	spi_ws_quad(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	spi_rs_quad(0,PAGESIZE,PAGESIZE);
	display_test_buf(PAGESIZE,PAGESIZE);

  $stop;
end

//
// When CS goes active, store state of output registers in test bench.
// This allows the test bench to provide a consistent environment for
// Each command that is written.  It also allows for the definition of the
// pins to change while CSn is held high.

always @(negedge CSn)				// When CSn goes low, device becomes active
begin
	temp_DIO_Reg = DIO_Reg;
	temp_DO_Reg = DO_Reg;
	temp_WPn_Reg = WPn_Reg;
	temp_HOLDn_Reg = HOLDn_Reg;
end

always @(posedge CSn)				// When CSn goes high, device becomes inactive
begin
	DIO_Reg = temp_DIO_Reg;
	DO_Reg = temp_DO_Reg;
	WPn_Reg = temp_WPn_Reg;
	HOLDn_Reg = temp_HOLDn_Reg;
end


/*****************************************************************************
Test
******************************************************************************/

/******************************************************************************
 The following task sends the Enable QPI command
******************************************************************************/

task spi_enable_QPI;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_ENABLE_QPI);
	$display("QPI Enabled.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
	qpi_mode = 1;
end
endtask

/******************************************************************************
 The following task sends the Enable QPI command
******************************************************************************/

task spi_disable_QPI;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_DISABLE_QPI);
	$display("QPI Disbled.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
	qpi_mode = 0;
end
endtask



/******************************************************************************
 The following task waits for the dut to become not busy via status polling
******************************************************************************/

task spi_wait_busy;
input [31:0] delay_time;
reg [7:0] status;
begin
	$display("Ready/Busy Polling with %.2fms delaytime between status polls",delay_time/1e6);
	spi_sr(status);
	while(status & `STATUS_WIP)
	begin
		#delay_time;
		spi_sr(status);
	end
end
endtask

/******************************************************************************
 The following task sends the Deep Power Down command
******************************************************************************/

task spi_pd;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_DEEP_POWERDOWN);
	$display("Deep Powerdown.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Read Signature/Release from Deep Sleep
******************************************************************************/

task spi_rsig;
output [7:0] signature;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_READ_SIGNATURE);
	output_dut_byte(null_reg);
	output_dut_byte(null_reg);
	output_dut_byte(null_reg);
	input_dut_byte(signature);

	$display("Read Signature/Release Deep Powerdown.(%h)",signature);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Read Unique ID
******************************************************************************/

task spi_runiqid;
output [63:0] id;
begin
	CSn_Reg = 1'b0;
     #Tcss;
	output_dut_byte(`CMD_READ_UNIQUE_ID);
	output_dut_byte(null_reg);
	output_dut_byte(null_reg);
	output_dut_byte(null_reg);
	output_dut_byte(null_reg);
	input_dut_byte(id[63:56]);
	input_dut_byte(id[55:48]);
	input_dut_byte(id[47:40]);
	input_dut_byte(id[39:32]);
	input_dut_byte(id[31:24]);
	input_dut_byte(id[23:16]);
	input_dut_byte(id[15:8]);
	input_dut_byte(id[7:0]);

	$display("Read 64 bit unique ID. (%h).",id);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Read Status command
******************************************************************************/

task spi_sr;
output [7:0] status;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_READ_STATUS);
	input_dut_byte(status[7:0]);

	$display("Read Status Register Low Byte ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Read Status Register 2 command
******************************************************************************/

task spi_sr2;
output [7:0] status;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_READ_STATUS2);
	input_dut_byte(status[7:0]);

	$display("Read Status Register 2 ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Read Status Register 3 command
******************************************************************************/

task spi_sr3;
output [7:0] status;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_READ_STATUS3);
	input_dut_byte(status[7:0]);

	$display("Read Status Register 3 ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Write Status command
******************************************************************************/

task spi_wsr;
input [15:0] status;
begin
	CSn_Reg = 1'b0;
   	#Tcss;
	output_dut_byte(`CMD_WRITE_STATUS);
	output_dut_byte(status[7:0]);
	output_dut_byte(status[15:8]);

	$display("Write Status Register ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Status 2 command
******************************************************************************/

task spi_wsr2;
input [7:0] status;
begin
	CSn_Reg = 1'b0;
   	#Tcss;
	output_dut_byte(`CMD_WRITE_STATUS2);
	output_dut_byte(status[7:0]);

	$display("Write Status Register 2 ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Status 3 command
******************************************************************************/

task spi_wsr3;
input [7:0] status;
begin
	CSn_Reg = 1'b0;
   	#Tcss;
	output_dut_byte(`CMD_WRITE_STATUS3);
	output_dut_byte(status[7:0]);

	$display("Write Status Register 3 ==> %h.",status);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Security Register command
******************************************************************************/

task spi_write_security_page;
input [7:0] page;
input [15:0] num;
input [15:0] test_buf_offset;

integer address;

begin
	CSn_Reg = 1'b0;
   	#Tcss;
	output_dut_byte(`CMD_SREG_PROGRAM);
  address = page[1:0] << 12;


	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	for(x = 0; x < num; x=x+1)
	begin
		output_dut_byte(test_buf[x+test_buf_offset]);
   end
	$display("Write to Security Page. (Page ID = %h)",page);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Read Page command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_read_security_page;
input [7:0] page;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;
integer address;

begin
	CSn_Reg = 1'b0;
   #Tcss;

   address = page[1:0] << 12;

	output_dut_byte(`CMD_SREG_READ);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	input_dut_byte(temp);            // Null

	begin
		for(x = 0; x < num; x=x+1)
		begin
			input_dut_byte(temp);
			test_buf[x+test_buf_off]=temp;
	   end
	end
	$display("Read Security Page. (Page = %h, Num = %h)",page,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Erase Security Sector command
******************************************************************************/

task spi_erase_security_page;
input [7:0] page;
integer address;

begin
	CSn_Reg = 1'b0;
     #Tcss;

   address = page[1:0] << 12;
	output_dut_byte(`CMD_SREG_ERASE);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	$display("Erase Security Page. (Page = %h)",page);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Disable command
******************************************************************************/

task spi_wd;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_WRITE_DISABLE);
	$display("Write Disable.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Enable command
******************************************************************************/

task spi_we;
begin
	CSn_Reg = 1'b0;
	#Tcss;
	output_dut_byte(`CMD_WRITE_ENABLE);
	$display("Write Enable.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Write Enable Volatile Status Register command
******************************************************************************/

task spi_we_vsr;
begin
	CSn_Reg = 1'b0;
	#Tcss;
	output_dut_byte(`CMD_WRITE_ENABLE_VSR);
	$display("Write Enable VSR.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Write to Page command
 This command writes the from offset for num bytes from the test buffer.
******************************************************************************/

task spi_ws;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_offset;
integer x,temp;

begin
  CSn_Reg = 1'b0;
  #Tcss;
	output_dut_byte(`CMD_PAGE_PROGRAM);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	for(x = 0; x < num; x=x+1)
	begin
		output_dut_byte(test_buf[x+test_buf_offset]);
   end
	$display("Write to Page. (Byte Address = %h, Num = %h)",address, num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Write to Page Quad command
 This command writes the from offset for num bytes from the test buffer.
******************************************************************************/

task spi_ws_quad;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_offset;
integer x,temp;

begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_PAGE_PROGRAM_QUAD);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	for(x = 0; x < num; x=x+1)
	begin
		output_dut_byte_quad(test_buf[x+test_buf_offset]);
   end
	$display("Write to Page Quad. (Byte Address = %h, Num = %h)",address, num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Erase Sector command
******************************************************************************/

task spi_es;
input [23:0] address;

begin
	CSn_Reg = 1'b0;
     #Tcss;
	output_dut_byte(`CMD_SECTOR_ERASE);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	$display("Erase Sector. (Byte Address = %h)",address);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Erase Bulk command
******************************************************************************/

task spi_eb;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_BULK_ERASE);
	$display("Bulk Erase.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Erase 64KB Block command
******************************************************************************/

task spi_eb1;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_BLOCK_ERASE);
	$display("64KB Block Erase.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Erase 32KB Block command
******************************************************************************/

task spi_eb2;
begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_HALF_BLOCK_ERASE);
	$display("32KB Block Erase.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the Read Page command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_DATA);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);

	begin
		for(x = 0; x < num; x=x+1)
		begin
			input_dut_byte(temp);
			test_buf[x+test_buf_off]=temp;
	   end
	end
	$display("Read Page. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask




/******************************************************************************
 The following task sends the Read Page Fast Output command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_fast;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
    #Tcss;
	output_dut_byte(`CMD_READ_DATA_FAST);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte(temp);
		test_buf[x+test_buf_off]=temp;
     end

	$display("Read Page Fast. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask



/******************************************************************************
 The following task sends the Read Page Fast Output command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_fast_qpi;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
    #Tcss;
	output_dut_byte(`CMD_READ_DATA_FAST);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_quad(temp);
		test_buf[x+test_buf_off]=temp;
     end

	$display("Read Page Fast - QPI. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask



/******************************************************************************
 The following task sends the Read Manufacturers ID command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rd_id;
input [23:0] address;
output [7:0] id;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_ID);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);

   input_dut_byte(id);

	$display("Read Manufacturers ID. (Address = %h, ID = %h)",address,id);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Read Manufacturers ID dual command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rd_id_dual;
input [23:0] address;
output [7:0] id;


begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_ID_DUAL);
	output_dut_byte_dual(address[23:16]);
	output_dut_byte_dual(address[15:8]);
	output_dut_byte_dual(address[7:0]);
	output_dut_byte_dual(8'hF0);

   input_dut_byte_dual(id);

	$display("Read Manufacturers ID Dual. (Address = %h, ID = %h)",address,id);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Read Manufacturers ID quad command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rd_id_quad;
input [23:0] address;
output [7:0] id;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_ID_QUAD);
	output_dut_byte_quad(address[23:16]);
	output_dut_byte_quad(address[15:8]);
	output_dut_byte_quad(address[7:0]);
	output_dut_byte_quad(8'hF0);
   output_dut_byte_quad(8'h00);
   output_dut_byte_quad(8'h00);

   input_dut_byte_quad(id);

	$display("Read Manufacturers ID Quad. (Address = %h, ID = %h)",address,id);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask



/******************************************************************************
 The following task sends the Suspend command to the device
******************************************************************************/

task spi_suspend;

begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_SUSPEND);
	$display("Suspend.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Resume command to the device
******************************************************************************/

task spi_resume;

begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_RESUME);
	$display("Resume.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Read Page Dual Output command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_dual;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
     #Tcss;
	output_dut_byte(`CMD_READ_DATA_FAST_DUAL);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_dual(temp);
		test_buf[x+test_buf_off]=temp;
     end

	$display("Read Page Dual. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask


/******************************************************************************
 The following task sends the Read Page Dual I/O command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_dualio;
input [23:0] address;
input [15:0] num;
input [7:0] mode;
input no_cmd;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
     #Tcss;
	if(!no_cmd)
		output_dut_byte(`CMD_READ_DATA_FAST_DUAL_IO);
	output_dut_byte_dual(address[23:16]);
	output_dut_byte_dual(address[15:8]);
	output_dut_byte_dual(address[7:0]);
	output_dut_byte_dual(mode);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_dual(temp);
		test_buf[x+test_buf_off]=temp;
     end

	if(no_cmd)
		$display("Read Page Dual IO - No CMD. (Address = %h, Num = %h, Mode = %h)",address,num,mode);
	else
		$display("Read Page Dual IO. (Address = %h, Num = %h, Mode = %h)",address,num,mode);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask


/******************************************************************************
 The following task sends the Read Page Quad Output command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_quad;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
     #Tcss;
	output_dut_byte(`CMD_READ_DATA_FAST_QUAD);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_quad(temp);
		test_buf[x+test_buf_off]=temp;
     end

	$display("Read Page Quad. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Read Page Quad QPI Output command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_quad_wrap_qpi;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
    #Tcss;
	output_dut_byte(`CMD_READ_DATA_FAST_WRAP);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_quad(temp);
		test_buf[x+test_buf_off]=temp;
     end

	$display("Read Page Quad Wrap QPI. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask


/******************************************************************************
 The following task sends the Read Page Quad I/O command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_rs_quadio;
input [23:0] address;
input [15:0] num;
input [7:0] mode;
input no_cmd;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
     #Tcss;
	if(!no_cmd)
		output_dut_byte(`CMD_READ_DATA_FAST_QUAD_IO);
	output_dut_byte_quad(address[23:16]);
	output_dut_byte_quad(address[15:8]);
	output_dut_byte_quad(address[7:0]);
	output_dut_byte_quad(mode);

	input_dut_byte_quad(temp);
	input_dut_byte_quad(temp);

	for(x = 0; x < num; x=x+1)
	begin
		input_dut_byte_quad(temp);
		test_buf[x+test_buf_off]=temp;
     end

	if(no_cmd)
		$display("Read Page Quad IO - No CMD. (Address = %h, Num = %h, Mode = %h)",address,num,mode);
	else
		$display("Read Page Quad IO. (Address = %h, Num = %h, Mode = %h)",address,num,mode);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the set wrap command 77h
******************************************************************************/

task spi_set_wrap;
input [7:0] wrap;

begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_SET_BURST_WRAP);
	output_dut_byte_quad(8'h00);
	output_dut_byte_quad(8'h00);
	output_dut_byte_quad(8'h00);
	output_dut_byte_quad(wrap);

	$display("Set Burst Wrap. (Wrap Value = %h)",wrap);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask

/******************************************************************************
 The following task sends the set read param command C0h
******************************************************************************/

task spi_set_qpi_param;
input [7:0] param;

begin
	CSn_Reg = 1'b0;
   #Tcss;
	output_dut_byte(`CMD_SET_READ_PARAM);
	output_dut_byte(param);

	$display("Set QPI Read Param. (Param Value = %h)",param);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;
end
endtask




/******************************************************************************
 The following task prints each byte in rows of 16 bytes.
******************************************************************************/

task display_test_buf;
input [31:0] offset;
input [31:0] num;
integer col,temp;
begin
	temp = (offset % 16);
	for(col = 0; col < temp; col=col+1)
	begin
		if(col == 0)
			$write("%h - ",offset - temp);
		if(!(col % 8) && (col % 16))
			$write("- ");
		else
			$write("   ");
	end
	for(col = offset; col < num + offset; col=col+1)
	begin
		if(!(col % 8) && (col % 16))
			$write("- ");
		if(col % 16)
			$write("%h ",test_buf[col]);
		else
			$write("\n%h - %h ",col,test_buf[col]);
	end
	$write("\n");
end
endtask

/******************************************************************************
 The following task places patterns within test_buf
******************************************************************************/

task pattern_test_buf;
input [31:0] offset;
input [31:0] num;
input [31:0] pattern;
integer x;
begin
	for(x = offset; x < num + offset; x=x+4)
	begin
		test_buf[x] = pattern[31:24];
		test_buf[x+1] = pattern[23:16];
		test_buf[x+2] = pattern[15:8];
		test_buf[x+3] = pattern[7:0];
	end
	$display("Set offset %h of test_buf to pattern %h for %h bytes.",offset, pattern, num);
end
endtask

/******************************************************************************
 The following task places patterns within test_buf
******************************************************************************/

task uniq_test_buf;
integer x;
begin
	for(x = 0; x < PAGESIZE; x=x+1)
		test_buf[x] = x;

	$display("Set test_buf to index pattern.");
end
endtask

/******************************************************************************
 The following task outputs a byte to the dut.
******************************************************************************/

task output_dut_byte;
input [7:0] data;
integer x;
begin

   if(qpi_mode)
      output_dut_byte_quad(data);
   else
   begin
     for(x = 7; x >= 0; x=x-1)
     begin
      		reading_reg = 1'b0;
      		CLK_Reg = 1'b0;
      		fork
       			#Thov DIO_Reg = data[x];
       			#CLKlo CLK_Reg = 1'b1;
      		join
      		#CLKhi;
      	end
  	end
	#CLKhi;		//CVG
end
endtask

/******************************************************************************
 The following task outputs a byte to the dut using the dual bit bus,
******************************************************************************/

task output_dut_byte_dual;
input [7:0] data;
integer x;
begin

	for(x = 7; x >= 0; x=x-2)
		begin
		reading_reg = 1'b0;
		CLK_Reg = 1'b0;
		fork
			#Thov DIO_Reg = data[x-1];
			DO_Reg = data[x];
			#CLKlo CLK_Reg = 1'b1;
		join
		#CLKhi;
	end
	#CLKhi;		//CVG
end
endtask

/******************************************************************************
 The following task outputs a byte to the dut using the quad bit bus,
******************************************************************************/

task output_dut_byte_quad;
input [7:0] data;
integer x;
begin

	for(x = 7; x >= 0; x=x-4)
		begin
		reading_reg = 1'b0;
		CLK_Reg = 1'b0;
		fork
			#Thov
			DIO_Reg = data[x-3];
			DO_Reg = data[x-2];
			WPn_Reg = data[x-1];
			HOLDn_Reg = data[x];
			#CLKlo CLK_Reg = 1'b1;
		join
		#CLKhi;
	end
	#CLKhi;		//CVG
end
endtask

/******************************************************************************
 The following task inputs a byte from the dut.
******************************************************************************/

task input_dut_byte_quad;
output [7:0] data;
integer x;
begin

	// Set output register to High-Z when reading
	HOLDn_Reg = 1'bz;
	WPn_Reg = 1'bz;
	DIO_Reg = 1'bz;
	DO_Reg = 1'bz;

	for(x = 7; x >= 0; x=x-4)
	begin
		reading_reg = 1'b1;
		CLK_Reg = 1'b0;
		#CLKlo CLK_Reg = 1'b1;
		data[x-3] = DIO;
		data[x-2] = DO;
		data[x-1] = WPn;
		data[x] = HOLDn;
		#CLKhi;
	end
	#CLKhi;  //CVG
end
endtask


/******************************************************************************
 The following task inputs a byte from the dut.
******************************************************************************/

task input_dut_byte_dual;
output [7:0] data;
integer x;
begin

	// Set output register to High-Z when reading
	DIO_Reg = 1'bz;
	DO_Reg = 1'bz;

	for(x = 7; x >= 0; x=x-2)
	begin
		reading_reg = 1'b1;
		CLK_Reg = 1'b0;
		#CLKlo CLK_Reg = 1'b1;
		data[x-1] = DIO;
		data[x] = DO;
		#CLKhi;
	end
	#CLKhi;  //CVG
end
endtask

/******************************************************************************
 The following task inputs a byte from the dut.
******************************************************************************/

task input_dut_byte;
output [7:0] data;
integer x;
begin

   if(qpi_mode)
      input_dut_byte_quad(data);
   else
   begin
      	// Set output register to High-Z when reading
      	DO_Reg = 1'bz;

      	for(x = 7; x >= 0; x=x-1)
      	begin
      		 reading_reg = 1'b1;
      		 CLK_Reg = 1'b0;
      		 #CLKlo CLK_Reg = 1'b1;
      		 data[x] = DO;
      		 #CLKhi;
      	end
  	end
	#CLKhi;  //CVG
end
endtask

/******************************************************************************
 The following task tests the HOLDn function of the DUT.
******************************************************************************/

task read_with_holdn;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
   #Tcss;

   HOLDn_Reg = 1'b0;

   output_dut_byte(`CMD_READ_STATUS);

   HOLDn_Reg = 1'b1;

   output_dut_byte(`CMD_READ_DATA);
   output_dut_byte(address[23:16]);
   output_dut_byte(address[15:8]);
   output_dut_byte(address[7:0]);

   begin
		for(x = 0; x < num; x=x+1)
		begin
		   input_dut_byte(temp);
		   test_buf[x+test_buf_off]=temp;
	   end
	end


	$display("Read Page with HOLDn test. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task tests the erase suspend / resume function of the DUT.
******************************************************************************/

task test_erase_suspend;
input [23:0] address;


begin

   spi_we;
   spi_es(address);

   // Delay 50 ms and send
   #15000000

	spi_sr(status);
	spi_suspend;
   spi_wait_busy(1000);

	spi_rs(address,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should Fail");

   spi_resume;
	spi_wait_busy(1000000);

	spi_rs(address,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

	$display("Erase sector with Suspend / Resume (Address = %h)",address);
   $display("First sector dump should be pre erase data. Second sector dump should be erased data.");

end
endtask


/******************************************************************************
 The following task tests the program suspend / resume function of the DUT.
******************************************************************************/

task test_program_suspend;
input [23:0] address;


begin

   pattern_test_buf(0,PAGESIZE,32'h12345678);
   spi_we;
   spi_ws(0,PAGESIZE,0);

   // Delay 1ms and send
   #500000

	spi_sr(status);
	spi_suspend;
   spi_wait_busy(1000);

	spi_rs(address,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

	pattern_test_buf(0,PAGESIZE,32'hff00ff00);
	spi_we;
	spi_ws(0,PAGESIZE,0);
	spi_wait_busy(1000000);
	$display("Should Fail");

   spi_resume;
	spi_wait_busy(1000000);

	spi_rs(address,PAGESIZE,PAGESIZE);
	spi_sr(status);
	display_test_buf(PAGESIZE,PAGESIZE);

	$display("Program sector with Suspend / Resume (Address = %h)",address);
   $display("First sector dump should be partially written page. Second sector dump should be completely written page.");

end
endtask


/******************************************************************************
 The following task enables the reset command.
******************************************************************************/

task spi_enable_reset;

begin
	CSn_Reg = 1'b0;
   #Tcss;

   output_dut_byte(`CMD_ENABLE_RESET);

	$display("Enable Reset.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask



/******************************************************************************
 The following task reset's the chip
******************************************************************************/

task spi_chip_reset;

begin
	CSn_Reg = 1'b0;
   #Tcss;

   output_dut_byte(`CMD_CHIP_RESET);

	$display("Chip Reset.");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask


/******************************************************************************
 The following task sends the Read Page command
 This routine reads from the passed page and offset, and
 places the results in the test buffer.
******************************************************************************/

task spi_r_sfdp;
input [23:0] address;
input [15:0] num;
input [15:0] test_buf_off;
integer x,temp;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_SFDP);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	output_dut_byte(0);

	begin
		for(x = 0; x < num; x=x+1)
		begin
			input_dut_byte(temp);
			test_buf[x+test_buf_off]=temp;
	   end
	end
	$display("Read SFDP Page. (Address = %h, Num = %h)",address,num);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Individual Lock command
 Locks the page / block identified by address.
******************************************************************************/

task spi_individual_lock;
input [23:0] address;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_INDIVIDUAL_LOCK);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);

	$display("Lock Block - (Address = %h)",address);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Individual Unlock command
 Unlock the page / block identified by address.
******************************************************************************/

task spi_individual_unlock;
input [23:0] address;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_INDIVIDUAL_UNLOCK);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);

	$display("Lock Block - (Address = %h)",address);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask


/******************************************************************************
 The following task sends the Read Block Lock command
 Reads the Block Lock bit identified by address.
******************************************************************************/

task spi_read_block_lock;
input [23:0] address;
inout [7:0] lockbit;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_READ_BLOCK_LOCK);
	output_dut_byte(address[23:16]);
	output_dut_byte(address[15:8]);
	output_dut_byte(address[7:0]);
	input_dut_byte(lockbit);

	$display("Read Block Lock - (Address = %h, Lockbit = %h)",address,lockbit);
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Global Lock command
 Set's the lock bits for all pages / blocks.
******************************************************************************/

task spi_global_lock;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_GLOBAL_BLOCK_LOCK);

	$display("Global Lock");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

/******************************************************************************
 The following task sends the Global Unlock command
 Reset's the lock bits for all pages / blocks.
******************************************************************************/

task spi_global_unlock;

begin
	CSn_Reg = 1'b0;
   #Tcss;

	output_dut_byte(`CMD_GLOBAL_BLOCK_UNLOCK);

	$display("Global Unlock");
	#Tcsh CSn_Reg = 1'b1;
	#Tcs;

end
endtask

endmodule // test_W25Q32JV
