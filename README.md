Scripts to generate/run flake regression tests.

# Prerequisites

Get the regression data:

```shell
# git clone git@github.com:DeterminateSystems/flake-regressions-data.git tests
```

# Running a version of Nix against the regression test suite

Ensure that the desired version of `nix` is in `$PATH`, e.g.

```shell
# nix shell nix/2.18.1
```

Run the test suite:

```shell
# rm tests/*/*/*/done
# ./eval-all.sh
```

# Updating the test suite

Optionally get new public flakes from FlakeHub:

```shell
# ./get-flake-list.sh
```

Then regenerate the test suite:

```shell
# rm tests/*/*/*/done
# REGENERATE=1 ./eval-all.sh
# ./commit-all.sh
# (cd tests && git commit -a && git push)
```
