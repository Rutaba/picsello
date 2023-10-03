# TODO: This file will remove once unit test cases will handle

# Booking Events Version 1 Test Scenarios
# Slots check
    # Example: 1
        # duration_length = 15 duration_buffer = 5
        # Time blocks
        # 5:00 - 6:00 (slots [5:00 - 5:20] [5:20 - 5:40] [5:40 - 6:00])

    # Example: 2
        # duration_length = 15 duration_buffer = 20
        # Time blocks
        # 5:00 - 6:00 (slots [5:00 - 5:35] [5:35 - 5:50])

    # Example: 3
        # duration_length = 5 duration_buffer = 20
        # Time blocks
        # option_1 5:00 - 6:00 (slots [5:00 - 5:25] [5:25 - 5:50] [5:50 - 5:55] [5:55 - 6:00])
        # option_2 5:00 - 6:00 (slots [5:00 - 5:25] [5:25 - 5:50] [5:50 - 5:55])
# Overlap time
    # currenlty we are checking time_block overlap or not, with in selected date and its time block
    # We have bugs in current prod version, let say for booking event#1 for date 18th sept, user select time block
       # 5:00 - 8:00 (date 18th sept)
       # 4:00 - 6:00 (date 18th sept)
      # if that scenario you check on current prod it will not show time overlap, but actually time is overlapping bcz date is same and time is overlapping.

    # Time Blocks
        # Example#1
            # 7:00 - 8:00
            # 4:00 - 6:00
            # 8:00 - 8:30
            # Expected Result (It's Fine , no time overlap)

        # Example#2
            # 4:00 - 8:00
            # 4:00 - 6:00
            # 8:00 - 8:30
            # Expected Result (Time overlap)

        # Example#2
            # 7:00 - 8:00
            # 4:00 - 9:00
            # 8:00 - 8:30
            # Expected Result (Time overlap)


# Booking Events Version 2 Test Scenarios
 # SLots count Remember is same as previous version

 # Time Block overlap
    - Time overlap means for selected date and selected time there is another booking_event or aonther booking_event_date there is conflict with time of same date
    # Example 1
        - Booking_event_1 has date 19-09-2023 time selected is 3:00 pm to 7:00pm
        - Now you are creating a new booking_event or with in same booking_event_1 adding a new event date
        - Let say date now adding is 19-09-2023 and time is selected (12:00pm to 4:00) pm or let say (4:00 to 7:00) on these both selected time it shows time overlap.
        - But let say if user selects (12:00pm to 3:00pm) or (7:00pm to 8:00pm) it should works fine without showing any error
    # Example 2 
        - Perform above test on already created booking_event_date try to edit that booking_event_date and change something from slot let say hide some slot and check is this showing `time overlap or not` if this showing then thats the bug.
        - when check time overlap or not skip to compare with current booking_event_date
    # if slot book or reserve can't hide that slot
    # if booking_event_date any slot booked can't edit that booking_event_date -> * needs to be confirm 

# Repeat dates
    1- if user selects repeat date section on while adding date, in background fetch all upcoming dates and check on each date there is any time overlap of selected time block (start_time, end_time), if any repeat date time overlap with any booking_event ot current_booking_event then changeset valid will be false, otherwise true.
    2- Insert/delete repeat dates while adding booking event date modal.
        - if user selects repeat date and all validation pass from step-1 then on save booking_event_date, there is condition which is checking that given condition 
        - Let say repeat dates are [19-09-2023, 20-10-2023, 10-11-2023] so we are checking for every date and selected time block is there any booked slot exist or not, if its exist then that means we don't need to insert repeat dates at all we skipp repeat dates otherwise first delete those dates of 
