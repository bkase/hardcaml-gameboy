# Makefile for building tools

SAMEBOY_DIR = ../vendor/SameBoy
SAMEBOY_BUILD = $(SAMEBOY_DIR)/build

CC = clang
CFLAGS = -O2 -I$(SAMEBOY_BUILD)/include -Wall
LDFLAGS = -L$(SAMEBOY_BUILD)/lib -lsameboy -lm

.PHONY: all clean

all: sameboy_headless

sameboy_headless: sameboy_headless.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f sameboy_headless