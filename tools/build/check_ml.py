import sys

print("Python", sys.version.split()[0])
missing = []
for mod in ["torch", "ultralytics", "cv2", "numpy", "onnxruntime"]:
    try:
        m = __import__(mod)
        v = getattr(m, "__version__", "?")
        print("  %-12s OK   %s" % (mod, v))
    except Exception as e:
        print("  %-12s 缺失 (%s)" % (mod, type(e).__name__))
        missing.append(mod)

try:
    import torch
    print("CUDA 可用:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("  显卡:", torch.cuda.get_device_name(0))
except Exception as e:
    print("CUDA 检查失败:", e)

print("缺失模块:", missing if missing else "无")
