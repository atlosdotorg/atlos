defmodule Platform.Billing do
  @moduledoc """
  This module is responsible for billing related operations.
  """

  alias Platform.Accounts

  def is_enabled? do
    System.get_env("BILLING_ENABLED") == "true"
  end

  def get_pricing_table_id() do
    System.get_env("STRIPE_PRICING_TABLE_ID")
  end

  def get_publishable_key() do
    System.get_env("STRIPE_PUBLISHABLE_KEY")
  end

  defp get_secret_key() do
    System.get_env("STRIPE_SECRET_KEY")
  end

  defp get_user_subscriptions(%Accounts.User{} = user) do
    case Req.get("https://api.stripe.com/v1/subscriptions",
           auth: {:bearer, get_secret_key()},
           params: [customer: user.billing_customer_id]
         ) do
      {:ok, response} ->
        response.body

      {:error, _} ->
        []
    end
  end

  def update_stripe_customer_information_for_user(%Accounts.User{billing_customer_id: nil} = user) do
    case Req.post("https://api.stripe.com/v1/customers",
           auth: {:bearer, get_secret_key()},
           form: [email: user.email, description: "Username: #{user.username}, ID: #{user.id}"]
         ) do
      {:ok, response} ->
        data = response.body

        Platform.Accounts.update_user_billing(user, %{
          billing_customer_id: data["id"],
          billing_info: data,
          billing_expires_at: DateTime.utc_now() |> DateTime.add(24, :hour),
          billing_subscriptions: get_user_subscriptions(%{user | billing_customer_id: data["id"]})
        })

      {:error, _} ->
        {:error, "Failed to create customer"}
    end
  end

  def update_stripe_customer_information_for_user(user) do
    case Req.post("https://api.stripe.com/v1/customers/#{user.billing_customer_id}",
           auth: {:bearer, get_secret_key()},
           form: [email: user.email, description: "Username: #{user.username}, ID: #{user.id}"]
         ) do
      {:ok, response} ->
        data = response.body

        Platform.Accounts.update_user_billing(user, %{
          billing_info: data,
          billing_expires_at: DateTime.utc_now() |> DateTime.add(24, :hour),
          billing_subscriptions: get_user_subscriptions(user)
        })

      {:error, _} ->
        {:error, "Failed to get customer information"}
    end
  end

  def get_customer_session_client_secret(%Accounts.User{} = user) do
    {:ok, user} = update_stripe_customer_information_for_user(user)

    case Req.post("https://api.stripe.com/v1/customer_sessions",
           auth: {:bearer, get_secret_key()},
           form: [customer: user.billing_customer_id, "components[pricing_table][enabled]": true]
         ) do
      {:ok, response} ->
        {:ok, response.body["client_secret"]}

      {:error, _} ->
        {:error, "Failed to get customer session URL"}
    end
  end

  def get_portal_url(%Accounts.User{} = user) do
    {:ok, user} = update_stripe_customer_information_for_user(user)

    case Req.post("https://api.stripe.com/v1/billing_portal/sessions",
           auth: {:bearer, get_secret_key()},
           form: [
             customer: user.billing_customer_id,
             return_url: "#{PlatformWeb.Endpoint.url()}/settings"
           ]
         ) do
      {:ok, response} ->
        {:ok, response.body["url"]}

      {:error, _} ->
        {:error, "Failed to get customer portal URL"}
    end
  end

  @doc """
  This is the main function from which we pull the user's entitlements.
  """
  def get_user_plan(%Accounts.User{} = user) do
    if not is_enabled?() do
      %Platform.Billing.Plan{
        allowed_api: true,
        allowed_edits_per_30d_period: :unlimited,
        is_organizational: false,
        name: "(Billing disabled)",
        is_free: false
      }
    else
      user =
        if is_nil(user.billing_expires_at) or user.billing_expires_at < DateTime.utc_now() do
          {:ok, user} = update_stripe_customer_information_for_user(user)
          user
        else
          user
        end

      case Map.get(user.billing_subscriptions, "data", []) do
        [] ->
          %Platform.Billing.Plan{
            allowed_api: true,
            allowed_edits_per_30d_period: :unlimited,
            is_organizational: false,
            name: "Free",
            is_free: true
          }

        [_ | _] ->
          %Platform.Billing.Plan{
            allowed_api: true,
            allowed_edits_per_30d_period: :unlimited,
            is_organizational: false,
            name: "Pro",
            is_free: false
          }
      end
    end
  end
end
