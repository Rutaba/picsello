defmodule Picsello.Profiles do
  @moduledoc "context module for public photographer profile"
  import Ecto.Query, only: [from: 2]

  alias Picsello.{
    Repo,
    Organization,
    Job,
    JobType,
    ClientMessage,
    Client,
    Accounts.User,
    Notifiers.UserNotifier
  }

  require Logger

  defmodule ProfileImage do
    @moduledoc "a public image embedded in the profile json"
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:url, :string)
      field(:content_type, :string)
    end

    def changeset(profile_image, attrs) do
      cast(profile_image, attrs, [:id, :url, :content_type])
    end
  end

  defmodule Profile do
    @moduledoc "used to render the organization public profile"
    use Ecto.Schema
    import Ecto.Changeset

    @colors ~w(#5C6578 #312B3F #865678 #93B6D6 #A98C77 #ECABAE #9E5D5D #6E967E)
    @default_color hd(@colors)

    def colors(), do: @colors

    def default_color(), do: @default_color

    @primary_key false
    embedded_schema do
      field :is_enabled, :boolean, default: true
      field(:color, :string)
      field(:job_types, {:array, :string})
      field(:no_website, :boolean, default: false)
      field(:website, :string)
      field(:website_login, :string)
      field(:description, :string)
      field(:job_types_description, :string)
      embeds_one(:logo, ProfileImage, on_replace: :update)
      embeds_one(:main_image, ProfileImage, on_replace: :update)
    end

    def enabled?(%__MODULE__{is_enabled: is_enabled}), do: is_enabled

    def changeset(%__MODULE__{} = profile, attrs) do
      profile
      |> cast(
        attrs,
        ~w[no_website website website_login color job_types description job_types_description]a
      )
      |> then(
        &if get_field(&1, :no_website),
          do: put_change(&1, :website, nil),
          else: &1
      )
      |> cast_embed(:logo)
      |> cast_embed(:main_image)
      |> prepare_changes(&clean_job_types/1)
      |> validate_change(:website, &for(e <- url_validation_errors(&2), do: {&1, e}))
      |> validate_change(:website_login, &for(e <- url_validation_errors(&2), do: {&1, e}))
    end

    defp url_validation_errors(url) do
      case URI.parse(url) do
        %{scheme: nil} ->
          ("https://" <> url) |> url_validation_errors()

        %{scheme: scheme, host: "" <> host} when scheme in ["http", "https"] ->
          label = "[a-zA-Z0-9\\-]{1,63}+"

          if "^(?:(?:#{label})\\.)+(?:#{label})$"
             |> Regex.compile!()
             |> Regex.match?(host),
             do: [],
             else: ["is invalid"]

        %{scheme: _scheme} ->
          ["is invalid"]
      end
    end

    defp clean_job_types(changeset) do
      update_change(changeset, :job_types, fn
        list -> list |> Enum.filter(&(&1 != "")) |> Enum.uniq() |> Enum.sort()
      end)
    end
  end

  defmodule Contact do
    @moduledoc "container for the contact form data"
    use Ecto.Schema
    import Ecto.Changeset
    import Picsello.Client, only: [valid_phone: 2]
    import Picsello.Accounts.User, only: [validate_email_format: 1]
    import PicselloWeb.Gettext

    @fields ~w[name email phone job_type message]a

    embedded_schema do
      for field <- @fields do
        field field, :string
      end
    end

    def changeset(%__MODULE__{} = contact, attrs) do
      contact
      |> cast(attrs, @fields)
      |> validate_email_format()
      |> validate_required(@fields)
      |> validate_change(:phone, &valid_phone/2)
    end

    def to_string(%__MODULE__{} = contact) do
      """
          name: #{contact.name}
         email: #{contact.email}
         phone: #{contact.phone}
      job type: #{dyn_gettext(contact.job_type)}
       message: #{contact.message}
      """
    end
  end

  def contact_changeset(contact, attrs) do
    Contact.changeset(contact, attrs)
  end

  def contact_changeset(attrs) do
    Contact.changeset(%Contact{}, attrs)
  end

  def contact_changeset() do
    Contact.changeset(%Contact{}, %{})
  end

  def edit_organization_profile_changeset(%Organization{} = organization, attrs) do
    Organization.edit_profile_changeset(organization, attrs)
  end

  def update_organization_profile(%Organization{} = organization, attrs) do
    organization |> edit_organization_profile_changeset(attrs) |> Repo.update()
  end

  def handle_contact(%{id: organization_id} = _organization, params, helpers) do
    changeset = contact_changeset(params)

    case changeset do
      %{valid?: true} ->
        contact = Ecto.Changeset.apply_changes(changeset)

        {:ok, _} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(
            :client,
            contact
            |> Map.take([:name, :email, :phone])
            |> Map.put(:organization_id, organization_id)
            |> Client.create_changeset(),
            on_conflict: {:replace, [:email]},
            conflict_target: [:organization_id, :email],
            returning: [:id]
          )
          |> Ecto.Multi.insert(
            :lead,
            &Job.create_changeset(%{type: contact.job_type, client_id: &1.client.id})
          )
          |> Ecto.Multi.insert(
            :message,
            &ClientMessage.create_inbound_changeset(%{
              job_id: &1.lead.id,
              subject: "New lead from profile",
              body_text: Contact.to_string(contact)
            })
          )
          |> Ecto.Multi.run(
            :email,
            fn _, changes ->
              UserNotifier.deliver_new_lead_email(changes.lead, contact.message, helpers)

              {:ok, :email}
            end
          )
          |> Repo.transaction()

        {:ok, contact}

      _ ->
        {:error, Map.put(changeset, :action, :validate)}
    end
  end

  def find_organization_by(slug: slug) do
    from(
      o in Organization,
      where:
        (o.slug == ^slug or o.previous_slug == ^slug) and
          fragment("coalesce((profile -> 'is_enabled')::boolean, true)"),
      order_by:
        fragment(
          """
          case
            when ?.slug = ? then 0
            when ?.previous_slug = ? then 1
          end asc
          """,
          o,
          ^slug,
          o,
          ^slug
        ),
      limit: 1,
      preload: [:user]
    )
    |> Repo.one!()
  end

  def find_organization_by(user: %User{} = user) do
    user |> Repo.preload(organization: :user) |> Map.get(:organization)
  end

  def enabled?(%Organization{profile: profile}), do: Profile.enabled?(profile)

  def toggle(%Organization{} = organization) do
    organization
    |> Ecto.Changeset.change(%{profile: %{is_enabled: !enabled?(organization)}})
    |> Repo.update!()
  end

  defdelegate colors(), to: Profile
  defdelegate job_types(), to: JobType, as: :all

  def color(%Organization{profile: %{color: color}}), do: color
  def color(_), do: Profile.default_color()

  def public_url(%Organization{slug: slug}) do
    PicselloWeb.Router.Helpers.profile_url(PicselloWeb.Endpoint, :index, slug)
  end

  def embed_url(%Organization{slug: slug}) do
    PicselloWeb.Router.Helpers.lead_contact_iframe_url(
      PicselloWeb.Endpoint,
      :index,
      slug
    )
  end

  def embed_code(%Organization{} = organization) do
    ~s(<iframe src="#{embed_url(organization)}" frameborder="0" style="max-width:100%;width:100%;height:100%;min-height:700px;"></iframe>)
  end

  def subscribe_to_photo_processed(%{slug: slug}) do
    topic = "profile_photo_ready:#{slug}"

    Phoenix.PubSub.subscribe(Picsello.PubSub, topic)
  end

  defp delete_image_from_storage(url) do
    Task.start(fn ->
      url
      |> URI.parse()
      |> Map.get(:path)
      |> Path.split()
      |> Enum.drop(2)
      |> Path.join()
      |> Picsello.Galleries.Workers.PhotoStorage.delete(bucket())
    end)
  end

  def handle_photo_processed_message(path, id) do
    image_field = if String.contains?(path, "main_image"), do: "main_image", else: "logo"

    image_field_atom = String.to_atom(image_field)

    from(org in Organization, where: fragment("profile -> ? ->> 'id' = ? ", ^image_field, ^id))
    |> Repo.all()
    |> case do
      [%{profile: profile} = organization] ->
        url = %URI{host: static_host(), path: "/" <> path, scheme: "https"} |> URI.to_string()

        {:ok, organization} =
          update_organization_profile(organization, %{
            profile: %{image_field_atom => %{url: url}}
          })

        topic = "profile_photo_ready:#{organization.slug}"

        Phoenix.PubSub.broadcast(
          Picsello.PubSub,
          topic,
          {:image_ready, image_field_atom, organization}
        )

        with %{^image_field_atom => %{url: "" <> old_url}} <- profile do
          delete_image_from_storage(old_url)
        end

      _ ->
        Logger.warn("ignoring path #{path} for version #{id}")
    end

    :ok
  end

  def remove_photo(organization, image_field) do
    image_url = Map.get(organization.profile, image_field).url

    {:ok, organization} =
      update_organization_profile(organization, %{
        profile: %{image_field => nil}
      })

    delete_image_from_storage(image_url)

    organization
  end

  def preflight(%{upload_config: image_field} = image, organization) do
    resize_height =
      %{
        logo: 104,
        main_image: 600
      }
      |> Map.get(image_field)

    params =
      Picsello.Galleries.Workers.PhotoStorage.params_for_upload(
        expires_in: 600,
        bucket: bucket(),
        key: to_filename(organization, image, "original"),
        fields:
          %{
            "resize" => Jason.encode!(%{height: resize_height, withoutEnlargement: true}),
            "pubsub-topic" => output_topic(),
            "version-id" => image.uuid,
            "out-filename" => to_filename(organization, image, "#{image.uuid}.png", ["resized"])
          }
          |> meta_fields()
          |> Enum.into(%{
            "content-type" => image.client_type,
            "cache-control" => "public, max-age=@upload_options"
          }),
        conditions: [["content-length-range", 0, 104_857_600]]
      )

    meta = params |> Map.take([:url, :key, :fields]) |> Map.put(:uploader, "GCS")

    {:ok, organization} =
      update_organization_profile(organization, %{
        profile: %{image_field => %{id: image.uuid, content_type: image.client_type}}
      })

    {:ok, meta, organization}
  end

  def logo_url(organization) do
    case organization do
      %{profile: %{logo: %{url: "" <> url}}} -> url
      _ -> nil
    end
  end

  defp to_filename(organization, %{client_type: content_type} = image, name),
    do:
      to_filename(
        organization,
        image,
        Enum.join([name, content_type |> MIME.extensions() |> hd], "."),
        []
      )

  defp to_filename(
         %{slug: slug},
         %{
           upload_config: upload_type
         },
         name,
         subdir
       ),
       do:
         [[slug, Atom.to_string(upload_type)], subdir, [name]]
         |> Enum.concat()
         |> Path.join()

  defp meta_fields(fields),
    do:
      for(
        {key, value} <- fields,
        into: %{},
        do: {Enum.join(["x-goog-meta", key], "-"), value}
      )

  defp output_topic, do: Application.get_env(:picsello, :photo_processing_output_topic)

  defp bucket, do: Keyword.get(config(), :bucket)

  defp static_host, do: Keyword.get(config(), :static_host)

  defp config(), do: Application.get_env(:picsello, :profile_images)
end
