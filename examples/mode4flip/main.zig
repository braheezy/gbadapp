const gba = @import("gba");
const input = gba.input;
const display = gba.display;

export var header linksection(".gbaheader") = gba.Header.init("MODE4FLIP", "AMFE", "00", 0);

const front_image_data = @embedFile("front.agi");
const back_image_data = @embedFile("back.agi");
const palette_data = @embedFile("mode4flip.agp");

fn loadImageData() void {
    // Create a more colorful palette that might better represent the original images
    const palette_mem = @as([*]align(4) volatile u16, @ptrFromInt(0x05000000));

    // Create a diverse color palette with many vibrant colors
    // This should better represent the original bitmap images

    // Basic colors (0-15)
    palette_mem[0] = 0x0000; // Black
    palette_mem[1] = 0x7FFF; // White
    palette_mem[2] = 0x001F; // Red
    palette_mem[3] = 0x7C00; // Blue
    palette_mem[4] = 0x07E0; // Green
    palette_mem[5] = 0xF81F; // Magenta
    palette_mem[6] = 0xFFE0; // Yellow
    palette_mem[7] = 0x07FF; // Cyan
    palette_mem[8] = 0x7C1F; // Purple
    palette_mem[9] = 0x03FF; // Light Blue
    palette_mem[10] = 0x7FE0; // Light Green
    palette_mem[11] = 0xFC1F; // Light Red
    palette_mem[12] = 0x7BEF; // Gray
    palette_mem[13] = 0x3DEF; // Dark Gray
    palette_mem[14] = 0x5AD6; // Medium Gray
    palette_mem[15] = 0x9CE7; // Light Gray

    // Fill the rest with a variety of colors
    for (16..256) |i| {
        const hue = @as(u8, @intCast(i - 16));

        // Create colors based on hue - simpler approach to avoid comptime issues
        const h = hue % 6;
        const intensity = @as(u16, @intCast((hue * 31) / 240));

        var r: u16 = 0;
        var g: u16 = 0;
        var b: u16 = 0;

        // Simple color wheel generation
        switch (h) {
            0 => {
                r = 31;
                g = intensity;
                b = 0;
            }, // Red to Yellow
            1 => {
                r = intensity;
                g = 31;
                b = 0;
            }, // Yellow to Green
            2 => {
                r = 0;
                g = 31;
                b = intensity;
            }, // Green to Cyan
            3 => {
                r = 0;
                g = intensity;
                b = 31;
            }, // Cyan to Blue
            4 => {
                r = intensity;
                g = 0;
                b = 31;
            }, // Blue to Magenta
            5 => {
                r = 31;
                g = 0;
                b = intensity;
            }, // Magenta to Red
            else => {
                r = intensity;
                g = intensity;
                b = intensity;
            }, // Fallback to grayscale
        }

        const color = r | (g << 5) | (b << 10);
        palette_mem[i] = color;
    }

    // Now load the actual bitmap images
    const vram_ptr = @as([*]align(4) volatile u8, @ptrFromInt(0x06000000));
    const back_page_ptr = @as([*]align(4) volatile u8, @ptrFromInt(0x0600A000));

    // Load front image data
    for (0..front_image_data.len) |i| {
        vram_ptr[i] = front_image_data[i];
    }

    // Load back image data
    for (0..back_image_data.len) |i| {
        back_page_ptr[i] = back_image_data[i];
    }
}

export fn main() void {
    display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    loadImageData();

    var i: u32 = 0;
    while (true) : (i += 1) {
        display.naiveVSync();

        if (i == 60 * 2) {
            i = 0;
            display.pageFlip();
        }
    }
}
