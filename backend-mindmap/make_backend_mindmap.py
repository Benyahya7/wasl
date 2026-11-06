#!/usr/bin/env python3
"""Generate the Wasl entire-system backend mind map as SVG inside an HTML page.
Layout: centre node, 4 branches left, 5 branches right. Wasl colours.
Output: backend-mindmap.html (2400x1620 canvas) next to this script.
"""
import html

W, H = 2400, 1620
CX, CY = 1200, 810

TEAL = "#0C4A4E"
INK = "#10201F"
AMBER = "#F2A81D"
BG = "#FAF8F3"
GREY = "#5A6B6B"

BRANCHES_LEFT = [
    ("Four surfaces", TEAL, [
        "Store app S1-S10 - creates deliveries",
        "Driver app D1-D10 - own + marketplace",
        "Customer link C1-C3 - no login, token",
        "Admin web A1-A8 - approvals, money",
    ]),
    ("Firestore collections", "#14635F", [
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
    ("Auth & rules", "#2E6FB7", [
        "Google + phone sign-in",
        "Roles enforced by server rules",
        "Customer: per-order token, no account",
        "Admin reads all, writes approvals",
    ]),
    ("Storage", "#6C5CE7", [
        "Delivery photo = proof, per stop",
        "Profile photos (store / driver)",
    ]),
]

BRANCHES_RIGHT = [
    ("Realtime", "#2E7D32", [
        "Live status, no refresh",
        "Trip-only driver location",
        "Chat + job board live",
    ]),
    ("Cloud Functions (Blaze)", "#C0392B", [
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
    ("Outside services", "#E67E22", [
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

LEAF_FS = 15
TITLE_FS = 20
LEAF_H = 30
LEAF_GAP = 44
BRANCH_GAP = 30


def text_w(s, fs):
    return len(s) * (fs * 0.55) + 30


def esc(s):
    return html.escape(s)


parts = []
parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, sans-serif">')
parts.append(f'<rect width="{W}" height="{H}" fill="{BG}"/>')

# Title + subtitle + footer
parts.append(f'<text x="{W//2}" y="56" text-anchor="middle" font-size="36" font-weight="bold" fill="{TEAL}">Wasl — Entire System Backend</text>')
parts.append(f'<text x="{W//2}" y="92" text-anchor="middle" font-size="19" fill="{GREY}">One Firebase backend · four surfaces · cash first · global by design</text>')
parts.append(f'<text x="{W//2}" y="1588" text-anchor="middle" font-size="15" fill="{GREY}">Firebase: Firestore · Auth · Storage · Cloud Functions (Blaze) · FCM · Spark free to start · Stripe deferred · 2026-11-06</text>')

# Centre node
cw, ch = 320, 116
cx0, cy0 = CX - cw // 2, CY - ch // 2
parts.append(f'<rect x="{cx0}" y="{cy0}" width="{cw}" height="{ch}" rx="24" fill="{TEAL}"/>')
parts.append(f'<rect x="{cx0}" y="{cy0}" width="{cw}" height="{ch}" rx="24" fill="none" stroke="{AMBER}" stroke-width="4"/>')
parts.append(f'<text x="{CX}" y="{CY - 12}" text-anchor="middle" font-size="32" font-weight="bold" fill="#FFFFFF">Wasl Backend</text>')
parts.append(f'<text x="{CX}" y="{CY + 26}" text-anchor="middle" font-size="17" fill="{AMBER}">Firebase · no server to run</text>')


def branch_block_height(leaves):
    return len(leaves) * LEAF_GAP + 56


def draw_side(branches, side):
    """side: -1 left, +1 right. Returns nothing; appends to parts."""
    total = sum(branch_block_height(l) for _, _, l in branches) + BRANCH_GAP * (len(branches) - 1)
    y = CY - total // 2
    title_cx = CX + side * 250
    leaf_edge = CX + side * 460  # leaves' inner edge (right edge on left side, left edge on right)
    for title, color, leaves in branches:
        tw = text_w(title, TITLE_FS)
        tx0 = title_cx - tw // 2
        ty = y + 22  # title pill centre y
        # connector: centre node edge -> title pill (approach from the top so a wide title never gets crossed by its own line)
        sx = CX + side * (cw // 2)
        parts.append(
            f'<path d="M {sx} {CY} C {sx + side * 90} {CY}, {title_cx} {ty - 60}, {title_cx} {ty - 21}" '
            f'fill="none" stroke="{color}" stroke-width="3" opacity="0.6"/>'
        )
        dark_text = color == AMBER
        parts.append(f'<rect x="{tx0}" y="{ty - 21}" width="{tw}" height="42" rx="21" fill="{color}"/>')
        parts.append(
            f'<text x="{title_cx}" y="{ty + 7}" text-anchor="middle" font-size="{TITLE_FS}" '
            f'font-weight="bold" fill="{"#10201F" if dark_text else "#FFFFFF"}">{esc(title)}</text>'
        )
        # leaves
        ly = y + 62
        for leaf in leaves:
            lw = text_w(leaf, LEAF_FS)
            if side == -1:
                lx0 = leaf_edge - lw
                lx1 = leaf_edge
            else:
                lx0 = leaf_edge
                lx1 = leaf_edge + lw
            lcy = ly + LEAF_H // 2
            # connector: title pill inner edge -> leaf inner edge
            tsx = title_cx - side * (tw // 2)
            parts.append(
                f'<path d="M {tsx} {ty} C {tsx - side * 40} {ty}, {lx1 + side * 40} {lcy}, {lx1} {lcy}" '
                f'fill="none" stroke="{color}" stroke-width="2" opacity="0.5"/>'
            )
            parts.append(
                f'<rect x="{lx0}" y="{ly}" width="{lw}" height="{LEAF_H}" rx="15" fill="#FFFFFF" '
                f'stroke="{color}" stroke-width="1.6"/>'
            )
            parts.append(
                f'<circle cx="{lx0 + 14 if side == 1 else lx1 - 14}" cy="{lcy}" r="4.5" fill="{color}"/>'
            )
            tx = lx0 + 26 if side == 1 else lx1 - 26
            anchor = "start" if side == 1 else "end"
            parts.append(
                f'<text x="{tx}" y="{lcy + 5}" text-anchor="{anchor}" font-size="{LEAF_FS}" fill="{INK}">{esc(leaf)}</text>'
            )
            ly += LEAF_GAP
        y += branch_block_height(leaves) + BRANCH_GAP


draw_side(BRANCHES_LEFT, -1)
draw_side(BRANCHES_RIGHT, 1)
parts.append("</svg>")

svg = "\n".join(parts)
html_doc = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Wasl Backend Mind Map</title>
<style>body{{margin:0;background:{BG};}}svg{{display:block;}}</style></head>
<body>{svg}</body></html>"""

with open("backend-mindmap.html", "w", encoding="utf-8") as f:
    f.write(html_doc)
print("wrote backend-mindmap.html", len(html_doc), "bytes")
