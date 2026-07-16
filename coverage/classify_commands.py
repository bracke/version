#!/usr/bin/env python3
"""Command-level functional coverage of git by `version`.

Measures whether the *capability* of each git command exists in version,
honouring version's intentional renames (commit->save, add->stage, ...).
The mapping/judgment tables below are explicit and reviewable on purpose --
adjust them rather than trusting a black box. Every MISSING entry is a real
functional gap; nothing is silently bucketed away.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

def load(name):
    with open(os.path.join(HERE, name)) as f:
        return sorted({l.strip() for l in f if l.strip()})

git_cmds = load("git-main-cmds.txt")
version_cmds = set(load("version-cmds.txt"))

# git command -> version command, where version deliberately renames it,
# or where git itself has an exact-equivalent alias version already covers.
RENAME = {
    "commit": "save",
    "add": "stage",
    "rm": "remove",
    "fsck": "verify",
    "init-db": "init",           # git alias of init
    "fsck-objects": "verify",    # git alias of fsck
    "version": "--version",      # `git version` == `git --version`
    "annotate": "blame",         # annotate is blame with a different layout
    "pickaxe": "blame",          # git-pickaxe was renamed to git-blame in 2006
}

# Declared non-goals (roadmap), deprecated, GUIs, web, foreign-SCM bridges,
# and pure server/transport daemons. Not counted against functional coverage,
# but listed transparently.
OUT_OF_SCOPE = {
    # roadmap non-goals / deprecated
    "send-email", "whatchanged", "request-pull",
    # git itself refuses to run this one now ("nominated for removal";
    # it dies unless you pass --i-still-use-this) and is deleting it.
    "pack-redundant",
    # experimental: git's own man pages say "THIS COMMAND IS EXPERIMENTAL.
    # THE BEHAVIOR MAY CHANGE."  Not a contract to match.  (version happens to
    # implement backfill, last-modified and `repo info` anyway; they just do
    # not count towards coverage.)
    "replay", "repo", "backfill", "last-modified",
    # GUIs / web
    "gitk", "gui", "citool", "instaweb", "gitweb",
    # foreign SCM bridges
    "p4", "svn", "cvsimport", "cvsexportcommit", "cvsserver",
    "archimport", "quiltimport",
    # server-side daemons / transport servers (version implements the client
    # + the protocol internally, but not these standalone server CLIs)
    "daemon", "http-backend", "update-server-info",
    # dumb-HTTP push: WebDAV against a server, the write half of a protocol
    # git deprecates (its server side, update-server-info, is already here).
    "http-push",
    "upload-pack", "receive-pack", "upload-archive",
    "fsmonitor--daemon", "shell",
    # bridges to other tools/formats
    "imap-send", "latexdiff",
}

# Internal helpers users never invoke directly.
HELPERS = {
    "checkout--worker", "checkout-index", "sh-i18n--envsubst", "column",
    "bugreport", "diagnose", "credential-cache", "credential-cache--daemon",
    "credential-store", "remote-ext", "remote-fd", "remote-ftp",
    "remote-ftps", "remote-http", "remote-https", "remote-testsvn", "sh-setup",
    "mergetool--lib", "difftool--helper", "web--browse",
    "submodule--helper", "upload-archive--writer",
}

present, renamed, missing, oos, helper = [], [], [], [], []
for c in git_cmds:
    if c in HELPERS:
        helper.append(c)
    elif c in OUT_OF_SCOPE:
        oos.append(c)
    elif c in version_cmds:
        present.append(c)
    elif c in RENAME and RENAME[c] in version_cmds:
        renamed.append((c, RENAME[c]))
    else:
        missing.append(c)

denom = len(present) + len(renamed) + len(missing)
covered = len(present) + len(renamed)
pct = (100.0 * covered / denom) if denom else 0.0

print(f"git ({len(git_cmds)} commands catalogued) vs version\n")
print(f"  present (same name):   {len(present)}")
print(f"  present (renamed):     {len(renamed)}")
print(f"  MISSING (real gap):    {len(missing)}")
print(f"  out-of-scope:          {len(oos)}")
print(f"  internal helper:       {len(helper)}")
print(f"\n  FUNCTIONAL COMMAND COVERAGE: {covered}/{denom} = {pct:.1f}%")
print(f"  (denominator excludes {len(oos)} out-of-scope + {len(helper)} helpers)\n")

print("== RENAMED (intentional, kept) ==")
print("  " + ", ".join(f"{g}->{v}" for g, v in renamed))
print("\n== MISSING functionality (the real gap) ==")
for c in missing:
    print(f"  {c}")
print("\n== version-only commands (extras beyond git) ==")
extras = sorted(version_cmds - set(git_cmds) - {RENAME[g] for g in RENAME})
print("  " + ", ".join(extras))
