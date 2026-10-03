import 'package:flutter_test/flutter_test.dart';
import 'package:paycheck_calculator/tax/paycheck_tax_service.dart';
import 'package:paycheck_calculator/tax/payroll_inputs.dart';
import 'package:paycheck_calculator/tax/qualified_overtime_calculator.dart';

QualifiedOvertimeInputs qot({
  int rate = 2500,
  int hours = 10000,
  int multiplier = 1500,
  bool qualified = true,
  int? magi = 5000000,
  bool mfs = false,
}) => QualifiedOvertimeInputs(
  overtimeCompensationCents: rate * hours * multiplier ~/ 1000000,
  regularRateCents: rate,
  overtimeHoursThousandths: hours,
  overtimeMultiplierThousandths: multiplier,
  treatAsFlsaQualified: qualified,
  marriedFilingSeparately: mfs,
  estimatedMagiCents: magi,
);

QualifiedOvertimeResult calculate(
  QualifiedOvertimeInputs inputs, {
  PayFrequency frequency = PayFrequency.weekly,
  FederalFilingStatus status =
      FederalFilingStatus.singleOrMarriedFilingSeparately,
}) => const QualifiedOvertimeCalculator().calculate(
  inputs: inputs,
  payFrequency: frequency,
  filingStatus: status,
);

void main() {
  group('2026 qualified overtime deduction estimate', () {
    test(
      'time-and-a-half produces 375 dollars OT and 125 dollars potential premium',
      () {
        final result = calculate(qot());
        expect(qot().overtimeCompensationCents, 37500);
        expect(result.potentialQualifiedOvertimePerPaycheckCents, 12500);
        expect(result.annualizedPotentialQualifiedOvertimeCents, 650000);
        expect(result.annualDeductionCents, 650000);
      },
    );

    test(
      'does not qualify whole OT compensation or premium above half time',
      () {
        expect(
          calculate(
            qot(multiplier: 2000),
          ).potentialQualifiedOvertimePerPaycheckCents,
          12500,
        );
        expect(
          calculate(
            qot(multiplier: 1000),
          ).potentialQualifiedOvertimePerPaycheckCents,
          0,
        );
        expect(
          calculate(qot(hours: 0)).potentialQualifiedOvertimePerPaycheckCents,
          0,
        );
      },
    );

    test(
      'unselected qualification reports potential but applies no deduction',
      () {
        final result = calculate(qot(qualified: false));
        expect(result.potentialQualifiedOvertimePerPaycheckCents, 12500);
        expect(result.annualDeductionCents, 0);
      },
    );

    test('annual individual and joint limits are respected', () {
      final individual = calculate(qot(rate: 100000, hours: 10000));
      final joint = calculate(
        qot(rate: 100000, hours: 10000),
        status: FederalFilingStatus.marriedFilingJointly,
      );
      expect(individual.annualDeductionCents, 1250000);
      expect(joint.annualDeductionCents, 2500000);
    });

    test(
      'MAGI phaseout reduces 100 dollars per completed 1000 dollars over threshold',
      () {
        expect(calculate(qot(magi: 15099999)).magiPhaseoutCents, 0);
        expect(calculate(qot(magi: 15100000)).magiPhaseoutCents, 10000);
        expect(calculate(qot(magi: 16000000)).magiPhaseoutCents, 100000);
        expect(
          calculate(
            qot(magi: 30100000),
            status: FederalFilingStatus.marriedFilingJointly,
          ).magiPhaseoutCents,
          10000,
        );
        expect(calculate(qot(magi: 100000000)).annualDeductionCents, 0);
      },
    );

    test('married filing separately cannot use the deduction', () {
      final result = calculate(qot(mfs: true));
      expect(result.annualDeductionCents, 0);
      expect(result.warnings, contains(contains('married filing separately')));
    });

    test('qualified estimate requires MAGI for phaseout calculation', () {
      expect(() => calculate(qot(magi: null)), throwsArgumentError);
    });

    test('rejects negative or impossible numeric input', () {
      expect(
        () => QualifiedOvertimeInputs(
          overtimeCompensationCents: -1,
          regularRateCents: 2500,
          overtimeHoursThousandths: 10000,
          overtimeMultiplierThousandths: 1500,
        ),
        throwsArgumentError,
      );
      expect(
        () => QualifiedOvertimeInputs(
          overtimeCompensationCents: 37500,
          regularRateCents: 2500,
          overtimeHoursThousandths: -1,
          overtimeMultiplierThousandths: 1500,
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
    });

    test('Step 4(b) QOT changes federal only and leaves FICA wages intact', () {
      final ordinary = PayrollInputs.fromDollars(
        grossPay: 2000,
        filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
        payFrequency: PayFrequency.weekly,
        state: StateCode.texas,
      );
      final overtime = PayrollInputs.fromDollars(
        grossPay: 2000,
        filingStatus: FederalFilingStatus.singleOrMarriedFilingSeparately,
        payFrequency: PayFrequency.weekly,
        state: StateCode.texas,
        qualifiedOvertime: qot(),
      );
      const service = PaycheckTaxService();
      final base = service.calculate(ordinary);
      final adjusted = service.calculate(overtime);
      expect(
        adjusted.federalIncomeTaxCents,
        lessThan(base.federalIncomeTaxCents),
      );
      expect(adjusted.socialSecurityCents, base.socialSecurityCents);
      expect(adjusted.medicareCents, base.medicareCents);
      expect(adjusted.grossPayCents, base.grossPayCents);
    });
  });
}
