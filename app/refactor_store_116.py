#!/usr/bin/env python3
"""1.0.16 store refactor: StoreHome -> 5-tab bottom-nav shell + _StoreDashboard.
Reads store_home.dart, extracts the S1 dashboard Scaffold, and rebuilds the
class. Run from ~/workspace/wasl-app. Prints verification counts."""
import re, sys

p = 'lib/screens/store_home.dart'
src = open(p).read()

# --- 1. Locate _StoreHomeState class span ---
cls = src.index('class _StoreHomeState extends State<StoreHome> {')
# class ends at the line '}' immediately before '/// S5 timeline'
s5 = src.index('/// S5 timeline')
class_end = src.rindex('\n}\n', 0, s5) + 3  # includes the closing '}\n'
old_class = src[cls:class_end]

# --- 2. Extract the Scaffold from the old build method ---
ret = old_class.index('    return Scaffold(')
# brace-count from the Scaffold's '(' to its matching close
depth = 0
i = old_class.index('(', ret)
j = i
while True:
    c = old_class[j]
    if c == '(':
        depth += 1
    elif c == ')':
        depth -= 1
        if depth == 0:
            break
    j += 1
scaffold = old_class[ret:j + 1]  # '    return Scaffold(...)' incl. closing ')'
# scaffold ends with ');' — the ';' is at j+1
assert old_class[j + 1] == ';', old_class[j + 1:j + 5]
scaffold = scaffold + ';'

# --- 3. Edit the extracted Scaffold into the dashboard version ---
def remove_block(text, start_marker):
    """Remove a widget block starting at start_marker (a line prefix), using brace counting."""
    s = text.index(start_marker)
    # find the opening '(' of the call
    paren = text.index('(', s)
    depth = 0
    k = paren
    while True:
        c = text[k]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                break
        k += 1
    # block ends at k (')') followed by ',' then newline; also swallow a
    # following 'const SizedBox(height: 8),' line if present
    end = k + 1
    if text[end] == ',':
        end += 1
    if text[end] == '\n':
        end += 1
    # swallow trailing SizedBox(height: 8) spacer line
    m = re.match(r'[ ]*const SizedBox\(height: 8\),\n', text[end:])
    if m:
        end += m.end()
    # also remove the leading indentation/newline of the block start line
    line_start = text.rindex('\n', 0, s) + 1
    return text[:line_start] + text[end:]

dash = scaffold
# drop the FAB
dash = remove_block(dash, '      floatingActionButton: FloatingActionButton.extended(')
# drop the profile IconButton in the app bar
dash = remove_block(dash, '          IconButton(\n            icon: const Icon(Icons.person),')
# drop My Drivers button (now a tab)
dash = remove_block(dash, "              OutlinedButton.icon(\n                onPressed: () => Navigator.push(\n                  context,\n                  MaterialPageRoute(\n                    builder: (_) => MyDriversScreen(profile: profile),")
# drop History & pay button (now a tab)
dash = remove_block(dash, "              OutlinedButton.icon(\n                onPressed: () => Navigator.push(\n                  context,\n                  MaterialPageRoute(\n                    builder: (_) => HistoryPayScreen(profile: profile),")
# field references (StatelessWidget: no `widget.`)
dash = dash.replace('widget.profile', 'profile')
dash = dash.replace('widget.auth', 'auth')
dash = dash.replace('_storeRecordError', 'storeRecordError')
dash = dash.replace('_statusColor(', 'statusColor(')
# the Scaffold text starts with '    return Scaffold('; re-indent base to 4 spaces is fine as-is

dashboard_class = '''/// S1 dashboard (Home tab): cash summary, Build a Run, live map,
/// runs and the deliveries list. The other tabs (New, My Drivers, Cash,
/// Profile) live in the bottom nav — this screen no longer links to them.
class _StoreDashboard extends StatelessWidget {
  final AppUser profile;
  final AuthService auth;
  final DeliveryService service;
  final String? storeRecordError;
  final Color Function(DeliveryStatus) statusColor;

  const _StoreDashboard({
    required this.profile,
    required this.auth,
    required this.service,
    required this.storeRecordError,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
''' + dash + '''
  }
}

'''

shell_class = '''class _StoreHomeState extends State<StoreHome> {
  String? _storeRecordError;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.auth.ensureStoreRecord(widget.profile).then((r) => r.fold(
          (_) {},
          (m) {
            if (mounted) setState(() => _storeRecordError = m);
          },
        ));
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.offered => Colors.blueGrey,
        DeliveryStatus.assigned => WaslTheme.marketplaceBlue,
        DeliveryStatus.accepted => WaslTheme.teal,
        DeliveryStatus.pickedUp => WaslTheme.teal,
        DeliveryStatus.delivering => WaslTheme.amber,
        DeliveryStatus.delivered => WaslTheme.okGreen,
        DeliveryStatus.cancelled => WaslTheme.danger,
      };

  void _onDeliveryCreated(Delivery d) {
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Delivery #${d.orderNumber} created — pickup code ${d.pickupCode} (on the order label).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    final profile = widget.profile;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _StoreDashboard(
            profile: profile,
            auth: widget.auth,
            service: service,
            storeRecordError: _storeRecordError,
            statusColor: _statusColor,
          ),
          NewDeliveryScreen(
            profile: profile,
            service: service,
            onCreated: _onDeliveryCreated,
          ),
          MyDriversScreen(profile: profile),
          HistoryPayScreen(profile: profile),
          StoreProfileScreen(profile: profile),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: WaslTheme.teal,
        unselectedItemColor: Colors.black54,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline), label: 'New'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'My Drivers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Cash'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

'''

new_src = src[:cls] + shell_class + dashboard_class + src[class_end:]
open(p, 'w').write(new_src)
print('shell+dashboard written')
print('FAB gone:', 'floatingActionButton' not in new_src)
print('StoreHome build count:', new_src.count('class _StoreHomeState'))
print('Dashboard count:', new_src.count('class _StoreDashboard'))
