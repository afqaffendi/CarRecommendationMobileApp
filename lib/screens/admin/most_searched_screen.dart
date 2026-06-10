import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/search_log_service.dart';
import '../../theme/app_theme.dart';

class MostSearchedScreen extends StatefulWidget {
  const MostSearchedScreen({super.key});

  @override
  State<MostSearchedScreen> createState() => _MostSearchedScreenState();
}

class _MostSearchedScreenState extends State<MostSearchedScreen> {
  List<Map<String, dynamic>> _cars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await SearchLogService.getTopSearchedCars(limit: 20);
    if (mounted) setState(() { _cars = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppTheme.textPrimary),
                onPressed: _load,
              ),
            ],
            title: const Text('Most Searched Cars',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3)),
            centerTitle: true,
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent)),
            )
          else if (_cars.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          size: 40, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 20),
                    const Text('No data yet',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Stats appear once users run searches',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: _buildTopThree(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i < 3) return const SizedBox.shrink();
                    return _buildRankRow(_cars[i], i)
                        .animate()
                        .fadeIn(delay: (i * 40).ms, duration: 300.ms)
                        .slideX(begin: 0.05, end: 0, duration: 300.ms);
                  },
                  childCount: _cars.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    final top = _cars.take(3).toList();
    final maxCount = (top.first['count'] as num).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Picks',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (top.length > 1)
              Expanded(child: _buildPodium(top[1], 2, maxCount, 90)),
            const SizedBox(width: 8),
            if (top.isNotEmpty)
              Expanded(child: _buildPodium(top[0], 1, maxCount, 110)),
            const SizedBox(width: 8),
            if (top.length > 2)
              Expanded(child: _buildPodium(top[2], 3, maxCount, 75)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPodium(Map<String, dynamic> car, int rank, double max, double height) {
    final colors = {
      1: AppTheme.accent,
      2: AppTheme.accentBlue,
      3: const Color(0xFF7C6AF7),
    };
    final color = colors[rank]!;
    final count = (car['count'] as num).toInt();

    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 4),
        Text(
          car['displayName'] as String? ?? '',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.2),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Center(
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(Map<String, dynamic> car, int index) {
    final count = (car['count'] as num).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car['displayName'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2),
                ),
                Text(
                  (car['type'] as String? ?? '').toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count searches',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
