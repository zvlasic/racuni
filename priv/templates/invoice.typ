// Croatian Invoice Template
// Data is passed via elixir_data global variable from Imprintor

#let invoice = elixir_data.at("invoice", default: (:))

#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2cm),
)

#set text(
  font: "DejaVu Sans",
  size: 10pt,
  lang: "hr",
)

// Header
#align(center)[
  #text(size: 18pt, weight: "bold")[RAČUN]
  #v(0.3cm)
  #text(size: 14pt)[Broj: #invoice.at("id", default: "")]
]

#v(0.5cm)

// Supplier and Customer info side by side
#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #text(weight: "bold")[IZDAVATELJ:]
    #v(0.2cm)
    #invoice.at("supplier", default: (:)).at("name", default: "") \
    #invoice.at("supplier", default: (:)).at("street", default: "") \
    #invoice.at("supplier", default: (:)).at("postal_code", default: "") #invoice.at("supplier", default: (:)).at("city", default: "") \
    OIB: #invoice.at("supplier", default: (:)).at("oib", default: "") \
    #if invoice.at("supplier", default: (:)).at("legal_form", default: none) != none [
      #text(size: 8pt)[#invoice.at("supplier", default: (:)).at("legal_form", default: "")]
    ]
  ],
  [
    #text(weight: "bold")[KUPAC:]
    #v(0.2cm)
    #invoice.at("customer", default: (:)).at("name", default: "") \
    #invoice.at("customer", default: (:)).at("street", default: "") \
    #invoice.at("customer", default: (:)).at("postal_code", default: "") #invoice.at("customer", default: (:)).at("city", default: "") \
    OIB: #invoice.at("customer", default: (:)).at("oib", default: "")
  ]
)

#v(0.5cm)

// Invoice metadata
#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    *Datum izdavanja:* #invoice.at("issue_date", default: "") \
    *Datum dospijeća:* #invoice.at("due_date", default: "") \
  ],
  [
    *Datum isporuke:* #invoice.at("delivery_date", default: "") \
    *Valuta:* #invoice.at("currency", default: "EUR")
  ]
)

#v(0.5cm)

// Line items table
#text(weight: "bold", size: 11pt)[Stavke računa]
#v(0.3cm)

#let items = invoice.at("line_items", default: ())

#table(
  columns: (auto, 1fr, auto, auto, auto, auto, auto),
  inset: 6pt,
  align: (col, row) => if col == 1 { left } else { right },
  fill: (col, row) => if row == 0 { luma(230) } else { none },
  stroke: 0.5pt,

  // Header
  [*Rb.*], [*Naziv*], [*Kol.*], [*JM*], [*Cijena*], [*Iznos*], [*PDV %*],

  // Items
  ..items.enumerate().map(((i, item)) => (
    str(i + 1),
    item.at("name", default: ""),
    item.at("quantity", default: ""),
    item.at("unit", default: ""),
    item.at("unit_price", default: ""),
    item.at("line_total", default: ""),
    item.at("vat_percent", default: ""),
  )).flatten()
)

#v(0.5cm)

// Tax breakdown
#let tax_breakdown = invoice.at("tax_breakdown", default: ())

#if tax_breakdown.len() > 0 [
  #text(weight: "bold", size: 11pt)[Rekapitulacija PDV-a]
  #v(0.3cm)

  #table(
    columns: (auto, auto, auto, auto),
    inset: 6pt,
    align: right,
    fill: (col, row) => if row == 0 { luma(230) } else { none },
    stroke: 0.5pt,

    [*Kategorija*], [*Stopa*], [*Osnovica*], [*PDV*],

    ..tax_breakdown.map(tax => (
      tax.at("category", default: ""),
      if tax.at("percent", default: none) != none [#tax.at("percent", default: "")%] else [],
      tax.at("taxable_amount", default: ""),
      tax.at("tax_amount", default: ""),
    )).flatten()
  )
]

#v(0.5cm)

// Totals
#let totals = invoice.at("totals", default: (:))

#align(right)[
  #table(
    columns: (auto, auto),
    inset: 6pt,
    align: (left, right),
    stroke: none,

    [Ukupno bez PDV-a:], [#totals.at("tax_exclusive", default: "") #invoice.at("currency", default: "EUR")],
    [PDV:], [#totals.at("tax_amount", default: "") #invoice.at("currency", default: "EUR")],
    table.hline(stroke: 1pt),
    [*UKUPNO ZA PLATITI:*], [*#totals.at("payable", default: "") #invoice.at("currency", default: "EUR")*],
  )
]

#v(1cm)

// Payment information
#let payment = invoice.at("payment_means", default: (:))

#box(
  width: 100%,
  stroke: 0.5pt,
  inset: 10pt,
  [
    #text(weight: "bold", size: 11pt)[Podaci za plaćanje]
    #v(0.3cm)
    #grid(
      columns: (auto, 1fr),
      gutter: 0.5cm,
      row-gutter: 0.2cm,
      [*IBAN:*], [#payment.at("iban", default: "")],
      [*Model:*], [#payment.at("model", default: "")],
      [*Poziv na broj:*], [#payment.at("reference", default: "")],
      [*Rok plaćanja:*], [#invoice.at("due_date", default: "")],
    )
  ]
)

#v(0.5cm)

// HUB3 Barcode - barcode_path contains path to PNG file
#let barcode_path = elixir_data.at("barcode_path", default: none)
#if barcode_path != none and barcode_path != "" [
  #v(0.5cm)
  #align(center)[
    #text(size: 9pt)[Skenirajte za plaćanje:]
    #v(0.2cm)
    #image(barcode_path, width: 6cm)
  ]
]

#v(1cm)

// Footer
#line(length: 100%, stroke: 0.5pt)
#v(0.3cm)
#text(size: 8pt)[
  Ovaj račun je izrađen elektronički i valjan je bez potpisa i pečata.
]
