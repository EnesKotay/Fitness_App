# ============================================================
# FitMentor — ProGuard / R8 Kuralları
# ============================================================

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio / OkHttp (HTTP client)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# JSON serialization — model sınıflarını koru
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Google Play Billing (in_app_purchase)
-keep class com.android.vending.billing.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# mobile_scanner (ML Kit barcode)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# image_cropper
-keep class com.yalantis.ucrop.** { *; }

# Genel Android korumaları
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Enum koruması
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Serializable koruması
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
