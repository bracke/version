with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Ref_Write_Policy_Selftest is
   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version_ref_write_policy_selftest_ada";

   function Copy_Fixture (Name : String) return String is
      Dest : constant String := Tool_Support.Join (Tmp, Name);
   begin
      Ada.Directories.Create_Path (Dest);
      Tool_Support.Copy_Tree
        (Tool_Support.Join (Root, "src"), Tool_Support.Join (Dest, "src"));
      return Dest;
   end Copy_Fixture;

   function Policy_Status (Dir : String) return Integer is
   begin
      return Tool_Support.Run_In_Directory
        (Directory   => Dir,
         Command     => Tool_Support.Shell_Quote
           (Tool_Support.Join (Root, "tools/bin/check_ref_write_policy")),
         Quiet       => True,
         Output_File => "/tmp/version_ref_write_policy_selftest.out");
   end Policy_Status;

   procedure Expect_Pass (Dir, Label : String) is
   begin
      if Policy_Status (Dir) /= 0 then
         Tool_Support.Fail
           ("ref write policy self-test unexpectedly failed for " & Label);
      end if;
   end Expect_Pass;

   procedure Expect_Fail (Dir, Label : String) is
   begin
      if Policy_Status (Dir) = 0 then
         Tool_Support.Fail
           ("ref write policy self-test did not fail for " & Label);
      end if;
   end Expect_Fail;

begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_ref_write_policy_selftest");
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
      Fixture : constant String := Copy_Fixture ("forbidden-direct-write");
   begin
      Tool_Support.Write_File
        (Tool_Support.Join (Fixture, "src/version-policy_violation.adb"),
         "procedure Version.Policy_Violation is" & ASCII.LF &
         "begin" & ASCII.LF &
         "   Version.Refs.Atomic_Write_Ref;" & ASCII.LF &
         "end Version.Policy_Violation;" & ASCII.LF);
      Expect_Fail (Fixture, "forbidden production Atomic_Write_Ref call");
   end;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Text_IO.Put_Line ("ref write policy self-tests passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      raise;
end Check_Ref_Write_Policy_Selftest;
