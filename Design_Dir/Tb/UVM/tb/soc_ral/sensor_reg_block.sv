`ifndef SENSOR_REG_BLOCK_SV
`define SENSOR_REG_BLOCK_SV

// ============================================================
// SENSOR BATTERY PERCENT REGISTER
// Offset : 0x00
// Access : RO
// Reset  : 0x00000000
// ============================================================

class sensor_battery_percent_reg extends uvm_reg;

    `uvm_object_utils(sensor_battery_percent_reg)

    uvm_reg_field battery_percent;

    function new(string name = "sensor_battery_percent_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        battery_percent =
            uvm_reg_field::type_id::create("battery_percent");

        battery_percent.configure(
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
// SENSOR BATTERY VOLTAGE REGISTER
// Offset : 0x04
// Access : RO
// Reset  : 0x00000000
// ============================================================

class sensor_battery_voltage_reg extends uvm_reg;

    `uvm_object_utils(sensor_battery_voltage_reg)

    uvm_reg_field battery_voltage;

    function new(string name = "sensor_battery_voltage_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        battery_voltage =
            uvm_reg_field::type_id::create("battery_voltage");

        battery_voltage.configure(
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
// SENSOR TEMPERATURE REGISTER
// Offset : 0x08
// Access : RO
// Reset  : 0x00000000
// ============================================================

class sensor_temperature_reg extends uvm_reg;

    `uvm_object_utils(sensor_temperature_reg)

    uvm_reg_field temperature;

    function new(string name = "sensor_temperature_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();

        temperature =
            uvm_reg_field::type_id::create("temperature");

        temperature.configure(
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
// SENSOR STATUS REGISTER BLOCK
//
// Local address map:
//
//   0x00  BATTERY_PERCENT
//   0x04  BATTERY_VOLTAGE
//   0x08  TEMPERATURE
//
// SoC base:
//
//   0x0001_2000
// ============================================================

class sensor_reg_block extends uvm_reg_block;

    `uvm_object_utils(sensor_reg_block)

    // --------------------------------------------------------
    // Registers
    // --------------------------------------------------------

    sensor_battery_percent_reg battery_percent;
    sensor_battery_voltage_reg battery_voltage;
    sensor_temperature_reg     temperature;

    // --------------------------------------------------------
    // Address map
    // --------------------------------------------------------

    uvm_reg_map default_map;// name 


    function new(string name = "sensor_reg_block");

        super.new(name, UVM_NO_COVERAGE);

    endfunction


    virtual function void build();

        // ----------------------------------------------------
        // Battery percentage
        // ----------------------------------------------------

        battery_percent =
            sensor_battery_percent_reg::type_id::create(
                "battery_percent"
            );

        battery_percent.configure(this);
        battery_percent.build();


        // ----------------------------------------------------
        // Battery voltage
        // ----------------------------------------------------

        battery_voltage =
            sensor_battery_voltage_reg::type_id::create(
                "battery_voltage"
            );

        battery_voltage.configure(this);
        battery_voltage.build();  // module build 


        // ----------------------------------------------------
        // Temperature
        // ----------------------------------------------------

        temperature =
            sensor_temperature_reg::type_id::create(
                "temperature"
            );

        temperature.configure(this);
        temperature.build();


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
        // Add registers
        // ----------------------------------------------------

        default_map.add_reg(
            battery_percent,
            32'h0000_0000,
            "RO"
        );

        default_map.add_reg(
            battery_voltage,
            32'h0000_0004,
            "RO"
        );

        default_map.add_reg(
            temperature,
            32'h0000_0008,
            "RO"
        );


        // ----------------------------------------------------
        // Lock RAL model
        // ----------------------------------------------------

        lock_model();

    endfunction

endclass

`endif