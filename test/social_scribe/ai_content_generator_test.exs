defmodule SocialScribe.AIContentGeneratorTest do
  use SocialScribe.DataCase

  import SocialScribe.MeetingsFixtures
  import Tesla.Mock

  alias SocialScribe.AIContentGenerator
  alias SocialScribe.Meetings

  setup do
    original_adapter = Application.get_env(:tesla, :adapter)
    original_api_key = Application.get_env(:social_scribe, :gemini_api_key)

    Application.put_env(:tesla, :adapter, Tesla.Mock)
    Application.put_env(:social_scribe, :gemini_api_key, "test_gemini_key")

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, original_adapter)
      Application.put_env(:social_scribe, :gemini_api_key, original_api_key)
    end)

    :ok
  end

  test "generate_crm_suggestions/2 parses fenced JSON responses" do
    meeting = meeting_with_prompt_data_fixture()

    mock(fn
      %{
        method: :post,
        url:
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=test_gemini_key",
        body: body
      } ->
        assert prompt_text_from_body(body) =~ "CRM provider: salesforce"

        %Tesla.Env{
          status: 200,
          body: %{
            "candidates" => [
              %{
                "content" => %{
                  "parts" => [
                    %{
                      "text" => """
                      ```json
                      [
                        {"field":"phone","suggested_value":"7778889999","reason":"Client shared a new phone number","confidence":0.9}
                      ]
                      ```
                      """
                    }
                  ]
                }
              }
            ]
          }
        }
    end)

    assert {:ok, [%{field: "phone", suggested_value: "7778889999"} = suggestion]} =
             AIContentGenerator.generate_crm_suggestions("salesforce", meeting)

    assert suggestion.reason == "Client shared a new phone number"
    assert suggestion.confidence == 0.9
  end

  test "generate_crm_suggestions/2 returns empty list for malformed AI JSON" do
    meeting = meeting_with_prompt_data_fixture()

    mock(fn
      %{
        method: :post,
        url:
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=test_gemini_key"
      } ->
        %Tesla.Env{
          status: 200,
          body: %{
            "candidates" => [
              %{
                "content" => %{
                  "parts" => [%{"text" => "not valid json"}]
                }
              }
            ]
          }
        }
    end)

    assert {:ok, []} = AIContentGenerator.generate_crm_suggestions("salesforce", meeting)
  end

  defp meeting_with_prompt_data_fixture do
    meeting = meeting_fixture(%{title: "CRM Suggestion Test Meeting"})

    meeting_participant_fixture(%{
      meeting_id: meeting.id,
      recall_participant_id: "participant-123",
      name: "Taylor Client",
      is_host: false
    })

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Taylor Client",
            "words" => [
              %{"text" => "Please"},
              %{"text" => "update"},
              %{"text" => "my"},
              %{"text" => "phone"},
              %{"text" => "to"},
              %{"text" => "7778889999"}
            ]
          }
        ]
      }
    })

    Meetings.get_meeting_with_details(meeting.id)
  end

  defp prompt_text_from_body(body) when is_map(body) do
    get_in(body, [:contents, Access.at(0), :parts, Access.at(0), :text]) ||
      get_in(body, ["contents", Access.at(0), "parts", Access.at(0), "text"]) ||
      ""
  end

  defp prompt_text_from_body(body) when is_binary(body) do
    body
    |> Jason.decode!()
    |> prompt_text_from_body()
  end
end
