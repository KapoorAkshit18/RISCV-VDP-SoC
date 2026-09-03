`ifndef CPU_SOC_RAM_TOP_V
`define CPU_SOC_RAM_TOP_V

// =============================================================================
// cpu_soc_ram_top.v
//
// Complete PicoRV32 SoC integration:
//
//   PicoRV32
//       |
//       v
//   CPU Bus Adapter
//       |
//       v
//   SoC Memory Interconnect
//       |
//       +----> RAM
//       +----> GPIO
//       +----> RF Telemetry
//       +----> Sensor Status
//       +----> VDP / VGA
//
// System address map:
//
//   0x0000_0000 - 0x0000_FFFF : RAM
//   0x0001_0000 - 0x0001_0FFF : GPIO
//   0x0001_1000 - 0x0001_1FFF : RF
//   0x0001_2000 - 0x0001_2FFF : Sensor
//   0x0001_3000 - 0x0001_3FFF : VDP
//   0x0001_4000 - 0x0001_4FFF : TPU

// Peripheral local address width = 12 bits.
//
// =============================================================================

module cpu_soc_ram_top #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_DEPTH      = 16384,
    parameter GPIO_WIDTH     = 32
)(
    // =========================================================================
    // System clock/reset
    // =========================================================================
    input wire clk,
    input wire resetn,

    // =========================================================================
    // Sensor inputs
    // =========================================================================
    input wire [7:0]  battery_percent_i,
    input wire [15:0] battery_voltage_mv_i,
    input wire [15:0] temperature_tenthsC_i,
    input wire        sensor_valid_i,

    // =========================================================================
    // RF telemetry inputs
    // =========================================================================
    input wire [7:0]  rssi_dbm_i,
    input wire        link_up_i,
    input wire        link_error_i,
    input wire        carrier_detect_i,

    // RF control
    output wire       rf_enable_o,

    // =========================================================================
    // GPIO
    // =========================================================================
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_oe,
    input  wire [GPIO_WIDTH-1:0] gpio_in,

    // =========================================================================
    // VDP / VGA
    // =========================================================================
    input wire pixel_clk,

    output wire       hsync_o,
    output wire       vsync_o,

    output wire [11:0] pixel_x_o,
    output wire [11:0] pixel_y_o,

    output wire [3:0] rgb_r_o,
    output wire [3:0] rgb_g_o,
    output wire [3:0] rgb_b_o,

    // =========================================================================
    // CPU status
    // =========================================================================
    output wire trap
);


    // =========================================================================
    // PicoRV32 native memory interface
    // =========================================================================

    wire                     mem_valid;
    wire                     mem_instr;
    wire [ADDR_WIDTH-1:0]    mem_addr;
    wire [DATA_WIDTH-1:0]    mem_wdata;
    wire [DATA_WIDTH/8-1:0]  mem_wstrb;

    wire                     mem_ready;
    wire [DATA_WIDTH-1:0]    mem_rdata;


    // =========================================================================
    // CPU bus adapter interface
    // =========================================================================

    wire                     m_valid;
    wire                     m_write;
    wire [ADDR_WIDTH-1:0]    m_addr;
    wire [DATA_WIDTH-1:0]    m_wdata;
    wire [DATA_WIDTH/8-1:0]  m_strb;

    wire                     m_ready;
    wire [DATA_WIDTH-1:0]    m_rdata;


    // =========================================================================
    // RAM interface
    // =========================================================================

    wire                     ram_valid;
    wire                     ram_write;
    wire [ADDR_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]    ram_wdata;
    wire [DATA_WIDTH/8-1:0]  ram_strb;

    wire                     ram_ready;
    wire [DATA_WIDTH-1:0]    ram_rdata;


    // =========================================================================
    // GPIO interface
    //
    // IMPORTANT:
    // Interconnect provides a 12-bit local peripheral address.
    // =========================================================================

    wire                     gpio_valid;
    wire                     gpio_write;
    wire [11:0]              gpio_addr;
    wire [DATA_WIDTH-1:0]    gpio_wdata;
    wire [DATA_WIDTH/8-1:0]  gpio_strb;

    wire                     gpio_ready;
    wire [DATA_WIDTH-1:0]    gpio_rdata;


    // =========================================================================
    // RF interface
    // =========================================================================

    wire                     rf_valid;
    wire                     rf_write;
    wire [11:0]              rf_addr;
    wire [DATA_WIDTH-1:0]    rf_wdata;
    wire [DATA_WIDTH/8-1:0]  rf_strb;

    wire                     rf_ready;
    wire [DATA_WIDTH-1:0]    rf_rdata;


    // =========================================================================
    // Sensor interface
    // =========================================================================

    wire                     sensor_valid;
    wire                     sensor_write;
    wire [11:0]              sensor_addr;
    wire [DATA_WIDTH-1:0]    sensor_wdata;
    wire [DATA_WIDTH/8-1:0]  sensor_strb;

    wire                     sensor_ready;
    wire [DATA_WIDTH-1:0]    sensor_rdata;


    // =========================================================================
    // VDP interface
    // =========================================================================

    wire                     vdp_valid;
    wire                     vdp_write;
    wire [11:0]              vdp_addr;
    wire [DATA_WIDTH-1:0]    vdp_wdata;
    wire [DATA_WIDTH/8-1:0]  vdp_strb;

    wire                     vdp_ready;
    wire [DATA_WIDTH-1:0]    vdp_rdata;
    // =========================================================================
    // TPU / NN Interface
    // =========================================================================
    wire                    nn_valid;  // valid signal 
    wire                    nn_write;
    wire [11:0]             nn_addr;
    wire [DATA_WIDTH-1:0]   nn_wdata;
    wire [DATA_WIDTH/8-1:0] nn_strb;
    wire                    nn_ready;  // ready signal
    wire [DATA_WIDTH-1:0]   nn_rdata;

// =============================================================================
// NN / TPU command interface
// Generated by nn_axi_wrapper
// =============================================================================

    wire                    axis_start;
    wire [63:0]             weight0;
    wire [63:0]             weight1;
    wire [63:0]             weight2;
    wire [63:0]             weight3;
    wire [63:0]             weight4;
    wire [63:0]             input0;
    wire [63:0]             input1;


// =============================================================================
// NN / TPU status interface
// Generated by nn_axis_master
// =============================================================================

    wire        axis_busy;
    wire        axis_done;


// =============================================================================
// NN / TPU result interface
// Generated by nn_axis_master
// =============================================================================

    wire [63:0] result0;
    wire [63:0] result1;

// =============================================================================
// AXI4-Stream connection between nn_axis_master and axis_nn
// =============================================================================

// Master -> accelerator
    wire [63:0] nn_m_axis_tdata;
    wire        nn_m_axis_tvalid;
    wire        nn_m_axis_tready;
    wire        nn_m_axis_tlast;

    // Accelerator -> master
    wire [63:0] nn_s_axis_tdata;
    wire        nn_s_axis_tvalid;
    wire        nn_s_axis_tready;
    wire        nn_s_axis_tlast;

    // =========================================================================
    // PicoRV32
    // =========================================================================

    ptb cpu (
        .clk        (clk),
        .resetn     (resetn),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .trap       (trap),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb)
    );


    // =========================================================================
    // CPU -> Native Bus Adapter
    // =========================================================================

    cpu_bus_adapter #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) adapter (
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),

        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),

        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata)
    );


    // =========================================================================
    // SoC Memory Interconnect
    //
    // NOTE:
    // No clk/reset here.
    //
    // The interconnect is purely combinational address decoding/routing.
    // =========================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) \interconnect (

        // Master
        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),

        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        // ---------------------------------------------------------------------
        // RAM
        // ---------------------------------------------------------------------

        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),

        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        // ---------------------------------------------------------------------
        // GPIO
        // ---------------------------------------------------------------------

        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),

        .gpio_ready  (gpio_ready),
        .gpio_rdata  (gpio_rdata),

        // ---------------------------------------------------------------------
        // RF
        // ---------------------------------------------------------------------

        .rf_valid   (rf_valid),
        .rf_write   (rf_write),
        .rf_addr    (rf_addr),
        .rf_wdata   (rf_wdata),
        .rf_strb    (rf_strb),

        .rf_ready   (rf_ready),
        .rf_rdata   (rf_rdata),

        // ---------------------------------------------------------------------
        // Sensor
        // ---------------------------------------------------------------------

        .sensor_valid (sensor_valid),
        .sensor_write (sensor_write),
        .sensor_addr  (sensor_addr),
        .sensor_wdata (sensor_wdata),
        .sensor_strb  (sensor_strb),

        .sensor_ready (sensor_ready),
        .sensor_rdata (sensor_rdata),

        // ---------------------------------------------------------------------
        // VDP
        // ---------------------------------------------------------------------

        .vdp_valid  (vdp_valid),
        .vdp_write  (vdp_write),
        .vdp_addr   (vdp_addr),
        .vdp_wdata  (vdp_wdata),
        .vdp_strb    (vdp_strb),

        .vdp_ready  (vdp_ready),
        .vdp_rdata  (vdp_rdata),
   
    // ---------------------------------------------------------------------
    // NN / TPU
    // ---------------------------------------------------------------------
        .nn_valid   (nn_valid),
        .nn_write   (nn_write),
        .nn_addr    (nn_addr),
        .nn_wdata   (nn_wdata),
        .nn_strb    (nn_strb),
        .nn_ready   (nn_ready),
        .nn_rdata   (nn_rdata)
 );
    // =========================================================================
    // RAM
    //
    // soc_ram reset is active-high.
    //
    // Top-level reset is active-low.
    //
    // Therefore:
    //
    //     reset = ~resetn
    // =========================================================================

    soc_ram #(
        .ADDR_WIDTH (RAM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) ram (

        .clk    (clk),
        .reset  (~resetn),

        .valid  (ram_valid),
        .write  (ram_write),

        .addr   (ram_addr[RAM_ADDR_WIDTH-1:0]),
        .wdata  (ram_wdata),
        .strb   (ram_strb),

        .ready  (ram_ready),
        .rdata  (ram_rdata)
    );


    // =========================================================================
    // GPIO
    // =========================================================================

    gpio_native_slave #(
        .GPIO_WIDTH (GPIO_WIDTH)
    ) gpio (

        .clk       (clk),
        .resetn    (resetn),

        .mem_valid (gpio_valid),
        .mem_instr (1'b0),
        .mem_ready (gpio_ready),

        .mem_addr  (gpio_addr),
        .mem_wdata (gpio_wdata),
        .mem_wstrb (gpio_strb),
        .mem_rdata (gpio_rdata),

        .gpio_out  (gpio_out),
        .gpio_oe   (gpio_oe),
        .gpio_in   (gpio_in)
    );


    // =========================================================================
    // SENSOR STATUS
    // =========================================================================

    sensor_status_native_slave sensor (

        .clk                   (clk),
        .resetn                (resetn),

        .mem_valid             (sensor_valid),
        .mem_instr             (1'b0),
        .mem_ready             (sensor_ready),

        .mem_addr              (sensor_addr),
        .mem_wdata             (sensor_wdata),
        .mem_wstrb             (sensor_strb),
        .mem_rdata             (sensor_rdata),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i)
    );


    // =========================================================================
    // RF TELEMETRY
    // =========================================================================

    rf_telemetry_native_slave #(
        .ADDR_WIDTH (12),
        .DATA_WIDTH (DATA_WIDTH)
    ) rf (

        .clk             (clk),
        .resetn          (resetn),

        .mem_valid       (rf_valid),
        .mem_instr       (1'b0),
        .mem_ready       (rf_ready),

        .mem_addr        (rf_addr),
        .mem_wdata       (rf_wdata),
        .mem_wstrb       (rf_strb),
        .mem_rdata       (rf_rdata),

        .rssi_dbm_i      (rssi_dbm_i),
        .link_up_i       (link_up_i),
        .link_error_i    (link_error_i),
        .carrier_detect_i(carrier_detect_i),

        .rf_enable_o     (rf_enable_o)
    );


    // =========================================================================
    // VDP / VGA
    // =========================================================================

    vdp_native_slave vdp (

        // System/native bus clock
        .clk        (clk),
        .resetn     (resetn),

        .mem_valid  (vdp_valid),
        .mem_instr  (1'b0),
        .mem_ready  (vdp_ready),

        .mem_addr   (vdp_addr),
        .mem_wdata  (vdp_wdata),
        .mem_wstrb  (vdp_strb),
        .mem_rdata  (vdp_rdata),

        // Independent VGA pixel clock
        .pixel_clk  (pixel_clk),

        // VGA timing
        .hsync_o    (hsync_o),
        .vsync_o    (vsync_o),

        .pixel_x_o  (pixel_x_o),
        .pixel_y_o  (pixel_y_o),

        // RGB444
        .rgb_r_o    (rgb_r_o),
        .rgb_g_o    (rgb_g_o),
        .rgb_b_o    (rgb_b_o)
    );

    // =============================================================================
// NN / TPU MMIO REGISTER BANK
//
// Converts CPU native memory-mapped accesses into:
//   - accelerator START command
//   - five 64-bit weights
//   - two 64-bit inputs
//
// Also exposes:
//   - BUSY / DONE status
//   - two 64-bit result registers
//
// IMPORTANT:
// This module does NOT contain AXI4-Stream logic.
// AXI4-Stream handling is performed by nn_axis_master.
// =============================================================================

nn_axi_wrapper #(
    .BASE_ADDR(32'h0001_4000)
) nn_wrapper (
    .clk       (clk),
    .rst_n     (resetn),

    // Native MMIO interface
    .bus_req   (nn_valid),
    .bus_write (nn_write),
    .bus_addr  ({20'd0, nn_addr}),
    .bus_wdata (nn_wdata),
    .bus_strb  (nn_strb),

    .bus_ready (nn_ready),
    .bus_rdata (nn_rdata),

    // Accelerator command
    .axis_start (axis_start),

    .weight0 (weight0),
    .weight1 (weight1),
    .weight2 (weight2),
    .weight3 (weight3),
    .weight4 (weight4),

    .input0 (input0),
    .input1 (input1),

    // Accelerator status
    .axis_busy (axis_busy),
    .axis_done (axis_done),

    // Accelerator results
    .result0 (result0),
    .result1 (result1)
);


// =============================================================================
// NN / TPU AXI4-STREAM MASTER
//
// Converts the wrapper's command/payload registers into a seven-beat AXI4-
// Stream transaction:
//
//   Beat 0 : weight0
//   Beat 1 : weight1
//   Beat 2 : weight2
//   Beat 3 : weight3
//   Beat 4 : weight4
//   Beat 5 : input0
//   Beat 6 : input1 + TLAST
//
// It also receives the accelerator's AXI4-Stream result packet.
// =============================================================================

nn_axis_master nn_axis_ctrl (
    .clk       (clk),
    .rst_n     (resetn),

    // -------------------------------------------------------------------------
    // Command from MMIO wrapper
    // -------------------------------------------------------------------------
    .axis_start (axis_start),

    .weight0 (weight0),
    .weight1 (weight1),
    .weight2 (weight2),
    .weight3 (weight3),
    .weight4 (weight4),

    .input0 (input0),
    .input1 (input1),

    // -------------------------------------------------------------------------
    // AXI4-Stream TX: master -> axis_nn
    // -------------------------------------------------------------------------
    .m_axis_tvalid (nn_m_axis_tvalid),
    .m_axis_tready (nn_m_axis_tready),
    .m_axis_tdata  (nn_m_axis_tdata),
    .m_axis_tlast  (nn_m_axis_tlast),

    // -------------------------------------------------------------------------
    // AXI4-Stream RX: axis_nn -> master
    // -------------------------------------------------------------------------
    .s_axis_tvalid (nn_s_axis_tvalid),
    .s_axis_tready (nn_s_axis_tready),
    .s_axis_tdata  (nn_s_axis_tdata),
    .s_axis_tlast  (nn_s_axis_tlast),

    // -------------------------------------------------------------------------
    // Status back to MMIO wrapper
    // -------------------------------------------------------------------------
    .axis_busy (axis_busy),
    .axis_done (axis_done)
);
// =============================================================================
// EXISTING NN / TPU ACCELERATOR
//
// This is the already-verified axis_nn RTL.
// DO NOT modify its internal implementation here.
//
// AXI4-Stream:
//     nn_axis_master -> axis_nn -> nn_axis_master
// =============================================================================

axis_nn nn_accelerator (
    .aclk    (clk),
    .aresetn (resetn),

    // -------------------------------------------------------------------------
    // AXI4-Stream slave: input payload from nn_axis_master
    // -------------------------------------------------------------------------
    .s_axis_tready (nn_m_axis_tready),
    .s_axis_tdata  (nn_m_axis_tdata),
    .s_axis_tvalid (nn_m_axis_tvalid),
    .s_axis_tlast  (nn_m_axis_tlast),

    // -------------------------------------------------------------------------
    // AXI4-Stream master: results toward nn_axis_master
    // -------------------------------------------------------------------------
    .m_axis_tready (nn_s_axis_tready),
    .m_axis_tdata  (nn_s_axis_tdata),
    .m_axis_tvalid (nn_s_axis_tvalid),
    .m_axis_tlast  (nn_s_axis_tlast)
);

endmodule

`endif