//============================================================================
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
//
//============================================================================


//TODO
//SD Led Activity
//WIP : Audio in 
//VHD -> CSD y CID estan definidos en el user_io.cpp del firmware(linux)
//static uint8_t CSD[16] = { 0xf1, 0x40, 0x40, 0x0a, 0x80, 0x7f, 0xe5, 0xe9, 0x00, 0x00, 0x59, 0x5b, 0x32, 0x00, 0x0e, 0x40 };
//static uint8_t CID[16] = { 0x3e, 0x00, 0x00, 0x34, 0x38, 0x32, 0x44, 0x00, 0x00, 0x73, 0x2f, 0x6f, 0x93, 0x00, 0xc7, 0xcd };

//DONE
//pump up Audio out
//Joystick


`define OSDDebug
`define Release

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	/*
	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.

	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	*/

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

//assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"MSX1;;",
	"-;",
	"S,VHD;",
	"OE,Reset after Mount,No,Yes;",
`ifndef Release
	"O5,SDHC,No,Yes;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O2,DE,Blank,DE;",
	"O8,DebugOSD,Yes,No",
`else
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
`endif
	"OD,Joysticks Swap,No,Yes;",
	"-;",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;



//VHD	
wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        sd_ack_conf;
wire        ioctl_wait = ~pll_locked;//0; //~ram_ready /*synthesis keep*/;//1'b1;

//Keyboard Ps2
wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;

// PS2DIV : la mitad del divisor que necesitas para dividir el clk_sys que le das al hpio, para que te de entre 10Khz y 16Kzh

hps_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(750)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
//	.EXT_BUS(),
//	.gamma_bus(),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	
//VHD	
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	.ioctl_wait(ioctl_wait),	

//Keyboard Ps2
   .ps2_kbd_clk_in(ps2_kbd_clk_out),
	.ps2_kbd_data_in(ps2_kbd_data_out),
	.ps2_kbd_clk_out(ps2_kbd_clk_in),
	.ps2_kbd_data_out(ps2_kbd_data_in),

//Joysticks	
	.joystick_0(joy_A),
	.joystick_1(joy_B)	
	
//	.status_menumask({status[5]}),
	
//	.ps2_key(ps2_key)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire clock_sdram_s, sdram_clk_o, clock_vga_s, pll_locked;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),	// 21.477 MHz					[21.484]
	.outclk_1(clock_sdram_s),  // 85.908 MHz (4x master)	[85.937] - 85.908 ----- OJO con sdrammister 100
	.outclk_2(sdram_clk_o),		// 85.908 MHz -90°
	.outclk_3(clock_vga_s),		// 25.200
	.locked(pll_locked)
);

//wire reset = RESET | status[0] | buttons[1];
wire reset = RESET | status[0] | buttons[1] | !pll_locked | (status[14] && img_mounted);


//assign SDRAM_CLK = sdram_clk_o;

//////////////////////////////////////////////////////////////////

//wire [1:0] col = status[4:3];

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix = 1;
wire [7:0] video;
wire vga_blank, vga_DE;



assign CLK_VIDEO = clock_vga_s;



//////////////////   SD   ///////////////////

wire sdclk;
wire sdmosi;
wire sdmiso = vsd_sel ? vsdmiso : SD_MISO;
wire sdss;

reg vsd_sel = 0;
always @(posedge CLK_50M) if(img_mounted) vsd_sel <= |img_size;



//NOOOO sd_clk_spi = clk_100Mhz y sd_clk_sys = CLK_50M OK si cpu > 5Mhz 
//wire sd_clk_spi, sd_clk_sys;
//assign sd_clk_sys = CLK_50M;
//assign sd_clk_spi = (CpuSpeed < 3'b100) ? clk_100Mhz : clk_25Mhz; // clk_100Mhz;
//
//Tested clk_spi = 50Mhz KO
//Tested NotSdSS KO
//To Test combinaciones de sdhc(1/0) y hw_hashwds_g 0/1 -> Done es indiferente ambos los soporta el driver
//To test sd_Card clk_sys que no sea clk_sys

`ifndef Release
wire sdhc = 0;
`else 
wire sdhc = status[5];
`endif

wire vsdmiso;
sd_card sd_card
(
	.*,
	//.clk_sys(CLK_50M),//(sd_clk_sys),//CLK_50M
	.clk_spi(clk_sys),  //(clk_100Mhz),//(sd_clk_spi),//OK (clk_100Mhz) con clk_sys = CLK_50M, //(clk_250Mhz),
	.sdhc(sdhc),
	.sck(sdclk),
	.ss(sdss | ~vsd_sel),
	.mosi(sdmosi),
	.miso(vsdmiso)
);

// VHD
assign SD_CS   = sdss   |  vsd_sel;
assign SD_SCK  = sdclk  & ~vsd_sel;
assign SD_MOSI = sdmosi & ~vsd_sel;

//SD
//assign SD_CS   = sdss;
//assign SD_SCK  = sdclk;
//assign SD_MOSI = sdmosi;
//wire sdmiso = SD_MISO;


//		.sd_cs_n_o		(sdss),								//: out   std_logic								:= '1';
//		.sd_sclk_o		(sdclk),								//: out   std_logic								:= '0';
//		.sd_mosi_o		(sdmosi),								//: out   std_logic								:= '0';
//		.sd_miso_i		(sdmiso),								//: in    std_logic;

//	input         SD_CD,


///////////////////// JoySticks //////////////
//JoyStick Buttons
//#define JOY_RIGHT       0x01
//#define JOY_LEFT        0x02
//#define JOY_DOWN        0x04
//#define JOY_UP          0x08
//#define JOY_BTN_SHIFT   4
//#define JOY_BTN1        0x10
//#define JOY_BTN2        0x20
//#define JOY_BTN3        0x40
//#define JOY_BTN4        0x80

wire [15:0] joy_0 = status[13] ? joy_B : joy_A;
wire [15:0] joy_1 = status[13] ? joy_A : joy_B;
wire [15:0] joy_A;
wire [15:0] joy_B;



Mister_top Msx1Core
(
//		-- Clocks
//--		clock_50_i			: in    std_logic;


		.clock_master_s	(clk_sys),	//		: std_logic;
		.clock_sdram_s		(clock_sdram_s), 	//		: std_logic;
		.clock_vga_s		(clock_vga_s),		//		: std_logic;
		.pll_locked_s		(pll_locked), 		//		: std_logic;
		.reset				(reset),
		
//		-- Buttons
//		.btn_n_i				(),						//: in    std_logic_vector(4 downto 1);


//		-- SDRAM	(H57V256 = 16Mx16 = 32MB)
		.sdram_clk_o	(SDRAM_CLK),					//		: out   std_logic								:= '0';
		.sdram_cke_o	(SDRAM_CKE),					//			: out   std_logic								:= '0';
		.sdram_ad_o		(SDRAM_A),						//			: out   std_logic_vector(12 downto 0)	:= (others => '0');
		.sdram_da_io	(SDRAM_DQ),						//			: inout std_logic_vector(15 downto 0)	:= (others => 'Z');
		.sdram_ba_o		(SDRAM_BA),						//			: out   std_logic_vector( 1 downto 0)	:= (others => '0');
		.sdram_dqm_o	({SDRAM_DQMH,SDRAM_DQML}),	//		: out   std_logic_vector( 1 downto 0)	:= (others => '1');
		.sdram_ras_o	(SDRAM_nRAS),					//		: out   std_logic								:= '1';
		.sdram_cas_o	(SDRAM_nCAS),					//		: out   std_logic								:= '1';
		.sdram_cs_o		(SDRAM_nCS),					//	: out   std_logic								:= '1';
		.sdram_we_o		(SDRAM_nWE),					//			: out   std_logic								:= '1';

		
//		-- PS2
//		ps2_clk_io			: inout std_logic								:= 'Z';
//		ps2_data_io			: inout std_logic								:= 'Z';
		.ps2_clk_i		(ps2_kbd_clk_in),				//	: inout std_logic								:= 'Z';
		.ps2_data_i		(ps2_kbd_data_in),			//	: inout std_logic								:= 'Z';
		.ps2_clk_o		(ps2_kbd_clk_out),			//	: inout std_logic								:= 'Z';
		.ps2_data_o		(ps2_kbd_data_out),			//	: inout std_logic								:= 'Z';
//		ps2_mouse_clk_io  : inout std_logic								:= 'Z';
//		ps2_mouse_data_io : inout std_logic								:= 'Z';

//		-- SD Card
		.sd_cs_n_o		(sdss),								//: out   std_logic								:= '1';
		.sd_sclk_o		(sdclk),								//: out   std_logic								:= '0';
		.sd_mosi_o		(sdmosi),								//: out   std_logic								:= '0';
		.sd_miso_i		(sdmiso),								//: in    std_logic;


///////////////////// JoySticks //////////////
//JoyStick Buttons
//#define JOY_RIGHT       0x01
//#define JOY_LEFT        0x02
//#define JOY_DOWN        0x04
//#define JOY_UP          0x08
//#define JOY_BTN_SHIFT   4
//#define JOY_BTN1        0x10
//#define JOY_BTN2        0x20
//#define JOY_BTN3        0x40
//#define JOY_BTN4        0x80		
		
//		-- Joysticks
		.joy1_up_i		(~joy_0[3]),	//	: in    std_logic;
		.joy1_down_i	(~joy_0[2]),	//			: in    std_logic;
		.joy1_left_i	(~joy_0[1]),	//			: in    std_logic;
		.joy1_right_i	(~joy_0[0]),	//		: in    std_logic;
		.joy1_p6_i		(~joy_0[4]),	//		: in    std_logic;
		.joy1_p9_i		(~joy_0[5]),	//		: in    std_logic;
		.joy2_up_i		(~joy_1[3]),	//		: in    std_logic;
		.joy2_down_i	(~joy_1[2]),	//			: in    std_logic;
		.joy2_left_i	(~joy_1[1]),	//			: in    std_logic;
		.joy2_right_i	(~joy_1[0]),	//		: in    std_logic;
		.joy2_p6_i		(~joy_1[4]),	//		: in    std_logic;
		.joy2_p9_i		(~joy_1[5]),	//		: in    std_logic;
//--		joyX_p7_o			: out   std_logic								:= '1';

//		-- Audio
//		dac_l_o				: out   std_logic								:= '0';
//		dac_r_o				: out   std_logic								:= '0';
		.PreDac_l_s			(AUDIO_L),		//: out   std_logic_vector(15 downto 0);
		.PreDac_r_s			(AUDIO_R),		//: out   std_logic_vector(15 downto 0);
		.ear_i				(tape_in),		//	: in    std_logic;
//		mic_o					: out   std_logic								:= '0';

//		-- VGA
		.vga_r_o			(Rx),		//			: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_g_o			(Gx),		//	: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_b_o			(Bx),		//	: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_hsync_n_o	(HSync),	//	: out   std_logic								:= '1';
		.vga_vsync_n_o	(VSync),	//	: out   std_logic								:= '1';
		.vga_blank		(vga_blank),			//
		.vga_DE			(vga_DE)
		

	);
	

reg [4:0] Rx, Gx, Bx;


/////////  EAR added by Fernando Mosquera

wire tape_in;
wire tape_adc, tape_adc_act;

assign tape_in = tape_adc_act & tape_adc;

ltc2308_tape ltc2308_tape
(
  .clk(clk_sys),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);
/////////////////////////

	

////////// OSD DEBUG /////////
//`define OSDDebug           //Comentar si no se quiere pasar por el modulo

`ifdef OSDDebug

`define Debug           //Comentar si no se quiere pasar por el modulo
//Parte Comun no Modificable 200525
//ovo #(.vOffset(50), .xScale(3), .yScale(3)) DebugOverlay(
ovo #(.vOffset(50)) DebugOverlay(
    // VGA IN
    .i_r   ( VGA_R_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_g   ( VGA_G_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_b   ( VGA_B_tmp),//: IN  unsigned(7 DOWNTO 0);
    .i_hs  (VGA_HS_tmp),//: IN  std_logic;
    .i_vs  (VGA_VS_tmp),//: IN  std_logic;
    .i_hb  (VGA_HB_tmp),//: IN  std_logic;
    .i_vb  (VGA_VB_tmp),//: IN  std_logic;
	 .i_de  (VGA_DE_tmp),//: IN  std_logic;
    .i_en  (VGA_CE_PIXEL_tmp),//(1'b1),//: IN  std_logic;
    .i_clk (VGA_CLK_tmp),//: IN  std_logic;

    // VGA_OUT
    .o_r   ( VGA_R_o),//: OUT unsigned(7 DOWNTO 0);
    .o_g   ( VGA_G_o),//: OUT unsigned(7 DOWNTO 0);
    .o_b   ( VGA_B_o),//: OUT unsigned(7 DOWNTO 0);
    .o_hs  (VGA_HS_o),//: OUT std_logic;
    .o_vs  (VGA_VS_o),//: OUT std_logic;
    .o_hb  (VGA_HB_o),//: OUT std_logic;
    .o_vb  (VGA_VB_o),//: OUT std_logic;
    .o_de  (VGA_DE_o),//: OUT std_logic;

    // Control
    .ena   (Show),//: IN std_logic; -- Overlay ON/OFF
	 //.xored (status[7]),//: IN std_logic; -- Draw Solid (0) or Mixed/Xored(1) chars

	 
    // Probes
    .in0   (DebugL0),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in1   (DebugL1),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in2   (DebugL2),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in3   (DebugL3),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in4   (DebugL4),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in5   (DebugL5),//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
    .in6   (DebugL6),//({5'b00000,5'b00001}),//IN unsigned(0 TO COLS*5-1);
    .in7   (DebugL7)//({5'b00010,5'b00011})//IN unsigned(0 TO COLS*5-1):=(OTHERS =>'0')
);

wire [7:0] VGA_R_o; 
wire [7:0] VGA_G_o; 
wire [7:0] VGA_B_o;
wire VGA_HS_o, VGA_VS_o, VGA_HB_o, VGA_VB_o, VGA_DE_o;
`ifdef Debug
	assign VGA_R  = VGA_R_o;
	assign VGA_G  = VGA_G_o;
	assign VGA_B  = VGA_B_o;
//	assign VGA_R_Tmp2  = VGA_R_o;
//	assign VGA_G_Tmp2  = VGA_G_o;
//	assign VGA_B_Tmp2  = VGA_B_o;
	assign VGA_HS = VGA_HS_o;
	assign VGA_VS = VGA_VS_o;
	//assign VGA_HB = VGA_HB_o;
	//assign VGA_VB = VGA_VB_o;
	assign VGA_DE = VGA_DE_o;
	assign CE_PIXEL = VGA_CE_PIXEL_tmp;
`else
	assign VGA_R  = VGA_R_tmp;
	assign VGA_G  = VGA_G_tmp;
	assign VGA_B  = VGA_B_tmp;
//	assign VGA_R_Tmp2  = VGA_R_tmp;
//	assign VGA_G_Tmp2  = VGA_G_tmp;
//	assign VGA_B_Tmp2  = VGA_B_tmp;
	assign VGA_HS = VGA_HS_tmp;
	assign VGA_VS = VGA_VS_tmp;
	//assign VGA_HB = VGA_HB_tmp;
	//assign VGA_VB = VGA_VB_tmp;
	assign VGA_DE = VGA_DE_tmp;
	assign CE_PIXEL = VGA_CE_PIXEL_tmp;
`endif


wire [7:0] VGA_R_tmp;
wire [7:0] VGA_G_tmp;
wire [7:0] VGA_B_tmp;
wire VGA_HS_tmp, VGA_VS_tmp, VGA_HB_tmp, VGA_VB_tmp, VGA_DE_tmp, VGA_CLK_tmp, VGA_CE_PIXEL_tmp, Show; // si visible o si no visible
wire [15:0] DebugL0, DebugL1,DebugL2, DebugL3,DebugL4, DebugL5, DebugL6, DebugL7;

//Parte Particular Modificable 200525


//Datos tal cual se entregarian a EMU


assign VGA_R_tmp = {Rx,Rx[4:2]};//{r, r}; //4'b0};
assign VGA_G_tmp = {Gx,Gx[4:2]};//{g, g}; //4'b0};
assign VGA_B_tmp = {Bx,Bx[4:2]};//{b, b}; //4'b0};

assign VGA_HS_tmp = ~HSync;
assign VGA_VS_tmp = ~VSync;

assign VGA_HB_tmp = HBlank;//Dummy //~HSync;
assign VGA_VB_tmp = VBlank;//Dummy //~VSync;
`ifdef Release
assign VGA_DE_tmp = ~vga_blank;//status[2]?~vga_blank:vga_DE;
`else
assign VGA_DE_tmp = status[2]?~vga_blank:vga_DE;
`endif
assign VGA_CLK_tmp = CLK_VIDEO;

	 
assign VGA_CE_PIXEL_tmp = 1;//status[11] ^ CLK_14;//SelectClk;//ce_vid;

`ifdef Release
assign Show = 0;//~status[8];//~status[8]; // si visible o si no visible
`else
assign ~status[8];//~status[8]; // si visible o si no visible
`endif

//Datos a mostrar

//wire [15:0] BramData;
//wire [15:0] Z80Addr;
//wire [15:0] Z80Data;
//wire [15:0] Z80F_BData;
//wire [15:0] Hex;
//wire [3:0] ExtraKeys14;


//assign DebugL0 = ({5'b00000,5'b00001,5'b00001});
//assign DebugL1 = ({5'b00010,5'b00011,5'b00011});

//Sample
// DebugLx must be 16 Bits => 4 digits of 4 bits each one
//assign DebugL1 = {4'b0000,4'b0001,4'b0010,{3'b0000,clk_25Mhz}}; 
//assign DebugL2 = {4'b0000,4'b0001,4'b0010,{3'b0000,clk_25Mhz}}; 
//assign DebugL0 = {{1'b0,vsd_sel,img_mounted,SD_CD},{3'b000,clk},{3'b000,status[9]},{3'b000,clk_25Mhz}};//BramData;//rememotech.U_RamRom.q[14:0];
//assign DebugL1 = Z80Addr;
//assign DebugL2 = Z80Data;
//assign DebugL3 = Z80F_BData; //"00" & not ctc_interrupt & M1_n & MREQ_n & IORQ_n & RD_n & WR_n & rom_q;
//assign DebugL4 = Hex;
//assign DebugL5 = {{1'b0,CpuSpeed},{3'b000,(CpuSpeed < 3'b100)},ExtraKeys14,img_size[3:0]}; 

//reg [20:0] ram_addr_tmp = 21'b0;
////always @(posedge CLK_56) ram_addr_tmp <= (ram_addr > ram_addr_tmp) ? ram_addr : ram_addr_tmp; //TODO Reset
//assign ram_addr_tmp = (ram_addr > ram_addr_tmp) ? ram_addr : ram_addr_tmp; //TODO Reset



//reg [20:0] ram_addrF_tmp = 21'b0;
////always @(posedge CLK_56) ram_addrF_tmp <= (AddrFixed > ram_addrF_tmp) ? AddrFixed : ram_addrF_tmp; //TODO Reset
//assign ram_addrF_tmp = (AddrFixed > ram_addrF_tmp) ? AddrFixed : ram_addrF_tmp; //TODO Reset


//assign ram_addr_tmp = ram_addr when ram_addr > ram_addr_tmp else 

//always @(ram_addr) begin  
//	if (ram_addr > ram_addr_tmp) begin
//		ram_addr_tmp <= ram_addr;
//	end
//end

//assign DebugL0 = {3'h0,ram_addr_tmp[20:8]};
//assign DebugL1 = {4'h0,ram_addr_tmp[11:0]};
//assign DebugL2 = ({4'h0,4'h0,4'h0,{2'h0,status[10:9]}});
//assign DebugL3 = ({{3'b0,ram_cs},{2'b0,ram_we,ram_rd},{3'b0,ram_ready},{3'b0,reset}});
////assign DebugL3 = ({4'hf,4'he,4'hd,4'hc});
////assign DebugL2 = {3'h0,ram_addrF_tmp[20:8]};
////assign DebugL3 = {4'h0,ram_addrF_tmp[11:0]};
//assign DebugL4 = {3'h0,ram_addr[20:8]};
//assign DebugL5 = {4'h0,ram_addr[11:0]};
////assign DebugL4 = ({4'hc,4'hb,4'ha,4'h9});



assign DebugL0 = ({4'h9,4'h8,4'h7,4'h6});
assign DebugL1 = ({4'h6,4'h5,4'h4,4'h3});
assign DebugL2 = ({4'h3,4'h2,4'h1,4'h0});
assign DebugL3 = ({4'hf,4'he,4'hd,4'hc});
assign DebugL4 = ({4'hc,4'hb,4'ha,4'h9});
assign DebugL5 = ({4'h9,4'h8,4'h7,4'h6});


`endif
////////////////////////

//reg [7:0] VGA_R_Tmp2;
//reg [7:0] VGA_G_Tmp2;
//reg [7:0] VGA_B_Tmp2;
//
//
//Monochrome Mono(
//    // VGA IN
//    .i_r   ( VGA_R_Tmp2),//: IN  unsigned(7 DOWNTO 0);
//    .i_g   ( VGA_G_Tmp2),//: IN  unsigned(7 DOWNTO 0);
//    .i_b   ( VGA_B_Tmp2),//: IN  unsigned(7 DOWNTO 0);
//
//    // VGA_OUT
//    .o_r   ( VGA_R),//: OUT unsigned(7 DOWNTO 0);
//    .o_g   ( VGA_G),//: OUT unsigned(7 DOWNTO 0);
//    .o_b   ( VGA_B),//: OUT unsigned(7 DOWNTO 0);
//
//    // Control
//    .ena   (Show),//: IN std_logic; -- Overlay ON/OFF
//	 .mode  (status[4:3]),//: IN std_logic; -- Draw Solid (0) or Mixed/Xored(1) chars
//);





endmodule
