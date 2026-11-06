# cda

`cda` is a small Bash helper for jumping to named directories.

It is meant to be sourced by your shell so it can run `cd` in the current shell process:

```bash
cda <alias>
```

Aliases are stored in `~/.config/cda/aliases` as a simple tab-separated text file.

## Install

Choose a directory where you keep local tools or project checkouts, for example:

```bash
mkdir -p ~/tools
cd ~/tools
```

Then clone the repo:

```bash
git clone https://github.com/hruskamiro/cda.git
cd cda
```

Run the installer:

```bash
./install.sh
```

Open a new Bash shell, or reload your current one:

```bash
source ~/.bashrc
```

Check the install:

```bash
cda -l
cda <alias>
```

## Doctor

Run the dependency and shell integration check without changing anything:

```bash
./install.sh check
```

`check`, `doctor`, and `--check` are equivalent.

## Usage

```bash
cda recent                  # choose recent directories (default: 20)
cda --recent                # picker even if an alias is named recent
cda <alias>                 # change to a configured directory
cda -a                      # add/update alias named after current directory
cda -a <alias> [directory]  # add/update alias, directory defaults to $PWD
cda -r                      # remove aliases pointing to $PWD
cda -r <alias>              # remove an alias
cda -R                      # remove all aliases after confirmation
cda -l                      # list configured aliases
cda -h                      # show help
```

Examples:

```bash
cda -a work ~/projects/work
cda -a
cda work
cda -r
cda -l
```

## Config

Alias data lives outside the repo:

```text
~/.config/cda/aliases
```

Override the config location with `CDA_ALIASES_FILE`:

```bash
CDA_ALIASES_FILE=/path/to/aliases source ~/tools/cda/cda.sh
```

The file format is one alias per line:

```text
alias<TAB>/absolute/path
```

## Uninstall

Remove the startup entry from `~/.bashrc`:

```bash
cd ~/tools/cda
./install.sh uninstall
```

Then remove the clone if you no longer want the source:

```bash
rm -rf ~/tools/cda
```

## License

MIT. See [LICENSE](LICENSE).

## Recent directories

Interactive Bash shells automatically remember directories at each prompt, only
writing when the directory changes. Run `cda recent`, type a number, and press
Enter to jump there. Enter alone (or EOF) cancels. An existing alias named
`recent` keeps its meaning; `cda --recent` always opens the picker.

By default, the newest 20 locations are shared across terminals and survive closing them.
Missing directories are skipped. Tracking starts after you reload the helper;
commands that visit several directories between prompts record only the final
location. No exit trap is needed, so forced terminal closure does not lose an
already recorded location.

Set `CDA_HISTORY_LIMIT` to change the number saved and shown (1–10000;
no leading zeros). For example, add this before the helper's source line in
`~/.bashrc`:

```bash
CDA_HISTORY_LIMIT=50
source ~/.local/share/cda/cda.sh  # use your actual installation path
```

Open a new terminal or reload the helper after changing startup configuration.
You can also run `CDA_HISTORY_LIMIT=50` in the current shell. Use the same setting
in all terminals: any writer with a smaller limit will trim the shared history
on its next directory change. Increasing the limit cannot restore discarded
entries. Invalid limits produce an error without rewriting history; named
aliases still work. Larger limits increase history IO and picker output linearly.

History is stored separately from aliases, at
`${XDG_STATE_HOME:-$HOME/.local/state}/cda/recent`. Set `CDA_HISTORY_FILE` before
sourcing the helper to override it. The history uses NUL-separated paths and
private file permissions. It contains directory names, so choose a private
location. Tracking requires `flock` (provided by util-linux on Linux); missing
`flock` or write failures produce an error while named aliases remain usable.
Concurrent writers use a lock with a two-second timeout and atomic replacement.
Unchanged prompts perform no file IO or external commands.

Run the regression checks with:

```bash
bash tests/recent.sh
```
