/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2009 by Michael Sparmann
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ****************************************************************************/

/* Read-only S5L8720 NAND driver. The FMC sequencer issues commands, decodes
 * BCH and transfers page data by DMA. Static buffers require caller locking.
 * DMA buffers must be cache-line aligned; unaligned reads use nand_bounce. */

#include "config.h"
#include "cpu.h"
#include "system.h"
#include "kernel.h"
#include "mv.h"
#include "storage.h"
#include "fs_defines.h"
#include "logf.h"
#include "clocking-s5l8702.h"
#include "nand-target.h"
#include "ftl-target.h"
#include "fmss-nano4g.h"
#include <cpucache-arm.h>
#include <string.h>

/* Rockbox maps DRAM and IRAM flat: a pointer is a DMA bus address. */
#define FMSS_RD(off)        (*(volatile uint32_t *)(FMC_BASE + (off)))
#define FMSS_WR(off, val)   (*(volatile uint32_t *)(FMC_BASE + (off)) = (val))
#define NAND_DMA_ADDR(p)    ((uint32_t)(uintptr_t)(p))

/* ==== Registers ==== */
/* FMC / FMSS registers, offsets from FMC_BASE */
#define FMC_CTRL1             0x004   /* transfer engine control */
#define FMCTRL1_RESET       0x800  /* transfer engine reset request (_resetFMSS) */
#define FMCTRL1_IDLE        (1u << 30)  /* reads 1 when the FMC is idle after the reset */
#define FMCTRL1_RELEASE     0x80000000u  /* written after the reset completes */
#define ECC_RESET           0x81c  /* ECC unit reset, write 1 (end of _resetFMSS) */
#define FMSS_CTRL           0xc00  /* sequencer control (CPU only) */
#define FMSS_CTRL_START     0xffb5  /* sequencer start command */
#define FMSS_CTRL_RESUME    0x1  /* OR-ed in to continue after a pause */
#define FMSS_CTRL_ABORT     0x2  /* abort a running program (STATUS 4) */
#define FMSS_CTRL_STOP      0x8  /* stop request, first write of _resetFMSS */
#define FMSS_CTRL_FMCRESET  0x80000  /* written before the FMC reset */
#define FMSS_PROG           0xc04   /* bus address of the program */
#define FMSS_STATUS         0xc08   /* 0 idle, 3 aborted, 4 busy */
#define FMSS_IRQ            0xc0c   /* write 1 to clear */
#define FMSS_IRQ_DONE       (1u << 0)  /* program reached END */
#define FMSS_IRQ_FAULT      (1u << 2)  /* a WAIT timed out, fault handler ran */
#define FMSS_IRQ_PAUSE      (1u << 3)  /* program paused (stepped over by the CPU) */
#define FMSS_IRQ_ALL        0xff  /* clear-all value of _startFMSS */
#define FMSS_IRQ_MASK       (FMSS_IRQ_DONE | FMSS_IRQ_FAULT | FMSS_IRQ_PAUSE)
#define FMSS_RESULT         0xc30   /* sequencer r6 when the program ended */
#define FMSS_RESULT_UECC    (1u << 30)
#define FMSS_RESULT_ERASED  (1u << 29)
#define FMSS_RESULT_NCORR   0xffff  /* bit n: some sector had n bits corrected */
#define FMSS_PC             0xc38  /* sequencer program counter (byte offset) */
#define FMSS_BUFRST         0xc60  /* buffer reset request: 1 = request, 0 = release */
#define FMSS_BUFRST_OK      0xc64  /* becomes 1 when the buffer reset is done */
#define FMSS_BUFCFG         0xc6c  /* buffer config: 0 = handshake path */
#define FMSS_BUFCFG_BYPASS  0x10  /* _resetFMSS skips the handshake if set */

/* The CPU writes these before every run; the READ program advances the list
 * pointers (P_ROWS, P_CEMASKS, P_DMALIST, P_META, P_ECCBUF) in place, so they
 * are always rewritten. Scratch words 0xd3c.. belong to the
 * microcode (V_D3C = page ECC summary). */
/* Parameter words the programs read */
#define P_IDBUF             0xd08  /* READ ID: bus address of u32 out[CEs] */
#define P_ROWS              0xd0c   /* READ: u32 row list; READ ID: CE count */
#define P_CEMASKS           0xd10  /* READ: u32 list, 1 << CE per page */
#define P_ECCBUF            0xd14  /* READ: u8 status per sector out, 0 = none */
#define P_COUNT             0xd18  /* READ: number of pages */
#define P_META              0xd1c  /* READ: 12 meta bytes per page out */
#define P_DMALIST           0xd20  /* READ: u32 bus address per 2 KiB chunk */
#define P_STATS             0xd24  /* READ: u32[18] ECC histogram, 0 = none */
#define P_CHUNKS            0xd28  /* DMA chunks per page (sectors / 4) */
#define P_ECCMODE           0xd2c  /* ECC_CTRL value for sectors 1.. */
#define P_ECCCFG            0xd30  /* ECC_CTRL value for sector 0 (+ meta) */
#define P_HDRLEN            0xd34  /* meta + parity bytes of sector 0, - 1 */
#define P_PARLEN            0xd38  /* parity bytes of sectors 1.., - 1 */
#define P_TIMING            0xd4c  /* FMC_CTRL0 timing fields (nand_calc_timing) */

/* FMC and ECC clock gates: PWRCON0 bits 5 and 9. */
#define CLOCKGATE_FMC       5
#define CLOCKGATE_FMC_ECC   9

/* 100 us per register poll, 2 s per program, 10 ms for NAND reset. */
#define POLL_TIMEOUT_US     100     /* register handshakes */
#define PROG_TIMEOUT_US     2000000 /* one program run */
#define RESET_SETTLE_US     10000   /* after the RESET program */

/* The bus clock the FMC timing is computed for. The first-stage loader and
 * Rockbox both run HCLK at 133 MHz on the nano 4G (PLL0 266 MHz, CLKCON1
 * 0x404040; measured on the device) and Rockbox never
 * changes the HCLK divider on the S5L8720. A slower real clock only makes the
 * timings longer. */
#ifdef IPOD_NANO5G
/* Not measured on the nano 5G yet (Rockbox keeps the clocks the loader
 * set): assume a fast bus so that a slower real one only lengthens them */
#define NAND_BUS_MHZ        200
#else
#define NAND_BUS_MHZ        133
#endif

/* 512-byte ECC sectors (8 per 4 KiB page, 16 per 8 KiB); one DMA entry
 * per 2048 bytes. */
#define SECTORS_PER_PAGE    (NAND_PAGE_SIZE / 512)
#define CHUNKS_PER_PAGE     (NAND_PAGE_SIZE / 2048)  /* DMA list entries */

#include "nand-chip-table.h"

/* ==== Driver state and DMA buffers ==== */
static struct nand_geometry nand_geom;
static uint32_t nand_timing;            /* FMC_CTRL0 timing fields */
#ifdef NAND_WRITABLE
static uint32_t nand_program_timing;
#endif
static uint32_t nand_ecc_mode, nand_ecc_cfg, nand_ecc_hdrlen, nand_ecc_parlen;  /* P_ECCMODE..P_PARLEN values */
static uint32_t nand_pages_read;  /* diagnostics: pages handed to the sequencer */
static bool nand_phys_ready;  /* nand_phys_init() succeeded */

/* Buffers the sequencer reads or writes by DMA: cache-line aligned, and the
 * request lists are cleaned from the D-cache before every run */
static uint32_t nand_idbuf[NAND_MAX_BANKS] CACHEALIGN_ATTR;  /* READ ID output, one u32 per CE */
static uint32_t nand_rows[NAND_MAX_PAGES_PER_READ] CACHEALIGN_ATTR;  /* row per page (P_ROWS) */
static uint32_t nand_cemasks[NAND_MAX_PAGES_PER_READ] CACHEALIGN_ATTR;  /* 1 << CE per page (P_CEMASKS) */
static uint32_t nand_dmalist[NAND_MAX_PAGES_PER_READ * CHUNKS_PER_PAGE]  /* 2 bus addresses per page */
    CACHEALIGN_ATTR;
static uint8_t nand_meta[NAND_MAX_PAGES_PER_READ * NAND_META_SIZE]  /* 12 meta bytes per page (P_META) */
    CACHEALIGN_ATTR;
static uint8_t nand_secstat[SECTORS_PER_PAGE] CACHEALIGN_ATTR;  /* status per sector, single-page reads */
static uint32_t nand_hist[18] CACHEALIGN_ATTR;  /* per-run ECC histogram */
static uint8_t nand_bounce[NAND_PAGE_SIZE] CACHEALIGN_ATTR;  /* for unaligned caller buffers */

/* ==== Sequencer control ==== */

/* True once us microseconds have passed since start (USEC_TIMER wraps; the
 * unsigned difference handles that) */
static bool nand_elapsed(uint32_t start, uint32_t us)
{
    return (uint32_t)(USEC_TIMER - start) >= us;
}

/* Wait until (reg & mask) == value, at most POLL_TIMEOUT_US */
static int fmss_poll(unsigned int reg, uint32_t mask, uint32_t value)
{
    uint32_t start = USEC_TIMER;
    while ((FMSS_RD(reg) & mask) != value)
        if (nand_elapsed(start, POLL_TIMEOUT_US))
            return NAND_ERR_TIMEOUT;
    return 0;
}

/* Stop the sequencer and reset its buffers, FMC and ECC unit. */

static int fmss_reset(void)
{
    uint32_t start, status;

    FMSS_WR(FMSS_CTRL, FMSS_CTRL_STOP);
    start = USEC_TIMER;
    while ((status = FMSS_RD(FMSS_STATUS)) != 0)
    {
        if (status == 4)  /* FMSS_STATUS 4 = a program is running */
        {
            /* busy: abort the program and wait for idle or aborted */
            FMSS_WR(FMSS_CTRL, FMSS_CTRL_ABORT);
            start = USEC_TIMER;
            while ((status = FMSS_RD(FMSS_STATUS)) != 0 && status != 3)  /* 0 idle, 3 aborted */
                if (nand_elapsed(start, POLL_TIMEOUT_US))
                    return NAND_ERR_TIMEOUT;
            break;
        }
        if (nand_elapsed(start, POLL_TIMEOUT_US))
            return NAND_ERR_TIMEOUT;
    }

    if (FMSS_RD(FMSS_BUFCFG) != FMSS_BUFCFG_BYPASS)
    {
        FMSS_WR(FMSS_BUFRST, 1);
        if (fmss_poll(FMSS_BUFRST_OK, 0xffffffff, 1))
            return NAND_ERR_TIMEOUT;
        FMSS_WR(FMSS_BUFRST, 0);
    }

    FMSS_WR(FMSS_CTRL, FMSS_CTRL_FMCRESET);
    FMSS_WR(FMC_CTRL1, FMCTRL1_RESET);
    if (fmss_poll(FMC_CTRL1, FMCTRL1_IDLE, FMCTRL1_IDLE))
        return NAND_ERR_TIMEOUT;
    FMSS_WR(FMC_CTRL1, FMCTRL1_RELEASE);
    FMSS_WR(ECC_RESET, 1);
    return 0;
}

/* Clear done/fault/pause flags and wait for acknowledgement. */

static int fmss_clear_irq(void)
{
    FMSS_WR(FMSS_IRQ, FMSS_IRQ_MASK);
    return fmss_poll(FMSS_IRQ, FMSS_IRQ_MASK, 0);
}

/* Reset buffers and start the program at FMSS_PROG. */

static int fmss_start(void)
{
    FMSS_WR(FMSS_IRQ, FMSS_IRQ_ALL);
    FMSS_WR(FMSS_BUFCFG, 0);
    FMSS_WR(FMSS_BUFRST, 1);
    if (fmss_poll(FMSS_BUFRST_OK, 0xffffffff, 1))
        return NAND_ERR_TIMEOUT;
    FMSS_WR(FMSS_BUFRST, 0);
    FMSS_WR(FMSS_CTRL, FMSS_CTRL_START);
    return 0;
}

/* Wait for completion; reset the sequencer on fault or timeout. */
/* A pause advances FMSS_PC by one instruction before resuming. */
static int fmss_wait(void)
{
    uint32_t start = USEC_TIMER, irq;

    do
    {
        if (nand_elapsed(start, PROG_TIMEOUT_US))
        {
            fmss_reset();
            return NAND_ERR_TIMEOUT;
        }
        irq = FMSS_RD(FMSS_IRQ) & FMSS_IRQ_MASK;
        if (irq & FMSS_IRQ_PAUSE)
        {
            FMSS_WR(FMSS_PC, FMSS_RD(FMSS_PC) + 8);  /* skip the 8-byte pausing instruction */
            FMSS_WR(FMSS_IRQ, FMSS_IRQ_PAUSE);
            irq &= ~FMSS_IRQ_PAUSE;
            FMSS_WR(FMSS_CTRL, FMSS_RD(FMSS_CTRL) | FMSS_CTRL_RESUME);
        }
    } while (!(irq & FMSS_IRQ_DONE));

    if (irq != FMSS_IRQ_DONE && (irq & FMSS_IRQ_FAULT))
        fmss_reset();
    if (fmss_clear_irq())
        return NAND_ERR_TIMEOUT;
    return irq == FMSS_IRQ_DONE ? 0 : NAND_ERR_TIMEOUT;
}

/* ==== Chip detect ==== */
/* Reset all chips and read four ID bytes from each of CE0..CE7. */
/* RESET program (0xFF to all 8 CEs), 10 ms for tRST, then the READ ID
 * program with P_ROWS = 8 CEs. nand_idbuf[ce] = ID bytes 0..3 little endian;
 * an empty CE reads 0 or 0xffffffff. The ID buffer is invalidated before
 * the run (the sequencer writes it by DMA) and again afterwards. */
static int nand_reset_and_read_ids(void)
{
    if (fmss_reset())
        return NAND_ERR_TIMEOUT;
    FMSS_WR(FMSS_PROG, NAND_DMA_ADDR(fmss_prog_reset));
    if (fmss_clear_irq() || fmss_start() || fmss_wait())
        return NAND_ERR_TIMEOUT;
    udelay(RESET_SETTLE_US);

    FMSS_WR(FMSS_PROG, NAND_DMA_ADDR(fmss_prog_readid));
    FMSS_WR(P_IDBUF, NAND_DMA_ADDR(nand_idbuf));
    FMSS_WR(P_ROWS, NAND_MAX_BANKS);
    if (fmss_clear_irq())
        return NAND_ERR_TIMEOUT;
    discard_dcache_range(nand_idbuf, sizeof(nand_idbuf));
    if (fmss_start() || fmss_wait())
        return NAND_ERR_TIMEOUT;
    discard_dcache_range(nand_idbuf, sizeof(nand_idbuf));
    return 0;
}

/* After a failed read, reset the chips and verify their IDs. */

static int nand_reset_chips(void)
{
    unsigned int i;

    if (fmss_reset() || nand_reset_and_read_ids())
        return NAND_ERR_TIMEOUT;
    for (i = 0; i < nand_geom.banks; i++)
        if (nand_idbuf[nand_geom.ce[i]] != nand_geom.id)
            return NAND_ERR_NOCHIP;
    return 0;
}

/* Decode ID fields for diagnostics using the legacy Samsung/Hynix format.
 * Other vendors encode spare size differently; use the part table for geometry. */
void nand_decode_id(uint32_t id, struct nand_id *out)
{
    static const struct { uint8_t code; const char *name; } makers[] =
    {
        { 0xad, "Hynix" }, { 0x98, "Toshiba" }, { 0xec, "Samsung" },
        { 0x2c, "Micron" }, { 0x89, "Intel" },
    };
    uint8_t b3 = (id >> 16) & 0xff, b4 = id >> 24;
    unsigned int i;

    out->maker = id & 0xff;
    out->device = (id >> 8) & 0xff;
    out->byte3 = b3;
    out->byte4 = b4;
    out->maker_name = "unknown";
    for (i = 0; i < ARRAYLEN(makers); i++)
        if (makers[i].code == out->maker)
            out->maker_name = makers[i].name;
    out->dies_per_ce = 1 << (b3 & 3);  /* byte 3 bits 1..0 */
    out->cell_levels = 2 << ((b3 >> 2) & 3);  /* bits 3..2: 2 = SLC, 4 = MLC */
    out->planes = 1 << ((b3 >> 4) & 3);  /* bits 5..4 */
    out->interleave = (b3 >> 6) & 1;  /* bit 6 */
    out->cache_program = (b3 >> 7) & 1;  /* bit 7 */
    out->page_size = 1024 << (b4 & 3);  /* byte 4 bits 1..0: 1/2/4/8 KiB */
    out->spare_per_512 = (b4 & 4) ? 16 : 8;  /* bit 2 */
    out->block_kib = 64 << ((b4 >> 4) & 3);  /* bits 5..4: 64..512 KiB */
    out->bus_width = (b4 & 0x40) ? 16 : 8;  /* bit 6 */
}

static struct nand_id nand_id_info;
static bool nand_id_valid;   /* some chip enable answered */
static bool nand_ids_valid;  /* a detection ran: nand_idbuf holds READ ID */

const struct nand_id *nand_get_id(void)
{
    return nand_id_valid ? &nand_id_info : NULL;
}

/* ==== Timing ==== */
static unsigned int ceil_div(unsigned int a, unsigned int b)
{
    return (a + b - 1) / b;
}

/* Convert cycle, pulse and hold times in ns to FMC_CTRL0 timing fields. */
/* Use truncated bus-clock periods, rounding each duration up to clocks.
 * Stretch hold to cover the cycle; store pulse/hold minus one and setup as
 * hold plus one, clamped to three bits. */
static uint32_t nand_calc_timing(unsigned int t_cycle, unsigned int t_pulse,
                                 unsigned int t_hold)
{
    unsigned int ns = 1000 / NAND_BUS_MHZ;     /* per clock, rounded down */
    unsigned int cycle = ceil_div(t_cycle, ns);
    unsigned int pulse = ceil_div(t_pulse, ns);
    unsigned int hold = ceil_div(t_hold, ns);
    unsigned int setup;

    if (hold + pulse < cycle)
        hold = cycle - pulse;
    hold = hold > 1 ? hold - 1 : 1;
    pulse = pulse > 1 ? pulse - 1 : 1;
    setup = MIN(hold + 1, 7u);
    hold = MIN(hold, 7u);
    pulse = MIN(pulse, 7u);
    return (pulse << 16) | (hold << 12) | (setup << 28);
}

/* Clocks and pins on, sequencer reset, RESET + READ ID, match what answered
 * against the population table, fill nand_geom, compute the timing and
 * select the ECC mode. Idempotent. Returns 0, NAND_ERR_TIMEOUT (sequencer
 * did not answer), NAND_ERR_NOCHIP (nothing answered, or a part not in the
 * table) or NAND_ERR_UNSUPPORTED (a known part in a population the nano 4G
 * firmware does not drive either, or one this driver's compile-time page
 * layout cannot handle). nand_get_id() and nand_get_raw_ids() are valid
 * after any return but TIMEOUT, for the bootloader's diagnostics. */
int nand_phys_init(void)
{
    const struct nand_population *pop = NULL, *unconfigured = NULL;
    const struct nand_part *part;
    unsigned int i, banks = 0;

    if (nand_phys_ready)
        return 0;

    /* Controller and ECC clocks on */
    clockgate_enable(CLOCKGATE_FMC, true);
    clockgate_enable(CLOCKGATE_FMC_ECC, true);

    /* NAND bus pins: the values the BootROM programs before it reads NAND
     * (in its own NAND boot path); this pin setup was used for every read
     * on hardware so far. Ports 6 and 7 already hold these values
     * after gpio_preinit(), port 8 differs in pins 2..5. */
    /* PCON(n): 4 bits per pin (function select). Port 6 pins 1..7 and port 7
     * pins 0..7 -> function 2, port 8 pin 0 -> 2 and pins 2..5 -> 3, the
     * other pins unchanged. The pin functions (NAND data / CLE / ALE / WE /
     * RE / CE / R-B) behind these numbers are not documented: the values are
     * the bootROM's. */
    PCON(6) = (PCON(6) & 0xf) | 0x22222220;
    PCON(7) = 0x22222222;
    PCON(8) = (PCON(8) & 0xff0000f0) | 0x333302;

    /* The sequencer fetches its programs from memory */
    commit_dcache_range(fmss_prog_reset, sizeof(fmss_prog_reset));
    commit_dcache_range(fmss_prog_readid, sizeof(fmss_prog_readid));
    commit_dcache_range(fmss_prog_read, sizeof(fmss_prog_read));

#ifdef NAND_WRITABLE
    commit_dcache_range(fmss_prog_program, sizeof(fmss_prog_program));
    commit_dcache_range(fmss_prog_erase, sizeof(fmss_prog_erase));
#endif

    if (fmss_reset() || nand_reset_and_read_ids())
        return NAND_ERR_TIMEOUT;

    /* bank i drives CE ce[i]; decode the first populated chip for display. */
    nand_ids_valid = true;
    nand_id_valid = false;
    for (i = 0; i < NAND_MAX_BANKS; i++)
    {
        if (nand_ce_empty(nand_idbuf[i]))
            continue;
        if (!nand_id_valid)
        {
            nand_decode_id(nand_idbuf[i], &nand_id_info);
            nand_id_valid = true;
        }
        nand_geom.ce[banks++] = i;
    }

    /* Select the first exact population match with a supported layout. */
    for (i = 0; i < ARRAYLEN(nand_populations) && !pop; i++)
    {
        if (!nand_population_matches(&nand_populations[i], nand_idbuf))
            continue;
        if (nand_populations[i].layout)
            pop = &nand_populations[i];
        else
            unconfigured = &nand_populations[i];
    }
    if (!pop)
    {
        if (banks && (unconfigured || nand_find_part(nand_idbuf[nand_geom.ce[0]])))
            return NAND_ERR_UNSUPPORTED;  /* a known part, an unlisted or undriven population */
        return NAND_ERR_NOCHIP;
    }
    part = nand_find_part(pop->id);
    if (!part)
        return NAND_ERR_NOCHIP;  /* a population row without its part: table error */
    /* Reject layouts incompatible with the static request lists and ECC setup. */
    if (part->page_size != NAND_PAGE_SIZE || banks != pop->groups * pop->chips)
        return NAND_ERR_UNSUPPORTED;

    nand_geom.id = pop->id;
    nand_geom.banks = banks;
    nand_geom.blocks = part->blocks;
    nand_geom.pages_per_block = part->pages_per_block;
    nand_geom.page_size = part->page_size;
    nand_geom.spare_size = part->spare;
    nand_geom.vendor = part->vendor;
    nand_geom.layout = pop->layout;
    nand_timing = nand_calc_timing(pop->t_read[0], pop->t_read[1], pop->t_read[2]);

#ifdef NAND_WRITABLE
    nand_program_timing = nand_calc_timing(pop->t_write[0], pop->t_write[1],
                                           pop->t_write[2]);
#endif

    /* BCH16 whenever the spare area holds it (10 metadata + 26 parity bytes
     * per sector: 218 on a 4 KiB page, 426 on an 8 KiB one), else BCH8
     * (10 + 13 per sector), as Apple's table and FTL choose. ECC_CTRL bit 2
     * selects BCH16; 0xa00 includes metadata in sector 0. Length fields
     * store byte count minus one. */
    if (10 + SECTORS_PER_PAGE * 26 <= part->spare)
    {
        nand_geom.ecc_bits = 16;
        nand_ecc_mode = 0x5;  /* BCH16 decode */
        nand_ecc_cfg = 0xa05;  /* BCH16 decode + meta */
        nand_ecc_hdrlen = 26 + 9;  /* = 35 = 10 meta + 26 parity - 1 */
        nand_ecc_parlen = 26 - 1;  /* = 25 */
    }
    else
    {
        nand_geom.ecc_bits = 8;
        nand_ecc_mode = 0x1;  /* BCH8 decode */
        nand_ecc_cfg = 0xa01;  /* BCH8 decode + meta */
        nand_ecc_hdrlen = 13 + 9;  /* = 22 = 10 meta + 13 parity - 1 */
        nand_ecc_parlen = 13 - 1;  /* = 12 */
    }

    nand_phys_ready = true;
    return 0;
}

/* The eight READ ID words of the last detection (CE0..CE7, 0 or ~0 for an
 * empty chip enable), NULL before one ran */
const uint32_t *nand_get_raw_ids(void)
{
    return nand_ids_valid ? nand_idbuf : NULL;
}

/* Geometry of the detected chips, NULL until nand_phys_init() succeeded */
const struct nand_geometry *nand_get_geometry(void)
{
    return nand_phys_ready ? &nand_geom : NULL;
}

uint32_t nand_get_read_count(void)
{
    return nand_pages_read;
}

/* ==== Page read ==== */
/* Read the pages in nand_rows/nand_cemasks/nand_dmalist. Single-page reads
 * return per-sector status through secstat and may return NAND_ERASED. */
/* data is used for cache maintenance; DMA addresses are already in the list.
 * On fault or timeout, reset and re-identify the chips. */
static int fmss_read(unsigned int n, void *data, uint8_t *secstat)
{
    uint32_t result;
    int rc;

    FMSS_WR(P_ROWS, NAND_DMA_ADDR(nand_rows));
    FMSS_WR(P_CEMASKS, NAND_DMA_ADDR(nand_cemasks));
    FMSS_WR(P_COUNT, n);
    FMSS_WR(P_META, NAND_DMA_ADDR(nand_meta));
    FMSS_WR(P_DMALIST, NAND_DMA_ADDR(nand_dmalist));
    FMSS_WR(P_STATS, NAND_DMA_ADDR(nand_hist));
    FMSS_WR(P_ECCBUF, secstat ? NAND_DMA_ADDR(secstat) : 0);  /* 0 = no status bytes */
    FMSS_WR(P_CHUNKS, CHUNKS_PER_PAGE);
    FMSS_WR(P_TIMING, nand_timing);
    FMSS_WR(P_ECCMODE, nand_ecc_mode);
    FMSS_WR(P_ECCCFG, nand_ecc_cfg);
    FMSS_WR(P_HDRLEN, nand_ecc_hdrlen);
    FMSS_WR(P_PARLEN, nand_ecc_parlen);
    FMSS_WR(FMSS_PROG, NAND_DMA_ADDR(fmss_prog_read));

    discard_dcache_range(data, n * NAND_PAGE_SIZE);
    discard_dcache_range(nand_meta, n * NAND_META_SIZE);
    if (secstat)
        discard_dcache_range(secstat, SECTORS_PER_PAGE);
    discard_dcache_range(nand_hist, sizeof(nand_hist));
    commit_dcache_range(nand_rows, n * sizeof(uint32_t));
    commit_dcache_range(nand_cemasks, n * sizeof(uint32_t));
    commit_dcache_range(nand_dmalist, n * CHUNKS_PER_PAGE * sizeof(uint32_t));

    nand_pages_read += n;
    rc = fmss_start();
    if (!rc)
        rc = fmss_wait();
    if (rc)
    {
        nand_reset_chips();
        return NAND_ERR_TIMEOUT;
    }

    /* nothing may have pulled the DMA targets into the cache meanwhile */
    discard_dcache_range(data, n * NAND_PAGE_SIZE);
    discard_dcache_range(nand_meta, n * NAND_META_SIZE);
    if (secstat)
        discard_dcache_range(secstat, SECTORS_PER_PAGE);

    /* Result word (sequencer r6): bit 30 = some sector uncorrectable,
     * bit 29 = some sector erased, bits 0..15 = corrected-bit counts seen */
    result = FMSS_RD(FMSS_RESULT);
    if (result & FMSS_RESULT_UECC)
    {
        /* An erased page whose blank sectors picked up a few flipped bits
         * decodes as erased + up to two uncorrectable sectors */
        if (secstat)
        {
            /* secstat order: four status bytes per u32, the first sector in
             * the most significant byte); only counted here,
             * so the order does not matter */
            unsigned int i, blank = 0, bad = 0;
            for (i = 0; i < SECTORS_PER_PAGE; i++)
            {
                if (secstat[i] == 0xfe)  /* erased sector */
                    blank++;
                else if (secstat[i] == 0xff)  /* uncorrectable sector */
                    bad++;
            }
            if (bad < 3 && blank + bad == SECTORS_PER_PAGE)
                return NAND_ERASED;
        }
        return NAND_ERR_ECC;
    }
    /* NAND_ERASED requires every sector erased and none corrected. */
    if (secstat && (result & FMSS_RESULT_ERASED)
        && !(result & FMSS_RESULT_NCORR))
        return NAND_ERASED;
    return NAND_OK;
}

/* Request list entry i: page `page` (row in the chip) on CE `bank`, data to
 * data + i * NAND_PAGE_SIZE as 2 KiB DMA chunks (as m2fmssReadScatteredPages) */
static void nand_set_request(unsigned int i, unsigned int bank, uint32_t page,
                             uint8_t *data)
{
    unsigned int c;

    nand_cemasks[i] = 1u << nand_geom.ce[bank];
    nand_rows[i] = page;
    for (c = 0; c < CHUNKS_PER_PAGE; c++)
        nand_dmalist[i * CHUNKS_PER_PAGE + c] =
            NAND_DMA_ADDR(data + i * NAND_PAGE_SIZE + c * 2048);
}

/* Read one page with sector status. Erased data and metadata become 0xff.
 * buf must be cache-line aligned. */
static int nand_read_page_once(unsigned int bank, uint32_t page, uint8_t *buf,
                               void *meta)
{
    int rc;

    nand_set_request(0, bank, page, buf);
    rc = fmss_read(1, buf, nand_secstat);
    if (rc == NAND_ERASED)
    {
        memset(buf, 0xff, NAND_PAGE_SIZE);
        memset(nand_meta, 0xff, NAND_META_SIZE);
    }
    if (meta)
        memcpy(meta, nand_meta, NAND_META_SIZE);
    return rc;
}

/* Retry once after a timeout or ECC failure. fmss_read already resets the
 * chips on timeout; ECC failures need an explicit reset here. */
int nand_read_page(unsigned int bank, uint32_t page, void *data, void *meta)
{
    uint8_t *buf = data;
    int rc;

    if (!nand_phys_ready || bank >= nand_geom.banks)
        return NAND_ERR_NOCHIP;
    if ((uintptr_t)buf & (CACHEALIGN_SIZE - 1))
        buf = nand_bounce;

    rc = nand_read_page_once(bank, page, buf, meta);
    if (rc < 0)
    {

        if (rc == NAND_ERR_ECC && nand_reset_chips())
            return NAND_ERR_TIMEOUT;
        rc = nand_read_page_once(bank, page, buf, meta);
    }
    if (buf != data)
        memcpy(data, buf, NAND_PAGE_SIZE);
    return rc;
}

/* Read multiple pages without retries. The FTL retries failures page by page. */
int nand_read_pages(unsigned int n, const uint8_t *bank, const uint32_t *page,
                    void *data, void *meta)
{
    unsigned int i;
    int rc;

    if (!nand_phys_ready)
        return NAND_ERR_NOCHIP;
    if (n == 0 || n > NAND_MAX_PAGES_PER_READ
        || ((uintptr_t)data & (CACHEALIGN_SIZE - 1)))
        return NAND_ERR_UNSUPPORTED;
    for (i = 0; i < n; i++)
    {
        if (bank[i] >= nand_geom.banks)
            return NAND_ERR_NOCHIP;
        nand_set_request(i, bank[i], page[i], data);
    }
    rc = fmss_read(n, data, NULL);
    if (rc == NAND_OK && meta)
        memcpy(meta, nand_meta, n * NAND_META_SIZE);
    return rc;
}

#ifdef NAND_WRITABLE

static int nand_finish_mutation(void)
{
    int rc = fmss_start();
    if (!rc)
        rc = fmss_wait();
    if (rc || (FMSS_RD(FMSS_RESULT) & (1u << 27)))
    {
        nand_reset_chips();
        return NAND_ERR_TIMEOUT;
    }
    if (FMSS_RD(FMSS_RESULT) & 1)
    {
        nand_reset_chips();
        return NAND_ERR_WRITE;
    }
    return NAND_OK;
}

int nand_device_program(unsigned int bank, uint32_t page,
                        const void *data, const void *meta)
{
    const void *source = data;

    if (!nand_phys_ready || bank >= nand_geom.banks)
        return NAND_ERR_NOCHIP;
    if (!data || !meta || page >= nand_geom.blocks * nand_geom.pages_per_block)
        return NAND_ERR_UNSUPPORTED;
    if ((uintptr_t)data & (CACHEALIGN_SIZE - 1))
    {
        memcpy(nand_bounce, data, NAND_PAGE_SIZE);
        source = nand_bounce;
    }
    memcpy(nand_meta, meta, NAND_META_SIZE);

    commit_dcache_range(source, NAND_PAGE_SIZE);
    commit_dcache_range(nand_meta, NAND_META_SIZE);

    FMSS_WR(P_ROWS, page);
    FMSS_WR(P_CEMASKS, 1u << nand_geom.ce[bank]);
    FMSS_WR(P_META, NAND_DMA_ADDR(nand_meta));
    FMSS_WR(P_DMALIST, NAND_DMA_ADDR(source));
    FMSS_WR(P_TIMING, nand_program_timing);

    FMSS_WR(P_ECCMODE, (nand_ecc_mode & ~1u) | 2);
    FMSS_WR(P_ECCCFG, (nand_ecc_cfg & ~1u) | 2);
    FMSS_WR(P_HDRLEN, nand_ecc_hdrlen);
    FMSS_WR(P_PARLEN, nand_ecc_parlen);
    FMSS_WR(FMSS_PROG, NAND_DMA_ADDR(fmss_prog_program));
    return nand_finish_mutation();
}

int nand_device_erase(unsigned int bank, uint32_t block)
{
    if (!nand_phys_ready || bank >= nand_geom.banks)
        return NAND_ERR_NOCHIP;
    if (block >= nand_geom.blocks)
        return NAND_ERR_UNSUPPORTED;
    FMSS_WR(P_ROWS, block * nand_geom.pages_per_block);
    FMSS_WR(P_CEMASKS, 1u << nand_geom.ce[bank]);
    FMSS_WR(P_TIMING, nand_program_timing);
    FMSS_WR(FMSS_PROG, NAND_DMA_ADDR(fmss_prog_erase));
    return nand_finish_mutation();
}
#endif

/* Storage API: one sector is a 4096-byte logical page on the nano 4G. On
 * the nano 5G an FTL page (8192 bytes) holds 16 sectors of 512 bytes, the
 * drive is read-only and the RAM disk holds the root volume. */
#if (CONFIG_STORAGE & STORAGE_NAND)
#define NAND_SECTORS_PER_PAGE (NAND_PAGE_SIZE / SECTOR_SIZE)
static struct mutex nand_mutex;  /* serialises reads, writes and flushes */
static long nand_last_activity_value = -1;
static bool nand_ready;  /* physical layer and FTL mounted */
static int nand_init_rc = 1;    /* 1 = not tried yet */

/* The storage device is the data area, the disk Apple's firmware presents
 * to a host in disk mode. The flash MBR (FTL page 0) describes the firmware
 * partition (type 0x3f, or type 0 on older layouts) and everything after
 * its end is the data area. The data area starts with its own MBR, whose
 * FAT32 partition normally begins at sector 63. Without a firmware
 * partition the whole FTL is the storage device. */
static uint32_t nand_data_start;
static uint8_t nand_mbr[NAND_PAGE_SIZE] CACHEALIGN_ATTR;

static uint32_t nand_find_data_start(void)
{
    uint32_t total = ftl_num_sectors();

    if (ftl_read(0, 1, nand_mbr) || nand_mbr[510] != 0x55
        || nand_mbr[511] != 0xaa)
        return 0;
    for (int i = 0; i < 4; i++)
    {
        const uint8_t *e = nand_mbr + 0x1be + 16 * i;
        uint32_t start = e[8] | (e[9] << 8) | (e[10] << 16)
                         | ((uint32_t)e[11] << 24);
        uint32_t size = e[12] | (e[13] << 8) | (e[14] << 16)
                        | ((uint32_t)e[15] << 24);
#if NAND_SECTORS_PER_PAGE > 1
        /* nano 5G: the flash MBR lists the FAT partition itself, so the
         * whole FTL is the disk */
        if (e[4] == 0x0b || e[4] == 0x0c)
            return 0;
#endif
        if ((e[4] == 0x3f || e[4] == 0x00) && size && start < total
            && size < total - start)
            return start + size;
    }
    return 0;
}

/* Idempotent: returns the cached result after the first call (0 or the
 * negative NAND_ERR_* of nand_phys_init() / ftl_init()) */
int nand_init(void)
{
    int rc;

    if (nand_init_rc <= 0)
        return nand_init_rc;

    mutex_init(&nand_mutex);
    rc = nand_phys_init();
    if (rc == 0)
        rc = ftl_init();
    if (rc == 0)
        nand_data_start = nand_find_data_start();
    nand_init_rc = rc;
    nand_ready = (rc == 0);
#ifdef STORAGE_RAMDISK_FIRST
    /* a second drive: the root volume on the RAM disk works without it */
    return 0;
#else
    return rc;
#endif
}

#ifdef HAVE_MULTIDRIVE
int nand_num_drives(int first_drive)
{
    (void)first_drive;
#ifdef IPOD_NANO5G
    /* Data partition plus a read-only view of the complete logical FTL. */
    return 2;
#else
    return 1;
#endif
}
#endif

uint32_t nand_get_data_start(void)
{
    return nand_data_start;
}

/* Base FTL page for the selected NAND drive. Nano 5G drive 1 is a
 * read-only view from logical page zero, including the MBR and firmware
 * partition; drive 0 remains Apple's user data area. */
static uint32_t nand_first_lpn(int drive)
{
#ifdef IPOD_NANO5G
    if (drive == 1)
        return 0;
#else
    (void)drive;
#endif
    return nand_data_start;
}

static sector_t nand_num_sectors(int drive)
{
    uint32_t first_lpn = nand_first_lpn(drive);
    uint32_t total_lpn = ftl_num_sectors();
    if (first_lpn > total_lpn)
        return 0;
    return (sector_t)(total_lpn - first_lpn) * NAND_SECTORS_PER_PAGE;
}

#if NAND_SECTORS_PER_PAGE > 1
static uint8_t nand_bounce[NAND_PAGE_SIZE] CACHEALIGN_ATTR;

/* Sectors smaller than the FTL page: whole aligned pages straight into the
 * buffer, the rest through a page buffer */
static int nand_read_split(sector_t start, int count, uint8_t *buf,
                           uint32_t first_lpn)
{
    while (count > 0)
    {
        uint32_t page = first_lpn + start / NAND_SECTORS_PER_PAGE;
        unsigned int off = start % NAND_SECTORS_PER_PAGE, n;

        if (!off && count >= NAND_SECTORS_PER_PAGE
            && !((uintptr_t)buf & (CACHEALIGN_SIZE - 1)))
        {
            n = count / NAND_SECTORS_PER_PAGE;
            if (ftl_read(page, n, buf))
                return -3;
            n *= NAND_SECTORS_PER_PAGE;
        }
        else
        {
            n = MIN((unsigned int)count, NAND_SECTORS_PER_PAGE - off);
            if (ftl_read(page, 1, nand_bounce))
                return -3;
            memcpy(buf, nand_bounce + off * SECTOR_SIZE, n * SECTOR_SIZE);
        }
        start += n;
        count -= n;
        buf += n * SECTOR_SIZE;
    }
    return 0;
}
#endif

/* Read raw logical FTL pages, including the MBR, firmware and SystemConfig.
 * These are 4096 bytes on the nano 4G and 8192 bytes on the nano 5G. */
int nand_read_flash_pages(uint32_t lpn, int count, void *buf)
{
    int rc;

    if (!nand_ready)
        return -1;
    if (count <= 0)
        return 0;
    if (lpn >= ftl_num_sectors()
        || (uint32_t)count > ftl_num_sectors() - lpn)
        return -2;

    mutex_lock(&nand_mutex);
    rc = ftl_read(lpn, (uint32_t)count, buf);
    nand_last_activity_value = current_tick;
    mutex_unlock(&nand_mutex);
    return rc ? -3 : 0;
}

/* Read raw logical storage sectors, starting at the MBR and including the
 * firmware partition. A nano 5G FTL page contains multiple sectors. */
int nand_read_flash_sectors(uint32_t sector, int count, void *buf)
{
    uint32_t total = ftl_num_sectors() * NAND_SECTORS_PER_PAGE;
    int rc;

    if (!nand_ready)
        return -1;
    if (count <= 0)
        return 0;
    if (sector >= total || (uint32_t)count > total - sector)
        return -2;

    mutex_lock(&nand_mutex);
#if NAND_SECTORS_PER_PAGE > 1
    rc = nand_read_split(sector, count, buf, 0);
#else
    rc = ftl_read(sector, (uint32_t)count, buf);
#endif
    nand_last_activity_value = current_tick;
    mutex_unlock(&nand_mutex);
    return rc ? -3 : 0;
}

void nand_spindown(int seconds)
{
    (void)seconds;
}

void nand_spin(void)
{
}

void nand_sleepnow(void)
{
}

#ifdef CONFIG_STORAGE_MULTI
/* called through storage.c only when there are several drivers */
void nand_enable(bool on)
{
    (void)on;
}

int nand_spinup_time(void)
{
    return 0;
}
#endif

#ifdef HAVE_STORAGE_FLUSH
int nand_flush(void)
{
#ifndef NAND_WRITABLE
    return 0;   /* nothing is ever written */
#else
    int rc;
    if (!nand_ready)
        return -1;
    mutex_lock(&nand_mutex);
    rc = ftl_flush();
    mutex_unlock(&nand_mutex);
    return rc;
#endif
}
#endif

#ifdef HAVE_STORAGE_READONLY
bool nand_readonly(IF_MD_NONVOID(int drive))
{
    IF_MD((void)drive);
#ifndef NAND_WRITABLE
    return true;
#else
    return false;
#endif
}
#endif

/* start / incount in 4096-byte sectors of the data area. Returns 0, -1 not
 * mounted, -2 out of range, -3 FTL read error (unreadable or bad-marked
 * page). */
int nand_read_sectors(IF_MD(int drive,) sector_t start, int incount,
                      void* inbuf)
{
    int rc;
    int ldrive = IF_MD_DRV(drive);

    if (!nand_ready)
        return -1;
    if (incount <= 0)
        return 0;
    if (start >= nand_num_sectors(ldrive)
        || (sector_t)incount > nand_num_sectors(ldrive) - start)
        return -2;

    mutex_lock(&nand_mutex);
#if NAND_SECTORS_PER_PAGE > 1
    rc = nand_read_split(start, incount, inbuf, nand_first_lpn(ldrive));
#else
    rc = ftl_read(nand_first_lpn(ldrive) + (uint32_t)start,
                  (uint32_t)incount,
                  inbuf);
#endif
    nand_last_activity_value = current_tick;
    mutex_unlock(&nand_mutex);
    return rc ? -3 : 0;
}

/* Firmware writes reach NAND before returning; bootloader writes fail. */
int nand_write_sectors(IF_MD(int drive,) sector_t start, int count,
                       const void* outbuf)
{
    int ldrive = IF_MD_DRV(drive);
    if (!nand_ready)
        return -1;
    if (count < 0 || start > nand_num_sectors(ldrive)
        || (sector_t)count > nand_num_sectors(ldrive) - start)
        return -2;
    if (!count)
        return 0;
#ifndef NAND_WRITABLE
    (void)outbuf;
    return -3;
#else
    int rc;
    mutex_lock(&nand_mutex);
    rc = ftl_write(nand_first_lpn(ldrive) + (uint32_t)start,
                   (uint32_t)count,
                   outbuf);
    nand_last_activity_value = current_tick;
    mutex_unlock(&nand_mutex);
    return rc;
#endif
}

int nand_event(long id, intptr_t data)
{
    (void)id;
    (void)data;
    return 0;
}

#ifdef STORAGE_GET_INFO
void nand_get_info(IF_MD(int drive,) struct storage_info *info)
{
    int ldrive = IF_MD_DRV(drive);
    info->sector_size = SECTOR_SIZE;  /* 4096: one FTL page; 5G 512 */
    info->num_sectors = nand_ready ? nand_num_sectors(ldrive) : 0;
    info->vendor = "Apple";
#ifdef IPOD_NANO5G
    info->product = ldrive == 1 ? "iPod Nano 5G FTL backup" : "iPod Nano 5G";
#else
    info->product = "iPod Nano 4G";
#endif
    info->revision = "0.1";
}
#endif

long nand_last_disk_activity(void)
{
    return nand_last_activity_value;
}
#endif /* CONFIG_STORAGE & STORAGE_NAND */
