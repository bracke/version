with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Release_Consistency_Selftest is
   use Ada.Strings.Unbounded;

   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version_release_consistency_selftest_ada";

   function Copy_Fixture (Name : String) return String is
      Dest : constant String := Tool_Support.Join (Tmp, Name);
   begin
      Ada.Directories.Create_Path (Dest);
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "docs"), Tool_Support.Join (Dest, "docs"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "src"), Tool_Support.Join (Dest, "src"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "tools"), Tool_Support.Join (Dest, "tools"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "ci"), Tool_Support.Join (Dest, "ci"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "README.md"), Tool_Support.Join (Dest, "README.md"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "CHANGELOG.md"), Tool_Support.Join (Dest, "CHANGELOG.md"));
      return Dest;
   end Copy_Fixture;


   procedure Append_File (Path, Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Append_File;

   procedure Rewrite_File
     (Path      : String;
      Transform : not null access procedure
        (Line : String; Output : in out Unbounded_String))
   is
      Input  : Ada.Text_IO.File_Type;
      Result : Unbounded_String;
   begin
      Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (Input) loop
         Transform (Ada.Text_IO.Get_Line (Input), Result);
      end loop;
      Ada.Text_IO.Close (Input);
      Tool_Support.Write_File (Path, To_String (Result));
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Input) then
            Ada.Text_IO.Close (Input);
         end if;
         raise;
   end Rewrite_File;

   procedure Append_Line (Output : in out Unbounded_String; Line : String) is
   begin
      Append (Output, Line);
      Append (Output, ASCII.LF);
   end Append_Line;

   procedure Delete_Lines_Containing (Path, Needle : String) is
      procedure Transform (Line : String; Output : in out Unbounded_String) is
      begin
         if Tool_Support.Index (Line, Needle) = 0 then
            Append_Line (Output, Line);
         end if;
      end Transform;
   begin
      Rewrite_File (Path, Transform'Access);
   end Delete_Lines_Containing;

   procedure Delete_Exact_Line (Path, Text : String) is
      procedure Transform (Line : String; Output : in out Unbounded_String) is
      begin
         if Line /= Text then
            Append_Line (Output, Line);
         end if;
      end Transform;
   begin
      Rewrite_File (Path, Transform'Access);
   end Delete_Exact_Line;

   function Replace_All (Text, Old, New_Value : String) return String is
      Result : Unbounded_String;
      Pos    : Natural := Text'First;
   begin
      while Pos <= Text'Last loop
         declare
            Found : constant Natural := Tool_Support.Index (Text (Pos .. Text'Last), Old);
         begin
            if Found = 0 then
               Append (Result, Text (Pos .. Text'Last));
               exit;
            end if;
            if Found > Pos then
               Append (Result, Text (Pos .. Found - 1));
            end if;
            Append (Result, New_Value);
            Pos := Found + Old'Length;
         end;
      end loop;
      return To_String (Result);
   exception
      when Constraint_Error =>
         return To_String (Result);
   end Replace_All;

   procedure Replace_In_File (Path, Old, New_Value : String) is
      procedure Transform (Line : String; Output : in out Unbounded_String) is
      begin
         Append_Line (Output, Replace_All (Line, Old, New_Value));
      end Transform;
   begin
      Rewrite_File (Path, Transform'Access);
   end Replace_In_File;

   function Consistency_Status (Dir : String) return Integer is
   begin
      return Tool_Support.Run_In_Directory
        (Directory   => Dir,
         Command     => Tool_Support.Shell_Quote
           (Tool_Support.Join (Root, "tools/bin/check_release_consistency")),
         Output_File => "/tmp/version_release_consistency_selftest.out");
   end Consistency_Status;

   procedure Expect_Fail (Dir, Label : String) is
   begin
      if Consistency_Status (Dir) = 0 then
         Tool_Support.Fail
           ("consistency self-test did not fail for " & Label);
      end if;
   end Expect_Fail;

   procedure Expect_Pass (Dir, Label : String) is
   begin
      if Consistency_Status (Dir) /= 0 then
         Tool_Support.Fail
           ("consistency self-test unexpectedly failed for " & Label);
      end if;
   end Expect_Pass;

begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_release_consistency_selftest");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Create_Path (Tmp);

   declare
      Fixture : constant String := Copy_Fixture ("base");
   begin
      Expect_Pass (Fixture, "base");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("command-drift");
   begin
      Delete_Exact_Line (Tool_Support.Join (Fixture, "docs/COMMANDS.md"), "### archive");
      Expect_Fail (Fixture, "command documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("unsupported-drift");
   begin
      Replace_In_File (Tool_Support.Join (Fixture, "docs/COMPATIBILITY.md"), "SHA-256", "SHA 256");
      Expect_Fail (Fixture, "unsupported-scope drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ci-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_platform_ci_matrix.adb"));
      Expect_Fail (Fixture, "platform CI gate drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence.adb"));
      Expect_Fail (Fixture, "platform CI evidence gate drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-selftest-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence_selftest.adb"));
      Expect_Fail (Fixture, "platform CI evidence self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-doc-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/CI.md"), "check_platform_ci_evidence");
      Expect_Fail (Fixture, "platform CI evidence documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-summary-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/summarize_release_evidence.adb"));
      Expect_Fail (Fixture, "platform CI evidence summary helper drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-summary-doc-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/CI.md"), "summarize_release_evidence");
      Expect_Fail (Fixture, "platform CI evidence summary documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-matrix-drift");
      Path    : constant String := Tool_Support.Join (Fixture, "ci/github-actions-platform-matrix.yml");
   begin
      Delete_Lines_Containing (Path, "check_platform_ci_evidence");
      Delete_Lines_Containing (Path, "VERSION_PLATFORM_CI_EVIDENCE_DIR");
      Expect_Fail (Fixture, "platform CI evidence matrix drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-evidence-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_matrix.adb"),
         "ref_transaction");
      Expect_Fail (Fixture, "platform ref transaction evidence marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-run-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_matrix.adb"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "platform ref transaction self-test run drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-checker-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence.adb"),
         "ref_transaction");
      Expect_Fail (Fixture, "platform ref transaction evidence checker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-summary-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/summarize_release_evidence.adb"),
         "ref_transaction");
      Expect_Fail (Fixture, "platform ref transaction evidence summary drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-selftest-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence_selftest.adb"),
         "ref_transaction");
      Expect_Fail (Fixture, "platform ref transaction evidence self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-testing-doc-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/TESTING.md"),
         "ref_transaction=passed");
      Expect_Fail (Fixture, "testing ref transaction evidence marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-ref-transaction-checklist-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"),
         "ref_transaction=passed");
      Expect_Fail (Fixture, "release checklist ref transaction evidence marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("package-selftest-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_release_package_selftest.adb"));
      Expect_Fail (Fixture, "release package self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-ready-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_release_ready.adb"));
      Expect_Fail (Fixture, "Ada release preflight drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-checklist-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "check_release_package_selftest");
      Expect_Fail (Fixture, "release checklist package self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-ready-checklist-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "check_release_ready");
      Expect_Fail (Fixture, "release checklist Ada preflight drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("packaging-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "check_release_package_selftest");
      Expect_Fail (Fixture, "packaging package self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("stale-shell-tool-packaging-drift");
   begin
      Append_File
        (Tool_Support.Join (Fixture, "docs/PACKAGING.md"),
         ASCII.LF & "Stale gate example: tools/check_release_package.sh" & ASCII.LF);
      Expect_Fail (Fixture, "stale shell tool reference drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-ready-packaging-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "check_release_ready");
      Expect_Fail (Fixture, "packaging Ada preflight drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-ready-testing-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/TESTING.md"), "check_release_ready");
      Expect_Fail (Fixture, "testing Ada preflight drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("test-scope-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_test_scope_completeness.adb"));
      Expect_Fail (Fixture, "test-scope completeness gate drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("test-scope-testing-doc-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/TESTING.md"), "check_test_scope_completeness");
      Expect_Fail (Fixture, "test-scope completeness testing documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("test-scope-release-checklist-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "check_test_scope_completeness");
      Expect_Fail (Fixture, "release checklist test-scope completeness drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("test-scope-packaging-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "check_test_scope_completeness");
      Expect_Fail (Fixture, "packaging test-scope completeness drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-write-policy-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_ref_write_policy.adb"));
      Expect_Fail (Fixture, "ref write policy gate drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-write-policy-selftest-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_ref_write_policy_selftest.adb"));
      Expect_Fail (Fixture, "ref write policy self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-selftest-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_ref_transaction_selftest.adb"));
      Expect_Fail (Fixture, "ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-selftest-testing-doc-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/TESTING.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "ref transaction self-test testing documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-selftest-release-checklist-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "release checklist ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-selftest-packaging-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/PACKAGING.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "packaging ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-release-notes-selftest-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_NOTES.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "release notes ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-release-notes-marker-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_NOTES.md"),
         "ref_transaction=passed");
      Expect_Fail (Fixture, "release notes ref transaction marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-changelog-selftest-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "CHANGELOG.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "changelog ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-changelog-marker-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "CHANGELOG.md"),
         "ref_transaction=passed");
      Expect_Fail (Fixture, "changelog ref transaction marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-docs-changelog-selftest-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/CHANGELOG.md"),
         "check_ref_transaction_selftest");
      Expect_Fail (Fixture, "docs changelog ref transaction self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-transaction-docs-changelog-marker-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/CHANGELOG.md"),
         "ref_transaction=passed");
      Expect_Fail (Fixture, "docs changelog ref transaction marker drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-selftest-testing-doc-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/TESTING.md"),
         "check_platform_ci_evidence_selftest");
      Expect_Fail (Fixture, "platform evidence self-test testing documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-selftest-release-checklist-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"),
         "check_platform_ci_evidence_selftest");
      Expect_Fail (Fixture, "release checklist platform evidence self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("platform-evidence-selftest-packaging-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/PACKAGING.md"),
         "check_platform_ci_evidence_selftest");
      Expect_Fail (Fixture, "packaging platform evidence self-test drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-write-policy-testing-doc-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/TESTING.md"),
         "check_ref_write_policy");
      Expect_Fail (Fixture, "ref write policy testing documentation drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-write-policy-release-checklist-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"),
         "check_ref_write_policy");
      Expect_Fail (Fixture, "release checklist ref write policy drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("ref-write-policy-packaging-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "docs/PACKAGING.md"),
         "check_ref_write_policy");
      Expect_Fail (Fixture, "packaging ref write policy drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("stale-source-path-drift");
   begin
      Append_File
        (Tool_Support.Join (Fixture, "tools/check_test_scope_completeness.adb"),
         ASCII.LF & "# stale flat-layout path fixture: src/core/version.ads" & ASCII.LF);
      Expect_Fail (Fixture, "stale source path drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-checklist-platform-evidence-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "check_platform_ci_evidence");
      Expect_Fail (Fixture, "release checklist platform evidence drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("packaging-platform-evidence-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "check_platform_ci_evidence");
      Expect_Fail (Fixture, "packaging platform evidence drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-checklist-platform-summary-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "summarize_release_evidence");
      Expect_Fail (Fixture, "release checklist platform evidence summary drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("packaging-platform-summary-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "summarize_release_evidence");
      Expect_Fail (Fixture, "packaging platform evidence summary drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-drift");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_documentation_coherence.adb"));
      Expect_Fail (Fixture, "documentation coherence gate drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("tool-doc-guards-spec-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/tool_doc_guards.ads"));
      Expect_Fail (Fixture, "tool doc guards spec drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("tool-doc-guards-body-drift");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/tool_doc_guards.adb"));
      Expect_Fail (Fixture, "tool doc guards body drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-doc-guard-usage-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_documentation_coherence.adb"),
         "Tool_Doc_Guards");
      Expect_Fail (Fixture, "documentation coherence shared doc guard usage drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("release-consistency-doc-guard-usage-drift");
   begin
      Delete_Lines_Containing
        (Tool_Support.Join (Fixture, "tools/check_release_consistency.adb"),
         "Tool_Doc_Guards");
      Expect_Fail (Fixture, "release consistency shared doc guard usage drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-notes-drift");
   begin
      Tool_Support.Write_File
        (Tool_Support.Join (Fixture, "docs/RELEASE_NOTES.md"),
         "- stray release note before heading" & ASCII.LF &
         Tool_Support.Read_File (Tool_Support.Join (Fixture, "docs/RELEASE_NOTES.md")));
      Expect_Fail (Fixture, "release-notes documentation coherence drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-checklist-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"), "check_documentation_coherence");
      Expect_Fail (Fixture, "release checklist documentation coherence drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-packaging-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/PACKAGING.md"), "check_documentation_coherence");
      Expect_Fail (Fixture, "packaging documentation coherence drift");
   end;

   declare
      Fixture : constant String := Copy_Fixture ("documentation-coherence-testing-drift");
   begin
      Delete_Lines_Containing (Tool_Support.Join (Fixture, "docs/TESTING.md"), "check_documentation_coherence");
      Expect_Fail (Fixture, "testing documentation coherence drift");
   end;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Text_IO.Put_Line ("release consistency self-tests passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      raise;
end Check_Release_Consistency_Selftest;
