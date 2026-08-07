`timescale 1ns/1ps
// =============================================================================
// tb_gpio_native.v -- self-checking testbench for gpio_native_slave
// (PicoRV32 native memory bus, NOT AXI4-Lite)
// Run with: iverilog -o sim_gpio_native tb_gpio_native.v ../rtl/gpio_native_slave.v
//           vvp sim_gpio_native
// =============================================================================
module tb_gpio_native;

    reg clk = 0;
    reg resetn;

    reg         mem_valid;
    reg         mem_instr;
    wire        mem_ready;
    reg  [11:0] mem_addr;
    reg  [31:0] mem_wdata;
    reg  [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    reg  [31:0] gpio_in_tb;
    wire [31:0] gpio_out_tb;
    wire [31:0] gpio_oe_tb;

    integer errors = 0;

    gpio_native_slave #(.GPIO_WIDTH(32)) dut (
        .clk(clk), .resetn(resetn),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .gpio_out(gpio_out_tb), .gpio_oe(gpio_oe_tb), .gpio_in(gpio_in_tb)
    );

    always #5 clk = ~clk; // 100MHz

    // Native-bus helper tasks: hold mem_valid + addr/data stable until mem_ready
    // pulses (this DUT has fixed 1-cycle latency, but the task doesn't assume
    // that -- it just waits for mem_ready like a real PicoRV32 master would).
    task native_write(input [11:0] addr, input [31:0] data, input [3:0] strb);
        begin
            @(posedge clk);
            mem_addr <= addr; mem_wdata <= data; mem_wstrb <= strb; mem_instr <= 1'b0;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            mem_valid <= 1'b0; mem_wstrb <= 4'h0;
            @(posedge clk);
        end
    endtask

    task native_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            mem_addr <= addr; mem_wstrb <= 4'b0000; mem_instr <= 1'b0;
            mem_valid <= 1'b1;
            @(posedge clk);
            while (!mem_ready) @(posedge clk);
            data = mem_rdata;
            mem_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_data;

    initial begin
        resetn = 0; mem_valid = 0; mem_instr = 0; mem_addr = 0; mem_wdata = 0; mem_wstrb = 0;
        gpio_in_tb = 32'hDEAD_BEEF;
        repeat (4) @(posedge clk);
        resetn = 1;
        repeat (2) @(posedge clk);

        // Test 1: fixed 1-cycle latency -- mem_ready must NOT be combinational
        @(posedge clk);
        #1;
        mem_addr <= 12'h008; mem_wdata <= 32'hFFFF_FFFF; mem_wstrb <= 4'hF; mem_valid <= 1'b1;
        if (mem_ready === 1'b0)
            $display("PASS: mem_ready is low the same cycle mem_valid asserts (1-cycle latency, not combinational)");
        else begin $display("FAIL: mem_ready asserted combinationally -- protocol expects 1-cycle latency"); errors=errors+1; end
        @(posedge clk);
        #1;
        if (mem_ready === 1'b1)
            $display("PASS: mem_ready pulses exactly 1 cycle after mem_valid (GPIO_DIR write)");
        else begin $display("FAIL: mem_ready = %b, expected 1", mem_ready); errors=errors+1; end
        mem_valid <= 1'b0; mem_wstrb <= 4'h0;
        @(posedge clk);
            #1;
        // Test 2: DATA_OUT write + readback
        native_write(12'h000, 32'hA5A5_A5A5, 4'hF);
        native_read(12'h000, rd_data);
        if (rd_data === 32'hA5A5_A5A5)
            $display("PASS: GPIO_DATA_OUT readback = %h", rd_data);
        else begin $display("FAIL: GPIO_DATA_OUT readback = %h (expected A5A5A5A5)", rd_data); errors=errors+1; end

        if (gpio_out_tb === 32'hA5A5_A5A5 && gpio_oe_tb === 32'hFFFF_FFFF)
            $display("PASS: gpio_out/gpio_oe pins driven correctly");
        else begin
            $display("FAIL: gpio_out=%h gpio_oe=%h (expected A5A5A5A5 / FFFFFFFF)", gpio_out_tb, gpio_oe_tb);
            errors = errors + 1;
        end

        // Test 3: DATA_IN reflects external pins after synchronizer settles
        native_read(12'h004, rd_data);
        if (rd_data === 32'hDEAD_BEEF)
            $display("PASS: GPIO_DATA_IN = %h", rd_data);
        else begin $display("FAIL: GPIO_DATA_IN = %h (expected DEADBEEF)", rd_data); errors=errors+1; end

        // Test 4: byte-lane write strobes (mem_wstrb partial write)
        native_write(12'h000, 32'h0000_0000, 4'hF); // clear
        native_write(12'h000, 32'h00FF_0000, 4'b0100); // only byte 2
        native_read(12'h000, rd_data);
        if (rd_data === 32'h00FF_0000)
            $display("PASS: byte-lane write strobe (wstrb=0100) applied correctly, DATA_OUT=%h", rd_data);
        else begin $display("FAIL: DATA_OUT = %h after partial write (expected 00FF0000)", rd_data); errors=errors+1; end

        // Test 5: write_pulse self-clears (checked one cycle after commit, before we poll it)
        native_write(12'h000, 32'h0000_0001, 4'hF);
        native_read(12'h00C, rd_data);
        if (rd_data[0] === 1'b0)
            $display("PASS: GPIO_STATUS write_pulse correctly self-clears (=%b)", rd_data[0]);
        else begin $display("FAIL: GPIO_STATUS write_pulse did not clear (=%b)", rd_data[0]); errors=errors+1; end

        // Test 6: unmapped offset reads 0, mem_ready still fires (no error channel in this protocol)
        native_read(12'h0FC, rd_data);
        if (rd_data === 32'h0)
            $display("PASS: unmapped offset 0xFC reads 0, mem_ready still completed the cycle");
        else begin $display("FAIL: unmapped offset 0xFC returned %h (expected 0)", rd_data); errors=errors+1; end

        // Test 7: synchronous reset behavior
        resetn = 0;
        @(posedge clk);
        #1;
        resetn = 1;
        repeat (2) @(posedge clk);
        native_read(12'h000, rd_data);
        if (rd_data === 32'h0)
            $display("PASS: GPIO_DATA_OUT resets to 0");
        else begin $display("FAIL: GPIO_DATA_OUT after reset = %h (expected 0)", rd_data); errors=errors+1; end

        if (errors == 0)
            $display("==== TB_GPIO_NATIVE: ALL TESTS PASSED ====");
        else
            $display("==== TB_GPIO_NATIVE: %0d TEST(S) FAILED ====", errors);

        $finish;
    end

endmodule
