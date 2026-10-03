import 'payroll_inputs.dart';
import 'tax_year_config.dart';

/// Qualified overtime deduction estimate. This is an estimated annual W-4
/// Step 4(b) adjustment, not a reduction to gross, FICA, or state wages.
class QualifiedOvertimeResult {
  const QualifiedOvertimeResult({
    required this.overtimeCompensationCents,
    required this.potentialQualifiedOvertimePerPaycheckCents,
    required this.annualizedPotentialQualifiedOvertimeCents,
    required this.annualLimitCents,
    required this.magiPhaseoutCents,
    required this.annualDeductionCents,
    required this.includedForEstimate,
    required this.warnings,
  });

  final int overtimeCompensationCents;
  final int potentialQualifiedOvertimePerPaycheckCents;
  final int annualizedPotentialQualifiedOvertimeCents;
  final int annualLimitCents;
  final int magiPhaseoutCents;
  final int annualDeductionCents;
  final bool includedForEstimate;
  final List<String> warnings;
}

class QualifiedOvertimeCalculator {
  const QualifiedOvertimeCalculator({this.config = TaxYearConfig.taxYear2026});

  final TaxYearConfig config;

  QualifiedOvertimeResult calculate({
    required QualifiedOvertimeInputs? inputs,
    required PayFrequency payFrequency,
    required FederalFilingStatus filingStatus,
  }) {
    if (inputs == null) {
      return const QualifiedOvertimeResult(
        overtimeCompensationCents: 0,
        potentialQualifiedOvertimePerPaycheckCents: 0,
        annualizedPotentialQualifiedOvertimeCents: 0,
        annualLimitCents: 0,
        magiPhaseoutCents: 0,
        annualDeductionCents: 0,
        includedForEstimate: false,
        warnings: [],
      );
    }

    if (inputs.treatAsFlsaQualified &&
        !inputs.marriedFilingSeparately &&
        inputs.estimatedMagiCents == null) {
      throw ArgumentError(
        'Enter estimated 2026 MAGI to estimate the overtime deduction.',
      );
    }

    // Under the FLSA the premium above the regular rate is generally 0.5x.
    // Paying 2x (or more) does not make the extra premium deductible.
    final potential = inputs.overtimeMultiplierThousandths < 1500
        ? 0
        : _roundRatioHalfUp(
            inputs.regularRateCents * inputs.overtimeHoursThousandths,
            2000,
          );
    final periods = payFrequency.payPeriodsPerYear;
    final annualized = potential * periods;
    final joint = filingStatus == FederalFilingStatus.marriedFilingJointly;
    final limit = joint
        ? config.qualifiedOvertimeJointLimitCents
        : config.qualifiedOvertimeIndividualLimitCents;
    final threshold = joint
        ? config.qualifiedOvertimeJointMagiThresholdCents
        : config.qualifiedOvertimeIndividualMagiThresholdCents;
    final capped = annualized < limit ? annualized : limit;
    final magi = inputs.estimatedMagiCents;
    var phaseout = 0;
    if (magi != null && magi > threshold) {
      final excessWholeThousands = (magi - threshold) ~/ 100000;
      phaseout =
          excessWholeThousands *
          config.qualifiedOvertimePhaseoutPerThousandCents;
    }
    final deductionAllowed =
        inputs.treatAsFlsaQualified &&
        !inputs.marriedFilingSeparately &&
        magi != null;
    final deduction = deductionAllowed ? _maxZero(capped - phaseout) : 0;
    final warnings = <String>[
      'Qualified overtime eligibility depends on FLSA coverage, nonexempt status, and the overtime being required under the FLSA; this is user-attested and not verified.',
      'The entered hourly rate is used as the FLSA regular rate; bonuses and other compensation that may change the FLSA regular rate are not modeled.',
      'The estimate does not verify the valid-for-employment Social Security number requirement or other individual eligibility requirements.',
      'Overtime entered is assumed to recur for every pay period in 2026; actual year-to-date qualified overtime is not modeled.',
      'MAGI is user-estimated and may differ from the modified adjusted gross income used on Schedule 1-A.',
      'Qualified overtime deduction does not reduce Social Security, Medicare, Additional Medicare, or state wages.',
    ];
    if (inputs.marriedFilingSeparately) {
      warnings.add(
        'The qualified overtime deduction is unavailable when married filing separately.',
      );
    }
    return QualifiedOvertimeResult(
      overtimeCompensationCents: inputs.overtimeCompensationCents,
      potentialQualifiedOvertimePerPaycheckCents: potential,
      annualizedPotentialQualifiedOvertimeCents: annualized,
      annualLimitCents: limit,
      magiPhaseoutCents: phaseout,
      annualDeductionCents: deduction,
      includedForEstimate: deductionAllowed,
      warnings: warnings,
    );
  }

  static int _roundRatioHalfUp(int numerator, int denominator) =>
      (numerator + denominator ~/ 2) ~/ denominator;
  static int _maxZero(int value) => value > 0 ? value : 0;
}
