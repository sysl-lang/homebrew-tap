class SyslAlpha < Formula
  desc "Ref-counted systems language that compiles through LLVM (self-hosted alpha)"
  homepage "https://sysl.sh/"
  version "0.1.0-alpha.1"
  license "ISC"

  # The self-hosted compiler: written in sysl and built by itself, from
  # sysl-lang/sysl rather than sysl-lang/sysl-bootstrap. macOS arm64 only for
  # the alpha -- the tarball is built on the author's machine by the compiler's
  # own release script, and there is no Linux build of it yet.
  on_macos do
    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-darwin-arm64.tar.gz"
      sha256 "9a9bf2edf82e763581e3460b424710d6df1291323bc2a5f6e15ea6bf246d62bf"
    end
  end

  # Keg-only, so it installs beside the `sysl` formula (the 0.0.x bootstrap)
  # without taking the `sysl` name on the PATH from it. Both formulae install a
  # bin/sysl; this one is run as $(brew --prefix sysl-alpha)/bin/sysl.
  keg_only "it is an alpha of the self-hosted compiler and installs the same `sysl` executable as the sysl formula"

  # Runtime dependencies, as for the sysl formula: clang assembles and links the
  # emitted IR and llvm-ar builds archives (Apple's command-line tools ship no
  # llvm-ar), and a package binding an installed C library is found through
  # pkg-config. The alpha has no separate sysl-doc binary, so no libuv.
  depends_on "llvm"
  depends_on "pkgconf"

  def install
    # The tarball is already a prefix -- bin/sysl and share/sysl/library -- and the
    # compiler finds its library at <prefix>/share/sysl/library, beside itself.
    prefix.install Dir["*"]
  end

  test do
    assert_match "sysl #{version}", shell_output("#{bin}/sysl --version")

    # A tarball without its library installs a compiler that starts and cannot
    # compile anything.
    assert_predicate pkgshare/"library/sysl", :directory?

    (testpath/"hello.sysl").write <<~SYSL
      print("Hello, sysl!")
      print(6 * 7)
    SYSL

    # Drives the whole toolchain: the installed library, the standard-module
    # artifact, IR emission, and clang from the llvm dependency. 42 is computed
    # by the compiled program, so a back end that got arithmetic wrong fails here.
    assert_equal "Hello, sysl!\n42\n", shell_output("#{bin}/sysl run #{testpath}/hello.sysl")
  end
end
