defmodule RacuniWeb.PageControllerTest do
  use RacuniWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Računi"
  end
end
