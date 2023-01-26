defmodule PicselloWeb.Live.Profile.CopyContactFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [footer: 1, close_x: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="mb-4 text-3xl font-bold">Preview form embed</h1>
        <.close_x />
      </div>
      <div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-12 flex items-center">
          <div>
            <div class="rounded-lg shadow-xl p-4">
              <%= raw @embed_code %>
            </div>
          </div>
          <div>
            <h2 class="text-2xl font-bold mb-4 sm:mt-0 mt-4">Tips & Tricks</h2>
            <hr />
            <dl class="mb-4">
              <dt class="font-bold mt-4">How do I embed this on my website platform?</dt>
              <dd class="text-base-250">If you are using Wordpress, SquareSpace, Wix or any other page builder system, you will need to put this code in a “code block” or “custom HTML embed”.</dd>
              <dt class="font-bold mt-4">Where should I put this form layout wise?</dt>
              <dd class="text-base-250">You should put this on your contact page, at the bottom of most pages and anywhere that may be a place where you think your clients will traffic most often. For example: your most popular blog posts or portfolio pages.</dd>
              <dt class="font-bold mt-4">Help! It looks funny on my site.</dt>
              <dd class="text-base-250">You may need to change the width and height of the form to fit within where you embedded. We’ve done our best to make this form as responsive as possible. If you continue to have trouble, please contact us.</dd>
            </dl>
            <hr />
            <div class="mt-4">
              <label class="font-bold" id="copy-embed-code" phx-hook="Clipboard" data-clipboard-text={@embed_code} data-clipboard-bg="bg-white">
              Embed code
                <textarea class="w-full text-input mt-2" readonly><%= @embed_code %></textarea>
                <div class="hidden p-1 mt-1 text-sm rounded shadow bg-base-100 font-normal" role="tooltip">Copied!</div>
              </label>
            </div>
          </div>
        </div>
      </div>
      <.footer>
        <button class="btn-primary" type="submit" id="copy-embed-code-footer" phx-hook="Clipboard" data-clipboard-text={@embed_code} data-clipboard-bg="bg-white" title="copy and close" type="button" phx-click="modal" phx-value-action="close">
          Copy & Close
          <div class="hidden p-1 mt-1 text-sm rounded shadow bg-base-100 font-normal text-base-300" role="tooltip">Copied!</div>
        </button>
        <button class="btn-secondary" title="close" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
      </.footer>
    </div>
    """
  end
end
