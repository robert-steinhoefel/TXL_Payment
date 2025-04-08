# P3 TXL Payment Extension: Kameralistik

## Management Summary

Bei dieser Applikation handelt es sich um eine individuelle Anpassung an Microsoft Dynamics Business Central 365. Sie verknüpft Zahlungsinformationen mit den zugehörigen Rechnungsinformationen und ermöglicht so eine buchhalterische Auswertung nach kameralistischen Gesichtspunkten.

Um dies technisch zu ermöglichen, werden einige Postentabellen um individuelle Spalten ergänzt, die während des Zahlungsausgleichsvorgangs gefüllt werden. Zusätzlich ist eine eigene Abfrage implementiert, die den Abruf der Zahlungsposten ergänzt um die Rechnungsinformationen über eine REST-API ermöglich.

1. [Management Summary](#management-summary)
2. [Implementierte Objekte](#implementierte-objekte)
   1. [Objektübersicht](#objektübersicht)
   2. [Source Ledger Entry Type (Enum)](#source-ledger-entry-type-enum)
   3. [P3.PMT-ALL (Permission Set)](#p3pmt-all-permission-set)
   4. [Installation (Codeunit)](#installation-codeunit)
   5. [Update Codeunit (Codeunit)](#update-codeunit-codeunit)
   6. [Event Subscriber (Codeunit)](#event-subscriber-codeunit)
   7. [Customer Ledger Entries / Vendor Ledger Entries (Codeunit)](#customer-ledger-entries--vendor-ledger-entries-codeunit)
   8. [Bank Account Ledger Entries (Codeunit)](#bank-account-ledger-entries-codeunit)
      1. [Debitoren-/Kreditorenposten](#debitoren-kreditorenposten)
      2. [Sachposten](#sachposten)
   9. [Tabellenerweiterungen](#tabellenerweiterungen)
      1. [Bank Acc. Ledger Entry (Bankposten)](#bank-acc-ledger-entry-bankposten)
      2. [Cust. Ledger Entry (Debitorenposten)](#cust-ledger-entry-debitorenposten)
      3. [Vendor Ledger Entry (Kreditorenposten)](#vendor-ledger-entry-kreditorenposten)
      4. [G/L Entry (Sachposten)](#gl-entry-sachposten)
      5. [Dimension Set Entry (Dimensionssatzposten)](#dimension-set-entry-dimensionssatzposten)
   10. [Bank Account Ledger Entries (Abfrage)](#bank-account-ledger-entries-abfrage)
       1. [API-Felder](#api-felder)

## Implementierte Objekte

Die im Folgenden genannten Objekte wurden im Rahmen dieser Erweiterung hinzugefügt.

### Objektübersicht

| Objekttyp       | Erste ID | Letzte ID |
| --------------- | -------- | --------- |
| table           | N/A      | N/A       |
| table extension | 51100    | 51105     |
| Page            | N/A      | N/A       |
| Page extension  | 51100    | 51103     |
| Enum            | 51100    | 51100     |
| Query           | 51100    | 51100     |
| Codeunit        | 51100    | 51105     |

### Source Ledger Entry Type (Enum)

| Schlüssel | Wert        | Beschreibung |
| --------- | ----------- | ------------ |
| 0         | " "         | ' '          |
| 1         | Customer    | Customer     |
| 2         | Vendor      | Vendor       |
| 3         | G/L Account | G/L Account  |

### P3.PMT-ALL (Permission Set)

Der Berechtigungssatz enthält alle Berechtigungen, um die Funktionalitäten der Erweiterung uneingeschränkt nutzen zu können.

### Installation (Codeunit)

Diese Codeunit wird automatisch bei der Installation der Erweiterung ausgeführt.
Sie fügt der Tabelle "Tenant Web Service" einen Eintrag für die Abfrage der Bankposten hinzu und veröffentlicht diese. Der Webdienst trägt die Bezeichnung `CameralisticBankAccountLedgerEntries`.

### Update Codeunit (Codeunit)

Diese Codeunit wird automatisch beim Aktualisieren der Erweiterung ausgeführt. Sie hat derzeit keinen Inhalt und wird nicht verwendet. 

### Event Subscriber (Codeunit)

Diese Codeunit abonniert systeminterne Events und ruft daraufhin bestimmte Funktionen auf.

In der Erweiterung sind drei Ereignisse abonniert:
- `OnAfterInsertEvent` der Tabelle `Detailed Vendor Ledg. Entry`
- `OnAfterInsertEvent` der Tabelle `Detailed Cust. Ledg. Entry`
- `OnAfterInsertEvent` der Tabelle `G/L Entry`

Diese Events der detaillierten Kreditoren-/Debitorenposten werden immer dann ausgelöst, wenn ein neuer detaillierter Kreditorenposten oder detaillierter Debitorenposten im System erstellt werden.

Diese beiden Events rufen eine nahezu identische Prozedur auf. Es wird geprüft, ob der Eintrag, der dieses Event auslöst
- ein temporärer Datensatz ist,
- nicht dem Eintragstyp "Ausgleich" entspricht,
- als Ursprungsbelegart "Zahlung" oder "Erstattung" hat.
Trifft keine dieser drei Bedingungen zu, wird eine Codeunit aufgerufen, welche anhand des detaillierten Kreditoren-/Debitorenposten die Kernfunktionalität der Erweiterung ausführt. Bei den aufgerufenen Codeunit handelt es sich um die unten genannten [[#Customer Ledger Entries / Vendor Ledger Entries (Codeunit)]].

Über die Einschränkung ist sichergestellt dass nur beim Buchen eines Postenausgleichs oder einer Ausgleichs-Aufhebung (und nicht schon beim Buchen einer Rechnung oder Zahlung) die Folge-Codeunit aufgerufen wird.

Das **dritte Event** wird immer dann ausgelöst, wenn ein neuer Sachposten erzeugt wird. In der getriggerten Methode wird geprüft ob dieses Event von einem Posten ausgelöst wird, der
- ein temporärer Datensatz ist,
- dessen Gegenkonto kein Bankkonto ist.
Trifft keine dieser beiden Bedingungen zu, wird der zugehörigen Bankposten identifiziert. Zusammen mit dem Sachposten wird dieser direkt an die [[#Bank Account Ledger Entries (Codeunit)]] (siehe Abschnitt [[#Sachposten]]) übergeben, um beide Posten dort weiter zu verarbeiten.
### Customer Ledger Entries / Vendor Ledger Entries (Codeunit)

Die diese beiden Codeunits identisch ablaufen, werden sie unter ein und demselben Abschnitt erläutert. Im folgenden wird bei der Wortwahl jedoch nur der Debitor (Customer) genannt. Dies ist mit dem Begriff "Kreditor" für den wechselseitigen Fall gleich zu setzen. Die Codeunits ermitteln im Falle einer Ausgleichsbuchung oder beim Buchen einer Ausgleichs-Aufhebung die zu bearbeitenden Rechnungs-/Gutschriftsposten, Sachposten und Bankposten.

Anhand des detaillierten Debitorenpostens, der vom [[#Event Subscriber (Codeunit)]] an die Codeunit übergeben wird, werden der detaillierte Debitorenposten und Debitorenposten ermittelt, die den Zahlungsposten definieren. Mit Hilfe dieses Zahlungspostens wird der zugehörige Bankposten identifiziert.

Der Debitorenposten der *Rechnung* bzw. Gutschrift sowie die zu diesem Debitorenposten zugehörigen Sachposten werden mit den Informationen aus dem Bankposten und dem Zahlungsposten aktualisiert:
- Es wird das Kennzeichen "bezahlt" gesetzt,
- das Buchungsdatum des Bankpostens wird als Bankbuchungsdatum eingetragen,
- die Belegnummer (i.d.R. Kontoauszugnummer) des Bankpostens wird als Bank Belegnr. eingetragen,
- zusätzlich wird in den Sachposten das Fälligkeitsdatum der Rechnung bzw. Gutschrift eingetragen.

Zum Abschluss wird der ermittelte Bankposten zusammen mit dem Rechnungsposten an die [[#Bank Account Ledger Entries (Codeunit)]] übergeben, um den Bankposten mit den entsprechenden Informationen zu aktualisieren.

Im Falle der Aufhebung eines Postenausgleiches werden sämtliche oben genannten Informationen aus diesen Posten wieder entfernt. Zusätzlich wird dann das Kennzeichen "Zahlungsausgleich aufgehoben" gesetzt. So soll nachvollziehbar bleiben, weshalb es zu Verschiebungen in den kameralistischen Auswertungen kommt.

### Bank Account Ledger Entries (Codeunit)

Diese Codeunit überträgt die Informationen aus einem mit einer Zahlung bzw. Erstattung ausgeglichenen Rechnungs- bzw. Gutschriftsposten in den zugehörigen Bankposten. Sie wird ausschließlich über die [[#Customer Ledger Entries / Vendor Ledger Entries (Codeunit)]] Codeunits aufgerufen.
Die Codeunit wirft einen Fehler aus, wenn versucht wird ein 

#### Debitoren-/Kreditorenposten
Auch hier werden Debitoren- und Kreditorenposten identisch behandelt, weshalb im Folgenden nur die Debitorenposten namentlich erwähnt sind.

Zunächst wird geprüft, ob im Bankposten als Debitor/Kreditor Belegnummer bereits die Rechnungs- oder Gutschriftsnummer des Debitorenposten vorhanden ist. Falls dem so ist, wird die Ausführung für diesen Datensatz beendet.
Ist bereits eine andere Rechnungs- oder Gutschriftsnummer im Bankposten eingetragen, so wird die Nummer aus dem aktuellen Datensatz mit einem Pipe-Zeichen (`|`) getrennt angehängt. Liegt das Fälligkeitsdatum des neuen Postens zeitlich *nach* dem bereits vorhandem Debitoren-/Kreditoren Fälligkeitsdatum, wird es überschrieben. Anderenfalls bleibt es bestehen. Es wird also immer das zeitlich spätere Fälligkeitsdatum eingetragen.
Ist die Gesamtlänge der Debitor/Kreditor Belegnummer-Zeichenkette länger als 20 Zeichen, so werden die überzählige Zeichen rechts abgeschnitten.

Dann wird aus dem Debitorenposten in die entsprechenden Felder des Bankposten übernommen:
- das Fälligkeitsdatum,
- der Postentyp (Debitor, Kreditor oder Sachposten)
- die Belegart (Rechnung oder Gutschrift)
- der globale Dimension 1 Code
- der globale Dimension 2 Code
- die Dimensionssatzposten-ID

#### Sachposten
Wir ein Bankposten direkt auf ein Sachkonto gebucht, so werden die Informationen aus dem Sachposten analog der Debitoren-/kreditorenposten in den Bankposten übertragen. Dabei gibt es folgende Abweichungen:
- Da ein Sachposten kein Fälligkeitsdatum hat, wird sowohl im Sachposten als auch im Bankposten das Debitor-/Kreditorposten Fälligkeitsdatum nicht gesetzt und verbleibt leer.

Wird eine Banktransaktion, die direkt auf ein Sachkonto gebucht wurde, mit der Funktion aus den BC-Standard "Transaktion stornieren" storniert, so werden alle gesetzten Informationen wieder entfernt. Zusätzlich wird bei *allen* betroffenen Posten - das bedeutet: sowohl die ursprünglichen als auch die Korrekturposten - das Kennzeichen "Zahlungsausgleich aufgehoben" gesetzt.
### Tabellenerweiterungen

Die folgenden Erweiterungen an Tabellen wurden implementiert. Die zugehörigen Ansichten (Pages) wurden ebenfalls ergänzt, um die Tabellenspalten einblenden zu können.

#### Bank Acc. Ledger Entry (Bankposten)

| Feldnr. | Feldname                   | Feldtyp                                                                  |
| ------- | -------------------------- | ------------------------------------------------------------------------ |
| 51100   | Ledger Entry Type          | Enum "Source Ledger Entry Type"                                          |
| 51101   | CV Doc. No.                | Code[20]  <br>TableRelation, konditionell abhängig vom Ledger Entry Type |
| 51102   | CV Doc. Due Date           | Date                                                                     |
| 51103   | CV Doc Type                | Enum "Gen. Journal Document Type"                                        |
| 51104   | CV Global Dimension 1 Code | Code[20]  <br>TableRelation                                              |
| 51105   | CV Global Dimension 2 Code | Code[20]  <br>TableRelation                                              |
| 51106   | CV Dimension Set ID        | Integer  <br>TableRelation                                               |

#### Cust. Ledger Entry (Debitorenposten)

| Feldnr. | Feldname          | Feldtyp  |
| ------- | ----------------- | -------- |
| 51100   | Paid              | Boolean  |
| 51101   | Pmt Cancelled     | Boolean  |
| 51102   | Bank Posting Date | Date     |
| 51103   | Bank Document No. | Code[20] |

#### Vendor Ledger Entry (Kreditorenposten)

| Feldnr. | Feldname          | Feldtyp  |
| ------- | ----------------- | -------- |
| 51100   | Paid              | Boolean  |
| 51101   | Pmt Cancelled     | Boolean  |
| 51102   | Bank Posting Date | Date     |
| 51103   | Bank Document No. | Code[20] |

#### G/L Entry (Sachposten)

| Feldnr. | Feldname          | Feldtyp  |
| ------- | ----------------- | -------- |
| 51100   | Paid              | Boolean  |
| 51101   | Pmt Cancelled     | Boolean  |
| 51102   | Bank Posting Date | Date     |
| 51103   | Bank Document No. | Code[20] |
| 51105   | CV Doc. Due Date  | Date     |

#### Dimension Set Entry (Dimensionssatzposten)

In den Dimensionssatzposten wurde eine neue Feldgruppe für den Typ "DropDown" definiert. Sie enthält die Felder "Dimension Code", "Dimension Value Code" und "Dimension Value Name".

Diese Feldgruppe wird zur verbesserten Darstellung der Tabellenrelation in den Bankposten verwendet.

### Bank Account Ledger Entries (Abfrage)
Eine benutzerdefinierte Abfrage stellt die Zahlungshauptbucheinträge als API-Abfrage bereit.

    EntitySetName = 'CameralisticBankAccountLedgerEntries';
    EntityName = 'CameralisticBankAccountLedgerEntry';
    APIPublisher = 'P3';
    APIVersion = 'v1.0';
    APIGroup = 'CameralisticLedgerEntries';

Durch Verwendung der [Installations-Codeunit] (#installation-codeunit) wird die Abfrage automatisch bei den Webservices von BC registriert.

Derzeit werden die Dimensionen durch die Dimensionssatz-Eintrags-ID aufgelöst, die mit dem Kunden-/Lieferantenbuchungsposten gepostet wird. Aufgrund des Konzepts von Abfragen in BC und ihrer DataItemLink-Eigenschaft können die Dimensionswerte nicht in Spalten nebeneinander genutzt werden. Stattdessen werden sie in mehreren Zeilen aufgelistet, was zu „gefälschten“ Bankkonten-Buchungsposten führt, die sich nur durch die „CVDimension_“-Werte unterscheiden. Für die Verwendung in externen Analysen sollte das Feld „Entry_No_“ verwendet werden, um diese Einträge wieder zusammenzuführen.

#### API-Felder
| Feldname               | Feldbeschreibung                                     | Feldtyp                                          |
| :--------------------- | :--------------------------------------------------- | :----------------------------------------------- |
| Entry_No_              | Bank Account Ledger Entry "Lfd. Nr."                 | `Integer`                                        |
| BankAccountNo          | Bank Account Ledger Entry "Bankkontonr."             | `Code[20]`                                       |
| AmountLCY              | Bank Account Ledger Entry "Betrag (MW)"              | `Decimal`                                        |
| PostingDate            | Bank Account Ledger Entry "Buchungsdatum"            | `Date`                                           |
| StatementNo            | Bank Account Ledger Entry "Auszugsnr."               | `Code[20]`                                       |
| BalAccountType         | Bank Account Ledger Entry "Gegenkonto Typ"           | Enum "Gen. Journal Account Type"                 |
| BalAccountNo           | Bank Account Ledger Entry "Gegenkonto Nr."           | `Code[20]`                                       |
| CVDocType              | Kreditor/ Debitor Belegart                           | Enum "Gen. Journal Document Type"                |
| CVDocNo                | Kreditor/Debitor Beleg-Nr.                           | `Code[20]`<br>RG-251001                          |
| CVDocDueDate           | Kreditor/Debitor Beleg Fälligkeitsdatum              | `Date`                                           |
| CVGlobalDimension1Code | Kreditor / Debitor Globale Dimension 1 Code          | `Code[20]`                                       |
| CVGlobalDimension2Code | Kreditor / Debitor Globale Dimension 2 Code          | `Code[20]`                                       |
| CVDimensionSetID       | Kreditor / Debitor Dimensionssatz-ID                 | `Integer`                                        |
| LedgerEntryType        | Buchungstyp für Ursprungsbuchung                     | Enum "Source Ledger Entry Type"                  |
| **>>> BEGIN**          | **DataItemLink = „Dimension Set ID“ =**              | **BankAccountLedgerEntry.„CV Dimension Set ID“** |
| CVDimension_Code       | Bank Account Ledger Entry "Dimension"                | `Code[20]`                                       |
| CVDimension_Value_Code | Customer/Vendor Ledger Entry "Dimensionswert"        | `Code[20]`                                       |
| CVDimension_Value_Name | Customer/Vendor Ledger Entry "Dimensionswert Name"   | `Text[50]`                                       |
| **<<< END OF**         | **DATAITEMLINK**                                     |                                                  |
| BankLEGlobDim1         | Bank Account Ledger Entry "Globale Dimension 1 Code" | `Code[20]`                                       |
| BankLEGlobDim2         | Bank Account Ledger Entry "Global Dimension 2 Code"  | `Code[20]`                                       |
| BankLEDimSetID         | Bank Account Ledger Entry "Dimensionssatz ID"        | `Integer`                                        |