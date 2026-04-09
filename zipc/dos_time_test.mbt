// Comprehensive tests for DOS time/date conversion

///|
test "dos time conversion basic functionality" {
  // Test known values
  let unix_time = 1640995200 // 2022-01-01 00:00:00 UTC
  let (dos_time, dos_date) = @zipc.unix_to_dos_datetime(unix_time)

  // Verify the conversion produces reasonable values
  inspect(dos_time >= 0, content="true")
  inspect(dos_date >= 0, content="true")

  // Test round-trip conversion
  let converted_back = @zipc.dos_datetime_to_unix(dos_time, dos_date)

  // Should be close (within a day due to time zone and precision differences)
  let diff = if converted_back > unix_time {
    converted_back - unix_time
  } else {
    unix_time - converted_back
  }
  inspect(diff < 86400, content="true") // Within 24 hours
}

///|
test "dos time component extraction" {
  // Test @zipc.make_dos_datetime and component extraction
  let (dos_time, dos_date) = @zipc.make_dos_datetime(2022, 6, 15, 14, 30, 45)
  let (year, month, day, hour, minute, second) = @zipc.dos_datetime_components(
    dos_time, dos_date,
  )
  inspect(year, content="2022")
  inspect(month, content="6")
  inspect(day, content="15")
  inspect(hour, content="14")
  inspect(minute, content="30")
  inspect(second, content="44") // DOS time has 2-second precision, so 45 becomes 44
}

///|
test "dos time edge cases" {
  // Test DOS epoch (1980-01-01 00:00:00)
  let (dos_time_epoch, dos_date_epoch) = @zipc.unix_to_dos_datetime(
    @zipc.dos_epoch,
  )
  let (year, month, day, hour, minute, second) = @zipc.dos_datetime_components(
    dos_time_epoch, dos_date_epoch,
  )
  inspect(year, content="1980")
  inspect(month, content="1")
  inspect(day, content="1")
  inspect(hour, content="0")
  inspect(minute, content="0")
  inspect(second, content="0")

  // Test before DOS epoch
  let before_epoch = @zipc.dos_epoch - 86400 // One day before
  let (dos_time_before, dos_date_before) = @zipc.unix_to_dos_datetime(
    before_epoch,
  )

  // Should clamp to minimum DOS date/time
  inspect(dos_time_before, content="0")
  inspect(dos_date_before, content="33") // 0x0021 = 1980-01-01
}

///|
test "dos time boundary values" {
  // Test maximum DOS date (2107-12-31)
  let (dos_time_max, dos_date_max) = @zipc.make_dos_datetime(
    2107, 12, 31, 23, 59, 58,
  )
  let (year, month, day, hour, minute, second) = @zipc.dos_datetime_components(
    dos_time_max, dos_date_max,
  )
  inspect(year, content="2107")
  inspect(month, content="12")
  inspect(day, content="31")
  inspect(hour, content="23")
  inspect(minute, content="59")
  inspect(second, content="58")

  // Test clamping of out-of-range values
  let (dos_time_clamp, dos_date_clamp) = @zipc.make_dos_datetime(
    2200, 15, 35, 25, 70, 80,
  )
  let (year_c, month_c, day_c, hour_c, minute_c, second_c) = @zipc.dos_datetime_components(
    dos_time_clamp, dos_date_clamp,
  )
  inspect(year_c, content="2107") // Clamped to max
  inspect(month_c, content="12") // Clamped to max
  inspect(day_c, content="31") // Clamped to max
  inspect(hour_c, content="23") // Clamped to max
  inspect(minute_c, content="59") // Clamped to max
  inspect(second_c, content="58") // Clamped to max (and 2-second precision)
}

///|
test "dos time formatting" {
  // Test human-readable formatting
  let (dos_time, dos_date) = @zipc.make_dos_datetime(2023, 7, 4, 16, 45, 30)
  let formatted = @zipc.format_dos_datetime(dos_time, dos_date)
  inspect(formatted, content="2023-07-04 16:45:30")

  // Test formatting with single digits
  let (dos_time2, dos_date2) = @zipc.make_dos_datetime(2001, 3, 8, 9, 5, 2)
  let formatted2 = @zipc.format_dos_datetime(dos_time2, dos_date2)
  inspect(formatted2, content="2001-03-08 09:05:02")
}

///|
test "dos time leap year handling" {
  // Test leap year (2020)
  let leap_year_time = @zipc.dos_datetime_to_unix(0, (40 << 9) | (2 << 5) | 29) // 2020-02-29 00:00:00
  let (dos_time_leap, dos_date_leap) = @zipc.unix_to_dos_datetime(
    leap_year_time,
  )
  let (year, month, day, _, _, _) = @zipc.dos_datetime_components(
    dos_time_leap, dos_date_leap,
  )

  // Should handle leap year correctly
  inspect(year, content="2020")
  inspect(month, content="2")
  inspect(day, content="29")

  // Test non-leap year (2021)
  let non_leap_year_time = @zipc.dos_datetime_to_unix(
    0,
    (41 << 9) | (2 << 5) | 28,
  ) // 2021-02-28 00:00:00
  let (dos_time_non_leap, dos_date_non_leap) = @zipc.unix_to_dos_datetime(
    non_leap_year_time,
  )
  let (year2, month2, day2, _, _, _) = @zipc.dos_datetime_components(
    dos_time_non_leap, dos_date_non_leap,
  )
  inspect(year2, content="2021")
  inspect(month2, content="2")
  inspect(day2, content="28")
}

///|
test "dos time precision" {
  // Test 2-second precision of DOS time
  let (dos_time_odd, _) = @zipc.make_dos_datetime(2022, 1, 1, 12, 0, 31) // Odd second
  let (dos_time_even, _) = @zipc.make_dos_datetime(2022, 1, 1, 12, 0, 32) // Even second
  let (_, _, _, _, _, second_odd) = @zipc.dos_datetime_components(
    dos_time_odd, 0,
  )
  let (_, _, _, _, _, second_even) = @zipc.dos_datetime_components(
    dos_time_even, 0,
  )

  // Odd seconds should be rounded down
  inspect(second_odd, content="30")
  inspect(second_even, content="32")
}

///|
test "dos time current timestamp" {
  // Test current timestamp function (placeholder)
  let current = @zipc.current_unix_timestamp()

  // Should be a reasonable timestamp (after 2020)
  inspect(current > 1577836800, content="true") // 2020-01-01 00:00:00 UTC

  // Should convert to DOS time without error
  let (dos_time, dos_date) = @zipc.unix_to_dos_datetime(current)
  inspect(dos_time >= 0, content="true")
  inspect(dos_date >= 0, content="true")
}

///|
test "dos time invalid date handling" {
  // Test invalid DOS date/time values
  let invalid_unix = @zipc.dos_datetime_to_unix(0xffff, 0xffff) // Invalid values

  // Should return DOS epoch for invalid dates
  inspect(invalid_unix, content=@zipc.dos_epoch.to_string())

  // Test zero values
  let zero_unix = @zipc.dos_datetime_to_unix(0, 0)
  inspect(zero_unix, content=@zipc.dos_epoch.to_string())
}

///|
test "dos time month calculations" {
  // Test all months
  let months = [
    (1, "January"),
    (2, "February"),
    (3, "March"),
    (4, "April"),
    (5, "May"),
    (6, "June"),
    (7, "July"),
    (8, "August"),
    (9, "September"),
    (10, "October"),
    (11, "November"),
    (12, "December"),
  ]
  for i = 0; i < months.length(); i = i + 1 {
    let (month_num, _) = months[i]
    let (dos_time, dos_date) = @zipc.make_dos_datetime(
      2022, month_num, 15, 12, 0, 0,
    )
    let (year, month, day, _, _, _) = @zipc.dos_datetime_components(
      dos_time, dos_date,
    )
    inspect(year, content="2022")
    inspect(month, content=month_num.to_string())
    inspect(day, content="15")
  }
}
