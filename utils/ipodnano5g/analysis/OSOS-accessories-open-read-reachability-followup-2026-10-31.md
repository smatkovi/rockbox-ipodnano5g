# `accessories.reg`: Open-/Read-Pfad weiter eingegrenzt

Stand: 31.10.2026. Read-only-Ghidra-Abgleich des OSOS-Runtime-Abbilds. Die
untersuchten Projektabfragen liefen mit `-noanalysis -readOnly`. Kein
Gerätezugriff, kein Schreiben auf NAND/NOR und kein Firmware-Flash.

## Neue, verifizierte Kante

Der normale FAT-Open-Wrapper `FUN_081382b6` ist kein bloßer unveränderter
Thunk: Er setzt `r3` zunächst auf `0xffffffff` und ruft danach
`FUN_081382c2` auf. Im üblichen Modus-1-Pfad von `FUN_0812a870` wird dieser
Wrapper verwendet, wenn das optionale Provider-Cachefeld `+0x60` leer ist.
Der neu konstruierte MBR/FAT-Provider initialisiert dieses Feld auf null; die
separate Cache-/Namensroute setzt einen zuvor befüllten, wiederverwendeten
Provider voraus.

`FUN_081382c2` übernimmt den Wert als viertes Argument und reicht ihn als
sechstes Argument an `FUN_0814f238` weiter. Bei einem Root-Open
(`param_1 == 0`) behandelt `FUN_0814f238` `-1` als Sentinel: Es überspringt
den optionalen `FUN_081f83c8`-Zwischenschritt und ruft den Verzeichnisscanner
`FUN_08158b64` auf. Damit ist der Scannerpfad für den normalen leeren
Provider-Cache mit konkretem Registerfluss belegt. Der Scanner lädt vor der
LFN-Verarbeitung den lokalen Verzeichniseintragsindex in `r2`; der frühere
Stackpufferzeiger wird dabei überschrieben. Das bestätigt den bereits
dokumentierten Fix der Stackzeiger-OOB-Hypothese.

## Mount- und Read-Kette

- Der automatische `accessories.reg`-Aufruf verwendet `FUN_082721f0(..., 0)`.
  Der Streamkonstruktor wandelt dies in den Modus 1 um. `FUN_08224970` wählt
  den Open-Callback bei VTable-Offset `+0x14`; beim MBR/FAT-Provider ist das
  `FUN_0812a870`.
- Der allgemeine Dateisystem-Open führt über `FUN_081fdd06` zu
  `FUN_0814e76c` und `FUN_0816039c`. Wenn der Laufwerkszustand die Mount-Route
  zulässt, geht diese zu `FUN_08158f90` und `FUN_0814ef74`; der BPB-Leser
  fordert den Startsektor über `FUN_08158dd0` und `FUN_082192c4(index, 0,
  buffer, 1, 0)` an.
- Ein Datei-Read aus dem Stream geht über `FUN_081fd5e8` zum Provider-VTable-
  Slot `+0x1c`. `FUN_0812ac00` zerlegt größere Anforderungen in begrenzte
  Teilreads und erreicht `FUN_081384b0`/`FUN_0814346c`; dort liegen der
  eigentliche FAT-Datei-/Cluster-Read und die Cachezugriffe.

Das schließt die statische Funktionskette weiter, aber nicht den Laufzeit-
Provider: Der dynamische Block-I/O-Tabelleninhalt liegt außerhalb des
aufgenommenen Runtime-Abbilds. Der automatische MainApp-Aufruf, die erfolgreiche
Slot-0-Registrierung und ein echter vollständiger VFS-Open-/Read wurden nicht
auf dem Gerät beobachtet. Die aktuellen QEMU-Rehosts setzen weiterhin
VFS-/Handlezustände oder modellieren Datei- und Loader-Reads.

## Auswirkung auf den Rockbox-Kandidaten

Der lokale 736-Byte-`accessories.reg`-Kandidat passt rechnerisch in den
vorhandenen 8192-Byte-Cluster. Der aufgezeichnete Gerätebestand enthielt
jedoch eine 69-Byte-Datei mit einem harmlosen Längenfeld von 9; ein ersetzter
Inhalt braucht daher auch passende Verzeichnis-Metadaten. Die statische
Open-/Read-Kette beweist weder, dass ein solcher Inhalt beim OSOS-Kaltstart
gelesen wird, noch dass der ROP-Pfad den lokalen Loader tatsächlich startet.
Der iPod und sein Datenträger wurden in dieser Runde nicht verändert.

## Belege

Read-only-Ghidra-Abzüge und Eingabehash liegen unter
`evidence/accessories-open-read-reachability-2026-10-31/`. Die vorhandenen
rohen FAT-Seiten und Rehosts bleiben unter
`evidence/lfn-resolution-2026-10-28/rehost/` und
`evidence/accessories-alias-system-parser-rehost-2026-10-31/`.

Der nächste Offline-Schritt ist, die beim Wrapper-Rehost noch manuell
gesetzten VFS-/Mountzustände weiter aus den echten Runtime-Konstruktoren und
den gesicherten Root-/Device-Verzeichnisseiten herzuleiten. Erst ein solcher
vollständiger Modelllauf könnte die verbleibenden Callback-Stubs verkleinern;
er ersetzt keine Messung der Slotregistrierung auf Hardware.
