## Description

This Plugin lets you extend the capability of find command in nvim. With the help of this
Plugin you can find multiple characters rather then one at a time.

By default after pressing `f` and `F` or `t` and `T` in **normal** or **visual** mode now
you have to type two characters rather then One to go to you desired position.<BR>
This plugin also changes the `;` and `,` to repeat the last pattern like the find and till
command's do.

> NOTE: This plugin is just extending the capability of neovim default find and
> till commands. It doesn't try to imitate the functionality of plugins like
> these [clever-f.vim](https://github.com/rhysd/clever-f.vim), [leap.nvim](https://github.com/ggandor/leap.nvim),
> or [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim) or any plugin like that.
> Its just a personal plugin that i though someone might find useful.

### Installation

#### Using Packer

```lua
use {
    opt = true,
    "TheSafdarAwan/find-extender.nvim",
    -- to lazy load this plugin
    keys = {
        { "n", "f" },
        { "v", "f" },
        { "n", "F" },
        { "v", "F" },
        { "n", "T" },
        { "v", "t" },
        { "n", "t" },
        { "v", "T" },
    },
    config = function()
        require("find-extender").setup({
            -- if you want do disable the plugin the set this to false
            enable = true,
            -- how many characters to find for
            chars_length = 2, -- default value is 2 chars
            -- timeout before the find-extender.nvim goes to the default behavior to find 1
            -- char
            -- * timeout in ms
            timeout = false -- false by default
            -- timeout starting point
            start_timeout_after_chars = 2, -- 2 by default
            -- key maps config
            keymaps = {
                modes = "nv",
                till = { "T", "t" },
                find = { "F", "f" },
            },
        })
    end,
}
```

### Commands

There are three commands available.

- FindExtenderDisable
- FindExtenderEnable
- FindExtenderToggle

### Configuration

You can change the amount of characters you want to find by specifying the amount in
this key.

```lua
-- how many characters to find for
chars_length = 2 -- default value is 2 chars
```

Default is _2_ characters and more then that is not recommended because it will slow you down
and that's not what i intend this plugin to do.

You can also alter the behaviour of this plugin to go to default _1_
character behaviour by specifying time in _milli secconds_ in this key. Also you
can change the _1_ to any other number using the _start_timeout_after_chars_ key.
If you don't input the next character within the time specified in this key then it will go
to default behaviour of _1_ character.<BR>
By default this is set to false:

```lua
-- timeout before the find-extender.nvim goes to the default behavior to find 1
-- char
-- * timeout in ms
timeout = false -- false by default
```

How many characters after which the timeout should be triggered. Important when
we have more set more then _2_ chars lenght in _chars_lenght_.

```lua
start_timeout_after_chars = 1, -- 1 by default
```

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
