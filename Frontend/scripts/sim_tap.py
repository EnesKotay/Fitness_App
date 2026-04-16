#!/usr/bin/env python3
"""
sim_tap.py — iOS Simülatör dokunma/kaydırma yardımcısı (Xcode 26+ uyumlu)

Kullanım:
  python3 sim_tap.py tap <logical_x> <logical_y>
  python3 sim_tap.py swipe <x1> <y1> <x2> <y2> [adım=20] [gecikme_ms=15]
  python3 sim_tap.py info     → pencere bilgilerini göster
  python3 sim_tap.py cal      → kalibrasyon test doku (ekranı kontrol et)

Koordinatlar: simülatör mantıksal nokta (örn. iPhone 17: 0-402, 0-874)
"""

import ctypes, ctypes.util, time, subprocess, sys, json

# ─── CoreGraphics ───────────────────────────────────────────────────────────
cg = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))
cg.CGEventCreateMouseEvent.restype  = ctypes.c_void_p
cg.CGEventPost.argtypes             = [ctypes.c_uint32, ctypes.c_void_p]
cf = ctypes.CDLL(ctypes.util.find_library('CoreFoundation'))
cf.CFRelease.argtypes               = [ctypes.c_void_p]

class CGPoint(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]

kCGEventLeftMouseDown = 1
kCGEventLeftMouseUp   = 2
kCGEventMouseMoved    = 5
kCGHIDEventTap        = 0

# ─── Pencere bilgisi ────────────────────────────────────────────────────────
def get_sim_window():
    """Simulator penceresinin ekran konumu ve boyutunu döndür."""
    script = '''
tell application "System Events"
  repeat with p in processes
    if name of p is "Simulator" then
      set w to window 1 of p
      set pos to position of w
      set sz to size of w
      return (item 1 of pos) as text & "," & (item 2 of pos) as text & "," & (item 1 of sz) as text & "," & (item 2 of sz) as text
    end if
  end repeat
end tell
'''
    r = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    parts = r.stdout.strip().split(',')
    if len(parts) != 4:
        raise RuntimeError(f"Simulator penceresi bulunamadı: {r.stderr}")
    wx, wy, ww, wh = [int(p) for p in parts]
    return wx, wy, ww, wh

# iPhone 17 mantıksal çözünürlük (402×874 nokta)
# simctl enumerate'dan gelen fiziksel 1206×2622 → scale 3 → 402×874 logical
SIM_LOGICAL_W = 402
SIM_LOGICAL_H = 874
TITLE_BAR_H   = 28    # Simulator başlık çubuğu

def sim_to_screen(lx, ly):
    """Simülatör mantıksal koordinat → ekran pikseli."""
    wx, wy, ww, wh = get_sim_window()
    content_h = wh - TITLE_BAR_H
    sx = wx + lx * (ww / SIM_LOGICAL_W)
    sy = wy + TITLE_BAR_H + ly * (content_h / SIM_LOGICAL_H)
    return sx, sy

# ─── Dokunma / Kaydırma ─────────────────────────────────────────────────────
def activate_sim():
    subprocess.run(['osascript', '-e', 'tell application "Simulator" to activate'],
                   capture_output=True)
    time.sleep(0.3)

def raw_click(sx, sy):
    """Ekran koordinatlarına ham mouse down/up gönder."""
    p  = CGPoint(sx, sy)
    dn = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseDown, p, 0)
    cg.CGEventPost(kCGHIDEventTap, dn)
    time.sleep(0.05)
    up = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseUp, p, 0)
    cg.CGEventPost(kCGHIDEventTap, up)
    cf.CFRelease(dn)
    cf.CFRelease(up)

def tap(lx, ly):
    activate_sim()
    sx, sy = sim_to_screen(lx, ly)
    print(f"  TAP logical({lx:.0f},{ly:.0f}) → screen({sx:.0f},{sy:.0f})")
    raw_click(sx, sy)
    time.sleep(0.2)

def swipe(lx1, ly1, lx2, ly2, steps=25, delay_ms=12):
    """İki mantıksal nokta arasında parmak kaydırma simülasyonu."""
    activate_sim()
    sx1, sy1 = sim_to_screen(lx1, ly1)
    sx2, sy2 = sim_to_screen(lx2, ly2)
    print(f"  SWIPE ({lx1},{ly1})→({lx2},{ly2})")

    # Mouse down
    p0 = CGPoint(sx1, sy1)
    dn = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseDown, p0, 0)
    cg.CGEventPost(kCGHIDEventTap, dn)
    cf.CFRelease(dn)
    time.sleep(0.05)

    # Dragged moves
    for i in range(1, steps + 1):
        t  = i / steps
        mx = sx1 + (sx2 - sx1) * t
        my = sy1 + (sy2 - sy1) * t
        pm = CGPoint(mx, my)
        mv = cg.CGEventCreateMouseEvent(None, 6, pm, 0)  # kCGEventLeftMouseDragged=6
        cg.CGEventPost(kCGHIDEventTap, mv)
        cf.CFRelease(mv)
        time.sleep(delay_ms / 1000)

    # Mouse up
    p1 = CGPoint(sx2, sy2)
    up = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseUp, p1, 0)
    cg.CGEventPost(kCGHIDEventTap, up)
    cf.CFRelease(up)
    time.sleep(0.3)

# ─── CLI ────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    args = sys.argv[1:]
    if not args or args[0] == 'info':
        wx, wy, ww, wh = get_sim_window()
        print(f"Simulator penceresi: pos=({wx},{wy}) size={ww}×{wh}")
        print(f"Mantıksal çözünürlük: {SIM_LOGICAL_W}×{SIM_LOGICAL_H}")
        print(f"Ölçek (x): {ww/SIM_LOGICAL_W:.3f}  (y): {(wh-TITLE_BAR_H)/SIM_LOGICAL_H:.3f}")

    elif args[0] == 'tap' and len(args) >= 3:
        tap(float(args[1]), float(args[2]))

    elif args[0] == 'swipe' and len(args) >= 5:
        steps = int(args[5]) if len(args) > 5 else 25
        tap_delay = int(args[6]) if len(args) > 6 else 12
        swipe(float(args[1]), float(args[2]), float(args[3]), float(args[4]), steps, tap_delay)

    elif args[0] == 'scroll-up':
        swipe(201, 650, 201, 180)   # orta ekrandan yukarı kaydır

    elif args[0] == 'scroll-down':
        swipe(201, 250, 201, 650)

    elif args[0] == 'back':
        swipe(10, 437, 200, 437)    # sol kenardan sağa (iOS back gesture)

    elif args[0] == 'cal':
        # Kalibrasyon: 4 köşe + merkeze dokun
        print("Kalibrasyon dokuşları gönderiliyor...")
        for (lx, ly, label) in [
            (201, 437, 'merkez'),
            (50,  100, 'sol-üst'),
            (350, 100, 'sağ-üst'),
            (201, 800, 'alt-orta'),
        ]:
            print(f"  → {label} ({lx},{ly})")
            tap(lx, ly)
            time.sleep(0.5)
        print("Kalibrasyon tamamlandı — ekran görüntüsü alıp kontrol et.")

    else:
        print(__doc__)
