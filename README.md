## What is this?

This automates [internalizing/recompiling](https://chocolatey.org/docs/how-to-recompile-packages) select Chocolatey packages.

## Why? 

- Because relying on software to be available at a specific URL on the internet in perpetuity is not a good idea.
- Manually downloading and internalizing for each package version is a lot of work.
- The [Chocolatey business license](https://chocolatey.org/pricing#faq-pricing) that also has [automated internalization functionality](https://chocolatey.org/docs/features-automatically-recompile-packages) is-
 
   - Not open source
   - Too expensive for home users at $640/year
   - May require an ongoing license to continue to use packages internalized. 

## Requirements

- PowerShell - tested so far with v5.1 on windows, should be compatible with 6+ and other OSes without too much effort
- `choco` installed and on your path
- Chocolatey `.nupgk` files that do not include all files in the package (i.e. not internal).
- A local chocolatey repository. Proget is ideal

## Setup 

- Copy `personal-packages-template.xml` to `personal-packages.xml` and open it.
- Set `downloadDir` to the directory your `.nupkg` files to internalize are.
- Set `internalizedDir` to the directory where you want the `.nupkg`s to be internalized in.
- If wanted, change `useDropPath` and/or `pushPkgs` to `yes` and change the `pushURL`/`dropPath` accordingly. These auto copy or push the internalized packages to your repository.
- If you have any custom packages, their IDs can be added to the personal section
- `personal-packages.xml` is searched for first in `%appdata%` or `.config` in the internalizer folder, then in the same folder that internalizer runs from. You can also provide a custom path to it. 

## Operation 

- Run `Internalize-ChocoPkg.ps1` in PowerShell
- If you have `useDropPath` and `pushPkgs` disabled, push the packages to your local repository, or in the case of Proget, copy to the drop path.
- If you have `writePerPkgs` disabled, add the package versions to `personal-packages.xml` under the correct IDs. 

## Caveats

- This is alpha software, please do not use in production (yet).
- Packages are supported by whitelist, and support must be added individually for each package. Only a limited subset of packages that would need internalization are supported at this moment.
- Error checking and logging are limited

## Todo

- Checksum downloads
- Logging, and support verbose
- Error checking and handling
- Turn into proper module
- Make individual package functions better
  
    ### Long term
  
  - Async/Parallelize file searching, copying, packing, possibly downloading 
  - Drop dependency on `choco`, possibly requires chocolatey to update the nuget.exe version as current version does not extract files added to zip after pack.
  - Ability to bump version of nupkg
  - Extract files individually rather then extracting all and removing excess, difficult because of packages like virtualbox that have files in root dir
  - Add option to trust names