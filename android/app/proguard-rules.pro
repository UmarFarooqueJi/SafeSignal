# Proguard rules for SafeSignal
# Suppress missing class warnings for unused ML Kit language models
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**

# Keep ML Kit components
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
