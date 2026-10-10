class Sysl < Formula
  desc "Ref-counted systems language that compiles through LLVM"
  homepage "https://sysl.sh/"
  version "0.1.0-alpha.6"
  license "ISC"

  # The self-hosted compiler: written in sysl and built by itself, from
  # sysl-lang/sysl. macOS arm64 only for now -- the tarball is built on the
  # author's machine by the compiler's own release script (a three-stage build
  # whose second and third stages must emit identical text), and there is no
  # Linux build of it yet.
  depends_on arch: :arm64
  depends_on :macos

  url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-darwin-arm64.tar.gz"
  sha256 "e6ec3c62150f9b631f4cbf93558c8d7bbb15d5e70dcda209f740b78eeb14aaf5"

  # Runtime dependencies. sysl emits textual LLVM IR and shells out from there:
  # clang assembles and links it, and llvm-ar builds archives (Apple's
  # command-line tools ship a clang but no llvm-ar). A package binding an
  # installed C library declares it -- requires { pkg_config { sdl3 = "..." } }
  # -- and the compiler asks pkg-config where it is, and macOS ships no
  # pkg-config. `sysl doc` is built into the compiler, so there is no separate
  # sysl-doc binary and no libuv.
  depends_on "llvm"
  depends_on "pkgconf"

  def install
    # The tarball is already a prefix -- bin/sysl and share/sysl/library -- and the
    # compiler finds its library at <prefix>/share/sysl/library, beside itself, so
    # an old keg left behind keeps using the library it shipped with.
    prefix.install Dir["*"]
  end

  test do
    assert_match "sysl #{version}", shell_output("#{bin}/sysl --version")

    # A tarball without its library installs a compiler that starts and cannot
    # compile anything.
    assert_predicate pkgshare/"library/sysl", :directory?

    # `sysl doc` over the library that shipped in the same tarball: the command is
    # built in, the library is where the compiler looks, and the two came from one
    # tree.
    system bin/"sysl", "doc", "-o", testpath/"api", pkgshare/"library"
    assert_match "module: sysl.text", (testpath/"api/sysl-text.md").read

    (testpath/"hello.sysl").write <<~SYSL
      print("Hello, sysl!")
      print(6 * 7)
    SYSL

    # Drives the whole toolchain: the installed library, the standard-module
    # artifact, IR emission, and clang from the llvm dependency. 42 is computed by
    # the compiled program, so a back end that got arithmetic wrong fails here.
    assert_equal "Hello, sysl!\n42\n", shell_output("#{bin}/sysl run #{testpath}/hello.sysl")
  end
end
