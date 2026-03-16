"""Generate a new teaser image comparing Reference vs Adaptive shading."""

import numpy as np
import imageio.v3 as iio
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.gridspec import GridSpec
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

BG_COLOR = "#0d1117"
TEXT_COLOR = "#e0e0e0"
ACCENT_REF = "#4a90d9"
ACCENT_ADP = "#50c878"
ACCENT_DIFF = "#e94560"


def load(path):
    img = iio.imread(path)
    if img.shape[2] == 4:
        img = img[:, :, :3]
    return img


def make_teaser():
    ref = load("Reference.png")
    adp = load("Result.png")
    h, w = ref.shape[:2]

    diff = np.abs(ref.astype(np.float32) - adp.astype(np.float32))
    diff_gray = np.mean(diff, axis=2)
    diff_amplified = np.clip(diff * 10, 0, 255).astype(np.uint8)

    mae = np.mean(diff)
    max_err = np.max(diff)
    psnr = 10 * np.log10(255**2 / (np.mean(diff**2) + 1e-10))
    match_pct = 100.0 * np.mean(diff_gray < 2.0)

    # Zoom region — pick an interesting area with detail
    zy, zx = int(h * 0.15), int(w * 0.45)
    zs = min(h, w) // 4
    crop_ref = ref[zy:zy+zs, zx:zx+zs]
    crop_adp = adp[zy:zy+zs, zx:zx+zs]
    crop_diff = diff_amplified[zy:zy+zs, zx:zx+zs]

    fig = plt.figure(figsize=(20, 11), facecolor=BG_COLOR)
    gs = GridSpec(2, 3, figure=fig, hspace=0.28, wspace=0.08,
                  left=0.03, right=0.97, top=0.92, bottom=0.04)

    fig.text(0.5, 0.96, "Deferred Adaptive Compute Shading",
             ha="center", va="center", fontsize=24, fontweight="bold",
             color=TEXT_COLOR, family="sans-serif")

    # --- Top row: full images ---
    panels = [
        (gs[0, 0], ref, "Reference (full shade)", ACCENT_REF),
        (gs[0, 1], adp, "Adaptive", ACCENT_ADP),
        (gs[0, 2], diff_amplified, "Difference (×10)", ACCENT_DIFF),
    ]

    top_axes = []
    for gs_pos, img, title, color in panels:
        ax = fig.add_subplot(gs_pos)
        ax.imshow(img)
        ax.set_title(title, fontsize=14, fontweight="bold", color=color, pad=10)
        ax.axis("off")

        for spine in ax.spines.values():
            spine.set_edgecolor(color)
            spine.set_linewidth(2)
            spine.set_visible(True)

        rect = mpatches.Rectangle(
            (zx, zy), zs, zs,
            linewidth=2, edgecolor="#ffffff", facecolor="none", linestyle="--"
        )
        ax.add_patch(rect)
        top_axes.append(ax)

    # --- Bottom row: zoomed crops + stats ---
    zoom_panels = [
        (gs[1, 0], crop_ref, "Zoom — Reference", ACCENT_REF),
        (gs[1, 1], crop_adp, "Zoom — Adaptive", ACCENT_ADP),
        (gs[1, 2], crop_diff, "Zoom — Difference (×10)", ACCENT_DIFF),
    ]

    for gs_pos, img, title, color in zoom_panels:
        ax = fig.add_subplot(gs_pos)
        ax.imshow(img, interpolation="nearest")
        ax.set_title(title, fontsize=13, fontweight="bold", color=color, pad=10)
        ax.axis("off")
        for spine in ax.spines.values():
            spine.set_edgecolor(color)
            spine.set_linewidth(2)
            spine.set_visible(True)

    # Stats overlay on the bottom-right panel
    stats_text = (
        f"PSNR: {psnr:.1f} dB\n"
        f"Mean Abs Error: {mae:.2f} / 255\n"
        f"Pixels within ±2: {match_pct:.1f}%"
    )
    fig.text(
        0.97, 0.06, stats_text,
        ha="right", va="bottom", fontsize=11,
        color="#cccccc", family="monospace",
        bbox=dict(boxstyle="round,pad=0.5", facecolor="#1a1a2e", edgecolor="#444444", alpha=0.9),
    )

    fig.savefig("teaser.png", dpi=120, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"Saved teaser.png  ({psnr:.1f} dB PSNR, {match_pct:.1f}% match)")


if __name__ == "__main__":
    make_teaser()
