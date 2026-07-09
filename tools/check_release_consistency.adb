with Ada.Command_Line;
with Ada.Text_IO;

with Tool_Doc_Guards;
with Tool_Support;

with Project_Tools.Release_Checks;

procedure Check_Release_Consistency is

   --  Failures are reported through project_tools' release-check model:
   --  file-existence requirements use a Release_Checks.Checker (see Checks
   --  below) and bespoke checks use Release_Checks.Fail. Both raise
   --  Program_Error after setting the failure exit status; the main body
   --  catches it so the tool still exits non-zero.
   procedure Require_Contains (Path, Needle, Message : String) is
   begin
      if not Tool_Support.Contains (Path, Needle) then
         Project_Tools.Release_Checks.Fail (Message);
      end if;
   end Require_Contains;

   procedure Require_Any_File_Contains
     (Needle  : String;
      Message : String)
   is
   begin
      if Tool_Support.Contains ("docs/COMPATIBILITY.md", Needle) then
         return;
      end if;

      Project_Tools.Release_Checks.Fail (Message);
   end Require_Any_File_Contains;

   procedure Require_Hook_Docs (Hook : String) is
   begin
      Require_Contains
        ("docs/COMPATIBILITY.md", Hook,
         "COMPATIBILITY.md does not mention hook " & Hook);
      Require_Contains
        ("docs/SECURITY.md", Hook,
         "SECURITY.md does not mention hook " & Hook);
   end Require_Hook_Docs;

   procedure Require_Command (Command : String) is
   begin
      Require_Contains
        ("docs/COMMANDS.md", "### " & Command,
         "COMMANDS.md missing public command " & Command);
   end Require_Command;

   procedure Require_Workflow (Workflow : String) is
   begin
      Require_Contains
        ("docs/RELEASE_CHECKLIST.md", Workflow,
         "release checklist missing " & Workflow);
   end Require_Workflow;

   procedure Check_No_Stale_Source_Path (Path : String) is
      Stale : constant String := "src" & "/core/";
   begin
      if Tool_Support.Contains (Path, Stale) then
         Project_Tools.Release_Checks.Fail ("release gate contains stale src/core path: " & Path);
      end if;
   end Check_No_Stale_Source_Path;

   Checks : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (".");
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: check_release_consistency");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Hook_Docs ("pre-commit");
   Require_Hook_Docs ("commit-msg");
   Require_Hook_Docs ("post-commit");
   Require_Hook_Docs ("post-checkout");
   Require_Hook_Docs ("pre-push");

   Require_Command ("init");
   Require_Command ("stage");
   Require_Command ("remove");
   Require_Command ("save");
   Require_Command ("status");
   Require_Command ("diff");
   Require_Command ("log");
   Require_Command ("show");
   Require_Command ("restore");
   Require_Command ("checkout");
   Require_Command ("branch");
   Require_Command ("tag");
   Require_Command ("remote");
   Require_Command ("fetch");
   Require_Command ("push");
   Require_Command ("clone");
   Require_Command ("stash");
   Require_Command ("rebase");
   Require_Command ("cherry-pick");
   Require_Command ("revert");
   Require_Command ("sparse");
   Require_Command ("worktree");
   Require_Command ("submodule");
   Require_Command ("archive");
   Require_Command ("verify");
   Require_Command ("repack");
   Require_Command ("prune");
   Require_Command ("gc");

   Require_Any_File_Contains
     ("SHA-256", "unsupported-scope docs do not mention SHA-256");
   Require_Any_File_Contains
     ("Partial clone", "unsupported-scope docs do not mention Partial clone");
   Require_Any_File_Contains
     ("sparse-index `sdir`", "compatibility docs do not mention sparse-index read expansion");
   Require_Any_File_Contains
     ("Git LFS", "unsupported-scope docs do not mention Git LFS");

   Require_Workflow ("init -> stage -> save -> git fsck");
   Require_Workflow ("clone local -> branch switch -> status clean");
   Require_Workflow ("fetch/push local round trip");
   Require_Workflow ("archive tar export");
   Require_Workflow ("archive zip export");
   Require_Workflow ("restore/checkout path workflows");
   Require_Workflow ("submodule update");

   if Tool_Support.First_Line ("docs/RELEASE_NOTES.md") /= "# Release notes: 0.1.0-dev" then
      Project_Tools.Release_Checks.Fail ("release notes must start with the release heading");
   end if;

   if not Tool_Support.Starts_With
       (Tool_Support.Second_Nonblank_Line ("docs/RELEASE_NOTES.md"),
        "This is a release-stabilization")
   then
      Project_Tools.Release_Checks.Fail
        ("release notes must start with the baseline release narrative");
   end if;

   Tool_Doc_Guards.Require_No_Stale_Tool_Script_References;

   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_release_consistency", "release checklist does not run consistency audit");
   Require_Contains ("docs/PACKAGING.md", "check_release_consistency", "packaging docs do not run consistency audit");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_release_ready", "release checklist does not run Ada release preflight");
   Require_Contains ("docs/PACKAGING.md", "check_release_ready", "packaging docs do not run Ada release preflight");
   Require_Contains ("docs/TESTING.md", "check_release_ready", "testing docs do not describe Ada release preflight");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_test_scope_completeness", "release checklist does not run test-scope completeness gate");
   Require_Contains ("docs/PACKAGING.md", "check_test_scope_completeness", "packaging docs do not run test-scope completeness gate");
   Require_Contains ("docs/TESTING.md", "check_test_scope_completeness", "testing docs do not describe test-scope completeness gate");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_ref_write_policy", "release checklist does not run ref write policy gate");
   Require_Contains ("docs/PACKAGING.md", "check_ref_write_policy", "packaging docs do not run ref write policy gate");
   Require_Contains ("docs/TESTING.md", "check_ref_write_policy", "testing docs do not describe ref write policy gate");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_ref_write_policy_selftest", "release checklist does not run ref write policy self-test");
   Require_Contains ("docs/PACKAGING.md", "check_ref_write_policy_selftest", "packaging docs do not run ref write policy self-test");
   Require_Contains ("docs/TESTING.md", "check_ref_write_policy_selftest", "testing docs do not describe ref write policy self-test");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_ref_transaction_selftest", "release checklist does not run ref transaction self-test");
   Require_Contains ("docs/PACKAGING.md", "check_ref_transaction_selftest", "packaging docs do not run ref transaction self-test");
   Require_Contains ("docs/TESTING.md", "check_ref_transaction_selftest", "testing docs do not describe ref transaction self-test");
   Require_Contains ("docs/RELEASE_NOTES.md", "check_ref_transaction_selftest", "release notes do not mention ref transaction self-test");
   Require_Contains ("docs/RELEASE_NOTES.md", "ref_transaction=passed", "release notes do not mention ref transaction evidence marker");
   Require_Contains ("CHANGELOG.md", "check_ref_transaction_selftest", "changelog does not mention ref transaction self-test");
   Require_Contains ("CHANGELOG.md", "ref_transaction=passed", "changelog does not mention ref transaction evidence marker");
   Require_Contains ("docs/CHANGELOG.md", "check_ref_transaction_selftest", "docs changelog does not mention ref transaction self-test");
   Require_Contains ("docs/CHANGELOG.md", "ref_transaction=passed", "docs changelog does not mention ref transaction evidence marker");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_platform_ci_evidence_selftest", "release checklist does not run platform evidence self-test");
   Require_Contains ("docs/PACKAGING.md", "check_platform_ci_evidence_selftest", "packaging docs do not run platform evidence self-test");
   Require_Contains ("docs/TESTING.md", "check_platform_ci_evidence_selftest", "testing docs do not describe platform evidence self-test");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_release_package_selftest", "release checklist does not run package self-test");
   Require_Contains ("docs/PACKAGING.md", "check_release_package_selftest", "packaging docs do not run package self-test");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_documentation_coherence", "release checklist does not run documentation coherence check");
   Require_Contains ("docs/PACKAGING.md", "check_documentation_coherence", "packaging docs do not run documentation coherence check");
   Require_Contains ("docs/TESTING.md", "check_documentation_coherence", "testing docs do not describe documentation coherence check");

   Checks.Require_File ("docs/CI.md");
   Checks.Require_File ("ci/github-actions-platform-matrix.yml");
   Checks.Require_File ("tools/check_release_package_selftest.adb");
   Checks.Require_File ("tools/check_release_ready.adb");
   Checks.Require_File ("tools/check_test_scope_completeness.adb");
   Checks.Require_File ("tools/check_ref_write_policy.adb");
   Checks.Require_File ("tools/check_ref_write_policy_selftest.adb");
   Checks.Require_File ("tools/check_ref_transaction_selftest.adb");
   Checks.Require_File ("tools/check_documentation_coherence.adb");
   Checks.Require_File ("tools/tool_doc_guards.ads");
   Checks.Require_File ("tools/tool_doc_guards.adb");
   Require_Contains ("tools/check_documentation_coherence.adb", "Tool_Doc_Guards", "documentation coherence does not use shared doc guards");
   Require_Contains ("tools/check_release_consistency.adb", "Tool_Doc_Guards", "release consistency does not use shared doc guards");
   Checks.Require_File ("tools/check_platform_ci_matrix.adb");
   Checks.Require_File ("tools/check_platform_ci_evidence.adb");
   Checks.Require_File ("tools/check_platform_ci_evidence_selftest.adb");
   Checks.Require_File ("tools/summarize_release_evidence.adb");

   Check_No_Stale_Source_Path ("tools/check_release_consistency.adb");
   Check_No_Stale_Source_Path ("tools/check_test_scope_completeness.adb");
   Check_No_Stale_Source_Path ("tools/check_version_metadata.adb");

   Require_Contains ("docs/CI.md", "tools/bin/check_platform_ci_matrix posix", "CI docs missing POSIX platform gate");
   Require_Contains ("docs/CI.md", "tools/bin/check_platform_ci_matrix windows", "CI docs missing Windows platform gate");
   Require_Contains ("docs/CI.md", "tools/bin/check_platform_ci_evidence", "CI docs missing platform evidence gate");
   Require_Contains ("docs/CI.md", "tools/bin/summarize_release_evidence", "CI docs missing evidence summary helper");
   Require_Contains ("tools/check_platform_ci_matrix.adb", "ref_transaction=passed", "platform matrix does not write ref transaction evidence");
   Require_Contains ("tools/check_platform_ci_matrix.adb", "check_ref_transaction_selftest", "platform matrix does not run ref transaction self-test");
   Require_Contains ("tools/check_platform_ci_evidence.adb", "ref_transaction=passed", "platform evidence checker does not require ref transaction evidence");
   Require_Contains ("tools/summarize_release_evidence.adb", "ref_transaction", "platform evidence summary does not report ref transaction evidence");
   Require_Contains ("tools/check_platform_ci_evidence_selftest.adb", "missing POSIX ref_transaction evidence", "platform evidence self-test missing POSIX ref transaction negative case");
   Require_Contains ("tools/check_platform_ci_evidence_selftest.adb", "bad Windows ref_transaction evidence", "platform evidence self-test missing bad ref transaction negative case");
   Require_Contains ("docs/TESTING.md", "ref_transaction=passed", "testing docs missing ref transaction evidence marker");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "ref_transaction=passed", "release checklist missing ref transaction evidence marker");
   Require_Contains ("ci/github-actions-platform-matrix.yml", "ubuntu-latest", "CI matrix missing POSIX runner");
   Require_Contains ("ci/github-actions-platform-matrix.yml", "windows-latest", "CI matrix missing Windows runner");
   Require_Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_matrix posix", "CI matrix does not run POSIX gate");
   if not Tool_Support.Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_matrix windows")
     and then not Tool_Support.Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_matrix.exe windows")
   then
      Project_Tools.Release_Checks.Fail ("CI matrix does not run Windows gate");
   end if;
   Require_Contains ("ci/github-actions-platform-matrix.yml", "check_platform_ci_evidence", "CI matrix does not verify platform evidence");
   Require_Contains ("ci/github-actions-platform-matrix.yml", "VERSION_PLATFORM_CI_EVIDENCE_DIR", "CI matrix does not request platform evidence");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_platform_ci_matrix", "release checklist missing platform CI gates");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "check_platform_ci_evidence", "release checklist missing platform evidence verification");
   Require_Contains ("docs/RELEASE_CHECKLIST.md", "summarize_release_evidence", "release checklist missing platform evidence summary");
   Require_Contains ("docs/PACKAGING.md", "check_platform_ci_matrix", "packaging docs missing platform CI gates");
   Require_Contains ("docs/PACKAGING.md", "check_platform_ci_evidence", "packaging docs missing platform evidence verification");
   Require_Contains ("docs/PACKAGING.md", "summarize_release_evidence", "packaging docs missing platform evidence summary");

   Ada.Text_IO.Put_Line ("release consistency checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when Program_Error =>
      --  Release_Checks.Fail already emitted the diagnostic and set the
      --  failure exit status before raising; exit non-zero without a traceback.
      null;
end Check_Release_Consistency;
