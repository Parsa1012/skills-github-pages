package android.content;
public interface SharedPreferences {
    boolean contains(String key);
    int getInt(String key, int fallback);
    long getLong(String key, long fallback);
    boolean getBoolean(String key, boolean fallback);
    String getString(String key, String fallback);
    Editor edit();
    interface Editor {
        Editor putInt(String key, int value);
        Editor putLong(String key, long value);
        Editor putBoolean(String key, boolean value);
        Editor putString(String key, String value);
        void apply();
    }
}
