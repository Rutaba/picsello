defmodule PicselloWeb.LayoutView do
  use PicselloWeb, :view

  alias Picsello.Accounts.User
  alias Picsello.Payments

  import PicselloWeb.LiveHelpers,
    only: [
      testid: 1,
      classes: 2,
      icon: 1,
      nav_link: 1,
      classes: 1,
      initials_circle: 1
    ]

  import Picsello.Profiles, only: [public_url: 1]

  import PicselloWeb.Live.Profile.Shared, only: [photographer_logo: 1]
  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1, gallery_top_banner: 1]

  use Phoenix.Component

  defp default_meta_tags do
    for(
      {meta_name, config_key} <- %{
        "google-site-verification" => :google_site_verification,
        "google-maps-api-key" => :google_maps_api_key
      },
      reduce: %{}
    ) do
      acc ->
        case Application.get_env(:picsello, config_key) do
          nil -> acc
          value -> Map.put(acc, meta_name, value)
        end
    end
  end

  def meta_tags(nil) do
    meta_tags(%{})
  end

  def meta_tags(attrs_list) do
    Map.merge(default_meta_tags(), attrs_list)
  end

  def dynamic_background_class(%{main_class: main_class}), do: main_class

  def dynamic_background_class(_), do: nil

  defp flash_styles,
    do: [
      {:error, "error", "text-red-sales-300"},
      {:info, "info", "text-blue-planning-300"},
      {:success, "tick", "text-green-finances-300"}
    ]

  def flash(flash) do
    assigns = %{flash: flash}

    ~H"""
    <div>
      <%= for {key, icon, text_color} <- flash_styles(), message <- [live_flash(@flash, key)], message do %>
        <%= if(key in [:error, :info, :success])  do %>
        <div phx-hook="Flash" id={"flash-#{DateTime.to_unix(DateTime.utc_now)}"} phx-click="lv:clear-flash" phx-value-key={key} title={key} class="fixed right-10-md right-0 top-1.5 z-40 max-w-lg px-1.5 px-0-md flash" role="alert">
          <div class="flex bg-white rounded-lg shadow-lg cursor-pointer">
            <div class={classes(["flex items-center justify-center p-3", text_color])}>
              <.icon name={icon} class="w-6 h-6 stroke-current" />
            </div>
            <div class="flex items-center justify-center font-sans flex-grow px-3 py-2 mr-7">
              <p><%= message %></p>
            </div>
            <div class="flex items-center justify-center mr-3">
              <.icon name="close-x" class="w-3 h-3 stroke-current" />
            </div>
          </div>
        </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def google_analytics(assigns) do
    ~H"""
    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src={"https://www.googletagmanager.com/gtag/js?id=#{@gaId}"}></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());

      gtag('config', '<%= @gaId %>');
    </script>
    """
  end

  def google_tag_manager(assigns) do
    ~H"""
    <!-- Google Tag Manager -->
    <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
    new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
    j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
    'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
    })(window,document,'script','dataLayer','<%= @gtmId %>');</script>
    <!-- End Google Tag Manager -->

    <!-- Google Tag Manager (noscript) -->
    <noscript><iframe src={"https://www.googletagmanager.com/ns.html?id=#{@gtmId}"}
    height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
    <!-- End Google Tag Manager (noscript) -->
    """
  end

  def help_chat_widget(
        %{assigns: %{current_user: %{email: _, user_id: _}}} = assigns
      ) do
    assigns = get_intercom_id(assigns)

    ~H"""
    <%= if @itercom_id do %>
      <script>
        window.intercomSettings = {
          api_base: "https://api-iam.intercom.io",
          app_id: "<%= @itercom_id %>",
          name: "<%= @current_user.name %>",
          email: "<%= @current_user.email %>",
          user_id: "<%= @current_user.id %>",
          created_at: "<%= @current_user.inserted_at %>",
          custom_launcher_selector: '.open-help'
        };
      </script>

      <.reattach_activator itercom_id={@itercom_id} />
    <% end %>
    """
  end

  def help_chat_widget(assigns) do
    assigns = get_intercom_id(assigns)

    ~H"""
    <%= if @itercom_id do %>
      <script>
        window.intercomSettings = {
          api_base: "https://api-iam.intercom.io",
          app_id: "<%= @itercom_id %>",
          custom_launcher_selector: '.open-help'
        };
      </script>
      <.reattach_activator itercom_id={@itercom_id} />
    <% end %>
    """
  end

  def side_nav(socket, _current_user) do
    [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{title: "Clients", icon: "phone", path: Routes.clients_path(socket, :index)},
      %{
        title: "Galleries",
        icon: "proof_notifier",
        path: Routes.gallery_path(socket, :galleries)
      },
      %{title: "Calendar", icon: "calendar", path: Routes.calendar_index_path(socket, :index)},
      %{title: "Orders", icon: "cart"},
      %{title: "Inbox", icon: "envelope", path: Routes.inbox_path(socket, :index)},
      %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)},
      %{
        title: "Questionnaires",
        icon: "package",
        path: Routes.questionnaires_index_path(socket, :index)
      },
      %{
        title: "Finances",
        icon: "money-bags",
        path: Routes.finance_settings_path(socket, :index)
      },
      %{title: "Settings", icon: "gear", path: Routes.user_settings_path(socket, :edit)},
      %{
        title: "Public profile",
        icon: "profile",
        path: Routes.profile_settings_path(socket, :index)
      },
      %{
        title: "Help",
        icon: "question-mark",
        path: "https://support.picsello.com"
      }
    ]
    |> Enum.filter(&Map.get(&1, :path))
  end

  def sub_nav(socket, _current_user),
    do: [
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Jobs", icon: "camera-check", path: Routes.job_path(socket, :jobs)},
      %{
        title: "Galleries",
        icon: "proof_notifier",
        path: Routes.gallery_path(socket, :galleries)
      },
      %{
        title: "Packages",
        icon: "package",
        path: Routes.package_templates_path(socket, :index)
      },
      %{
        title: "Booking Events",
        icon: "calendar",
        path: Routes.calendar_booking_events_path(socket, :index)
      }
    ]

  def subscription_ending_soon(%{current_user: current_user} = assigns) do
    subscription = current_user |> Picsello.Subscriptions.subscription_ending_soon_info()
    assigns = Enum.into(assigns, %{subscription: subscription})

    case assigns.type do
      "header" ->
        ~H"""
        <div class={classes(%{"hidden" => @subscription.hidden_30_days?})}>
          <%= live_redirect to: Routes.user_settings_path(@socket, :edit), class: "flex gap-2 items-center mr-4" do %>
            <h6 class="text-xs italic text-gray-250 opacity-50">Trial ending soon! <%= ngettext("1 day", "%{count} days", Map.get(@subscription, :days_left, 0)) %> left.</h6>
            <button class="hidden sm:block text-xs rounded-lg px-4 py-1 border border-blue-planning-300 font-semibold hover:bg-blue-planning-100">Renew plan</button>
          <% end %>
        </div>
        """

      "banner" ->
        ~H"""
        <div {testid("subscription-top-banner")} class={classes(@class, %{"hidden" => @subscription.hidden?})}>
          <.icon name="clock-filled" class="lg:w-5 lg:h-5 w-8 h-8 mr-2"/>
          <span>You have <%= ngettext("1 day", "%{count} days", Map.get(@subscription, :days_left, 0)) %> left before your subscription ends.
            <%= live_redirect to: Routes.user_settings_path(@socket, :edit), title: "Click here" do %>
              <span class="font-bold underline px-1 cursor-pointer">Click here</span>
            <% end %>
            to upgrade.
          </span>
        </div>
        """

      _ ->
        ~H"""
        <div {testid("subscription-footer")} class={classes(@class, %{"hidden" => @subscription.hidden?})}>
          <%= live_redirect to: Routes.user_settings_path(@socket, :edit) do %>
            <%= ngettext("1 day", "%{count} days", Map.get(@subscription, :days_left, 0)) %> left until your subscription ends
          <% end %>
        </div>
        """
    end
  end

  def admin_banner(assigns) do
    ~H"""
    <div class="hidden fixed top-4 right-4 p-2 bg-red-sales-300/25 rounded-lg text-red-sales-300 shadow-lg backdrop-blur-md z-[1000]" id="admin-banner">
      <span class="font-bold">You are logged in as a user, please log out when finished</span>
      <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete, class: "ml-4 btn-tertiary px-2 py-1 text-sm text-red-sales-300") %>
    </div>
    """
  end

  def main_header(assigns) do
    ~H"""
    <header class="border-b fixed left-0 right-0 top-0 z-40 bg-white">
      <div class="flex items-center px-6 center-container">
        <div id="hamburger-menu" class="relative cursor-pointer" phx-update="ignore" phx-hook="ToggleContent">
          <%= if @current_user do %>
          <div class="absolute left-0 z-10 flex flex-col items-start hidden cursor-default -top-2 toggle-content">
            <div class="p-4 -mb-2 bg-white shadow-md cursor-pointer text-base-300">
              <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2" />
            </div>

            <nav class="flex flex-col bg-white rounded-lg shadow-md">
              <%= for %{title: title, icon: icon, path: path} <- side_nav(@socket, @current_user), @current_user do %>
                <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="px-4 flex items-center py-3 whitespace-nowrap hover:bg-blue-planning-100 hover:font-bold" active_class="bg-blue-planning-100 font-bold">
                  <.icon name={icon} class="inline-block w-5 h-5 mr-2 text-blue-planning-300 shrink-0" />
                  <%= title %>
                </.nav_link>
              <% end %>
            </nav>
          </div>

          <.icon name="hamburger" class="h-4 text-base-300 w-9" />
          <% end %>
        </div>

        <nav class="flex items-center justify-center flex-1 mx-8 lg:justify-start">
          <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
            <.icon name="logo" class="my-4 w-28 h-9 mr-6" />
          <% end %>

          <div class="hidden lg:flex">
            <div id="sub-menu" class="relative cursor-pointer" phx-update="ignore" phx-hook="ToggleContent" data-icon="toggle-icon">
              <div class="absolute left-0 z-10 flex flex-col items-start hidden cursor-default top-10 toggle-content">
                <nav class="flex flex-col bg-white rounded-lg shadow-md">
                  <%= for %{title: title, icon: icon, path: path} <- sub_nav(@socket, @current_user), @current_user do %>
                    <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="px-4 flex items-center py-3 whitespace-nowrap hover:bg-blue-planning-100 hover:font-bold" active_class="bg-blue-planning-100 font-bold">
                      <.icon name={icon} class="inline-block w-5 h-5 mr-2 text-blue-planning-300 shrink-0" />
                      <%= title %>
                    </.nav_link>
                  <% end %>
                </nav>
              </div>

              <div class="group hidden lg:flex items-center mr-6 transition-all font-bold text-blue-planning-300 hover:opacity-70">
              Your work <.icon name="down" class="w-3 h-3 stroke-current stroke-3 ml-2 toggle-icon transition-transform group-hover:rotate-180" />
              </div>
            </div>
            <.nav_link title="Calendar" to="/calendar" socket={@socket} live_action={@live_action} class="hidden lg:block items-center mr-6 transition-all font-bold text-blue-planning-300 hover:opacity-70" active_class="">
              Calendar
            </.nav_link>
            <.nav_link title="Help" to="https://support.picsello.com/" socket={@socket} live_action={@live_action} class="hidden lg:block items-center mr-6 transition-all font-bold text-blue-planning-300 hover:opacity-70" active_class="">
              Help
            </.nav_link>
            <.nav_link title="Settings" to="/users/settings" socket={@socket} live_action={@live_action} class="hidden lg:block items-center mr-6 transition-all font-bold text-blue-planning-300 hover:opacity-70" active_class="">
              Settings
            </.nav_link>
          </div>
        </nav>

        <.subscription_ending_soon type="header" socket={@socket} current_user={@current_user} />
        <div id="initials-menu" class="relative flex flex-row justify-end cursor-pointer" phx-update="ignore" phx-hook="ToggleContent">
          <%= if @current_user do %>
            <div class="absolute top-0 right-0 flex flex-col items-end hidden cursor-default text-base-300 toggle-content">
              <div class="p-4 -mb-2 bg-white shadow-md cursor-pointer text-base-300">
                <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2" />
              </div>
              <div class="bg-gray-100 rounded-lg shadow-md w-max z-30">
                <%= live_redirect to: Routes.user_settings_path(@socket, :edit), title: "Account", class: "flex items-center px-2 py-2 bg-white" do %>
                  <.initials_circle user={@current_user} />
                  <div class="ml-2 font-semibold">Account</div>
                <% end %>

                <%= if Enum.any?(@current_user.onboarding.intro_states) do %>
                  <.live_component module={PicselloWeb.Live.RestartTourComponent} id="current_user", current_user={@current_user} />
                <% end %>
                <.form :let={_} for={%{}} as={:sign_out} action={Routes.user_session_path(@socket, :delete)} method="delete">
                  <%= submit "Logout", class: "text-center py-2 w-full" %>
                </.form>
              </div>
            </div>
            <div class="flex flex-col items-center justify-center text-sm text-base-300 bg-gray-100 rounded-full w-9 h-9 pb-0.5" title={@current_user.name}>
              <%= User.initials @current_user %>
            </div>
          <% end %>
        </div>
      </div>
    </header>
    """
  end

  def stripe_setup_banner(%{current_user: current_user} = assigns) do
    stripe_status = Payments.simple_status(current_user)
    assigns = Enum.into(assigns, %{stripe_status: stripe_status})

    ~H"""
    <%= if !Enum.member?([:charges_enabled, :loading], @stripe_status) do %>
      <div class="bg-gray-100 py-3 border-b border-b-white">
        <div class="center-container px-6">
          <div class="flex justify-between items-center gap-2">
            <details class="cursor-pointer text-base-250 group">
              <summary class="flex items-center font-bold text-black">
                <.icon name="confetti" class="w-5 h-5 mr-2 text-blue-planning-300"/>
                Get paid within Picsello!
                <.icon name="down" class="w-4 h-4 stroke-current stroke-2 text-blue-planning-300 ml-2 group-open:rotate-180" />
              </summary>
              To accept money from bookings & galleries, connect your Stripe account and add a payment method. <em>We also offer offline payments for bookings only. <a href="https://support.picsello.com/article/32-set-up-stripe" class="underline" target="_blank" rel="noreferrer">Learn more</a></em>
            </details>
            <div class="flex gap-2">
              <a href={Routes.finance_settings_path(@socket, :index)} class="flex text-xs items-center px-2 py-1 btn-tertiary bg-blue-planning-300 text-white hover:bg-blue-planning-300/75">
                <.icon name="settings" class="inline-block w-4 h-4 fill-current text-white mr-1" />
                Connect Stripe
              </a>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def main_footer(assigns) do
    ~H"""
    <div class="mt-12"></div>
    <footer class="mt-auto hidden sm:block bg-base-300 text-white">
      <div class="px-6 center-container py-10">
        <div class="flex justify-between gap-8">
          <nav class="flex text-lg font-bold mt-4 w-full items-center">
            <ul class="flex">
              <li><a href="https://support.picsello.com/" target="_blank" rel="noopener noreferrer">Help center</a></li>
              <%= if @current_user && Application.get_env(:picsello, :intercom_id) do %>
              <li><a href="#help" class="ml-10 open-help">Contact us</a></li>
              <% end %>
              <li><a class="ml-10" href="https://www.picsello.com/blog" target="_blank" rel="noopener noreferrer">Blog</a></li>
            </ul>
            <.subscription_ending_soon type="footer" socket={@socket} current_user={@current_user} class="flex ml-auto bg-white text-black rounded px-4 py-2 items-center text-sm"/>
          </nav>
          <div>
            <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Footer" do %>
              <.icon name="logo-shoot-higher" class="h-12 sm:h-16 w-32 sm:w-36" />
            <% end %>
          </div>
        </div>
        <hr class="my-8 opacity-30" />
        <div class="flex">
          <div class="text-base-250 text-xs">Copyright © <%= DateTime.utc_now.year %> Picsello</div>
          <ul class="flex ml-auto">
            <li class="text-base-250 text-xs"><a href="https://www.picsello.com/terms-conditions" target="_blank" rel="noopener noreferrer">Terms</a></li>
            <li class="text-base-250 text-xs"><a href="https://www.picsello.com/privacy-policy" class="ml-10" target="_blank" rel="noopener noreferrer">Privacy Policy</a></li>
            <li class="text-base-250 text-xs"><a href="https://www.picsello.com/privacy-policy#ccpa" class="ml-10" target="_blank" rel="noopener noreferrer">California Privacy</a></li>
          </ul>
        </div>
      </div>
    </footer>
    """
  end

  defp footer_nav(assigns) do
    organization = load_organization(assigns.gallery)
    assigns = Enum.into(assigns, %{organization: organization})

    ~H"""
    <nav class="flex text-lg font-bold">
      <div class="font-bold">
        <.photographer_logo organization={@organization} />
      </div>
      <div class="ml-auto pt-3">
        <a class="flex items-center justify-center px-2.5 py-1 text-base-300 bg-base-100 border border-base-300 hover:text-base-100 hover:bg-base-300" href={"#{public_url(@organization)}#contact-form"}>
          <.icon name="envelope" class="mr-2 w-4 h-4 fill-current"/>
          Contact
        </a>
      </div>
    </nav>
    <hr class="my-8 opacity-30 border-base-300" />
    <div class="flex text-base-250 flex-col sm:flex-row">
      <div class="flex justify-center">©<%= DateTime.utc_now.year %> <span class="font-base-300 font-bold ml-2"><%= @organization.name %></span>. All Rights Reserved</div>
      <div class="flex md:ml-auto justify-center">
        Powered by
        <a href="https://www.picsello.com/terms-conditions" class="underline ml-1" target="_blank" rel="noopener noreferrer"> <b>Picsello</b></a>
      </div>
    </div>
    """
  end

  defp reattach_activator(assigns) do
    ~H"""
    <script>
    (function(){var w=window;var ic=w.Intercom;if(typeof ic==="function"){ic('reattach_activator');ic('update',w.intercomSettings);}else{var d=document;var i=function(){i.c(arguments);};i.q=[];i.c=function(args){i.q.push(args);};w.Intercom=i;var l=function(){var s=d.createElement('script');s.type='text/javascript';s.async=true;s.src='https://widget.intercom.io/widget/<%= @itercom_id %>';var x=d.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};if(document.readyState==='complete'){l();}else if(w.attachEvent){w.attachEvent('onload',l);}else{w.addEventListener('load',l,false);}}})();
    </script>
    """
  end

  defp load_organization(gallery) do
    gallery
    |> Picsello.Repo.preload([job: [client: :organization]], force: true)
    |> extract_organization()
  end

  defp get_intercom_id(assigns), do: assign(assigns, :itercom_id, Application.get_env(:picsello, :intercom_id))

  defp extract_organization(%{job: %{client: %{organization: organization}}}), do: organization
end
