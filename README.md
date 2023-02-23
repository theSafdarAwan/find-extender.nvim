## Description

This Plugin lets you extend the capability of find command in nvim. With the help of this
Plugin you can find multiple characters rather then one at a time.

By default after pressing `f` and `F` or `t` and `T` in **normal** or **visual** mode now
you have to type two characters rather then One to go to you desired position.<BR>
This plugin also changes the `;` and `,` to repeat the last pattern like the find and till
command's do.

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
            -- how many characters to find for
            find_extender_find_chars_length = 2 -- default value is 2 chars
            -- timeout before the find-extender.nvim goes to the default behavior to find 1
            -- char
            -- * timeout in ms
            find_extender_find_timeout = false -- false by default
        })
    end,
}
```

### Configuration

You can change the amount of characters you want to find by specifying the amount in
this key.

```lua
-- how many characters to find for
find_extender_find_chars_length = 2 -- default value is 2 chars
```

Default is _2_ characters and more then that is not recommended because it will slow you down
and that's not what i intend this plugin to do.

You can also alter the behaviour of this plugin to go to default _1_
character behaviour by specifying time in _milli secconds_ in this key.
If you don't input the next character within the time specified in this key then it will go
to default behaviour of _1_ character.<BR>
By default this is set to false:

```lua
-- timeout before the find-extender.nvim goes to the default behavior to find 1
-- char
-- * timeout in ms
find_extender_find_timeout = false -- false by default
```
