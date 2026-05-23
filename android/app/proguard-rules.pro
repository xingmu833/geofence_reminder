# Baidu Map SDK references this optional advanced-permission class from some
# artifacts, but the class is not packaged by the Flutter SDK dependency.
-dontwarn com.baidu.mapsdkplatform.comapi.util.MapSDKAdvancedPermission

# Baidu Map Flutter SDK uses native code and reflection internally. Keep its
# Android wrapper classes stable in release builds to avoid startup crashes
# after R8 shrinking.
-keep class com.baidu.** { *; }
-keep class vi.com.** { *; }
-dontwarn com.baidu.**
-dontwarn vi.com.**
