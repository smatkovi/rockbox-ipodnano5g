# BDS→OSOS-Handoff: Kopierlänge und Stackpuffer-Kandidat

Stand: 31.10.2026. Read-only-Analyse der extrahierten BDS-/OSOS-Binärdateien.
Kein Geräte-, USB-, DFU-, Reboot-, Dateisystem- oder Flashzugriff.

## Verifizierter Befund

Die frühere Vermutung, OSOS kopiere ein Byte mehr als BDS bereitstellt, war
falsch. BDS `FUN_00000bc4` findet die EFI-GUID
`CA BE 81 31 A1 92 41 BA 90 34 D9 F8 E4 9A 32 3D` und ruft
`interface+4` mit `(interface, 1, sp+0x18)` auf. Danach übergibt BDS an
`CopyMem` die Länge `0x138`. Die Bytes landen bei `0x22028cc0`; BDS schreibt
außerdem den Marker `0x53797349` und diesen Quellzeiger in den SRAM-
Übergabeblock.

OSOS `FUN_0801b32c` prüft den Marker, lädt den Quellzeiger und kopiert nach
`0x086c7404`. Der Thumb-Code setzt den Zähler auf `0xff`, addiert `0x39` und
erhält `0x138`. Vor jeder Bytekopie dekrementiert er den Zähler und kopiert,
solange der unsigned Borrow noch nicht gesetzt ist. Das ergibt genau 312
Bytekopien: `0x137` bis `0`, danach beendet der nächste Schritt mit Borrow die
Schleife. Damit stimmen BDS- und OSOS-Länge überein; die Adresse `sp+0x150`
liegt außerhalb des kopierten Bereichs.

Der Ein-Byte-Überlauf ist kein Exploitkandidat. Die GUID-Karte zeigt zwei
Protokollanbieter, die `FUN_00000bc4` abfragt:

- GUID `0x15a0` führt zu Modul `42__0.pe32`. Slot `+4` zeigt auf
  `FUN_000005e8`, die BDS mit `(interface, 1, sp+0x18)` aufruft. Die Methode
  kombiniert ihre Argumente 2 und 3 zu einer Bitmaske; sie dereferenziert oder
  beschreibt den Stackzeiger nicht.
- GUID `0x1570` führt zu Modul `11__0.pe32`. Slot 0 zeigt auf
  `FUN_00000270`. BDS ruft die Methode mit dem Wort bei `sp+0x9c` und dem Wort
  bei `sp+0x1a0` auf. Das erste Wort ist Handoff-Offset `+0x84`; die Methode
  liest es als Skalar und gibt nur dann Erfolg zurück, wenn
  `(Wert >> 16) == 0x1c` und das zweite Wort `0x1c000` ist. Sie schreibt an
  keiner der beiden Adressen.

Direkte Stores in `FUN_00000bc4` initialisieren den Quellbereich
`[sp+0x18, sp+0x150)` nicht: Der Nullstore liegt bei `sp+0x150`, genau am
exklusiven Ende. Der einzige In-Range-Zeiger, den BDS einem Provider übergibt,
ist `sp+0x18` an den nicht schreibenden Modul-42-Slot. Das Wort bei `sp+0x9c`
ist damit stack-abgeleitet, wenn Modul 11 es prüft. Den Rückgabestatus des
vorherigen Aufrufs `param_1+0x24` ignoriert BDS. Dieser Aufruf erhält zwar
einen 0x30-Byte-Ausgabebereich ab `sp+0x178`, der das zweite Gate-Wort bei
`sp+0x1a0` umfasst; bei einem Fehler könnte auch dieses Wort stale sein.
Erfolg am Gate führt zum Kopieren von 312 Bytes in den SRAM-Handoff. Ob dieser
Pfad auf einem realen Kaltstart erreicht wird, ist nicht belegt.

Korrektur zur Zwischenfassung: Provider `01__0.pe32` registriert GUID
`0x14f0`, die BDS in anderen Funktionen referenziert, aber nicht in
`FUN_00000bc4`. Seine Funktion `FUN_00000394` belegt daher nicht, dass ein
Callback Handoff-Offset `+0x84` befüllt. Die frühere Aussage über einen
Schreiber bei `sp+0x9c` war falsch. Die Slotprüfung schließt außerdem einen
zunächst vermuteten ABI-Fehler: Das Interface ab `0x428` hat die Einträge
`0x265` (`FUN_00000264`), `0x395` (`FUN_00000394`) und `0x221`
(`FUN_00000220`). BDS ruft Slot 0 auf. `FUN_00000264` nimmt zwei Argumente,
prüft Dateisystem-Info und öffnet den übergebenen UTF-16-Pfad; BDS übergibt
bei `0x4e0` den String `disk`. Die drei Argumente von `FUN_00000394` gehören
zu Slot 1, daher trifft der BDS-Zwei-Argument-Aufruf diese Methode nicht.
`FUN_00000f0c` nutzt Slot 2 (`FUN_00000220`) zum Schließen eines geöffneten
Dateihandles. Der Byte-Scan der geprüften `bl-efi`- und `diags-efi`-PE32-
Module findet die GUID nur in `bl-efi/01__0.pe32` (Registrierung) und
`bl-efi/05__0.pe32` (BDS-Abfrage). Das belegt passende statische
Schnittstellen, aber keinen erfolgreichen Laufzeit-Open oder einen Exploit.

OSOS liest das kopierte Feld bei `+0x84` später als Plattformkennung:
`FUN_08006e34` nimmt die oberen 16 Bits und ordnet `0x1c` dem Metadatenwert 5
für `GamesPlatformID` zu. Das Feld ist damit ein Datenwert, kein
Kontrollflusszeiger. Im aktuellen Ghidra-Callgraph wird dieser Leser von
`FUN_08008290` aufgerufen; diese Funktion wird von `FUN_0804d748` auf dessen
`param_2 == 0`-Zweig aufgerufen. Einziger gefundener direkter Aufrufer von
`FUN_0804d748` ist `FUN_080054a0`. Das belegt noch keinen Kaltstartpfad und
keine Angreiferkontrolle. Ein Codeausführungsprimitive oder ein Weg zum
untethered Rockbox-Boot ist nicht belegt.

## Belege

Die vollständigen read-only Ghidra-Ausgaben und das Thumb-Listing liegen in
[`evidence/bds-osos-handoff-length-2026-10-31/README.md`](evidence/bds-osos-handoff-length-2026-10-31/README.md).
Der OSOS-DRAM-Suffix hat SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`; die
Eingabe-Hashes der EFI-Module sind im Evidenz-README notiert.

## Nächste Runde

Der Längenhinweis ist geschlossen. Der stack-abgeleitete Plattformwert und
das Modul-11-Gate sind statisch belegt; Laufzeitwerte und
Kaltstart-Erreichbarkeit bleiben offen. Die GUID-`0x14f0`-Aufrufkette ist
statisch geklärt; ein ABI-Fehler ist kein Kandidat. Der OSOS-Accessory-VFS-/
FAT-Open-Pfad ist bereits in den separaten Berichten
`OSOS-accessories-slot0-open-argument-audit-2026-10-30.md` und
`OSOS-accessories-real-volume-LBA-rehost-followup-2026-10-30.md` eingegrenzt.
Die maßgebliche offene Frage ist nun die tatsächliche Start-/Task-
Erreichbarkeit des Parseraufrufs samt Laufzeit-Provider-, Handle- und
Speicherzustand. Kein Geräte-, USB-, DFU-, Flash- oder Emulator-Test wurde in
dieser Runde ausgeführt.
