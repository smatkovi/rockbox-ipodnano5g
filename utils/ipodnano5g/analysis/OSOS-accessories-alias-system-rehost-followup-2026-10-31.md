# `accessories.reg`: System-Rehost des Alias-/Loader-Handoffs

Stand: 31.10.2026. ARM1176-System-QEMU-Rehost des 736-Byte-Kandidaten mit
dem Originalparser, dem echten OSOS-DSB-Helper, einer OSOS-konformen
DRAM-Aliasabbildung und dem echten lokalen Rockbox-Zwischenloader. Kein
Geräte-/USB-/DFU-Zugriff und keine NAND-/NOR-/Firmwareänderung.

## Ergebnis

Der vollständige Kandidaten-ROP läuft im System-Rehost im SVC-Modus bis zum
echten DSB-Helper `0x083531c0`. Am Breakpoint davor gelten `r0=0`,
`r1=0x10f80` und `r2=0x8bf10f80`. Nach Ausführung des unveränderten
`MCR p15,0,r0,c7,c10,4` erreicht der Kontrollfluss den echten
Loader-BSS-Initialisierer bei `0x8bf001c8` und danach den Alias-Einstieg
`0x8bf00000`.

Am Loader-Einstieg sind drei zuvor gesetzte BSS-Marker gelöscht. Die
ausgelesenen `0x10f80` Bytes am Alias- und Identitätsziel stimmen bytegenau
mit `bootloader-safe.bin` überein (SHA-256
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`). Die
L1-Einträge für Loaderidentität und Alias sind im Rehost `0x0bf07c0e` und
`0x0bf04c02`.

Das schließt die frühere Lücke zwischen dem User-Mode-Parser-ROP-Rehost und
dem separaten ARM1176-MMU-/Loader-Rehost: Parser-ROP, SVC-Modus, echter DSB,
Aliaszugriff und echter `bss_init`-Code laufen nun in einem System-QEMU-Lauf
zusammen. Der Lauf stoppt am Loader-Einstieg vor der ersten Loaderinstruktion;
Rockbox wird nicht gestartet.

## Korrektur eines Harnessfehlers

Der erste Integrationsversuch legte seine synthetische 16-KiB-L1-Tabelle bei
`0x08004000` ab. Dort liegen auch Runtimebytes und ROP-Gadgets des OSOS-
Abbilds. Das Nullsetzen und Beschreiben der Tabelle überschrieb diese Bytes;
der Parserpfad kehrte daraufhin falsch in den Rehost-Startcode zurück. Die
Tabelle liegt jetzt bei `0x0bfd0000`, außerhalb der geladenen Gadgets,
Loader-BSS und Loaderquelldatei. Die dokumentierten Erfolgswerte stammen nur
aus dem korrigierten, reproduzierbaren Lauf.

## Grenzen

- Die L1-Tabelle wird vom Harness aufgebaut. Ihre Abschnittswerte entsprechen
  den statisch aus dem OSOS-Startup ermittelten Werten; der Harness führt den
  vollständigen OSOS-Startup/MMU-Initialisierer nicht aus.
- Parserobjekt, FAT-Volume-/Handlezustand und Stream werden teilweise vom
  Harness gesetzt. Der erfolgreiche `BOOT.BIN`-Open und Dateiread bleiben ein
  Callback, der die eingebetteten Loaderbytes kopiert. ATA-/USB-I/O und die
  reale Providerregistrierung laufen nicht.
- QEMU-TCG ist kein Messgerät für den tatsächlichen ARM1176-Cachezustand,
  reale TLB-Belegung, freie DRAM-Regionen oder den Gerätestart.
- Das Ergebnis beweist weder, dass der Kandidat auf dem iPod gespeichert ist,
  noch dass der automatische MainApp-Open ihn vom Gerät liest. Es beweist
  keinen Rockbox-Start und keinen untethered Boot.

## Dauerbelege und Reproduktion

Alle Quelldateien, der ARM1176-Systemlauf, GDB-Spuren, die beiden
Loader-Dumps und SHA-256-Werte liegen in
`evidence/accessories-alias-system-parser-rehost-2026-10-31/`.
Reproduktion vom Repository-Root:

```sh
utils/ipodnano5g/analysis/evidence/accessories-alias-system-parser-rehost-2026-10-31/run_alias_system_parser_rehost.sh
```

Der Kandidat liegt unter
`evidence/accessories-cache-alias-2026-10-31/candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin`
(736 Byte, SHA-256
`b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e`). Die
eingebettete Runtime-Eingabe ist
`../local-analysis/inputs/osos_runtime_dram_20261025.bin` (SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`).

## Nächste Schritte

1. Den `BOOT.BIN`-Open und -Read im gemeinsamen Rehost vom VFS-Provider bis
   zum FAT-Dateireader führen, ohne Stream-/Handle-Startzustände vorzufüllen.
2. Die reale frühe Slot-0-Providerregistrierung und den erfolgreichen
   `accessories.reg`-Open separat absichern; der vorhandene Rehost bleibt
   dafür ein Modell.
3. Danach den Rockbox-Handoff und die Hold-gesperrte Rückkehr zur iPod-Software
   getrennt bewerten. Bis dahin bleibt untethered Boot unbestätigt.
