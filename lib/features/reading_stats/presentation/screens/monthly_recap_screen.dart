import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/image_export_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/monthly_recap.dart';
import '../providers/monthly_recap_provider.dart';
import '../widgets/monthly_recap_card.dart';

class MonthlyRecapScreen extends ConsumerStatefulWidget {
  final RecapMonth month;
  const MonthlyRecapScreen({required this.month, super.key});

  @override
  ConsumerState<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends ConsumerState<MonthlyRecapScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(monthlyRecapProvider(widget.month));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(l10n.recapTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (recap) => recap.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.recapEmptyMonth,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _RecapPreview(
                recap: recap,
                boundaryKey: _boundaryKey,
                sharing: _sharing,
                onShare: () => _onShare(recap),
              ),
      ),
    );
  }

  Future<void> _onShare(MonthlyRecap recap) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context)!;
    final monthName =
        DateFormat.MMMM(l10n.localeName).format(DateTime(recap.year, recap.month));
    try {
      await shareWidgetAsPng(
        boundaryKey: _boundaryKey,
        filename: 'rsvp-recap-${recap.year}-${recap.month.toString().padLeft(2, '0')}',
        shareText: l10n.recapShareText(monthName),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _RecapPreview extends StatelessWidget {
  final MonthlyRecap recap;
  final GlobalKey boundaryKey;
  final bool sharing;
  final VoidCallback onShare;
  const _RecapPreview({
    required this.recap,
    required this.boundaryKey,
    required this.sharing,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: MonthlyRecapCard(recap: recap),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: sharing ? null : onShare,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.recapShareCta),
            ),
          ],
        ),
      ),
    );
  }
}

