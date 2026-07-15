import 'package:flutter/material.dart';

enum BakerySpinnerSize { sm, md, lg }

/// Matches web `LoadingSpinner`: amber ring with lighter track.
class BakeryLoadingSpinner extends StatelessWidget {
  const BakeryLoadingSpinner({
    super.key,
    this.size = BakerySpinnerSize.md,
    this.label,
    this.fullPage = false,
    this.color = const Color(0xFFD97706),
    this.trackColor = const Color(0xFFFDE68A),
  });

  final BakerySpinnerSize size;
  final String? label;
  final bool fullPage;
  final Color color;
  final Color trackColor;

  double get _dimension {
    switch (size) {
      case BakerySpinnerSize.sm:
        return 20;
      case BakerySpinnerSize.md:
        return 32;
      case BakerySpinnerSize.lg:
        return 48;
    }
  }

  double get _stroke {
    switch (size) {
      case BakerySpinnerSize.sm:
        return 2;
      case BakerySpinnerSize.md:
        return 3;
      case BakerySpinnerSize.lg:
        return 3.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spinner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _dimension,
          height: _dimension,
          child: CircularProgressIndicator(
            strokeWidth: _stroke,
            color: color,
            backgroundColor: trackColor,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1C1917),
            ),
          ),
        ],
      ],
    );

    if (fullPage) {
      return SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * 0.4,
        child: Center(child: spinner),
      );
    }

    return spinner;
  }
}

/// Centered page/section loader (same look as web fullPage spinner).
class BakeryLoadingCenter extends StatelessWidget {
  const BakeryLoadingCenter({
    super.key,
    this.label,
    this.size = BakerySpinnerSize.md,
  });

  final String? label;
  final BakerySpinnerSize size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BakeryLoadingSpinner(
        size: size,
        label: label,
      ),
    );
  }
}
