from PIL import Image, ImageDraw
import os

# Create 1024x1024 image with solid background
size = 1024

# Start with solid blue background (no alpha)
img = Image.new('RGB', (size, size), '#2563eb')
draw = ImageDraw.Draw(img)

# Draw gradient effect FIRST
print("Drawing gradient...")
for y in range(size):
    for x in range(size):
        # Diagonal gradient
        progress = (x + y) / (2 * size)
        
        # Start color: #2563eb
        r1, g1, b1 = 0x25, 0x63, 0xeb
        # End color: #1e40af  
        r2, g2, b2 = 0x1e, 0x40, 0xaf
        
        r = int(r1 + (r2 - r1) * progress)
        g = int(g1 + (g2 - g1) * progress)
        b = int(b1 + (b2 - b1) * progress)
        
        img.putpixel((x, y), (r, g, b))

# NOW draw the warehouse boxes ON TOP of the gradient
print("Drawing boxes...")
draw = ImageDraw.Draw(img)  # Recreate draw object after gradient

# Bottom box (largest)
draw.rectangle([(312, 600), (712, 880)], fill='#60a5fa', outline='#1e40af', width=4)
draw.line([(512, 600), (512, 880)], fill='#1e40af', width=4)
draw.line([(312, 740), (712, 740)], fill='#1e40af', width=3)

# Middle box
draw.rectangle([(362, 380), (662, 620)], fill='#60a5fa', outline='#1e40af', width=3)
draw.line([(512, 380), (512, 620)], fill='#1e40af', width=3)
draw.line([(362, 500), (662, 500)], fill='#1e40af', width=3)

# Top box
draw.rectangle([(412, 200), (612, 400)], fill='#60a5fa', outline='#1e40af', width=2)
draw.line([(512, 200), (512, 400)], fill='#1e40af', width=2)
draw.line([(412, 300), (612, 300)], fill='#1e40af', width=2)

# Add barcode lines on top box
print("Drawing barcode...")
barcode_y = 260
barcode_height = 80
barcode_specs = [
    (442, 8), (458, 12), (478, 6), (492, 14),
    (514, 10), (532, 8), (548, 12), (568, 14)
]

for x, width in barcode_specs:
    draw.rectangle([(x, barcode_y), (x + width, barcode_y + barcode_height)], fill='white')

# Add checkmark circle
print("Drawing checkmark...")
draw.ellipse([(680, 180), (880, 380)], fill='#10b981')

# Checkmark path (simplified)
draw.line([(730, 280), (760, 310)], fill='white', width=20)
draw.line([(760, 310), (830, 240)], fill='white', width=20)

# Save to Desktop
desktop_path = os.path.expanduser('~/Desktop/AppIcon_Fixed.png')
img.save(desktop_path, 'PNG')

print(f"✅ Created: {desktop_path}")
print("📁 Check your Desktop for AppIcon_Fixed.png")
print("🎨 This version has the warehouse boxes, barcode, and checkmark!")