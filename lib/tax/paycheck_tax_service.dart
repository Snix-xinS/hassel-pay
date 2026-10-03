import 'federal_withholding.dart';
import 'fica_calculator.dart';
import 'paycheck_result.dart';
import 'payroll_inputs.dart';
import 'state/state_tax_provider.dart';
import 'state/texas_provider.dart';
import 'tax_year_config.dart';

/// Coordinates tax components without depending on Flutter or gross-pay UI.
class PaycheckTaxService {
  const PaycheckTaxService({
    this.config = TaxYearConfig.taxYear2026,
    this.federalCalculator = const FederalWithholdingCalculator(),
    this.ficaCalculator = const FicaCalculator(),
    this.stateProviders = const [TexasStateTaxProvider()],
  });

  final TaxYearConfig config;
  final FederalWithholdingCalculator federalCalculator;
  final FicaCalculator ficaCalculator;
  final List<StateTaxProvider> stateProviders;

  PaycheckTaxResult calculate(PayrollInputs inputs) {
    final federal = federalCalculator.calculate(inputs);
    final fica = ficaCalculator.calculate(inputs);
    final wages =
        inputs.taxableWageBases ??
        TaxableWageBases.fromGrossPay(inputs.grossPayCents);

    StateTaxResult stateResult;
    if (inputs.state == StateCode.notSelected) {
      stateResult = StateTaxResult(
        state: inputs.state,
        withholdingCents: 0,
        status: StateTaxSupportStatus.notSelected,
        assumptions: const [
          'Select a state to estimate state income-tax withholding.',
        ],
      );
    } else {
      final provider = stateProviders.where(
        (item) => item.state == inputs.state,
      );
      stateResult = provider.isEmpty
          ? const UnsupportedStateTaxProvider().calculate(
              StateTaxRequest(
                state: inputs.state,
                taxableWagesCents: wages.stateIncomeTaxCents,
                payFrequency: inputs.payFrequency,
                taxYear: config.taxYear,
              ),
            )
          : provider.first.calculate(
              StateTaxRequest(
                state: inputs.state,
                taxableWagesCents: wages.stateIncomeTaxCents,
                payFrequency: inputs.payFrequency,
                taxYear: config.taxYear,
              ),
            );
    }

    final stateKnown = stateResult.status == StateTaxSupportStatus.supported;
    final total =
        federal.finalFederalIncomeTaxWithholdingCents +
        fica.socialSecurityCents +
        fica.medicareCents +
        fica.additionalMedicareCents +
        (stateKnown ? stateResult.withholdingCents : 0) +
        inputs.otherCashDeductionsCents;
    final warnings = <String>[
      ...federal.assumptions,
      ...fica.assumptions,
      ...stateResult.assumptions,
      'Pre-tax deductions are not modeled; gross pay is used for wage bases unless explicitly provided.',
      'Multiple jobs are represented only by the W-4 Step 2 checkbox; prior-employer wages, bonuses, irregular pay, special payroll arrangements, and final tax liability are not modeled.',
    ];
    if (inputs.exemptFromFederalWithholding) {
      warnings.add(
        'Federal exemption eligibility is user-attested and is not verified.',
      );
    }

    return PaycheckTaxResult(
      taxYear: config.taxYear,
      grossPayCents: inputs.grossPayCents,
      federalIncomeTaxCents: federal.finalFederalIncomeTaxWithholdingCents,
      socialSecurityCents: fica.socialSecurityCents,
      medicareCents: fica.medicareCents,
      additionalMedicareCents: fica.additionalMedicareCents,
      stateIncomeTaxCents: stateKnown ? stateResult.withholdingCents : 0,
      stateStatus: stateResult.status,
      otherDeductionsCents: inputs.otherCashDeductionsCents,
      totalWithholdingCents: total,
      estimatedTakeHomePayCents: stateKnown
          ? inputs.grossPayCents - total
          : null,
      warnings: warnings,
    );
  }
}
