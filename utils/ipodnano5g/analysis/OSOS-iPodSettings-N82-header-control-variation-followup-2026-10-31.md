# iPodSettings QName-Heapkandidat: N82-Varianten am Original-Freepfad

Stand: 31.10.2026. ARM1176-Usermode-QEMU mit dem vorhandenen
Originalparser-/Heap-Rehost; kein Geräte-, USB-, DFU-, NAND-, NOR- oder
Firmwarezugriff.

## Ergebnis

Die Bytes am Ende eines gültigen 82-Zeichen-QNames ändern im synthetischen
gemeinsamen Heapmodell, ob der korrumpierte Original-Freepfad abstürzt:

- `A*78 + "0000"` läuft durch beide im Harness nachgebildeten Loader-Callbacks,
  den originalen Freecode und `FUN_0827ec10` (Dokument-Cleanup). Der nach dem
  Cleanup zusätzlich vom Harness angeforderte `FUN_08020df4(0x50)` liefert
  `0x0bb63bdc`; der Lauf meldet `PASS`, Exit 0.
- Mit `MODEL_STREAM_SLOT` ruft der Harness zusätzlich `FUN_0822491c` auf, um
  den originalen 1-Element-Hilfsvektor anzulegen, und gibt ihn nach dem
  Dokument-Cleanup mit `FUN_08281cf4` frei. Auch dieser Lauf kehrt ohne Fault
  zurück. Der Folgeallocator liefert nun `0x0bb636fc` und meldet mit
  aktualisierter Erwartung `PASS`, Exit 0. Der erste Stream-Slot-Lauf mit der
  alten Erwartung `0x0bb63bdc` endete nur an dieser Harness-Assertion (Exit 1).
- `A*82` mit nur einer gültigen Änderung in der Mitte (`A*40 + "BAAA" + A*38`)
  faultet im ersten Callback-Free in `FUN_081a8060`. Der Trace zeigt den Store
  des Nachbarzeigers über den ungültigen Vorgängerzeiger `1` an Adresse `0x9`;
  der betroffene Freiknoten selbst liegt bei `0x0bb63aa4`.
- `A*80 + "BB"` faultet ebenfalls in `FUN_081a8060`; der Trace zeigt dort den
  ungültigen Freiknotenparameter `r1=0xca74f90b` bereits beim Funktionsaufruf.
  Dieser Wert ist hier der Knotenpointer, kein nachgewiesenes
  `prev`-/`next`-Feld; der Fault passiert beim Zugriff auf den Knoten.

Im erfolgreichen `"0000"`-Fall ohne Stream-Hilfsvektor werden beim ersten
Callback die überwachten Nachbarwörter `0x44 -> 0x3030 -> 0x3032` und beim
zweiten Callback `0x58 -> 0x3030 -> 0x3033`. Mit Stream-Hilfsvektor verschieben
sich die synthetischen Chunks; beide Callback-Aufrufe kehren dennoch zurück.
Das bestätigt eine eingabeabhängige Allocator-/Free-Listenwirkung im
vorgegebenen Modell. Die erfolgreichen Folgezeiger liegen innerhalb des
modellierten Heapintervalls; sie sind kein Nachweis eines Schreibzugriffs auf
ein lebendes Gerätobjekt.

Der Tracevergleich grenzt die Fehlermechanik ein: `N82_midpatch_B` erreicht
den Unlink mit einem gültigen Knotenpointer und einem ungültigen
Vorgängerpointer `1`; `N82_tail_BB` übergibt bereits einen ungültigen
Knotenpointer. Das sind zwei unterschiedliche Faults. Keine Variante zeigt
eine frei gewählte Adresse in einem echten OSOS-Objekt oder eine
Kontrollflussübernahme.

Ein zusätzlicher 81-Paare-Tailbyte-Lauf findet acht vollständige `PASS`-Fälle
mit erster Überlaufbyte `0`, 64 SIGSEGV-Fälle und neun Fälle, die an einer
Harness-Assertion enden. Alle acht vollständigen Fälle behalten denselben
Folgezeiger `0x0bb636fc`, obwohl das Nachbarwort und einzelne Allocatorzähler
variieren. Matrix und Einzel-Runlogs:
`OSOS-iPodSettings-tail-byte-sweep-followup-2026-10-31.md` und
`evidence/xml-heap-tail-byte-sweep-2026-10-31/`.
Eine nachgeschaltete Reihe vorgegebener Original-Allokationen liefert bis
`0x200` identische Pointer; die `0x400`-Rückgabe variiert im synthetischen
Heap um bis zu `0x4d00` Byte. Das ist Heapformung im Rehost, kein Nachweis,
dass ein realer Aufrufer diese Größen anfordert oder dass dadurch ein
Geräteobjekt kontrolliert wird. Die äußere Stream-Cleanup-Kette bleibt
unmodelliert.

## Was der Lauf tatsächlich ausführt

Der Harness benutzt den unveränderten Pushparser und Tree-Builder, die
Original-Registryfactory, den Originalformatter, den Callback über die echte
Handler-VTable, `FUN_0802502a`/`FUN_0819af00` für die Freigaben,
`FUN_08020df4` als Originalallocator sowie `FUN_0827ec10` für den
Dokument-Cleanup. In der `MODEL_STREAM_SLOT`-Variante ruft er außerdem
`FUN_0822491c`/`FUN_08281cf4` für den Hilfsvektor auf. Er prüft eine
`iPodSettings`-Wurzel und den 82-Zeichen-Elternnamen mit einem `X`-Kind. Die
beiden Callback-Eingaben werden vom Harness in derselben Reihenfolge gebildet,
die der dokumentierte Loader für Root/Kind und Kind/Enkel verwendet.

Der Rehost führt **nicht** `FUN_08059ab0` samt VFS-Open, vollständiger
Treewalk-Schleife und Streamcleanup aus. Der Heapmanager, die Vorbelegung und
die Registry liegen im synthetischen QEMU-Adressraum; Schedulerinterleavings
und echte MainApp-Heapnachbarn fehlen. Ein `PASS` belegt daher weder einen
Geräte-Heap-Overwrite noch Kontrollflussübernahme, Codeausführung, Persistenz
oder Rockbox-Handoff.

## Dauerbelege

Alle Dateien liegen in `evidence/xml-heap-qname-sweep-2026-10-31/`. Die
Ausgangsquelle und der Linkerentwurf sind:

- `evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_rehost_20261030.S`
- `evidence/xml-heap-2026-10-29/OSOS_iPodSettings_shared_heap_fullrange_rehost_20261030.ld`

Die Varianten `N82_tail_00` und `N82_tail_00_streamslot_pass` enthalten ELF,
QEMU-Runlog und vollständigen Instruktions-/Registertrace. Der erste
`N82_tail_00_streamslot`-Lauf hält den revidierten Folgezeiger als
Assertion-Mismatch fest. `N82_midpatch_B` und `N82_tail_BB` enthalten die
Ausführungsbelege für die beiden Free-Fehler. Die Runner-Skripte dokumentieren
die QEMU-Aufrufe. `SHA256SUMS` bezieht alle lokalen ELF-, Runlog-, Trace- und
Runnerdateien ein.

## Nächste Schritte

1. Der statische Audit der vollständigen Stream-Cleanup-Kette ist jetzt
   dokumentiert in
   `OSOS-iPodSettings-full-stream-cleanup-modelability-followup-2026-10-31.md`.
   Ein valider Rehost braucht den echten Streamkonstruktor plus VFS-/Provider-
   und Registryzustand; einen synthetischen Objektbaum werde ich nicht als
   vollständigen Cleanup-Test ausgeben.
2. Als nächster QEMU-Schritt bleibt, den echten Loader-Aufrufer samt
   Providerzustand in denselben Lauf zu integrieren und danach zu prüfen, ob
   der veränderte Allocatorzustand ein konkretes beschreibbares Objekt trifft.
3. Unabhängig davon bleibt der stärker kontrollflussorientierte
   `accessories.reg`-Kandidat offen; sein vollständiger Provider-Open fehlt.

Keine Änderung an Gerätedaten; keine Firmware- oder Flashaktion.
