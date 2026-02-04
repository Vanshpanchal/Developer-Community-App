# Asset Tree Shaker Report

Generated: 2025-12-30T15:52:47.332937

Project: `F:\GitCrafter\Developer-Community-App\.`

## Summary

| Metric | Count |
|--------|-------|
| Total Assets | 3 |
| Used Assets | 2 |
| **Unused Assets** | **1** |
| Whitelisted | 0 |
| Dynamic Match | 0 |
| Annotated | 0 |
| Missing Files | 0 |
| Files Scanned | 41 |

### Size Analysis

- Total asset size: **290.3 KB**
- Unused asset size: **103.2 KB** (35.6%)

## 🗑️ Unused Assets

The following assets appear to have no references in your code:

| Asset Path | Size |
|------------|------|
| `assets/images/background_pattern.jpg` | 103.2 KB |

## Recommendations

1. Review the unused assets list above
2. Verify they are truly unused (check for dynamic references)
3. Run `dart run asset_tree_shaker clean` to remove them
4. Add false positives to `exclude_patterns` in your config
