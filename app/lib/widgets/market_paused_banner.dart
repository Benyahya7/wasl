import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/market_service.dart';
import '../theme.dart';

/// Shows when the admin paused this store's market: no new orders can
/// be created until the market is unpaused (storm / holiday / closure).
/// Hidden when the market is open or the store record is missing.
class MarketPausedBanner extends StatelessWidget {
  final String storeUid;

  const MarketPausedBanner({super.key, required this.storeUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('stores')
          .where('ownerUid', isEqualTo: storeUid)
          .limit(1)
          .get(),
      builder: (context, storeSnapshot) {
        if (!storeSnapshot.hasData || storeSnapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final marketId =
            (storeSnapshot.data!.docs.first.data()['market'] ?? '')
                .toString();
        if (marketId.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<bool>(
          stream: MarketService().marketPausedStream(marketId),
          builder: (context, snapshot) {
            if (snapshot.data != true) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WaslTheme.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'New orders are paused in your market right now — the admin paused it. You can still see your deliveries, but you cannot create new ones until it reopens.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          },
        );
      },
    );
  }
}
