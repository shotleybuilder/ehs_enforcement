defmodule EhsEnforcementWeb.Plugs.AuthHelpers do
  @moduledoc """
  Authentication helper plugs for Ash Authentication integration.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  alias EhsEnforcement.Accounts.User
  
  def load_from_session(conn, _opts) do
    case AshAuthentication.Phoenix.Plug.retrieve_from_session(conn, otp_app: :ehs_enforcement) do
      {conn, nil} -> 
        assign(conn, :current_user, nil)
      {conn, user} -> 
        conn
        |> assign(:current_user, user)
        |> maybe_refresh_admin_status(user)
    end
  end
  
  def load_from_bearer(conn, _opts) do
    case AshAuthentication.Phoenix.Plug.retrieve_from_bearer(conn, otp_app: :ehs_enforcement) do
      {conn, nil} -> 
        assign(conn, :current_user, nil)
      {conn, user} -> 
        assign(conn, :current_user, user)
    end
  end
  
  def require_authenticated_user(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:info, "Please sign in to continue")
        |> redirect(to: "/sign-in")
        |> halt()
      _user ->
        conn
    end
  end
  
  def require_admin_user(conn, _opts) do
    user = conn.assigns[:current_user]
    
    case user do
      %{is_admin: true} ->
        conn
      _ ->
        conn
        |> put_status(:forbidden)
        |> put_flash(:error, "Admin privileges required")
        |> redirect(to: "/")
        |> halt()
    end
  end
  
  # Private helper functions
  
  defp maybe_refresh_admin_status(conn, user) do
    # Check if admin status needs refresh (older than 1 hour)
    needs_refresh = is_nil(user.admin_checked_at) or 
                   DateTime.diff(DateTime.utc_now(), user.admin_checked_at, :second) > 3600
    
    if needs_refresh do
      # Refresh admin status in the background
      Task.start(fn -> refresh_user_admin_status(user) end)
    end
    
    conn
  end
  
  defp refresh_user_admin_status(user) do
    is_admin = check_github_repository_permissions(user)
    
    case Ash.update(user, :update_admin_status, %{is_admin: is_admin}) do
      {:ok, _updated_user} ->
        :ok
      {:error, error} ->
        require Logger
        Logger.error("Failed to update admin status for user #{user.id}: #{inspect(error)}")
    end
  end
  
  defp check_github_repository_permissions(user) do
    config = Application.get_env(:ehs_enforcement, :github_admin, %{})
    
    case config do
      %{owner: owner, repo: repo, access_token: token} when not is_nil(token) ->
        check_user_repository_access(user.github_login, owner, repo, token)
      %{allowed_users: allowed_users} when is_list(allowed_users) ->
        user.github_login in allowed_users
      _ ->
        false
    end
  end
  
  defp check_user_repository_access(username, owner, repo, access_token) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/collaborators/#{username}"
    
    headers = [
      {"Authorization", "token #{access_token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "EHS-Enforcement-App"}
    ]
    
    case Req.get(url, headers: headers) do
      {:ok, %{status: 204}} -> true
      {:ok, %{status: 404}} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  end
end