`ifndef TPU_MONITOR_SV
`define TPU_MONITOR_SV

// import uvm_pkg::*;
// `include "uvm_macros.svh"

class tpu_monitor extends uvm_monitor;

    `uvm_component_utils(tpu_monitor)

    virtual tpu_debug_if vif;

    uvm_analysis_port #(tpu_debug_transaction) analysis_port;

    longint unsigned cycle_count;

    bit previous_start;
    bit previous_done;

    event tpu_done_event;

    function new(
        string name = "tpu_monitor",
        uvm_component parent = null
    );

        super.new(name, parent);

        analysis_port = new(
            "analysis_port",
            this
        );

        cycle_count   = 0;
        previous_start = 0;
        previous_done  = 0;

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(
                virtual tpu_debug_if
            )::get(
                this,
                "",
                "tpu_vif",
                vif
            )) begin

            `uvm_fatal(
                "NO_TPU_VIF",
                "tpu_debug_if was not found"
            )

        end

    endfunction


    task run_phase(uvm_phase phase);

        forever begin

            @(posedge vif.clk);

            cycle_count++;

            monitor_start();
            monitor_input();
            monitor_output();
            monitor_done();

        end

    endtask


    task monitor_start();

        tpu_debug_transaction tr;

        if (vif.axis_start && !previous_start) begin

            tr = tpu_debug_transaction::type_id::create(
                "start_tr"
            );

            tr.event_type =
                tpu_debug_transaction::TPU_START;

            tr.timestamp = $time;
            tr.cycle     = cycle_count;

            analysis_port.write(tr);
            
            `uvm_info(
                "TPU_MON",
                "TPU START detected",
                UVM_MEDIUM
            )

        end

        previous_start = vif.axis_start;

    endtask


    task monitor_input();

        tpu_debug_transaction tr;

        // AXI transfer occurs only on:
        // TVALID && TREADY

        if (vif.in_tvalid &&
            vif.in_tready) begin

            tr = tpu_debug_transaction::type_id::create(
                "input_tr"
            );

            tr.event_type =
                tpu_debug_transaction::TPU_INPUT_TRANSFER;

            tr.data = vif.in_tdata;
            tr.last = vif.in_tlast;

            tr.timestamp = $time;
            tr.cycle     = cycle_count;

            analysis_port.write(tr);

            `uvm_info(
                "TPU_INPUT",
                $sformatf(
                    "cycle=%0d data=%016h last=%0b",
                    cycle_count,
                    vif.in_tdata,
                    vif.in_tlast
                ),
                UVM_HIGH
            )

        end

    endtask


    task monitor_output();

        tpu_debug_transaction tr;

        if (vif.out_tvalid &&
            vif.out_tready) begin

            tr = tpu_debug_transaction::type_id::create(
                "output_tr"
            );

            tr.event_type =
                tpu_debug_transaction::TPU_OUTPUT_TRANSFER;

            tr.data = vif.out_tdata;
            tr.last = vif.out_tlast;

            tr.timestamp = $time;
            tr.cycle     = cycle_count;

            analysis_port.write(tr);

            `uvm_info(
                "TPU_OUTPUT",
                $sformatf(
                    "cycle=%0d data=%016h last=%0b",
                    cycle_count,
                    vif.out_tdata,
                    vif.out_tlast
                ),
                UVM_MEDIUM
            )

        end

    endtask


    task monitor_done();

        tpu_debug_transaction tr;

        if (vif.axis_done && !previous_done) begin

            tr = tpu_debug_transaction::type_id::create(
                "done_tr"
            );

            tr.event_type =
                tpu_debug_transaction::TPU_DONE;

            tr.result0 = vif.result0;
            tr.result1 = vif.result1;

            tr.timestamp = $time;
            tr.cycle     = cycle_count;

            analysis_port.write(tr);

                    
            -> tpu_done_event;      

            `uvm_info(
                "TPU_DONE",
                $sformatf(
                    "cycle=%0d result0=%016h result1=%016h",
                    cycle_count,
                    vif.result0,
                    vif.result1
                ),
        UVM_MEDIUM
            )

            `uvm_info(
                "TPU_DONE",
                $sformatf(
                    "cycle=%0d result0=%016h result1=%016h",
                    cycle_count,
                    vif.result0,
                    vif.result1
                ),
                UVM_MEDIUM
            )

        end

        previous_done = vif.axis_done;

    endtask

endclass

`endif