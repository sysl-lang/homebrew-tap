class Nex < Formula
  desc "Array-first numerical language with Fortran's semantics, compiled through MLIR"
  homepage "https://github.com/sysl-lang/nex"
  version "0.0.2"
  license "ISC"

  # nex is written in sysl and its release tarball is built on the author's machine by
  # scripts/package.zsh. macOS arm64 only for now: the Linux tarballs are built but not yet checked
  # on Linux.
  depends_on arch: :arm64
  depends_on :macos

  url "https://github.com/sysl-lang/nex/releases/download/v#{version}/nex-#{version}-darwin-arm64.tar.gz"
  sha256 "4c8124ef4505b548a25309b7afee9ec68e5a2578995f7755b8055a10d3733e07"

  # Compiling a program runs LLVM's mlir-opt, mlir-translate and clang, and a program with a
  # `parallel` construct links LLVM's libomp. nex finds them in Homebrew's opt/llvm. The interpreter
  # (`nex run --interp`) needs none of them.
  depends_on "llvm"

  def install
    # nex finds its runtime archive, libnex_rt.a, beside its own executable (the path the loader
    # resolves), so the two stay together in libexec and only nex is linked into bin.
    libexec.install "bin/nex", "bin/libnex_rt.a"
    bin.install_symlink libexec/"nex"
    prefix.install "share"
  end

  test do
    assert_equal "nex #{version}\n", shell_output("#{bin}/nex --version")

    (testpath/"hello.nex").write <<~NEX
      def main() =
        print("Hello, nex!")
        print(6 * 7)
    NEX

    # The interpreter: no toolchain.
    assert_equal "Hello, nex!\n42\n", shell_output("#{bin}/nex run --interp #{testpath}/hello.nex")

    # The compiler, started through the bin/ symlink with no NEX_RUNTIME, so it must find
    # libnex_rt.a beside the real executable. MLIR, clang and the runtime all take part, and 42 is
    # computed by the compiled program.
    assert_equal "Hello, nex!\n42\n", shell_output("#{bin}/nex run #{testpath}/hello.nex")
  end
end
