class Webview < Formula
  desc "Tiny cross-platform webview library using the system's own browser engine"
  homepage "https://github.com/webview/webview"
  license "MIT"

  # **A pinned commit rather than a tag, because webview publishes neither.**
  # The repository has no GitHub releases at all -- checked with `gh release list`,
  # which answers nothing -- and no tag for 0.12.0 despite the version macros
  # saying 0.12.0. So there is no stable tarball to point at, and a formula that
  # tracked the branch would install something different every week.
  #
  # This is the commit that `sysl-lang/webview` was written and tested against:
  # `cbbdee4`, "Add Zig Binding (#1352)", 2026-03-09. Nothing about it is special
  # beyond that -- it was the tip of master when the binding was built, the whole
  # C API was surveyed from it, and the binding's suite passes against exactly
  # these bytes. Move it when the binding is re-verified, and not before.
  url "https://github.com/webview/webview.git",
      revision: "cbbdee44afff22867de9fd88a9fc8350d9bdd399"
  version "0.12.0"

  depends_on "cmake" => :build
  depends_on "ninja" => :build

  on_linux do
    depends_on "gtk+3"
    depends_on "webkitgtk"
  end

  def install
    args = %W[
      -DCMAKE_BUILD_TYPE=Release
      -DWEBVIEW_BUILD_SHARED_LIBRARY=ON
      -DWEBVIEW_BUILD_STATIC_LIBRARY=OFF
      -DWEBVIEW_BUILD_AMALGAMATION=OFF
      -DWEBVIEW_BUILD_EXAMPLES=OFF
      -DWEBVIEW_BUILD_TESTS=OFF
      -DWEBVIEW_BUILD_DOCS=OFF
      -DWEBVIEW_INSTALL_DOCS=OFF
      -DWEBVIEW_ENABLE_CHECKS=OFF
      -DWEBVIEW_ENABLE_PACKAGING=OFF
    ]

    # **The one flag that is not obvious, and the one this formula exists for.**
    #
    # webview's CMake gives the library a VERSION and a SOVERSION, so CMake writes
    # its install name as `@rpath/libwebview.0.12.dylib`. A program linked against
    # that needs an `-rpath` on its own link line to find it at run time -- and
    # sysl's `--link-path` emits `-L` and nothing else, so a sysl program links
    # cleanly and then dies at startup with
    #
    #     dyld: Library not loaded: @rpath/libwebview.0.12.dylib
    #           Reason: no LC_RPATH's found
    #
    # which reads as a missing library sitting exactly where it was said to be.
    # Naming the directory in the install name removes the question: the library
    # says where it lives, and nothing downstream has to. Verified before this
    # formula was written -- built both ways into a scratch prefix, and the sysl
    # probe package needs no `DYLD_LIBRARY_PATH` with this flag and does without.
    #
    # It is `opt_lib` rather than `lib` so that the name survives an upgrade: a
    # keg path carries the version, and a program linked against 0.12.0 would go
    # looking for a cellar directory that a later `brew upgrade` has moved.
    args << "-DCMAKE_INSTALL_NAME_DIR=#{opt_lib}"

    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # **Upstream ships no pkg-config file**, so this writes one. That is the whole
    # point of the formula for a sysl consumer: a package declares
    # `pkg_config { webview = "..." }` and the compiler asks pkg-config for the
    # include and link lines, so nobody passes a flag. Homebrew's own `lmdb`
    # formula does exactly this for exactly the same reason.
    #
    # The link line is one `-lwebview` and no frameworks, and that is not an
    # oversight: the shared library records WebKit, libc++ and libobjc as its own
    # load commands, so a C program that links it inherits them. `otool -L`
    # confirms it. That matters more than it looks here, because a sysl `@link`
    # directive names a library and cannot be a `-framework` flag -- so a static
    # libwebview could not be linked from sysl at all.
    (lib/"pkgconfig/webview.pc").write pc_file
  end

  def pc_file
    <<~PC
      prefix=#{opt_prefix}
      exec_prefix=${prefix}
      libdir=${prefix}/lib
      includedir=${prefix}/include

      Name: webview
      Description: #{desc}
      URL: #{homepage}
      Version: #{version}
      Libs: -L${libdir} -lwebview
      Cflags: -I${includedir}
    PC
  end

  test do
    # **The header a C program includes is `webview/api.h`, not `webview/webview.h`.**
    # The latter unconditionally includes `c_api_impl.hh`, which is C++; including
    # it from C fails with a wall of errors that name the C++ header rather than
    # the mistake. Anything that binds this library from C wants `api.h`, and this
    # test is where that is written down in a form that fails if it stops being true.
    (testpath/"version.c").write <<~C
      #include <stdio.h>
      #include <webview/api.h>

      int main(void) {
        const webview_version_info_t *v = webview_version();
        printf("%u.%u.%u\\n", v->version.major, v->version.minor, v->version.patch);
        return 0;
      }
    C

    # **Deliberately no window.** `webview_create` calls `[NSApplication run]` and
    # blocks until the application-did-finish-launching notification arrives, which
    # never happens in a session with no window server attached -- a `brew test`
    # under CI, or any non-Aqua login. A test that opened a window would hang
    # rather than fail, which is the worst way for a test to be wrong.
    #
    # `webview_version` reaches everything this formula could get wrong anyway: the
    # header is found, the library links, the symbol resolves, and the call returns
    # a struct whose contents are checked below.
    system ENV.cc, "version.c", "-o", "version",
           "-I#{include}", "-L#{lib}", "-lwebview"

    assert_equal "#{version}\n", shell_output("./version")

    # The run above already proved the library loads, which is the thing the
    # install-name flag is for -- no `DYLD_LIBRARY_PATH` was set and none is
    # needed. This pins the reason: an `@rpath` install name would have made that
    # run fail, so if somebody drops the flag this assertion says why.
    if OS.mac?
      install_name = shell_output("otool -D #{lib}/libwebview.dylib").lines.last.strip
      assert_match opt_lib.to_s, install_name
    end

    # pkg-config has to answer, since that is how a sysl package reaches this.
    ENV.prepend_path "PKG_CONFIG_PATH", lib/"pkgconfig"
    assert_match "-lwebview", shell_output("pkg-config --libs webview")
    assert_match include.to_s, shell_output("pkg-config --cflags webview")
  end
end
