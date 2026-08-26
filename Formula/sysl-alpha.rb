# An early build of the next release, published so that work against it can carry
# on while that release's Native gate runs. It is a **prerelease**: ungated, macOS
# arm64 only, and superseded by `sysl` the moment the real version is out.
#
# A formula of its own rather than a change to `sysl.rb`, for two reasons. The tap
# is public, so pointing the ordinary formula at an alpha would serve one to anybody
# installing sysl; and there is no Linux tarball for a prerelease, so the three
# platform blocks `sysl.rb` carries could not all be filled.
#
# Installing it conflicts with `sysl` -- both link `bin/sysl` -- which is deliberate
# and is what keeps a machine from having two compilers answering to one name:
#
#     brew uninstall sysl && brew install sysl-lang/tap/sysl-alpha
#
# and to go back, once the release is out:
#
#     brew uninstall sysl-alpha && brew install sysl-lang/tap/sysl
class SyslAlpha < Formula
  desc "Ref-counted systems language that compiles through LLVM (prerelease)"
  homepage "https://sysl.sh/"
  version "0.0.82-alpha"
  license "ISC"

  # macOS arm64 only. Scala Native does not cross-compile and the Linux tarballs are
  # built by CI off a release tag, which a prerelease deliberately does not trigger.
  on_macos do
    on_arm do
      url "https://github.com/sysl-lang/sysl/releases/download/v#{version}/sysl-#{version}-darwin-arm64.tar.gz"
      sha256 "b5d9f370731d0582f9bf9a30d8cd0fb088010b5fb2abf74ba3efc845127ca9ad"
    end
  end

  conflicts_with "sysl", because: "both install bin/sysl"

  # The same four the release formula takes, and for the same reasons: sysl emits
  # textual LLVM IR and shells out to clang and llvm-ar from there, asks pkg-config
  # where a bound library's headers are, and `sysl-doc` links libuv through juicer.
  depends_on "llvm"
  depends_on "pkgconf"
  depends_on "libuv"

  def install
    # The tarball is already a prefix -- bin/ and share/sysl/library -- so the whole
    # tree moves into the keg and brew links bin/sysl itself.
    prefix.install Dir["*"]
  end

  test do
    assert_match "sysl #{version}", shell_output("#{bin}/sysl --version")

    # The library ships beside the executable rather than inside it, so a tarball
    # staged without it installs a compiler that answers --version and compiles
    # nothing.
    assert_predicate pkgshare/"library/sysl", :directory?
    assert_predicate bin/"sysl-doc", :executable?

    # Exercises what this prerelease is FOR, rather than only that the binary runs:
    # the derivation clause's new spelling, a slice comparing element-wise, and
    # `from_utf8_unchecked` reached as an imported library function. A build without
    # the four cards in it fails here rather than printing a greeting and passing.
    (testpath/"t.sysl").write <<~SYSL
      import sysl.text.from_utf8_unchecked

      struct P derives Eq, Display
          n: int

      val a = [1, 2, 3]
      val b = [1, 2, 3]

      print(a == b, P(1) == P(1), from_utf8_unchecked("hi".bytes))
    SYSL

    assert_equal "true true hi\n", shell_output("#{bin}/sysl run #{testpath}/t.sysl")
  end
end
