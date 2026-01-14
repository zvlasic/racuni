defmodule Racuni.Invoice do
  @moduledoc """
  Struct and parser for UBL 2.1 invoices.
  """

  import SweetXml

  defstruct [
    :id,
    :issue_date,
    :issue_time,
    :due_date,
    :currency,
    :type_code,
    :supplier,
    :customer,
    :payment_means,
    :line_items,
    :tax_breakdown,
    :totals,
    :delivery_date
  ]

  defmodule Party do
    @moduledoc "Represents a supplier or customer party."
    defstruct [:name, :street, :city, :postal_code, :country, :tax_id, :oib, :legal_form]
  end

  defmodule PaymentMeans do
    @moduledoc "Payment information including IBAN and reference."
    defstruct [:iban, :model, :reference, :note]
  end

  defmodule LineItem do
    @moduledoc "A single invoice line item."
    defstruct [
      :id,
      :name,
      :description,
      :quantity,
      :unit,
      :unit_price,
      :line_total,
      :vat_percent,
      :vat_category
    ]
  end

  defmodule TaxSubtotal do
    @moduledoc "VAT breakdown by category/rate."
    defstruct [:category, :percent, :taxable_amount, :tax_amount, :exemption_reason]
  end

  defmodule Totals do
    @moduledoc "Invoice monetary totals."
    defstruct [
      :line_extension,
      :tax_exclusive,
      :tax_inclusive,
      :tax_amount,
      :payable,
      :charge_total,
      :allowance_total
    ]
  end

  @ubl_ns [
    invoice: "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
    cac: "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
    cbc: "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
  ]

  @doc """
  Parses a UBL 2.1 Invoice XML string into an Invoice struct.

  Returns `{:ok, %Invoice{}}` or `{:error, reason}`.
  """
  def parse(xml_string) when is_binary(xml_string) do
    try do
      doc = SweetXml.parse(xml_string)

      invoice = %__MODULE__{
        id: xpath(doc, ~x"/invoice:Invoice/cbc:ID/text()"s |> add_ns()),
        issue_date:
          xpath(doc, ~x"/invoice:Invoice/cbc:IssueDate/text()"s |> add_ns()) |> parse_date(),
        issue_time: xpath(doc, ~x"/invoice:Invoice/cbc:IssueTime/text()"os |> add_ns()),
        due_date:
          xpath(doc, ~x"/invoice:Invoice/cbc:DueDate/text()"os |> add_ns()) |> parse_date(),
        currency: xpath(doc, ~x"/invoice:Invoice/cbc:DocumentCurrencyCode/text()"s |> add_ns()),
        type_code: xpath(doc, ~x"/invoice:Invoice/cbc:InvoiceTypeCode/text()"s |> add_ns()),
        supplier: parse_supplier(doc),
        customer: parse_customer(doc),
        payment_means: parse_payment_means(doc),
        line_items: parse_line_items(doc),
        tax_breakdown: parse_tax_breakdown(doc),
        totals: parse_totals(doc),
        delivery_date:
          xpath(doc, ~x"//cac:Delivery/cbc:ActualDeliveryDate/text()"os |> add_ns())
          |> parse_date()
      }

      {:ok, invoice}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp add_ns(xpath_expr) do
    Enum.reduce(@ubl_ns, xpath_expr, fn {prefix, uri}, acc ->
      SweetXml.add_namespace(acc, to_string(prefix), uri)
    end)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_supplier(doc) do
    base = ~x"//cac:AccountingSupplierParty/cac:Party"e |> add_ns()
    party = xpath(doc, base)

    if party do
      %Party{
        name: xpath(party, ~x"./cac:PartyLegalEntity/cbc:RegistrationName/text()"s |> add_ns()),
        street: xpath(party, ~x"./cac:PostalAddress/cbc:StreetName/text()"s |> add_ns()),
        city: xpath(party, ~x"./cac:PostalAddress/cbc:CityName/text()"s |> add_ns()),
        postal_code: xpath(party, ~x"./cac:PostalAddress/cbc:PostalZone/text()"s |> add_ns()),
        country:
          xpath(
            party,
            ~x"./cac:PostalAddress/cac:Country/cbc:IdentificationCode/text()"s |> add_ns()
          ),
        tax_id: xpath(party, ~x"./cac:PartyTaxScheme/cbc:CompanyID/text()"s |> add_ns()),
        oib: xpath(party, ~x"./cbc:EndpointID/text()"s |> add_ns()),
        legal_form:
          xpath(party, ~x"./cac:PartyLegalEntity/cbc:CompanyLegalForm/text()"os |> add_ns())
      }
    end
  end

  defp parse_customer(doc) do
    base = ~x"//cac:AccountingCustomerParty/cac:Party"e |> add_ns()
    party = xpath(doc, base)

    if party do
      %Party{
        name: xpath(party, ~x"./cac:PartyLegalEntity/cbc:RegistrationName/text()"s |> add_ns()),
        street: xpath(party, ~x"./cac:PostalAddress/cbc:StreetName/text()"s |> add_ns()),
        city: xpath(party, ~x"./cac:PostalAddress/cbc:CityName/text()"s |> add_ns()),
        postal_code: xpath(party, ~x"./cac:PostalAddress/cbc:PostalZone/text()"s |> add_ns()),
        country:
          xpath(
            party,
            ~x"./cac:PostalAddress/cac:Country/cbc:IdentificationCode/text()"s |> add_ns()
          ),
        tax_id: xpath(party, ~x"./cac:PartyTaxScheme/cbc:CompanyID/text()"s |> add_ns()),
        oib: xpath(party, ~x"./cbc:EndpointID/text()"s |> add_ns()),
        legal_form: nil
      }
    end
  end

  defp parse_payment_means(doc) do
    base = ~x"//cac:PaymentMeans"e |> add_ns()
    pm = xpath(doc, base)

    if pm do
      payment_id = xpath(pm, ~x"./cbc:PaymentID/text()"s |> add_ns())
      {model, reference} = parse_payment_id(payment_id)

      %PaymentMeans{
        iban: xpath(pm, ~x"./cac:PayeeFinancialAccount/cbc:ID/text()"s |> add_ns()),
        model: model,
        reference: reference,
        note: xpath(pm, ~x"./cbc:InstructionNote/text()"os |> add_ns())
      }
    end
  end

  defp parse_payment_id(nil), do: {"HR99", ""}
  defp parse_payment_id(""), do: {"HR99", ""}

  defp parse_payment_id(payment_id) do
    # Format is typically "HR00 123456" or "HR00123456"
    case String.split(String.trim(payment_id), ~r/\s+/, parts: 2) do
      [model, reference] ->
        {model, reference}

      [combined] ->
        if String.starts_with?(combined, "HR") do
          {String.slice(combined, 0, 4), String.slice(combined, 4..-1//1)}
        else
          {"HR99", combined}
        end
    end
  end

  defp parse_line_items(doc) do
    xpath(doc, ~x"//cac:InvoiceLine"el |> add_ns())
    |> Enum.map(fn item ->
      %LineItem{
        id: xpath(item, ~x"./cbc:ID/text()"s |> add_ns()),
        name: xpath(item, ~x"./cac:Item/cbc:Name/text()"s |> add_ns()),
        description: xpath(item, ~x"./cac:Item/cbc:Description/text()"os |> add_ns()),
        quantity: xpath(item, ~x"./cbc:InvoicedQuantity/text()"s |> add_ns()) |> parse_decimal(),
        unit: xpath(item, ~x"./cbc:InvoicedQuantity/@unitCode"s),
        unit_price:
          xpath(item, ~x"./cac:Price/cbc:PriceAmount/text()"s |> add_ns()) |> parse_decimal(),
        line_total:
          xpath(item, ~x"./cbc:LineExtensionAmount/text()"s |> add_ns()) |> parse_decimal(),
        vat_percent:
          xpath(item, ~x"./cac:Item/cac:ClassifiedTaxCategory/cbc:Percent/text()"s |> add_ns())
          |> parse_decimal(),
        vat_category:
          xpath(item, ~x"./cac:Item/cac:ClassifiedTaxCategory/cbc:ID/text()"s |> add_ns())
      }
    end)
  end

  defp parse_tax_breakdown(doc) do
    xpath(doc, ~x"//cac:TaxTotal/cac:TaxSubtotal"el |> add_ns())
    |> Enum.map(fn subtotal ->
      %TaxSubtotal{
        category: xpath(subtotal, ~x"./cac:TaxCategory/cbc:ID/text()"s |> add_ns()),
        percent:
          xpath(subtotal, ~x"./cac:TaxCategory/cbc:Percent/text()"s |> add_ns())
          |> parse_decimal(),
        taxable_amount:
          xpath(subtotal, ~x"./cbc:TaxableAmount/text()"s |> add_ns()) |> parse_decimal(),
        tax_amount: xpath(subtotal, ~x"./cbc:TaxAmount/text()"s |> add_ns()) |> parse_decimal(),
        exemption_reason:
          xpath(subtotal, ~x"./cac:TaxCategory/cbc:TaxExemptionReason/text()"os |> add_ns())
      }
    end)
  end

  defp parse_totals(doc) do
    base = ~x"//cac:LegalMonetaryTotal"e |> add_ns()
    totals = xpath(doc, base)

    if totals do
      %Totals{
        line_extension:
          xpath(totals, ~x"./cbc:LineExtensionAmount/text()"s |> add_ns()) |> parse_decimal(),
        tax_exclusive:
          xpath(totals, ~x"./cbc:TaxExclusiveAmount/text()"s |> add_ns()) |> parse_decimal(),
        tax_inclusive:
          xpath(totals, ~x"./cbc:TaxInclusiveAmount/text()"s |> add_ns()) |> parse_decimal(),
        payable: xpath(totals, ~x"./cbc:PayableAmount/text()"s |> add_ns()) |> parse_decimal(),
        charge_total:
          xpath(totals, ~x"./cbc:ChargeTotalAmount/text()"os |> add_ns()) |> parse_decimal(),
        allowance_total:
          xpath(totals, ~x"./cbc:AllowanceTotalAmount/text()"os |> add_ns()) |> parse_decimal(),
        tax_amount:
          xpath(doc, ~x"//cac:TaxTotal/cbc:TaxAmount/text()"s |> add_ns()) |> parse_decimal()
      }
    end
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil

  defp parse_decimal(string) do
    case Decimal.parse(string) do
      {decimal, ""} -> decimal
      {decimal, _rest} -> decimal
      :error -> nil
    end
  end
end
