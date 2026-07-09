with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Platform_CI_Evidence is
   use Ada.Strings.Unbounded;
   procedure Require_Line (Path, Text : String) is
   begin
      if not Tool_Support.Has_Line (Path, Text) then
         Tool_Support.Fail (Path & " missing evidence line: " & Text);
      end if;
   end Require_Line;

   procedure Require_Key (Path, Key : String) is
   begin
      if Tool_Support.Value_Of (Path, Key) = "" then
         Tool_Support.Fail (Path & " missing evidence key: " & Key);
      end if;
   end Require_Key;

   Dir          : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Posix        : Unbounded_String;
   Windows      : Unbounded_String;
   Posix_Tree   : Unbounded_String;
   Windows_Tree : Unbounded_String;
begin
   if Dir = "" then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_platform_ci_evidence EVIDENCE_DIR");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Require_Directory
     (Dir, "platform CI evidence directory does not exist: " & Dir);

   Posix := To_Unbounded_String (Tool_Support.Find_File (Dir, "platform-posix.txt"));
   Windows := To_Unbounded_String (Tool_Support.Find_File (Dir, "platform-windows.txt"));

   if Length (Posix) = 0 then
      Tool_Support.Fail
        ("missing POSIX platform CI evidence file platform-posix.txt");
   end if;
   if Length (Windows) = 0 then
      Tool_Support.Fail
        ("missing Windows platform CI evidence file platform-windows.txt");
   end if;

   Require_Key (To_String (Posix), "source_tree");
   Require_Key (To_String (Posix), "timestamp_utc");
   Require_Line (To_String (Posix), "result=passed");
   Require_Line (To_String (Posix), "build=passed");
   Require_Line (To_String (Posix), "aunit=passed");
   Require_Line (To_String (Posix), "release_consistency=passed");
   Require_Line (To_String (Posix), "ref_write_policy=passed");
   Require_Line (To_String (Posix), "ref_transaction=passed");
   if Tool_Support.Contains_Bad_Marker (To_String (Posix)) then
      Tool_Support.Fail
        (To_String (Posix) & " contains skipped/not-run/failed marker");
   end if;

   Require_Key (To_String (Windows), "source_tree");
   Require_Key (To_String (Windows), "timestamp_utc");
   Require_Line (To_String (Windows), "result=passed");
   Require_Line (To_String (Windows), "build=passed");
   Require_Line (To_String (Windows), "aunit=passed");
   Require_Line (To_String (Windows), "release_consistency=passed");
   Require_Line (To_String (Windows), "ref_write_policy=passed");
   Require_Line (To_String (Windows), "ref_transaction=passed");
   if Tool_Support.Contains_Bad_Marker (To_String (Windows)) then
      Tool_Support.Fail
        (To_String (Windows) & " contains skipped/not-run/failed marker");
   end if;

   Require_Line (To_String (Posix), "mode=posix");
   Require_Line (To_String (Posix), "filesystem=posix-real");
   Require_Line (To_String (Windows), "mode=windows");
   Require_Line (To_String (Windows), "filesystem=windows-real");

   Posix_Tree := To_Unbounded_String (Tool_Support.Value_Of (To_String (Posix), "source_tree"));
   Windows_Tree := To_Unbounded_String (Tool_Support.Value_Of (To_String (Windows), "source_tree"));

   if Length (Posix_Tree) = 0 then
      Tool_Support.Fail ("POSIX evidence has empty source_tree");
   end if;

   if To_String (Posix_Tree) /= To_String (Windows_Tree) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: POSIX and Windows evidence were not produced from the same source tree");
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "posix:   " & To_String (Posix_Tree));
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "windows: " & To_String (Windows_Tree));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Text_IO.Put_Line ("platform CI evidence checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Check_Platform_CI_Evidence;
