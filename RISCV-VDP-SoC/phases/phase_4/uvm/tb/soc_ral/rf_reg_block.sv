`ifndef RF_REG_BLOCK_SV
`define RF_REG_BLOCK_SV

// ============================================================
// RF RSSI Register
// Offset : 0x00
// Access : RO
// Reset  : 0x00000000
// ============================================================

class rf_rssi_reg extends uvm_reg;

    `uvm_object_utils(rf_rssi_reg)

    uvm_reg_field rssi;

    function new(string name = "rf_rssi_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        rssi = uvm_reg_field::type_id::create("rssi");

        rssi.configure(
            this,
            32,             // field size
            0,              // lsb position
            "RO",           // access
            0,              // volatile
            32'h00000000,   // reset
            1,              // has reset
            0,              // rand
            0               // individually accessible
        );

    endfunction

endclass


// ============================================================
// RF LINK STATUS Register
// Offset : 0x04
// Access : RO
// Reset  : 0x00000000
// ============================================================

class rf_link_status_reg extends uvm_reg;

    `uvm_object_utils(rf_link_status_reg)

    uvm_reg_field link_status;

    function new(string name = "rf_link_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        link_status = uvm_reg_field::type_id::create("link_status");

        link_status.configure(
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
// RF TELEMETRY REGISTER BLOCK
//
// Local address map:
//
//   0x00  RF_RSSI
//   0x04  RF_LINK_STATUS
//
// SoC base address:
//
//   0x0001_1000
//
// ============================================================

class rf_reg_block extends uvm_reg_block;

    `uvm_object_utils(rf_reg_block)

    // --------------------------------------------------------
    // Registers
    // --------------------------------------------------------

    rf_rssi_reg        rssi;
    rf_link_status_reg link_status;

    // --------------------------------------------------------
    // Address map
    // --------------------------------------------------------

    uvm_reg_map default_map;


    function new(string name = "rf_reg_block");

        super.new(name, UVM_NO_COVERAGE);

    endfunction


    virtual function void build();

        // ----------------------------------------------------
        // Create RSSI register
        // ----------------------------------------------------

        rssi = rf_rssi_reg::type_id::create("rssi");
        rssi.configure(this);
        rssi.build();


        // ----------------------------------------------------
        // Create LINK STATUS register
        // ----------------------------------------------------

        link_status =
            rf_link_status_reg::type_id::create("link_status");

        link_status.configure(this);
        link_status.build();


        // ----------------------------------------------------
        // Create local address map
        // ----------------------------------------------------

        default_map = create_map(
            "default_map",
            32'h0000_0000,
            4,
            UVM_LITTLE_ENDIAN
        );


        // ----------------------------------------------------
        // Add registers using local offsets
        // ----------------------------------------------------

        default_map.add_reg(
            rssi,
            32'h0000_0000,
            "RO"
        );

        default_map.add_reg(
            link_status,
            32'h0000_0004,
            "RO"
        );


        // ----------------------------------------------------
        // Lock RAL model
        // ----------------------------------------------------

        lock_model();

    endfunction

endclass

`endif