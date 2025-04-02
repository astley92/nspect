# NSpect

## Why

A few reasons:
- I recently moved from VS Code and wanted to learn how plugins work to make debugging all the things easier
- I run a lot of RSpec tests
- I didn't see other plugins that have this type of functionality (admittedly I didn't look hard)

## Setup

Default values are shown in configuration examples

### Lazy

```lua
return {
    "https://github.com/astley92/nspect",
    opts = {
        run_file_keymap = "<leader>F",
        run_line_keymap = "<leader>H",
        run_previous_keymap = "<leader>G",
        open_prev_keymap = "<leader>O",
        close_windows_keymap = "q",
        run_highlighted_spec_keymap = "r",
        copy_command_keymap or "y",
        run_failed_keymap or "f", "
    }
```

### Packer

TODO

## Configuration

An explanation of each of the options that can be given in the opts hash.

|value|default|function|
|-----|-------|--------|
|run_file_keymap            |`<leader>F`|keymap to run the current spec file in normal mode                                             |
|run_line_keymap            |`<leader>H`|keymap to run the specs associated with the current cursor line file in normal mode            |
|run_previous_keymap        |`<leader>G`|keymap to run the most recent spec run that was run by NSpect in normal mode                   |
|open_prev_keymap           |`<leader>O`|keymap to open the most recent output NSpect run dialog in normal mode                         |
|close_windows_keymap       |`q`        |keymap close the dialog windows when in one of the output windows                              |
|run_highlighted_spec_keymap|`r`        |keymap run the spec underneath the cursor when in the main output window                       |
|copy_command_keymap        |`y`        |keymap to copy the command used to run the current spec run when in one of the output windows  |
|run_failed_keymap          |`f`        |keymap run all failed specs within the current run when in one of the output windows           |
|reload_nspect_keymap       |`<leader>R`|keymap to reload the NSpect plugin (helpful for dev)                                           |

## Development

### How To Release

TODO

### Helpful Sources

- [Structuring plugins](https://zignar.net/2022/11/06/structuring-neovim-lua-plugins/)
- [NeoVim Docs](https://neovim.io/doc/user/index.html)
- [RSpec Custom Formatters](https://rspec.info/features/3-13/rspec-core/formatters/custom-formatter/)
- [RSpec Formatters Source](https://github.com/rspec/rspec/blob/main/rspec-core/lib/rspec/core/formatters.rb)

### Things I Might Add One Day

-   (external) Show backtrace properly on error
-   (external) Don't add reload plugin outside of dev
-   (external) Finish README
-   (external) Highlight multiple specs to rerun
-   (external) View previous spec runs

-   (internal) Split out plugin state so not manually managing all the things
-   (internal) Create window manager abstraction and actually manage windows properly.

-   (both)     Audit output capturing, definitely missing things

