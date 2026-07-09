with Ada.Directories; use Ada.Directories;
with Ada.Strings.Fixed;

with AUnit.Assertions;
with AUnit.Test_Cases;

with Version.Test_Support;

package body Version.Documentation.Tests is

   use AUnit.Assertions;
   use AUnit.Test_Cases.Registration;

   procedure Check_File
     (Path : String)
   is
   begin
      Assert (Ada.Directories.Exists (Path), Path & " must exist");
      Assert
        (Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File,
         Path & " must be an ordinary file");
      Assert
        (Version.Test_Support.Read_Text_File (Path)'Length > 0,
         Path & " must not be empty");
   end Check_File;

   procedure Check_Contains
     (Path : String;
      Text : String)
   is
      Content : constant String := Version.Test_Support.Read_Text_File (Path);
   begin
      Assert
        (Ada.Strings.Fixed.Index (Content, Text) > 0,
         Path & " must mention " & Text);
   end Check_Contains;

   procedure Required_Phase_39_Files_Exist
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Check_File ("README.md");
      Check_File ("CHANGELOG.md");

      Check_File ("docs/COMMANDS.md");
      Check_File ("docs/COMPATIBILITY.md");
      Check_File ("docs/SECURITY.md");
      Check_File ("docs/RELEASE_CHECKLIST.md");
      Check_File ("docs/PACKAGING.md");
      Check_File ("docs/CI.md");

      Check_File ("examples/basic_workflow.md");
      Check_File ("examples/local_remote_workflow.md");
      Check_File ("examples/http_remote_workflow.md");
      Check_File ("examples/ssh_remote_workflow.md");
      Check_File ("examples/worktree_workflow.md");
      Check_File ("examples/submodule_workflow.md");
      Check_File ("examples/archive_workflow.md");
      Check_File ("tools/check_examples.adb");
      Check_File ("tools/check_release_consistency.adb");
      Check_File ("tools/check_platform_ci_matrix.adb");
      Check_File ("tools/check_platform_ci_evidence.adb");
      Check_File ("ci/github-actions-platform-matrix.yml");
   end Required_Phase_39_Files_Exist;

   procedure Command_Reference_Covers_Implemented_Surface
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "docs/COMMANDS.md";
   begin
      Check_Contains (Path, "### init");
      Check_Contains (Path, "### stage");
      Check_Contains (Path, "### remove");
      Check_Contains (Path, "### save");
      Check_Contains (Path, "### status");
      Check_Contains (Path, "### diff");
      Check_Contains (Path, "### log");
      Check_Contains (Path, "### show");
      Check_Contains (Path, "### restore");
      Check_Contains (Path, "### checkout");
      Check_Contains (Path, "### branch");
      Check_Contains (Path, "### tag");
      Check_Contains (Path, "### remote");
      Check_Contains (Path, "### fetch");
      Check_Contains (Path, "### push");
      Check_Contains (Path, "### clone");
      Check_Contains (Path, "### stash");
      Check_Contains (Path, "### rebase");
      Check_Contains (Path, "### cherry-pick");
      Check_Contains (Path, "### revert");
      Check_Contains (Path, "### sparse");
      Check_Contains (Path, "### worktree");
      Check_Contains (Path, "### submodule");
      Check_Contains (Path, "### archive");
      Check_Contains (Path, "### verify");
      Check_Contains (Path, "### repack");
      Check_Contains (Path, "### prune");
      Check_Contains (Path, "### gc");
   end Command_Reference_Covers_Implemented_Surface;

   procedure Compatibility_Document_Is_Honest
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "docs/COMPATIBILITY.md";
   begin
      Check_Contains (Path, "supported/limited");
      Check_Contains (Path, "unsupported");
      Check_Contains (Path, "Loose objects");
      Check_Contains (Path, "Partial clone");
      Check_Contains (Path, "LFS");
   end Compatibility_Document_Is_Honest;

   procedure Examples_Are_Copy_Pasteable_Shell_Blocks
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Check_Contains ("examples/basic_workflow.md", "```sh");
      Check_Contains ("examples/basic_workflow.md", "version init demo");
      Check_Contains ("examples/local_remote_workflow.md", "version push origin main");
      Check_Contains ("examples/worktree_workflow.md", "version worktree add");
      Check_Contains ("examples/submodule_workflow.md", "version submodule update");
      Check_Contains ("examples/archive_workflow.md", "version archive HEAD");
      Check_Contains ("tools/check_examples.adb", "example smoke tests passed");
   end Examples_Are_Copy_Pasteable_Shell_Blocks;

   procedure Release_Checklist_Covers_Required_Smoke_Workflows
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "docs/RELEASE_CHECKLIST.md";
   begin
      Check_Contains (Path, "init -> stage -> save -> git fsck");
      Check_Contains (Path, "clone local -> branch switch -> status clean");
      Check_Contains (Path, "fetch/push local round trip");
      Check_Contains (Path, "archive tar export");
      Check_Contains (Path, "archive zip export");
      Check_Contains (Path, "restore/checkout path workflows");
      Check_Contains (Path, "rebase conflict workflow");
      Check_Contains (Path, "cherry-pick conflict workflow");
      Check_Contains (Path, "revert conflict workflow");
      Check_Contains (Path, "worktree add/remove");
      Check_Contains (Path, "submodule update");
      Check_Contains (Path, "must not depend on the public internet");
      Check_Contains (Path, "tools/bin/check_release_consistency");
      Check_Contains (Path, "tools/bin/check_release_ready");
   end Release_Checklist_Covers_Required_Smoke_Workflows;

   procedure CI_Documentation_Requires_Real_Platform_Gates
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Check_Contains ("docs/CI.md", "POSIX host");
      Check_Contains ("docs/CI.md", "Windows host");
      Check_Contains ("docs/CI.md", "tools/bin/check_platform_ci_matrix posix");
      Check_Contains ("docs/CI.md", "tools/bin/check_platform_ci_matrix windows");
      Check_Contains ("docs/CI.md", "tools/bin/check_platform_ci_evidence");
      Check_Contains ("docs/CI.md", "platform-posix.txt");
      Check_Contains ("docs/CI.md", "platform-windows.txt");
      Check_Contains ("docs/CI.md", "ci/github-actions-platform-matrix.yml");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "ubuntu-latest");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "windows-latest");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "VERSION_PLATFORM_CI_EVIDENCE_DIR");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_matrix posix");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_matrix.exe windows");
      Check_Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_evidence");
   end CI_Documentation_Requires_Real_Platform_Gates;

   overriding procedure Register_Tests
     (T : in out Test_Case)
   is
   begin
      Register_Routine
        (T,
         Required_Phase_39_Files_Exist'Access,
         "docs: required Phase 39 files exist");

      Register_Routine
        (T,
         Command_Reference_Covers_Implemented_Surface'Access,
         "docs: command reference covers implemented surface");

      Register_Routine
        (T,
         Compatibility_Document_Is_Honest'Access,
         "docs: compatibility document is honest");

      Register_Routine
        (T,
         Examples_Are_Copy_Pasteable_Shell_Blocks'Access,
         "docs: examples are copy-pasteable shell blocks");

      Register_Routine
        (T,
         Release_Checklist_Covers_Required_Smoke_Workflows'Access,
         "docs: release checklist covers required smoke workflows");

      Register_Routine
        (T,
         CI_Documentation_Requires_Real_Platform_Gates'Access,
         "docs: CI platform gates are documented");

   end Register_Tests;

   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String
   is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Version.Documentation");
   end Name;

end Version.Documentation.Tests;
