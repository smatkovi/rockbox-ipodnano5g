# OSOS-Voice-Reader: Längenüberlauf und Host-Modelltest

Stand: 31.10.2026. Die Binäranalyse beruht auf read-only-Ghidra-Abfragen am
persistenten Runtime-Projekt `N5G_OSOS_runtime_analysis` und dem Input
`osos_runtime_dram_20261025.bin`. Der reproduzierbare Test ist ein kleines
Host-Modell in C; es führt keinen OSOS-Code aus und greift nicht auf den iPod
zu.

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

Quelltext und vollständige Ausgabe sind
`evidence/accessories-open-read-reachability-2026-10-31/repro_variable_voice_reader_wrap_20261031.c`
und `evidence/accessories-open-read-reachability-2026-10-31/repro_variable_voice_reader_wrap_20261031.log`.

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
Speicherüberschreitung, nicht die Provider- oder Kaltstart-Erreichbarkeit.
Eine beschädigte Datei wurde nicht auf den iPod geschrieben.

## Gerätestatus während dieser Prüfung

Die USB-Abfrage `lsusb -d 05ac:` ergab `05ac:2137 Apple, Inc. U-Boot firmware dbg`.
Der Shell-fähige U-Boot wurde zuvor nur in RAM geladen. Die persistierte
Konsolenausgabe liegt in
`evidence/accessories-open-read-reachability-2026-10-31/OSOS_n5g_uboot_ram_console_20261031.log`.
Es erfolgte kein NAND-/NOR-Schreib- oder Löschzugriff und kein Flash-Versuch.

## Sinnvolle nächste Prüfung

Als nächster Test sollte die Dateigröße unabhängig vom iPod anhand eines
kleinen FAT-Abbilds durch den OSOS-Stat-/Open-Pfad laufen. Danach sollte die
Provider- und Allokatorvariante in einer isolierten Emulation oder mit einem
kurzen, kontrollierten Fake-Provider geprüft werden. Erst wenn diese Tests
den Überlauf und den Voice-Aufrufpfad bestätigen, wäre ein Gerätetest mit
gesichertem Dateisystem vertretbar. Für die derzeitige RCE- und Bootbewertung
ist ein Live-Test mit beschädigter iPod-Datei nicht belegt.

## Rohbelege

Die read-only-Ghidra-Abzüge, USB-/U-Boot-Beobachtung, Modellquelle und
Modellausgabe liegen dauerhaft in
`analysis/evidence/accessories-open-read-reachability-2026-10-31/`. Die
Eingabeprüfsumme steht in `INPUT_SHA256.txt`; `SHA256SUMS` deckt die Dateien
des Belegordners ab.
