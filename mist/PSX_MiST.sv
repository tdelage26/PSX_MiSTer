//============================================================================
//============================================================================
//  PSX top-level for MiST
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module PSX_MiST
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 0;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
/*
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif
*/
`include "build_id.v"

assign LED  = ~ioctl_download;

//           1111111111222222222233333333334444444444555555555566
// 01234567890123456789012345678901234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
parameter CONF_STR = {
	"PSX;;",
	"S1C,CUE,Mount CD;",
	"S2U,SAV,Mount Memcard1;",
	"S3U,SAV,Mount Memcard2;",
	"Tn,Save Memcards;",
	"F1,EXE;",
	"OUV,System Type,Auto,NTSC-U,NTSC-J,PAL;",
	`SEP

	"P1,Video & Audio;",
	"P1O12,Scanlines,Off,25%,50%,75%;",
	"P1O3,Blend,Off,On;",
	"P1O4,480i to 480p Hack,Off,On;",
	"P1O5,Fixed VBlank,Off,On;",
	"P1O67,Vertical Crop,Off,On(224/270),On(216/256);",
	"P1O8,Horizontal Crop,Off,On;",
	"P1O9,Sync 480i for HDMI,Off,On;",
	"P1OA,Dither 24 Bit for VGA,Off,On;",
	"P1OB,Render 24 Bit,Off,On;",
	"P1OC,Rotate,Off,On;",
	"P1ODE,Widescreen Hack,Off,3:2,5:3,16:9;",

	"P2,Controls;",
	"P2OG,Joystick Swap,Off,On;",
	"P2OHK,Pad1,Dualshock,Off,Digital,Analog,GunCon,NeGcon,Wheel-NegCon,Wheel-Analog,Mouse,Justifier,Analog Joystick,Pop'n;",
	"P2OLO,Pad2,Dualshock,Off,Digital,Analog,GunCon,NeGcon,Wheel-NegCon,Wheel-Analog,Mouse,Justifier,Analog Joystick,Pop'n;",
	"P2OP,Show Crosshair,Off,On;",
	"P2OQR,Multitap,Off,Port1: 4 x Digital,Port1: 4 x Analog;",

	"P3,Miscellaneous;",
	"P3OW,Fastboot,Off,On;",
	"P3OX,CD Lid,Closed,Open;",
	"P3",`SEP
	"P3OYZ,Turbo(Cheats Off),Off,Low(U),Medium(U),High(U);",
	"P3Oa,Pause when CD slow,On,Off(U);",
	"P3Ob,PAL 60Hz Hack,Off,On(U);",
	"P3Oc,CD Fast Seek,Off,On(U);",
	"P3Odf,CD Speed,Original,Forced 1X(U),Forced 2X(U),Hack 4X(U),Hack 6X(U),Hack 8X(U);",
	"P3Og,Limit Max CD Speed,Off,On(U);",
	"P3Oh,RAM(Homebrew),2 MByte,8 MByte(U);",
	"P3Oi,GPU Slowdown,Off,On(U);",
	"P3",`SEP
	"P3Oj,FPS Overlay,Off,On;",
	"P3Ok,Error Overlay,Off,On;",
	"P3Ol,CD Slow Overlay,Off,On;",
	"P3Om,CD Overlay,Read,Read+Seek;",
	`SEP
	"Oo,Pause,Off,On;",
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire  [1:0] st_region = status[31:30];

wire  [1:0] scanlines = status[2:1];
wire        blend = status[3];
wire        hack_480p = status[4];
wire        st_fixvb = status[5];
wire  [1:0] st_vcrop = status[7:6];
wire        st_hcrop = status[8];
wire        st_syncinterlace = status[9];
wire        st_dither24 = status[10];
wire        st_render24 = status[11];
wire        st_rotate = status[12];
wire  [1:0] st_widescreen = status[14:13];

wire        joyswap = status[16];
wire  [3:0] st_pad1 = status[20:17];
wire  [3:0] st_pad2 = status[24:21];
wire        st_showcrosshair = status[25];
wire  [1:0] st_multitap = status[27:26];

wire        st_fastboot = status[32];
wire        st_cdlid = status[33];
wire  [1:0] st_turbo = status[35:34];
wire        st_pauseoncdslow = status[36];
wire        st_pal60 = status[37];
wire        st_instantseek = status[38];
wire  [2:0] st_cdspeed = status[41:39];
wire        st_limitreadspeed = status[42];
wire        st_ram8 = status[43];
wire        st_drawslow = status[44];

wire        st_fpsoverlay = status[45];
wire        st_erroroverlay = status[46];
wire        st_cdslowoverlay = status[47];
wire        st_cdoverlay = status[48];

wire        bk_save = status[49];
wire        st_pause = status[50];

////////////////////   CLOCKS   ///////////////////

wire pll_locked;
wire clk_3x, clk_2x, clk_1x, clk_vid, clk_vid_2x;
assign SDRAM_CLK = clk_3x;
wire clk_sys = clk_1x;

pll pll
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(clk_3x),
	.c1(clk_2x),
	.c2(clk_1x),
	.locked(pll_locked)
);

pll_vid pll_vid
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(clk_vid),
	.c1(clk_vid_2x)
);

assign SDRAM2_CKE = 1;

wire pll2_locked, clk2_3x;

pll pll2
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(clk2_3x),
	.locked(pll2_locked)
);
assign SDRAM2_CLK = clk2_3x;

reg reset;
always @(posedge clk_sys) begin
	reset <= buttons[1] | status[0] | bios_download | exe_download | cdDownloadReset;
end

//////////////////   MiST I/O   ///////////////////
wire [31:0] joy_0;
wire [31:0] joy_1;
wire [31:0] joy_2;
wire [31:0] joy_3;
wire [31:0] joy_4;

wire [31:0] joystick_analog_0;
wire [31:0] joystick_analog_1;

wire  [1:0] buttons;
wire [63:0] status;
wire [63:0] RTC_time;
wire        ypbpr;
wire        scandoubler_disable;
wire        no_csync;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
wire        mouse_strobe;

wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

reg  [31:0] sd_lba;
reg   [3:0] sd_rd = 0;
reg   [3:0] sd_wr = 0;
wire  [3:0] sd_ack_x;
wire  [9:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire  [3:0] img_mounted;
wire [31:0] img_size;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

wire [24:0] mouse = { mouse_strobe_level, mouse_y[7:0], mouse_x[7:0], mouse_flags };
reg         mouse_strobe_level;
wire [10:0] conf_str_addr;
reg   [7:0] conf_str_char;

always @(posedge clk_sys) begin
	conf_str_char <= CONF_STR[(($size(CONF_STR)>>3) - conf_str_addr - 1)<<3 +:8];
	if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;
end

user_io #(.FEATURES(32'h8000 /* FEAT PSX */| (BIG_OSD << 13) | (HDMI << 14)), .SD_IMAGES(4), .SD_BLKSZ(1'b1)) user_io
(
	.clk_sys(clk_sys),
	.clk_sd(clk_sys),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_CLK(SPI_SCK),
	.SPI_MOSI(SPI_DI),
	.SPI_MISO(SPI_DO),

	.conf_addr(conf_str_addr),
	.conf_chr(conf_str_char),

	.status(status),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.buttons(buttons),
	.rtc(RTC_time),
	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_4(joy_4),

	.joystick_analog_0(joystick_analog_0),
	.joystick_analog_1(joystick_analog_1),

	.mouse_x(mouse_x),
	.mouse_y(mouse_y),
	.mouse_flags(mouse_flags),
	.mouse_strobe(mouse_strobe),

	.key_strobe(key_strobe),
	.key_code(key_code),
	.key_pressed(key_pressed),
	.key_extended(key_extended),

`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif

	.sd_conf(1'b0),
	.sd_sdhc(1'b1),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack_x(sd_ack_x),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),
	.sd_din_strobe(sd_buff_rd),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

reg   [8:0] sd_buff_addr16;
reg  [15:0] sd_buff_dout16;
wire        sd_buff_wr16;
reg         sd_buff_bs;

always @(posedge clk_sys) begin
	if (~|sd_ack_x) begin
		sd_buff_bs <= 0;
		sd_buff_addr16 <= 0;
	end

	sd_buff_wr16 <= 0;
	if (sd_buff_wr) begin
		sd_buff_bs <= ~sd_buff_bs;
		if (sd_buff_bs) begin
			sd_buff_dout16[15:8] <= sd_buff_dout;
			sd_buff_addr16 <= sd_buff_addr[9:1];
			sd_buff_wr16 <= 1;
		end else
			sd_buff_dout16[7:0] <= sd_buff_dout;
	end
	if (sd_buff_rd)
		sd_buff_addr16 <= sd_buff_addr[9:1];
end

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;

data_io #(.DOUT_16(1'b1), .USE_QSPI(QSPI)) data_io
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_DI(SPI_DI),
	.SPI_DO(SPI_DO),
	.SPI_SS2(SPI_SS2),
	.SPI_SS4(SPI_SS4),
`ifdef USE_QSPI
	.QSCK(QSCK),
	.QCSn(QCSn),
	.QDAT(QDAT),
`endif
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

//////////////////////////  ROM DETECT  /////////////////////////////////

reg bios_download, exe_download, cdinfo_download, code_download;
always @(posedge clk_1x) begin
	bios_download    <= ioctl_download & (ioctl_index[5:0] == 0);
	exe_download     <= ioctl_download & (ioctl_index == 1);
	cdinfo_download  <= ioctl_download & (ioctl_index == 251);
	code_download    <= ioctl_download & (ioctl_index == 255);
end

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (exe_download || img_mounted[1]) begin
		cart_loaded <= 1;
	end
end

localparam EXE_START = 16777216;
localparam BIOS_START = 8388608;

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

reg        hasCD = 0;

reg exe_download_1 = 0;
reg cdinfo_download_1 = 0;
reg loadExe = 0;

reg sd_mounted2 = 0;
reg sd_mounted3 = 0;

reg memcard1_load = 0;
reg memcard2_load = 0;
reg memcard_save = 0;

wire saving_memcard;

reg memcard1_inserted = 0;
reg memcard2_inserted = 0;
reg [25:0] memcard1_cnt = 0;
reg [25:0] memcard2_cnt = 0;

wire bk_autosave = 0;//~status[71];

reg old_save = 0; 
reg old_save_a = 0;

wire bk_save_a = 0;//OSD_STATUS & bk_autosave;

reg cdbios = 0;
reg  [1:0] region;
reg  [1:0] biosregion;
wire [1:0] region_out;
reg        isPal;
reg biosMod = 0;

reg [31:0] exe_initial_pc;  
reg [31:0] exe_initial_gp;  
reg [31:0] exe_load_address;
reg [31:0] exe_file_size;   
reg [31:0] exe_stackpointer;

wire resetFromCD;
reg  cdDownloadReset = 0;

always @(posedge clk_1x) begin
	ramdownload_wr <= 0;
	if(exe_download | bios_download | cdinfo_download) begin
      if (ioctl_wr) begin
         if(~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)         ramdownload_wraddr  <= {4'd1, 2'b00, ioctl_addr[20:0]};
            else if (exe_download)     ramdownload_wraddr  <= ioctl_addr[22:0] + EXE_START[26:0];                              
            else if (cdinfo_download)  ramdownload_wraddr  <= ioctl_addr[26:0];      
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            //ioctl_wait                <= 1;
            //if (cdinfo_download) ioctl_wait <= 0;
         end
      end
      //if(sdramCh3_done) ioctl_wait <= 0;
   end else begin 
      //ioctl_wait <= 0;
	end
   exe_download_1  <= exe_download;
   loadExe         <= exe_download_1 & ~exe_download;  

   if (exe_download & ramdownload_wr) begin
      if (ramdownload_wraddr[22:0] == 'h10) exe_initial_pc     <= ramdownload_wrdata;
      if (ramdownload_wraddr[22:0] == 'h14) exe_initial_gp     <= ramdownload_wrdata;
      if (ramdownload_wraddr[22:0] == 'h18) exe_load_address   <= ramdownload_wrdata;
      if (ramdownload_wraddr[22:0] == 'h1C) exe_file_size      <= ramdownload_wrdata;
      if (ramdownload_wraddr[22:0] == 'h30) exe_stackpointer   <= ramdownload_wrdata;
      if (ramdownload_wraddr[22:0] == 'h34) exe_stackpointer   <= exe_stackpointer + ramdownload_wrdata;
   end

   if (loadExe) biosMod <= 1'b1;
     
   if (img_mounted[1]) begin
      if (img_size > 0) begin
         hasCD     <= 1;
      end else begin
         hasCD     <= 0;
      end
   end
  
   case(st_region)
      0: begin
            case(region_out)
               0: begin region = 2'b00; isPal <= 0; end   // unknown => default to NTSC          
               1: begin region = 2'b01; isPal <= 0; end   // JP
               2: begin region = 2'b00; isPal <= 0; end   // US
               3: begin region = 2'b10; isPal <= 1; end   // EU
            endcase
         end
      1: begin region = 2'b00; isPal <= 0; end
      2: begin region = 2'b01; isPal <= 0; end
      3: begin region = 2'b10; isPal <= 1; end
	endcase
   
   if (bios_download && ioctl_index[7:6] == 2'b11) cdbios <= 1'b1;
   
   if (cdbios)
      biosregion <= 2'b11;
   else
      biosregion <= region;
   
   memcard1_load <= 0;
   memcard2_load <= 0;
   memcard_save <= 0;
   
   // memcard 1
   if (img_mounted[2]) begin
      memcard1_inserted <= 0;
      memcard1_cnt      <= 26'd0;
      if (img_size > 0) begin
         sd_mounted2       <= 1;
         memcard1_load     <= 1;
      end else begin
         sd_mounted2       <= 0;
      end
   end
   
   if (sd_mounted2) begin // delay memcard inserted for ~2 seconds on card change
      if (memcard1_cnt[25]) begin
         memcard1_inserted <= 1;
      end else begin
         memcard1_cnt <= memcard1_cnt + 1'd1;
      end
   end
   
   // memcard 2
   if (img_mounted[3]) begin
      memcard2_inserted <= 0;
      memcard2_cnt      <= 26'd0;
      if (img_size > 0) begin
         sd_mounted3   <= 1;
         memcard2_load <= 1;
      end else begin
         sd_mounted3 <= 0;
      end
   end
   
   if (sd_mounted3) begin
      if (memcard2_cnt[25]) begin
         memcard2_inserted <= 1;
      end else begin
         memcard2_cnt <= memcard2_cnt + 1'd1;
      end
   end

   old_save   <= bk_save;
   old_save_a <= bk_save_a;

   if ((~old_save & bk_save) | (~old_save_a & bk_save_a)) memcard_save <= 1;

   cdinfo_download_1 <= cdinfo_download;
	 cdDownloadReset <= 0;
   if (cdinfo_download_1 && ~cdinfo_download && resetFromCD) begin
      cdDownloadReset <= 1;
   end
end

////////////////////////////  PAD  ///////////////////////////////////

// 0000 -> DualShock
// 0001 -> off
// 0010 -> digital
// 0011 -> analog
// 0100 -> Namco GunCon lightgun
// 0101 -> Namco NeGcon
// 0110 -> Wheel Negcon
// 0111 -> Wheel Analog
// 1000 -> mouse
// 1001 -> Konami Justifier lightgun
// 1010 -> Analog Joystick
// 1100..1111 -> reserved

wire PadPortDS1      = (st_pad1 == 4'b0000);
wire PadPortEnable1  = (st_pad1 != 4'b0001);
wire PadPortDigital1 = (st_pad1 == 4'b0010) || (st_pad1 == 4'b1100);
wire PadPortAnalog1  = (st_pad1 == 4'b0011) || (st_pad1 == 4'b0111);
wire PadPortGunCon1  = (st_pad1 == 4'b0100);
wire PadPortNeGcon1  = (st_pad1 == 4'b0101) || (st_pad1 == 4'b0110);
wire PadPortWheel1   = (st_pad1 == 4'b0110) || (st_pad1 == 4'b0111);
wire PadPortMouse1   = (st_pad1 == 4'b1000);
wire PadPortJustif1  = (st_pad1 == 4'b1001);
wire PadPortStick1   = (st_pad1 == 4'b1010);
wire PadPortPopn1    = (st_pad1 == 4'b1100);
   
wire PadPortDS2      = (st_pad2 == 4'b0000);
wire PadPortEnable2  = (st_pad2 != 4'b0001) && ~multitap;
wire PadPortDigital2 = (st_pad2 == 4'b0010) || (st_pad2 == 4'b1100);
wire PadPortAnalog2  = (st_pad2 == 4'b0011) || (st_pad2 == 4'b0111);
wire PadPortGunCon2  = (st_pad2 == 4'b0100);
wire PadPortNeGcon2  = (st_pad2 == 4'b0101) || (st_pad2 == 4'b0110);
wire PadPortWheel2   = (st_pad2 == 4'b0110) || (st_pad2 == 4'b0111);
wire PadPortMouse2   = (st_pad2 == 4'b1000);
wire PadPortJustif2  = (st_pad2 == 4'b1001);
wire PadPortStick2   = (st_pad2 == 4'b1010);
wire PadPortPopn2    = (st_pad2 == 4'b1100);

wire [31:0] joystick_ana_0 = joyswap ? joystick_analog_1 : joystick_analog_0;
wire [31:0] joystick_ana_1 = joyswap ? joystick_analog_0 : joystick_analog_1;

reg paddleMode = 0;
reg paddleMin = 0;
reg paddleMax = 0;
wire [7:0] joy0_xmuxed = /*(paddleMode) ? (paddle_0 - 8'd128) :*/ joystick_ana_0[15:8];


// 00 -> multitap off
// 01 -> port1, 4 x digital
// 10 -> port1, 4 x analog
wire multitap        = (st_multitap != 2'b00);
wire multitapDigital = (st_multitap == 2'b01);
wire multitapAnalog  = (st_multitap == 2'b10);

////////////////////////////  SYSTEM  ///////////////////////////////////
wire [7:0] r,g,b;
wire hs, vs, hbl, vbl, video_ce;
wire [3:0] video_clkdiv;
wire [15:0] laudio, raudio;

wire [31:0] sd_lba1, sd_lba2, sd_lba3;
assign sd_lba = (sd_rd[3] | sd_wr[3]) ? sd_lba3 : (sd_rd[2] | sd_wr[2]) ? sd_lba2 : sd_lba1;

wire [15:0] sd_buff_din16, sd_buff_din2, sd_buff_din3;
assign sd_buff_din16 = sd_ack_x[3] ? sd_buff_din3 : sd_buff_din2;
assign sd_buff_din = sd_buff_addr[0] ? sd_buff_din16[15:8] : sd_buff_din16[7:0];

reg TURBO_MEM;
reg TURBO_COMP;
reg TURBO_CACHE;
reg TURBO_CACHE50;
reg paused;

always @(posedge clk_1x) begin
   paused <= st_pause;

   // 1 => low    -> only MEM
   // 2 => medium -> MEM + 50% cache
   // 3 => high   -> everything
   TURBO_MEM      <= |st_turbo;
   TURBO_COMP     <= st_turbo == 2'b11;
   TURBO_CACHE    <= st_turbo[1];
   TURBO_CACHE50  <= st_turbo == 2'b10;

end

psx_mister psx
(
   .clk1x(clk_1x),          
   .clk2x(clk_2x),
   .clk3x(clk_3x),
   .clkvid(clk_vid),
   .reset(reset),
   .isPaused(),
   // commands 
   .pause(paused),
   .hps_busy(1'b0),
   .loadExe(loadExe),
   .exe_initial_pc(exe_initial_pc),
   .exe_initial_gp(exe_initial_gp), 
   .exe_load_address(exe_load_address),
   .exe_file_size(exe_file_size),   
   .exe_stackpointer(exe_stackpointer),
   .fastboot(st_fastboot && hasCD),
   .ram8mb(st_ram8),
   .TURBO_MEM(TURBO_MEM),
   .TURBO_COMP(TURBO_COMP),
   .TURBO_CACHE(TURBO_CACHE),
   .TURBO_CACHE50(TURBO_CACHE50),
   .REPRODUCIBLEGPUTIMING(0),
   .INSTANTSEEK(st_instantseek),
   .FORCECDSPEED(st_cdspeed),
   .LIMITREADSPEED(st_limitreadspeed),
   .IGNORECDDMATIMING(1'b0),
   .ditherOff(1'b0),
   .interlaced480pHack(hack_480p),
   .showGunCrosshairs(st_showcrosshair),
   .fpscountOn(st_fpsoverlay),
   .cdslowOn(st_cdslowoverlay),
   .testSeek(st_cdoverlay),
   .pauseOnCDSlow(~st_pauseoncdslow),
   .errorOn(st_erroroverlay),
   .LBAOn(1'b0),
   .PATCHSERIAL(0), //.PATCHSERIAL(status[54]),
   .noTexture(1'b0),
   .textureFilter(status8281),
   .textureFilterStrength(status8786),
   .textureFilter2DOff(status83),
   .dither24(st_dither24),
   .render24(st_render24 && ~hack_480p),
   .drawSlow(st_drawslow),
   .syncVideoOut(1'b0),
   .syncInterlace(st_syncinterlace),
   .rotate180(st_rotate),
   .fixedVBlank(st_fixvb && ~hack_480p),
   .vCrop(hack_480p ? 2'b00 : st_vcrop),
   .hCrop(st_hcrop),
   .SPUon(1'b1),
   .SPUIRQTrigger(1'b0),
   .SPUSDRAM(1'b1),
   .REVERBOFF(0),
   .REPRODUCIBLESPUDMA(1'b0),
   .WIDESCREEN(st_widescreen),
   // RAM/BIOS interface      
   .biosregion(biosregion),
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead32(sdr_sdram_dout32),
   .ram_Adr(sdram_addr),
   .ram_cntDMA(sdram_cntDMA),
   .ram_be(sdram_be), 
   .ram_rnw(sdram_rnw),  
   .ram_ena(sdram_req), 
   .ram_dma(sdram_dma), 
   .ram_cache(sdram_cache), 
   .ram_done(sdram_ack),
   .ram_dmafifo_adr  (sdram_dmafifo_adr),  
   .ram_dmafifo_data (sdram_dmafifo_data), 
   .ram_dmafifo_empty(sdram_dmafifo_empty),
   .ram_dmafifo_read (sdram_dmafifo_read),
   .cache_wr(cache_wr),  
   .cache_data(cache_data),
   .cache_addr(cache_addr),
   .dma_wr(dma_wr),  
   .dma_reqprocessed(dma_reqprocessed),
   .dma_data(dma_data),
   // vram/ddr3
   .DDRAM_BUSY      (vram_BUSY),
   .DDRAM_BURSTCNT  (vram_BURSTCNT),
   .DDRAM_ADDR      (vram_ADDR[27:3]),
   .DDRAM_DOUT      (vram_DOUT),
   .DDRAM_DOUT_READY(vram_DOUT_READY),
   .DDRAM_RD        (vram_RD),
   .DDRAM_DIN       (vram_DIN),
   .DDRAM_BE        (vram_BE),
   .DDRAM_WE        (vram_WE),
   // cd
   .region          (region),
   .region_out      (region_out),
   .hasCD           (hasCD),
   .LIDopen         (st_cdlid),
   .fastCD          (0),
   .trackinfo_data  (ramdownload_wrdata),
   .trackinfo_addr  (ramdownload_wraddr[10:2]),
   .trackinfo_write (ramdownload_wr && cdinfo_download),
   .resetFromCD     (resetFromCD),
   .cd_hps_req      (sd_rd[1]),  
   .cd_hps_lba      (sd_lba1),  
   .cd_hps_ack      (sd_ack_x[1]),
   .cd_hps_write    (sd_buff_wr16),
   .cd_hps_data     (sd_buff_dout16), 
   // spuram
   .spuram_dataWrite(spuram_dataWrite),
   .spuram_Adr      (spuram_Adr      ),
   .spuram_be       (spuram_be       ),
   .spuram_rnw      (spuram_rnw      ),
   .spuram_ena      (spuram_ena      ),
   .spuram_dataRead (spuram_dataRead ),
   .spuram_done     (spuram_done     ),
   // memcard
   .memcard_changed (bk_pending),
   .saving_memcard  (saving_memcard),
   .memcard1_load   (memcard1_load),
   .memcard2_load   (memcard2_load),
   .memcard_save    (memcard_save),
   .memcard1_mounted   (sd_mounted2),
   .memcard1_available (memcard1_inserted),
   .memcard1_rd     (sd_rd[2]),
   .memcard1_wr     (sd_wr[2]),
   .memcard1_lba    (sd_lba2),
   .memcard1_ack    (sd_ack_x[2]),
   .memcard1_write  (sd_buff_wr16),
   .memcard1_addr   (sd_buff_addr16),
   .memcard1_dataIn (sd_buff_dout16),
   .memcard1_dataOut(sd_buff_din2),    
   .memcard2_mounted   (sd_mounted3),
   .memcard2_available (memcard2_inserted),   
   .memcard2_rd     (sd_rd[3]),
   .memcard2_wr     (sd_wr[3]),
   .memcard2_lba    (sd_lba3),
   .memcard2_ack    (sd_ack_x[3]),
   .memcard2_write  (sd_buff_wr16),
   .memcard2_addr   (sd_buff_addr16),
   .memcard2_dataIn (sd_buff_dout16),
   .memcard2_dataOut(sd_buff_din3), 
   // video
   .videoout_on     (1'b1),
   .isPal           (isPal),
   .pal60           (st_pal60),
   .hsync           (hs),
   .vsync           (vs),
   .hblank          (hbl),
   .vblank          (vbl),
   .DisplayWidth    (), 
   .DisplayHeight   (),
   .DisplayOffsetX  (),
   .DisplayOffsetY  (),
   .video_ce        (video_ce),
   .video_clkdiv    (video_clkdiv),
   .video_interlace (),
   .video_r         (r),
   .video_g         (g),
   .video_b         (b),
   .video_isPal     (),   
   .video_fbmode    (),   
   .video_fb24      (),   
   .video_hResMode  (),
   .video_frameindex(),
   //Keys
   .DSAltSwitchMode(status31),
   .PadPortEnable1 (PadPortEnable1),
   .PadPortDigital1(PadPortDigital1),
   .PadPortAnalog1 (PadPortAnalog1),
   .PadPortMouse1  (PadPortMouse1 ),
   .PadPortGunCon1 (PadPortGunCon1),
   .PadPortNeGcon1 (PadPortNeGcon1),
   .PadPortWheel1  (PadPortWheel1),
   .PadPortDS1     (PadPortDS1),
   .PadPortJustif1 (PadPortJustif1),
   .PadPortStick1  (PadPortStick1),
   .PadPortPopn1   (PadPortPopn1),
   .PadPortEnable2 (PadPortEnable2),
   .PadPortDigital2(PadPortDigital2),
   .PadPortAnalog2 (PadPortAnalog2),
   .PadPortMouse2  (PadPortMouse2 ),
   .PadPortGunCon2 (PadPortGunCon2),
   .PadPortNeGcon2 (PadPortNeGcon2),
   .PadPortWheel2  (PadPortWheel2),
   .PadPortDS2     (PadPortDS2),
   .PadPortJustif2 (PadPortJustif2),
   .PadPortStick2  (PadPortStick2),
   .PadPortPopn2   (PadPortPopn2),

   .KeyTriangle({m_fire4[0], m_fire3[0], m_fire2[0], m_fire1[0]}),
   .KeyCircle  ({m_fire4[1], m_fire3[1], m_fire2[1], m_fire1[1]}),
   .KeyCross   ({m_fire4[4], m_fire3[4], m_fire2[4], m_fire1[4]}),
   .KeySquare  ({m_fire4[5], m_fire3[5], m_fire2[5], m_fire1[5]}),
   .KeySelect  ({m_fire4[2], m_fire3[2], m_fire2[2], m_fire1[2]}),
   .KeyStart   ({m_fire4[3], m_fire3[3], m_fire2[3], m_fire1[3]}),
   .KeyRight   ({m_right4, m_right3, m_right2, m_right1}),
   .KeyLeft    ({m_left4, m_left3, m_left2, m_left1}),
   .KeyUp      ({m_up4, m_up3, m_up2, m_up1}),
   .KeyDown    ({m_down4, m_down3, m_down2, m_down1}),
   .KeyR1      ({m_fire4[7], m_fire3[7], m_fire2[7], m_fire1[7]}),
   .KeyR2      ({m_fire4[9], m_fire3[9], m_fire2[9], m_fire1[9]}),
   .KeyR3      ({m_fire4[11], m_fire3[11], m_fire2[11], m_fire1[11]}),
   .KeyL1      ({m_fire4[6], m_fire3[6], m_fire2[6], m_fire1[6]}),
   .KeyL2      ({m_fire4[8], m_fire3[8], m_fire2[8], m_fire1[8]}),
   .KeyL3      ({m_fire4[10], m_fire3[10], m_fire2[10], m_fire1[10]}),

//   .ToggleDS   (ToggleDS),
   .Analog1XP1(joy0_xmuxed),
   .Analog1YP1(joystick_ana_0[7:0]),
   .Analog2XP1(joystick_ana_0[31:24]),
   .Analog2YP1(joystick_ana_0[23:16]),
   .Analog1XP2(joystick_ana_1[15:8]),
   .Analog1YP2(joystick_ana_1[7:0]),
   .Analog2XP2(joystick_ana_1[31:24]),
   .Analog2YP2(joystick_ana_1[23:16]),
/*
   .Analog1XP3(joystick_analog_l2[7:0]),
   .Analog1YP3(joystick_analog_l2[15:8]),
   .Analog2XP3(joystick_analog_r2[7:0]),
   .Analog2YP3(joystick_analog_r2[15:8]),
   .Analog1XP4(joystick_analog_l3[7:0]),
   .Analog1YP4(joystick_analog_l3[15:8]),
   .Analog2XP4(joystick_analog_r3[7:0]),
   .Analog2YP4(joystick_analog_r3[15:8]),*/
   .RumbleDataP1(joystick1_rumble),
   .RumbleDataP2(joystick2_rumble),
   .RumbleDataP3(joystick3_rumble),
   .RumbleDataP4(joystick4_rumble),
   .padMode(),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
   .multitap(multitap),
   .multitapDigital(multitapDigital),
   .multitapAnalog(multitapAnalog),
   //snac
   .snacPort1(),
   .snacPort2(),
   .selectedPort1Snac(),
   .selectedPort2Snac(),
   .irq10Snac(),
   .transmitValueSnac(),
   .clk9Snac(),
   .receiveBufferSnac(),
   .beginTransferSnac(),
   .actionNextSnac(),
   .receiveValidSnac(),
   .ackSnac(1'b1),//using real ack not the 1 cycle ack
   .snacMC(1'b0),
	
   //sound       
	.sound_out_left(laudio),
	.sound_out_right(raudio),
   //savestates
   .increaseSSHeaderCount (!status36),
   .save_state            (ss_save),
   .load_state            (ss_load),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   .rewind_on             (0), //(status[27]),
   .rewind_active         (0), //(status[27] & joy[15]),
   //cheats
   .cheat_clear(gg_reset),
   .cheats_enabled(1'b0/*~status6 && ~TURBO_MEM && ~ioctl_download*/),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

   .Cheats_BusAddr(cheats_addr),
   .Cheats_BusRnW(cheats_rnw),
   .Cheats_BusByteEnable(cheats_be),
   .Cheats_BusWriteData(cheats_dout),
   .Cheats_Bus_ena(cheats_ena),
   .Cheats_BusReadData(cheats_din),
   .Cheats_BusDone(sdramCh3_done)
);

///////////////////////////// MEMORY ////////////////////////////////////
wire         vram_BUSY;
wire  [63:0] vram_DOUT;
wire         vram_DOUT_READY;
wire   [7:0] vram_BURSTCNT;
wire  [27:0] vram_ADDR;
wire  [63:0] vram_DIN;
wire   [7:0] vram_BE;
wire         vram_WE;
wire         vram_RD;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire  [31:0] sdr_sdram_dout32;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [24:0] sdram_addr;
wire   [1:0] sdram_cntDMA;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_dma;
wire         sdram_cache;
wire  [ 3:0] cache_wr;
wire  [31:0] cache_data;
wire  [ 7:0] cache_addr;
wire         dma_wr;
wire         dma_reqprocessed;
wire  [31:0] dma_data;

wire  [22:0] sdram_dmafifo_adr;  
wire  [31:0] sdram_dmafifo_data; 
wire         sdram_dmafifo_empty;
wire         sdram_dmafifo_read; 

wire [20:0] cheats_addr;
wire cheats_rnw;
wire [3:0] cheats_be;
wire [31:0] cheats_dout;
wire cheats_ena;
wire [31:0] cheats_din;
wire sdramCh3_done;

assign sdram_ack = sdram_readack | sdram_writeack;

sdram sdram
(
	.SDRAM_DQ   (SDRAM_DQ),
	.SDRAM_A    (SDRAM_A),
	.SDRAM_DQML (SDRAM_DQML),
	.SDRAM_DQMH (SDRAM_DQMH),
	.SDRAM_BA   (SDRAM_BA),
	.SDRAM_nCS  (SDRAM_nCS),
	.SDRAM_nWE  (SDRAM_nWE),
	.SDRAM_nRAS (SDRAM_nRAS),
	.SDRAM_nCAS (SDRAM_nCAS),
	.SDRAM_CKE  (SDRAM_CKE),
	.SDRAM_CLK  (),
   
	.SDRAM_EN(1'b1),
	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),
	
	.refreshForce(sdr_refresh),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(sdr_sdram_dout32),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(sdram_dma),
	.ch1_cntDMA(sdram_cntDMA),
	.ch1_cache(sdram_cache),
	.ch1_ready(sdram_readack),
	.cache_wr(cache_wr),  
	.cache_data(cache_data),
	.cache_addr(cache_addr),
	.dma_wr(dma_wr),  
	.dma_reqprocessed(dma_reqprocessed),  
	.dma_data(dma_data),

	.ch2_addr (sdram_addr),
	.ch2_din  (sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  (sdram_req & ~sdram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr ((exe_download | bios_download) ? ramdownload_wraddr : cheats_addr),
	.ch3_din  ((exe_download | bios_download) ? ramdownload_wrdata : cheats_dout),
	.ch3_dout (cheats_din),
	.ch3_req  ((exe_download | bios_download) ? ramdownload_wr     : cheats_ena),
	.ch3_rnw  (cheats_rnw),
	.ch3_be   ((exe_download | bios_download) ? 4'b1111            : cheats_be),
	.ch3_ready(sdramCh3_done),

	.dmafifo_adr  (sdram_dmafifo_adr),
	.dmafifo_data (sdram_dmafifo_data),
	.dmafifo_empty(sdram_dmafifo_empty),
	.dmafifo_read (sdram_dmafifo_read)
);

wire [15:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [15:0] spuram_dataRead;
wire        spuram_done;

sdram_4w #(133) sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
	.SDRAM_A    (SDRAM2_A),
	.SDRAM_DQML (SDRAM2_DQML),
	.SDRAM_DQMH (SDRAM2_DQMH),
	.SDRAM_BA   (SDRAM2_BA),
	.SDRAM_nCS  (SDRAM2_nCS),
	.SDRAM_nWE  (SDRAM2_nWE),
	.SDRAM_nRAS (SDRAM2_nRAS),
	.SDRAM_nCAS (SDRAM2_nCAS),

	.init_n     (pll2_locked),
	.clk        (clk_3x),
	.clk_1x     (clk_1x),
	.clk_2x     (clk_2x),

	.port1_req  (spuram_ena),
	.port1_ack  (spuram_done),
	.port1_a    (spuram_Adr),
	.port1_we   (~spuram_rnw),
	.port1_ds   (spuram_be),
	.port1_d    (spuram_dataWrite[15:0]),
	.port1_q    (spuram_dataRead[15:0]),

	.port2_req  (vram_RD | vram_WE),
	.port2_busy (vram_BUSY),
	.port2_we   (vram_WE),
	.port2_a    (vram_ADDR),
	.port2_ds   (vram_BE),
	.port2_d    (vram_DIN),
	.port2_q    (vram_DOUT),
	.port2_ack  (vram_DOUT_READY),
	.port2_burstcnt(vram_BURSTCNT)
);

/*
assign spuram_done     = sdram_readack2 | sdram_writeack2;

sdram sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
	.SDRAM_A    (SDRAM2_A),
	.SDRAM_DQML (SDRAM2_DQML),
	.SDRAM_DQMH (SDRAM2_DQMH),
	.SDRAM_BA   (SDRAM2_BA),
	.SDRAM_nCS  (SDRAM2_nCS),
	.SDRAM_nWE  (SDRAM2_nWE),
	.SDRAM_nRAS (SDRAM2_nRAS),
	.SDRAM_nCAS (SDRAM2_nCAS),
	.SDRAM_CKE  (SDRAM2_CKE),
	.SDRAM_CLK  (),
	.SDRAM_EN   (1'b1),

	.init(~pll2_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),

	.refreshForce(1'b0),
	.ram_idle(),

	.ch1_addr(spuram_Adr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(spuram_dataRead),
	.ch1_req(spuram_ena & spuram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(1'b0),
	.ch1_cntDMA(2'b00),
	.ch1_cache(1'b0),
	.ch1_ready(sdram_readack2),

	.ch2_addr (spuram_Adr),
	.ch2_din  (spuram_dataWrite),
	.ch2_dout (),
	.ch2_req  (spuram_ena & ~spuram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (spuram_be),
	.ch2_ready(sdram_writeack2),

	.ch3_addr(),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(),
	.ch3_rnw(),
	.ch3_ready(),
	.ch3_be(),

	.dmafifo_adr  (0),
	.dmafifo_data (0),
	.dmafifo_empty(1'b1),
	.dmafifo_read ()
);
*/
///////////////////////////// VIDEO /////////////////////////////////////

wire [2:0] ce_divider_vga = (video_clkdiv == 10) ? 3'd5 : (video_clkdiv - 1'd1);

mist_video #(.SD_HCNT_WIDTH(11), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video
(
	.clk_sys(clk_vid_2x),
	.scanlines(scanlines),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.rotate(2'b00),
	.blend(blend),
	.ce_divider(ce_divider_vga),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B)
);

////////////////////////////  HDMI  ///////////////////////////////////

`ifdef USE_HDMI
i2c_master #(33_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

wire [2:0] ce_divider_hdmi = (video_clkdiv[0] ? video_clkdiv[2:0] : video_clkdiv[3:1]) - 1'd1;

mist_video #(.SD_HCNT_WIDTH(11), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD)) hdmi_video
(
	.clk_sys(clk_vid),
	.scanlines(scanlines),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.blend(blend),
	.ce_divider(ce_divider_hdmi),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(HDMI_HS),
	.VGA_VS(HDMI_VS),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_DE(HDMI_DE)
);

assign HDMI_PCLK = clk_vid;
`endif

//////////////////   AUDIO   //////////////////

hybrid_pwm_sd_2ndorder dac
(
	.clk(clk_sys),
	.reset_n(1'b1),
	.d_l({~laudio[15], laudio[14:0]}),
	.q_l(AUDIO_L),
	.d_r({~raudio[15], raudio[14:0]}),
	.q_r(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s
(
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd33_870_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({laudio}),
	.right_chan({raudio})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(1'b0),
	.clk_rate_i(32'd33_870_000),
	.spdif_o(SPDIF),
	.sample_i({raudio, laudio})
);
`endif

////////////////////////////  INPUT  ///////////////////////////////////
wire m_up1, m_down1, m_left1, m_right1;
wire m_up2, m_down2, m_left2, m_right2;
wire m_up3, m_down3, m_left3, m_right3;
wire m_up4, m_down4, m_left4, m_right4;
wire [11:0] m_fire1, m_fire2, m_fire3, m_fire4;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs #(.START1(7)) inputs (
	.clk         ( clk_sys     ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joy_0       ),
	.joystick_1  ( joy_1       ),
	.joystick_2  ( joy_2       ),
	.joystick_3  ( joy_3       ),
	.rotate      ( 2'b00       ),
	.orientation ( 2'b00       ),
	.joyswap     ( joyswap     ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fire1, m_up1, m_down1, m_left1, m_right1} ),
	.player2     ( {m_fire2, m_up2, m_down2, m_left2, m_right2} ),
	.player3     ( {m_fire3, m_up3, m_down3, m_left3, m_right3} ),
	.player4     ( {m_fire4, m_up4, m_down4, m_left4, m_right4} )
);

endmodule
