# iTunes-Präfix: MMU- und Data-Abort-Folgeprüfung

Stand: 31.10.2026. Read-only-Auswertung des OSOS-Bootprefixes und Runtime-
Abbilds. Keine Geräte-, USB-, DFU-, NAND-, NOR-, Dateisystem- oder
Firmwareoperation.

## Ergebnis

Der bisher synthetische iTunes-Präfixpfad enthält vor der dateinamenabhängigen
Instruktionsfolge einen bedingten Byte-Lesezugriff bei Offset `+0x0c`:

```asm
LDRBVC r6, [r4, #-0x95c]
```

Für den aufrufbaren Fehlerpfad ist `V=0`: `FUN_080b1904` ruft
`FUN_08270164` mit einem nicht-null Ausgabezeiger und `param_3=0` auf. Der
Parser vergleicht `param_3` mit null, wodurch `V=0` wird; die untersuchten
Rückgabepfade behalten diesen Wert. Der Epilog von `FUN_080b1904` besteht aus
`ADD SP` und `POP`, die die Flags nicht ändern. Damit wird der `LDRBVC` auf
diesen Pfaden ausgeführt, bevor die späteren `LDCLPL`-/Dateinamenschritte
erreicht würden.

`r4` stammt bei `FUN_08213400` aus `FUN_080b0cb6()`. Dieser Helfer bildet den
festen Pfad `iPod_Control\\iTunes\\iTunesDB` und gibt einen vom Parser
`FUN_08270164` erzeugten kalenderbasierten Sekundenwert zurück. Bei
Parserfehler bleibt der initialisierte Wert null. Die Zeitzonenkorrektur des
Aufrufers liegt nach `FUN_080b1904`; eine überschriebene Rücksprungadresse
lenkt vorher ab. Der Wert in `r4` am manipulierten Rücksprung ist also der
unkorrigierte Parserwert. Das aktuelle Gerätedatum wurde nicht gelesen.

## MMU-Abgleich

Der Bootprefix nullt vor dem MMU-Aufbau den Bereich
`[0x086c43a8, 0x08e54e4c)`, der die 16-KiB-L1-Tabelle bei `0x086dc000`
enthält. `FUN_22005d3c` richtet anschließend diese expliziten
Abschnittsbereiche ein:

| Virtuelle Spanne | Physische Basis | Deskriptorattribut |
| --- | --- | --- |
| `0x00000000–0x000fffff` | `0x22000000` | `0xc802` |
| `0x20000000–0x21ffffff` | `0x20000000` | `0x6c0a` |
| `0x22000000–0x220fffff` | `0x22000000` | `0x4c02` |
| `0x08000000–0x0bffffff` | `0x08000000` | `0x7c0e` |
| `0x88000000–0x8bffffff` | `0x08000000` | `0x4c02` |
| `0x38000000–0x3fffffff` | `0x38000000` | `0x0c02` |

Der bekannte spätere Runtime-Mapper fügt ein dynamisches 1-MiB-Fenster bei
`0x18000000` hinzu. Weder diese Fenster noch die expliziten Prefix-Bereiche
decken eine normale aktuelle Unix-Zeitadresse um `0x4bxxxxxx` oder die
Null-Fehleradresse `0xfffff6a4` ab. Beispielwerte:

- synthetisch `r4=0x4b3d3b00` (2010-01-01 UTC) ergibt die Ladeadresse
  `0x4b3d31a4`;
- `r4=0` ergibt mit 32-Bit-Wraparound `0xfffff6a4`.

Der Zugriff liegt nur dann im bekannten identitätsabgebildeten DRAM-Fenster,
wenn `0x0800095c <= r4 < 0x0c00095c`. Als Unix-Sekunden entspricht das dem
ungewöhnlich engen Intervall 1974-04-03 11:22:04 UTC bis vor 1976-05-19
04:43:08 UTC. Das ist ein statischer Vergleich der bekannten Tabellenaufbau-
Aufrufe. Spätere indirekte L1-Änderungen oder weitere, nicht erkannte Mapper
sind nicht vollständig ausgeschlossen.

## Erwarteter Fehlerpfad

Die Vektortabelle leitet den Data Abort bei Adresse `0x10` über
`0x220038a8` an den Runtime-Handler `0x08352974` weiter. Dieser reicht den
Kontext an `FUN_08355dd8`. Bei gelöschtem JTAG-Warteflag protokolliert der
Handler den C-Ausnahmekontext und ruft `arm_81a5608`, eine Endlosschleife.
Der alternate JTAG-Wartepfad und der Flagwert auf dem Gerät sind nicht live
gemessen. Die Handlersemantik ist zusätzlich in
`OSOS-iAP-location-packet86-followup-2026-10-28.md` dokumentiert.

**Bewertung:** Für gewöhnliche aktuelle Datumswerte und den Nullwert führt die
bekannte Boot-MMU-Konfiguration vor den kontrollierten Präfixbytes in einen
Data Abort. Das macht den iTunes-Partial-LR-Kandidaten auf den untersuchten
Pfaden zu einem möglichen Hänger, nicht zu einem nachgewiesenen
Kontrollfluss-Handoff. Ein späterer MMU-Eintrag oder ein anderer echter
`r4`-Wert ist nicht ausgeschlossen; die Callback-Erreichbarkeit bleibt
außerdem offen.

## Belege und nächste Schritte

Belege einschließlich Prefixvektoren, MMU-Setup, Runtime-Aborthandler,
read-only-Ghidra-Auszügen und Eingabehashes liegen unter
`evidence/accessories-prefix-data-abort-2026-10-31/`.

1. Wenn das lokale iTunesDB-Abbild vorliegt, dessen Datumswert offline
   auswerten; dafür ist kein iPod-Test nötig.
2. Alle späteren dynamischen L1-Tabellenwriter und deren Aufrufer weiter
   eingrenzen, damit die Möglichkeit einer zusätzlichen Abbildung bei
   `0x4bxxxxxx` kleiner wird.
3. Den iTunes-Kandidaten bis dahin zurückstellen und die verbleibende
   `accessories.reg`-Open-/Read-Lücke separat bearbeiten. Deren QEMU-Systemlauf
   erreicht bereits den echten Loader-Einstieg, verwendet für Datei-Open und
   Loader-Read aber weiterhin modellierte Callbacks.

Keine der Analysen führte den Kandidaten auf dem iPod aus.
