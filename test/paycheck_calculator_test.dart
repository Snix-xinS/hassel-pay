import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycheck_calculator/main.dart';
import 'package:paycheck_calculator/paycheck_calculator.dart';
import 'package:paycheck_calculator/tax/paycheck_tax_service.dart';
import 'package:paycheck_calculator/tax/payroll_inputs.dart' as tax;

void main() {
  const calculator = PaycheckCalculator();

  PaycheckInputs inputs({
    double hourlyRate = 20,
    double regularHours = 40,
    double overtimeHours = 0,
    double overtimeMultiplier = 1.5,
    PayPeriod payPeriod = PayPeriod.weekly,
  }) => PaycheckInputs(
    hourlyRate: hourlyRate,
    regularHours: regularHours,
    overtimeHours: overtimeHours,
    overtimeMultiplier: overtimeMultiplier,
    payPeriod: payPeriod,
  );

  group('PaycheckCalculator', () {
    test('calculates regular pay only', () {
      final result = calculator.calculate(inputs());
      expect(result.regularPay, 800);
      expect(result.overtimePay, 0);
      expect(result.grossPay, 800);
    });

    test('calculates regular plus overtime pay', () {
      final result = calculator.calculate(inputs(overtimeHours: 10));
      expect(result.regularPay, 800);
      expect(result.overtimePay, 300);
      expect(result.grossPay, 1100);
    });

    test('uses the selected overtime multiplier', () {
      final doubleTime = calculator.calculate(
        inputs(overtimeHours: 5, overtimeMultiplier: 2),
      );
      expect(doubleTime.overtimePay, 200);
      expect(doubleTime.grossPay, 1000);
    });

    for (final period in PayPeriod.values) {
      test('retains ${period.label} on the result', () {
        final result = calculator.calculate(inputs(payPeriod: period));
        expect(result.payPeriod, period);
        expect(
          result.regularHours,
          closeTo(40 * period.weeklyHoursMultiplier, 0.000001),
        );
        expect(
          result.grossPay,
          closeTo(800 * period.weeklyHoursMultiplier, 0.000001),
        );
      });
    }

    test('converts weekly baseline hours into each actual paycheck', () {
      final expectedRegularGross = <PayPeriod, double>{
        PayPeriod.weekly: 1000,
        PayPeriod.biweekly: 2000,
        PayPeriod.semimonthly: 2166.67,
        PayPeriod.monthly: 4333.33,
      };
      final expectedOvertimeGross = <PayPeriod, double>{
        PayPeriod.weekly: 375,
        PayPeriod.biweekly: 750,
        PayPeriod.semimonthly: 812.50,
        PayPeriod.monthly: 1625,
      };
      final expectedGross = <PayPeriod, double>{
        PayPeriod.weekly: 1375,
        PayPeriod.biweekly: 2750,
        PayPeriod.semimonthly: 2979.17,
        PayPeriod.monthly: 5958.33,
      };

      for (final period in PayPeriod.values) {
        final regular = calculator.calculate(
          inputs(hourlyRate: 25, payPeriod: period),
        );
        expect(regular.grossPay, closeTo(expectedRegularGross[period]!, 0.005));

        final withOvertime = calculator.calculate(
          inputs(hourlyRate: 25, overtimeHours: 10, payPeriod: period),
        );
        expect(
          withOvertime.regularPay,
          closeTo(expectedRegularGross[period]!, 0.005),
        );
        expect(
          withOvertime.overtimePay,
          closeTo(expectedOvertimeGross[period]!, 0.005),
        );
        expect(withOvertime.grossPay, closeTo(expectedGross[period]!, 0.005));
        expect(
          withOvertime.overtimeHours,
          closeTo(10 * 52 / period.payPeriodsPerYear, 0.000001),
        );
      }
    });

    test(
      'tax service receives gross wages for the selected paycheck period',
      () {
        const taxService = PaycheckTaxService();
        const expectedGrossCents = <PayPeriod, int>{
          PayPeriod.weekly: 137500,
          PayPeriod.biweekly: 275000,
          PayPeriod.semimonthly: 297917,
          PayPeriod.monthly: 595833,
        };

        for (final period in PayPeriod.values) {
          final paycheck = calculator.calculate(
            inputs(hourlyRate: 25, overtimeHours: 10, payPeriod: period),
          );
          final taxResult = taxService.calculate(
            tax.PayrollInputs.fromDollars(
              grossPay: paycheck.grossPay,
              filingStatus:
                  tax.FederalFilingStatus.singleOrMarriedFilingSeparately,
              payFrequency: switch (period) {
                PayPeriod.weekly => tax.PayFrequency.weekly,
                PayPeriod.biweekly => tax.PayFrequency.biweekly,
                PayPeriod.semimonthly => tax.PayFrequency.semimonthly,
                PayPeriod.monthly => tax.PayFrequency.monthly,
              },
              state: tax.StateCode.texas,
              ytdSocialSecurityWages: 0,
              ytdMedicareWages: 0,
            ),
          );

          expect(taxResult.grossPayCents, expectedGrossCents[period]);
          expect(
            taxResult.socialSecurityCents,
            (taxResult.grossPayCents * 620 + 5000) ~/ 10000,
          );
          expect(
            taxResult.medicareCents,
            (taxResult.grossPayCents * 145 + 5000) ~/ 10000,
          );
          expect(taxResult.stateIncomeTaxCents, 0);
        }
      },
    );

    test(
      'rejects negative values, non-finite values, and invalid multipliers',
      () {
        for (final badValue in ['-1', 'NaN', 'Infinity', 'not a number', '']) {
          final errors = PaycheckInputs.validateText(
            hourlyRate: badValue,
            regularHours: '40',
            overtimeHours: '0',
            overtimeMultiplier: '1.5',
          );
          expect(errors, contains('hourlyRate'), reason: 'value: $badValue');
        }
        for (final badMultiplier in ['0', '-1', 'NaN', 'Infinity', '']) {
          final errors = PaycheckInputs.validateText(
            hourlyRate: '20',
            regularHours: '40',
            overtimeHours: '0',
            overtimeMultiplier: badMultiplier,
          );
          expect(errors, contains('overtimeMultiplier'));
        }
      },
    );

    test('rejects calculations that overflow to infinity', () {
      expect(
        () => calculator.calculate(
          inputs(hourlyRate: 1e308, regularHours: 1e308),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid values even when inputs bypass text parsing', () {
      expect(
        () => calculator.calculate(inputs(hourlyRate: -1)),
        throwsArgumentError,
      );
      expect(
        () => calculator.calculate(inputs(overtimeMultiplier: double.nan)),
        throwsArgumentError,
      );
      expect(
        () => calculator.calculate(inputs(overtimeMultiplier: 0)),
        throwsArgumentError,
      );
    });
  });

  testWidgets('Clear resets fields, results, and selected options', (
    tester,
  ) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());

    await tester.enterText(find.byType(EditableText).at(0), '20');
    await tester.enterText(find.byType(EditableText).at(1), '40');
    await tester.enterText(find.byType(EditableText).at(2), '10');
    await tester.ensureVisible(find.text('Calculate Pay'));
    await tester.tap(find.text('Calculate Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Pay breakdown'), findsOneWidget);
    expect(find.text('\$1100.00'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Your estimate will appear here'), findsOneWidget);
    expect(find.text('Your estimated paycheck'), findsNothing);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(0))
          .controller
          .text,
      '',
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .controller
          .text,
      '',
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(2))
          .controller
          .text,
      '',
    );
    expect(find.text('\$0.00'), findsNothing);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(3))
          .controller
          .text,
      '1.5',
    );
  });

  testWidgets('Texas is the default state and Clear restores it', (
    tester,
  ) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());
    expect(find.text('PAYCHECK & TAKE-HOME CALCULATOR'), findsOneWidget);
    expect(find.text('Texas'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(0), '20');
    await tester.enterText(find.byType(EditableText).at(1), '40');
    await tester.enterText(find.byType(EditableText).at(2), '0');
    await tester.ensureVisible(find.text('Calculate Pay'));
    await tester.tap(find.text('Calculate Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Your estimated paycheck'), findsOneWidget);
    expect(find.text('ESTIMATED TAKE-HOME'), findsOneWidget);
    expect(
      find.textContaining('Estimated take-home unavailable'),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Your estimated paycheck'), findsNothing);
    expect(find.text('Texas'), findsOneWidget);
  });

  testWidgets('Hassel header has no theme control', (tester) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());
    expect(find.text('PAYCHECK & TAKE-HOME CALCULATOR'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byTooltip('Switch to light theme'), findsNothing);
    expect(find.byTooltip('Switch to dark theme'), findsNothing);
  });

  testWidgets(
    'phone layout explains weekly hours and shows results without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PaycheckCalculatorApp());
      expect(find.text('Regular hours per week'), findsOneWidget);
      expect(find.text('Overtime hours per week'), findsOneWidget);
      expect(
        find.textContaining('adjust them for the selected pay period'),
        findsOneWidget,
      );
      expect(find.text('Your estimate will appear here'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), '25');
      await tester.enterText(find.byType(EditableText).at(1), '40');
      await tester.enterText(find.byType(EditableText).at(2), '10');
      await tester.ensureVisible(find.text('Calculate Pay'));
      await tester.tap(find.text('Calculate Pay'));
      await tester.pumpAndSettle();

      expect(find.text('Your estimated paycheck'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('qualified overtime controls invalidate and display estimate', (
    tester,
  ) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());
    await tester.enterText(find.byType(EditableText).at(0), '25');
    await tester.enterText(find.byType(EditableText).at(1), '40');
    await tester.enterText(find.byType(EditableText).at(2), '10');
    await tester.ensureVisible(
      find.text('Estimate possible overtime deduction'),
    );
    await tester.tap(find.text('Estimate possible overtime deduction'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Optional W-4 details'));
    await tester.tap(find.text('Optional W-4 details'));
    await tester.pumpAndSettle();
    final magiField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText ==
              'Estimated income for 2026 overtime limit',
    );
    await tester.ensureVisible(magiField);
    await tester.enterText(magiField, '50000');
    await tester.ensureVisible(find.text('Calculate Pay'));
    await tester.tap(find.text('Calculate Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Your estimated paycheck'), findsOneWidget);
    expect(find.text('Potential overtime premium this check'), findsOneWidget);
    expect(find.text('Estimated overtime deduction this year'), findsOneWidget);
    expect(
      find.textContaining('does not lower Social Security or Medicare'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('How we estimated this'));
    await tester.tap(find.text('How we estimated this'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Only overtime that meets federal rules'),
      findsOneWidget,
    );

    await tester.enterText(magiField, '60000');
    await tester.pumpAndSettle();
    expect(find.text('Your estimated paycheck'), findsNothing);

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Estimate possible overtime deduction'), findsOneWidget);
    final switchControl = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Estimate possible overtime deduction'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(switchControl.value, isFalse);
  });
}
