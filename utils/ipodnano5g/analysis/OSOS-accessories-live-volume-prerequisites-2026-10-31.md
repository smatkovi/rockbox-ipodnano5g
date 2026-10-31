# `accessories.reg`: Live-Volume-Prüfung der Autostart-Voraussetzungen

Stand: 31.10.2026. Direkte, ausschließlich lesende mtools-Abfrage des aktuell
angeschlossenen iPod-FAT-Datenträgers und Abgleich mit den lokalen
Rehost-Artefakten. Keine Dateisystemänderung, kein Neustart, kein DFU-Aufruf
und kein NAND-/NOR-/Firmwarezugriff.

## Beobachteter Datenträgerzustand

- `iPod_Control/Device/accessories.reg` ist 69 Byte groß und hat SHA-256
  `b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854`.
  Das entspricht dem bereits archivierten harmlosen Backup; das `0x44`-Feld
  fordert neun Byte (`Pedometer`) an. Der Overflow-Kandidat liegt nicht auf
  dem Datenträger.
- `iPod_Control/Device/iPodSettings.xml` ist 1767 Byte groß; SHA-256
  `ec327e09e3617e72013a56f1291ff0fa6301d9a476f3439eddc06cf80ce935f4`.
- `/.rockbox/rockbox.ipod` ist vorhanden (1.079.128 Byte). Die zugehörige
  `rockbox-info.txt` meldet Ziel `ipodnano5g`, 32 MiB und Version
  `d49f519a9bM-261024`.
- `/.rockbox/n5g-ramdisk.img` ist vorhanden (8.388.608 Byte).
- `/BOOT.BIN` fehlt im Root-Verzeichnis. Der aktuell sichtbare Datenträger
  enthält also Rockbox-Dateien, aber nicht die erste Stufe, die der
  Accessories-Kandidat anfordert.

## Korrekte Loaderdatei für den vorhandenen Kandidaten

Der 736-Byte-Kandidat
`evidence/accessories-cache-alias-2026-10-31/candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin`
fordert `0x10f80` (69.504) Bytes aus `/BOOT.BIN` an und springt zum Alias
`0x8bf00000`. Die korrespondierende Datei ist der separat bei `0x0bf00000`
gelinkte Loader
`evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin`
(SHA-256 `ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`).
Sein ELF hat Entry `0x0bf00000`.

Der gleich große Standard-Build
`build-n5g-blramdisk/bootloader.bin` ist **nicht austauschbar**: sein ELF-
Entry ist `0x09000000` und sein SHA-256 ist
`09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03`. Würde
man diesen Standard-Build als `/BOOT.BIN` verwenden, stimmte sein Linklayout
nicht mit dem ROP-Ziel und dem Selbstrelokationspfad überein.

## Aussagekraft und nächste Schritte

Die Live-Prüfung bestätigt die vorhandenen Rockbox-Nutzdaten und präzisiert
die beiden fehlenden Dateien für einen späteren Test: den 736-Byte-Kandidaten
als `iPod_Control/Device/accessories.reg` sowie den relocatierten
`bootloader-safe.bin` als `/BOOT.BIN`. Sie bestätigt weder den automatischen
OSOS-Open/Read noch den Parser-Overflow, den ROP-Kontrollfluss, einen
Geräte-Handoff oder untethered Boot. In dieser Runde wurden beide Dateien
nicht geschrieben; die Stockdatei blieb unangetastet.

Die Rohdaten wurden in der lokalen Session notiert; eine bereinigte, von
Volume-Seriennummern freie Zusammenfassung und ihre Prüfsumme liegen unter
`evidence/accessories-live-volume-2026-10-31/README.md`.
