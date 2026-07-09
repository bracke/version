with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Platform_CI_Evidence_Selftest is
   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version_platform_ci_evidence_selftest_ada";

   function Evidence_Text
     (Mode            : String;
      Filesystem      : String;
      Ref_Write_Policy : String := "passed";
      Ref_Transaction : String := "passed") return String
   is
   begin
      return
        "mode=" & Mode & ASCII.LF &
        "filesystem=" & Filesystem & ASCII.LF &
        "source_tree=selftest-tree" & ASCII.LF &
        "timestamp_utc=2026-06-08T00:00:00Z" & ASCII.LF &
        "result=passed" & ASCII.LF &
        "build=passed" & ASCII.LF &
        "aunit=passed" & ASCII.LF &
        "release_consistency=passed" & ASCII.LF &
        (if Ref_Write_Policy = "" then ""
         else "ref_write_policy=" & Ref_Write_Policy & ASCII.LF) &
        (if Ref_Transaction = "" then ""
         else "ref_transaction=" & Ref_Transaction & ASCII.LF);
   end Evidence_Text;

   function Make_Fixture
     (Name                     : String;
      Posix_Ref_Write_Policy   : String := "passed";
      Windows_Ref_Write_Policy : String := "passed";
      Posix_Ref_Transaction    : String := "passed";
      Windows_Ref_Transaction  : String := "passed") return String
   is
      Dir : constant String := Tool_Support.Join (Tmp, Name);
   begin
      Tool_Support.Delete_If_Exists (Dir);
      Ada.Directories.Create_Path (Dir);
      Tool_Support.Write_File
        (Tool_Support.Join (Dir, "platform-posix.txt"),
         Evidence_Text
           ("posix", "posix-real", Posix_Ref_Write_Policy, Posix_Ref_Transaction));
      Tool_Support.Write_File
        (Tool_Support.Join (Dir, "platform-windows.txt"),
         Evidence_Text
           ("windows", "windows-real",
            Windows_Ref_Write_Policy, Windows_Ref_Transaction));
      return Dir;
   end Make_Fixture;

   function Checker_Status (Dir : String) return Integer is
   begin
      return Tool_Support.Run_In_Directory
        (Directory   => Root,
         Command     => Tool_Support.Shell_Quote
           (Tool_Support.Join (Root, "tools/bin/check_platform_ci_evidence")) &
           " " & Tool_Support.Shell_Quote (Dir),
         Quiet       => True,
         Output_File => "/tmp/version_platform_ci_evidence_selftest_checker.out");
   end Checker_Status;

   function Summary_Status (Dir : String) return Integer is
   begin
      return Tool_Support.Run_In_Directory
        (Directory   => Root,
         Command     => Tool_Support.Shell_Quote
           (Tool_Support.Join (Root, "tools/bin/summarize_release_evidence")) &
           " " & Tool_Support.Shell_Quote (Dir),
         Quiet       => True,
         Output_File => "/tmp/version_platform_ci_evidence_selftest_summary.out");
   end Summary_Status;

   procedure Expect_Pass (Dir, Label : String) is
   begin
      if Checker_Status (Dir) /= 0 then
         Tool_Support.Fail
           ("platform CI evidence checker unexpectedly failed for " & Label);
      end if;
      if Summary_Status (Dir) /= 0 then
         Tool_Support.Fail
           ("release evidence summarizer unexpectedly failed for " & Label);
      end if;
   end Expect_Pass;

   procedure Expect_Fail (Dir, Label : String) is
   begin
      if Checker_Status (Dir) = 0 then
         Tool_Support.Fail
           ("platform CI evidence checker did not fail for " & Label);
      end if;
      if Summary_Status (Dir) = 0 then
         Tool_Support.Fail
           ("release evidence summarizer did not fail for " & Label);
      end if;
   end Expect_Fail;

begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_platform_ci_evidence_selftest");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Create_Path (Tmp);

   Expect_Pass (Make_Fixture ("good"), "complete platform evidence");
   Expect_Fail
     (Make_Fixture ("missing-posix-ref-write-policy", Posix_Ref_Write_Policy => ""),
      "missing POSIX ref_write_policy evidence");
   Expect_Fail
     (Make_Fixture ("missing-windows-ref-write-policy", Windows_Ref_Write_Policy => ""),
      "missing Windows ref_write_policy evidence");
   Expect_Fail
     (Make_Fixture ("bad-posix-ref-write-policy", Posix_Ref_Write_Policy => "failed"),
      "bad POSIX ref_write_policy evidence");
   Expect_Fail
     (Make_Fixture ("bad-windows-ref-write-policy", Windows_Ref_Write_Policy => "not-run"),
      "bad Windows ref_write_policy evidence");
   Expect_Fail
     (Make_Fixture
        ("missing-posix-ref-transaction", Posix_Ref_Transaction => ""),
      "missing POSIX ref_transaction evidence");
   Expect_Fail
     (Make_Fixture
        ("missing-windows-ref-transaction", Windows_Ref_Transaction => ""),
      "missing Windows ref_transaction evidence");
   Expect_Fail
     (Make_Fixture
        ("bad-posix-ref-transaction", Posix_Ref_Transaction => "failed"),
      "bad POSIX ref_transaction evidence");
   Expect_Fail
     (Make_Fixture
        ("bad-windows-ref-transaction", Windows_Ref_Transaction => "not-run"),
      "bad Windows ref_transaction evidence");

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Text_IO.Put_Line ("platform CI evidence self-tests passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      raise;
end Check_Platform_CI_Evidence_Selftest;
