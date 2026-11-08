#!/usr/bin/env python3
"""1.0.16 driver refactor: DriverHome -> 5-tab bottom-nav shell.
Jobs / My Runs / Earning / Chat / Profile, per the prototype the user is
looking at. Run from ~/workspace/wasl-app."""
import re

p = 'lib/screens/driver_home.dart'
src = open(p).read()

# --- Locate the old DriverHome class span ---
cls = src.index('class DriverHome extends StatelessWidget {')
end_marker = '\nvoid _showError('
class_end = src.index(end_marker, cls)
old_class = src[cls:class_end]

new_code = '''Color _driverStatusColor(DeliveryStatus s) => switch (s) {
      DeliveryStatus.offered => Colors.blueGrey,
      DeliveryStatus.assigned => WaslTheme.marketplaceBlue,
      DeliveryStatus.accepted => WaslTheme.teal,
      DeliveryStatus.pickedUp => WaslTheme.teal,
      DeliveryStatus.delivering => WaslTheme.amber,
      DeliveryStatus.delivered => WaslTheme.okGreen,
      DeliveryStatus.cancelled => WaslTheme.danger,
    };

/// Driver home: bottom nav with Jobs / My Runs / Earning / Chat / Profile,
/// as in the high-fidelity prototype. The driver-record gate (setup screen
/// when no record, pending banner until the admin approves) and the
/// trip-only location reporter live here in the shell, above the tabs.
class DriverHome extends StatefulWidget {
  final AppUser profile;
  final AuthService auth;

  const DriverHome({super.key, required this.profile, required this.auth});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      // No driver record yet → one-time setup (S4 needs the record to
      // exist before a store can pick this driver). The record is created
      // as pending; the admin approves it.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DriverService().myDriverDocStream(profile.uid),
        builder: (context, docSnapshot) {
          if (docSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(
                    message: 'Could not load your driver profile.'),
              ),
            );
          }
          if (!docSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = docSnapshot.data!.docs;
          if (docs.isEmpty) {
            return DriverSetupScreen(profile: profile);
          }
          final pending =
              (docs.first.data()['verificationStatus'] ?? '') != 'approved';
          return Column(
            children: [
              // Trip-only location sharing: on while an active job exists,
              // off otherwise. Invisible — it only reports the position.
              _LocationReporter(
                driverDocId: docs.first.id,
                profileUid: profile.uid,
              ),
              if (pending)
                Container(
                  width: double.infinity,
                  color: WaslTheme.amber.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'Your driver profile is waiting for admin approval — stores can\\'t assign you directly until then, but you can still take marketplace offers.',
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _DriverJobsTab(
                        profile: profile, auth: widget.auth),
                    _DriverRunsTab(profile: profile),
                    _DriverEarningsTab(profile: profile),
                    _DriverChatsTab(profile: profile),
                    DriverProfileScreen(profile: profile),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: WaslTheme.teal,
        unselectedItemColor: Colors.black54,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline), label: 'Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.route), label: 'My Runs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Earning'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Jobs tab (D1): the active job on top, then the open job board.
class _DriverJobsTab extends StatelessWidget {
  final AppUser profile;
  final AuthService auth;

  const _DriverJobsTab({required this.profile, required this.auth});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(
        leading: const WaslAppBarLogo(),
        title: Text('Wasl — ${profile.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    JobMapScreen(profile: profile, service: service),
              ),
            ),
            tooltip: 'Job map',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, mySnapshot) {
          return StreamBuilder<List<Delivery>>(
            stream: service.driverBoardStream(profile.uid),
            builder: (context, boardSnapshot) {
              if (boardSnapshot.hasError || mySnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: ErrorBanner(
                        message: 'Could not load jobs — check connection.'),
                  ),
                );
              }
              if (!boardSnapshot.hasData || !mySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final board = boardSnapshot.data!;
              final mine = mySnapshot.data!;
              final active = mine.where((d) =>
                  d.status == DeliveryStatus.accepted ||
                  d.status == DeliveryStatus.pickedUp ||
                  d.status == DeliveryStatus.delivering).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isNotEmpty) ...[
                    const Text('Active job',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...active.map((d) => _JobCard(
                          delivery: d,
                          profile: profile,
                          service: service,
                          color: _driverStatusColor(d.status),
                        )),
                    const SizedBox(height: 16),
                  ],
                  const Text('Job board',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (board.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No open jobs right now.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...board.map((d) => _JobCard(
                        delivery: d,
                        profile: profile,
                        service: service,
                        color: _driverStatusColor(d.status),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// My Runs tab (D6/D7): batched run offers and the active run, plus the
/// driver's past deliveries.
class _DriverRunsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverRunsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Runs')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, mySnapshot) {
          if (mySnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load runs.'),
              ),
            );
          }
          if (!mySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = mySnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Batched runs',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              StreamBuilder<List<Run>>(
                stream: RunService().driverRunsStream(profile.uid),
                builder: (context, runsSnapshot) {
                  if (runsSnapshot.hasError) {
                    return ErrorBanner(
                        message:
                            'Could not load runs: ${runsSnapshot.error}');
                  }
                  if (!runsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final runs = runsSnapshot.data!;
                  if (runs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No batch offers right now.',
                          style: TextStyle(color: Colors.black54)),
                    );
                  }
                  return Column(
                    children: runs
                        .map((r) => _RunCard(
                            run: r, profile: profile, service: service))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('My deliveries',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...mine
                  .where((d) =>
                      d.status == DeliveryStatus.delivered ||
                      d.status == DeliveryStatus.cancelled)
                  .map((d) => Card(
                        child: ListTile(
                          title:
                              Text('#${d.orderNumber} — ${d.storeName}'),
                          subtitle: Text(
                              '${d.items} • ${d.money(d.orderTotal)}'),
                          trailing: StatusChip(
                              label: d.status.label,
                              color: _driverStatusColor(d.status)),
                        ),
                      )),
            ],
          );
        },
      ),
    );
  }
}

/// Earning tab (D5): what the store owes the driver, cash still to return
/// to the store, and tips kept — plus every delivered order behind it.
class _DriverEarningsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverEarningsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Earning')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load earnings.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final delivered = snapshot.data!
              .where((d) => d.status == DeliveryStatus.delivered)
              .toList();
          final payOwed =
              delivered.fold<double>(0, (s, d) => s + d.fee);
          final cashOwed =
              delivered.fold<double>(0, (s, d) => s + d.cashOwed);
          final tips =
              delivered.fold<double>(0, (s, d) => s + d.tipKept);
          final currency =
              delivered.isEmpty ? 'USD' : delivered.first.currency;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: WaslTheme.teal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My earnings',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text(
                        'Pay owed $currency ${payOwed.toStringAsFixed(2)}  •  Cash to return ${cashOwed.toStringAsFixed(2)}  •  Tips kept ${tips.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Text(
                        'You return all cash to the store and keep the tip. The store pays your fee in cash.',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (delivered.isEmpty)
                const Text('No delivered orders yet.',
                    style: TextStyle(color: Colors.black54)),
              ...delivered.map((d) => Card(
                    child: ListTile(
                      title: Text('#${d.orderNumber} — ${d.storeName}'),
                      subtitle: Text(
                          '${d.items} • fee ${d.money(d.fee)} • tip ${d.money(d.tipKept)} • cash to return ${d.money(d.cashOwed)}${d.driverPaid ? ' • paid' : ' • not paid yet'}'),
                      trailing: StatusChip(
                          label: d.status.label,
                          color: _driverStatusColor(d.status)),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

/// Chat tab (D8): one conversation per delivery, with the store.
/// Only deliveries the driver has or had — nothing else.
class _DriverChatsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverChatsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load chats.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = snapshot.data!;
          if (mine.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No deliveries yet — your chats with stores will show here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: mine
                .map((d) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                            '#${d.orderNumber} — ${d.storeName}'),
                        subtitle: Text(
                            '${d.items} • ${d.status.label}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatScreen(delivery: d, profile: profile),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

'''

new_src = src[:cls] + new_code + src[class_end:]
open(p, 'w').write(new_src)
print('driver shell written')
print('DriverHome classes:', new_src.count('class DriverHome'), new_src.count('class _DriverHomeState'))
print('tabs:', new_src.count('_DriverJobsTab'), new_src.count('_DriverRunsTab'), new_src.count('_DriverEarningsTab'), new_src.count('_DriverChatsTab'))
print('old _statusColor method gone:', 'Color _statusColor(' not in new_src)
