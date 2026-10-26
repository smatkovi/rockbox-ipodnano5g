# OSOS: dynamischer Device-XML-Loader und unbeschränkter Formatter

Stand: 26.10.2026. Read-only-Analyse des lokalen OSOS-Ghidra-Projekts und des
dechiffrierten OSOS-Bodys. Keine Geräte-, USB-, DFU-, Boot-, NAND-, NOR- oder
Flashoperation; kein Payload wurde erzeugt oder ausgeführt.

## Befund

Der Wrapper `FUN_081c38b0` ist ein unbeschränkter `sprintf`-ähnlicher Formatter.
Er ruft `FUN_0829f4b0` und den Format-Interpreter `FUN_082d5b24` auf. Beim
`%s`-Format ohne Genauigkeit verwendet `FUN_082d5b24` den Grenzwert
`0xffffffff`; `FUN_082e26bc` läuft bis zum NUL-Byte und übergibt den gesamten
Bereich an `FUN_08060636`. Dieser Callback gibt jedes Byte über
`FUN_08286902` aus. `FUN_08286902` schreibt das Byte an den aktuellen Zeiger
und erhöht den Zeiger, ohne eine Zielkapazität zu prüfen. `FUN_081c38b0`
terminiert danach mit einem weiteren Byte-Write. Im geprüften Aufrufpfad ist
kein Längenargument für den Zielpuffer vorhanden.

Ein bislang nicht dokumentierter Verbraucher dieses Formatters liegt bei
`0x08087d2c`. Ghidra hatte dort im gespeicherten Projekt keine Funktion
definiert; der Prolog `push {r0,r4,r5,r6,r7,lr}; sub sp,#0x1fc; sub sp,#0x2c`
wurde in einer read-only-Projektansicht manuell als Thumb-Funktion
disassembliert. Sie formatiert `iPod_Control/Device/%s.xml` in einen lokalen
256-Byte-Puffer und versucht, die Datei über `FUN_082aba26` zu laden. Bei
erfolgreichem Parse iteriert sie über Knoten und formatiert deren
dateikontrollierte Namen mit `"%s_%s"` in einen 252-Byte-Stackpuffer.
Anschließend wird der zusammengesetzte Name an eine virtuelle Methode des
Objekts übergeben.

Damit ist eine bedingte Stackkorruption durch lange Schlüssel statisch
plausibel: mehr als 252 Ausgabebytes überschreiben benachbarte lokale Werte.
Der Zielpuffer beginnt bei `sp+0x14`; der gespeicherte LR liegt bei
`sp+0x23c`, also `0x228` Bytes nach dem Pufferanfang. Ein vollständiges
Überschreiben seines 32-Bit-Werts erfordert mindestens `0x22c` ausgegebene
Bytes. Die dazwischenliegenden lokalen Variablen werden schon vorher
überschrieben und später verwendet. Deshalb sind zuverlässige
Kontrollflussübernahme und RCE nicht belegt. Ebenfalls nicht verifiziert ist,
ob der Parser beliebig lange XML-/Property-List-Schlüssel annimmt.

Wenn der erste Dateipfad nicht erfolgreich verarbeitet wird, ruft derselbe
Funktionskörper `FUN_0821a3f0` mit dem Namen auf. Diese Funktion formatiert
denselben `Device/<name>.xml`-Pfad erneut in einen lokalen 256-Byte-Puffer und
übergibt ihn an den XML-Parser `FUN_082a0ed0`. Auch dort gibt es für den
Formatierer keine Zielgrößenangabe. Ein sehr langer Funktionsparameter wäre
somit ein weiterer bedingter Stackfehler; seine Quelle ist nicht bestimmt.

## Erreichbarkeit

Der einzige direkte Code-Xref auf `FUN_0821a3f0` im Ghidra-Projekt ist der
Aufruf bei `0x08087dac` im rekonstruierten Körper `0x08087d2c`. Für
`0x08087d2c` selbst fand sich kein direkter Code-Xref. Ein Scan des
`osos_body.bin` nach absoluten, Thumb-markierten und 24-Bit-relativen
Funktionszeigern auf diesen Einstieg ergab keine Treffer. Das schließt
berechnete, extern registrierte oder zur Laufzeit geladene Aufrufe nicht aus,
belegt aber keinen Weg von einem normalen OSOS-Kaltstart zu diesem Parser.

Der separate Loader `FUN_082e0a0c` wird beim lazily erzeugten Objekt aus
`FUN_082d91f0` aufgerufen; dieses Objekt wird über `FUN_0828fc1c` bereitgestellt.
Einige gefundene Zugänge laufen über Event-, Medien- oder Workout-Funktionen.
Ein Kaltstartpfad von MainApp bis zum rekonstruierten XML-Parser oder zu
`0x08087d2c` wurde dabei nicht hergestellt. `FUN_08077f10` und
`FUN_08230678` enumerieren außerdem `iPod_Control/Device/Accessories/Tags/`;
im geprüften Enumerationspfad werden Dateinamen an Callbacks übergeben, aber
Dateiinhalte nicht geparst.

## Bewertung

Der Formatter-Fehler ist bestätigt. Der Stackfehler im Device-XML-Loader ist
ein neuer dateikontrollierter Speicherfehler-Kandidat, aber derzeit weder als
beim Kaltstart erreichbarer Pfad noch als zuverlässige Codeausführung
verifiziert. Er ist noch kein belastbarer Weg zum untethered Rockbox-Boot.

## Nächste statische Schritte

1. Die externe Registrierung oder indirekte Aufrufstelle für `0x08087d2c`
   finden und ihre Kaltstart-Erreichbarkeit prüfen.
2. Die Format- und Längenregeln von `FUN_082aba26`/`FUN_0835b1a0` für
   Schlüsselstrings klären, einschließlich möglicher Parsergrenzen.
3. Weitere erreichbare Aufrufer von `FUN_081c38b0` nach dateikontrollierten
   Argumenten und kleineren Stackzielen durchsuchen.
4. Den getrennten `FUN_082e0a0c`-Konfigurationspfad von seinem Singleton bis
   zu einem konkreten Start- oder Eventauslöser verfolgen.

## Rohbelege

- `/tmp/OSOS_dynamic_xml_functions_followup_20261026.txt`
- `/tmp/OSOS_dynamic_xml_owner_08087d2c_20261026.txt`
- `/tmp/OSOS_dynamic_xml_refs_20261026.txt`
- `/tmp/OSOS_dynamic_xml_roots_and_tags_refs_20261026.txt`
- `/tmp/OSOS_xml_paths_and_accessory_tags_followup_20261026.txt`
- `/tmp/OSOS_formatter_sink_followup_20261026.txt`
- `/tmp/OSOS_formatter_string_sink_followup_20261026.txt`
- `/tmp/OSOS_formatter_callbacks_followup_20261026.txt`
- `/tmp/OSOS_property_loader_callers_20261026.txt`
- `/tmp/OSOS_property_loader_dispatch_refs_20261026.txt`
- `/tmp/OSOS_property_loader_mediator_callers_20261026.txt`
- `/tmp/OSOS_property_loader_mediator_refs_20261026.txt`
- `/tmp/OSOS_property_loader_outer_refs_20261026.txt`
- `/tmp/OSOS_property_loader_top_refs_20261026.txt`
- `/tmp/OSOS_property_loader_upstream_20261026.txt`

Alle Ghidra-Läufe verwendeten `-noanalysis -readOnly`; Änderungen wurden vom
Projekt verworfen.

## Nachtrag: Parser-Eingabelimit (26.10.2026)

`FUN_082aba26` übergibt `0x8000` an `FUN_082acd00` und von dort an den
Parserkontext-Konstruktor `FUN_0829f290`. Der Wert steuert eine
`FUN_081bd3b0`-Allokation von `0x8000 + 0x20` Bytes. Er ist damit eine
Anfangsgröße, keine nachgewiesene Gesamtgrenze der XML-Datei.

Beim weiteren Einlesen hängt `FUN_082a1a9c` Daten an den Parserpuffer an und
ruft bei fehlender Kapazität `FUN_08285740` zum Vergrößern auf. Die dort
verwendete obere Schranke ist `0x7fffffff` (`DAT_08285810`), nicht `0x8000`.
Der eingesehene Pfad weist daher keine 32-KiB-Gesamtgrenze nach. Eine
XML-Schlüsselgröße über dem für LR nötigen Abstand ist durch diesen
Initialwert nicht ausgeschlossen. Ob der Loader beim Kaltstart erreicht wird,
bleibt offen; die Namensgrenze wurde in einem Nachtrag weiter geprüft. Es wurde
kein Gerätetest durchgeführt.

Zusätzliche Rohbelege:

- `/tmp/OSOS_xml_parser_limits_followup_20261026.txt`
- `/tmp/OSOS_xml_parser_constructor_followup_20261026.txt`
- `/tmp/OSOS_xml_buffer_growth_followup_20261026.txt`
- `/tmp/OSOS_xml_buffer_constants_followup_20261026.txt`

## Nachtrag: XML-Elementnamen ohne feste Scannergrenze (26.10.2026)

Der Start-Tag-Parser `FUN_081517cc` ruft für den Elementnamen
`FUN_0824fc98` auf. Dessen unqualifizierter Pfad geht über `FUN_08150e44`;
der durch `:` getrennte Namenspfad verwendet zusätzlich `FUN_0827d660`.
Beide Scanner laufen bis zum ersten unzulässigen Trennzeichen und übergeben
die vollständige Differenz als Länge an den Dictionary-Internierer
`FUN_0829eba4`. In den gescannten Schleifen gibt es keine feste
Namenslängenprüfung. Der Internierer vergleicht die Länge mit vorhandenen
Einträgen und legt bei Bedarf einen Speicherblock anhand der Länge an; für
Namen in der Größenordnung des `0x22c`-Byte-LR-Abstands ist in diesem Pfad
keine zusätzliche Grenze sichtbar.

Damit können XML-Elementnamen aus bereits verfügbaren ASCII-Bytes statisch
länger als der Abstand zum gespeicherten LR werden. Die Parserpuffer-Analyse
weist `0x8000` als anfängliche, vergrößerbare Kapazität nach; ein Name von
`0x22d` Bytes liegt darunter. Der Loader `0x08087d2c` verwendet anschließend
geparste Knotennamen aus dem XML-Baum in `sprintf("%s_%s")` mit dem lokalen
252-Byte-Zielpuffer. Das schließt die frühere Unsicherheit über eine feste
Namensgrenze für diesen Eingabepfad.

Es schließt die Erreichbarkeitslücke nicht: Für `0x08087d2c` gibt es weiterhin
keinen direkten Code-Xref oder gefundenen statischen Funktionszeiger aus dem
normalen OSOS-Kaltstart. Auch ein vollständig überschriebenes LR beweist wegen
der zuvor überschriebenen und später verwendeten lokalen Variablen keine
zuverlässige Kontrollflussübernahme. Es wurde weder ein Parserlauf noch ein
Gerätetest ausgeführt; das bleibt ein bestätigter dateikontrollierter
Speicherfehler-Kandidat, kein bestätigter RCE-Pfad.

Zusätzliche Rohbelege:

- `/tmp/OSOS_xml_name_scanner_context_20261026.txt`
- `/tmp/OSOS_xml_name_helper_20261026.txt`
- `/tmp/OSOS_xml_name_helpers_2_20261026.txt`
- `/tmp/OSOS_xml_08150e44_20261026.txt`
- `/tmp/OSOS_xml_intern_and_nodes_20261026.txt`
- `/tmp/OSOS_xml_tree_methods_20261026.txt`
