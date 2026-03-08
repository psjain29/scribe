defmodule SocialScribe.CRMSuggestions do
  @moduledoc """
  Orchestrates CRM suggestion generation, merge, and safe update payloads.
  """

  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.CRM
  alias SocialScribe.CRMSuggestions.Registry

  @unsupported_provider_message "Could not complete CRM action. Only HubSpot and Salesforce are supported right now. Reconnect your CRM account in Settings and try again."
  @rate_limited_ai_message "AI suggestions are temporarily rate limited. Kindly request at a lower rate or contact app owner."

  @type suggestion_row :: %{
          field: String.t(),
          label: String.t(),
          existing_value: String.t() | nil,
          suggested_value: String.t() | nil,
          reason: String.t() | nil,
          confidence: number() | nil,
          apply: boolean(),
          has_change: boolean()
        }

  @doc """
  Returns provider-safe message shown for unsupported provider flows.
  """
  def unsupported_provider_message, do: @unsupported_provider_message

  @doc """
  Returns a user-friendly message for CRM suggestion generation failures.
  """
  def suggestion_generation_error_message({:api_error, 429, _body}, _default_message),
    do: @rate_limited_ai_message

  def suggestion_generation_error_message(_reason, default_message), do: default_message

  @doc """
  Generates suggestion rows for the selected contact from one meeting transcript.
  """
  def generate_for_contact(provider, credential, contact_id, meeting) do
    with {:ok, contact} <- CRM.get_contact(credential, contact_id),
         {:ok, ai_suggestions} <- generate_from_meeting(provider, meeting),
         {:ok, suggestion_rows} <- merge_with_contact(provider, ai_suggestions, contact) do
      {:ok, %{contact: contact, suggestion_rows: suggestion_rows}}
    end
  end

  @doc """
  Generates normalized AI suggestions for a provider from meeting transcript data.
  """
  def generate_from_meeting(provider, meeting) do
    with {:ok, strategy} <- Registry.fetch(provider),
         {:ok, ai_suggestions} <-
           AIContentGeneratorApi.generate_crm_suggestions(provider, meeting) do
      {:ok, sanitize_ai_suggestions(strategy, ai_suggestions)}
    end
  end

  @doc """
  Merges normalized AI suggestions with an existing CRM contact.
  """
  def merge_with_contact(provider, ai_suggestions, contact)
      when is_list(ai_suggestions) and is_map(contact) do
    with {:ok, strategy} <- Registry.fetch(provider) do
      rows =
        sanitize_ai_suggestions(strategy, ai_suggestions)
        |> Enum.map(fn suggestion ->
          field = suggestion.field
          existing_value = contact_value(strategy, contact, field)
          suggested_value = trim_or_nil(suggestion.suggested_value)
          has_change = existing_value != suggested_value

          %{
            field: field,
            label: field_label(strategy, field),
            existing_value: existing_value,
            suggested_value: suggested_value,
            reason: suggestion.reason,
            confidence: suggestion.confidence,
            apply: has_change,
            has_change: has_change
          }
        end)
        |> Enum.filter(& &1.has_change)

      {:ok, rows}
    end
  end

  @doc """
  Builds a provider-native CRM update payload from selected suggestion rows.
  """
  def build_update_payload(provider, suggestion_rows) when is_list(suggestion_rows) do
    with {:ok, strategy} <- Registry.fetch(provider) do
      payload =
        Enum.reduce(suggestion_rows, %{}, fn row, acc ->
          apply? = row[:apply] || row["apply"] || false
          has_change? = row[:has_change] || row["has_change"] || false
          field = row[:field] || row["field"]
          suggested_value = trim_or_nil(row[:suggested_value] || row["suggested_value"])
          update_key = strategy.update_key_map() |> Map.get(field)

          cond do
            !apply? -> acc
            !has_change? -> acc
            is_nil(update_key) -> acc
            is_nil(suggested_value) -> acc
            true -> Map.put(acc, update_key, suggested_value)
          end
        end)

      {:ok, payload}
    end
  end

  defp sanitize_ai_suggestions(strategy, ai_suggestions) when is_list(ai_suggestions) do
    allowed_fields = strategy.update_key_map() |> Map.keys() |> MapSet.new()

    ai_suggestions
    |> Enum.reduce([], fn raw, acc ->
      field = normalize_field(raw[:field] || raw["field"])

      suggested_value =
        (raw[:suggested_value] || raw["suggested_value"] || raw[:value] ||
           raw["value"])
        |> trim_or_nil()

      reason =
        (raw[:reason] || raw["reason"] || raw[:context] || raw["context"])
        |> trim_or_nil()

      cond do
        is_nil(field) ->
          acc

        is_nil(suggested_value) ->
          acc

        !MapSet.member?(allowed_fields, field) ->
          acc

        true ->
          [
            %{
              field: field,
              suggested_value: suggested_value,
              reason: trim_or_nil(reason),
              confidence: parse_confidence(raw[:confidence] || raw["confidence"])
            }
            | acc
          ]
      end
    end)
    |> Enum.reverse()
  end

  defp sanitize_ai_suggestions(_strategy, _ai_suggestions), do: []

  defp field_label(strategy, field) do
    strategy.field_labels() |> Map.get(field, field)
  end

  defp contact_value(strategy, contact, field) do
    key = strategy.contact_key_map() |> Map.get(field)

    case key do
      nil -> nil
      _ -> trim_or_nil(Map.get(contact, key))
    end
  end

  defp normalize_field(nil), do: nil

  defp normalize_field(field) when is_binary(field) do
    case field |> String.trim() |> String.downcase() do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_field(_field), do: nil

  defp trim_or_nil(nil), do: nil

  defp trim_or_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim_or_nil(value), do: value

  defp parse_confidence(nil), do: nil
  defp parse_confidence(value) when is_number(value), do: value

  defp parse_confidence(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp parse_confidence(_value), do: nil
end
