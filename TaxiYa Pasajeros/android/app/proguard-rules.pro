# Flutter & Android Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Mapbox SDK
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# RevenueCat & Google Play Billing
-keep class com.revenuecat.purchases.** { *; }
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.revenuecat.purchases.**
-dontwarn com.amazon.device.iap.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Flutter Local Notifications & Gson
-keep class com.dexterous.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
