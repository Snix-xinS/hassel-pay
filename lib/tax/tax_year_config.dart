import 'payroll_inputs.dart';

/// One row in a Pub. 15-T annual Percentage Method table.
///
/// The interval is [lowerBoundaryDollars, upperBoundaryDollars); a null upper
/// boundary denotes the final open-ended row. The base amount is stored in
/// cents, the rate as an integer percent, and excessOverDollars is column E.
class PercentageMethodRow {
  const PercentageMethodRow(
    this.lowerBoundaryDollars,
    this.upperBoundaryDollars,
    this.baseAmountCents,
    this.ratePercent,
    this.excessOverDollars,
  );

  final int lowerBoundaryDollars;
  final int? upperBoundaryDollars;
  final int baseAmountCents;
  final int ratePercent;
  final int excessOverDollars;

  bool containsAdjustedWages(int cents) {
    final lower = lowerBoundaryDollars * 100;
    final upper = upperBoundaryDollars;
    return cents >= lower && (upper == null || cents < upper * 100);
  }
}

/// IRS Pub. 15-T (2026), Worksheet 1A constants and annual tables.
///
/// The source is the 2026 Percentage Method Tables for Automated Payroll
/// Systems, section 1. Keep future tax years in separate configurations.
class TaxYearConfig {
  const TaxYearConfig._({required this.taxYear});

  static const TaxYearConfig taxYear2026 = TaxYearConfig._(taxYear: 2026);

  final int taxYear;

  int get socialSecurityRateBasisPoints => 620;
  int get socialSecurityWageBaseCents => 18450000;
  int get medicareRateBasisPoints => 145;
  int get additionalMedicareRateBasisPoints => 90;
  int get additionalMedicareWithholdingThresholdCents => 20000000;
  int get qualifiedOvertimeIndividualLimitCents => 1250000;
  int get qualifiedOvertimeJointLimitCents => 2500000;
  int get qualifiedOvertimeIndividualMagiThresholdCents => 15000000;
  int get qualifiedOvertimeJointMagiThresholdCents => 30000000;
  int get qualifiedOvertimePhaseoutPerThousandCents => 10000;

  /// Calculates employee tax in cents, rounded half up to one cent.
  int withholdingCents(int taxableWagesCents, int rateBasisPoints) {
    return (taxableWagesCents * rateBasisPoints + 5000) ~/ 10000;
  }

  int get standardAdjustmentSingleOrMfsCents => 860000;
  int get standardAdjustmentMarriedFilingJointlyCents => 1290000;

  int standardAdjustmentCents(FederalFilingStatus filingStatus) {
    return switch (filingStatus) {
      FederalFilingStatus.marriedFilingJointly =>
        standardAdjustmentMarriedFilingJointlyCents,
      FederalFilingStatus.singleOrMarriedFilingSeparately ||
      FederalFilingStatus.headOfHousehold => standardAdjustmentSingleOrMfsCents,
    };
  }

  List<PercentageMethodRow> tableFor(
    FederalFilingStatus status, {
    required bool step2Checkbox,
  }) {
    return switch ((status, step2Checkbox)) {
      (FederalFilingStatus.marriedFilingJointly, false) => _mfjStandard,
      (FederalFilingStatus.marriedFilingJointly, true) => _mfjStep2,
      (FederalFilingStatus.singleOrMarriedFilingSeparately, false) =>
        _singleStandard,
      (FederalFilingStatus.singleOrMarriedFilingSeparately, true) =>
        _singleStep2,
      (FederalFilingStatus.headOfHousehold, false) => _hohStandard,
      (FederalFilingStatus.headOfHousehold, true) => _hohStep2,
    };
  }

  static const _mfjStandard = <PercentageMethodRow>[
    PercentageMethodRow(0, 19300, 0, 0, 0),
    PercentageMethodRow(19300, 44100, 0, 10, 19300),
    PercentageMethodRow(44100, 120100, 248000, 12, 44100),
    PercentageMethodRow(120100, 230700, 1160000, 22, 120100),
    PercentageMethodRow(230700, 422850, 3593200, 24, 230700),
    PercentageMethodRow(422850, 531750, 8204800, 32, 422850),
    PercentageMethodRow(531750, 788000, 11689600, 35, 531750),
    PercentageMethodRow(788000, null, 20658350, 37, 788000),
  ];

  static const _mfjStep2 = <PercentageMethodRow>[
    PercentageMethodRow(0, 16100, 0, 0, 0),
    PercentageMethodRow(16100, 28500, 0, 10, 16100),
    PercentageMethodRow(28500, 66500, 124000, 12, 28500),
    PercentageMethodRow(66500, 121800, 580000, 22, 66500),
    PercentageMethodRow(121800, 217875, 1796600, 24, 121800),
    PercentageMethodRow(217875, 272325, 4102400, 32, 217875),
    PercentageMethodRow(272325, 400450, 5844800, 35, 272325),
    PercentageMethodRow(400450, null, 10329175, 37, 400450),
  ];

  static const _singleStandard = <PercentageMethodRow>[
    PercentageMethodRow(0, 7500, 0, 0, 0),
    PercentageMethodRow(7500, 19900, 0, 10, 7500),
    PercentageMethodRow(19900, 57900, 124000, 12, 19900),
    PercentageMethodRow(57900, 113200, 580000, 22, 57900),
    PercentageMethodRow(113200, 209275, 1796600, 24, 113200),
    PercentageMethodRow(209275, 263725, 4102400, 32, 209275),
    PercentageMethodRow(263725, 648100, 5844800, 35, 263725),
    PercentageMethodRow(648100, null, 19297925, 37, 648100),
  ];

  static const _singleStep2 = <PercentageMethodRow>[
    PercentageMethodRow(0, 8050, 0, 0, 0),
    PercentageMethodRow(8050, 14250, 0, 10, 8050),
    PercentageMethodRow(14250, 33250, 62000, 12, 14250),
    PercentageMethodRow(33250, 60900, 290000, 22, 33250),
    PercentageMethodRow(60900, 108938, 898300, 24, 60900),
    PercentageMethodRow(108938, 136163, 2051200, 32, 108938),
    PercentageMethodRow(136163, 328350, 2922400, 35, 136163),
    PercentageMethodRow(328350, null, 9648963, 37, 328350),
  ];

  static const _hohStandard = <PercentageMethodRow>[
    PercentageMethodRow(0, 15550, 0, 0, 0),
    PercentageMethodRow(15550, 33250, 0, 10, 15550),
    PercentageMethodRow(33250, 83000, 177000, 12, 33250),
    PercentageMethodRow(83000, 121250, 774000, 22, 83000),
    PercentageMethodRow(121250, 217300, 1615500, 24, 121250),
    PercentageMethodRow(217300, 271750, 3920700, 32, 217300),
    PercentageMethodRow(271750, 656150, 5663100, 35, 271750),
    PercentageMethodRow(656150, null, 19117100, 37, 656150),
  ];

  static const _hohStep2 = <PercentageMethodRow>[
    PercentageMethodRow(0, 12075, 0, 0, 0),
    PercentageMethodRow(12075, 20925, 0, 10, 12075),
    PercentageMethodRow(20925, 45800, 88500, 12, 20925),
    PercentageMethodRow(45800, 64925, 387000, 22, 45800),
    PercentageMethodRow(64925, 112950, 807750, 24, 64925),
    PercentageMethodRow(112950, 140175, 1960350, 32, 112950),
    PercentageMethodRow(140175, 332375, 2831550, 35, 140175),
    PercentageMethodRow(332375, null, 9558550, 37, 332375),
  ];
}
