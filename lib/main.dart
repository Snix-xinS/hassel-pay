import 'package:flutter/material.dart';

void main() {
  runApp(const PaycheckCalculatorApp());
}

class PaycheckCalculatorApp extends StatelessWidget {
  const PaycheckCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paycheck Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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
    return Scaffold(
appBar: AppBar(
  title: const Text(
    'Paycheck Calculator',
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
  centerTitle: true,
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Calculate Your Gross Pay',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: hourlyRateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Hourly Rate',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: regularHoursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Regular Hours',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: overtimeHoursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Overtime Hours',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: overtimeMultiplierController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Overtime Multiplier',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

        Row(
  children: [
    Expanded(
      child: FilledButton(
        onPressed: calculatePay,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Calculate Pay',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: OutlinedButton(
        onPressed: () {
          hourlyRateController.clear();
          regularHoursController.clear();
          overtimeHoursController.clear();
          overtimeMultiplierController.text = '1.5';

          setState(() {
  grossPay = 0;
  regularPay = 0;
  overtimePay = 0;
});
        },
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Clear',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    ),
  ],
),

            const SizedBox(height: 30),

Card(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        const Text(
          'Pay Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Regular Pay',
              style: TextStyle(fontSize: 17),
            ),
            Text(
              '\$${regularPay.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overtime Pay',
              style: TextStyle(fontSize: 17),
            ),
            Text(
              '\$${overtimePay.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Divider(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gross Pay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${grossPay.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),
          ],
        ),
      ),
    );
  }
}