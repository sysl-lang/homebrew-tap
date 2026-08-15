class Sysl < Formula
  desc "Ref-counted systems language that compiles through LLVM"
  homepage "https://sysl.sh/"
  version "0.0.57"
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
      sha256 "82c88e0a03e6583b7747f9373f4dfb96b5a271577a942343dd3e62665ac03fe0"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-x86_64.tar.gz"
      sha256 "20d5cd867f0a1e6d70854b26e9524475682fb9f7b08bcc2eb5663f1c6266b852"
    end

    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-arm64.tar.gz"
      sha256 "a0535bd313a9cbbace880c0a0d96ef4ed538a30e88a44d7122329b53548fefb1"
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
