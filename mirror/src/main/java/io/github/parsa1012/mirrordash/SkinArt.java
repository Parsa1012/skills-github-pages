package io.github.parsa1012.mirrordash;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;

/** Shared local artwork for gameplay and the shop preview. Artwork is cosmetic only. */
public final class SkinArt {
    private final Bitmap[] art = new Bitmap[BallPalette.assetCount()];
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final RectF bounds = new RectF();
    private final Path shape = new Path();
    public SkinArt(Context context) {
        for (int i = 0; i < art.length; i++) {
            int resource = context.getResources().getIdentifier("skin_" + BallPalette.assetName(i), "drawable", context.getPackageName());
            if (resource != 0) art[i] = BitmapFactory.decodeResource(context.getResources(), resource);
        }
    }
    public Path outline(int id, float x, float y, float r) {
        shape.reset();
        if (!BallPalette.premium(id)) { shape.addCircle(x, y, r, Path.Direction.CW); return shape; }
        int n = (id % 2 == 0) ? 5 : 6;
        for (int i = 0; i < n * 2; i++) {
            double angle = -Math.PI / 2 + i * Math.PI / n;
            float radius = (i % 2 == 0 ? .99f : .76f) * r;
            float px = x + (float)Math.cos(angle) * radius, py = y + (float)Math.sin(angle) * radius;
            if (i == 0) shape.moveTo(px, py); else shape.lineTo(px, py);
        }
        shape.close(); return shape;
    }
    public void image(Canvas canvas, int id, float x, float y, float r) {
        int index = BallPalette.assetIndex(id);
        if (index < 0 || art[index] == null) return;
        float size = r * .84f;
        bounds.set(x-size, y-size, x+size, y+size);
        paint.setColor(0xffffffff); paint.setShader(null); paint.setStyle(Paint.Style.FILL); paint.setAlpha(255);
        canvas.drawBitmap(art[index], null, bounds, paint);
    }
    public void preview(Canvas canvas, int id, float x, float y, float r, int color) {
        canvas.save(); canvas.clipPath(outline(id, x, y, r));
        paint.setStyle(Paint.Style.FILL); paint.setColor(color);
        paint.setShader(new RadialGradient(x-r*.35f, y-r*.4f, r*1.7f, 0xffffffff, color, Shader.TileMode.CLAMP));
        canvas.drawCircle(x, y, r, paint); paint.setShader(null);
        image(canvas, id, x, y, r); canvas.restore();
        paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(Math.max(1, r*.06f)); paint.setColor(0xffe9f3ff);
        canvas.drawPath(outline(id, x, y, r), paint); paint.setStyle(Paint.Style.FILL);
        if (BallPalette.premium(id)) {
            paint.setColor(color); paint.setAlpha(120);
            canvas.drawCircle(x-r*1.25f, y+r*.45f, r*.2f, paint);
            canvas.drawCircle(x-r*1.6f, y+r*.7f, r*.12f, paint); paint.setAlpha(255);
        }
    }
}
