# Babblelon

A mobile game built with Flutter and Flame engine.

## Project Overview

Babblelon is a cross-platform mobile game that uses the Flutter framework and Flame game engine. The game features dynamic gameplay, user authentication with Supabase, and a modern, responsive UI.

## Technologies Used

- **Flutter**: UI framework for building natively compiled applications
- **Flame**: 2D game engine for Flutter
- **Supabase**: Backend as a Service (BaaS) for authentication and data storage
- **Provider**: State management solution
- **GitHub Actions**: CI/CD for automated testing and deployment

## Getting Started

### Prerequisites

- Flutter SDK 3.19.0 or higher
- Dart SDK 3.2.0 or higher
- A Supabase account
- Android Studio/VS Code with Flutter extensions

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/babblelon.git
   cd babblelon
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Update Supabase credentials:
   Create a `.env` file in the root directory and add your Supabase URL and anon key:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. Run the app:
   ```
   flutter run
   ```

## Project Structure

- `lib/game/`: Contains all Flame game-related code
- `lib/screens/`: Flutter UI screens
- `lib/widgets/`: Reusable UI components
- `lib/models/`: Data models
- `lib/services/`: Service classes for API interactions
- `lib/utils/`: Utility functions and helpers
- `lib/constants/`: App-wide constants
- `assets/`: Images, audio, and other resources

## Development Workflow

1. Create a new branch for your feature: `git checkout -b feature/your-feature-name`
2. Make your changes and commit them: `git commit -m "Add your message here"`
3. Push to the branch: `git push origin feature/your-feature-name`
4. Create a Pull Request

## Testing

Run the test suite with:
```
flutter test
```

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 