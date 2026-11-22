# Task 4 — eSim Upgradation (CSE and related fields)

FOSSEE eSim Semester Long Internship — Autumn 2026

Candidate: Sukumar Sawant  
Date: 22 November 2026  
Upstream: https://github.com/FOSSEE/eSim  
Fork: https://github.com/Sukumarsawant/eSim  
Branch: `installers`

## 1. What I did

I installed Ubuntu 25.04 in VirtualBox, downloaded the official eSim 2.5 ZIP, and tried to install it. The installer failed in several places. I then inspected the Bash installer scripts from the upstream `installers` branch, reproduced each failure with a separate command, and patched two scripts.

I found seven issues. I fixed six of them. The seventh is inside the bundled `nghdl.zip`, so I documented it instead of modifying a binary package.

The main GUI dependency path is covered: the dispatcher syntax error, Ubuntu 25.04 routing, the broken KiCad PPA, the premature `exit 0`, and the wrong KiCad 8 config directory.

## 2. Branch note

The task text says to check out the `installer` branch, but the link in the same document points to:

```text
https://github.com/FOSSEE/eSim/tree/installers
```

The real branch is `installers`, so all work here is against `installers`.

Before starting, I also looked at three existing open Task 4 submissions — PRs #638, #641 and #656 — only to understand the expected report style. They were all open and unmerged. No code or report text was taken from them.

## 3. Links from the task document

I extracted the hyperlinks directly from the task DOCX. The ones used for this task were:

```text
https://github.com/FOSSEE/eSim
https://github.com/FOSSEE/eSim/blob/installers/Ubuntu/install-eSim.sh
https://github.com/FOSSEE/eSim/tree/installers
https://static.fossee.in/esim/installation-files/eSim-2.5.zip
https://llvm.org/
https://spoken-tutorial.org/tutorial-search/?search_foss=BASH&search_language=
https://spoken-tutorial.org/tutorial-search/?search_foss=Git&search_language=English
https://spoken-tutorial.org/tutorial-search/?search_foss=Python+3.4.3&search_language=
```

I downloaded the eSim ZIP from the linked URL and verified it:

```text
b9860ae26f026930bae589520761f4a57b85d593a2e2cd1ac83d5e5db2f281ed  eSim-2.5.zip
```

Evidence: `evidence/03-esim-download-checksum.txt`, `screenshots/03-esim-download-checksum.png`

## 4. Environment

```text
Ubuntu 25.04 (Plucky Puffin), x86_64
Oracle VirtualBox guest
Guest user: sawan
Guest work dir: /home/sawan/esim-task4/eSim-2.5
```

## 5. Problems and fixes

### 1. The upstream dispatcher does not parse

Running `bash -n` on the upstream `Ubuntu/install-eSim.sh` gave:

```text
install-eSim.sh: line 70: syntax error near unexpected token `}'
install-eSim.sh: line 70: `}'
syntax_exit=2
```

Evidence: `evidence/02-upstream-syntax-error.txt`, `screenshots/02-upstream-syntax-error.png`

A bad merge had left a config-writing block and duplicate functions inside `run_version_script()`, with an `if` that was never closed by `fi`. The installer could not start at all.

I replaced the file with a clean dispatcher: proper `if/else/fi`, no duplicated functions, and a case for `25.04`.

### 2. Ubuntu 25.04 is detected as an empty string, and the 25.04 script is unreachable

Running the bundled installer gave:

```text
Detected Ubuntu Version:
Unsupported Ubuntu version: 25.04 ()
exit=1
```

Evidence: `evidence/04-version-detection-bug.txt`, `screenshots/04-version-detection-bug.png`

One important correction: the bundled ZIP **does** contain `install-eSim-scripts/install-eSim-25.04.sh`. The dispatcher simply never calls it:

```text
36:        "22.04")
43:        "23.04")
46:        "24.04")
=== available version scripts ===
install-eSim-22.04.sh
install-eSim-23.04.sh
install-eSim-24.04.sh
install-eSim-25.04.sh
```

Evidence: `evidence/05-bundled-scripts.txt`, `screenshots/05-bundled-scripts.png`

The version check used a three-part regex, which returns nothing for `25.04`. I changed detection to use `lsb_release -rs`, with an `/etc/os-release` fallback, and added the `25.04` case.

After the fix:

```text
syntax OK
Detected Ubuntu Version: 25.04 (25.04)
Running script: /tmp/dispatch-fixed/install-eSim-scripts/install-eSim-25.04.sh --install
STUB VERSION SCRIPT CALLED WITH: --install
```

Evidence: `evidence/17-fixed-dispatcher.txt`, `screenshots/17-fixed-dispatcher.png`

### 3. The KiCad PPA breaks on Ubuntu 25.04

After adding `ppa:kicad/kicad-8.0-releases`:

```text
Candidate: 8.0.9-0~ubuntu25.04.1
...
The following packages have unmet dependencies:
 kicad : Depends: libgit2-1.8 (>= 1.8.0) but it is not installable
E: Unable to correct problems, you have held broken packages.
```

Evidence: `evidence/07-kicad-ppa-broken.txt`, `screenshots/07-kicad-ppa-broken.png`

The PPA offers KiCad 8.0.9 for Plucky, but `libgit2-1.8` is not available in Ubuntu 25.04. The script also pinned `kicad=8.0.8+dfsg-1`, which is stale on 25.04.

I made the 25.04 path skip the PPA and install the unversioned archive packages. The old pin remains only for 24.04. After removing the PPA, the fixed function installed KiCad cleanly:

```text
=== kicad candidate after PPA removal ===
kicad:
  Installed: (none)
  Candidate: 8.0.8+dfsg-1
...
KiCad installation completed successfully!
kicad version: 8.0.8+dfsg-1
```

Evidence: `evidence/20-clean-kicad-install.txt`, `screenshots/20-clean-kicad-install.png`

### 4. `installKicad` exited the whole installer

The original function ended with:

```bash
echo "KiCad 8.0 is already installed."
exit 0
```

A small harness showed the line after the call never ran:

```text
before installKicad
Installing KiCad...........................
Ubuntu 25.04 detected.
KiCad 8.0 is already installed.
harness_exit=0
```

Evidence: `evidence/09-exit0-bug.txt`, `screenshots/09-exit0-bug.png`

On a normal 25.04 system KiCad 8 is already present, so NGHDL, SKY130, symbols and the launcher were silently skipped while the installer returned success. I changed `exit 0` to `return 0`.

### 5. Symbols went to the wrong KiCad directory

KiCad 8 uses `~/.config/kicad/8.0`, but the script hardcoded `6.0`:

```text
$ kicad-cli version
8.0.8
$ ls -d ~/.config/kicad/*
/home/sawan/.config/kicad/8.0

234:    if [ -d ~/.config/kicad/6.0 ];then
242:    cp kicadLibrary/template/sym-lib-table ~/.config/kicad/6.0/
```

Evidence: `evidence/10-kicad-config-dir-bug.txt`, `screenshots/10-kicad-config-dir-bug.png`

I now derive the directory from `kicad-cli version`. The result:

```text
Using KiCad config directory: /home/sawan/.config/kicad/8.0
symbol table copied in the directory
-rw-rw-r-- 1 sawan sawan 37320 ... /home/sawan/.config/kicad/8.0/sym-lib-table
```

Evidence: `evidence/19-fixed-symbol-table.txt`, `screenshots/19-fixed-symbol-table.png`

### 6. `apt install` had no `-y`

A non-interactive run stopped at:

```text
Continue? [Y/n] Abort.
apt_exit=1
```

Evidence: `evidence/11-apt-no-y-bug.txt`, `screenshots/11-apt-no-y-bug.png`

I changed it to `sudo apt-get install -y python3-virtualenv`.

### 7. Bundled NGHDL has no Ubuntu 25.04 script — reported, not fixed

The bundled NGHDL dispatcher only ships scripts for 22.04, 23.04 and 24.04:

```text
Detected Ubuntu Version:
Unsupported Ubuntu version: 25.04 ()
nghdl_exit=1

llvm:
  Candidate: 1:20.0-63ubuntu1
llvm-dev:
  Candidate: 1:20.0-63ubuntu1
```

Evidence: `evidence/06-nghdl-no-2504.txt`, `screenshots/06-nghdl-no-2504.png`

Ubuntu 25.04 provides LLVM 20 while the bundled GHDL is 4.1.0, so blindly reusing the 24.04 script is unsafe. This fix belongs in `FOSSEE/nghdl` and requires repackaging `nghdl.zip`, so I left it as a documented upstream issue.

## 6. Verification

I used Bash for the reproduction and fixes, and a small Python check during preparation to confirm the patched files statically. It passed all nine checks:

```text
9/9 checks passed
```

Evidence: `evidence/15-python-verifier.txt`, `screenshots/15-python-verifier.png`

Live checks in the VM confirmed the dispatcher routes 25.04, `installKicad` returns properly, the symbol table lands in the KiCad 8 directory, and KiCad 8.0.8 installs from the Ubuntu archive without the broken PPA.

## 7. How this maps to the evaluation criteria

**Documentation quality.** This report walks through each bug with the command that exposed it, the output, the root cause, the change made, and a verification result. The repository also keeps the original command outputs in `evidence/` and matching command-and-output images in `screenshots/`, so a reader can follow what was tried and why each fix was needed.

**Number of issues reported.** Seven issues are documented in §5.

**Number of issues fixed.** Six of the seven are fixed in the two installer scripts. The remaining one is inside the bundled `nghdl.zip` and is documented as an upstream item.

**Difficulty of the problems fixed.** The fixes sit on the main GUI dependency path, not just the smaller blocks: dispatcher syntax, Ubuntu 25.04 routing, the KiCad PPA/`libgit2-1.8` failure, the premature `exit 0`, the KiCad 8 config directory, and the non-interactive `apt` call. Only NGHDL/LLVM is left unfixed.

## 8. Expected vs done checklist

| Expected by the task | Status | Where |
|---|---|---|
| Install Ubuntu 25.04 | Done | VirtualBox guest, `lsb_release -rs` = `25.04` |
| Download eSim 2.5 from the linked URL | Done | SHA256 recorded in §3 |
| List problems faced, including dependency issues | Done | 7 issues in §5 |
| Inspect and change `install-eSim.sh` | Done | Dispatcher rewritten |
| Fix at least one issue | Done | 6 issues fixed |
| Use Bash Script | Done | Installer inspection, patching and reproduction commands |
| Use Python | Done | Static verification, evidence in §6 |
| Use eSim | Done | eSim 2.5 ZIP downloaded, checksummed and installed |
| Refer to Git / Spoken Tutorial on Git | Done | Fork/branch/commit workflow; task link noted in §3 |
| Use Ubuntu 25.04 OS | Done | All reproduction performed in the VM |
| Create a well-documented report | Done | This file |
| Fork the repository | Done | `Sukumarsawant/eSim` |
| Checkout the installer branch | Done as `installers` | Real branch name explained in §2 |
| Commit code files | Done | Two installer scripts committed |
| Share fork link and report by email | Pending | To be done after pushing |

## 9. Technologies used

- **Bash Script** — the installer scripts were inspected, reproduced and patched with Bash.
- **Python** — a small static check was used during preparation; its output is in §6.
- **eSim** — the official eSim 2.5 ZIP was downloaded, verified and installed.
- **Git / Spoken Tutorial on Git** — the fork, upstream remote, `installers` branch and commits follow the Git workflow referenced by the task.
- **Ubuntu 25.04 OS** — the VirtualBox guest used for every reproduction and verification.

## 10. Submission procedure

| Step | Status |
|---|---|
| Create a GitHub account | Done — `Sukumarsawant` |
| Fork `FOSSEE/eSim` | Done — `https://github.com/Sukumarsawant/eSim` |
| Checkout the installer branch | Done as `installers` (the real branch name) |
| Commit the code files | Done — both installer scripts are committed and pushed |
| Mail the fork link and report to `contact-esim@fossee.in` | Pending |

Email subject to use:

```text
eSim Semester Long Internship - Autumn 2026 Submission Task 4
```

Fork link to include:

```text
https://github.com/Sukumarsawant/eSim/tree/installers
```

## 11. Files changed

```text
Ubuntu/install-eSim.sh
Ubuntu/install-eSim-scripts/install-eSim-25.04.sh
TASK4_REPORT.md
evidence/            selected command outputs
screenshots/         matching command + output images
```

The diff for the two scripts is:

```text
2 files changed, 97 insertions(+), 303 deletions(-)
```
