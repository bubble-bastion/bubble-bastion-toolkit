"""本地 OCR：给一张图，输出识别到的文字和坐标（不联网、不臆测）。

用法:
  python ocr.py <图片路径> [--min-score 0.5]
输出:
  每行: x,y 宽x高  置信度  文字
"""
import sys
from rapidocr_onnxruntime import RapidOCR

def main():
    if len(sys.argv) < 2:
        print("用法: python ocr.py <图片>")
        return
    path = sys.argv[1]
    min_score = 0.5
    if "--min-score" in sys.argv:
        try:
            min_score = float(sys.argv[sys.argv.index("--min-score") + 1])
        except Exception:
            pass

    engine = RapidOCR()
    result, _ = engine(path)
    if not result:
        print("（没识别到文字）")
        return
    for box, text, score in result:
        if score < min_score:
            continue
        xs = [p[0] for p in box]; ys = [p[1] for p in box]
        x, y = int(min(xs)), int(min(ys))
        w, h = int(max(xs) - min(xs)), int(max(ys) - min(ys))
        print(f"{x},{y} {w}x{h}  {score:.2f}  {text}")

if __name__ == "__main__":
    main()
