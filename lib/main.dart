import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paycheck_calculator.dart';
import 'tax/paycheck_result.dart';
import 'tax/paycheck_tax_service.dart';
import 'tax/payroll_inputs.dart' as tax;
import 'tax/state/state_tax_provider.dart';

void main() {
  runApp(const PaycheckCalculatorApp());
}

class PaycheckCalculatorApp extends StatelessWidget {
  const PaycheckCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paycheck Calculator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6F8),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const PaycheckCalculatorPage(),
    );
  }
}

enum FilingStatus {
  singleOrMarriedFilingSeparately,
  marriedFilingJointly,
  headOfHousehold,
}

extension FilingStatusLabel on FilingStatus {
  String get label {
    switch (this) {
      case FilingStatus.singleOrMarriedFilingSeparately:
        return 'Single or Married filing separately';
      case FilingStatus.marriedFilingJointly:
        return 'Married filing jointly';
      case FilingStatus.headOfHousehold:
        return 'Head of household';
    }
  }
}

class PaycheckCalculatorPage extends StatefulWidget {
  const PaycheckCalculatorPage({super.key});

  @override
  State<PaycheckCalculatorPage> createState() => _PaycheckCalculatorPageState();
}

class _PaycheckCalculatorPageState extends State<PaycheckCalculatorPage> {
  final PaycheckCalculator calculator = const PaycheckCalculator();
  final TextEditingController hourlyRateController = TextEditingController();
  final TextEditingController regularHoursController = TextEditingController();
  final TextEditingController overtimeHoursController = TextEditingController();
  final TextEditingController overtimeMultiplierController =
      TextEditingController(text: '1.5');
  final TextEditingController step3Controller = TextEditingController(
    text: '0',
  );
  final TextEditingController step4aController = TextEditingController(
    text: '0',
  );
  final TextEditingController step4bController = TextEditingController(
    text: '0',
  );
  final TextEditingController step4cController = TextEditingController(
    text: '0',
  );
  final TextEditingController qualifiedOvertimeMagiController =
      TextEditingController();
  final TextEditingController socialSecurityYtdController =
      TextEditingController();
  final TextEditingController medicareYtdController = TextEditingController();
  final TextEditingController otherDeductionsController = TextEditingController(
    text: '0',
  );
  final PaycheckTaxService taxService = const PaycheckTaxService();

  PaycheckResult? result;
  PaycheckTaxResult? taxResult;
  PayPeriod selectedPayPeriod = PayPeriod.weekly;
  FilingStatus selectedFilingStatus =
      FilingStatus.singleOrMarriedFilingSeparately;
  tax.StateCode selectedState = tax.StateCode.notSelected;
  bool step2Checked = false;
  bool qualifiedOvertimeSelected = false;
  bool overtimeMarriedFilingSeparately = false;
  String? taxInputError;

  String? hourlyRateError;
  String? regularHoursError;
  String? overtimeHoursError;
  String? overtimeMultiplierError;

  bool validateInputs() {
    final errors = PaycheckInputs.validateText(
      hourlyRate: hourlyRateController.text,
      regularHours: regularHoursController.text,
      overtimeHours: overtimeHoursController.text,
      overtimeMultiplier: overtimeMultiplierController.text,
    );

    setState(() {
      hourlyRateError = errors['hourlyRate'];
      regularHoursError = errors['regularHours'];
      overtimeHoursError = errors['overtimeHours'];
      overtimeMultiplierError = errors['overtimeMultiplier'];
    });

    return errors.isEmpty;
  }

  void calculatePay() {
    if (!validateInputs()) {
      return;
    }

    PaycheckResult? grossResult;
    try {
      final inputs = PaycheckInputs.fromText(
        hourlyRate: hourlyRateController.text,
        regularHours: regularHoursController.text,
        overtimeHours: overtimeHoursController.text,
        overtimeMultiplier: overtimeMultiplierController.text,
        payPeriod: selectedPayPeriod,
      );
      final calculated = calculator.calculate(inputs);
      grossResult = calculated;
      final estimatedMagi = qualifiedOvertimeSelected
          ? _optionalMoney(qualifiedOvertimeMagiController.text)
          : null;
      final isMfs =
          selectedFilingStatus ==
              FilingStatus.singleOrMarriedFilingSeparately &&
          overtimeMarriedFilingSeparately;
      final overtimeInputs = tax.QualifiedOvertimeInputs(
        overtimeCompensationCents: tax.PayrollInputs.dollarsToCents(
          calculated.overtimePay,
          'overtime compensation',
        ),
        regularRateCents: tax.PayrollInputs.dollarsToCents(
          inputs.hourlyRate,
          'regular rate',
        ),
        overtimeHoursThousandths: (inputs.overtimeHours * 1000).round(),
        overtimeMultiplierThousandths: (inputs.overtimeMultiplier * 1000)
            .round(),
        treatAsFlsaQualified: qualifiedOvertimeSelected,
        marriedFilingSeparately: isMfs,
        estimatedMagiCents: estimatedMagi == null
            ? null
            : tax.PayrollInputs.dollarsToCents(estimatedMagi, 'estimated MAGI'),
      );
      final taxInputs = tax.PayrollInputs.fromDollars(
        grossPay: calculated.grossPay,
        filingStatus: switch (selectedFilingStatus) {
          FilingStatus.singleOrMarriedFilingSeparately =>
            tax.FederalFilingStatus.singleOrMarriedFilingSeparately,
          FilingStatus.marriedFilingJointly =>
            tax.FederalFilingStatus.marriedFilingJointly,
          FilingStatus.headOfHousehold =>
            tax.FederalFilingStatus.headOfHousehold,
        },
        payFrequency: switch (selectedPayPeriod) {
          PayPeriod.weekly => tax.PayFrequency.weekly,
          PayPeriod.biweekly => tax.PayFrequency.biweekly,
          PayPeriod.semimonthly => tax.PayFrequency.semimonthly,
          PayPeriod.monthly => tax.PayFrequency.monthly,
        },
        state: selectedState,
        ytdSocialSecurityWages: _optionalMoney(
          socialSecurityYtdController.text,
        ),
        ytdMedicareWages: _optionalMoney(medicareYtdController.text),
        step2Checkbox: step2Checked,
        step3Annual: _money(step3Controller.text),
        step4aAnnual: _money(step4aController.text),
        step4bAnnual: _money(step4bController.text),
        step4cPerPaycheck: _money(step4cController.text),
        otherCashDeductions: _money(otherDeductionsController.text),
        qualifiedOvertime: overtimeInputs,
      );
      final calculatedTax = taxService.calculate(taxInputs);
      setState(() {
        result = calculated;
        taxResult = calculatedTax;
        taxInputError = null;
      });
    } on FormatException catch (error) {
      setState(() {
        result = grossResult;
        taxResult = null;
        taxInputError = error.message;
      });
    } on ArgumentError catch (error) {
      setState(() {
        result = grossResult;
        taxResult = null;
        taxInputError = error.message?.toString() ?? 'Check tax inputs.';
      });
    }
  }

  double _money(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw FormatException('Enter a valid non-negative tax amount.');
    }
    return parsed;
  }

  double? _optionalMoney(String text) =>
      text.trim().isEmpty ? null : _money(text);

  void clearTaxResult() => setState(() {
    taxResult = null;
    taxInputError = null;
  });

  void applyHoursPreset({
    required String regularHours,
    required String overtimeHours,
  }) {
    regularHoursController.text = regularHours;
    overtimeHoursController.text = overtimeHours;

    setState(() {
      regularHoursError = null;
      overtimeHoursError = null;
      result = null;
      taxResult = null;
    });
  }

  void clearForm() {
    hourlyRateController.clear();
    regularHoursController.clear();
    overtimeHoursController.clear();
    overtimeMultiplierController.text = '1.5';
    step3Controller.text = '0';
    step4aController.text = '0';
    step4bController.text = '0';
    step4cController.text = '0';
    qualifiedOvertimeMagiController.clear();
    socialSecurityYtdController.clear();
    medicareYtdController.clear();
    otherDeductionsController.text = '0';

    setState(() {
      result = null;
      taxResult = null;
      selectedPayPeriod = PayPeriod.weekly;
      selectedFilingStatus = FilingStatus.singleOrMarriedFilingSeparately;
      hourlyRateError = null;
      regularHoursError = null;
      overtimeHoursError = null;
      overtimeMultiplierError = null;
      selectedState = tax.StateCode.notSelected;
      step2Checked = false;
      qualifiedOvertimeSelected = false;
      overtimeMarriedFilingSeparately = false;
      taxInputError = null;
    });
  }

  @override
  void dispose() {
    hourlyRateController.dispose();
    regularHoursController.dispose();
    overtimeHoursController.dispose();
    overtimeMultiplierController.dispose();
    step3Controller.dispose();
    step4aController.dispose();
    step4bController.dispose();
    step4cController.dispose();
    qualifiedOvertimeMagiController.dispose();
    socialSecurityYtdController.dispose();
    medicareYtdController.dispose();
    otherDeductionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final horizontalPadding = media.size.width >= 720 ? 32.0 : 20.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 560
                  ? 520.0
                  : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AppHeader(),
                        const SizedBox(height: 20),
                        _GrossPayHero(
                          amount: result?.grossPay ?? 0,
                          payPeriod: selectedPayPeriod,
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Hours & rate',
                          subtitle: 'Enter your pay details for this check',
                          child: Column(
                            children: [
                              _PayPeriodSelector(
                                value: selectedPayPeriod,
                                onChanged: (payPeriod) {
                                  if (payPeriod == null) {
                                    return;
                                  }
                                  setState(() {
                                    selectedPayPeriod = payPeriod;
                                    result = null;
                                    taxResult = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: hourlyRateController,
                                label: 'Hourly Rate',
                                hint: '0.00',
                                prefixText: '\$ ',
                                icon: Icons.payments_outlined,
                                errorText: hourlyRateError,
                                onChanged: (_) {
                                  setState(() {
                                    hourlyRateError = null;
                                    result = null;
                                    taxResult = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _HoursPresets(onSelect: applyHoursPreset),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: regularHoursController,
                                label: 'Regular Hours',
                                hint: '40',
                                icon: Icons.schedule_outlined,
                                errorText: regularHoursError,
                                onChanged: (_) {
                                  setState(() {
                                    regularHoursError = null;
                                    result = null;
                                    taxResult = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: overtimeHoursController,
                                label: 'Overtime Hours',
                                hint: '0',
                                icon: Icons.more_time_outlined,
                                errorText: overtimeHoursError,
                                onChanged: (_) {
                                  setState(() {
                                    overtimeHoursError = null;
                                    result = null;
                                    taxResult = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: overtimeMultiplierController,
                                label: 'Overtime Multiplier',
                                hint: '1.5',
                                icon: Icons.trending_up_outlined,
                                errorText: overtimeMultiplierError,
                                onChanged: (_) {
                                  setState(() {
                                    overtimeMultiplierError = null;
                                    result = null;
                                    taxResult = null;
                                  });
                                },
                              ),
                              Material(
                                color: Colors.transparent,
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Treat overtime as FLSA-qualified',
                                  ),
                                  subtitle: const Text(
                                    'Only the premium above your regular rate may qualify (usually 0.5×). Eligibility depends on FLSA rules.',
                                  ),
                                  value: qualifiedOvertimeSelected,
                                  onChanged: (value) => setState(() {
                                    qualifiedOvertimeSelected = value;
                                    taxResult = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Federal Tax Settings',
                          subtitle: 'Estimate federal and other withholding',
                          child: Column(
                            children: [
                              _FilingStatusSelector(
                                value: selectedFilingStatus,
                                onChanged: (filingStatus) {
                                  if (filingStatus == null) return;
                                  setState(() {
                                    selectedFilingStatus = filingStatus;
                                    taxResult = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Material(
                                color: Colors.transparent,
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text(
                                    'W-4 adjustments and payroll details',
                                  ),
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'W-4 Step 2: multiple jobs',
                                      ),
                                      value: step2Checked,
                                      onChanged: (value) => setState(() {
                                        step2Checked = value;
                                        taxResult = null;
                                      }),
                                    ),
                                    _TaxAmountField(
                                      controller: step3Controller,
                                      label: 'Step 3 annual credits',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: step4aController,
                                      label: 'Step 4(a) annual other income',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: step4bController,
                                      label:
                                          'Other Step 4(b) deductions (annual)',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    if (qualifiedOvertimeSelected) ...[
                                      _TaxAmountField(
                                        controller:
                                            qualifiedOvertimeMagiController,
                                        label:
                                            'Estimated 2026 MAGI for overtime phaseout',
                                        onChanged: (_) => clearTaxResult(),
                                      ),
                                      if (selectedFilingStatus ==
                                          FilingStatus
                                              .singleOrMarriedFilingSeparately)
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'I file married filing separately',
                                          ),
                                          subtitle: const Text(
                                            'Married taxpayers must file jointly for this deduction.',
                                          ),
                                          value:
                                              overtimeMarriedFilingSeparately,
                                          onChanged: (value) => setState(() {
                                            overtimeMarriedFilingSeparately =
                                                value;
                                            taxResult = null;
                                          }),
                                        ),
                                    ],
                                    _TaxAmountField(
                                      controller: step4cController,
                                      label: 'Step 4(c) extra per paycheck',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    DropdownButtonFormField<tax.StateCode>(
                                      initialValue: selectedState,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'State',
                                      ),
                                      items: tax.StateCode.values
                                          .map(
                                            (state) => DropdownMenuItem(
                                              value: state,
                                              child: Text(state.label),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) => setState(() {
                                        selectedState =
                                            value ?? tax.StateCode.notSelected;
                                        taxResult = null;
                                      }),
                                    ),
                                    const SizedBox(height: 8),
                                    _TaxAmountField(
                                      controller: socialSecurityYtdController,
                                      label:
                                          'Current-employer Social Security wages YTD (blank assumes \$0)',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: medicareYtdController,
                                      label:
                                          'Current-employer Medicare wages YTD (blank assumes \$0)',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: otherDeductionsController,
                                      label:
                                          'Other after-tax deductions per check',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Pre-tax deductions are not modeled. Qualified overtime eligibility is user-attested and not verified.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ActionButtons(
                          onCalculate: calculatePay,
                          onClear: clearForm,
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Pay Breakdown',
                          subtitle:
                              '${result?.payPeriod.label ?? selectedPayPeriod.label} gross pay before taxes and deductions',
                          child: Column(
                            children: [
                              _BreakdownRow(
                                label: 'Regular Pay',
                                value: result?.regularPay ?? 0,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 8),
                              _BreakdownRow(
                                label: 'Overtime Pay',
                                value: result?.overtimePay ?? 0,
                                colorScheme: colorScheme,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              _GrossPaySummaryRow(
                                amount: result?.grossPay ?? 0,
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ),
                        if (taxInputError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            taxInputError!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        if (taxResult != null) ...[
                          const SizedBox(height: 20),
                          _SectionCard(
                            title: 'TAX & TAKE-HOME ESTIMATE',
                            subtitle:
                                'Estimated paycheck withholding — not a final tax calculation.',
                            child: Column(
                              children: [
                                _TaxResultRow(
                                  label: 'Gross Pay',
                                  cents: taxResult!.grossPayCents,
                                ),
                                _TaxResultRow(
                                  label: 'Total overtime compensation',
                                  cents: taxResult!
                                      .qualifiedOvertime
                                      .overtimeCompensationCents,
                                ),
                                _TaxResultRow(
                                  label:
                                      'Potential qualified overtime (this check)',
                                  cents: taxResult!
                                      .qualifiedOvertime
                                      .potentialQualifiedOvertimePerPaycheckCents,
                                ),
                                _TaxResultRow(
                                  label:
                                      'Qualified overtime Step 4(b) estimate (annual)',
                                  cents: taxResult!
                                      .qualifiedOvertime
                                      .annualDeductionCents,
                                ),
                                _TaxResultRow(
                                  label: 'Federal Income Tax',
                                  cents: taxResult!.federalIncomeTaxCents,
                                ),
                                _TaxResultRow(
                                  label: 'Social Security',
                                  cents: taxResult!.socialSecurityCents,
                                ),
                                _TaxResultRow(
                                  label: 'Medicare',
                                  cents: taxResult!.medicareCents,
                                ),
                                _TaxResultRow(
                                  label: 'Additional Medicare',
                                  cents: taxResult!.additionalMedicareCents,
                                ),
                                _TaxResultRow(
                                  label: 'State Income Tax',
                                  cents: taxResult!.stateIncomeTaxCents,
                                  suffix: switch (taxResult!.stateStatus) {
                                    StateTaxSupportStatus.supported => null,
                                    StateTaxSupportStatus.unsupported =>
                                      'Not supported',
                                    StateTaxSupportStatus.notSelected =>
                                      'Select a state',
                                  },
                                ),
                                _TaxResultRow(
                                  label: 'Other after-tax deductions',
                                  cents: taxResult!.otherDeductionsCents,
                                ),
                                const Divider(height: 20),
                                _TaxResultRow(
                                  label: 'Known withholding subtotal',
                                  cents: taxResult!.totalWithholdingCents,
                                  bold: true,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  taxResult!.estimatedTakeHomePayCents == null
                                      ? 'Estimated take-home unavailable until a supported state is selected.'
                                      : 'ESTIMATED TAKE-HOME\n\$${(taxResult!.estimatedTakeHomePayCents! / 100).toStringAsFixed(2)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...taxResult!.warnings.map(
                                  (warning) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '• $warning',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paycheck Calculator',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Estimate your gross pay in seconds.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrossPayHero extends StatelessWidget {
  const _GrossPayHero({required this.amount, required this.payPeriod});

  final double amount;
  final PayPeriod payPeriod;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.82),
            colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROSS PAY - ${payPeriod.label.toUpperCase()}',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 44,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Before taxes and deductions',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HoursPresets extends StatelessWidget {
  const _HoursPresets({required this.onSelect});

  final void Function({
    required String regularHours,
    required String overtimeHours,
  })
  onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Standard 40 Hours'),
              onPressed: () => onSelect(regularHours: '40', overtimeHours: '0'),
            ),
            ActionChip(
              label: const Text('40 + 10 OT'),
              onPressed: () =>
                  onSelect(regularHours: '40', overtimeHours: '10'),
            ),
            ActionChip(
              label: const Text('40 + 20 OT'),
              onPressed: () =>
                  onSelect(regularHours: '40', overtimeHours: '20'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PayPeriodSelector extends StatelessWidget {
  const _PayPeriodSelector({required this.value, required this.onChanged});

  final PayPeriod value;
  final ValueChanged<PayPeriod?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<PayPeriod>(
      key: ValueKey(value),
      initialValue: value,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: 'Pay Period',
        prefixIcon: const Icon(Icons.calendar_month_outlined, size: 22),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      items: PayPeriod.values
          .map(
            (payPeriod) => DropdownMenuItem<PayPeriod>(
              value: payPeriod,
              child: Text(payPeriod.label),
            ),
          )
          .toList(),
    );
  }
}

class _FilingStatusSelector extends StatelessWidget {
  const _FilingStatusSelector({required this.value, required this.onChanged});

  final FilingStatus value;
  final ValueChanged<FilingStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<FilingStatus>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: 'Filing Status',
        prefixIcon: const Icon(Icons.assignment_ind_outlined, size: 22),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      items: FilingStatus.values
          .map(
            (status) => DropdownMenuItem<FilingStatus>(
              value: status,
              child: Text(status.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }
}

class _PayInputField extends StatelessWidget {
  const _PayInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefixText,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.error, width: 1.6),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, size: 22),
        errorText: errorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onCalculate, required this.onClear});

  final VoidCallback onCalculate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 360;

        final calculateButton = FilledButton.icon(
          onPressed: onCalculate,
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: const Text('Calculate Pay'),
        );

        final clearButton = OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text('Clear'),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              calculateButton,
              const SizedBox(height: 10),
              clearButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: calculateButton),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: clearButton),
          ],
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  final String label;
  final double value;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TaxAmountField extends StatelessWidget {
  const _TaxAmountField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _TaxResultRow extends StatelessWidget {
  const _TaxResultRow({
    required this.label,
    required this.cents,
    this.suffix,
    this.bold = false,
  });

  final String label;
  final int cents;
  final String? suffix;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
        ),
        Text(
          suffix ?? '\$${(cents / 100).toStringAsFixed(2)}',
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    ),
  );
}

class _GrossPaySummaryRow extends StatelessWidget {
  const _GrossPaySummaryRow({required this.amount, required this.colorScheme});

  final double amount;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Gross Pay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
