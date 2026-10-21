class Slimebyte < Formula
  desc "Minecraft slime farm finder: seed search, perimeter commands and a terminal app"
  homepage "https://github.com/kyoubitt/SlimeByte"
  url "https://github.com/kyoubitt/SlimeByte/archive/refs/tags/v1.2.tar.gz"
  sha256 "348dba279ed4ca04f194247085c707d8d8e82721459cc30888cc8040a5b867ad"
  head "https://github.com/kyoubitt/SlimeByte.git", branch: "main"

  depends_on "python@3.13"

  def install
    cd "slime_toolchain" do
      # The CPU tools. The GPU search (slime_gpu) is CUDA, which macOS doesn't have, so it isn't built here.
      system ENV.cxx, "-O3", "-std=c++17", "-pthread", "slime_refine.cpp", "-o", "slime_refine"
      system ENV.cxx, "-O3", "-std=c++17", "perimeter_setup.cpp", "-o", "perimeter_setup"
      system ENV.cxx, "-O3", "-std=c++17", "afk_rescan.cpp", "-o", "afk_rescan"
      system ENV.cxx, "-O3", "-std=c++17", "-pthread", "geo_rank.cpp", "-o", "geo_rank"

      # perimeter_gen: C, linked to the same slime-chunk code through a one-function C++ shim
      mkdir_p "main/work/build"
      system ENV.cxx, "-O2", "-std=c++17", "-c", "perimeter_gen/slime_core_shim.cpp",
             "-o", "main/work/build/slime_core_shim.o"
      system ENV.cc, "-O2", "-std=c11", "-DSLIME_CORE_SHIM",
             "perimeter_gen/src/main.c", "perimeter_gen/src/Perimeter.c", "perimeter_gen/src/util/Inputs.c",
             "main/work/build/slime_core_shim.o", OS.mac? ? "-lc++" : "-lstdc++", "-o", "perimeter_gen/perimeter_gen"

      rm_r "main/work"
      libexec.install Dir["*"]
    end

    # The app writes its saved searches and settings here, not into the Cellar (which every upgrade replaces).
    data_home = OS.mac? ? "$HOME/Library/Application Support/SlimeByte" : "${XDG_DATA_HOME:-$HOME/.local/share}/slimebyte"
    (bin/"slimebyte").write <<~EOS
      #!/bin/bash
      export SLIMEBYTE_DATA="${SLIMEBYTE_DATA:-#{data_home}}"
      exec "#{Formula["python@3.13"].opt_bin}/python3.13" "#{libexec}/slime" "${@:-gui}"
    EOS
  end

  def caveats
    <<~EOS
      Run:  slimebyte

      macOS has no CUDA, so this build has no GPU search: the app does Manual scoring, the map and the
      perimeter commands. Best AFK / Cluster search needs an NVIDIA GPU (Linux or Windows).
    EOS
  end

  test do
    assert_match "slime", shell_output("#{bin}/slimebyte --help")
    assert_predicate libexec/"perimeter_gen/perimeter_gen", :executable?
  end
end
