//`timescale 1ns / 1ps

module tb_ptb();

    // --------------------------------------------------------
    // Clock & Reset Signals
    // --------------------------------------------------------
    reg clk;
    reg resetn;

    // --------------------------------------------------------
    // Native Memory Interface Wires
    // --------------------------------------------------------
    wire        trap;
    wire        mem_valid;
    wire        mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;

    reg         mem_ready;
    reg  [31:0] mem_rdata;

    // --------------------------------------------------------
    // Mock Memory Array
    // --------------------------------------------------------
    reg [31:0] memory [0:255];

    // --------------------------------------------------------
    // Instantiate Wrapper (DUT)
    // --------------------------------------------------------
    ptb uut (
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

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0,tb_ptb_rv32i_full);
   
    
  end
    // --------------------------------------------------------
    // 100 MHz Clock Generator
    // --------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --------------------------------------------------------
    // Machine Code Initialization & Execution Sequence
    // --------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 32'h0;

        // --- 1. Upper Immediates ---
        memory[0]  = 32'h123450b7; // 0x00: lui   x1, 0x12345        (x1  = 0x12345000)
        memory[1]  = 32'h00000117; // 0x04: auipc x2, 0              (x2  = 0x00000004)

        // --- 2. Register-Immediate ALU Operations ---
        memory[2]  = 32'h01300193; // 0x08: addi  x3, x0, 19         (x3  = 19)
        memory[3]  = 32'hfff02213; // 0x0C: slti  x4, x0, -1         (x4  = 0)
        memory[4]  = 32'h00103293; // 0x10: sltiu x5, x0, 1          (x5  = 1)
        memory[5]  = 32'h00f1c313; // 0x14: xori  x6, x3, 15         (x6  = 19 ^ 15 = 20)
        memory[6]  = 32'h0f036393; // 0x18: ori   x7, x6, 240        (x7  = 20 | 240 = 244)
        memory[7]  = 32'h00f3f413; // 0x1C: andi  x8, x7, 15         (x8  = 244 & 15 = 4)
        memory[8]  = 32'h00241493; // 0x20: slli  x9, x8, 2          (x9  = 16)
        memory[9]  = 32'h0014d513; // 0x24: srli  x10, x9, 1         (x10 = 8)
        memory[10] = 32'h4014d593; // 0x28: srai  x11, x9, 1         (x11 = 8)

        // --- 3. Register-Register ALU Operations ---
        memory[11] = 32'h00a18633; // 0x2C: add   x12, x3, x10       (x12 = 19 + 8 = 27)
        memory[12] = 32'h40a186b3; // 0x30: sub   x13, x3, x10       (x13 = 19 - 8 = 11)
        memory[13] = 32'h00849733; // 0x34: sll   x14, x9, x8        (x14 = 16 << 4 = 256)
        memory[14] = 32'h00a6a7b3; // 0x38: slt   x15, x13, x10      (x15 = 11 < 8 = 0)
        memory[15] = 32'h00a6b833; // 0x3C: sltu  x16, x13, x10      (x16 = 11 < 8 = 0)
        memory[16] = 32'h00a6c8b3; // 0x40: xor   x17, x13, x10      (x17 = 11 ^ 8 = 3)
        memory[17] = 32'h00875933; // 0x44: srl   x18, x14, x8       (x18 = 256 >> 4 = 16)
        memory[18] = 32'h408759b3; // 0x48: sra   x19, x14, x8       (x19 = 256 >>> 4 = 16)
        memory[19] = 32'h00a6ea33; // 0x4C: or    x20, x13, x10      (x20 = 11 | 8 = 11)
        memory[20] = 32'h00a6fab3; // 0x50: and   x21, x13, x10      (x21 = 11 & 8 = 8)

        // --- 4. Load & Store Operations ---
        memory[21] = 32'h07402023; // 0x54: sw    x20, 96(x0)        (store word 11 at 0x60)
        memory[22] = 32'h06002b03; // 0x58: lw    x22, 96(x0)        (x22 = 11)
        memory[23] = 32'h07101223; // 0x5C: sh    x17, 100(x0)       (store halfword 16 at 0x64)
        memory[24] = 32'h06401b83; // 0x60: lh    x23, 100(x0)       (x23 = 16)
        memory[25] = 32'h06405c03; // 0x64: lhu   x24, 100(x0)       (x24 = 16)
        memory[26] = 32'h07500323; // 0x68: sb    x21, 102(x0)       (store byte 8 at 0x66)        memory[26] = 32'h07500323; // 0x68: sb    x21, 102(x0)       (store byte 8 at 0x66)
        memory[27] = 32'h06600ca3; // 0x6C: lb    x25, 102(x0)       (x25 = 8)
        memory[28] = 32'h06604d23; // 0x70: lbu   x26, 102(x0)       (x26 = 8)

        // --- 5. Branch Operations ---
        memory[29] = 32'h00000463; // 0x74: beq   x0, x0, +8         (taken -> jump to 0x7C)
        memory[30] = 32'h00000000; // 0x78: [FAIL GUARD - Illegal instruction]
        memory[31] = 32'h00519463; // 0x7C: bne   x3, x5, +8         (19 != 1 -> taken -> jump to 0x84)
        memory[32] = 32'h00000000; // 0x80: [FAIL GUARD - Illegal instruction]
        memory[33] = 32'h0032c063; // 0x84: blt   x5, x3, +8         (1 < 19 -> taken -> jump to 0x8C)
        memory[34] = 32'h00000000; // 0x88: [FAIL GUARD]
        memory[35] = 32'h0051d063; // 0x8C: bge   x3, x5, +8         (19 >= 1 -> taken -> jump to 0x94)
        memory[36] = 32'h00000000; // 0x90: [FAIL GUARD]
        memory[37] = 32'h0032e063; // 0x94: bltu  x5, x3, +8         (1 < 19 unsigned -> taken -> jump to 0x9C)
        memory[38] = 32'h00000000; // 0x98: [FAIL GUARD]
        memory[39] = 32'h0051f063; // 0x9C: bgeu  x3, x5, +8         (19 >= 1 unsigned -> taken -> jump to 0x0A4)
        memory[40] = 32'h00000000; // 0x0A0: [FAIL GUARD]

        // --- 6. Jump Operations ---
        memory[41] = 32'h00800de7; // 0x0A4: jal  x27, +8            (jump to 0x0AC, link to x27)
        memory[42] = 32'h00000000; // 0x0A8: [FAIL GUARD]
        memory[43] = 32'h00000e67; // 0x0AC: jalr x28, x0, 180       (jump to 180 = 0x0B4, link to x28)
        memory[44] = 32'h00000000; // 0x0B0: [FAIL GUARD]
        memory[45] = 32'h00000000; // 0x0B4: Illegal Instruction (Terminates Verification cleanly)

        mem_ready = 0;
        mem_rdata = 0;

        resetn = 0;
        #50;
        resetn = 1;
        $display("[TEST START] RV32I Full Instruction Verification Running...");

        wait(trap == 1);
        $display("[%0t] [TRAP ASSERTED] Core execution halted at PC=0x%08x.", $time, uut.prv.reg_pc);
        $finish;
    end

    // --------------------------------------------------------
    // Slave Responder & Instruction Monitor
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 0;
        end else begin
            mem_ready <= 0;

            if (mem_valid && !mem_ready) begin
                mem_ready <= 1;

                if (mem_wstrb == 0) begin
                    mem_rdata <= memory[mem_addr >> 2];
                    if (mem_instr)
                        $display("[%0t] [FETCH] PC=0x%08x | Instruction=0x%08x", $time, mem_addr, memory[mem_addr >> 2]);
                    else
                        $display("[%0t] [READ]  Addr=0x%08x | Data=0x%08x", $time, mem_addr, memory[mem_addr >> 2]);
                end else begin
                    if (mem_wstrb[0]) memory[mem_addr >> 2][7:0]   <= mem_wdata[7:0];
                    if (mem_wstrb[1]) memory[mem_addr >> 2][15:8]  <= mem_wdata[15:8];
                    if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
                    $display("[%0t] [WRITE] Addr=0x%08x | Data=0x%08x | Strobe=%b", $time, mem_addr, mem_wdata, mem_wstrb);
                end
            end
        end
    end

endmodule