defmodule SocialScribe.Accounts.UserCredential do
  @moduledoc """
  Persists OAuth credentials for social and CRM provider connections.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "user_credentials" do
    field :token, :string
    field :uid, :string
    field :provider, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :email, :string
    field :external_account_id, :string
    field :metadata, :map, default: %{}

    belongs_to :user, SocialScribe.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds the base credential changeset used by provider upserts.
  """
  def changeset(user_credential, attrs) do
    changeset =
      user_credential
      |> cast(attrs, [
        :provider,
        :uid,
        :token,
        :refresh_token,
        :expires_at,
        :user_id,
        :email,
        :external_account_id,
        :metadata
      ])
      |> validate_required([:provider, :uid, :token, :expires_at, :user_id, :email])

    changeset
    |> put_change(:metadata, normalize_metadata(get_field(changeset, :metadata)))
    |> unique_constraint(:external_account_id,
      name: :user_credentials_user_provider_external_account_idx
    )
  end

  @doc """
  Backward-compatible changeset kept for legacy LinkedIn flows.
  """
  def linkedin_changeset(user_credential, attrs) do
    user_credential
    |> cast(attrs, [:provider, :uid, :token, :refresh_token, :expires_at, :user_id, :email])
    |> validate_required([:provider, :uid, :token, :expires_at, :user_id, :email])
  end

  # Ensure downstream code always receives a map for metadata.
  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: %{}
end
