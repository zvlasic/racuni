defmodule Racuni.Invoice.EFiskalizacijaParser do
  @moduledoc """
  Parser for Croatian Tax Authority eFiskalizacija XML format.

  This parser handles XML documents conforming to the eFiskalizacijaSchema.xsd
  from Porezna Uprava (Croatian Tax Authority).

  The format is different from standard UBL 2.1 and uses Croatian element names.
  """

  import SweetXml

  alias Racuni.Invoice
  alias Racuni.Invoice.{Party, PaymentMeans, LineItem, TaxSubtotal, Totals}

  @efis_ns "http://www.porezna-uprava.gov.hr/fin/2024/types/eFiskalizacija"

  @doc """
  Parses an eFiskalizacija XML string into an Invoice struct.

  Returns `{:ok, %Invoice{}}` or `{:error, reason}`.
  """
  def parse(xml_string) when is_binary(xml_string) do
    try do
      doc = SweetXml.parse(xml_string)

      # eFiskalizacija can have multiple ERacun elements, we take the first one
      eracun = xpath(doc, ~x"//tns:ERacun"e |> add_ns())

      if is_nil(eracun) do
        {:error, "Element ERacun nije pronađen u dokumentu"}
      else
        invoice = %Invoice{
          id: xpath(eracun, ~x"./tns:brojDokumenta/text()"s |> add_ns()),
          issue_date: xpath(eracun, ~x"./tns:datumIzdavanja/text()"s |> add_ns()) |> parse_date(),
          due_date:
            xpath(eracun, ~x"./tns:datumDospijecaPlacanja/text()"os |> add_ns()) |> parse_date(),
          delivery_date:
            xpath(eracun, ~x"./tns:datumIsporuke/text()"os |> add_ns()) |> parse_date(),
          currency: xpath(eracun, ~x"./tns:valutaERacuna/text()"s |> add_ns()),
          type_code: xpath(eracun, ~x"./tns:vrstaDokumenta/text()"s |> add_ns()),
          supplier: parse_izdavatelj(eracun),
          customer: parse_primatelj(eracun),
          payment_means: parse_prijenos_sredstava(eracun),
          line_items: parse_stavke(eracun),
          tax_breakdown: parse_raspodjela_pdv(eracun),
          totals: parse_dokument_ukupan_iznos(eracun)
        }

        {:ok, invoice}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp add_ns(xpath_expr) do
    SweetXml.add_namespace(xpath_expr, "tns", @efis_ns)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_izdavatelj(eracun) do
    izdavatelj = xpath(eracun, ~x"./tns:Izdavatelj"e |> add_ns())

    if izdavatelj do
      oib = xpath(izdavatelj, ~x"./tns:oibPorezniBroj/text()"s |> add_ns())

      %Party{
        name: xpath(izdavatelj, ~x"./tns:ime/text()"s |> add_ns()),
        oib: extract_oib(oib),
        tax_id: oib,
        # eFiskalizacija format doesn't include address details for Izdavatelj
        street: nil,
        city: nil,
        postal_code: nil,
        country: "HR"
      }
    end
  end

  defp parse_primatelj(eracun) do
    primatelj = xpath(eracun, ~x"./tns:Primatelj"e |> add_ns())

    if primatelj do
      oib = xpath(primatelj, ~x"./tns:oibPorezniBroj/text()"s |> add_ns())

      %Party{
        name: xpath(primatelj, ~x"./tns:ime/text()"s |> add_ns()),
        oib: extract_oib(oib),
        tax_id: oib,
        # eFiskalizacija format doesn't include address details for Primatelj
        street: nil,
        city: nil,
        postal_code: nil,
        country: "HR"
      }
    end
  end

  # Extract OIB from tax ID (handles "HR12345678901" format)
  defp extract_oib(nil), do: nil
  defp extract_oib(""), do: nil

  defp extract_oib(tax_id) do
    case Regex.run(~r/(\d{11})/, tax_id) do
      [_, oib] -> oib
      _ -> tax_id
    end
  end

  defp parse_prijenos_sredstava(eracun) do
    # Take first payment means if multiple exist
    prijenos = xpath(eracun, ~x"./tns:PrijenosSredstava"e |> add_ns())

    if prijenos do
      %PaymentMeans{
        iban: xpath(prijenos, ~x"./tns:identifikatorRacunaZaPlacanje/text()"s |> add_ns()),
        # eFiskalizacija doesn't have model/reference in PrijenosSredstava
        model: "HR99",
        reference: "",
        note: xpath(prijenos, ~x"./tns:nazivRacunaZaPlacanje/text()"os |> add_ns())
      }
    else
      # Return default payment means if none specified
      %PaymentMeans{iban: "", model: "HR99", reference: "", note: nil}
    end
  end

  defp parse_stavke(eracun) do
    xpath(eracun, ~x"./tns:StavkaERacuna"el |> add_ns())
    |> Enum.with_index(1)
    |> Enum.map(fn {stavka, index} ->
      %LineItem{
        id: Integer.to_string(index),
        name: xpath(stavka, ~x"./tns:artiklNaziv/text()"s |> add_ns()),
        description: xpath(stavka, ~x"./tns:artiklOpis/text()"os |> add_ns()),
        quantity: xpath(stavka, ~x"./tns:kolicina/text()"s |> add_ns()) |> parse_decimal(),
        unit: xpath(stavka, ~x"./tns:jedinicaMjere/text()"s |> add_ns()),
        unit_price:
          xpath(stavka, ~x"./tns:artiklNetoCijena/text()"s |> add_ns()) |> parse_decimal(),
        line_total: xpath(stavka, ~x"./tns:neto/text()"s |> add_ns()) |> parse_decimal(),
        vat_percent:
          xpath(stavka, ~x"./tns:artiklStopaPdv/text()"os |> add_ns()) |> parse_decimal(),
        vat_category: xpath(stavka, ~x"./tns:artiklKategorijaPdv/text()"s |> add_ns())
      }
    end)
  end

  defp parse_raspodjela_pdv(eracun) do
    xpath(eracun, ~x"./tns:RaspodjelaPdv"el |> add_ns())
    |> Enum.map(fn raspodjela ->
      %TaxSubtotal{
        category: xpath(raspodjela, ~x"./tns:kategorijaPdv/text()"s |> add_ns()),
        percent: xpath(raspodjela, ~x"./tns:stopa/text()"os |> add_ns()) |> parse_decimal(),
        taxable_amount:
          xpath(raspodjela, ~x"./tns:oporeziviIznos/text()"s |> add_ns()) |> parse_decimal(),
        tax_amount:
          xpath(raspodjela, ~x"./tns:iznosPoreza/text()"s |> add_ns()) |> parse_decimal(),
        exemption_reason:
          xpath(raspodjela, ~x"./tns:tekstRazlogaOslobodenja/text()"os |> add_ns())
      }
    end)
  end

  defp parse_dokument_ukupan_iznos(eracun) do
    ukupno = xpath(eracun, ~x"./tns:DokumentUkupanIznos"e |> add_ns())

    if ukupno do
      %Totals{
        line_extension: xpath(ukupno, ~x"./tns:neto/text()"s |> add_ns()) |> parse_decimal(),
        tax_exclusive:
          xpath(ukupno, ~x"./tns:iznosBezPdv/text()"s |> add_ns()) |> parse_decimal(),
        tax_inclusive: xpath(ukupno, ~x"./tns:iznosSPdv/text()"s |> add_ns()) |> parse_decimal(),
        tax_amount: xpath(ukupno, ~x"./tns:pdv/text()"s |> add_ns()) |> parse_decimal(),
        payable:
          xpath(ukupno, ~x"./tns:iznosKojiDospijevaZaPlacanje/text()"s |> add_ns())
          |> parse_decimal(),
        charge_total: xpath(ukupno, ~x"./tns:trosak/text()"os |> add_ns()) |> parse_decimal(),
        allowance_total: xpath(ukupno, ~x"./tns:popust/text()"os |> add_ns()) |> parse_decimal()
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
