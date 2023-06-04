defmodule PicselloWeb.EmailAutomationLive.EditEmailComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

  @steps [:timing, :edit_email, :preview_email]
  @impl true
  def update(
        _,
        socket
      ) do
    socket
    |> assign(steps: @steps)
    |> assign(step: :preview_email)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="relative bg-white p-6">
        <.close_x />

        <.steps step={:timing} steps={@steps} target={@myself} />
        <h1 class="mt-2 mb-4 text-3xl">
          <span class="font-bold">Add Wedding Email Step:</span>
          <%= case @step do %>
            <% :timing -> %> Timing
            <% :edit_email -> %> Edit Email
            <% :preview_email -> %> Preview Email
          <% end %>
        </h1>
        <.step step={@step} />


        <.footer class="pt-10">
          <.form :let={f} for={:timing} class="mr-auto md:hidden flex w-full">
            <%= select_field f, :add_to, ["long text", "very long text", "super duper long text"], class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 w-full" %>
          </.form>
          <.step_buttons step={@step} myself={@myself} />

          <%= if step_number(@step, @steps) == 1 do %>
            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Close
            </button>
          <% else %>
            <button class="btn-secondary" title="back" type="button" phx-click="back" phx-target={@myself}>
              Go back
            </button>
          <% end %>

          <.form :let={f} for={:timing} class="mr-auto hidden md:flex">
            <%= select_field f, :add_to, ["long text", "very long text", "super duper long text"], class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8" %>
          </.form>
        </.footer>
      </div>
    """
  end

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  def step_buttons(%{step: step} = assigns) when step in [:timing, :edit_email] do
    ~H"""
    <button class="btn-primary" title="Next" type="submit" phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{step: :preview_email} = assigns) do
    ~H"""
    <button class="btn-primary" title="Save" type="submit" phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{step: :timing} = assigns) do
    ~H"""
      <div class="rounded-lg border-base-200 border">
        <div class="bg-base-200 p-4 flex rounded-t-lg">
          <div class="flex flex-row items-center mr-[600px]">
            <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center mr-3">
              <.icon name="envelope" class="w-5 h-5 text-blue-planning-300" />
            </div>
            <span class="text-blue-planning-300 text-lg"><b>Send email:</b> Day Before Shoot</span>
          </div>
          <div class="flex ml-auto items-center">
            <div class="w-8 h-8 rounded-full bg-blue-planning-300 flex items-center justify-center mr-3">
              <.icon name="play-icon" class="w-4 h-4 fill-current text-white" />
            </div>
            <span>Job Automation</span>
          </div>
        </div>

        <div class="px-14 py-6">
          <b>Automation timing</b>
          <span class="text-base-250">Choose when you’d like your automation to run</span>
          <.form :let={f} for={:timing} class="flex gap-4 flex-col my-4">
            <label class="flex items-center">
              <%= radio_button(f, :immediately, true, class: "w-5 h-5 mr-4 radio cursor-pointer") %>
              <p>Send immediately when event happens</p>
            </label>
            <label class="flex items-center">
              <%= radio_button(f, :certain_time, true, class: "w-5 h-5 mr-4 radio cursor-pointer") %>
              <p>Send at a certain time</p>
            </label>
          </.form>
          <b>Email Status</b>
          <span class="text-base-250">Choose is if this email step is enabled or not to send</span>

          <.form :let={_} for={%{}} as={:toggle} phx-change="toggle">
            <label class="flex pt-4">
              <input type="checkbox" class="peer hidden" checked={}/>
              <div class="hidden peer-checked:flex cursor-pointer">
                <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                  <div class="rounded-full h-5 w-5 bg-base-100"></div>
                </div>
                Email enabled
              </div>
              <div class="flex peer-checked:hidden cursor-pointer">
                <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                  <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                </div>
                Email disabled
              </div>
            </label>
          </.form>
        </div>
      </div>
    """
  end

  def step(%{step: :edit_email} = assigns) do
    ~H"""
      <div class="flex flex-row mt-2 items-center">
        <div class="flex mr-2">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-planning-300">
            <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
          </div>
        </div>
        <div class="flex flex-col ml-2">
          <p><b> Job:</b> Day Before Shoot</p>
          <p class="text-sm text-base-250">Send email 2 hours before shoot</p>
        </div>
      </div>

      <hr class="my-8" />

      <.form :let={f} for={:edit_email} class="mr-auto">
        <div class="grid grid-cols-3 gap-6">
          <label class="flex flex-col">
            <b>Select email preset</b>
            <%= select_field f, :email_preset, ["long text", "very long text", "super duper long text"], class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>

          <label class="flex flex-col">
            <b>Subject Line</b>
            <%= input f, :subject,  class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
          <label class="flex flex-col">
            <b>Private Name</b>
            <%= input f, :name,  placeholder: "Inquiry Email", class: "border-base-200 hover:border-blue-planning-300 cursor-pointer pr-8 mt-2" %>
          </label>
        </div>

        <div class="flex flex-col mt-4">
          <.input_label form={f} class="flex items-end justify-between mb-2 text-sm font-semibold" field={:content}>
            <b>Email Content</b>
            <.icon_button color="red-sales-300" phx_hook="ClearQuillInput" icon="trash" id="clear-description" data-input-name={input_name(f,:content)}>
              <p class="text-black">Clear</p>
            </.icon_button>
          </.input_label>
          <.quill_input f={f} html_field={:content} editor_class="min-h-[16rem]" placeholder={"Write your email content here"} />
        </div>
      </.form>
    """
  end

  def step(%{step: :preview_email} = assigns) do
    ~H"""
      <div class="flex flex-row mt-2 mb-4 items-center">
        <div class="flex mr-2">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-planning-300">
            <.icon name="envelope" class="w-4 h-4 text-white fill-current"/>
          </div>
        </div>
        <div class="flex flex-col ml-2">
          <p><b> Job:</b> Upcoming Shoot Automation</p>
          <p class="text-sm text-base-250">Send email 7 days before next upcoming shoot</p>
        </div>
      </div>
      <span class="text-base-250">Check out how your client will see your emails. We’ve put in some placeholder data to visualize the variables.</span>

      <hr class="my-4" />

      <div class="bg-base-200 flex items-center justify-center p-4 rounded-lg">
        <img src="/images/empty-state.png" />
      </div>
    """
  end

end
