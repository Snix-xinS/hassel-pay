/// Recurring payroll frequencies used by the 2026 Pub. 15-T worksheet.
enum PayFrequency {
  weekly(52),
  biweekly(26),
  semimonthly(24),
  monthly(12);

  const PayFrequency(this.payPeriodsPerYear);

  final int payPeriodsPerYear;
}

/// Filing-status choices on the 2026 Form W-4 Step 1(c).
enum FederalFilingStatus {
  singleOrMarriedFilingSeparately,
  marriedFilingJointly,
  headOfHousehold,
}

/// All dollar amounts are stored as integer cents.
///
/// [fromDollars] is available for callers that start with decimal dollar
/// amounts. It rejects non-finite, negative, and excessively large values
/// before converting them to cents.
class PayrollInputs {
  PayrollInputs({
    required this.grossPayCents,
    required this.filingStatus,
    required this.payFrequency,
    this.step2Checkbox = false,
    this.step3AnnualCents = 0,
    this.step4aAnnualCents = 0,
    this.step4bAnnualCents = 0,
    this.step4cPerPaycheckCents = 0,
  }) {
    _validateCents(grossPayCents, 'gross pay');
    _validateCents(step3AnnualCents, 'Step 3');
    _validateCents(step4aAnnualCents, 'Step 4(a)');
    _validateCents(step4bAnnualCents, 'Step 4(b)');
    _validateCents(step4cPerPaycheckCents, 'Step 4(c)');
  }

  /// Guards integer arithmetic while allowing extremely high wages.
  static const int maxInputCents = 100000000000000; // $1 trillion.

  final int grossPayCents;
  final FederalFilingStatus filingStatus;
  final PayFrequency payFrequency;
  final bool step2Checkbox;
  final int step3AnnualCents;
  final int step4aAnnualCents;
  final int step4bAnnualCents;
  final int step4cPerPaycheckCents;

  factory PayrollInputs.fromDollars({
    required double grossPay,
    required FederalFilingStatus filingStatus,
    required PayFrequency payFrequency,
    bool step2Checkbox = false,
    double step3Annual = 0,
    double step4aAnnual = 0,
    double step4bAnnual = 0,
    double step4cPerPaycheck = 0,
  }) {
    return PayrollInputs(
      grossPayCents: dollarsToCents(grossPay, 'gross pay'),
      filingStatus: filingStatus,
      payFrequency: payFrequency,
      step2Checkbox: step2Checkbox,
      step3AnnualCents: dollarsToCents(step3Annual, 'Step 3'),
      step4aAnnualCents: dollarsToCents(step4aAnnual, 'Step 4(a)'),
      step4bAnnualCents: dollarsToCents(step4bAnnual, 'Step 4(b)'),
      step4cPerPaycheckCents: dollarsToCents(step4cPerPaycheck, 'Step 4(c)'),
    );
  }

  static int dollarsToCents(double dollars, String label) {
    if (!dollars.isFinite || dollars < 0 || dollars > maxInputCents / 100) {
      throw ArgumentError.value(
        dollars,
        label,
        'Must be finite and non-negative within supported range.',
      );
    }

    // Parse the shortest decimal representation, rather than multiplying the
    // binary floating-point value by 100 (which can mis-round values like 1.005).
    final parts = dollars.toString().toLowerCase().split('e');
    final significand = parts.first;
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final decimalPoint = significand.indexOf('.');
    final fractionalDigits = decimalPoint < 0
        ? 0
        : significand.length - decimalPoint - 1;
    final digits = significand.replaceAll('.', '');
    final scale = fractionalDigits - exponent - 2;
    final integer = BigInt.parse(digits);
    final cents = scale <= 0
        ? integer * BigInt.from(10).pow(-scale)
        : _roundBigIntHalfUp(integer, BigInt.from(10).pow(scale));
    if (cents > BigInt.from(maxInputCents)) {
      throw ArgumentError.value(
        dollars,
        label,
        'Must be within supported range.',
      );
    }
    return cents.toInt();
  }

  static BigInt _roundBigIntHalfUp(BigInt numerator, BigInt denominator) {
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    return remainder * BigInt.two >= denominator
        ? quotient + BigInt.one
        : quotient;
  }

  static void _validateCents(int cents, String label) {
    if (cents < 0 || cents > maxInputCents) {
      throw ArgumentError.value(
        cents,
        label,
        'Must be non-negative and within supported range.',
      );
    }
  }
}
