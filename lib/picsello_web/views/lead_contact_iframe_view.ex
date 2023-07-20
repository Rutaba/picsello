defmodule PicselloWeb.LeadContactIframeView do
  use PicselloWeb, :view

  import Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [job_type_option: 1, icon: 1]

  def render("index.html", assigns) do
    ~H"""
    <.container>
      <h1 class="text-3xl font-light max-w-md">Get in touch</h1>

      <.form for={@changeset} :let={f} id="client-form">
        <div class="flex flex-col mt-3">
          <%= label_for f, :name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", label: "Your name", class: "py-2 font-light" %>

          <%= input f, :name, placeholder: "Type your first and last name...", required: true %>
        </div>

        <div class="flex flex-col lg:flex-row">
          <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
            <%= label_for f, :email, label: "Your email", class: "py-2 font-light" %>

            <%= input f, :email, type: :email_input, placeholder: "Type email...", required: true %>
          </div>

          <div class="flex flex-col flex-1 mt-3">
            <%= label_for f, :phone, label: "Your phone number", class: "py-2 font-light" %>

            <%= input f, :phone, type: :telephone_input, placeholder: "Type phone number...", required: true, id: "phone" %>
          </div>
        </div>

        <div class="flex flex-col mt-3">
            <%= labeled_select f, :referred_by, referred_by_options(), label: "How did you hear about #{@organization.name}?", prompt: "select one...", phx_debounce: 300, phx_update: "ignore" %>
            <em class="text-base-250 font-normal pt-1 text-xs">optional</em>
        </div>

        <div id="referralNameDiv" class="flex flex-col mt-3 hidden">
            <%= label_for f, :referral_name, label: "Would you mind sharing their name?", class: "py-2" %>

            <%= input f, :referral_name, placeholder: "Type name...", phx_debounce: 300 %>
            <em class="text-base-250 font-normal pt-1 text-xs">optional</em>
        </div>

        <%= if Enum.any?(@job_types) do %>
          <div class="mt-4">
            <%= label_for f, :job_type, label: "What type of session are you looking for?", class: "font-light" %>
            <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mt-1">
              <%= for job_type <- @job_types do %>
                <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={input_value(f, :job_type) == job_type} color="black" class="rounded-none" />
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="flex flex-col mt-7">
          <%= label_for f, :message, label: "Your message", class: "py-2 font-light" %>

          <%= input f, :message, type: :textarea, placeholder: "Type your message...", rows: 5, required: true %>
        </div>

        <div class="mt-8 text-right"><button type="submit" class="w-full lg:w-auto btn-primary">Submit</button></div>
      </.form>
      <script>
        const referredBySelect = document.querySelector("#client-form_referred_by")
        const referralNameDiv = document.getElementById('referralNameDiv');
        const referralNameLabel = document.querySelector('#referralNameDiv label');
        const referralNameInput = document.querySelector('#referralNameDiv input');

        referredBySelect.addEventListener('change', function() {
          const selectedOption = this.value;
          if (selectedOption === 'Other') {
            referralNameLabel.textContent = "Would you mind sharing where?";
            referralNameInput.placeholder = "Type where?";
          }
          referralNameDiv.classList.toggle('hidden', selectedOption !== 'Friend' && selectedOption !== 'Other');
        });
      </script>
      <script defer phx-track-static type="text/javascript" src={Routes.static_path(@conn, "/js/leadForm.js")}></script>
    </.container>
    """
  end

  def render("thank-you.html", assigns) do
    ~H"""
    <.container>
      <div class="flex items-center mt-14 min-w-max justify-center h-96">
        <.icon name="confetti" class="w-20 h-20 stroke-current mr-9" />
        <div>
          <h1 class="text-2xl font-light">Message sent</h1>
          We'll contact you soon!
        </div>
      </div>
    </.container>
    """
  end

  defp container(assigns) do
    ~H"""
    <div class="p-9 border-base-200 client-app">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  defp referred_by_options() do
    [
      "Friend",
      "Google",
      "Facebook",
      "Instagram",
      "Tiktok",
      "Pinterest",
      "Event / Tradeshow",
      "Other"
    ]
  end
end
