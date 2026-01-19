defmodule RacuniWeb.Router do
  use RacuniWeb, :router
  use Honeybadger.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RacuniWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' wss:"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RacuniWeb do
    pipe_through :browser

    live "/", InvoiceLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", RacuniWeb do
  #   pipe_through :api
  # end
end
