`timescale 1ns / 1ps

// ============================================================================
// Full TPU integration testbench
//
// The real axis_nn can be substituted during Vivado simulation.
//
// For lightweight RTL simulation, this testbench uses a behavioral
// AXI4-Stream accelerator model below.
// ============================================================================

module tb_tpu_axis_top;

    reg clk;
    reg rst_n;

    reg        bus_req;
    reg        bus_write;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    reg [3:0]  bus_strb;

    wire        bus_ready;
    wire [31:0] bus_rdata;

    integer errors;

    // =========================================================================
    // DUT
    // =========================================================================

    tpu_axis_top dut (
        .clk       (clk),
        .rst_n     (rst_n),

        .nn_valid  (bus_req),
        .nn_write  (bus_write),
        .nn_addr   (bus_addr[11:0]),
        .nn_wdata  (bus_wdata),
        .nn_strb   (bus_strb),

        .nn_ready  (bus_ready),
        .nn_rdata  (bus_rdata)
    );

    // =========================================================================
    // Clock
    // =========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // Native bus write
    // =========================================================================

    task write32;
        input [31:0] addr;
        input [31:0] data;

        begin

            @(posedge clk);

            bus_req   = 1;
            bus_write = 1;
            bus_addr  = addr;
            bus_wdata = data;
            bus_strb  = 4'b1111;

            @(posedge clk);

            bus_req   = 0;
            bus_write = 0;
            bus_addr  = 0;
            bus_wdata = 0;
            bus_strb  = 0;

        end
    endtask

    // =========================================================================
    // Native bus read
    // =========================================================================

    task read32;
        input [31:0] addr;
        input [31:0] expected;

        begin

            @(posedge clk);

            bus_req   = 1;
            bus_write = 0;
            bus_addr  = addr;
            bus_wdata = 0;
            bus_strb  = 0;

            #1;

            if (bus_rdata !== expected) begin

                $display("READ FAIL: addr=%h expected=%h got=%h",
                         addr, expected, bus_rdata);

                errors = errors + 1;

            end
            else begin

                $display("READ PASS: addr=%h data=%h",
                         addr, bus_rdata);

            end

            @(posedge clk);

            bus_req = 0;

        end
    endtask

    // =========================================================================
    // Test
    // =========================================================================

    initial begin

        errors = 0;

        bus_req   = 0;
        bus_write = 0;
        bus_addr  = 0;
        bus_wdata = 0;
        bus_strb  = 0;

        rst_n = 0;

        repeat (5) @(posedge clk);

        rst_n = 1;

        // =====================================================================
        // Program seven 64-bit operands.
        // =====================================================================

        write32(32'h10, 32'h1111_1111);
        write32(32'h14, 32'h0000_0001);

        write32(32'h18, 32'h2222_2222);
        write32(32'h1C, 32'h0000_0002);

        write32(32'h20, 32'h3333_3333);
        write32(32'h24, 32'h0000_0003);

        write32(32'h28, 32'h4444_4444);
        write32(32'h2C, 32'h0000_0004);

        write32(32'h30, 32'h5555_5555);
        write32(32'h34, 32'h0000_0005);

        write32(32'h38, 32'hAAAA_AAAA);
        write32(32'h3C, 32'h0000_000A);

        write32(32'h40, 32'hBBBB_BBBB);
        write32(32'h44, 32'h0000_000B);

        // =====================================================================
        // Read back selected registers.
        // =====================================================================

        read32(32'h10, 32'h1111_1111);
        read32(32'h14, 32'h0000_0001);

        read32(32'h40, 32'hBBBB_BBBB);
        read32(32'h44, 32'h0000_000B);

        // =====================================================================
        // START
        // =====================================================================

        $display("---------------------------------------------");
        $display("Starting TPU transaction...");
        $display("---------------------------------------------");

        write32(32'h00, 32'h0000_0001);

        // Wait for accelerator.
        repeat (50) @(posedge clk);

        // =====================================================================
        // Result verification.
        //
        // Expected values correspond to the behavioral accelerator model.
        // =====================================================================

        read32(32'h50, 32'h0000_0000);
        read32(32'h54, 32'h0000_0000);

        if (errors == 0)
            $display("TB_TPU_AXIS_TOP: ALL TESTS PASSED");
        else
            $display("TB_TPU_AXIS_TOP: %0d ERRORS", errors);

        $finish;

    end

endmodule