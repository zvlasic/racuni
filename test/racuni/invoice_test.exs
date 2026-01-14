defmodule Racuni.InvoiceTest do
  use ExUnit.Case, async: true

  alias Racuni.Invoice

  describe "detect_format/1" do
    test "detects UBL 2.1 format by namespace" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2">
      </Invoice>
      """

      assert Invoice.detect_format(xml) == :ubl
    end

    test "detects UBL 2.1 format by CommonBasicComponents" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Invoice xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
      </Invoice>
      """

      assert Invoice.detect_format(xml) == :ubl
    end

    test "detects eFiskalizacija format" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <EvidentirajERacunZahtjev xmlns="http://www.porezna-uprava.gov.hr/fin/2024/types/eFiskalizacija">
      </EvidentirajERacunZahtjev>
      """

      assert Invoice.detect_format(xml) == :efiskalizacija
    end

    test "returns unknown for unrecognized format" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <SomeOtherDocument>
      </SomeOtherDocument>
      """

      assert Invoice.detect_format(xml) == :unknown
    end
  end

  describe "parse/1" do
    test "returns error for unknown format" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <SomeOtherDocument>
      </SomeOtherDocument>
      """

      assert {:error, message} = Invoice.parse(xml)
      assert message =~ "Nepoznat format"
    end
  end
end
