import 'payroll_inputs.dart';
import 'tax_year_config.dart';

class FicaResult {
  const FicaResult({
    required this.socialSecurityTaxableWagesCents,
    required this.socialSecurityCents,
    required this.medicareTaxableWagesCents,
    required this.medicareCents,
    required this.additionalMedicareTaxableWagesCents,
    required this.additionalMedicareCents,
    required this.assumedZeroSocialSecurityYtd,
    required this.assumedZeroMedicareYtd,
    required this.assumptions,
  });

  final int socialSecurityTaxableWagesCents;
  final int socialSecurityCents;
  final int medicareTaxableWagesCents;
  final int medicareCents;
  final int additionalMedicareTaxableWagesCents;
  final int additionalMedicareCents;
  final bool assumedZeroSocialSecurityYtd;
  final bool assumedZeroMedicareYtd;
  final List<String> assumptions;
}

/// Employee FICA withholding under the standard 2026 Pub. 15 rules.
class FicaCalculator {
  const FicaCalculator({this.config = TaxYearConfig.taxYear2026});

  final TaxYearConfig config;

  FicaResult calculate(PayrollInputs inputs) {
    final wages =
        inputs.taxableWageBases ??
        TaxableWageBases.fromGrossPay(inputs.grossPayCents);
    final ytdSocialSecurity = inputs.ytdSocialSecurityWagesCents ?? 0;
    final ytdMedicare = inputs.ytdMedicareWagesCents ?? 0;

    final remainingSocialSecurityBase =
        config.socialSecurityWageBaseCents > ytdSocialSecurity
        ? config.socialSecurityWageBaseCents - ytdSocialSecurity
        : 0;
    final socialSecurityTaxableWages = _min(
      wages.socialSecurityCents,
      remainingSocialSecurityBase,
    );

    final additionalMedicareWagesAfterCheck = ytdMedicare + wages.medicareCents;
    final additionalMedicareWagesBeforeCheck = ytdMedicare;
    final additionalMedicareTaxableWages =
        _maxZero(
          additionalMedicareWagesAfterCheck -
              config.additionalMedicareWithholdingThresholdCents,
        ) -
        _maxZero(
          additionalMedicareWagesBeforeCheck -
              config.additionalMedicareWithholdingThresholdCents,
        );

    final assumptions = <String>[];
    if (inputs.ytdSocialSecurityWagesCents == null) {
      assumptions.add(
        'Social Security year-to-date wages were not entered; zero is assumed.',
      );
    }
    if (inputs.ytdMedicareWagesCents == null) {
      assumptions.add(
        'Medicare year-to-date wages were not entered; zero is assumed.',
      );
    }

    return FicaResult(
      socialSecurityTaxableWagesCents: socialSecurityTaxableWages,
      socialSecurityCents: config.withholdingCents(
        socialSecurityTaxableWages,
        config.socialSecurityRateBasisPoints,
      ),
      medicareTaxableWagesCents: wages.medicareCents,
      medicareCents: config.withholdingCents(
        wages.medicareCents,
        config.medicareRateBasisPoints,
      ),
      additionalMedicareTaxableWagesCents: additionalMedicareTaxableWages,
      additionalMedicareCents: config.withholdingCents(
        additionalMedicareTaxableWages,
        config.additionalMedicareRateBasisPoints,
      ),
      assumedZeroSocialSecurityYtd: inputs.ytdSocialSecurityWagesCents == null,
      assumedZeroMedicareYtd: inputs.ytdMedicareWagesCents == null,
      assumptions: assumptions,
    );
  }

  static int _min(int first, int second) => first < second ? first : second;
  static int _maxZero(int value) => value > 0 ? value : 0;
}
