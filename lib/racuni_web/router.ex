defmodule RacuniWeb.Router do
  use RacuniWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RacuniWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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
