import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'new_trip.dart';
import 'database.dart';
import 'main.dart';
import 'trip_screen.dart';
import 'download_manager.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Image.asset(
          'assets/icon/icon.png',
          height: 32,
          alignment: Alignment.centerLeft,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor, size: 24),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: textColor, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewTripScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: DownloadManager.instance,
              builder: (context, _) {
                final dm = DownloadManager.instance;
                if (!dm.isDownloading) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: textColor.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.download, color: textColor.withOpacity(0.5), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Downloading map for ${dm.currentCity}...',
                              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
                            ),
                          ),
                          Text(
                            '${(dm.progress * 100).toInt()}%',
                            style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: dm.progress,
                        backgroundColor: textColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(textColor.withOpacity(0.4)),
                      ),
                    ],
                  ),
                );
              },
            ),
            Text('Your Trips',
                style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 14,
                    letterSpacing: 1.2)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<Trip>>(
                stream: database.watchAllTrips(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: textColor.withOpacity(0.3)));
                  }
                  final trips = snapshot.data ?? [];
                  if (trips.isEmpty) {
                    return _EmptyStateHint(textColor: textColor);
                  }
                  return ListView.separated(
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final trip = trips[i];
                      final statusColor = _statusColor(trip.status);
                      final dates = _formatDates(trip.departureDate, trip.returnDate);
                      return _TripCard(
                        trip: trip,
                        dates: dates,
                        statusColor: statusColor,
                        onDelete: () => database.deleteTrip(trip.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TripScreen(trip: trip)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active': return Colors.greenAccent;
      case 'Planned': return const Color(0xFFFFCC00);
      case 'Completed': return Colors.white38;
      default: return Colors.white38;
    }
  }

  String _formatDates(DateTime? departure, DateTime? returnDate) {
    if (departure == null) return 'Dates not set';
    final dep = '${departure.day}.${departure.month}';
    if (returnDate == null) return 'From $dep';
    final ret = '${returnDate.day}.${returnDate.month}';
    return '$dep — $ret';
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final String dates;
  final Color statusColor;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.dates,
    required this.statusColor,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Dismissible(
      key: Key('${trip.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name ?? trip.city,
                        style: TextStyle(
                            color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (trip.country != null)
                      Text(trip.country!,
                          style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(dates,
                        style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(trip.status,
                    style: TextStyle(
                        color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateHint extends StatefulWidget {
  final Color textColor;
  const _EmptyStateHint({required this.textColor});

  @override
  State<_EmptyStateHint> createState() => _EmptyStateHintState();
}

class _EmptyStateHintState extends State<_EmptyStateHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.textColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flight_takeoff, size: 64, color: textColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No trips yet',
              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 18)),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _bounce.value),
              child: child,
            ),
            child: Transform.rotate(
              angle: pi / 4,
              child: Icon(Icons.arrow_upward,
                  size: 28, color: textColor.withOpacity(0.35)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Create your first trip',
              style: TextStyle(color: textColor.withOpacity(0.25), fontSize: 14)),
        ],
      ),
    );
  }
}