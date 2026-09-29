`ifndef TPU_REG_BLOCK_SV
`define TPU_REG_BLOCK_SV

// =============================================================================
// RISCV-VDP-SoC
// UVM RAL Block - TPU / NN
// =============================================================================

// -----------------------------------------------------------------------------
// CTRL Register
// Offset: 0x00
// -----------------------------------------------------------------------------
class tpu_reg_ctrl extends uvm_reg;
    `uvm_object_utils(tpu_reg_ctrl)

    uvm_reg_field start;

    function new(string name = "tpu_reg_ctrl");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        start = uvm_reg_field::type_id::create("start");
        // name, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible
        start.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// -----------------------------------------------------------------------------
// STATUS Register
// Offset: 0x04
// -----------------------------------------------------------------------------
class tpu_reg_status extends uvm_reg;
    `uvm_object_utils(tpu_reg_status)

    uvm_reg_field busy;
    uvm_reg_field done;

    function new(string name = "tpu_reg_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        done = uvm_reg_field::type_id::create("done");

        busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
        done.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    endfunction
endclass

// -----------------------------------------------------------------------------
// Generic 32-bit Data Register (RW)
// Used for W0-W4 and INPUT0-1
// -----------------------------------------------------------------------------
class tpu_reg_data extends uvm_reg;
    `uvm_object_utils(tpu_reg_data)

    uvm_reg_field val;

    function new(string name = "tpu_reg_data");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        val = uvm_reg_field::type_id::create("val");
        val.configure(this, 32, 0, "RW", 0, 32'h00000000, 1, 1, 0);
    endfunction
endclass

// -----------------------------------------------------------------------------
// Generic 32-bit Result Register (RO)
// Used for RESULT0-1
// -----------------------------------------------------------------------------
class tpu_reg_result extends uvm_reg;
    `uvm_object_utils(tpu_reg_result)

    uvm_reg_field val;

    function new(string name = "tpu_reg_result");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        val = uvm_reg_field::type_id::create("val");
        val.configure(this, 32, 0, "RO", 1, 32'h00000000, 1, 0, 0);
    endfunction
endclass

// -----------------------------------------------------------------------------
// TPU Register Block
// -----------------------------------------------------------------------------
class tpu_reg_block extends uvm_reg_block;
    `uvm_object_utils(tpu_reg_block)

    tpu_reg_ctrl   ctrl;
    tpu_reg_status status;

    tpu_reg_data   weight0_l;
    tpu_reg_data   weight0_h;
    tpu_reg_data   weight1_l;
    tpu_reg_data   weight1_h;
    tpu_reg_data   weight2_l;
    tpu_reg_data   weight2_h;
    tpu_reg_data   weight3_l;
    tpu_reg_data   weight3_h;
    tpu_reg_data   weight4_l;
    tpu_reg_data   weight4_h;

    tpu_reg_data   input0_l;
    tpu_reg_data   input0_h;
    tpu_reg_data   input1_l;
    tpu_reg_data   input1_h;

    tpu_reg_result result0_l;
    tpu_reg_result result0_h;
    tpu_reg_result result1_l;
    tpu_reg_result result1_h;

    uvm_reg_map default_map;

    function new(string name = "tpu_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);

        // Control / Status
        ctrl = tpu_reg_ctrl::type_id::create("ctrl");
        ctrl.configure(this, null, "");
        ctrl.build();
        default_map.add_reg(ctrl, 32'h00, "RW");

        status = tpu_reg_status::type_id::create("status");
        status.configure(this, null, "");
        status.build();
        default_map.add_reg(status, 32'h04, "RO");

        // Weights
        weight0_l = tpu_reg_data::type_id::create("weight0_l");
        weight0_l.configure(this, null, "");
        weight0_l.build();
        default_map.add_reg(weight0_l, 32'h10, "RW");

        weight0_h = tpu_reg_data::type_id::create("weight0_h");
        weight0_h.configure(this, null, "");
        weight0_h.build();
        default_map.add_reg(weight0_h, 32'h14, "RW");

        weight1_l = tpu_reg_data::type_id::create("weight1_l");
        weight1_l.configure(this, null, "");
        weight1_l.build();
        default_map.add_reg(weight1_l, 32'h18, "RW");

        weight1_h = tpu_reg_data::type_id::create("weight1_h");
        weight1_h.configure(this, null, "");
        weight1_h.build();
        default_map.add_reg(weight1_h, 32'h1C, "RW");

        weight2_l = tpu_reg_data::type_id::create("weight2_l");
        weight2_l.configure(this, null, "");
        weight2_l.build();
        default_map.add_reg(weight2_l, 32'h20, "RW");

        weight2_h = tpu_reg_data::type_id::create("weight2_h");
        weight2_h.configure(this, null, "");
        weight2_h.build();
        default_map.add_reg(weight2_h, 32'h24, "RW");

        weight3_l = tpu_reg_data::type_id::create("weight3_l");
        weight3_l.configure(this, null, "");
        weight3_l.build();
        default_map.add_reg(weight3_l, 32'h28, "RW");

        weight3_h = tpu_reg_data::type_id::create("weight3_h");
        weight3_h.configure(this, null, "");
        weight3_h.build();
        default_map.add_reg(weight3_h, 32'h2C, "RW");

        weight4_l = tpu_reg_data::type_id::create("weight4_l");
        weight4_l.configure(this, null, "");
        weight4_l.build();
        default_map.add_reg(weight4_l, 32'h30, "RW");

        weight4_h = tpu_reg_data::type_id::create("weight4_h");
        weight4_h.configure(this, null, "");
        weight4_h.build();
        default_map.add_reg(weight4_h, 32'h34, "RW");

        // Inputs
        input0_l = tpu_reg_data::type_id::create("input0_l");
        input0_l.configure(this, null, "");
        input0_l.build();
        default_map.add_reg(input0_l, 32'h38, "RW");

        input0_h = tpu_reg_data::type_id::create("input0_h");
        input0_h.configure(this, null, "");
        input0_h.build();
        default_map.add_reg(input0_h, 32'h3C, "RW");

        input1_l = tpu_reg_data::type_id::create("input1_l");
        input1_l.configure(this, null, "");
        input1_l.build();
        default_map.add_reg(input1_l, 32'h40, "RW");

        input1_h = tpu_reg_data::type_id::create("input1_h");
        input1_h.configure(this, null, "");
        input1_h.build();
        default_map.add_reg(input1_h, 32'h44, "RW");

        // Results
        result0_l = tpu_reg_result::type_id::create("result0_l");
        result0_l.configure(this, null, "");
        result0_l.build();
        default_map.add_reg(result0_l, 32'h50, "RO");

        result0_h = tpu_reg_result::type_id::create("result0_h");
        result0_h.configure(this, null, "");
        result0_h.build();
        default_map.add_reg(result0_h, 32'h54, "RO");

        result1_l = tpu_reg_result::type_id::create("result1_l");
        result1_l.configure(this, null, "");
        result1_l.build();
        default_map.add_reg(result1_l, 32'h58, "RO");

        result1_h = tpu_reg_result::type_id::create("result1_h");
        result1_h.configure(this, null, "");
        result1_h.build();
        default_map.add_reg(result1_h, 32'h5C, "RO");

        lock_model();
    endfunction
endclass

`endif
