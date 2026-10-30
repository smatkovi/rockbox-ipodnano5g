# Nano-5G-Bootloader: No-FAT-Fallback und Stand des lokalen Builds

Stand: 30.10.2026. Read-only-Prüfung des vorhandenen Rockbox-Builds und seiner Quellpfade. Kein Gerätezugriff, kein Boot, kein NAND-/NOR-Schreiben, kein Löschen und kein Flashversuch.

## Verifizierter Pfad bei „No FAT partition found“

Das lokale ELF ist für `ipodnano5g` gebaut (`TARGET_DEFINE=-DIPOD_NANO5G`). Seine `main`-Disassemblierung zeigt:

1. `disk_mount_all()` läuft bei `0x09000ed8`; `r0 <= 0` verzweigt bei `0x09000ee4` zu `0x09000f58`.
2. `r0` enthält dabei weiterhin den Zeiger auf `"No FAT partition found"` (`0x0900d361`). Der gemeinsame `printf` läuft bei `0x09000f58`.
3. Danach springt der Code zu `0x09000f1c`, lädt den Zeiger `0x0900d308` auf die Zeichenfolge `"osos"` und ruft bei `0x09000f20` `launch_apple` auf.
4. Falls `launch_apple("osos")` zurückkehrt, ruft der Code `boot_error()` bei `0x09000f24` auf. Der Fehlerpfad kehrt nicht zu U-Boot zurück.

Damit erklärt sich die Meldung: Sie ist eine Zwischenmeldung vor dem vorgesehenen Versuch, das signierte Apple-OS zu starten. Bleibt das Gerät danach im Bootloaderbildschirm, ist ein fehlgeschlagener oder zurückgekehrter OSOS-Start eine plausible Erklärung; der konkrete Grund wurde hier nicht dynamisch gemessen.

## Was der normale Rockbox-Pfad danach voraussetzt

Bei erfolgreichem FAT-Mount lädt der Bootloader `/.rockbox/rockbox.ipod` nach `0x08000000`. Anschließend öffnet er `/.rockbox/n5g-ramdisk.img`, verlangt exakt 8 MiB und prüft FAT16-Merkmale, bevor er in das geladene Rockbox-Image springt. Die RAM-Disk-Adresse `0x0a000000` liegt innerhalb des in den Sitzungsnotizen belegten 64-MiB-SDRAM-Fensters `0x08000000..0x0bffffff`.

In den geprüften Build- und `local-analysis`-Eingaben fand sich `bootloader.bin`, aber keine Kopie von `rockbox.ipod` oder `n5g-ramdisk.img`. Das sagt nichts darüber aus, ob diese Dateien auf dem iPod liegen. Der vorhandene FAT-Snapshot enthält laut vorheriger Analyse kein `/BOOT.BIN`; der Exploit-Rehost lädt den Bootloader bislang nicht.

Das optionale `N5G_OSOS_REACHABILITY_TEST` steht zwar im Quelltext, ist laut generiertem Makefile aber nicht definiert. Das vorhandene ELF enthält keine `reachability_hit`-Funktion. Der entsprechende Test-Hook stellt daher im vorhandenen Build keine U-Boot-Rückkehr bereit; außerdem ist er ein OSOS-Callback-Hook und kein No-FAT-Fallback.

## Build-Frische

Das vorhandene `bootloader.bin` ist 69.504 Byte (`0x10f80`), SHA-256 `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03`. Das ELF ist für ARMv6KZ gelinkt, hat Entry `0x09000000`, und sein erster LOAD-Bereich hat ebenfalls `FileSiz=0x10f80`; die rohe Datei beginnt mit einem ARM-Branch an diesem Entry. Damit passt die Datei statisch zur bisher analysierten ROP-Ladegröße und Zieladresse.

Der Quelltext `bootloader/ipodnano4g.c` ist neuer als sein Objekt und das vorhandene ELF. Ein Dry-Run des korrekten Build-Verzeichnisses plant erneute Kompilierung, Linken und Verpacken. Das vorhandene ELF enthält nachweislich den oben beschriebenen No-FAT→OSOS-Pfad; wegen der Zeitstempel ist es aber kein verlässlicher Beleg für alle aktuellen Quelltextänderungen. In dieser Runde wurde nicht neu gebaut.

## Belege und Grenzen

- `evidence/accessories-rockbox-entry-2026-10-30/bootloader_main_disassembly_20261030.txt` — `main` aus dem vorhandenen ELF.
- `evidence/accessories-rockbox-entry-2026-10-30/bootloader_elf_layout_20261030.txt`, `bootloader_bin_entry_20261030.txt`, `bootloader_artifact_identity_20261030.txt` — ELF-Ladebereich, Entry, Zielmodell, Größe und Hash.
- `evidence/accessories-rockbox-entry-2026-10-30/bootloader_build_freshness_20261030.txt` und `bootloader_make_dry_run_stale_targets_20261030.txt` — Zeitstempel und reiner Make-Dry-Run.
- `bootloader/ipodnano4g.c`, `firmware/export/config/ipodnano5g.h` und `build-n5g-blramdisk/Makefile` — Quellpfad, Dateinamen, RAM-Disk-Größe und Build-Defines.

Das ist kein Nachweis des installierten Bootloaderstands und keine Aussage über einen tatsächlichen OSOS-Start. Der nächste belastbare Offline-Schritt bleibt ein Rehost, der den realen No-FAT-Fehlerpfad bis zum Loaderübergang modelliert, sowie ein separater vollständiger FAT-Open/Read-Rehost für `accessories.reg`. Für einen späteren Rockbox-Handoff muss zusätzlich geklärt werden, dass die erwarteten Firmware- und RAM-Disk-Dateien auf dem Volume vorhanden sind.
