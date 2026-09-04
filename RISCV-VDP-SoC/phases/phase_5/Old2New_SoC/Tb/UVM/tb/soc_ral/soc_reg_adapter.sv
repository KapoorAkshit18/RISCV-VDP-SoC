`ifndef SOC_REG_ADAPTER_SV
`define SOC_REG_ADAPTER_SV

// =============================================================================
// RISCV-VDP-SoC
// UVM RAL Adapter
//
// Converts:
//
//     UVM RAL transaction
//              |
//              v
//       uvm_reg_bus_op
//              |
//              v
//      soc_sequence_item
//              |
//              v
//        Native SoC Bus
//
// Native bus protocol:
//
//     write = 1  -> write
//     write = 0  -> read
//
//     strb != 0  -> write
//     strb == 0  -> read
//
// Address : 32-bit
// Data    : 32-bit
// WSTRB   : 4-bit
// =============================================================================

class soc_reg_adapter extends uvm_reg_adapter;

    `uvm_object_utils(soc_reg_adapter)


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_reg_adapter");

        super.new(name);

        // The driver returns a response transaction.
        provides_responses = 0;

        // Native bus supports byte write strobes.
        supports_byte_enable = 1;

    endfunction


    // =========================================================================
    // RAL -> Native Bus
    //
    // Converts uvm_reg_bus_op into soc_sequence_item.
    // =========================================================================

    virtual function uvm_sequence_item reg2bus(
        const ref uvm_reg_bus_op rw
    );

        soc_sequence_item tr;


        // ---------------------------------------------------------------------
        // Create native bus transaction
        // ---------------------------------------------------------------------

        tr = soc_sequence_item::type_id::create("tr");


        // ---------------------------------------------------------------------
        // Address
        // ---------------------------------------------------------------------

        tr.addr = rw.addr;


        // ---------------------------------------------------------------------
        // Operation type
        // ---------------------------------------------------------------------

        if (rw.kind == UVM_WRITE) begin

            tr.write = 1'b1;

        end
        else begin

            tr.write = 1'b0;

        end


        // ---------------------------------------------------------------------
        // Write data
        //
        // For reads, this value is ignored by the native DUT.
        // ---------------------------------------------------------------------

        tr.wdata = rw.data;


        // ---------------------------------------------------------------------
        // Byte strobes
        //
        // Native protocol:
        //
        //   READ  -> 0000
        //   WRITE -> 1111
        //
        // RAL register accesses are 32-bit accesses here.
        // ---------------------------------------------------------------------

        if (rw.kind == UVM_WRITE)

            tr.strb = 4'b1111;

        else

            tr.strb = 4'b0000;


        // ---------------------------------------------------------------------
        // Determine target peripheral.
        // ---------------------------------------------------------------------

        tr.set_target();


        return tr;

    endfunction


    // =========================================================================
    // Native Bus -> RAL
    //
    // Converts completed soc_sequence_item into uvm_reg_bus_op.
    // =========================================================================

    virtual function void bus2reg(
        uvm_sequence_item bus_item,
        ref uvm_reg_bus_op rw
    );

        soc_sequence_item tr;


        // ---------------------------------------------------------------------
        // Verify transaction type
        // ---------------------------------------------------------------------

        if (!$cast(tr, bus_item)) begin

            `uvm_fatal(
                "SOC_RAL_ADAPTER",
                "bus_item is not a soc_sequence_item"
            )

        end


        // ---------------------------------------------------------------------
        // Address
        // ---------------------------------------------------------------------

        rw.addr = tr.addr;


        // ---------------------------------------------------------------------
        // Determine operation type
        // ---------------------------------------------------------------------

        if (tr.write)

            rw.kind = UVM_WRITE;

        else

            rw.kind = UVM_READ;


        // ---------------------------------------------------------------------
        // Data
        //
        // For a write:
        //     return the written data.
        //
        // For a read:
        //     return DUT read data.
        // ---------------------------------------------------------------------

        if (tr.write)

            rw.data = tr.wdata;

        else

            rw.data = tr.rdata;


        // ---------------------------------------------------------------------
        // Response status
        //
        // Native bus does not have AXI-style BRESP/RRESP.
        //
        // The driver should only return the item after mem_ready.
        // Therefore a completed transaction is considered successful.
        // ---------------------------------------------------------------------

        if (tr.ready)

            rw.status = UVM_IS_OK;

        else

            rw.status = UVM_NOT_OK;


    endfunction

endclass


`endif