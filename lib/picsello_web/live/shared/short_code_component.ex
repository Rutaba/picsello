defmodule PicselloWeb.Shared.ShortCodeComponent do
  @moduledoc """
    Helper functions to use the Short Codes
  """
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    job = Map.get(assigns, :job, nil)
    assigns =
      assigns
      |> Enum.into(%{
        variables_list: variables_codes(assigns.job_type, assigns.current_user, job)
      })

    ~H"""
      <div>
        <div class="flex items-center font-bold bg-gray-100 rounded-t-lg border-gray-200 text-blue-planning-300 p-2.5">
          <.icon name="vertical-list" class="w-4 h-4 mr-2 text-blue-planning-300" />
          Email Variables

          <a href="#" phx-click="toggle-variables" phx-value-show-variables={"#{@show_variables}"} phx-target={@target} title="close" class="ml-auto cursor-pointer">
            <.icon name="close-x" class="w-3 h-3 stroke-current text-base-300 stroke-2" />
          </a>
        </div>
        <div class="flex flex-col p-2.5 border border-gray-200 rounded-b-lg h-72 overflow-auto">
          <p class="text-base-250">Copy & paste the variable to use in your email. If you remove a variable, the information won’t be inserted.</p>
          <hr class="my-3" />
          <%= for code <- @variables_list do%>
            <p class="text-blue-planning-300 capitalize mb-3"><%= code.type %> variables</p>
            <%= for variable <- code.variables do%>
            <% name = "{{" <> variable.name <> "}}" %>
              <div class="flex-col flex mb-2">
                  <div class="flex">
                    <p><%= name %></p>
                    <div class="ml-auto flex flex-row items-center justify-center">
                    <a href="#" id={"copy-code-#{code.type}-#{variable.id}"} data-clipboard-text={name} phx-hook="Clipboard" title="copy" class="ml-auto cursor-pointer">
                      <.icon name="clip-board" class="w-4 h-4 text-blue-planning-300" />
                      <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
                        Copied!
                      </div>
                    </a>
                    </div>
                  </div>
                <span class="text-base-250 text-sm"><%= variable.description %></span>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    """
  end

  def short_codes_select(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id]} {assigns} />
    """
  end

  def variables_codes(job_type, current_user, job) do
    photographer(current_user.organization) |> IO.inspect()

    leads = [
      %{
        type: "lead",
        variables: [
          %{
            id: 1,
            name: "delivery_time",
            sample: "two weeks",
            description:
              "Image turnaround time in number of weeks; image turnaround time is _ weeks"
          }
        ]
      }
    ]

    other =
      case job_type do
        :job -> job_variables()
        :gallery -> job_variables() ++ gallery_variables()
        _ -> []
      end

    client_variables(job) ++ photograopher_variables(current_user) ++ leads ++ other
  end

  defp gallery_variables() do
    [
      %{
        type: "gallery",
        variables: [
          %{
            id: 1,
            name: "gallery_name",
            sample: "Gallery name",
            description: "Gallery name"
          },
          %{
            id: 2,
            name: "password",
            sample: "81234",
            description: "Password that has been generated for a client gallery"
          },
          %{
            id: 3,
            name: "gallery_link",
            sample: "https://gallerylinkhere.com",
            description: "Link to the client gallery"
          },
          %{
            id: 4,
            name: "album_password",
            sample: "75642",
            description: "Password that has been generaged for a gallery album"
          },
          %{
            id: 5,
            name: "gallery_expiration_date",
            sample: "August 15, 2023",
            description: "Expiration date of the specific gallery formatted as Month DD, YYYY"
          },
          %{
            id: 6,
            name: "download_photos",
            sample: "https://gallerydownloadshere.com",
            description: "Link to the download gallery photos"
          },
          %{
            id: 7,
            name: "order_first_name",
            sample: "Jane",
            description: "First name to personalize gallery order emails"
          },
          %{
            id: 8,
            name: "album_link",
            sample: "https://albumlinkhere.com",
            description: "Link to individual album, such as proofing, within client gallery"
          },
          %{
            id: 9,
            name: "client_gallery_order_page",
            sample: "https://clientgalleryorderpage.com",
            description: "Link for client to view their completed gallery order"
          }
        ]
      }
    ]
  end

  defp client_variables(job) do
    name = get_client_data(job)
    [
      %{
        type: "client",
        variables: [
          %{
            id: 1,
            name: "client_first_name",
            sample: name |> String.split(" ") |> List.first(),
            description: "Client first name to personalize emails"
          },
          %{
            id: 2,
            name: "client_full_name",
            sample: name,
            description: "Client full name to personalize emails"
          }
        ]
      }
    ]
  end

  defp photograopher_variables(user) do
    name = get_photopgrapher_data(user)
    [
      %{
        type: "photographer",
        variables: [
          %{
            id: 1,
            name: "photography_company_s_name",
            sample: name,
            description: "photohrapher company"
          },
          %{
            id: 2,
            name: "email_signature",
            sample: name,
            description: "Included on every email sent from your Picsello account"
          },
          %{
            id: 3,
            name: "photographer_cell",
            sample: "(123) 456-7891",
            description:
              "Your cellphone so clients can communicate with you on the day of the shoot"
          }
        ]
      }
    ]
  end

  defp job_variables() do
    [
      %{
        type: "job",
        variables: [
          %{
            id: 1,
            name: "delivery_time",
            sample: "two weeks",
            description:
              "Image turnaround time in number of weeks; image turnaround time is _ weeks"
          },
          %{
            id: 2,
            name: "invoice_due_date",
            sample: "August 15, 2023",
            description: "Invoice due date to reinforce timely client payments"
          },
          %{
            id: 3,
            name: "invoice_amount",
            sample: "450 USD",
            description: "Invoice amount; use in context with payments and balances due"
          },
          %{
            id: 4,
            name: "payment_amount",
            sample: "775 USD",
            description: "Current payment being made"
          },
          %{
            id: 5,
            name: "remaining_amount",
            sample: "650 USD",
            description: "Outstanding balance due; use in context with payments, invoices"
          },
          %{
            id: 6,
            name: "session_date",
            sample: "August 15, 2023",
            description: "Shoot/Session date formatted as Month DD, YYYY"
          },
          %{
            id: 7,
            name: "session_location",
            sample: "123 Main Street, Anytown, NY 12345",
            description:
              "Name and address of where the shoot will be held including street, town, state and zipcode"
          },
          %{
            id: 8,
            name: "session_time",
            sample: "1:00:00 PM",
            description: "Start time for the photoshoot shoot/session; formatted as 10:00 pm"
          },
          %{
            id: 9,
            name: "view_proposal_button",
            sample: "https://bookingproposalhere.com ",
            description:
              "Link for clients to access their secure portal to make payments and keep in touch"
          }
        ]
      }
    ]
  end

  defp get_photopgrapher_data(user) do
    Map.get(user.organization, :name, "John lee") |> String.capitalize()
  end

  defp get_client_data(nil), do: "Jane Goodrich"
  defp get_client_data(job) do
    Map.get(job.client, :name, "John Goodrich") |> String.capitalize()
  end

end
