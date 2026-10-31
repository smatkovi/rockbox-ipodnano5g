# Zubehör-ROP: Vorbereitung des ersten echten Kaltstarttests

Stand 31.10.2026. Der Prüfkandidat und sein Rockbox-Zwischenloader sind auf
dem internen FAT-Volume abgelegt. Der iPod wurde seit dem Schreiben noch nicht
kalt gestartet; ein Bootergebnis liegt daher noch nicht vor.

## Vorheriger Inhalt und Sicherung

Das Gerät erschien als `05ac:1265` und stellte `/dev/sdb1` (VFAT, 14,9 GiB)
bereit. Es war auf dem PC nicht gemountet. Vor dem Schreiben wurden die
Originaldatei `iPod_Control/Device/accessories.reg` (69 Byte,
SHA-256 `b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854`)
und `/.rockbox/rockbox.ipod` (1.079.128 Byte, SHA-256
`65276d4bf5b88af3c2ff5701a21fa6cd6654e24b4f147d7e7c31395a7023ec16`)
nach `/home/sebastian/ipod-re/device-backup-20261031/` kopiert. `/BOOT.BIN`
war im Root vorher nicht vorhanden.

## Eingespielte Dateien

- `iPod_Control/Device/accessories.reg`: 736-Byte-Kandidat
  `candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin`, SHA-256
  `b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e`.
- `/BOOT.BIN`: 69.504-Byte-Loader `bootloader-safe.bin`, SHA-256
  `ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`.
  Er ist bei `0x0bf00000` gelinkt und passt exakt zur Read-Länge des
  Kandidaten.

Beide Dateien wurden nach dem Schreiben vom Volume zurückgelesen. Größe und
SHA-256 stimmen; derselbe Abgleich bestand auch nach SCSI-Auswurf, erneutem
Laden des Mediums und einem SCSI-LUN-Reset. Der LUN-Reset war kein CPU-Kaltstart.

## Auslösen und Beobachtung

Der OSOS-MainApp-Startpfad ruft den Zubehörparser auf; der Kandidat braucht
also einen echten Neustart des iPods. Ein SCSI-Auswurf und ein SCSI-Gerätereset
haben den Prozessor nicht neu gestartet. Der aktuelle Zustand bleibt USB-
Massenspeicher `05ac:1265` mit den Testdateien. Für den Bootversuch ist ein
normaler Neustart per Menu+Center nötig: beide Tasten bis zum schwarzen
Display halten und dann loslassen. Nicht weiter bis zum DFU-Modus halten.
Danach USB-ID, Display und Rockbox-Menü beobachten.

## Rückrollen

Wenn der iPod wieder als USB-Massenspeicher erscheint:

```sh
sudo mcopy -o -i /dev/sdb1 /home/sebastian/ipod-re/device-backup-20261031/accessories.reg.original.bin ::/iPod_Control/Device/accessories.reg
sudo mdel -i /dev/sdb1 ::/BOOT.BIN
sudo blockdev --flushbufs /dev/sdb1
sudo sync
```

Die Wiederherstellung ist mit `mcopy -i /dev/sdb1 ::/iPod_Control/Device/accessories.reg -`
und SHA-256 gegen die Sicherung zu verifizieren. Wenn der normale OSOS-Start
nicht mehr zur Massenspeicherfunktion kommt, kann der bekannte DFU→U-Boot→
tethered-Rockbox-Pfad zum Wiederherstellen verwendet werden.

Die Sicherungskopien liegen lokal und sind nicht Bestandteil dieses
Repository-Verzeichnisses. Dieses Verzeichnis enthält nur Ablauf, Hashes und
Gerätebeobachtungen.
