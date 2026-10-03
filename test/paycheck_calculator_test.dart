import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paycheck_calculator/main.dart';
import 'package:paycheck_calculator/paycheck_calculator.dart';

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
        expect(result.grossPay, 800);
      });
    }

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
    expect(find.text('GROSS PAY - WEEKLY'), findsOneWidget);
    expect(find.text('\$1100.00'), findsNWidgets(3));

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('GROSS PAY - WEEKLY'), findsOneWidget);
    expect(find.text('Pay Breakdown'), findsOneWidget);
    expect(find.text('Before taxes and deductions'), findsOneWidget);
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
    expect(find.text('\$0.00'), findsNWidgets(4));
  });

  testWidgets('tax estimate marks an unselected state and Clear removes it', (
    tester,
  ) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());
    await tester.enterText(find.byType(EditableText).at(0), '20');
    await tester.enterText(find.byType(EditableText).at(1), '40');
    await tester.enterText(find.byType(EditableText).at(2), '0');
    await tester.ensureVisible(find.text('Calculate Pay'));
    await tester.tap(find.text('Calculate Pay'));
    await tester.pumpAndSettle();
    expect(find.text('TAX & TAKE-HOME ESTIMATE'), findsOneWidget);
    expect(
      find.textContaining('Estimated take-home unavailable'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('TAX & TAKE-HOME ESTIMATE'), findsNothing);
  });

  testWidgets('qualified overtime controls invalidate and display estimate', (
    tester,
  ) async {
    await tester.pumpWidget(const PaycheckCalculatorApp());
    await tester.enterText(find.byType(EditableText).at(0), '25');
    await tester.enterText(find.byType(EditableText).at(1), '40');
    await tester.enterText(find.byType(EditableText).at(2), '10');
    await tester.ensureVisible(find.text('Treat overtime as FLSA-qualified'));
    await tester.tap(find.text('Treat overtime as FLSA-qualified'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('W-4 adjustments and payroll details'),
    );
    await tester.tap(find.text('W-4 adjustments and payroll details'));
    await tester.pumpAndSettle();
    final magiField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText ==
              'Estimated 2026 MAGI for overtime phaseout',
    );
    await tester.ensureVisible(magiField);
    await tester.enterText(magiField, '50000');
    await tester.ensureVisible(find.text('Calculate Pay'));
    await tester.tap(find.text('Calculate Pay'));
    await tester.pumpAndSettle();
    expect(find.text('TAX & TAKE-HOME ESTIMATE'), findsOneWidget);
    expect(
      find.text('Potential qualified overtime (this check)'),
      findsOneWidget,
    );
    expect(
      find.text('Qualified overtime Step 4(b) estimate (annual)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('overtime being required under'),
      findsOneWidget,
    );

    await tester.enterText(magiField, '60000');
    await tester.pumpAndSettle();
    expect(find.text('TAX & TAKE-HOME ESTIMATE'), findsNothing);

    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Treat overtime as FLSA-qualified'), findsOneWidget);
    final switchControl = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Treat overtime as FLSA-qualified'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(switchControl.value, isFalse);
  });
}
