## Artem's CV

### Requirements

* Haskell toolchain (cabal, ghc)
* LaTeX toolchain (latexmk to use the Makefile)


### Build

The main way to build this CV is via Nix: call `nix-build` to get `restult/cv.pdf`.
For convenience, `make` (and `make all`) does that plus it copies the result in CWD.

The nix-less way of building the CV is `make pdf`.
It assumes GHC has the necessary packages in its package database (the packages are listed in `default.nix`).
The easiest way to set this up is probably by doing `cabal install --lib package1 package2... --package-env .` manually.


### Architecture

I've been keeping this CV for many years as just a Latex file.
But then I got tired of navigating tons of Latex code to make simple updates.
I bit the bullet and harnessed a [template engine][wikipedia:template].
As a Haskell fan, naturally, I implemented a Haskell script ([`cv.hs`](./cv.hs)) that uses [Ginger][hackage:ginger] (a Haskell re-implementation of Python's Jinja) for templating (the template is [`cv.tex.ginger`](./cv.tex.ginger)).

[wikipedia:template]: https://en.wikipedia.org/wiki/Template_processor
[hackage:ginger]: https://hackage.haskell.org/package/ginger

The data, for now, is stored in the Haskell script itself, and it's only the basic info about me and the list of publications with DOI's (things that get updated most of all these days).

I owe Ming-Ho Yee the [idea of radically separating data and representation][mingho:resume].
Though, the technical details are different: he uses Ruby and its ERB system for templating and YAML to store the data.
Ming-Ho also generates his homepage from the same source.
One day I'll get there…

[mingho:resume]: https://github.com/mhyee/resume
