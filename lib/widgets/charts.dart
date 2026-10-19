import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';

class Series {
  final String label;
  final Color color;
  final List<int> paise;
  const Series(this.label, this.color, this.paise);
}

Widget _legend(List<(String, Color)> items) => Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final (l, c) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );

String _short(double v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 10000000) return '$s${(a / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000) return '$s${(a / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '$s${(a / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)}k';
  return '$s${a.toStringAsFixed(0)}';
}

/// Bar chart (optionally stacked) with an optional line overlay.
class BarsChart extends StatelessWidget {
  final List<String> labels;
  final List<Series> bars;
  final Series? line;
  final bool stacked;
  final double height;
  const BarsChart({
    super.key,
    required this.labels,
    required this.bars,
    this.line,
    this.stacked = true,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    double maxY = 0, minY = 0;
    for (var i = 0; i < n; i++) {
      var pos = 0.0, neg = 0.0;
      for (final s in bars) {
        final v = rupees(s.paise[i]);
        if (stacked) {
          if (v >= 0) {
            pos += v;
          } else {
            neg += v;
          }
        } else {
          if (v > maxY) maxY = v;
          if (v < minY) minY = v;
        }
      }
      if (stacked) {
        if (pos > maxY) maxY = pos;
        if (neg < minY) minY = neg;
      }
      if (line != null) {
        final v = rupees(line!.paise[i]);
        if (v > maxY) maxY = v;
        if (v < minY) minY = v;
      }
    }
    if (maxY == 0 && minY == 0) maxY = 100;
    final width = (n * (stacked ? 46.0 : 24.0 * bars.length + 20)).clamp(300.0, 4000.0);

    final groups = [
      for (var i = 0; i < n; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 3,
          barRods: [
            if (stacked)
              BarChartRodData(
                toY: bars.fold<double>(0, (s, b) => s + (rupees(b.paise[i]) > 0 ? rupees(b.paise[i]) : 0)),
                width: 22,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: () {
                  var from = 0.0;
                  return [
                    for (final b in bars)
                      () {
                        final v = rupees(b.paise[i]).clamp(0, double.infinity).toDouble();
                        final item = BarChartRodStackItem(from, from + v, b.color);
                        from += v;
                        return item;
                      }()
                  ];
                }(),
              )
            else
              for (final b in bars)
                BarChartRodData(
                  toY: rupees(b.paise[i]),
                  color: b.color,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
          ],
        ),
    ];

    final chart = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          BarChart(
            BarChartData(
              maxY: maxY * 1.12,
              minY: minY * 1.12,
              barGroups: groups,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (v, m) => Text(
                      '₹${_short(v)}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= n || v != i.toDouble()) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (g, gi, rod, ri) {
                    final idx = g.x.toInt();
                    final title = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                    if (stacked && bars.length > 1) {
                      var totalPaise = 0;
                      final spans = <TextSpan>[];
                      for (final b in bars) {
                        if (idx >= 0 && idx < b.paise.length) {
                          final p = b.paise[idx];
                          totalPaise += p;
                          if (p > 0) {
                            spans.add(
                              TextSpan(
                                text: '\n${b.label}: ${inr(p)}',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                        }
                      }
                      spans.add(
                        TextSpan(
                          text: '\nTotal: ${inr(totalPaise)}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                      return BarTooltipItem(
                        title,
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        children: spans,
                      );
                    } else {
                      final valPaise = stacked
                          ? (bars.isNotEmpty && idx >= 0 && idx < bars.first.paise.length
                              ? bars.fold<int>(0, (s, b) => s + (idx < b.paise.length ? b.paise[idx] : 0))
                              : (rod.toY * 100).round())
                          : (ri >= 0 && ri < bars.length && idx >= 0 && idx < bars[ri].paise.length
                              ? bars[ri].paise[idx]
                              : (rod.toY * 100).round());
                      return BarTooltipItem(
                        title,
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: '\n${inr(valPaise)}',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          if (line != null)
            IgnorePointer(
              child: LineChart(
                LineChartData(
                  minX: -0.5,
                  maxX: n - 0.5,
                  maxY: maxY * 1.12,
                  minY: minY * 1.12,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), rupees(line!.paise[i]))],
                      color: line!.color,
                      barWidth: 2.5,
                      isCurved: false,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (s, p, l, i) => FlDotCirclePainter(
                          radius: 3.5,
                          color: line!.color,
                          strokeColor: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legend([for (final b in bars) (b.label, b.color), if (line != null) (line!.label, line!.color)]),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart),
      ],
    );
  }
}

class DoughnutChart extends StatelessWidget {
  final List<String> labels;
  final List<int> paise;
  final List<Color> colors;
  final double height;
  const DoughnutChart({
    super.key,
    required this.labels,
    required this.paise,
    required this.colors,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final total = paise.fold<int>(0, (s, v) => s + v);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: height / 4,
              sectionsSpace: 3,
              sections: [
                for (var i = 0; i < labels.length; i++)
                  PieChartSectionData(
                    value: rupees(paise[i]),
                    color: colors[i % colors.length],
                    radius: height / 4.2,
                    title: total == 0 ? '' : '${(paise[i] * 100 / total).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _legend([for (var i = 0; i < labels.length; i++) ('${labels[i]} · ${inr(paise[i])}', colors[i % colors.length])]),
      ],
    );
  }
}
