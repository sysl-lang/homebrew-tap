class Sysl < Formula
  desc "Ref-counted systems language that compiles through LLVM"
  homepage "https://sysl.sh/"
  version "0.0.79"
  license "ISC"

  # Three tarballs, and each is built where it runs: Scala Native does not
  # cross-compile, so the macOS binary comes off the author's machine and the two
  # Linux ones off CI. Every other platform builds from source, which is a clone
  # and one sbt invocation.
  #
  # The Linux binaries are built on the 22.04 images so the glibc floor stays low
  # enough to cover Debian 12 and RHEL 9. That floor is measured from the binary
  # at each release rather than assumed from the image -- 2.34 for this one.
  on_macos do
    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-darwin-arm64.tar.gz"
      sha256 "c9309250db3f02d650d65fe6a8f8ff389e76b46f8941208983f7c9ab93b449b1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-x86_64.tar.gz"
      sha256 "ab984c5d86fbc40fd7efacf81b5c4b5c8b382f8190bea236d9d57b6e3ca376b1"
    end

    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-arm64.tar.gz"
      sha256 "859dab3edc8cf507330b25cea534bc1b8cfcedf885593d062ca56d0f42a47c93"
    end
  end

  # A *runtime* dependency rather than a build one. sysl emits textual LLVM IR and
  # shells out from there: clang assembles and links it, and llvm-ar is what builds
  # a library into a .syslib. Apple's command-line tools ship a clang but no
  # llvm-ar, which is why this cannot be left to whatever is already on the machine
  # -- and why Toolchain.arCandidates already looks in /opt/homebrew/opt/llvm/bin.
  depends_on "llvm"

  # Also a runtime dependency, and for the same reason: sysl shells out to it.
  # A package that binds an installed C library can declare it -- requires {
  # pkg_config { sdl3 = "..." } } -- and the compiler asks pkg-config where
  # that library's headers and link line are, so a consumer needs no flags.
  #
  # macOS ships no pkg-config and the libraries do not bring one: brew deps
  # cairo lists fifteen packages and pkgconf is not among them. Unlike llvm
  # this keg is not keg-only, so pkg-config lands on the PATH and the compiler
  # finds it by bare name.
  depends_on "pkgconf"

  # `sysl-doc`'s, not the compiler's. The doc tool links juicer-core -- the site
  # generator without its command line -- whose server is built on microserve, and
  # Scala Native puts `-luv` on its link line for that. `otool -L` on the shipped
  # binary names /opt/homebrew/opt/libuv/lib/libuv.1.dylib, so this is a runtime
  # dependency of the tarball as a whole even though `bin/sysl` itself has no use
  # for it. juicer's own formula depends on it for the same reason.
  depends_on "libuv"

  def install
    # The tarball is already a prefix -- bin/sysl and share/sysl/library -- so the
    # whole tree moves into the keg and brew links bin/sysl itself.
    #
    # The standard library ships as source rather than being generated into the
    # binary, and the compiler finds it by resolving its own path and looking for
    # <prefix>/share/sysl/library. That is exactly pkgshare, which is why installing
    # the tree as it stands is the whole of it: no wrapper script, no environment
    # variable, and an old keg left behind keeps using the library it shipped with.
    prefix.install Dir["*"]
  end

  test do
    assert_match "sysl #{version}", shell_output("#{bin}/sysl --version")

    # The one way this formula can be wrong and still install. The library lives
    # beside the executable rather than inside it, so a tarball built without it,
    # or an install step that dropped it, produces a compiler that starts, answers
    # --version, and cannot compile anything.
    assert_predicate pkgshare/"library/sysl", :directory?

    # The second binary, and the second way this formula can be wrong and still
    # install. `sysl doc` execs `sysl-doc` off the PATH -- git-style dispatch --
    # so a tarball staged with only the compiler in it produces an install where
    # `sysl doc` reports there is no sysl-doc on your PATH, on the machine where
    # somebody has just installed one.
    #
    # Running it over the library that shipped in the same tarball reaches three
    # things at once: the binary links (which is what the libuv dependency above
    # is for), the library is where the compiler will look for it, and the two
    # came from one tree.
    assert_predicate bin/"sysl-doc", :executable?

    system bin/"sysl-doc", pkgshare/"library", "--out", testpath/"api"
    assert_predicate testpath/"api/sysl-text.md", :file?
    assert_match "module: sysl.text", (testpath/"api/sysl-text.md").read

    (testpath/"hello.sysl").write <<~SYSL
      print("Hello, sysl!")
      print(6 * 7)
    SYSL

    # Deliberately more than a smoke test of the binary starting. This drives the
    # whole toolchain: it finds the library installed above, builds the
    # standard-module artifact into the cache from it, emits IR, and hands that
    # to clang to assemble and link -- so it fails if the llvm dependency is not
    # actually reachable at runtime, which is the other way this formula could be
    # wrong and still install.
    #
    # assert_equal rather than assert_match, so this pins the *whole* of stdout
    # rather than passing on the text appearing somewhere in it. And 42 is
    # computed by the compiled program rather than echoed, so a back end that
    # got arithmetic wrong fails here instead of printing a greeting and passing.
    # The artifact-build notice goes to stderr and so is not part of this.
    assert_equal "Hello, sysl!\n42\n", shell_output("#{bin}/sysl run #{testpath}/hello.sysl")
  end
end
