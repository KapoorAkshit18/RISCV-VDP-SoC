// (c) Copyright 1995-2026 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:vdp_native_slave:1.0
// IP Revision: 1

(* X_CORE_INFO = "vdp_native_slave,Vivado 2020.1" *)
(* CHECK_LICENSE_TYPE = "cb_vdp_native_slave_0_1,vdp_native_slave,{}" *)
(* CORE_GENERATION_INFO = "cb_vdp_native_slave_0_1,vdp_native_slave,{x_ipProduct=Vivado 2020.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=vdp_native_slave,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module cb_vdp_native_slave_0_1 (
  clk,
  resetn,
  mem_valid,
  mem_instr,
  mem_ready,
  mem_addr,
  mem_wdata,
  mem_wstrb,
  mem_rdata,
  pixel_clk,
  hsync_o,
  vsync_o,
  pixel_x_o,
  pixel_y_o,
  rgb_r_o,
  rgb_g_o,
  rgb_b_o
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, FREQ_HZ 25000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST" *)
input wire resetn;
input wire mem_valid;
input wire mem_instr;
output wire mem_ready;
input wire [11 : 0] mem_addr;
input wire [31 : 0] mem_wdata;
input wire [3 : 0] mem_wstrb;
output wire [31 : 0] mem_rdata;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pixel_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 pixel_clk CLK" *)
input wire pixel_clk;
output wire hsync_o;
output wire vsync_o;
output wire [11 : 0] pixel_x_o;
output wire [11 : 0] pixel_y_o;
output wire [3 : 0] rgb_r_o;
output wire [3 : 0] rgb_g_o;
output wire [3 : 0] rgb_b_o;

  vdp_native_slave inst (
    .clk(clk),
    .resetn(resetn),
    .mem_valid(mem_valid),
    .mem_instr(mem_instr),
    .mem_ready(mem_ready),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(mem_wstrb),
    .mem_rdata(mem_rdata),
    .pixel_clk(pixel_clk),
    .hsync_o(hsync_o),
    .vsync_o(vsync_o),
    .pixel_x_o(pixel_x_o),
    .pixel_y_o(pixel_y_o),
    .rgb_r_o(rgb_r_o),
    .rgb_g_o(rgb_g_o),
    .rgb_b_o(rgb_b_o)
  );
endmodule
