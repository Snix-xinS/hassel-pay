import 'package:flutter/material.dart';

const privacyPolicyContact = 'hasselpayapp@gmail.com';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Hassel Pay Privacy Policy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Effective date: October 3, 2026',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                const _PolicySection(
                  title: 'Information the app processes',
                  body:
                      'When you use the calculator, Hassel Pay processes the pay and tax details you enter, such as hourly rate, hours, pay period, filing status, W-4 amounts, state, year-to-date wages, and deductions. These details may be sensitive financial information. They are used only to calculate the gross pay, estimated withholding, and take-home amount shown in the app.',
                ),
                const _PolicySection(
                  title: 'Local processing and transmission',
                  body:
                      'Calculations are performed locally on your device. Hassel Pay does not transmit paycheck or tax inputs, or calculated results, to a Hassel Pay server or another party. The app has no user account and no cloud synchronization.',
                ),
                const _PolicySection(
                  title: 'Sharing and third-party services',
                  body:
                      'Hassel Pay does not sell or share user-entered paycheck information with third parties. The app does not include analytics, advertising, tracking, or crash-reporting SDKs.',
                ),
                const _PolicySection(
                  title: 'Retention and deletion',
                  body:
                      'Calculator inputs and results are held temporarily while you use the app. Hassel Pay does not save them to a database, file, or account, and has no server-side account or data system that retains user data. There is no server-side user data to request deletion of.',
                ),
                const _PolicySection(
                  title: 'Device permissions',
                  body:
                      'Hassel Pay does not request or use location, contacts, camera, microphone, SMS, or phone access. The release app manifest contains no sensitive or runtime permissions. Android includes an internal signature-level permission for library components; it does not grant access to those personal data categories.',
                ),
                const _PolicySection(
                  title: "Children's privacy",
                  body:
                      'Hassel Pay is a general paycheck calculator and is not designed for children under 13. The app does not knowingly collect personal information from children. Calculator inputs are processed locally and are not transmitted to Hassel Pay.',
                ),
                const _PolicySection(
                  title: 'Security',
                  body:
                      'The app processes calculator values locally and does not maintain a server copy. Keep your device and its access credentials protected. No method of using a device can be guaranteed completely secure.',
                ),
                const _PolicySection(
                  title: 'Calculator estimates',
                  body:
                      'Hassel Pay provides paycheck and tax withholding estimates for informational purposes. An estimate is not a guarantee of the amount on an employer paycheck and is not professional tax or financial advice.',
                ),
                const _PolicySection(
                  title: 'Changes to this policy',
                  body:
                      'If this policy changes, the updated policy will be made available in the app and its effective date will be revised.',
                ),
                const _PolicySection(
                  title: 'Contact',
                  body: privacyPolicyContact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
