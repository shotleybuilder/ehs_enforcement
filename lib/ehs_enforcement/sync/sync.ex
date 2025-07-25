defmodule EhsEnforcement.Sync do
  @moduledoc """
  The Sync domain for managing synchronization operations and logs.
  """
  
  use Ash.Domain

  resources do
    resource EhsEnforcement.Sync.SyncLog
  end
end