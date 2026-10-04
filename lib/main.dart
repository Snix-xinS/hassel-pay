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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hassel Pay',
      theme: _hasselTheme(Brightness.light),
      darkTheme: _hasselTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const PaycheckCalculatorPage(),
    );
  }
}

ThemeData _hasselTheme(Brightness brightness) {
  const backgroundDark = Color(0xFF0B1220);
  const surfaceDark = Color(0xFF111827);
  const green = Color(0xFF22CC5E);
  const emerald = Color(0xFF10B981);
  const blue = Color(0xFF2563EB);
  const primaryTextDark = Color(0xFFE5E7EB);
  const secondaryTextDark = Color(0xFF94A3B8);
  final isDark = brightness == Brightness.dark;
  final colorScheme =
      ColorScheme.fromSeed(seedColor: green, brightness: brightness).copyWith(
        primary: green,
        onPrimary: const Color(0xFF06120A),
        primaryContainer: isDark
            ? const Color(0xFF123222)
            : const Color(0xFFDDF7E5),
        onPrimaryContainer: isDark
            ? const Color(0xFFD9FBE4)
            : const Color(0xFF14532D),
        secondary: emerald,
        onSecondary: const Color(0xFF061510),
        tertiary: blue,
        surface: isDark ? surfaceDark : const Color(0xFFFFFFFF),
        onSurface: isDark ? primaryTextDark : const Color(0xFF0F172A),
        onSurfaceVariant: isDark ? secondaryTextDark : const Color(0xFF475569),
        outline: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        outlineVariant: isDark
            ? const Color(0xFF263449)
            : const Color(0xFFE2E8F0),
        surfaceContainerHighest: isDark
            ? const Color(0xFF1B2638)
            : const Color(0xFFF1F5F9),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? backgroundDark : const Color(0xFFF8FAFC),
    dividerColor: colorScheme.outlineVariant,
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
      prefixStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: const Color(0xFF06120A),
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
  );
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
  final TextEditingController step3Controller = TextEditingController();
  final TextEditingController step4aController = TextEditingController();
  final TextEditingController step4bController = TextEditingController();
  final TextEditingController step4cController = TextEditingController();
  final TextEditingController qualifiedOvertimeMagiController =
      TextEditingController();
  final TextEditingController socialSecurityYtdController =
      TextEditingController();
  final TextEditingController medicareYtdController = TextEditingController();
  final TextEditingController otherDeductionsController =
      TextEditingController();
  final PaycheckTaxService taxService = const PaycheckTaxService();

  PaycheckResult? result;
  PaycheckTaxResult? taxResult;
  PayPeriod selectedPayPeriod = PayPeriod.weekly;
  FilingStatus selectedFilingStatus =
      FilingStatus.singleOrMarriedFilingSeparately;
  tax.StateCode selectedState = tax.StateCode.texas;
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
    FocusScope.of(context).unfocus();
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
        overtimeHoursThousandths: (calculated.overtimeHours * 1000).round(),
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
    if (text.trim().isEmpty) return 0;
    final parsed = double.tryParse(text.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw FormatException(
        'Enter a dollar amount using numbers only, with no negative values.',
      );
    }
    return parsed;
  }

  double? _optionalMoney(String text) =>
      text.trim().isEmpty ? null : _money(text);

  List<String> _estimateExplanationMessages(
    tax.StateCode state,
    bool includesQualifiedOvertime,
  ) => [
    'Federal income-tax withholding is estimated from your pay period, filing status, and W-4 entries.',
    'Social Security and Medicare are estimated separately. Year-to-date wages help account for annual limits.',
    if (includesQualifiedOvertime)
      'If your overtime meets federal rules, the eligible premium may lower federal income-tax withholding. It remains subject to Social Security and Medicare.',
    if (state == tax.StateCode.texas)
      'Texas has no individual state income tax.'
    else
      'State withholding is included only for states with supported rules. This estimate currently supports Texas.',
    'This is an estimate, not a guarantee of your employer paycheck. Pre-tax deductions and other payroll-specific adjustments are not included.',
  ];

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
    FocusScope.of(context).unfocus();
    hourlyRateController.clear();
    regularHoursController.clear();
    overtimeHoursController.clear();
    overtimeMultiplierController.text = '1.5';
    step3Controller.clear();
    step4aController.clear();
    step4bController.clear();
    step4cController.clear();
    qualifiedOvertimeMagiController.clear();
    socialSecurityYtdController.clear();
    medicareYtdController.clear();
    otherDeductionsController.clear();

    setState(() {
      result = null;
      taxResult = null;
      selectedPayPeriod = PayPeriod.weekly;
      selectedFilingStatus = FilingStatus.singleOrMarriedFilingSeparately;
      hourlyRateError = null;
      regularHoursError = null;
      overtimeHoursError = null;
      overtimeMultiplierError = null;
      selectedState = tax.StateCode.texas;
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
      value:
          (Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 760
                  ? 720.0
                  : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AppHeader(),
                        const SizedBox(height: 24),
                        _SectionCard(
                          title: 'Hours & rate',
                          subtitle:
                              'Enter your typical weekly hours. We adjust them for the selected pay period.',
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
                                label: 'Hourly rate',
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
                                label: 'Regular hours per week',
                                hint: '40',
                                suffixText: 'hrs',
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
                                label: 'Overtime hours per week',
                                hint: '0',
                                suffixText: 'hrs',
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
                                label: 'Overtime multiplier',
                                hint: '1.5',
                                suffixText: '×',
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
                                    'Estimate possible overtime deduction',
                                  ),
                                  subtitle: const Text(
                                    'Only the extra premium may qualify under federal rules. This is an estimate.',
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
                          title: 'Tax details',
                          subtitle:
                              'Choose your filing status and state. W-4 details are optional.',
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
                                  title: const Text('Optional W-4 details'),
                                  subtitle: const Text(
                                    'Use the amounts from your current W-4.',
                                  ),
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'I have multiple jobs (Step 2)',
                                      ),
                                      subtitle: const Text(
                                        'Checking this may increase federal withholding.',
                                      ),
                                      value: step2Checked,
                                      onChanged: (value) => setState(() {
                                        step2Checked = value;
                                        taxResult = null;
                                      }),
                                    ),
                                    _TaxAmountField(
                                      controller: step3Controller,
                                      label: 'Tax credits per year (Step 3)',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: step4aController,
                                      label:
                                          'Other income per year (Step 4(a))',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: step4bController,
                                      label: 'Deductions per year (Step 4(b))',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    if (qualifiedOvertimeSelected) ...[
                                      _TaxAmountField(
                                        controller:
                                            qualifiedOvertimeMagiController,
                                        label:
                                            'Estimated income for 2026 overtime limit',
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
                                      label:
                                          'Extra withholding per paycheck (Step 4(c))',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    const SizedBox(height: 8),
                                    _TaxAmountField(
                                      controller: socialSecurityYtdController,
                                      label: 'Social Security wages this year',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    _TaxAmountField(
                                      controller: medicareYtdController,
                                      label: 'Medicare wages this year',
                                      onChanged: (_) => clearTaxResult(),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'Enter wages from this employer so far this year. Leave blank if you are starting a new job. Pre-tax deductions are not included.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _TaxAmountField(
                                controller: otherDeductionsController,
                                label:
                                    'Other after-tax deductions per paycheck',
                                onChanged: (_) => clearTaxResult(),
                              ),
                              const SizedBox(height: 10),
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
                                  selectedState = value ?? tax.StateCode.texas;
                                  taxResult = null;
                                }),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  selectedState == tax.StateCode.texas
                                      ? 'Texas has no individual state income tax.'
                                      : selectedState ==
                                            tax.StateCode.notSelected
                                      ? 'Choose a state to include state withholding.'
                                      : 'State withholding is currently supported for Texas only. Other state taxes are not included.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
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
                        if (taxInputError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Check your entries. ${taxInputError!}',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        if (result == null && taxInputError == null) ...[
                          const SizedBox(height: 20),
                          _SectionCard(
                            title: 'Your estimate will appear here',
                            subtitle:
                                'Enter your hourly rate and typical weekly hours, then calculate your paycheck.',
                            child: const SizedBox.shrink(),
                          ),
                        ],
                        if (result != null) ...[
                          const SizedBox(height: 20),
                          _SectionCard(
                            title: 'Pay breakdown',
                            subtitle:
                                '${result!.payPeriod.label} paycheck based on your weekly schedule',
                            child: Column(
                              children: [
                                _BreakdownRow(
                                  label:
                                      'Regular pay (${result!.regularHours.toStringAsFixed(2)} hrs)',
                                  value: result!.regularPay,
                                  colorScheme: colorScheme,
                                ),
                                _BreakdownRow(
                                  label:
                                      'Overtime pay (${result!.overtimeHours.toStringAsFixed(2)} hrs)',
                                  value: result!.overtimePay,
                                  colorScheme: colorScheme,
                                ),
                                const Divider(height: 24),
                                _GrossPaySummaryRow(
                                  amount: result!.grossPay,
                                  colorScheme: colorScheme,
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (taxResult != null) ...[
                          const SizedBox(height: 20),
                          _SectionCard(
                            title: 'Your estimated paycheck',
                            subtitle:
                                'Take-home estimate after taxes and deductions.',
                            child: Column(
                              children: [
                                _TakeHomeHero(
                                  amountCents:
                                      taxResult!.estimatedTakeHomePayCents,
                                ),
                                const SizedBox(height: 17),
                                _TaxResultRow(
                                  label: 'Gross pay',
                                  cents: taxResult!.grossPayCents,
                                ),
                                if (qualifiedOvertimeSelected) ...[
                                  _TaxResultRow(
                                    label:
                                        'Potential overtime premium this check',
                                    cents: taxResult!
                                        .qualifiedOvertime
                                        .potentialQualifiedOvertimePerPaycheckCents,
                                  ),
                                  _TaxResultRow(
                                    label:
                                        'Estimated overtime deduction this year',
                                    cents: taxResult!
                                        .qualifiedOvertime
                                        .annualDeductionCents,
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Only overtime that meets federal rules may count. This estimate can lower federal income-tax withholding, but does not lower Social Security or Medicare.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                _TaxResultRow(
                                  label: 'Federal income tax',
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
                                if (taxResult!.additionalMedicareCents > 0)
                                  _TaxResultRow(
                                    label: 'Additional Medicare',
                                    cents: taxResult!.additionalMedicareCents,
                                  ),
                                _TaxResultRow(
                                  label: 'State income tax',
                                  cents: taxResult!.stateIncomeTaxCents,
                                  suffix: switch (taxResult!.stateStatus) {
                                    StateTaxSupportStatus.supported => null,
                                    StateTaxSupportStatus.unsupported =>
                                      'Not supported',
                                    StateTaxSupportStatus.notSelected =>
                                      'Select a state',
                                  },
                                ),
                                if (taxResult!.otherDeductionsCents > 0)
                                  _TaxResultRow(
                                    label: 'Other after-tax deductions',
                                    cents: taxResult!.otherDeductionsCents,
                                  ),
                                const Divider(height: 20),
                                _TaxResultRow(
                                  label: 'Total taxes and deductions',
                                  cents: taxResult!.totalWithholdingCents,
                                  bold: true,
                                ),
                                const SizedBox(height: 5),
                                if (taxResult!.warnings.isNotEmpty)
                                  Material(
                                    color: Colors.transparent,
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      title: const Text(
                                        'How we estimated this',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      children:
                                          _estimateExplanationMessages(
                                                selectedState,
                                                qualifiedOvertimeSelected,
                                              )
                                              .map(
                                                (warning) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      '• $warning',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
              height: 1.1,
            ),
            children: [
              TextSpan(
                text: 'Hassel ',
                style: TextStyle(color: Color(0xFFE5E7EB)),
              ),
              TextSpan(
                text: 'Pay',
                style: TextStyle(color: Color(0xFF22CC5E)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PAYCHECK & TAKE-HOME CALCULATOR',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.05,
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
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
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(color: colorScheme.outlineVariant),
              labelStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            ActionChip(
              label: const Text('40 + 10 OT'),
              onPressed: () =>
                  onSelect(regularHours: '40', overtimeHours: '10'),
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(color: colorScheme.outlineVariant),
              labelStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            ActionChip(
              label: const Text('40 + 20 OT'),
              onPressed: () =>
                  onSelect(regularHours: '40', overtimeHours: '20'),
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(color: colorScheme.outlineVariant),
              labelStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
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
    final focusColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.primary
        : const Color(0xFF13863F);

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
          borderSide: BorderSide(color: focusColor, width: 1.6),
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
    final focusColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.primary
        : const Color(0xFF13863F);

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
          borderSide: BorderSide(color: focusColor, width: 1.6),
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
    this.suffixText,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;
  final String? suffixText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = Theme.of(context).brightness == Brightness.dark
        ? colorScheme.primary
        : const Color(0xFF13863F);
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.error, width: 1.6),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
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
          borderSide: BorderSide(color: focusColor, width: 1.6),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '\$${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
  );
}

class _TakeHomeHero extends StatelessWidget {
  const _TakeHomeHero({required this.amountCents});

  final int? amountCents;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.primary.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTIMATED TAKE-HOME',
            style: TextStyle(
              color: isDark ? colors.primary : colors.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          if (amountCents == null)
            Text(
              'Take-home is unavailable because state tax rules are not supported for this state.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '\$${(amountCents! / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.15,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
