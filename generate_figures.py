"""Generate README figures for the adaptive shading project."""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe
import numpy as np
from matplotlib.colors import LinearSegmentedColormap

PASS_COLORS = {
    -1: "#1a1a2e",   # unshaded (dark)
    0:  "#e94560",    # pass 0 — red
    1:  "#f5a623",    # pass 1 — orange
    2:  "#50c878",    # pass 2 — green
    3:  "#4a90d9",    # pass 3 — blue
    4:  "#b07cd8",    # pass 4 — purple
}

PASS_LABELS = {
    0: "Pass 0 — Sparse Seed (1 px)",
    1: "Pass 1 — Diagonal Center (1 px)",
    2: "Pass 2 — Axis Midpoints (2 px)",
    3: "Pass 3 — Diagonal Midpoints (4 px)",
    4: "Pass 4 — Remaining (8 px)",
}

FILL_ORDER = np.array([
    [0, 4, 2, 4],
    [4, 3, 4, 3],
    [2, 4, 1, 4],
    [4, 3, 4, 3],
])


def draw_grid(ax, grid, show_numbers=True, title=None, highlight_pass=None):
    """Draw a 4x4 colored grid on the given axes."""
    for r in range(4):
        for c in range(4):
            val = grid[r, c]
            if highlight_pass is not None:
                if val == highlight_pass:
                    color = PASS_COLORS[val]
                    alpha = 1.0
                elif val >= 0 and val < highlight_pass:
                    color = PASS_COLORS[val]
                    alpha = 0.3
                else:
                    color = PASS_COLORS[-1]
                    alpha = 1.0
            else:
                color = PASS_COLORS.get(val, PASS_COLORS[-1])
                alpha = 1.0

            rect = mpatches.FancyBboxPatch(
                (c + 0.05, 3 - r + 0.05), 0.9, 0.9,
                boxstyle="round,pad=0.02",
                facecolor=color, alpha=alpha,
                edgecolor="#ffffff" if alpha > 0.5 else "#555555",
                linewidth=1.5,
            )
            ax.add_patch(rect)

            if show_numbers and val >= 0:
                text_alpha = alpha if alpha > 0.5 else 0.4
                ax.text(
                    c + 0.5, 3 - r + 0.5, str(val),
                    ha="center", va="center",
                    fontsize=16, fontweight="bold",
                    color="white", alpha=text_alpha,
                    path_effects=[pe.withStroke(linewidth=2, foreground="#00000088")],
                )

    ax.set_xlim(0, 4)
    ax.set_ylim(0, 4)
    ax.set_aspect("equal")
    ax.axis("off")
    if title:
        ax.set_title(title, fontsize=11, fontweight="bold", pad=8, color="#e0e0e0")


def generate_pass_progression():
    """Generate the 5-pass progression figure."""
    fig, axes = plt.subplots(1, 5, figsize=(18, 4.2), facecolor="#0d1117")
    fig.subplots_adjust(wspace=0.15, left=0.02, right=0.98, top=0.82, bottom=0.08)

    for p in range(5):
        grid = np.where(FILL_ORDER <= p, FILL_ORDER, -1)
        draw_grid(axes[p], grid, show_numbers=True, highlight_pass=p,
                  title=f"Pass {p}")

    for i in range(4):
        mid_x = (axes[i].get_position().x1 + axes[i + 1].get_position().x0) / 2
        fig.text(mid_x, 0.50, "\u2192", ha="center", va="center",
                 fontsize=22, color="#888888", fontweight="bold")

    legend_handles = [
        mpatches.Patch(facecolor=PASS_COLORS[p], edgecolor="white", linewidth=0.8, label=PASS_LABELS[p])
        for p in range(5)
    ]
    fig.legend(
        handles=legend_handles, loc="lower center", ncol=5,
        fontsize=9, frameon=False, labelcolor="#c0c0c0",
        handlelength=1.5, handleheight=1.2,
    )

    fig.savefig("Docs/pass_progression.png", dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print("Saved Docs/pass_progression.png")


def generate_fill_order():
    """Generate the fill order grid with pass numbers."""
    fig, ax = plt.subplots(1, 1, figsize=(4.5, 4.5), facecolor="#0d1117")
    fig.subplots_adjust(left=0.05, right=0.95, top=0.90, bottom=0.05)

    for r in range(4):
        for c in range(4):
            val = FILL_ORDER[r, c]
            color = PASS_COLORS[val]
            rect = mpatches.FancyBboxPatch(
                (c + 0.06, 3 - r + 0.06), 0.88, 0.88,
                boxstyle="round,pad=0.03",
                facecolor=color, edgecolor="#ffffff", linewidth=2,
            )
            ax.add_patch(rect)
            ax.text(
                c + 0.5, 3 - r + 0.5, str(val),
                ha="center", va="center",
                fontsize=22, fontweight="bold", color="white",
                path_effects=[pe.withStroke(linewidth=3, foreground="#00000088")],
            )

    ax.set_xlim(0, 4)
    ax.set_ylim(0, 4)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_title("Fill Order (pass index per pixel)", fontsize=13,
                 fontweight="bold", pad=12, color="#e0e0e0")

    fig.savefig("Docs/fill_order.png", dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print("Saved Docs/fill_order.png")


def generate_distribute_work():
    """Generate a diagram comparing naive vs DistributeWork wave utilization."""
    fig, axes = plt.subplots(2, 1, figsize=(14, 4.5), facecolor="#0d1117")
    fig.subplots_adjust(hspace=0.55, left=0.02, right=0.98, top=0.88, bottom=0.08)

    np.random.seed(42)
    n_lanes = 16
    needs_shade = np.random.random(n_lanes) > 0.45
    shade_color = "#e94560"
    interp_color = "#2a3a4a"
    idle_color = "#111822"
    packed_color = "#50c878"

    # --- Naive ---
    ax = axes[0]
    ax.set_title("Naive: threads diverge, idle lanes waste SIMD capacity",
                 fontsize=11, fontweight="bold", color="#e0e0e0", pad=8, loc="left")
    for i in range(n_lanes):
        color = shade_color if needs_shade[i] else interp_color
        rect = mpatches.FancyBboxPatch(
            (i + 0.06, 0.1), 0.88, 0.8,
            boxstyle="round,pad=0.02",
            facecolor=color, edgecolor="#555555", linewidth=1.2,
        )
        ax.add_patch(rect)
        label = "S" if needs_shade[i] else "I"
        ax.text(i + 0.5, 0.5, label, ha="center", va="center",
                fontsize=12, fontweight="bold",
                color="white" if needs_shade[i] else "#556677")

    shade_count = int(needs_shade.sum())
    idle_count = n_lanes - shade_count
    ax.text(n_lanes + 0.3, 0.5,
            f"{shade_count}S + {idle_count}I\n= {n_lanes} lanes\n({idle_count} idle during shade)",
            fontsize=9, va="center", color="#999999", family="monospace")

    ax.set_xlim(-0.2, n_lanes + 5)
    ax.set_ylim(-0.2, 1.2)
    ax.set_aspect("equal")
    ax.axis("off")

    # --- DistributeWork ---
    ax = axes[1]
    ax.set_title("DistributeWork: shade tasks packed, all lanes productive",
                 fontsize=11, fontweight="bold", color="#e0e0e0", pad=8, loc="left")

    for i in range(n_lanes):
        if i < shade_count:
            color = packed_color
            label = "S"
            text_color = "white"
        else:
            color = idle_color
            label = ""
            text_color = "#334455"

        rect = mpatches.FancyBboxPatch(
            (i + 0.06, 0.1), 0.88, 0.8,
            boxstyle="round,pad=0.02",
            facecolor=color,
            edgecolor="#555555" if i < shade_count else "#222222",
            linewidth=1.2,
        )
        ax.add_patch(rect)
        if label:
            ax.text(i + 0.5, 0.5, label, ha="center", va="center",
                    fontsize=12, fontweight="bold", color=text_color)

    ax.text(n_lanes + 0.3, 0.5,
            f"{shade_count}S packed\n= {shade_count}/{n_lanes} lanes active\n(no divergence waste)",
            fontsize=9, va="center", color="#999999", family="monospace")

    ax.set_xlim(-0.2, n_lanes + 5)
    ax.set_ylim(-0.2, 1.2)
    ax.set_aspect("equal")
    ax.axis("off")

    legend_handles = [
        mpatches.Patch(facecolor=shade_color, edgecolor="white", linewidth=0.6, label="Shade (naive)"),
        mpatches.Patch(facecolor=interp_color, edgecolor="white", linewidth=0.6, label="Interpolate (idle during shade)"),
        mpatches.Patch(facecolor=packed_color, edgecolor="white", linewidth=0.6, label="Shade (packed)"),
        mpatches.Patch(facecolor=idle_color, edgecolor="#333333", linewidth=0.6, label="Empty"),
    ]
    fig.legend(
        handles=legend_handles, loc="lower center", ncol=4,
        fontsize=9, frameon=False, labelcolor="#c0c0c0",
        handlelength=1.5, handleheight=1.2,
    )

    fig.savefig("Docs/distribute_work.png", dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print("Saved Docs/distribute_work.png")


def generate_super_block():
    """Generate a diagram showing 2x2 super-block mapping for pass 1 & 2."""
    fig, ax = plt.subplots(1, 1, figsize=(8, 8), facecolor="#0d1117")
    fig.subplots_adjust(left=0.05, right=0.95, top=0.92, bottom=0.05)

    block_colors = ["#e94560", "#f5a623", "#4a90d9", "#50c878"]
    block_labels = ["Block\n(0,0)", "Block\n(1,0)", "Block\n(0,1)", "Block\n(1,1)"]
    block_offsets = [(0, 4), (4, 4), (0, 0), (4, 0)]  # (col, row) in 8x8 grid, y-flipped

    for bi, (bc, br) in enumerate(block_offsets):
        for r in range(4):
            for c in range(4):
                rect = mpatches.FancyBboxPatch(
                    (bc + c + 0.06, br + r + 0.06), 0.88, 0.88,
                    boxstyle="round,pad=0.02",
                    facecolor=block_colors[bi], alpha=0.15,
                    edgecolor=block_colors[bi], linewidth=0.5,
                )
                ax.add_patch(rect)

        highlight_positions = {
            0: [(0, 0)],             # pass 0 pixel
            1: [(0, 0)],
            2: [(0, 0)],
            3: [(0, 0)],
        }

        pass1_pos = (2, 2)
        px, py = bc + pass1_pos[0], br + pass1_pos[1]
        rect = mpatches.FancyBboxPatch(
            (px + 0.06, py + 0.06), 0.88, 0.88,
            boxstyle="round,pad=0.02",
            facecolor=PASS_COLORS[1], alpha=0.9,
            edgecolor="white", linewidth=2,
        )
        ax.add_patch(rect)
        ax.text(px + 0.5, py + 0.5, "1", ha="center", va="center",
                fontsize=11, fontweight="bold", color="white",
                path_effects=[pe.withStroke(linewidth=2, foreground="#00000088")])

        p0_pos = (0, 0)
        px0, py0 = bc + p0_pos[0], br + p0_pos[1]
        rect0 = mpatches.FancyBboxPatch(
            (px0 + 0.06, py0 + 0.06), 0.88, 0.88,
            boxstyle="round,pad=0.02",
            facecolor=PASS_COLORS[0], alpha=0.9,
            edgecolor="white", linewidth=2,
        )
        ax.add_patch(rect0)
        ax.text(px0 + 0.5, py0 + 0.5, "0", ha="center", va="center",
                fontsize=11, fontweight="bold", color="white",
                path_effects=[pe.withStroke(linewidth=2, foreground="#00000088")])

        bx = bc + 2
        by = br + 2
        ax.text(bx, by - 0.8, block_labels[bi], ha="center", va="top",
                fontsize=8, color=block_colors[bi], alpha=0.8, fontweight="bold")

    for bi, (bc, br) in enumerate(block_offsets):
        rect_border = mpatches.FancyBboxPatch(
            (bc + 0.02, br + 0.02), 3.96, 3.96,
            boxstyle="round,pad=0.01",
            facecolor="none",
            edgecolor=block_colors[bi], linewidth=2.5, linestyle="--",
        )
        ax.add_patch(rect_border)

    super_border = mpatches.FancyBboxPatch(
        (-0.1, -0.1), 8.2, 8.2,
        boxstyle="round,pad=0.02",
        facecolor="none",
        edgecolor="#ffffff", linewidth=3,
    )
    ax.add_patch(super_border)
    ax.text(4, 8.5, "1 Super-Block = 2×2 blocks = 8×8 pixels",
            ha="center", va="center", fontsize=13, fontweight="bold", color="#e0e0e0")
    ax.text(4, -0.7, "1 lane processes 4 Pass-1 pixels (one per block)",
            ha="center", va="center", fontsize=10, color="#999999")

    ax.set_xlim(-0.8, 8.8)
    ax.set_ylim(-1.2, 9.0)
    ax.set_aspect("equal")
    ax.axis("off")

    fig.savefig("Docs/super_block.png", dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print("Saved Docs/super_block.png")


if __name__ == "__main__":
    import os
    os.makedirs("Docs", exist_ok=True)
    generate_pass_progression()
    generate_fill_order()
    generate_distribute_work()
    generate_super_block()
    print("All figures generated.")
