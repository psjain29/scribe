defmodule SocialScribe.AIContentGenerator do
  @moduledoc "Generates content using Google Gemini."

  @behaviour SocialScribe.AIContentGeneratorApi

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.CRMSuggestions.Registry

  require Logger

  # gemini-2.5-flash is used because gemini-2.0-flash-lite returned 0 free-tier quota
  # and frequent 429 rate-limit errors in this region/project during local validation.
  # if needed select appropriate model with active limits in Google AI Studio as per quota available
  #todo update back to models that are not rate limited - once manual QA done
  @gemini_model "gemini-2.0-flash-lite"
  @gemini_api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl SocialScribe.AIContentGeneratorApi
  def generate_follow_up_email(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        Based on the following meeting transcript, please draft a concise and professional follow-up email.
        The email should summarize the key discussion points and clearly list any action items assigned, including who is responsible if mentioned.
        Keep the tone friendly and action-oriented.

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_automation(automation, meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        #{Automations.generate_prompt_for_automation(automation)}

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_crm_suggestions(provider, meeting) do
    with {:ok, strategy} <- Registry.fetch(provider),
         {:ok, meeting_prompt} <- Meetings.generate_prompt_for_meeting(meeting),
         {:ok, response} <-
           call_gemini(crm_suggestions_prompt(provider, strategy, meeting_prompt)) do
      {:ok, parse_crm_suggestions(response)}
    end
  end

  defp crm_suggestions_prompt(provider, strategy, meeting_prompt) do
    allowed_fields =
      strategy.update_key_map()
      |> Map.keys()
      |> Enum.join(", ")

    field_guidance =
      strategy.prompt_field_guidance()
      |> Enum.map_join("\n", fn {field, description} -> "- #{field}: #{description}" end)

    """
    You are an AI assistant that extracts CRM contact updates from meeting transcripts.

    CRM provider: #{provider}
    Allowed fields: #{allowed_fields}
    Field guidance:
    #{field_guidance}

    IMPORTANT:
    - Only return values explicitly mentioned in the transcript.
    - Do not infer or guess.
    - Use only the allowed field names listed above.

    Return valid JSON only, no markdown and no extra text.
    Response schema:
    [
      {
        "field": "allowed_field_name",
        "suggested_value": "value from transcript",
        "reason": "short quote or summary from transcript",
        "confidence": 0.0
      }
    ]

    If no updates are found, return [].

    Meeting transcript:
    #{meeting_prompt}
    """
  end

  defp parse_crm_suggestions(response) when is_binary(response) do
    response
    |> clean_json_response()
    |> Jason.decode()
    |> case do
      {:ok, parsed} when is_list(parsed) ->
        parsed
        |> Enum.filter(&is_map/1)
        |> Enum.map(fn item ->
          %{
            field: item["field"],
            suggested_value: item["suggested_value"] || item["value"],
            reason: item["reason"] || item["context"],
            confidence: item["confidence"]
          }
        end)
        |> Enum.filter(fn suggestion ->
          is_binary(suggestion.field) and String.trim(suggestion.field) != "" and
            is_binary(suggestion.suggested_value) and
            String.trim(suggestion.suggested_value) != ""
        end)

      {:ok, _other} ->
        []

      {:error, error} ->
        Logger.warning("Failed to parse CRM suggestions JSON: #{inspect(error)}")
        []
    end
  end

  defp parse_crm_suggestions(_response), do: []

  defp clean_json_response(response) do
    response
    |> String.trim()
    |> String.replace(~r/^```json\s*/i, "")
    |> String.replace(~r/\s*```$/, "")
    |> String.trim()
  end

  defp call_gemini(prompt_text) do
    api_key = Application.get_env(:social_scribe, :gemini_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, {:config_error, "Gemini API key is missing - set GEMINI_API_KEY env var"}}
    else
      path = "/#{@gemini_model}:generateContent?key=#{api_key}"

      payload = %{
        contents: [
          %{
            parts: [%{text: prompt_text}]
          }
        ]
      }

      case Tesla.post(client(), path, payload) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          text_path = [
            "candidates",
            Access.at(0),
            "content",
            "parts",
            Access.at(0),
            "text"
          ]

          case get_in(body, text_path) do
            nil -> {:error, {:parsing_error, "No text content found in Gemini response", body}}
            text_content -> {:ok, text_content}
          end

        {:ok, %Tesla.Env{status: status, body: error_body}} ->
          {:error, {:api_error, status, error_body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @gemini_api_base_url},
      Tesla.Middleware.JSON
    ])
  end
end
