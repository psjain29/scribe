defmodule SocialScribe.Repo.Migrations.AddSalesforceFieldsToUserCredentials do
  use Ecto.Migration

  def change do
    alter table(:user_credentials) do
      add :external_account_id, :string
      add :metadata, :map, default: %{}, null: false
    end

    create unique_index(:user_credentials, [:user_id, :provider, :external_account_id],
             name: :user_credentials_user_provider_external_account_idx
           )
  end
end
