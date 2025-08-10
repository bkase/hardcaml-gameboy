#!/bin/bash

# Fake gcc wrapper that calls clang instead
# This allows SameBoy to build with clang even when it expects gcc

exec clang "$@"