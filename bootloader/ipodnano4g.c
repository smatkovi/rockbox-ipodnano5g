/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2005 by Dave Chapman
 * Copyright (C) 2026 Viktor Krapivin
 *
 * iPod nano 4G (S5L8720) bootloader: split from ipod-s5l87xx.c, which
 * stays the S5L8702 (iPod Classic 6G, nano 3G) bootloader.
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
#include <stdio.h>
#include <string.h>
#include "config.h"
#include "cpu.h"
#include "system.h"
#include "lcd.h"
#include "../kernel-internal.h"
#include "file.h"
#include "file_internal.h"
#include "storage.h"
#include "disk.h"
#include "font.h"
#include "backlight.h"
#include "button.h"
#include "common.h"
#include "rb-loader.h"
#include "loader_strerror.h"
#include "version.h"
#include "applefw.h"
#include "nand-target.h"
#include "s5l87xx.h"
#include "clocking-s5l8702.h"
#include "i2c-s5l8702.h"
#include "pmu-target.h"
#include "power.h"

#define MAX_LOADSIZE (8 * 1024 * 1024)
#define LCD_REDORANGE LCD_RGBPACK(255, 70, 0)

extern void bss_init(void);
extern void lcd_update_pio(void);

static uint32_t clk_at_entry[32];
static uint32_t sm1div_at_entry;

/* Firmware startup contract: construct the 0x120-byte system record from
 * this device's SysCfg private partition. No captured device data is embedded.
 * +0x84 is the board id, +0xe0/+0xe4 the SDRAM size/base, and +0xe8/+0xec
 * the SRAM size/base. The SRAM record contains the magic and block address. */
#define APPLE_CFG_BLOCK     ((volatile uint8_t *)0x22028cc0)
#define APPLE_CFG_RECORD    ((volatile uint32_t *)0x2202ff18)
#define APPLE_CFG_VARIANT   ((volatile uint32_t *)0x2202ff10)
#define APPLE_CFG_TAGS      ((volatile uint32_t *)0x2202ff00)
#define APPLE_CFG_MAGIC     0x53797349u     /* 'IsyS' */
#define SYSCFG_MAGIC_WORD   0x53436667u     /* 'SCfg' */
#define SYSCFG_TAG_HWVR_W   0x48775672u     /* 'HwVr' */
#define SYSCFG_TAG_SRNM_W   0x53724e6du    /* 'SrNm' */
#define SYSCFG_TAG_MODN_W   0x4d6f6423u     /* 'Mod#' */
#define SYSCFG_TAG_REGN_W   0x5265676eu     /* 'Regn' */
#ifdef IPOD_NANO5G
#define APPLE_MODEL_NAME    "iPod N33"
#define APPLE_BOARD_DEFAULT 0x1d000bu
#define APPLE_BOARD_FAMILY  0x1du
#else
#define APPLE_MODEL_NAME    "iPod N58"
#define APPLE_BOARD_DEFAULT 0x17000bu
#define APPLE_BOARD_FAMILY  0x17u
#endif
#define SYSCFG_FIRST_LPN    1               /* private partition: lpn 1..4 */
#define SYSCFG_LPNS         4

static uint8_t apple_cfg_build[0x120] __attribute__((aligned(32)));
static uint8_t apple_cfg_page[NAND_PAGE_SIZE] __attribute__((aligned(32)));

static void put_le32(uint8_t *p, uint32_t v)
{
    p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24;
}

static uint32_t get_le32(const volatile uint8_t *p)
{
    return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24);
}

/* Fill the block from the SysCfg entries on the disk (pages of the private
 * partition) and the constants; returns the board id used. */
static uint32_t apple_cfg_construct(void)
{
    uint8_t *b = apple_cfg_build;
    uint32_t board = APPLE_BOARD_DEFAULT;
    int lpn;

    memset(b, 0, sizeof(apple_cfg_build));
    put_le32(b + 0x00, APPLE_CFG_MAGIC);
    put_le32(b + 0x04, 4);
    strcpy((char *)b + 0x08, APPLE_MODEL_NAME);
    b[0x88] = 'N'; b[0x89] = 'A'; b[0x8a] = 0;
    put_le32(b + 0xe0, (uint32_t)MEMORYSIZE * 0x100000u);
    put_le32(b + 0xe4, 0x08000000u);
    put_le32(b + 0xe8, 0x30000u);
    put_le32(b + 0xec, 0x22000000u);
    put_le32(b + 0xf0, 0x100000u);
    put_le32(b + 0xf4, 0x24000000u);
    put_le32(b + 0x118, 0x7672736eu);
    put_le32(b + 0x11c, 0x02036008u);

    for (lpn = SYSCFG_FIRST_LPN; lpn < SYSCFG_FIRST_LPN + SYSCFG_LPNS; lpn++)
    {
        uint32_t n, i;
        if (nand_read_flash_pages(lpn, 1, apple_cfg_page) != 0)
            continue;
        if (get_le32(apple_cfg_page) != SYSCFG_MAGIC_WORD)
            continue;
        n = get_le32(apple_cfg_page + 0x14);        /* entry count */
        if (n > (sizeof(apple_cfg_page) - 0x18) / 20)
            n = (sizeof(apple_cfg_page) - 0x18) / 20;
        for (i = 0; i < n; i++)
        {
            const uint8_t *e = apple_cfg_page + 0x18 + i * 20;
            uint32_t tag = get_le32(e);
            if (tag == SYSCFG_TAG_HWVR_W)
                /* HwVr: the board id is the second 32-bit word of the
                 * entry's 16 data bytes */
                board = get_le32(e + 8);
            else if (tag == SYSCFG_TAG_SRNM_W)
                memcpy(b + 0x18, e + 4, 16);
            else if (tag == SYSCFG_TAG_MODN_W)
                memcpy(b + 0x98, e + 4, 16);
            else if (tag == SYSCFG_TAG_REGN_W)
                memcpy(b + 0x108, e + 4, 16);
        }
        break;
    }
    if ((board >> 16) != APPLE_BOARD_FAMILY)
        board = APPLE_BOARD_DEFAULT;
    put_le32(b + 0x84, board);
    return board;
}

/* Handoff flags at 0x2202ff10: bit 2 keeps disk mode active without USB;
 * bit 4 selects the connection screen. Bit 5 requests factory reformat and
 * must never be set. */
static uint32_t apple_variant(const char *name)
{
    if (memcmp(name, APPLE_IMG_DISK, 4) == 0)
        return 4;
    return 0;
}

/* Write the SRAM words the image reads; interrupts are already off. */
static void apple_cfg_install(uint32_t variant)
{
    int i;
    for (i = 0; i < 4; i++)
        APPLE_CFG_TAGS[i] = 0;                      /* result tags 0x2202ff00..0x2202ff0f */
    *APPLE_CFG_VARIANT = variant & ~0x20u;          /* never bit 5: reformat */
    memcpy((void *)APPLE_CFG_BLOCK, apple_cfg_build, sizeof(apple_cfg_build));
    APPLE_CFG_RECORD[0] = APPLE_CFG_MAGIC;
    APPLE_CFG_RECORD[1] = (uint32_t)APPLE_CFG_BLOCK;
}

/* Switch CPU mode only after the entry address is in a register. main()
 * runs in SYS mode, whose stack differs from the SVC stack installed by
 * crt0. Changing modes in a C function would make later stack accesses
 * (including a spilled image entry address) use the wrong stack. This
 * non-returning assembly handoff also makes the final cache clean atomic
 * with the D-cache disable: no compiler-generated stores can intervene. */
static void __attribute__((naked, noreturn))
apple_jump(void *entry_addr __attribute__((unused)))
{
    asm volatile(
        "mov r4, r0                    \n"
        "bl commit_discard_idcache     \n"
        "msr cpsr_c, #0xd3             \n"
        "mrc p15, 0, r1, c1, c0, 0     \n"
        "bic r1, r1, #4                \n"
        "mcr p15, 0, r1, c1, c0, 0     \n"
        "mov r1, #0                    \n"
        "mcr p15, 0, r1, c7, c10, 4    \n"
        "mcr p15, 0, r1, c7, c5, 4     \n"
        "adr lr, 1f                    \n"
        "bx r4                         \n"
        "1: b 1b                       \n");
}

static int launch_apple(const char *name)
{
    struct applefw_info info;
    int rc = applefw_load(name, &info);
    if (rc != APPLEFW_OK)
    {
        printf("Cannot load %s: %d", name, rc);
        return rc;
    }
    apple_cfg_construct();
    printf("Starting %s", name);

    /* Leave USB input enabled and at 100 mA until the next image enumerates. */
    unsigned char input = pmu_read(0x0a);
    unsigned char limit = pmu_read(0x33);
    if (input & 8)
        pmu_write(0x0a, input & ~8);
    if (limit & 3)
        pmu_write(0x33, limit & ~3);
    sleep(HZ / 20);

    /* No scheduler calls after this point: changing clocks stops the tick.
     * USB is disconnected, interrupt service is cleared, and the two I2C
     * controllers are left in the polled state expected by the next image. */
    disable_irq();
    {
        volatile uint32_t *clk = (volatile uint32_t *)CLK_BASE;
        unsigned int i, bus;
        /* 1. USB as EFI leaves it */
        clockgate_enable(CLOCKGATE_USBOTG, true);
        clockgate_enable(CLOCKGATE_USBPHY, true);
        *(volatile uint32_t *)(OTGBASE + 0x804) |= 2;   /* soft disconnect */
        OPHYPWR = 0x1f;
        ORSTCON = 1;
        clockgate_enable(CLOCKGATE_USBOTG, false);
        clockgate_enable(CLOCKGATE_USBPHY, false);
        /* 2. VIC */
        for (i = 0; i < 2; i++)
        {
            volatile uint32_t *vic = (volatile uint32_t *)(VIC_BASE + 0x1000 * i);
            unsigned int k;
            vic[0x14 / 4] = ~0u;                /* INTENCLEAR */
            vic[0x0c / 4] = 0;                  /* INTSELECT: all IRQ */
            vic[0x1c / 4] = ~0u;                /* SOFTINTCLEAR */
            for (k = 0; k < 16; k++)
                vic[0xf00 / 4] = 0;             /* VICADDRESS: pop any in-service priority */
        }
        /* 3. clocks: dividers/selectors as at entry, gates = EFI */
        clk[1] = clk_at_entry[1];
        clk[0x08 / 4] = clk_at_entry[0x08 / 4];
        clk[0x0c / 4] = clk_at_entry[0x0c / 4];
        clk[0x10 / 4] = clk_at_entry[0x10 / 4];
        clk[0x14 / 4] = clk_at_entry[0x14 / 4];
        clk[0x70 / 4] = clk_at_entry[0x70 / 4];
        SM1_DIV = sm1div_at_entry;
        clk[0x48 / 4] = 0x000325c5;
        clk[0x4c / 4] = 0xfe2bed2d;
        clk[0x58 / 4] = 0x00000073;
        clk[0x68 / 4] = 0x000000ff;
        clk[0x6c / 4] = 0x00dce779;
        /* Reset both I2C buses. */
        for (bus = 0; bus < 2; bus++)
        {
            volatile uint32_t *iic = (volatile uint32_t *)(bus ? 0x3c900000 : 0x3c600000);
            unsigned int guard = 100000;
            while ((iic[0x10 / 4] & 1) && --guard)
                ;
            iic[0x08 / 4] = 0x40;
            iic[0x14 / 4] = 1;
            iic[0x18 / 4] = 0;
            iic[0x04 / 4] = 0x80;
            iic[0x00 / 4] = 0;
            iic[0x04 / 4] = 0;
            iic[0x0c / 4] = 0x40;
            iic[0x00 / 4] = 0x181;
            iic[0x04 / 4] = 0x10;
            iic[0x28 / 4] = 0;
        }
    }
    apple_cfg_install(apple_variant(name));
    lcd_set_foreground(LCD_REDORANGE);
    lcd_fillrect(0, LCD_HEIGHT - 8, LCD_WIDTH, 8);
    lcd_update_pio();
    apple_jump(info.entry_addr);
}

/* The clickwheel reports held buttons asynchronously after initialization.
 * USEC_TIMER already ran in the first-stage loader: an absolute deadline
 * followed by one read can see BUTTON_NONE even with SELECT+PLAY held.
 * Give every boot a fresh window and latch a stable physical key-combo. */
static int read_apple_boot_combo(uint32_t timeout_us)
{
    uint32_t start = USEC_TIMER;
    uint32_t stable_since = start;
    int candidate = BUTTON_NONE;

    while ((uint32_t)(USEC_TIMER - start) < timeout_us) {
        int btn = button_read_device();
        /* Preserve the reset/DFU chord: allow time to select another mode
         * after releasing MENU+SELECT, before touching NAND. */
        if (btn == (BUTTON_SELECT|BUTTON_MENU)) {
            while (button_read_device() == (BUTTON_SELECT|BUTTON_MENU))
                sleep(HZ/10);
            sleep(HZ);
            start = stable_since = USEC_TIMER;
            candidate = BUTTON_NONE;
            continue;
        }
        if (btn != BUTTON_MENU && btn != (BUTTON_SELECT|BUTTON_PLAY))
            btn = BUTTON_NONE;

        uint32_t now = USEC_TIMER;
        if (btn != candidate) {
            candidate = btn;
            stable_since = now;
        } else if (candidate != BUTTON_NONE
                && (uint32_t)(now - stable_since) >= 50000) {
            return candidate;
        }
        sleep(HZ/100);
    }
    return BUTTON_NONE;
}

/* Which firmware image each boot key-combo selects: MENU = the Apple OS,
 * SELECT+PLAY = disk mode */
static int kernel_launch_combo(int btn)
{
    const char *name = APPLE_IMG_OSOS;      /* MENU: the Apple OS */
    if (btn == (BUTTON_SELECT|BUTTON_PLAY))
        name = APPLE_IMG_DISK;              /* disk mode */
    return launch_apple(name);
}

#ifdef IPOD_NANO5G
#define N5G_RAMDISK_FILE   BOOTDIR "/n5g-ramdisk.img"
#define N5G_RAMDISK_BYTES  (RAMDISK_SECTORS * SECTOR_SIZE)

/* The main firmware's first volume is a writable RAM disk. Load the FAT16
 * image from NAND before jumping so settings and directory-cache updates stay
 * in SDRAM. The NAND FTL remains read-only. */
static bool load_n5g_ramdisk(void)
{
    int fd = open(N5G_RAMDISK_FILE, O_RDONLY);
    if (fd < 0)
        return false;

    off_t len = ffilesize(fd);
    if (len != N5G_RAMDISK_BYTES)
    {
        close(fd);
        return false;
    }

    unsigned char *image = (unsigned char *)RAMDISK_ADDR;
    int rc = read(fd, image, N5G_RAMDISK_BYTES);
    close(fd);
    if (rc != N5G_RAMDISK_BYTES)
        return false;

    /* Reject files that are the right size but not the expected FAT image. */
    return image[510] == 0x55 && image[511] == 0xaa
        && image[11] == 0x00 && image[12] == 0x02
        && image[13] == 2 && image[16] == 2
        && image[19] == (RAMDISK_SECTORS & 0xff)
        && image[20] == (RAMDISK_SECTORS >> 8);
}
#endif

/* Remain available for disk-mode selection after a filesystem/load error. */
static void NORETURN_ATTR boot_error(void)
{
    printf("SELECT+PLAY: disk mode");
    printf("MENU+SELECT: reset");
    while (1)
    {
        if (read_apple_boot_combo(1000000) == (BUTTON_SELECT | BUTTON_PLAY))
            launch_apple(APPLE_IMG_DISK);
        sleep(HZ / 10);
    }
}

void main(void)
{
    int rc, apple_combo;
    usec_timer_init();
    i2c_preinit(0);
    /* The independent SRAM stage initialized SDRAM. crt0 relocated this
     * bootloader above the firmware load area; install Rockbox's MMU now. */
    system_preinit();
    memory_init();
    bss_init();
    for (unsigned int i = 0; i < 32; i++)
        clk_at_entry[i] = ((volatile uint32_t *)CLK_BASE)[i];
    sm1div_at_entry = SM1_DIV;
    system_init();
    kernel_init();
    i2c_init();
    power_init();
    enable_irq();
    button_init();
    apple_combo = read_apple_boot_combo(1000000);

    lcd_init();
    lcd_set_foreground(LCD_WHITE);
    lcd_set_background(LCD_BLACK);
    lcd_clear_display();
    font_init();
    lcd_setfont(FONT_SYSFIXED);
    lcd_update();
    sleep(HZ / 40);
    verbose = true;
    printf("Rockbox boot loader");
    printf("Version: %s", rbversion);
    backlight_init();

#ifdef IPOD_NANO5G
    /* If Hold is locked, the Apple OS needs NAND only. Do not make this
     * fallback depend on the RAM disk or filesystem initialization. */
    if (pmu_holdswitch_locked())
    {
        rc = nand_init();
        if (rc != 0)
            printf("NAND init for Apple OS failed: %d", rc);
        else
            launch_apple(APPLE_IMG_OSOS);
        boot_error();
    }
#endif

    rc = storage_init();
    if (rc != 0)
    {
        printf("Storage error: %d", rc);
#ifdef IPOD_NANO5G
        /* If RAM-disk initialization failed before storage_init reached
         * NAND, still try the signed Apple OS when Hold requests it. */
        if (pmu_holdswitch_locked())
        {
            rc = nand_init();
            if (rc != 0)
                printf("NAND init for Apple OS failed: %d", rc);
            else
                launch_apple(APPLE_IMG_OSOS);
        }
#endif
        boot_error();
    }
    if (!apple_combo)
        apple_combo = read_apple_boot_combo(400000);
    if (pmu_holdswitch_locked())
        apple_combo = BUTTON_MENU;
    if (apple_combo)
    {
        kernel_launch_combo(apple_combo);
        boot_error();
    }
    filesystem_init();
    if (disk_mount_all() <= 0)
    {
        printf("No FAT partition found");
#ifdef IPOD_NANO5G
        /* A damaged, absent, or unsupported data volume must not prevent the
         * original signed OS from starting. The firmware partition is
         * independent of the FAT mount and can still supply OSOS. */
        launch_apple(APPLE_IMG_OSOS);
#endif
        boot_error();
    }
    printf("Loading Rockbox...");
    unsigned char *loadbuffer = (unsigned char *)DRAM_ORIG;
    rc = load_firmware(loadbuffer, BOOTFILE, MAX_LOADSIZE);
    if (rc <= EFILE_EMPTY)
    {
        printf("Cannot load " BOOTFILE ": %s", loader_strerror(rc));
#ifdef IPOD_NANO5G
        /* Until Rockbox is installed, or if its boot file is missing, return
         * to the signed Apple OS instead of stopping at the boot screen. */
        launch_apple(APPLE_IMG_OSOS);
#endif
        boot_error();
    }
#ifdef IPOD_NANO5G
    if (!load_n5g_ramdisk())
    {
        printf("Cannot load " N5G_RAMDISK_FILE);
        launch_apple(APPLE_IMG_OSOS);
        boot_error();
    }
#endif
    disable_irq();
    commit_discard_idcache();
    ((void (*)(void))loadbuffer)();
    /* A firmware entry must never return. */
    while (1);
}
