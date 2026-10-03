import '../payroll_inputs.dart';
import 'state_tax_provider.dart';

/// Texas has no individual income tax; this provider covers only that tax.
class TexasStateTaxProvider implements StateTaxProvider {
  const TexasStateTaxProvider();

  @override
  StateCode get state => StateCode.texas;

  @override
  StateTaxResult calculate(StateTaxRequest request) {
    if (request.state != StateCode.texas || request.taxYear != 2026) {
      return const UnsupportedStateTaxProvider().calculate(request);
    }
    return StateTaxResult(
      state: StateCode.texas,
      withholdingCents: 0,
      status: StateTaxSupportStatus.supported,
      assumptions: const [
        'Texas individual income-tax withholding is \$0; this does not represent other taxes.',
      ],
    );
  }
}
