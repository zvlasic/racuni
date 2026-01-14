defmodule Racuni.HUB3 do
  @moduledoc """
  Generates HUB3 payment barcodes (PDF417) according to Croatian banking standards.

  The HUB3 format (HRVHUB30) is used on Croatian payment slips and can be
  scanned by mobile banking apps.
  """

  alias Racuni.Invoice

  @doc """
  Generates a HUB3 barcode PNG image from an invoice.

  Returns `{:ok, png_binary}` or `{:error, reason}`.
  """
  def generate_barcode(%Invoice{} = invoice) do
    with :ok <- validate_invoice_for_hub3(invoice) do
      data = format_hub3_string(invoice)

      case PDF417.encode(data, %{columns: 8, security_level: 2}) do
        {:ok, png_iodata} ->
          {:ok, IO.iodata_to_binary(png_iodata)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_invoice_for_hub3(%Invoice{} = invoice) do
    cond do
      is_nil(invoice.totals) ->
        {:error, "Nedostaju ukupni iznosi računa (totals)"}

      is_nil(invoice.totals.payable) ->
        {:error, "Nedostaje iznos za plaćanje (payable)"}

      is_nil(invoice.supplier) ->
        {:error, "Nedostaju podaci o izdavatelju (supplier)"}

      is_nil(invoice.customer) ->
        {:error, "Nedostaju podaci o kupcu (customer)"}

      is_nil(invoice.payment_means) ->
        {:error, "Nedostaju podaci o plaćanju (payment_means)"}

      true ->
        :ok
    end
  end

  @doc """
  Formats invoice data into the HUB3 string format.
  """
  def format_hub3_string(%Invoice{} = invoice) do
    amount_cents = amount_to_cents(invoice.totals.payable)

    lines = [
      "HRVHUB30",
      pad_right(invoice.currency || "EUR", 3),
      pad_left(Integer.to_string(amount_cents), 15, "0"),
      truncate_hub3(invoice.customer.name, 30),
      truncate_hub3(invoice.customer.street, 27),
      truncate_hub3(format_city(invoice.customer), 27),
      truncate_hub3(invoice.supplier.name, 30),
      truncate_hub3(invoice.supplier.street, 27),
      truncate_hub3(format_city(invoice.supplier), 27),
      invoice.payment_means.iban || "",
      invoice.payment_means.model || "HR99",
      invoice.payment_means.reference || "",
      "COST",
      truncate_hub3("Racun #{invoice.id}", 35)
    ]

    Enum.join(lines, "\n")
  end

  defp amount_to_cents(nil), do: 0

  defp amount_to_cents(%Decimal{} = amount) do
    amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  defp format_city(%{postal_code: postal_code, city: city}) do
    [postal_code, city]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  @doc """
  Truncates a string for HUB3 format, accounting for Croatian diacritics.

  Croatian characters (č, ć, ž, š, đ) count as 2 characters in HUB3.
  """
  def truncate_hub3(nil, _max_length), do: ""
  def truncate_hub3("", _max_length), do: ""

  def truncate_hub3(string, max_length) do
    string
    |> String.trim()
    |> do_truncate_hub3(max_length, 0, [])
    |> Enum.reverse()
    |> Enum.join()
  end

  @croatian_chars ~w(č ć ž š đ Č Ć Ž Š Đ)

  defp do_truncate_hub3("", _max, _count, acc), do: acc

  defp do_truncate_hub3(string, max, count, acc) do
    {char, rest} = String.next_grapheme(string)
    char_weight = if char in @croatian_chars, do: 2, else: 1
    new_count = count + char_weight

    if new_count > max do
      acc
    else
      do_truncate_hub3(rest, max, new_count, [char | acc])
    end
  end

  defp pad_left(string, length, char) do
    String.pad_leading(string, length, char)
  end

  defp pad_right(string, length) do
    String.pad_trailing(string, length)
  end
end
