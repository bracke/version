with Ada.Command_Line;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Tool_Support;

procedure Check_Platform_CI_Matrix is
   Tmp_Root : constant String := "/tmp";


   function Is_Windows_Host return Boolean is
   begin
      return GNAT.OS_Lib.Directory_Separator = Character'Val (16#5C#);
   end Is_Windows_Host;

   function Is_Posix_Host return Boolean is
   begin
      return not Is_Windows_Host;
   end Is_Posix_Host;

   procedure Run_Step (Command : String) is
   begin
      Tool_Support.Run_Checked
        (Command, "platform CI step failed: " & Command);
   end Run_Step;

   procedure Run_Step_In (Directory, Command : String) is
   begin
      Tool_Support.Run_In_Directory_Checked
        (Directory => Directory,
         Command   => Command,
         Message   =>
           "platform CI step failed: cd " & Directory & " && " & Command);
   end Run_Step_In;

   procedure Probe_Platform (Mode : String) is
      Probe : constant String := Tool_Support.Join (Tmp_Root, "version-" & Mode & "-ci-ada");
   begin
      Tool_Support.Delete_If_Exists (Tool_Support.Join (Probe, "link"));
      Tool_Support.Delete_If_Exists (Probe);
      Ada.Directories.Create_Path (Tool_Support.Join (Probe, "real"));

      if Mode = "posix" then
         Run_Step
           ("ln -s " & Tool_Support.Shell_Quote (Tool_Support.Join (Probe, "real")) &
            " " & Tool_Support.Shell_Quote (Tool_Support.Join (Probe, "link")));
         if not Ada.Directories.Exists (Tool_Support.Join (Probe, "link")) then
            Tool_Support.Fail
              ("POSIX symlink support is required for platform tests");
         end if;
      else
         Tool_Support.Write_File (Tool_Support.Join (Probe, "C_drive_policy_probe.txt"), "probe");
         if not Tool_Support.Is_File (Tool_Support.Join (Probe, "C_drive_policy_probe.txt")) then
            Tool_Support.Fail ("Windows filesystem probe failed");
         end if;
      end if;

      Tool_Support.Delete_If_Exists (Tool_Support.Join (Probe, "link"));
      Tool_Support.Delete_If_Exists (Probe);
   exception
      when others =>
         Tool_Support.Delete_If_Exists (Tool_Support.Join (Probe, "link"));
         Tool_Support.Delete_If_Exists (Probe);
         raise;
   end Probe_Platform;

   function UTC_Timestamp return String is
      Image : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Clock, Time_Zone => 0);
   begin
      return Image (Image'First .. Image'First + 9) & "T" &
        Image (Image'First + 11 .. Image'Last) & "Z";
   end UTC_Timestamp;

   procedure Write_Evidence (Mode, Source_Tree : String) is
      Dir : constant String :=
        (if Ada.Environment_Variables.Exists ("VERSION_PLATFORM_CI_EVIDENCE_DIR")
         then Ada.Environment_Variables.Value ("VERSION_PLATFORM_CI_EVIDENCE_DIR")
         else "");
      Git_Version : constant String :=
        Tool_Support.Command_Output_Trimmed ("git --version");
      Timestamp : constant String := UTC_Timestamp;
      Filesystem : constant String :=
        (if Mode = "posix" then "posix-real" else "windows-real");
   begin
      if Dir = "" then
         return;
      end if;

      Ada.Directories.Create_Path (Dir);
      Tool_Support.Write_File
        (Tool_Support.Join (Dir, "platform-" & Mode & ".txt"),
         "mode=" & Mode & ASCII.LF &
         "filesystem=" & Filesystem & ASCII.LF &
         "source_tree=" & Source_Tree & ASCII.LF &
         "timestamp_utc=" & Timestamp & ASCII.LF &
         "git=" & Git_Version & ASCII.LF &
         "alr=available" & ASCII.LF &
         "gprbuild=available" & ASCII.LF &
         "build=passed" & ASCII.LF &
         "aunit=passed" & ASCII.LF &
         "release_consistency=passed" & ASCII.LF &
         "ref_write_policy=passed" & ASCII.LF &
         "ref_transaction=passed" & ASCII.LF &
         "result=passed" & ASCII.LF);
   end Write_Evidence;

   Mode        : constant String :=
     (if Ada.Command_Line.Argument_Count = 1 then Ada.Command_Line.Argument (1) else "");
   Source_Tree : constant String :=
     (declare
        Value : constant String := Tool_Support.Command_Output_Trimmed ("git rev-parse HEAD");
      begin
        (if Value = "" then "unknown" else Value));
begin
   if Mode /= "posix" and then Mode /= "windows" then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_platform_ci_matrix posix|windows");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if Mode = "posix" and then not Is_Posix_Host then
      Tool_Support.Fail ("POSIX platform gate must run on a POSIX host");
   elsif Mode = "windows" and then not Is_Windows_Host then
      Tool_Support.Fail ("Windows platform gate must run on a native Windows host");
   end if;

   Tool_Support.Require_Command ("git");
   Tool_Support.Require_Command ("alr");

   Probe_Platform (Mode);

   Run_Step ("alr build");
   Run_Step_In ("tests", "alr exec -- gprbuild -P tests.gpr");
   if Mode = "windows" and then Tool_Support.Is_File ("./tests/bin/tests.exe") then
      Run_Step ("./tests/bin/tests.exe");
   else
      Run_Step ("./tests/bin/tests");
   end if;

   --  versionlib's functionality suite is exercised by versionlib's own
   --  platform/release tooling, not from the version crate.

   Run_Step ("./tools/bin/check_release_consistency");
   Run_Step ("./tools/bin/check_ref_write_policy");
   Run_Step ("./tools/bin/check_ref_transaction_selftest");
   if Mode = "posix" then
      Run_Step ("./tools/bin/check_release_consistency_selftest");
      Run_Step ("./tools/bin/check_ref_write_policy_selftest");
   end if;

   if Ada.Environment_Variables.Exists ("VERSION_RELEASE_ARCHIVE") then
      Run_Step
        ("./tools/bin/check_release_package " &
         Tool_Support.Shell_Quote
           (Ada.Environment_Variables.Value ("VERSION_RELEASE_ARCHIVE")));
   end if;

   Write_Evidence (Mode, Source_Tree);
   Ada.Text_IO.Put_Line (Mode & " platform CI matrix passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Check_Platform_CI_Matrix;
