# sysl-lang Homebrew Tap

The Homebrew tap for [sysl](https://github.com/sysl-lang/sysl) — a ref-counted systems language that
compiles through LLVM to a native executable, with no garbage collector and no borrow checker.

## Install

```
brew install sysl-lang/tap/sysl
```

That is a native binary: there is no JVM under it and nothing to start up.

`llvm` comes with it as a **runtime** dependency, which is unusual enough to be worth saying. sysl
emits textual LLVM IR and shells out from there — `clang` assembles and links it, and `llvm-ar` is
what builds a library into a `.syslib`. Apple's command-line tools ship a `clang` but no `llvm-ar`,
so this cannot be left to whatever is already on the machine.

**Apple silicon only for now.** Other platforms build from source, which is a clone and one sbt
invocation — see [sysl.sh/getting-started/installation](https://sysl.sh/getting-started/installation/).

## Moving from the old tap

sysl used to live in `edadma/homebrew-tap`, before the project moved to the `sysl-lang`
organisation. An existing install does not follow a tap move on its own:

```
brew uninstall sysl
brew untap edadma/tap
brew install sysl-lang/tap/sysl
```

The old tap keeps its casks; only the sysl formula moved.

## Documentation

Everything about the language itself is at **[sysl.sh](https://sysl.sh/)** — a tour, a reference, a
standard-library index, and fourteen worked guide programs. Every code block on that site is compiled
and run by the real compiler on every build, so nothing there can quietly rot.
