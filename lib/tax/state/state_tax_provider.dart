import '../payroll_inputs.dart';

enum StateTaxSupportStatus { supported, unsupported, notSelected }

/// Marker for future jurisdiction-specific state settings.
abstract interface class StateTaxSettings {}

class StateTaxRequest {
  const StateTaxRequest({
    required this.state,
    required this.taxableWagesCents,
    required this.payFrequency,
    required this.taxYear,
    this.settings,
  });

  final StateCode state;
  final int taxableWagesCents;
  final PayFrequency payFrequency;
  final int taxYear;
  final StateTaxSettings? settings;
}

class StateTaxResult {
  const StateTaxResult({
    required this.state,
    required this.withholdingCents,
    required this.status,
    this.assumptions = const [],
  });

  final StateCode state;

  /// Zero for unsupported states is a placeholder only; inspect [status].
  final int withholdingCents;
  final StateTaxSupportStatus status;
  final List<String> assumptions;
}

abstract interface class StateTaxProvider {
  StateCode get state;

  StateTaxResult calculate(StateTaxRequest request);
}

class UnsupportedStateTaxProvider implements StateTaxProvider {
  const UnsupportedStateTaxProvider();

  @override
  StateCode get state => StateCode.notSelected;

  @override
  StateTaxResult calculate(StateTaxRequest request) {
    return StateTaxResult(
      state: request.state,
      withholdingCents: 0,
      status: StateTaxSupportStatus.unsupported,
      assumptions: const [
        'State income tax withholding is not currently supported for this state.',
      ],
    );
  }
}
