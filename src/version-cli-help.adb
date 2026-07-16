with Ada.Text_IO;
with Ada.Strings.Unbounded;

package body Version.CLI.Help is

   procedure Append_Line
     (Text : in out Ada.Strings.Unbounded.Unbounded_String;
      Line : String := "")
   is
      use Ada.Strings.Unbounded;
   begin
      Append (Text, Line);
      Append (Text, Character'Val (10));
   end Append_Line;

   function Top_Level_Text return String is
      use Ada.Strings.Unbounded;
      Text : Unbounded_String;
   begin
      Append_Line (Text, "Usage:");
      Append_Line (Text, "  version [--quiet] <command> [arguments]");
      Append_Line (Text, "  version help [command]");
      Append_Line (Text, "  version <command> --help");
      Append_Line (Text, "  version --help | -h");
      Append_Line (Text, "  version --version");
      Append_Line (Text, "  version doctor [--release]");
      Append_Line (Text, "  version completion bash");
      Append_Line (Text, "  version man");
      Append_Line (Text);
      Append_Line (Text, "Repository:");
      Append_Line
        (Text, "  init              Create a Git-compatible repository");
      Append_Line (Text, "  clone             Clone a repository");
      Append_Line
        (Text, "  verify            Verify repository object consistency");
      Append_Line (Text, "  repack            Repack repository objects");
      Append_Line
        (Text,
         "  prune             Report or remove unreachable loose objects");
      Append_Line (Text, "  gc                Run repository maintenance");
      Append_Line
        (Text, "  doctor            Check repository health or release gates");
      Append_Line
        (Text, "  config            Inspect local repository config values");
      Append_Line (Text);
      Append_Line (Text, "Changes:");
      Append_Line (Text, "  stage             Add paths to the index");
      Append_Line
        (Text,
         "  remove            Remove paths from the index and working tree");
      Append_Line (Text, "  mv                Move or rename a tracked file");
      Append_Line
        (Text, "  restore           Restore working tree or staged paths");
      Append_Line (Text, "  apply             Apply a unified diff");
      Append_Line
        (Text, "  format-patch      Write commits as mbox patch files");
      Append_Line
        (Text, "  am                Apply patches from an mbox");
      Append_Line
        (Text, "  cherry            Find commits not yet upstream");
      Append_Line
        (Text, "  range-diff        Compare two ranges of commits");
      Append_Line (Text, "  save              Create or amend a commit");
      Append_Line (Text, "  status            Show working tree status");
      Append_Line
        (Text, "  clean             Remove untracked files");
      Append_Line
        (Text,
         "  diff              Show working tree, staged/cached, or commit diffs");
      Append_Line
        (Text, "  check-ignore      Test whether paths are ignored");
      Append_Line (Text);
      Append_Line (Text, "Branches:");
      Append_Line
        (Text,
         "  branch list       List branches (--verbose/--contains/--merged/no-merged)");
      Append_Line (Text, "  branch current    Print the current branch name");
      Append_Line (Text, "  branch exists     Test whether a branch exists");
      Append_Line (Text, "  branch resolve    Print the branch tip object id");
      Append_Line (Text, "  branch upstream   Print a branch upstream");
      Append_Line
        (Text, "  branch contains   List branches containing a commit");
      Append_Line
        (Text, "  branch merged     List branches merged into a branch");
      Append_Line
        (Text, "  branch unmerged   List branches not merged into a branch");
      Append_Line (Text, "  branch create     Create a branch");
      Append_Line (Text, "  branch switch     Switch branches");
      Append_Line (Text, "  branch rename     Rename a branch");
      Append_Line (Text, "  branch delete     Delete a branch");
      Append_Line (Text, "  branch integrate  Integrate another branch");
      Append_Line (Text, "  merge             Merge branches into HEAD");
      Append_Line
        (Text,
         "  rebase            Replay current branch commits onto a target");
      Append_Line
        (Text, "  cherry-pick       Apply existing commits onto HEAD");
      Append_Line
        (Text,
         "  revert            Create commits that reverse existing commits");
      Append_Line
        (Text,
         "  stash             Save, list, apply, pop, or drop uncommitted work");
      Append_Line
        (Text,
         "  sparse-checkout   Set, add, list, reapply, or disable sparse checkout patterns");
      Append_Line
        (Text,
         "  worktree          Add, list, inspect, or remove linked worktrees");
      Append_Line
        (Text,
         "  submodule         Initialize, update, inspect, sync, foreach, or deinit submodules");
      Append_Line
        (Text, "  archive           Export a revision tree as TAR or ZIP");
      Append_Line (Text);
      Append_Line (Text, "Plumbing:");
      Append_Line (Text, "  cat-file          Show object type, size, or content");
      Append_Line (Text, "  rev-parse         Resolve revisions to object ids");
      Append_Line (Text, "  rev-list          List or count reachable commits");
      Append_Line (Text, "  ls-files          List tracked index paths");
      Append_Line (Text, "  ls-tree           List a tree's entries (-r to recurse)");
      Append_Line (Text, "  hash-object       Hash (and optionally write) a blob");
      Append_Line (Text, "  write-tree        Write the index as a tree");
      Append_Line (Text, "  read-tree         Replace the index with a tree");
      Append_Line (Text, "  commit-tree       Create a commit object");
      Append_Line (Text, "  update-ref        Set or delete a ref");
      Append_Line (Text, "  symbolic-ref      Show or set the branch HEAD points at");
      Append_Line (Text, "  show-ref          List refs and their object ids");
      Append_Line (Text, "  for-each-ref      List refs with object type");
      Append_Line (Text);
      Append_Line (Text, "Remotes:");
      Append_Line (Text, "  remote add        Add a remote");
      Append_Line (Text, "  remote list       List remotes");
      Append_Line (Text, "  remote get-url    Print a remote URL");
      Append_Line (Text, "  remote exists     Test whether a remote exists");
      Append_Line (Text, "  remote set-url    Update a remote URL");
      Append_Line (Text, "  remote rename     Rename a remote");
      Append_Line
        (Text, "  remote prune      Report stale remote-tracking refs");
      Append_Line (Text, "  remote delete     Delete a remote");
      Append_Line (Text, "  fetch             Fetch from a remote");
      Append_Line (Text, "  pull              Fetch and integrate the upstream");
      Append_Line (Text, "  push              Push a branch or tags");
      Append_Line
        (Text, "  bundle            Create, verify, or list a bundle");
      Append_Line (Text);
      Append_Line (Text, "History:");
      Append_Line (Text, "  log               Show commit history");
      Append_Line (Text, "  show              Show a commit");
      Append_Line (Text, "  shortlog          Summarize history by author");
      Append_Line (Text, "  grep              Search tracked files");
      Append_Line (Text, "  describe          Name a commit by nearest tag");
      Append_Line (Text, "  blame             Show per-line commit attribution");
      Append_Line (Text, "  notes             Add or show commit notes");
      Append_Line (Text, "  checkout          Check out a revision or path");
      Append_Line
        (Text, "  reset             Reset HEAD/index/working tree or unstage paths");
      Append_Line
        (Text, "  reflog            Show the ref movement log");
      Append_Line
        (Text, "  tag               Create, delete, list, inspect, or resolve tags");
      Append_Line (Text);
      Append_Line
        (Text,
         "Use 'version help <command>' or 'version <command> --help' for command-specific help.");
      Append_Line
        (Text, "Use --quiet before the command to suppress success messages.");
      return To_String (Text);
   end Top_Level_Text;

   function Command_Text (Name : String) return String is
      use Ada.Strings.Unbounded;
      Text : Unbounded_String;
   begin
      if Name = "stage" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version stage [-f|--force] [--] PATHSPEC...");
         Append_Line (Text);
         Append_Line
           (Text, "Add one or more matching working tree paths to the index.");
         Append_Line
           (Text, "Use -f or --force to stage ignored matches.");
      elsif Name = "save" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version save MESSAGE");
         Append_Line (Text, "  version save -m MESSAGE");
         Append_Line (Text, "  version save --no-verify MESSAGE");
         Append_Line (Text, "  version save --no-verify -m MESSAGE");
         Append_Line (Text, "  version save --amend MESSAGE");
         Append_Line (Text, "  version save --amend -m MESSAGE");
         Append_Line (Text, "  version save --amend --no-verify MESSAGE");
         Append_Line (Text, "  version save --amend --no-verify -m MESSAGE");
         Append_Line (Text);
         Append_Line (Text, "Create a commit, or amend the current commit.");
         Append_Line
           (Text, "Use --no-verify to skip blocking commit hooks.");
      elsif Name = "status" then
         Append_Line (Text, "Usage:");
         Append_Line
           (Text,
            "  version status [--porcelain|--short|--branch] " &
            "[--ignored[=MODE]] [--] [PATHSPEC...]");
         Append_Line (Text);
         Append_Line
           (Text,
            "Show deterministic working tree and index status, optionally filtered by pathspec.");
         Append_Line
           (Text,
            "Use --porcelain or its --short alias for the machine-readable subset.");
         Append_Line
           (Text,
            "Use --branch for a branch header followed by the same short status entries.");
         Append_Line
           (Text,
            "Use --ignored[=traditional|matching|no] with long, short, porcelain, or branch output.");
      elsif Name = "check-ignore" then
         Append_Line (Text, "Usage:");
         Append_Line
           (Text,
            "  version check-ignore [-q|--quiet] [-v|--verbose] " &
            "[--stdin] [-z] [-n|--non-matching] " &
            "[--index|--no-index] [--] PATH...");
         Append_Line (Text);
         Append_Line
           (Text,
            "Print ignored path operands and return success when any operand is "
            & "ignored or, with --verbose, matched by an ignore rule.");
         Append_Line
           (Text, "Use -q or --quiet to test by exit status without output; use "
            & "--stdin, -z, --verbose, --non-matching, and --no-index "
            & "for Git-style inspection modes.");
      elsif Name = "restore" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version restore [--] PATHSPEC...");
         Append_Line (Text, "  version restore --staged [--] PATHSPEC...");
         Append_Line (Text, "  version restore --source REV [--] PATHSPEC...");
         Append_Line
           (Text, "  version restore --source REV --staged [--] PATHSPEC...");
         Append_Line
           (Text, "  version restore --staged --source REV [--] PATHSPEC...");
         Append_Line (Text);
         Append_Line
           (Text,
            "Restore working tree or staged paths selected by pathspec.");
      elsif Name = "branch" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version branch list");
         Append_Line (Text, "  version branch list --verbose");
         Append_Line (Text, "  version branch list --contains REV");
         Append_Line (Text, "  version branch list --merged [BRANCH]");
         Append_Line (Text, "  version branch list --no-merged [BRANCH]");
         Append_Line (Text, "  version branch current");
         Append_Line (Text, "  version branch exists NAME");
         Append_Line (Text, "  version branch resolve NAME");
         Append_Line (Text, "  version branch upstream [BRANCH]");
         Append_Line (Text, "  version branch contains REV");
         Append_Line (Text, "  version branch merged [BRANCH]");
         Append_Line (Text, "  version branch unmerged [BRANCH]");
         Append_Line (Text, "  version branch create NAME");
         Append_Line (Text, "  version branch switch NAME");
         Append_Line (Text, "  version branch rename OLD NEW");
         Append_Line (Text, "  version branch rename NEW");
         Append_Line (Text, "  version branch delete NAME");
         Append_Line (Text, "  version branch delete --force NAME");
         Append_Line (Text, "  version branch delete NAME --force");
         Append_Line (Text, "  version branch integrate NAME");
         Append_Line (Text, "  version branch integrate --finalize");
         Append_Line (Text, "  version branch integrate --abort");
         Append_Line (Text, "  version branch finalize");
         Append_Line
           (Text, "  version branch set-upstream BRANCH REMOTE REMOTE_BRANCH");
         Append_Line (Text, "  version branch unset-upstream BRANCH");
         Append_Line (Text, "  version branch ahead-behind BRANCH");
         Append_Line (Text, "  version branch update NAME");
         Append_Line (Text);
         Append_Line
           (Text,
            "Show, create, switch, rename, delete, track, integrate, or list branches.");
         Append_Line
           (Text,
            "branch list --verbose prints tip details; --contains is an alias.");
         Append_Line
           (Text,
            "branch list --merged and --no-merged alias merged/unmerged.");
         Append_Line
           (Text,
            "branch exists is quiet; branch resolve and upstream print one value.");
      elsif Name = "merge" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version merge [OPTIONS] [TARGET...]");
         Append_Line (Text, "  version merge --continue [--verify|--no-verify]");
         Append_Line (Text, "  version merge --abort");
         Append_Line (Text, "  version merge --quit");
         Append_Line (Text);
         Append_Line
           (Text,
            "Merge one or more TARGET revisions into the current branch.");
         Append_Line
           (Text,
            "Options include --ff, --ff-only, --no-ff, --no-commit, --squash,");
         Append_Line
           (Text,
            "-m/--message, -F/--file, --edit/--no-edit, --log[=N],");
         Append_Line
           (Text,
            "--signoff, --cleanup, -s/--strategy, -X, --conflict,");
         Append_Line
           (Text,
            "--marker-size, --autostash, --verify-signatures/--no-verify-signatures,");
         Append_Line
           (Text,
            "--renormalize, --find-renames[=N], --find-copies[=N], --find-copies-harder, --rerere-autoupdate,");
         Append_Line
           (Text,
            "--gpg-sign, --recurse-submodules, --stat, and --allow-unrelated-histories.");
      elsif Name = "clone" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version clone SOURCE TARGET");
         Append_Line (Text, "  version clone --depth N SOURCE TARGET");
         Append_Line (Text, "  version clone --recursive SOURCE TARGET");
         Append_Line (Text, "  version clone --filter SPEC SOURCE TARGET");
         Append_Line (Text);
         Append_Line
           (Text,
            "Clone SOURCE into TARGET, optionally updating submodules recursively.");
         Append_Line
           (Text, "Use --depth N for a shallow clone when the transport supports it.");
      elsif Name = "fetch" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version fetch REMOTE");
         Append_Line (Text, "  version fetch --depth N REMOTE");
         Append_Line (Text, "  version fetch --deepen N REMOTE");
         Append_Line (Text, "  version fetch --unshallow REMOTE");
         Append_Line (Text);
         Append_Line (Text, "Fetch objects and refs from a remote.");
         Append_Line
           (Text, "Use --depth N for a shallow fetch when the transport supports it.");
      elsif Name = "push" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version push REMOTE");
         Append_Line (Text, "  version push REMOTE BRANCH");
         Append_Line (Text, "  version push --no-verify REMOTE BRANCH");
         Append_Line (Text, "  version push --force REMOTE BRANCH");
         Append_Line (Text, "  version push --delete REMOTE REF");
         Append_Line (Text, "  version push REMOTE SRC:DST");
         Append_Line (Text, "  version push REMOTE :DST");
         Append_Line (Text, "  version push --tags REMOTE");
         Append_Line (Text, "  version push REMOTE --tags");
         Append_Line (Text, "  version push --no-verify --tags [REMOTE]");
         Append_Line (Text, "  version push --no-verify REMOTE --tags");
         Append_Line (Text);
         Append_Line (Text, "Push a branch or tags to a remote.");
         Append_Line
           (Text, "Use --no-verify to skip blocking pre-push hooks.");
      elsif Name = "archive" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version archive REV");
         Append_Line (Text, "  version archive REV --output PATH");
         Append_Line (Text, "  version archive REV --format tar|zip");
         Append_Line (Text, "  version archive REV --prefix DIR/");
         Append_Line (Text, "  version archive REV [--] PATHSPEC...");
         Append_Line (Text);
         Append_Line
           (Text,
            "Export repository contents from a revision tree without using the working tree.");
      elsif Name = "submodule" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version submodule init");
         Append_Line (Text, "  version submodule update [--recursive]");
         Append_Line (Text, "  version submodule status");
         Append_Line
           (Text, "  version submodule foreach [--recursive] COMMAND");
         Append_Line (Text, "  version submodule sync [--recursive]");
         Append_Line
           (Text, "  version submodule deinit [--force] [--all|PATH...]");
         Append_Line (Text);
         Append_Line
           (Text,
            "Initialize, update, and inspect Git-compatible submodules.");
      elsif Name = "worktree" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version worktree add PATH BRANCH");
         Append_Line (Text, "  version worktree add --detach PATH REV");
         Append_Line (Text, "  version worktree list");
         Append_Line (Text, "  version worktree current");
         Append_Line (Text, "  version worktree remove PATH");
         Append_Line (Text);
         Append_Line
           (Text,
            "Manage linked worktrees with shared objects and refs but isolated HEAD and index.");
      elsif Name = "sparse" or else Name = "sparse-checkout" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version sparse-checkout set [--cone|--no-cone] DIR...");
         Append_Line (Text, "  version sparse-checkout add [--cone|--no-cone] DIR...");
         Append_Line (Text, "  version sparse-checkout list");
         Append_Line (Text, "  version sparse-checkout status");
         Append_Line (Text, "  version sparse-checkout reapply");
         Append_Line (Text, "  version sparse-checkout init [--cone|--no-cone]");
         Append_Line (Text, "  version sparse-checkout disable");
         Append_Line (Text);
         Append_Line (Text, "Manage cone-style sparse checkout patterns.");
      elsif Name = "doctor" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version doctor");
         Append_Line (Text, "  version doctor --release");
         Append_Line (Text);
         Append_Line
           (Text,
            "Check repository health, or run release-gate scripts from a source tree.");
      elsif Name = "remote" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version remote add NAME URL");
         Append_Line (Text, "  version remote delete NAME");
         Append_Line (Text, "  version remote remove NAME");
         Append_Line (Text, "  version remote list");
         Append_Line (Text, "  version remote get-url NAME");
         Append_Line (Text, "  version remote exists NAME");
         Append_Line (Text, "  version remote set-url NAME URL");
         Append_Line (Text, "  version remote rename OLD NEW");
         Append_Line (Text, "  version remote prune NAME --dry-run");
         Append_Line (Text, "  version remote prune NAME");
         Append_Line (Text);
         Append_Line (Text, "Manage repository remotes.");
         Append_Line
           (Text,
            "remote list prints stable tab-separated name/url rows.");
         Append_Line
           (Text,
            "remote get-url prints only the configured URL.");
         Append_Line
           (Text,
            "remote exists reports existence by exit status.");
         Append_Line
           (Text,
            "remote set-url updates one existing remote URL.");
         Append_Line
           (Text,
            "remote rename renames an existing remote.");
         Append_Line
           (Text,
            "remote prune reports stale remote-tracking refs.");
      elsif Name = "tag" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version tag create NAME");
         Append_Line (Text, "  version tag create NAME REV");
         Append_Line (Text, "  version tag create -a NAME -m MESSAGE");
         Append_Line (Text, "  version tag create -a NAME REV -m MESSAGE");
         Append_Line (Text, "  version tag delete NAME");
         Append_Line (Text, "  version tag remove NAME");
         Append_Line (Text, "  version tag rename OLD NEW");
         Append_Line (Text, "  version tag list");
         Append_Line (Text, "  version tag list --points-at REV");
         Append_Line (Text, "  version tag list --contains REV");
         Append_Line (Text, "  version tag exists NAME");
         Append_Line (Text, "  version tag resolve NAME");
         Append_Line (Text, "  version tag peel NAME");
         Append_Line (Text, "  version tag show NAME");
         Append_Line (Text);
         Append_Line
           (Text,
            "Create, delete, list, test, resolve, or inspect lightweight and annotated tags.");
         Append_Line (Text, "tag create defaults to HEAD when REV is omitted.");
         Append_Line
           (Text,
            "tag list --points-at REV prints tags whose peeled target is REV.");
         Append_Line
           (Text,
            "tag list --contains REV prints tags whose peeled commit contains REV.");
         Append_Line
           (Text,
            "tag exists is quiet; tag resolve prints the ref object id.");
         Append_Line
           (Text,
            "tag peel prints the peeled target id; tag show inspects the tag.");
      elsif Name = "completion" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version completion bash");
         Append_Line (Text);
         Append_Line (Text, "Print a static bash completion script for version commands.");
      elsif Name = "man" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version man");
         Append_Line (Text);
         Append_Line (Text, "Print generated version(1) roff text.");
      elsif Name = "config" then
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version config list");
         Append_Line (Text, "  version config keys");
         Append_Line (Text, "  version config get KEY");
         Append_Line (Text, "  version config has KEY");
         Append_Line (Text, "  version config set KEY VALUE");
         Append_Line (Text, "  version config unset KEY");
         Append_Line (Text);
         Append_Line
           (Text,
            "List section.key=value entries, keys only, or one value.");
         Append_Line
           (Text,
            "set one local config key or remove one local config key.");
         Append_Line
           (Text,
            "Inspection commands are read-only and report existence by exit status.");
      else
         Append_Line (Text, "Usage:");
         Append_Line (Text, "  version help COMMAND");
      end if;

      return To_String (Text);
   end Command_Text;

   procedure Line (Text : String := "") is
   begin
      Ada.Text_IO.Put_Line (Text);
   end Line;

   function Known_Command (Name : String) return Boolean is
   begin
      return
        Name = "init"
        or else Name = "stage"
        or else Name = "remove"
        or else Name = "save"
        or else Name = "status"
        or else Name = "check-ignore"
        or else Name = "diff"
        or else Name = "log"
        or else Name = "show"
        or else Name = "restore"
        or else Name = "checkout"
        or else Name = "branch"
        or else Name = "merge"
        or else Name = "rebase"
        or else Name = "cherry-pick"
        or else Name = "revert"
        or else Name = "stash"
        or else Name = "sparse"
        or else Name = "sparse-checkout"
        or else Name = "worktree"
        or else Name = "submodule"
        or else Name = "archive"
        or else Name = "tag"
        or else Name = "remote"
        or else Name = "fetch"
        or else Name = "push"
        or else Name = "clone"
        or else Name = "doctor"
        or else Name = "completion"
        or else Name = "man"
        or else Name = "config"
        or else Name = "verify"
        or else Name = "repack"
        or else Name = "prune"
        or else Name = "gc"
        or else Name = "pack-refs"
        or else Name = "lfs"
        or else Name = "history";
   end Known_Command;

   function Completion_Bash_Text return String is
      use Ada.Strings.Unbounded;
      Text : Unbounded_String;
   begin
      Append_Line (Text, "# bash completion for version");
      Append_Line (Text, "_version_completion() {");
      Append_Line (Text, "  local cur=""${COMP_WORDS[COMP_CWORD]}""");
      Append_Line (Text, "  if [ ${COMP_CWORD} -le 1 ]; then");
      Append_Line
        (Text,
         "    COMPREPLY=( $(compgen -W ""--quiet --help -h --version init " &
         "clone verify repack prune gc pack-refs config stage remove save " &
         "status check-ignore diff log show restore checkout branch merge rebase cherry-pick " &
         "revert stash sparse sparse-checkout worktree submodule archive " &
         "tag remote fetch " &
         "push doctor completion man history"" -- ""$cur"") )");
      Append_Line (Text, "    return");
      Append_Line (Text, "  fi");
      Append_Line (Text, "  case ""${COMP_WORDS[1]}"" in");
      Append_Line
        (Text,
         "    tag) COMPREPLY=( $(compgen -W ""create delete remove rename " &
         "list exists resolve peel show --points-at --contains -a -m"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    branch) COMPREPLY=( $(compgen -W ""list current exists resolve " &
         "upstream contains merged unmerged create switch rename delete " &
         "integrate finalize set-upstream unset-upstream ahead-behind " &
         "update --verbose --contains --merged --no-merged --force"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    merge) COMPREPLY=( $(compgen -W ""--continue --abort --quit " &
         "--ff --ff-only --no-ff --no-commit --squash -m --message -F --file " &
         "--strategy -X --strategy-option --conflict --conflict-style " &
         "--marker-size --renormalize --no-renormalize --find-renames " &
         "--find-copies --find-copies-harder --no-copies --no-renames --rerere-autoupdate --no-rerere-autoupdate " &
         "--verify --no-verify --edit --no-edit --autostash --no-autostash " &
         "--recurse-submodules --no-recurse-submodules " &
         "--stat --no-stat --summary --no-summary --compact-summary " &
         "--log --no-log --signoff --no-signoff --cleanup --into-name " &
         "--gpg-sign --no-gpg-sign --verify-signatures --no-verify-signatures " &
         "--quiet --verbose --allow-unrelated-histories"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    save) COMPREPLY=( $(compgen -W ""--no-verify --amend -m"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    push) COMPREPLY=( $(compgen -W ""--no-verify --tags"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    fetch) COMPREPLY=( $(compgen -W ""--depth"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    clone) COMPREPLY=( $(compgen -W ""--depth --recursive"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    remote) COMPREPLY=( $(compgen -W ""add list get-url exists " &
         "set-url rename prune delete remove --dry-run"" -- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    check-ignore) COMPREPLY=( $(compgen -W ""-q --quiet --no-quiet " &
         "-v --verbose --no-verbose --stdin --no-stdin -z -n " &
         "--non-matching --no-non-matching --index --no-index"" " &
         "-- ""$cur"") ) ;;");
      Append_Line
        (Text,
         "    completion) COMPREPLY=( $(compgen -W ""bash"" -- ""$cur"") ) ;;");
      Append_Line (Text, "    *) COMPREPLY=() ;;");
      Append_Line (Text, "  esac");
      Append_Line (Text, "}");
      Append_Line (Text, "complete -F _version_completion version");
      return To_String (Text);
   end Completion_Bash_Text;

   function Man_Page_Text return String is
      use Ada.Strings.Unbounded;
      Text : Unbounded_String;
   begin
      Append_Line (Text, ".TH VERSION 1");
      Append_Line (Text, ".SH NAME");
      Append_Line (Text, "version - practical Git-compatible version control");
      Append_Line (Text, ".SH SYNOPSIS");
      Append_Line (Text, "version [--quiet] COMMAND [ARGUMENTS...]");
      Append_Line (Text, ".SH DESCRIPTION");
      Append_Line (Text, "version provides deterministic Git-compatible repository workflows.");
      Append_Line (Text, ".SH COMMANDS");
      Append_Line (Text, "version save [--no-verify] MESSAGE");
      Append_Line (Text, "version save --amend [--no-verify] MESSAGE");
      Append_Line (Text, "version push [--no-verify] [--force] REMOTE BRANCH");
      Append_Line (Text, "version push [--no-verify] --tags [REMOTE]");
      Append_Line (Text, "version push [--no-verify] --delete REMOTE REF");
      Append_Line (Text, "version push [--no-verify] REMOTE SRC:DST");
      Append_Line
        (Text,
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]");
      Append_Line (Text, "version clone [--depth N] SOURCE TARGET");
      Append_Line (Text, "version merge [OPTIONS] [TARGET...]");
      Append_Line (Text, "version merge --continue [--verify|--no-verify]");
      Append_Line (Text, "version merge --abort");
      Append_Line (Text, "version merge --quit");
      Append_Line (Text, "version tag create NAME [REV]");
      Append_Line (Text, "version tag create -a NAME [REV] -m MESSAGE");
      Append_Line (Text, "version tag resolve NAME");
      Append_Line (Text, "version tag peel NAME");
      Append_Line (Text, "version tag show NAME");
      Append_Line
        (Text,
         "version check-ignore [-q|--quiet] [-v|--verbose] " &
         "[--stdin] [-z] [-n|--non-matching] " &
         "[--index|--no-index] [--] PATH...");
      Append_Line (Text, "version completion bash");
      Append_Line (Text, "version man");
      Append_Line (Text, ".SH EXIT STATUS");
      Append_Line (Text, "0 success; 1 expected operation or validation failure; 2 usage error");
      Append_Line (Text, ".SH SEE ALSO");
      Append_Line (Text, "git(1)");
      return To_String (Text);
   end Man_Page_Text;

   procedure Print_Top_Level is
   begin
      Ada.Text_IO.Put (Top_Level_Text);
   end Print_Top_Level;

   procedure Print_Command (Name : String) is
   begin
      if Name = "init" then
         Line ("Usage:");
         Line ("  version init [PATH]");
         Line ("  version init --bare [PATH]");
         Line ("  version init --object-format=(sha1|sha256) [PATH]");
         Line;
         Line ("Create a new Git-compatible repository.");
         Line ("--object-format selects the hash algorithm (default sha1).");
      elsif Name = "doctor" then
         Line ("Usage:");
         Line ("  version doctor");
         Line ("  version doctor --release");
         Line;
         Line
           ("Check repository health, or run release-gate scripts from a source tree.");
      elsif Name = "tag" then
         Line ("Usage:");
         Line ("  version tag create NAME");
         Line ("  version tag create NAME REV");
         Line ("  version tag create -a NAME -m MESSAGE");
         Line ("  version tag create -a NAME REV -m MESSAGE");
         Line ("  version tag delete NAME");
         Line ("  version tag remove NAME");
         Line ("  version tag rename OLD NEW");
         Line ("  version tag list");
         Line ("  version tag list --points-at REV");
         Line ("  version tag list --contains REV");
         Line ("  version tag exists NAME");
         Line ("  version tag resolve NAME");
         Line ("  version tag peel NAME");
         Line ("  version tag show NAME");
         Line;
         Line
           ("Create, delete, list, test, resolve, or inspect lightweight and annotated tags.");
         Line ("tag create defaults to HEAD when REV is omitted.");
         Line
           ("tag list --points-at REV prints tags whose peeled target is REV.");
         Line
           ("tag list --contains REV prints tags whose peeled commit contains REV.");
         Line ("tag exists is quiet and reports existence by exit status.");
         Line
           ("tag resolve prints only the object id currently stored in the tag ref.");
         Line ("tag peel prints the peeled target id.");
         Line ("tag show prints stable tag details.");
      elsif Name = "config" then
         Line ("Usage:");
         Line ("  version config list");
         Line ("  version config keys");
         Line ("  version config get KEY");
         Line ("  version config has KEY");
         Line ("  version config set KEY VALUE");
         Line ("  version config unset KEY");
         Line;
         Line
           ("List local repository config entries in stable section.key=value form, print local config keys only,");
         Line
           ("print one local config value, quietly test whether a key exists, set one local config key,");
         Line ("or remove one local config key.");
         Line
           ("Inspection commands are read-only; config has is quiet and reports existence by exit status.");
      elsif Name = "stage" then
         Line ("Usage:");
         Line ("  version stage [-f|--force] [--] PATHSPEC...");
         Line;
         Line ("Add one or more matching working tree paths to the index.");
         Line ("Use -f or --force to stage ignored matches.");
      elsif Name = "remove" then
         Line ("Usage:");
         Line ("  version remove [--] PATHSPEC...");
         Line;
         Line
           ("Remove one or more matching tracked paths from the index and working tree.");
      elsif Name = "save" then
         Line ("Usage:");
         Line ("  version save MESSAGE");
         Line ("  version save -m MESSAGE");
         Line ("  version save --no-verify MESSAGE");
         Line ("  version save --no-verify -m MESSAGE");
         Line ("  version save --amend MESSAGE");
         Line ("  version save --amend -m MESSAGE");
         Line ("  version save --amend --no-verify MESSAGE");
         Line ("  version save --amend --no-verify -m MESSAGE");
         Line;
         Line ("Create a commit, or amend the current commit.");
         Line ("Use --no-verify to skip blocking commit hooks.");
      elsif Name = "status" then
         Line ("Usage:");
         Line
           ("  version status [--porcelain|--short|--branch] " &
            "[--ignored[=MODE]] [--] [PATHSPEC...]");
         Line;
         Line
           ("Show deterministic working tree and index status, optionally filtered by pathspec.");
         Line
           ("Use --porcelain or its --short alias for the machine-readable subset.");
         Line
           ("Use --branch for a branch header followed by short status entries.");
         Line
           ("Use --ignored[=traditional|matching|no] with long, short, porcelain, or branch output.");
      elsif Name = "check-ignore" then
         Line ("Usage:");
         Line
           ("  version check-ignore [-q|--quiet] [-v|--verbose] " &
            "[--stdin] [-z] [-n|--non-matching] " &
            "[--index|--no-index] [--] PATH...");
         Line;
         Line
           ("Print ignored path operands and return success when any operand is "
            & "ignored or, with --verbose, matched by an ignore rule.");
         Line
           ("Use -q or --quiet to test by exit status without output; use "
            & "--stdin, -z, --verbose, --non-matching, and --no-index "
            & "for Git-style inspection modes.");
      elsif Name = "diff" then
         Line ("Usage:");
         Line ("  version diff [--] [PATHSPEC...]");
         Line ("  version diff --staged [--] [PATHSPEC...]");
         Line ("  version diff --cached [--] [PATHSPEC...]");
         Line ("  version diff REV1 REV2");
         Line;
         Line ("Show working tree, staged, or commit-to-commit differences.");
         Line ("--cached is a byte-identical alias for --staged.");
      elsif Name = "log" then
         Line ("Usage:");
         Line ("  version log [REV]");
         Line ("  version log --oneline [REV]");
         Line ("  version log --show-signature [REV]");
         Line;
         Line ("Show commit history from HEAD or a revision.");
         Line ("Use --oneline for one compact '<short-id> <subject>' line per commit.");
         Line ("Use --show-signature to verify and show each signed commit's signature.");
      elsif Name = "show" then
         Line ("Usage:");
         Line ("  version show [REV]");
         Line;
         Line ("Show a commit and its changes.");
      elsif Name = "restore" then
         Line ("Usage:");
         Line ("  version restore [--] PATHSPEC...");
         Line ("  version restore --staged [--] PATHSPEC...");
         Line ("  version restore --source REV [--] PATHSPEC...");
         Line ("  version restore --source REV --staged [--] PATHSPEC...");
         Line ("  version restore --staged --source REV [--] PATHSPEC...");
         Line;
         Line ("Restore working tree or staged paths selected by pathspec.");
      elsif Name = "checkout" then
         Line ("Usage:");
         Line ("  version checkout REV");
         Line ("  version checkout REV -- PATHSPEC...");
         Line;
         Line ("Check out a commit or restore matching paths from a commit.");
      elsif Name = "branch" then
         Line ("Usage:");
         Line ("  version branch list");
         Line ("  version branch list --verbose");
         Line ("  version branch list --contains REV");
         Line ("  version branch list --merged [BRANCH]");
         Line ("  version branch list --no-merged [BRANCH]");
         Line ("  version branch current");
         Line ("  version branch exists NAME");
         Line ("  version branch resolve NAME");
         Line ("  version branch upstream [BRANCH]");
         Line ("  version branch contains REV");
         Line ("  version branch merged [BRANCH]");
         Line ("  version branch unmerged [BRANCH]");
         Line ("  version branch create NAME");
         Line ("  version branch switch NAME");
         Line ("  version branch rename OLD NEW");
         Line ("  version branch rename NEW");
         Line ("  version branch delete NAME");
         Line ("  version branch delete --force NAME");
         Line ("  version branch delete NAME --force");
         Line ("  version branch integrate NAME");
         Line ("  version branch integrate --finalize");
         Line ("  version branch integrate --abort");
         Line ("  version branch finalize");
         Line ("  version branch set-upstream BRANCH REMOTE REMOTE_BRANCH");
         Line ("  version branch unset-upstream BRANCH");
         Line ("  version branch ahead-behind BRANCH");
         Line ("  version branch update NAME");
         Line;
         Line
           ("Show, create, switch, rename, delete, track, integrate, or list branches by reachability.");
         Line
           ("branch list --verbose prints current marker, name, short tip id, and commit subject.");
         Line
           ("branch list --contains REV is an alias for branch contains REV.");
         Line
           ("branch list --merged [BRANCH] is an alias for branch merged [BRANCH].");
         Line
           ("branch list --no-merged [BRANCH] is an alias for branch unmerged [BRANCH].");
         Line ("branch exists is quiet and reports existence by exit status.");
         Line
           ("branch resolve prints the branch tip object id plus a trailing newline.");
         Line
           ("branch upstream prints the configured upstream as remote/branch plus a trailing newline.");
      elsif Name = "merge" then
         Line ("Usage:");
         Line ("  version merge [OPTIONS] [TARGET...]");
         Line ("  version merge --continue [--verify|--no-verify]");
         Line ("  version merge --abort");
         Line ("  version merge --quit");
         Line;
         Line
           ("Merge one or more TARGET revisions into the current branch.");
         Line
           ("Options include --ff, --ff-only, --no-ff, --no-commit, --squash,");
         Line
           ("-m/--message, -F/--file, --edit/--no-edit, --log[=N],");
         Line
           ("--signoff, --cleanup, -s/--strategy, -X, --conflict,");
         Line
           ("--marker-size, --autostash, --verify-signatures/--no-verify-signatures,");
         Line
           ("--renormalize, --find-renames[=N], --find-copies[=N], --find-copies-harder, --rerere-autoupdate,");
         Line
           ("--gpg-sign, --recurse-submodules, --stat, and --allow-unrelated-histories.");

      elsif Name = "rebase" then
         Line ("Usage:");
         Line ("  version rebase TARGET");
         Line ("  version rebase --continue");
         Line ("  version rebase --abort");
         Line;
         Line
           ("Replay current branch commits onto TARGET with resumable conflict handling.");
      elsif Name = "cherry-pick" then
         Line ("Usage:");
         Line ("  version cherry-pick REV");
         Line ("  version cherry-pick REV...");
         Line ("  version cherry-pick -m PARENT REV...");
         Line ("  version cherry-pick --mainline PARENT REV...");
         Line ("  version cherry-pick --continue");
         Line ("  version cherry-pick --abort");
         Line;
         Line
           ("Apply existing commits onto the current HEAD without switching branches.");
         Line
           ("Use -m/--mainline to replay a merge commit relative to a parent number.");
      elsif Name = "revert" then
         Line ("Usage:");
         Line ("  version revert REV");
         Line ("  version revert REV...");
         Line ("  version revert -m PARENT REV...");
         Line ("  version revert --mainline PARENT REV...");
         Line ("  version revert --continue");
         Line ("  version revert --abort");
         Line;
         Line
           ("Create commits that reverse existing commits without changing originals.");
         Line
           ("Use -m/--mainline to revert a merge commit relative to a parent number.");

      elsif Name = "stash" then
         Line ("Usage:");
         Line ("  version stash");
         Line ("  version stash push [PATH...]");
         Line ("  version stash push --include-untracked [PATH...]");
         Line ("  version stash push --include-ignored [PATH...]");
         Line ("  version stash create [PATH...]");
         Line ("  version stash create --include-untracked [PATH...]");
         Line ("  version stash create --include-ignored [PATH...]");
         Line ("  version stash store COMMIT");
         Line ("  version stash store -m MESSAGE COMMIT");
         Line ("  version stash list");
         Line ("  version stash show [--patch] [stash@{N}] [PATH...]");
         Line ("  version stash apply [stash@{N}] [PATH...]");
         Line ("  version stash pop [stash@{N}] [PATH...]");
         Line ("  version stash branch NAME [stash@{N}]");
         Line ("  version stash drop [stash@{N}]");
         Line ("  version stash clear");
         Line;
         Line
           ("Temporarily save uncommitted work in refs/stash and restore it later.");

      elsif Name = "sparse" then
         Line ("Usage:");
         Line ("  version sparse set PATHSPEC...");
         Line ("  version sparse add PATHSPEC...");
         Line ("  version sparse disable");
         Line ("  version sparse init");
         Line ("  version sparse list");
         Line ("  version sparse status");
         Line;
         Line
           ("Keep only selected tracked paths materialized in the working tree.");

      elsif Name = "worktree" then
         Line ("Usage:");
         Line ("  version worktree add PATH BRANCH");
         Line ("  version worktree add --detach PATH REV");
         Line ("  version worktree list");
         Line ("  version worktree current");
         Line ("  version worktree remove PATH");
         Line;
         Line
           ("Manage linked worktrees with shared objects and refs but isolated HEAD and index.");

      elsif Name = "submodule" then
         Line ("Usage:");
         Line ("  version submodule init");
         Line ("  version submodule update [--recursive]");
         Line ("  version submodule status");
         Line;
         Line ("Initialize, update, and inspect Git-compatible submodules.");

      elsif Name = "archive" then
         Line ("Usage:");
         Line ("  version archive REV");
         Line ("  version archive REV --output PATH");
         Line ("  version archive REV --format tar|zip");
         Line ("  version archive REV --prefix DIR/");
         Line ("  version archive REV [--] PATHSPEC...");
         Line;
         Line
           ("Export repository contents from a revision tree without using the working tree.");
         Line
           ("TAR and ZIP preserve regular files, directories, executable bits, and symlinks.");

      elsif Name = "tag" then
         Line ("Usage:");
         Line ("  version tag create NAME");
         Line ("  version tag create NAME REV");
         Line ("  version tag create -a NAME -m MESSAGE");
         Line ("  version tag create -a NAME REV -m MESSAGE");
         Line ("  version tag delete NAME");
         Line ("  version tag remove NAME");
         Line ("  version tag rename OLD NEW");
         Line ("  version tag list");
         Line ("  version tag list --points-at REV");
         Line ("  version tag list --contains REV");
         Line ("  version tag exists NAME");
         Line ("  version tag resolve NAME");
         Line ("  version tag peel NAME");
         Line ("  version tag show NAME");
         Line;
         Line
           ("Create, delete, list, test, resolve, or inspect lightweight and annotated tags.");
         Line ("tag create defaults to HEAD when REV is omitted.");
         Line
           ("tag list --points-at REV prints tags whose peeled target is REV.");
         Line
           ("tag list --contains REV prints tags whose peeled commit contains REV.");
         Line ("tag exists is quiet and reports existence by exit status.");
         Line
           ("tag resolve prints only the object id currently stored in the tag ref.");
         Line ("tag peel prints the peeled target id.");
         Line ("tag show prints stable tag details.");
      elsif Name = "remote" then
         Line ("Usage:");
         Line ("  version remote add NAME URL");
         Line ("  version remote delete NAME");
         Line ("  version remote remove NAME");
         Line ("  version remote list");
         Line ("  version remote get-url NAME");
         Line ("  version remote exists NAME");
         Line ("  version remote set-url NAME URL");
         Line ("  version remote rename OLD NEW");
         Line ("  version remote prune NAME --dry-run");
         Line ("  version remote prune NAME");
         Line;
         Line ("Manage repository remotes.");
         Line
           ("remote list prints one tab-separated name/url row per configured remote.");
         Line
           ("remote get-url prints only the configured URL for one remote.");
         Line ("remote exists is quiet and reports existence by exit status.");
         Line
           ("remote set-url updates the configured URL for an existing remote.");
         Line
           ("remote rename renames an existing remote and preserves its URL and fetch refspec.");
         Line
           ("remote prune NAME --dry-run reports stale refs as 'would prune NAME/BRANCH'.");
         Line
           ("remote prune NAME deletes stale refs and reports 'pruned NAME/BRANCH'.");
      elsif Name = "fetch" then
         Line ("Usage:");
         Line ("  version fetch REMOTE");
         Line ("  version fetch --depth N REMOTE");
         Line;
         Line ("Fetch objects and refs from a remote.");
         Line ("Use --depth N for a shallow fetch when the transport supports it.");
      elsif Name = "push" then
         Line ("Usage:");
         Line ("  version push REMOTE");
         Line ("  version push REMOTE BRANCH");
         Line ("  version push --no-verify REMOTE BRANCH");
         Line ("  version push --force REMOTE BRANCH");
         Line ("  version push --delete REMOTE REF");
         Line ("  version push REMOTE SRC:DST");
         Line ("  version push REMOTE :DST");
         Line ("  version push --atomic REMOTE REFSPEC...");
         Line ("  version push --atomic --delete REMOTE REF...");
         Line ("  version push --tags REMOTE");
         Line ("  version push REMOTE --tags");
         Line ("  version push --no-verify --tags [REMOTE]");
         Line ("  version push --no-verify REMOTE --tags");
         Line;
         Line ("Push a branch or tags to a remote.");
         Line ("Use --no-verify to skip blocking pre-push hooks.");
         Line ("Use --atomic to apply all ref updates all-or-nothing"
               & " in one request.");
      elsif Name = "clone" then
         Line ("Usage:");
         Line ("  version clone SOURCE TARGET");
         Line ("  version clone --depth N SOURCE TARGET");
         Line ("  version clone --recursive SOURCE TARGET");
         Line ("  version clone --filter SPEC SOURCE TARGET");
         Line;
         Line
           ("Clone SOURCE into TARGET, optionally updating submodules recursively.");
         Line ("Use --depth N for a shallow clone when the transport supports it.");
      elsif Name = "doctor" then
         Line ("Usage:");
         Line ("  version doctor");
         Line ("  version doctor --release");
         Line;
         Line
           ("Check repository health, or run release-gate scripts from a source tree.");
      elsif Name = "tag" then
         Line ("Usage:");
         Line ("  version tag create NAME");
         Line ("  version tag create NAME REV");
         Line ("  version tag create -a NAME -m MESSAGE");
         Line ("  version tag create -a NAME REV -m MESSAGE");
         Line ("  version tag delete NAME");
         Line ("  version tag remove NAME");
         Line ("  version tag rename OLD NEW");
         Line ("  version tag list");
         Line ("  version tag list --points-at REV");
         Line ("  version tag list --contains REV");
         Line ("  version tag exists NAME");
         Line ("  version tag resolve NAME");
         Line ("  version tag peel NAME");
         Line ("  version tag show NAME");
         Line;
         Line
           ("Create, delete, list, test, resolve, or inspect lightweight and annotated tags.");
         Line ("tag create defaults to HEAD when REV is omitted.");
         Line
           ("tag list --points-at REV prints tags whose peeled target is REV.");
         Line
           ("tag list --contains REV prints tags whose peeled commit contains REV.");
         Line ("tag exists is quiet and reports existence by exit status.");
         Line
           ("tag resolve prints only the object id currently stored in the tag ref.");
         Line ("tag peel prints the peeled target id.");
         Line ("tag show prints stable tag details.");
      elsif Name = "config" then
         Line ("Usage:");
         Line ("  version config list");
         Line ("  version config keys");
         Line ("  version config get KEY");
         Line ("  version config has KEY");
         Line ("  version config set KEY VALUE");
         Line ("  version config unset KEY");
         Line;
         Line
           ("List local repository config entries in stable section.key=value form, print local config keys only,");
         Line
           ("print one local config value, quietly test whether a key exists, set one local config key,");
         Line ("or remove one local config key.");
         Line
           ("Inspection commands are read-only; config has is quiet and reports existence by exit status.");
      elsif Name = "verify" then
         Line ("Usage:");
         Line ("  version verify");
         Line;
         Line ("Verify repository object consistency.");
      elsif Name = "repack" then
         Line ("Usage:");
         Line ("  version repack");
         Line;
         Line ("Write a repository pack from reachable objects.");
      elsif Name = "prune" then
         Line ("Usage:");
         Line ("  version prune [--dry-run|--now]");
         Line;
         Line ("Report or delete unreachable loose objects.");
      elsif Name = "gc" then
         Line ("Usage:");
         Line ("  version gc [--dry-run|--now]");
         Line;
         Line ("Run repository maintenance.");
      elsif Name = "pack-refs" then
         Line ("Usage:");
         Line ("  version pack-refs [--prune]");
         Line;
         Line ("Pack loose refs into packed-refs.");
      elsif Name = "history" then
         Line ("Usage:");
         Line ("  version history");
         Line;
         Line ("Deprecated alias for 'version log'.");
      elsif Name = "lfs" then
         Line ("Usage:");
         Line ("  version lfs track [PATTERN...]");
         Line ("  version lfs untrack PATTERN...");
         Line ("  version lfs ls-files [-l] [REF]");
         Line ("  version lfs status");
         Line ("  version lfs pointer --file=PATH");
         Line ("  version lfs env");
         Line ("  version lfs fetch [--all] [REMOTE [REF...]]");
         Line ("  version lfs pull [REMOTE]");
         Line ("  version lfs checkout [PATH...]");
         Line ("  version lfs push REMOTE [REF]");
         Line ("  version lfs fsck");
         Line ("  version lfs prune [--dry-run]");
         Line ("  version lfs migrate (import|export) --include=PATTERN");
         Line ("  version lfs migrate info [--everything]");
         Line ("  version lfs lock PATH");
         Line ("  version lfs unlock PATH");
         Line ("  version lfs unlock --id ID");
         Line ("  version lfs locks [--path PATH] [--id ID] [--verify]");
         Line;
         Line ("Manage Git LFS: track patterns, inspect pointer files,");
         Line ("fetch/checkout/push media, and lock files on the LFS server.");
         Line
           ("Use --force with unlock to release a lock owned by someone else.");
      else
         Line ("Usage:");
         Line ("  version help COMMAND");
      end if;
   end Print_Command;

end Version.CLI.Help;
