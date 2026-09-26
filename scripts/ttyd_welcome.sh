#!/bin/bash
# สคริปต์นี้ ttyd จะรันทุกครั้งที่มีคนเปิดลิงก์ terminal เข้ามา
# แสดงลิงก์ webui + คำสั่งที่ใช้บ่อย (ckpt/lora) ให้เห็นทันที ไม่ต้องไปงมใน log
# แล้วค่อย exec เข้า shell จริงต่อ (พิมพ์คำสั่งได้ตามปกติ)

clear
echo "=============================================="
echo " Forge Neo (webui): เข้าผ่าน IP:Port ที่หน้า Vast.ai (Instance > IP & Port Info)"
echo "=============================================="
echo " คำสั่งที่ใช้บ่อย:"
echo "   ckpt <URL> [zimage]   โหลด checkpoint ใหม่"
echo "   lora <URL1>,<URL2>    โหลด LoRA หลายตัวพร้อมกัน"
echo "=============================================="
echo ""

cd /workspace/forge
exec bash -l
