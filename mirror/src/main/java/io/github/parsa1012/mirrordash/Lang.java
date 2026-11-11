package io.github.parsa1012.mirrordash;

/**
 * The four interface languages. The game is not tied to the phone's locale: the player picks
 * one here, it is stored in preferences, and every screen is rebuilt from
 * {@link Strings#of(Lang)}.
 */
public enum Lang {

    FA("فارسی", true),
    EN("English", false),
    AR("العربية", true),
    ES("Español", false);

    private final String nativeName;
    private final boolean rtl;

    Lang(String nativeName, boolean rtl) {
        this.nativeName = nativeName;
        this.rtl = rtl;
    }

    /** Name of the language written in that language, for the language picker. */
    public String nativeName() {
        return nativeName;
    }

    public boolean rtl() {
        return rtl;
    }

    public static Lang fromName(String name) {
        if (name != null) {
            for (Lang value : values()) {
                if (value.name().equals(name)) {
                    return value;
                }
            }
        }
        return FA;
    }
}
