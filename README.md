MacVimFramework
===============

This is a fork of <https://github.com/b4winckler/macvim>. I made some modifications such that you can compile a Framework with which you can use MacVim-view in your own Apps. It does not have a well-thought-out Framework design due to the fact that I wanted to make the absolute minimal amount of modifications to the original code base. However, there is room for improvements and I'll add them gradually.

An (absolute minimal) example project will follow soon.

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

* Link your target with `PSMTabBarControl.framework` which is included with the project.
* Link your target with `MacVimFramework.framework`
* Examine the code of the example which will soon follow.
