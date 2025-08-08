#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sameboy/gb.h>

static uint32_t pixel_buffer[160 * 144];
static int frame_count = 0;
static int target_frames = 0;

static void vblank_callback(GB_gameboy_t *gb, GB_vblank_type_t type) {
    // Called when vblank occurs
    if (type == GB_VBLANK_TYPE_NORMAL_FRAME) {
        frame_count++;
    }
}

static uint32_t rgb_encode(GB_gameboy_t *gb, uint8_t r, uint8_t g, uint8_t b) {
    // Encode RGB to RGBA format
    return (r << 24) | (g << 16) | (b << 8) | 0xFF;
}

static void save_frame_rgba(const char *output_dir, int frame_num) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/frame_%04d.rgba", output_dir, frame_num);
    
    FILE *f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "Failed to open %s for writing\n", path);
        return;
    }
    
    // Write raw RGBA data
    for (int i = 0; i < 160 * 144; i++) {
        uint32_t pixel = pixel_buffer[i];
        uint8_t rgba[4] = {
            (pixel >> 24) & 0xFF,  // R
            (pixel >> 16) & 0xFF,  // G
            (pixel >> 8) & 0xFF,   // B
            pixel & 0xFF           // A
        };
        fwrite(rgba, 1, 4, f);
    }
    
    fclose(f);
}

static void save_frame_ppm(const char *output_dir, int frame_num) {
    char path[1024];
    snprintf(path, sizeof(path), "%s/frame_%04d.ppm", output_dir, frame_num);
    
    FILE *f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "Failed to open %s for writing\n", path);
        return;
    }
    
    // PPM header
    fprintf(f, "P3\n");
    fprintf(f, "160 144\n");
    fprintf(f, "255\n");
    
    // Write RGB data
    for (int y = 0; y < 144; y++) {
        for (int x = 0; x < 160; x++) {
            uint32_t pixel = pixel_buffer[y * 160 + x];
            uint8_t r = (pixel >> 24) & 0xFF;
            uint8_t g = (pixel >> 16) & 0xFF;
            uint8_t b = (pixel >> 8) & 0xFF;
            fprintf(f, "%d %d %d ", r, g, b);
        }
        fprintf(f, "\n");
    }
    
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <rom_file> <num_frames> <output_dir>\n", argv[0]);
        return 1;
    }
    
    const char *rom_file = argv[1];
    target_frames = atoi(argv[2]);
    const char *output_dir = argv[3];
    
    // Create output directory
    mkdir(output_dir, 0755);
    
    // Initialize GB
    GB_gameboy_t gb;
    GB_init(&gb, GB_MODEL_DMG_B);
    
    // Set callbacks
    GB_set_vblank_callback(&gb, vblank_callback);
    GB_set_rgb_encode_callback(&gb, rgb_encode);
    GB_set_pixels_output(&gb, pixel_buffer);
    
    // Load ROM
    if (GB_load_rom(&gb, rom_file) != 0) {
        fprintf(stderr, "Failed to load ROM: %s\n", rom_file);
        GB_free(&gb);
        return 1;
    }
    
    // Run for specified number of frames
    int saved_frames = 0;
    int cycles = 0;
    const int MAX_CYCLES = 1000000; // Prevent infinite loop
    
    printf("Running emulator for %d frames...\n", target_frames);
    
    while (saved_frames < target_frames && cycles < MAX_CYCLES) {
        // Run the emulator for one frame worth of cycles
        // GB runs at 4194304 Hz, ~70224 cycles per frame
        for (int i = 0; i < 70224; i++) {
            GB_run(&gb);
        }
        
        cycles++;
        saved_frames++;
        printf("Saving frame %d...\n", saved_frames);
        save_frame_rgba(output_dir, saved_frames);
        save_frame_ppm(output_dir, saved_frames);
    }
    
    if (cycles >= MAX_CYCLES) {
        fprintf(stderr, "Warning: Maximum cycles reached\n");
    }
    
    GB_free(&gb);
    printf("Generated %d frames in %s\n", saved_frames, output_dir);
    
    return 0;
}