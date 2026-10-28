# Persistente Speakable-Belege

Die Abfragen, Scannergebnisse und Skripte dieser Runde liegen vollständig
unter diesem Verzeichnis im Repository. Auf dem aktuellen Rechner liegt es
auf `/dev/nvme0n1p8` (`ext4`, schreibbar) und bleibt nach einem Neustart
erhalten. Es wurde für diese Beleggruppe kein Arbeitsverzeichnis in `/tmp`
verwendet.

Der Hauptbericht ist
`../../OSOS-Speakable-startup-plist-readers-followup-2026-10-28.md`.
Das SHA-256-Manifest `SHA256SUMS` umfasst alle Dateien in diesem Verzeichnis
außer sich selbst sowie den Hauptbericht. Vom Repository-Wurzelverzeichnis
lässt es sich mit folgendem Befehl prüfen:

```sh
sha256sum -c utils/ipodnano5g/analysis/evidence/speakable-2026-10-28/SHA256SUMS
```

Die lokale Ghidra-Datenbank liegt außerhalb des Git-Repositories unter
`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/`.
Das Eingabeabbild liegt unter
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`
und hat SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

`OSOS_speakable_factory_registry_mainapp_loop_followup_20261028.log` ist nur
eine Warnnotiz. Die fehlerhafte, zu große Sammelausgabe ist daneben
komprimiert archiviert; die verifizierbaren Ergebnisse stehen in den
gezielten Folgeabfragen.
