defmodule SocialScribe.CRMSuggestions.StrategyBehaviour do
  @moduledoc """
  Provider metadata contract for CRM suggestion orchestration.
  """

  @callback provider() :: String.t()
  @callback field_labels() :: %{required(String.t()) => String.t()}
  @callback contact_key_map() :: %{required(String.t()) => atom()}
  @callback update_key_map() :: %{required(String.t()) => String.t()}
  @callback prompt_field_guidance() :: [{String.t(), String.t()}]
end
