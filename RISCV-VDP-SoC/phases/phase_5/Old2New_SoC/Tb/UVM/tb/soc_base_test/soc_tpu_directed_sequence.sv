`ifndef SOC_TPU_DIRECTED_SEQUENCE_SV
`define SOC_TPU_DIRECTED_SEQUENCE_SV

`include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"

class soc_tpu_directed_sequence extends uvm_sequence #(soc_sequence_item);

    `uvm_object_utils(soc_tpu_directed_sequence)

    // TPU MMIO map (matches soc_tpu_scoreboard.sv / tb_tpu_scoreboard.sv)
    localparam bit [31:0] TPU_BASE       = 32'h0001_4000;
    localparam bit [31:0] TPU_CONTROL    = TPU_BASE + 32'h0000;
    localparam bit [31:0] TPU_STATUS     = TPU_BASE + 32'h0004;
    localparam bit [31:0] TPU_WEIGHT0_LO = TPU_BASE + 32'h0010;
    localparam bit [31:0] TPU_WEIGHT0_HI = TPU_BASE + 32'h0014;
    localparam bit [31:0] TPU_WEIGHT1_LO = TPU_BASE + 32'h0018;
    localparam bit [31:0] TPU_WEIGHT1_HI = TPU_BASE + 32'h001C;
    localparam bit [31:0] TPU_WEIGHT2_LO = TPU_BASE + 32'h0020;
    localparam bit [31:0] TPU_WEIGHT2_HI = TPU_BASE + 32'h0024;
    localparam bit [31:0] TPU_WEIGHT3_LO = TPU_BASE + 32'h0028;
    localparam bit [31:0] TPU_WEIGHT3_HI = TPU_BASE + 32'h002C;
    localparam bit [31:0] TPU_WEIGHT4_LO = TPU_BASE + 32'h0030;
    localparam bit [31:0] TPU_WEIGHT4_HI = TPU_BASE + 32'h0034;
    localparam bit [31:0] TPU_INPUT0_LO  = TPU_BASE + 32'h0038;
    localparam bit [31:0] TPU_INPUT0_HI  = TPU_BASE + 32'h003C;
    localparam bit [31:0] TPU_INPUT1_LO  = TPU_BASE + 32'h0040;
    localparam bit [31:0] TPU_INPUT1_HI  = TPU_BASE + 32'h0044;
    localparam bit [31:0] TPU_RESULT0_LO = TPU_BASE + 32'h0050;
    localparam bit [31:0] TPU_RESULT0_HI = TPU_BASE + 32'h0054;
    localparam bit [31:0] TPU_RESULT1_LO = TPU_BASE + 32'h0058;
    localparam bit [31:0] TPU_RESULT1_HI = TPU_BASE + 32'h005C;

    localparam int MAX_POLL_ITERS = 1000;

    function new(string name = "soc_tpu_directed_sequence");
        super.new(name);
    endfunction

    task body();

        write32(TPU_WEIGHT0_LO, 32'h0505_057A);
        write32(TPU_WEIGHT0_HI, 32'h0000_B07A);
        write32(TPU_WEIGHT1_LO, 32'h03E1_0314);
        write32(TPU_WEIGHT1_HI, 32'h0000_FC66);
        write32(TPU_WEIGHT2_LO, 32'h028F_0433);
        write32(TPU_WEIGHT2_HI, 32'h0000_FC70);
        write32(TPU_WEIGHT3_LO, 32'hFAC2_1870);
        write32(TPU_WEIGHT3_HI, 32'hF5A3_0051);
        write32(TPU_WEIGHT4_LO, 32'h0685_E399);
        write32(TPU_WEIGHT4_HI, 32'h00CC_07E1);
        write32(TPU_INPUT0_LO,  32'h2000_2000);
        write32(TPU_INPUT0_HI,  32'h1400_1400);
        write32(TPU_INPUT1_LO,  32'h1400_2000);
        write32(TPU_INPUT1_HI,  32'h1400_2000);

        write32(TPU_CONTROL, 32'h0000_0001);   // START

        poll_done();

        read32_status(TPU_RESULT0_LO);
        read32_status(TPU_RESULT0_HI);
        read32_status(TPU_RESULT1_LO);
        read32_status(TPU_RESULT1_HI);

    endtask

    // ---- helpers -------------------------------------------------

    task automatic write32(bit [31:0] addr, bit [31:0] data);
        soc_sequence_item item;
        item = soc_sequence_item::type_id::create("item");
        start_item(item);
        item.addr  = addr;
        item.wdata = data;
        item.write = 1'b1;
        item.strb  = 4'b1111;
        item.set_target();
        finish_item(item);
    endtask

    task automatic read32(bit [31:0] addr, output bit [31:0] data);
        soc_sequence_item item;
        item = soc_sequence_item::type_id::create("item");
        start_item(item);
        item.addr  = addr;
        item.write = 1'b0;
        item.strb  = 4'b0000;
        item.set_target();
        finish_item(item);
        data = item.rdata;
    endtask

    task automatic read32_status(bit [31:0] addr);
        bit [31:0] unused;
        read32(addr, unused);
    endtask

    task automatic poll_done();
        bit [31:0] status;
        int        iters;
        iters = 0;
        do begin
            read32(TPU_STATUS, status);
        `uvm_info("TPU_SEQ", $sformatf("STATUS poll #%0d = 0x%08h", iters, status), UVM_LOW)

            iters++;
        end while (!status[1] && iters < MAX_POLL_ITERS);   // bit1 = DONE

        if (iters >= MAX_POLL_ITERS)
            `uvm_error("TPU_SEQ", "Timed out waiting for TPU DONE")
        
    endtask

endclass

`endif