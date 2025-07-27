defmodule EhsEnforcementWeb.PageControllerTest do
  use EhsEnforcementWeb.ConnCase

  test "GET /home", %{conn: conn} do
    conn = get(conn, ~p"/home")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production."
  end
end
