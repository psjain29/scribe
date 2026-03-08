defmodule SocialScribe.CRMSuggestionsTest do
  use ExUnit.Case, async: true

  import Mox

  alias SocialScribe.CRMSuggestions

  setup :verify_on_exit!

  test "generate_from_meeting sanitizes AI suggestions using provider strategy" do
    SocialScribe.AIContentGeneratorMock
    |> expect(:generate_crm_suggestions, fn provider, meeting ->
      assert provider == "hubspot"
      assert meeting == %{id: 1}

      {:ok,
       [
         %{"field" => " PHONE ", "suggested_value" => "5551234567", "reason" => "Phone shared"},
         %{"field" => "unknown_field", "suggested_value" => "ignored"},
         %{"field" => "email", "suggested_value" => "   "}
       ]}
    end)

    assert {:ok, [row]} = CRMSuggestions.generate_from_meeting("hubspot", %{id: 1})
    assert row.field == "phone"
    assert row.suggested_value == "5551234567"
    assert row.reason == "Phone shared"
  end

  test "merge_with_contact filters unchanged values and keeps changed rows" do
    ai_rows = [
      %{field: "phone", suggested_value: "5551234567", reason: "Mentioned phone"},
      %{field: "email", suggested_value: "advisor@example.com", reason: "Same email"}
    ]

    contact = %{
      phone: nil,
      email: "advisor@example.com"
    }

    assert {:ok, rows} = CRMSuggestions.merge_with_contact("hubspot", ai_rows, contact)
    assert length(rows) == 1

    row = hd(rows)
    assert row.field == "phone"
    assert row.existing_value == nil
    assert row.suggested_value == "5551234567"
    assert row.apply
    assert row.has_change
  end

  test "build_update_payload maps provider-native keys and filters non-applicable rows" do
    rows = [
      %{
        field: "linkedin_url",
        suggested_value: "https://www.linkedin.com/in/alex-taylor/",
        apply: true,
        has_change: true
      },
      %{
        field: "twitter_handle",
        suggested_value: "@alex",
        apply: true,
        has_change: true
      },
      %{
        field: "phone",
        suggested_value: "5550001111",
        apply: false,
        has_change: true
      }
    ]

    assert {:ok, payload} = CRMSuggestions.build_update_payload("hubspot", rows)

    assert payload == %{
             "hs_linkedin_url" => "https://www.linkedin.com/in/alex-taylor/",
             "twitterhandle" => "@alex"
           }
  end

  test "build_update_payload maps Salesforce keys and ignores unknown fields" do
    rows = [
      %{field: "firstname", suggested_value: "Alex", apply: true, has_change: true},
      %{field: "mailing_city", suggested_value: "Denver", apply: true, has_change: true},
      %{field: "unknown", suggested_value: "ignore", apply: true, has_change: true}
    ]

    assert {:ok, payload} = CRMSuggestions.build_update_payload("salesforce", rows)

    assert payload == %{
             "FirstName" => "Alex",
             "MailingCity" => "Denver"
           }
  end

  test "returns unsupported provider error for unknown providers" do
    assert {:error, {:unsupported_provider, "pipedrive"}} =
             CRMSuggestions.generate_from_meeting("pipedrive", %{id: 1})

    assert {:error, {:unsupported_provider, "pipedrive"}} =
             CRMSuggestions.build_update_payload("pipedrive", [])
  end
end
