defmodule SocialScribeWeb.MeetingLive.SalesforceModalComponent do
  @moduledoc """
  Salesforce contact review modal shell.

  Handles contact search/select and renders pending CRM rows before
  suggestion generation and update submission are enabled.
  """

  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:modal_id, fn -> "salesforce-modal-wrapper" end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:contacts, fn -> [] end)
      |> assign_new(:selected_contact, fn -> nil end)
      |> assign_new(:pending_rows, fn -> [] end)
      |> assign_new(:searching, fn -> false end)
      |> assign_new(:loading_contact, fn -> false end)
      |> assign_new(:dropdown_open, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :patch, ~p"/dashboard/meetings/#{assigns.meeting}")
    assigns = assign(assigns, :selected_count, Enum.count(assigns.pending_rows, & &1.apply))

    ~H"""
    <div class="space-y-6">
      <div>
        <h2 id={"#{@modal_id}-title"} class="text-xl font-medium tracking-tight text-slate-900">
          Update in Salesforce
        </h2>
        <p id={"#{@modal_id}-description"} class="mt-2 text-base font-light leading-7 text-slate-500">
          Here are suggested updates to sync with Salesforce based on this
          <span class="block">meeting</span>
        </p>
      </div>

      <.salesforce_contact_select
        selected_contact={@selected_contact}
        contacts={@contacts}
        loading={@searching}
        loading_contact={@loading_contact}
        open={@dropdown_open}
        query={@query}
        target={@myself}
        error={@error}
        id="salesforce-contact-select"
      />

      <%= if @selected_contact do %>
        <div class="space-y-4">
          <%= if @loading_contact do %>
            <div class="text-center py-8 text-slate-500">
              <.icon name="hero-arrow-path" class="h-6 w-6 animate-spin mx-auto mb-2" />
              <p>Loading contact details...</p>
            </div>
          <% else %>
            <div class="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
              <.pending_row_card :for={row <- @pending_rows} row={row} />
            </div>

            <.modal_footer
              cancel_patch={@patch}
              submit_text="Update Salesforce"
              submit_class="bg-green-600 hover:bg-green-700"
              disabled={true}
              loading={false}
              info_text={"1 object, #{@selected_count} fields in 1 integration selected to update"}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("contact_search", %{"value" => query}, socket) do
    trimmed_query = String.trim(query)

    if String.length(trimmed_query) >= 2 do
      send(self(), {:salesforce_search, trimmed_query, socket.assigns.credential})

      {:noreply,
       assign(socket,
         searching: true,
         dropdown_open: true,
         query: trimmed_query,
         error: nil
       )}
    else
      {:noreply,
       assign(socket,
         query: query,
         contacts: [],
         searching: false,
         dropdown_open: query != "",
         error: nil
       )}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    send(self(), {:salesforce_load_contact, contact_id, socket.assigns.credential})

    {:noreply,
     assign(socket,
       selected_contact: %{
         id: contact_id,
         name: display_name_for_contact(contact_id, socket.assigns.contacts)
       },
       pending_rows: [],
       loading_contact: true,
       dropdown_open: false,
       query: "",
       error: nil
     )}
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply,
     assign(socket,
       selected_contact: nil,
       pending_rows: [],
       loading_contact: false,
       query: "",
       contacts: [],
       dropdown_open: false,
       error: nil
     )}
  end

  @impl true
  def handle_event("open_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: true)}
  end

  @impl true
  def handle_event("close_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  @impl true
  def handle_event("toggle_contact_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: !socket.assigns.dropdown_open)}
  end

  attr :selected_contact, :map, default: nil
  attr :contacts, :list, default: []
  attr :loading, :boolean, default: false
  attr :loading_contact, :boolean, default: false
  attr :open, :boolean, default: false
  attr :query, :string, default: ""
  attr :target, :any, default: nil
  attr :error, :string, default: nil
  attr :id, :string, default: "salesforce-contact-select"

  defp salesforce_contact_select(assigns) do
    ~H"""
    <div class="space-y-1">
      <label for={"#{@id}-input"} class="block text-sm font-medium text-slate-700">
        Select Contact
      </label>
      <div class="relative">
        <%= if @selected_contact do %>
          <button
            type="button"
            phx-click="toggle_contact_dropdown"
            phx-target={@target}
            role="combobox"
            aria-haspopup="listbox"
            aria-expanded={to_string(@open)}
            aria-controls={"#{@id}-listbox"}
            disabled={@loading_contact}
            class="relative w-full bg-white border border-hubspot-input rounded-lg pl-1.5 pr-10 py-[5px] text-left cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm disabled:opacity-60"
          >
            <span class="flex items-center">
              <.name_avatar name={@selected_contact.name} size={:sm} />
              <span class="ml-1.5 block truncate text-slate-900">
                {@selected_contact.name}
              </span>
            </span>
            <span class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
              <%= if @loading_contact do %>
                <.icon name="hero-arrow-path" class="h-5 w-5 text-hubspot-icon animate-spin" />
              <% else %>
                <.icon name="hero-chevron-up-down" class="h-5 w-5 text-hubspot-icon" />
              <% end %>
            </span>
          </button>
        <% else %>
          <div class="relative">
            <input
              id={"#{@id}-input"}
              type="text"
              name="contact_query"
              value={@query}
              placeholder="Search Salesforce contacts..."
              phx-keyup="contact_search"
              phx-target={@target}
              phx-focus="open_contact_dropdown"
              phx-debounce="150"
              autocomplete="off"
              role="combobox"
              aria-autocomplete="list"
              aria-expanded={to_string(@open)}
              aria-controls={"#{@id}-listbox"}
              disabled={@loading_contact}
              class="w-full bg-white border border-hubspot-input rounded-lg pl-2 pr-10 py-[5px] text-left focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm disabled:opacity-60"
            />
            <span class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
              <%= if @loading do %>
                <.icon name="hero-arrow-path" class="h-5 w-5 text-hubspot-icon animate-spin" />
              <% else %>
                <.icon name="hero-chevron-up-down" class="h-5 w-5 text-hubspot-icon" />
              <% end %>
            </span>
          </div>
        <% end %>

        <div
          :if={@open && (@selected_contact || Enum.any?(@contacts) || @loading || @query != "")}
          id={"#{@id}-listbox"}
          role="listbox"
          phx-click-away="close_contact_dropdown"
          phx-target={@target}
          class="absolute z-10 mt-1 w-full bg-white shadow-lg max-h-60 rounded-md py-1 text-base ring-1 ring-black ring-opacity-5 overflow-auto focus:outline-none sm:text-sm"
        >
          <button
            :if={@selected_contact}
            type="button"
            phx-click="clear_contact"
            phx-target={@target}
            role="option"
            aria-selected="false"
            class="w-full text-left px-4 py-2 hover:bg-slate-50 text-sm text-slate-700 cursor-pointer"
          >
            Clear selection
          </button>

          <div :if={@loading} class="px-4 py-2 text-sm text-gray-500">
            Searching...
          </div>

          <div
            :if={!@loading && Enum.empty?(@contacts) && @query != ""}
            class="px-4 py-2 text-sm text-gray-500"
          >
            No contacts found
          </div>

          <button
            :for={contact <- @contacts}
            type="button"
            phx-click="select_contact"
            phx-value-id={contact.id}
            phx-target={@target}
            role="option"
            aria-selected="false"
            class="w-full text-left px-4 py-2 hover:bg-slate-50 flex items-center space-x-3 cursor-pointer"
          >
            <.name_avatar name={contact.name} size={:sm} />
            <div>
              <div class="text-sm font-medium text-slate-900">
                {contact.name}
              </div>
              <div class="text-xs text-slate-500">
                {contact.email || "No email"}
              </div>
            </div>
          </button>
        </div>
      </div>

      <.inline_error :if={@error} message={@error} />
    </div>
    """
  end

  attr :row, :map, required: true

  defp pending_row_card(assigns) do
    ~H"""
    <div class="bg-hubspot-card rounded-2xl p-6 mb-4">
      <div class="flex items-start justify-between">
        <div class="flex items-start gap-3">
          <div class="flex items-center h-5 pt-0.5">
            <input
              type="checkbox"
              checked={@row.apply}
              disabled
              class="h-4 w-4 rounded-[3px] border-slate-300 text-hubspot-checkbox accent-hubspot-checkbox focus:ring-0 focus:ring-offset-0 cursor-not-allowed opacity-60"
            />
          </div>
          <div class="text-sm font-semibold text-slate-900 leading-5">{@row.label}</div>
        </div>

        <div class="flex items-center gap-3 pt-0.5">
          <span class="inline-flex items-center rounded-full bg-hubspot-pill px-2 py-1 text-xs font-medium text-hubspot-pill-text">
            {if @row.apply, do: "1 update selected", else: "0 updates selected"}
          </span>
          <button
            type="button"
            class="text-xs text-hubspot-hide hover:text-hubspot-hide-hover font-medium"
          >
            Hide details
          </button>
        </div>
      </div>

      <div class="mt-2 pl-8">
        <div class="text-sm font-medium text-slate-700 leading-5 ml-1">{@row.label}</div>

        <div class="relative mt-2">
          <div class="grid grid-cols-[1fr_32px_1fr] items-center gap-6">
            <input
              type="text"
              readonly
              value={@row.existing_value || ""}
              placeholder="No existing value"
              class={[
                "block w-full shadow-sm text-sm bg-white border border-gray-300 rounded-[7px] py-1.5 px-2",
                if(@row.existing_value && @row.existing_value != "",
                  do: "line-through text-gray-500",
                  else: "text-gray-400"
                )
              ]}
            />

            <div class="w-8 flex justify-center text-hubspot-arrow">
              <.icon name="hero-arrow-long-right" class="h-7 w-7" />
            </div>

            <input
              type="text"
              readonly
              value=""
              placeholder="Pending AI suggestion"
              class="block w-full shadow-sm text-sm text-slate-500 bg-white border border-hubspot-input rounded-[7px] py-1.5 px-2"
            />
          </div>
        </div>

        <div class="mt-3 grid grid-cols-[1fr_32px_1fr] items-start gap-6">
          <button
            type="button"
            class="text-xs text-hubspot-link hover:text-hubspot-link-hover font-medium justify-self-start"
          >
            Update mapping
          </button>
          <span></span>
          <span class="text-xs text-slate-500 justify-self-start">
            Suggestions will appear after AI review
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]

  defp name_avatar(assigns) do
    size_classes = %{
      sm: "h-6 w-6 text-[10px]",
      md: "h-8 w-8 text-[10px]",
      lg: "h-10 w-10 text-sm"
    }

    assigns =
      assigns
      |> assign(:size_class, size_classes[assigns.size])
      |> assign(:initials, initials(assigns.name))

    ~H"""
    <div class={[
      "rounded-full bg-hubspot-avatar flex items-center justify-center font-semibold text-hubspot-avatar-text flex-shrink-0",
      @size_class
    ]}>
      {@initials}
    </div>
    """
  end

  defp initials(nil), do: "??"
  defp initials(""), do: "??"

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", fn part -> part |> String.first() |> String.upcase() end)
  end

  defp display_name_for_contact(contact_id, contacts) do
    case Enum.find(contacts, &(&1.id == contact_id)) do
      nil -> "Selected Contact"
      contact -> contact.name || "Selected Contact"
    end
  end
end
