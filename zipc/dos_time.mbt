// DOS time/date conversion utilities for ZIP files
// DOS time format: 16-bit time and 16-bit date fields

// DOS time structure (packed into 16 bits)
// Bits 15-11: Hours (0-23)
// Bits 10-5:  Minutes (0-59) 
// Bits 4-0:   Seconds/2 (0-29, representing 0-58 seconds in 2-second intervals)

// DOS date structure (packed into 16 bits)  
// Bits 15-9: Year offset from 1980 (0-127, representing 1980-2107)
// Bits 8-5:  Month (1-12)
// Bits 4-0:  Day (1-31)

// Unix timestamp to DOS date/time conversion

///|
pub fn unix_to_dos_datetime(unix_timestamp : Int) -> (Int, Int) {
  // Convert Unix timestamp to components
  // This is a simplified conversion - a full implementation would handle
  // leap years, time zones, etc. more accurately

  if unix_timestamp <= dos_epoch {
    // Before DOS epoch, use minimum DOS date/time (1980-01-01 00:00:00)
    return (0, 0x0021) // Time: 00:00:00, Date: 1980-01-01
  }
  let seconds_since_dos_epoch = unix_timestamp - dos_epoch
  let days_since_dos_epoch = seconds_since_dos_epoch / 86400
  let seconds_in_day = seconds_since_dos_epoch % 86400

  // Calculate time components
  let hours = seconds_in_day / 3600
  let minutes = seconds_in_day % 3600 / 60
  let seconds = seconds_in_day % 60

  // Pack DOS time (seconds are divided by 2)
  let dos_time = (hours << 11) | (minutes << 5) | (seconds / 2)

  // Calculate date components (simplified - doesn't handle leap years perfectly)
  let mut year = 1980
  let mut remaining_days = days_since_dos_epoch

  // Approximate year calculation
  while remaining_days >= 365 {
    let days_in_year = if is_leap_year(year) { 366 } else { 365 }
    if remaining_days >= days_in_year {
      remaining_days = remaining_days - days_in_year
      year = year + 1
    } else {
      break
    }
  }

  // Calculate month and day
  let (month, day) = day_of_year_to_month_day(
    remaining_days + 1,
    is_leap_year(year),
  )

  // Pack DOS date
  let year_offset = year - 1980
  let dos_date = (year_offset << 9) | (month << 5) | day
  (dos_time, dos_date)
}

// DOS date/time to Unix timestamp conversion

///|
pub fn dos_datetime_to_unix(dos_time : Int, dos_date : Int) -> Int {
  // Unpack DOS time
  let hours = (dos_time >> 11) & 0x1f
  let minutes = (dos_time >> 5) & 0x3f
  let seconds = (dos_time & 0x1f) * 2

  // Unpack DOS date
  let year_offset = (dos_date >> 9) & 0x7f
  let month = (dos_date >> 5) & 0x0f
  let day = dos_date & 0x1f
  let year = 1980 + year_offset

  // Validate components
  if month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hours > 23 ||
    minutes > 59 ||
    seconds > 59 {
    return dos_epoch // Return DOS epoch for invalid dates
  }

  // Calculate days since DOS epoch
  let mut days = 0

  // Add days for complete years
  for y = 1980; y < year; y = y + 1 {
    days = days + (if is_leap_year(y) { 366 } else { 365 })
  }

  // Add days for complete months in the current year
  days = days + month_day_to_day_of_year(month, day, is_leap_year(year)) - 1

  // Calculate total seconds
  dos_epoch + days * 86400 + hours * 3600 + minutes * 60 + seconds
}

// Check if a year is a leap year

///|
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

// Convert day of year to month and day

///|
fn day_of_year_to_month_day(day_of_year : Int, is_leap : Bool) -> (Int, Int) {
  let days_in_months = if is_leap {
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  } else {
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  }
  let mut remaining_days = day_of_year
  let mut month = 1
  for i = 0; i < days_in_months.length(); i = i + 1 {
    if remaining_days <= days_in_months[i] {
      return (month, remaining_days)
    }
    remaining_days = remaining_days - days_in_months[i]
    month = month + 1
  }

  // Fallback for invalid day of year
  (12, 31)
}

// Convert month and day to day of year

///|
fn month_day_to_day_of_year(month : Int, day : Int, is_leap : Bool) -> Int {
  let days_in_months = if is_leap {
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  } else {
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  }
  let mut day_of_year = day
  for i = 0; i < month - 1 && i < days_in_months.length(); i = i + 1 {
    day_of_year = day_of_year + days_in_months[i]
  }
  day_of_year
}

// Get current Unix timestamp (placeholder - would need system integration)

///|
pub fn current_unix_timestamp() -> Int {
  // This is a placeholder. In a real implementation, this would
  // get the current system time. For now, return a reasonable default.
  1640995200 // 2022-01-01 00:00:00 UTC
}

// Create DOS time/date from individual components

///|
pub fn make_dos_datetime(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> (Int, Int) {
  // Validate and clamp inputs
  let year_clamped = if year < 1980 {
    1980
  } else if year > 2107 {
    2107
  } else {
    year
  }
  let month_clamped = if month < 1 {
    1
  } else if month > 12 {
    12
  } else {
    month
  }
  let day_clamped = if day < 1 { 1 } else if day > 31 { 31 } else { day }
  let hour_clamped = if hour < 0 { 0 } else if hour > 23 { 23 } else { hour }
  let minute_clamped = if minute < 0 {
    0
  } else if minute > 59 {
    59
  } else {
    minute
  }
  let second_clamped = if second < 0 {
    0
  } else if second > 59 {
    59
  } else {
    second
  }

  // Pack DOS time
  let dos_time = (hour_clamped << 11) |
    (minute_clamped << 5) |
    (second_clamped / 2)

  // Pack DOS date
  let year_offset = year_clamped - 1980
  let dos_date = (year_offset << 9) | (month_clamped << 5) | day_clamped
  (dos_time, dos_date)
}

// Extract individual components from DOS time/date

///|
pub fn dos_datetime_components(
  dos_time : Int,
  dos_date : Int,
) -> (Int, Int, Int, Int, Int, Int) {
  // Unpack DOS time
  let hours = (dos_time >> 11) & 0x1f
  let minutes = (dos_time >> 5) & 0x3f
  let seconds = (dos_time & 0x1f) * 2

  // Unpack DOS date
  let year_offset = (dos_date >> 9) & 0x7f
  let month = (dos_date >> 5) & 0x0f
  let day = dos_date & 0x1f
  let year = 1980 + year_offset
  (year, month, day, hours, minutes, seconds)
}

// Format DOS date/time as human-readable string

///|
pub fn format_dos_datetime(dos_time : Int, dos_date : Int) -> String {
  let (year, month, day, hours, minutes, seconds) = dos_datetime_components(
    dos_time, dos_date,
  )

  // Format as YYYY-MM-DD HH:MM:SS
  let year_str = year.to_string()
  let month_str = if month < 10 {
    "0" + month.to_string()
  } else {
    month.to_string()
  }
  let day_str = if day < 10 { "0" + day.to_string() } else { day.to_string() }
  let hour_str = if hours < 10 {
    "0" + hours.to_string()
  } else {
    hours.to_string()
  }
  let minute_str = if minutes < 10 {
    "0" + minutes.to_string()
  } else {
    minutes.to_string()
  }
  let second_str = if seconds < 10 {
    "0" + seconds.to_string()
  } else {
    seconds.to_string()
  }
  year_str +
  "-" +
  month_str +
  "-" +
  day_str +
  " " +
  hour_str +
  ":" +
  minute_str +
  ":" +
  second_str
}
