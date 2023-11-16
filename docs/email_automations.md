# `Email Automation Feature Documentation`

Email automation, as the name depicts is somewhat related to the automations of the email-system in Picsello. So this feature covers all the aspect
of email-notifications which trigger on the basis of various conditions i.e. some emails trigger whenever a client pays a retainer, some emails trigger on the basis of order-confirmations and some emails trigger whenever there's some balance due for any client etc. So this feature spans over 15,000 lines of code collectively divided into various files across the file directory. So before explaining the details related to each of those files
distributed over the directory of picsello-project - I will first enlist the related files path here:

```elixir
 - lib/picsello/email_automations.ex
 - lib/picsello/notifiers/email_automation_notifier.ex
 - lib/picsello/email_automation/email_automation_pipeline.ex
 - lib/picsello/email_automation_schedules.ex
 - lib/picsello/email_automation/email_automation_category.ex
 - lib/picsello/email_automation/email_automation_sub_category.ex
 - lib/picsello/notifiers/email_automation/impl.ex
 - lib/picsello/email_automation/email_preset.ex
 - lib/picsello/email_automation/email_schedule_history.ex
 - lib/picsello/email_automation/email_schedule.ex
 - lib/picsello/email_automation/gallery_resolver.ex
 - lib/picsello/email_automation/job_resolver.ex
 - lib/picsello_web/live/email_automation_live/add_email_component.ex
 - lib/picsello_web/live/email_automation_live/edit_email_component.ex
 - lib/picsello_web/live/email_automation_live/edit_email_schedule_component.ex
 - lib/picsello_web/live/email_automation_live/edit_time_component.ex
 - lib/picsello_web/live/email_automation_live/index.ex
 - lib/picsello_web/live/email_automation_live/index.html.heex
 - lib/picsello_web/live/email_automation_live/shared.ex
 - lib/picsello_web/live/email_automation_live/show.ex
 - lib/picsello_web/live/email_automation_live/show.html.heex
 - lib/picsello_web/live/email_automation_live/template_preview_component.ex
```

So now, lets take each of the file and I'll explain the purpose, functions being used in it and everything about it in details below:

# `Picsello.EmailAutomations`

The `Picsello.EmailAutomations` module provides functionality for managing and automating email communication within the Picsello application. This module contains functions for retrieving email presets, managing email automation pipelines, and sending automated emails. This module serves as a context for email automation within the Picsello application.

## `Dependencies`

Before using the functions in this module, ensure you have the following dependencies properly configured:

- Ecto for database operations.
- Phoenix for web functionalities.
- Picsello database schema and relevant modules.

## `Functions`

- `get_emails_for_schedule/4`
- `get_sub_categories/0`
- `get_pipeline_by_id/1`
- `get_pipeline_by_state/1`
- `update_pipeline_and_settings_status/2`
- `delete_email/1`
- `get_email_by_id/1`
- `get_all_pipelines_emails/2`
- `resolve_variables/3`
- `resolve_all_subjects/4`
- `create_pipeline/4`
- `update_pipeline/2`
- `create_or_update_email/2`
- `send_email/2`

# `Picsello.Notifiers.EmailAutomationNotifier`

The `Picsello.Notifiers.EmailAutomationNotifier` module defines a behavior for delivering automation emails for different scenarios. It provides callback functions for delivering emails related to jobs, galleries, and orders within the Picsello application. This module is part of the Picsello application and serves as an abstraction for delivering automated email notifications in various contexts, such as jobs, galleries, and orders.

## `Callback Functions`

This module defines the following callback functions, which must be implemented by modules that use this behavior:

### `deliver_automation_email_job/5`

Delivers an automation email related to a job. This function is responsible for delivering an automation email for a job, using the provided email preset, job data, schema, state, and helper information.

#### `Callback Signature`

```elixir
@callback deliver_automation_email_job(email_preset :: map(), job :: map(), schema :: tuple(), state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

### `deliver_automation_email_gallery/5`

Delivers an automation email related to a gallery. This function is responsible for delivering an automation email for a gallery, using the provided email preset, gallery data, schema, state, and helper information.

#### `Callback Signature`

```elixir
@callback deliver_automation_email_gallery(email_preset :: map(), gallery :: map(), schema :: tuple(), state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

### `deliver_automation_email_order/5`

Delivers an automation email related to an order. This function is responsible for delivering an automation email for an order, using the provided email preset, order data, schema, state, and helper information.

#### `Callback Signature`

```elixir
@callback deliver_automation_email_order(email_preset :: map(), order :: map(), schema :: tuple(), state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

# `Picsello.Notifiers.EmailAutomationNotifier.Impl`

The `Picsello.Notifiers.EmailAutomationNotifier.Impl` module is the implementation module for the `EmailAutomationNotifier` behavior. It provides concrete implementations for delivering automation emails in various contexts such as jobs, galleries, and orders within the Picsello application. This module is responsible for implementing the behavior defined in the `EmailAutomationNotifier` module. It handles the delivery of automation emails for different scenarios by resolving email templates and delivering them to the appropriate recipients.

## `Callback Functions Implementation`

This module implements the callback functions defined in the `EmailAutomationNotifier` behavior.

### `deliver_automation_email_job/5`

Delivers an automation email related to a job. This function is responsible for delivering an automation email for a job. It resolves the email subject and body templates, determines the recipient, and delivers the email.

#### `Callback Implementation`

```elixir
@spec deliver_automation_email_job(email_preset :: map(), job :: map(), schema :: tuple(), _state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

### `deliver_automation_email_gallery/5`

Delivers an automation email related to a gallery. This function is responsible for delivering an automation email for a gallery. It resolves the email subject and body templates, determines the recipient, and delivers the email.

#### `Callback Implementation`

```elixir
@spec deliver_automation_email_gallery(email_preset :: map(), gallery :: map(), schema :: tuple(), _state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

### `deliver_automation_email_order/5`

Delivers an automation email related to an order. This function is responsible for delivering an automation email for an order. It resolves the email subject and body templates, determines the recipient based on the order's delivery information, and delivers the email.

#### `Callback Implementation`

```elixir
@spec deliver_automation_email_order(email_preset :: map(), order :: map(), _schema :: tuple(), _state :: atom(), helpers :: any()) ::
  {:error, binary() | map()} | {:ok, map()}
```

# `Picsello.EmailAutomationSchedules`

The `Picsello.EmailAutomationSchedules` module serves as the context module for email automation within the Picsello application. This module provides functions to interact with email automation schedules, enabling the retrieval of email schedules by various criteria such as `job_id`, `gallery_id`, and `order_id`. It also facilitates the insertion of email templates for different categories and types, making it an essential part of Picsello's email automation system.

## `Module Functions`

### `get_schedule_by_id/1`

Retrieves an email schedule by its unique identifier.

```elixir
  get_schedule_by_id(id :: any()) :: map() | nil
```

### `get_emails_by_gallery/3`

Retrieves a list of email schedules associated with a gallery by gallery_id and type.

```elixir
  get_emails_by_gallery(table :: any(), gallery_id :: any(), type :: any()) :: [map()]
```

### `get_emails_by_order/3`

Retrieves a list of email schedules associated with an order by order_id and type.

```elixir
  get_emails_by_order(table :: any(), order_id :: any(), type :: any()) :: [map()]
```

### `get_emails_by_job/3`

Retrieves a list of email schedules associated with a job by job_id and type.

```elixir
  get_emails_by_job(table :: any(), job_id :: any(), type :: any()) :: [map()]
```

### `get_active_email_schedule_count/1`

Calculates the count of active email schedules related to a job. It considers both job-level and gallery-level email schedules.

```elixir
  get_active_email_schedule_count(job_id :: any()) :: integer()
```

### `get_email_schedules_by_ids/2`

Retrieves email schedules by their IDs and type. This function allows fetching email schedules by a list of IDs, considering both the EmailSchedule and EmailScheduleHistory tables.

```elixir
  get_email_schedules_by_ids(ids :: [any()], type :: any()) :: [map()]
```

### `update_email_schedule/2`

Updates an email schedule. This function is overloaded to handle two different scenarios. In the first scenario, it inserts a new entry into the EmailScheduleHistory table and deletes the original schedule. In the second scenario, it updates the existing schedule directly.

```elixir
  update_email_schedule(id :: any(), params :: map()) :: {:ok, any()} | any()
```

### `filter_email_schedule/3`

Filters email schedules based on either galleries or jobs, depending on the given parameters.

```elixir
  filter_email_schedule(query :: any(), galleries :: [any()], :gallery | :job) :: any()
```

### `email_schedules_group_by_categories/1`

Groups email schedules by categories and subcategories, making it easier to manage and access them. The result is a structured map.

```elixir
  email_schedules_group_by_categories(emails_schedules :: [map()]) :: [map()]
```

### `query_get_email_schedule/5`

Constructs a query for retrieving email schedules based on category type, gallery ID, and job ID. The resulting query can be used to fetch email schedules.

```elixir
  query_get_email_schedule(
    category_type :: atom(),
    gallery_id :: any(),
    job_id :: any(),
    piepline_id :: any(),
    table :: any() \\ EmailSchedule
  ) :: query()
```

### `get_last_completed_email/6`

Retrieves the last completed email schedule based on category type, gallery ID, job ID, pipeline ID, and a set of custom state transitions and sorting functions.

```elixir
  get_last_completed_email(
    category_type :: atom(),
    gallery_id :: any(),
    job_id :: any(),
    pipeline_id :: any(),
    state :: any(),
    helpers :: any()
  ) :: map() | nil
```

### `job_emails/4`

Inserts email templates for jobs and leads into email schedules based on the given parameters. It filters out email templates based on specified states.

```elixir
  job_emails(
    type :: atom(),
    organization_id :: any(),
    job_id :: any(),
    category_type :: atom(),
    skip_states :: [atom()]
  ) :: [map()]
```

### `insert_job_emails_from_gallery/2`

Inserts email templates for a gallery based on the provided type.

```elixir
  insert_job_emails_from_gallery(gallery :: map(), type :: atom()) :: {:ok, integer()} | {:error, string()}
```

### `gallery_order_emails/2`

Inserts email templates for galleries or orders, considering the type and available subcategories. It avoids inserting email templates that already exist.

```elixir
  gallery_order_emails(gallery :: map(), order :: map()) :: [map()]
```

### `insert_gallery_order_emails/2`

Inserts email templates for a gallery or order into email schedules.

```elixir
  insert_gallery_order_emails(gallery :: map(), order :: map()) :: {:ok, integer()} | {:error, string()}
```

### `insert_job_emails/5`

Inserts email templates for jobs based on the specified parameters. It allows filtering out email templates based on certain states.

```elixir
  insert_job_emails(
    type :: atom(),
    organization_id :: any(),
    job_id :: any(),
    category_type :: atom(),
    skip_states :: [atom()]
  ) :: {:ok, integer()} | {:error, string()}
```

### `email_mapping/4`

Maps email data to a standardized format for insertion into email schedules.

```elixir
  email_mapping(data :: [map()], gallery :: map(), category_type :: atom(), order_id :: any()) :: [map()]
```

# `Picsello.EmailPresets`

The `Picsello.EmailPresets` module is a context module responsible for handling email presets within the Picsello application. This module provides functions to work with email presets, allowing you to retrieve presets based on various criteria, such as type, job type, and pipeline ID. It also provides the ability to resolve variables within email presets and render email templates based on the provided data.

## `Module Functions`

### `email_automation_presets/3`

Retrieves email presets based on type, job type, and pipeline ID.

```elixir
  email_automation_presets(type :: any(), job_type :: any(), pipeline_id :: any()) :: [map()]
```

### `user_email_automation_presets/4`

Retrieves user-specific email presets based on type, job type, pipeline ID, and organization ID.

```elixir
  user_email_automation_presets(type :: any(), job_type :: any(), pipeline_id :: any(), org_id :: any()) :: [map()]
```

### `for/2 (Overloaded)`

Retrieves email presets for either a Gallery or Job based on the provided object and state.

```elixir
  for(%Gallery{} = gallery :: map(), state :: any()) :: [map()]
  for(%Job{type: job_type} = job :: map(), state :: any()) :: [map()]
  for(%Job{type: job_type} = job :: map()) :: [map()]
```

### `resolve_variables/3`

Resolves variables within an email preset, rendering email templates based on provided schemas and helpers.

```elixir
  resolve_variables(preset :: map(), schemas :: any(), helpers :: any()) :: map()
```

### `job_presets/0`

Retrieves email presets for job-related scenarios.

```elixir
job_presets() :: [map()]
```

### `gallery_presets/0`

Retrieves email presets for gallery-related scenarios.

```elixir
gallery_presets() :: [map()]
```

### `presets/1`

Retrieves email presets based on the specified type and orders them by position.

```elixir
  presets(type :: any()) :: query()
```

### `Function Overloads`

The `for/2 function` is overloaded to retrieve email presets based on a Gallery or a Job object and the desired state. Depending on the object's type and state, the appropriate logic is applied to fetch email presets.

# `PicselloWeb.EmailAutomationLive.AddEmailComponent`

The `PicselloWeb.EmailAutomationLive.AddEmailComponent` module is responsible for handling email automation in the Picsello application. It provides live components for adding and configuring email presets for automation.

## `Module Functions`

- `update/2` (Overloaded): Handles updates for the live component. It includes logic to manage different steps of email automation setup.
- `step_valid?/1`: Validates if the current step is valid based on the provided assigns.
- `handle_event/3` (Multiple Function Definitions): Handles various events triggered within the live component, such as going back to the previous step, toggling the display of email variables, validating input, submitting data, and more.
- `render/1`: Defines the rendering logic for the live component based on the current step.
- `assign_changeset/2`: Prepares the changeset for saving email presets.
- `save/1`: Saves email presets and associates them with selected job types.

## `Function Overloads`

- The `update/2` function is overloaded to handle different scenarios based on the current step and assigns provided in the socket.
- The `handle_event/3` function has multiple definitions to handle various events and actions within the live component.

## `Usage`

- Use the `update/2` function to handle updates for the live component. This function is overloaded to manage different steps of email automation setup.
- Utilize the `step_valid?/1` function to validate the current step based on the provided assigns.
- The `handle_event/3` function handles various events within the live component, such as navigating between steps, toggling email variables, validating input, and submitting data.
- The `render/1` function defines the rendering logic for the live component based on the current step.
- The `assign_changeset/2` function prepares the changeset for saving email presets.
- Use the `save/1` function to save email presets and associate them with selected job types.

# `PicselloWeb.EmailAutomationLive.EditEmailComponent`

The code defines a module named `EditEmailComponent` in the `PicselloWeb.EmailAutomationLive` namespace.

## `Module Attributes`
- `@moduledoc false`: This module attribute hides the module documentation.

## `Module Imports`
Several `import` statements bring in functions and modules from other parts of the application for use within this module.

## `Alias`
- `alias Picsello.{Repo, EmailPresets, EmailPresets.EmailPreset}`: It provides aliases for modules used later in the code.

## `Module-level Constants`
- `@steps`: This module attribute defines a list of steps (phases) for email template editing.

## `Update Function`
- The `update/2` function handles various update events based on parameters and socket state:
  - The first clause updates the socket with various assigns and returns an `ok/1` response.
  - The second clause updates the `job_types` in the socket and returns an `ok/1` response.
  - The third clause updates the socket with assigns for the final step, "preview_email," and returns an `ok/1` response.

## `Helper Functions`
- `remove_duplicate/2`: A private function that removes duplicate email presets from a list.
- `step_valid?/1`: A private function that checks if all email presets in the assigns are valid and validates job types.

## `Event Handlers`
- Several `handle_event/3` functions handle events like going back, validating email presets, submitting email templates, and toggling variables.

## `Render Function`
- The `render/1` function defines the HTML structure of the LiveView component, including form elements and UI components for editing and previewing email templates.

## `step/1` Functions
- Two `step/1` functions are used to define the HTML structure for different steps of the email editing process.

## `step_buttons/1` Functions
- Two `step_buttons/1` functions define the buttons for the different steps of the email editing process.

## `save/1` Function
- The `save/1` function handles saving email template changes to the database. It performs database operations using Ecto's Multi transaction and returns an `ok/1` or `error` result.

The code structure follows the standard conventions for a Phoenix LiveView component, with functions for handling events, rendering the UI, and processing user interactions. It provides a clear separation of concerns between different steps and components in the email template editing process.

# `PicselloWeb.EmailAutomationLive.EditEmailScheduleComponent`

This Elixir Phoenix LiveView module, named `EditEmailScheduleComponent`, serves the purpose of allowing users to edit and preview email templates in the context of email scheduling within the picsello-application.

## `Module Configuration`

- `@moduledoc false`: This attribute hides the module documentation.
- `use PicselloWeb, :live_component`: The module makes use of the `PicselloWeb` application with the `:live_component` functionality.
- Import statements bring in functions and modules for use within the module.

## `Module Aliases`

- The module sets up aliases for the `Repo`, `EmailPresets`, and `EmailAutomation.EmailSchedule` modules to interact with the database and email scheduling data.

## `Module-level Constants`

- `@steps`: This module attribute defines a list of steps (phases) for email template editing.

## `Update Function`

- The `update/2` function handles different update events based on the provided parameters and the socket's state.
- It allows users to edit email templates, preview them, and assign various attributes to the socket, including job types, email presets, and email templates.
- This function is called when users interact with the UI components in the LiveView.

## `Helper Functions`

- `remove_duplicate/2`: A private function that removes duplicate email presets from a list.
- `step_valid?/1`: A private function that checks if all email presets in the assigns are valid.

## `Event Handlers`

- Several `handle_event/3` functions handle events such as going back, validating email presets, submitting email templates, and toggling variables.

## `Render Function`

- The `render/1` function defines the HTML structure of the LiveView component, including form elements and UI components for editing and previewing email templates.

## `step/1` Functions

- Two `step/1` functions are used to define the HTML structure for different steps of the email editing process. These steps include editing email templates and previewing them.

## `step_buttons/1` Functions

- Two `step_buttons/1` functions define the buttons for the different steps of the email editing process. Buttons include "Next" and "Save."

## `save/1` Function

- The `save/1` function handles saving email template changes to the database. It performs database operations using Ecto's Multi transaction and returns an `ok/1` or `error` result. This function ensures that edited email templates are persisted in the application's data store.

In summary, this module plays a crucial role in facilitating the editing and previewing of email templates in the context of email scheduling within the Picsello application. Users can interact with various UI components to create and save email templates for future scheduling.

# `PicselloWeb.EmailAutomationLive.EditTimeComponent`

This Elixir Phoenix LiveView module, named `EditTimeComponent`, serves the purpose of enabling users to edit and configure the timing settings for email automation within an application.

## `Module Configuration`

- `@moduledoc false`: This attribute hides the module documentation.
- `use PicselloWeb, :live_component`: The module makes use of the `PicselloWeb` application with the `:live_component` functionality.
- Import statements bring in functions and modules for use within the module.

## `Module Aliases`

- The module sets up aliases for the `Repo`, `EmailPresets.EmailPreset`, and `EmailAutomations` modules to interact with the database and email automation settings data.

## `Update Function`

- The `update/2` function handles the initial setup of email automation settings based on the provided parameters and the socket's state.
- It conditionally sets the email automation to send immediately or at a certain time based on the total hours.
- A changeset is created for these settings.

## `Helper Functions`

- `step_valid?/1`: A private function that checks if the changeset is valid.

## `Event Handlers`

- The `handle_event/3` functions handle events for validating email automation settings and saving the changes.

## `Save Function`

- The `save/1` function handles the process of saving the email automation settings to the database.
- It uses Ecto's `Repo.insert/2` to perform the insert operation.
- The function returns an `ok/1` result upon successful insertion and sends an update message, or an `error` result, handling validation errors.

## `Render Function`

- The `render/1` function defines the HTML structure of the LiveView component. It includes a form for configuring email automation timing settings.

In summary, this module allows users to configure the timing settings for email automation, determining when emails should be sent. Users can choose to send emails immediately or at specific times, and these settings are saved to the database. The module is an essential part of the application's email automation functionality.

# `PicselloWeb.Live.EmailAutomations.Index`

This Elixir Phoenix LiveView module, `PicselloWeb.Live.EmailAutomations.Index`, serves the purpose of managing and displaying email automation settings and email templates within an application.

## `Module Configuration`

- `@moduledoc false`: This attribute hides the module documentation.
- `use PicselloWeb, :live_view`: The module uses the `PicselloWeb` application with the `:live_view` functionality.
- Import statements are used to include functions and modules from other modules.

## `Mount Function`

- The `mount/3` function initializes the LiveView when it's mounted and assigns initial values to the socket, such as page title and mobile state.

## `Default Assigns Function`

- The `default_assigns/1` function sets up default socket assigns, including job types, automation pipelines, and collapsed sections.

## `Assign Job Types Function`

- The `assign_job_types/1` function assigns job types to the socket.
- It fetches job types related to the current user's organization from the database.

## `Event Handlers`

The module handles various events triggered by user interactions:

- `"back_to_navbar"`: Toggles the mobile state.
- `"assign_templates_by_type"`: Assigns templates based on job type.
- `"add-email-popup"`: Opens a modal for adding email templates.
- `"edit-time-popup" and "edit-email-popup"`: Open modals for editing time and email templates, respectively.
- `"delete-email"`: Initiates email template deletion with a confirmation popup.
- `"toggle-section"`: Toggles the visibility of email automation pipeline sections.
- `"toggle"`: Enables or disables email automation pipelines.
- `"confirm-delete-email"`: Handles the confirmation of email template deletion.

## `Pipeline Section Function`

- The `pipeline_section/1` function generates HTML for email automation pipeline sections.
- It displays the pipeline's name, description, and associated email templates, allowing users to add, edit, and delete email templates.

## `Helper Functions`

- `is_pipeline_active?/1`: Determines if a pipeline is active.
- `disabled_email?/1`: Checks if the email template is disabled.

In summary, this module allows users to manage email automation settings and templates. It provides a user interface for adding, editing, and deleting email templates within automation pipelines. Users can also enable or disable entire email automation sequences. The module's functionality is essential for configuring email automation within the application.

# `PicselloWeb.EmailAutomationLive.Shared` 

The `PicselloWeb.EmailAutomationLive.Shared` module is part of the PicselloWeb application. It contains functions and utilities related to email automation in a Phoenix LiveView context. This module handles the update of email automation settings, email templates, and other related functionalities.

## `Functions`

This module has soo many context functions and helper actions that are being used over and over in email-automation feature, I'll enlist the details of few functions below:

### `handle_info({:update_automation, %{message: message}}, socket)`
- `Description`: Handles an update automation event and assigns automation pipelines.
- `Returns`: A modified socket.
  
### `handle_info({:load_template_preview, component, body_html}, socket)`
- `Description`: Loads and previews an email template.
- `Returns`: A modified socket.

### `preview_template(socket)`
- `Description`: Compiles section values, renders the body_html, and assigns the `template_preview`, `email_preset_changeset`, and `step` to the socket.
- `Returns`: `{:noreply, socket}`.

## `make_email_presets_options(email_presets, state)`
- `Description`: Generates options for email presets.
- `Returns`: A list of name-value pairs.

### `make_sign_options(state)`
- `Description`: Generates sign options for email automation schedules.
- `Returns`: A list of sign options.

### `email_preset_changeset(socket, email_preset, params \\ nil)`
- `Description`: Builds an email preset changeset and optionally pushes a quill update event.
- `Returns`: A modified socket with the `email_preset_changeset` assigned.

### `assign_automation_pipelines(socket)`
- `Description`: Assigns automation pipelines to the socket.
- `Returns`: A modified socket with `automation_pipelines` assigned.

### `get_pipeline(pipeline_id)`
- `Description`: Fetches an email automation pipeline by its ID.
- `Returns`: A pipeline with associated data.

### `sort_emails(emails, state)`
- `Description`: Sorts emails based on various criteria, including state.
- `Returns`: A sorted list of emails.

### `state?(state)`
- `Description`: Checks if the state represents a manually triggered event.
- `Returns`: A boolean indicating if the state is manual.

AND MANY MOREEEE...!

# `Some Most-Important Points to Remember`

- Some of the emails are disabled by default to enable them, you need to follow below mentioned-steps:
  - Visit http://localhost:4000/email-automations url on your local, or just click `Email Automations` from the dropdown menu of navbar
  - Open any `email-pipeline` and enable or disable it by `Enable Sequence` or `Disable Sequence` buttons.
- If there are no automations in the job or lead, it most probably means that lead/job is old one.
- Email automations is yet in beta-version.
- Email Scheduler works every 10-minutes, and finds out which emails needs to be send and trigger those ones only.
- Shoot Reminder emails will popup in the job email-automation pipelines automatically when you will add up the shoots details `(Keeping in mind that shoot-reminder emails are enabled)`
- Email Pipelines along-with their triggering scenarios:
  - `Client Pays Retainer`: Triggers when a user pays online retainer amount
  - `Client Pays Retainer (Offline)`: Triggers when a user pays offline retainer amount through mark-paid modal. A thing to remember, if there is only 1 payment and you make the whole-payment then this `client-pays-retainer-offline` email will not trigger.
  - `Thank You for Booking`: This email triggers when user signs the contract and questionnaire and retainer is paid `(either online or offline)`
  - `Client Contacts You`: This email triggers when your client contacts you via your Picsello public profile or contact form unless you disable the automation
  - `Inquiry and Follow up Emails`: These emails are manually triggered, i.e. you will have to use the send-now button to trigger them.
  - `Booking proposal and Follow up Emails`: These emails are also manually triggered.
  - `Balance Due`: This email is triggered whenever there's a payment due within a payment schedule.
  - `Balance Due (Offline)`: Triggered when a payment is due within a payment schedule that is offline.
  - `Paid in Full`: Triggered when a payment schedule is completed.
  - `Paid in Full (Offline)`: Triggered when a payment schedule is completed from offline payments.
  - `Before the Shoot`: Triggers a week before the shoot and sends another day before the shoot.
  - `Thank You`: Triggers after a shoot with emails 1 day & 1–9 months later to encourage reviews/bookings.
  - `Post Shoot Follow-up`: Sends 3 months and 9 months after the shoot was done.
  - `Send Standard Gallery Link`: Manually triggered email.
  - `Send Proofing Gallery for Selection`: Manually triggered email.
  - `Send Proofing Gallery Finals`: Manually triggered email.
  - `Cart Abandoned`: These emails are triggered when you leave the cart with items, and they trigger with following sequence 1 hour after, 1 day after and 2 days after.
  - `Gallery expiring soon`: This email triggeres whenever your gallery is expiring i.e. 7 days before expiring, 3 days before expiring and 1 day before expiring.
  - `Gallery Send Feedback`: This triggers whenever you share the standard or final gallery.
  - `Order Received (Physical/Digital Products)`: This will trigger when an order has been completed.
  - `Digitals Ready for Download`: This will trigger when digitals are packed and ready for download.
  - `Abandoned Booking Event Emails`: These emails will trigger whenever you leave the booking-event abandoned. 

