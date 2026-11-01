# SoundCraft in Visual Studio 2026

Open **SoundCraft.slnx** at the repository root. Select **Debug | x64** and press **F5** (Local Windows Debugger). The sole project is the Rust desktop application. Build, Rebuild and Clean call Cargo through packaging/windows/visual-studio.ps1; the VC++ project is a native debugger/build host, not a C++ rewrite.

## Prerequisites

- Visual Studio 2026 with **Desktop development with C++**, the v145 x64 tools and a Windows 10/11 SDK.
- Rust installed through rustup, with **1.95.0-x86_64-pc-windows-msvc**. Install with: rustup toolchain install 1.95.0-x86_64-pc-windows-msvc.
- Network access for the first locked Cargo build, including pinned Git dependencies. Optional craft-fonts is not required to start the app; follow the repository's font instructions if needed.

## Build and debug

Debug writes soundcraft.exe and soundcraft.pdb beneath **target/visual-studio/x86_64-pc-windows-msvc/debug**. Release writes beneath the matching **release** directory and retains the upstream release profile. Other Cargo target directories are separate.

The helper enables full Debug symbols and disables symbol stripping for workspace code while retaining upstream optimization/package overrides. Optimized code can make stepping jump and some locals unavailable. The installed Rust toolchain's Natvis files are included when present. Native debugging does not require a Rust language extension; Rust editing/completion and expression support depend on installed IDE tooling.

The working directory is the repository root. The default debugger environment adds RUST_BACKTRACE=1. The project supplies no sample/document/control arguments and enables no additional optional model features; application startup otherwise follows upstream behavior. To pass a file or sample flag, use **Project Properties > Configuration Properties > Debugging > Command Arguments**. Arguments and other personal debugger choices belong in the ignored .vcxproj.user file.

Build from a terminal with:

    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File packaging/windows/visual-studio.ps1 -Configuration Debug
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File packaging/windows/visual-studio.ps1 -Configuration Release
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File packaging/windows/visual-studio.ps1 -Action Rebuild -Configuration Debug

The helper accepts **-Offline** after dependencies are cached, **-Toolchain** to select another installed MSVC toolchain, and **-Features** for explicit optional Cargo features. The project exposes the matching MSBuild properties CargoOffline=true, CargoToolchain and CargoFeatures. Default Cargo features are unchanged; optional codecs/models/SDKs remain opt-in as specified by this repository.

To limit compilation parallelism, set CARGO_BUILD_JOBS before starting Visual Studio. F5/Build always lets Cargo check dependency freshness, even when the executable already exists. A build failure stops the build; do not choose to launch an older executable after a failed build.

## Troubleshooting

- A missing Microsoft.Cpp.Default.props or v145 toolset means the C++ workload/tools are absent from the Visual Studio instance opening the solution.
- Rust MSVC link/resource errors can indicate missing Windows SDK/tooling. Use a VS 2026 Developer PowerShell if automatic tool detection is unavailable.
- The first build can take several minutes and significant disk space. Offline mode cannot fetch missing crates or Git revisions.
- Keep the PDB beside the executable. If a breakpoint is unbound, check **Debug > Windows > Modules** for this exact executable and symbol path, then place the breakpoint on an executable Rust line.
- If startup fails, inspect this application's logs and existing Windows renderer guidance. This project preserves application renderer defaults.

The solution does not alter Rust sources, Cargo.lock, application behavior, product assets, signing or installer flows. Verification results for the initial setup are recorded in the FlowCTRL Suite Craft Visual Studio setup handoff.

References: [Microsoft makefile projects](https://learn.microsoft.com/en-us/cpp/build/reference/creating-a-makefile-project) and [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html).

## Review-branch validation, 2026-11-01

The setup is based on the latest fetched origin/main. Both Debug and Release x64 MSBuild configurations, solution/project XML and build-helper PowerShell syntax were checked. These configuration checks are not a fresh application build or an interactive F5 acceptance test.

Full application CI was not run under the owner-approved IDE-only review-branch exception.

The owner approved publication of IDE-only review branches with inherited CI failures or incomplete broad checks recorded. This change does not qualify a new FlowCTRL engine bundle or replace its pinned binaries.
