## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.** { *; }

## Google Sign-In & Auth
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.auth.api.credentials.** { *; }

## Smart Auth (if present)
-keep class fman.ge.smart_auth.** { *; }
-dontwarn fman.ge.smart_auth.**
