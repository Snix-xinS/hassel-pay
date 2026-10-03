import 'state/state_tax_provider.dart';
import 'qualified_overtime_calculator.dart';

class PaycheckTaxResult {
  const PaycheckTaxResult({
    required this.taxYear,
    required this.grossPayCents,
    required this.federalIncomeTaxCents,
    required this.socialSecurityCents,
    required this.medicareCents,
    required this.additionalMedicareCents,
    required this.stateIncomeTaxCents,
    required this.stateStatus,
    required this.otherDeductionsCents,
    required this.totalWithholdingCents,
    required this.estimatedTakeHomePayCents,
    required this.warnings,
    required this.qualifiedOvertime,
  });

  final int taxYear;
  final int grossPayCents;
  final int federalIncomeTaxCents;
  final int socialSecurityCents;
  final int medicareCents;
  final int additionalMedicareCents;
  final int stateIncomeTaxCents;
  final StateTaxSupportStatus stateStatus;
  final int otherDeductionsCents;

  /// Known withholding sum. State support status indicates if state tax is
  /// excluded because it could not be determined.
  final int totalWithholdingCents;

  /// Null if state is unselected or unsupported, avoiding a misleading net.
  final int? estimatedTakeHomePayCents;
  final List<String> warnings;
  final QualifiedOvertimeResult qualifiedOvertime;
}
