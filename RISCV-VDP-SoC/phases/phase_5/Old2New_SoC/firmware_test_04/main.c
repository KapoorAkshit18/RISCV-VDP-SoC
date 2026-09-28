#include <stdint.h>

/* Sensor MMIO */
#define SENSOR_BASE              0x00012000u
#define SENSOR_BATT_PERCENT      0x0000u
#define SENSOR_BATT_VOLTAGE      0x0004u
#define SENSOR_TEMPERATURE       0x0008u
#define SENSOR_STATUS            0x000Cu
#define SENSOR_UNMAPPED          0x0010u

#define STATUS_VALID              (1u << 0)
#define STATUS_BATT_LOW           (1u << 1)
#define STATUS_TEMP_ALARM         (1u << 2)

#define BATT_LOW_THRESH           15u
#define TEMP_ALARM_HIGH           800

/* Debug RAM */
#define DEBUG_RESULT0_LO          0x00001230u
#define DEBUG_RESULT0_HI          0x00001234u
#define DEBUG_RESULT1_LO          0x00001238u
#define DEBUG_RESULT1_HI          0x0000123Cu
#define DEBUG_CYCLES_LO           0x000012A0u
#define DEBUG_CYCLES_HI           0x000012A4u
#define DEBUG_MARKER              0x000012A8u
#define DEBUG_ERROR               0x000012ACu

#define MARK_START                0x11111111u
#define MARK_READS                0x22222222u
#define MARK_STATUS_OK            0x33333333u
#define MARK_RO_OK                0x44444444u
#define MARK_SUCCESS              0x55555555u
#define MARK_ERROR                0xDEAD0001u

#define ERROR_STATUS              1u
#define ERROR_UNMAPPED            2u
#define ERROR_RO_WRITE            3u

static inline void mmio_write(uint32_t a, uint32_t v)
{
    *(volatile uint32_t *)(uintptr_t)a = v;
}

static inline uint32_t mmio_read(uint32_t a)
{
    return *(volatile uint32_t *)(uintptr_t)a;
}

static inline uint32_t sensor_read(uint32_t off)
{
    return mmio_read(SENSOR_BASE + off);
}

static inline void sensor_write(uint32_t off, uint32_t value)
{
    mmio_write(SENSOR_BASE + off, value);
}

static inline uint64_t read_cycle64(void)
{
    uint32_t hi1, lo, hi2;
    do {
        __asm__ volatile ("rdcycleh %0" : "=r"(hi1));
        __asm__ volatile ("rdcycle %0"  : "=r"(lo));
        __asm__ volatile ("rdcycleh %0" : "=r"(hi2));
    } while (hi1 != hi2);
    return ((uint64_t)hi2 << 32) | lo;
}

static void fail(uint32_t code)
{
    mmio_write(DEBUG_ERROR, code);
    mmio_write(DEBUG_MARKER, MARK_ERROR);
    while (1) __asm__ volatile ("nop");
}

int main(void)
{
    uint64_t start, end, elapsed;
    uint32_t batt, volt, temp_raw, status;
    uint32_t unmapped, before, after;
    int32_t temp;

    mmio_write(DEBUG_CYCLES_LO, 0);
    mmio_write(DEBUG_CYCLES_HI, 0);
    mmio_write(DEBUG_RESULT0_LO, 0);
    mmio_write(DEBUG_RESULT0_HI, 0);
    mmio_write(DEBUG_RESULT1_LO, 0);
    mmio_write(DEBUG_RESULT1_HI, 0);
    mmio_write(DEBUG_ERROR, 0);
    mmio_write(DEBUG_MARKER, MARK_START);

    start = read_cycle64();

    /* Read complete sensor telemetry window. */
    batt      = sensor_read(SENSOR_BATT_PERCENT);
    volt      = sensor_read(SENSOR_BATT_VOLTAGE);
    temp_raw  = sensor_read(SENSOR_TEMPERATURE);
    status    = sensor_read(SENSOR_STATUS);

    mmio_write(DEBUG_RESULT0_LO, batt);
    mmio_write(DEBUG_RESULT0_HI, volt);
    mmio_write(DEBUG_RESULT1_LO, temp_raw);
    mmio_write(DEBUG_RESULT1_HI, status);
    mmio_write(DEBUG_MARKER, MARK_READS);

    /* Bits [31:3] must always be zero. */
    if (status & 0xFFFFFFF8u)
        fail(ERROR_STATUS);

    /*
     * Sensor RTL:
     *   battery_low = battery_percent <= 15
     *   temp_alarm  = signed temperature > 800
     *
     * sensor_valid is supplied by the RNM chain, so we only require it to
     * occupy bit 0; its actual value depends on the current RNM stimulus.
     */
    if (((status & STATUS_BATT_LOW) != 0u) !=
        (batt <= BATT_LOW_THRESH))
        fail(ERROR_STATUS);

    temp = (int32_t)(int16_t)(temp_raw & 0xFFFFu);

    if (((status & STATUS_TEMP_ALARM) != 0u) !=
        (temp > TEMP_ALARM_HIGH))
        fail(ERROR_STATUS);

    mmio_write(DEBUG_MARKER, MARK_STATUS_OK);

    /* Unmapped reads must return zero. */
    unmapped = sensor_read(SENSOR_UNMAPPED);
    if (unmapped != 0u)
        fail(ERROR_UNMAPPED);

    /* Sensor window is read-only; writes are silently discarded. */
    before = sensor_read(SENSOR_BATT_PERCENT);
    sensor_write(SENSOR_BATT_PERCENT, 0u);
    after = sensor_read(SENSOR_BATT_PERCENT);

    if (after != before)
        fail(ERROR_RO_WRITE);

    mmio_write(DEBUG_MARKER, MARK_RO_OK);

    end = read_cycle64();
    elapsed = end - start;

    mmio_write(DEBUG_CYCLES_LO, (uint32_t)elapsed);
    mmio_write(DEBUG_CYCLES_HI, (uint32_t)(elapsed >> 32));

    mmio_write(DEBUG_MARKER, MARK_SUCCESS);

    while (1) __asm__ volatile ("nop");
    return 0;
}
