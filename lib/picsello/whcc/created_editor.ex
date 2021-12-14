defmodule Picsello.WHCC.CreatedEditor do
  @moduledoc "Editor creation responce from WHCC API"
  defstruct [:url, :editor_id]

  @type t :: %__MODULE__{
          editor_id: String.t(),
          url: String.t()
        }

  def from_map(%{"url" => url, "editorId" => editor_id}) do
    %__MODULE__{
      url: url |> to_string(),
      editor_id: editor_id |> to_string()
    }
  end
end
