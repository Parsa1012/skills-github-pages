package io.github.parsa1012.mirrordash;

/**
 * Every piece of interface copy, in all four languages.
 *
 * <p>Text lives here instead of {@code res/values/strings.xml} because the language is chosen
 * inside the game, not by the phone's locale: picking a language rebuilds the activity and
 * every label comes from {@link #of(Lang)}. Everything is bundled — the game still needs no
 * network and no permissions.</p>
 */
public final class Strings {

    public String appName;
    public String tagline;

    public String start;
    public String settings;
    public String back;
    public String close;
    public String menu;
    public String resume;
    public String restart;
    public String playAgain;
    public String hint;

    public String difficulty;
    public String easy;
    public String normal;
    public String hard;
    public String difficultyLine;      // %1$s = difficulty name
    public String records;
    public String recordFor;           // %1$s = difficulty, %2$d = score

    public String appearance;
    public String night;
    public String day;
    public String sound;
    public String music;
    public String on;
    public String off;

    public String pausedTitle;
    public String gameOver;
    public String newRecord;
    public String scoreLine;           // %1$d
    public String bestLine;            // %1$d
    public String rowsLine;            // %1$d

    public String helpTitle;
    public String helpBody;
    public String languageTitle;
    public String aboutTitle;
    public String creatorLabel;
    public String emailLabel;
    public String creatorName;
    public String creatorEmail;
    public String aboutBody;
    public String versionLabel;

    public String pauseDescription;
    public String logoDescription;
    public String infoDescription;
    public String languageDescription;
    public String aboutDescription;

    private Strings() {
    }

    public static Strings of(Lang lang) {
        switch (lang) {
            case EN:
                return english();
            case AR:
                return arabic();
            case ES:
                return spanish();
            case FA:
            default:
                return persian();
        }
    }

    // --------------------------------------------------------------- languages

    private static Strings persian() {
        Strings s = new Strings();
        s.appName = "توپهای همزاد";
        s.tagline = "یک انگشت، دو نیمه";

        s.start = "شروع بازی";
        s.settings = "تنظیمات";
        s.back = "بازگشت";
        s.close = "بستن";
        s.menu = "منو";
        s.resume = "ادامه";
        s.restart = "شروع دوباره";
        s.playAgain = "دوباره";
        s.hint = "برای حرکت، انگشت را بکشید";

        s.difficulty = "درجه سختی";
        s.easy = "آسان";
        s.normal = "متوسط";
        s.hard = "دشوار";
        s.difficultyLine = "سختی: %1$s";
        s.records = "رکوردها";
        s.recordFor = "%1$s: %2$d";

        s.appearance = "حالت نمایش";
        s.night = "شب";
        s.day = "روز";
        s.sound = "جلوه‌های صوتی";
        s.music = "موسیقی";
        s.on = "روشن";
        s.off = "خاموش";

        s.pausedTitle = "توقف";
        s.gameOver = "بازی تمام شد";
        s.newRecord = "رکورد جدید!";
        s.scoreLine = "امتیاز %1$d";
        s.bestLine = "رکورد %1$d";
        s.rowsLine = "ردیف عبورشده %1$d";

        s.helpTitle = "راهنمای بازی";
        s.helpBody =
                "۱) کنترل\n"
                        + "انگشت را هر جای صفحه بکشید. توپ آبی به سمت موقعیت افقی انگشت می‌رود و توپ قرمز "
                        + "آینه‌ی آن در نیمه‌ی دیگر صفحه؛ هر دو با هم حرکت می‌کنند و هیچ‌کدام را "
                        + "نمی‌توانید جدا ببرید.\n\n"
                        + "۲) دیوارها\n"
                        + "ردیف‌ها از بالا می‌آیند و هر ردیف یک دیوار است با یک یا دو سوراخ:\n"
                        + "• یک سوراخ: هر دو توپ باید از همان سوراخ رد شوند، پس باید روی محور "
                        + "میانی و نزدیک هم بایستند.\n"
                        + "• دو سوراخ: هر توپ باید از سوراخ خودش رد شود، پس باید از هم دور شوند.\n\n"
                        + "۳) ریتم\n"
                        + "ردیف‌ها به شکل «کنار هم» یا «دور از هم» با ترتیب تصادفی می‌آیند. "
                        + "به‌محض رد کردن یک ردیف، برای ردیف بعدی جابه‌جا شوید.\n\n"
                        + "۴) امتیاز\n"
                        + "هر ثانیه ۱۰ امتیاز و هر ردیف عبورشده ۵ امتیاز. با بالا رفتن سطح، "
                        + "ردیف‌ها سریع‌تر و تنگ‌تر می‌شوند.\n\n"
                        + "۵) رکورد\n"
                        + "رکورد هر درجه سختی جدا ذخیره می‌شود؛ هر سه را در تنظیمات می‌بینید.\n\n"
                        + "۶) صدا و تم\n"
                        + "در تنظیمات، جلوه‌های صوتی و موسیقی را جداگانه خاموش یا روشن کنید و حالت شب یا روز را انتخاب کنید.\n\n"
                        + "۷) پایان بازی\n"
                        + "برخورد هر یک از دو توپ با دیوار بازی را تمام می‌کند، پس مراقب هر دو "
                        + "نیمه باشید.";
        s.languageTitle = "زبان";
        s.aboutTitle = "درباره سازنده";
        s.creatorLabel = "سازنده";
        s.emailLabel = "ایمیل";
        s.creatorName = "پارسا احمدی";
        s.creatorEmail = "mahdi950212@gmail.com";
        s.aboutBody = "این بازی با یک انگشت و دو توپ آینه‌ای ساخته شده است: ساده برای شروع، "
                + "سخت برای استاد شدن.\n\nاگر پیشنهاد، ایراد یا ایده‌ای دارید، به همین ایمیل "
                + "بنویسید.";
        s.versionLabel = "نسخه";

        s.pauseDescription = "توقف بازی";
        s.logoDescription = "لوگوی بازی";
        s.infoDescription = "راهنمای بازی";
        s.languageDescription = "انتخاب زبان";
        s.aboutDescription = "درباره سازنده";
        return s;
    }

    private static Strings english() {
        Strings s = new Strings();
        s.appName = "Twin Balls";
        s.tagline = "One finger, two halves";

        s.start = "Play";
        s.settings = "Settings";
        s.back = "Back";
        s.close = "Close";
        s.menu = "Menu";
        s.resume = "Resume";
        s.restart = "Restart";
        s.playAgain = "Play again";
        s.hint = "Drag your finger to move";

        s.difficulty = "Difficulty";
        s.easy = "Easy";
        s.normal = "Normal";
        s.hard = "Hard";
        s.difficultyLine = "Difficulty: %1$s";
        s.records = "Records";
        s.recordFor = "%1$s: %2$d";

        s.appearance = "Theme";
        s.night = "Night";
        s.day = "Day";
        s.sound = "Sound effects";
        s.music = "Music";
        s.on = "On";
        s.off = "Off";

        s.pausedTitle = "Paused";
        s.gameOver = "Game over";
        s.newRecord = "New record!";
        s.scoreLine = "Score %1$d";
        s.bestLine = "Best %1$d";
        s.rowsLine = "Rows cleared %1$d";

        s.helpTitle = "How to play";
        s.helpBody =
                "1) Controls\n"
                        + "Drag your finger anywhere on the screen. The blue ball moves towards the horizontal position "
                        + "of your finger and the red ball is its mirror in the other half; "
                        + "they always move together.\n\n"
                        + "2) Walls\n"
                        + "Rows fall from the top, each one a wall with one or two openings:\n"
                        + "• One opening: both balls must pass through it, so they have to sit "
                        + "together on the centre line.\n"
                        + "• Two openings: each ball passes through its own, so they have to be "
                        + "far apart.\n\n"
                        + "3) Rhythm\n"
                        + "Rows can be together or far apart in random order. The "
                        + "moment a row passes, move for the next one.\n\n"
                        + "4) Score\n"
                        + "10 points per second and 5 per row cleared. Rows get faster and "
                        + "tighter as the level rises.\n\n"
                        + "5) Records\n"
                        + "Each difficulty keeps its own record; all three are shown in "
                        + "Settings.\n\n"
                        + "6) Sound and theme\n"
                        + "Control sound effects and music independently, and choose night or day, in Settings.\n\n"
                        + "7) Game over\n"
                        + "If either ball touches a wall the run ends, so watch both halves.";
        s.languageTitle = "Language";
        s.aboutTitle = "About the creator";
        s.creatorLabel = "Creator";
        s.emailLabel = "Email";
        s.creatorName = "Parsa Ahmadi";
        s.creatorEmail = "mahdi950212@gmail.com";
        s.aboutBody = "This game is built on one finger and two mirrored balls: easy to "
                + "start, hard to master.\n\nIf you have a suggestion, a bug report or an "
                + "idea, write to the address above.";
        s.versionLabel = "Version";

        s.pauseDescription = "Pause game";
        s.logoDescription = "Game logo";
        s.infoDescription = "How to play";
        s.languageDescription = "Choose language";
        s.aboutDescription = "About the creator";
        return s;
    }

    private static Strings arabic() {
        Strings s = new Strings();
        s.appName = "كرات التوأم";
        s.tagline = "إصبع واحد، نصفان";

        s.start = "ابدأ اللعب";
        s.settings = "الإعدادات";
        s.back = "رجوع";
        s.close = "إغلاق";
        s.menu = "القائمة";
        s.resume = "متابعة";
        s.restart = "إعادة البدء";
        s.playAgain = "مرة أخرى";
        s.hint = "اسحب إصبعك للتحرّك";

        s.difficulty = "الصعوبة";
        s.easy = "سهل";
        s.normal = "متوسط";
        s.hard = "صعب";
        s.difficultyLine = "الصعوبة: %1$s";
        s.records = "الأرقام القياسية";
        s.recordFor = "%1$s: %2$d";

        s.appearance = "المظهر";
        s.night = "ليل";
        s.day = "نهار";
        s.sound = "المؤثرات الصوتية";
        s.music = "الموسيقى";
        s.on = "مفعّل";
        s.off = "مغلق";

        s.pausedTitle = "إيقاف مؤقت";
        s.gameOver = "انتهت اللعبة";
        s.newRecord = "رقم قياسي جديد!";
        s.scoreLine = "النقاط %1$d";
        s.bestLine = "الأفضل %1$d";
        s.rowsLine = "الصفوف %1$d";

        s.helpTitle = "طريقة اللعب";
        s.helpBody =
                "١) التحكّم\n"
                        + "اسحب إصبعك في أي مكان على الشاشة. تتحرك الكرة الزرقاء نحو موقع إصبعك الأفقي "
                        + "والكرة الحمراء هي صورتها المرآة في النصف الآخر، وتتحرّكان معًا "
                        + "دائمًا.\n\n"
                        + "٢) الجدران\n"
                        + "تنزل الصفوف من الأعلى، وكل صف جدار فيه فتحة أو فتحتان:\n"
                        + "• فتحة واحدة: يجب أن تمرّ الكرتان منها معًا، أي أن تكونا متجاورتين "
                        + "على المحور.\n"
                        + "• فتحتان: تمرّ كل كرة من فتحتها، أي يجب أن تبتعدا عن بعضهما.\n\n"
                        + "٣) الإيقاع\n"
                        + "تأتي الصفوف بين «متجاورتين» و«متباعدتين» بترتيب عشوائي؛ بمجرّد "
                        + "تجاوز صف، تحرّك للصف التالي.\n\n"
                        + "٤) النقاط\n"
                        + "١٠ نقاط لكل ثانية و٥ لكل صف. تزداد سرعة الصفوف وضيقها مع الصعود.\n\n"
                        + "٥) الأرقام القياسية\n"
                        + "لكل درجة صعوبة رقمها القياسي المستقل، وتجد الثلاثة في الإعدادات.\n\n"
                        + "٦) الصوت والمظهر\n"
                        + "تحكّم بالمؤثرات الصوتية والموسيقى كل على حدة، واختر الليل أو النهار من الإعدادات.\n\n"
                        + "٧) نهاية اللعبة\n"
                        + "اصطدام أي من الكرتين بالجدار ينهي الجولة، فاحترس للنصفين.";
        s.languageTitle = "اللغة";
        s.aboutTitle = "عن المطوّر";
        s.creatorLabel = "المطوّر";
        s.emailLabel = "البريد الإلكتروني";
        s.creatorName = "پارسا أحمدي";
        s.creatorEmail = "mahdi950212@gmail.com";
        s.aboutBody = "هذه اللعبة مبنيّة على إصبع واحد وكرتين متقابلتين: سهلة في البداية، "
                + "صعبة في الإتقان.\n\nإن كان لديك اقتراح أو ملاحظة، راسلنا على البريد أعلاه.";
        s.versionLabel = "الإصدار";

        s.pauseDescription = "إيقاف اللعبة";
        s.logoDescription = "شعار اللعبة";
        s.infoDescription = "طريقة اللعب";
        s.languageDescription = "اختيار اللغة";
        s.aboutDescription = "عن المطوّر";
        return s;
    }

    private static Strings spanish() {
        Strings s = new Strings();
        s.appName = "Bolas Gemelas";
        s.tagline = "Un dedo, dos mitades";

        s.start = "Jugar";
        s.settings = "Ajustes";
        s.back = "Volver";
        s.close = "Cerrar";
        s.menu = "Menú";
        s.resume = "Continuar";
        s.restart = "Reiniciar";
        s.playAgain = "Otra vez";
        s.hint = "Arrastra el dedo para moverte";

        s.difficulty = "Dificultad";
        s.easy = "Fácil";
        s.normal = "Normal";
        s.hard = "Difícil";
        s.difficultyLine = "Dificultad: %1$s";
        s.records = "Récords";
        s.recordFor = "%1$s: %2$d";

        s.appearance = "Tema";
        s.night = "Noche";
        s.day = "Día";
        s.sound = "Efectos de sonido";
        s.music = "Música";
        s.on = "Sí";
        s.off = "No";

        s.pausedTitle = "En pausa";
        s.gameOver = "Fin del juego";
        s.newRecord = "¡Nuevo récord!";
        s.scoreLine = "Puntos %1$d";
        s.bestLine = "Récord %1$d";
        s.rowsLine = "Filas %1$d";

        s.helpTitle = "Cómo jugar";
        s.helpBody =
                "1) Controles\n"
                        + "Arrastra el dedo por cualquier parte de la pantalla. La bola azul se mueve hacia la posición horizontal "
                        + "de tu dedo y la roja es su reflejo en la otra mitad: "
                        + "siempre se mueven juntas.\n\n"
                        + "2) Muros\n"
                        + "Las filas caen desde arriba, cada una es un muro con una o dos "
                        + "aberturas:\n"
                        + "• Una abertura: las dos bolas deben pasar por ella, así que tienen "
                        + "que estar juntas sobre el eje.\n"
                        + "• Dos aberturas: cada bola pasa por la suya, así que tienen que "
                        + "estar separadas.\n\n"
                        + "3) Ritmo\n"
                        + "Las filas pueden ser juntas o separadas en orden aleatorio. "
                        + "Cuando pase una fila, muévete para la siguiente.\n\n"
                        + "4) Puntuación\n"
                        + "10 puntos por segundo y 5 por cada fila. Las filas se vuelven más "
                        + "rápidas y estrechas al subir de nivel.\n\n"
                        + "5) Récords\n"
                        + "Cada dificultad guarda su propio récord; los tres están en Ajustes.\n\n"
                        + "6) Sonido y tema\n"
                        + "Controla los efectos y la música por separado, y elige noche o día en Ajustes.\n\n"
                        + "7) Fin del juego\n"
                        + "Si cualquiera de las dos bolas toca un muro, la partida termina: "
                        + "vigila las dos mitades.";
        s.languageTitle = "Idioma";
        s.aboutTitle = "Sobre el creador";
        s.creatorLabel = "Creador";
        s.emailLabel = "Correo";
        s.creatorName = "Parsa Ahmadi";
        s.creatorEmail = "mahdi950212@gmail.com";
        s.aboutBody = "Este juego se apoya en un dedo y dos bolas enfrentadas: fácil de "
                + "empezar, difícil de dominar.\n\nSi tienes una sugerencia, un fallo o una "
                + "idea, escribe al correo de arriba.";
        s.versionLabel = "Versión";

        s.pauseDescription = "Pausar el juego";
        s.logoDescription = "Logotipo del juego";
        s.infoDescription = "Cómo jugar";
        s.languageDescription = "Elegir idioma";
        s.aboutDescription = "Sobre el creador";
        return s;
    }
}
