class Sysl < Formula
  desc "Ref-counted systems language that compiles through LLVM"
  homepage "https://sysl.sh/"
  version "0.0.65"
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
      sha256 "203b8596458c775366c762b8311dbcbfe4e7b74d99c7a497ee0013d49e2095dd"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-x86_64.tar.gz"
      sha256 "e50f324482c2d7c225e0176a92d205a232269e4be0f00bb60ad1bd205bcc176a"
    end

    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-linux-arm64.tar.gz"
      sha256 "6f43ecd6874dfa9feaab5f1d615d9f3efc5e81edd4c601a12232463ce3c9174a"
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
