# OSOS-Voice-Reader: Längenüberlauf und Host-Modelltest

Stand: 31.10.2026. Die Binäranalyse beruht auf read-only-Ghidra-Abfragen am
persistenten Runtime-Projekt `N5G_OSOS_runtime_analysis` und dem Input
`osos_runtime_dram_20261025.bin`. Die Belegkette umfasst ein C-Hostmodell,
einen ARM1176-QEMU-Rehost und einen flüchtigen ARM-Test auf dem iPod. Nur der
letzte führt die Originalbytes des Streamwrappers auf dem Gerät aus; Datei-
und Providerzustand bleiben dabei Stubs.

## Ergebnis

`FUN_082b60a4` ermittelt die Dateilänge `n`, fragt die Ausrichtung `a=0x20`
ab und fordert `n+a-1` Byte beim Heapwrapper `FUN_08194f20` an. Danach richtet
es den zurückgegebenen Zeiger auf 32 Byte aus, liest aber weiterhin `n` Byte
über `FUN_0819887c`. Die Addition ist auf dem ARM-Ziel eine 32-Bit-Operation.
Für sehr große Dateilängen kann die Allokationsgröße daher klein werden,
während die Read-Länge groß bleibt.

Der Stream-Reader `FUN_081fd5e8` berechnet `cursor + request` mit
32-Bit-Arithmetik und vergleicht den resultierenden Wert mit der gespeicherten
Dateigröße; einen Übertrag prüft er nicht separat. Bei der ersten
Leseoperation mit `cursor=0` und `request=n` wird die volle Länge akzeptiert.
Der untere Provider begrenzt einen einzelnen Read
auf `0x10000` Byte. Wenn die gewählte Allokatorvariante einen kleinen Block
zurückgibt und der Provider diesen ersten 64-KiB-Block tatsächlich liefert,
schreibt der Reader deutlich über die für die Dateidaten verfügbare
Heapkapazität hinaus.

## Geprüfte Grenzwerte

Der generische Fallback `FUN_08020df4` rundet seine Anforderung mit
`(request + 0x0b) & ~3`, begrenzt sie auf mindestens `0x10` Byte und gibt den
Nutzzeiger acht Byte hinter dem Blockkopf zurück. Die größenklassierte
Allocator-Alternative in `FUN_0819680c` wird zuerst versucht; ihre
Laufzeitklasse und ihr Verhalten sind hier nicht modelliert.

| Dateigröße `n` | `n + 0x1f` an `FUN_08194f20` | Generischer Fallback | nomineller Nutzraum |
|---:|---:|---:|---:|
| `0xffffffe1` | `0x00000000` | Mindestanforderung `0x10` | mindestens 8 Byte |
| `0xffffffe0` | `0xffffffff` | interne Rundung läuft auf Mindestanforderung `0x10` über | mindestens 8 Byte |
| `0xffffffff` | `0x0000001e` | Mindestanforderung `0x28` | mindestens 32 Byte |

Der C-Test prüft diese 32-Bit-Rechnungen, dass der Stream-Reader die erste
Anforderung nicht kürzt, und die Wirkung eines vollständig gelieferten
64-KiB-Chunks auf ein Host-Arena-Modell. Er variiert den Allokatorzeiger über
alle 4-Byte-ausgerichteten Offsets innerhalb der 32-Byte-Ausrichtung. Je nach
Fall und Offset liegen im Modell 65.504 bis 65.536 Bytes des ersten Chunks
außerhalb des nominalen Nutzraums. Die Assertions bestanden mit:

```text
cc -std=c11 -O2 -Wall -Wextra -Werror
```

Zusätzlich lief dasselbe Modell mit AddressSanitizer und UndefinedBehaviorSanitizer;
beide meldeten keinen Fehler im Host-Testprogramm. Das sagt nichts über die
Laufzeit des OSOS-Binaries aus.

Ein ARM1176-QEMU-Rehost führt außerdem die originalen Runtimebytes von
`FUN_081fd5e8` aus. Bei `Dateigröße=0xffffffff`, `cursor=0` und
`request=0xffffffff` bestätigt der Prüf-Providerstub `offset=0`, die volle
Länge und den vollen Outcount; der Lauf endet mit `PASS`. Der Rehost stubbt
Datei-Status, Locking und Provider und führt weder den FAT-Pfad noch den
Voice-Allocator aus. Er bestätigt somit die Übergabe des großen Requests durch
den Original-Streamwrapper, nicht den vollständigen Gerätepfad.

Quelltext und vollständige Ausgabe des Host-Modells sind
`evidence/accessories-open-read-reachability-2026-10-31/repro_variable_voice_reader_wrap_20261031.c`
und `evidence/accessories-open-read-reachability-2026-10-31/repro_variable_voice_reader_wrap_20261031.log`.

## ARM-Test auf dem Gerät

Am 31.10.2026 wurde der Originalwrapper `FUN_081fd5e8` zusätzlich direkt auf
dem Nano-5G-ARM-Prozessor ausgeführt. `wInd3x cfw run` startete den
Shell-fähigen U-Boot flüchtig aus DFU. `bdinfo` meldete DRAM
`0x08000000..0x0bffffff`, U-Boot-Relokation bei `0x0bfa7000` und
`flashsize=0`. Die neun Harness-Segmente wurden mit YMODEM in freie DRAM-
Bereiche geladen. Für jedes Segment stimmte U-Boots CRC32 mit der lokal
berechneten CRC32 überein.

Der ARM1176-Test durchlief Requests `0xffffffff`, `0x284`, einen bis zum
Dateiende gekürzten Request, einen kurzen Prefetch-Read, den 32-Bit-Wrap-Fall
und einen kurzen Provider-Read. `go 0x08010000` kehrte mit Rückgabecode null
zur U-Boot-Konsole zurück. `md.l 0x08e68098 1` ergab `0x50415353` (`PASS`).
Die zuletzt gesetzten Messwerte waren Request `0xfffffd50`, Offset `0x2c0`,
Handle `0xfeed0001`, Provider-Outcount `0x1d00` und Streamcursor `0x1fc0`.
Der Testcode prüft beim ersten Request explizit, dass der Provider den vollen
Wert `0xffffffff` bei Offset null und denselben Outcount erhält.

Das bestätigt die Ausführung des Originalwrappers auf der realen CPU und seine
32-Bit-Request-/Cursor-Semantik. Der Providerstub schreibt keine 64 KiB in
den übergebenen Puffer; FAT, echter Datei-Provider und Voice-Allokator liefen
nicht. Der Test bestätigt daher weder eine reale Überschreibung noch deren
Kontrollierbarkeit oder Codeausführung. Die vollständige Konsolenausgabe und
der Wiederholungsablauf stehen in
`evidence/accessories-open-read-reachability-2026-10-31/OSOS_voice_reader_live_ram_20261031.device.log`
und `.commands.txt`.

## Erreichbarkeit und Auswirkung

Belegt ist der Funktionspfad innerhalb des Voice-Readers: `FUN_082b60a4`
ruft den Datei-Stat, Allocator, Stream-Öffner und Reader auf. `FUN_082af756`
ruft `FUN_082b60a4` auf. Der Pfadkonstruktor `FUN_082bc4c8` formt den
Voice-Dateipfad aus Laufzeitwerten. Das Runtime-Projekt belegt damit eine
aufrufbare Implementierung, aber nicht, dass ein externer Dateieintrag diesen
Pfad beim Kaltstart erreicht.

Offen bleiben insbesondere:

1. Ob ein vom Gerät akzeptierter FAT-Eintrag eine solche Dateigröße bis zum
   Voice-Stat durchreichen kann und ob dazu eine passende Clusterkette gelesen
   wird.
2. Ob der Voice-Pfad `iPod_Control/Device/voices/` von außen beschreibbar und
   über den vorhandenen Resolver tatsächlich erreichbar ist.
3. Ob der größenklassierte Allocatorzweig die Unterallokation abfängt oder
   ebenfalls einen kleinen Block liefert.
4. Ob die benachbarten Heapdaten kontrollierbar sind und ob sich aus der
   Korruption eine stabile Codeausführung ergibt.

Bewertung: **starker, bedingter Heap-Overwrite-Kandidat; keine bestätigte
RCE, kein nachgewiesener Rockbox-Handoff und kein Beleg für untethered boot.**
Der Host-Modelltest verifiziert die Arithmetik und die bedingte
Speicherüberschreitung. QEMU und der Live-Test bestätigen, dass der
Original-Streamwrapper den großen Request unverändert an seinen Provider
weitergibt. Provider-, FAT- und Kaltstart-Erreichbarkeit bleiben offen. Eine
beschädigte Datei wurde nicht auf den iPod geschrieben.

## Gerätestatus während dieser Prüfung

Zu Testbeginn wurde `05ac:1231` (DFU) erkannt; anschließend startete
`wInd3x cfw run` U-Boot im RAM. Der aktuelle Gerätezustand nach dem Test ist
`05ac:2137` (U-Boot-Konsole). `bdinfo` meldet `flashsize=0`; verwendet wurden
nur `loady`, RAM-Füllung, `go`, `md.l`, `crc32`, `version` und `bdinfo`.
Es gab keinen NAND-/NOR-Schreib- oder Löschzugriff und keinen Flash-Versuch.
Die Konsolenausgaben liegen in
`evidence/accessories-open-read-reachability-2026-10-31/OSOS_voice_reader_live_ram_20261031.device.log`
und im früheren U-Boot-Basislog
`evidence/accessories-open-read-reachability-2026-10-31/OSOS_n5g_uboot_ram_console_20261031.log`.

## Sinnvolle nächste Prüfung

Als Nächstes sollten ein kleines FAT-Abbild durch den OSOS-Stat-/Open-Pfad
und die tatsächliche Allocator-Variante `FUN_0819680c` mit dem Voice-Caller
abgeglichen werden. Danach ist zu klären, ob der reale Provider bei einem
großen Request wirklich bis zu `0x10000` Byte in den kleineren Voice-Puffer
schreibt. Der RAM-Test hat diese Voraussetzungen absichtlich gestubbt. Eine
reale Datei wurde nicht verändert; RCE, stabiler Heap-Overwrite und
Rockbox-Handoff bleiben unbewiesen.

## Rohbelege

Die read-only-Ghidra-Abzüge, USB-/U-Boot-Beobachtung, Modellquelle und
Modellausgabe liegen dauerhaft in
`analysis/evidence/accessories-open-read-reachability-2026-10-31/`. Die
Eingabeprüfsumme steht in `INPUT_SHA256.txt`; `SHA256SUMS` deckt die Dateien
des Belegordners ab. Der Streamwrapper-Rehost steht in
`OSOS_voice_reader_stream_wrapper_max_request_20261031.S`, `.ld` und
`.run.log`.
