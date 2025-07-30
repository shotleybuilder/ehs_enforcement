defmodule EhsEnforcementWeb.AuthController do
  @moduledoc """
  Handles Ash Authentication callbacks and user session management.
  """
  
  use EhsEnforcementWeb, :controller
  use AshAuthentication.Phoenix.Controller
  
  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user) 
    |> put_flash(:info, "Welcome #{user.display_name || user.github_login}!")
    |> redirect(to: "/")
  end

  def failure(conn, _activity, reason) do
    conn
    |> put_flash(:error, "Authentication failed: #{reason}")
    |> redirect(to: "/")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:ehs_enforcement)
    |> put_flash(:info, "Successfully signed out")
    |> redirect(to: "/")
  end
end