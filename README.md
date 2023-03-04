## Description

This Plugin extend's the capability of find, till and text manipulation(yank/delete/change)
command's in nvim. With the help of this Plugin you can find multiple characters rather than
one at a time.

🔥 This Plugins Effects the following commands:

    f|F (find commands)
    t|T (till commands)
    ;|, (last pattern commands)
    c{t|T|f|f} (change command)
    d{t|T|f|f} (delete command)
    y{t|T|f|f} (yank command)

By default after pressing any of these commands now you have to type two
characters(or more you can specify characters length) rather than One to
go to next position.

## ✨ Features

- adds capability to add more characters to finding command's.
- yank/delete/change(y/d/c) text same as finding.
- added Highlight the yanked area with color using neovim predefined
  `require("vim.highlight").range()`.
- timeout to find before the `chars_length` variable lenght has completed.
- provide number like `2` before key to go to second position for the pattern.
  This is universal for y/d/c or t/T/f/F commands.

## 🚀 Usage

#### find forward

<details>
    <summary>Click to Expand</summary>
    <img alt="f command" src="https://bit.ly/3mmsCaC">
    <img alt="f command" src="https://github.com/TheSafdarAwan/assets/blob/main/find-extender.nvim/Fir.gif">
</details>

#### find backwards

<details>
    <summary>Click to Expand</summary>
    <img alt="F command" src="https://bit.ly/3KW3i5F">
</details>

#### delete

<details>
    <summary>Click to Expand</summary>
    <img alt="f command" src="https://bit.ly/3SLteTj" style="object-fit: cover;">
</details>

## 📦 Installation

Install the theme with your preferred package manager:

[vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'TheSafdarAwan/find-extender.nvim'
```

[packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    opt = true,
    "TheSafdarAwan/find-extender.nvim",
    -- to lazy load this plugin
    keys = {
        { "v", "f" },
        { "v", "F" },
        { "n", "f" },
        { "n", "F" },
        { "n", "T" },
        { "n", "t" },
        { "v", "T" },
        { "v", "t" },
        { "n", "c" },
        { "n", "d" },
        { "n", "y" },
    },
    config = function()
        -- configuration here
    end,
}
```

## Setup

```lua
require("find-extender").setup({
    -- if you want do disable the plugin the set this to false
    enable = true,
    -- how many characters to find for
    chars_length = 2, -- default value is 2 chars
    -- timeout before the find-extender.nvim goes to find the available
    -- characters on timeout after the limit of start_timeout_after_chars
    -- has been reached
    -- timeout in ms
    timeout = false, -- false by default
    -- timeout starting point
    start_timeout_after_chars = 2, -- 2 by default
    -- key maps config
    keymaps = {
        modes = "nv",
        till = { "T", "t" },
        find = { "F", "f" },
        -- to delete, copy or change using t,f or T,F commands
        text_manipulation = { yank = true, delete = true, change = true },
    },
    highlight_on_yank = {
        -- whether to highlight the yanked are or not
        enable = true,
        -- time for which the area will be highlighted
        timeout = 40,
        -- highlight group for the yanked are color
        hl_group = "IncSearch",
    }
})
```

## Commands

There are three commands available.

- FindExtenderDisable
- FindExtenderEnable
- FindExtenderToggle

## ⚙️ Configuration

### chars_length

You can change the amount of characters you want to find by specifying the amount in
this key.

```lua
-- how many characters to find for
chars_length = 2 -- default value is 2 chars
```

Default is _2_ characters and more than that is not recommended because it will slow you down
and that's not what i intend this plugin to do.

### timeout

Timeout before the find-extender.nvim goes to find the characters that you have entered.
before you complete the chars_length character's limit.

```lua
-- timeout in ms
timeout = false -- false by default
```

### start_timeout_after_chars

How many characters after which the timeout should be triggered.

```lua
start_timeout_after_chars = 1, -- 1 by default
```

### ⌨ keymaps

Keymaps are exposed to user if any key you want to remove just remove it from the
tbl

```lua
keymaps = {
    modes = "nv",
    till = { "T", "t" },
    find = { "F", "f" },
},
```

Modes is a string with the modes name initials.

### text_manipulation

Mappings related to the text manipulation like change, delete and yank(copy).
If you want to disable any of the macro then set it to false.

```lua
keymaps = {
    ...,
    -- to delete, copy or change using t,f or T,F commands
    text_manipulation = { yank = true, delete = true, change = true },
}
```

### highlight on yank

These options control the highlight when yanking text.

```lua
highlight_on_yank = {
    -- whether to highlight the yanked are or not
    enable = true,
    -- time for which the area will be highlighted
    timeout = 40,
    -- highlight group for the yanked are color
    hl_group = "IncSearch",
}
```

### Related Plugins

👉 Written in vimscript

- [vim-easymotion](https://github.com/easymotion/vim-easymotion)
- [vim-sneak](https://github.com/justinmk/vim-sneak)
- [clever-f.vim](https://github.com/rhysd/clever-f.vim)

👉 Written in lua

- [leap.nvim](https://github.com/ggandor/leap.nvim),
- [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim)
- [flit.nvim](https://github.com/ggandor/flit.nvim/)
