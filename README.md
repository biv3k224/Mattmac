# mattmac

A small macOS app that overlays a paper-like matte texture across connected displays. It is a standalone implementation with original procedural textures.

## Features

- Nine monochrome texture styles
- Adjustable texture intensity
- Click-through display overlay
- Menu-bar toggle
- Settings remembered between launches
- Local rendering; no screen-recording permission requested

## Requirements

- macOS 13 or later
- Xcode Command Line Tools with the Swift compiler

## Build the app

```sh
make app
open build/mattmac.app
```

The build script creates and ad-hoc signs `build/mattmac.app`. For a downloadable archive, zip that app bundle after building. macOS may ask you to confirm opening an ad-hoc signed app.

You can also compile the executable with Swift Package Manager:

```sh
swift build
```

## License

No license file is included. The repository is public, but no reuse or redistribution license is granted.
