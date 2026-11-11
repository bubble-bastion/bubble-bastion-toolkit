"""实时视觉伺服（closed-loop）原型 —— 感知与控制并行，不是串行。

架构（对标低速自动驾驶）:
  采集线程  ──写──>  [最新帧]  ──读──> 主循环(检测高亮格 → 算误差 → 发 MOVE)
      ↑ 持续跑，不等主循环                        ↓
      └────────────── 控制 ~12Hz，感知 ~3Hz ──────┘

关键点: 采集用后台线程，主循环永远拿"最新一帧"，不会因为等待采集而空转。
        raw 帧（不编码 PNG）比 PNG 快一倍：597ms → 324ms。

用法:
  python servo.py --probe           # 只测闭环频率，不发控制
  python servo.py --hold X Y        # 按住 (X,Y) 的干员，闭环拖到检测出的第一个高亮格
"""
import argparse
import subprocess
import sys
import threading
import time
from collections import deque

import numpy as np
from PIL import Image

ADB = r"D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe"
DEV = "127.0.0.1:16416"
W, H = 1280, 720


def adb(args, timeout=10):
    return subprocess.run([ADB, "-s", DEV] + args, capture_output=True, timeout=timeout)


class FrameGrabber(threading.Thread):
    """后台持续抓帧，只保留最新一帧（像车载摄像头的环形缓冲）。"""

    def __init__(self):
        super().__init__(daemon=True)
        self.frame = None
        self.seq = 0
        self.running = True
        self.times = deque(maxlen=30)
        self.lock = threading.Lock()

    def run(self):
        while self.running:
            t0 = time.perf_counter()
            try:
                r = adb(["exec-out", "screencap"], timeout=8)
                raw = r.stdout
                # 头 12 或 16 字节：w,h,format(,colorSpace)
                if len(raw) < W * H * 4:
                    continue
                off = len(raw) - W * H * 4
                arr = np.frombuffer(raw, dtype=np.uint8, count=W * H * 4, offset=off)
                arr = arr.reshape((H, W, 4))[:, :, :3]
                with self.lock:
                    self.frame = arr
                    self.seq += 1
                self.times.append(time.perf_counter() - t0)
            except Exception:
                time.sleep(0.05)

    def latest(self):
        with self.lock:
            return self.frame

    def fps(self):
        if not self.times:
            return 0.0
        return 1.0 / (sum(self.times) / len(self.times))


def detect_tiles(arr):
    """黄绿高亮（围墙和地面都会亮，靠"有没有一圈边"再区分）。"""
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    mask = (g > 130) & ((g - b) > 60) & ((g - r) > 20)
    mask[:100, :] = False
    mask[540:, :] = False
    if mask.sum() < 400:
        return []
    ys, xs = np.nonzero(mask)
    tiles = []
    seen = np.zeros_like(mask)
    for i in range(len(xs)):
        x0, y0 = xs[i], ys[i]
        if seen[y0, x0]:
            continue
        # 简单泛洪（用 BFS 队列）
        stack = [(x0, y0)]
        seen[y0, x0] = True
        mnx = mxx = x0
        mny = mxy = y0
        n = 0
        while stack:
            x, y = stack.pop()
            n += 1
            if x < mnx: mnx = x
            if x > mxx: mxx = x
            if y < mny: mny = y
            if y > mxy: mxy = y
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((nx, ny))
        w = mxx - mnx + 1
        h = mxy - mny + 1
        if n >= 400 and 35 <= w <= 140 and 20 <= h <= 140:
            tiles.append((mnx + w // 2, mny + h // 2, w, h))
    tiles.sort(key=lambda t: (t[1] // 35, t[0]))
    return tiles


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--hold", nargs=2, type=int)
    ap.add_argument("--seconds", type=float, default=3.0)
    a = ap.parse_args()

    g = FrameGrabber()
    g.start()
    time.sleep(1.2)  # 等第一帧

    if a.probe:
        t_end = time.perf_counter() + a.seconds
        n = 0
        while time.perf_counter() < t_end:
            f = g.latest()
            if f is None:
                time.sleep(0.02)
                continue
            n += 1
            time.sleep(0.01)
        print(f"采集线程帧率: {g.fps():.1f} FPS")
        f = g.latest()
        if f is not None:
            t0 = time.perf_counter()
            tiles = detect_tiles(f)
            dt = (time.perf_counter() - t0) * 1000
            print(f"单帧检测耗时: {dt:.1f} ms，检出 {len(tiles)} 格")
            for t in tiles:
                print(f"  ({t[0]},{t[1]}) {t[2]}x{t[3]}")
        g.running = False
        return

    if a.hold:
        sx, sy = a.hold
        adb(["shell", f"input motionevent DOWN {sx} {sy}"])
        time.sleep(0.6)
        adb(["shell", f"input motionevent MOVE {sx-4} {sy-12}"])
        time.sleep(1.2)
        cycles = 0
        t_end = time.perf_counter() + 4.0
        target = None
        while time.perf_counter() < t_end:
            f = g.latest()
            if f is None:
                continue
            tiles = detect_tiles(f)
            cycles += 1
            if tiles and target is None:
                target = tiles[0]
                print(f"锁定目标格 {target}")
            if target:
                # 视觉伺服：朝目标挪一小步（模拟方向盘微调）
                adb(["shell", f"input motionevent MOVE {target[0]} {target[1]}"])
            time.sleep(0.05)
        # 松手必须落在目标格上，否则干员会弹回整备区
        if target:
            adb(["shell", f"input motionevent UP {target[0]} {target[1]}"])
            print(f"在目标格 ({target[0]},{target[1]}) 松手")
        else:
            adb(["shell", f"input motionevent UP {sx-4} {sy-12}"])
            print("没锁定目标，原地松手（取消）")
        print(f"4 秒内完成 {cycles} 个闭环周期 ≈ {cycles/4:.1f} Hz")
        g.running = False
        return

    print("用 --probe 或 --hold X Y")
    g.running = False


if __name__ == "__main__":
    main()
