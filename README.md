## Description

This Plugin lets you extend the capability of find command in nvim. With the help of this
Plugin you can find multiple characters rather then one at a time.

By default after pressing `f` in **normal** and **visual** mode now you have to type two characters rather then
One to find it.
You can change the amount of characters you want to find by this specifying the amount in
this key.

### Installation

#### Using Packer
```lua
use {
    opt = true,
    "TheSafdarAwan/find-extender.nvim",
    keys = {
        { "n", "f" },
    },
    config = function()
        require("find-extender").setup()
    end,
}
```

### Configuration
```lua
-- how many characters to find for
find_extender_find_chars_length = 2 -- default value is 2 chars
```

Default is _2_ characters and more then that is not recommended because it will make you slow
and that's not what i intend this plugin to do.

Other feature is that this can go back to the default _1_ character behaviour if you don't
input a character within the timeout you specified in this key.

```lua
-- timeout before the find-extender.nvim goes to the default behavior of f to find 1
-- char timeout in ms
find_extender_find_timeout = false -- false by default
```
