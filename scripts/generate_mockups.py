import os
import sys
from PIL import Image, ImageDraw, ImageFilter

def create_phone_mockup(input_path, output_path, crop_top=48, crop_bottom=28):
    """
    Renders an app screenshot inside a sleek dark titanium phone mockup:
    - Strips off the system status bar (time, Wi-Fi, cellular signal, battery icons)
    - Strips off the bottom gesture navigation pill
    - Applies rounded corner masking matching modern mobile display curves
    - Adds an outer bezel with speaker grill and camera punch-hole
    - Adds elevation drop shadow for presentation on GitHub README
    """
    if not os.path.exists(input_path):
        print(f"Error: File not found: {input_path}")
        return False

    im = Image.open(input_path).convert('RGBA')
    w, h = im.size
    
    # Crop status bar and bottom gesture bar
    cropped = im.crop((0, crop_top, w, h - crop_bottom))
    cw, ch = cropped.size
    
    # Phone frame styling
    bezel = 16
    chin = 20
    radius = 36
    inner_radius = 24
    
    fw = cw + bezel * 2
    fh = ch + bezel + chin
    
    # Canvas with padding for shadow
    pad = 30
    canvas_w = fw + pad * 2
    canvas_h = fh + pad * 2
    
    canvas = Image.new('RGBA', (canvas_w, canvas_h), (0, 0, 0, 0))
    
    # Drop shadow
    shadow = Image.new('RGBA', (canvas_w, canvas_h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle(
        [pad + 4, pad + 8, pad + fw - 4, pad + fh + 8],
        radius=radius,
        fill=(0, 0, 0, 95)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas.paste(shadow, (0, 0), shadow)
    
    # Phone chassis
    phone_layer = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(phone_layer)
    
    # Outer dark chassis (titanium finish)
    p_draw.rounded_rectangle(
        [0, 0, fw - 1, fh - 1],
        radius=radius,
        fill=(24, 28, 36, 255),
        outline=(55, 65, 81, 255),
        width=2
    )
    
    # Screen mask with rounded corners
    screen_mask = Image.new('L', (cw, ch), 0)
    m_draw = ImageDraw.Draw(screen_mask)
    m_draw.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=inner_radius, fill=255)
    
    # Paste screen onto chassis
    phone_layer.paste(cropped, (bezel, bezel), screen_mask)
    
    # Subtle inner screen border
    p_draw.rounded_rectangle(
        [bezel, bezel, bezel + cw - 1, bezel + ch - 1],
        radius=inner_radius,
        outline=(15, 23, 42, 120),
        width=1
    )
    
    # Punch hole camera at top center
    cam_x = fw // 2
    cam_y = bezel // 2 + 3
    cam_r = 5
    p_draw.ellipse([cam_x - cam_r, cam_y - cam_r, cam_x + cam_r, cam_y + cam_r], fill=(10, 15, 20, 255), outline=(30, 41, 59, 255))
    p_draw.ellipse([cam_x - 1, cam_y - 2, cam_x + 1, cam_y], fill=(70, 90, 120, 180))
    
    # Top speaker grill
    p_draw.rounded_rectangle([cam_x - 22, 5, cam_x + 22, 8], radius=2, fill=(40, 48, 60, 255))
    
    canvas.paste(phone_layer, (pad, pad), phone_layer)
    
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    canvas.save(output_path, 'PNG', optimize=True)
    print(f"[OK] Generated Phone Mockup: {output_path} ({canvas_w}x{canvas_h})")
    return True

if __name__ == '__main__':
    if len(sys.argv) >= 3:
        create_phone_mockup(sys.argv[1], sys.argv[2])
    else:
        print("Usage: python scripts/generate_mockups.py <input_img> <output_img>")
