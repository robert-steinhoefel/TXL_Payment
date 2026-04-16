# Abrechnungseintrag API (`settlementEntries`)

OData-API-Seite (Seite 51102), die den **Abrechnungseintrag** (Tabelle 51106) für Power BI und externe Verbraucher bereitstellt.

## Endpunkt

```
GET /api/p3group/txlPayment/v1.0/companies({id})/settlementEntries
```

- **Authentifizierung:** OAuth 2.0 (BC SaaS) oder Basic Auth (On-Premises)
- **Schreibgeschützt:** INSERT / MODIFY / DELETE sind deaktiviert

## Schlüsselfeld

`entryNo` (*Lfd. Nr.*, Integer, automatisch erhöht) ist der OData-Primärschlüssel (`ODataKeyFields`).
Jede Zeile repräsentiert einen Abrechnungseintrag: eine einzelne Zahlungszuordnung eines bestimmten Betrags zu einer bestimmten Belegzeile.

## Klassifizierungsfelder

| Feld                  | Werte                                              |
| --------------------- | -------------------------------------------------- |
| `transactionType`     | `Sales` (Verkauf) \| `Purchase` (Einkauf)          |
| `documentType`        | `Invoice` (Rechnung) \| `Credit Memo` (Gutschrift) |
| `settlementEntryType` | `Normal` \| `Unallocated` \| `Reversal`            |

- **Normal** — Standardeintrag, der bei Zahlung/Ausgleich erstellt wird.
- **Unallocated** — Überzahlungsrest, der noch keiner Belegzeile zugeordnet wurde;
  `documentNo` ist für diese Zeilen absichtlich leer.
- **Reversal** — Wird erstellt, wenn ein Zahlungs- oder Gutschriftsausgleich aufgehoben wird;
  Beträge tragen das **umgekehrte Vorzeichen** des ursprünglichen Eintrags.
  Mit `reversalEntry = true` und `originalEntryNo` den ursprünglichen Eintrag verknüpfen.

## Belegreferenz

`documentNo` / `documentLineNo` identifizieren die gebuchte Rechnungs- oder Gutschriftszeile,
zu der dieser Abrechnungseintrag gehört.

## Beträge (alle in MW)

| Feld                                         | Inhalt                                                                                                   |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `settlementAmt` / `settlementAmtInclVat`     | Anteil der Zahlung, der dieser Zeile zugeordnet wurde                                                    |
| `cashDiscountAmt` / `cashDiscountAmtInclVat` | Auf diese Zeile verteilter Skontobetrag                                                                  |
| `originalLineAmt` / `originalLineAmtInclVat` | Snapshot des Quellbelegzeilenbetrags zum Zeitpunkt der Eintragserfassung (für Abweichungsberichte)       |
| `nonDeductibleVatAmt`                        | Nicht abziehbarer MwSt.-Anteil der Zeile                                                                 |
| `totalSettledAmtInclVat` / `totalSettledAmt` | `settlementAmt + cashDiscountAmt` — denormalisiert für das FlowField-Summenfeld in der Quellbelagtabelle |

Stornoeinträge tragen **negative** Beträge; Netto aus Original + Storno = 0.

## Vollständig-beglichen-Kennzeichen

- `lineFullySettled` — `true`, sobald der gesamte ausgeglichene Betrag für diese Belegzeile den
  ursprünglichen Zeilenbetrag erreicht (innerhalb einer ±0,01-Rundungstoleranz).
- `documentFullySettled` — `true`, sobald der Restbetrag des Debitor-/Kreditorposten-Eintrags 0 erreicht.

Beide Kennzeichen werden nach jedem Einfügen oder Storno auf **allen** Abrechnungseinträgen für die
betroffene Zeile/den betroffenen Beleg aktualisiert, sodass Power BI den aktuellen Abrechnungsstatus
ohne Aggregation filtern kann.

> **Bekannte Lücke:** Bei einer Gutschrift, die vor einer Zahlung gebucht wird (separate Transaktionen),
> erhalten die Gutschriftseinträge `documentFullySettled = false` zum Erstellungszeitpunkt und werden
> nicht aktualisiert, wenn die spätere Zahlung den Beleg schließt. Zahlungseinträge sind stets zuverlässig.

## Dimensionen

Alle 8 Dimensionsabkürzungscodes (`globalDimension1Code` … `shortcutDimension8Code`) werden direkt im
Datensatz gespeichert — keine Joins oder CalcFields erforderlich. OData-`$filter` auf jeden Dimensionscode
ist indexgestützt.

Dimensions**bezeichnungen** werden hier nicht gespeichert. So lösen Sie einen Code in seinen Anzeigenamen auf:
- Verknüpfung mit dem Standard-BC-Endpunkt `dimensionValues` über den Dimensionscode als Schlüssel, oder
- Aufbau einer Power BI-Nachschlagetabelle aus diesem Endpunkt.

`dimensionSetId` dient als Brücke zur Standard-Dimensionssatz-Eintrags-API für Verbraucher, die alle
Dimensionswerte über die 8 Abkürzungen hinaus abrufen möchten.

## Sachkonto

`glAccountNo` / `glAccountName` — Sachkontonummer und -bezeichnung, zum Zeitpunkt der Eintragserfassung gespeichert.

## Debitor / Kreditor

`cvNo` / `cvName` — Debitor- oder Kreditorennummer und -name (Snapshot; wird bei Umbenennung nicht aktualisiert).
Über `transactionType` unterscheiden: `Sales` → Debitor, `Purchase` → Kreditor.

## Stornierungskette

| Feld              | Inhalt                                                         |
| ----------------- | -------------------------------------------------------------- |
| `reversalEntry`   | `true`, wenn diese Zeile ein Storno eines anderen Eintrags ist |
| `originalEntryNo` | `entryNo` des stornierten Eintrags (0, wenn kein Storno)       |
| `reversed`        | `true` beim Originaleintrag, sobald er storniert wurde         |
| `reversalEntryNo` | `entryNo` des Stornoeintrags (0, wenn noch nicht storniert)    |

## Delta-Abfragen / Inkrementelle Aktualisierung

`ChangeTrackingAllowed = true` aktiviert OData-`$deltatoken`. Die inkrementelle Power BI-Aktualisierung
kann nur seit der letzten Aktualisierung erstellte oder geänderte Zeilen abrufen, anstatt die gesamte
Tabelle neu zu laden. `systemModifiedAt` als Grenzwert für die inkrementelle Aktualisierung verwenden.

## Systemfelder

`systemId`, `systemCreatedAt`, `systemModifiedAt`, `systemCreatedBy`, `systemModifiedBy` werden automatisch
von der BC-OData-Schicht für alle benutzerdefinierten API-Seiten bereitgestellt —
keine expliziten Felddeklarationen erforderlich.

## Ausgelassene Felder

`sourceTransactionNo` / `sourcePaymentCLEEntryNo` — interne Deduplizierungsfelder, die von
`SettlementEntryMgt` verwendet werden; für Berichte nicht relevant.
