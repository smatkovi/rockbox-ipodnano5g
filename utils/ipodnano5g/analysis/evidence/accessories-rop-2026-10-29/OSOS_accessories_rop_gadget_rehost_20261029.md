# `accessories.reg`: lokaler Helper-, Epilog- und Gadget-Rehost

## Ergebnis

Der QEMU-Rehost endet mit `PASS` (Exitcode 0). Er startet den unveränderten
Runtime-Code `FUN_08039048` und übergibt `max_length=0x100`, einen synthetischen
Stream sowie einen separaten Zielpuffer. Ein Read-Stub liefert zuerst die
Länge `0x284`; der Originalhelper ruft denselben Dispatcher danach mit
`length=0x284` und Ziel `S+4` auf. Der Stub kopiert genau `0x284` Bytes aus dem
vorbereiteten Kandidatenfeld nach `S+4`. Nach der Rückkehr prüft der Harness
die Länge, zwei erwartete Kandidatenwörter, den Zähler beider Helper-Reads und
das letzte Feldbyte an `S+0x287`.

Anschließend springt der Harness direkt zum unveränderten Parser-Epilog
`0x0802c505`; die Parser-Tokenloop wird dabei übersprungen. Der echte
Close-Wrapper `FUN_082721d8` läuft mit dem Nullsentinel. Der Epilog setzt das
Testbyte an `0x09000040` von `0x7f` auf `0`, ruft den String-Destruktor-Stub
auf und kehrt in die Kandidaten-Gadgets zurück. Die originalen Gadgetbytes
führen bis zum vorverlinkten Loader-Sentinel `0x09000000`. Die Spur zeigt nach
Open SP=`S+0x228` und nach dem Read-Trampolin-Pop SP=`S+0x288`.

Das belegt in einem synthetischen ARM-Prozess den Originalhelper mit einer
Länge über seinem übergebenen `0x100`-Argument sowie den Stack-/Registerfluss
ab dem Parser-Epilog. Es belegt keinen echten Datei-Read, keinen vollständigen
Parserlauf, keinen OSOS-VFS-Open, keinen Rockbox-Loaderstart und keinen
Geräte- oder untethered Boot.

## Aufbau und Aussagegrenzen

- Runtime-Eingabe: `osos_runtime_dram_20261025.bin`, SHA-256
  `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.
- Kandidat: `candidate_accessories_reg_unexecuted.bin`, 704 Byte (`0x2c0`),
  SHA-256 `7045ca2fe6a5f2660a815bdd182ff015691d90991ddc6f023972affcbd54e851`.
  Sein `0x44`-Feld ist 0x284 Byte lang. Die Harness-Eingabe liegt separat bei
  `0x08e57000`; der Originalhelper kopiert sie nach `S+4`, bei
  `S=0x08e55000`.
- Originalbytes werden für `FUN_08039048`, Parser-Epilog, Close-Wrapper und
  die Gadgetfolge an ihre Runtime-Adressen gelinkt. Der Read-Dispatcher bei
  `0x08268c3a` ist ein Prüf-Stub: Aufruf 1 liefert die Länge, Aufruf 2 kopiert
  die Kandidatenbytes, Aufruf 3 prüft nur die späteren Loader-Read-Argumente.
  `FUN_0826dd26`, Konstruktor, Open, String-Destruktor und Loader sind
  ebenfalls Stubs.
- Das synthetische Streamobjekt und der Helper-Leseinhalt sind vorbereitet.
  Weder echter Streamzustand noch Dateisystem, FAT-Provider oder VFS werden
  ausgeführt. Der komplette Tokenloop in `FUN_0802c3c4` läuft nicht; der
  Harness springt nach dem Helper direkt in dessen Epilog.
- Der Loader-Read füllt `0x09000000` nicht. Ein Sentinel ist dort vorgelinkt,
  damit der indirekte Sprung unabhängig von Dateiinhalt beobachtet werden
  kann. Die Stackadresse ist synthetisch und nicht am Gerät gemessen.

## Reproduktion

Vom Verzeichnis `rb-n5g` aus:

```sh
clang --target=arm-linux-gnueabi -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_rop_gadget_rehost_20261029.ld \
  -Wl,--build-id=none \
  -o utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_rop_gadget_rehost_20261029.elf \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_rop_gadget_rehost_20261029.S
qemu-arm -d in_asm,cpu \
  -D utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_rop_gadget_rehost_20261029.qemu-trace.log \
  utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_rop_gadget_rehost_20261029.elf
```

`run.log` records the observed output and limits. The complete trace and
reproduction inputs are listed in `SHA256SUMS`.
