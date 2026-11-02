# Filter plan

```text
GPU HDMI OUT -> Mimas HDMI IN -> selected filter -> Mimas HDMI OUT -> monitor
```

Start with 640x480 at 60 Hz. One button advances to the next preset and wraps
back to passthrough. Debounce presses, keep S3 for reset, and switch presets
between frames. The output timing stays fixed.

## Presets

These are visual themes; tune them by eye once the input pipeline works.

| Preset | Look |
| --- | --- |
| Passthrough | Original image |
| 1950s | Soft monochrome, grain, rounded corners |
| 1960s | Warm color, soft detail, slight color misalignment |
| 1970s | Rich color, chroma bleed, faint scanlines |
| 1980s | Console/computer feel, scanlines, phosphor mask |
| 1990s | Cleaner CRT image, finer scanlines, less color bleed |
| Grayscale | Neutral monochrome |

Other ideas: Sobel outlines, posterization, dithering, green/amber terminal,
retro handheld palettes, false color.

## Next steps

1. HDMI input and unchanged passthrough, including EDID and HPD.
2. Button cycling with passthrough and grayscale.
3. Scanlines, color adjustments, noise, softness, and color bleed.
4. Curvature, richer glow, persistence, and motion trails as buffering allows.

Keep pixel data, active video, and sync latency aligned across all modes.
