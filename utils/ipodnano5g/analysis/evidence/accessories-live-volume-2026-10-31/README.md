# Bereinigte Live-Volume-Zusammenfassung

Erfasst am 31.10.2026 über mtools mit ausschließlich lesenden `mdir`- und
`mtype`-Aufrufen gegen den aktuell angeschlossenen iPod-FAT-Datenträger.
Seriennummer und Volume-Kennung wurden nicht in diesen Beleg übernommen.
Es gab keine Schreib-, Flush-, Eject-, Neustart-, DFU- oder Flashoperation.

| Pfad | Größe | Ergebnis |
| --- | ---: | --- |
| `iPod_Control/Device/accessories.reg` | 69 | SHA-256 `b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854`; unveränderter Stockinhalt, `0x44`-Länge 9 (`Pedometer`). |
| `iPod_Control/Device/iPodSettings.xml` | 1.767 | SHA-256 `ec327e09e3617e72013a56f1291ff0fa6301d9a476f3439eddc06cf80ce935f4`. |
| `.rockbox/rockbox.ipod` | 1.079.128 | Ziel `ipodnano5g`, 32 MiB, Version `d49f519a9bM-261024`; SHA-256 `65276d4bf5b88af3c2ff5701a21fa6cd6654e24b4f147d7e7c31395a7023ec16`. |
| `.rockbox/n5g-ramdisk.img` | 8.388.608 | SHA-256 `6fb9df06b8083f8d27d18fdc2bfd70be383c5306b4691d767ef5c9e43c3a0cf5`. |
| `/BOOT.BIN` | — | Nicht vorhanden. |

Lokaler Abgleich der nicht installierten Testdateien:

| Datei | Größe | SHA-256 | ELF-Entry |
| --- | ---: | --- | ---: |
| `candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin` | 736 | `b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e` | — |
| `bootloader-safe.bin` | 69.504 | `ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2` | `0x0bf00000` |
| `build-n5g-blramdisk/bootloader.bin` | 69.504 | `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03` | `0x09000000` |

Der Kandidat und der relocatierte Loader wurden nicht auf das Gerät kopiert.
Der vorhandene QEMU-Nachweis hält vor der ersten Loaderinstruktion bzw. an
`start_loc`; er ist kein Geräteboot.
