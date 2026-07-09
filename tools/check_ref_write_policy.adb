with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Ref_Write_Policy is
   Failed : Boolean := False;

   function Is_Ada_Source (Name : String) return Boolean is
   begin
      return Tool_Support.Ends_With (Name, ".adb")
        or else Tool_Support.Ends_With (Name, ".ads");
   end Is_Ada_Source;

   function Is_Allowed_Source (Name : String) return Boolean is
   begin
      return Name = "version-refs.adb" or else Name = "version-refs.ads";
   end Is_Allowed_Source;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "error: " & Message);
      Failed := True;
   end Fail;

   procedure Check_Source_File (Path, Name : String) is
      Text : constant String := Tool_Support.Read_File (Path);
   begin
      if Ada.Strings.Fixed.Index (Text, "Atomic_Write_Ref") /= 0
        and then not Is_Allowed_Source (Name)
      then
         Fail
           ("direct Atomic_Write_Ref use outside Version.Refs: " & Path);
      end if;
   exception
      when others =>
         Fail ("could not inspect source file: " & Path);
   end Check_Source_File;

   --  Scans the version (CLI) crate's own sources only; the library's
   --  ref-mutation code is guarded by versionlib's own check_ref_write_policy.
   procedure Scan_Directory (Dir : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Opened    : Boolean := False;
   begin
      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Dir,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => False,
            Ada.Directories.Special_File  => False]);
      Opened := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Path : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Is_Ada_Source (Name) then
               Check_Source_File (Path, Name);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Opened then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Scan_Directory;

begin
   --  Only scans the version (CLI) crate's own sources; versionlib's ref-write
   --  policy is enforced by versionlib's own check_ref_write_policy.
   Tool_Support.Require_Directory ("src", "missing source directory: src");
   Scan_Directory ("src");

   if Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("ref write policy checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Check_Ref_Write_Policy;
