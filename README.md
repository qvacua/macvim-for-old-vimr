MacVimFramework
===============

This is a fork of <https://github.com/b4winckler/macvim>. I made some modifications such that you can compile a Framework with which you can use MacVim-view in your own Apps. It does not have a well-thought-out Framework design due to the fact that I wanted to make the absolute minimal amount of modifications to the original code base. However, there is room for improvements and I'll add them gradually.

An (absolute minimal) example App (`MinimalMacVim`) is included. You can also have a look at [Project VimR](https://github.com/qvacua/vimr).

How to Build
------------

Go to project root and do the following:

```
cd src
./configure
make
```

Open the Xcode project `MacVim.xcodeproject` in `src/MacVim` and build the `MacVimFramework` target.

How to Use
----------

### Build Settings
* Add `@loader_path/../Frameworks` to `Runtime Search Paths`

### Build Phases
* Link and copy `PSMTabBarControl.framework` which is included with the project.
* Link and copy `MacVimFramework.framework`

### Example Code
Examine the target `MinimalMacVim`. It essentially has only one class—`MMAppDelegate`—that handles everything.
