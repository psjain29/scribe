defmodule SocialScribe.CRMSuggestions.Strategies.Hubspot do
  @moduledoc """
  HubSpot-specific CRM suggestion metadata.
  """

  @behaviour SocialScribe.CRMSuggestions.StrategyBehaviour

  @field_labels %{
    "firstname" => "First Name",
    "lastname" => "Last Name",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "Mobile Phone",
    "company" => "Company",
    "jobtitle" => "Job Title",
    "address" => "Address",
    "city" => "City",
    "state" => "State",
    "zip" => "ZIP Code",
    "country" => "Country",
    "website" => "Website",
    "linkedin_url" => "LinkedIn",
    "twitter_handle" => "Twitter"
  }

  @contact_key_map %{
    "firstname" => :firstname,
    "lastname" => :lastname,
    "email" => :email,
    "phone" => :phone,
    "mobilephone" => :mobilephone,
    "company" => :company,
    "jobtitle" => :jobtitle,
    "address" => :address,
    "city" => :city,
    "state" => :state,
    "zip" => :zip,
    "country" => :country,
    "website" => :website,
    "linkedin_url" => :linkedin_url,
    "twitter_handle" => :twitter_handle
  }

  @update_key_map %{
    "firstname" => "firstname",
    "lastname" => "lastname",
    "email" => "email",
    "phone" => "phone",
    "mobilephone" => "mobilephone",
    "company" => "company",
    "jobtitle" => "jobtitle",
    "address" => "address",
    "city" => "city",
    "state" => "state",
    "zip" => "zip",
    "country" => "country",
    "website" => "website",
    "linkedin_url" => "hs_linkedin_url",
    "twitter_handle" => "twitterhandle"
  }

  @prompt_field_guidance [
    {"firstname", "First name"},
    {"lastname", "Last name"},
    {"email", "Email address"},
    {"phone", "Primary phone number"},
    {"mobilephone", "Mobile phone number"},
    {"company", "Company name"},
    {"jobtitle", "Job title or role"},
    {"address", "Street address"},
    {"city", "City"},
    {"state", "State"},
    {"zip", "ZIP or postal code"},
    {"country", "Country"},
    {"website", "Website URL"},
    {"linkedin_url", "LinkedIn profile URL"},
    {"twitter_handle", "Twitter/X handle"}
  ]

  @impl true
  def provider, do: "hubspot"

  @impl true
  def field_labels, do: @field_labels

  @impl true
  def contact_key_map, do: @contact_key_map

  @impl true
  def update_key_map, do: @update_key_map

  @impl true
  def prompt_field_guidance, do: @prompt_field_guidance
end
