defmodule Racuni.PDF do
  @moduledoc """
  PDF generation using Typst templates via Imprintor.
  """

  alias Racuni.Invoice
  alias Racuni.HUB3

  @template_path "priv/templates/invoice.typ"

  @doc """
  Generates a PDF from an invoice.

  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  def generate(%Invoice{} = invoice) do
    with {:ok, barcode_png} <- HUB3.generate_barcode(invoice),
         {:ok, pdf_binary} <- compile_pdf(invoice, barcode_png) do
      {:ok, pdf_binary}
    end
  end

  defp compile_pdf(invoice, barcode_png) do
    template = File.read!(@template_path)

    # Write barcode to temp file since Imprintor can't handle raw binary
    barcode_path = Path.join(System.tmp_dir!(), "barcode-#{:erlang.unique_integer([:positive])}.png")
    File.write!(barcode_path, barcode_png)

    # Imprintor passes data directly as elixir_data global variable
    data = %{
      "invoice" => serialize_invoice(invoice),
      "barcode_path" => barcode_path
    }

    # Set root_directory to / so we can access the temp file with absolute path
    config = Imprintor.Config.new(template, data, root_directory: "/")

    result =
      case Imprintor.compile_to_pdf(config) do
        {:ok, pdf} -> {:ok, pdf}
        {:error, reason} -> {:error, "PDF compilation failed: #{inspect(reason)}"}
      end

    # Cleanup temp file
    File.rm(barcode_path)

    result
  end

  defp serialize_invoice(%Invoice{} = invoice) do
    %{
      "id" => invoice.id,
      "issue_date" => format_date(invoice.issue_date),
      "due_date" => format_date(invoice.due_date),
      "delivery_date" => format_date(invoice.delivery_date),
      "currency" => invoice.currency,
      "type_code" => invoice.type_code,
      "supplier" => serialize_party(invoice.supplier),
      "customer" => serialize_party(invoice.customer),
      "payment_means" => serialize_payment_means(invoice.payment_means),
      "line_items" => Enum.map(invoice.line_items, &serialize_line_item/1),
      "tax_breakdown" => Enum.map(invoice.tax_breakdown, &serialize_tax_subtotal/1),
      "totals" => serialize_totals(invoice.totals)
    }
  end

  defp serialize_party(nil), do: %{}

  defp serialize_party(%Invoice.Party{} = party) do
    %{
      "name" => party.name,
      "street" => party.street,
      "city" => party.city,
      "postal_code" => party.postal_code,
      "country" => party.country,
      "tax_id" => party.tax_id,
      "oib" => party.oib,
      "legal_form" => party.legal_form
    }
  end

  defp serialize_payment_means(nil), do: %{}

  defp serialize_payment_means(%Invoice.PaymentMeans{} = pm) do
    %{
      "iban" => pm.iban,
      "model" => pm.model,
      "reference" => pm.reference,
      "note" => pm.note
    }
  end

  defp serialize_line_item(%Invoice.LineItem{} = item) do
    %{
      "id" => item.id,
      "name" => item.name,
      "description" => item.description,
      "quantity" => format_decimal(item.quantity),
      "unit" => format_unit(item.unit),
      "unit_price" => format_decimal(item.unit_price),
      "line_total" => format_decimal(item.line_total),
      "vat_percent" => format_decimal(item.vat_percent),
      "vat_category" => item.vat_category
    }
  end

  defp serialize_tax_subtotal(%Invoice.TaxSubtotal{} = tax) do
    %{
      "category" => tax.category,
      "percent" => format_decimal(tax.percent),
      "taxable_amount" => format_decimal(tax.taxable_amount),
      "tax_amount" => format_decimal(tax.tax_amount),
      "exemption_reason" => tax.exemption_reason
    }
  end

  defp serialize_totals(nil), do: %{}

  defp serialize_totals(%Invoice.Totals{} = totals) do
    %{
      "line_extension" => format_decimal(totals.line_extension),
      "tax_exclusive" => format_decimal(totals.tax_exclusive),
      "tax_inclusive" => format_decimal(totals.tax_inclusive),
      "tax_amount" => format_decimal(totals.tax_amount),
      "payable" => format_decimal(totals.payable),
      "charge_total" => format_decimal(totals.charge_total),
      "allowance_total" => format_decimal(totals.allowance_total)
    }
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp format_decimal(nil), do: ""
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)

  # Common unit codes to Croatian abbreviations
  @unit_codes %{
    "H87" => "kom",
    "PCE" => "kom",
    "EA" => "kom",
    "HUR" => "sat",
    "DAY" => "dan",
    "MON" => "mj",
    "KGM" => "kg",
    "GRM" => "g",
    "LTR" => "l",
    "MTR" => "m",
    "MTK" => "m²",
    "MTQ" => "m³"
  }

  defp format_unit(nil), do: ""
  defp format_unit(code), do: Map.get(@unit_codes, code, code)
end
