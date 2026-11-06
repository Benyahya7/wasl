#!/usr/bin/env python3
"""Render the Wasl backend mind map to PNG with PIL (same layout as the SVG version).
Headless Chrome is blocked on this VM, so PIL draws it directly.
Output: backend-mindmap.png (2400x1620)."""
from PIL import Image, ImageDraw, ImageFont

W, H = 2400, 1620
CX, CY = 1200, 810
TEAL = (12, 74, 78)
INK = (16, 32, 31)
AMBER = (242, 168, 29)
BG = (250, 248, 243)
GREY = (90, 107, 107)
WHITE = (255, 255, 255)

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def f(path, size):
    return ImageFont.truetype(path, size)


BRANCHES_LEFT = [
    ("Four surfaces", TEAL, [
        "Store app S1-S10 - creates deliveries",
        "Driver app D1-D10 - own + marketplace",
        "Customer link C1-C3 - no login, token",
        "Admin web A1-A8 - approvals, money",
    ]),
    ("Firestore collections", (20, 99, 95), [
        "users - role: store / driver / admin",
        "stores - business, zone, fees",
        "drivers - vehicle, verification, rating",
        "deliveries - THE CORE order doc",
        "runs - batched multi-stop runs",
        "chats - one thread per order",
        "ratings - store to driver, per delivery",
        "payouts - pay, cash, weekly totals",
        "zones - boundaries, fees",
    ]),
    ("Auth & rules", (46, 111, 183), [
        "Google + phone sign-in",
        "Roles enforced by server rules",
        "Customer: per-order token, no account",
        "Admin reads all, writes approvals",
    ]),
    ("Storage", (108, 92, 231), [
        "Delivery photo = proof, per stop",
        "Profile photos (store / driver)",
    ]),
]

BRANCHES_RIGHT = [
    ("Realtime", (46, 125, 50), [
        "Live status, no refresh",
        "Trip-only driver location",
        "Chat + job board live",
    ]),
    ("Cloud Functions (Blaze)", (192, 57, 43), [
        "2-min auto-escalation timer",
        "Push: assign / decline / delivered",
        "Payout math on the server",
        "LIMIT: needs Blaze, Spark cannot",
    ]),
    ("Money", AMBER, [
        "Cash only at start",
        "Driver returns ALL cash, keeps tip",
        "Card per store later (admin switch)",
        "Revenue: per-delivery + monthly",
    ]),
    ("Outside services", (230, 126, 34), [
        "Google Maps - routes, ETA",
        "Stripe - deferred (cash first)",
        "Resend - order emails",
        "SMS provider - to decide",
    ]),
    ("Order flow", INK, [
        "1  Create delivery (store)",
        "2  Assign / Broadcast / Auto",
        "3  Driver accepts",
        "4  Picked up",
        "5  On the way",
        "6  Delivered + photo",
        "7  Paid (cash recorded)",
    ]),
]

LEAF_GAP = 44
BRANCH_GAP = 30

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img, "RGBA")


def bezier(p0, p1, p2, p3, color, width):
    pts = []
    for i in range(31):
        t = i / 30
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    d.line(pts, fill=color + (150,), width=width, joint="curve")


def text_w(s, font):
    return d.textlength(s, font=font)


# Title + subtitle + footer
d.text((W // 2, 56), "Wasl — Entire System Backend", font=f(FONTB, 36), fill=TEAL, anchor="mm")
d.text((W // 2, 94), "One Firebase backend · four surfaces · cash first · global by design",
       font=f(FONT, 19), fill=GREY, anchor="mm")
d.text((W // 2, 1588), "Firebase: Firestore · Auth · Storage · Cloud Functions (Blaze) · FCM · Spark free to start · Stripe deferred · 2026-11-06",
       font=f(FONT, 15), fill=GREY, anchor="mm")

# Centre node
cw, ch = 320, 116
cx0, cy0 = CX - cw // 2, CY - ch // 2
d.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=24, fill=TEAL, outline=AMBER, width=4)
d.text((CX, CY - 12), "Wasl Backend", font=f(FONTB, 32), fill=WHITE, anchor="mm")
d.text((CX, CY + 26), "Firebase · no server to run", font=f(FONT, 17), fill=AMBER, anchor="mm")


def block_h(leaves):
    return len(leaves) * LEAF_GAP + 56


def draw_side(branches, side):
    total = sum(block_h(l) for _, _, l in branches) + BRANCH_GAP * (len(branches) - 1)
    y = CY - total // 2
    title_cx = CX + side * 250
    leaf_edge = CX + side * 460
    for title, color, leaves in branches:
        tfont = f(FONTB, 20)
        tw = text_w(title, tfont) + 34
        tx0 = title_cx - tw // 2
        ty = y + 22
        sx = CX + side * (cw // 2)
        # Approach the title pill from the top so a wide title never gets crossed by its own line
        bezier((sx, CY), (sx + side * 90, CY), (title_cx, ty - 60), (title_cx, ty - 21), color, 3)
        d.rounded_rectangle([tx0, ty - 21, tx0 + tw, ty + 21], radius=21, fill=color)
        tfill = INK if color == AMBER else WHITE
        d.text((title_cx, ty), title, font=tfont, fill=tfill, anchor="mm")
        lfont = f(FONT, 15)
        ly = y + 62
        for leaf in leaves:
            lw = text_w(leaf, lfont) + 44
            if side == -1:
                lx0, lx1 = leaf_edge - lw, leaf_edge
            else:
                lx0, lx1 = leaf_edge, leaf_edge + lw
            lcy = ly + 15
            tsx = title_cx - side * (tw // 2)
            bezier((tsx, ty), (tsx - side * 40, ty), (lx1 + side * 40, lcy), (lx1, lcy), color, 2)
            d.rounded_rectangle([lx0, ly, lx0 + lw, ly + 30], radius=15, fill=WHITE, outline=color, width=2)
            dotx = lx0 + 15 if side == 1 else lx1 - 15
            d.ellipse([dotx - 4.5, lcy - 4.5, dotx + 4.5, lcy + 4.5], fill=color)
            if side == 1:
                d.text((lx0 + 27, lcy), leaf, font=lfont, fill=INK, anchor="lm")
            else:
                d.text((lx1 - 27, lcy), leaf, font=lfont, fill=INK, anchor="rm")
            ly += LEAF_GAP
        y += block_h(leaves) + BRANCH_GAP


draw_side(BRANCHES_LEFT, -1)
draw_side(BRANCHES_RIGHT, 1)

img.save("backend-mindmap.png")
print("wrote backend-mindmap.png", img.size)
