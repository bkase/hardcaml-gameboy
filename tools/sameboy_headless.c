#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sameboy/gb.h>
#include "boot_rom.h"

static uint32_t pixel_buffer[160 * 144];
static int frame_count = 0;
static int target_frames = 0;
static int enable_debug = 0;

static void log_callback(GB_gameboy_t *gb, const char *string, GB_log_attributes attributes) {
    // Only print logs in debug mode
    if (enable_debug) {
        printf("[LOG] %s", string);
    }
}

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
    if (argc < 4 || argc > 5) {
        fprintf(stderr, "Usage: %s <rom_file> <num_frames> <output_dir> [--debug]\n", argv[0]);
        return 1;
    }
    
    const char *rom_file = argv[1];
    target_frames = atoi(argv[2]);
    const char *output_dir = argv[3];
    
    // Check for debug flag
    if (argc == 5 && strcmp(argv[4], "--debug") == 0) {
        enable_debug = 1;
        printf("Debug mode enabled\n");
    }
    
    // Create output directory
    mkdir(output_dir, 0755);
    
    // Initialize GB
    GB_gameboy_t gb;
    GB_init(&gb, GB_MODEL_DMG_B);
    
    // Set callbacks
    GB_set_vblank_callback(&gb, vblank_callback);
    GB_set_rgb_encode_callback(&gb, rgb_encode);
    GB_set_pixels_output(&gb, pixel_buffer);
    GB_set_log_callback(&gb, log_callback);
    
    // Load embedded boot ROM from memory
    GB_load_boot_rom_from_buffer(&gb, dmg_boot_rom, dmg_boot_rom_size);
    if (enable_debug) {
        printf("Loaded embedded boot ROM (%zu bytes)\n", dmg_boot_rom_size);
    }
    
    // Load ROM
    if (GB_load_rom(&gb, rom_file) != 0) {
        fprintf(stderr, "Failed to load ROM: %s\n", rom_file);
        GB_free(&gb);
        return 1;
    }
    
    // Run for specified number of frames
    int saved_frames = 0;
    
    if (enable_debug) {
        printf("Running emulator for %d frames...\n", target_frames);
    }
    
    // Run emulation and save frames
    for (int frame = 0; frame < target_frames; frame++) {
        // Run one complete frame
        GB_run_frame(&gb);
        
        // Debug: Print state info at the end if in debug mode
        if (enable_debug && frame == target_frames - 1) {
            printf("[DEBUG] After frame %d:\n", frame + 1);
            printf("  LCDC (0xFF40): 0x%02X\n", GB_read_memory(&gb, 0xFF40));
            printf("  BGP (0xFF47): 0x%02X\n", GB_read_memory(&gb, 0xFF47));
            printf("  SCY (0xFF42): 0x%02X\n", GB_read_memory(&gb, 0xFF42));
            printf("  SCX (0xFF43): 0x%02X\n", GB_read_memory(&gb, 0xFF43));
            printf("  LY (0xFF44): 0x%02X\n", GB_read_memory(&gb, 0xFF44));
            
            // Check tile data at 0x8000
            printf("  Tile 0 first bytes: 0x%02X 0x%02X\n", 
                   GB_read_memory(&gb, 0x8000), GB_read_memory(&gb, 0x8001));
            printf("  Tile 1 first bytes: 0x%02X 0x%02X\n", 
                   GB_read_memory(&gb, 0x8010), GB_read_memory(&gb, 0x8011));
            printf("  Tilemap[0-7]: %02X %02X %02X %02X %02X %02X %02X %02X\n",
                   GB_read_memory(&gb, 0x9800), GB_read_memory(&gb, 0x9801),
                   GB_read_memory(&gb, 0x9802), GB_read_memory(&gb, 0x9803),
                   GB_read_memory(&gb, 0x9804), GB_read_memory(&gb, 0x9805),
                   GB_read_memory(&gb, 0x9806), GB_read_memory(&gb, 0x9807));
        }
        
        // Save the current frame (only save first/last frames to speed up)
        saved_frames++;
        if (frame >= target_frames - 10 || frame < 2) {
            if (enable_debug) {
                printf("Saving frame %d...\n", saved_frames);
            }
            save_frame_rgba(output_dir, saved_frames);
            save_frame_ppm(output_dir, saved_frames);
        }
    }
    
    GB_free(&gb);
    printf("Generated %d frames in %s\n", saved_frames, output_dir);
    
    return 0;
}