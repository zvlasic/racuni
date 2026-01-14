defmodule RacuniWeb.PageController do
  use RacuniWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
