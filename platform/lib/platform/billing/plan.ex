defmodule Platform.Billing.Plan do
  @moduledoc """
  This module defines a struct for a billing plan. It provides information about
  what a user is allowed to do based on their plan, as well as information about
  the plan itself.
  """
  defstruct [:allowed_api, :allowed_edits_per_30d_period, :is_organizational, :name, :is_free]
end
