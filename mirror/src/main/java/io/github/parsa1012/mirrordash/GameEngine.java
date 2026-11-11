package io.github.parsa1012.mirrordash;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Game rules and state machine.
 *
 * <p>Two bodies are mirrored around the vertical centre line: the left one follows the touch
 * input with a short smoothing lag, the right one is always {@code width - left}. Rows of
 * hazards scroll down; a row only allows the pair to survive inside a narrow x-window, and
 * every row is generated so that window exists and is reachable from the previous row's
 * window. That is what makes the difficulty fair instead of random.</p>
 *
 * <p>States: {@code ATTRACT} (menu background) → {@code COUNTDOWN} → {@code PLAYING} →
 * {@code DYING} (short hit-stop with particles and shake) → {@code GAME_OVER}.</p>
 */
public class GameEngine {

    public enum State {
        ATTRACT, COUNTDOWN, PLAYING, DYING, GAME_OVER
    }

    /** Time constant of the position smoothing, in seconds. */
    private static final float SMOOTH_TIME = 0.08f;

    private static final float PLAYER_RADIUS_DP = 16f;
    private static final float PLAYER_BOTTOM_OFFSET_DP = 150f;
    private static final float START_PROGRESS = 0.3f;

    /** Collision radius is a little smaller than the drawn one so deaths feel fair. */
    private static final float COLLISION_FORGIVENESS = 0.85f;

    private static final float FIRST_ROW_DELAY_SECONDS = 0.25f;
    private static final int MAX_ROWS = 10;
    private static final int MAX_SPAWN_ATTEMPTS = 48;

    /** Row archetypes: the pair is either bunched on the axis or pulled wide apart. */
    private static final int SPREAD_TOGETHER = 0;
    private static final int SPREAD_APART = 1;

    /** Model of a quick swipe, used to keep the required between-row travel honest. */
    private static final float HUMAN_SWIPE_DP_PER_SECOND = 850f;
    private static final float REACTION_MARGIN_SECONDS = 0.10f;
    private static final int BREATHER_EVERY_ROWS = 7;

    private static final int POINTS_PER_SECOND = 10;
    private static final int POINTS_PER_ROW = 5;

    private static final float COUNTDOWN_SECONDS = 1.05f;
    private static final float DYING_SECONDS = 0.45f;

    static final int MAX_PARTICLES = 240;
    static final int MAX_FLOATERS = 14;

    private static final float PARTICLE_DRAG = 1.7f;
    private static final float SHAKE_DECAY = 5.5f;
    private static final float FLASH_DECAY = 4.0f;

    private final Player leftPlayer = new Player(Theme.BLUE_NIGHT);
    private final Player rightPlayer = new Player(Theme.RED_NIGHT);

    private Difficulty difficulty = Difficulty.NORMAL;
    public enum Mode { ENDLESS, PRACTICE, STAGES }
    private Mode mode = Mode.ENDLESS;
    private int stage = 1;
    private volatile boolean stageCompleted;
    private volatile boolean reducedEffects;
    private volatile float sensitivity = 1f;
    private float impactX, impactY, impactTimer;
    private static final int MAX_COINS = 10;
    private final boolean[] coinVisible = new boolean[MAX_COINS];
    private final float[] coinX = new float[MAX_COINS], coinY = new float[MAX_COINS];
    private int coinEvents, collectedCoins;
    private double worldSeconds;
    public int coinSlots() { return MAX_COINS; }
    public boolean coinVisible(int index) { return index >= 0 && index < MAX_COINS && coinVisible[index]; }
    public float coinX(int index) { return coinX[index]; }
    public float coinY(int index) { return coinY[index]; }
    public float coinRadius() { return 11f * density; }
    public int collectedCoins() { return collectedCoins; }
    public int consumeCoinEvents() { int count = coinEvents; coinEvents = 0; return count; }
    public int stageNumber() { return stage; }
    private volatile int hitBall;
    public int hitBall() { return hitBall; }
    public Mode mode() { return mode; }
    private final java.util.Set<ObstacleRow> practiceHitRows = new java.util.HashSet<>();
    public void configureRun(Mode mode, int stage) {
        this.mode = mode == null ? Mode.ENDLESS : mode;
        this.stage = Math.max(1, Math.min(5, stage));
    }
    public void setAccessibility(boolean reduced, float sensitivity) {
        this.reducedEffects = reduced;
        this.sensitivity = Math.max(0.5f, Math.min(1.5f, sensitivity));
    }
    public boolean stageCompleted() { return stageCompleted; }
    public float impactX() { return impactX; }
    public float impactY() { return impactY; }
    public float impactTimer() { return impactTimer; }
    public boolean reducedEffects() { return reducedEffects; }
    public int stageGoal() { return 10 + stage * 5; }

    private final List<ObstacleRow> rows = new ArrayList<>(MAX_ROWS);
    private final Random random = new Random();

    // Particles (pooled arrays: no allocation while playing).
    final float[] particleX = new float[MAX_PARTICLES];
    final float[] particleY = new float[MAX_PARTICLES];
    final float[] particleVx = new float[MAX_PARTICLES];
    final float[] particleVy = new float[MAX_PARTICLES];
    final float[] particleLife = new float[MAX_PARTICLES];
    final float[] particleMaxLife = new float[MAX_PARTICLES];
    final float[] particleRadius = new float[MAX_PARTICLES];
    final int[] particleColor = new int[MAX_PARTICLES];
    int particleCount;

    // Floating "+5" labels.
    final float[] floaterX = new float[MAX_FLOATERS];
    final float[] floaterY = new float[MAX_FLOATERS];
    final float[] floaterLife = new float[MAX_FLOATERS];
    final float[] floaterMaxLife = new float[MAX_FLOATERS];
    final int[] floaterColor = new int[MAX_FLOATERS];
    int floaterCount;

    private volatile State state = State.ATTRACT;
    private volatile boolean paused;

    private int width;
    private int height;
    private float density = 1f;

    private float targetX;
    private float previousLeftX, previousRightX;
    private boolean touchActive;

    private double elapsedSeconds;
    private double runSeconds;
    private float distanceSinceSpawn;
    private int rowsCleared;
    private int rowsSpawned;
    /** NaN until the finish line enters from above, one row-spacing after the last obstacle. */
    private float finishY = Float.NaN;
    public float finishY() { return finishY; }
    private int rowsSinceBreather;
    private float lastWindowCenter = -1f;
    private int lastSpread = -1;
    private int spreadRun;

    private int score;
    private float countdown = COUNTDOWN_SECONDS;
    private float dyingTimer;
    private boolean justDied;
    private boolean impactEvent;
    private int rowPassEvents;
    private boolean initialised;

    private float shakeMagnitude;
    private float shakeX;
    private float shakeY;
    private float flash;

    public Player leftPlayer() {
        return leftPlayer;
    }

    public Player rightPlayer() {
        return rightPlayer;
    }

    public List<ObstacleRow> rows() {
        return rows;
    }

    public State state() {
        return state;
    }

    public int score() {
        return score;
    }

    public int rowsCleared() {
        return rowsCleared;
    }

    public long runMillis() { return (long) (runSeconds * 1000.0); }

    public float level() {
        return LevelConfig.levelOf(rowsCleared) + (mode == Mode.STAGES ? stage - 1 : 0);
    }

    public float countdown() {
        return countdown;
    }

    public float shakeX() {
        return shakeX;
    }

    public float shakeY() {
        return shakeY;
    }

    public float flash() {
        return flash;
    }

    public boolean isPaused() {
        return paused;
    }

    public Difficulty difficulty() {
        return difficulty;
    }

    /** Applies immediately: rows that are already on screen keep their geometry. */
    public void setDifficulty(Difficulty difficulty) {
        this.difficulty = difficulty == null ? Difficulty.NORMAL : difficulty;
    }

    /** Recolours the two bodies to match the active theme. */
    public void applyTheme(Theme theme) {
        leftPlayer.color = theme.playerBlue;
        rightPlayer.color = theme.playerRed;
    }
    public void setBallColors(int first, int second) { leftPlayer.color = first; rightPlayer.color = second; }

    public void setPaused(boolean paused) {
        this.paused = paused;
    }

    /** Idle "attract" scene used behind the menu: drifting bodies, no hazards. */
    public void enterAttract() {
        state = State.ATTRACT;
        paused = false;
        rows.clear();
        resetRunData();
    }

    /** Starts a real run: countdown, then hazards. */
    public void startRun() {
        rows.clear();
        resetRunData();
        random.setSeed(System.nanoTime());
        paused = false;
        state = State.COUNTDOWN;
        countdown = COUNTDOWN_SECONDS;

        if (width > 0) {
            float radius = leftPlayer.radius > 0 ? leftPlayer.radius : PLAYER_RADIUS_DP * density;
            leftPlayer.x = clamp(width * START_PROGRESS, radius, width - radius);
            rightPlayer.x = width - leftPlayer.x;
        }
        leftPlayer.resetTrail();
        rightPlayer.resetTrail();

        float speed = speedFor(1f);
        float spacing = spacingFor(1f);
        distanceSinceSpawn = spacing - speed * FIRST_ROW_DELAY_SECONDS;
    }

    private void resetRunData() {
        rowsCleared = 0;
        rowsSpawned = 0;
        worldSeconds = 0;
        java.util.Arrays.fill(coinVisible, false);
        coinEvents = 0;
        collectedCoins = 0;
        finishY = Float.NaN;
        stageCompleted = false;
        hitBall = 0;
        impactTimer = 0;
        practiceHitRows.clear();
        rowsSinceBreather = 0;
        runSeconds = 0.0;
        score = 0;
        lastWindowCenter = -1f;
        lastSpread = -1;
        spreadRun = 0;
        touchActive = false;
        countdown = COUNTDOWN_SECONDS;
        dyingTimer = 0f;
        justDied = false;
        impactEvent = false;
        rowPassEvents = 0;
        particleCount = 0;
        floaterCount = 0;
        shakeMagnitude = 0f;
        shakeX = 0f;
        shakeY = 0f;
        flash = 0f;
        distanceSinceSpawn = 0f;
    }

    /** Called on every surface size change and once at startup. */
    public void resize(int width, int height, float density) {
        this.width = width;
        this.height = height;
        this.density = density;

        float radius = PLAYER_RADIUS_DP * density;
        float y = height - PLAYER_BOTTOM_OFFSET_DP * density;
        leftPlayer.radius = radius;
        rightPlayer.radius = radius;
        leftPlayer.y = y;
        rightPlayer.y = y;

        if (!initialised) {
            initialised = true;
            float start = clamp(width * 0.32f, radius, width - radius);
            leftPlayer.x = start;
            rightPlayer.x = width - start;
            leftPlayer.resetTrail();
            rightPlayer.resetTrail();
            enterAttract();
        } else {
            leftPlayer.x = clamp(leftPlayer.x, radius, width - radius);
            rightPlayer.x = width - leftPlayer.x;
        }
    }

    /** Touch x in pixels. */
    public void setTouchX(float x) {
        if (width <= 0) {
            return;
        }
        touchActive = true;
        float half = width * 0.5f - leftPlayer.radius;
        if (half <= 0) return;
        float n = clamp((x - width * 0.5f) / half, -1f, 1f);
        targetX = width * 0.5f + Math.signum(n) * (float) Math.pow(Math.abs(n), 1f / sensitivity) * half;
    }

    /** True exactly once, when the run ends (after the dying hit-stop). */
    public boolean consumeJustDied() {
        if (!justDied) {
            return false;
        }
        justDied = false;
        return true;
    }

    /** True exactly once, on the frame of the fatal impact. */
    public boolean consumeImpact() {
        if (!impactEvent) {
            return false;
        }
        impactEvent = false;
        return true;
    }

    /** Number of rows cleared since the last call (used for the tick sound). */
    public int consumeRowPasses() {
        int passes = rowPassEvents;
        rowPassEvents = 0;
        return passes;
    }

    public void update(double dtValue) {
        if (width <= 0 || height <= 0 || paused) {
            return;
        }
        final float dt = (float) dtValue;
        elapsedSeconds += dtValue;

        updateEffects(dt);
        impactTimer = Math.max(0f, impactTimer - dt);

        switch (state) {
            case ATTRACT:
                updateAttract(dt);
                break;
            case COUNTDOWN:
                countdown -= dt;
                updatePlayers(dt);
                if (mode != Mode.STAGES) updateWorld(dt, false);
                if (countdown <= 0f) {
                    countdown = 0f;
                    state = State.PLAYING;
                }
                break;
            case PLAYING:
                runSeconds += dtValue;
                previousLeftX = leftPlayer.x;
                previousRightX = rightPlayer.x;
                updatePlayers(dt);
                updateWorld(dt, true);
                break;
            case DYING:
                dyingTimer -= dt;
                if (dyingTimer <= 0f) {
                    state = State.GAME_OVER;
                    justDied = true;
                }
                break;
            case GAME_OVER:
            default:
                break;
        }
    }

    private void updateAttract(float dt) {
        float target = width * 0.5f + (float) Math.sin(elapsedSeconds * 0.55) * width * 0.26f;
        followTarget(target, dt);
    }

    private void updatePlayers(float dt) {
        float goal = touchActive ? targetX : leftPlayer.x;
        followTarget(goal, dt);
    }

    private void followTarget(float goal, float dt) {
        float radius = leftPlayer.radius;
        float minX = radius;
        float maxX = width - radius;
        goal = clamp(goal, minX, maxX);

        // Frame-rate independent exponential smoothing.
        float t = 1f - (float) Math.exp(-dt / SMOOTH_TIME);
        leftPlayer.x = clamp(leftPlayer.x + (goal - leftPlayer.x) * t, minX, maxX);
        rightPlayer.x = width - leftPlayer.x;

        leftPlayer.pushTrail();
        rightPlayer.pushTrail();
    }

    /** Moves and spawns rows, and (when {@code lethal}) resolves collisions. */
    private void updateWorld(float dt, boolean lethal) {
        worldSeconds += dt;
        float level = level();
        float speed = speedFor(level);
        float spacing = spacingFor(level);

        for (int i = rows.size() - 1; i >= 0; i--) {
            ObstacleRow row = rows.get(i);
            row.y += speed * dt;
            row.updateWave(worldSeconds);

            if (!row.scored && row.y > leftPlayer.y + leftPlayer.radius) {
                row.scored = true;
                if (lethal) {
                    rowsCleared++;
                    rowPassEvents++;
                    spawnFloater(leftPlayer.x + leftPlayer.radius * 1.6f, leftPlayer.y - leftPlayer.radius * 2.2f,
                            leftPlayer.color);
                    spawnFloater(rightPlayer.x - rightPlayer.radius * 1.6f, rightPlayer.y - rightPlayer.radius * 2.2f,
                            rightPlayer.color);
                }
            }
            if (row.y > height + row.height) {
                practiceHitRows.remove(row);
                rows.remove(i);
            }
        }

        for (int i = 0; i < MAX_COINS; i++) {
            if (!coinVisible[i]) continue;
            float previousY = coinY[i];
            coinY[i] += speed * dt;
            float reach = coinRadius() + leftPlayer.radius;
            float oldY = leftPlayer.y - previousY, newY = leftPlayer.y - coinY[i];
            boolean leftTouch = sweptCircle(previousLeftX - coinX[i], oldY, leftPlayer.x - coinX[i], newY, reach);
            boolean rightTouch = sweptCircle(previousRightX - coinX[i], oldY, rightPlayer.x - coinX[i], newY, reach);
            if (lethal && (leftTouch || rightTouch)) {
                coinVisible[i] = false;
                coinEvents++;
                collectedCoins++;
                if (!reducedEffects) burstCoin(coinX[i], coinY[i]);
            } else if (coinY[i] > height + reach) {
                coinVisible[i] = false;
            }
        }
        if (!Float.isNaN(finishY)) finishY += speed * dt;
        distanceSinceSpawn += speed * dt;
        if (distanceSinceSpawn >= spacing) {
            if (mode == Mode.STAGES && rowsSpawned >= stageGoal()) {
                if (Float.isNaN(finishY)) {
                    finishY = -LevelConfig.rowHeight(density);
                    distanceSinceSpawn = 0f;
                }
            } else if (rows.size() < MAX_ROWS) {
                distanceSinceSpawn = 0f;
                spawnRow(level);
                if (mode == Mode.STAGES) {
                    rowsSpawned++;
                    // One optional coin after every four generated obstacles, between rows.
                    if (rowsSpawned % 4 == 0) {
                        for (int i = 0; i < MAX_COINS; i++) {
                            if (!coinVisible[i]) {
                                coinVisible[i] = true;
                                coinX[i] = clamp(lastWindowCenter, coinRadius(), width - coinRadius());
                                coinY[i] = -LevelConfig.rowHeight(density) - spacing * .5f;
                                break;
                            }
                        }
                    }
                }
            }
        }

        if (lethal && collides()) {
            impactTimer = mode == Mode.PRACTICE ? 0.8f : 3f;
            impactEvent = true;
            if (mode != Mode.PRACTICE) die();
        }
        if (lethal && state == State.PLAYING && mode == Mode.STAGES && rowsCleared >= stageGoal()
                && !Float.isNaN(finishY) && finishY > leftPlayer.y + leftPlayer.radius) {
            stageCompleted = true;
            score = computeScore();
            state = State.GAME_OVER;
            justDied = true;
        }
        if (lethal) {
            score = computeScore();
        }
    }

    private void die() {
        state = State.DYING;
        dyingTimer = DYING_SECONDS;
        impactEvent = true;
        score = computeScore();
        if (!reducedEffects) {
            shakeMagnitude = 16f * density;
            flash = 1f;
            burstDeath(leftPlayer);
            burstDeath(rightPlayer);
        }
    }

    // ------------------------------------------------------------------- effects

    private void updateEffects(float dt) {
        for (int i = particleCount - 1; i >= 0; i--) {
            particleLife[i] -= dt;
            if (particleLife[i] <= 0f) {
                particleCount--;
                moveParticle(particleCount, i);
                continue;
            }
            float drag = 1f - PARTICLE_DRAG * dt;
            if (drag < 0f) {
                drag = 0f;
            }
            particleVx[i] *= drag;
            particleVy[i] *= drag;
            particleX[i] += particleVx[i] * dt;
            particleY[i] += particleVy[i] * dt;
        }

        for (int i = floaterCount - 1; i >= 0; i--) {
            floaterLife[i] -= dt;
            if (floaterLife[i] <= 0f) {
                floaterCount--;
                floaterX[i] = floaterX[floaterCount];
                floaterY[i] = floaterY[floaterCount];
                floaterLife[i] = floaterLife[floaterCount];
                floaterMaxLife[i] = floaterMaxLife[floaterCount];
                floaterColor[i] = floaterColor[floaterCount];
                continue;
            }
            floaterY[i] -= 46f * density * dt;
        }

        if (shakeMagnitude > 0.4f) {
            shakeMagnitude *= (float) Math.exp(-SHAKE_DECAY * dt);
            shakeX = (random.nextFloat() * 2f - 1f) * shakeMagnitude;
            shakeY = (random.nextFloat() * 2f - 1f) * shakeMagnitude;
        } else {
            shakeMagnitude = 0f;
            shakeX = 0f;
            shakeY = 0f;
        }

        if (flash > 0f) {
            flash *= (float) Math.exp(-FLASH_DECAY * dt);
            if (flash < 0.01f) {
                flash = 0f;
            }
        }
    }

    private void burstCoin(float x, float y) {
        for (int i = 0; i < 12 && particleCount < MAX_PARTICLES; i++) {
            float angle = i * 6.2831855f / 12f;
            int k = particleCount++;
            particleX[k] = x; particleY[k] = y;
            particleVx[k] = (float) Math.cos(angle) * 95f * density;
            particleVy[k] = (float) Math.sin(angle) * 95f * density;
            particleLife[k] = particleMaxLife[k] = .42f;
            particleRadius[k] = 2.4f * density; particleColor[k] = 0xffffd454;
        }
    }

    private void burstDeath(Player player) {
        for (int i = 0; i < 44 && particleCount < MAX_PARTICLES; i++) {
            float angle = random.nextFloat() * 6.2831855f;
            float speed = (90f + random.nextFloat() * 430f) * density;
            float life = 0.35f + random.nextFloat() * 0.5f;
            int index = particleCount++;
            particleX[index] = player.x;
            particleY[index] = player.y;
            particleVx[index] = (float) Math.cos(angle) * speed;
            particleVy[index] = (float) Math.sin(angle) * speed;
            particleLife[index] = life;
            particleMaxLife[index] = life;
            particleRadius[index] = (1.6f + random.nextFloat() * 3.4f) * density;
            particleColor[index] = player.color;
        }
    }

    private void spawnFloater(float x, float y, int color) {
        if (floaterCount >= MAX_FLOATERS) {
            return;
        }
        int index = floaterCount++;
        floaterX[index] = x;
        floaterY[index] = y;
        floaterLife[index] = 0.65f;
        floaterMaxLife[index] = 0.65f;
        floaterColor[index] = color;
    }

    private void moveParticle(int from, int to) {
        particleX[to] = particleX[from];
        particleY[to] = particleY[from];
        particleVx[to] = particleVx[from];
        particleVy[to] = particleVy[from];
        particleLife[to] = particleLife[from];
        particleMaxLife[to] = particleMaxLife[from];
        particleRadius[to] = particleRadius[from];
        particleColor[to] = particleColor[from];
    }

    // ------------------------------------------------------------ tuning helpers

    private float speedFor(float level) {
        // Stages 3–5 are progressively faster even once the base speed curve caps out.
        float stageScale = mode != Mode.STAGES || stage < 3 ? 1f : 1f + (stage - 2) * .06f;
        return LevelConfig.rowSpeed(density, level) * difficulty.speedScale() * stageScale;
    }

    private float spacingFor(float level) {
        return LevelConfig.rowSpacing(density, level) * difficulty.spacingScale();
    }

    private float gapFor(float level) {
        return Math.max(24f * density, LevelConfig.gapWidth(density, level)
                + difficulty.gapBonus(density));
    }

    private float singleGapFor(float level) {
        return Math.max(40f * density, LevelConfig.singleGapWidth(density, level)
                + difficulty.gapBonus(density));
    }

    private float minWindowFor() {
        // Window width includes both visible radii; leave usable room instead of a
        // mathematically non-empty slit that requires pixel-perfect touch input.
        return (50f * density) + difficulty.minWindowBonus(density);
    }

    private float mismatchFor(float level, float gapWidth) {
        float budget = Math.max(0f, gapWidth - minWindowFor());
        float scaled = LevelConfig.maxMismatch(density, level) * difficulty.mismatchScale();
        return Math.min(budget, scaled);
    }

    private float movingChanceFor(float level) {
        float chance = LevelConfig.movingChance(level) * difficulty.movingScale();
        return Math.max(0f, Math.min(0.50f, chance));
    }

    /** How often the row type flips between "together" and "apart". */
    private float switchChanceFor(float level) {
        float levelBoost = 0.08f * LevelConfig.clamp01((level - 1f) / 8f);
        return Math.max(0.30f, Math.min(0.85f, difficulty.switchChance() + levelBoost));
    }

    /**
     * Furthest the pair may be asked to move sideways between two rows while staying
     * humanly reachable: a fast swipe (~1100 dp/s) for the time the rows are apart.
     */
    private float maxTravelFor(float level) {
        float clearDistance = Math.max(0f, spacingFor(level)
                - LevelConfig.rowHeight(density) - 2f * PLAYER_RADIUS_DP * density);
        float seconds = clearDistance / Math.max(1f, speedFor(level)) - REACTION_MARGIN_SECONDS;
        return HUMAN_SWIPE_DP_PER_SECOND * density * Math.max(0f, seconds);
    }

    /** How far from the centre line an "apart" row may sit, in the x of the left body. */
    private float apartMaxOffset(float level) {
        float levelT = LevelConfig.clamp01((level - 1f) / 8f);
        return width * (0.26f + 0.10f * levelT) * difficulty.apartScale();
    }

    // ---------------------------------------------------------------- generation

    /**
     * Picks the archetype of the next row.
     *
     * <p>Rows alternate between <em>together</em> (one shared opening, so both bodies sit on
     * the axis) and <em>apart</em> (two openings, so the bodies are pulled towards the edges).
     * Alternating is what forces the player to keep repositioning; the randomness and the odd
     * repeat stop it from feeling like a metronome. Two identical rows in a row are the
     * maximum, so the pattern can never settle into one safe corner.</p>
     */
    private int nextSpread(float level) {
        if (lastSpread < 0) {
            return random.nextFloat() < 0.5f ? SPREAD_APART : SPREAD_TOGETHER;
        }
        int opposite = lastSpread == SPREAD_APART ? SPREAD_TOGETHER : SPREAD_APART;
        if (spreadRun >= 2) {
            return opposite;
        }
        return random.nextFloat() < switchChanceFor(level) ? opposite : lastSpread;
    }

    private void spawnRow(float level) {
        ObstacleRow row = new ObstacleRow();
        row.begin(-LevelConfig.rowHeight(density), LevelConfig.rowHeight(density));

        boolean breather = rowsSinceBreather >= BREATHER_EVERY_ROWS || lastWindowCenter < 0f;
        int wanted = breather ? SPREAD_TOGETHER : nextSpread(level);

        boolean built;
        if (wanted == SPREAD_APART) {
            built = tryApartGap(row, level) || tryTogetherGap(row, level);
        } else {
            built = tryTogetherGap(row, level) || tryApartGap(row, level);
        }
        if (!built && !tryEasyMirror(row, level)) {
            buildFallback(row, level);
        }

        int builtSpread = row.gapCount > 1 ? SPREAD_APART : SPREAD_TOGETHER;
        spreadRun = builtSpread == lastSpread ? spreadRun + 1 : 1;
        lastSpread = builtSpread;

        if (breather) {
            rowsSinceBreather = 0;
        } else {
            rowsSinceBreather++;
        }

        rows.add(row);
        lastWindowCenter = row.windowCenter;
    }

    /**
     * A shared opening with enough room for the full visible balls to pass without touching.
     * Width here includes both ball radii; the remaining half-width determines how far from
     * the centre either ball can sit. A modest offset retains asymmetry without tight pinches.
     */
    private boolean tryTogetherGap(ObstacleRow row, float level) {
        float gapWidth = singleGapFor(level);
        // At least 24 dp from the axis (plus visible radius), even on Hard. Easier
        // presets allow a wider non-overlapping placement and more finger tolerance.
        float minWindow = (80f * density) + 2f * Math.max(0f,
                difficulty.minWindowBonus(density) + 4f * density);
        float margin = LevelConfig.EDGE_MARGIN_DP * density;
        if (lastWindowCenter >= 0f
                && Math.abs(lastWindowCenter - width * 0.5f) > maxTravelFor(level)) {
            return false;
        }
        if (gapWidth >= width - 2f * margin || gapWidth < minWindow) {
            return false;
        }
        float sliver = LevelConfig.minSliver(density);
        float maxOffset = Math.max(0f, (gapWidth - minWindow) * 0.5f);
        maxOffset = Math.min(maxOffset, Math.max(0f, width * 0.5f - gapWidth * 0.5f - sliver));

        for (int attempt = 0; attempt < MAX_SPAWN_ATTEMPTS; attempt++) {
            float center = width * 0.5f + (random.nextFloat() * 2f - 1f) * maxOffset;
            float windowWidth = gapWidth - Math.abs(2f * center - width);
            if (windowWidth < minWindow) {
                continue;
            }
            row.begin(-row.height, row.height);
            row.setGap(0, center, gapWidth);
            row.windowCenter = width * 0.5f;
            row.windowWidth = windowWidth;
            // Breathing shared openings are a new, gentle variation. Even at their
            // narrowest, they retain the full separated-ball safety window.
            float edgeSpace = Math.min(center - gapWidth * .5f - margin,
                    width - margin - center - gapWidth * .5f);
            float pulseAmplitude = Math.min(12f * density,
                    Math.min(windowWidth - minWindow, 2f * edgeSpace));
            if (lastWindowCenter >= 0f && level >= 3f && pulseAmplitude >= 3f * density
                    && random.nextFloat() < 0.28f) {
                row.enablePulse(pulseAmplitude, 3.2f, random.nextFloat() * 6.2831855f);
            }
            return true;
        }
        return false;
    }

    /**
     * "Apart" row: two openings mirrored with a deliberate offset from the centre line, so
     * the two bodies have to sit far from each other (each in its own opening). The offset is
     * biased towards the far end of the allowed band, and the pair is never asked to travel
     * further than a fast swipe can cover in the time between rows.
     */
    private boolean tryApartGap(ObstacleRow row, float level) {
        float gapWidth = gapFor(level);
        float minWindow = minWindowFor();
        float margin = LevelConfig.EDGE_MARGIN_DP * density;
        float sliver = LevelConfig.minSliver(density);
        float halfWidth = width * 0.5f;
        float minOffset = Math.max((gapWidth + sliver) * 0.5f, width * 0.16f);
        float maxOffset = apartMaxOffset(level);
        if (maxOffset <= minOffset) {
            return false;
        }

        float mismatch = mismatchFor(level, gapWidth);
        float amplitude = LevelConfig.waveAmplitude(density);
        float movingMinWindow = LevelConfig.movingMinWindow(density);
        float movingChance = movingChanceFor(level);
        float anchor = lastWindowCenter < 0f ? halfWidth : lastWindowCenter;
        float travel = maxTravelFor(level);
        float edge = gapWidth * 0.5f + margin;

        for (int attempt = 0; attempt < MAX_SPAWN_ATTEMPTS; attempt++) {
            float side = random.nextBoolean() ? 1f : -1f;
            // Clamp the offset so this row stays reachable from wherever the player is.
            float reachable = side > 0f ? anchor + travel - halfWidth : halfWidth - anchor + travel;
            float limit = Math.min(maxOffset, reachable);
            if (limit < minOffset) {
                continue;
            }
            // sqrt skew: the far end of the band is the common case, which is what makes the
            // rows feel wide apart instead of a timid wobble around the axis.
            float bias = (float) Math.sqrt(random.nextFloat());
            float offset = minOffset + (limit - minOffset) * bias;
            float windowCenter = halfWidth + side * offset;
            // The upper bound alone does not constrain jumps back toward the axis.
            // Reject both directions that exceed the actual swipe budget.
            if (lastWindowCenter >= 0f && Math.abs(windowCenter - anchor) > travel) continue;
            float error = (random.nextFloat() * 2f - 1f) * mismatch;
            float first = windowCenter + error * 0.5f;
            float second = width - windowCenter + error * 0.5f;
            if (first < edge || first > width - edge || second < edge || second > width - edge) {
                continue;
            }
            if (Math.abs(first - second) - gapWidth < sliver) {
                continue;
            }
            float windowWidth = gapWidth - Math.abs(error);
            if (windowWidth < minWindow) {
                continue;
            }

            row.begin(-row.height, row.height);
            row.setGap(0, first, gapWidth);
            row.setGap(1, second, gapWidth);
            row.windowCenter = windowCenter;
            row.windowWidth = windowWidth;
            // Both gaps shift in the same direction. The mirrored intersection can shrink
            // by 2*amplitude, not zero: reserve the full visible-body window at every phase.
            float safeAmplitude = Math.min(amplitude, (windowWidth - minWindow) * 0.5f);
            safeAmplitude = Math.min(safeAmplitude, Math.min(Math.min(first - edge,
                    width - edge - first), Math.min(second - edge, width - edge - second)));
            if (windowWidth >= movingMinWindow && safeAmplitude >= 2f * density
                    && random.nextFloat() < movingChance) {
                row.enableWave(safeAmplitude, LevelConfig.WAVE_PERIOD_SECONDS,
                        random.nextFloat() * 6.2831855f);
            } else if (level >= 4f) {
                // Second variant: two gaps breathe together, never combined with sideways
                // movement. Reserve the full safe window, edge clearance and solid sliver.
                float edgeRoom = 2f * Math.min(Math.min(first - edge, width - edge - first),
                        Math.min(second - edge, width - edge - second));
                float pulseRoom = Math.min(12f * density, Math.min(windowWidth - minWindow,
                        Math.min(edgeRoom, Math.abs(first - second) - gapWidth - sliver)));
                if (pulseRoom >= 3f * density && random.nextFloat() < 0.22f) {
                    row.enablePulse(pulseRoom, 3.2f, random.nextFloat() * 6.2831855f);
                }
            }
            return true;
        }
        return false;
    }

    /** Perfectly mirrored gaps: the widest possible safe window, always fair. */
    private boolean tryEasyMirror(ObstacleRow row, float level) {
        float gapWidth = gapFor(level);
        float margin = LevelConfig.EDGE_MARGIN_DP * density + LevelConfig.minSliver(density);
        float half = gapWidth * 0.5f + margin;
        if (half * 2f >= width) {
            return false;
        }
        float anchor = lastWindowCenter < 0f ? width * 0.5f : lastWindowCenter;
        float center = clamp(anchor, half, width - half);

        row.begin(-row.height, row.height);
        row.setGap(0, center, gapWidth);
        row.setGap(1, width - center, gapWidth);
        row.windowCenter = center;
        row.windowWidth = gapWidth;
        return true;
    }

    private void buildFallback(ObstacleRow row, float level) {
        float gapWidth = singleGapFor(level);
        float half = Math.min(gapWidth * 0.5f + LevelConfig.minSliver(density), width * 0.5f);
        float anchor = lastWindowCenter < 0f ? width * 0.5f : lastWindowCenter;
        float center = clamp(anchor, half, width - half);

        row.begin(-row.height, row.height);
        row.setGap(0, center, gapWidth);
        row.setGap(1, width - center, gapWidth);
        row.windowCenter = center;
        row.windowWidth = gapWidth;
    }

    // ------------------------------------------------------------------ collision

    private boolean collides() {
        float radius = leftPlayer.radius * COLLISION_FORGIVENESS;
        float playerTop = leftPlayer.y - radius;
        float playerBottom = leftPlayer.y + radius;

        for (int i = 0; i < rows.size(); i++) {
            ObstacleRow row = rows.get(i);
            if (mode == Mode.PRACTICE && practiceHitRows.contains(row)) continue;
            float top = row.y;
            float bottom = row.y + row.height;
            if (bottom < playerTop || top > playerBottom) {
                continue;
            }
            int segments = row.segments(width);
            for (int s = 0; s < segments; s++) {
                float left = row.segmentEdges[s * 2];
                float right = row.segmentEdges[s * 2 + 1];
                boolean hitLeft = circleHitsRect(leftPlayer.x, leftPlayer.y, radius, left, top, right, bottom);
                boolean hitRight = circleHitsRect(rightPlayer.x, rightPlayer.y, radius, left, top, right, bottom);
                if (hitLeft || hitRight) {
                    hitBall = hitLeft && hitRight ? 3 : (hitLeft ? 1 : 2);
                    Player hit = hitLeft ? leftPlayer : rightPlayer;
                    impactX = clamp(hit.x, left, right);
                    impactY = clamp(hit.y, top, bottom);
                    practiceHitRows.add(row);
                    return true;
                }
            }
        }
        return false;
    }

    /** Minimum distance from the relative motion segment to the pickup centre. */
    private static boolean sweptCircle(float x0, float y0, float x1, float y1, float radius) {
        float dx = x1 - x0, dy = y1 - y0;
        float length2 = dx * dx + dy * dy;
        float t = length2 > 0f ? clamp(-(x0 * dx + y0 * dy) / length2, 0f, 1f) : 0f;
        float x = x0 + t * dx, y = y0 + t * dy;
        return x * x + y * y <= radius * radius;
    }

    /**
     * Classic closest-point circle/rectangle test: clamp the centre to the rectangle and
     * compare the squared distance with the squared radius.
     */
    private static boolean circleHitsRect(float cx, float cy, float radius,
                                          float left, float top, float right, float bottom) {
        float closestX = clamp(cx, left, right);
        float closestY = clamp(cy, top, bottom);
        float dx = cx - closestX;
        float dy = cy - closestY;
        return dx * dx + dy * dy <= radius * radius;
    }

    private int computeScore() {
        return (int) (runSeconds * POINTS_PER_SECOND) + rowsCleared * POINTS_PER_ROW;
    }

    private static float clamp(float value, float min, float max) {
        if (value < min) {
            return min;
        }
        return value > max ? max : value;
    }
}
