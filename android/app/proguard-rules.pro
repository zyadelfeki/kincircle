# Keep TensorFlow Lite GPU and NNAPI delegate classes used by tflite_flutter
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep Firebase and Google Play services models (avoid stripping required annotations/classes)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Flutter bindings and generated plugin registrant
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Keep classes referenced by reflection
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}
