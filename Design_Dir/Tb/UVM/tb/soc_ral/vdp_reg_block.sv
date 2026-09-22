`ifndef VDP_REG_BLOCK_SV
`define VDP_REG_BLOCK_SV


// ============================================================
// VDP CTRL REGISTER
//
// Offset : 0x000
// Access : RW
//
// bit [0] : display_enable
// bit [1] : pattern_mode
// bit [31:2] : Reserved
// ============================================================

class vdp_ctrl_reg extends uvm_reg;

    `uvm_object_utils(vdp_ctrl_reg)

    uvm_reg_field display_enable;
    uvm_reg_field pattern_mode;

    function new(string name = "vdp_ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        display_enable =
            uvm_reg_field::type_id::create("display_enable");

        display_enable.configure(
            this,
            1,
            0,
            "RW",
            0,
            1'b0,
            1,
            1,
            0
        );


        pattern_mode =
            uvm_reg_field::type_id::create("pattern_mode");

        pattern_mode.configure(
            this,
            1,
            1,
            "RW",
            0,
            1'b0,
            1,
            1,
            0
        );

    endfunction

endclass


// ============================================================
// VDP STATUS REGISTER
//
// Offset : 0x004
//
// bit [0] : hsync active       RO
// bit [1] : vsync active       RO
// bit [2] : video active       RO
// bit [3] : frame flag         W1C
// bit [31:4] : Reserved        RO
// ============================================================

class vdp_status_reg extends uvm_reg;

    `uvm_object_utils(vdp_status_reg)

    uvm_reg_field hsync_active;
    uvm_reg_field vsync_active;
    uvm_reg_field video_active;
    uvm_reg_field frame_flag;
    uvm_reg_field reserved;

    function new(string name = "vdp_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        hsync_active =
            uvm_reg_field::type_id::create("hsync_active");

        hsync_active.configure(
            this,
            1,
            0,
            "RO",
            1,
            1'b0,
            1,
            0,
            0
        );


        vsync_active =
            uvm_reg_field::type_id::create("vsync_active");

        vsync_active.configure(
            this,
            1,
            1,
            "RO",
            1,
            1'b0,
            1,
            0,
            0
        );


        video_active =
            uvm_reg_field::type_id::create("video_active");

        video_active.configure(
            this,
            1,
            2,
            "RO",
            1,
            1'b0,
            1,
            0,
            0
        );


        frame_flag =
            uvm_reg_field::type_id::create("frame_flag");

        frame_flag.configure(
            this,
            1,
            3,
            "W1C",
            1,
            1'b0,
            1,
            0,
            0
        );


        reserved =
            uvm_reg_field::type_id::create("reserved");

        reserved.configure(
            this,
            28,
            4,
            "RO",
            0,
            28'h0,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// VDP HCOUNT REGISTER
//
// Offset : 0x008
// Access : RO
//
// bit [11:0] : horizontal pixel counter
// bit [31:12] : Reserved
// ============================================================

class vdp_hcount_reg extends uvm_reg;

    `uvm_object_utils(vdp_hcount_reg)

    uvm_reg_field hcount;
    uvm_reg_field reserved;

    function new(string name = "vdp_hcount_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        hcount =
            uvm_reg_field::type_id::create("hcount");

        hcount.configure(
            this,
            12,
            0,
            "RO",
            1,
            12'h000,
            1,
            0,
            0
        );


        reserved =
            uvm_reg_field::type_id::create("reserved");

        reserved.configure(
            this,
            20,
            12,
            "RO",
            0,
            20'h0,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// VDP VCOUNT REGISTER
//
// Offset : 0x00C
// Access : RO
//
// bit [11:0] : vertical pixel counter
// bit [31:12] : Reserved
// ============================================================

class vdp_vcount_reg extends uvm_reg;

    `uvm_object_utils(vdp_vcount_reg)

    uvm_reg_field vcount;
    uvm_reg_field reserved;

    function new(string name = "vdp_vcount_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        vcount =
            uvm_reg_field::type_id::create("vcount");

        vcount.configure(
            this,
            12,
            0,
            "RO",
            1,
            12'h000,
            1,
            0,
            0
        );


        reserved =
            uvm_reg_field::type_id::create("reserved");

        reserved.configure(
            this,
            20,
            12,
            "RO",
            0,
            20'h0,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// VDP COLOR REGISTER
//
// Offset : 0x010
// Access : RW
//
// bit [23:16] : Red
// bit [15:8]  : Green
// bit [7:0]   : Blue
// bit [31:24] : Reserved
// ============================================================

class vdp_color_reg extends uvm_reg;

    `uvm_object_utils(vdp_color_reg)

    uvm_reg_field blue;
    uvm_reg_field green;
    uvm_reg_field red;
    uvm_reg_field reserved;

    function new(string name = "vdp_color_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        blue =
            uvm_reg_field::type_id::create("blue");

        blue.configure(
            this,
            8,
            0,
            "RW",
            0,
            8'hFF,
            1,
            1,
            0
        );


        green =
            uvm_reg_field::type_id::create("green");

        green.configure(
            this,
            8,
            8,
            "RW",
            0,
            8'hFF,
            1,
            1,
            0
        );


        red =
            uvm_reg_field::type_id::create("red");

        red.configure(
            this,
            8,
            16,
            "RW",
            0,
            8'hFF,
            1,
            1,
            0
        );


        reserved =
            uvm_reg_field::type_id::create("reserved");

        reserved.configure(
            this,
            8,
            24,
            "RO",
            0,
            8'h00,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// VDP REGISTER BLOCK
//
// Local address map:
//
//   0x000  VDP_CTRL
//   0x004  VDP_STATUS
//   0x008  VDP_HCOUNT
//   0x00C  VDP_VCOUNT
//   0x010  VDP_COLOR
//
// SoC base:
//
//   0x0001_3000
// ============================================================

class vdp_reg_block extends uvm_reg_block;

    `uvm_object_utils(vdp_reg_block)

    // --------------------------------------------------------
    // Registers
    // --------------------------------------------------------

    vdp_ctrl_reg   ctrl;
    vdp_status_reg status;
    vdp_hcount_reg hcount;
    vdp_vcount_reg vcount;
    vdp_color_reg  color;

    // --------------------------------------------------------
    // Address map
    // --------------------------------------------------------

    uvm_reg_map default_map;


    function new(string name = "vdp_reg_block");

        super.new(name, UVM_NO_COVERAGE);

    endfunction


    virtual function void build();

        // ----------------------------------------------------
        // CTRL
        // ----------------------------------------------------

        ctrl =
            vdp_ctrl_reg::type_id::create("ctrl");

        ctrl.configure(this);
        ctrl.build();


        // ----------------------------------------------------
        // STATUS
        // ----------------------------------------------------

        status =
            vdp_status_reg::type_id::create("status");

        status.configure(this);
        status.build();


        // ----------------------------------------------------
        // HCOUNT
        // ----------------------------------------------------

        hcount =
            vdp_hcount_reg::type_id::create("hcount");

        hcount.configure(this);
        hcount.build();


        // ----------------------------------------------------
        // VCOUNT
        // ----------------------------------------------------

        vcount =
            vdp_vcount_reg::type_id::create("vcount");

        vcount.configure(this);
        vcount.build();


        // ----------------------------------------------------
        // COLOR
        // ----------------------------------------------------

        color =
            vdp_color_reg::type_id::create("color");

        color.configure(this);
        color.build();


        // ----------------------------------------------------
        // Local address map
        // ----------------------------------------------------

        default_map = create_map(
            "default_map",
            32'h0000_0000,
            4,
            UVM_LITTLE_ENDIAN
        );


        // ----------------------------------------------------
        // Register offsets
        // ----------------------------------------------------

        default_map.add_reg(
            ctrl,
            32'h0000_0000,
            "RW"
        );

        default_map.add_reg(
            status,
            32'h0000_0004,
            "RO"
        );

        default_map.add_reg(
            hcount,
            32'h0000_0008,
            "RO"
        );

        default_map.add_reg(
            vcount,
            32'h0000_000C,
            "RO"
        );

        default_map.add_reg(
            color,
            32'h0000_0010,
            "RW"
        );


        // ----------------------------------------------------
        // Lock model
        // ----------------------------------------------------

        lock_model();

    endfunction

endclass

`endif