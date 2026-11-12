import 'package:flutter/material.dart';
import 'package:scratch_card/scratch_card.dart';

void main() => runApp(const ScratchCardDemoApp());

class ScratchCardDemoApp extends StatelessWidget {
  const ScratchCardDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scratch card demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF7931E),
        scaffoldBackgroundColor: const Color(0xFFF6F4F1),
      ),
      home: const RewardsPage(),
    );
  }
}

/// A reward returned by the fake backend.
class Reward {
  const Reward(this.amount, this.description);

  final String amount;
  final String description;
}

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final ScratchCardController _firstCard = ScratchCardController();
  final List<String> _log = [];
  final ScrollController _logScroll = ScrollController();
  int _flakyAttempts = 0;

  @override
  void dispose() {
    _firstCard.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _record(String card, String event) {
    final now = TimeOfDay.now().format(context);
    setState(() => _log.add('$now  $card · $event'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  /// Wires every callback of a card into the event log.
  ScratchCard<T> _card<T>(
    String name, {
    ScratchCardController? controller,
    ScratchCardStyle style = const ScratchCardStyle(),
    WidgetBuilder? rewardChild,
    RewardWidgetBuilder<T>? rewardBuilder,
    Future<T> Function()? onFetchReward,
    bool isScratched = false,
    CelebrationType celebrationType = CelebrationType.confettiAndRays,
  }) {
    var lastLoggedProgress = -1;
    return ScratchCard<T>(
      controller: controller,
      style: style,
      rewardChild: rewardChild,
      rewardBuilder: rewardBuilder,
      onFetchReward: onFetchReward,
      isScratched: isScratched,
      celebrationType: celebrationType,
      onTap: () => _record(name, 'onTap'),
      onOpened: () => _record(name, 'onOpened'),
      onScratchStart: () => _record(name, 'onScratchStart'),
      onScratchProgress: (p) {
        // Log every 10% so the log stays readable.
        final step = (p * 10).floor();
        if (step != lastLoggedProgress) {
          lastLoggedProgress = step;
          _record(name, 'onScratchProgress ${(p * 100).round()}%');
        }
      },
      onThresholdReached: () => _record(name, 'onThresholdReached'),
      onRevealed: () => _record(name, 'onRevealed'),
      onCelebrationComplete: () => _record(name, 'onCelebrationComplete'),
      onClosed: () {
        lastLoggedProgress = -1;
        _record(name, 'onClosed');
      },
      onRewardError: (error, _) => _record(name, 'onRewardError: $error'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      // 1. Static reward.
      _card<Object?>(
        'Cashback',
        controller: _firstCard,
        rewardChild: (_) => const RewardView(
          icon: Icons.monetization_on_rounded,
          color: Color(0xFFF7A600),
          amount: '₹50',
          description: 'Cashback credited to your wallet',
        ),
      ),

      // 2. Async reward (1.5 s fake request).
      _card<Reward>(
        'Async',
        style: const ScratchCardStyle(title: 'Weekend reward'),
        onFetchReward: () => Future.delayed(
          const Duration(milliseconds: 1500),
          () => const Reward('₹100 OFF', 'on your next order above ₹499'),
        ),
        rewardBuilder: (context, reward) => RewardView(
          icon: Icons.local_offer_rounded,
          color: const Color(0xFFE65100),
          amount: reward.amount,
          description: reward.description,
        ),
      ),

      // 3. Fails the first time, succeeds on retry.
      _card<Reward>(
        'Flaky',
        style: const ScratchCardStyle(title: 'Mystery reward'),
        onFetchReward: () async {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          _flakyAttempts++;
          if (_flakyAttempts.isOdd) throw Exception('Network unavailable');
          return const Reward('Free delivery', 'for your next 3 orders');
        },
        rewardBuilder: (context, reward) => RewardView(
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFF2E7D32),
          amount: reward.amount,
          description: reward.description,
        ),
      ),

      // 4. Already scratched.
      _card<Object?>(
        'Claimed',
        isScratched: true,
        rewardChild: (_) => const RewardView(
          icon: Icons.percent_rounded,
          color: Color(0xFF6A1B9A),
          amount: '10% OFF',
          description: 'Already claimed',
        ),
      ),

      // 5. Custom purple/blue theme.
      _card<Object?>(
        'Purple',
        style: const ScratchCardStyle(
          title: 'Festive reward',
          icon: Icons.auto_awesome_rounded,
          gradientColors: [
            Color(0xFF8E7BFF),
            Color(0xFF5B5BEA),
            Color(0xFF3949AB),
          ],
          shadowColor: Color(0x593949AB),
        ),
        rewardChild: (_) => const RewardView(
          icon: Icons.stars_rounded,
          color: Color(0xFF3949AB),
          amount: '250 coins',
          description: 'Added to your rewards balance',
        ),
      ),

      // 6. No celebration.
      _card<Object?>(
        'Quiet',
        style: const ScratchCardStyle(title: 'Daily reward'),
        celebrationType: CelebrationType.none,
        rewardChild: (_) => const RewardView(
          icon: Icons.sentiment_satisfied_rounded,
          color: Color(0xFF546E7A),
          amount: 'Better luck',
          description: 'next time! Come back tomorrow.',
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My rewards'),
        actions: [
          TextButton.icon(
            onPressed: () => _firstCard.reveal(),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Reveal #1'),
          ),
          TextButton.icon(
            onPressed: () {
              _firstCard.reset();
              _record('Cashback', 'controller.reset()');
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset #1'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 180 / 170,
              children: cards,
            ),
          ),
          _EventLog(entries: _log, controller: _logScroll),
        ],
      ),
    );
  }
}

/// The reward shown under the cover.
class RewardView extends StatelessWidget {
  const RewardView({
    super.key,
    required this.icon,
    required this.color,
    required this.amount,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String amount;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 52, color: color),
          ),
          const SizedBox(height: 20),
          const Text(
            'You won',
            style: TextStyle(fontSize: 15, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
          ),
        ],
      ),
    );
  }
}

class _EventLog extends StatelessWidget {
  const _EventLog({required this.entries, required this.controller});

  final List<String> entries;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                'EVENT LOG',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Tap a card to start…',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => Text(
                        entries[i],
                        style: const TextStyle(
                          color: Color(0xFF9CDCFE),
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
