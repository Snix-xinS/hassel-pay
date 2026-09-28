import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class PaycheckCalculatorPage extends StatefulWidget {
  const PaycheckCalculatorPage({super.key});

  @override
  State<PaycheckCalculatorPage> createState() =>
      _PaycheckCalculatorPageState();
}

class _PaycheckCalculatorPageState extends State<PaycheckCalculatorPage> {
  final TextEditingController hourlyRateController = TextEditingController();
  final TextEditingController regularHoursController =
      TextEditingController();
  final TextEditingController overtimeHoursController =
      TextEditingController();
  final TextEditingController overtimeMultiplierController =
      TextEditingController(text: '1.5');

  double grossPay = 0;
  double regularPay = 0;
  double overtimePay = 0;

  void calculatePay() {
    final double hourlyRate =
        double.tryParse(hourlyRateController.text) ?? 0;

    final double regularHours =
        double.tryParse(regularHoursController.text) ?? 0;

    final double overtimeHours =
        double.tryParse(overtimeHoursController.text) ?? 0;

    final double overtimeMultiplier =
        double.tryParse(overtimeMultiplierController.text) ?? 1.5;

    final double regularPay = hourlyRate * regularHours;
    final double overtimePay =
        hourlyRate * overtimeMultiplier * overtimeHours;

    setState(() {
      this.regularPay = regularPay;
      this.overtimePay = overtimePay;
      grossPay = regularPay + overtimePay;
    });
  }

  void clearForm() {
    hourlyRateController.clear();
    regularHoursController.clear();
    overtimeHoursController.clear();
    overtimeMultiplierController.text = '1.5';

    setState(() {
      grossPay = 0;
      regularPay = 0;
      overtimePay = 0;
    });
  }

  @override
  void dispose() {
    hourlyRateController.dispose();
    regularHoursController.dispose();
    overtimeHoursController.dispose();
    overtimeMultiplierController.dispose();
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
              final maxContentWidth =
                  constraints.maxWidth > 560 ? 520.0 : constraints.maxWidth;

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
                        _GrossPayHero(amount: grossPay),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Hours & rate',
                          subtitle: 'Enter your pay details for this check',
                          child: Column(
                            children: [
                              _PayInputField(
                                controller: hourlyRateController,
                                label: 'Hourly Rate',
                                hint: '0.00',
                                prefixText: '\$ ',
                                icon: Icons.payments_outlined,
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: regularHoursController,
                                label: 'Regular Hours',
                                hint: '40',
                                icon: Icons.schedule_outlined,
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: overtimeHoursController,
                                label: 'Overtime Hours',
                                hint: '0',
                                icon: Icons.more_time_outlined,
                              ),
                              const SizedBox(height: 14),
                              _PayInputField(
                                controller: overtimeMultiplierController,
                                label: 'Overtime Multiplier',
                                hint: '1.5',
                                icon: Icons.trending_up_outlined,
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
                          subtitle: 'Regular, overtime, and total gross pay',
                          child: Column(
                            children: [
                              _BreakdownRow(
                                label: 'Regular Pay',
                                value: regularPay,
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 8),
                              _BreakdownRow(
                                label: 'Overtime Pay',
                                value: overtimePay,
                                colorScheme: colorScheme,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              _GrossPaySummaryRow(
                                amount: grossPay,
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ),
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
                'Calculate your gross pay',
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
  const _GrossPayHero({required this.amount});

  final double amount;

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
            'GROSS PAY',
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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

class _PayInputField extends StatelessWidget {
  const _PayInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefixText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, size: 22),
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
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onCalculate,
    required this.onClear,
  });

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrossPaySummaryRow extends StatelessWidget {
  const _GrossPaySummaryRow({
    required this.amount,
    required this.colorScheme,
  });

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
