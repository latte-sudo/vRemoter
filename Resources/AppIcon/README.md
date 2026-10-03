# Temporary neutral app icon

`placeholder-app-icon.png` is a letter-free geometric remote illustration.
It replaces the inherited app/menu logo while the final product name and icon
remain TODO. It is not a selected final brand, a photo, or a claim of authorship
for the rest of this project.

Generate from the checked-in, standard-library-only Python source:

```sh
python3 Tools/generate-placeholder-icon.py
python3 Tools/generate-placeholder-icon.py --check
```

The generator uses no external image, font, logo or third-party artwork.
Packaging converts this 1024 × 1024 PNG to `AppIcon.icns` with macOS image tools;
the original PNG also supplies native window/menu artwork. A geometric native
fallback is used if the image cannot load. Review actual small-size and
Light/Dark appearance on macOS before release.

The source and original MIT/third-party notices are retained. See the
[identity and asset inventory](../../docs/PROJECT_OWNERSHIP_AND_LICENSES.md).
