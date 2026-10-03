/// Supported pay periods for gross pay estimates.
enum PayPeriod {
  weekly('Weekly'),
  biweekly('Biweekly'),
  semimonthly('Semimonthly'),
  monthly('Monthly');

  const PayPeriod(this.label);

  final String label;
}

/// Values entered by the user for one selected pay period.
class PaycheckInputs {
  const PaycheckInputs({
    required this.hourlyRate,
    required this.regularHours,
    required this.overtimeHours,
    required this.overtimeMultiplier,
    required this.payPeriod,
  });

  final double hourlyRate;
  final double regularHours;
  final double overtimeHours;
  final double overtimeMultiplier;
  final PayPeriod payPeriod;

  /// Parses and validates the raw text field values.
  static Map<String, String> validateText({
    required String hourlyRate,
    required String regularHours,
    required String overtimeHours,
    required String overtimeMultiplier,
  }) {
    final errors = <String, String>{};
    _validateNonNegative(hourlyRate, 'hourly rate', 'hourlyRate', errors);
    _validateNonNegative(regularHours, 'regular hours', 'regularHours', errors);
    _validateNonNegative(
      overtimeHours,
      'overtime hours',
      'overtimeHours',
      errors,
    );
    final multiplier = _parse(overtimeMultiplier);
    if (multiplier == null) {
      errors['overtimeMultiplier'] = overtimeMultiplier.trim().isEmpty
          ? 'Enter overtime multiplier.'
          : 'Enter a valid number for overtime multiplier.';
    } else if (multiplier <= 0) {
      errors['overtimeMultiplier'] =
          'Overtime multiplier must be greater than zero.';
    }
    return errors;
  }

  static void _validateNonNegative(
    String value,
    String label,
    String key,
    Map<String, String> errors,
  ) {
    final parsed = _parse(value);
    if (parsed == null) {
      errors[key] = value.trim().isEmpty
          ? 'Enter $label.'
          : 'Enter a valid number for $label.';
    } else if (parsed < 0) {
      errors[key] = '$label cannot be negative.';
    }
  }

  static double? _parse(String value) {
    final parsed = double.tryParse(value.trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static PaycheckInputs fromText({
    required String hourlyRate,
    required String regularHours,
    required String overtimeHours,
    required String overtimeMultiplier,
    required PayPeriod payPeriod,
  }) {
    final errors = validateText(
      hourlyRate: hourlyRate,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      overtimeMultiplier: overtimeMultiplier,
    );
    if (errors.isNotEmpty) {
      throw ArgumentError.value(errors, 'inputs', 'Invalid paycheck inputs');
    }
    return PaycheckInputs(
      hourlyRate: _parse(hourlyRate)!,
      regularHours: _parse(regularHours)!,
      overtimeHours: _parse(overtimeHours)!,
      overtimeMultiplier: _parse(overtimeMultiplier)!,
      payPeriod: payPeriod,
    );
  }
}

/// Gross pay result before taxes or deductions.
class PaycheckResult {
  const PaycheckResult({
    required this.regularPay,
    required this.overtimePay,
    required this.grossPay,
    required this.payPeriod,
  });

  final double regularPay;
  final double overtimePay;
  final double grossPay;
  final PayPeriod payPeriod;
}

class PaycheckCalculator {
  const PaycheckCalculator();

  PaycheckResult calculate(PaycheckInputs inputs) {
    final values = [
      inputs.hourlyRate,
      inputs.regularHours,
      inputs.overtimeHours,
      inputs.overtimeMultiplier,
    ];
    if (values.any((value) => !value.isFinite || value < 0) ||
        inputs.overtimeMultiplier == 0) {
      throw ArgumentError(
        'Paycheck inputs must be finite and non-negative, with a positive overtime multiplier.',
      );
    }
    final regularPay = inputs.hourlyRate * inputs.regularHours;
    final overtimePay =
        inputs.hourlyRate * inputs.overtimeMultiplier * inputs.overtimeHours;
    final grossPay = regularPay + overtimePay;
    if (!regularPay.isFinite || !overtimePay.isFinite || !grossPay.isFinite) {
      throw ArgumentError('The inputs produce an unrepresentable pay amount.');
    }
    return PaycheckResult(
      regularPay: regularPay,
      overtimePay: overtimePay,
      grossPay: grossPay,
      payPeriod: inputs.payPeriod,
    );
  }
}
