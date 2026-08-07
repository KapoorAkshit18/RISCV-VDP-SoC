module soc_mem_interconnect_formal;

    reg         m_valid;
    reg         m_write;
    reg  [31:0] m_addr;
    reg  [31:0] m_wdata;
    reg  [3:0]  m_strb;

    wire        m_ready;
    wire [31:0] m_rdata;

    wire        ram_valid;
    wire        ram_write;
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [3:0]  ram_strb;

    reg         ram_ready;
    reg  [31:0] ram_rdata;

    wire        gpio_valid;
    wire        gpio_write;
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [3:0]  gpio_strb;

    reg         gpio_ready;
    reg  [31:0] gpio_rdata;


    // DUT
    soc_mem_interconnect dut (

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


    // ------------------------------------------------
    // Formal assumptions
    // ------------------------------------------------

    always @(*) begin

        // Slave responses are arbitrary.
        // No assumptions about their internal implementation.

    end


    // ------------------------------------------------
    // Property 1:
    // RAM address selects RAM
    // ------------------------------------------------

    always @(*) begin

        if (m_valid &&
            ((m_addr & 32'hFFFF_0000) == 32'h0000_0000))

            assert(ram_valid);

    end


    // ------------------------------------------------
    // Property 2:
    // GPIO address selects GPIO
    // ------------------------------------------------

    always @(*) begin

        if (m_valid &&
            ((m_addr & 32'hFFFF_F000) == 32'h4000_0000))

            assert(gpio_valid);

    end


    // ------------------------------------------------
    // Property 3:
    // RAM and GPIO cannot both be selected
    // ------------------------------------------------

    always @(*) begin

        assert(!(ram_valid && gpio_valid));

    end


    // ------------------------------------------------
    // Property 4:
    // Invalid address selects nothing
    // ------------------------------------------------

    always @(*) begin

        if (m_valid &&
            !(((m_addr & 32'hFFFF_0000) == 32'h0000_0000)) &&
            !(((m_addr & 32'hFFFF_F000) == 32'h4000_0000)))

            assert(!ram_valid && !gpio_valid);

    end


    // ------------------------------------------------
    // Property 5:
    // RAM request mirrors master
    // ------------------------------------------------

    always @(*) begin

        if (ram_valid) begin

            assert(ram_write == m_write);
            assert(ram_addr  == m_addr);
            assert(ram_wdata == m_wdata);
            assert(ram_strb  == m_strb);

        end

    end


    // ------------------------------------------------
    // Property 6:
    // GPIO request mirrors master
    // ------------------------------------------------

    always @(*) begin

        if (gpio_valid) begin

            assert(gpio_write == m_write);
            assert(gpio_addr  == m_addr);
            assert(gpio_wdata == m_wdata);
            assert(gpio_strb  == m_strb);

        end

    end


    // ------------------------------------------------
    // Property 7:
    // Response routing
    // ------------------------------------------------

    always @(*) begin

        if (ram_valid) begin

            assert(m_ready == ram_ready);
            assert(m_rdata == ram_rdata);

        end

        if (gpio_valid) begin

            assert(m_ready == gpio_ready);
            assert(m_rdata == gpio_rdata);

        end

    end

endmodule