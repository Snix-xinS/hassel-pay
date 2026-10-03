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

/// User-provided facts used to estimate the qualified overtime deduction.
/// Hours use thousandths to avoid floating point in the deduction engine.
class QualifiedOvertimeInputs {
  QualifiedOvertimeInputs({
    required this.overtimeCompensationCents,
    required this.regularRateCents,
    required this.overtimeHoursThousandths,
    required this.overtimeMultiplierThousandths,
    this.treatAsFlsaQualified = false,
    this.marriedFilingSeparately = false,
    this.estimatedMagiCents,
  }) {
    _validateCents(overtimeCompensationCents, 'overtime compensation');
    _validateCents(regularRateCents, 'regular rate');
    if (overtimeHoursThousandths < 0 || overtimeHoursThousandths > 1000000000) {
      throw ArgumentError.value(overtimeHoursThousandths, 'overtime hours');
    }
    if (overtimeMultiplierThousandths <= 0 ||
        overtimeMultiplierThousandths > 1000000) {
      throw ArgumentError.value(
        overtimeMultiplierThousandths,
        'overtime multiplier',
      );
    }
    final potentialNumerator =
        BigInt.from(regularRateCents) * BigInt.from(overtimeHoursThousandths);
    if (potentialNumerator >=
        BigInt.from(PayrollInputs.maxInputCents) * BigInt.from(2000) +
            BigInt.from(1000)) {
      throw ArgumentError(
        'Overtime inputs exceed the supported calculation range.',
      );
    }
    if (estimatedMagiCents != null) {
      _validateCents(estimatedMagiCents!, 'estimated MAGI');
    }
  }

  final int overtimeCompensationCents;
  final int regularRateCents;
  final int overtimeHoursThousandths;
  final int overtimeMultiplierThousandths;
  final bool treatAsFlsaQualified;
  final bool marriedFilingSeparately;
  final int? estimatedMagiCents;

  static void _validateCents(int value, String label) {
    if (value < 0 || value > PayrollInputs.maxInputCents) {
      throw ArgumentError.value(
        value,
        label,
        'Must be non-negative and within supported range.',
      );
    }
  }
}

/// U.S. state jurisdictions plus the District of Columbia.
enum StateCode {
  notSelected('Select a state'),
  alabama('Alabama'),
  alaska('Alaska'),
  arizona('Arizona'),
  arkansas('Arkansas'),
  california('California'),
  colorado('Colorado'),
  connecticut('Connecticut'),
  delaware('Delaware'),
  districtOfColumbia('District of Columbia'),
  florida('Florida'),
  georgia('Georgia'),
  hawaii('Hawaii'),
  idaho('Idaho'),
  illinois('Illinois'),
  indiana('Indiana'),
  iowa('Iowa'),
  kansas('Kansas'),
  kentucky('Kentucky'),
  louisiana('Louisiana'),
  maine('Maine'),
  maryland('Maryland'),
  massachusetts('Massachusetts'),
  michigan('Michigan'),
  minnesota('Minnesota'),
  mississippi('Mississippi'),
  missouri('Missouri'),
  montana('Montana'),
  nebraska('Nebraska'),
  nevada('Nevada'),
  newHampshire('New Hampshire'),
  newJersey('New Jersey'),
  newMexico('New Mexico'),
  newYork('New York'),
  northCarolina('North Carolina'),
  northDakota('North Dakota'),
  ohio('Ohio'),
  oklahoma('Oklahoma'),
  oregon('Oregon'),
  pennsylvania('Pennsylvania'),
  rhodeIsland('Rhode Island'),
  southCarolina('South Carolina'),
  southDakota('South Dakota'),
  tennessee('Tennessee'),
  texas('Texas'),
  utah('Utah'),
  vermont('Vermont'),
  virginia('Virginia'),
  washington('Washington'),
  westVirginia('West Virginia'),
  wisconsin('Wisconsin'),
  wyoming('Wyoming');

  const StateCode(this.label);

  final String label;
}

/// Per-tax wage bases. All default to gross pay until deduction rules exist.
class TaxableWageBases {
  const TaxableWageBases({
    required this.federalIncomeTaxCents,
    required this.socialSecurityCents,
    required this.medicareCents,
    required this.stateIncomeTaxCents,
  });

  factory TaxableWageBases.fromGrossPay(int grossPayCents) => TaxableWageBases(
    federalIncomeTaxCents: grossPayCents,
    socialSecurityCents: grossPayCents,
    medicareCents: grossPayCents,
    stateIncomeTaxCents: grossPayCents,
  );

  final int federalIncomeTaxCents;
  final int socialSecurityCents;
  final int medicareCents;
  final int stateIncomeTaxCents;
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
    this.taxableWageBases,
    this.state = StateCode.notSelected,
    this.ytdSocialSecurityWagesCents,
    this.ytdMedicareWagesCents,
    this.otherCashDeductionsCents = 0,
    this.step2Checkbox = false,
    this.step3AnnualCents = 0,
    this.step4aAnnualCents = 0,
    this.step4bAnnualCents = 0,
    this.step4cPerPaycheckCents = 0,
    this.qualifiedOvertime,
  }) {
    _validateCents(grossPayCents, 'gross pay');
    final wageBases =
        taxableWageBases ?? TaxableWageBases.fromGrossPay(grossPayCents);
    _validateCents(wageBases.federalIncomeTaxCents, 'federal taxable wages');
    _validateCents(wageBases.socialSecurityCents, 'Social Security wages');
    _validateCents(wageBases.medicareCents, 'Medicare wages');
    _validateCents(wageBases.stateIncomeTaxCents, 'state taxable wages');
    if (ytdSocialSecurityWagesCents != null) {
      _validateCents(ytdSocialSecurityWagesCents!, 'YTD Social Security wages');
    }
    if (ytdMedicareWagesCents != null) {
      _validateCents(ytdMedicareWagesCents!, 'YTD Medicare wages');
    }
    _validateCents(otherCashDeductionsCents, 'other after-tax deductions');
    _validateCents(step3AnnualCents, 'Step 3');
    _validateCents(step4aAnnualCents, 'Step 4(a)');
    _validateCents(step4bAnnualCents, 'Step 4(b)');
    _validateCents(step4cPerPaycheckCents, 'Step 4(c)');
  }

  /// Guards integer arithmetic while allowing extremely high wages.
  static const int maxInputCents = 100000000000000; // $1 trillion.

  final int grossPayCents;
  final TaxableWageBases? taxableWageBases;
  final StateCode state;

  /// Null means YTD wages were not provided and the estimate assumes zero.
  final int? ytdSocialSecurityWagesCents;

  /// Null means YTD wages were not provided and the estimate assumes zero.
  final int? ytdMedicareWagesCents;
  final int otherCashDeductionsCents;
  final FederalFilingStatus filingStatus;
  final PayFrequency payFrequency;
  final bool step2Checkbox;
  final int step3AnnualCents;
  final int step4aAnnualCents;
  final int step4bAnnualCents;
  final int step4cPerPaycheckCents;

  /// Other Step 4(b) deduction amount. Qualified overtime is modeled
  /// separately and is added to this only for federal withholding.
  final QualifiedOvertimeInputs? qualifiedOvertime;

  factory PayrollInputs.fromDollars({
    required double grossPay,
    required FederalFilingStatus filingStatus,
    required PayFrequency payFrequency,
    StateCode state = StateCode.notSelected,
    double? ytdSocialSecurityWages,
    double? ytdMedicareWages,
    double otherCashDeductions = 0,
    bool step2Checkbox = false,
    double step3Annual = 0,
    double step4aAnnual = 0,
    double step4bAnnual = 0,
    double step4cPerPaycheck = 0,
    QualifiedOvertimeInputs? qualifiedOvertime,
  }) {
    return PayrollInputs(
      grossPayCents: dollarsToCents(grossPay, 'gross pay'),
      filingStatus: filingStatus,
      payFrequency: payFrequency,
      state: state,
      ytdSocialSecurityWagesCents: ytdSocialSecurityWages == null
          ? null
          : dollarsToCents(ytdSocialSecurityWages, 'YTD Social Security wages'),
      ytdMedicareWagesCents: ytdMedicareWages == null
          ? null
          : dollarsToCents(ytdMedicareWages, 'YTD Medicare wages'),
      otherCashDeductionsCents: dollarsToCents(
        otherCashDeductions,
        'other after-tax deductions',
      ),
      step2Checkbox: step2Checkbox,
      step3AnnualCents: dollarsToCents(step3Annual, 'Step 3'),
      step4aAnnualCents: dollarsToCents(step4aAnnual, 'Step 4(a)'),
      step4bAnnualCents: dollarsToCents(step4bAnnual, 'Step 4(b)'),
      step4cPerPaycheckCents: dollarsToCents(step4cPerPaycheck, 'Step 4(c)'),
      qualifiedOvertime: qualifiedOvertime,
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
