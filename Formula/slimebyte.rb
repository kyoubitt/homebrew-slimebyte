class Slimebyte < Formula
  desc "Minecraft slime farm finder: seed search, perimeter commands and a terminal app"
  homepage "https://github.com/kyoubitt/SlimeByte"
  url "https://github.com/kyoubitt/SlimeByte/archive/refs/tags/v1.4.tar.gz"
  sha256 "ff1e29d99a3c815a011a4426a36f1df035b2bc2acd393ff2fda620f9a4ac7f63"
  head "https://github.com/kyoubitt/SlimeByte.git", branch: "main"

  depends_on "python@3.13"

  def install
    cd "slime_toolchain" do
      # The position search without CUDA: slime_cl uses the graphics card through OpenCL (opened at run time, so
      # nothing to link), slime_cpu uses every core (AVX2 on an Intel Mac that has it; Apple silicon needs no flag).
      avx2 = Hardware::CPU.intel? && Hardware::CPU.avx2? ? ["-mavx2"] : []
      system ENV.cxx, "-O3", *avx2, "-std=c++17", "-pthread", "slime_cpu.cpp", "-o", "slime_cpu"
      system ENV.cxx, "-O2", "-std=c++17", "slime_cl.cpp", *(OS.linux? ? ["-ldl"] : []), "-o", "slime_cl"

      # The rest of the CPU tools. (slime_gpu is CUDA, which macOS doesn't have, so it isn't built here.)
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

      Best AFK / Cluster search runs on your graphics card through OpenCL, or on the CPU if that
      doesn't work. `slimebyte doctor` says which one it is using.

      Based on xvyz1's Vibecoded-Slime-Chunk-Finder: https://github.com/xvyz1/Vibecoded-Slime-Chunk-Finder
    EOS
  end

  test do
    assert_match "slime", shell_output("#{bin}/slimebyte --help")
    assert_match "SELF TEST PASSED", shell_output("#{libexec}/slime_cpu --self-test")
    assert_predicate libexec/"perimeter_gen/perimeter_gen", :executable?
  end
end
