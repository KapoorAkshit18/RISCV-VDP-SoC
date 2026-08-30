`timescale 1ns/1ps

// =============================================================================
// tb_soc_mem_interconnect.v
//
// Self-checking simulation testbench for soc_mem_interconnect.
//
// IMPORTANT:
// GPIO and RF telemetry do NOT have physical RTL slave modules in this
// simulation. Their bus interfaces are modeled here as simple dummy slave
// responses so that the memory interconnect's address decoding and routing
// logic can still be verified.
//
// Simulation-only slave models:
//   - GPIO
//   - RF Telemetry
//   - Sensor
//   - VDP
//
// The purpose of this testbench is to verify:
//
//   1. Address decoding
//   2. Slave selection
//   3. Local-address generation
//   4. Write/read propagation
//   5. Write data propagation
//   6. Byte-strobe propagation
//   7. Ready propagation
//   8. Read-data return path
//   9. Unmapped-address handling
//  10. No overlapping slave selection
//
// Address map:
//
//   0x0000_0000 - 0x0000_FFFF : RAM
//   0x0001_0000 - 0x0001_0FFF : GPIO (simulation model)
//   0x0001_1000 - 0x0001_1FFF : RF   (simulation model)
//   0x0001_2000 - 0x0001_2FFF : Sensor (simulation model)
//   0x0001_3000 - 0x0001_3FFF : VDP    (simulation model)
//
// Peripheral local addresses are 12 bits.
//
// Native bus:
//
//   m_valid = request
//   m_write = 1 for write, 0 for read
//   m_addr  = 32-bit system address
//   m_wdata = write data
//   m_strb  = byte strobes
//   m_ready = transaction complete
//   m_rdata = read data
//
// =============================================================================

module tb_soc_mem_interconnect;

    // =========================================================================
    // CLOCK
    // =========================================================================

    reg clk;

    always #5 clk = ~clk;


    // =========================================================================
    // MASTER / CPU-SIDE INTERFACE
    // =========================================================================

    reg         m_valid;
    reg         m_write;
    reg [31:0]  m_addr;
    reg [31:0]  m_wdata;
    reg [3:0]   m_strb;

    wire        m_ready;
    wire [31:0] m_rdata;


    // =========================================================================
    // RAM INTERFACE
    // =========================================================================

    wire        ram_valid;
    wire        ram_write;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [3:0]  ram_strb;

    reg         ram_ready;
    reg [31:0]  ram_rdata;


    // =========================================================================
    // GPIO INTERFACE
    //
    // No GPIO slave RTL is instantiated.
    // These signals represent a SIMULATION-ONLY GPIO slave interface.
    // =========================================================================

    wire        gpio_valid;
    wire        gpio_write;
    wire [11:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [3:0]  gpio_strb;

    reg         gpio_ready;
    reg [31:0]  gpio_rdata;


    // =========================================================================
    // RF TELEMETRY INTERFACE
    //
    // No RF telemetry slave RTL is instantiated.
    // These signals represent a SIMULATION-ONLY RF slave interface.
    // =========================================================================

    wire        rf_valid;
    wire        rf_write;
    wire [11:0] rf_addr;
    wire [31:0] rf_wdata;
    wire [3:0]  rf_strb;

    reg         rf_ready;
    reg [31:0]  rf_rdata;


    // =========================================================================
    // SENSOR INTERFACE
    //
    // Simulation response is provided directly by the testbench.
    // =========================================================================

    wire        sensor_valid;
    wire        sensor_write;
    wire [11:0] sensor_addr;
    wire [31:0] sensor_wdata;
    wire [3:0]  sensor_strb;

    reg         sensor_ready;
    reg [31:0]  sensor_rdata;


    // =========================================================================
    // VDP INTERFACE
    //
    // Simulation response is provided directly by the testbench.
    // =========================================================================

    wire        vdp_valid;
    wire        vdp_write;
    wire [11:0] vdp_addr;
    wire [31:0] vdp_wdata;
    wire [3:0]  vdp_strb;

    reg         vdp_ready;
    reg [31:0]  vdp_rdata;


    // =========================================================================
    // ERROR COUNTER
    // =========================================================================

    integer errors;


    // =========================================================================
    // DUT : SOC MEMORY INTERCONNECT
    // =========================================================================

    soc_mem_interconnect #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) dut (

        // ---------------------------------------------------------------------
        // Master / CPU-side interface
        // ---------------------------------------------------------------------

        .m_valid(m_valid),
        .m_write(m_write),
        .m_addr(m_addr),
        .m_wdata(m_wdata),
        .m_strb(m_strb),
        .m_ready(m_ready),
        .m_rdata(m_rdata),

        // ---------------------------------------------------------------------
        // RAM
        // ---------------------------------------------------------------------

        .ram_valid(ram_valid),
        .ram_write(ram_write),
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata),
        .ram_strb(ram_strb),
        .ram_ready(ram_ready),
        .ram_rdata(ram_rdata),

        // ---------------------------------------------------------------------
        // GPIO simulation interface
        // ---------------------------------------------------------------------

        .gpio_valid(gpio_valid),
        .gpio_write(gpio_write),
        .gpio_addr(gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_strb(gpio_strb),
        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata),

        // ---------------------------------------------------------------------
        // RF telemetry simulation interface
        // ---------------------------------------------------------------------

        .rf_valid(rf_valid),
        .rf_write(rf_write),
        .rf_addr(rf_addr),
        .rf_wdata(rf_wdata),
        .rf_strb(rf_strb),
        .rf_ready(rf_ready),
        .rf_rdata(rf_rdata),

        // ---------------------------------------------------------------------
        // Sensor simulation interface
        // ---------------------------------------------------------------------

        .sensor_valid(sensor_valid),
        .sensor_write(sensor_write),
        .sensor_addr(sensor_addr),
        .sensor_wdata(sensor_wdata),
        .sensor_strb(sensor_strb),
        .sensor_ready(sensor_ready),
        .sensor_rdata(sensor_rdata),

        // ---------------------------------------------------------------------
        // VDP simulation interface
        // ---------------------------------------------------------------------

        .vdp_valid(vdp_valid),
        .vdp_write(vdp_write),
        .vdp_addr(vdp_addr),
        .vdp_wdata(vdp_wdata),
        .vdp_strb(vdp_strb),
        .vdp_ready(vdp_ready),
        .vdp_rdata(vdp_rdata)
    );


    // =========================================================================
    // TASK: CLEAR ALL INPUTS
    // =========================================================================

    task clear_inputs;
        begin

            // Master
            m_valid = 1'b0;
            m_write = 1'b0;
            m_addr  = 32'h0000_0000;
            m_wdata = 32'h0000_0000;
            m_strb  = 4'h0;

            // RAM simulation response
            ram_ready = 1'b0;
            ram_rdata = 32'h0000_0000;

            // GPIO simulation response
            gpio_ready = 1'b0;
            gpio_rdata = 32'h0000_0000;

            // RF simulation response
            rf_ready = 1'b0;
            rf_rdata = 32'h0000_0000;

            // Sensor simulation response
            sensor_ready = 1'b0;
            sensor_rdata = 32'h0000_0000;

            // VDP simulation response
            vdp_ready = 1'b0;
            vdp_rdata = 32'h0000_0000;

        end
    endtask


    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================

    initial begin

        clk    = 1'b0;
        errors = 0;

        clear_inputs();

        #20;


        // =====================================================================
        // TEST 1 : RAM ROUTING
        // =====================================================================

        $display("");
        $display("TEST 1 : RAM ROUTING");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0000_0040;
        m_wdata = 32'h1234_5678;
        m_strb  = 4'h0;

        // Simulated RAM response
        ram_ready = 1'b1;
        ram_rdata = 32'hA5A5_5A5A;

        #1;

        if (ram_valid &&
            !gpio_valid &&
            !rf_valid &&
            !sensor_valid &&
            !vdp_valid)

            $display("PASS: RAM address routed only to RAM");

        else begin
            $display("FAIL: RAM routing incorrect");
            errors = errors + 1;
        end


        if (ram_addr === 32'h0000_0040)

            $display("PASS: RAM receives address = %08h",
                     ram_addr);

        else begin
            $display("FAIL: RAM address = %08h",
                     ram_addr);
            errors = errors + 1;
        end


        if (m_ready === 1'b1 &&
            m_rdata === 32'hA5A5_5A5A)

            $display("PASS: RAM ready/data returned to master");

        else begin
            $display("FAIL: RAM response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 2 : GPIO SIMULATION SLAVE
        // =====================================================================

        $display("");
        $display("TEST 2 : GPIO SIMULATION SLAVE");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0001_000C;
        m_strb  = 4'h0;

        // Dummy GPIO slave response
        gpio_ready = 1'b1;
        gpio_rdata = 32'h1122_3344;

        #1;

        if (gpio_valid &&
            !ram_valid &&
            !rf_valid &&
            !sensor_valid &&
            !vdp_valid)

            $display("PASS: GPIO address routed only to GPIO model");

        else begin
            $display("FAIL: GPIO routing incorrect");
            errors = errors + 1;
        end


        if (gpio_addr === 12'h00C)

            $display("PASS: GPIO local address = %03h",
                     gpio_addr);

        else begin
            $display("FAIL: GPIO local address = %03h",
                     gpio_addr);
            errors = errors + 1;
        end


        if (m_ready &&
            m_rdata === 32'h1122_3344)

            $display("PASS: GPIO model response returned to master");

        else begin
            $display("FAIL: GPIO response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 3 : RF TELEMETRY SIMULATION SLAVE
        // =====================================================================

        $display("");
        $display("TEST 3 : RF TELEMETRY SIMULATION SLAVE");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0001_1008;
        m_strb  = 4'h0;

        // Dummy RF telemetry slave response
        rf_ready = 1'b1;
        rf_rdata = 32'h5246_5430;

        #1;

        if (rf_valid &&
            !ram_valid &&
            !gpio_valid &&
            !sensor_valid &&
            !vdp_valid)

            $display("PASS: RF address routed only to RF model");

        else begin
            $display("FAIL: RF routing incorrect");
            errors = errors + 1;
        end


        if (rf_addr === 12'h008)

            $display("PASS: RF local address = %03h",
                     rf_addr);

        else begin
            $display("FAIL: RF local address = %03h",
                     rf_addr);
            errors = errors + 1;
        end


        if (m_ready &&
            m_rdata === 32'h5246_5430)

            $display("PASS: RF model response returned to master");

        else begin
            $display("FAIL: RF response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 4 : SENSOR SIMULATION SLAVE
        // =====================================================================

        $display("");
        $display("TEST 4 : SENSOR SIMULATION SLAVE");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0001_200C;
        m_strb  = 4'h0;

        sensor_ready = 1'b1;
        sensor_rdata = 32'h0000_0001;

        #1;

        if (sensor_valid &&
            !ram_valid &&
            !gpio_valid &&
            !rf_valid &&
            !vdp_valid)

            $display("PASS: Sensor address routed only to Sensor model");

        else begin
            $display("FAIL: Sensor routing incorrect");
            errors = errors + 1;
        end


        if (sensor_addr === 12'h00C)

            $display("PASS: Sensor local address = %03h",
                     sensor_addr);

        else begin
            $display("FAIL: Sensor local address = %03h",
                     sensor_addr);
            errors = errors + 1;
        end


        if (m_ready &&
            m_rdata === 32'h0000_0001)

            $display("PASS: Sensor response returned to master");

        else begin
            $display("FAIL: Sensor response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 5 : VDP SIMULATION SLAVE
        // =====================================================================

        $display("");
        $display("TEST 5 : VDP SIMULATION SLAVE");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0001_3010;
        m_strb  = 4'h0;

        vdp_ready = 1'b1;
        vdp_rdata = 32'h00FF_1234;

        #1;

        if (vdp_valid &&
            !ram_valid &&
            !gpio_valid &&
            !rf_valid &&
            !sensor_valid)

            $display("PASS: VDP address routed only to VDP model");

        else begin
            $display("FAIL: VDP routing incorrect");
            errors = errors + 1;
        end


        if (vdp_addr === 12'h010)

            $display("PASS: VDP local address = %03h",
                     vdp_addr);

        else begin
            $display("FAIL: VDP local address = %03h",
                     vdp_addr);
            errors = errors + 1;
        end


        if (m_ready &&
            m_rdata === 32'h00FF_1234)

            $display("PASS: VDP response returned to master");

        else begin
            $display("FAIL: VDP response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 6 : WRITE ROUTING + BYTE STROBES
        // =====================================================================

        $display("");
        $display("TEST 6 : WRITE ROUTING + BYTE STROBES");

        m_valid = 1'b1;
        m_write = 1'b1;
        m_addr  = 32'h0001_0000;
        m_wdata = 32'hDEAD_BEEF;
        m_strb  = 4'b0100;

        gpio_ready = 1'b1;

        #1;

        if (gpio_valid &&
            gpio_write &&
            gpio_addr === 12'h000 &&
            gpio_wdata === 32'hDEAD_BEEF &&
            gpio_strb === 4'b0100)

            $display("PASS: GPIO write/strobe routed correctly");

        else begin
            $display("FAIL: GPIO write routing incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 7 : UNMAPPED READ
        // =====================================================================

        $display("");
        $display("TEST 7 : UNMAPPED READ");

        m_valid = 1'b1;
        m_write = 1'b0;
        m_addr  = 32'h0002_0000;
        m_strb  = 4'h0;

        #1;

        if (!ram_valid &&
            !gpio_valid &&
            !rf_valid &&
            !sensor_valid &&
            !vdp_valid)

            $display("PASS: Unmapped read selects no slave");

        else begin
            $display("FAIL: Unmapped read selected a slave");
            errors = errors + 1;
        end


        if (m_ready === 1'b1 &&
            m_rdata === 32'h0000_0000)

            $display("PASS: Unmapped read completes with zero");

        else begin
            $display("FAIL: Unmapped read response incorrect");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 8 : UNMAPPED WRITE
        // =====================================================================

        $display("");
        $display("TEST 8 : UNMAPPED WRITE");

        m_valid = 1'b1;
        m_write = 1'b1;
        m_addr  = 32'h0002_0000;
        m_wdata = 32'hCAFE_BABE;
        m_strb  = 4'hF;

        #1;

        if (!ram_valid &&
            !gpio_valid &&
            !rf_valid &&
            !sensor_valid &&
            !vdp_valid)

            $display("PASS: Unmapped write selects no slave");

        else begin
            $display("FAIL: Unmapped write selected a slave");
            errors = errors + 1;
        end


        if (m_ready === 1'b1)

            $display("PASS: Unmapped write completes");

        else begin
            $display("FAIL: Unmapped write did not complete");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // TEST 9 : NO OVERLAPPING DECODE
        // =====================================================================

        $display("");
        $display("TEST 9 : NO OVERLAPPING DECODE");

        m_valid = 1'b1;
        m_addr  = 32'h0001_0000;

        #1;

        if ((ram_valid +
             gpio_valid +
             rf_valid +
             sensor_valid +
             vdp_valid) == 1)

            $display("PASS: Exactly one slave selected");

        else begin
            $display("FAIL: Decode overlap detected");
            errors = errors + 1;
        end


        clear_inputs();
        #10;


        // =====================================================================
        // FINAL TEST SUMMARY
        // =====================================================================

        $display("");
        $display("==============================================");

        if (errors == 0) begin
            $display("TB_SOC_MEM_INTERCONNECT");
            $display("ALL TESTS PASSED");
        end
        else begin
            $display("TB_SOC_MEM_INTERCONNECT");
            $display("%0d TEST(S) FAILED", errors);
        end

        $display("==============================================");

        $finish;

    end

endmodule