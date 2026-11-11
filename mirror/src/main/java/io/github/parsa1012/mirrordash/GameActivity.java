package io.github.parsa1012.mirrordash;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Toast;
import android.widget.TextView;

/**
 * Hosts the game surface and every overlay: main menu (with the logo), settings
 * (difficulty / day-night / sound), in-game HUD, pause panel and game-over panel.
 *
 * <p>Everything is built in code on purpose — there are no layout XML files, so the theme can
 * be swapped at runtime without a resource qualifier. Persian copy lives in TextViews so
 * Android handles shaping and bidi, and the whole UI is drawn with the bundled Vazirmatn
 * font. Buttons are plain TextViews with a state-list background: the platform Button style
 * applies its own insets and padding that misalign Persian glyphs.</p>
 *
 * <p>The layout direction is pinned to RTL because the interface is Persian only; on a phone
 * set to English the rows would otherwise be laid out left-to-right and read backwards.</p>
 */
public class GameActivity extends Activity {

    /** Theme switches recreate the activity; this flag makes the settings page come back. */
    private static boolean reopenSettingsAfterRecreate;

    private FrameLayout root;
    private GameView gameView;
    private MusicPlayer music;

    private Lang lang;
    private Strings strings;
    private TextView recordsText;
    private Theme theme;
    private Typeface typeRegular;
    private Typeface typeBold;

    private Difficulty difficulty;
    private boolean nightMode;
    private boolean soundEnabled;
    private boolean musicEnabled;

    private LinearLayout hud;
    private TextView pauseButton;
    private TextView hudBest;

    private TextView hint;
    private boolean hintConsumed;

    private View scrim;
    private View menuOverlay;
    private TextView menuBest;
    private TextView menuDifficulty;
    private TextView menuCoins;
    private View shopOverlay;
    private LinearLayout shopItems;
    private TextView shopBalance;

    private View settingsOverlay;
    private View stageOverlay;
    private LinearLayout stageGrid;
    private VictoryConfetti confetti;
    private TextView nextStageButton;
    private TextView chipEasy;
    private TextView chipNormal;
    private TextView chipHard;
    private TextView chipNight;
    private TextView chipDay;
    private TextView chipSoundOn;
    private TextView chipSoundOff;
    private TextView chipMusicOn;
    private TextView chipMusicOff;

    private View pausePanel;
    private TextView pauseSound, pauseMusic;
    private SeekBar pauseSoundVolume, pauseMusicVolume;
    private android.widget.Switch pauseEffects, settingsEffects;
    private SeekBar settingsSoundVolume, settingsMusicVolume;
    private View gameOverPanel;
    private TextView gameOverTitle;
    private TextView gameOverScore;
    private TextView gameOverRows;
    private TextView gameOverBest;

    private boolean pauseOnResume;
    private GameEngine.Mode mode = GameEngine.Mode.ENDLESS;
    private int selectedStage = 1;
    private String tr(String fa, String en, String ar, String es) {
        switch (lang) { case EN: return en; case AR: return ar; case ES: return es; default: return fa; }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        GamePrefs.migrate(this);
        boolean initialStageBonus = GamePrefs.claimInitialStageBonus(this);
        lang = GamePrefs.lang(this);
        strings = Strings.of(lang);
        getWindow().getDecorView().setLayoutDirection(lang.rtl() ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR);

        nightMode = GamePrefs.nightMode(this);
        soundEnabled = GamePrefs.soundEnabled(this);
        musicEnabled = GamePrefs.musicEnabled(this);
        music = new MusicPlayer(this, musicEnabled);
        music.setVolume(GamePrefs.volume(this, true));
        music.setScene(MusicPlayer.Scene.MENU);
        difficulty = GamePrefs.difficulty(this);
        theme = Theme.of(nightMode);
        // Same colour as the canvas, so rotation/recreate never flashes the platform grey.
        getWindow().setBackgroundDrawable(new GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] {theme.background, theme.background}));
        typeBold = Renderer.load(this, "fonts/Vazirmatn-Bold.ttf", Typeface.BOLD);
        typeRegular = Renderer.load(this, "fonts/Vazirmatn-Regular.ttf", Typeface.NORMAL);

        root = new FrameLayout(this);
        gameView = new GameView(this);
        gameView.setTheme(theme);
        gameView.setDifficulty(difficulty);
        applyAccessibility();
        gameView.setSoundEnabled(soundEnabled);
        gameView.setSoundVolume(GamePrefs.volume(this, false));
        gameView.setAppearance(GamePrefs.appearance(this, false), GamePrefs.appearance(this, true));
        gameView.setBallPalette(GamePrefs.selectedPalette(this));
        root.addView(gameView, matchParent());

        buildHud();
        buildHint();
        buildScrim();
        buildMenu();
        buildStageMenu();
        buildShop();
        buildSettings();
        confetti = new VictoryConfetti(this);
        root.addView(confetti, matchParent());
        buildPausePanel();
        buildGameOverPanel();

        gameView.setCoinListener(() -> refreshLabels());

        gameView.setGameOverListener(new GameView.GameOverListener() {
            @Override
            public void onGameOver(int score, int rowsCleared, long millis) {
                showGameOver(score, rowsCleared, millis);
            }
        });

        setContentView(root);
        hideSystemBars();
        refreshLabels();
        refreshSettingChips();
        if (!GamePrefs.helpSeen(this)) root.post(() -> { if (!isFinishing()) showHelp(); });
        if (initialStageBonus) Toast.makeText(this, tr("مرحلهٔ اول باز است: ۲۰ سکه هدیه!", "Stage 1 unlocked: 20 bonus coins!", "المرحلة الأولى مفتوحة: ٢٠ عملة هدية!", "Nivel 1 desbloqueado: ¡20 monedas de regalo!"), Toast.LENGTH_LONG).show();

        if (reopenSettingsAfterRecreate) {
            reopenSettingsAfterRecreate = false;
            showSettings();
        }
    }

    // ------------------------------------------------------------------ menu / HUD

    private void buildHud() {
        hud = new LinearLayout(this);
        hud.setOrientation(LinearLayout.HORIZONTAL);
        hud.setGravity(Gravity.CENTER_VERTICAL);
        hud.setPadding(dp(14), dp(22), dp(14), 0);
        hud.setVisibility(View.GONE);

        pauseButton = new TextView(this);
        pauseButton.setText("II");
        pauseButton.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        pauseButton.setTypeface(typeBold);
        pauseButton.setTextColor(theme.textSecondary);
        pauseButton.setGravity(Gravity.CENTER);
        pauseButton.setIncludeFontPadding(false);
        pauseButton.setPadding(dp(14), dp(9), dp(14), dp(9));
        pauseButton.setBackground(buttonBackground(theme.chipBackground, theme.panelStroke));
        pauseButton.setClickable(true);
        pauseButton.setFocusable(true);
        pauseButton.setContentDescription(strings.pauseDescription);
        pauseButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showPause();
            }
        });
        hud.addView(pauseButton);

        hudBest = new TextView(this);
        hudBest.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        hudBest.setTypeface(typeRegular);
        hudBest.setTextColor(theme.textMuted);
        hudBest.setGravity(Gravity.END);
        hudBest.setIncludeFontPadding(false);
        hud.addView(hudBest, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP;
        root.addView(hud, params);
    }

    private void buildHint() {
        hint = new TextView(this);
        hint.setText(strings.hint);
        hint.setTextColor(theme.textSecondary);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        hint.setTypeface(typeRegular);
        hint.setIncludeFontPadding(false);
        hint.setGravity(Gravity.CENTER);
        hint.setVisibility(View.GONE);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        params.topMargin = dp(128);
        root.addView(hint, params);
    }

    private void buildScrim() {
        scrim = new View(this);
        scrim.setBackgroundColor(theme.scrim);
        scrim.setClickable(true);
        scrim.setVisibility(View.GONE);
        root.addView(scrim, matchParent());
    }

    private void buildMenu() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground());
        overlay.setClickable(true);
        menuOverlay = overlay;

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(28), dp(16), dp(28), dp(16));

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.logo);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        logo.setContentDescription(strings.logoDescription);
        content.addView(logo, new LinearLayout.LayoutParams(dp(104), dp(104)));

        TextView title = label(strings.appName, 34, true, theme.textPrimary);
        content.addView(title, wrapWithTopMargin(10));

        TextView tagline = label(strings.tagline, 14, false, theme.playerBlue);
        content.addView(tagline, wrapWithTopMargin(6));

        menuBest = label(strings.bestLine, 14, true, theme.playerRed);
        content.addView(menuBest, wrapWithTopMargin(16));

        menuCoins = label("", 14, true, 0xffffcc53);
        content.addView(menuCoins, wrapWithTopMargin(8));

        menuDifficulty = label(strings.difficultyLine, 12, false, theme.textMuted);
        content.addView(menuDifficulty, wrapWithTopMargin(6));

        LinearLayout modes = new LinearLayout(this);
        modes.setOrientation(LinearLayout.HORIZONTAL);
        modes.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams modesParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        modesParams.topMargin = dp(20);
        content.addView(modes, modesParams);
        TextView endless = modeTile("∞", tr("رکورد بی‌پایان", "Endless record", "الرقم اللانهائي", "Récord infinito"), false);
        LinearLayout.LayoutParams firstMode = new LinearLayout.LayoutParams(0, dp(112), 1f);
        firstMode.setMarginEnd(dp(5));
        modes.addView(endless, firstMode);
        endless.setOnClickListener(v -> { mode = GameEngine.Mode.ENDLESS; startGame(); });
        TextView stages = modeTile("◆", tr("بازی مرحله‌ای", "Stages", "المراحل", "Niveles"), true);
        LinearLayout.LayoutParams secondMode = new LinearLayout.LayoutParams(0, dp(112), 1f);
        secondMode.setMarginStart(dp(5));
        modes.addView(stages, secondMode);
        stages.setOnClickListener(v -> chooseStage());

        TextView appearance = secondaryAction("◉  " + tr("ظاهر", "Appearance", "المظهر", "Apariencia"));
        content.addView(appearance, fullWidthButtonParams(10));
        appearance.setOnClickListener(v -> showShop());

        TextView practice = secondaryAction(tr("تمرین", "Practice", "تدريب", "Práctica"));
        content.addView(practice, fullWidthButtonParams(10));
        practice.setOnClickListener(v -> { mode = GameEngine.Mode.PRACTICE; startGame(); });

        TextView settings = secondaryAction(strings.settings);
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        settingsParams.topMargin = dp(10);
        content.addView(settings, settingsParams);
        settings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showSettings();
            }
        });

        // Reserve the top corner for the vertical tools; scroll on short displays or with
        // large system text instead of overlapping the logo and actions.
        ScrollView menuScroll = new ScrollView(this);
        menuScroll.setFillViewport(true);
        menuScroll.setClipToPadding(false);
        LinearLayout menuCentre = new LinearLayout(this);
        menuCentre.setOrientation(LinearLayout.VERTICAL);
        menuCentre.setGravity(Gravity.CENTER);
        int availableWidth = Math.max(dp(180), getResources().getDisplayMetrics().widthPixels - dp(32));
        menuCentre.addView(content, new LinearLayout.LayoutParams(
                Math.min(dp(340), availableWidth), ViewGroup.LayoutParams.WRAP_CONTENT));
        menuScroll.addView(menuCentre, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        FrameLayout.LayoutParams contentParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        contentParams.topMargin = dp(176);
        overlay.addView(menuScroll, contentParams);

        addMenuTools(overlay);
        root.addView(overlay, matchParent());
    }

    private void addMenuTools(FrameLayout overlay) {
        LinearLayout tools = new LinearLayout(this);
        tools.setOrientation(LinearLayout.VERTICAL);
        tools.setPadding(dp(12), dp(12), dp(12), 0);
        addTool(tools, "i", strings.infoDescription, () -> showHelp());
        addTool(tools, "A", strings.languageDescription, () -> showLanguageDialog());
        addTool(tools, "@", strings.aboutDescription, () -> showTextDialog(strings.aboutTitle,
                strings.creatorLabel + ": " + strings.creatorName + "\n" + strings.emailLabel + ":\n" + strings.creatorEmail + "\n\n" + strings.aboutBody + "\n\n" + strings.versionLabel + ": " + BuildConfig.VERSION_NAME));
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.END);
        overlay.addView(tools, lp);
    }

    private void addTool(LinearLayout row, String text, String description, Runnable action) {
        TextView b = actionBase(text, 16, true);
        b.setContentDescription(description);
        b.setTextColor(theme.textPrimary);
        b.setBackground(buttonBackground(theme.chipBackground, theme.panelStroke));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(48), dp(48));
        lp.topMargin = dp(6);
        row.addView(b, lp);
        b.setOnClickListener(v -> action.run());
    }

    /** Readable, scrollable first-run guide, also available from the menu's info button. */
    private void showHelp() {
        gameView.playUiMenu();
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(20), dp(12), dp(20), dp(18));
        content.setBackgroundColor(0xfff4f7fc);
        helpSection(content, "01  " + tr("کنترل دو توپ", "Control both balls", "التحكم بالكرتين", "Controla las dos bolas"),
            tr("انگشت را روی صفحه به چپ و راست بکش. توپ دوم آینه‌ای حرکت می‌کند؛ هر دو توپ باید از شکاف رد شوند.", "Drag left or right anywhere on the screen. The second ball mirrors the first; both must pass through the openings.", "اسحب إصبعك يميناً ويساراً. تتحرك الكرة الثانية بصورة معكوسة؛ يجب أن تعبر الكرتان الفتحات.", "Desliza el dedo a izquierda o derecha. La segunda bola se mueve en espejo; ambas deben cruzar los huecos."));
        helpSection(content, "02  " + tr("آینه‌ها و نشانه‌ها", "Mirrors and markers", "المرايا والعلامات", "Espejos y señales"),
            tr("آینه‌ها از بالا می‌آیند. یک شکاف یعنی توپ‌ها نزدیک وسط؛ دو شکاف یعنی دورتر از هم. فلش‌ها حرکت افقی و دو خط باز و بسته شدن شکاف را نشان می‌دهند. بعضی آینه‌ها در ادامه برق می‌زنند.", "Mirrors descend from above. One gap brings the balls together; two gaps pull them apart. Arrows mark sliding gaps and two bars mark expanding gaps. A few later mirrors shimmer.", "تنزل المرايا من الأعلى. فتحة واحدة تقرّب الكرتين وفتحتان تبعدانهما. الأسهم للحركة الجانبية والخطان للفتحة المتغيرة. بعض المرايا تلمع لاحقاً.", "Los espejos bajan. Un hueco junta las bolas y dos las separan. Las flechas indican movimiento lateral y las barras, apertura variable. Algunos espejos brillan más adelante."));
        helpSection(content, "03  " + tr("حالت‌های بازی", "Game modes", "أوضاع اللعب", "Modos de juego"),
            tr("بی‌پایان: تا برخورد بازی کن و برای هر سختی رکورد جدا ثبت کن. مرحله‌ای: از همهٔ آینه‌ها و خط پایان عبور کن تا مرحلهٔ بعد باز شود. تمرین: برخورد پایان بازی نیست و رکورد ثبت نمی‌شود.", "Endless: survive to set a separate record for each difficulty. Stages: clear all mirrors and cross the finish to unlock the next stage. Practice: collisions do not end the run or set records.", "اللامتناهي: سجّل رقماً لكل صعوبة. المراحل: اعبر المرايا وخط النهاية لفتح المرحلة التالية. التدريب: الاصطدام لا ينهي اللعب ولا يسجل رقماً.", "Infinito: consigue un récord por dificultad. Niveles: supera los espejos y cruza la meta para desbloquear el siguiente. Práctica: los choques no terminan la partida ni cuentan como récord."));
        helpSection(content, "04  " + tr("سکه و فروشگاه", "Coins and shop", "العملات والمتجر", "Monedas y tienda"),
            tr("سکه‌های مرحله‌ای را با هر کدام از توپ‌ها جمع کن. باز شدن هر مرحله ۲۰ سکه جایزه دارد. برد دوبارهٔ مراحل ۱ و ۲ به‌ترتیب ۵ و ۸ سکه می‌دهد؛ مراحل ۳ تا ۵ در مسیر سکه دارند. در فروشگاه ظاهر، قیمت و رکورد لازم هر آیتم را ببین.", "Collect stage coins with either ball. Each newly unlocked stage gives 20 coins. Replaying stages 1 and 2 gives 5 and 8 coins on victory; stages 3–5 have coins along the way. Check each shop item's price and required record.", "اجمع العملات بأي كرة. فتح كل مرحلة يمنح ٢٠ عملة. الفوز مجدداً في ١ و٢ يمنح ٥ و٨؛ المراحل ٣–٥ فيها عملات في المسار. تحقق من السعر والرقم المطلوب في المتجر.", "Recoge monedas con cualquiera de las bolas. Cada nivel desbloqueado da 20 monedas. Al repetir los niveles 1 y 2 ganas 5 y 8 al vencer; los niveles 3–5 tienen monedas en el camino. Consulta el precio y el récord de cada artículo."));
        helpSection(content, "05  " + tr("توقف و تنظیمات", "Pause and settings", "الإيقاف والإعدادات", "Pausa y ajustes"),
            tr("با دکمهٔ توقف، بازی را ادامه بده، دوباره شروع کن یا به منو برو. صدا، موسیقی و کاهش جلوه‌ها در توقف و تنظیمات در دسترس‌اند. برای بازگشت به این راهنما دکمهٔ i منو را بزن.", "Pause to resume, restart or return to the menu. Sound, music and reduced effects are available in pause and settings. Reopen this guide with the menu's i button.", "أوقف اللعبة للمتابعة أو الإعادة أو العودة للقائمة. الصوت والموسيقى وتقليل المؤثرات متاحة في الإيقاف والإعدادات. اضغط i لفتح الدليل مجدداً.", "Pausa para continuar, reiniciar o volver al menú. El sonido, la música y los efectos reducidos están en pausa y ajustes. Pulsa i en el menú para volver a esta guía."));
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(false); scroll.addView(content);
        android.app.AlertDialog dialog = new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle(strings.helpTitle).setView(scroll).setPositiveButton(tr("متوجه شدم", "Got it", "فهمت", "Entendido"), (d, w) -> {}).create();
        dialog.setOnDismissListener(d -> GamePrefs.setHelpSeen(this));
        dialog.setOnShowListener(d -> dialog.getWindow().getDecorView().setLayoutDirection(lang.rtl() ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR));
        dialog.show();
    }

    private void helpSection(LinearLayout container, String title, String body) {
        LinearLayout section = new LinearLayout(this);
        section.setOrientation(LinearLayout.VERTICAL); section.setPadding(dp(15), dp(12), dp(15), dp(12));
        GradientDrawable bg = new GradientDrawable(); bg.setColor(0xffffffff); bg.setCornerRadius(dp(14)); bg.setStroke(dp(1), 0xffd7e4f5);
        section.setBackground(bg);
        TextView heading = label(title, 16, true, 0xff194c80); heading.setGravity(Gravity.START);
        TextView text = label(body, 14, false, 0xff29384b); text.setGravity(Gravity.START);
        text.setTextDirection(lang.rtl() ? View.TEXT_DIRECTION_RTL : View.TEXT_DIRECTION_LTR);
        section.addView(heading, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        LinearLayout.LayoutParams paragraph = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); paragraph.topMargin = dp(6);
        section.addView(text, paragraph);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); params.bottomMargin = dp(10);
        container.addView(section, params);
    }

    private void showTextDialog(String title, String body) {
        gameView.playUiMenu();
        TextView message = label(body, 15, false, android.graphics.Color.rgb(30, 35, 45));
        message.setGravity(Gravity.START);
        message.setTextDirection(lang.rtl() ? View.TEXT_DIRECTION_RTL : View.TEXT_DIRECTION_LTR);
        message.setPadding(dp(22), dp(12), dp(22), dp(12));
        ScrollView scroller = new ScrollView(this);
        scroller.addView(message);
        android.app.AlertDialog dialog = new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle(title).setView(scroller).setPositiveButton(strings.close, (d, which) -> {}).create();
        dialog.setOnShowListener(d -> dialog.getWindow().getDecorView().setLayoutDirection(lang.rtl() ? View.LAYOUT_DIRECTION_RTL : View.LAYOUT_DIRECTION_LTR));
        dialog.show();
    }

    private void showLanguageDialog() {
        gameView.playUiMenu();
        Lang[] languages = Lang.values();
        String[] names = new String[languages.length];
        for (int i = 0; i < languages.length; i++) names[i] = languages[i].nativeName();
        new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT).setTitle(strings.languageTitle)
                .setSingleChoiceItems(names, lang.ordinal(), (dialog, which) -> {
                    GamePrefs.setLang(this, languages[which]);
                    dialog.dismiss();
                    recreate();
                }).setNegativeButton(strings.close, (d, which) -> {}).show();
    }

    private String difficultyName(Difficulty d) {
        return d == Difficulty.EASY ? strings.easy : d == Difficulty.HARD ? strings.hard : strings.normal;
    }

    // ------------------------------------------------------------------- settings

    private void buildSettings() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground());
        overlay.setClickable(true);
        overlay.setVisibility(View.GONE);
        settingsOverlay = overlay;

        ScrollView scroller = new ScrollView(this);
        scroller.setFillViewport(true);
        scroller.setClipToPadding(false);

        LinearLayout centring = new LinearLayout(this);
        centring.setOrientation(LinearLayout.VERTICAL);
        centring.setGravity(Gravity.CENTER);
        centring.setPadding(dp(20), dp(20), dp(20), dp(20));
        scroller.addView(centring, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout card = card(theme, dp(340));
        card.setVisibility(View.VISIBLE);
        card.setAlpha(1f);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        card.setPadding(dp(20), dp(18), dp(20), dp(18));
        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        centring.addView(card, new LinearLayout.LayoutParams(
                Math.min(dp(340), screenWidth - dp(40)),
                ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = label("⚙  " + strings.settings, 24, true, theme.textPrimary);
        card.addView(title);
        card.addView(label(tr("بازی را برای خودت تنظیم کن", "Make the game yours", "اضبط اللعبة كما تحب", "Personaliza tu juego"), 12, false, theme.textMuted), wrapWithTopMargin(4));

        LinearLayout difficultyGroup = settingsSection(card, "◈  " + strings.difficulty);
        chipEasy = chipLabel(strings.easy); chipNormal = chipLabel(strings.normal); chipHard = chipLabel(strings.hard);
        difficultyGroup.addView(chipRow(chipEasy, chipNormal, chipHard), matchWidthWithTopMargin(8));

        LinearLayout appearanceGroup = settingsSection(card, "◐  " + strings.appearance);
        chipNight = chipLabel(strings.night); chipDay = chipLabel(strings.day);
        appearanceGroup.addView(chipRow(chipNight, chipDay), matchWidthWithTopMargin(8));

        LinearLayout audioGroup = settingsSection(card, "♫  " + tr("صدا و موسیقی", "SOUND & MUSIC", "الصوت والموسيقى", "SONIDO Y MÚSICA"));
        chipSoundOn = chipLabel(strings.on); chipSoundOff = chipLabel(strings.off);
        audioGroup.addView(sectionLabel(strings.sound), wrapWithTopMargin(8));
        audioGroup.addView(chipRow(chipSoundOn, chipSoundOff), matchWidthWithTopMargin(8));
        addVolumeControl(audioGroup, false);
        chipMusicOn = chipLabel(strings.on); chipMusicOff = chipLabel(strings.off);
        audioGroup.addView(sectionLabel(strings.music), wrapWithTopMargin(12));
        audioGroup.addView(chipRow(chipMusicOn, chipMusicOff), matchWidthWithTopMargin(8));
        addVolumeControl(audioGroup, true);

        LinearLayout accessGroup = settingsSection(card, "✦  " + tr("نمایش و کنترل", "DISPLAY & CONTROL", "العرض والتحكم", "PANTALLA Y CONTROL"));
        addAccessibilityControls(accessGroup);

        LinearLayout recordsGroup = settingsSection(card, "◆  " + strings.records);
        recordsText = label("", 13, false, theme.textSecondary);
        recordsGroup.addView(recordsText, wrapWithTopMargin(8));
        TextView statistics = secondaryAction(strings.statistics);
        recordsGroup.addView(statistics, fullWidthButtonParams(12));
        statistics.setOnClickListener(v -> showStatistics());
        TextView collection = secondaryAction(strings.collection);
        recordsGroup.addView(collection, fullWidthButtonParams(8));
        collection.setOnClickListener(v -> showCollection());

        TextView back = primaryAction(strings.back);
        card.addView(back, fullWidthButtonParams(20));
        back.setOnClickListener(v -> hideSettings());

        chipEasy.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.EASY);
            }
        });
        chipNormal.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.NORMAL);
            }
        });
        chipHard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectDifficulty(Difficulty.HARD);
            }
        });
        chipNight.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectNight(true);
            }
        });
        chipDay.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectNight(false);
            }
        });
        chipSoundOn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectSound(true);
            }
        });
        chipSoundOff.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectSound(false);
            }
        });

        chipMusicOn.setOnClickListener(v -> selectMusic(true));
        chipMusicOff.setOnClickListener(v -> selectMusic(false));

        overlay.addView(scroller, matchParent());
        root.addView(overlay, matchParent());
    }

    private GradientDrawable tileBackground(int start, int end, int stroke) {
        GradientDrawable bg = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                new int[] {start, end});
        bg.setCornerRadius(dp(20));
        bg.setStroke(dp(1.5f), stroke);
        return bg;
    }

    private TextView modeTile(String symbol, String text, boolean stages) {
        TextView tile = actionBase(symbol + "\n" + text, 16, true);
        android.text.SpannableString styled = new android.text.SpannableString(symbol + "\n" + text);
        styled.setSpan(new android.text.style.RelativeSizeSpan(1.9f), 0, symbol.length(), 0);
        tile.setText(styled);
        tile.setTextColor(0xfff8fbff);
        tile.setLineSpacing(dp(5), 1f);
        tile.setBackground(stages ? tileBackground(0xff6240a0, 0xff392455, 0xffba94ff)
                : tileBackground(0xff176995, 0xff153556, 0xff65d8ff));
        tile.setContentDescription(text);
        return tile;
    }

    /** Dedicated, scrollable level-select screen, rebuilt when returning after a win. */
    private void buildStageMenu() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground());
        overlay.setClickable(true);
        overlay.setVisibility(View.GONE);
        stageOverlay = overlay;
        ScrollView scroller = new ScrollView(this);
        scroller.setFillViewport(true);
        LinearLayout centre = new LinearLayout(this);
        centre.setOrientation(LinearLayout.VERTICAL);
        centre.setGravity(Gravity.CENTER_HORIZONTAL);
        centre.setPadding(dp(24), dp(34), dp(24), dp(30));
        scroller.addView(centre);
        TextView eyebrow = label("◆  " + tr("ماجراجویی همزاد", "TWIN ADVENTURE", "مغامرة التوأم", "AVENTURA GEMELA") + "  ◆", 12, true, theme.playerBlue);
        centre.addView(eyebrow);
        centre.addView(label(tr("انتخاب مرحله", "Choose a stage", "اختر المرحلة", "Elige un nivel"), 27, true, theme.textPrimary), wrapWithTopMargin(10));
        centre.addView(label(tr("هر پیروزی، راه مرحلهٔ بعد را باز می‌کند", "Win to unlock the next stage", "افز لفتح المرحلة التالية", "Gana para desbloquear el siguiente nivel"), 13, false, theme.textSecondary), wrapWithTopMargin(9));
        stageGrid = new LinearLayout(this);
        stageGrid.setOrientation(LinearLayout.VERTICAL);
        int width = Math.max(dp(180), Math.min(dp(380), getResources().getDisplayMetrics().widthPixels - dp(48)));
        LinearLayout.LayoutParams gridParams = new LinearLayout.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT);
        gridParams.topMargin = dp(24);
        centre.addView(stageGrid, gridParams);
        TextView back = secondaryAction(strings.back);
        LinearLayout.LayoutParams backParams = new LinearLayout.LayoutParams(width, dp(50));
        backParams.topMargin = dp(20);
        centre.addView(back, backParams);
        back.setOnClickListener(v -> closeStageMenu());
        overlay.addView(scroller, matchParent());
        root.addView(overlay, matchParent());
    }

    private void chooseStage() {
        gameView.playUiMenu();
        int unlocked = GamePrefs.unlockedStage(this);
        stageGrid.removeAllViews();
        for (int i = 1; i <= 5; i += 2) {
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            for (int n = i; n <= Math.min(5, i + 1); n++) {
                final int number = n;
                boolean open = number <= unlocked;
                String place = number == 1 ? tr("آغاز", "Origins", "البداية", "Inicio")
                    : number == 2 ? tr("بیابان", "Desert", "الصحراء", "Desierto")
                    : number == 3 ? tr("شهر", "City", "المدينة", "Ciudad")
                    : number == 4 ? tr("فانتزی", "Fantasy", "الخيال", "Fantasía")
                    : tr("فضا", "Space", "الفضاء", "Espacio");
                String name = tr("مرحله ", "Stage ", "المرحلة ", "Nivel ") + number + " · " + place;
                String status = open ? (GamePrefs.stageComplete(this, number) ? tr("✓ تکمیل‌شده", "✓ Complete", "✓ مكتملة", "✓ Completado") : tr("آمادهٔ بازی", "Ready to play", "جاهزة للعب", "Listo para jugar"))
                    : tr("🔒 قفل", "🔒 Locked", "🔒 مقفلة", "🔒 Bloqueado");
                TextView tile = actionBase((open ? "✦" : "🔒") + "\n" + name + "\n" + status, 15, true);
                android.text.SpannableString iconText = new android.text.SpannableString(tile.getText());
                int iconEnd = iconText.toString().indexOf('\n');
                if (iconEnd > 0) iconText.setSpan(new android.text.style.RelativeSizeSpan(1.5f), 0, iconEnd, 0);
                tile.setText(iconText);
                tile.setLineSpacing(dp(4), 1f);
                tile.setTextColor(open ? 0xfff6f7ff : 0xffaab3c1);
                tile.setBackground(open ? tileBackground(0xff3b568e, 0xff29234d, 0xff8fa9ff)
                        : tileBackground(0xff303b4a, 0xff202633, 0xff566170));
                tile.setEnabled(open);
                tile.setContentDescription(name + ", " + status + ", " + (10 + 5 * number) + tr(" ردیف", " rows", " صفاً", " filas"));
                LinearLayout.LayoutParams item = new LinearLayout.LayoutParams(0, dp(120), 1f);
                if (n == i) item.setMarginEnd(dp(5)); else item.setMarginStart(dp(5));
                row.addView(tile, item);
                if (open) tile.setOnClickListener(v -> { mode = GameEngine.Mode.STAGES; selectedStage = number; startGame(); });
            }
            if (i == 5) row.addView(new View(this), new LinearLayout.LayoutParams(0, 1, 1f));
            LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            if (i > 1) rowParams.topMargin = dp(10);
            stageGrid.addView(row, rowParams);
        }
        stageOverlay.setVisibility(View.VISIBLE);
    }

    private void closeStageMenu() {
        gameView.playUiClick();
        stageOverlay.setVisibility(View.GONE);
    }

    private String coinLabel() {
        return tr("سکه‌ها: ", "Coins: ", "العملات: ", "Monedas: ") + GamePrefs.coins(this) + " $";
    }

    /** Separate, scrollable shop; the existing record-unlocked patterns remain in settings. */
    private void buildShop() {
        FrameLayout overlay = new FrameLayout(this);
        overlay.setBackground(menuBackground()); overlay.setClickable(true); overlay.setVisibility(View.GONE);
        shopOverlay = overlay;
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL); content.setGravity(Gravity.CENTER_HORIZONTAL);
        content.setPadding(dp(24), dp(34), dp(24), dp(32));
        scroll.addView(content);
        content.addView(label("◉  " + tr("ظاهر توپ‌ها", "Ball appearance", "مظهر الكرات", "Aspecto de las bolas"), 25, true, theme.textPrimary));
        shopBalance = label("", 16, true, 0xffffcc53);
        content.addView(shopBalance, wrapWithTopMargin(12));
        content.addView(label(tr("برای هر خرید، هم سکه و هم رکورد درجهٔ مشخص‌شده لازم است. خریدها دائمی‌اند.", "Each purchase requires both coins and the specified difficulty record. Purchases are permanent.", "يتطلب الشراء العملات والرقم المحدد في درجة الصعوبة. المشتريات دائمة.", "Cada compra requiere monedas y el récord de la dificultad indicada. Las compras son permanentes."), 13, false, theme.textSecondary), wrapWithTopMargin(8));
        shopItems = new LinearLayout(this); shopItems.setOrientation(LinearLayout.VERTICAL);
        int width = Math.max(dp(180), Math.min(dp(380), getResources().getDisplayMetrics().widthPixels - dp(48)));
        LinearLayout.LayoutParams itemsParams = new LinearLayout.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT);
        itemsParams.topMargin = dp(18); content.addView(shopItems, itemsParams);
        content.addView(label("Fluent UI Emoji © Microsoft · MIT License\nhttps://github.com/microsoft/fluentui-emoji", 11, false, theme.textSecondary), wrapWithTopMargin(18));
        TextView back = secondaryAction(strings.back);
        LinearLayout.LayoutParams backParams = new LinearLayout.LayoutParams(width, dp(50)); backParams.topMargin = dp(20);
        content.addView(back, backParams);
        back.setOnClickListener(v -> closeShop());
        overlay.addView(scroll, matchParent()); root.addView(overlay, matchParent());
    }

    private void showShop() {
        gameView.playUiMenu();
        shopOverlay.setVisibility(View.VISIBLE);
        refreshShop();
    }
    private void closeShop() { gameView.playUiClick(); shopOverlay.setVisibility(View.GONE); refreshLabels(); }
    private void refreshShop() {
        shopBalance.setText(coinLabel());
        shopItems.removeAllViews();
        final SkinArt shopArt = new SkinArt(this);
        for (int id = 0; id < BallPalette.COUNT; id++) {
            if (!BallPalette.available(id)) continue;
            final int choice = id;
            boolean owned = GamePrefs.ownsPalette(this, id), selected = GamePrefs.selectedPalette(this) == id;
            LinearLayout item = new LinearLayout(this); item.setOrientation(LinearLayout.VERTICAL);
            item.setGravity(Gravity.CENTER); item.setPadding(dp(14), dp(12), dp(14), dp(12));
            item.setClickable(true); item.setFocusable(true);
            int badgeColor = selected ? 0xffffd45c : owned ? 0xff51e3b0 : 0xff71849c;
            item.setBackground(tileBackground(owned ? 0xff224c4c : 0xff293e61, owned ? 0xff193c40 : 0xff1e293f, badgeColor));
            final android.graphics.Paint badgePaint = new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
            badgePaint.setColor(badgeColor); badgePaint.setStyle(android.graphics.Paint.Style.STROKE); badgePaint.setStrokeWidth(dp(2));
            View preview = new View(this) {
                @Override protected void onDraw(android.graphics.Canvas canvas) {
                    super.onDraw(canvas);
                    float x = getWidth() / 2f, y = getHeight() / 2f, r = dp(25);
                    shopArt.preview(canvas, choice, x - dp(34), y, r, BallPalette.left(choice, theme));
                    shopArt.preview(canvas, choice, x + dp(34), y, r, BallPalette.right(choice, theme));
                    canvas.drawCircle(x - dp(34), y, r + dp(3), badgePaint);
                    canvas.drawCircle(x + dp(34), y, r + dp(3), badgePaint);
                }
            };
            item.addView(preview, new LinearLayout.LayoutParams(dp(180), dp(62)));
            String name = skinName(id);
            item.addView(label(name, 16, true, 0xffffffff), wrapWithTopMargin(7));
            String cost = id == 0 ? tr("رایگان", "Free", "مجاني", "Gratis") : BallPalette.price(id) + tr(" سکه", " coins", " عملات", " monedas");
            String requirement = id == 0 ? "" : "  •  " + tr("رکورد ", "Record ", "رقم ", "Récord ") + difficultyName(BallPalette.requiredDifficulty(id)) + ": " + BallPalette.requiredScore(id);
            String state = selected ? tr(" • انتخاب‌شده", " • Selected", " • مختار", " • Seleccionado") : owned ? tr(" • خریداری‌شده", " • Owned", " • مملوك", " • Adquirido") : "";
            item.addView(label(cost + requirement + state, 13, false, 0xffffda75), wrapWithTopMargin(5));
            item.setContentDescription(name + "، " + cost + requirement + state);
            item.setOnClickListener(v -> {
                boolean alreadyOwned = GamePrefs.ownsPalette(this, choice);
                if (GamePrefs.buyOrSelectPalette(this, choice)) {
                    gameView.setBallPalette(GamePrefs.selectedPalette(this));
                    if (alreadyOwned) gameView.playUiClick();
                    else {
                        gameView.playWin();
                        if (!GamePrefs.reducedEffects(this)) confetti.celebrate();
                        Toast.makeText(this, tr("تبریک! ظاهر جدید خریداری شد ✨", "Congratulations! New appearance purchased ✨", "تهانينا! تم شراء المظهر الجديد ✨", "¡Enhorabuena! Apariencia comprada ✨"), Toast.LENGTH_LONG).show();
                    }
                    refreshShop(); refreshLabels();
                } else {
                    Toast.makeText(this, tr("سکه یا رکورد لازم را نداری", "You need the required coins and record", "تحتاج إلى العملات والرقم المطلوبين", "Necesitas las monedas y el récord requeridos"), Toast.LENGTH_LONG).show();
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            if (id > 0) lp.topMargin = dp(10);
            shopItems.addView(item, lp);
        }
    }

    private String skinName(int id) {
        if (id == 0) return tr("کلاسیک", "Classic", "كلاسيكي", "Clásico");
        if (id == 1) return tr("بنفش و فیروزه‌ای", "Violet & mint", "بنفسجي وتركوازي", "Violeta y menta");
        if (id == 2) return tr("سبز و صورتی", "Emerald & pink", "أخضر ووردي", "Verde y rosa");
        if (id == 3) return tr("طلایی و بنفش", "Amber & violet", "ذهبي وبنفسجي", "Ámbar y violeta");
        String[] fa = {"اژدها", "شیر", "پلنگ", "گربه", "ببر", "گرگ", "روباه", "پاندا", "خرس", "خرگوش", "فوتبال", "والیبال", "تنیس", "بسکتبال", "بیس‌بال", "بیلیارد", "آتش", "ماه", "ستاره", "الماس", "تاج", "سیاره", "آذرخش", "گوی بلورین"};
        String[] en = {"Dragon", "Lion", "Leopard", "Cat", "Tiger", "Wolf", "Fox", "Panda", "Bear", "Rabbit", "Football", "Volleyball", "Tennis", "Basketball", "Baseball", "Billiards", "Fire", "Moon", "Star", "Diamond", "Crown", "Planet", "Lightning", "Crystal"};
        String[] ar = {"تنين", "أسد", "نمر مرقط", "قطة", "ببر", "ذئب", "ثعلب", "باندا", "دب", "أرنب", "كرة القدم", "كرة الطائرة", "تنس", "سلة", "بيسبول", "بلياردو", "نار", "قمر", "نجمة", "ألماس", "تاج", "كوكب", "برق", "بلورة"};
        String[] es = {"Dragón", "León", "Leopardo", "Gato", "Tigre", "Lobo", "Zorro", "Panda", "Oso", "Conejo", "Fútbol", "Voleibol", "Tenis", "Baloncesto", "Béisbol", "Billar", "Fuego", "Luna", "Estrella", "Diamante", "Corona", "Planeta", "Rayo", "Cristal"};
        int index = BallPalette.assetIndex(id);
        String name = (lang == Lang.EN ? en : lang == Lang.AR ? ar : lang == Lang.ES ? es : fa)[index];
        return name;
    }

    private void applyAccessibility() {
        gameView.engine().setAccessibility(GamePrefs.reducedEffects(this), GamePrefs.sensitivity(this) / 100f);
        gameView.setClearMarkers(GamePrefs.clearMarkers(this));
    }

    private void addAccessibilityControls(LinearLayout card) {

        android.widget.Switch effects = new android.widget.Switch(this);
        settingsEffects = effects;
        effects.setText(tr("کاهش جلوه‌های تصویری", "Reduce visual effects", "تقليل المؤثرات البصرية", "Reducir efectos visuales"));
        effects.setTextColor(theme.textPrimary);
        effects.setChecked(GamePrefs.reducedEffects(this));
        card.addView(effects, fullWidthButtonParams(8));
        effects.setOnCheckedChangeListener((button, checked) -> { GamePrefs.setReducedEffects(this, checked); applyAccessibility(); });
        android.widget.Switch markers = new android.widget.Switch(this);
        markers.setText(tr("نشانه‌های واضح‌تر موانع", "Clearer obstacle markers", "علامات عوائق أوضح", "Marcas de obstáculos más visibles"));
        markers.setTextColor(theme.textPrimary);
        markers.setChecked(GamePrefs.clearMarkers(this));
        card.addView(markers, fullWidthButtonParams(8));
        markers.setOnCheckedChangeListener((button, checked) -> { GamePrefs.setClearMarkers(this, checked); applyAccessibility(); });
        TextView caption = label("", 12, false, theme.textSecondary);
        String sensitivityLabel = tr("حساسیت حرکت", "Movement sensitivity", "حساسية الحركة", "Sensibilidad del movimiento");
        caption.setText(sensitivityLabel + ": " + GamePrefs.sensitivity(this) + "%");
        card.addView(caption, wrapWithTopMargin(8));
        SeekBar bar = new SeekBar(this);
        bar.setMax(100); bar.setProgress(GamePrefs.sensitivity(this) - 50);
        bar.setContentDescription(sensitivityLabel);
        card.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar b, int value, boolean fromUser) {
                caption.setText(sensitivityLabel + ": " + (value + 50) + "%");
                if (fromUser) { GamePrefs.setSensitivity(GameActivity.this, value + 50); applyAccessibility(); }
            }
            public void onStartTrackingTouch(SeekBar b) {}
            public void onStopTrackingTouch(SeekBar b) {}
        });
    }

    private void addVolumeControl(LinearLayout card, boolean isMusic) {
        TextView caption = label("", 12, false, theme.textSecondary);
        int initial = GamePrefs.volume(this, isMusic);
        caption.setText(strings.volume + ": " + initial + "%");
        card.addView(caption, wrapWithTopMargin(8));
        SeekBar bar = new SeekBar(this);
        if (isMusic) settingsMusicVolume = bar; else settingsSoundVolume = bar;
        bar.setMax(100);
        bar.setProgress(initial);
        bar.setContentDescription((isMusic ? strings.music : strings.sound) + " — " + strings.volume);
        card.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int value, boolean fromUser) {
                caption.setText(strings.volume + ": " + value + "%");
                if (!fromUser) return;
                GamePrefs.setVolume(GameActivity.this, isMusic, value);
                if (isMusic) music.setVolume(value); else gameView.setSoundVolume(value);
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }

    private void showStatistics() {
        StringBuilder body = new StringBuilder(strings.statisticsNote);
        for (Difficulty d : Difficulty.values()) {
            body.append("\n\n").append(difficultyName(d)).append("\n")
                .append(strings.runs).append(": ").append(GamePrefs.runs(this, d)).append("\n")
                .append(strings.bestLine.replace("%1$d", Integer.toString(GamePrefs.best(this, d)))).append("\n")
                .append(strings.totalRows).append(": ").append(GamePrefs.totalRows(this, d)).append("\n")
                .append(strings.bestRows).append(": ").append(GamePrefs.bestRows(this, d)).append("\n")
                .append(strings.bestTime).append(": ").append(GamePrefs.bestTime(this, d) / 1000).append("\n")
                .append(strings.bestLevel).append(": ").append(GamePrefs.bestLevel(this, d));
        }
        showTextDialog(strings.statistics, body.toString());
    }

    private void showCollection() {
        gameView.playUiMenu();
        new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle(strings.collection).setItems(new String[]{strings.ballStyle, strings.backgroundStyle},
                        (dialog, which) -> showStyleChoices(which == 1))
                .setNegativeButton(strings.close, (dialog, which) -> {}).show();
    }

    private void showStyleChoices(boolean background) {
        gameView.playUiMenu();
        String[] names = {strings.styleClassic, background ? strings.backgroundOne : strings.styleOne,
                background ? strings.backgroundTwo : strings.styleTwo};
        String[] choices = new String[names.length];
        int selected = GamePrefs.appearance(this, background);
        int score = GamePrefs.highestScore(this);
        for (int i = 0; i < names.length; i++) {
            String extra = score < Progress.threshold(i)
                    ? String.format(java.util.Locale.ROOT, strings.unlockAt, Progress.threshold(i))
                    : (selected == i ? strings.selected : "");
            choices[i] = names[i] + (extra.isEmpty() ? "" : " — " + extra);
        }
        new android.app.AlertDialog.Builder(this, android.app.AlertDialog.THEME_DEVICE_DEFAULT_LIGHT)
                .setTitle(background ? strings.backgroundStyle : strings.ballStyle)
                .setItems(choices, (dialog, which) -> {
                    if (score < Progress.threshold(which)) {
                        Toast.makeText(this, String.format(java.util.Locale.ROOT, strings.unlockAt,
                                Progress.threshold(which)), Toast.LENGTH_LONG).show();
                        return;
                    }
                    gameView.playUiClick();
                    GamePrefs.setAppearance(this, background, which);
                    gameView.setAppearance(GamePrefs.appearance(this, false), GamePrefs.appearance(this, true));
                }).setNegativeButton(strings.close, (dialog, which) -> {}).show();
    }

    private TextView sectionLabel(String textRes) {
        TextView label = label(textRes, 12, false, theme.textMuted);
        label.setGravity(Gravity.CENTER);
        return label;
    }

    private TextView chipLabel(String textRes) {
        TextView chip = new TextView(this);
        chip.setText(textRes);
        chip.setGravity(Gravity.CENTER);
        chip.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        chip.setIncludeFontPadding(false);
        chip.setSingleLine(true);
        chip.setPadding(dp(6), dp(12), dp(6), dp(12));
        chip.setMinHeight(dp(46));
        chip.setClickable(true);
        chip.setFocusable(true);
        return chip;
    }

    private LinearLayout chipRow(TextView... chips) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        for (int i = 0; i < chips.length; i++) {
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            if (i > 0) {
                params.setMarginStart(dp(8));
            }
            row.addView(chips[i], params);
        }
        return row;
    }

    private void refreshSettingChips() {
        styleChip(chipEasy, difficulty == Difficulty.EASY);
        styleChip(chipNormal, difficulty == Difficulty.NORMAL);
        styleChip(chipHard, difficulty == Difficulty.HARD);
        styleChip(chipNight, nightMode);
        styleChip(chipDay, !nightMode);
        styleChip(chipSoundOn, soundEnabled);
        styleChip(chipSoundOff, !soundEnabled);
        styleChip(chipMusicOn, musicEnabled);
        styleChip(chipMusicOff, !musicEnabled);
    }

    private void styleChip(TextView chip, boolean selected) {
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(dp(13));
        shape.setColor(selected ? theme.primaryButtonBackground : theme.chipBackground);
        shape.setStroke(dp(1), selected ? theme.primaryButtonBackground : theme.panelStroke);
        chip.setBackground(shape);
        chip.setTextColor(selected ? theme.primaryButtonText : theme.textSecondary);
        chip.setTypeface(selected ? typeBold : typeRegular);
    }

    private void selectDifficulty(Difficulty value) {
        gameView.playUiClick();
        difficulty = value;
        GamePrefs.setDifficulty(this, value);
        gameView.setDifficulty(value);
        refreshSettingChips();
        refreshLabels();
    }

    private void selectSound(boolean enabled) {
        gameView.playUiClick();
        soundEnabled = enabled;
        GamePrefs.setSoundEnabled(this, enabled);
        gameView.setSoundEnabled(enabled);
        refreshSettingChips();
    }

    private void selectMusic(boolean enabled) {
        gameView.playUiClick();
        musicEnabled = enabled;
        GamePrefs.setMusicEnabled(this, enabled);
        music.setEnabled(enabled);
        refreshSettingChips();
    }

    private void selectNight(boolean night) {
        gameView.playUiClick();
        if (night == nightMode) {
            return;
        }
        nightMode = night;
        GamePrefs.setNightMode(this, night);
        reopenSettingsAfterRecreate = true;
        recreate();
    }

    private void showSettings() {
        gameView.playUiMenu();
        settingsSoundVolume.setProgress(GamePrefs.volume(this, false));
        settingsMusicVolume.setProgress(GamePrefs.volume(this, true));
        settingsEffects.setChecked(GamePrefs.reducedEffects(this));
        settingsOverlay.setVisibility(View.VISIBLE);
        settingsOverlay.setAlpha(0f);
        settingsOverlay.animate().alpha(1f).setDuration(180).start();
    }

    private void hideSettings() {
        gameView.playUiClick();
        settingsOverlay.animate().alpha(0f).setDuration(150)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        settingsOverlay.setVisibility(View.GONE);
                    }
                }).start();
    }

    // ---------------------------------------------------------------- pause / over

    private void buildPausePanel() {
        LinearLayout panel = card(theme, dp(340));
        panel.setVisibility(View.VISIBLE);
        panel.setAlpha(1f); // card() starts invisible; the wrapper is animated, not its child.
        TextView title = label(strings.pausedTitle, 24, true, theme.textPrimary);
        panel.addView(title);
        panel.addView(label(tr("تنظیمات سریع", "QUICK SETTINGS", "إعدادات سريعة", "AJUSTES RÁPIDOS"), 12, true, theme.playerBlue), wrapWithTopMargin(12));

        pauseSound = secondaryAction(""); pauseMusic = secondaryAction("");
        LinearLayout toggles = new LinearLayout(this); toggles.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams toggleParams = new LinearLayout.LayoutParams(0, dp(48), 1f); toggleParams.setMarginEnd(dp(4));
        toggles.addView(pauseSound, toggleParams);
        LinearLayout.LayoutParams otherParams = new LinearLayout.LayoutParams(0, dp(48), 1f); otherParams.setMarginStart(dp(4));
        toggles.addView(pauseMusic, otherParams);
        LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); rowParams.topMargin = dp(8);
        panel.addView(toggles, rowParams);
        pauseSound.setOnClickListener(v -> { selectSound(!soundEnabled); refreshPauseControls(); });
        pauseMusic.setOnClickListener(v -> { selectMusic(!musicEnabled); refreshPauseControls(); });
        pauseSoundVolume = addPauseVolume(panel, false);
        pauseMusicVolume = addPauseVolume(panel, true);

        pauseEffects = new android.widget.Switch(this);
        pauseEffects.setText(tr("کاهش جلوه‌های تصویری", "Reduce visual effects", "تقليل المؤثرات البصرية", "Reducir efectos visuales"));
        pauseEffects.setTextColor(theme.textSecondary); pauseEffects.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        LinearLayout.LayoutParams switchParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); switchParams.topMargin = dp(8);
        panel.addView(pauseEffects, switchParams);
        pauseEffects.setOnCheckedChangeListener((button, checked) -> {
            GamePrefs.setReducedEffects(this, checked); applyAccessibility();
        });
        TextView resume = primaryAction(strings.resume); panel.addView(resume, fullWidthButtonParams(16));
        resume.setOnClickListener(v -> hidePause());
        TextView restart = secondaryAction(strings.restart); panel.addView(restart, fullWidthButtonParams(8));
        restart.setOnClickListener(v -> { hidePause(); startGame(); });
        TextView menu = secondaryAction(strings.menu); panel.addView(menu, fullWidthButtonParams(8));
        menu.setOnClickListener(v -> { hidePause(); goToMenu(); });

        LinearLayout centre = new LinearLayout(this); centre.setGravity(Gravity.CENTER); centre.setOrientation(LinearLayout.VERTICAL);
        centre.addView(panel, new LinearLayout.LayoutParams(Math.max(dp(180), Math.min(dp(340), getResources().getDisplayMetrics().widthPixels - dp(48))), ViewGroup.LayoutParams.WRAP_CONTENT));
        ScrollView wrapper = new ScrollView(this); wrapper.setFillViewport(true); wrapper.addView(centre); wrapper.setVisibility(View.GONE);
        pausePanel = wrapper;
        FrameLayout.LayoutParams wrapperParams = matchParent(); wrapperParams.topMargin = dp(12); wrapperParams.bottomMargin = dp(12);
        root.addView(wrapper, wrapperParams);
    }

    private SeekBar addPauseVolume(LinearLayout panel, boolean isMusic) {
        TextView caption = label("", 13, false, theme.textSecondary); caption.setGravity(Gravity.START);
        LinearLayout.LayoutParams captionParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); captionParams.topMargin = dp(9);
        panel.addView(caption, captionParams);
        SeekBar bar = new SeekBar(this); bar.setMax(100);
        bar.setContentDescription((isMusic ? strings.music : strings.sound) + " — " + strings.volume);
        panel.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(40)));
        caption.setText((isMusic ? strings.music : strings.sound) + " · " + GamePrefs.volume(this, isMusic) + "%");
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar b, int value, boolean fromUser) {
                caption.setText((isMusic ? strings.music : strings.sound) + " · " + value + "%");
                if (!fromUser) return;
                GamePrefs.setVolume(GameActivity.this, isMusic, value);
                if (isMusic) music.setVolume(value); else gameView.setSoundVolume(value);
            }
            public void onStartTrackingTouch(SeekBar b) {}
            public void onStopTrackingTouch(SeekBar b) {}
        });
        return bar;
    }

    private void refreshPauseControls() {
        pauseSound.setText("♪  " + strings.sound + ": " + (soundEnabled ? strings.on : strings.off));
        pauseMusic.setText("♫  " + strings.music + ": " + (musicEnabled ? strings.on : strings.off));
        pauseSoundVolume.setProgress(GamePrefs.volume(this, false));
        pauseMusicVolume.setProgress(GamePrefs.volume(this, true));
        pauseEffects.setChecked(GamePrefs.reducedEffects(this));
    }

    private void buildGameOverPanel() {
        LinearLayout panel = card(theme, dp(320));

        gameOverTitle = label(strings.gameOver, 22, true, theme.textPrimary);
        panel.addView(gameOverTitle);

        gameOverScore = label(strings.scoreLine, 24, true, theme.playerBlue);
        panel.addView(gameOverScore, wrapWithTopMargin(12));

        gameOverRows = label(strings.rowsLine, 13, false, theme.textSecondary);
        panel.addView(gameOverRows, wrapWithTopMargin(6));

        gameOverBest = label(strings.bestLine, 13, true, theme.playerRed);
        panel.addView(gameOverBest, wrapWithTopMargin(6));

        nextStageButton = primaryAction(tr("مرحلهٔ بعد", "Next stage", "المرحلة التالية", "Siguiente nivel"));
        panel.addView(nextStageButton, fullWidthButtonParams(16));
        nextStageButton.setVisibility(View.GONE);
        nextStageButton.setOnClickListener(v -> { selectedStage++; startGame(); });

        TextView again = primaryAction(strings.playAgain);
        panel.addView(again, fullWidthButtonParams(18));
        again.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                startGame();
            }
        });

        TextView menu = secondaryAction(strings.menu);
        panel.addView(menu, fullWidthButtonParams(10));
        menu.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                hideGameOver();
                goToMenu();
            }
        });

        // The result card can grow for translated text or large fonts; keep all actions reachable.
        panel.setVisibility(View.VISIBLE);
        panel.setAlpha(1f);
        LinearLayout centre = new LinearLayout(this);
        centre.setGravity(Gravity.CENTER);
        centre.setOrientation(LinearLayout.VERTICAL);
        centre.addView(panel, new LinearLayout.LayoutParams(
                Math.max(dp(180), Math.min(dp(320), getResources().getDisplayMetrics().widthPixels - dp(48))),
                ViewGroup.LayoutParams.WRAP_CONTENT));
        ScrollView wrapper = new ScrollView(this);
        wrapper.setFillViewport(true);
        wrapper.addView(centre);
        wrapper.setVisibility(View.GONE);
        gameOverPanel = wrapper;
        FrameLayout.LayoutParams wrapperParams = matchParent();
        wrapperParams.topMargin = dp(16);
        wrapperParams.bottomMargin = dp(16);
        root.addView(wrapper, wrapperParams);
    }

    // ---------------------------------------------------------------- shared views

    private TextView label(String textRes, float sizeSp, boolean bold, int color) {
        TextView view = new TextView(this);
        view.setText(textRes);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        view.setTypeface(bold ? typeBold : typeRegular);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER);
        view.setIncludeFontPadding(false);
        view.setLineSpacing(dp(4), 1f);
        return view;
    }

    private LinearLayout card(Theme theme, int maxWidthPx) {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_HORIZONTAL);
        panel.setPadding(dp(22), dp(20), dp(22), dp(20));
        panel.setClickable(true);

        GradientDrawable background = new GradientDrawable();
        background.setColor(theme.panelBackground);
        background.setCornerRadius(dp(22));
        background.setStroke(dp(1), theme.panelStroke);
        panel.setBackground(background);

        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        panel.setMinimumWidth(Math.min(maxWidthPx, screenWidth - dp(48)));

        panel.setVisibility(View.GONE);
        panel.setAlpha(0f);
        return panel;
    }

    private TextView primaryAction(String textRes) {
        TextView button = actionBase(textRes, 16, true);
        button.setTextColor(theme.primaryButtonText);
        button.setBackground(buttonBackground(theme.primaryButtonBackground,
                blend(theme.primaryButtonBackground, theme.primaryButtonText, 0.16f)));
        return button;
    }

    private TextView secondaryAction(String textRes) {
        TextView button = actionBase(textRes, 15, false);
        button.setTextColor(theme.secondaryButtonText);
        button.setBackground(buttonBackground(theme.secondaryButtonBackground,
                blend(theme.secondaryButtonBackground, theme.secondaryButtonText, 0.10f)));
        return button;
    }

    private TextView actionBase(String textRes, float sizeSp, boolean bold) {
        TextView button = new TextView(this);
        button.setText(textRes);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp);
        button.setTypeface(bold ? typeBold : typeRegular);
        button.setGravity(Gravity.CENTER);
        button.setIncludeFontPadding(false);
        button.setPadding(dp(14), dp(10), dp(14), dp(10));
        button.setClickable(true);
        button.setFocusable(true);
        return button;
    }

    private Drawable buttonBackground(int normal, int pressed) {
        StateListDrawable states = new StateListDrawable();
        states.addState(new int[] {android.R.attr.state_pressed}, roundedRect(pressed));
        states.addState(new int[] {android.R.attr.state_enabled}, roundedRect(normal));
        return states;
    }

    private Drawable roundedRect(int color) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(dp(14));
        shape.setStroke(dp(1), theme.panelStroke);
        return shape;
    }

    private Drawable menuBackground() {
        Drawable image = getResources().getDrawable(nightMode ? R.drawable.scene_night : R.drawable.scene_day);
        GradientDrawable shade = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                nightMode ? new int[] {0x66061020, 0x99061020} : new int[] {0x55ffffff, 0x99f2f5fb});
        return new android.graphics.drawable.LayerDrawable(new Drawable[] {image, shade});
    }

    private static int blend(int from, int to, float amount) {
        int a = (int) (((from >> 24) & 0xFF) * (1f - amount) + ((to >> 24) & 0xFF) * amount);
        int r = (int) (((from >> 16) & 0xFF) * (1f - amount) + ((to >> 16) & 0xFF) * amount);
        int g = (int) (((from >> 8) & 0xFF) * (1f - amount) + ((to >> 8) & 0xFF) * amount);
        int b = (int) ((from & 0xFF) * (1f - amount) + (to & 0xFF) * amount);
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    private LinearLayout settingsSection(LinearLayout parent, String title) {
        LinearLayout group = new LinearLayout(this);
        group.setOrientation(LinearLayout.VERTICAL);
        group.setGravity(Gravity.CENTER_HORIZONTAL);
        group.setPadding(dp(14), dp(12), dp(14), dp(14));
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(dp(17)); shape.setColor(theme.chipBackground); shape.setStroke(dp(1), theme.panelStroke);
        group.setBackground(shape);
        TextView heading = label(title, 13, true, theme.playerBlue);
        heading.setGravity(Gravity.START);
        group.addView(heading, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        parent.addView(group, matchWidthWithTopMargin(12));
        return group;
    }
    private LinearLayout.LayoutParams matchWidthWithTopMargin(int margin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(margin); return params;
    }

    private LinearLayout.LayoutParams fullWidthButtonParams(int topMarginDp) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(50));
        params.topMargin = dp(topMarginDp);
        return params;
    }

    private LinearLayout.LayoutParams wrapWithTopMargin(int topMarginDp) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(topMarginDp);
        return params;
    }

    private FrameLayout.LayoutParams centeredPanelParams() {
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.gravity = Gravity.CENTER;
        params.leftMargin = dp(20);
        params.rightMargin = dp(20);
        return params;
    }

    private FrameLayout.LayoutParams matchParent() {
        return new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    // ------------------------------------------------------------------------ flow

    private void startGame() {
        gameView.playUiClick();
        confetti.stop();
        stageOverlay.setVisibility(View.GONE);
        shopOverlay.setVisibility(View.GONE);
        music.setGameStage(mode == GameEngine.Mode.STAGES ? selectedStage : 0);
        music.setScene(MusicPlayer.Scene.GAME);
        music.setPaused(false);
        menuOverlay.setVisibility(View.GONE);
        if (settingsOverlay.getVisibility() == View.VISIBLE) {
            hideSettings();
        }
        hideGameOver();
        pauseOnResume = false;
        hud.setVisibility(View.VISIBLE);
        hudBest.setTextColor(mode == GameEngine.Mode.STAGES && selectedStage >= 2 ? 0xffdcefff : theme.textMuted);
        if (!hintConsumed) {
            hint.setVisibility(View.VISIBLE);
            hint.setAlpha(1f);
            gameView.setOnFirstTouchListener(new Runnable() {
                @Override
                public void run() {
                    hideHint();
                }
            });
        }
        refreshLabels();
        gameView.startRun(mode, selectedStage);
        if (mode == GameEngine.Mode.STAGES && GamePrefs.stageComplete(this, selectedStage)) {
            String message = selectedStage <= 2
                    ? tr("مرحلهٔ تکراری: جایزهٔ پیروزی ", "Replay victory reward: ", "مكافأة الفوز في الإعادة: ", "Premio por repetir: ") + GameEngine.replayWinReward(selectedStage) + tr(" سکه؛ در مسیر سکه‌ای نیست.", " coins; no pickups on the way.", " عملات؛ لا عملات في المسار.", " monedas; no hay monedas en el camino.")
                    : tr("مرحلهٔ تکراری: سکه‌های کمی در مسیر ظاهر می‌شوند.", "Replay: a few coins appear along the way.", "الإعادة: تظهر عملات قليلة في المسار.", "Repetición: aparecen pocas monedas en el camino.");
            Toast.makeText(this, message, Toast.LENGTH_LONG).show();
        }
        if (mode == GameEngine.Mode.PRACTICE) Toast.makeText(this, tr("تمرین: برخورد بازی را تمام نمی‌کند و رکورد ثبت نمی‌شود", "Practice: collisions do not end the run or count towards records", "تدريب: الاصطدام لا ينهي اللعب ولا يسجل رقماً", "Práctica: los choques no terminan la partida ni cuentan para récords"), Toast.LENGTH_LONG).show();
        if (mode == GameEngine.Mode.STAGES) Toast.makeText(this, tr("هدف: عبور از ", "Goal: clear ", "الهدف: تجاوز ", "Objetivo: superar ") + (10 + selectedStage * 5) + tr(" ردیف", " rows", " صفاً", " filas"), Toast.LENGTH_LONG).show();
        gameView.resumeGame();
    }

    private void goToMenu() {
        gameView.playUiMenu();
        confetti.stop();
        stageOverlay.setVisibility(View.GONE);
        shopOverlay.setVisibility(View.GONE);
        music.setScene(MusicPlayer.Scene.MENU);
        hud.setVisibility(View.GONE);
        hint.setVisibility(View.GONE);
        menuOverlay.setVisibility(View.VISIBLE);
        scrim.setVisibility(View.GONE);
        gameView.showAttract();
        gameView.resumeGame();
        refreshLabels();
    }

    private void showPause() {
        if (!gameView.canPause()) return;
        if (gameOverPanel.getVisibility() == View.VISIBLE) {
            return;
        }
        gameView.pauseGame();
        refreshPauseControls();
        gameView.playUiMenu();
        music.setPaused(true);
        hud.setVisibility(View.GONE);
        scrim.setVisibility(View.VISIBLE);
        fadeIn(scrim);
        panelIn(pausePanel);
    }

    private void hidePause() {
        gameView.playUiClick();
        music.setPaused(false);
        hideCard(pausePanel);
        hud.setVisibility(View.VISIBLE);
        gameView.resumeGame();
    }

    private void showGameOver(int score, int rowsCleared, long millis) {
        music.setScene(MusicPlayer.Scene.NONE);
        boolean completed = mode == GameEngine.Mode.STAGES && gameView.engine().stageCompleted();
        boolean replayed = completed && GamePrefs.stageComplete(this, selectedStage);
        int unlockBonus = completed ? GamePrefs.completeStage(this, selectedStage) : 0;
        int previousBest = GamePrefs.highestScore(this);
        boolean record = mode == GameEngine.Mode.ENDLESS && GamePrefs.recordRun(this, difficulty, score, rowsCleared, millis);
        int newBest = GamePrefs.highestScore(this);
        if (Progress.unlockedBetween(previousBest, newBest)) {
            gameView.playUiUnlock();
            Toast.makeText(this, strings.unlockNotice, Toast.LENGTH_LONG).show();
        }
        nextStageButton.setVisibility(completed && selectedStage < 5 ? View.VISIBLE : View.GONE);
        if (completed) {
            gameOverTitle.setText(tr("تو بردی!", "You won!", "لقد فزت!", "¡Ganaste!"));
            gameOverTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
            gameOverTitle.setTextColor(0xff70dfff);
            gameOverTitle.getPaint().setShader(new android.graphics.LinearGradient(0, 0, dp(180), 0,
                    new int[]{0xff67dfff, 0xffff81c0, 0xffffdc70}, null, android.graphics.Shader.TileMode.MIRROR));
            gameOverScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
            gameOverScore.setTextColor(theme.textSecondary);
            gameOverScore.setText(String.format(java.util.Locale.ROOT, strings.scoreLine, score));
            String rewards = replayed && selectedStage <= 2
                    ? "\n+" + GameEngine.replayWinReward(selectedStage) + tr(" سکه جایزه", " reward coins", " عملات مكافأة", " monedas de premio") : "";
            if (unlockBonus > 0) rewards += "\n+20 " + tr("سکه برای باز شدن مرحلهٔ بعد", "coins for unlocking the next stage", "عملة لفتح المرحلة التالية", "monedas por desbloquear el siguiente nivel");
            gameOverRows.setText(String.format(java.util.Locale.ROOT, strings.rowsLine, rowsCleared)
                    + "\n" + tr("مرحله ", "Stage ", "المرحلة ", "Nivel ") + selectedStage
                    + " · " + difficultyName(difficulty) + rewards);
            gameOverBest.setTextColor(theme.textSecondary);
            gameOverBest.setTypeface(typeRegular);
            gameOverBest.setText(tr("زمان: ", "Time: ", "الوقت: ", "Tiempo: ") + String.format(java.util.Locale.ROOT, "%d:%02d", millis / 60000, (millis / 1000) % 60) + "  •  " + coinLabel());
            gameView.playWin();
            if (!GamePrefs.reducedEffects(this)) confetti.celebrate();
        } else {
            gameOverTitle.getPaint().setShader(null);
            gameOverTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
            gameOverTitle.setTextColor(theme.textPrimary);
            gameOverTitle.setText(record ? strings.newRecord : strings.gameOver);
            gameOverScore.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
            gameOverScore.setTextColor(theme.playerBlue);
            gameOverScore.setText(String.format(java.util.Locale.ROOT, strings.scoreLine, score));
            int hit = gameView.engine().hitBall();
            String collision = hit == 3 ? tr("هر دو توپ برخورد کردند", "Both balls collided", "اصطدمت الكرتان", "Chocaron ambas bolas")
                : hit == 1 ? tr("توپ اول برخورد کرد", "First ball collided", "اصطدمت الكرة الأولى", "Chocó la primera bola")
                : tr("توپ دوم برخورد کرد", "Second ball collided", "اصطدمت الكرة الثانية", "Chocó la segunda bola");
            gameOverRows.setText(String.format(java.util.Locale.ROOT, strings.rowsLine, rowsCleared) + "\n" + collision);
            gameOverBest.setTextColor(theme.playerRed);
            gameOverBest.setTypeface(typeBold);
            gameOverBest.setText(mode == GameEngine.Mode.ENDLESS ? String.format(java.util.Locale.ROOT, strings.bestLine, GamePrefs.best(this, difficulty)) : tr("رکورد بی‌پایان ثبت نمی‌شود", "Endless records are not affected", "لا تتأثر الأرقام القياسية", "Los récords no se modifican"));
        }

        hud.setVisibility(View.GONE);
        hideHint();
        scrim.setVisibility(View.VISIBLE);
        fadeIn(scrim);
        panelIn(gameOverPanel);
        refreshLabels();
    }

    private void hideGameOver() {
        if (confetti != null) confetti.stop();
        hideCard(gameOverPanel);
    }

    private void hideHint() {
        if (hint.getVisibility() != View.VISIBLE) {
            return;
        }
        hintConsumed = true;
        hint.animate()
                .alpha(0f)
                .setDuration(450)
                .withEndAction(new Runnable() {
                    @Override
                    public void run() {
                        hint.setVisibility(View.GONE);
                    }
                })
                .start();
    }

    private void refreshLabels() {
        if (recordsText != null) {
            StringBuilder records = new StringBuilder();
            for (Difficulty d : Difficulty.values()) {
                if (records.length() > 0) records.append("\n");
                records.append(String.format(java.util.Locale.ROOT, strings.recordFor, difficultyName(d), GamePrefs.best(this, d)));
            }
            recordsText.setText(records.toString());
        }
        int best = GamePrefs.best(this, difficulty);
        if (menuBest != null) {
            menuBest.setText(String.format(java.util.Locale.ROOT, strings.bestLine, best));
        }
        if (menuCoins != null) menuCoins.setText(coinLabel());
        if (hudBest != null) {
            hudBest.setText(mode == GameEngine.Mode.STAGES ? coinLabel() : String.format(java.util.Locale.ROOT, strings.bestLine, best));
        }
        if (menuDifficulty != null) {
            menuDifficulty.setText(String.format(java.util.Locale.ROOT, strings.difficultyLine, difficultyName(difficulty)));
        }
    }

    private void fadeIn(View view) {
        view.setAlpha(0f);
        view.animate().alpha(1f).setDuration(200).start();
    }

    private void panelIn(View panel) {
        panel.setVisibility(View.VISIBLE);
        panel.setAlpha(0f);
        panel.setScaleX(0.94f);
        panel.setScaleY(0.94f);
        panel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(220).start();
    }

    /** Hide synchronously so a stale animation cannot dismiss a newer overlay. */
    private void hideCard(final View panel) {
        panel.animate().cancel();
        panel.setVisibility(View.GONE);
        if (pausePanel != null && gameOverPanel != null
                && pausePanel.getVisibility() != View.VISIBLE && gameOverPanel.getVisibility() != View.VISIBLE) {
            scrim.animate().cancel();
            scrim.setVisibility(View.GONE);
        }
    }

    // ------------------------------------------------------------------- lifecycle

    @Override
    protected void onResume() {
        super.onResume();
        if (gameView != null) {
            gameView.start();
        }
        if (pauseOnResume) {
            pauseOnResume = false;
            showPause();
        }
        if (music != null) music.setForeground(true);
    }

    @Override
    protected void onPause() {
        if (music != null) music.setForeground(false);
        if (gameView != null) {
            GameEngine.State state = gameView.engine().state();
            if (state == GameEngine.State.PLAYING || state == GameEngine.State.COUNTDOWN) {
                gameView.pauseGame();
                pauseOnResume = true;
            }
            gameView.stop();
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (music != null) music.release();
        if (gameView != null) {
            gameView.release();
        }
        super.onDestroy();
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (settingsOverlay.getVisibility() == View.VISIBLE) {
            hideSettings();
            return;
        }
        if (shopOverlay.getVisibility() == View.VISIBLE) {
            closeShop();
            return;
        }
        if (stageOverlay.getVisibility() == View.VISIBLE) {
            closeStageMenu();
            return;
        }
        if (menuOverlay.getVisibility() == View.VISIBLE) {
            super.onBackPressed();
            return;
        }
        if (gameOverPanel.getVisibility() == View.VISIBLE) {
            hideGameOver();
            goToMenu();
            return;
        }
        if (pausePanel.getVisibility() == View.VISIBLE) {
            hidePause();
            return;
        }
        showPause();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemBars();
        }
    }

    @SuppressWarnings("deprecation")
    private void hideSystemBars() {
        View decor = getWindow().getDecorView();
        decor.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    private int dp(float value) {
        return Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, value, getResources().getDisplayMetrics()));
    }
}
