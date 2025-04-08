# Testfälle und Ergebnisse der Kameralistik Erweiterung
Dieses Dokument ist nur in deutscher Sprache verfügbar

1. [Ausgleiche über beleghafte Kreditoren- und Debitorenposten](#ausgleiche-über-beleghafte-kreditoren--und-debitorenposten)
   1. [Ausgleich eines Kreditoren-Rechnungspostens mit einer Zahlung](#ausgleich-eines-kreditoren-rechnungspostens-mit-einer-zahlung)
   2. [Ausgleich eines Kreditoren-Zahlungsposten mit einer Rechnung](#ausgleich-eines-kreditoren-zahlungsposten-mit-einer-rechnung)
   3. [Ausgleich eines Kreditoren-Gutschriftspostens mit einer Erstattung](#ausgleich-eines-kreditoren-gutschriftspostens-mit-einer-erstattung)
   4. [Ausgleich eines Kreditoren-Erstattungsposten mit einer Gutschrift](#ausgleich-eines-kreditoren-erstattungsposten-mit-einer-gutschrift)
   5. [Ausgleich eines Debitoren-Rechnungspostens mit einer Zahlung](#ausgleich-eines-debitoren-rechnungspostens-mit-einer-zahlung)
   6. [Ausgleich eines Debitoren-Zahlungsposten mit einer Rechnung](#ausgleich-eines-debitoren-zahlungsposten-mit-einer-rechnung)
   7. [Ausgleich eines Debitoren-Gutschriftspostens mit einer Erstattung](#ausgleich-eines-debitoren-gutschriftspostens-mit-einer-erstattung)
   8. [Ausgleich eines Debitoren-Erstattungsposten mit einer Gutschrift](#ausgleich-eines-debitoren-erstattungsposten-mit-einer-gutschrift)
2. [Ausgleiche von und über Buch.-Blatt Buchungen](#ausgleiche-von-und-über-buch-blatt-buchungen)
   1. [Erfassen einer Kreditorzahlung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Rechnung](#erfassen-einer-kreditorzahlung-im-buch-blatt-mit-direktem-ausgleich-der-zugehörigen-rechnung)
   2. [Erfassen einer Kreditorerstattung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Gutschrift](#erfassen-einer-kreditorerstattung-im-buch-blatt-mit-direktem-ausgleich-der-zugehörigen-gutschrift)
   3. [Erfassen einer Debitorzahlung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Rechnung](#erfassen-einer-debitorzahlung-im-buch-blatt-mit-direktem-ausgleich-der-zugehörigen-rechnung)
   4. [Erfassen einer Debitorerstattung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Gutschrift](#erfassen-einer-debitorerstattung-im-buch-blatt-mit-direktem-ausgleich-der-zugehörigen-gutschrift)
3. [Aufheben eines Zahlungsausgleiches](#aufheben-eines-zahlungsausgleiches)
4. [Bankposten Abfrage](#bankposten-abfrage)


## Ausgleiche über beleghafte Kreditoren- und Debitorenposten

### Ausgleich eines Kreditoren-Rechnungspostens mit einer Zahlung

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Zahlungsposten zum Ausgleich muss auf dem Kreditor bereits vorhanden sein)

- Kreditoren mit offenem Rechnungsposten aufrufen und in die Postenliste gehen
- Offenen Rechnungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Zahlungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Kreditorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Kreditoren-Zahlungsposten mit einer Rechnung

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Zahlungsposten zum Ausgleich muss auf dem Kreditor bereits vorhanden sein)

- Kreditoren mit offenem Rechnungsposten aufrufen und in die Postenliste gehen
- Zahlungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Rechnungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Kreditorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Kreditoren-Gutschriftspostens mit einer Erstattung

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Erstattungsposten zum Ausgleich muss auf dem Kreditor bereits vorhanden sein)

- Kreditoren mit offenem Gutschriftsposten aufrufen und in die Postenliste gehen
- Gutschriftsposten auswählen
- Menü: Start -> Posten ausgleichen
- Erstattungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Kreditorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Kreditoren-Erstattungsposten mit einer Gutschrift

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Erstattungsposten zum Ausgleich muss auf dem Kreditor bereits vorhanden sein)

- Kreditoren mit offenem Gutschriftsposten aufrufen und in die Postenliste gehen
- Erstattungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Gutschriftsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Kreditorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Debitoren-Rechnungspostens mit einer Zahlung

Erwartetes Ergebnis: Die Informationen aus dem Debitoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Zahlungsposten zum Ausgleich muss auf dem Debitor bereits vorhanden sein)

- Debitor mit offenem Rechnungsposten aufrufen und in die Postenliste gehen
- Offenen Rechnungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Zahlungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Debitorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Debitoren-Zahlungsposten mit einer Rechnung

Erwartetes Ergebnis: Die Informationen aus dem Debitoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Zahlungsposten zum Ausgleich muss auf dem Debitor bereits vorhanden sein)

- Debitor mit offenem Rechnungsposten aufrufen und in die Postenliste gehen
- Offenen Zahlungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Rechnungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Debitorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Debitoren-Gutschriftspostens mit einer Erstattung

Erwartetes Ergebnis: Die Informationen aus dem Debitoren Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Erstattungsposten zum Ausgleich muss auf dem Debitor bereits vorhanden sein)

- Debitor mit offenem Gutschriftsposten aufrufen und in die Postenliste gehen
- Gutschriftsposten auswählen
- Menü: Start -> Posten ausgleichen
- Erstattungsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Debitorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

### Ausgleich eines Debitoren-Erstattungsposten mit einer Gutschrift

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

(Erstattungsposten zum Ausgleich muss auf dem Debitor bereits vorhanden sein)

- Debitor mit offenem Gutschriftsposten aufrufen und in die Postenliste gehen
- Erstattungsposten auswählen
- Menü: Start -> Posten ausgleichen
- Gutschriftsposten auswählen, im Menü "Ausgleichs-ID setzen" wählen
- Menü: "Ausgleich buchen"
- Ergebnis prüfen: Debitorenposten, Sachposten, Bankposten

Ausgleich: bestanden
Ausgleich aufheben: bestanden

## Ausgleiche von und über Buch.-Blatt Buchungen
### Erfassen einer Kreditorzahlung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Rechnung

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

- Zahlungsposten in Buch Blatt erfassen
- In den Spalten "Ausgleich mit Belegart": Rechnung, "Ausgleich mit Belegnr." die entsprechende Rechnung auswählen.
- Buchen, Ergebnis prüfen

FiBu Buch.-Blatt: bestanden
FiBu Buch.-Blatt Ausgleich aufheben: bestanden
Erw. Zahlungseingangs Buch.-Blatt: bestanden
Erw. Zahlungseingangs Buch.-Blatt Ausgleich aufheben: bestanden

### Erfassen einer Kreditorerstattung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Gutschrift

Erwartetes Ergebnis: Die Informationen aus dem Kreditoren Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

- Erstattungsposten in Buch Blatt erfassen
- In den Spalten "Ausgleich mit Belegart": Gutschrift, "Ausgleich mit Belegnr." die entsprechende Gutschrift auswählen.
- Buchen, Ergebnis prüfen

FiBu Buch.-Blatt: bestanden
FiBu Buch.-Blatt Ausgleich aufheben: bestanden
Erw. Zahlungseingangs Buch.-Blatt: bestanden
Erw. Zahlungseingangs Buch.-Blatt Ausgleich aufheben: bestanden

### Erfassen einer Debitorzahlung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Rechnung

Erwartetes Ergebnis: Die Informationen aus dem Debitoren Rechnungsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Zahlung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Rechnungsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

- Zahlungsposten in Buch Blatt erfassen
- In den Spalten "Ausgleich mit Belegart": Rechnung, "Ausgleich mit Belegnr." die entsprechende Rechnung auswählen.
- Buchen, Ergebnis prüfen

FiBu Buch.-Blatt: bestanden
FiBu Buch.-Blatt Ausgleich aufheben: bestanden
Erw. Zahlungseingangs Buch.-Blatt: bestanden
Erw. Zahlungseingangs Buch.-Blatt Ausgleich aufheben: bestanden

### Erfassen einer Debitorerstattung im Buch.-Blatt mit direktem Ausgleich der zugehörigen Gutschrift

Erwartetes Ergebnis: Die Informationen aus dem Debitor Gutschriftsposten (externe Belegnummer, Fälligkeitsdatum, Belegtyp, globale Dim 1, globale Dim 2, Dim Set ID) werden in den Bankposten der Erstattung übernommen.

Aus dem Bankposten wird das Buchungsdatum und die Belegnummer in den Gutschriftsposten sowie die damit unmittelbar verknüpften Sachposten übernommen.

- Erstattungsposten in Buch Blatt erfassen
- In den Spalten "Ausgleich mit Belegart": Gutschrift, "Ausgleich mit Belegnr." die entsprechende Gutschrift auswählen.
- Buchen, Ergebnis prüfen

FiBu Buch.-Blatt: bestanden
FiBu Buch.-Blatt Ausgleich aufheben: bestanden
Erw. Zahlungseingangs Buch.-Blatt: bestanden
Erw. Zahlungseingangs Buch.-Blatt Ausgleich aufheben: bestanden

## Aufheben eines Zahlungsausgleiches

Erwartetes Ergebnis: Bei jeder Aufhebung eines Ausgleiches zwischen Zahlung und Rechnung oder Erstattung und Gutschrift, werden die betroffenen Informationen wieder entfernt. Im Rechnungs- (Gutschrifts-) Posten sowie den unmittelbar verknüpften Sachposten werden Bank-Buchungsdatum, Bank-Belegnummer und das Kennzeichen "bezahlt" wieder entfernt, das Kennzeichen "Zahlung storniert" hingegen gesetzt. Aus dem mit der Zahlung (Erstattung) verknüpften Bankposten werden der Belegtyp, Beleg-Fälligkeitsdatum, Belegnummer(n) und Postentyp sowie die Dimensionsinformationen zum Rechnungs-/Gutschriftsposten entfernt.

## Bankposten Abfrage

Erwartetes Ergebnis: Die Abfrage (Query) listet alle Bankposten, unabhängig von Buchungsdatum, Bankkonto oder Ausgleichsstatus auf (sie kann über Parameter in der externen Abfrage eingeschränkt werden). Dabei werden die Informationen aus den Ausgleichen zwischen Rechnungen und Zahlungen mit aufgelistet sowie die zugehörigen Dimensionswerte.

Ergebnis: bestanden