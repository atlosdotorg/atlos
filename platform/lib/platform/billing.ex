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

  def update_stripe_customer_information_for_user(%Accounts.User{billing_customer_id: nil} = user) do
    case Req.post("https://api.stripe.com/v1/customers",
           auth: {:bearer, get_secret_key()},
           form: [email: user.email, description: "Username: #{user.username}, ID: #{user.id}"]
         ) do
      {:ok, response} ->
        data = response.body

        Platform.Accounts.update_user_billing(user, %{
          billing_customer_id: data["id"],
          billing_info: data
        })

      {:error, _} ->
        {:error, "Failed to create customer"}
    end
  end

  def update_stripe_customer_information_for_user(user) do
    case Req.get("https://api.stripe.com/v1/customers/#{user.billing_customer_id}",
           auth: {:bearer, get_secret_key()},
           form: [email: user.email, description: "Username: #{user.username}, ID: #{user.id}"]
         ) do
      {:ok, response} ->
        data = response.body
        Platform.Accounts.update_user_billing(user, %{billing_info: data})

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
    # curl https://api.stripe.com/v1/billing_portal/sessions \
    # -u "sk...:" \
    # -d customer={{USER_ID}} \
    # --data-urlencode return_url="https://platform.atlos.org/settings"
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
end
