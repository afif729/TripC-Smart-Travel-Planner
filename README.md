# TripC — Smart Travel Planner & Expense Manager

TripC is a Flutter-based mobile application designed to help users organize trips, plan activities, manage travel expenses, and monitor budgets in one place.

## Features

- **Trip Management:** Create and manage multiple trips with destination, dates, and budget details.
- **Place Planning:** Organize places to visit and review their priorities and estimated costs.
- **Itinerary Management:** Schedule activities and organize travel plans by date and time.
- **Expense Tracking:** Record travel expenses and categorize spending.
- **Budget Monitoring:** Review total expenditure, budget usage, and remaining funds.
- **Planned vs. Actual Analysis:** Compare estimated itinerary costs with recorded expenses.
- **Financial Analytics:** Review spending summaries and category-wise expenses.
- **Currency Options:** Choose from the currencies supported by the application.
- **Local Data Persistence:** Save trip data locally using SharedPreferences and JSON serialization.
- **User Interface:** Material Design 3-based Flutter interface.

## Technology Stack

- **Frontend:** Flutter and Dart
- **UI:** Material Design 3
- **Local Storage:** SharedPreferences
- **Data Serialization:** JSON
- **Development Tools:** Flutter SDK, Android Studio or Visual Studio Code

## Getting Started

### Prerequisites

Install the Flutter SDK and configure an appropriate development environment. For Android development, install Android Studio and the Android SDK.

Flutter installation guide: https://docs.flutter.dev/get-started/install

### Run the Application

1. Clone this repository.
2. Open a terminal in the project directory.
3. Install the project dependencies.
4. Run the application on a connected device or emulator.

```bash
git clone https://github.com/afif729/TripC-Smart-Travel-Planner.git
cd TripC-Smart-Travel-Planner
flutter pub get
flutter run
```

If the repository has a different name, replace the clone URL and directory name with the actual repository details.

## Project Structure

```text
lib/          Application source code
test/         Automated tests
android/      Android platform configuration
ios/          iOS platform configuration
web/          Web platform configuration
windows/      Windows platform configuration
linux/        Linux platform configuration
macos/        macOS platform configuration
```

## Storage and Limitations

The current implementation stores trip information locally on the device. Cloud synchronization and collaborative trip editing are not currently provided. Analytical insights are based on programmed calculations and rules rather than a trained machine-learning model.

Platform-specific testing may be required before deploying to devices beyond the development environment.

## Future Improvements

- Cloud backup and synchronization
- Collaborative trip planning
- Expanded automated testing
- Additional travel analytics and planning capabilities
- Broader device and platform testing

## Academic Project

TripC is developed as a software engineering project demonstrating the integration of travel planning, itinerary management, expense tracking, and budget analysis in a single application.
