# Fork Changes Documentation

This document tracks all custom modifications, patches, and deviations from the upstream `cmdrootaccess/another-flushbar` repository.

## Fork Information

- **Fork Repository**: `https://github.com/pieces-app/another-flushbar`
- **Upstream Repository**: `https://github.com/cmdrootaccess/another-flushbar`
- **Current Branch**: `main`
- **Fork Version**: `1.12.30`
- **Commits Ahead**: 7
- **Commits Behind**: 0
- **Last Upstream Merge**: Fork is fully caught up with upstream

## Custom Modifications

### 1. Position Support: TOP_RIGHT and BOTTOM_RIGHT
- **Commits**: `c33356d` (TOP_RIGHT), `585b757` (BOTTOM_RIGHT)
- **Changes**:
  - Added `FlushbarPosition.TOP_RIGHT` position option
  - Added `FlushbarPosition.BOTTOM_RIGHT` position option
  - Updated positioning logic in `flushbar_route.dart`
- **Files Modified**:
  - `lib/flushbar.dart` (56 lines changed)
  - `lib/flushbar_route.dart` (89 lines changed)
- **Reason**: Pieces notification system requires right-aligned flushbar positions for desktop UX

### 2. Pubspec and Dependency Updates
- **Commits**: `fa6dd00`, `ea3c798`, `9322fb8`
- **Changes**: Updated pubspec.yaml for SDK compatibility

### 3. IDE Configuration
- **Commits**: `68d7024`, `034e472`
- **Changes**: Added/updated `.iml` IDE project file

## Upstream Sync Status

- **Current Gap**: 0 commits behind (fully synced)
- **Status**: Only our custom position additions diverge from upstream

## Why This Fork Exists

1. **RIGHT-aligned Positions**: Upstream only supports TOP and BOTTOM positions; Pieces desktop apps need TOP_RIGHT and BOTTOM_RIGHT for notification placement

## Future Considerations

1. **Upstream Contribution**: Consider contributing TOP_RIGHT/BOTTOM_RIGHT positions back to upstream
2. **Alternative Package**: Evaluate if a different notification package supports these positions natively

## Contact

For questions about this fork or to request changes, contact the Pieces development team.
