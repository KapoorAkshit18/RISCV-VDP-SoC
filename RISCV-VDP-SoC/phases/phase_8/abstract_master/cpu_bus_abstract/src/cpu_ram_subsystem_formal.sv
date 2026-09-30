module cpu_ram_subsystem_formal;
    reg clk;
    reg resetn;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Reset constraint: Active low, start in reset
    initial assume(!resetn);

    // Symbolic variables for transaction generator
    wire        f_valid;
    wire        f_instr;
    wire [31:0] f_addr;
    wire [31:0] f_wdata;
    wire [ 3:0] f_wstrb;

    // Abstract CPU Bus
    wire        mem_valid;
    wire        mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    formal_cpu_master u_master (
        .clk       (clk),
        .resetn    (resetn),
        .f_valid   (f_valid),
        .f_instr   (f_instr),
        .f_addr    (f_addr),
        .f_wdata   (f_wdata),
        .f_wstrb   (f_wstrb),
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata)
    );

    // Adapter Bus
    wire        m_valid;
    wire        m_write;
    wire [31:0] m_addr;
    wire [31:0] m_wdata;
    wire [ 3:0] m_strb;
    wire        m_ready;
    wire [31:0] m_rdata;

    cpu_bus_adapter u_adapter (
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_ready (mem_ready),
        .mem_rdata (mem_rdata),
        
        .m_valid   (m_valid),
        .m_write   (m_write),
        .m_addr    (m_addr),
        .m_wdata   (m_wdata),
        .m_strb    (m_strb),
        .m_ready   (m_ready),
        .m_rdata   (m_rdata)
    );

    // RAM Bus
    wire        ram_valid;
    wire        ram_write;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [ 3:0] ram_strb;
    wire        ram_ready;
    wire [31:0] ram_rdata;

    // GPIO Bus (Hardcoded dummy per subsystem implementation)
    wire        gpio_valid;
    wire        gpio_write;
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [ 3:0] gpio_strb;
    wire        gpio_ready = 1'b0;
    wire [31:0] gpio_rdata = 32'b0;

    soc_mem_interconnect #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_interconnect (
        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),
        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),
        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata),

        .gpio_valid (gpio_valid),
        .gpio_write (gpio_write),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_strb  (gpio_strb),
        .gpio_ready (gpio_ready),
        .gpio_rdata (gpio_rdata)
    );

    soc_ram #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .DEPTH(256)
    ) u_ram (
        .clk    (clk),
        .reset  (~resetn),  // RAM uses active-high reset natively
        .valid  (ram_valid),
        .write  (ram_write),
        .addr   (ram_addr),
        .wdata  (ram_wdata),
        .strb   (ram_strb),
        .ready  (ram_ready),
        .rdata  (ram_rdata)
    );

    cpu_bus_formal u_checker (
        .clk        (clk),
        .resetn     (resetn),

        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata),
        
        .m_valid    (m_valid),
        .m_write    (m_write),
        .m_addr     (m_addr),
        .m_wdata    (m_wdata),
        .m_strb     (m_strb),
        .m_ready    (m_ready),
        .m_rdata    (m_rdata),

        .ram_valid  (ram_valid),
        .ram_write  (ram_write),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_strb   (ram_strb),
        .ram_ready  (ram_ready),
        .ram_rdata  (ram_rdata)
    );

endmodule
