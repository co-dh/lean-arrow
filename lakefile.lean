import Lake
open Lake DSL System

package «lean-arrow» where
  moreLinkArgs := #[
    "/usr/lib/libarrow.so",
    "/usr/lib/libarrow_compute.so",
    "/usr/lib/libstdc++.so",
    "-Wl,-rpath,/usr/lib",
    "-Wl,--no-as-needed"]

lean_lib Arrow where
  precompileModules := true

lean_lib Apl where
  precompileModules := true

@[default_target]
lean_exe test where
  root := `Test

lean_exe apltest where
  root := `AplTest

target ffi.o pkg : FilePath := do
  let oFile := pkg.buildDir / "ffi" / "arrow_lean.o"
  let src ← inputBinFile <| pkg.dir / "ffi" / "arrow_lean.cpp"
  let lean ← getLeanInstall
  buildO oFile src
    (traceArgs := #["-x", "c++", "-std=c++17", "-fPIC", "-O2", s!"-I{lean.includeDir}"])
    (compiler := "c++")

extern_lib libleanarrow pkg := do
  let name := nameToStaticLib "learnarrow"
  let o ← ffi.o.fetch
  buildStaticLib (pkg.toPackage.staticLibDir / name) #[o]
