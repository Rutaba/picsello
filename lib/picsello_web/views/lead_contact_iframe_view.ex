defmodule PicselloWeb.LeadContactIframeView do
  use PicselloWeb, :view
  
  import Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [job_type_option: 1, icon: 1]

  def render("index.html", assigns) do
    ~H"""
    <.container>
      <h1 class="text-3xl font-bold max-w-md">Get in touch</h1>

      <.form for={@changeset} :let={f} id="client-form">
        <div class="flex flex-col mt-3">
          <%= label_for f, :name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", label: "Your name", class: "py-2 font-bold" %>

          <%= input f, :name, placeholder: "First and last name", required: true %>
        </div>

        <div class="flex flex-col lg:flex-row">
          <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
            <%= label_for f, :email, label: "Your email", class: "py-2 font-bold" %>

            <%= input f, :email, type: :email_input, placeholder: "email@example.com", required: true %>
          </div>

          <div class="flex flex-col flex-1 mt-3">
            <%= label_for f, :phone, label: "Your phone number", class: "py-2 font-bold" %>

            <%= input f, :phone, type: :telephone_input, placeholder: "(555) 555-5555", required: true, id: "phone" %>
          </div>
        </div>

        <div class="mt-7 grid grid-cols-1 lg:grid-cols-2 gap-4">
          <%= label_for f, :job_type, label: "What photography type are you interested in?", class: "py-2 font-bold col-span-1 lg:col-span-2" %>

          <%= for job_type <- @job_types do %>
            <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={input_value(f, :job_type) == job_type} color="black" class="rounded-none" />
          <% end %>
        </div>

        <div class="flex flex-col mt-7">
          <%= label_for f, :message, label: "Your message", class: "py-2 font-bold" %>

          <%= input f, :message, type: :textarea, placeholder: "e.g. Date(s), what you're looking for, any relevant information, etc.", rows: 5, required: true %>
        </div>

        <div class="mt-8 text-right"><button type="submit" class="w-full lg:w-auto btn-primary">Submit</button></div>
      </.form>
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
          <h1 class="text-2xl font-bold">Message sent</h1>
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
end
