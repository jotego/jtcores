# Version History

Version encoding consists of the letter _v_ followed by a three-digit code:

1. Versions that break compatibility with previous versions and will require changes in cores. For instance, adding a new input port to the game module without gating it with a JTFRAME_ macro
2. New functionality that does not break compatibility
3. Patches

New versions are elaborated in a separate branch, typically _wip_, and then merged into the master branch and assign a number and a git tag. When the branch is ready, use `jtmerge` to merge it into master and advance the version number.

Version coding started almost three years after the first JTFRAME commit with version 1.0.0, used in the [JTKARNOV](https://github.com/jotego/jtcop) beta.

For JT cores, the same three digit encoding applies. Breaking compatibility in a core will occur when:

- changing a structural item in the MRA files that prevent the old RBF to work with the new MRA and vice versa
- similar to JSON files
- changing the NVRAM structure
- changing the OSD options in a way that would prevent old status work to be loaded correctly

## Edit Flow

When you have to make edits to jtframe, follow this flow:

```
cd $JTFRAME
jtmerge --edit
# do your edits
git commit -am "my edits"
jtmerge --patch # if the version change is a patch
jtmerge --feature # if it is a feature
jtmerge --major # if it breaks compatibility
```

You can start editing in the _master_ branch and `jtmerge --edit` will stash your changes when creating the _edit_ branch.

You can cancel one edit and go back to _master_ with `jtmerge --abort`. If there are changes done, you will be asked whether to stash them. If you had made commits to the edit branch, the branch will not be deleted automatically.

When the only change in a repository is an update to JTFRAME, use `jtfc` (for JTFRAME Commit) to make the git commit. This will create a commit with the JTFRAME version and its commit description.