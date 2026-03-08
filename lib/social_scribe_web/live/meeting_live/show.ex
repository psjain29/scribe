defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton
  import SocialScribeWeb.ModalComponents, only: [hubspot_modal: 1]

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.CRM
  alias SocialScribe.CRMSuggestions

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)

    user_has_automations =
      Automations.list_active_user_automations(socket.assigns.current_user.id)
      |> length()
      |> Kernel.>(0)

    automation_results = Automations.list_automation_results_for_meeting(meeting_id)

    if meeting.calendar_event.user_id != socket.assigns.current_user.id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      hubspot_credential = Accounts.get_user_hubspot_credential(socket.assigns.current_user.id)

      salesforce_credential =
        socket.assigns.current_user.id
        |> Accounts.list_user_salesforce_credentials()
        |> List.first()

      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        |> assign(:hubspot_credential, hubspot_credential)
        |> assign(:salesforce_credential, salesforce_credential)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:hubspot_search, query, credential}, socket) do
    case CRM.search_contacts(credential, query) do
      {:ok, contacts} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          contacts: contacts,
          searching: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Failed to search contacts: #{inspect(reason)}",
          searching: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:generate_suggestions, contact, meeting, credential}, socket) do
    case CRMSuggestions.generate_for_contact(credential.provider, credential, contact.id, meeting) do
      {:ok, %{suggestion_rows: suggestion_rows}} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          step: :suggestions,
          suggestions: suggestion_rows,
          loading: false
        )

      {:error, {:unsupported_provider, _provider}} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: CRMSuggestions.unsupported_provider_message(),
          loading: false
        )

      {:error, reason} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Failed to generate suggestions: #{inspect(reason)}",
          loading: false
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:apply_hubspot_updates, suggestion_rows, contact, credential}, socket) do
    case CRMSuggestions.build_update_payload(credential.provider, suggestion_rows) do
      {:ok, payload} when map_size(payload) == 0 ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: "Please select at least one changed field to update.",
          loading: false
        )

        {:noreply, socket}

      {:ok, payload} ->
        case CRM.update_contact(credential, contact.id, payload) do
          {:ok, _updated_contact} ->
            socket =
              socket
              |> put_flash(:info, "Successfully updated #{map_size(payload)} field(s) in HubSpot")
              |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

            {:noreply, socket}

          {:error, :not_found} ->
            send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
              id: "hubspot-modal",
              error: "That HubSpot contact could not be found. Please select another contact.",
              loading: false
            )

            {:noreply, socket}

          {:error, {:unsupported_provider, _provider}} ->
            send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
              id: "hubspot-modal",
              error: CRMSuggestions.unsupported_provider_message(),
              loading: false
            )

            {:noreply, socket}

          {:error, _reason} ->
            send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
              id: "hubspot-modal",
              error: "Failed to update HubSpot contact. Please try again.",
              loading: false
            )

            {:noreply, socket}
        end

      {:error, {:unsupported_provider, _provider}} ->
        send_update(SocialScribeWeb.MeetingLive.HubspotModalComponent,
          id: "hubspot-modal",
          error: CRMSuggestions.unsupported_provider_message(),
          loading: false
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:salesforce_search, query, credential}, socket) do
    case CRM.search_contacts(credential, query) do
      {:ok, contacts} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          contacts: contacts,
          searching: false,
          error: nil
        )

      {:error, {:malformed_response, _body}} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          contacts: [],
          searching: false,
          error: "Salesforce returned an unexpected contact search response. Please try again."
        )

      {:error, _reason} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          contacts: [],
          searching: false,
          error: "Failed to search Salesforce contacts. Please try again."
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:salesforce_generate_suggestions, contact_id, credential}, socket) do
    case CRMSuggestions.generate_for_contact(
           credential.provider,
           credential,
           contact_id,
           socket.assigns.meeting
         ) do
      {:ok, %{contact: contact, suggestion_rows: suggestion_rows}} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          selected_contact: contact,
          suggestion_rows: suggestion_rows,
          loading_contact: false,
          error: nil
        )

      {:error, {:unsupported_provider, _provider}} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          loading_contact: false,
          error: CRMSuggestions.unsupported_provider_message()
        )

      {:error, :not_found} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          loading_contact: false,
          error: "That Salesforce contact could not be found. Please select another contact."
        )

      {:error, _reason} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          loading_contact: false,
          error: "Failed to load Salesforce contact details. Please try again."
        )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:apply_salesforce_updates, suggestion_rows, contact, credential}, socket) do
    case CRMSuggestions.build_update_payload(credential.provider, suggestion_rows) do
      {:ok, payload} when map_size(payload) == 0 ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          loading: false,
          error: "Please select at least one changed field to update."
        )

        {:noreply, socket}

      {:ok, payload} ->
        case CRM.update_contact(credential, contact.id, payload) do
          {:ok, _updated_contact} ->
            socket =
              socket
              |> put_flash(
                :info,
                "Successfully updated #{map_size(payload)} field(s) in Salesforce"
              )
              |> push_patch(to: ~p"/dashboard/meetings/#{socket.assigns.meeting}")

            {:noreply, socket}

          {:error, :not_found} ->
            send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
              id: "salesforce-modal",
              loading: false,
              error: "That Salesforce contact could not be found. Please select another contact."
            )

            {:noreply, socket}

          {:error, {:unsupported_provider, _provider}} ->
            send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
              id: "salesforce-modal",
              loading: false,
              error: CRMSuggestions.unsupported_provider_message()
            )

            {:noreply, socket}

          {:error, reason} ->
            send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
              id: "salesforce-modal",
              loading: false,
              error: salesforce_update_error_message(reason)
            )

            {:noreply, socket}
        end

      {:error, {:unsupported_provider, _provider}} ->
        send_update(SocialScribeWeb.MeetingLive.SalesforceModalComponent,
          id: "salesforce-modal",
          loading: false,
          error: CRMSuggestions.unsupported_provider_message()
        )

        {:noreply, socket}
    end
  end

  defp salesforce_update_error_message({:api_error, _status, body}) do
    case extract_salesforce_error(body) do
      %{"errorCode" => "DUPLICATE_VALUE"} = error ->
        case extract_error_field(error) do
          "Email" ->
            "Could not update Salesforce: Email is already used by another contact."

          field when is_binary(field) ->
            "Could not update Salesforce: #{field} is already used by another record."

          _ ->
            "Could not update Salesforce: one selected value is already used by another record."
        end

      %{"errorCode" => "INVALID_FIELD_FOR_INSERT_UPDATE"} = error ->
        case extract_error_field(error) do
          field when is_binary(field) ->
            "Could not update Salesforce: #{field} cannot be updated."

          _ ->
            "Could not update Salesforce: one selected field cannot be updated."
        end

      %{"errorCode" => "REQUIRED_FIELD_MISSING"} = error ->
        case extract_error_field(error) do
          field when is_binary(field) -> "Could not update Salesforce: #{field} is required."
          _ -> "Could not update Salesforce: a required field is missing."
        end

      _ ->
        "Failed to update Salesforce contact. Please try again."
    end
  end

  defp salesforce_update_error_message(_reason),
    do: "Failed to update Salesforce contact. Please try again."

  defp extract_salesforce_error([%{} = first | _]), do: first
  defp extract_salesforce_error(%{"errorCode" => _} = error), do: error
  defp extract_salesforce_error(%{"errors" => [%{} = first | _]}), do: first
  defp extract_salesforce_error(_), do: nil

  defp extract_error_field(%{"fields" => [field | _]}) when is_binary(field),
    do: humanize_field_name(field)

  defp extract_error_field(_), do: nil

  defp humanize_field_name(field), do: field |> Macro.underscore() |> humanize_snake_case()

  defp humanize_snake_case(value) do
    value
    |> String.replace("_", " ")
    |> String.downcase()
    |> String.capitalize()
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <div class="bg-white shadow-xl rounded-lg p-6 md:p-8">
      <h2 class="text-2xl font-semibold mb-4 text-slate-700">
        Meeting Transcript
      </h2>
      <div class="prose prose-sm sm:prose max-w-none h-96 overflow-y-auto pr-2">
        <%= if @has_transcript do %>
          <div :for={segment <- @meeting_transcript.content["data"]} class="mb-3">
            <p>
              <span class="font-semibold text-indigo-600">
                {segment["speaker"] || "Unknown Speaker"}:
              </span>
              {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
            </p>
          </div>
        <% else %>
          <p class="text-slate-500">
            Transcript not available for this meeting.
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
