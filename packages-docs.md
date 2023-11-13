# Picsello Package Management 

## Package Base Prices

The Picsello system Getting its base price for packages from third party(google sheet) `Picsello.Workers.SyncTiers` module is responsible for it. From admin page we can synce it 

### Schema

- `base_price`: Represents the base_price using the `Money.Ecto.Map.Type`. 
- `print_credits`: Represents the print_credits using the `Money.Ecto.Map.Type`
- `buy_all`: Represents the buy_all using the `Money.Ecto.Map.Type`
- `description`: Description in string.
- `download_count`: Download count in integer.
- `full_time`: A boolean field .
- `job_type`: A string field for job_type like new_born.
- `min_years_experience`: min_years_experience in integer 
- `shoot_count`: shoot_count in integer
- `max_session_per_year`: max_session_per_year max_session_per_year
- `tier`: A string field for tier like 'essential' 
- `turnaround_weeks`: turnaround_weeks in 
- `timestamps`: Includes `inserted_at` and `updated_at` of type `utc_datetime`.

## Package

Package is crucel in this feature. System is handling it through this `Picsello.Packages` module. 

You can add a package template from packages. It will create a record with `package_template_id: nil`
While creating template  you can associate it with qustioniere and contract.   

When you add a package from lead that will add  copy of template record and you can customize that
copy of record will  have value of `package_template_id: template_id`

All data related to packages like discount/surcharge, qustioniere, job_type  store in this `packages` table except last step of payment in modal

### Embeded Schemas

Package have following embeded schemas with their responsbalitis
- `Multiplier`: Its responsible for discount/surcharge value on base_price/digital/crediits.
- `PackagePricing`: Its responsible for setting buy_all and package price
- `Download`: its responsbile for digital photos like per each photo price and how many are free  in digital

### Schema
- `archived_at`: Represents that package is archived or not its value is stored in utc_datetime. 
- `base_multiplier`: Represents  discount/surcharge will be calcualated on the basis of this value
- `base_price`: Represents the base price of a session with currency in `Money.Ecto.Map.Type`
- `description`: Represent the description of a package.
- `thumbnail_url`: Represent Photo you have attached with package value is string.
- `download_count`: Represent Download count in integer.
- `download_each_price`: Represent per photo price value in `Money.Ecto.Map.Type`
- `name`: Represent a name of package in string
- `shoot_count`: Represent shoot count you have selected in integer
- `print_credits`: max_session_per_year max_session_per_year
- `buy_all`: Represents that you can buy all photo in this price using the `Money.Ecto.Map.Type`
- `collected_price`: Represents that price collected  
- `turnaround_weeks`: Represents how many weeks require in integer
- `schedule_type`: Represents that schedule type like custom in string
- `fixed`: Represents price is fixed or not in boolean .
- `show_on_public_profile`: should show on public site or not in boolean.
- `print_credits_include_in_total`: should printcredits include in total or not in boolean.
- `digitals_include_in_total`: should digitals include in total or not in boolean.
- `discount_base_price`: should discount on basic session price  or not in boolean.
- `discount_digitals`: should discount on digitals or not in boolean.
- `discount_print_credits`: should discount print_credits or not in boolean.
- `questionnaire_template_id`: A string field for tier like 'essential' 
- `organization_id`: turnaround_weeks in 
- `package_template_id`: Represent that this package have join with itself so its nil value show that package is template
- `timestamps`: Includes `inserted_at` and `updated_at` of type `utc_datetime`.

## Package Payment Presets

We can defined both pre and custom presets for scheduling package payments based on package job types. 
These presets are exclusively customized plans for scheduling payments,
whether they are fixed amounts or based on a percentage.


### Schema
- `schedule_type`: Represent that is related to custom or simple job type in string. 
- `job_type`: Represents category in string 
- `fixed`: Represents  that is it fixed or % in boolean


## Package Payment schedule

In this keep record of schedule payment plans
Suppose we have split amount in three then three record of that preset will be added 
### Schema
- `price`: price of this payment in `Money.Ecto.Map.Type`.
- `percentage`: Represents that how much % it will take in integer
- `interval`: Represents  in boolean
- `due_interval`: Represent that due_interval from pre_defined like booking etc in string  .
- `count_interval`: Represents that interval in string
- `time_interval`: Represents  time_interval in string like "Day"
- `shoot_interval`: Represents description of shoot interval in string.
- `percentage`: Represents that how much % it will take in integer
- `due_at`: Represents  due at date
- `schedule_date`: Represents that on which date it is for
- `Package_id`: Represents Package if nil then its record for preset it will be in ineteger
- `package_payment_preset_id`: Represents package_payment_preset in integer
