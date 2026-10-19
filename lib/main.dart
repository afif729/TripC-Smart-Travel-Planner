import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

String currencySymbol(String currency) {
  switch (currency) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'AED':
      return 'د.إ';
    default:
      return '₹';
  }
}

String formatMoney(double amount, String currency) {
  return '${currencySymbol(currency)}${amount.toStringAsFixed(0)}';
}

Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  runApp(const TravelMate());
}

class Trip {
  String name;
  String destination;
  DateTime startDate;
  DateTime endDate;
  double budget;
  List<Expense> expenses;
  List<ItineraryItem> itinerary;
  List<Place> places;

  Trip({
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    List<Expense>? expenses,
    List<ItineraryItem>? itinerary,
    List<Place>? places,
  }) : expenses = expenses ?? [],
       itinerary = itinerary ?? [],
       places = places ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'budget': budget,
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'itinerary': itinerary.map((i) => i.toJson()).toList(),
      'places': places.map((p) => p.toJson()).toList(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      name: json['name'],
      destination: json['destination'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      budget: (json['budget'] as num).toDouble(),
      expenses: (json['expenses'] as List)
          .map((e) => Expense.fromJson(e))
          .toList(),
      itinerary: (json['itinerary'] as List)
          .map((i) => ItineraryItem.fromJson(i))
          .toList(),
      places: (json['places'] as List).map((p) => Place.fromJson(p)).toList(),
    );
  }
}

class Expense {
  String name;
  double amount;
  String category;
  DateTime date;
  String note;

  Expense({
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      date: DateTime.parse(json['date']),
      note: json['note'] ?? '',
    );
  }
}

class ItineraryItem {
  String place;
  String description;
  DateTime date;
  TimeOfDay time;
  double estimatedCost;

  ItineraryItem({
    required this.place,
    required this.description,
    required this.date,
    required this.time,
    required this.estimatedCost,
  });

  Map<String, dynamic> toJson() {
    return {
      'place': place,
      'description': description,
      'date': date.toIso8601String(),
      'hour': time.hour,
      'minute': time.minute,
      'estimatedCost': estimatedCost,
    };
  }

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      place: json['place'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
    );
  }
}

class Place {
  String name;
  String description;
  double estimatedCost;
  String priority;

  Place({
    required this.name,
    required this.description,
    required this.estimatedCost,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'estimatedCost': estimatedCost,
      'priority': priority,
    };
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'],
      description: json['description'],
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      priority: json['priority'],
    );
  }
}

class StorageService {
  static const String key = 'trips';

  static Future<void> saveTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();

    final data = trips.map((trip) => trip.toJson()).toList();

    await prefs.setString(key, jsonEncode(data));
  }

  static Future<List<Trip>> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(key);

    if (data == null) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(data);

    return jsonList.map((json) => Trip.fromJson(json)).toList();
  }

  static Future<void> saveTrip(Trip trip) async {
    final trips = await loadTrips();

    final index = trips.indexWhere(
      (t) =>
          t.name == trip.name &&
          t.destination == trip.destination &&
          t.startDate == trip.startDate &&
          t.endDate == trip.endDate,
    );

    if (index != -1) {
      trips[index] = trip;
    }

    await saveTrips(trips);
  }
}

class TravelMate extends StatefulWidget {
  const TravelMate({super.key});

  @override
  State<TravelMate> createState() => _TravelMateState();
}

class _TravelMateState extends State<TravelMate> {
  ThemeMode themeMode = ThemeMode.light;
  String currency = 'INR';
  Color accentColor = Colors.teal;
  String accentColorName = 'Teal';

  final Map<String, Color> accentColors = {
    'Teal': Colors.teal,
    'Blue': Colors.blue,
    'Purple': Colors.purple,
    'Pink': Colors.pink,
    'Orange': Colors.orange,
    'Red': Colors.red,
    'Green': Colors.green,
    'Indigo': Colors.indigo,
  };

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final dark = prefs.getBool('darkMode') ?? false;
    final savedCurrency = prefs.getString('currency') ?? 'INR';
    final savedAccent = prefs.getString('accentColor') ?? 'Teal';

    if (!mounted) return;

    setState(() {
      themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      currency = savedCurrency;
      accentColorName = savedAccent;
      accentColor = accentColors[savedAccent] ?? Colors.teal;
    });
  }

  Future<void> changeTheme(bool dark) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', dark);

    if (!mounted) return;

    setState(() {
      themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> changeCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('currency', value);

    if (!mounted) return;

    setState(() {
      currency = value;
    });
  }

  Future<void> changeAccentColor(String value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('accentColor', value);

    if (!mounted) return;

    setState(() {
      accentColorName = value;
      accentColor = accentColors[value] ?? Colors.teal;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101414)
          : const Color(0xFFF7F9F9),

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(width: 2, color: colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TripC',

      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,

      home: HomeScreen(
        onThemeChanged: changeTheme,
        currency: currency,
        onCurrencyChanged: changeCurrency,
        accentColorName: accentColorName,
        onAccentColorChanged: changeAccentColor,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final String currency;
  final Function(String) onCurrencyChanged;
  final String accentColorName;
  final Function(String) onAccentColorChanged;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.currency,
    required this.onCurrencyChanged,
    required this.accentColorName,
    required this.onAccentColorChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  bool loading = true;

  final List<Trip> trips = [];

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    final savedTrips = await StorageService.loadTrips();

    if (!mounted) return;

    setState(() {
      if (savedTrips.isNotEmpty) {
        trips.addAll(savedTrips);
      } else {
        trips.add(
          Trip(
            name: 'Goa Adventure',
            destination: 'Goa, India',
            startDate: DateTime(2026, 10, 12),
            endDate: DateTime(2026, 10, 16),
            budget: 25000,
          ),
        );
      }

      loading = false;
    });

    if (savedTrips.isEmpty) {
      await StorageService.saveTrips(trips);
    }

    await NotificationService.instance.syncAllTrips(trips);
  }

  Future<void> saveTrips() async {
    await StorageService.saveTrips(trips);
  }

  void newTrip() async {
    final trip = await Navigator.push<Trip>(
      context,
      slideRoute(CreateTripPage(currency: widget.currency)),
    );

    if (trip != null) {
      setState(() {
        trips.add(trip);
      });

      await saveTrips();
      await NotificationService.instance.syncTripReminder(trip);
    }
  }

  void addExpense(Trip trip) async {
    final expense = await Navigator.push<Expense>(
      context,
      slideRoute(AddExpensePage(currency: widget.currency)),
    );

    if (expense != null) {
      setState(() {
        trip.expenses.add(expense);
      });

      await saveTrips();
      await NotificationService.instance.checkBudgetAlert(trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    size: 46,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'TripC',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading your trips...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      HomePage(
        trip: trips.isNotEmpty ? trips.first : null,
        trips: trips,
        onNewTrip: newTrip,
        currency: widget.currency,
      ),
      TripsPage(trips: trips, onNewTrip: newTrip, currency: widget.currency),
      ExpensesPage(
        trips: trips,
        onAddExpense: addExpense,
        currency: widget.currency,
      ),
      AnalyticsPage(trips: trips, currency: widget.currency),
      ProfilePage(
        onThemeChanged: widget.onThemeChanged,
        currency: widget.currency,
        onCurrencyChanged: widget.onCurrencyChanged,
        trips: trips,
        accentColorName: widget.accentColorName,
        onAccentColorChanged: widget.onAccentColorChanged,
      ),
    ];

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        setState(() {
          selectedIndex = 0;
        });
      },
      child: Scaffold(
        body: IndexedStack(index: selectedIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) {
              return;
            }

            setState(() {
              selectedIndex = index;
            });
          },
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          elevation: 0,
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home,
                color: colorScheme.onPrimaryContainer,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.flight_outlined),
              selectedIcon: Icon(
                Icons.flight,
                color: colorScheme.onPrimaryContainer,
              ),
              label: 'Trips',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(
                Icons.receipt_long,
                color: colorScheme.onPrimaryContainer,
              ),
              label: 'Expenses',
            ),
            NavigationDestination(
              icon: const Icon(Icons.analytics_outlined),
              selectedIcon: Icon(
                Icons.analytics,
                color: colorScheme.onPrimaryContainer,
              ),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Trip? trip;
  final List<Trip> trips;
  final VoidCallback onNewTrip;
  final String currency;

  const HomePage({
    super.key,
    required this.trip,
    required this.trips,
    required this.onNewTrip,
    required this.currency,
  });

  String formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  int getDuration(Trip t) {
    final days = t.endDate.difference(t.startDate).inDays + 1;
    return days < 1 ? 1 : days;
  }

  String getSmartInsight(Trip trip) {
    final spent = trip.expenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final remaining = trip.budget - spent;
    final usage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return 'Set a trip budget to receive personalized spending insights.';
    }

    if (usage >= 1.0) {
      return 'You are over budget by '
          '${formatMoney(-remaining, currency)}. '
          'Consider reducing non-essential spending.';
    }

    if (usage >= 0.8) {
      return 'You have used ${(usage * 100).toStringAsFixed(0)}% '
          'of your budget. Keep the remaining '
          '${formatMoney(remaining, currency)} for essential expenses.';
    }

    if (trip.expenses.isNotEmpty) {
      final categoryTotals = <String, double>{};

      for (final expense in trip.expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      String highestCategory = '';
      double highestAmount = 0;

      for (final entry in categoryTotals.entries) {
        if (entry.value > highestAmount) {
          highestCategory = entry.key;
          highestAmount = entry.value;
        }
      }

      final categoryShare = spent > 0 ? highestAmount / spent : 0.0;

      if (categoryShare >= 0.5) {
        return '$highestCategory accounts for '
            '${(categoryShare * 100).toStringAsFixed(0)}% of your spending. '
            'Consider reviewing this category for possible savings.';
      }
    }

    final duration = getDuration(trip);

    if (trip.itinerary.isEmpty) {
      return 'Your itinerary is empty. Add activities to organize your '
          '$duration-day trip.';
    }

    final activitiesPerDay = trip.itinerary.length / duration;

    if (activitiesPerDay < 0.5) {
      return 'You have only ${trip.itinerary.length} planned '
          '${trip.itinerary.length == 1 ? 'activity' : 'activities'} '
          'for $duration days. Consider adding more activities.';
    }

    if (trip.places.isEmpty) {
      return 'You have not saved any places yet. Explore destinations '
          'and add interesting locations to your trip.';
    }

    if (trip.places.length < 3) {
      return 'You have saved ${trip.places.length} '
          '${trip.places.length == 1 ? 'place' : 'places'}. '
          'Consider exploring a few more destinations.';
    }

    if (spent == 0) {
      return 'Your trip is planned, but no expenses have been recorded yet. '
          'Add expenses to track your budget accurately.';
    }

    return 'Your trip looks well planned. Keep updating your expenses '
        'and itinerary for better insights.';
  }

  IconData getSmartInsightIcon(Trip trip) {
    final spent = trip.expenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final usage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (usage >= 0.8) {
      return Icons.account_balance_wallet_outlined;
    }

    if (trip.itinerary.isEmpty) {
      return Icons.event_note_outlined;
    }

    if (trip.places.isEmpty) {
      return Icons.location_on_outlined;
    }

    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'TripC',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    size: 52,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome to TripC',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Plan your trips, manage your budget,\nand keep everything organized in one place.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: onNewTrip,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Your First Trip'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spent = trip!.expenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final remaining = trip!.budget - spent;

    final rawProgress = trip!.budget > 0 ? spent / trip!.budget : 0.0;

    final progress = rawProgress.clamp(0.0, 1.0);

    final activities = [...trip!.itinerary]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);

        if (dateCompare != 0) {
          return dateCompare;
        }

        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;

        return aMinutes.compareTo(bMinutes);
      });

    final now = DateTime.now();

    final upcomingActivities = activities.where((item) {
      final activityDateTime = DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
        item.time.hour,
        item.time.minute,
      );

      return activityDateTime.isAfter(now);
    }).toList();

    final nextActivity = upcomingActivities.isNotEmpty
        ? upcomingActivities.first
        : null;

    final budgetColor = rawProgress >= 1
        ? colorScheme.error
        : rawProgress >= 0.8
        ? Colors.orange
        : colorScheme.primary;

    final smartInsight = getSmartInsight(trip!);
    final smartIcon = getSmartInsightIcon(trip!);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TripC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back 👋',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ready for your next adventure?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flight_takeoff_rounded,
                      color: colorScheme.primary,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Current Trip
            Card(
              clipBehavior: Clip.antiAlias,
              color: colorScheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flight_takeoff_rounded,
                              color: colorScheme.onPrimary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT TRIP',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  trip!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 19,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            trip!.destination,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${formatDate(trip!.startDate)} - ${formatDate(trip!.endDate)}',
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${getDuration(trip!)} days',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Budget
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 19,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Budget usage',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(rawProgress * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: budgetColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              color: budgetColor,
                              backgroundColor: colorScheme.surface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatMoney(spent, currency),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'of ${formatMoney(trip!.budget, currency)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Remaining / Over Budget
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: remaining >= 0
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.55,
                              )
                            : colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: remaining >= 0
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: remaining >= 0
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : colorScheme.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              remaining >= 0
                                  ? Icons.account_balance_wallet_outlined
                                  : Icons.warning_amber_rounded,
                              size: 20,
                              color: remaining >= 0
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  remaining >= 0
                                      ? 'Budget remaining'
                                      : 'Over budget',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: remaining >= 0
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  remaining >= 0
                                      ? formatMoney(remaining, currency)
                                      : formatMoney(-remaining, currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: remaining >= 0
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Smart Insight
            Card(
              color: colorScheme.primaryContainer,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        smartIcon,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Insight',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            smartInsight,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Statistics
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    Icons.event_note_rounded,
                    'Activities',
                    '${trip!.itinerary.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    context,
                    Icons.place_rounded,
                    'Places',
                    '${trip!.places.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    context,
                    Icons.receipt_long_rounded,
                    'Expenses',
                    '${trip!.expenses.length}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Next Activity
            Card(
              color: colorScheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: nextActivity == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            context,
                            Icons.schedule_rounded,
                            'Next Activity',
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.event_available_outlined,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No activities planned yet. Add activities to build your itinerary.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            context,
                            Icons.schedule_rounded,
                            'Next Activity',
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primaryContainer,
                                  colorScheme.surfaceContainerHighest,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.event_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nextActivity.place,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        nextActivity.description.isEmpty
                                            ? 'Planned activity'
                                            : nextActivity.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatDate(nextActivity.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                nextActivity.time.format(context),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 22),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: onNewTrip,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New Trip'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          slideRoute(
                            ExplorePage(
                              trip: trip!,
                              trips: trips,
                              currency: currency,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explore'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 21,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripsPage extends StatefulWidget {
  final List<Trip> trips;
  final VoidCallback onNewTrip;
  final String currency;

  const TripsPage({
    super.key,
    required this.trips,
    required this.onNewTrip,
    required this.currency,
  });

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  double getSpent(Trip trip) {
    return trip.expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<void> editTrip(Trip trip) async {
    final result = await Navigator.push<Trip>(
      context,
      slideRoute(CreateTripPage(trip: trip, currency: widget.currency)),
    );

    if (result != null) {
      setState(() {});
      await StorageService.saveTrips(widget.trips);
    }
  }

  Future<void> deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Delete Trip?'),
          content: Text('Are you sure you want to delete "${trip.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        widget.trips.remove(trip);
      });

      await StorageService.saveTrips(widget.trips);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String getTripStatus(Trip trip) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    if (today.isBefore(start)) {
      return 'Upcoming';
    }

    if (today.isAfter(end)) {
      return 'Completed';
    }

    return 'Ongoing';
  }

  int getDaysUntilTrip(Trip trip) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    return start.difference(today).inDays;
  }

  int getDaysRemaining(Trip trip) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    return end.difference(today).inDays;
  }

  String getTripTimingText(Trip trip) {
    final status = getTripStatus(trip);

    if (status == 'Upcoming') {
      final days = getDaysUntilTrip(trip);

      if (days == 0) {
        return 'Starts today';
      }

      if (days == 1) {
        return 'Starts tomorrow';
      }

      return 'Starts in $days days';
    }

    if (status == 'Ongoing') {
      final days = getDaysRemaining(trip);

      if (days == 0) {
        return 'Ends today';
      }

      if (days == 1) {
        return '1 day remaining';
      }

      return '$days days remaining';
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    final daysAgo = today.difference(end).inDays;

    if (daysAgo == 1) {
      return 'Ended yesterday';
    }

    return 'Ended $daysAgo days ago';
  }

  IconData getTripStatusIcon(Trip trip) {
    switch (getTripStatus(trip)) {
      case 'Upcoming':
        return Icons.schedule_rounded;
      case 'Ongoing':
        return Icons.flight_takeoff_rounded;
      case 'Completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Color getTripStatusColor(Trip trip, ColorScheme colors) {
    switch (getTripStatus(trip)) {
      case 'Upcoming':
        return colors.primary;
      case 'Ongoing':
        return colors.secondary;
      case 'Completed':
        return colors.onSurfaceVariant;
      default:
        return colors.primary;
    }
  }

  String getSmartStatus(Trip trip) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return 'Set a travel budget';
    }

    if (budgetUsage >= 1) {
      return 'Over budget';
    }

    if (budgetUsage >= 0.8) {
      return '80%+ budget used';
    }

    if (trip.itinerary.isEmpty) {
      return 'Few activities planned';
    }

    if (trip.places.isEmpty) {
      return 'No places saved';
    }

    if (trip.itinerary.length < 2) {
      return 'Add more activities';
    }

    return 'Trip looks well planned';
  }

  IconData getSmartStatusIcon(Trip trip) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return Icons.account_balance_wallet_outlined;
    }

    if (budgetUsage >= 1) {
      return Icons.warning_amber_rounded;
    }

    if (budgetUsage >= 0.8) {
      return Icons.trending_up_rounded;
    }

    if (trip.itinerary.isEmpty) {
      return Icons.event_note_outlined;
    }

    if (trip.places.isEmpty) {
      return Icons.location_off_outlined;
    }

    if (trip.itinerary.length < 2) {
      return Icons.add_task_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  Color getSmartStatusColor(Trip trip, ColorScheme colors) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return colors.onSurfaceVariant;
    }

    if (budgetUsage >= 1) {
      return colors.error;
    }

    if (budgetUsage >= 0.8) {
      return Colors.orange;
    }

    if (trip.itinerary.isEmpty || trip.places.isEmpty) {
      return colors.tertiary;
    }

    return colors.primary;
  }

  double getDailySpendingRate(Trip trip) {
    final spent = getSpent(trip);
    final status = getTripStatus(trip);

    if (spent <= 0) {
      return 0;
    }

    if (status == 'Upcoming') {
      return 0;
    }

    if (status == 'Completed') {
      final duration = trip.endDate.difference(trip.startDate).inDays + 1;

      return duration > 0 ? spent / duration : spent;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final elapsedDays = today.difference(start).inDays + 1;

    return elapsedDays > 0 ? spent / elapsedDays : spent;
  }

  double getProjectedSpending(Trip trip) {
    final spent = getSpent(trip);
    final status = getTripStatus(trip);

    if (status == 'Upcoming') {
      return 0;
    }

    if (status == 'Completed') {
      return spent;
    }

    final dailyRate = getDailySpendingRate(trip);

    final duration = trip.endDate.difference(trip.startDate).inDays + 1;

    return dailyRate * duration;
  }

  String getBudgetPaceText(Trip trip) {
    if (trip.budget <= 0) {
      return 'No budget set';
    }

    final spent = getSpent(trip);
    final status = getTripStatus(trip);

    if (spent >= trip.budget) {
      return 'Budget exceeded';
    }

    if (status == 'Upcoming') {
      return 'Budget ready for the trip';
    }

    if (status == 'Completed') {
      final usage = spent / trip.budget;

      if (usage < 0.8) {
        return 'Trip finished under budget';
      }

      if (usage < 1) {
        return 'Trip finished near budget';
      }

      return 'Trip finished over budget';
    }

    final projected = getProjectedSpending(trip);

    if (projected > trip.budget) {
      return 'Spending pace may exceed budget';
    }

    if (projected >= trip.budget * 0.9) {
      return 'Spending pace is close to budget';
    }

    return 'Spending pace is on track';
  }

  Color getBudgetPaceColor(Trip trip, ColorScheme colors) {
    if (trip.budget <= 0) {
      return colors.onSurfaceVariant;
    }

    final spent = getSpent(trip);

    if (spent >= trip.budget) {
      return colors.error;
    }

    if (getTripStatus(trip) == 'Upcoming') {
      return colors.primary;
    }

    final projected = getProjectedSpending(trip);

    if (projected > trip.budget) {
      return colors.error;
    }

    if (projected >= trip.budget * 0.9) {
      return Colors.orange;
    }

    return colors.primary;
  }

  IconData getBudgetPaceIcon(Trip trip) {
    if (trip.budget <= 0) {
      return Icons.account_balance_wallet_outlined;
    }

    final spent = getSpent(trip);

    if (spent >= trip.budget) {
      return Icons.warning_amber_rounded;
    }

    if (getTripStatus(trip) == 'Upcoming') {
      return Icons.savings_outlined;
    }

    final projected = getProjectedSpending(trip);

    if (projected > trip.budget) {
      return Icons.trending_up_rounded;
    }

    if (projected >= trip.budget * 0.9) {
      return Icons.speed_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  // 31C - Itinerary Intelligence

  DateTime getItineraryDateTime(ItineraryItem item) {
    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      item.time.hour,
      item.time.minute,
    );
  }

  int getItineraryCount(Trip trip) {
    return trip.itinerary.length;
  }

  int getTodayItineraryCount(Trip trip) {
    final now = DateTime.now();

    return trip.itinerary.where((item) {
      return item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day;
    }).length;
  }

  int getOverdueItineraryCount(Trip trip) {
    final now = DateTime.now();

    return trip.itinerary.where((item) {
      return getItineraryDateTime(item).isBefore(now);
    }).length;
  }

  ItineraryItem? getNextItineraryItem(Trip trip) {
    final now = DateTime.now();

    final upcoming = trip.itinerary
        .where((item) => getItineraryDateTime(item).isAfter(now))
        .toList();

    if (upcoming.isEmpty) {
      return null;
    }

    upcoming.sort(
      (a, b) => getItineraryDateTime(a).compareTo(getItineraryDateTime(b)),
    );

    return upcoming.first;
  }

  double getPlannedItineraryCost(Trip trip) {
    return trip.itinerary.fold(0.0, (sum, item) => sum + item.estimatedCost);
  }

  String getItineraryInsight(Trip trip) {
    final count = getItineraryCount(trip);
    final todayCount = getTodayItineraryCount(trip);
    final overdueCount = getOverdueItineraryCount(trip);
    final plannedCost = getPlannedItineraryCost(trip);

    if (count == 0) {
      return 'No activities planned yet';
    }

    if (overdueCount > 0 && getTripStatus(trip) == 'Ongoing') {
      return '$overdueCount ${overdueCount == 1 ? 'activity is' : 'activities are'} overdue';
    }

    if (trip.budget > 0 && plannedCost > trip.budget) {
      return 'Planned activities exceed the trip budget';
    }

    if (todayCount > 0) {
      return '$todayCount ${todayCount == 1 ? 'activity' : 'activities'} planned for today';
    }

    if (count == 1) {
      return '1 activity planned';
    }

    return '$count activities planned';
  }

  IconData getItineraryInsightIcon(Trip trip) {
    final count = getItineraryCount(trip);
    final overdueCount = getOverdueItineraryCount(trip);
    final plannedCost = getPlannedItineraryCost(trip);

    if (count == 0) {
      return Icons.event_note_outlined;
    }

    if (overdueCount > 0 && getTripStatus(trip) == 'Ongoing') {
      return Icons.warning_amber_rounded;
    }

    if (trip.budget > 0 && plannedCost > trip.budget) {
      return Icons.account_balance_wallet_outlined;
    }

    if (getTodayItineraryCount(trip) > 0) {
      return Icons.today_rounded;
    }

    return Icons.check_circle_outline_rounded;
  }

  Color getItineraryInsightColor(Trip trip, ColorScheme colors) {
    final count = getItineraryCount(trip);
    final overdueCount = getOverdueItineraryCount(trip);
    final plannedCost = getPlannedItineraryCost(trip);

    if (count == 0) {
      return colors.tertiary;
    }

    if (overdueCount > 0 && getTripStatus(trip) == 'Ongoing') {
      return colors.error;
    }

    if (trip.budget > 0 && plannedCost > trip.budget) {
      return colors.error;
    }

    if (getTodayItineraryCount(trip) > 0) {
      return colors.primary;
    }

    return colors.primary;
  }

  String getNextActivityText(Trip trip) {
    final next = getNextItineraryItem(trip);

    if (next == null) {
      if (trip.itinerary.isEmpty) {
        return 'Add activities to build your itinerary';
      }

      return 'No upcoming activities';
    }

    return '${next.place} • ${formatDate(next.date)}';
  }

  String getItineraryBudgetText(Trip trip) {
    final plannedCost = getPlannedItineraryCost(trip);

    if (plannedCost <= 0) {
      return 'No estimated activity cost';
    }

    if (trip.budget <= 0) {
      return '${formatMoney(plannedCost, widget.currency)} planned';
    }

    final percentage = plannedCost / trip.budget;

    if (percentage > 1) {
      return '${formatMoney(plannedCost, widget.currency)} exceeds budget';
    }

    return '${formatMoney(plannedCost, widget.currency)} planned • ${(percentage * 100).toStringAsFixed(0)}% of budget';
  }

  // 31D - Smart Recommendations

  List<Map<String, dynamic>> getTripRecommendations(Trip trip) {
    final recommendations = <Map<String, dynamic>>[];

    final spent = getSpent(trip);
    final status = getTripStatus(trip);
    final overdue = getOverdueItineraryCount(trip);
    final plannedCost = getPlannedItineraryCost(trip);
    final projected = getProjectedSpending(trip);

    if (trip.budget <= 0) {
      recommendations.add({
        'title': 'Set a travel budget',
        'description':
            'Add a budget to unlock spending predictions and budget alerts.',
        'icon': Icons.account_balance_wallet_outlined,
        'color': 'warning',
      });
    } else if (spent >= trip.budget) {
      recommendations.add({
        'title': 'Review your spending',
        'description':
            'Your current expenses have reached or exceeded the trip budget.',
        'icon': Icons.warning_amber_rounded,
        'color': 'error',
      });
    } else if (status == 'Ongoing' && projected > trip.budget) {
      recommendations.add({
        'title': 'Slow down spending',
        'description':
            'Your current spending pace may take you over the trip budget.',
        'icon': Icons.trending_up_rounded,
        'color': 'error',
      });
    } else if (status == 'Ongoing' && projected >= trip.budget * 0.9) {
      recommendations.add({
        'title': 'Watch your remaining budget',
        'description':
            'Your projected spending is getting close to the trip budget.',
        'icon': Icons.speed_rounded,
        'color': 'warning',
      });
    }

    if (status == 'Ongoing' && overdue > 0) {
      recommendations.add({
        'title': 'Review overdue activities',
        'description':
            '$overdue ${overdue == 1 ? 'activity is' : 'activities are'} past their scheduled time.',
        'icon': Icons.schedule_rounded,
        'color': 'error',
      });
    }

    if (trip.budget > 0 && plannedCost > trip.budget) {
      recommendations.add({
        'title': 'Reduce planned activity costs',
        'description':
            'Your estimated itinerary cost is higher than the trip budget.',
        'icon': Icons.account_balance_wallet_outlined,
        'color': 'error',
      });
    }

    if (trip.itinerary.isEmpty) {
      recommendations.add({
        'title': 'Build your itinerary',
        'description':
            'Add activities and timings so TripC can track your schedule.',
        'icon': Icons.event_note_outlined,
        'color': 'primary',
      });
    } else if (trip.itinerary.length < 2 && status != 'Completed') {
      recommendations.add({
        'title': 'Add more activities',
        'description': 'Your itinerary has very few activities. Consider planning more of your trip.',
        'icon': Icons.add_task_rounded,
        'color': 'primary',
      });
    }

    if (trip.places.isEmpty && status != 'Completed') {
      recommendations.add({
        'title': 'Save places to visit',
        'description': 'Add interesting destinations so you can turn them into itinerary activities later.',
        'icon': Icons.location_on_outlined,
        'color': 'primary',
      });
    }

    if (status == 'Upcoming') {
      final days = getDaysUntilTrip(trip);

      if (days <= 7 && trip.itinerary.isEmpty) {
        recommendations.add({
          'title': 'Prepare your trip',
          'description': 'Your trip is approaching. Start planning activities and places now.',
          'icon': Icons.luggage_outlined,
          'color': 'warning',
        });
      } else if (trip.itinerary.isNotEmpty &&
          trip.places.isNotEmpty &&
          trip.budget > 0) {
        recommendations.add({
          'title': 'Trip preparation looks good',
          'description':
              'Your budget, places, and itinerary are ready for the trip.',
          'icon': Icons.check_circle_outline_rounded,
          'color': 'success',
        });
      }
    }

    if (status == 'Ongoing' && trip.expenses.isEmpty && trip.budget > 0) {
      recommendations.add({
        'title': 'Record your expenses',
        'description': 'Add expenses as you travel to keep your budget predictions accurate.',
        'icon': Icons.receipt_long_outlined,
        'color': 'primary',
      });
    }

    if (status == 'Completed' &&
        trip.budget > 0 &&
        spent < trip.budget &&
        overdue == 0) {
      recommendations.add({
        'title': 'Great budget control',
        'description':
            'You completed the trip without exceeding your planned budget.',
        'icon': Icons.emoji_events_outlined,
        'color': 'success',
      });
    }

    if (recommendations.isEmpty) {
      recommendations.add({
        'title': 'Trip looks well planned',
        'description':
            'Your budget and itinerary are in good shape. Enjoy your trip!',
        'icon': Icons.auto_awesome_rounded,
        'color': 'success',
      });
    }

    return recommendations.take(3).toList();
  }

  Color getRecommendationColor(String type, ColorScheme colors) {
    switch (type) {
      case 'error':
        return colors.error;
      case 'warning':
        return Colors.orange;
      case 'success':
        return colors.primary;
      default:
        return colors.primary;
    }
  }

  // 31E - Trip Progress

  double getTimelineProgress(Trip trip) {
    final status = getTripStatus(trip);

    if (status == 'Upcoming') {
      return 0.0;
    }

    if (status == 'Completed') {
      return 1.0;
    }

    final now = DateTime.now();

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    final totalDays = end.difference(start).inDays + 1;

    final elapsedDays = today.difference(start).inDays + 1;

    if (totalDays <= 0) {
      return 0.0;
    }

    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  double getPlanningProgress(Trip trip) {
    double progress = 0.0;

    if (trip.budget > 0) {
      progress += 0.25;
    }

    if (trip.itinerary.isNotEmpty) {
      progress += 0.20;
    }

    if (trip.itinerary.length >= 3) {
      progress += 0.20;
    } else if (trip.itinerary.length >= 2) {
      progress += 0.10;
    }

    if (trip.places.isNotEmpty) {
      progress += 0.075;
    }

    if (trip.places.length >= 3) {
      progress += 0.075;
    }

    return progress.clamp(0.0, 1.0);
  }

  double getBudgetTrackingProgress(Trip trip) {
    if (trip.budget <= 0) {
      return 0.0;
    }

    if (getTripStatus(trip) == 'Completed') {
      return 1.0;
    }

    if (trip.expenses.isNotEmpty) {
      return 1.0;
    }

    return 0.0;
  }

  double getTripProgress(Trip trip) {
    final status = getTripStatus(trip);

    if (status == 'Completed') {
      return 1.0;
    }

    final timeline = getTimelineProgress(trip);
    final planning = getPlanningProgress(trip);
    final tracking = getBudgetTrackingProgress(trip);

    if (status == 'Upcoming') {
      return (planning * 0.70 + tracking * 0.30).clamp(0.0, 1.0);
    }

    return (timeline * 0.50 + planning * 0.30 + tracking * 0.20).clamp(
      0.0,
      1.0,
    );
  }

  String getTripProgressLabel(Trip trip) {
    final status = getTripStatus(trip);
    final percentage = (getTripProgress(trip) * 100).round();

    if (status == 'Upcoming') {
      if (percentage >= 80) {
        return 'Trip preparation is $percentage% complete';
      }

      if (percentage >= 50) {
        return 'Trip preparation is progressing well';
      }

      return 'Trip preparation is $percentage% complete';
    }

    if (status == 'Ongoing') {
      if (percentage >= 80) {
        return 'Trip is $percentage% complete';
      }

      if (percentage >= 50) {
        return 'You are making good progress';
      }

      return 'Trip is $percentage% complete';
    }

    return 'Trip completed successfully';
  }

  Color getTripProgressColor(Trip trip, ColorScheme colors) {
    final status = getTripStatus(trip);

    if (status == 'Completed') {
      return colors.primary;
    }

    final progress = getTripProgress(trip);

    if (progress >= 0.75) {
      return colors.primary;
    }

    if (progress >= 0.45) {
      return Colors.orange;
    }

    return colors.tertiary;
  }

  String getProgressMetricText(double value) {
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Trips',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.trips.isEmpty
                  ? 'Start planning your next adventure'
                  : '${widget.trips.length} ${widget.trips.length == 1 ? 'trip' : 'trips'} planned',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: widget.trips.isEmpty
          ? _emptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.luggage_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        '${widget.trips.length} ${widget.trips.length == 1 ? 'trip' : 'trips'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.travel_explore_rounded,
                        size: 19,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...widget.trips.map((trip) => _tripCard(context, trip, colors)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onNewTrip,
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 48,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No trips yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first trip and start planning your next adventure.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onNewTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(BuildContext context, Trip trip, ColorScheme colors) {
    final theme = Theme.of(context);

    final spent = getSpent(trip);
    final remaining = trip.budget - spent;

    final rawProgress = trip.budget > 0 ? spent / trip.budget : 0.0;

    final progress = rawProgress.clamp(0.0, 1.0);

    final duration = trip.endDate.difference(trip.startDate).inDays + 1;

    final budgetColor = rawProgress >= 1
        ? colors.error
        : rawProgress >= 0.8
        ? Colors.orange
        : colors.primary;

    final tripStatus = getTripStatus(trip);
    final tripTiming = getTripTimingText(trip);
    final tripStatusColor = getTripStatusColor(trip, colors);
    final tripStatusIcon = getTripStatusIcon(trip);

    final smartColor = getSmartStatusColor(trip, colors);
    final smartIcon = getSmartStatusIcon(trip);
    final smartStatus = getSmartStatus(trip);

    final dailyRate = getDailySpendingRate(trip);

    final projectedSpending = getProjectedSpending(trip);

    final budgetPaceText = getBudgetPaceText(trip);

    final budgetPaceColor = getBudgetPaceColor(trip, colors);

    final budgetPaceIcon = getBudgetPaceIcon(trip);

    final itineraryCount = getItineraryCount(trip);

    final todayItineraryCount = getTodayItineraryCount(trip);

    final overdueItineraryCount = getOverdueItineraryCount(trip);

    final plannedItineraryCost = getPlannedItineraryCost(trip);

    final itineraryInsight = getItineraryInsight(trip);

    final itineraryInsightIcon = getItineraryInsightIcon(trip);

    final itineraryInsightColor = getItineraryInsightColor(trip, colors);

    final recommendations = getTripRecommendations(trip);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            slideRoute(
              TripDetailsPage(
                trip: trip,
                trips: widget.trips,
                currency: widget.currency,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.flight_takeoff_rounded,
                      color: colors.onPrimary,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Trip options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        editTrip(trip);
                      } else if (value == 'delete') {
                        deleteTrip(trip);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tripStatusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tripStatusColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(tripStatusIcon, size: 19, color: tripStatusColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tripStatus,
                            style: TextStyle(
                              color: tripStatusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tripTiming,
                            style: TextStyle(
                              color: tripStatusColor.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tripStatus == 'Upcoming')
                      Icon(
                        Icons.event_available_rounded,
                        size: 18,
                        color: tripStatusColor,
                      )
                    else if (tripStatus == 'Ongoing')
                      Icon(
                        Icons.explore_rounded,
                        size: 18,
                        color: tripStatusColor,
                      )
                    else
                      Icon(
                        Icons.done_all_rounded,
                        size: 18,
                        color: tripStatusColor,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 19,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Travel dates',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$duration ${duration == 1 ? 'day' : 'days'}',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: smartColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: smartColor.withValues(alpha: 0.22)),
                ),
                child: Row(
                  children: [
                    Icon(smartIcon, size: 18, color: smartColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        smartStatus,
                        style: TextStyle(
                          color: smartColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.auto_awesome, size: 16, color: smartColor),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 19,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Budget',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(rawProgress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: budgetColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: colors.surface,
                        color: budgetColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent ${formatMoney(spent, widget.currency)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          remaining >= 0
                              ? '${formatMoney(remaining, widget.currency)} left'
                              : '${formatMoney(remaining.abs(), widget.currency)} over',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: remaining >= 0
                                ? colors.primary
                                : colors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    if (trip.budget > 0 &&
                        (tripStatus != 'Upcoming' || spent > 0)) ...[
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _budgetMetric(
                              context,
                              icon: Icons.speed_rounded,
                              label: 'Daily rate',
                              value: dailyRate > 0
                                  ? formatMoney(dailyRate, widget.currency)
                                  : '—',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: colors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          Expanded(
                            child: _budgetMetric(
                              context,
                              icon: Icons.auto_graph_rounded,
                              label: tripStatus == 'Completed'
                                  ? 'Final spend'
                                  : 'Projected',
                              value: tripStatus == 'Upcoming'
                                  ? '—'
                                  : formatMoney(
                                      projectedSpending,
                                      widget.currency,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: budgetPaceColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: budgetPaceColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              budgetPaceIcon,
                              size: 17,
                              color: budgetPaceColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                budgetPaceText,
                                style: TextStyle(
                                  color: budgetPaceColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Itinerary Intelligence
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.route_rounded,
                            size: 19,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Itinerary Intelligence',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                itineraryInsight,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          itineraryInsightIcon,
                          size: 19,
                          color: itineraryInsightColor,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _itineraryMetric(
                            context,
                            icon: Icons.event_note_outlined,
                            label: 'Activities',
                            value: '$itineraryCount',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _itineraryMetric(
                            context,
                            icon: Icons.today_outlined,
                            label: 'Today',
                            value: '$todayItineraryCount',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _itineraryMetric(
                            context,
                            icon: Icons.warning_amber_outlined,
                            label: 'Overdue',
                            value: '$overdueItineraryCount',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 17,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getNextActivityText(trip),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (plannedItineraryCost > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        getItineraryBudgetText(trip),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              trip.budget > 0 &&
                                  plannedItineraryCost > trip.budget
                              ? colors.error
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 31E - Trip Progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 19,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trip Progress',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                getTripProgressLabel(trip),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(getTripProgress(trip) * 100).round()}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: getTripProgressColor(trip, colors),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: getTripProgress(trip),
                        minHeight: 10,
                        backgroundColor: colors.surfaceContainerHighest,
                        color: getTripProgressColor(trip, colors),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: _progressMetric(
                            context,
                            icon: Icons.schedule_rounded,
                            label: 'Timeline',
                            value: getProgressMetricText(
                              getTimelineProgress(trip),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _progressMetric(
                            context,
                            icon: Icons.route_rounded,
                            label: 'Planning',
                            value: getProgressMetricText(
                              getPlanningProgress(trip),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        Expanded(
                          child: _progressMetric(
                            context,
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Budget',
                            value: trip.budget > 0
                                ? getProgressMetricText(
                                    getBudgetTrackingProgress(trip),
                                  )
                                : '—',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: getTripProgressColor(
                          trip,
                          colors,
                        ).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            getTripStatus(trip) == 'Completed'
                                ? Icons.check_circle_rounded
                                : Icons.auto_graph_rounded,
                            size: 17,
                            color: getTripProgressColor(trip, colors),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getTripStatus(trip) == 'Completed'
                                  ? 'All trip stages completed'
                                  : getTripProgressLabel(trip),
                              style: TextStyle(
                                color: getTripProgressColor(trip, colors),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 31D - Smart Recommendations
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 19,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Recommendations',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Personalized suggestions for this trip',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 19,
                          color: colors.primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    ...recommendations.asMap().entries.map((entry) {
                      final recommendation = entry.value;

                      final recommendationColor = getRecommendationColor(
                        recommendation['color'] as String,
                        colors,
                      );

                      final isLast = entry.key == recommendations.length - 1;

                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: recommendationColor.withValues(
                                alpha: 0.07,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: recommendationColor.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: recommendationColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    recommendation['icon'] as IconData,
                                    size: 18,
                                    color: recommendationColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recommendation['title'] as String,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: recommendationColor,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        recommendation['description'] as String,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast) const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budgetMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itineraryMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTripPage extends StatefulWidget {
  final Trip? trip;
  final String currency;

  const CreateTripPage({super.key, this.trip, required this.currency});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final nameController = TextEditingController();
  final destinationController = TextEditingController();
  final budgetController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  bool get editing => widget.trip != null;

  String getTripStatus(Trip trip) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    if (today.isBefore(start)) {
      return 'Upcoming';
    }

    if (today.isAfter(end)) {
      return 'Completed';
    }

    return 'Ongoing';
  }

  @override
  void initState() {
    super.initState();

    if (widget.trip != null) {
      nameController.text = widget.trip!.name;
      destinationController.text = widget.trip!.destination;
      budgetController.text = widget.trip!.budget.toStringAsFixed(0);

      startDate = widget.trip!.startDate;
      endDate = widget.trip!.endDate;
    }
  }

  Future<void> pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: startDate ?? DateTime.now(),
    );

    if (date != null) {
      setState(() {
        startDate = date;

        if (endDate != null && endDate!.isBefore(date)) {
          endDate = null;
        }
      });
    }
  }

  Future<void> pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: endDate ?? startDate ?? DateTime.now(),
    );

    if (date != null) {
      setState(() {
        endDate = date;
      });
    }
  }

  void saveTrip() {
    final name = nameController.text.trim();
    final destination = destinationController.text.trim();
    final budget = double.tryParse(budgetController.text);

    if (name.isEmpty ||
        destination.isEmpty ||
        budget == null ||
        budget <= 0 ||
        startDate == null ||
        endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields correctly'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (editing) {
      widget.trip!.name = name;
      widget.trip!.destination = destination;
      widget.trip!.budget = budget;
      widget.trip!.startDate = startDate!;
      widget.trip!.endDate = endDate!;

      Navigator.pop(context, widget.trip);
    } else {
      Navigator.pop(
        context,
        Trip(
          name: name,
          destination: destination,
          startDate: startDate!,
          endDate: endDate!,
          budget: budget,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    destinationController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  // 31E - Trip Progress

  double getTimelineProgress(Trip trip) {
    final status = getTripStatus(trip);

    if (status == 'Upcoming') {
      return 0.0;
    }

    if (status == 'Completed') {
      return 1.0;
    }

    final now = DateTime.now();

    final start = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );

    final end = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    final totalDays = end.difference(start).inDays + 1;
    final elapsedDays = today.difference(start).inDays + 1;

    if (totalDays <= 0) {
      return 0.0;
    }

    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  double getPlanningProgress(Trip trip) {
    double progress = 0.0;

    // Budget preparation: 25%
    if (trip.budget > 0) {
      progress += 0.25;
    }

    // Itinerary preparation: 40%
    if (trip.itinerary.isNotEmpty) {
      progress += 0.20;
    }

    if (trip.itinerary.length >= 3) {
      progress += 0.20;
    } else if (trip.itinerary.length >= 2) {
      progress += 0.10;
    }

    // Places preparation: 15%
    if (trip.places.isNotEmpty) {
      progress += 0.075;
    }

    if (trip.places.length >= 3) {
      progress += 0.075;
    }

    return progress.clamp(0.0, 1.0);
  }

  double getBudgetTrackingProgress(Trip trip) {
    if (trip.budget <= 0) {
      return 0.0;
    }

    if (getTripStatus(trip) == 'Completed') {
      return 1.0;
    }

    if (trip.expenses.isNotEmpty) {
      return 1.0;
    }

    return 0.0;
  }

  double getTripProgress(Trip trip) {
    final status = getTripStatus(trip);

    if (status == 'Completed') {
      return 1.0;
    }

    final timeline = getTimelineProgress(trip);
    final planning = getPlanningProgress(trip);
    final tracking = getBudgetTrackingProgress(trip);

    if (status == 'Upcoming') {
      // Upcoming trips focus mainly on preparation.
      return (planning * 0.70 + tracking * 0.30).clamp(0.0, 1.0);
    }

    // Ongoing trips focus on journey progress,
    // preparation and expense tracking.
    return (timeline * 0.50 + planning * 0.30 + tracking * 0.20).clamp(
      0.0,
      1.0,
    );
  }

  String getTripProgressLabel(Trip trip) {
    final status = getTripStatus(trip);
    final progress = getTripProgress(trip);

    final percentage = (progress * 100).round();

    if (status == 'Upcoming') {
      if (percentage >= 80) {
        return 'Trip preparation is $percentage% complete';
      }

      if (percentage >= 50) {
        return 'Trip preparation is progressing well';
      }

      return 'Trip preparation is $percentage% complete';
    }

    if (status == 'Ongoing') {
      if (percentage >= 80) {
        return 'Trip is $percentage% complete';
      }

      if (percentage >= 50) {
        return 'You are making good progress';
      }

      return 'Trip is $percentage% complete';
    }

    return 'Trip completed successfully';
  }

  Color getTripProgressColor(Trip trip, ColorScheme colors) {
    final status = getTripStatus(trip);

    if (status == 'Completed') {
      return colors.primary;
    }

    final progress = getTripProgress(trip);

    if (progress >= 0.75) {
      return colors.primary;
    }

    if (progress >= 0.45) {
      return Colors.orange;
    }

    return colors.tertiary;
  }

  String getProgressMetricText(double value) {
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Trip' : 'Create Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                prefixIcon: Icon(Icons.flight),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Budget',
                prefixText: '${currencySymbol(widget.currency)} ',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
              title: Text(
                startDate == null
                    ? 'Select Start Date'
                    : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
              ),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.chevron_right),
              onTap: pickStartDate,
            ),

            const SizedBox(height: 10),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
              title: Text(
                endDate == null
                    ? 'Select End Date'
                    : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
              ),
              leading: const Icon(Icons.calendar_month),
              trailing: const Icon(Icons.chevron_right),
              onTap: pickEndDate,
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saveTrip,
                icon: Icon(editing ? Icons.save : Icons.add),
                label: Text(editing ? 'Save Changes' : 'Create Trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlannedVsActualPage extends StatelessWidget {
  final Trip trip;
  final String currency;

  const PlannedVsActualPage({
    super.key,
    required this.trip,
    required this.currency,
  });

  double getPlannedCost() {
    return trip.itinerary.fold(0.0, (sum, item) => sum + item.estimatedCost);
  }

  double getActualCost() {
    return trip.expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final planned = getPlannedCost();
    final actual = getActualCost();
    final difference = actual - planned;

    final maxValue = planned > actual ? planned : actual;

    final plannedProgress = maxValue > 0
        ? (planned / maxValue).clamp(0.0, 1.0)
        : 0.0;

    final actualProgress = maxValue > 0
        ? (actual / maxValue).clamp(0.0, 1.0)
        : 0.0;

    final hasData = planned > 0 || actual > 0;

    final variancePercentage = planned > 0
        ? ((difference.abs() / planned) * 100)
        : 0.0;

    final bool overPlan = difference > 0;
    final bool underPlan = difference < 0;

    final statusColor = overPlan
        ? colors.error
        : underPlan
        ? colors.primary
        : colors.secondary;

    final statusIcon = overPlan
        ? Icons.warning_amber_rounded
        : underPlan
        ? Icons.check_circle_outline_rounded
        : Icons.balance_rounded;

    final statusTitle = overPlan
        ? 'Above planned cost'
        : underPlan
        ? 'Within planned cost'
        : 'Exactly on plan';

    final statusMessage = !hasData
        ? 'Add itinerary costs and expenses to compare your trip spending.'
        : overPlan
        ? 'Your actual spending is higher than the estimated activity cost.'
        : underPlan
        ? 'You are currently spending less than the estimated activity cost.'
        : 'Your actual spending matches the estimated activity cost.';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Planned vs Actual',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        color: colors.primary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip spending',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  formatMoney(actual, currency),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'actual spending',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 18, color: statusColor),
                      const SizedBox(width: 7),
                      Text(
                        statusTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  context,
                  icon: Icons.event_note_rounded,
                  label: 'Planned',
                  value: formatMoney(planned, currency),
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  context,
                  icon: Icons.receipt_long_rounded,
                  label: 'Actual',
                  value: formatMoney(actual, currency),
                  color: colors.secondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _varianceCard(
            context,
            difference: difference,
            percentage: variancePercentage,
            color: statusColor,
            icon: statusIcon,
          ),

          const SizedBox(height: 18),

          // Comparison section
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          size: 21,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cost comparison',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Estimated activity cost vs recorded expenses',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _comparison(
                    context,
                    Icons.event_note_outlined,
                    'Planned activity cost',
                    planned,
                    plannedProgress,
                    colors.primary,
                  ),

                  const SizedBox(height: 24),

                  _comparison(
                    context,
                    Icons.receipt_long_outlined,
                    'Actual expenses',
                    actual,
                    actualProgress,
                    overPlan ? colors.error : colors.secondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Insight card
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spending insight',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          statusMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!hasData) ...[const SizedBox(height: 16), _emptyState(context)],
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 13),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _varianceCard(
    BuildContext context, {
    required double difference,
    required double percentage,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final label = difference > 0
        ? 'Over plan'
        : difference < 0
        ? 'Under plan'
        : 'No variance';

    final value = difference == 0
        ? formatMoney(0, currency)
        : formatMoney(difference.abs(), currency);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (difference != 0)
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _comparison(
    BuildContext context,
    IconData icon,
    String label,
    double value,
    double progress,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatMoney(value, currency),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: colors.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing to compare yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add planned itinerary costs or record expenses to see your spending comparison.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class TripDetailsPage extends StatelessWidget {
  final Trip trip;
  final List<Trip> trips;
  final String currency;

  const TripDetailsPage({
    super.key,
    required this.trip,
    required this.trips,
    required this.currency,
  });

  double getSpent() {
    return trip.expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  int getDuration() {
    final days = trip.endDate.difference(trip.startDate).inDays + 1;
    return days < 1 ? 1 : days;
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String getSmartInsight() {
    final spent = getSpent();
    final remaining = trip.budget - spent;

    final usage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return 'Set a trip budget to receive personalized insights.';
    }

    if (usage >= 1.0) {
      return 'This trip is over budget by '
          '${formatMoney(-remaining, currency)}. '
          'Consider reducing non-essential spending.';
    }

    if (usage >= 0.8) {
      return 'You have used ${(usage * 100).toStringAsFixed(0)}% '
          'of the trip budget. Keep the remaining '
          '${formatMoney(remaining, currency)} for essential expenses.';
    }

    if (trip.expenses.isNotEmpty) {
      final categoryTotals = <String, double>{};

      for (final expense in trip.expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      String highestCategory = '';
      double highestAmount = 0;

      for (final entry in categoryTotals.entries) {
        if (entry.value > highestAmount) {
          highestCategory = entry.key;
          highestAmount = entry.value;
        }
      }

      final categoryShare = spent > 0 ? highestAmount / spent : 0.0;

      if (categoryShare >= 0.5) {
        return '$highestCategory accounts for '
            '${(categoryShare * 100).toStringAsFixed(0)}% of your spending. '
            'Review this category for possible savings.';
      }
    }

    final duration = getDuration();

    if (trip.itinerary.isEmpty) {
      return 'No activities are planned yet for this $duration-day trip. '
          'Add activities to organize your schedule.';
    }

    final activitiesPerDay = trip.itinerary.length / duration;

    if (activitiesPerDay < 0.5) {
      return 'Only ${trip.itinerary.length} '
          '${trip.itinerary.length == 1 ? 'activity is' : 'activities are'} '
          'planned for $duration days. Consider adding more activities.';
    }

    if (trip.places.isEmpty) {
      return 'No places have been saved yet. Explore destinations '
          'and add interesting locations to your trip.';
    }

    if (trip.places.length < 3) {
      return 'You have saved ${trip.places.length} '
          '${trip.places.length == 1 ? 'place' : 'places'}. '
          'Consider exploring a few more destinations.';
    }

    if (spent == 0) {
      return 'Your trip is planned, but no expenses have been recorded. '
          'Add expenses to keep your budget accurate.';
    }

    return 'Your trip looks well planned. Keep updating your '
        'expenses and itinerary for better insights.';
  }

  IconData getSmartInsightIcon() {
    final spent = getSpent();

    final usage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (usage >= 0.8) {
      return Icons.account_balance_wallet_outlined;
    }

    if (trip.itinerary.isEmpty) {
      return Icons.event_note_outlined;
    }

    if (trip.places.isEmpty) {
      return Icons.location_on_outlined;
    }

    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final spent = getSpent();
    final remaining = trip.budget - spent;

    final rawProgress = trip.budget > 0 ? spent / trip.budget : 0.0;

    final progress = rawProgress.clamp(0.0, 1.0);

    final budgetColor = rawProgress >= 1
        ? colors.error
        : rawProgress >= 0.8
        ? Colors.orange
        : colors.primary;

    final smartInsight = getSmartInsight();
    final smartIcon = getSmartInsightIcon();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trip.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Trip header
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.flight_takeoff_rounded,
                          size: 28,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          trip.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${getDuration()} days',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Budget overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Budget Overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      Text(
                        formatMoney(trip.budget, currency),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spent',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      Text(
                        formatMoney(spent, currency),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        remaining >= 0 ? 'Remaining' : 'Over Budget',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      Text(
                        remaining >= 0
                            ? formatMoney(remaining, currency)
                            : formatMoney(remaining.abs(), currency),
                        style: TextStyle(
                          color: remaining >= 0 ? colors.primary : colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 9,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: budgetColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(rawProgress * 100).toStringAsFixed(0)}% used',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Smart Insight
          Card(
            color: colors.primaryContainer,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(smartIcon, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Insight',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          smartInsight,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _statCard(
                  context,
                  Icons.event_outlined,
                  'Activities',
                  '${trip.itinerary.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  context,
                  Icons.place_outlined,
                  'Places',
                  '${trip.places.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  context,
                  Icons.receipt_long_outlined,
                  'Expenses',
                  '${trip.expenses.length}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Trip Management',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          _managementCard(
            context,
            icon: Icons.event_outlined,
            title: 'Itinerary',
            subtitle: 'Plan and manage your activities',
            onTap: () {
              Navigator.push(
                context,
                slideRoute(ItineraryPage(trip: trip, currency: currency)),
              );
            },
          ),

          _managementCard(
            context,
            icon: Icons.compare_arrows_rounded,
            title: 'Planned vs Actual',
            subtitle: 'Compare planned activity costs with actual expenses',
            onTap: () {
              Navigator.push(
                context,
                slideRoute(PlannedVsActualPage(trip: trip, currency: currency)),
              );
            },
          ),

          _managementCard(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Expenses',
            subtitle: 'Track and manage trip expenses',
            onTap: () {
              Navigator.push(
                context,
                slideRoute(
                  ExpensesPage(
                    trips: trips,
                    onAddExpense: (selectedTrip) async {
                      final expense = await Navigator.push<Expense>(
                        context,
                        slideRoute(AddExpensePage(currency: currency)),
                      );

                      if (expense != null) {
                        selectedTrip.expenses.add(expense);
                        await StorageService.saveTrips(trips);
                      }
                    },
                    currency: currency,
                  ),
                ),
              );
            },
          ),

          _managementCard(
            context,
            icon: Icons.place_outlined,
            title: 'Places',
            subtitle: 'Manage places you want to visit',
            onTap: () {
              Navigator.push(
                context,
                slideRoute(PlacesPage(trip: trip, currency: currency)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 25, color: colors.primary),
            const SizedBox(height: 7),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _managementCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpensesPage extends StatefulWidget {
  final List<Trip> trips;
  final Function(Trip) onAddExpense;
  final String currency;

  const ExpensesPage({
    super.key,
    required this.trips,
    required this.onAddExpense,
    required this.currency,
  });

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  Trip? selectedTrip;

  @override
  void initState() {
    super.initState();

    if (widget.trips.isNotEmpty) {
      selectedTrip = widget.trips.first;
    }
  }

  double getSpent(Trip trip) {
    return trip.expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> getCategoryTotals(Trip trip) {
    final totals = <String, double>{};

    for (final expense in trip.expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    return totals;
  }

  String getSmartInsight(Trip trip) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return 'Set a budget to start tracking your spending.';
    }

    if (budgetUsage >= 1) {
      return 'You are over budget. Consider reducing non-essential spending.';
    }

    if (budgetUsage >= 0.8) {
      return 'You have used over 80% of your budget. Spend carefully.';
    }

    if (trip.expenses.isEmpty) {
      return 'No spending recorded yet. Add expenses to track your trip.';
    }

    final categoryTotals = getCategoryTotals(trip);

    if (categoryTotals.isNotEmpty) {
      final highestCategory = categoryTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      if (spent > 0 && highestCategory.value / spent >= 0.5) {
        return '${highestCategory.key} is your largest spending category. '
            'Look for ways to save here.';
      }
    }

    if (trip.expenses.length >= 10) {
      return 'You have many expenses recorded. Review smaller purchases '
          'to find potential savings.';
    }

    return 'Your spending is currently within a healthy range.';
  }

  IconData getSmartInsightIcon(Trip trip) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return Icons.account_balance_wallet_outlined;
    }

    if (budgetUsage >= 1) {
      return Icons.warning_amber_rounded;
    }

    if (budgetUsage >= 0.8) {
      return Icons.trending_up_rounded;
    }

    if (trip.expenses.isEmpty) {
      return Icons.receipt_long_outlined;
    }

    final categoryTotals = getCategoryTotals(trip);

    if (categoryTotals.isNotEmpty) {
      final highestCategory = categoryTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      if (spent > 0 && highestCategory.value / spent >= 0.5) {
        return Icons.savings_outlined;
      }
    }

    if (trip.expenses.length >= 10) {
      return Icons.analytics_outlined;
    }

    return Icons.check_circle_outline_rounded;
  }

  Color getSmartInsightColor(Trip trip, ColorScheme colors) {
    final spent = getSpent(trip);
    final budgetUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    if (trip.budget <= 0) {
      return colors.onSurfaceVariant;
    }

    if (budgetUsage >= 1) {
      return colors.error;
    }

    if (budgetUsage >= 0.8) {
      return Colors.orange;
    }

    if (trip.expenses.isEmpty) {
      return colors.onSurfaceVariant;
    }

    final categoryTotals = getCategoryTotals(trip);

    if (categoryTotals.isNotEmpty) {
      final highestCategory = categoryTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      if (spent > 0 && highestCategory.value / spent >= 0.5) {
        return colors.tertiary;
      }
    }

    return colors.primary;
  }

  void editExpense(Trip trip, Expense expense) async {
    final updated = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddExpensePage(expense: expense, currency: widget.currency),
      ),
    );

    if (updated != null) {
      setState(() {
        final index = trip.expenses.indexOf(expense);

        if (index != -1) {
          trip.expenses[index] = updated;
        }
      });

      await StorageService.saveTrips(widget.trips);
      await NotificationService.instance.checkBudgetAlert(trip);
    }
  }

  void deleteExpense(Trip trip, Expense expense) async {
    setState(() {
      trip.expenses.remove(expense);
    });

    await StorageService.saveTrips(widget.trips);
    await NotificationService.instance.checkBudgetAlert(trip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (widget.trips.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Expenses',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _emptyState(context),
      );
    }

    final trip = selectedTrip ?? widget.trips.first;
    final spent = getSpent(trip);
    final remaining = trip.budget - spent;

    final rawProgress = trip.budget > 0 ? spent / trip.budget : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);

    final budgetColor = rawProgress >= 1
        ? colors.error
        : rawProgress >= 0.8
        ? Colors.orange
        : colors.primary;

    final smartColor = getSmartInsightColor(trip, colors);
    final smartIcon = getSmartInsightIcon(trip);
    final smartInsight = getSmartInsight(trip);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expenses',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${trip.expenses.length} ${trip.expenses.length == 1 ? 'expense' : 'expenses'} recorded',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Trip selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Trip>(
                value: trip,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.primary,
                ),
                items: widget.trips.map((t) {
                  return DropdownMenuItem<Trip>(
                    value: t,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            size: 19,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            '${t.name} - ${t.destination}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedTrip = value;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Budget summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: colors.onPrimaryContainer,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget Overview',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget usage',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(rawProgress * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: budgetColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: colors.surface,
                          color: budgetColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spent',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatMoney(spent, widget.currency),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                remaining >= 0 ? 'Remaining' : 'Over budget',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatMoney(remaining.abs(), widget.currency),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: remaining >= 0
                                      ? colors.primary
                                      : colors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Smart Expense Insight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: smartColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: smartColor.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: smartColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(smartIcon, size: 21, color: smartColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Expense Insight',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: smartColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        smartInsight,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Expense History
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expense History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trip.expenses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${trip.expenses.length}',
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (trip.expenses.isEmpty)
            _noExpensesState(context)
          else
            ...trip.expenses.map(
              (expense) => _expenseCard(context, trip, expense),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onAddExpense(trip),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No trips yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a trip before adding expenses.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _noExpensesState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 28,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No expenses yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your first expense to start tracking your spending.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseCard(BuildContext context, Trip trip, Expense expense) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _categoryIcon(expense.category),
                color: colors.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(
                            alpha: 0.65,
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          expense.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (expense.note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      expense.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(expense.amount, widget.currency),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  tooltip: 'Expense options',
                  onSelected: (value) {
                    if (value == 'edit') {
                      editExpense(trip, expense);
                    } else if (value == 'delete') {
                      deleteExpense(trip, expense);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_car_outlined;
      case 'Hotel':
        return Icons.hotel_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Activities':
        return Icons.local_activity_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class AddExpensePage extends StatefulWidget {
  final Expense? expense;
  final String currency;

  const AddExpensePage({super.key, this.expense, required this.currency});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String category = 'Food';
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      nameController.text = widget.expense!.name;
      amountController.text = widget.expense!.amount.toString();
      noteController.text = widget.expense!.note;
      category = widget.expense!.category;
      date = widget.expense!.date;
    }
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: date,
    );

    if (selected != null) {
      setState(() {
        date = selected;
      });
    }
  }

  void saveExpense() {
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text);
    final note = noteController.text.trim();

    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid name and amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.expense != null) {
      widget.expense!.name = name;
      widget.expense!.amount = amount;
      widget.expense!.category = category;
      widget.expense!.date = date;
      widget.expense!.note = note;

      Navigator.pop(context, widget.expense);
    } else {
      Navigator.pop(
        context,
        Expense(
          name: name,
          amount: amount,
          category: category,
          date: date,
          note: note,
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final editing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Edit Expense' : 'Add Expense',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 30,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      editing
                          ? 'Update the details of this expense.'
                          : 'Track your spending by adding a new expense.',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Expense Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Expense Name',
                hintText: 'e.g. Dinner',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${currencySymbol(widget.currency)} ',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Food', child: Text('Food')),
                DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                DropdownMenuItem(value: 'Hotel', child: Text('Hotel')),
                DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                DropdownMenuItem(
                  value: 'Activities',
                  child: Text('Activities'),
                ),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),

            const SizedBox(height: 14),

            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text('${date.day}/${date.month}/${date.year}'),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add any additional details...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 45),
                  child: Icon(Icons.notes_outlined),
                ),
              ),
            ),

            const SizedBox(height: 26),

            FilledButton.icon(
              onPressed: saveExpense,
              icon: Icon(editing ? Icons.save_outlined : Icons.add),
              label: Text(editing ? 'Update Expense' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  final List<Trip> trips;
  final String currency;

  const AnalyticsPage({super.key, required this.trips, required this.currency});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Trip? selectedTrip;

  @override
  void initState() {
    super.initState();

    if (widget.trips.isNotEmpty) {
      selectedTrip = widget.trips.first;
    }
  }

  double getSpent(Trip trip) {
    return trip.expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> getCategoryTotals(Trip trip) {
    final totals = <String, double>{};

    for (final expense in trip.expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    return totals;
  }

  double getItineraryCost(Trip trip) {
    return trip.itinerary.fold(0.0, (sum, item) => sum + item.estimatedCost);
  }

  int getTripDuration(Trip trip) {
    final days = trip.endDate.difference(trip.startDate).inDays + 1;
    return days < 1 ? 1 : days;
  }

  List<String> getRecommendations(Trip trip) {
    final recommendations = <String>[];

    final spent = getSpent(trip);
    final remaining = trip.budget - spent;
    final rawUsage = trip.budget > 0 ? spent / trip.budget : 0.0;

    final categories = getCategoryTotals(trip);

    String highestCategory = '';
    double highestAmount = 0;

    for (final entry in categories.entries) {
      if (entry.value > highestAmount) {
        highestAmount = entry.value;
        highestCategory = entry.key;
      }
    }

    final itineraryCost = getItineraryCost(trip);
    final duration = getTripDuration(trip);
    final activityCount = trip.itinerary.length;
    final placeCount = trip.places.length;
    final expenseCount = trip.expenses.length;

    final today = DateTime.now();

    final tripStarted = !trip.startDate.isAfter(today);
    final tripFinished = trip.endDate.isBefore(today);

    if (trip.budget <= 0) {
      recommendations.add(
        'Set a valid trip budget to receive accurate spending insights.',
      );
    } else if (rawUsage >= 1.0) {
      recommendations.add(
        'Your spending has exceeded the trip budget by '
        '${formatMoney(-remaining, widget.currency)}. '
        'Consider reducing non-essential expenses.',
      );
    } else if (rawUsage >= 0.8) {
      recommendations.add(
        'You have used ${(rawUsage * 100).toStringAsFixed(0)}% of your budget. '
        'Keep the remaining ${formatMoney(remaining, widget.currency)} '
        'for essential expenses.',
      );
    } else if (rawUsage >= 0.6) {
      recommendations.add(
        'You have used ${(rawUsage * 100).toStringAsFixed(0)}% of your budget. '
        'Your spending is worth monitoring as the trip continues.',
      );
    } else if (spent == 0) {
      recommendations.add(
        'No expenses have been recorded yet. Add expenses to get '
        'personalized spending insights.',
      );
    } else {
      recommendations.add(
        'Your current spending is within a healthy range of the trip budget.',
      );
    }

    if (highestCategory.isNotEmpty && spent > 0) {
      final categoryShare = highestAmount / spent;

      if (categoryShare >= 0.5) {
        recommendations.add(
          '$highestCategory accounts for '
          '${(categoryShare * 100).toStringAsFixed(0)}% of your spending. '
          'Consider reviewing this category for possible savings.',
        );
      } else {
        recommendations.add(
          '$highestCategory is your highest spending category at '
          '${formatMoney(highestAmount, widget.currency)}.',
        );
      }
    }

    if (expenseCount == 0) {
      recommendations.add(
        'Start recording your travel expenses to maintain an accurate '
        'budget and spending history.',
      );
    } else if (duration > 0) {
      final expensesPerDay = expenseCount / duration;

      if (expensesPerDay >= 5) {
        recommendations.add(
          'You are recording expenses frequently. Review your spending '
          'regularly to avoid small purchases adding up.',
        );
      }
    }

    if (!tripFinished) {
      if (activityCount == 0) {
        recommendations.add(
          'Your itinerary is empty. Add activities to organize your '
          'trip schedule.',
        );
      } else {
        final activitiesPerDay = activityCount / duration;

        if (activitiesPerDay < 0.5) {
          recommendations.add(
            'Your itinerary has only $activityCount planned '
            '${activityCount == 1 ? 'activity' : 'activities'} for '
            '$duration days. Consider adding more activities.',
          );
        } else if (activitiesPerDay > 4) {
          recommendations.add(
            'Your itinerary is quite busy with '
            '${activitiesPerDay.toStringAsFixed(1)} activities per day. '
            'Leave some free time for unexpected plans.',
          );
        } else {
          recommendations.add(
            'Your itinerary currently has $activityCount planned '
            '${activityCount == 1 ? 'activity' : 'activities'} '
            'across $duration days.',
          );
        }
      }
    }

    if (itineraryCost > 0 && trip.budget > 0) {
      final plannedShare = itineraryCost / trip.budget;

      if (plannedShare >= 0.5) {
        recommendations.add(
          'Your planned activities have an estimated cost of '
          '${formatMoney(itineraryCost, widget.currency)}, which is '
          '${(plannedShare * 100).toStringAsFixed(0)}% of your total budget. '
          'Keep this in mind when adding new activities.',
        );
      }
    }

    if (!tripFinished) {
      if (placeCount == 0) {
        recommendations.add(
          'No places have been saved yet. Explore recommended places '
          'and add interesting locations to your trip.',
        );
      } else if (placeCount < 3) {
        recommendations.add(
          'You have saved $placeCount '
          '${placeCount == 1 ? 'place' : 'places'}. '
          'Consider exploring more destinations around your trip.',
        );
      }
    }

    if (tripFinished) {
      recommendations.add(
        'This trip has ended. Review your final expenses and compare '
        'your actual spending with the original budget.',
      );
    } else if (!tripStarted) {
      final daysUntilTrip = trip.startDate.difference(today).inDays;

      if (daysUntilTrip == 0) {
        recommendations.add(
          'Your trip starts today. Review your itinerary and budget '
          'before you begin.',
        );
      } else if (daysUntilTrip <= 7) {
        recommendations.add(
          'Your trip starts in $daysUntilTrip '
          '${daysUntilTrip == 1 ? 'day' : 'days'}. '
          'This is a good time to finalize your plans.',
        );
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Your trip data looks balanced. Keep updating your expenses '
        'and itinerary for better insights.',
      );
    }

    return recommendations;
  }

  IconData recommendationIcon(String recommendation) {
    final text = recommendation.toLowerCase();

    if (text.contains('budget') ||
        text.contains('spending') ||
        text.contains('expense')) {
      return Icons.account_balance_wallet_outlined;
    }

    if (text.contains('itinerary') || text.contains('activit')) {
      return Icons.event_note_outlined;
    }

    if (text.contains('place') ||
        text.contains('destination') ||
        text.contains('explor')) {
      return Icons.location_on_outlined;
    }

    if (text.contains('trip starts') || text.contains('finalize')) {
      return Icons.flight_takeoff_outlined;
    }

    return Icons.lightbulb_outline;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (color ?? colors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color ?? colors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.trips.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'No analytics yet',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a trip and start recording expenses '
                  'to see useful travel insights here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final trip = selectedTrip ?? widget.trips.first;

    final spent = getSpent(trip);
    final remaining = trip.budget - spent;
    final rawUsage = trip.budget > 0 ? spent / trip.budget : 0.0;
    final usage = rawUsage.clamp(0.0, 1.0);

    final categories = getCategoryTotals(trip);

    String highestCategory = 'None';
    double highestAmount = 0;

    for (final entry in categories.entries) {
      if (entry.value > highestAmount) {
        highestAmount = entry.value;
        highestCategory = entry.key;
      }
    }

    final recommendations = getRecommendations(trip);
    final duration = getTripDuration(trip);

    Color budgetColor;

    if (rawUsage >= 1.0) {
      budgetColor = colors.error;
    } else if (rawUsage >= 0.8) {
      budgetColor = Colors.orange;
    } else {
      budgetColor = colors.primary;
    }

    final budgetPercentage = rawUsage.isFinite
        ? '${(rawUsage * 100).toStringAsFixed(1)}%'
        : '0.0%';

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Trip selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Trip>(
                value: trip,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: widget.trips.map((t) {
                  return DropdownMenuItem<Trip>(
                    value: t,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            size: 19,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                t.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedTrip = value;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Trip header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Overview statistics
          Row(
            children: [
              _statCard(
                context,
                icon: Icons.calendar_month_outlined,
                label: 'Duration',
                value: '$duration days',
              ),
              const SizedBox(width: 10),
              _statCard(
                context,
                icon: Icons.receipt_long_outlined,
                label: 'Expenses',
                value: '${trip.expenses.length}',
              ),
              const SizedBox(width: 10),
              _statCard(
                context,
                icon: Icons.event_note_outlined,
                label: 'Activities',
                value: '${trip.itinerary.length}',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Budget overview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: budgetColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: budgetColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget Overview',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$budgetPercentage used',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(trip.budget, widget.currency),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: usage,
                    minHeight: 11,
                    color: budgetColor,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _budgetValue(
                        context,
                        'Spent',
                        formatMoney(spent, widget.currency),
                        budgetColor,
                      ),
                    ),
                    Expanded(
                      child: _budgetValue(
                        context,
                        remaining >= 0 ? 'Remaining' : 'Over budget',
                        remaining >= 0
                            ? formatMoney(remaining, widget.currency)
                            : formatMoney(-remaining, widget.currency),
                        remaining < 0 ? colors.error : colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Spending summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Summary',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _summaryRow(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Total Spent',
                  value: formatMoney(spent, widget.currency),
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  context,
                  icon: Icons.savings_outlined,
                  label: remaining >= 0 ? 'Remaining' : 'Over Budget',
                  value: remaining >= 0
                      ? formatMoney(remaining, widget.currency)
                      : formatMoney(-remaining, widget.currency),
                  valueColor: remaining < 0 ? colors.error : null,
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  context,
                  icon: Icons.trending_up_rounded,
                  label: 'Top Category',
                  value: highestCategory,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Category breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Category Breakdown',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (categories.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${categories.length} categories',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (categories.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 34,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No expense data available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else
                  ...categories.entries.map((entry) {
                    final percentage = spent > 0 ? entry.value / spent : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                formatMoney(entry.value, widget.currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: percentage.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: colors.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Smart recommendations
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Recommendations',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Insights based on your trip data',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...recommendations.asMap().entries.map((entry) {
                  final recommendation = entry.value;
                  final isLast = entry.key == recommendations.length - 1;

                  return Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            recommendationIcon(recommendation),
                            size: 18,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetValue(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}

List<String> getRecommendations(Trip trip) {
  final recommendations = <String>[];

  double total = 0;

  final Map<String, double> categoryTotals = {
    'Food': 0,
    'Transport': 0,
    'Hotel': 0,
    'Shopping': 0,
    'Other': 0,
  };

  for (var expense in trip.expenses) {
    total += expense.amount;

    if (categoryTotals.containsKey(expense.category)) {
      categoryTotals[expense.category] =
          categoryTotals[expense.category]! + expense.amount;
    }
  }

  if (total == 0) {
    recommendations.add(
      '💡 Add some expenses to receive personalized recommendations.',
    );
    return recommendations;
  }

  final budgetUsed = total / trip.budget;

  if (budgetUsed >= 1) {
    recommendations.add(
      '🚨 You have exceeded your trip budget. Consider reducing non-essential spending.',
    );
  } else if (budgetUsed >= 0.8) {
    recommendations.add(
      '⚠️ You have used more than 80% of your budget. Spend carefully for the rest of the trip.',
    );
  } else if (budgetUsed >= 0.5) {
    recommendations.add(
      '⚡ You have used more than half of your budget. Keep monitoring your expenses.',
    );
  } else {
    recommendations.add('✅ Your spending is currently within a healthy range.');
  }

  String highestCategory = 'None';
  double highestAmount = 0;

  categoryTotals.forEach((category, amount) {
    if (amount > highestAmount) {
      highestAmount = amount;
      highestCategory = category;
    }
  });

  if (highestCategory != 'None') {
    final percentage = highestAmount / total;

    if (percentage >= 0.4) {
      recommendations.add(
        '💡 $highestCategory is your largest expense category at ${(percentage * 100).toStringAsFixed(0)}% of total spending.',
      );
    }
  }

  final remaining = trip.budget - total;

  if (remaining > 0 && trip.expenses.length >= 3) {
    recommendations.add(
      '💰 You currently have ₹${remaining.toStringAsFixed(0)} remaining in your trip budget.',
    );
  }

  return recommendations;
}

class ProfilePage extends StatelessWidget {
  final Function(bool) onThemeChanged;
  final String currency;
  final List<Trip> trips;
  final Function(String) onCurrencyChanged;
  final String accentColorName;
  final Function(String) onAccentColorChanged;

  const ProfilePage({
    super.key,
    required this.onThemeChanged,
    required this.currency,
    required this.onCurrencyChanged,
    required this.trips,
    required this.accentColorName,
    required this.onAccentColorChanged,
  });

  String currencyName() {
    switch (currency) {
      case 'USD':
        return 'US Dollar (\$)';
      case 'EUR':
        return 'Euro (€)';
      case 'GBP':
        return 'British Pound (£)';
      case 'AED':
        return 'UAE Dirham (د.إ)';
      default:
        return 'Indian Rupee (₹)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          // Profile header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface.withValues(alpha: 0.75),
                  ),
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 45,
                      color: colors.onPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'TripC User',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Smart Travel Planner & Expense Manager',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flight_takeoff_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${trips.length} '
                        '${trips.length == 1 ? 'trip' : 'trips'} planned',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _sectionTitle(context, Icons.tune_rounded, 'Preferences'),

          const SizedBox(height: 10),

          // Preferences card
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              children: [
                // Currency
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(
                    context,
                    Icons.currency_exchange_rounded,
                  ),
                  title: const Text(
                    'Currency',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(currencyName()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (context) {
                        return SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 20),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  12,
                                ),
                                child: Text(
                                  'Select Currency',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              RadioGroup<String>(
                                groupValue: currency,
                                onChanged: (value) {
                                  if (value != null) {
                                    onCurrencyChanged(value);
                                    Navigator.pop(context);
                                  }
                                },
                                child: Column(
                                  children: [
                                    _currencyOption(
                                      'INR',
                                      'Indian Rupee (₹)',
                                      '₹',
                                    ),
                                    _currencyOption(
                                      'USD',
                                      'US Dollar (\$)',
                                      '\$',
                                    ),
                                    _currencyOption('EUR', 'Euro (€)', '€'),
                                    _currencyOption(
                                      'GBP',
                                      'British Pound (£)',
                                      '£',
                                    ),
                                    _currencyOption(
                                      'AED',
                                      'UAE Dirham (د.إ)',
                                      'د.إ',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                // Accent color
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(context, Icons.palette_outlined),
                  title: const Text(
                    'Accent Color',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(accentColorName),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (context) {
                        return SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 20),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  12,
                                ),
                                child: Text(
                                  'Choose Accent Color',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...[
                                'Teal',
                                'Blue',
                                'Purple',
                                'Pink',
                                'Orange',
                                'Red',
                                'Green',
                                'Indigo',
                              ].map(
                                (colorName) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _accentColor(colorName),
                                  ),
                                  title: Text(colorName),
                                  trailing: accentColorName == colorName
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: colors.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    onAccentColorChanged(colorName);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                // Notifications
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(
                    context,
                    Icons.notifications_outlined,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Manage travel reminders'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    bool enabled = await NotificationService.instance
                        .isEnabled();

                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Notifications'),
                          content: StatefulBuilder(
                            builder: (context, setState) {
                              return SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enable Notifications'),
                                subtitle: const Text(
                                  'Trip and itinerary reminders',
                                ),
                                value: enabled,
                                onChanged: (value) async {
                                  await NotificationService.instance.setEnabled(
                                    value,
                                  );

                                  if (value) {
                                    await NotificationService.instance
                                        .syncAllTrips(trips);
                                  }

                                  setState(() {
                                    enabled = value;
                                  });
                                },
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                // Dark mode
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(
                    context,
                    isDark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDark ? 'Dark theme is enabled' : 'Light theme is enabled',
                  ),
                  trailing: Switch(value: isDark, onChanged: onThemeChanged),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _sectionTitle(context, Icons.info_outline_rounded, 'About'),

          const SizedBox(height: 10),

          // About card
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(
                    context,
                    Icons.travel_explore_rounded,
                  ),
                  title: const Text(
                    'About TripC',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Smart Travel Planner & Expense Manager',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'TripC',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Smart Travel Planner & Expense Manager',
                    );
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(context, Icons.code_outlined),
                  title: const Text(
                    'Version',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('1.0.0'),
                ),

                const Divider(height: 1),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: _iconContainer(
                    context,
                    Icons.notifications_active_outlined,
                  ),
                  title: const Text(
                    'Test Notification',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Send a test notification'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await NotificationService.instance.sendTestNotification();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test notification sent'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Footer
          Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  size: 27,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'TripC',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Plan smarter. Travel better.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _iconContainer(BuildContext context, IconData icon) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: colors.primary, size: 21),
    );
  }

  Widget _currencyOption(String value, String title, String symbol) {
    return RadioListTile<String>(
      value: value,
      title: Text(title),
      secondary: CircleAvatar(
        radius: 20,
        child: Text(
          symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _accentColor(String name) {
    switch (name) {
      case 'Blue':
        return Colors.blue;
      case 'Purple':
        return Colors.purple;
      case 'Pink':
        return Colors.pink;
      case 'Orange':
        return Colors.orange;
      case 'Red':
        return Colors.red;
      case 'Green':
        return Colors.green;
      case 'Indigo':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }
}

class ExplorePage extends StatefulWidget {
  final Trip trip;
  final List<Trip> trips;
  final String currency;

  const ExplorePage({
    super.key,
    required this.trip,
    required this.trips,
    required this.currency,
  });

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String search = '';

  List<Map<String, dynamic>> get places {
    final destination = widget.trip.destination.toLowerCase();

    if (destination.contains('goa')) {
      return [
        {
          'name': 'Baga Beach',
          'description': 'Popular beach known for water sports and nightlife.',
          'cost': 500.0,
          'icon': Icons.beach_access,
        },
        {
          'name': 'Fort Aguada',
          'description': 'Historic Portuguese fort with beautiful sea views.',
          'cost': 100.0,
          'icon': Icons.account_balance,
        },
        {
          'name': 'Basilica of Bom Jesus',
          'description': 'Historic church and UNESCO World Heritage site.',
          'cost': 50.0,
          'icon': Icons.church,
        },
        {
          'name': 'Dudhsagar Falls',
          'description': 'Famous waterfall surrounded by lush greenery.',
          'cost': 800.0,
          'icon': Icons.water,
        },
        {
          'name': 'Anjuna Beach',
          'description': 'Scenic beach famous for its relaxed atmosphere.',
          'cost': 300.0,
          'icon': Icons.waves,
        },
      ];
    }

    return [
      {
        'name': 'City Sightseeing',
        'description': 'Explore popular attractions around the destination.',
        'cost': 500.0,
        'icon': Icons.location_city,
      },
      {
        'name': 'Local Market',
        'description': 'Discover local food, shopping and culture.',
        'cost': 300.0,
        'icon': Icons.storefront,
      },
      {
        'name': 'Historical Landmark',
        'description': 'Visit an important historical attraction.',
        'cost': 200.0,
        'icon': Icons.account_balance,
      },
    ];
  }

  double getRecommendedCost() {
    return places.fold(
      0,
      (sum, place) => sum + (place['cost'] as num).toDouble(),
    );
  }

  int getAlreadyAddedCount() {
    return places.where((place) {
      return widget.trip.places.any((saved) => saved.name == place['name']);
    }).length;
  }

  int getScheduledCount() {
    return places.where((place) {
      return widget.trip.itinerary.any(
        (item) =>
            item.place.toLowerCase() == place['name'].toString().toLowerCase(),
      );
    }).length;
  }

  double getRemainingBudget() {
    final spent = widget.trip.expenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    return widget.trip.budget - spent;
  }

  String getSmartInsight() {
    final totalRecommendations = places.length;
    final added = getAlreadyAddedCount();
    final scheduled = getScheduledCount();
    final remaining = totalRecommendations - added;
    final recommendedCost = getRecommendedCost();
    final remainingBudget = getRemainingBudget();

    if (totalRecommendations == 0) {
      return 'No recommendations are available for this destination yet.';
    }

    if (remainingBudget <= 0) {
      return 'Your trip budget is already fully used. Review your expenses before adding more places.';
    }

    if (remainingBudget < recommendedCost * 0.5) {
      return 'Many recommended places may be difficult to fit into your remaining budget. Prioritize the attractions you value most.';
    }

    if (added == totalRecommendations) {
      if (scheduled == totalRecommendations) {
        return 'You have explored all recommendations and scheduled them. Your destination planning is well organized.';
      }

      return 'You have saved all recommended places. Consider adding the remaining destinations to your itinerary.';
    }

    if (added == 0) {
      return 'You have not saved any recommended places yet. Explore the options and add destinations that match your interests.';
    }

    if (remaining == 1) {
      return 'Only one recommended place remains unexplored. Take a look before finalizing your plans.';
    }

    if (added >= totalRecommendations * 0.7) {
      return 'You have explored most recommendations. Focus on your priorities and leave enough time for each destination.';
    }

    if (scheduled > 0 && scheduled < added) {
      return 'Some saved places are already scheduled. Consider organizing the remaining saved destinations into your itinerary.';
    }

    return '$remaining recommended places are still unexplored. Compare them with your budget and available travel time.';
  }

  IconData getSmartInsightIcon() {
    final totalRecommendations = places.length;
    final added = getAlreadyAddedCount();
    final scheduled = getScheduledCount();
    final remainingBudget = getRemainingBudget();
    final recommendedCost = getRecommendedCost();

    if (totalRecommendations == 0) {
      return Icons.explore_off;
    }

    if (remainingBudget <= 0 || remainingBudget < recommendedCost * 0.5) {
      return Icons.account_balance_wallet;
    }

    if (added == totalRecommendations && scheduled == totalRecommendations) {
      return Icons.check_circle;
    }

    if (added == 0) {
      return Icons.explore;
    }

    return Icons.lightbulb;
  }

  Color getSmartInsightColor(ColorScheme colors) {
    final added = getAlreadyAddedCount();
    final scheduled = getScheduledCount();
    final remainingBudget = getRemainingBudget();
    final recommendedCost = getRecommendedCost();

    if (remainingBudget <= 0 || remainingBudget < recommendedCost * 0.5) {
      return Colors.orange;
    }

    if (added == places.length && scheduled == places.length) {
      return Colors.green;
    }

    return colors.primary;
  }

  Future<void> addPlace(Map<String, dynamic> place) async {
    final exists = widget.trip.places.any((p) => p.name == place['name']);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place already added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.trip.places.add(
      Place(
        name: place['name'],
        description: place['description'],
        estimatedCost: place['cost'],
        priority: 'Medium',
      ),
    );

    await StorageService.saveTrips(widget.trips);

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${place['name']} added to your trip'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> addToItinerary(Map<String, dynamic> place) async {
    final item = await Navigator.push<ItineraryItem>(
      context,
      slideRoute(
        AddItineraryPage(
          trip: widget.trip,
          currency: widget.currency,
          place: Place(
            name: place['name'],
            description: place['description'],
            estimatedCost: place['cost'],
            priority: 'Medium',
          ),
        ),
      ),
    );

    if (item != null) {
      widget.trip.itinerary.add(item);

      await StorageService.saveTrips(widget.trips);

      await NotificationService.instance.syncItineraryReminders(widget.trip);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${place['name']} added to itinerary'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final filtered = places.where((place) {
      return place['name'].toString().toLowerCase().contains(
        search.toLowerCase(),
      );
    }).toList();

    final recommendedCost = getRecommendedCost();
    final addedCount = getAlreadyAddedCount();
    final scheduledCount = getScheduledCount();
    final remainingBudget = getRemainingBudget();

    final smartColor = getSmartInsightColor(colors);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Places')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore ${widget.trip.destination}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Discover places worth adding to your trip.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Smart Explore Insight
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(getSmartInsightIcon(), color: smartColor, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Explore Insight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(getSmartInsight()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Explore Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryItem(
                      context,
                      Icons.place_outlined,
                      'Recommended',
                      '${places.length}',
                    ),
                  ),
                  Expanded(
                    child: _summaryItem(
                      context,
                      Icons.bookmark_outline,
                      'Saved',
                      '$addedCount',
                    ),
                  ),
                  Expanded(
                    child: _summaryItem(
                      context,
                      Icons.event_outlined,
                      'Scheduled',
                      '$scheduledCount',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (recommendedCost > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recommended places total: '
                        '${formatMoney(recommendedCost, widget.currency)}',
                      ),
                    ),
                    Text(
                      'Remaining: '
                      '${formatMoney(remainingBudget, widget.currency)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 22),

          TextField(
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search places',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          search = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (value) {
              setState(() {
                search = value;
              });
            },
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Text(
                'Recommended Places',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${filtered.length} found',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off,
                      size: 42,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No places found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try searching for another place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            ...filtered.map((place) {
              final placeName = place['name'].toString();

              final placeDescription = place['description'].toString();

              final placeCost = (place['cost'] as num).toDouble();

              final placeIcon = place['icon'] as IconData;

              final alreadyAdded = widget.trip.places.any(
                (p) => p.name == placeName,
              );

              final alreadyScheduled = widget.trip.itinerary.any(
                (item) => item.place.toLowerCase() == placeName.toLowerCase(),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              placeIcon,
                              color: colors.primary,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  placeName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  placeDescription,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payments_outlined, size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  formatMoney(placeCost, widget.currency),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (alreadyScheduled)
                            Row(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Scheduled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            )
                          else if (alreadyAdded)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Added',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: alreadyAdded
                                  ? null
                                  : () => addPlace(place),
                              icon: Icon(
                                alreadyAdded ? Icons.check : Icons.add,
                              ),
                              label: Text(
                                alreadyAdded ? 'Added to Trip' : 'Add to Trip',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: alreadyScheduled
                                  ? null
                                  : () => addToItinerary(place),
                              icon: Icon(
                                alreadyScheduled
                                    ? Icons.event_available
                                    : Icons.event_outlined,
                              ),
                              label: Text(
                                alreadyScheduled ? 'Scheduled' : 'Itinerary',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 21, color: colors.primary),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ItineraryPage extends StatefulWidget {
  final Trip trip;
  final String currency;

  const ItineraryPage({super.key, required this.trip, required this.currency});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  Future<void> addItem() async {
    final item = await Navigator.push<ItineraryItem>(
      context,
      slideRoute(
        AddItineraryPage(trip: widget.trip, currency: widget.currency),
      ),
    );

    if (item != null) {
      setState(() {
        widget.trip.itinerary.add(item);
      });

      await StorageService.saveTrip(widget.trip);
      await NotificationService.instance.syncItineraryReminders(widget.trip);
    }
  }

  Future<void> editItem(ItineraryItem item) async {
    final result = await Navigator.push<ItineraryItem>(
      context,
      slideRoute(
        AddItineraryPage(
          trip: widget.trip,
          item: item,
          currency: widget.currency,
        ),
      ),
    );

    if (result != null) {
      setState(() {});

      await StorageService.saveTrip(widget.trip);
      await NotificationService.instance.syncItineraryReminders(widget.trip);
    }
  }

  Future<void> deleteItem(ItineraryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text('Are you sure you want to delete "${item.place}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        widget.trip.itinerary.remove(item);
      });

      await StorageService.saveTrip(widget.trip);
      await NotificationService.instance.syncItineraryReminders(widget.trip);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String getSmartInsight(List<ItineraryItem> items, double estimatedTotal) {
    if (items.isEmpty) {
      return 'Your itinerary is empty. Add activities to start planning your trip.';
    }

    final tripDays =
        widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;

    final activitiesPerDay = items.length / tripDays;

    if (activitiesPerDay < 1) {
      return 'Your itinerary has fewer than one activity per day. '
          'Consider adding a few more activities.';
    }

    final dailyCounts = <String, int>{};

    for (final item in items) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    if (dailyCounts.values.any((count) => count >= 5)) {
      return 'Some days are very busy. Consider leaving free time '
          'between activities.';
    }

    if (widget.trip.budget > 0 && estimatedTotal > widget.trip.budget * 0.3) {
      return 'Planned activities use a significant part of your budget. '
          'Review activity costs before your trip.';
    }

    if (items.length == 1) {
      return 'Only one activity is planned. Add more activities '
          'to build a more complete itinerary.';
    }

    if (items.length >= tripDays * 3) {
      return 'Your itinerary is well planned, but make sure to leave '
          'enough time for travel and rest.';
    }

    return 'Your itinerary looks well balanced for the trip.';
  }

  IconData getSmartInsightIcon(
    List<ItineraryItem> items,
    double estimatedTotal,
  ) {
    if (items.isEmpty) {
      return Icons.event_note_outlined;
    }

    final tripDays =
        widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;

    final activitiesPerDay = items.length / tripDays;

    if (activitiesPerDay < 1) {
      return Icons.add_task_rounded;
    }

    final dailyCounts = <String, int>{};

    for (final item in items) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    if (dailyCounts.values.any((count) => count >= 5)) {
      return Icons.schedule_outlined;
    }

    if (widget.trip.budget > 0 && estimatedTotal > widget.trip.budget * 0.3) {
      return Icons.payments_outlined;
    }

    if (items.length == 1) {
      return Icons.add_circle_outline;
    }

    if (items.length >= tripDays * 3) {
      return Icons.balance_outlined;
    }

    return Icons.check_circle_outline_rounded;
  }

  Color getSmartInsightColor(
    List<ItineraryItem> items,
    double estimatedTotal,
    ColorScheme colors,
  ) {
    if (items.isEmpty) {
      return colors.onSurfaceVariant;
    }

    final tripDays =
        widget.trip.endDate.difference(widget.trip.startDate).inDays + 1;

    final activitiesPerDay = items.length / tripDays;

    if (activitiesPerDay < 1) {
      return colors.tertiary;
    }

    final dailyCounts = <String, int>{};

    for (final item in items) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    if (dailyCounts.values.any((count) => count >= 5)) {
      return Colors.orange;
    }

    if (widget.trip.budget > 0 && estimatedTotal > widget.trip.budget * 0.3) {
      return colors.tertiary;
    }

    if (items.length == 1) {
      return colors.tertiary;
    }

    return colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final items = [...widget.trip.itinerary];

    items.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);

      if (dateCompare != 0) {
        return dateCompare;
      }

      final hourCompare = a.time.hour.compareTo(b.time.hour);

      if (hourCompare != 0) {
        return hourCompare;
      }

      return a.time.minute.compareTo(b.time.minute);
    });

    double estimatedTotal = 0;

    for (final item in items) {
      estimatedTotal += item.estimatedCost;
    }

    final smartInsight = getSmartInsight(items, estimatedTotal);

    final smartIcon = getSmartInsightIcon(items, estimatedTotal);

    final smartColor = getSmartInsightColor(items, estimatedTotal, colors);

    return Scaffold(
      appBar: AppBar(title: const Text('Itinerary')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_note, color: colors.primary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activities', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 45,
                  width: 1,
                  color: colors.outline.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.payments_outlined, color: colors.primary),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Estimated Cost',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatMoney(estimatedTotal, widget.currency),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Smart Itinerary Insight
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: smartColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: smartColor.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: smartColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(smartIcon, size: 20, color: smartColor),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Itinerary Insight',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: smartColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          smartInsight,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Row(
              children: [
                Text(
                  'Planned Activities',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  Text(
                    '${items.length} '
                    '${items.length == 1 ? 'activity' : 'activities'}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_available,
                              size: 48,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No activities yet',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start planning your trip by adding your first activity.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Activity'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${item.date.day}',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                    ),
                                    Text(
                                      _monthName(item.date.month),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.place,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 15,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.time.format(context),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${item.date.day}/'
                                          '${item.date.month}/'
                                          '${item.date.year}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),

                                    if (item.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],

                                    const SizedBox(height: 8),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.secondaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        formatMoney(
                                          item.estimatedCost,
                                          widget.currency,
                                        ),
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    editItem(item);
                                  } else if (value == 'delete') {
                                    deleteItem(item);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined),
                                        SizedBox(width: 10),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline),
                                        SizedBox(width: 10),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}

class AddItineraryPage extends StatefulWidget {
  final Trip trip;
  final String currency;
  final Place? place;
  final ItineraryItem? item;

  const AddItineraryPage({
    super.key,
    required this.trip,
    required this.currency,
    this.place,
    this.item,
  });

  @override
  State<AddItineraryPage> createState() => _AddItineraryPageState();
}

class _AddItineraryPageState extends State<AddItineraryPage> {
  final placeName = TextEditingController();
  final description = TextEditingController();
  final cost = TextEditingController();

  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();

  bool get editing => widget.item != null;

  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      placeName.text = widget.item!.place;
      description.text = widget.item!.description;
      cost.text = widget.item!.estimatedCost.toStringAsFixed(0);
      date = widget.item!.date;
      time = widget.item!.time;
    } else if (widget.place != null) {
      placeName.text = widget.place!.name;
      description.text = widget.place!.description;
      cost.text = widget.place!.estimatedCost.toStringAsFixed(0);
    }
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: date,
    );

    if (selected != null) {
      setState(() {
        date = selected;
      });
    }
  }

  Future<void> pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: time);

    if (selected != null) {
      setState(() {
        time = selected;
      });
    }
  }

  void saveItem() {
    final p = placeName.text.trim();
    final d = description.text.trim();
    final c = double.tryParse(cost.text);

    if (p.isEmpty || c == null || c < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid place and cost'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (editing) {
      widget.item!.place = p;
      widget.item!.description = d;
      widget.item!.date = date;
      widget.item!.time = time;
      widget.item!.estimatedCost = c;

      Navigator.pop(context, widget.item);
    } else {
      Navigator.pop(
        context,
        ItineraryItem(
          place: p,
          description: d,
          date: date,
          time: time,
          estimatedCost: c,
        ),
      );
    }
  }

  @override
  void dispose() {
    placeName.dispose();
    description.dispose();
    cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Activity' : 'Add Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    editing ? Icons.edit_calendar : Icons.event_available,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      editing
                          ? 'Update your planned activity'
                          : 'Add something exciting to your trip',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Activity Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: placeName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Place / Activity',
                hintText: 'e.g. Baga Beach',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What do you plan to do?',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 42),
                  child: Icon(Icons.notes_outlined),
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Estimated Cost',
                hintText: '0',
                prefixText: '${currencySymbol(widget.currency)} ',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Schedule',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text('${date.day}/${date.month}/${date.year}'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: pickTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        prefixIcon: Icon(Icons.access_time_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(time.format(context)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saveItem,
                icon: Icon(editing ? Icons.save_outlined : Icons.add),
                label: Text(editing ? 'Update Activity' : 'Add Activity'),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class PlacesPage extends StatefulWidget {
  final Trip trip;
  final String currency;

  const PlacesPage({super.key, required this.trip, required this.currency});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  Future<void> editPlace(Place place) async {
    final result = await Navigator.push<Place>(
      context,
      slideRoute(AddPlacePage(trip: widget.trip, place: place)),
    );

    if (result != null) {
      setState(() {});
      await StorageService.saveTrip(widget.trip);
    }
  }

  Future<void> deletePlace(Place place) async {
    final colors = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 32),
        title: const Text('Delete Place?'),
        content: Text(
          'Are you sure you want to remove "${place.name}" from your saved places?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        widget.trip.places.remove(place);
      });

      await StorageService.saveTrip(widget.trip);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  double getEstimatedTotal() {
    return widget.trip.places.fold(
      0.0,
      (sum, place) => sum + place.estimatedCost,
    );
  }

  int getHighPriorityCount() {
    return widget.trip.places
        .where((place) => place.priority.toLowerCase() == 'high')
        .length;
  }

  int getAddedToItineraryCount() {
    return widget.trip.places.where((place) {
      return widget.trip.itinerary.any(
        (item) => item.place.toLowerCase() == place.name.toLowerCase(),
      );
    }).length;
  }

  bool isScheduled(Place place) {
    return widget.trip.itinerary.any(
      (item) => item.place.toLowerCase() == place.name.toLowerCase(),
    );
  }

  String getSmartInsight() {
    final places = widget.trip.places;
    final totalCost = getEstimatedTotal();
    final budget = widget.trip.budget;
    final highPriority = getHighPriorityCount();
    final itineraryCount = getAddedToItineraryCount();

    if (places.isEmpty) {
      return 'Start exploring! Add some places you would like to visit during this trip.';
    }

    if (places.length == 1) {
      return 'You have only one place saved. Add a few more attractions to give your trip more variety.';
    }

    if (budget > 0 && totalCost > budget * 0.30) {
      return 'Saved places may use a large part of your budget. Review estimated costs before finalizing your plans.';
    }

    if (highPriority >= 3) {
      return 'You have several high-priority places. Consider adding the most important ones to your itinerary first.';
    }

    if (highPriority > 0 && itineraryCount == 0) {
      return 'You have priority places saved but none are scheduled yet. Consider adding them to your itinerary.';
    }

    if (itineraryCount == places.length && places.length >= 3) {
      return 'All saved places are scheduled. Your destination planning looks well organized.';
    }

    if (itineraryCount < places.length) {
      final remaining = places.length - itineraryCount;
      return '$remaining saved place${remaining == 1 ? '' : 's'} still need to be added to your itinerary.';
    }

    if (places.length >= 5) {
      return 'You have a good variety of places saved. Make sure to leave enough time between activities.';
    }

    return 'Your saved places look balanced. Keep adding destinations that match your interests and budget.';
  }

  IconData getSmartInsightIcon() {
    final places = widget.trip.places;
    final totalCost = getEstimatedTotal();
    final budget = widget.trip.budget;
    final highPriority = getHighPriorityCount();
    final itineraryCount = getAddedToItineraryCount();

    if (places.isEmpty) {
      return Icons.explore_rounded;
    }

    if (budget > 0 && totalCost > budget * 0.30) {
      return Icons.account_balance_wallet_rounded;
    }

    if (highPriority > 0 && itineraryCount < places.length) {
      return Icons.priority_high_rounded;
    }

    if (itineraryCount == places.length && places.length >= 3) {
      return Icons.check_circle_rounded;
    }

    return Icons.lightbulb_rounded;
  }

  Color getSmartInsightColor(ColorScheme colors) {
    final places = widget.trip.places;
    final totalCost = getEstimatedTotal();
    final budget = widget.trip.budget;
    final highPriority = getHighPriorityCount();
    final itineraryCount = getAddedToItineraryCount();

    if (places.isEmpty) {
      return colors.primary;
    }

    if (budget > 0 && totalCost > budget * 0.30) {
      return Colors.orange;
    }

    if (highPriority > 0 && itineraryCount < places.length) {
      return Colors.deepOrange;
    }

    if (itineraryCount == places.length && places.length >= 3) {
      return Colors.green;
    }

    return colors.primary;
  }

  Future<void> addPlace() async {
    final place = await Navigator.push<Place>(
      context,
      slideRoute(AddPlacePage(trip: widget.trip)),
    );

    if (place != null) {
      setState(() {});
      await StorageService.saveTrip(widget.trip);
    }
  }

  Future<void> addToItinerary(Place place) async {
    final item = await Navigator.push<ItineraryItem>(
      context,
      slideRoute(
        AddItineraryPage(
          trip: widget.trip,
          currency: widget.currency,
          place: place,
        ),
      ),
    );

    if (item != null) {
      widget.trip.itinerary.add(item);

      await StorageService.saveTrip(widget.trip);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to itinerary'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final places = widget.trip.places;

    final estimatedTotal = getEstimatedTotal();
    final highPriority = getHighPriorityCount();
    final itineraryCount = getAddedToItineraryCount();
    final smartColor = getSmartInsightColor(colors);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Places',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: places.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _buildHero(
                  context,
                  places.length,
                  estimatedTotal,
                  itineraryCount,
                ),

                const SizedBox(height: 14),

                _buildStats(
                  context,
                  estimatedTotal,
                  highPriority,
                  itineraryCount,
                ),

                const SizedBox(height: 14),

                _buildInsight(context, smartColor),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Text(
                      'Saved places',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${places.length} total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ...places.map(
                  (place) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPlaceCard(context, place),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPlace,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Place'),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    int count,
    double estimatedTotal,
    int scheduled,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.explore_rounded, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count saved ${count == 1 ? 'place' : 'places'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  scheduled == count
                      ? 'Everything is planned in your itinerary'
                      : '$scheduled of $count added to your itinerary',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    double estimatedTotal,
    int highPriority,
    int scheduled,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            Icons.payments_outlined,
            'Estimated',
            formatMoney(estimatedTotal, widget.currency),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            Icons.priority_high_rounded,
            'High Priority',
            '$highPriority',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            Icons.event_available_rounded,
            'Scheduled',
            '$scheduled',
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsight(BuildContext context, Color smartColor) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: smartColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: smartColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: smartColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(getSmartInsightIcon(), color: smartColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Places Insight',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getSmartInsight(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, Place place) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final scheduled = isScheduled(place);
    final priority = place.priority.toLowerCase();

    final Color priorityColor;

    if (priority == 'high') {
      priorityColor = colors.error;
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = colors.primary;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          _badge(
                            context,
                            icon: priority == 'high'
                                ? Icons.priority_high_rounded
                                : Icons.flag_outlined,
                            label: '${place.priority} priority',
                            color: priorityColor,
                          ),
                          if (scheduled)
                            _badge(
                              context,
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Scheduled',
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (place.description.trim().isNotEmpty)
              Text(
                place.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 19,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated cost',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(place.estimatedCost, widget.currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => editPlace(place),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => deletePlace(place),
                  tooltip: 'Delete place',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.error,
                    backgroundColor: colors.errorContainer,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: scheduled ? null : () => addToItinerary(place),
                icon: Icon(
                  scheduled
                      ? Icons.check_circle_outline_rounded
                      : Icons.event_available_rounded,
                ),
                label: Text(
                  scheduled ? 'Already in Itinerary' : 'Add to Itinerary',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primaryContainer, colors.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_rounded,
                  size: 42,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Discover your trip',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save places you want to visit and build them into your itinerary.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: addPlace,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Your First Place'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Add your must-visit places first, then schedule them from this page.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AddPlacePage extends StatefulWidget {
  final Trip trip;
  final Place? place;

  const AddPlacePage({super.key, required this.trip, this.place});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final name = TextEditingController();
  final description = TextEditingController();
  final cost = TextEditingController();

  String priority = 'Medium';

  @override
  void initState() {
    super.initState();

    if (widget.place != null) {
      name.text = widget.place!.name;
      description.text = widget.place!.description;
      cost.text = widget.place!.estimatedCost.toString();
      priority = widget.place!.priority;
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    cost.dispose();
    super.dispose();
  }

  void savePlace() {
    final placeName = name.text.trim();

    if (placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a place name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final duplicate = widget.trip.places.any(
      (place) =>
          place.name.trim().toLowerCase() == placeName.toLowerCase() &&
          place != widget.place,
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This place is already added to the trip'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final estimatedCost = double.tryParse(cost.text.trim()) ?? 0;

    if (widget.place != null) {
      widget.place!.name = placeName;
      widget.place!.description = description.text.trim();
      widget.place!.estimatedCost = estimatedCost;
      widget.place!.priority = priority;

      Navigator.pop(context, widget.place);
    } else {
      final place = Place(
        name: placeName,
        description: description.text.trim(),
        estimatedCost: estimatedCost,
        priority: priority,
      );

      widget.trip.places.add(place);

      Navigator.pop(context, place);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place == null ? 'Add Place' : 'Edit Place'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Place Name',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: description,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller: cost,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated Cost',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 15),

          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Low', child: Text('Low')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'High', child: Text('High')),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                priority = value;
              });
            },
          ),

          const SizedBox(height: 25),

          ElevatedButton(
            onPressed: savePlace,
            child: Text(widget.place == null ? 'Save Place' : 'Update Place'),
          ),
        ],
      ),
    );
  }
}
