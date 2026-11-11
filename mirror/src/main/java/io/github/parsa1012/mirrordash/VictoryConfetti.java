package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.os.SystemClock;
import android.view.View;
import java.util.Random;

/** Small, bounded celebration overlay. It never consumes input and stops drawing after 3 seconds. */
public final class VictoryConfetti extends View {
    private static final int COUNT = 80;
    private static final long DURATION = 3000;
    private final float[] vx = new float[COUNT], vy = new float[COUNT], size = new float[COUNT];
    private final int[] color = new int[COUNT];
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private long start;
    private final float density;

    public VictoryConfetti(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        setClickable(false);
        setVisibility(GONE);
        Random rng = new Random(1901);
        int[] colors = {0xff54d7ff, 0xffff638d, 0xffffd45c, 0xffa38bff, 0xff6aefb6};
        for (int i = 0; i < COUNT; i++) {
            vx[i] = (55 + rng.nextFloat() * 170) * density;
            vy[i] = (25 + rng.nextFloat() * 180) * density;
            size[i] = (4 + rng.nextFloat() * 5) * density;
            color[i] = colors[i % colors.length];
        }
    }

    public void celebrate() {
        start = SystemClock.uptimeMillis();
        setVisibility(VISIBLE);
        invalidate();
    }
    public void stop() { setVisibility(GONE); }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float t = (SystemClock.uptimeMillis() - start) / 1000f;
        if (t * 1000 >= DURATION) { setVisibility(GONE); return; }
        float alpha = Math.min(1f, (3f - t) * 1.5f);
        for (int i = 0; i < COUNT; i++) {
            float delay = (i % 9) * .05f;
            float age = Math.max(0, t - delay);
            float x = (i % 2 == 0 ? 0 : getWidth()) + (i % 2 == 0 ? 1 : -1) * vx[i] * age;
            float y = -12 * density + vy[i] * age + 90 * density * age * age;
            paint.setColor(color[i]);
            paint.setAlpha((int) (255 * alpha));
            canvas.save();
            canvas.rotate(age * (i % 2 == 0 ? 240 : -220) + i * 17, x, y);
            canvas.drawRect(x, y, x + size[i], y + size[i] * .6f, paint);
            canvas.restore();
        }
        postInvalidateOnAnimation();
    }
}
