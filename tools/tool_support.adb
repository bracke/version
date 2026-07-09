with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Files;
with Project_Tools.Text;
with Project_Tools.Processes;

package body Tool_Support is

   --  File-system, text, and shell helpers delegate to the shared project_tools
   --  crate so the whole workspace uses one implementation. Behaviour-specific
   --  helpers (Fail's OS_Exit policy, Read_File, Write_File's auto-mkdir, the
   --  Copy_Tree fail-on-existing semantics) stay local on purpose.
   function Exists (Path : String) return Boolean is
   begin
      return Project_Tools.Files.Exists (Path);
   end Exists;

   function Is_File (Path : String) return Boolean is
   begin
      return Project_Tools.Files.File_Exists (Path);
   end Is_File;

   function Is_Directory (Path : String) return Boolean is
   begin
      return Project_Tools.Files.Directory_Exists (Path);
   end Is_Directory;

   function Join (Left, Right : String) return String is
   begin
      return Project_Tools.Files.Join (Left, Right);
   end Join;

   function Dirname (Path : String) return String is
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            if I = Path'First then
               return "/";
            end if;
            return Path (Path'First .. I - 1);
         end if;
      end loop;
      return ".";
   end Dirname;

   function Basename (Path : String) return String is
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            return Path (I + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Basename;

   procedure Delete_If_Exists (Path : String) is
      use type Ada.Directories.File_Kind;
   begin
      if GNAT.OS_Lib.Is_Symbolic_Link (Path) then
         Ada.Directories.Delete_File (Path);
      elsif Ada.Directories.Exists (Path) then
         case Ada.Directories.Kind (Path) is
            when Ada.Directories.Directory =>
               Ada.Directories.Delete_Tree (Path);
            when Ada.Directories.Ordinary_File =>
               Ada.Directories.Delete_File (Path);
            when others =>
               null;
         end case;
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Delete_File_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_File_If_Exists;

   procedure Write_File (Path, Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path (Dirname (Path));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_File;

   procedure Copy_File_To (Source, Dest : String) is
   begin
      Ada.Directories.Create_Path (Dirname (Dest));
      Ada.Directories.Copy_File (Source, Dest);
   end Copy_File_To;

   procedure Copy_Tree (Source, Dest : String) is
      use type Ada.Directories.File_Kind;
      Search : Ada.Directories.Search_Type;
   begin
      Ada.Directories.Create_Path (Dest);
      Ada.Directories.Start_Search
        (Search,
         Source,
         "",
         [Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          others                        => False]);

      while Ada.Directories.More_Entries (Search) loop
         declare
            Item : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Simple : constant String := Ada.Directories.Simple_Name (Item);
               From   : constant String := Join (Source, Simple);
               To     : constant String := Join (Dest, Simple);
            begin
               if Simple /= "." and then Simple /= ".." then
                  case Ada.Directories.Kind (Item) is
                     when Ada.Directories.Directory =>
                        Copy_Tree (From, To);
                     when Ada.Directories.Ordinary_File =>
                        Ada.Directories.Copy_File (From, To);
                     when others =>
                        null;
                  end case;
               end if;
            end;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Ada.Directories.More_Entries (Search) then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Copy_Tree;

   function Read_File (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Result : US.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         US.Append (Result, Ada.Text_IO.Get_Line (File));
         US.Append (Result, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return US.To_String (Result);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Read_File;

   function First_Line (Path : String) return String is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return "";
      end if;
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
      begin
         Ada.Text_IO.Close (File);
         return Line;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end First_Line;

   function Second_Nonblank_Line (Path : String) return String is
      File : Ada.Text_IO.File_Type;
      Seen : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Line'Length > 0 then
               Seen := Seen + 1;
               if Seen = 2 then
                  Ada.Text_IO.Close (File);
                  return Line;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Second_Nonblank_Line;

   function Index (Text, Needle : String) return Natural is
   begin
      return Project_Tools.Text.Index (Text, Needle);
   end Index;

   function Starts_With (Value, Prefix : String) return Boolean is
   begin
      return Project_Tools.Text.Starts_With (Value, Prefix);
   end Starts_With;

   function Ends_With (Value, Suffix : String) return Boolean is
   begin
      return Project_Tools.Text.Ends_With (Value, Suffix);
   end Ends_With;

   function Contains (Path : String; Needle : String) return Boolean is
   begin
      return Project_Tools.Files.File_Contains (Path, Needle);
   end Contains;

   function Has_Line (Path, Text : String) return Boolean is
   begin
      return Project_Tools.Files.Has_Line (Path, Text);
   end Has_Line;

   function Value_Of (Path, Key : String) return String is
   begin
      return Project_Tools.Files.Value_Of (Path, Key);
   end Value_Of;

   function Lower (Text : String) return String is
      Result : String := Text;
   begin
      for Ch of Result loop
         if Ch in 'A' .. 'Z' then
            Ch := Character'Val
              (Character'Pos (Ch) - Character'Pos ('A') + Character'Pos ('a'));
         end if;
      end loop;
      return Result;
   end Lower;

   function Contains_Case_Insensitive (Path, Needle : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index
        (Lower (Read_File (Path)), Lower (Needle)) /= 0;
   end Contains_Case_Insensitive;

   function Contains_Bad_Marker (Path : String) return Boolean is
      Text : constant String := Lower (Read_File (Path));
   begin
      return Ada.Strings.Fixed.Index (Text, "skip") /= 0
        or else Ada.Strings.Fixed.Index (Text, "skipped") /= 0
        or else Ada.Strings.Fixed.Index (Text, "not run") /= 0
        or else Ada.Strings.Fixed.Index (Text, "failed") /= 0;
   end Contains_Bad_Marker;

   function Find_File (Directory, Name : String) return String is
   begin
      return Project_Tools.Files.Find_File (Directory, Name);
   end Find_File;

   function Shell_Quote (Value : String) return String is
   begin
      return Project_Tools.Processes.Shell_Quote (Value);
   end Shell_Quote;

   function Run (Command : String) return Integer is
   begin
      return Project_Tools.Processes.Run_Shell (Command);
   end Run;

   function Run_Program (Program : String) return Integer is
      Args : GNAT.OS_Lib.Argument_List (1 .. 0);
   begin
      return GNAT.OS_Lib.Spawn (Program_Name => Program, Args => Args);
   exception
      when others =>
         return 1;
   end Run_Program;

   procedure Restore_Path (Had_Path : Boolean; Old_Path : String) is
   begin
      if Had_Path then
         Ada.Environment_Variables.Set ("PATH", Old_Path);
      else
         Ada.Environment_Variables.Clear ("PATH");
      end if;
   end Restore_Path;

   function Run_Program_With_Path_Prefix
     (Program     : String;
      Path_Prefix : String) return Integer
   is
      Old_Path : constant String :=
        Ada.Environment_Variables.Value ("PATH", "");
      Had_Path : constant Boolean :=
        Ada.Environment_Variables.Exists ("PATH");
      Status   : Integer;
   begin
      Ada.Environment_Variables.Set
        ("PATH",
         (if Had_Path and then Old_Path'Length > 0
          then Path_Prefix & ":" & Old_Path
          else Path_Prefix));
      Status := Run_Program (Program);
      Restore_Path (Had_Path, Old_Path);
      return Status;
   exception
      when others =>
         Restore_Path (Had_Path, Old_Path);
         return 1;
   end Run_Program_With_Path_Prefix;

   function Run_In_Directory
     (Directory   : String;
      Command     : String;
      Quiet       : Boolean := False;
      Output_File : String := "") return Integer
   is
   begin
      return Project_Tools.Processes.Run_Shell_In_Directory
        (Directory, Command, Quiet, Output_File);
   end Run_In_Directory;

   procedure Run_In_Directory_Checked
     (Directory : String;
      Command   : String;
      Message   : String;
      Quiet     : Boolean := False)
   is
      Status : constant Integer :=
        Run_In_Directory
          (Directory => Directory, Command => Command, Quiet => Quiet);
   begin
      if Status /= 0 then
         Fail (Message);
      end if;
   end Run_In_Directory_Checked;

   procedure Run_Checked (Command : String; Message : String) is
      Status : constant Integer := Run (Command);
   begin
      if Status /= 0 then
         Fail (Message);
      end if;
   end Run_Checked;

   function Command_Output (Command : String) return String is
   begin
      return Project_Tools.Processes.Shell_Output (Command);
   end Command_Output;

   function Command_Output_Trimmed (Command : String) return String is
   begin
      return Project_Tools.Processes.Shell_Output_Trimmed (Command);
   end Command_Output_Trimmed;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "error: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      GNAT.OS_Lib.OS_Exit (1);
   end Fail;

   procedure Require_File (Path : String; Message : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path) then
         Fail (Message);
      end if;
   end Require_File;

   procedure Require_File (Path : String) is
   begin
      Require_File (Path, "missing required file: " & Path);
   end Require_File;

   procedure Require_Directory (Path : String; Message : String) is
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         Fail (Message);
      end if;
   end Require_Directory;

   procedure Require_Contains
     (Path    : String;
      Needle  : String;
      Message : String)
   is
   begin
      if not Contains (Path, Needle) then
         Fail (Message);
      end if;
   end Require_Contains;

   procedure Require_Command (Command : String) is
   begin
      if Run ("command -v " & Shell_Quote (Command) & " >/dev/null 2>&1") /= 0
      then
         Fail ("required command not found: " & Command);
      end if;
   end Require_Command;
end Tool_Support;
