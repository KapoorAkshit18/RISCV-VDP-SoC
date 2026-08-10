`timescale 1ns/1ps

interface soc_native_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk
);

    // ================================================================
    // Native master -> interconnect
    // ================================================================

    logic                         m_valid;
    logic                         m_write;
    logic [ADDR_WIDTH-1:0]        m_addr;
    logic [DATA_WIDTH-1:0]        m_wdata;
    logic [DATA_WIDTH/8-1:0]      m_strb;

    // ================================================================
    // Native interconnect -> master
    // ================================================================

    logic                         m_ready;
    logic [DATA_WIDTH-1:0]        m_rdata;


    // ================================================================
    // Driver clocking block
    // ================================================================
    //
    // Driver drives request signals.
    // Driver samples response signals.
    //
    // The interconnect itself is combinational, but the clocking
    // block provides deterministic UVM synchronization.
    // ================================================================

    clocking driver_cb @(posedge clk);

        default input #1step output #1;

        output m_valid;
        output m_write;
        output m_addr;
        output m_wdata;
        output m_strb;

        input  m_ready;
        input  m_rdata;

    endclocking


    // ================================================================
    // Monitor clocking block
    // ================================================================

    clocking monitor_cb @(posedge clk);

        default input #1step;

        input m_valid;
        input m_write;
        input m_addr;
        input m_wdata;
        input m_strb;

        input m_ready;
        input m_rdata;

    endclocking


    // ================================================================
    // Modports
    // ================================================================

    modport DRIVER (
        clocking driver_cb
    );

    modport MONITOR (
        clocking monitor_cb
    );

endinterface