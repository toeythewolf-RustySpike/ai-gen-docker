#!/bin/bash
# =============================================================
# comfyui_vast_setup.sh
# สคริปต์ setup สำหรับ ComfyUI บน Vast.ai (template: vastai/comfy)
# แยกไฟล์จาก Forge Neo entrypoint.sh โดยเจตนา — คนละระบบ ไม่เกี่ยวกัน
# รันครั้งเดียวหลังเปิด Jupyter Terminal ของ instance ใหม่
# =============================================================
set -e

echo "=== เช็ค environment ก่อนทำอะไร ==="
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
df -h /workspace
echo "อยู่ใน tmux อยู่แล้วหรือไม่: ${TMUX:-ยังไม่ได้อยู่}"

if [ ! -d "/workspace/ComfyUI" ]; then
  echo "!! ไม่เจอ /workspace/ComfyUI — เช็คว่าเลือก template ถูกหรือเปล่า แล้วหยุดก่อนรันต่อ"
  exit 1
fi

if [ -z "$TMUX" ]; then
  echo "แนะนำ: รัน 'tmux new -s comfy' ก่อน แล้วค่อยรันสคริปต์นี้อีกทีข้างในนั้น"
fi

echo "=== ติดตั้ง aria2 (ใช้โหลดไฟล์ทุกไฟล์ >200MB) ==="
which aria2c >/dev/null 2>&1 && echo "มีอยู่แล้ว ข้าม" || (apt-get update -y && apt-get install -y aria2)

echo "=== สร้างโฟลเดอร์โมเดลให้ครบ (เผื่อโมเดลแบบแยกไฟล์อย่าง Flux/Z-Image/Krea2) ==="
mkdir -p /workspace/ComfyUI/models/{checkpoints,diffusion_models,loras,vae,text_encoders,controlnet,upscale_models,embeddings}

echo "=== เช็ค/ติดตั้ง ComfyUI-Manager ==="
cd /workspace/ComfyUI/custom_nodes
if find . -maxdepth 1 -iname "comfyui-manager" | grep -q .; then
  echo "มี Manager ติดมากับ template แล้ว ข้าม"
else
  git clone https://github.com/Comfy-Org/ComfyUI-Manager comfyui-manager
  pip install -r comfyui-manager/requirements.txt --break-system-packages 2>/dev/null || pip install -r comfyui-manager/requirements.txt
fi

echo "=== เพิ่ม shortcut โหลดโมเดล: ckpt / lora / vae / unet / clipenc ==="
if grep -q "_dl_model" ~/.bashrc 2>/dev/null; then
  sed -i '/^_dl_model() {/,/^}/d' ~/.bashrc
  sed -i '/^ckpt()/d;/^lora()/d;/^vae()/d;/^unet()/d;/^clipenc()/d' ~/.bashrc
fi
cat >> ~/.bashrc << 'EOF'

# --- ComfyUI model download shortcuts (comfyui_vast_setup.sh) ---
_dl_model() {
  local folder="$1"; local url="$2"
  mkdir -p "/workspace/ComfyUI/models/$folder" && cd "/workspace/ComfyUI/models/$folder" || return 1

  local filename=""
  if [[ "$url" == *civitai.com* || "$url" == *civitai.red* ]]; then
    local origin=$(echo "$url" | grep -oP '(?<=https://)[^/]+')
    local vid=$(echo "$url" | grep -oP '(?<=modelVersionId=)\d+|(?<=/api/download/models/)\d+')
    if [ -z "$vid" ]; then
      local mid=$(echo "$url" | grep -oP '(?<=/models/)\d+')
      if [ -n "$mid" ]; then
        vid=$(curl -s -H "Authorization: Bearer ${CIVITAI_TOKEN}" "https://${origin}/api/v1/models/${mid}" | grep -oP '"modelVersions":\[\{"id":\K\d+')
      fi
    fi
    if [ -n "$vid" ]; then
      echo "กำลังดึงชื่อไฟล์จริงจาก Civitai..."
      local meta=$(curl -s -H "Authorization: Bearer ${CIVITAI_TOKEN}" "https://${origin}/api/v1/model-versions/${vid}")
      filename=$(echo "$meta" | grep -oP '"name":"\K[^"]+\.(safetensors|ckpt|pt)' | head -1)
      url="https://${origin}/api/download/models/${vid}"
      [ -n "$CIVITAI_TOKEN" ] && url="${url}?token=${CIVITAI_TOKEN}"
    else
      echo "!! หาเวอร์ชันโมเดลไม่เจอ ให้ copy link จากปุ่ม Download บนเว็บแทน"
      return 1
    fi
  fi

  if [ -n "$filename" ]; then
    echo "ชื่อไฟล์: $filename"
    aria2c -x16 -s16 -k1M -o "$filename" "$url"
  else
    aria2c -x16 -s16 -k1M --content-disposition-default-utf8=true "$url"
  fi
}

ckpt()    { _dl_model "checkpoints" "$1"; }
lora()    { _dl_model "loras" "$1"; }
vae()     { _dl_model "vae" "$1"; }
unet()    { _dl_model "diffusion_models" "$1"; }
clipenc() { _dl_model "text_encoders" "$1"; }
EOF
echo "เพิ่ม/อัปเดต shortcut แล้ว"
source ~/.bashrc

echo ""
echo "=== เสร็จแล้ว ==="
echo "ใช้งาน shortcut ได้เลย เช่น:"
echo '  export CIVITAI_TOKEN="xxxxxxxx"   # ตั้งถ้าโมเดลต้อง login'
echo '  ckpt https://civitai.com/models/12345?modelVersionId=67890'
echo '  unet https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors'
echo ""
echo "เปิด ComfyUI จากหน้า portal แล้วเช็คว่าหน้า UI ขึ้นปกติ"
