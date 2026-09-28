# App-specific R8 rules.
#
# Flutter, Firebase, Play Services and the plugins ship their own consumer
# rules, so broad "-keep class com.google.firebase.** { *; }"-style rules are
# not needed and only stop R8 from shrinking those libraries (audit PERF-09).

# Flutter's embedding references Play Core deferred-components classes that
# this app does not include; silence R8's missing-class errors for them.
-dontwarn com.google.android.play.core.**

# flutter_secure_storage uses reflection-sensitive crypto classes.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep generic signatures and annotations for reflection-based libraries.
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses
