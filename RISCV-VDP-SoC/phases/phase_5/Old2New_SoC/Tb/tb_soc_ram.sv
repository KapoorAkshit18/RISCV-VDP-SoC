`timescale 1ns/1ps

module tb_soc_ram;

    reg clk;
    reg reset;

    reg        valid;
    reg        write;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg [3:0]  strb;

    wire        ready;
    wire [31:0] rdata;

    soc_ram #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .DEPTH(256)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .valid (valid),
        .write (write),
        .addr  (addr),
        .wdata (wdata),
        .strb  (strb),
        .ready (ready),
        .rdata (rdata)
    );

    always #5 clk = ~clk;

    initial begin

        clk   = 0;
        reset = 1;
        valid = 0;
        write = 0;
        addr  = 0;
        wdata = 0;
        strb  = 0;

        // -------------------------
        // RESET
        // -------------------------
        #20;
        reset = 0;

        // -------------------------
        // TEST 1: RAM WRITE
        // -------------------------
        $display("[TEST] RAM write");

        @(negedge clk);

        valid = 1;
        write = 1;
        addr  = 32'h0000_0000;
        wdata = 32'h1234_ABCD;
        strb  = 4'b1111;

        @(posedge clk);
        #1;

        if (ready)
            $display("[PASS] RAM write accepted");
        else
            $display("[FAIL] RAM write not accepted");

        valid = 0;
        write = 0;

        // -------------------------
        // TEST 2: RAM READ
        // -------------------------
        $display("[TEST] RAM read");

        @(negedge clk);

        valid = 1;
        write = 0;
        addr  = 32'h0000_0000;

        @(posedge clk);
        #1;

        if (ready && rdata == 32'h1234_ABCD)
            $display("[PASS] RAM read returned correct data");
        else
            $display("[FAIL] RAM read: rdata = %h", rdata);

        valid = 0;

        // -------------------------
        // TEST 3: BYTE WRITE
        // -------------------------
        $display("[TEST] Byte write");

        @(negedge clk);

        valid = 1;
        write = 1;
        addr  = 32'h0000_0000;
        wdata = 32'h0000_0055;
        strb  = 4'b0001;

        @(posedge clk);
        #1;

        valid = 0;
        write = 0;

        // Read back
        @(negedge clk);

        valid = 1;
        addr  = 32'h0000_0000;

        @(posedge clk);
        #1;

        if (ready && rdata == 32'h1234_AB55)
            $display("[PASS] Byte write worked");
        else
            $display("[FAIL] Byte write: rdata = %h", rdata);

        valid = 0;

        // -------------------------
        // TEST 4: SECOND LOCATION
        // -------------------------
        $display("[TEST] Second RAM location");

        @(negedge clk);

        valid = 1;
        write = 1;
        addr  = 32'h0000_0004;
        wdata = 32'hDEAD_BEEF;
        strb  = 4'b1111;

        @(posedge clk);
        #1;

        valid = 0;
        write = 0;

        @(negedge clk);

        valid = 1;
        addr  = 32'h0000_0004;

        @(posedge clk);
        #1;

        if (ready && rdata == 32'hDEAD_BEEF)
            $display("[PASS] Second RAM location works");
        else
            $display("[FAIL] Second RAM location: rdata = %h", rdata);

        valid = 0;

        // -------------------------
        // COMPLETE
        // -------------------------
        #20;

        $display("--------------------------------");
        $display("SOC RAM TEST COMPLETE");
        $display("--------------------------------");

        $finish;
    end

endmodule