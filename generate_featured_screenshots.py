import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# --- Configuration ---
CANVAS_SIZES = {
    "phone": (1080, 1920),       # Portrait
    "tablet_7": (1200, 1920),    # Portrait
    "tablet_10": (2560, 1600)    # Landscape
}
BG_COLOR = "#515B92"  # Primary theme color
TEXT_COLOR = "#FFFFFF"
SCREENSHOT_SCALE_PORTRAIT = 0.8
SCREENSHOT_SCALE_LANDSCAPE = 0.7
CORNER_RADIUS = 60

# Mapping of raw screenshot filenames to their marketing captions
SCREENS_TEXT = {
    "01_hub_empty.png": "Welcome to Your Hub",
    "02_members_page.png": "Manage Your Community",
    "03_event_creation.png": "Create Custom Events",
    "04_hub_one_event.png": "Track Event Progress",
    "05_hub_multiple_events.png": "Manage All Your Events",
    "06_attendance_taking.png": "Quick & Easy Attendance",
    "07_session_summary.png": "Instant Session Summaries",
    "08_hub_with_stats.png": "Track Participation",
    "09_swipe_members_added.png": "Build Your Member List",
    "10_hub_before_swipe.png": "Ready for Session",
    "11_swipe_start.png": "Swipe to Record",
    "12_swipe_summary.png": "Review Attendance",
    "13_hub_final_swipe.png": "Real-time Statistics",
}

def get_font(size):
    """Attempt to load a high-quality system font."""
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Avenir.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    ]
    for path in font_paths:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def add_corners(im, rad):
    """Add rounded corners to an image."""
    circle = Image.new('L', (rad * 2, rad * 2), 0)
    draw = ImageDraw.Draw(circle)
    draw.ellipse((0, 0, rad * 2 - 1, rad * 2 - 1), fill=255)
    alpha = Image.new('L', im.size, 255)
    w, h = im.size
    alpha.paste(circle.crop((0, 0, rad, rad)), (0, 0))
    alpha.paste(circle.crop((0, rad, rad, rad * 2)), (0, h - rad))
    alpha.paste(circle.crop((rad, 0, rad * 2, rad)), (w - rad, 0))
    alpha.paste(circle.crop((rad, rad, rad * 2, rad * 2)), (w - rad, h - rad))
    im.putalpha(alpha)
    return im

def add_drop_shadow(im, rad, blur=40):
    """Create a soft drop shadow canvas for the screenshot."""
    shadow = Image.new('RGBA', im.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rectangle([0, 0, im.size[0], im.size[1]], fill=(0, 0, 0, 150))
    shadow = add_corners(shadow, rad)
    shadow_canvas = Image.new('RGBA', (im.size[0] + blur * 4, im.size[1] + blur * 4), (0, 0, 0, 0))
    shadow_canvas.paste(shadow, (blur * 2, blur * 2), shadow)
    return shadow_canvas.filter(ImageFilter.GaussianBlur(blur))

def draw_text_with_wrapping(draw, text, font, canvas_width, top_y):
    """Draw text centered with wrapping if it exceeds canvas width."""
    max_width = int(canvas_width * 0.9)
    words = text.split(' ')
    lines = []
    current_line = []

    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = font.getbbox(test_line)
        if (bbox[2] - bbox[0]) <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(' '.join(current_line))
            current_line = [word]
    if current_line:
        lines.append(' '.join(current_line))

    # Draw each line
    y = top_y
    line_spacing = int(font.size * 0.2)
    for line in lines:
        bbox = font.getbbox(line)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        x = (canvas_width - w) // 2
        draw.text((x, y), line, fill=TEXT_COLOR, font=font)
        y += h + line_spacing
    return y

def process_device(device_type):
    """Process all screenshots for a specific device type."""
    input_dir = f"screenshots/{device_type}"
    output_dir = f"screenshots/featured_{device_type}"
    
    if not os.path.exists(input_dir):
        print(f"Directory {input_dir} not found. Run generate_screenshots.sh first.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    canvas_size = CANVAS_SIZES[device_type]
    is_landscape = canvas_size[0] > canvas_size[1]
    
    # Scale typography and effects based on the smaller dimension
    base_dim = canvas_size[1] if is_landscape else canvas_size[0]
    font_size = int(base_dim * 0.08)
    font = get_font(font_size)
    blur = int(base_dim * 0.04)
    
    scale = SCREENSHOT_SCALE_LANDSCAPE if is_landscape else SCREENSHOT_SCALE_PORTRAIT
    
    print(f"\n--- Generating {device_type.replace('_', ' ').title()} Assets ({canvas_size[0]}x{canvas_size[1]}) ---")

    for i in range(1, 14):
        prefix = f"{i:02d}_"
        match = [f for f in SCREENS_TEXT.keys() if f.startswith(prefix)]
        if not match: continue
        
        orig_filename = match[0]
        text = SCREENS_TEXT[orig_filename]
        input_path = os.path.join(input_dir, orig_filename)
        
        if not os.path.exists(input_path):
            print(f"  [!] Skipping {orig_filename}: Raw screenshot not found.")
            continue

        # Create Background
        canvas = Image.new('RGBA', canvas_size, BG_COLOR)
        draw = ImageDraw.Draw(canvas)

        # Add Marketing Text (Centered with Wrapping)
        text_y_start = int(canvas_size[1] * 0.06)
        draw_text_with_wrapping(draw, text, font, canvas_size[0], text_y_start)

        # Process Raw Screenshot
        ss = Image.open(input_path).convert("RGBA")
        
        if is_landscape:
            target_h = int(canvas_size[1] * scale)
            ratio = target_h / ss.height
            target_w = int(ss.width * ratio)
        else:
            target_w = int(canvas_size[0] * scale)
            ratio = target_w / ss.width
            target_h = int(ss.height * ratio)
            
        ss = ss.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        # Rounding and Shadow Effects
        ss_rad = int(CORNER_RADIUS * ratio)
        ss = add_corners(ss, ss_rad)
        shadow = add_drop_shadow(ss, ss_rad, blur=blur)
        
        # Composite
        ss_x = (canvas_size[0] - target_w) // 2
        ss_y = int(canvas_size[1] * 0.2)
        
        shadow_x = ss_x - blur * 2
        shadow_y = ss_y - blur * 2 + int(blur * 0.8) # Slight Y offset for depth
        
        canvas.paste(shadow, (shadow_x, shadow_y), shadow)
        canvas.paste(ss, (ss_x, ss_y), ss)

        # Save Final Asset
        output_path = os.path.join(output_dir, orig_filename.replace('.png', '_featured.png'))
        canvas.convert('RGB').save(output_path, 'PNG', optimize=True)
        print(f"  [+] Generated: {output_path}")

def main():
    print("Attendance Tracker: Generating Marketing Assets...")
    for device in ["phone", "tablet_7", "tablet_10"]:
        process_device(device)
    print("\n✅ All featured graphics generated successfully in 'screenshots/'")

if __name__ == "__main__":
    main()
