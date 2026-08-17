`ifndef SOC_REG_BLOCK_SV
`define SOC_REG_BLOCK_SV

// ============================================================
// Top-level SoC RAL block
//
// SoC Address Map:
//
//   RAM
//     0x0000_0000 - 0x0000_FFFF
//
//   GPIO
//     0x0001_0000 - 0x0001_0FFF
//
//   RF TELEMETRY
//     0x0001_1000 - 0x0001_1FFF
//
//   SENSOR STATUS
//     0x0001_2000 - 0x0001_2FFF
//
//   VDP
//     0x0001_3000 - 0x0001_3FFF
//
// ============================================================

class soc_reg_block extends uvm_reg_block;

    `uvm_object_utils(soc_reg_block)

    // --------------------------------------------------------
    // Peripheral register blocks
    // --------------------------------------------------------

    gpio_reg_block   gpio;
    rf_reg_block     rf;
    sensor_reg_block sensor;
    vdp_reg_block    vdp;

    // --------------------------------------------------------
    // Top-level address map
    // --------------------------------------------------------

    uvm_reg_map default_map;


    function new(string name = "soc_reg_block");

        super.new(name, UVM_NO_COVERAGE);

    endfunction


    virtual function void build();

        // ====================================================
        // Create GPIO RAL block
        // ====================================================

        gpio =
            gpio_reg_block::type_id::create("gpio");

        gpio.configure(this);
        gpio.build();


        // ====================================================
        // Create RF RAL block
        // ====================================================

        rf =
            rf_reg_block::type_id::create("rf");

        rf.configure(this);
        rf.build();


        // ====================================================
        // Create Sensor RAL block
        // ====================================================

        sensor =
            sensor_reg_block::type_id::create("sensor");

        sensor.configure(this);
        sensor.build();


        // ====================================================
        // Create VDP RAL block
        // ====================================================

        vdp =
            vdp_reg_block::type_id::create("vdp");

        vdp.configure(this);
        vdp.build();


        // ====================================================
        // Create top-level SoC address map
        //
        // Base address = 0x0000_0000
        // Bus width    = 32 bits
        // Endianness   = Little endian
        // ====================================================

        default_map = create_map(
            "default_map",
            32'h0000_0000,
            4,
            UVM_LITTLE_ENDIAN
        );


        // ====================================================
        // Add peripheral submaps
        // ====================================================

        // GPIO
        // 0x0001_0000 - 0x0001_0FFF

        default_map.add_submap(
            gpio.default_map,
            32'h0001_0000
        );


        // RF Telemetry
        // 0x0001_1000 - 0x0001_1FFF

        default_map.add_submap(
            rf.default_map,
            32'h0001_1000
        );


        // Sensor Status
        // 0x0001_2000 - 0x0001_2FFF

        default_map.add_submap(
            sensor.default_map,
            32'h0001_2000
        );


        // VDP
        // 0x0001_3000 - 0x0001_3FFF

        default_map.add_submap(
            vdp.default_map,
            32'h0001_3000
        );


        // ====================================================
        // Lock complete RAL model
        // ====================================================

        lock_model();

    endfunction

endclass

`endif