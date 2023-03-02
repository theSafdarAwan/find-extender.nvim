## Description

This Plugin lets you extend the capability of find and till command's in nvim. With the help
of this Plugin you can find multiple characters rather than one at a time.

By default after pressing `f` and `F` or `t` and `T` in **normal** or **visual** mode now
you have to type two characters(or more you can specify characters lenght) rather than One
to go to next Characters position.

This plugin also changes the `;` and `,` to repeat the last pattern like the find and till command's do.

> NOTE: This plugin is just extending the capability of neovim default find and
> till commands. It doesn't try to imitate the functionality of plugins like
> [clever-f.vim](https://github.com/rhysd/clever-f.vim), [leap.nvim](https://github.com/ggandor/leap.nvim),
> [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim), [flit.nvim](https://github.com/ggandor/flit.nvim/)
> or any plugin like that. Its just a personal plugin that i though someone might find useful.

The main Reason why i don't use these mentioned Plugins.

> Reason why i don't use the mentioned plugins is because rather than extending
> the vim(nvim)'s default find command these plugins try to do something
> completely different. Also these plugin change the colors which i don't like at
> all i just wanted a simple plugin that i could use to navigate more efficiently.
> These plugins are great but these are not for the people like me.

### Installation

#### Using Packer

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
        require("find-extender").setup({
            -- if you want do disable the plugin the set this to false
            enable = true,
            -- how many characters to find for
            chars_length = 2, -- default value is 2 chars
            -- timeout before the find-extender.nvim goes to the default behavior to find 1
            -- char
            -- * timeout in ms
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
            -- whether to highlight the yanked are or not
            highlight_on_yank_enabled = true,
            -- time for which the area will be highlighted
            highlight_on_yank_timeout = 40,
            -- highlight group for the yanked are color
            highlight_on_yank_hl_group = "IncSearch",
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

##### chars_length

```lua
-- how many characters to find for
chars_length = 2 -- default value is 2 chars
```

Default is _2_ characters and more than that is not recommended because it will slow you down
and that's not what i intend this plugin to do.

##### timeout

Timeout before the find-extender.nvim goes to find the characters that you have entered.
before you complete the chars_length character's limit.

```lua
-- timeout in ms
timeout = false -- false by default
```

##### start_timeout_after_chars

How many characters after which the timeout should be triggered.

```lua
start_timeout_after_chars = 1, -- 1 by default
```

##### keymaps

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

##### text_manipulation

Mappings related to the text manipulation like change, delete and yank(copy).
If you want to disable any of the macro then set it to false.

```lua
-- to delete, copy or change using t,f or T,F commands
keymaps.text_manipulation = { yank = true, delete = true, change = true },
```

##### highlight on yank options

These options control the highlight when yanking text.

```lua
-- whether to highlight the yanked are or not
highlight_on_yank_enabled = true,
-- time for which the area will be highlighted
highlight_on_yank_timeout = 40,
-- highlight group for the yanked are color
highlight_on_yank_hl_group = "IncSearch",
```

### Is this Plugin really useful?

Well some people asked me how this plugin is useful think of why we need find
command in vim anyway we can just use _l_ or _h_ but that won't be very useful.
It will take a lot of time and we would get frustrated. Now lets now add the find
command back in vim and now it makes our life much easier but when it comes to
find command. It lacks one thing that is to search more characters rather than one.
Which is a bummer considering why we started to use vim in the first place to
edit and navigate code more efficiently.

This plugin might not satisfy you in just one line of code search but after you
use it for an hour when writing code and navigating than only you can notice its
capability and what it gives you as user.

Now some people might disagree with this plugin functionality because they might
think it make navigation more complex i thought the same thing but after i used
this plugin i came to realization that i was missing many things. Now i can go on
and on about this but the only thing i can say try this plugin and than disable
it than you will come to a realization why this plugin is amazing. I have addded
commands that lets you enable and disable this plugin. You can use that to see
the difference.

I would say use this plugin its free you won't loose any money anyway. If you
don't like it than just remove it 👍.
