#!/bin/bash
set -e

cd /workspace/forge

# --- Fix บั๊ก: host/template บางที่ set PYTORCH_VERSION ไว้ล่วงหน้าแบบไม่มี +cuXXX ---
# ทำให้ launch_utils.py regex parse ไม่ผ่าน (AttributeError: 'NoneType' object has no attribute 'group')
# ดึงค่าจริงจาก torch.__version__ เสมอ แทนที่ env var เดิม
export PYTORCH_VERSION="$(python3 -c "import torch; print(torch.__version__)")"
echo "[entrypoint] PYTORCH_VERSION fixed -> ${PYTORCH_VERSION}"

# --- เช็ค CUDA พร้อมใช้งานจริงก่อนเปิด webui (fail เร็ว ดีกว่ารอ error ลึกๆ ทีหลัง) ---
python3 -c "import torch; assert torch.cuda.is_available(), 'CUDA ไม่พร้อมใช้งานบน instance นี้'"

# --- โหลด checkpoint หลักอัตโนมัติ (ถ้ามี CHECKPOINT_URL ส่งมาเป็น environment variable) ---
# ใช้เลือกได้ว่าวันนี้จะเจนรูปด้วย checkpoint ตัวไหน (Z-Image Turbo, Illustrious, ฯลฯ)
# โดยไม่ต้อง SSH เข้าไปพิมพ์เอง — ถ้าไม่ตั้งค่า จะข้ามไป (โหลดทีหลังผ่านคำสั่ง `ckpt <URL>` แทนได้)
source /workspace/scripts/common_download.sh

if [ -n "${CHECKPOINT_URL}" ]; then
    echo "[entrypoint] พบ CHECKPOINT_URL — กำลังโหลด checkpoint หลัก..."
    download_asset "${CHECKPOINT_URL}" "/workspace/forge/models/Stable-diffusion" \
        || echo "[entrypoint] คำเตือน: โหลด checkpoint ไม่สำเร็จ — webui จะเปิดต่อโดยยังไม่มี checkpoint (แก้ทีหลังผ่าน ckpt ได้)"
else
    echo "[entrypoint] ไม่พบ CHECKPOINT_URL — ยังไม่มี checkpoint ให้เลือกตอนเปิด webui"
    echo "[entrypoint] โหลดเพิ่มทีหลังผ่าน SSH ด้วยคำสั่ง: ckpt <URL>"
fi

# --- ถ้าเป็น Z-Image checkpoint (MODEL_ARCH=zimage) ต้องมี text encoder + VAE แยกเสมอ ---
ensure_model_arch_deps "${MODEL_ARCH}" \
    || echo "[entrypoint] คำเตือน: โหลดไฟล์เสริมของ ${MODEL_ARCH} ไม่สำเร็จ — webui จะเปิดต่อ แก้ทีหลังผ่าน SSH ได้"

# --- แจ้งวิธีเข้า Forge Neo ---
# เอา ngrok ออกแล้ว: Vast.ai ให้ static public IP + port mapping ตรงมาอยู่แล้ว
# (ดูได้ที่หน้า Instance > IP & Port Info) เร็วกว่า ไม่มี request quota แบบ ngrok free plan
echo "=============================================="
echo "[entrypoint] Forge Neo กำลังเปิดที่ port 7860"
echo "[entrypoint] เข้าผ่าน IP:Port ที่หน้า Vast.ai (Instance > IP & Port Info)"
echo "=============================================="

echo "[entrypoint] Starting Forge Neo..."
# --cuda-malloc: Forge Neo เตือนใน log ทุกครั้งว่า RTX 30 series ขึ้นไปรองรับ flag นี้
# และช่วยเพิ่มความเร็วได้ (ยืนยันซ้ำจาก community guide การใช้ Wan 2.2 บน Forge Neo ด้วย)
# --xformers: เช็คแล้วว่า xformers==0.0.35 ต้องการ torch>=2.10 ตรงกับที่ pin ไว้ในโปรเจคนี้พอดี
# ช่วยเพิ่มความเร็วตอน generate จริง (attention layer) ถ้าติดตั้งไม่สำเร็จ webui จะเปิดต่อได้ปกติ
# (Forge Neo ครอบ try/except ไว้ ไม่ crash) แค่ไม่ได้ speed boost เท่านั้น
exec python3 launch.py --listen --port 7860 --api --cuda-malloc --xformers "$@"
