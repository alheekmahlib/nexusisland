# Release checklist

This checklist separates local contributor builds from signed maintainer releases. Local builds can stay unsigned or development-signed. Public releases should be Developer ID signed, notarized, stapled, and verified before publishing.

We ship two DMGs per release — one per Mac architecture. The two build paths are kept as separate, self-contained scripts (no shared helpers) so each is easy to debug in isolation.

| Arch     | Local (unsigned)                   | Signed + notarized                          | DMG output                              |
|----------|------------------------------------|---------------------------------------------|-----------------------------------------|
| arm64    | `./scripts/build-dmg.sh`           | `./scripts/build-and-release.sh`            | `build/NexusIsland.dmg`                 |
| x86_64   | `./scripts/build-dmg-intel.sh`     | `./scripts/build-and-release-intel.sh`      | `build-intel/NexusIsland-x86_64.dmg`    |

The two scripts in each row use separate build directories (`build/` and `build-intel/`) so they can be run independently without clobbering each other.

## Local unsigned DMG

```bash
./scripts/build-dmg.sh         # arm64 → build/NexusIsland.dmg
./scripts/build-dmg-intel.sh   # x86_64 → build-intel/NexusIsland-x86_64.dmg
```

Each script builds a single-arch Release app, bundles the matching Node.js runtime, creates the DMG, and signs with a local development certificate when one is available.

## Signed release DMG

Create `.env` from `.env.template` and fill in:

```bash
APPLE_ID=you@example.com
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
TEAM_ID=XXXXXXXXXX
SIGNING_IDENTITY=Developer ID Application: Your Name (TEAMID)
```

Then run both arches:

```bash
./scripts/build-and-release.sh         # arm64
./scripts/build-and-release-intel.sh   # x86_64
```

Each script archives a single-arch Release app, bundles the matching Node.js runtime, signs the app and DMG, submits the DMG for notarization, staples the ticket, and verifies the final DMG.

## Binary verification

Spot-check the produced artifacts:

```bash
lipo -info build/NexusIsland.app/Contents/MacOS/NexusIsland
lipo -info build/NexusIsland.app/Contents/Resources/node
codesign --verify --deep --strict --verbose=2 build/NexusIsland.app
spctl --assess --type execute --verbose build/NexusIsland.app
```

Repeat for `build-intel/NexusIsland.app`. Expected: `lipo -info` reports `arm64` for the arm64 build and `x86_64` for the Intel build, on both the Swift binary and the bundled `node` binary.

## Homebrew Cask update

The cask lives at `homebrew-tap/Casks/nexusisland.rb` and uses `on_arm` / `on_intel` blocks to pick the right DMG per architecture. The `homebrew-tap/` folder mirrors the standalone `shobhit99/homebrew-tap` GitHub repo — see `homebrew-tap/README.md` for the publishing flow.

After uploading both release DMGs:

```bash
shasum -a 256 build/NexusIsland.dmg
shasum -a 256 build-intel/NexusIsland-x86_64.dmg
```

Update:

- `version`
- both `sha256` values (one inside `on_arm`, one inside `on_intel`)
- `url`s, if the release asset paths change

Then test locally with Homebrew:

```bash
brew install --cask --no-quarantine ./homebrew-tap/Casks/nexusisland.rb
brew uninstall --cask nexusisland
```

Once verified, mirror `homebrew-tap/` into the `shobhit99/homebrew-tap` repo and push so `brew install --cask shobhit99/tap/nexusisland` picks up the new version.

## Release checklist

- Run `xcodegen generate`.
- Build and smoke-test the app locally on the host arch.
- Run `./scripts/build-and-release.sh` (arm64).
- Run `./scripts/build-and-release-intel.sh` (x86_64).
- Confirm `lipo -info` reports the expected single arch for each `.app` and bundled `node`.
- Confirm notarization succeeds and the ticket is stapled for both DMGs.
- Confirm `spctl` accepts both DMGs.
- Update the Homebrew Cask version and both SHA256 values.
- Upload both DMGs (`NexusIsland.dmg` + `NexusIsland-x86_64.dmg`) and publish release notes.
