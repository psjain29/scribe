defmodule SocialScribe.CRMSuggestions.Registry do
  @moduledoc """
  Resolves CRM suggestion strategy modules from runtime provider configuration.
  """

  @doc """
  Fetches the strategy module for the given provider.
  """
  def fetch(provider) when is_binary(provider) do
    provider =
      provider
      |> String.trim()
      |> String.downcase()

    strategies = Application.get_env(:social_scribe, :crm_suggestion_strategies, %{})

    case Map.get(strategies, provider) do
      nil -> {:error, {:unsupported_provider, provider}}
      strategy -> {:ok, strategy}
    end
  end

  def fetch(_provider), do: {:error, {:unsupported_provider, nil}}
end
