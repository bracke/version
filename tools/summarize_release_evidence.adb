with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Tool_Support;

procedure Summarize_Release_Evidence is
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

   procedure Validate_Common (Path : String) is
   begin
      Require_Key (Path, "source_tree");
      Require_Key (Path, "timestamp_utc");
      Require_Line (Path, "result=passed");
      Require_Line (Path, "build=passed");
      Require_Line (Path, "aunit=passed");
      Require_Line (Path, "release_consistency=passed");
      Require_Line (Path, "ref_write_policy=passed");
      Require_Line (Path, "ref_transaction=passed");
      if Tool_Support.Contains_Bad_Marker (Path) then
         Tool_Support.Fail (Path & " contains skipped/not-run/failed marker");
      end if;
   end Validate_Common;

   procedure Validate (Dir, Posix, Windows : String) is
      pragma Unreferenced (Dir);
      Posix_Tree   : constant String := Tool_Support.Value_Of (Posix, "source_tree");
      Windows_Tree : constant String := Tool_Support.Value_Of (Windows, "source_tree");
   begin
      Validate_Common (Posix);
      Validate_Common (Windows);
      Require_Line (Posix, "mode=posix");
      Require_Line (Posix, "filesystem=posix-real");
      Require_Line (Windows, "mode=windows");
      Require_Line (Windows, "filesystem=windows-real");

      if Posix_Tree = "" then
         Tool_Support.Fail ("POSIX evidence has empty source_tree");
      elsif Posix_Tree /= Windows_Tree then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "error: POSIX and Windows evidence were not produced from the same source tree");
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "posix:   " & Posix_Tree);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "windows: " & Windows_Tree);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         Tool_Support.Fail ("platform evidence source tree mismatch");
      end if;
   end Validate;

   procedure Put_Platform_Summary (Label, Path : String) is
   begin
      Ada.Text_IO.Put_Line
        (Label & ": passed; filesystem=" & Tool_Support.Value_Of (Path, "filesystem") &
         "; build=" & Tool_Support.Value_Of (Path, "build") &
         "; aunit=" & Tool_Support.Value_Of (Path, "aunit") &
         "; release_consistency=" & Tool_Support.Value_Of (Path, "release_consistency") &
         "; ref_write_policy=" & Tool_Support.Value_Of (Path, "ref_write_policy") &
         "; ref_transaction=" & Tool_Support.Value_Of (Path, "ref_transaction") &
         "; timestamp_utc=" & Tool_Support.Value_Of (Path, "timestamp_utc"));
   end Put_Platform_Summary;

   Dir     : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Posix   : Unbounded_String;
   Windows : Unbounded_String;
begin
   if Dir = "" then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: summarize_release_evidence EVIDENCE_DIR");
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

   Validate (Dir, To_String (Posix), To_String (Windows));

   Ada.Text_IO.Put_Line ("Release platform evidence summary");
   Ada.Text_IO.Put_Line
     ("source_tree: " & Tool_Support.Value_Of (To_String (Posix), "source_tree"));
   Put_Platform_Summary ("posix", To_String (Posix));
   Put_Platform_Summary ("windows", To_String (Windows));
   Ada.Text_IO.Put_Line ("status: verified");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Summarize_Release_Evidence;
