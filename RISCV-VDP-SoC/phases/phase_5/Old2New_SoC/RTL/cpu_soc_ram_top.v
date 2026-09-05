`ifndef CPU_SOC_RAM_TOP_V
`define CPU_SOC_RAM_TOP_V

// =============================================================================
// cpu_soc_ram_top.v
//
// RISC-V SoC TOP LEVEL
// =============================================================================
//
// Architecture:
//
//                    +----------------+
//                    |    PicoRV32    |
//                    |      ptb       |
//                    +-------+--------+
//                            |
//                            | Native memory interface
//                            v
//                    +-------+--------+
//                    | CPU Bus        |
//                    | Adapter        |
//                    +-------+--------+
//                            |
//                            v
//                    +-------+--------+
//                    | SoC Memory     |
//                    | Interconnect   |
//                    +-------+--------+
//                            |
//        +-------------------+-------------------+
//        |          |          |         |       |
//        v          v          v         v       v
//       RAM        GPIO       RF      SENSOR    VDP
//                                                  
//                                      +----------+
//                                      |
//                                      v
//                                  TPU / NN
//                                  0x14000
//                                      |
//                                      v
//                              tpu_axis_top
//                                      |
//                                      v
//                              nn_axi_wrapper
//                                      |
//                                      v
//                              nn_axis_master
//                                      |
//                                      v
//                                  axis_nn
//
// =============================================================================
//
// SYSTEM ADDRESS MAP
// =============================================================================
//
//   0x0000_0000 - 0x0000_FFFF : RAM       (64 KB)
//   0x0001_0000 - 0x0001_0FFF : GPIO      (4 KB)
//   0x0001_1000 - 0x0001_1FFF : RF        (4 KB)
//   0x0001_2000 - 0x0001_2FFF : SENSOR    (4 KB)
//   0x0001_3000 - 0x0001_3FFF : VDP       (4 KB)
//   0x0001_4000 - 0x0001_4FFF : TPU / NN  (4 KB)
//
// Peripheral local address width = 12 bits.
//
// =============================================================================
//
// IMPORTANT DESIGN DECISIONS
// =============================================================================
//
// 1. PicoRV32 remains connected through its native memory interface.
//
// 2. No AXI4-Lite is inserted between PicoRV32 and the SoC interconnect.
//
// 3. The SoC interconnect performs only native-bus address decoding.
//
// 4. TPU MMIO is decoded at 0x0001_4000.
//
// 5. tpu_axis_top is the TPU integration boundary.
//
// 6. axis_nn is instantiated ONLY inside tpu_axis_top.
//
// 7. No second nn instance is created here.
//
// 8. AXI4-Stream exists ONLY inside the TPU hierarchy.
//
// 9. Firmware initialization is intentionally NOT performed here.
//    The firmware-loading mechanism belongs to the testbench / Part-2 flow.
//
// 10. This module is written to remain compatible with Vivado 2020.1.
//
// =============================================================================

`timescale 1ns / 1ps

module cpu_soc_ram_top #(
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_DEPTH      = 16384,
    parameter GPIO_WIDTH     = 32
)(
    // =========================================================================
    // SYSTEM CLOCK / RESET
    // =========================================================================

    input wire clk,
    input wire resetn,

    // =========================================================================
    // SENSOR INPUTS
    // =========================================================================

    input wire [7:0]  battery_percent_i,
    input wire [15:0] battery_voltage_mv_i,
    input wire [15:0] temperature_tenthsC_i,
    input wire        sensor_valid_i,

    // =========================================================================
    // RF TELEMETRY INPUTS
    // =========================================================================

    input wire [7:0] rssi_dbm_i,
    input wire       link_up_i,
    input wire       link_error_i,
    input wire       carrier_detect_i,

    // RF control output
    output wire rf_enable_o,

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
    // CPU STATUS
    // =========================================================================

    output wire trap

);

    // =========================================================================
    // CONSTANTS
    // =========================================================================

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;

    // TPU system base address.
    //
    // The actual address decoding is performed by soc_mem_interconnect.
    //
    localparam [ADDR_WIDTH-1:0] TPU_BASE_ADDR =
                                32'h0001_4000;


    // =========================================================================
    // 1. PicoRV32 NATIVE MEMORY BUS
    // =========================================================================
    //
    // PicoRV32 communicates with the rest of the SoC through its native
    // valid/ready memory interface.
    //
    // No AXI protocol is present at this level.
    //
    // =========================================================================

    wire                    mem_valid;
    wire                    mem_instr;

    wire [ADDR_WIDTH-1:0]   mem_addr;
    wire [DATA_WIDTH-1:0]   mem_wdata;
    wire [STRB_WIDTH-1:0]   mem_wstrb;

    wire                    mem_ready;
    wire [DATA_WIDTH-1:0]   mem_rdata;


    // =========================================================================
    // 2. CPU BUS ADAPTER
    // =========================================================================
    //
    // Converts the PicoRV32 native memory request into the SoC's generic
    // master-side transaction format.
    //
    // =========================================================================

    wire                    m_valid;
    wire                    m_write;

    wire [ADDR_WIDTH-1:0]   m_addr;
    wire [DATA_WIDTH-1:0]   m_wdata;
    wire [STRB_WIDTH-1:0]   m_strb;

    wire                    m_ready;
    wire [DATA_WIDTH-1:0]   m_rdata;


    // =========================================================================
    // 3. RAM INTERFACE
    // =========================================================================

    wire                    ram_valid;
    wire                    ram_write;

    wire [ADDR_WIDTH-1:0]   ram_addr;
    wire [DATA_WIDTH-1:0]   ram_wdata;
    wire [STRB_WIDTH-1:0]   ram_strb;

    wire                    ram_ready;
    wire [DATA_WIDTH-1:0]   ram_rdata;


    // =========================================================================
    // 4. GPIO INTERFACE
    // =========================================================================

    wire                    gpio_valid;
    wire                    gpio_write;

    wire [11:0]             gpio_addr;
    wire [DATA_WIDTH-1:0]   gpio_wdata;
    wire [STRB_WIDTH-1:0]   gpio_strb;

    wire                    gpio_ready;
    wire [DATA_WIDTH-1:0]   gpio_rdata;


    // =========================================================================
    // 5. RF INTERFACE
    // =========================================================================

    wire                    rf_valid;
    wire                    rf_write;

    wire [11:0]             rf_addr;
    wire [DATA_WIDTH-1:0]   rf_wdata;
    wire [STRB_WIDTH-1:0]   rf_strb;

    wire                    rf_ready;
    wire [DATA_WIDTH-1:0]   rf_rdata;


    // =========================================================================
    // 6. SENSOR INTERFACE
    // =========================================================================

    wire                    sensor_valid;
    wire                    sensor_write;

    wire [11:0]             sensor_addr;
    wire [DATA_WIDTH-1:0]   sensor_wdata;
    wire [STRB_WIDTH-1:0]   sensor_strb;

    wire                    sensor_ready;
    wire [DATA_WIDTH-1:0]   sensor_rdata;


    // =========================================================================
    // 7. VDP INTERFACE
    // =========================================================================

    wire                    vdp_valid;
    wire                    vdp_write;

    wire [11:0]             vdp_addr;
    wire [DATA_WIDTH-1:0]   vdp_wdata;
    wire [STRB_WIDTH-1:0]   vdp_strb;

    wire                    vdp_ready;
    wire [DATA_WIDTH-1:0]   vdp_rdata;


    // =========================================================================
    // 8. TPU / NN NATIVE MMIO INTERFACE
    // =========================================================================
    //
    // This is the ONLY CPU-facing interface of the TPU.
    //
    // The interconnect converts:
    //
    //     CPU address 0x0001_4000
    //
    // into:
    //
    //     nn_addr = 12'h000
    //
    // and so on for the complete 4-KB TPU window.
    //
    // =========================================================================

    wire                    nn_valid;
    wire                    nn_write;

    wire [11:0]             nn_addr;
    wire [DATA_WIDTH-1:0]   nn_wdata;
    wire [STRB_WIDTH-1:0]   nn_strb;

    wire                    nn_ready;
    wire [DATA_WIDTH-1:0]   nn_rdata;
    wire [63:0]              result0;
    wire [63:0]              result1;

    // =========================================================================
    // 9. PICORV32
    // =========================================================================
    //
    // ptb is the local wrapper around picorv32a.
    //
    // PCPI is disabled inside ptb because the TPU is integrated as a
    // memory-mapped peripheral rather than a PCPI coprocessor.
    //
    // =========================================================================

    ptb cpu (
        .clk       (clk),
        .resetn    (resetn),

        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata),

        .trap      (trap),

        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb)
    );


    // =========================================================================
    // 10. CPU BUS ADAPTER
    // =========================================================================
    //
    // PicoRV32 native memory bus
    //              |
    //              v
    //      generic SoC master bus
    //
    // =========================================================================

    cpu_bus_adapter #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) adapter (

        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),

        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata),

        .m_valid   (m_valid),
        .m_write   (m_write),
        .m_addr    (m_addr),
        .m_wdata   (m_wdata),
        .m_strb    (m_strb),

        .m_ready   (m_ready),
        .m_rdata   (m_rdata)
    );


    // =========================================================================
    // 11. SOC MEMORY INTERCONNECT
    // =========================================================================
    //
    // The interconnect is combinational.
    //
    // It performs:
    //
    //     system address decode
    //     transaction routing
    //     slave response multiplexing
    //
    // Address decoding for TPU is already implemented inside
    // soc_mem_interconnect:
    //
    //     0x0001_4000 - 0x0001_4FFF
    //
    // =========================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_interconnect (

        // ---------------------------------------------------------------------
        // MASTER
        // ---------------------------------------------------------------------

        .m_valid (m_valid),
        .m_write (m_write),
        .m_addr  (m_addr),
        .m_wdata (m_wdata),
        .m_strb  (m_strb),

        .m_ready (m_ready),
        .m_rdata (m_rdata),


        // ---------------------------------------------------------------------
        // RAM
        // ---------------------------------------------------------------------

        .ram_valid (ram_valid),
        .ram_write (ram_write),
        .ram_addr  (ram_addr),
        .ram_wdata (ram_wdata),
        .ram_strb  (ram_strb),

        .ram_ready (ram_ready),
        .ram_rdata (ram_rdata),


        // ---------------------------------------------------------------------
        // GPIO
        // ---------------------------------------------------------------------

        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),

        .gpio_ready (gpio_ready),
        .gpio_rdata (gpio_rdata),


        // ---------------------------------------------------------------------
        // RF
        // ---------------------------------------------------------------------

        .rf_valid (rf_valid),
        .rf_write (rf_write),
        .rf_addr  (rf_addr),
        .rf_wdata (rf_wdata),
        .rf_strb  (rf_strb),

        .rf_ready (rf_ready),
        .rf_rdata (rf_rdata),


        // ---------------------------------------------------------------------
        // SENSOR
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

        .vdp_valid (vdp_valid),
        .vdp_write (vdp_write),
        .vdp_addr  (vdp_addr),
        .vdp_wdata (vdp_wdata),
        .vdp_strb   (vdp_strb),

        .vdp_ready  (vdp_ready),
        .vdp_rdata  (vdp_rdata),


        // ---------------------------------------------------------------------
        // TPU / NN
        // ---------------------------------------------------------------------
        //
        // The interconnect performs the system-to-local address conversion.
        //
        // Example:
        //
        //     m_addr = 0x0001_4010
        //
        // becomes:
        //
        //     nn_addr = 12'h010
        //
        // ---------------------------------------------------------------------

        .nn_valid (nn_valid),
        .nn_write (nn_write),
        .nn_addr  (nn_addr),
        .nn_wdata (nn_wdata),
        .nn_strb  (nn_strb),

        .nn_ready (nn_ready),
        .nn_rdata (nn_rdata)

    );


    // =========================================================================
    // 12. SOC RAM
    // =========================================================================
    //
    // The RAM is unchanged by TPU integration.
    //
    // It remains the 0x0000_0000 - 0x0000_FFFF region.
    //
    // IMPORTANT:
    //
    // Firmware loading is intentionally NOT performed here.
    //
    // The Phase-1 style testbench can initialize/access memory separately
    // when firmware testing is introduced.
    //
    // =========================================================================

    soc_ram #(
        .ADDR_WIDTH (RAM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (RAM_DEPTH)
    ) ram (

        .clk   (clk),

        // soc_ram uses active-high reset.
        .reset (~resetn),

        .valid (ram_valid),
        .write (ram_write),

        .addr  (ram_addr[RAM_ADDR_WIDTH-1:0]),

        .wdata (ram_wdata),
        .strb  (ram_strb),

        .ready (ram_ready),
        .rdata (ram_rdata)
    );


    // =========================================================================
    // 13. GPIO
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
    // 14. SENSOR STATUS
    // =========================================================================

    sensor_status_native_slave sensor (

        .clk   (clk),
        .resetn(resetn),

        .mem_valid (sensor_valid),
        .mem_instr (1'b0),

        .mem_ready (sensor_ready),

        .mem_addr  (sensor_addr),
        .mem_wdata (sensor_wdata),
        .mem_wstrb (sensor_strb),

        .mem_rdata (sensor_rdata),

        .battery_percent_i     (battery_percent_i),
        .battery_voltage_mv_i  (battery_voltage_mv_i),
        .temperature_tenthsC_i (temperature_tenthsC_i),
        .sensor_valid_i        (sensor_valid_i)
    );


    // =========================================================================
    // 15. RF TELEMETRY
    // =========================================================================

    rf_telemetry_native_slave #(
        .ADDR_WIDTH (12),
        .DATA_WIDTH (DATA_WIDTH)
    ) rf (

        .clk    (clk),
        .resetn (resetn),

        .mem_valid (rf_valid),
        .mem_instr (1'b0),

        .mem_ready (rf_ready),

        .mem_addr  (rf_addr),
        .mem_wdata (rf_wdata),
        .mem_wstrb (rf_strb),

        .mem_rdata (rf_rdata),

        .rssi_dbm_i       (rssi_dbm_i),
        .link_up_i        (link_up_i),
        .link_error_i     (link_error_i),
        .carrier_detect_i (carrier_detect_i),

        .rf_enable_o (rf_enable_o)
    );


    // =========================================================================
    // 16. VDP / VGA
    // =========================================================================
    //
    // VDP has two clock domains:
    //
    //     clk       -> CPU/MMIO interface
    //     pixel_clk -> VGA timing/pixel generation
    //
    // The VDP module internally handles the required clock-domain separation.
    //
    // =========================================================================

    vdp_native_slave vdp (

        // System/native bus clock
        .clk       (clk),
        .resetn    (resetn),

        // Native CPU bus
        .mem_valid (vdp_valid),
        .mem_instr (1'b0),

        .mem_ready (vdp_ready),

        .mem_addr  (vdp_addr),
        .mem_wdata (vdp_wdata),
        .mem_wstrb (vdp_strb),

        .mem_rdata (vdp_rdata),

        // VGA pixel clock
        .pixel_clk (pixel_clk),

        // VGA timing
        .hsync_o   (hsync_o),
        .vsync_o   (vsync_o),

        .pixel_x_o (pixel_x_o),
        .pixel_y_o (pixel_y_o),

        // RGB444
        .rgb_r_o   (rgb_r_o),
        .rgb_g_o   (rgb_g_o),
        .rgb_b_o   (rgb_b_o)
    );


    // =========================================================================
    // 17. TPU / NN
    // =========================================================================
    //
    // IMPORTANT:
    //
    // Use the existing tpu_axis_top hierarchy.
    //
    // Do NOT instantiate:
    //
    //     nn_axi_wrapper
    //     nn_axis_master
    //     axis_nn
    //
    // separately here.
    //
    // tpu_axis_top already provides:
    //
    //     nn_axi_wrapper
    //          |
    //          v
    //     nn_axis_master
    //          |
    //          v
    //       axis_nn
    //
    // and axis_nn already contains the verified NN implementation.
    //
    // CPU-side interface:
    //
    //     nn_valid
    //     nn_write
    //     nn_addr[11:0]
    //     nn_wdata[31:0]
    //     nn_strb[3:0]
    //     nn_ready
    //     nn_rdata[31:0]
    //
    // AXI4-Stream remains internal to the TPU hierarchy.
    //
    // =========================================================================

    tpu_axis_top #(
        .BASE_ADDR (TPU_BASE_ADDR)
    ) tpu (

        .clk      (clk),
        .rst_n    (resetn),

        // ---------------------------------------------------------------------
        // Native MMIO interface from SoC interconnect
        // ---------------------------------------------------------------------

        .nn_valid (nn_valid),
        .nn_write (nn_write),
        .nn_addr  (nn_addr),
        .nn_wdata (nn_wdata),
        .nn_strb  (nn_strb),

        .nn_ready (nn_ready),
        .nn_rdata (nn_rdata),
        .result0   (result0),
        .result1   (result1)
    );


endmodule

`endif
