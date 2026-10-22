/*
 * This config file is for iPod Nano 5th Generation
 *
 * Bring-up state: the S5L8730 runs on the clocks and SDRAM set up by
 * Apple's WTF stage (started tethered with wInd3x). Storage is a RAM disk
 * preloaded with a FAT image. The PMU (D1759) drives the backlight and the
 * battery ADC; NAND, audio, USB, charging and RTC are not driven yet.
 */

#define IPOD_ARCH 1

/* For Rolo and boot loader */
#define MODEL_NUMBER 134

#define MODEL_NAME   "Apple iPod Nano 5G"

/* define the bitmask of hardware sample rates */
#define HW_SAMPR_CAPS   (SAMPR_CAP_44 | SAMPR_CAP_22 | SAMPR_CAP_11 \
                       | SAMPR_CAP_48 | SAMPR_CAP_24 | SAMPR_CAP_12 \
                       | SAMPR_CAP_32 | SAMPR_CAP_16 | SAMPR_CAP_8)

/* define this if you have a bitmap LCD display */
#define HAVE_LCD_BITMAP

/* define this if you have a colour LCD */
#define HAVE_LCD_COLOR

/* define this if you want album art for this target */
#define HAVE_ALBUMART

/* define this to enable bitmap scaling */
#define HAVE_BMP_SCALING

/* define this to enable JPEG decoding */
#define HAVE_JPEG

/* LCD stays visible without backlight - simulator hint */
#define HAVE_TRANSFLECTIVE_LCD

/* define this if you have access to the quickscreen */
#define HAVE_QUICKSCREEN

/* define this if you would like tagcache to build on this target */
#define HAVE_TAGCACHE

/* define this if the unit uses a scrollwheel for navigation */
#define HAVE_SCROLLWHEEL
#define HAVE_WHEEL_ACCELERATION
#define WHEEL_ACCEL_START 270
#define WHEEL_ACCELERATION 3

/* Define this if you can read an absolute wheel position */
#define HAVE_WHEEL_POSITION

/* the wheel controller speaks the nano 3G/4G protocol (measured) */
#define CONFIG_KEYPAD IPOD_4G_PAD

#define CONFIG_NAND 0   /* the S5L87xx NAND driver, not a generic one */

/* Bring-up: a RAM disk at RAMDISK_ADDR, loaded with a FAT image before
 * Rockbox starts, holds .rockbox and is the first drive (the root volume).
 * The NAND, read-only, is the second: Apple's data partition with its
 * 4096-byte FAT sectors on a drive of 512-byte sectors (the FTL page is
 * 8192 bytes), as on the iPod 6G hard disk. */
#ifndef BOOTLOADER
/* LIS331DLF, for the pedometer plugin */
#define HAVE_ACCELEROMETER
#define CONFIG_STORAGE (STORAGE_RAMDISK | STORAGE_NAND)
#define NUM_DRIVES 2
#define STORAGE_RAMDISK_FIRST
#define HAVE_STORAGE_READONLY
#define MAX_VIRT_SECTOR_SIZE 4096
#else
#define CONFIG_STORAGE STORAGE_RAMDISK
#endif
#define RAMDISK_ADDR    0x0a000000
#define RAMDISK_SECTORS 16384   /* 8 MiB; the dev loop keeps images above */
/* the RAM disk image is small enough to be FAT16 */
#define HAVE_FAT16SUPPORT

/* LCD dimensions */
#define LCD_WIDTH  240
#define LCD_HEIGHT 376
/* sqrt(376^2 + 240^2) / 2.2 = 202.8 */
#define LCD_DPI 203
#define LCD_DEPTH  16   /* pseudo 262.144 colors */
#define LCD_PIXELFORMAT RGB565 /* rgb565 */

#ifdef BOOTLOADER
#define DISABLE_ALPHA_BITMAP
#define DISABLE_BACKTRACE
#endif

/* Define this to have CPU boosted while scrolling in the UI */
#define HAVE_GUI_BOOST

#define AB_REPEAT_ENABLE
#define ACTION_WPSAB_SINGLE ACTION_WPS_BROWSE

/* Define this to enable morse code input */
#define HAVE_MORSE_INPUT

/* Define this if you do software codec */
#define CONFIG_CODEC SWCODEC

/* define this if you have a real-time clock */
#define CONFIG_RTC  0

#define CONFIG_LCD LCD_IPOD6GNANO3G4G

/* Define the type of audio codec: a Cirrus Logic CS42L58 (Apple's diags),
 * driven like the CS42L55, on I2S2 (pcm-s5l8702.c, cscodec-nano5g.c) */
#define HAVE_CS42L55

#define HAVE_PCM_DMA_ADDRESS

/* Define this for LCD backlight available */
#define HAVE_BACKLIGHT
#define HAVE_BACKLIGHT_BRIGHTNESS

/* Main LCD backlight brightness range and defaults (D1759 LEDOUT >> 2;
 * Apple leaves 0x28) */
#define MIN_BRIGHTNESS_SETTING      1
#define MAX_BRIGHTNESS_SETTING      0x3f
#define DEFAULT_BRIGHTNESS_SETTING  0x28

/* Define this if you have a software controlled poweroff */
#define HAVE_SW_POWEROFF

/* The number of bytes reserved for loadable codecs */
#define CODEC_SIZE 0x100000

/* The number of bytes reserved for loadable plugins */
#define PLUGIN_BUFFER_SIZE 0x80000

#define BATTERY_CAPACITY_DEFAULT 240 /* default battery capacity */
#define BATTERY_CAPACITY_MIN     200 /* min. capacity selectable */
#define BATTERY_CAPACITY_MAX     300 /* max. capacity selectable */
#define BATTERY_CAPACITY_INC      10 /* capacity increment */

#define CONFIG_BATTERY_MEASURE VOLTAGE_MEASURE

/* define current usage levels */
#define CURRENT_NORMAL     17  /* playback @48MHz clock, backlight off */
#define CURRENT_BACKLIGHT  23  /* maximum brightness */

/* The exact type of CPU */
#define CONFIG_CPU S5L8730

/* Define this to the CPU frequency */
#define CPU_FREQ        266000000           // TODO: TBC

/* I2C interface */
#define CONFIG_I2C I2C_S5L8702

/* The size of the flash ROM */
#define FLASH_SIZE 0x100000

/* Offset ( in the firmware file's header ) to the file CRC */
#define FIRMWARE_OFFSET_FILE_CRC 0

/* Offset ( in the firmware file's header ) to the real data */
#define FIRMWARE_OFFSET_FILE_DATA 8

#define BOOTFILE_EXT "ipod"
#define BOOTFILE "rockbox." BOOTFILE_EXT
#define BOOTDIR "/.rockbox"

/* Define this if a programmable hotkey is mapped */
#define HAVE_HOTKEY

/* USB: Synopsys DesignWare OTG as on the S5L8720, PHY as in freemyipod's
 * nano 5G U-Boot and Linux; cable presence from the D1759 (status A) */
#define CONFIG_USBOTG USBOTG_DESIGNWARE
#define USB_DW_CLOCK 0
#define USB_DW_TURNAROUND 5
#define HAVE_USBSTACK
#define USB_STATUS_BY_EVENT
#define USB_VENDOR_ID 0x05AC
#define USB_PRODUCT_ID 0x1265
#define USB_DEVBSS_ATTR __attribute__((aligned(32)))
#define USB_READ_BUFFER_SIZE (1024*24)

/* Bring-up conveniences for working on the device over USB alone:
 * logf over USB serial (on by default), leave USB mode when the host ejects
 * the disk, and restart a changed rockbox.ipod without asking */
#define ROCKBOX_HAS_LOGF
#define USB_ENABLE_SERIAL
#define USB_SERIAL_DEFAULT_ON
#define USB_EJECT_LEAVES_USB_MODE
/* no BOOTFILE_CHANGED_ROLO_WITHOUT_ASKING: after an eject the devloop starts
 * the new boot file itself (devloop-nano5g.c) */
