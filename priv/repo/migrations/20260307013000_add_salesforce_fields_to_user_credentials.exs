defmodule SocialScribe.Repo.Migrations.AddSalesforceFieldsToUserCredentials do
  use Ecto.Migration

  def change do
    # Stores Salesforce instance identity and provider-specific metadata.
    alter table(:user_credentials) do
      add :external_account_id, :string
      add :metadata, :map, default: %{}, null: false
    end

    # Prevents duplicate provider connections for the same external Salesforce account.
    create unique_index(:user_credentials, [:user_id, :provider, :external_account_id],
             name: :user_credentials_user_provider_external_account_idx
           )
  end
end
