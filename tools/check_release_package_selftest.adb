with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Release_Package_Selftest is
   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version_release_package_selftest_ada";

   procedure Strip_Local_Pins (Path : String) is
      Input  : Ada.Text_IO.File_Type;
      Output : Ada.Text_IO.File_Type;
      Tmp_In : constant String := Path & ".native-selftest.tmp";
      Skip   : Boolean := False;
   begin
      Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Path);
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Tmp_In);
      while not Ada.Text_IO.End_Of_File (Input) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (Input);
         begin
            if Skip then
               Skip := False;
            elsif Line = "[[pins]]" then
               Skip := True;
            else
               Ada.Text_IO.Put_Line (Output, Line);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (Input);
      Ada.Text_IO.Close (Output);
      Ada.Directories.Delete_File (Path);
      Ada.Directories.Rename (Tmp_In, Path);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Input) then
            Ada.Text_IO.Close (Input);
         end if;
         if Ada.Text_IO.Is_Open (Output) then
            Ada.Text_IO.Close (Output);
         end if;
         raise;
   end Strip_Local_Pins;

   function Make_Fixture (Name : String) return String is
      Fixture : constant String := Tool_Support.Join (Tool_Support.Join (Tmp, Name), "version");
   begin
      Ada.Directories.Create_Path (Fixture);

      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "src"), Tool_Support.Join (Fixture, "src"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "tests"), Tool_Support.Join (Fixture, "tests"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "docs"), Tool_Support.Join (Fixture, "docs"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "examples"), Tool_Support.Join (Fixture, "examples"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "tools"), Tool_Support.Join (Fixture, "tools"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "config"), Tool_Support.Join (Fixture, "config"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "ci"), Tool_Support.Join (Fixture, "ci"));
      Tool_Support.Copy_Tree (Tool_Support.Join (Root, "LICENSES"), Tool_Support.Join (Fixture, "LICENSES"));

      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "alire.toml"), Tool_Support.Join (Fixture, "alire.toml"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "version.gpr"), Tool_Support.Join (Fixture, "version.gpr"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "README.md"), Tool_Support.Join (Fixture, "README.md"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "CHANGELOG.md"), Tool_Support.Join (Fixture, "CHANGELOG.md"));
      Tool_Support.Copy_File_To (Tool_Support.Join (Root, "LICENSE"), Tool_Support.Join (Fixture, "LICENSE"));

      Strip_Local_Pins (Tool_Support.Join (Fixture, "alire.toml"));

      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "bin"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "obj"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "share"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tests/bin"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tests/obj"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tests/share"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tests/alire"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tools/bin"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tools/obj"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tools/share"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "tools/tmp"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "examples/bin"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "examples/obj"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "examples/share"));
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Fixture, "examples/alire"));

      return Fixture;
   end Make_Fixture;

   procedure Pack_Fixture (Fixture, Archive : String) is
      Parent  : constant String := Tool_Support.Dirname (Fixture);
      Base    : constant String := Tool_Support.Basename (Fixture);
      Command : constant String :=
        "zip -qr " & Tool_Support.Shell_Quote (Archive) & " " &
        Tool_Support.Shell_Quote (Base);
   begin
      Tool_Support.Run_In_Directory_Checked
        (Directory => Parent,
         Command   => Command,
         Message   => "could not create fixture archive: " & Archive);
   end Pack_Fixture;

   function Package_Check_Status (Archive : String) return Integer is
   begin
      return Tool_Support.Run_In_Directory
        (Directory   => Root,
         Command     =>
           "./tools/bin/check_release_package " &
           Tool_Support.Shell_Quote (Archive),
         Output_File => "/tmp/version_release_package_selftest.out");
   end Package_Check_Status;

   procedure Expect_Package_Fail (Fixture, Label : String) is
      Archive : constant String := Tool_Support.Join (Tmp, Label & ".zip");
   begin
      Pack_Fixture (Fixture, Archive);
      if Package_Check_Status (Archive) = 0 then
         Tool_Support.Fail ("package self-test did not fail for " & Label);
      end if;
   end Expect_Package_Fail;

   procedure Expect_Clean_Package (Fixture, Archive : String) is
   begin
      Pack_Fixture (Fixture, Archive);
      if Package_Check_Status (Archive) /= 0 then
         Tool_Support.Fail ("package self-test clean fixture failed");
      end if;
   end Expect_Clean_Package;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: check_release_package_selftest");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Create_Path (Tmp);

   declare
      Fixture : constant String := Make_Fixture ("clean");
   begin
      Expect_Clean_Package (Fixture, Tool_Support.Join (Tmp, "clean.zip"));
   end;

   declare
      Fixture : constant String := Make_Fixture ("obj-artifact");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "obj/build.log"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "obj-artifact");
   end;

   declare
      Fixture : constant String := Make_Fixture ("bin-artifact");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "bin/version"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "bin-artifact");
   end;

   declare
      Fixture : constant String := Make_Fixture ("ali-artifact");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "src/version.ali"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "ali-artifact");
   end;

   declare
      Fixture : constant String := Make_Fixture ("o-artifact");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "src/version.o"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "o-artifact");
   end;

   declare
      Fixture : constant String := Make_Fixture ("nested-zip");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "docs/generated.zip"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "nested-zip");
   end;

   declare
      Fixture : constant String := Make_Fixture ("nested-tar");
   begin
      Tool_Support.Write_File (Tool_Support.Join (Fixture, "docs/generated.tar"), "artifact" & ASCII.LF);
      Expect_Package_Fail (Fixture, "nested-tar");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-readme");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "README.md"));
      Expect_Package_Fail (Fixture, "missing-readme");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-changelog");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "CHANGELOG.md"));
      Expect_Package_Fail (Fixture, "missing-changelog");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-release-notes");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "docs/RELEASE_NOTES.md"));
      Expect_Package_Fail (Fixture, "missing-release-notes");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-release-checklist");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "docs/RELEASE_CHECKLIST.md"));
      Expect_Package_Fail (Fixture, "missing-release-checklist");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-consistency");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_release_consistency.adb"));
      Expect_Package_Fail (Fixture, "missing-consistency");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-test-scope-gate");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_test_scope_completeness.adb"));
      Expect_Package_Fail (Fixture, "missing-test-scope-gate");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-release-ready");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_release_ready.adb"));
      Expect_Package_Fail (Fixture, "missing-release-ready");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-ref-write-policy");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_ref_write_policy.adb"));
      Expect_Package_Fail (Fixture, "missing-ref-write-policy");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-ref-write-policy-selftest");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_ref_write_policy_selftest.adb"));
      Expect_Package_Fail (Fixture, "missing-ref-write-policy-selftest");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-ref-transaction-selftest");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_ref_transaction_selftest.adb"));
      Expect_Package_Fail (Fixture, "missing-ref-transaction-selftest");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-posix-gate");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_platform_ci_matrix.adb"));
      Expect_Package_Fail (Fixture, "missing-posix-gate");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-windows-gate");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_platform_ci_matrix.adb"));
      Expect_Package_Fail (Fixture, "missing-windows-gate");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-evidence-gate");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence.adb"));
      Expect_Package_Fail (Fixture, "missing-evidence-gate");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-evidence-selftest");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/check_platform_ci_evidence_selftest.adb"));
      Expect_Package_Fail (Fixture, "missing-evidence-selftest");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-doc-coherence-gate");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/check_documentation_coherence.adb"));
      Expect_Package_Fail (Fixture, "missing-doc-coherence-gate");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-tool-doc-guards-spec");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/tool_doc_guards.ads"));
      Expect_Package_Fail (Fixture, "missing-tool-doc-guards-spec");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-tool-doc-guards-body");
   begin
      Tool_Support.Delete_File_If_Exists
        (Tool_Support.Join (Fixture, "tools/tool_doc_guards.adb"));
      Expect_Package_Fail (Fixture, "missing-tool-doc-guards-body");
   end;

   declare
      Fixture : constant String := Make_Fixture ("missing-evidence-summary");
   begin
      Tool_Support.Delete_File_If_Exists (Tool_Support.Join (Fixture, "tools/summarize_release_evidence.adb"));
      Expect_Package_Fail (Fixture, "missing-evidence-summary");
   end;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Text_IO.Put_Line ("release package self-tests passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      raise;
end Check_Release_Package_Selftest;
