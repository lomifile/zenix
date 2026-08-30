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
itself. It is resolved in this order:

1. `--repo PATH`
2. `$ZENIX_REPO`
3. the first ancestor of the current directory holding `install.sh` and
   `packages/pacman.txt`
4. `~/build/zenix`

## Building

`install.sh` does this for you. By hand:

```sh
python -m build --wheel --no-isolation   # needs python-build, python-setuptools, python-wheel
pipx install --force dist/zenix-*.whl
```
