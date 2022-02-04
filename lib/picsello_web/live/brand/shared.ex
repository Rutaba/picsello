defmodule PicselloWeb.Live.Brand.Shared do
  @moduledoc false

  import Phoenix.LiveView
  use Phoenix.Component
  use Phoenix.HTML

  def email_signature_preview(assigns) do
    ~H"""
    <div>
      <div class="input-label mb-4">Signature Preview</div>
      <div class="shadow-2xl rounded-lg px-6 pb-6 raw_html">
        <div>
          <%= raw Phoenix.View.render_to_string(PicselloWeb.EmailSignatureView, "show.html", organization: @organization, user: @user) %>
        </div>
      </div>
    </div>
    """
  end
end
