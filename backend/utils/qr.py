from PIL import Image, ImageDraw, ImageFont
import qrcode
import os
from pathlib import Path
from datetime import datetime

# Folder untuk menyimpan QR codes
QR_DIR = Path("static/qrcodes")
QR_DIR.mkdir(parents=True, exist_ok=True)

def generate_batch_qr(batch_id: str, base_url: str, batch_details: dict = None):
    """
    Generate QR code for a batch with text overlay and save it as PNG.
    """
    # URL format: http://[ip]:[port]/update-batch/[batch_id]
    data = f"{base_url}/update-batch/{batch_id}"
    
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H, # Higher error correction for overlay
        box_size=10,
        border=2,
    )
    qr.add_data(data)
    qr.make(fit=True)

    qr_img = qr.make_image(fill_color="black", back_color="white").convert('RGB')
    
    # Create a larger canvas (QR is 290x290 approx with default settings)
    # We want a landscape card format: QR on left/right, text on the other side
    canvas_width = 600
    canvas_height = 300
    canvas = Image.new('RGB', (canvas_width, canvas_height), color='white')
    
    # Paste QR
    qr_size = 280
    qr_img = qr_img.resize((qr_size, qr_size))
    canvas.paste(qr_img, (10, 10))
    
    # Draw Text
    draw = ImageDraw.Draw(canvas)
    
    # Try to load a font, fallback to default
    try:
        # Windows font path
        font_bold = ImageFont.truetype("arialbd.ttf", 24)
        font_regular = ImageFont.truetype("arial.ttf", 18)
        font_small = ImageFont.truetype("arial.ttf", 14)
    except:
        font_bold = ImageFont.load_default()
        font_regular = ImageFont.load_default()
        font_small = ImageFont.load_default()

    text_x = 300
    curr_y = 40
    
    draw.text((text_x, curr_y), f"BATCH: {batch_id}", fill="black", font=font_bold)
    curr_y += 40
    
    if batch_details:
        draw.text((text_x, curr_y), f"Varietas: {batch_details.get('varietas', '-')}", fill="black", font=font_regular)
        curr_y += 30
        draw.text((text_x, curr_y), f"Lokasi: {batch_details.get('lokasi', '-')}", fill="black", font=font_regular)
        curr_y += 30
        
        tgl = batch_details.get('tanggal_semai')
        if isinstance(tgl, datetime):
            tgl_str = tgl.strftime('%d %b %Y')
        else:
            tgl_str = str(tgl)
            
        draw.text((text_x, curr_y), f"Tgl Semai: {tgl_str}", fill="black", font=font_regular)
        curr_y += 30
        draw.text((text_x, curr_y), f"Jumlah Awal: {batch_details.get('jumlah_awal', '0')}", fill="black", font=font_regular)

    # Add SIBIT Footer
    draw.text((text_x, 260), "SIBIT - Sistem Tracking Bibit", fill="gray", font=font_small)
    
    file_name = f"qr_{batch_id}.png"
    file_path = QR_DIR / file_name
    canvas.save(str(file_path))
    
    return f"/static/qrcodes/{file_name}"
