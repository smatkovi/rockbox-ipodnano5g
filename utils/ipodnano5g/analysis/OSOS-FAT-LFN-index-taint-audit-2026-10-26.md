# FAT-LFN-Pfadauflösung: Stackzeiger als Eintragsindex

Stand: 26.10.2026. Statische Auswertung des vorhandenen OSOS-Runtime-Abbilds
`osos_runtime_dram_20261025.bin` und des read-only geöffneten Ghidra-Projekts.
Zusätzlich wurde das aktuell per USB als Massenspeicher erkannte FAT-Volume
read-only untersucht. Es gab keine Änderungen am Datenträger, keinen DFU- oder
Neustart und keinen Lauf des OSOS-Callbacks.

## Ergebnis

Beim Auflösen von FAT-Verzeichniseinträgen erhält `FUN_08158b64` einen Zeiger
auf einen Stackpuffer als drittes Argument. Bei einem gültigen VFAT-LFN-Eintrag
setzt sie diesen Wert über `FUN_081f7f9c` in den lokalen LFN-Zustand. Beim
folgenden Kurznamen verwendet `FUN_08159128` den Wert als Verzeichniseintrags-
index und berechnet daraus eine Leseadresse in einem gecachten Sektor.

Das ist ein statisch belegter, datenträgerabhängiger ungültiger Lesezugriff in
der FAT-Namensauflösung. Die geprüften Kopierziele bleiben dabei innerhalb des
256-Byte-LFN-Puffers; eine überschreibbare Rücksprungadresse oder eine
Kontrollflussübernahme ergibt sich aus diesem Pfad nicht. Der Befund ist daher
ein möglicher Absturz-/Denial-of-Service-Kandidat, keine bestätigte RCE.

## Read-only-Prüfung des aktuellen Gerätespeichers

`lsusb` meldete das Gerät als `05ac:1265` (iPod nano 5G), Konfiguration 1 als
USB-Massenspeicher. `/dev/sda1` wurde unter
`/tmp/ipod-sebipod-readonly` mit `ro,nosuid,nodev,noexec` eingehängt. Der
Linux-VFAT-`READDIR_BOTH`-ioctl lieferte für die relevanten Verzeichnisse
folgende Kurznamen (8.3) und Langnamen:

- Volume-Root: `IPOD_C~1` → `iPod_Control`.
- `iPod_Control`: `DEVICE` → `Device`.
- `iPod_Control/Device`: `ACCESS~1.REG` → `accessories.reg`.
- Volume-Root: `ROCKBO~1` → `.rockbox`; darin ist `rockbox.ipod` vorhanden.

Damit enthalten sowohl der erste Pfadbestandteil `iPod_Control` als auch die
Zieldatei `accessories.reg` echte VFAT-LFN-Einträge. Die kanonische
`accessories.reg`-Öffnung muss daher den LFN-Zweig der Namensauflösung
durchlaufen. Wenn die fehlerhafte LFN-Rekonstruktion nicht abbricht, vergleicht
der Resolver danach zusätzlich den 8.3-Kurznamen; dieser Alias stimmt nicht
mit dem angeforderten Langnamen überein. Das macht einen erfolgreichen Open
über den untersuchten Pfad unwahrscheinlich, beweist ihn aber nicht: Fault-
Adresse, Rückgabepfad und exaktes Laufzeitverhalten wurden nicht am Gerät
gemessen. Der USB-Massenspeicherzugriff führt den OSOS-Datei-Open nicht aus.

Der aktuelle MBR ist unauffällig: logische Sektorgröße 4096 Byte, Partition 1
beginnt bei LBA 63 und umfasst 3.901.312 Sektoren; das Gerät meldet 3.901.376
Sektoren. Die BPB-Sektorgröße ist ebenfalls 4096 Byte. Das bestätigt nur den
Zustand der aktuellen Partition und testet keine OSOS-LBA-Verarbeitung.

## Argument- und Datenfluss

Ghidra meldet für `FUN_0814f238` zwei direkte Aufrufe:

- `0x08138360` aus `FUN_081382c2`. Die Callsite übergibt
  `(0, handle, auStack_234, auStack_238, 0, local_18)`. Die Instruktionen in
  `FUN_0814f238` reichen die ursprünglichen Argumente 3, 4 und 5 an
  `FUN_08158b64` weiter. Damit kommt dessen Register `r2` als Adresse des
  Stackfelds `auStack_238` an.
- `0x0821b440` aus `FUN_0821b42c`. Dieser Wrapper reicht die ersten fünf
  Argumente weiter und setzt Argument 6 auf `-1`. Ein geprüfter Caller aus
  `FUN_081fdb38` übergibt als drittes Argument `auStack_118` und als viertes
  `auStack_11c`; auch hier ist das spätere `r2` in `FUN_08158b64` eine
  Stackadresse.

Der Open-Callback `FUN_0812a870` ruft `FUN_081382c2` bei `0x0812a90a` direkt
auf. Sein alternativer Pfad geht über `FUN_081382b6`, das ebenfalls
`FUN_081382c2` aufruft. `FUN_081382c2` löst danach Komponenten über
`FUN_081fdb38` und `FUN_0814f238` auf. Der LFN-Fehler liegt daher im generischen
FAT-Pfadauflösungspfad, den der Open-Callback verwendet.

`FUN_08158b64` hat genau einen direkten Code-Aufrufer, `FUN_0814f238` bei
`0x0814f27a`. Die Assembly-Spur des ersten LFN-Datensatzes ist:

1. `FUN_081f822c` initialisiert den lokalen Zustand, ohne `r2` zu ändern.
2. `FUN_0821959c` lädt den Verzeichnisblock. Diese Funktion sichert `r2` mit
   `push {r2,r3,...}` und stellt es mit `pop {r2,r3,...}` wieder her.
3. Bei einem LFN-Eintrag ruft `FUN_08158b64` bei `0x08158bb0`
   `FUN_081f7f9c(state, cursor[3])` auf, setzt `r2` davor aber nicht neu.
   Die Instruktion bei `0x081f7fb4` speichert genau dieses Register in
   `state[1]`.
4. Beim folgenden Kurznamen ruft `FUN_08158b64` bei `0x08158bf8`
   `FUN_08159128` auf. Diese Funktion berechnet aus `state[1]` den Quellzeiger
   `cached_block + 0x18 + state[1] * 0x20`.

Die Decompiler-Signatur von `FUN_081f7f9c` zeigt nur zwei Argumente. Die
Instruktionen belegen jedoch die Speicherung des bereits vorhandenen dritten
Arguments in `r2`; die Aussage beruht deshalb auf der Assembly- und
Callsite-Spur, nicht auf der unvollständigen Decompiler-Signatur.

## Auswirkung und Grenzen

Die LFN-Rekonstruktion schreibt in den lokalen Puffer `auStack_138[256]`.
`FUN_08160828` prüft vor dem Zeichenkopieren gegen das Zielende abzüglich vier
Bytes und terminiert innerhalb dieses Puffers. Im hier untersuchten Aufruf
liegt `state[1]` bei einer normalen OSOS-Stackadresse im positiven Bereich;
damit wird `iVar2` auf die LFN-Anzahl begrenzt. Die zweite Kopierphase erhält
dann Länge `Anzahl - iVar2 = 0`. Der fehlerhafte Wert beeinflusst somit die
Quelladresse, nicht das Schreibziel.

Der berechnete Quellzeiger kann außerhalb des gecachten Sektors liegen. Ob er
im konkreten Lauf einen Data Abort auslöst oder auf anderes RAM zeigt, hängt
von der dynamischen Task-Stackbasis und dem Cachepuffer ab; beides ist aus dem
Runtime-Abbild nicht bestimmbar. Selbst bei einem lesbaren Ziel ist aus dem
geprüften Code kein Schreiben an diese Adresse und kein kontrollierter
Rücksprung ersichtlich.

Die Routine verarbeitet Verzeichniseinträge aus dem FAT-Datenträger und wird
von den generischen Pfadauflösern verwendet. Damit ist die Eingabequelle
statisch dateisystemkontrolliert. Die frühe `accessories.reg`- und die
Kandidaten-Loaderöffnung benutzen den OSOS-VFS-Stream; falls ihre Pfadteile
über VFAT-LFN-Einträge gefunden werden, kann dieser Fehler bereits die
Pfadauflösung unterbrechen, bevor die jeweilige Datei gelesen wird. Welche
Short-/Long-Name-Einträge der konkrete Datenträger enthält, welche Adresse der
Taskstack zur Laufzeit hat und ob der Open-Aufruf den LFN-Zweig erfolgreich
passiert, ist nicht belegt. Ein gezielter Gerätelauf fand nicht statt.

## Ghidra-Xrefs und Arbeitsartefakte

- `FUN_0814f238`: direkte Callsites `0x08138360` und `0x0821b440`.
- `FUN_08158b64`: einzige direkte Callsite `0x0814f27a`.
- `FUN_08159128`: Callsites `0x08158bf8` und `0x08143d48`; der zweite Pfad ist
  die separat geprüfte Verzeichnisenumeration mit eigener Zustandsinitialisierung.
- VFS-Kette: `FUN_0812a870` → `FUN_081382c2` bei `0x0812a90a`; der Fallback
  `FUN_081382b6` ruft ebenfalls `FUN_081382c2` auf.
- Lokale Disassemblierungen: `/tmp/OSOS_runtime_fat_path_core_followup_20261026.txt`,
  `/tmp/OSOS_runtime_fat_path_resolution_20261026.txt`,
  `/tmp/OSOS_runtime_fat_lfn_audit_20261026.txt` und
  `/tmp/OSOS_runtime_fat_lfn_copy_helpers_20261026.txt`.
- Referenzen wurden mit Ghidra `analyzeHeadless` am read-only Projekt
  `/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime` abgefragt. Die dafür
  benutzten temporären Skripte liegen unter `/tmp/ghidra-query-script/`.
- Die read-only FAT-Namensliste wurde mit `/tmp/ipod_vfat_dir_ioctl.py` erzeugt
  und in `/tmp/OSOS_live_vfat_dir_ioctl_20261026.txt` festgehalten. Das Volume
  war währenddessen unter `/tmp/ipod-sebipod-readonly` read-only eingehängt.

## Nächster sinnvoller Schritt

Für eine endgültige Laufzeitentscheidung wären dynamische Task-Stack- und
Sektorbuffer-Adressen sowie ein gezielter OSOS-Lauf beim normalen Neustart
nötig. Dieser Test wurde nicht ausgelöst, weil die aktuelle Verbindung nur
den USB-Massenspeicherzugriff bereitstellt. Der aktuelle Langnamenbestand
verschärft die Erreichbarkeitsbedingung des `accessories.reg`-Kandidaten; der
Stacküberlauf bleibt der stärkste Kontrollfluss-Kandidat, aber sein
automatischer Open/Read und der Loader-Handoff sind weiterhin unbestätigt.

## Nachtrag: LFN-Zustandswert und gemeinsam veränderte Zählvariable (27.10.2026)

Die Aufruferprüfung bestätigt den fehlerhaften Wert genauer: In beiden
Aufrufketten erhält FUN_08158b64 als drittes Argument die Adresse eines lokalen
Stackfelds. Bei einem VFAT-LFN-Eintrag speichert FUN_081f7f9c das unverändert
übergebene r2 in state[1]. FUN_08159128 verwendet state[1] anschließend als
Index und bildet daraus mit index * 0x20 eine Leseadresse im gecachten
Verzeichnisblock. Das bestätigt einen datenträgerabhängigen Out-of-bounds-Read
aus einer aus dem Stackzeiger abgeleiteten Adresse.

Die Kopierroutine FUN_08160828 begrenzt das Ziel weiter auf den lokalen
256-Byte-Puffer. Im untersuchten Pfad schreibt sie nicht an die berechnete
Quelladresse. Der Befund bleibt daher ein ungültiger Read mit möglichem Abort
oder fehlerhafter Namensauflösung; eine Kontrollflussübernahme ist daraus nicht
ersichtlich.

Zusätzlich addieren FUN_0814f6c8 und FUN_08158b64 Werte aus diesem
Stackargument in das gemeinsame globale Wort bei 0x086b7544. Die direkten
Referenzen zeigen dort Read-Add-Write-Sequenzen, aber keine sichtbare
Verzweigung anhand des Werts. Das liefert derzeit keine zusätzliche
Kontrollflusskante. Der genaue Zweck der globalen Zählvariable ist weiter
offen.

Belege aus dieser Runde: /tmp/OSOS_lfn_resolver_deep_20261027.txt,
/tmp/OSOS_lfn_resolver_callers_20261027.txt,
/tmp/OSOS_lfn_global_users_20261027.txt,
/tmp/OSOS_lfn_globals_20261027.txt,
/tmp/OSOS_lfn_globals2_20261027.txt und der Ghidra-Xref-Lauf zu
0x086b7544. Die Headless-Ghidra-Läufe verwendeten -readOnly -noanalysis.
Es gab keinen Gerätezugriff und keinen Dateisystemtest.

## Nachtrag: 8.3-Fallback und erreichbarer Openpfad (27.10.2026)

Der Kurzname-Fallback wurde jetzt bis zu seinem Vergleich verfolgt.
`FUN_0821758c` formt aus den elf Bytes des FAT-Kurzeintrags einen druckbaren
8.3-Namen (Leerzeichen werden ausgelassen, ein Punkt trennt Basisname und
Erweiterung). `FUN_08158b64` versucht bei einem LFN-Eintrag zuerst die
Rekonstruktion über `FUN_08159128` und vergleicht sie mit dem angeforderten
Pfadbestandteil über `FUN_08160950`. Wenn das nicht passt, baut es den
Kurznamen und ruft `FUN_081f1a38` auf. Dieser Wrapper setzt nur den
Wildcard-Modus und landet wieder in `FUN_08160950`. Der Vergleich ist
case-insensitiv und kann `*`/`?` im angeforderten Muster auswerten; er wandelt
den Kurznamen nicht in den Langnamen um.

Für den ausgelesenen Datenträger passen daher `Device` und `DEVICE` nach
Groß-/Kleinschreibung, aber `iPod_Control` passt nicht auf `IPOD_C~1` und
`accessories.reg` nicht auf `ACCESS~1.REG`. Die automatische
`accessories.reg`-Route muss zunächst das Root-Verzeichnis `iPod_Control`
auflösen. Sie erreicht das normale Datei-Open/den übergroßen Read deshalb nach
dieser statischen Spur voraussichtlich nicht. Zusätzlich ist beim ersten
LFN-Eintrag der aus einer Stackadresse abgeleitete Index als mögliche
Data-Abort-/Fehlauflösungsursache belegt. Die Reihenfolge der internen
Directory-Callbacks, Fault-Behandlung und tatsächliche Open-Rückgabe wurden
nicht dynamisch geprüft; ein alternativer Providerpfad ist daher nicht
ausgeschlossen.

Der zusätzliche Mehrkomponentenpfad in `FUN_08224970` enthält ebenfalls keine
erkennbare 8.3-zu-LFN-Übersetzung. Die geprüfte FAT-Provider-Tabelle bei
`0x085056b0` hat bei `+0x14` den Thumb-Zeiger auf `FUN_0812a870` und bei
`+0x58` den Thumb-Zeiger auf `FUN_0812a7b4`. `FUN_08224970` verwendet diese
beiden Slots für den endgültigen Open beziehungsweise die Prüfung eines
mehrteiligen Pfades. `FUN_0812a7b4` delegiert an `FUN_08137c12`; dieser Pfad
zerlegt und löst Komponenten über `FUN_081fdb38` und `FUN_0821b42c` auf und
landet damit wieder im beschriebenen FAT-LFN-Resolver. `FUN_0821ab24` im
anderen Zweig initialisiert nur einen Providerzustand und enthält keinen
Pfadauflöser. Das schließt einen anderen, dynamisch ausgewählten Provider
nicht aus, bestätigt aber für die geprüfte FAT-Provider-Tabelle keinen
Kurzname-Umweg.

**Auswirkung auf den Rockbox-Kandidaten:** Der statisch abgezählte Überlauf in
`FUN_0802c3c4` bleibt eine echte Rücksprungkontrollmöglichkeit, falls sein
Read erreicht wird. Mit dem aktuellen FAT-Namensbestand und dem untersuchten
Vergleich ist der benötigte Open/Read jedoch nicht belegt und eher blockiert.
Die ROP-Folge ist daher kein ausführbarer oder bestätigter Installationsweg.
Dasselbe Erreichbarkeitsproblem kann andere fest codierte
`iPod_Control/...`-Dateien betreffen; kurze letzte Komponenten wie `alarms`
umgehen das lange Root-Verzeichnis nicht.

Neue Rohbelege:

- `/tmp/OSOS_accessories_lfn_name_fallback_20261027.txt` – Vergleichs- und
  8.3-Formatierungsfunktionen.
- `/tmp/OSOS_accessories_open_dispatch_deep_20261027.txt` – Dispatcher
  `FUN_08224970`, Komponenten-Zähler und `FUN_082284e0`.
- `/tmp/OSOS_accessories_open_path_helpers_20261026.txt` und
  `/tmp/OSOS_accessories_vfs_open_followup_20261026.txt` – Provider- und
  Stream-Aufrufpfad.
- `/tmp/OSOS_fat_provider_callbacks_refs_20261027.txt` und
  `/tmp/OSOS_fat_provider_vtable_20261027.txt` – Xref und Methodenwerte der
  geprüften FAT-Provider-Tabelle.
- `/tmp/OSOS_fat_provider_slot58_temp_20261027.txt` und
  `/tmp/OSOS_fat_provider_slot58_helpers_20261027.txt` – dekompilierter
  `+0x58`-Pfad und seine Resolver-Helfer.

Die Ghidra-Abfrage lief read-only mit `-readOnly -noanalysis`; es gab keine
Geräteabfrage, keinen Neustart, keinen Dateisystemtest und keinen
NAND-/NOR-/Flashzugriff.
