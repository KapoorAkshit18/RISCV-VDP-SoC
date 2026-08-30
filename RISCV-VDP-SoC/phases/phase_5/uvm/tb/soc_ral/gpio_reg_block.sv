`ifndef GPIO_REG_BLOCK_SV
`define GPIO_REG_BLOCK_SV

// ============================================================
// GPIO_DATA_OUT Register
// Offset : 0x00
// Access : RW
// Reset  : 0x00000000
// ============================================================

class gpio_data_out_reg extends uvm_reg;

    `uvm_object_utils(gpio_data_out_reg)

    uvm_reg_field data;

    function new(string name = "gpio_data_out_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        data = uvm_reg_field::type_id::create("data");

        data.configure(
            this,
            32,             // field size
            0,              // lsb position
            "RW",           // access
            0,              // volatile
            32'h00000000,   // reset value
            1,              // has reset
            1,              // is rand
            0               // individually accessible
        );

    endfunction

endclass


// ============================================================
// GPIO_DATA_IN Register
// Offset : 0x04
// Access : RO
// Reset  : 0x00000000
// ============================================================

class gpio_data_in_reg extends uvm_reg;

    `uvm_object_utils(gpio_data_in_reg)

    uvm_reg_field data;

    function new(string name = "gpio_data_in_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        data = uvm_reg_field::type_id::create("data");

        data.configure(
            this,
            32,
            0,
            "RO",
            0,
            32'h00000000,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// GPIO_DIR Register
// Offset : 0x08
// Access : RW
// Reset  : 0x00000000
// ============================================================

class gpio_dir_reg extends uvm_reg;

    `uvm_object_utils(gpio_dir_reg)

    uvm_reg_field direction;

    function new(string name = "gpio_dir_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        direction = uvm_reg_field::type_id::create("direction");

        direction.configure(
            this,
            32,
            0,
            "RW",
            0,
            32'h00000000,
            1,
            1,
            0
        );

    endfunction

endclass


// ============================================================
// GPIO_STATUS Register
// Offset : 0x0C
// Access : RO
// Reset  : 0x00000000
// ============================================================

class gpio_status_reg extends uvm_reg;

    `uvm_object_utils(gpio_status_reg)

    uvm_reg_field status;

    function new(string name = "gpio_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        status = uvm_reg_field::type_id::create("status");

        status.configure(
            this,
            32,
            0,
            "RO",
            0,
            32'h00000000,
            1,
            0,
            0
        );

    endfunction

endclass


// ============================================================
// GPIO Register Block
//
// Local GPIO address map:
//   0x00 GPIO_DATA_OUT   RW
//   0x04 GPIO_DATA_IN    RO
//   0x08 GPIO_DIR        RW
//   0x0C GPIO_STATUS     RO
//
// SoC base address:
//   0x0001_0000
//
// ============================================================

class gpio_reg_block extends uvm_reg_block;

    `uvm_object_utils(gpio_reg_block)

    // --------------------------------------------------------
    // Registers
    // --------------------------------------------------------

    gpio_data_out_reg data_out;
    gpio_data_in_reg  data_in;
    gpio_dir_reg      dir;
    gpio_status_reg   status;

    // --------------------------------------------------------
    // Address map
    // --------------------------------------------------------

    uvm_reg_map default_map;


    function new(string name = "gpio_reg_block");

        super.new(name, UVM_NO_COVERAGE);

    endfunction


    virtual function void build();

        // ----------------------------------------------------
        // Create registers
        // ----------------------------------------------------

        data_out = gpio_data_out_reg::type_id::create("data_out");
        data_out.configure(this);
        data_out.build();

        data_in = gpio_data_in_reg::type_id::create("data_in");
        data_in.configure(this);
        data_in.build();

        dir = gpio_dir_reg::type_id::create("dir");
        dir.configure(this);
        dir.build();

        status = gpio_status_reg::type_id::create("status");
        status.configure(this);
        status.build();


        // ----------------------------------------------------
        // Create local GPIO address map
        //
        // Base = 0x000
        // Bus width = 32 bits = 4 bytes
        // ----------------------------------------------------

        default_map = create_map(
            "default_map",
            32'h00000000,
            4,
            UVM_LITTLE_ENDIAN
        );


        // ----------------------------------------------------
        // Add registers
        // ----------------------------------------------------

        default_map.add_reg(
            data_out,
            32'h00000000,
            "RW"
        );

        default_map.add_reg(
            data_in,
            32'h00000004,
            "RO"
        );

        default_map.add_reg(
            dir,
            32'h00000008,
            "RW"
        );

        default_map.add_reg(
            status,
            32'h0000000C,
            "RO"
        );


        // ----------------------------------------------------
        // Finalize RAL model
        // ----------------------------------------------------

        lock_model();

    endfunction

endclass

`endif