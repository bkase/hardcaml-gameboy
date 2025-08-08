#!/bin/bash
# Convert binary file to C header

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_binary> <output_header>"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
VARNAME="dmg_boot_rom"

echo "Converting $INPUT to $OUTPUT..."

cat > "$OUTPUT" << EOF
// Auto-generated from $INPUT
#ifndef BOOT_ROM_H
#define BOOT_ROM_H

#include <stdint.h>
#include <stddef.h>

static const uint8_t ${VARNAME}[] = {
EOF

# Convert binary to hex array
hexdump -v -e '16/1 "0x%02x, " "\n"' "$INPUT" | sed 's/^/    /' | sed '$ s/, *$//' >> "$OUTPUT"

cat >> "$OUTPUT" << EOF
};

static const size_t ${VARNAME}_size = sizeof(${VARNAME});

#endif // BOOT_ROM_H
EOF

echo "Generated $OUTPUT"