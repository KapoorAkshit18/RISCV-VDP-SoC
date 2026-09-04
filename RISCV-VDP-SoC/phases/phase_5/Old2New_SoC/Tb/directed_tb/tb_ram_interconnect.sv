`timescale 1ns/1ps

module tb_ram_interconnect;

    reg clk;
    reg reset;

    // Master side
    reg        m_valid;
    reg        m_write;
    reg [31:0] m_addr;
    reg [31:0] m_wdata;
    reg [3:0]  m_strb;

    wire        m_ready;
    wire [31:0] m_rdata;

    // RAM side
    wire        ram_valid;
    wire        ram_write;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [3:0]  ram_strb;

    wire        ram_ready;
    wire [31:0] ram_rdata;

    // GPIO side
    wire        gpio_valid;
    wire        gpio_write;
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [3:0]  gpio_strb;

    reg         gpio_ready;
    reg  [31:0] gpio_rdata;


    // ------------------------------------------------
    // Interconnect
    // ------------------------------------------------

    soc_mem_interconnect dut_interconnect (

        .m_valid   (m_valid),
        .m_write   (m_write),
        .m_addr    (m_addr),
        .m_wdata   (m_wdata),
        .m_strb    (m_strb),

        .m_ready   (m_ready),
        .m_rdata   (m_rdata),

        .ram_valid (ram_valid),
        .ram_write (ram_write),
        .ram_addr  (ram_addr),
        .ram_wdata (ram_wdata),
        .ram_strb  (ram_strb),

        .ram_ready (ram_ready),
        .ram_rdata (ram_rdata),

        .gpio_valid(gpio_valid),
        .gpio_write(gpio_write),
        .gpio_addr (gpio_addr),
        .gpio_wdata(gpio_wdata),
        .gpio_strb (gpio_strb),

        .gpio_ready(gpio_ready),
        .gpio_rdata(gpio_rdata)
    );


    // ------------------------------------------------
    // RAM
    // ------------------------------------------------

    soc_ram #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .DEPTH(256)
    ) dut_ram (

        .clk   (clk),
        .reset (reset),

        .valid (ram_valid),
        .write (ram_write),
        .addr  (ram_addr),
        .wdata (ram_wdata),
        .strb  (ram_strb),

        .ready (ram_ready),
        .rdata (ram_rdata)
    );


    // ------------------------------------------------
    // Clock
    // ------------------------------------------------

    always #5 clk = ~clk;


    // ------------------------------------------------
    // Test
    // ------------------------------------------------

    initial begin

        clk   = 0;
        reset = 1;

        m_valid = 0;
        m_write = 0;
        m_addr  = 0;
        m_wdata = 0;
        m_strb  = 0;

        gpio_ready = 0;
        gpio_rdata = 0;

        #20;
        reset = 0;


        // ============================================
        // TEST 1: RAM WRITE
        // ============================================

        $display("[TEST] RAM write through interconnect");

        @(negedge clk);

        m_valid = 1;
        m_write = 1;
        m_addr  = 32'h0000_0000;
        m_wdata = 32'h1234_ABCD;
        m_strb  = 4'b1111;

        @(posedge clk);
        #1;

        if (ram_valid &&
            ram_write &&
            ram_addr == 32'h0000_0000 &&
            ram_wdata == 32'h1234_ABCD &&
            m_ready)

            $display("[PASS] RAM write routed correctly");

        else
            $display("[FAIL] RAM write routing");


        m_valid = 0;
        m_write = 0;


        // ============================================
        // TEST 2: RAM READ
        // ============================================

        $display("[TEST] RAM read through interconnect");

        @(negedge clk);

        m_valid = 1;
        m_write = 0;
        m_addr  = 32'h0000_0000;

        @(posedge clk);
        #1;

        if (m_ready && m_rdata == 32'h1234_ABCD)

            $display("[PASS] RAM read returned correct data");

        else

            $display("[FAIL] RAM read: rdata = %h", m_rdata);


        m_valid = 0;


        // ============================================
        // TEST 3: BYTE WRITE
        // ============================================

        $display("[TEST] RAM byte write through interconnect");

        @(negedge clk);

        m_valid = 1;
        m_write = 1;
        m_addr  = 32'h0000_0000;
        m_wdata = 32'h0000_0055;
        m_strb  = 4'b0001;

        @(posedge clk);
        #1;

        m_valid = 0;
        m_write = 0;


        // Read back

        @(negedge clk);

        m_valid = 1;
        m_write = 0;
        m_addr  = 32'h0000_0000;

        @(posedge clk);
        #1;

        if (m_ready && m_rdata == 32'h1234_AB55)

            $display("[PASS] RAM byte write routed correctly");

        else

            $display("[FAIL] RAM byte write: rdata = %h",
                     m_rdata);

        m_valid = 0;


        // ============================================
        // TEST 4: GPIO ADDRESS MUST NOT HIT RAM
        // ============================================

        $display("[TEST] GPIO address does not select RAM");

        @(negedge clk);

        m_valid = 1;
        m_write = 1;
        m_addr  = 32'h4000_0000;
        m_wdata = 32'hAAAA_BBBB;
        m_strb  = 4'b1111;

        #1;

        if (!ram_valid && !m_ready)

            $display("[PASS] GPIO address did not access RAM");

        else

            $display("[FAIL] GPIO address incorrectly accessed RAM");

        m_valid = 0;


        // ============================================
        // TEST 5: INVALID ADDRESS
        // ============================================

        $display("[TEST] Invalid address");

        @(negedge clk);

        m_valid = 1;
        m_write = 0;
        m_addr  = 32'h8000_0000;

        #1;

        if (!ram_valid &&
            !gpio_valid &&
            !m_ready)

            $display("[PASS] Invalid address not routed");

        else

            $display("[FAIL] Invalid address incorrectly routed");

        m_valid = 0;


        #20;

        $display("----------------------------------------");
        $display("RAM + MEMORY INTERCONNECT TEST COMPLETE");
        $display("----------------------------------------");

        $finish;

    end

endmodule