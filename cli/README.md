# zenix

CLI for the parts of the [zenix](..) setup that change often: wallpapers, the
keyboard layout, the SDDM background and the timezone.

Every command writes the **repo** first and only then touches the running
system. The repo is what `install.sh` rebuilds a machine from, so a change
applied live but not written back would be lost on the next rebuild.

```
zenix status                          # what is configured where, repo vs live
zenix wallpaper list
zenix wallpaper set NAME [--greeter]  # a name in assets/wallpaper/, or a path
zenix keyboard list [FILTER]
zenix keyboard set LAYOUT [--variant V]
zenix timezone list [FILTER]
zenix timezone set ZONE
```

`-n/--dry-run` changes nothing; `--no-apply` writes the repo but leaves the
running system alone.

## Finding the repo

Installed into a venv, the code can no longer locate the repo relative to
itself, so it has to be discovered.

`--repo PATH` settles it on its own: the path is checked for `install.sh` and
`packages/pacman.txt` and the command fails if it has neither, rather than
quietly editing some other checkout. Without it, the search runs in order:

1. `$ZENIX_REPO`
2. the first ancestor of the current directory holding `install.sh` and
   `packages/pacman.txt`
3. `~/build/zenix`

## Building

`install.sh` does this for you. By hand:

```sh
python -m build --wheel --no-isolation   # needs python-build, python-setuptools, python-wheel
pipx install --force dist/zenix-*.whl
```

## Tests

Stdlib `unittest`, no dependencies to install:

```sh
cd cli
python -m unittest discover -s tests -t .        # the lot
python -m unittest discover -s tests -t . -v     # naming each test
python -m unittest tests.test_wallpaper          # one module
python -m unittest tests.test_repo.FindRepo      # one class, or .one_test
```

`-t .` is what lets the test modules import `tests.support`, so run them from
`cli/` rather than from inside `tests/`.

Nothing shells out to `sudo`, `hyprctl` or `gcalcli`, and `$HOME`, `Path.home`
and `Path.cwd` are redirected at every entry point: the suite works on a
fixture checkout in a temp dir and cannot reach the live config.
