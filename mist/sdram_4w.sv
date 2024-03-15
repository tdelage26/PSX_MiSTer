//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019-2024 Gyorgy Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram_4w (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // two byte masks
	output reg        SDRAM_DQMH, // two byte masks
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock
	input             clk_1x,
	input             clk_2x,

	// 1st bank
	input             port1_req,
	output reg        port1_ack = 0,
	input             port1_we,
	input      [23:0] port1_a,
	input       [1:0] port1_ds,
	input      [15:0] port1_d,
	output reg [15:0] port1_q,


	// 2nd bank
	input             port2_req,
	output reg        port2_busy = 0,
	input             port2_we,
	input       [7:0] port2_burstcnt,
	input      [23:0] port2_a,
	input       [7:0] port2_ds,
	input      [63:0] port2_d,
	output reg [63:0] port2_q,
	output reg        port2_ack
);

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// 64ms/8192 rows = 7.8us
localparam RFRSH_CYCLES = 16'd78*MHZ/4'd10;

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 SDRAM state machine for 2 bank interleaved access
cmd issued  registered  DQ
 0 RAS0     cas1(rw)    data1[63:48] wr   data1[32:16] rd
 1          ras0                          data1[47:32] rd
 2 CAS0                                   data1[63:48] rd
 3 RAS1     cas0(rw)    data0        wr
 4          ras1
 5 CAS1                                   data0 rd
 6 CAS1(rw) cas1(rw)    data1[15: 0] wr
 7 CAS1(rw) cas1(rw)    data1[31:16] wr
 8 CAS1(rw) cas1(rw)    data1[47:32] wr   data1[15:0]  rd

 5-6-7-8 repeated for a second 4-word read cycle if circumstances (see burst_cont) allow it (R1-R4)
*/

localparam STATE_RAS0      = 4'd0;   // first state in cycle
localparam STATE_CAS0      = 4'd2;
localparam STATE_DS0       = 4'd2;
localparam STATE_READ0     = 4'd6;   // STATE_CAS0 + CAS_LATENCY + 2'd2;
localparam STATE_RAS1      = 4'd3;   // Second ACTIVE command after RAS0 + tRRD (15ns)
localparam STATE_CAS1      = 4'd5;   // CAS phase
localparam STATE_CAS1b     = 4'd6;   // CAS phase
localparam STATE_CAS1c     = 4'd7;   // CAS phase
localparam STATE_CAS1d     = 4'd8;   // CAS phase
localparam STATE_READ1     = 4'd0;
localparam STATE_READ1b    = 4'd1;
localparam STATE_READ1c    = 4'd2;
localparam STATE_READ1d    = 4'd3;
localparam STATE_DS1       = 4'd5;
localparam STATE_DS1b      = 4'd6;
localparam STATE_DS1c      = 4'd7;
localparam STATE_DS1d      = 4'd8;
localparam STATE_LAST      = 4'd8;

localparam STATE_R1        = 4'd9;
localparam STATE_R2        = 4'd10;
localparam STATE_R3        = 4'd11;
localparam STATE_R4        = 4'd12;

reg [3:0] t;

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if(!init_n) begin
		reset <= 5'h1f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0]  sd_cmd;   // current command sent to sd ram
reg [15:0] sd_din;
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg        port1_rq;
reg        port1_act;
reg        port2_act;
reg        port1_done;
reg        port2_done;
reg [23:0] port2_ad;
reg        port2_wr;
reg  [7:0] port2_bs;
reg        port2_start_flag, port2_start_flag_d;
reg        port2_run_flag;
reg        port2_clr_busy;
reg [47:0] port2_out;
reg [63:0] port2_in;


reg  [7:0] burstcnt = 0; // 1 burst = 64 bits
wire       burst_cont = burstcnt[2:0] != 3'b001 && (port2_ad[9:0] + 4'd8) != 0; // continue burst for max. 4x64bits read/write
reg        burst_cont_r;

reg        refresh;
reg [12:0] refresh_cnt;
wire       need_refresh = (refresh_cnt >= RFRSH_CYCLES);

always @(posedge clk) begin

	case (t)
	0: t <= 1;
	1: t <= 2;
	2: t <= 3;
	3: t <= 4;
	4: t <= 5;
	5: t <= 6;
	6: t <= 7;
	7: t <= 8;
	STATE_LAST: t <= STATE_RAS0;
	STATE_R1: t <= STATE_R2;
	STATE_R2: t <= STATE_R3;
	STATE_R3: t <= STATE_R4;
	STATE_R4: t <= STATE_RAS0;
	endcase
	
	burst_cont_r <= burst_cont;
	
	// permanently latch ram data to reduce delays
	sd_din <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle
	refresh_cnt <= refresh_cnt + 1'd1;

	if(init) begin
		port1_rq <= 0;
		port1_act <= 0;
		port2_act <= 0;
		port2_run_flag <= 0;
		port1_done <= 0;
		port2_done <= 0;
		refresh_cnt <= 0;
		refresh <= 0;

		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		port1_rq <= port1_rq | port1_req;

		// bank 0 (16 bit)
		if(t == STATE_RAS0) begin
			if (!refresh && (port1_rq | port1_req)) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= port1_a[22:10];
				SDRAM_BA <= 0;
				port1_act <= 1;
			end
			else if (!refresh && (!port2_act || port2_wr))
				t <= STATE_RAS1;
		end

		if(t == STATE_CAS0) begin
			if (port1_act) begin
				sd_cmd <= port1_we?CMD_WRITE:CMD_READ;
				if (port1_we) begin
					SDRAM_DQ <= port1_d[15:0];
					{ SDRAM_DQMH, SDRAM_DQML } <= ~port1_ds[1:0];
				end
				SDRAM_A <= { 4'b0010, port1_a[9:1] }; // auto precharge
				SDRAM_BA <= 0;
				if (port1_we) begin
					port1_done <= ~port1_done;
					port1_rq <= 0;
				end
			end
		end

		if(t == STATE_DS0) begin
			if (port1_act && !port1_we)
				{ SDRAM_DQMH, SDRAM_DQML } <= ~port1_ds[1:0];
		end
		if(t == STATE_READ0) begin
			if (port1_act && !port1_we) begin
				port1_q[15:0] <= sd_din;
				port1_done <= ~port1_done;
				port1_rq <= 0;
			end
			port1_act <= 0;
		end

		// bank 1 (64 bit)
		if(t == STATE_RAS1) begin
			port2_act <= 0;
			refresh <= 0;
			if (need_refresh && !port1_act) begin
				refresh_cnt <= refresh_cnt - RFRSH_CYCLES;
				sd_cmd <= CMD_AUTO_REFRESH;
				refresh <= 1;
			end else if (port2_run_flag) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= port2_ad[22:10];
				SDRAM_BA <= 1;
				port2_act <= 1;
			end else begin
				port2_start_flag_d <= port2_start_flag;
				if (port2_start_flag_d ^ port2_start_flag) begin
					port2_run_flag <= 1;
					port2_ad <= port2_a;
					port2_wr <= port2_we;
					burstcnt <= port2_burstcnt;
					port2_bs <= port2_ds;
					port2_in <= port2_d;
					sd_cmd <= CMD_ACTIVE;
					SDRAM_A <= port2_a[22:10];
					SDRAM_BA <= 1;
					port2_act <= 1;
					port2_clr_busy <= ~port2_clr_busy;
				end else if (!port1_act)
					t <= STATE_RAS0;
			end
		end

		if(t == STATE_CAS1 || t == STATE_R1) begin
			if (port2_act) begin
				sd_cmd <= port2_wr?CMD_WRITE:CMD_READ;
				SDRAM_A <= { 4'd0, port2_ad[9:1] };
				SDRAM_BA <= 1;
				if (port2_wr) begin
					SDRAM_DQ <= port2_in[15:0];
					{ SDRAM_DQMH, SDRAM_DQML } <= ~port2_bs[1:0];
				end
			end
		end
		if(t == STATE_CAS1b || t == STATE_R2) begin
			if (port2_act) begin
				sd_cmd <= port2_wr?CMD_WRITE:CMD_READ;
				SDRAM_A <= { 4'd0, port2_ad[9:1] + 2'd1 };
				SDRAM_BA <= 1;
				if (port2_wr) begin
					{ SDRAM_DQMH, SDRAM_DQML } <= ~port2_bs[3:2];
					SDRAM_DQ <= port2_in[31:16];
				end
			end
		end
		if(t == STATE_CAS1c || t == STATE_R3) begin
			if (port2_act) begin
				sd_cmd <= port2_wr?CMD_WRITE:CMD_READ;
				SDRAM_A <= { 4'd0, port2_ad[9:1] + 2'd2 };
				SDRAM_BA <= 1;
				if (port2_wr) begin
					{ SDRAM_DQMH, SDRAM_DQML } <= ~port2_bs[5:4];
					SDRAM_DQ <= port2_in[47:32];
				end
			end
		end
		if(t == STATE_CAS1d || t == STATE_R4) begin
			if (port2_act) begin
				sd_cmd <= port2_wr?CMD_WRITE:CMD_READ;
				SDRAM_A <= { 4'b0010, port2_ad[9:1] + 2'd3 }; // auto precharge
				SDRAM_A[10] <= !burst_cont_r;
				SDRAM_BA <= 1;
				if (port2_wr) begin
					{ SDRAM_DQMH, SDRAM_DQML } <= ~port2_bs[7:6];
					SDRAM_DQ <= port2_in[63:48];
				end
				port2_ad <= port2_ad + 4'd8;
				burstcnt <= burstcnt - 1'd1;
				if (burstcnt == 1)
					port2_run_flag <= 0;
				if (burst_cont_r) t <= STATE_R1;
			end
		end

		if(t == STATE_DS1 || t == STATE_DS1b || t == STATE_DS1c || t == STATE_DS1d ||
		   t == STATE_R1  || t == STATE_R2   || t == STATE_R3   || t == STATE_R4) begin
			if (port2_act && !port2_wr)
				{ SDRAM_DQMH, SDRAM_DQML } <= 0;
		end

		if(t == STATE_READ1 || t == STATE_R1 || t == STATE_READ1b || t == STATE_R2 || t == STATE_READ1c || t == STATE_R3) begin
			if (port2_act && !port2_wr) begin
				port2_out <= {sd_din, port2_out[47:16]};
			end
		end

		if(t == STATE_READ1d || t == STATE_R4) begin
			if (port2_act && !port2_wr) begin
				port2_q <= {sd_din, port2_out};
				port2_done <= ~port2_done;
			end
		end
	end
end

always @(posedge clk_1x) begin
	reg port1_done_old;
	port1_done_old <= port1_done;

	port1_ack <= 0;
	if (port1_done_old ^ port1_done) port1_ack <= 1;
end

reg port2_done_old;
reg port2_clr_busy_old;
reg port2_bsy = 0, port2_bsy_d = 0;
assign port2_busy = port2_bsy | (port2_req & ~port2_bsy_d);

always @(posedge clk_2x) begin

	port2_done_old <= port2_done;
	port2_clr_busy_old <= port2_clr_busy;
	port2_bsy_d <= port2_bsy;

	port2_ack <= 0;

	if (port2_done_old ^ port2_done) begin
		port2_ack <= 1;
	end

	else if (port2_req & ~port2_bsy_d) begin
		port2_bsy <= 1;
		if (!port2_bsy)
			port2_start_flag <= ~port2_start_flag;
	end

	if (port2_clr_busy_old ^ port2_clr_busy)
		port2_bsy <= 0;
end

endmodule
