## Description

This Plugin lets you extend the capability of find command in nvim. With the help of this
Plugin you can find multiple characters rather then one at a time.

By default after pressing `f` in normal mode now you have to type two characters rather then
One to find it.
You can change the amount of characters you want to find by this specifying the amount in
this variable.

```lua
-- how many characters to find for
vim.find_extender_find_chars_length = 2
```
Default is _2_ characters and more then that is not recommended because it will make you slow
and that's not what i intend this plugin to do.

Other feature is that this can go back to the default _1_ character behaviour if you don't
input a character with the timeout you specified in this variable.
```lua
-- timeout before the find-extender.nvim movement goes to the default behavior of f to find 1
-- char false or timeout in ms
vim.find_extender_find_timeout = nil -- nil by default
```
