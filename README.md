# 7th-Heaven-Catalogs

Catalogs for 7th-Heaven - Maintained by the Tsunamods community

## How to submit your mod

1. **Prepare:** fork and clone this repository, then create a branch from `master`.
2. **Add or update your entry:** create `mods/<catalog>/<Your Mod Name>/mod.xml`
   in the appropriate catalog folder, or edit your existing entry.
   Use entries in [mods](mods) as examples and follow the
   [catalog documentation](https://github.com/tsunamods-codes/7th-Heaven/blob/master/docs/CATALOG.md).
3. **Format (optional):** double-click [`format.bat`](./format.bat) in the repository folder.
4. **Validate:** double-click [`validate.bat`](./validate.bat) (requires Git and the .NET SDK).
   Fix errors in your submission, then validate again.
5. **Submit:** review your changes, commit only the intended catalog changes,
   and push your branch. Open a pull request against
   `tsunamods-codes/7th-Heaven-Catalogs`'s `master` branch describing your mod or update.
6. **Follow up:** address automated check failures and maintainer feedback.
   Validate any corrections, then push them to the same branch.
   Wait for maintainer approval and merge.

**Before submitting:** include only one `<Mod>...</Mod>` entry, use your mod
package's ID (not another mod's), and provide a working public download in
`iros://` format. Upload the catalog entry here, **not the mod package**.

## Formatting

Double-click [`format.bat`](./format.bat) to tidy up your catalog files without
changing their content. No extra software is needed.
Generated catalogs are also formatted automatically during validation.

The included [`.editorconfig`](./.editorconfig) helps your editor follow the
project's style as you edit. Use built-in EditorConfig support or install a
plugin; see the official [supported editors](https://editorconfig.org/#pre-installed)
and [plugin setup](https://editorconfig.org/#download) guides.

## `mod.xml` Template

See the [catalog documentation](https://github.com/tsunamods-codes/7th-Heaven/blob/master/docs/CATALOG.md)
and examples in [mods](mods).
