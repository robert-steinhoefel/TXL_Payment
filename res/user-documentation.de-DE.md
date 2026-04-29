# TXL Payment – Anwenderdokumentation

## Überblick

Die TXL-Payment-Erweiterung ergänzt Microsoft Dynamics 365 Business Central um eine kameralistische Zahlungsabwicklung. Statt Zahlungen nur auf Belegkopfebene zu erfassen, wird jede Zahlung bis auf die einzelne Rechnungs- oder Gutschriftzeile heruntergebrochen. Finance-Teams erhalten damit eine genaue, zeilenweise Übersicht darüber, was wann und durch welche Bankbuchung beglichen wurde – ohne die Standard-Anwendungslogik von Business Central zu ersetzen.

> **Aktueller Umfang:** Diese Erweiterung deckt ausschließlich den **Verkaufsbereich (Debitoren)** ab. Verrechnungsposten werden für gebuchte Verkaufsrechnungen und Verkaufsgutschriften erstellt.

Die Erweiterung fügt zwei zentrale Seiten hinzu:

- **Verrechnungsposten** – ein dauerhaftes, schreibgeschütztes Prüfprotokoll jedes Zahlungszuordnungsvorgangs
- **Manuelle Zahlungszuordnung** – ein modaler Dialog, der bei Teilzahlungen erscheint und eine manuelle Verteilung auf die Zeilen ermöglicht

---

## Verrechnungsposten

### Was die Seite zeigt

Die Seite Verrechnungsposten listet alle von der Erweiterung erstellten Verrechnungsdatensätze auf. Jede Zeile steht für die Zuordnung einer Zahlung (oder Gutschriftsanwendung oder Stornierung) auf eine einzelne Zeile einer gebuchten Verkaufsrechnung oder Verkaufsgutschrift. In der aktuellen Version erscheinen hier ausschließlich Belege aus dem Verkaufsbereich.

**Standardmäßig sichtbare Spalten:**

| Spalte                           | Beschreibung                                                                                                                                                            |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Verrechnungstyp                  | *Normal*, *Nicht Zugeordnet* (Überzahlungsrest) oder *Storno*                                                                                                           |
| Transaktionsart                  | *Verkauf* oder *Einkauf* – welche Seite des Hauptbuchs betroffen ist. In der aktuellen Version werden ausschließlich Posten mit der Transaktionsart *Verkauf* erstellt. |
| Belegart                         | *Rechnung* oder *Gutschrift*                                                                                                                                            |
| Belegnr.                         | Nummer der gebuchten Rechnung oder Gutschrift                                                                                                                           |
| Debitor/Kreditor Nr.             | Debitor zum Zeitpunkt der Verrechnung                                                                                                                                   |
| Debitor/Kreditor Name            | Snapshot des Debitorennamens zum Verrechnungszeitpunkt                                                                                                                  |
| Verrechnungsdatum                | Buchungsdatum der Zahlung, die die Verrechnung ausgelöst hat                                                                                                            |
| Verrechnungsbetrag               | Auf diese Zeile abgerechneter Nettobetrag *ohne* MwSt.                                                                                                                  |
| Urspr. Zeilenbetrag              | Snapshot des Rechnungszeilenbetrags (ohne MwSt.) zum Verrechnungszeitpunkt                                                                                              |
| Urspr. Zeilenbetrag inkl. MwSt.  | Snapshot des Rechnungszeilenbetrags *mit* MwSt.                                                                                                                         |
| Nicht abzugsfähiger MwSt.-Betrag | Nicht abzugsfähiger MwSt.-Anteil dieser Zeile zum Verrechnungszeitpunkt                                                                                                 |
| Stornoposten                     | Markiert, wenn dieser Posten einen früheren Verrechnungsposten storniert                                                                                                |
| Storniert                        | Markiert, wenn dieser Originalposten bereits storniert wurde                                                                                                            |
| Kontoauszug Belegnr.             | Verweis auf den Kontoauszugsbeleg, über den die Zahlung eingegangen ist                                                                                                 |
| Beschreibung                     | Freitext-Beschreibung der Verrechnung                                                                                                                                   |

Weitere Spalten (standardmäßig ausgeblendet, können über *Spalten auswählen* eingeblendet werden):

| Spalte                         | Beschreibung                                                                                                                             |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Zuordnungs-ID                  | Fasst alle Verrechnungsposten desselben Zahlungsvorgangs zusammen. Format: `{Debitor Nr.}-{JJMMTT}-{LfdNr.}`, z. B. `CUST001-260312-001` |
| Verrechnungsbetrag inkl. MwSt. | Abgerechneter Betrag inklusive MwSt.                                                                                                     |
| Skontobetrag                   | Gewährtes Skonto auf dieser Verrechnung (ohne MwSt.)                                                                                     |
| Skontobetrag inkl. MwSt.       | Gewährtes Skonto inklusive MwSt.                                                                                                         |
| Zeile vollständig verrechnet   | Zeigt an, dass diese Rechnungszeile vollständig bezahlt wurde                                                                            |
| Beleg vollständig verrechnet   | Zeigt an, dass alle Zeilen des Belegs vollständig bezahlt wurden                                                                         |
| Sachkontonr. / Sachkontoname   | Erlös- oder Aufwandskonto aus der Rechnungszeile                                                                                         |
| Fördermittel Bescheidnr.       | Förderreferenz für die öffentliche Fördermittelbuchhaltung                                                                               |
| Erstellt von / Erstellt am     | Prüfinformation zu Ersteller und Zeitpunkt                                                                                               |

---

### Wie Verrechnungsposten entstehen

Verrechnungsposten werden von der Erweiterung automatisch erstellt, sobald Business Central eine Zahlung gegen eine Rechnung ausgleicht. Sie werden nicht manuell angelegt. Es gibt drei Szenarien:

#### Vollständige Verrechnung

Wenn eine Zahlung eine Rechnung genau ausgleicht (oder geringfügig überzahlt), sodass die Rechnung vollständig geschlossen wird, verteilt die Erweiterung die Zahlung proportional auf alle Rechnungszeilen. Pro Zeile wird ein Verrechnungsposten geschrieben.

*Proportionale Verteilung* bedeutet: Jede Zeile erhält einen Anteil der Gesamtzahlung, der ihrem Anteil am Gesamtrechnungsbetrag entspricht. Die letzte Zeile nimmt etwaige Rundungsdifferenzen auf.

Wurde die Rechnung mit **Skonto** geschlossen, wird der Skontobetrag in den Skonto-Feldern des jeweiligen Verrechnungspostens erfasst. Skonto wird nur dann befüllt, wenn eine einzige Zahlung die Rechnung schließt; bei mehreren Teilzahlungen kann das Skonto keiner einzelnen Zahlung eindeutig zugeordnet werden und bleibt daher leer.

#### Teilzahlung

Wenn eine Zahlung nur einen Teil einer Rechnung abdeckt (die Rechnung bleibt nach der Buchung offen), öffnet die Erweiterung die **Manuelle Zahlungszuordnung** unmittelbar vor der Buchung. Weitere Details finden Sie im gleichnamigen Abschnitt weiter unten. Nach Bestätigung der Zuordnung wird pro zugeordneter Zeile ein Verrechnungsposten erstellt.

#### Gutschriftsanwendung

Wenn eine Gutschrift gegen eine Rechnung ausgeglichen wird, behandelt die Erweiterung diesen Vorgang wie eine Zahlung: Für jede durch die Gutschrift gedeckte Rechnungszeile werden Verrechnungsposten erstellt, die die Reduzierung des offenen Saldos widerspiegeln.

#### Überzahlung (Nicht zugeordneter Posten)

Wenn eine Zahlung den Gesamtrechnungsbetrag übersteigt, wird der Überschuss als **Nicht zugeordneter** Verrechnungsposten erfasst. Dieser Posten hat keine Belegnummer – die leere Belegnummer in der Liste ist das visuelle Erkennungszeichen dafür, dass dieser Betrag noch keiner konkreten Zeile zugeordnet wurde. Der Posten teilt dieselbe Zuordnungs-ID wie die übrigen Verrechnungsposten dieses Zahlungsvorgangs und kann bei einer späteren Anwendung verbraucht werden.

#### Storno (Ausgleichsaufhebung)

Wenn ein Zahlungsausgleich in Business Central rückgängig gemacht wird (über *Debitorenposten ausgleichen aufheben*), erstellt die Erweiterung automatisch für jeden betroffenen Originalposten einen Storno-Verrechnungsposten. Stornoposten tragen das umgekehrte Vorzeichen der Originale, sodass die Summe aller Posten einer Belegzeile stets den korrekten offenen Nettosaldo ergibt. Die Originalposten werden mit `Storniert = Ja` markiert, die Stornoposten mit `Stornoposten = Ja`. Beide bleiben dauerhaft in der Liste erhalten; Posten werden niemals gelöscht.

---

### Die Verrechnungspostenliste lesen

Einige praktische Hinweise beim Lesen der Liste:

- **Zeilen ohne Belegnummer** sind Nicht zugeordnete Posten (Überzahlungsüberschuss). Sie sind normal und zu erwarten, wenn ein Kunde etwas mehr als den Rechnungsbetrag überweist.
- **Negative Beträge** sind Stornoposten. Sie heben die positiven Beträge der ursprünglichen Verrechnung auf. Das Netto aller Posten einer Belegzeile ergibt die aktuelle offene Saldoreduzierung.
- **Mehrere Posten zur selben Rechnung** sind normal. Pro Rechnungszeile erscheint eine Zeile, und für jede Folge-Teilzahlung kommen weitere Zeilen hinzu.
- Die **Zuordnungs-ID** verbindet alle Posten eines Zahlungsvorgangs. Filtern oder gruppieren Sie nach dieser Spalte, um alle von einer einzelnen Überweisung betroffenen Zeilen zu sehen.

---

## Manuelle Zahlungszuordnung

### Wann sie erscheint

Die Manuelle Zahlungszuordnung öffnet sich automatisch – als modaler Dialog – unmittelbar bevor eine Teilzahlung gebucht wird. Das System erkennt, dass der Zahlungsbetrag unter dem offenen Restbetrag der Rechnung liegt, und unterbricht die Buchung, um zu fragen, wie die Zahlung auf die einzelnen Rechnungszeilen verteilt werden soll.

Dies geschieht an zwei Stellen:

- Beim Buchen eines **Buchungsblatts**, das eine auf eine Verkaufsrechnung angewendete Zahlung enthält
- Beim Verwenden von **Debitorenposten ausgleichen**, um eine gebuchte Zahlung manuell gegen eine gebuchte Verkaufsrechnung auszugleichen

Wird die Seite abgebrochen, wird die gesamte Zahlungsbuchung zurückgerollt. Es wird nichts gebucht, bis eine gültige Zuordnung bestätigt wurde.

### Aufbau der Seite

**Kopfbereich:**

| Feld                      | Beschreibung                                                                                       |
| ------------------------- | -------------------------------------------------------------------------------------------------- |
| Debitor Nr.               | Debitor, zu dem die Rechnung gehört                                                                |
| Debitor Name              | Name des Debitors                                                                                  |
| Belegnr.                  | Die teilweise bezahlte Rechnung                                                                    |
| Zahlbetrag                | Der Gesamtbetrag der eingehenden Zahlung inklusive MwSt.                                           |
| Gesamtbetrag              | Laufende Summe der bisher auf Zeilen zugeordneten Beträge                                          |
| Noch zuzuordnender Betrag | Differenz zwischen Zahlbetrag und Gesamtbetrag – muss auf null sinken, bevor bestätigt werden kann |

**Zeilenbereich (eine Zeile pro Rechnungszeile):**

| Spalte                       | Beschreibung                                                                                                               |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Zeilennr.                    | Zeilennummer aus der Originalrechnung                                                                                      |
| Beschreibung                 | Beschreibung aus der Rechnungszeile                                                                                        |
| Sachkonto Nr.                | Erlöskonto der Zeile                                                                                                       |
| Urspr. Betrag                | Rechnungszeilenbetrag ohne MwSt.                                                                                           |
| Urspr. Betrag inkl. MwSt.    | Rechnungszeilenbetrag mit MwSt.                                                                                            |
| Bereits verrechnet           | Aus früheren Teilzahlungen bereits bezahlter Betrag dieser Zeile (bei erster Zahlung null)                                 |
| Zuordnungsbetrag inkl. MwSt. | **Das Eingabefeld.** Tragen Sie hier ein, wie viel dieser Zahlung auf diese Zeile angerechnet werden soll, inklusive MwSt. |

### Manuelle Zuordnung eingeben

1. Prüfen Sie die Spalten **Urspr. Betrag inkl. MwSt.** und **Bereits verrechnet**, um den noch offenen Betrag pro Zeile zu verstehen.
2. Tragen Sie in der Spalte **Zuordnungsbetrag inkl. MwSt.** ein, wie viel von dieser Zahlung auf jede Zeile entfallen soll.
3. Beobachten Sie das Feld **Noch zuzuordnender Betrag** im Kopfbereich. Es muss exakt null erreichen (oder innerhalb der Rundungstoleranz), bevor Sie bestätigen können.
4. Wählen Sie **Zuordnung anwenden**, um zu bestätigen und mit der Buchung fortzufahren.

Das System berechnet intern den Nettobetrag (ohne MwSt.) aus dem von Ihnen eingegebenen Bruttobetrag anhand des MwSt.-Satzes der Originalrechnungszeile.

### Proportional verteilen

Wenn Sie nicht manuell zuordnen möchten, wählen Sie **Proportional verteilen**. Das System berechnet den verbleibenden offenen Saldo pro Zeile (Urspr. Betrag minus bereits verrechnet) und verteilt die Zahlung in denselben Verhältnissen. Die letzte Zeile nimmt etwaige Rundungsdifferenzen auf. Sie können diese Verteilung als Ausgangspunkt nutzen und anschließend einzelne Zeilen vor der Bestätigung noch anpassen.

### Abbrechen

Das Wählen von **Abbrechen** verwirft alle eingegebenen Beträge und rollt die gesamte Zahlungsanwendung zurück. Die Buchungsblattszeile oder die manuelle Ausgleichsbuchung wird verworfen; es wird nichts gebucht. Sie können anschließend zum Buchungsblatt oder zur Ausgleichsseite zurückkehren, die Beträge korrigieren und es erneut versuchen.

---

## Statusindikatoren auf Rechnungszeilen

Die Erweiterung fügt einen Zahlungsstatus-Indikator zu gebuchten Verkaufsrechnungszeilen hinzu. Der Status wird dynamisch aus den Netto-Verrechnungsbeträgen abgeleitet:

| Status        | Bedeutung                                                                                           |
| ------------- | --------------------------------------------------------------------------------------------------- |
| **Offen**     | Keine Verrechnungsposten vorhanden, oder alle Verrechnungen wurden storniert                        |
| **Teilweise** | Verrechnungsposten vorhanden, aber der offene Saldo wurde noch nicht auf null reduziert             |
| **Bezahlt**   | Die Summe aller Verrechnungsbeträge entspricht dem Zeilenbetrag (innerhalb einer Toleranz von 0,01) |

Der Status wird farblich angezeigt: grün für *Bezahlt*, gelb für *Teilweise*, kein Farbton für *Offen*.

Das Feld **Ausstehender Betrag** auf jeder Rechnungszeile zeigt den verbleibenden numerischen Saldo, berechnet als: *Ursprünglicher Zeilenbetrag – Gesamter Netto-Verrechnungsbetrag*.

---

## Zuordnungs-ID

Jedem Zahlungsvorgang wird eine eindeutige **Zuordnungs-ID** im Format `{Debitor Nr.}-{JJMMTT}-{LfdNr.}` zugewiesen, z. B. `CUST001-260312-001`. Alle durch eine einzige Zahlung erstellten Verrechnungsposten – ob über mehrere Rechnungszeilen oder einschließlich eines Nicht zugeordneten Postens – teilen dieselbe Zuordnungs-ID.

Verwenden Sie die Zuordnungs-ID, um:

- Alle Verrechnungszeilen einer Banküberweisung zu gruppieren
- In den Power-BI-Berichten nachzuvollziehen, welche Rechnungszeilen durch eine bestimmte Zahlung gedeckt wurden
- Zu verstehen, ob ein Nicht zugeordneter Posten zur selben Banküberweisung wie eine Gruppe normaler Verrechnungen gehört

---

## Häufig gestellte Fragen

**Warum zeigt eine Rechnungszeile „Teilweise", obwohl ich eine vollständige Zahlung eingegeben habe?**
Das System berechnet den Status aus dem Netto aller Verrechnungsposten, einschließlich Stornierungen. Wenn eine frühere Verrechnung storniert wurde, ist der Nettosaldo niedriger als erwartet. Prüfen Sie die Verrechnungspostenliste gefiltert nach der Rechnungsnummer, um alle Posten und Stornierungen zu sehen.

**Kann ich Verrechnungsposten bearbeiten?**
Nein. Verrechnungsposten sind ein unveränderliches Prüfprotokoll. Bei einem fehlerhaften Posten muss die Zahlungsanwendung in Business Central über die Standard-Ausgleichsaufhebungsfunktion rückgängig gemacht werden. Die Erweiterung erstellt dann automatisch die entsprechenden Storno-Verrechnungsposten.

**Warum ist die Kontoauszug Belegnr. bei manchen Posten leer?**
Dieses Feld wird nur befüllt, wenn das System die Zahlung zum Zeitpunkt der Verrechnungspostenerstellung auf einen konkreten Bankbuchhaltungsposten zurückverfolgen kann. Wird eine Verrechnung über eine manuelle Ausgleichsbuchung erstellt, die nicht direkt mit einer Bankbuchung verknüpft ist, kann das Feld leer bleiben.

**Was passiert, wenn ich die Manuelle Zahlungszuordnung schließe, ohne alle Beträge zuzuordnen?**
Die Aktion **Zuordnung anwenden** ist nur aktiv, wenn das Feld **Noch zuzuordnender Betrag** null erreicht. Wenn Sie stattdessen auf **Abbrechen** klicken, wird die Buchung vollständig zurückgerollt.

**Können zwei Zahlungen im selben Buchungsblatt-Stapel zugeordnet werden?**
Ja. Die Manuelle Zahlungszuordnung öffnet sich einmal für jede im Stapel erkannte Teilanwendung. Jede muss einzeln bestätigt werden, bevor die Buchung fortgesetzt wird.
