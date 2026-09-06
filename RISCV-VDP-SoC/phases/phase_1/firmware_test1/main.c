#include <stdint.h>

/*
 * Memory-mapped RAM test address.
 *
 * 0x00000100 is an address within the SoC's RAM address space.
 * The pointer is declared volatile so the compiler does not
 * optimize away the memory write or read. This is important
 * because these accesses must appear as actual bus transactions
 * in the RISC-V SoC simulation.
 */
volatile uint32_t *ram_test = (volatile uint32_t *)0x00000100;

int main(void)
{
    /*
     * Write a known test value to the RAM.
     *
     * Expected SoC behavior:
     * RISC-V CPU -> CPU Bus Adapter -> Interconnect -> RAM
     */
    *ram_test = 42;

    /*
     * Read the value back from RAM.
     *
     * 'volatile' ensures that the compiler generates an actual
     * memory read transaction instead of using a cached value.
     */
    volatile uint32_t value = *ram_test;

    /*
     * Verify that the value read from RAM matches the value written.
     *
     * If the RAM transaction is successful, the loop condition
     * becomes false and the program exits.
     *
     * If the value is incorrect, the CPU remains here indefinitely,
     * indicating a RAM read/write failure.
     */
    while (value != 42)
        ;

    /*
     * RAM write/read test passed.
     */
    return 0;
}