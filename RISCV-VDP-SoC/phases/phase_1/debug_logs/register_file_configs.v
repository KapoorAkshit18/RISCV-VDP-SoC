// enable regs 
localparam integer irqregs_offset = ENABLE_REGS_16_31 ? 32 : 16;
	localparam integer regfile_size = (ENABLE_REGS_16_31 ? 32 : 16) + 4*ENABLE_IRQ*ENABLE_IRQ_QREGS;
	localparam integer regindex_bits = (ENABLE_REGS_16_31 ? 5 : 4) + ENABLE_IRQ*ENABLE_IRQ_QREGS;

    localparam integer irqregs_offset = ENABLE_REGS_16_31 ? 32 : 16;
	localparam integer regfile_size = (ENABLE_REGS_16_31 ? 32 : 16) + 4*ENABLE_IRQ*ENABLE_IRQ_QREGS;
	localparam integer regindex_bits = (ENABLE_REGS_16_31 ? 5 : 4) + ENABLE_IRQ*ENABLE_IRQ_QREGS;
//  regfile size
    `ifndef PICORV32_REGS
	reg [31:0] cpuregs [0:regfile_size-1];

	integer i;
	initial begin
		if (REGS_INIT_ZERO) begin
			for (i = 0; i < regfile_size; i = i+1)
				cpuregs[i] = 0;
		end
	end
`endif

// ============================================================
// cpuregs_rs1
1283:   reg [31:0] cpuregs_rs1;
1324:                   cpuregs_rs1 = decoded_rs1 ? cpuregs[decoded_rs1] : 0;
1327:                   cpuregs_rs1 = decoded_rs1 ? $anyseq : 0;
1333:                   cpuregs_rs1 = decoded_rs ? cpuregs[decoded_rs] : 0;
1335:                   cpuregs_rs1 = decoded_rs ? $anyseq : 0;
1337:                   cpuregs_rs2 = cpuregs_rs1;
1362:                   cpuregs_rs1 = decoded_rs1 ? cpuregs_rdata1 : 0;
1366:                   cpuregs_rs1 = decoded_rs ? cpuregs_rdata1 : 0;
1367:                   cpuregs_rs2 = cpuregs_rs1;
1565:                                                   `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1566:                                                   reg_op1 <= cpuregs_rs1;
1567:                                                   dbg_rs1val <= cpuregs_rs1;
1629:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1630:                                           reg_out <= cpuregs_rs1;
1631:                                           dbg_rs1val <= cpuregs_rs1;
1637:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1638:                                           reg_out <= cpuregs_rs1;
1639:                                           dbg_rs1val <= cpuregs_rs1;
1650:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1651:                                           reg_out <= CATCH_MISALIGN ? (cpuregs_rs1 & 32'h fffffffe) : cpuregs_rs1;
1652:                                           dbg_rs1val <= cpuregs_rs1;
1659:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1660:                                           irq_mask <= cpuregs_rs1 | MASKED_IRQ;
1661:                                           dbg_rs1val <= cpuregs_rs1;
1668:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1669:                                           timer <= cpuregs_rs1;
1670:                                           dbg_rs1val <= cpuregs_rs1;
1675:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1676:                                           reg_op1 <= cpuregs_rs1;
1677:                                           dbg_rs1val <= cpuregs_rs1;
1683:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1684:                                           reg_op1 <= cpuregs_rs1;
1685:                                           dbg_rs1val <= cpuregs_rs1;
1691:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1692:                                           reg_op1 <= cpuregs_rs1;
1693:                                           dbg_rs1val <= cpuregs_rs1;
1703:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1704:                                           reg_op1 <= cpuregs_rs1;
1705:                                           dbg_rs1val <= cpuregs_rs1;
// cpu_regs_2

1283:   reg [31:0] cpuregs_rs1;
1324:                   cpuregs_rs1 = decoded_rs1 ? cpuregs[decoded_rs1] : 0;
1327:                   cpuregs_rs1 = decoded_rs1 ? $anyseq : 0;
1333:                   cpuregs_rs1 = decoded_rs ? cpuregs[decoded_rs] : 0;
1335:                   cpuregs_rs1 = decoded_rs ? $anyseq : 0;
1337:                   cpuregs_rs2 = cpuregs_rs1;
1362:                   cpuregs_rs1 = decoded_rs1 ? cpuregs_rdata1 : 0;
1366:                   cpuregs_rs1 = decoded_rs ? cpuregs_rdata1 : 0;
1367:                   cpuregs_rs2 = cpuregs_rs1;
1565:                                                   `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1566:                                                   reg_op1 <= cpuregs_rs1;
1567:                                                   dbg_rs1val <= cpuregs_rs1;
1629:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1630:                                           reg_out <= cpuregs_rs1;
1631:                                           dbg_rs1val <= cpuregs_rs1;
1637:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1638:                                           reg_out <= cpuregs_rs1;
1639:                                           dbg_rs1val <= cpuregs_rs1;
1650:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1651:                                           reg_out <= CATCH_MISALIGN ? (cpuregs_rs1 & 32'h fffffffe) : cpuregs_rs1;
1652:                                           dbg_rs1val <= cpuregs_rs1;
1659:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1660:                                           irq_mask <= cpuregs_rs1 | MASKED_IRQ;
1661:                                           dbg_rs1val <= cpuregs_rs1;
1668:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1669:                                           timer <= cpuregs_rs1;
1670:                                           dbg_rs1val <= cpuregs_rs1;
1675:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1676:                                           reg_op1 <= cpuregs_rs1;
1677:                                           dbg_rs1val <= cpuregs_rs1;
1683:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1684:                                           reg_op1 <= cpuregs_rs1;
1685:                                           dbg_rs1val <= cpuregs_rs1;
1691:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1692:                                           reg_op1 <= cpuregs_rs1;
1693:                                           dbg_rs1val <= cpuregs_rs1;
1703:                                           `debug($display("LD_RS1: %2d 0x%08x", decoded_rs1, cpuregs_rs1);)
1704:                                           reg_op1 <= cpuregs_rs1;
1705:                                           dbg_rs1val <= cpuregs_rs1;

akshi@Envy MINGW64 /c/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_1/riscv/rtl (main|MERGING)
$ grep -n "cpuregs_rs2" riscv.v
1284:   reg [31:0] cpuregs_rs2;
1325:                   cpuregs_rs2 = decoded_rs2 ? cpuregs[decoded_rs2] : 0;
1328:                   cpuregs_rs2 = decoded_rs2 ? $anyseq : 0;
1337:                   cpuregs_rs2 = cpuregs_rs1;
1363:                   cpuregs_rs2 = decoded_rs2 ? cpuregs_rdata2 : 0;
1367:                   cpuregs_rs2 = cpuregs_rs1;
1571:                                                           `debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, cpuregs_rs2);)
1572:                                                           reg_sh <= cpuregs_rs2;
1573:                                                           reg_op2 <= cpuregs_rs2;
1574:                                                           dbg_rs2val <= cpuregs_rs2;
1708:                                                   `debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, cpuregs_rs2);)
1709:                                                   reg_sh <= cpuregs_rs2;
1710:                                                   reg_op2 <= cpuregs_rs2;
1711:                                                   dbg_rs2val <= cpuregs_rs2;
1738:                           `debug($display("LD_RS2: %2d 0x%08x", decoded_rs2, cpuregs_rs2);)
1739:                           reg_sh <= cpuregs_rs2;
1740:                           reg_op2 <= cpuregs_rs2;
1741:                           dbg_rs2val <= cpuregs_rs2;
//  cpuregs_write
$ grep -n "cpuregs_write" riscv.v
1281:   reg cpuregs_write;
1288:           cpuregs_write = 0;
1296:                                   cpuregs_write = 1;
1300:                                   cpuregs_write = 1;
1304:                                   cpuregs_write = 1;
1308:                                   cpuregs_write = 1;
1316:           if (resetn && cpuregs_write && latched_rd)
1350:           .wen(resetn && cpuregs_write && latched_rd),
1983:           if (cpuregs_write && !irq_state) begin
// cpuregs_wrdata

$ grep -n "cpuregs_wrdata" riscv.v
1282:   reg [31:0] cpuregs_wrdata;
1289:           cpuregs_wrdata = 'bx;
1295:                                   cpuregs_wrdata = reg_pc + (latched_compr ? 2 : 4);
1299:                                   cpuregs_wrdata = latched_stalu ? alu_out_q : reg_out;
1303:                                   cpuregs_wrdata = reg_next_pc | latched_compr;
1307:                                   cpuregs_wrdata = irq_pending & ~irq_mask;
1317:                   cpuregs[latched_rd] <= cpuregs_wrdata;
1354:           .wdata(cpuregs_wrdata),
1985:                   rvfi_rd_wdata <= latched_rd ? cpuregs_wrdata : 0;






