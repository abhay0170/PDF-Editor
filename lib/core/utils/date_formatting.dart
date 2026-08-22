const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as "Aug 16", avoiding a dependency on `intl` for one
/// short label used in list rows.
String formatShortDate(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}';
}
