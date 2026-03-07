defmodule SocialScribeWeb.SalesforceModalTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import Mox

  setup :verify_on_exit!

  describe "Salesforce Modal" do
    setup %{conn: conn} do
      user = user_fixture()
      salesforce_credential = salesforce_credential_fixture(%{user_id: user.id})
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting,
        salesforce_credential: salesforce_credential
      }
    end

    test "renders modal when navigating to salesforce route", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      assert has_element?(view, "#salesforce-modal-wrapper")
      assert has_element?(view, "h2", "Update in Salesforce")
      assert has_element?(view, "label", "Select Contact")
    end

    test "search input and dropdown render contacts", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, query ->
        assert query == "Alex"
        {:ok, contacts}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Alex Taylor"
      assert html =~ "alex.taylor@example.test"
    end

    test "single-character input shows helper text and does not query API", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "A"})

      :timer.sleep(200)

      assert render(view) =~ "Please enter at least 2 characters to search."
    end

    test "selecting a contact fetches details and renders pending rows", %{
      conn: conn,
      meeting: meeting
    } do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000",
        mobilephone: nil,
        title: "Advisor",
        mailing_street: nil,
        mailing_city: "Denver",
        mailing_state: nil,
        mailing_postal_code: nil,
        mailing_country: "USA"
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, contact_id ->
        assert contact_id == "0031"
        {:ok, contact}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      :timer.sleep(200)

      html = render(view)
      assert html =~ "First Name"
      assert html =~ "Pending AI suggestion"
      assert html =~ "Update Salesforce"
    end

    test "shows loading state while contact fetch is in flight", %{conn: conn, meeting: meeting} do
      contacts = [
        %{id: "0031", name: "Alex Taylor", email: "alex.taylor@example.test", phone: "555-1000"}
      ]

      contact = %{
        id: "0031",
        name: "Alex Taylor",
        firstname: "Alex",
        lastname: "Taylor",
        email: "alex.taylor@example.test",
        phone: "555-1000",
        mobilephone: nil,
        title: nil,
        mailing_street: nil,
        mailing_city: nil,
        mailing_state: nil,
        mailing_postal_code: nil,
        mailing_country: nil
      }

      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query -> {:ok, contacts} end)
      |> expect(:get_contact, fn _credential, _contact_id ->
        Process.sleep(200)
        {:ok, contact}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      view
      |> element("button[phx-click='select_contact'][phx-value-id='0031']")
      |> render_click()

      assert render(view) =~ "Loading contact details..."

      :timer.sleep(250)
      refute render(view) =~ "Loading contact details..."
    end

    test "renders inline error and remains interactive after search failure", %{
      conn: conn,
      meeting: meeting
    } do
      SocialScribe.SalesforceApiMock
      |> expect(:search_contacts, fn _credential, _query ->
        {:error, {:api_error, 500, %{}}}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{"value" => "Alex"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Failed to search Salesforce contacts. Please try again."
      assert has_element?(view, "input[phx-keyup='contact_search']")
    end
  end

  describe "Salesforce Modal without credential" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture_with_transcript(user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: meeting
      }
    end

    test "meeting page hides Salesforce integration card", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "Salesforce Integration"
      refute html =~ "Update Salesforce Contact"
    end

    test "salesforce route does not render modal", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      refute html =~ "salesforce-modal-wrapper"
      refute html =~ "Update in Salesforce"
    end
  end

  defp meeting_fixture_with_transcript(user) do
    meeting = meeting_fixture(%{})
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _updated_event} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Advisor",
            "words" => [
              %{"text" => "Let's"},
              %{"text" => "review"},
              %{"text" => "your"},
              %{"text" => "contact"},
              %{"text" => "details"}
            ]
          }
        ]
      }
    })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
