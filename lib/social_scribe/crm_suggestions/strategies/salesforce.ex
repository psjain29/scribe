defmodule SocialScribe.CRMSuggestions.Strategies.Salesforce do
  @moduledoc """
  Salesforce-specific CRM suggestion metadata.
  """

  @behaviour SocialScribe.CRMSuggestions.StrategyBehaviour

  @field_labels %{
    "firstname" => "First Name",
    "lastname" => "Last Name",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "Mobile Phone",
    "title" => "Title",
    "mailing_street" => "Mailing Street",
    "mailing_city" => "Mailing City",
    "mailing_state" => "Mailing State",
    "mailing_postal_code" => "Mailing Postal Code",
    "mailing_country" => "Mailing Country"
  }

  @contact_key_map %{
    "firstname" => :firstname,
    "lastname" => :lastname,
    "email" => :email,
    "phone" => :phone,
    "mobilephone" => :mobilephone,
    "title" => :title,
    "mailing_street" => :mailing_street,
    "mailing_city" => :mailing_city,
    "mailing_state" => :mailing_state,
    "mailing_postal_code" => :mailing_postal_code,
    "mailing_country" => :mailing_country
  }

  @update_key_map %{
    "firstname" => "FirstName",
    "lastname" => "LastName",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "MobilePhone",
    "title" => "Title",
    "mailing_street" => "MailingStreet",
    "mailing_city" => "MailingCity",
    "mailing_state" => "MailingState",
    "mailing_postal_code" => "MailingPostalCode",
    "mailing_country" => "MailingCountry"
  }

  @prompt_field_guidance [
    {"firstname", "First name"},
    {"lastname", "Last name"},
    {"email", "Email address"},
    {"phone", "Primary phone number"},
    {"mobilephone", "Mobile phone number"},
    {"title", "Job title"},
    {"mailing_street", "Street address"},
    {"mailing_city", "City"},
    {"mailing_state", "State"},
    {"mailing_postal_code", "Postal code"},
    {"mailing_country", "Country"}
  ]

  @impl true
  def provider, do: "salesforce"

  @impl true
  def field_labels, do: @field_labels

  @impl true
  def contact_key_map, do: @contact_key_map

  @impl true
  def update_key_map, do: @update_key_map

  @impl true
  def prompt_field_guidance, do: @prompt_field_guidance
end
