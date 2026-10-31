# OSOS-`time`-Callback: Registry und Event-Dispatch (31.10.2026)

Read-only-Auswertung des Runtime-Ghidra-Projekts `N5G_OSOS_runtime` und des
Runtime-Abbilds vom 25.10.2026. Keine USB-, DFU-, Geräte-, NAND-, NOR- oder
Flashaktion.

## Verifizierte Kette

- Der statische Eintrag bei `0x084315d8` enthält den Schlüssel `time`, bei
  `0x084315dc` den Thumb-Zeiger `0x08154545` (`FUN_08154544`) und bei
  `0x084315e0` den Nullwert. `FUN_081aaa84` übergibt Tabellenbasis
  `0x08431560` an `FUN_081b093c`; diese iteriert in Dreiergruppen bis zum
  Nullschlüssel und registriert jedes Tupel über `FUN_08154814`.
- Der MainApp-Taskeintrag enthält Einstieg `0x080202d9` für
  `FUN_080202d8`. Dieser Task ruft `FUN_08023f64`, das wiederum
  `FUN_081aaa84` aufruft. Damit ist die Registrierung im statischen
  MainApp-Taskpfad verankert. Das belegt für sich allein weder den
  Laufzeitzeitpunkt noch einen dynamischen Kaltstart-Trace.
- `FUN_08029298` liest einen Eventdatensatz, sucht dessen Schlüssel im
  registrierten Manager bei `FUN_081a52d4()+0x20` und ruft den gefundenen
  Funktionszeiger mit `(Eventdatensatz, Registry-Wert)` auf. Beim statischen
  `time`-Eintrag ist der dritte Tabellenwert, also dieser Registry-Wert,
  `0`. Ein `time`-Event kann damit `FUN_08154544` erreichen, sofern der
  MainApp-Manager initialisiert wurde.
- Im `time`-Callback ist `Eventdatensatz+0x0c` ein Zeiger auf den
  Timerdatensatz; `FUN_08154544` liest daraus bei `Timerdatensatz+0x24` das
  Empfängerobjekt. Für den anschließend erzeugten Typ-`0x12`-Event übernimmt
  die Funktion dagegen ihr zweites Argument. Auf dem registrierten
  MainApp-`time`-Pfad ist das der Tabellenwert `0`, nicht der Timerdatensatz.
  Der Event wird über den virtuellen Slot `+0x3c` des Empfängerobjekts
  zugestellt.
- `FUN_08038d38` behandelt Typ `0x12`, fragt dessen Interface `0xd00` ab und
  vergleicht den gelieferten Zeiger mit eingebetteten Objektadressen. Der
  Nullwert aus dem registrierten `time`-Eintrag kann diese nicht-nulligen
  Identitäten nicht erfüllen; insbesondere ist darüber der Zweig zu
  `FUN_0804bd38` nicht erreichbar. Andere Timer-Callbacks oder andere
  Registry-Einträge sind davon nicht automatisch ausgeschlossen.

## Abgrenzung zum Timer-Worker

Der generische Timer-Worker kann bei einem Eintrag ohne Callback dessen
Adresse in eine Queue stellen. Das ist nicht derselbe Beleg wie der
`time`-Schlüssel in der Callback-Tabelle. Der Timer-Worker lädt einen
Funktionszeiger aus `TimerRecord+0x14`; bisher ist keine Initialisierung des
konkreten `TMusicLoadingTask`-Eintrags nachgewiesen, die dort
`FUN_08154544` setzt. Ebenso ist noch nicht geklärt, welcher Produzent ein
`time`-Event in die MainApp-Hauptqueue stellt. Die zwei anderen in der
MainApp-Startfunktion registrierten Callbacktabellen bei `0x08437878` und
`0x084378d8` enthalten keinen zweiten `time`-Schlüssel. Andere taskspezifische
Registrierungen wurden in dieser Runde nicht inventarisiert.

## Sicherheitsbewertung

Die neue Verknüpfung belegt die Erreichbarkeit des registrierten `time`-
Callbacks und seines Empfänger-Dispatchs, sobald der MainApp-Task läuft. Sie
verbindet diesen Pfad aber gerade nicht mit dem identitätsabhängigen
`FUN_0804bd38`-Zweig: Der Registry-Wert ist null. Ein vom Host oder von einer
Datei kontrollierter Eventschlüssel oder Wert, ein Speicherfehler, ein
kontrollierter Rücksprung oder beliebige Codeausführung ist nicht belegt.
Auch ein Rockbox-Handoff oder eine persistente Installationsmöglichkeit folgt
daraus nicht.

Nächster statischer Schritt: taskübergreifend nach weiteren Registrierungen
von `time -> FUN_08154544` suchen und die Schreiber des Timerfeldes
`+0x14` verfolgen. Ein alternativer Pfad müsste einen nicht-null
Registry-/Senderwert mit dem konkreten Empfänger verbinden, um den
Identitätszweig überhaupt zu erreichen.

## Rohbelege

Die gezielten Ghidra-Abfragen mit `-readOnly -noanalysis` liegen unter
`evidence/time-callback-registry-2026-10-31/`; das lokale Projekt und die
Eingabe sind unter `/home/sebastian/ipod-re/local-analysis/` abgelegt. Die
genaue MainAppTask-Registrierung ist zusätzlich im bereits vorhandenen
`evidence/xml-heap-2026-10-29/README.md` dokumentiert.
