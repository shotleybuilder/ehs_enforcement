defmodule EhsEnforcementWeb.DashboardAuthTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  
  describe "DashboardLive authentication integration" do
    setup do
      # Create test agencies for dashboard functionality
      {:ok, hse_agency} = EhsEnforcement.Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      %{agency: hse_agency}
    end

    test "displays sign-in link when user is not authenticated", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show sign-in link
      assert html =~ "Sign In"
      assert has_element?(view, "a[href='/sign-in']")
    end

    test "shows user information when authenticated as regular user", %{conn: conn} do
      # Create a mock user (without hitting the database)
      user = %{
        id: "test-user-id",
        email: "user@test.com",
        name: "Test User",
        github_login: "testuser",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      # Sign in the user by setting in connection assigns
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show user's name
      assert html =~ "Welcome, Test User"
      # Should show sign-out link
      assert html =~ "Sign Out"
      assert has_element?(view, "a[href='/sign-out']")
      # Should NOT show admin badge
      refute html =~ "ADMIN"
    end

    test "shows admin badge and privileges when authenticated as admin user", %{conn: conn} do
      # Create a mock admin user
      admin_user = %{
        id: "admin-user-id",
        email: "admin@test.com",
        name: "Admin User",
        github_login: "adminuser",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }
      
      # Sign in the admin user
      conn = conn |> assign(:current_user, admin_user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should show user's name
      assert html =~ "Welcome, Admin User"
      # Should show admin badge
      assert html =~ "ADMIN"
      # Should show sign-out link
      assert has_element?(view, "a[href='/sign-out']")
    end

    test "shows admin action buttons only for admin users", %{conn: conn} do
      # Test with regular user first
      regular_user = %{
        id: "regular-user-id",
        email: "user@test.com",
        name: "Regular User",
        github_login: "regularuser",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      conn_regular = conn |> assign(:current_user, regular_user)
      
      {:ok, _view_regular, html_regular} = live(conn_regular, "/dashboard")

      # Should NOT show admin actions for regular user
      refute html_regular =~ "[ADMIN] > Add New Case"
      refute html_regular =~ "[ADMIN] > Add New Notice"

      # Test with admin user
      admin_user = %{
        id: "admin-user-id",
        email: "admin@test.com",
        name: "Admin User", 
        github_login: "adminuser",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }
      
      conn_admin = conn |> assign(:current_user, admin_user)
      
      {:ok, view_admin, html_admin} = live(conn_admin, "/dashboard")

      # Should show admin actions for admin user
      assert html_admin =~ "[ADMIN] > Add New Case"
      assert html_admin =~ "[ADMIN] > Add New Notice"
      
      # Admin buttons should have proper phx-click handlers
      assert has_element?(view_admin, "button[phx-click='navigate_to_new_case']")
      assert has_element?(view_admin, "button[phx-click='navigate_to_new_notice']")
    end

    test "handles nil current_user gracefully", %{conn: conn} do
      # Explicitly set current_user to nil
      conn = conn |> assign(:current_user, nil)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should not crash and show sign-in option
      assert html =~ "Sign In"
      refute html =~ "Welcome,"
      refute html =~ "ADMIN"
      refute html =~ "[ADMIN]"
    end

    test "handles user without admin_checked_at field", %{conn: conn} do
      # Create user without admin_checked_at (simulating older user record)
      user_attrs = %{
        email: "legacy@test.com",
        name: "Legacy User",
        github_login: "legacyuser", 
        is_admin: false
        # No admin_checked_at field
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should handle gracefully
      assert html =~ "Welcome, Legacy User"
      refute html =~ "ADMIN"
    end

    test "updates admin status when admin_checked_at is old", %{conn: conn} do
      # Create user with old admin check
      old_timestamp = DateTime.add(DateTime.utc_now(), -7200, :second) # 2 hours ago
      
      user_attrs = %{
        email: "stale@test.com",
        name: "Stale User",
        github_login: "staleuser",
        is_admin: false,
        admin_checked_at: old_timestamp
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should still display (admin refresh happens in background)
      assert html =~ "Welcome, Stale User"
      # Should not crash due to stale admin status
      assert Process.alive?(view.pid)
    end
  end

  describe "DashboardLive admin privilege enforcement" do
    setup do
      # Create regular and admin users
      {:ok, regular_user} = Accounts.create_user(%{
        email: "regular@test.com",
        name: "Regular User",
        github_login: "regular",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      })

      {:ok, admin_user} = Accounts.create_user(%{
        email: "admin@test.com", 
        name: "Admin User",
        github_login: "admin",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      })

      %{regular_user: regular_user, admin_user: admin_user}
    end

    test "admin action cards are hidden for regular users", %{conn: conn, regular_user: user} do
      conn = conn |> assign(:current_user, user)
      {:ok, view, html} = live(conn, "/dashboard")

      # Cases management card should not show admin actions
      assert html =~ "ENFORCEMENT CASES"
      refute html =~ "[ADMIN] > Add New Case"
      
      # Notices management card should not show admin actions  
      assert html =~ "ENFORCEMENT NOTICES"
      refute html =~ "[ADMIN] > Add New Notice"
    end

    test "admin action cards are visible for admin users", %{conn: conn, admin_user: user} do
      conn = conn |> assign(:current_user, user)
      {:ok, view, html} = live(conn, "/dashboard")

      # Cases management card should show admin actions
      assert html =~ "ENFORCEMENT CASES"
      assert html =~ "[ADMIN] > Add New Case"
      
      # Notices management card should show admin actions
      assert html =~ "ENFORCEMENT NOTICES"  
      assert html =~ "[ADMIN] > Add New Notice"
    end

    test "admin buttons are properly enabled for admin users", %{conn: conn, admin_user: user} do
      conn = conn |> assign(:current_user, user)
      {:ok, view, html} = live(conn, "/dashboard")

      # Admin buttons should not be disabled
      refute html =~ "disabled=\"true\""
      refute html =~ "disabled={true}"
      
      # Should have proper navigation attributes
      assert has_element?(view, "*[navigate='/cases/new']") or
             has_element?(view, "a[href='/cases/new']")
      assert has_element?(view, "*[navigate='/notices/new']") or
             has_element?(view, "a[href='/notices/new']")
    end

    test "handles dynamic admin status changes", %{conn: conn, regular_user: user} do
      # Start with regular user
      conn = conn |> assign(:current_user, user)
      {:ok, view, html_initial} = live(conn, "/dashboard")

      # Should not show admin actions initially
      refute html_initial =~ "[ADMIN]"

      # Simulate user being promoted to admin (would happen via background process)
      updated_user = %{user | is_admin: true}
      
      # Reconnect with updated user
      conn_updated = conn |> assign(:current_user, updated_user)
      {:ok, view_updated, html_updated} = live(conn_updated, "/dashboard")

      # Should now show admin actions
      assert html_updated =~ "[ADMIN] > Add New Case"
      assert html_updated =~ "[ADMIN] > Add New Notice"
      assert html_updated =~ "ADMIN" # Admin badge
    end
  end

  describe "DashboardLive session management" do
    test "handles session expiry gracefully", %{conn: conn} do
      user_attrs = %{
        email: "session@test.com",
        name: "Session User",
        github_login: "sessionuser",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should display user info initially
      assert html =~ "Welcome, Session User"

      # Simulate session expiry by sending nil current_user
      send(view.pid, %Phoenix.Socket.Broadcast{
        topic: "user_sessions:" <> user.id,
        event: "disconnect",
        payload: %{}
      })

      # Should handle gracefully without crashing
      assert Process.alive?(view.pid)
    end

    test "maintains authentication state across page reloads", %{conn: conn} do
      user_attrs = %{
        email: "persistent@test.com",
        name: "Persistent User",
        github_login: "persistent",
        is_admin: true,
        admin_checked_at: DateTime.utc_now()
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      # First load
      {:ok, view1, html1} = live(conn, "/dashboard")
      assert html1 =~ "Welcome, Persistent User"
      assert html1 =~ "ADMIN"

      # Simulate navigation away and back
      {:ok, view2, html2} = live(conn, "/dashboard")
      assert html2 =~ "Welcome, Persistent User"
      assert html2 =~ "ADMIN"
      assert html2 =~ "[ADMIN] > Add New Case"
    end
  end

  describe "DashboardLive GitHub OAuth integration" do
    test "displays GitHub profile information when available", %{conn: conn} do
      user_attrs = %{
        email: "github@test.com",
        name: "GitHub User",
        github_login: "githubuser",
        github_id: "12345",
        avatar_url: "https://github.com/avatars/u/12345",
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should display GitHub username
      assert html =~ "GitHub User"
      
      # May include GitHub profile information (depending on implementation)
      # This test ensures it doesn't crash with GitHub-specific user data
      assert Process.alive?(view.pid)
    end

    test "handles missing GitHub profile data gracefully", %{conn: conn} do
      user_attrs = %{
        email: "minimal@test.com",
        name: "Minimal User",
        # Missing GitHub-specific fields
        is_admin: false,
        admin_checked_at: DateTime.utc_now()
      }
      
      {:ok, user} = Accounts.create_user(user_attrs)
      conn = conn |> assign(:current_user, user)
      
      {:ok, view, html} = live(conn, "/dashboard")

      # Should handle missing GitHub data without errors
      assert html =~ "Welcome, Minimal User"
      assert Process.alive?(view.pid)
    end
  end
end