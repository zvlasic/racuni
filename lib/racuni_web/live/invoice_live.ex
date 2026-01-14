defmodule RacuniWeb.InvoiceLive do
  use RacuniWeb, :live_view

  alias Racuni.Invoice
  alias Racuni.PDF

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:invoice, nil)
     |> assign(:pdf_data, nil)
     |> assign(:error, nil)
     |> assign(:processing, false)
     |> allow_upload(:xml_file,
       accept: ~w(.xml),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto py-8">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-base-content">Računi</h1>
          <p class="text-base-content/70 mt-2">
            Učitajte UBL 2.1 XML račun i generirajte PDF s HUB3 barkodom za plaćanje
          </p>
        </div>

        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <form id="upload-form" phx-submit="generate" phx-change="validate">
              <div
                class="border-2 border-dashed border-base-content/20 rounded-lg p-8 text-center hover:border-primary/50 transition-colors"
                phx-drop-target={@uploads.xml_file.ref}
              >
                <.live_file_input upload={@uploads.xml_file} class="hidden" />

                <div class="flex flex-col items-center gap-4">
                  <.icon name="hero-document-arrow-up" class="w-12 h-12 text-base-content/50" />

                  <div>
                    <label
                      for={@uploads.xml_file.ref}
                      class="btn btn-primary btn-outline cursor-pointer"
                    >
                      Odaberi XML datoteku
                    </label>
                    <p class="text-sm text-base-content/50 mt-2">
                      ili povuci i ispusti ovdje
                    </p>
                  </div>
                </div>

                <%= for entry <- @uploads.xml_file.entries do %>
                  <div class="mt-4 flex items-center justify-center gap-4">
                    <.icon name="hero-document-text" class="w-6 h-6 text-success" />
                    <span class="font-medium"><%= entry.client_name %></span>
                    <span class="text-sm text-base-content/50">
                      (<%= format_bytes(entry.client_size) %>)
                    </span>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="btn btn-ghost btn-xs btn-circle"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>

                  <%= for err <- upload_errors(@uploads.xml_file, entry) do %>
                    <p class="text-error text-sm mt-2"><%= error_to_string(err) %></p>
                  <% end %>
                <% end %>
              </div>

              <%= if @error do %>
                <div class="alert alert-error mt-4">
                  <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                  <span><%= @error %></span>
                </div>
              <% end %>

              <div class="mt-6 flex justify-center gap-4">
                <button
                  type="submit"
                  class={["btn btn-primary", @processing && "loading"]}
                  disabled={@uploads.xml_file.entries == [] or @processing}
                >
                  <%= if @processing do %>
                    Generiranje...
                  <% else %>
                    <.icon name="hero-document-text" class="w-5 h-5" />
                    Generiraj PDF
                  <% end %>
                </button>

                <%= if @pdf_data do %>
                  <button
                    type="button"
                    phx-click="download"
                    class="btn btn-success"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                    Preuzmi PDF
                  </button>
                <% end %>
              </div>
            </form>
          </div>
        </div>

        <%= if @invoice do %>
          <div class="card bg-base-200 shadow-xl mt-8">
            <div class="card-body">
              <h2 class="card-title">
                <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
                Račun uspješno učitan
              </h2>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
                <div>
                  <h3 class="font-semibold text-base-content/70 mb-2">Izdavatelj</h3>
                  <p class="font-medium"><%= @invoice.supplier.name %></p>
                  <p class="text-sm"><%= @invoice.supplier.street %></p>
                  <p class="text-sm">
                    <%= @invoice.supplier.postal_code %> <%= @invoice.supplier.city %>
                  </p>
                  <p class="text-sm">OIB: <%= @invoice.supplier.oib %></p>
                </div>

                <div>
                  <h3 class="font-semibold text-base-content/70 mb-2">Kupac</h3>
                  <p class="font-medium"><%= @invoice.customer.name %></p>
                  <p class="text-sm"><%= @invoice.customer.street %></p>
                  <p class="text-sm">
                    <%= @invoice.customer.postal_code %> <%= @invoice.customer.city %>
                  </p>
                  <p class="text-sm">OIB: <%= @invoice.customer.oib %></p>
                </div>
              </div>

              <div class="divider"></div>

              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <span class="text-sm text-base-content/70">Broj računa</span>
                  <p class="font-medium"><%= @invoice.id %></p>
                </div>
                <div>
                  <span class="text-sm text-base-content/70">Datum izdavanja</span>
                  <p class="font-medium"><%= format_date(@invoice.issue_date) %></p>
                </div>
                <div>
                  <span class="text-sm text-base-content/70">Rok plaćanja</span>
                  <p class="font-medium"><%= format_date(@invoice.due_date) %></p>
                </div>
                <div>
                  <span class="text-sm text-base-content/70">Iznos za platiti</span>
                  <p class="font-medium text-lg">
                    <%= format_amount(@invoice.totals.payable) %> <%= @invoice.currency %>
                  </p>
                </div>
              </div>

              <div class="divider"></div>

              <h3 class="font-semibold text-base-content/70 mb-2">
                Stavke (<%= length(@invoice.line_items) %>)
              </h3>

              <div class="overflow-x-auto">
                <table class="table table-zebra table-sm">
                  <thead>
                    <tr>
                      <th>Naziv</th>
                      <th class="text-right">Količina</th>
                      <th class="text-right">Cijena</th>
                      <th class="text-right">Iznos</th>
                      <th class="text-right">PDV</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for item <- @invoice.line_items do %>
                      <tr>
                        <td><%= item.name %></td>
                        <td class="text-right">
                          <%= format_amount(item.quantity) %> <%= format_unit(item.unit) %>
                        </td>
                        <td class="text-right"><%= format_amount(item.unit_price) %></td>
                        <td class="text-right"><%= format_amount(item.line_total) %></td>
                        <td class="text-right"><%= format_amount(item.vat_percent) %>%</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :xml_file, ref)}
  end

  @impl true
  def handle_event("generate", _params, socket) do
    socket = assign(socket, :processing, true)
    socket = assign(socket, :error, nil)

    uploaded_files =
      consume_uploaded_entries(socket, :xml_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case uploaded_files do
      [xml_content] when is_binary(xml_content) ->
        case process_invoice(xml_content) do
          {:ok, invoice, pdf_binary} ->
            {:noreply,
             socket
             |> assign(:invoice, invoice)
             |> assign(:pdf_data, Base.encode64(pdf_binary))
             |> assign(:processing, false)
             |> put_flash(:info, "PDF uspješno generiran!")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:error, reason)
             |> assign(:processing, false)}
        end

      [] ->
        {:noreply,
         socket
         |> assign(:error, "Molimo odaberite XML datoteku")
         |> assign(:processing, false)}

      _other ->
        {:noreply,
         socket
         |> assign(:error, "Greška pri čitanju datoteke")
         |> assign(:processing, false)}
    end
  end

  @impl true
  def handle_event("download", _params, socket) do
    if socket.assigns.pdf_data do
      filename = "racun-#{socket.assigns.invoice.id}.pdf"

      {:noreply,
       push_event(socket, "download", %{
         data: socket.assigns.pdf_data,
         filename: filename,
         content_type: "application/pdf"
       })}
    else
      {:noreply, socket}
    end
  end

  defp process_invoice(xml_content) do
    with {:ok, invoice} <- Invoice.parse(xml_content),
         {:ok, pdf_binary} <- PDF.generate(invoice) do
      {:ok, invoice, pdf_binary}
    else
      {:error, reason} -> {:error, "Greška: #{reason}"}
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d.%m.%Y")

  defp format_amount(nil), do: "-"
  defp format_amount(%Decimal{} = d), do: Decimal.to_string(d, :normal)

  @unit_codes %{
    "H87" => "kom",
    "PCE" => "kom",
    "EA" => "kom",
    "HUR" => "sat",
    "DAY" => "dan",
    "MON" => "mj",
    "KGM" => "kg",
    "LTR" => "l",
    "MTR" => "m"
  }

  defp format_unit(nil), do: ""
  defp format_unit(code), do: Map.get(@unit_codes, code, code)

  defp error_to_string(:too_large), do: "Datoteka je prevelika (max 5 MB)"
  defp error_to_string(:not_accepted), do: "Nepodržani format datoteke (samo .xml)"
  defp error_to_string(:too_many_files), do: "Možete učitati samo jednu datoteku"
  defp error_to_string(err), do: "Greška: #{inspect(err)}"
end
