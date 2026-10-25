# OSOS-Laufzeitlücke als möglicher untethered Einstieg – VTable-Folgeprüfung

Stand: 25.10.2026. Diese Prüfung war offline und read-only. Es gab keine
USB-, DFU-, Boot-, NAND- oder NOR-Aktion.

## Bewertung der Idee

Ja: Eine Schwachstelle im signierten, normal gestarteten iPod-OS könnte
prinzipiell einen untethered Rockbox-Start ermöglichen, ohne eine
Bootloader-Signatur zu fälschen. Dafür müsste ein persistenter, vom Nutzer
kontrollierbarer Datensatz den fehlerhaften OSOS-Pfad bei jedem normalen
Kaltstart automatisch erneut auslösen. Die Fehlerwirkung müsste
Codeausführung statt eines Absturzes liefern; der Code müsste Rockbox aus
einem Datenbereich nach RAM laden und an einen passenden Einstieg übergeben.
Ein nachträglicher manueller Exploit im bereits laufenden OS wäre dagegen noch
kein automatischer untethered Boot. Das signierte OSOS-/LLB-Image müsste dabei
unverändert bleiben.

Das passt auch zum veröffentlichten Stand von wInd3x: Der Projekt-README
beschreibt den N5G-Pfad als temporären DFU-Boot, der bis zum nächsten Neustart
gilt ([wInd3x](https://github.com/freemyipod/wInd3x)); der Exploit-Autor führte
das automatische Entkoppeln von der USB-Verbindung als offene Arbeit auf
([wInd3x-Artikel](https://q3k.org/wInd3x.html)). Das ist ein historischer
öffentlicher Stand und schließt neuere oder bislang unveröffentlichte
OSOS-Befunde nicht aus.

## Neue VTable-Prüfung

Ghidra lief mit `-noanalysis -readOnly` auf dem vorhandenen Runtime-Projekt
`/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.gpr` und dem Offline-Abbild
`/tmp/osos_runtime_dram_20261025.bin`.

- `FUN_082a8548` weist neu angelegten Objekten den VTable-Zeiger
  `0x084f71cc` zu. Der Eintrag bei `+0x24` zeigt auf `FUN_082b5508`.
- `FUN_082b5508` fügt ein Objekt in eine verkettete Liste ein, benachrichtigt
  bestehende Listener über virtuelle Methoden und sendet dabei zwei
  Benachrichtigungen. Das ist anhand des Codes ein Listener-/Observer-Container;
  ein ursprünglicher Klassenname ist nicht belegt.
- `FUN_081b115c` gibt den globalen Zeiger `0x087643e0` zurück und registriert
  beim ersten Zugriff zusätzlich ein über `FUN_082a8548` erzeugtes Hilfsobjekt
  mit einem Cleanup-Callback. `0x087643e0` liegt außerhalb des Offline-Abbilds
  (Ende `0x086c43a8`) im BSS. Die tatsächliche VTable dieses globalen Objekts
  und damit der Empfänger des MainApp-Handlers sind folglich weiter offen.
- Die gefundene VTable ist diejenige, die `FUN_082a8548` für das Hilfsobjekt
  verwendet. Sie darf nicht ohne weiteren Beleg mit der VTable des globalen
  Empfängers gleichgesetzt werden. Der Dispatcher-Empfänger für `0xa9000001`
  ist damit weiterhin nicht aufgelöst.

Rohbelege: `/tmp/OSOS_registry_vtable_followup_20261025.txt` und
`/tmp/OSOS_registry_vtable_refs_20261025.txt`.

## Stand der verwundbaren OSOS-Pfade

Die vorhandenen statischen Befunde reichen noch nicht für einen Installations-
oder Bootpfad:

- **Notes/Pfadverarbeitung:** Der UTF-8-Cursorfehler kann bei unvollständigem
  Mehrbytezeichen eine unterlaufene Länge an einen Kopierhelfer weiterreichen.
  Der Weg von einem präparierten Notes-Link zu diesem Helfer ist plausibel,
  aber die automatische Kaltstart-Auslösung, eine kontrollierte
  Kontrollflussübernahme und eine RCE sind nicht nachgewiesen.
- **ArtworkDB:** Der Link-Count führt zu einer zu kleinen Allokation bei
  anschließenden Schreibzugriffen. Eine Heap-Korruption ist statisch belegt;
  kontrollierter PC/LR, RCE und ein automatisch erreichter Kaltstartpfad sind
  nicht belegt.
- **Task-Argumentparser:** Es gibt einen statischen Stackschreibfehler, doch
  die bisher gefundenen Tasknamen sind kurze, fest eingebettete Werte. Ein
  nutzerkontrollierter Eingabepfad fehlt.
- **Device Preferences:** Die bisher untersuchten Reads begrenzen die Länge;
  der konkrete Preferences-Pfad hat keinen bestätigten Überlauf und sein
  automatischer Startpfad ist nicht aufgelöst.

Das Rockbox-Binary und die RAM-Disk liegen bereits auf der FAT-Partition und
wurden früher lesend verifiziert. Der aktuelle Startloader wird jedoch über
wInd3x/U-Boot und USB nach SDRAM geladen. Für einen OSOS-Exploit fehlt noch ein
passender RAM-Handoff zu Rockbox. Eine Hold-Abfrage mit Rückkehr zum Apple-OS
müsste ebenfalls im späteren Exploit-/Loaderpfad erhalten bleiben.

## Nächste Schritte

1. Die BSS-/Overlay-Initialisierung des globalen Objekts `0x087643e0` und den
   konkreten Empfänger von `0xa9000001` weiter zuordnen.
2. Für Notes und ArtworkDB jeweils den automatischen Start-/Resume-Auslöser
   und die persistent kontrollierbare Datei bis zum Parser nachweisen oder
   ausschließen.
3. Den Heap-/Stringfehler nur dann weiter als Exploitpfad bewerten, wenn ein
   realistischer automatischer Trigger und eine belastbare
   Kontrollflusswirkung gefunden werden.
4. Anschließend einen RAM-Handoff von OSOS zu den bereits installierten
   Rockbox-Dateien konzeptionell und offline gegen die vorhandenen Loader
   prüfen. Keine NAND-/NOR-Schreibmethode ist dafür derzeit nachgewiesen.
