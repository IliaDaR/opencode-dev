# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep setters so SharedPreferences works
-keepclassmembers class * {
    *** *(...);
    void set*(***);
}

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
