import 'package:flutter_test/flutter_test.dart';
import 'package:paycheck_calculator/tax/fica_calculator.dart';
import 'package:paycheck_calculator/tax/federal_withholding.dart';
import 'package:paycheck_calculator/tax/paycheck_tax_service.dart';
import 'package:paycheck_calculator/tax/payroll_inputs.dart';
import 'package:paycheck_calculator/tax/state/state_tax_provider.dart';
import 'package:paycheck_calculator/tax/state/texas_provider.dart';

PayrollInputs input({
  double gross = 1000,
  StateCode state = StateCode.texas,
  double? ssYtd = 0,
  double? medYtd = 0,
  FederalFilingStatus status =
      FederalFilingStatus.singleOrMarriedFilingSeparately,
  PayFrequency frequency = PayFrequency.weekly,
  bool step2 = false,
  double step3 = 0,
  double step4a = 0,
  double step4b = 0,
  double step4c = 0,
  double otherDeduction = 0,
  QualifiedOvertimeInputs? qualifiedOvertime,
}) => PayrollInputs.fromDollars(
  grossPay: gross,
  state: state,
  ytdSocialSecurityWages: ssYtd,
  ytdMedicareWages: medYtd,
  filingStatus: status,
  payFrequency: frequency,
  step2Checkbox: step2,
  step3Annual: step3,
  step4aAnnual: step4a,
  step4bAnnual: step4b,
  step4cPerPaycheck: step4c,
  otherCashDeductions: otherDeduction,
  qualifiedOvertime: qualifiedOvertime,
);

void main() {
  const fica = FicaCalculator();

  group('2026 employee FICA', () {
    test('normal wages calculate Social Security and Medicare', () {
      final result = fica.calculate(input());
      expect(result.socialSecurityCents, 6200);
      expect(result.medicareCents, 1450);
      expect(result.additionalMedicareCents, 0);
    });

    test('Social Security stops at and crosses wage base', () {
      expect(fica.calculate(input(ssYtd: 184000)).socialSecurityCents, 3100);
      expect(fica.calculate(input(ssYtd: 184500)).socialSecurityCents, 0);
      expect(fica.calculate(input(ssYtd: 200000)).socialSecurityCents, 0);
    });

    test('Medicare has no wage cap', () {
      expect(fica.calculate(input(gross: 250000)).medicareCents, 362500);
    });

    test('Additional Medicare tracks threshold crossing per employer', () {
      expect(
        fica.calculate(input(medYtd: 199500)).additionalMedicareCents,
        450,
      );
      expect(
        fica.calculate(input(medYtd: 200000)).additionalMedicareCents,
        900,
      );
      expect(fica.calculate(input(medYtd: 0)).additionalMedicareCents, 0);
      expect(
        fica.calculate(input(medYtd: 205000)).additionalMedicareCents,
        900,
      );
    });

    test('Social Security and Medicare use separate YTD wage fields', () {
      final result = fica.calculate(input(ssYtd: 184500, medYtd: 199500));
      expect(result.socialSecurityCents, 0);
      expect(result.medicareCents, 1450);
      expect(result.additionalMedicareCents, 450);
    });

    test('missing YTD values assume zero and flag the assumption', () {
      final result = fica.calculate(input(ssYtd: null, medYtd: null));
      expect(result.assumedZeroSocialSecurityYtd, isTrue);
      expect(result.assumedZeroMedicareYtd, isTrue);
      expect(result.assumptions, hasLength(2));
    });

    test('large check crossing multiple thresholds is capped correctly', () {
      final result = fica.calculate(
        input(gross: 300000, ssYtd: 184000, medYtd: 199000),
      );
      expect(result.socialSecurityTaxableWagesCents, 50000);
      expect(result.additionalMedicareTaxableWagesCents, 29900000);
      expect(result.additionalMedicareCents, 269100);
    });
  });

  group('state tax', () {
    test('Texas reports supported zero individual income tax', () {
      final result = const TexasStateTaxProvider().calculate(
        const StateTaxRequest(
          state: StateCode.texas,
          taxableWagesCents: 100000,
          payFrequency: PayFrequency.weekly,
          taxYear: 2026,
        ),
      );
      expect(result.status, StateTaxSupportStatus.supported);
      expect(result.withholdingCents, 0);
      expect(result.assumptions.single, contains('other taxes'));
    });

    test('unsupported state is identified, not treated as supported zero', () {
      final result = const PaycheckTaxService().calculate(
        input(state: StateCode.california),
      );
      expect(result.stateStatus, StateTaxSupportStatus.unsupported);
      expect(result.estimatedTakeHomePayCents, isNull);
      expect(result.warnings, contains(contains('not currently supported')));
    });

    test('unselected state also prevents a misleading net result', () {
      final result = const PaycheckTaxService().calculate(
        input(state: StateCode.notSelected),
      );
      expect(result.stateStatus, StateTaxSupportStatus.notSelected);
      expect(result.estimatedTakeHomePayCents, isNull);
    });
  });

  group('integrated take-home service', () {
    const service = PaycheckTaxService();

    test('gross less supported withholding equals estimated take-home', () {
      final result = service.calculate(input(otherDeduction: 25));
      expect(
        result.estimatedTakeHomePayCents,
        result.grossPayCents -
            result.federalIncomeTaxCents -
            result.socialSecurityCents -
            result.medicareCents -
            result.additionalMedicareCents -
            result.stateIncomeTaxCents -
            result.otherDeductionsCents,
      );
      expect(result.otherDeductionsCents, 2500);
    });

    test('Step 4(c) reduces net by exactly the added withholding', () {
      final base = service.calculate(input());
      final added = service.calculate(input(step4c: 18.25));
      expect(added.federalIncomeTaxCents - base.federalIncomeTaxCents, 1825);
      expect(
        base.estimatedTakeHomePayCents! - added.estimatedTakeHomePayCents!,
        1825,
      );
    });

    test('filing status and pay frequency affect federal withholding', () {
      final single = service.calculate(input());
      final joint = service.calculate(
        input(status: FederalFilingStatus.marriedFilingJointly),
      );
      final biweekly = service.calculate(
        input(frequency: PayFrequency.biweekly),
      );
      expect(single.federalIncomeTaxCents, isNot(joint.federalIncomeTaxCents));
      expect(
        single.federalIncomeTaxCents,
        isNot(biweekly.federalIncomeTaxCents),
      );
    });

    test(
      'Step 2 changes the federal method and Texas state withholding remains zero',
      () {
        final standard = service.calculate(input());
        final step2 = service.calculate(input(step2: true));
        expect(
          step2.federalIncomeTaxCents,
          isNot(standard.federalIncomeTaxCents),
        );
        expect(standard.stateIncomeTaxCents, 0);
        expect(step2.stateIncomeTaxCents, 0);
      },
    );

    test('YTD wages affect FICA in combined result', () {
      final below = service.calculate(input(ssYtd: 0, medYtd: 0));
      final above = service.calculate(input(ssYtd: 184500, medYtd: 200000));
      expect(below.socialSecurityCents, 6200);
      expect(above.socialSecurityCents, 0);
      expect(above.additionalMedicareCents, 900);
    });

    test('W-4 Step 4(b) does not become a cash deduction', () {
      final result = service.calculate(input(step4b: 10000));
      expect(result.otherDeductionsCents, 0);
    });

    test('qualified overtime changes federal withholding, not FICA wages', () {
      final inputs = input(
        qualifiedOvertime: QualifiedOvertimeInputs(
          overtimeCompensationCents: 37500,
          regularRateCents: 2500,
          overtimeHoursThousandths: 10000,
          overtimeMultiplierThousandths: 1500,
          treatAsFlsaQualified: true,
          estimatedMagiCents: 5000000,
        ),
      );
      final result = service.calculate(inputs);
      expect(
        result.qualifiedOvertime.potentialQualifiedOvertimePerPaycheckCents,
        12500,
      );
      expect(
        result.federalIncomeTaxCents,
        lessThan(service.calculate(input()).federalIncomeTaxCents),
      );
      expect(result.socialSecurityCents, 6200);
      expect(result.medicareCents, 1450);
    });
  });

  test('invalid and non-finite tax inputs are rejected', () {
    expect(
      () => PayrollInputs.fromDollars(
        grossPay: -1,
        filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
        payFrequency: PayFrequency.weekly,
      ),
      throwsArgumentError,
    );
    expect(
      () => PayrollInputs.fromDollars(
        grossPay: double.infinity,
        filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
        payFrequency: PayFrequency.weekly,
      ),
      throwsArgumentError,
    );
    expect(
      () => PayrollInputs.fromDollars(
        grossPay: 1,
        filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
        payFrequency: PayFrequency.weekly,
        ytdMedicareWages: double.nan,
      ),
      throwsArgumentError,
    );
  });

  test('each tax uses its own taxable wage base', () {
    final inputs = PayrollInputs(
      grossPayCents: 100000,
      filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
      payFrequency: PayFrequency.weekly,
      state: StateCode.texas,
      ytdSocialSecurityWagesCents: 18400000,
      ytdMedicareWagesCents: 0,
      taxableWageBases: const TaxableWageBases(
        federalIncomeTaxCents: 80000,
        socialSecurityCents: 50000,
        medicareCents: 70000,
        stateIncomeTaxCents: 60000,
      ),
    );
    const service = PaycheckTaxService();
    final result = service.calculate(inputs);
    final federal = const FederalWithholdingCalculator().calculate(inputs);
    final fica = const FicaCalculator().calculate(inputs);
    expect(federal.adjustedAnnualWagesCents, 3300000);
    expect(fica.socialSecurityTaxableWagesCents, 50000);
    expect(fica.medicareTaxableWagesCents, 70000);
    expect(result.grossPayCents, 100000);
  });
}
