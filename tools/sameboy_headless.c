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

static void output_frame_rgb555_to_stdout(int frame_num) {
    // Output frame header to stderr for debugging, data to stdout
    if (enable_debug) {
        fprintf(stderr, "[FRAME] %d\n", frame_num);
    }
    
    // Write raw RGB555 data to stdout
    for (int i = 0; i < 160 * 144; i++) {
        uint32_t pixel = pixel_buffer[i];
        uint8_t r8 = (pixel >> 24) & 0xFF;  // R
        uint8_t g8 = (pixel >> 16) & 0xFF;  // G
        uint8_t b8 = (pixel >> 8) & 0xFF;   // B
        
        // Convert 8-bit RGB to 5-bit RGB555 format
        uint8_t r5 = (r8 * 31) / 255;
        uint8_t g5 = (g8 * 31) / 255; 
        uint8_t b5 = (b8 * 31) / 255;
        
        // Pack into 16-bit RGB555: RRRRRGGGGGBBBBB
        uint16_t rgb555 = (r5 << 10) | (g5 << 5) | b5;
        
        // Write as little-endian 16-bit value
        uint8_t bytes[2] = {
            rgb555 & 0xFF,         // Low byte
            (rgb555 >> 8) & 0xFF   // High byte
        };
        fwrite(bytes, 1, 2, stdout);
    }
    
    fflush(stdout);
}


int main(int argc, char **argv) {
    if (argc < 3 || argc > 4) {
        fprintf(stderr, "Usage: %s <rom_file> <num_frames> [--debug]\n", argv[0]);
        return 1;
    }
    
    const char *rom_file = argv[1];
    target_frames = atoi(argv[2]);
    
    // Check for debug flag
    if (argc == 4 && strcmp(argv[3], "--debug") == 0) {
        enable_debug = 1;
        fprintf(stderr, "Debug mode enabled\n");
    }
    
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
    
    if (enable_debug) {
        fprintf(stderr, "Running emulator for %d frames...\n", target_frames);
    }
    
    // Run emulation and output final frame
    for (int frame = 0; frame < target_frames; frame++) {
        // Run one complete frame
        GB_run_frame(&gb);
        
        // Debug: Print state info at the end if in debug mode
        if (enable_debug && frame == target_frames - 1) {
            fprintf(stderr, "[DEBUG] After frame %d:\n", frame + 1);
            fprintf(stderr, "  LCDC (0xFF40): 0x%02X\n", GB_read_memory(&gb, 0xFF40));
            fprintf(stderr, "  BGP (0xFF47): 0x%02X\n", GB_read_memory(&gb, 0xFF47));
            fprintf(stderr, "  SCY (0xFF42): 0x%02X\n", GB_read_memory(&gb, 0xFF42));
            fprintf(stderr, "  SCX (0xFF43): 0x%02X\n", GB_read_memory(&gb, 0xFF43));
            fprintf(stderr, "  LY (0xFF44): 0x%02X\n", GB_read_memory(&gb, 0xFF44));
            
            // Check tile data at 0x8000
            fprintf(stderr, "  Tile 0 first bytes: 0x%02X 0x%02X\n", 
                   GB_read_memory(&gb, 0x8000), GB_read_memory(&gb, 0x8001));
            fprintf(stderr, "  Tile 1 first bytes: 0x%02X 0x%02X\n", 
                   GB_read_memory(&gb, 0x8010), GB_read_memory(&gb, 0x8011));
            fprintf(stderr, "  Tilemap[0-7]: %02X %02X %02X %02X %02X %02X %02X %02X\n",
                   GB_read_memory(&gb, 0x9800), GB_read_memory(&gb, 0x9801),
                   GB_read_memory(&gb, 0x9802), GB_read_memory(&gb, 0x9803),
                   GB_read_memory(&gb, 0x9804), GB_read_memory(&gb, 0x9805),
                   GB_read_memory(&gb, 0x9806), GB_read_memory(&gb, 0x9807));
        }
    }
    
    // Output the final frame data to stdout
    output_frame_rgb555_to_stdout(target_frames);
    
    GB_free(&gb);
    
    if (enable_debug) {
        fprintf(stderr, "Completed %d frames\n", target_frames);
    }
    
    return 0;
}