import 'package:flutter_test/flutter_test.dart';
import 'package:paycheck_calculator/tax/federal_withholding.dart';
import 'package:paycheck_calculator/tax/payroll_inputs.dart';
import 'package:paycheck_calculator/tax/tax_year_config.dart';

void main() {
  const calculator = FederalWithholdingCalculator();
  const config = TaxYearConfig.taxYear2026;

  PayrollInputs input({
    double grossPay = 1000,
    FederalFilingStatus status =
        FederalFilingStatus.singleOrMarriedFilingSeparately,
    PayFrequency frequency = PayFrequency.weekly,
    bool step2 = false,
    double step3 = 0,
    double step4a = 0,
    double step4b = 0,
    double step4c = 0,
  }) => PayrollInputs.fromDollars(
    grossPay: grossPay,
    filingStatus: status,
    payFrequency: frequency,
    step2Checkbox: step2,
    step3Annual: step3,
    step4aAnnual: step4a,
    step4bAnnual: step4b,
    step4cPerPaycheck: step4c,
  );

  group('FederalWithholdingCalculator — Pub. 15-T (2026) Worksheet 1A', () {
    test('matches the weekly Single/MFS IRS table vector', () {
      final result = calculator.calculate(input());

      expect(result.adjustedAnnualWagesCents, 4340000);
      expect(result.annualTentativeWithholdingCents, 406000);
      expect(result.annualStep3CreditCents, 0);
      expect(result.payPeriodFederalIncomeTaxCents, 7808);
      expect(result.finalFederalIncomeTaxWithholdingCents, 7808);
      expect(result.payPeriodsPerYear, 52);
      expect(result.selectedTableRow.lowerBoundaryDollars, 19900);
      expect(result.selectedTableRow.upperBoundaryDollars, 57900);
      expect(result.selectedTableRow.baseAmountCents, 124000);
      expect(result.selectedTableRow.ratePercent, 12);
      expect(result.selectedTableRow.excessOverDollars, 19900);
    });

    test('uses the IRS period count and same annual tentative amount', () {
      final expected = <PayFrequency, int>{
        PayFrequency.weekly: 52,
        PayFrequency.biweekly: 26,
        PayFrequency.semimonthly: 24,
        PayFrequency.monthly: 12,
      };
      final grossByFrequency = <PayFrequency, double>{
        PayFrequency.weekly: 1200,
        PayFrequency.biweekly: 2400,
        PayFrequency.semimonthly: 2600,
        PayFrequency.monthly: 5200,
      };
      final expectedPerCheckCents = <PayFrequency, int>{
        PayFrequency.weekly: 10208,
        PayFrequency.biweekly: 20415,
        PayFrequency.semimonthly: 22117,
        PayFrequency.monthly: 44233,
      };

      for (final entry in expected.entries) {
        final result = calculator.calculate(
          input(frequency: entry.key, grossPay: grossByFrequency[entry.key]!),
        );
        expect(result.payPeriodsPerYear, entry.value);
        expect(result.adjustedAnnualWagesCents, 5380000);
        expect(result.annualTentativeWithholdingCents, 530800);
        expect(
          result.finalFederalIncomeTaxWithholdingCents,
          expectedPerCheckCents[entry.key],
        );
      }
    });

    test(
      'Step 2 selects the checkbox table and removes standard adjustment',
      () {
        final result = calculator.calculate(input(step2: true));

        expect(result.adjustedAnnualWagesCents, 5200000);
        expect(result.selectedTableRow.lowerBoundaryDollars, 33250);
        expect(result.selectedTableRow.upperBoundaryDollars, 60900);
        expect(result.selectedTableRow.baseAmountCents, 290000);
        expect(result.selectedTableRow.ratePercent, 22);
        expect(result.annualTentativeWithholdingCents, 702500);
        expect(result.finalFederalIncomeTaxWithholdingCents, 13510);
        expect(
          result.finalFederalIncomeTaxWithholdingCents,
          greaterThan(
            calculator.calculate(input()).finalFederalIncomeTaxWithholdingCents,
          ),
        );
      },
    );

    test('Step 3 credit cannot make federal withholding negative', () {
      final withCredit = calculator.calculate(input(step3: 10000, step4c: 3));

      expect(withCredit.payPeriodFederalIncomeTaxCents, 0);
      expect(withCredit.finalFederalIncomeTaxWithholdingCents, 300);
    });

    test('Step 4(a) increases adjusted wages and withholding', () {
      final baseline = calculator.calculate(input());
      final withOtherIncome = calculator.calculate(input(step4a: 10000));

      expect(withOtherIncome.adjustedAnnualWagesCents, 5340000);
      expect(
        withOtherIncome.finalFederalIncomeTaxWithholdingCents,
        greaterThan(baseline.finalFederalIncomeTaxWithholdingCents),
      );
    });

    test('Step 4(b) decreases adjusted wages and applies the zero floor', () {
      final reduced = calculator.calculate(input(step4b: 10000));
      final floored = calculator.calculate(input(step4b: 100000));

      expect(reduced.adjustedAnnualWagesCents, 3340000);
      expect(reduced.finalFederalIncomeTaxWithholdingCents, lessThan(7808));
      expect(floored.adjustedAnnualWagesCents, 0);
      expect(floored.annualTentativeWithholdingCents, 0);
      expect(floored.finalFederalIncomeTaxWithholdingCents, 0);
    });

    test('Step 4(c) is added after Step 3 reduction', () {
      final noExtra = calculator.calculate(input(step3: 1000));
      final withExtra = calculator.calculate(input(step3: 1000, step4c: 5));

      expect(noExtra.payPeriodFederalIncomeTaxCents, 5885);
      expect(withExtra.payPeriodFederalIncomeTaxCents, 5885);
      expect(withExtra.finalFederalIncomeTaxWithholdingCents, 6385);
    });

    test('uses all three filing statuses and their standard adjustments', () {
      final single = calculator.calculate(input());
      final mfj = calculator.calculate(
        input(status: FederalFilingStatus.marriedFilingJointly),
      );
      final hoh = calculator.calculate(
        input(status: FederalFilingStatus.headOfHousehold),
      );

      expect(single.adjustedAnnualWagesCents, 4340000);
      expect(single.finalFederalIncomeTaxWithholdingCents, 7808);
      expect(mfj.adjustedAnnualWagesCents, 3910000);
      expect(mfj.finalFederalIncomeTaxWithholdingCents, 3808);
      expect(hoh.adjustedAnnualWagesCents, 4340000);
      expect(hoh.finalFederalIncomeTaxWithholdingCents, 5746);
    });

    for (final status in FederalFilingStatus.values) {
      for (final step2 in [false, true]) {
        test('selects every annual table: $status, Step 2=$step2', () {
          final rows = config.tableFor(status, step2Checkbox: step2);
          expect(rows, hasLength(8));
          expect(rows.first.lowerBoundaryDollars, 0);
          expect(rows.last.upperBoundaryDollars, isNull);
          for (var i = 1; i < rows.length; i++) {
            expect(
              rows[i].lowerBoundaryDollars,
              rows[i - 1].upperBoundaryDollars,
            );
          }
        });
      }
    }

    for (final status in FederalFilingStatus.values) {
      for (final step2 in [false, true]) {
        final rows = config.tableFor(status, step2Checkbox: step2);
        for (var i = 1; i < rows.length; i++) {
          final lowerCents = rows[i].lowerBoundaryDollars * 100;
          final adjustmentCents = step2
              ? 0
              : config.standardAdjustmentCents(status);
          PayrollInputs atAdjustedWages(int adjustedCents) => PayrollInputs(
            grossPayCents: 0,
            filingStatus: status,
            payFrequency: PayFrequency.weekly,
            step2Checkbox: step2,
            step4aAnnualCents: adjustedCents + adjustmentCents,
          );

          test('$status Step 2=$step2: exact boundary $i selects new row', () {
            final atBoundary = calculator.calculate(
              atAdjustedWages(lowerCents),
            );
            final pennyBelow = calculator.calculate(
              atAdjustedWages(lowerCents - 1),
            );

            expect(atBoundary.adjustedAnnualWagesCents, lowerCents);
            expect(atBoundary.selectedTableRow, same(rows[i]));
            expect(pennyBelow.selectedTableRow, same(rows[i - 1]));
          });
        }

        test('$status Step 2=$step2: highest bracket remains open-ended', () {
          final adjustmentCents = step2
              ? 0
              : config.standardAdjustmentCents(status);
          final result = calculator.calculate(
            PayrollInputs(
              grossPayCents: 0,
              filingStatus: status,
              payFrequency: PayFrequency.weekly,
              step2Checkbox: step2,
              step4aAnnualCents: 10000000000 + adjustmentCents,
            ),
          );
          expect(result.selectedTableRow, same(rows.last));
        });
      }
    }

    test('zero gross pay is valid and withholding floors at zero', () {
      final result = calculator.calculate(input(grossPay: 0));
      expect(result.adjustedAnnualWagesCents, 0);
      expect(result.annualTentativeWithholdingCents, 0);
      expect(result.finalFederalIncomeTaxWithholdingCents, 0);
    });

    test('rejects negative and non-finite dollar inputs', () {
      expect(() => input(grossPay: -1), throwsArgumentError);
      expect(() => input(step3: -1), throwsArgumentError);
      expect(() => input(step4a: -1), throwsArgumentError);
      expect(() => input(step4b: -1), throwsArgumentError);
      expect(() => input(step4c: -1), throwsArgumentError);
      expect(() => input(grossPay: double.nan), throwsArgumentError);
      expect(() => input(step3: double.infinity), throwsArgumentError);
      expect(() => input(step4a: double.negativeInfinity), throwsArgumentError);
    });

    test(
      'rejects negative cents and values beyond arithmetic safety limit',
      () {
        expect(
          () => PayrollInputs(
            grossPayCents: -1,
            filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
            payFrequency: PayFrequency.weekly,
          ),
          throwsArgumentError,
        );
        expect(() => input(grossPay: 1000000000001), throwsArgumentError);
      },
    );

    test('converts decimal dollar inputs to cents using half-up rounding', () {
      expect(
        PayrollInputs.fromDollars(
          grossPay: 1.005,
          filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
          payFrequency: PayFrequency.weekly,
        ).grossPayCents,
        101,
      );
      expect(
        PayrollInputs.fromDollars(
          grossPay: 1.004,
          filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
          payFrequency: PayFrequency.weekly,
        ).grossPayCents,
        100,
      );
    });

    test('reports rounding and annualization assumptions', () {
      final result = calculator.calculate(input());
      expect(result.assumptions, hasLength(3));
      expect(result.assumptions.join(' '), contains('recur'));
      expect(result.taxYear, 2026);
    });
  });
}
