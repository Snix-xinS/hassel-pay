import 'payroll_inputs.dart';
import 'tax_year_config.dart';

/// Result of applying IRS Pub. 15-T (2026), Worksheet 1A.
///
/// All monetary outputs are integer cents. Worksheet arithmetic is carried in
/// hundredths of a cent (integer numerator) without intermediate rounding;
/// final per-paycheck amounts are rounded to the nearest cent, half up.
class FederalWithholdingResult {
  const FederalWithholdingResult({
    required this.taxYear,
    required this.adjustedAnnualWagesCents,
    required this.annualTentativeWithholdingCents,
    required this.annualStep3CreditCents,
    required this.effectiveStep4bAnnualCents,
    required this.payPeriodFederalIncomeTaxCents,
    required this.step4cAdditionalWithholdingCents,
    required this.finalFederalIncomeTaxWithholdingCents,
    required this.payPeriodsPerYear,
    required this.selectedTableRow,
    required this.assumptions,
  });

  final int taxYear;
  final int adjustedAnnualWagesCents;

  /// Annual tentative amount, rounded to cents for reporting.
  final int annualTentativeWithholdingCents;
  final int annualStep3CreditCents;
  final int effectiveStep4bAnnualCents;

  /// Per-paycheck withholding after Step 3 and before Step 4(c).
  final int payPeriodFederalIncomeTaxCents;
  final int step4cAdditionalWithholdingCents;
  final int finalFederalIncomeTaxWithholdingCents;
  final int payPeriodsPerYear;
  final PercentageMethodRow selectedTableRow;
  final List<String> assumptions;
}

/// Federal income-tax withholding using the 2026 automated Percentage Method.
class FederalWithholdingCalculator {
  const FederalWithholdingCalculator({this.config = TaxYearConfig.taxYear2026});

  final TaxYearConfig config;

  FederalWithholdingResult calculate(
    PayrollInputs inputs, {
    int qualifiedOvertimeStep4bAnnualCents = 0,
  }) {
    if (qualifiedOvertimeStep4bAnnualCents < 0) {
      throw ArgumentError.value(qualifiedOvertimeStep4bAnnualCents);
    }
    final periods = inputs.payFrequency.payPeriodsPerYear;
    final taxableWages =
        inputs.taxableWageBases ??
        TaxableWageBases.fromGrossPay(inputs.grossPayCents);
    final annualizedWagesCents = taxableWages.federalIncomeTaxCents * periods;

    final standardAdjustmentCents = inputs.step2Checkbox
        ? 0
        : config.standardAdjustmentCents(inputs.filingStatus);

    final adjustedAnnualWagesCents = _maxZero(
      annualizedWagesCents +
          inputs.step4aAnnualCents -
          inputs.step4bAnnualCents -
          qualifiedOvertimeStep4bAnnualCents -
          standardAdjustmentCents,
    );

    final rows = config.tableFor(
      inputs.filingStatus,
      step2Checkbox: inputs.step2Checkbox,
    );
    final selectedRow = rows.firstWhere(
      (row) => row.containsAdjustedWages(adjustedAnnualWagesCents),
      orElse: () => throw StateError(
        'No ${config.taxYear} percentage-method row covers '
        '$adjustedAnnualWagesCents cents.',
      ),
    );

    // Values are in hundredths of a cent. This keeps percentage multiplication
    // exact until the final per-check rounding step.
    final excessCents =
        adjustedAnnualWagesCents - selectedRow.excessOverDollars * 100;
    final annualTentativeHundredthCents =
        selectedRow.baseAmountCents * 100 +
        excessCents * selectedRow.ratePercent;

    final annualTentativeCents = _roundRatioHalfUp(
      annualTentativeHundredthCents,
      100,
    );
    final annualAfterStep3HundredthCents = _maxZero(
      annualTentativeHundredthCents - inputs.step3AnnualCents * 100,
    );
    final payPeriodTaxCents = _roundRatioHalfUp(
      annualAfterStep3HundredthCents,
      periods * 100,
    );
    final finalTaxCents = payPeriodTaxCents + inputs.step4cPerPaycheckCents;

    return FederalWithholdingResult(
      taxYear: config.taxYear,
      adjustedAnnualWagesCents: adjustedAnnualWagesCents,
      annualTentativeWithholdingCents: annualTentativeCents,
      annualStep3CreditCents: inputs.step3AnnualCents,
      effectiveStep4bAnnualCents:
          inputs.step4bAnnualCents + qualifiedOvertimeStep4bAnnualCents,
      payPeriodFederalIncomeTaxCents: payPeriodTaxCents,
      step4cAdditionalWithholdingCents: inputs.step4cPerPaycheckCents,
      finalFederalIncomeTaxWithholdingCents: finalTaxCents,
      payPeriodsPerYear: periods,
      selectedTableRow: selectedRow,
      assumptions: const [
        'Current paycheck wages are assumed to recur for every pay period in the tax year.',
        'No pay dates or remaining-pay-period adjustment is applied.',
        'Step 3 and Step 4(b) amounts are supplied by the user; eligibility is not determined.',
      ],
    );
  }

  static int _maxZero(int value) => value > 0 ? value : 0;

  /// Rounds a non-negative ratio to the nearest integer, with ties rounded up.
  static int _roundRatioHalfUp(int numerator, int denominator) {
    return (numerator + denominator ~/ 2) ~/ denominator;
  }
}
