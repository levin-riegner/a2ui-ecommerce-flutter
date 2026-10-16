/// EUR is the only supported currency. External APIs retain numeric euro values;
/// every calculation converts each amount to integer cents before arithmetic.
/// Fractions of a cent are rounded once at that boundary.
int euroCents(num euros) {
  if (!euros.isFinite) {
    throw const FormatException('Enter a finite amount in EUR.');
  }
  return (euros * 100).round();
}

double eurosFromCents(int cents) => cents / 100;

double sumEuros(Iterable<num> amounts) => eurosFromCents(
  amounts.fold<int>(0, (total, amount) => total + euroCents(amount)),
);

double subtractEuros(num amount, num deduction) => amount == double.infinity
    ? double.infinity
    : eurosFromCents(euroCents(amount) - euroCents(deduction));

/// An infinite limit is an absent cap, never a persisted monetary amount.
bool euroAmountExceeds(num amount, num limit) =>
    limit == double.infinity ? false : euroCents(amount) > euroCents(limit);

String formatEuros(num amount, {bool omitZeroCents = false}) {
  final cents = euroCents(amount);
  final absolute = cents.abs();
  final fraction = absolute % 100;
  return '€${cents < 0 ? '-' : ''}${absolute ~/ 100}'
      '${omitZeroCents && fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}'}';
}
