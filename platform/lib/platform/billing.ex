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

      cond do
        "Complimentary" in user.billing_flags ->
          %Platform.Billing.Plan{
            allowed_api: true,
            allowed_edits_per_30d_period: :unlimited,
            is_organizational: false,
            name: "Complimentary",
            managed_by_stripe: false,
            is_free: false
          }

        Enum.any?(user.billing_flags, fn flag ->
          String.starts_with?(flag, "Organization/")
        end) ->
          flag =
            Enum.find(user.billing_flags, fn flag ->
              String.starts_with?(flag, "Organization/")
            end)

          org_name = String.replace(flag, "Organization/", "")

          %Platform.Billing.Plan{
            allowed_api: true,
            allowed_edits_per_30d_period: :unlimited,
            is_organizational: true,
            name: "Pro (via #{org_name})",
            managed_by_stripe: false,
            is_free: false
          }

        true ->
          case Map.get(user.billing_subscriptions, "data", []) do
            [] ->
              # If the user's sign up date is before Feb 10, 2024, they get a free plan with unlimited edits.

              if NaiveDateTime.compare(
                   user.inserted_at,
                   DateTime.from_naive!(~N[2020-02-01 00:00:00], "Etc/UTC")
                 ) == :lt do
                %Platform.Billing.Plan{
                  allowed_api: false,
                  allowed_edits_per_30d_period: :unlimited,
                  is_organizational: false,
                  name: "Free (early adopter)",
                  managed_by_stripe: false,
                  is_free: true
                }
              else
                %Platform.Billing.Plan{
                  allowed_api: false,
                  allowed_edits_per_30d_period: 10,
                  is_organizational: false,
                  name: "Free",
                  managed_by_stripe: false,
                  is_free: true
                }
              end

            [_ | _] ->
              %Platform.Billing.Plan{
                allowed_api: true,
                allowed_edits_per_30d_period: :unlimited,
                is_organizational: false,
                name: "Pro",
                managed_by_stripe: true,
                is_free: false
              }
          end
      end
    end
  end

  def has_user_exceeded_edit_limit?(%Accounts.User{} = user) do
    case get_user_plan(user) do
      %Platform.Billing.Plan{allowed_edits_per_30d_period: :unlimited} ->
        false

      %Platform.Billing.Plan{allowed_edits_per_30d_period: limit} ->
        case Platform.Updates.get_total_updates_by_user_over_30d(user) do
          count when count >= limit ->
            true

          _ ->
            false
        end
    end
  end

  def get_billing_flags() do
    [
      "Complimentary"
    ] ++ Platform.Accounts.get_all_billing_flags()
  end
end
