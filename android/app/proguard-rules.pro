# R8 was off until 2026-09-15 because nobody had written keep rules and the
# fear was kotlinx.serialization / ktor / Supabase reflection breaking in a
# Release build nobody could test. These are those rules.

# ---- kotlinx.serialization -------------------------------------------------
# The compiler plugin generates a `Companion.serializer()` and a `$$serializer`
# for every @Serializable class. R8 cannot see the reflective lookup, so both
# have to be kept, along with the annotation itself.
-keepattributes *Annotation*, InnerClasses, Signature, RuntimeVisible*Annotations, EnclosingMethod
-dontnote kotlinx.serialization.**

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Every @Serializable type in the app, plus its generated serializer.
-keep,includedescriptorclasses class com.pick1.app.**$$serializer { *; }
-keepclassmembers class com.pick1.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.pick1.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}
# The model holders themselves: field names ARE the JSON keys.
-keep class com.pick1.app.data.model.** { *; }

# ---- ktor / okhttp ---------------------------------------------------------
-dontwarn org.slf4j.**
-dontwarn kotlinx.coroutines.debug.**
-dontwarn io.ktor.**
-keep class io.ktor.** { *; }
-keepclassmembers class io.ktor.** { volatile <fields>; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ---- Supabase --------------------------------------------------------------
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**

# ---- Firebase messaging ----------------------------------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ---- Play Billing ----------------------------------------------------------
-keep class com.android.billingclient.** { *; }

# ---- Coroutines ------------------------------------------------------------
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# ---- Enums are looked up by name in a few `when` branches ------------------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
