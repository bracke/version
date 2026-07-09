with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Containers; use Ada.Containers;
with Interfaces.C;
with System;

with Version.Archive; use Version.Archive;
with Version.Availability;
with Version.Files;
with Version.CLI.Help;
with Version.Objects; use Version.Objects;
with Version.Repository;
with Version.Staging;
with Version.Path_Safety;
with Version.Pathspec;
with Version.Platform;
with Version.Working_Tree;
with Version.Ignore;
with Version.Revisions;
with Version.Credential;
with Version.Ref_Format;
with Version.Refs;
with Version.Verify;
with Version.Status;
with Version.Write;
with Version.Restore;
with Version.Branch;
with Version.Merge;
with Version.Merge_State;
with Version.Remove;
with Version.Tags;
with Version.Remotes;
with Version.Fetch;
with Version.Clone;
with Version.Config;
with Version.Push;
with Version.Init;
with Version.Packed_Refs;
with Version.Checkout;
with Version.Reset;
with Version.Reflog;
with Version.Move;
with Version.Clean;
with Version.Bundle;
with Version.Apply;
with Version.Format_Patch;
with Version.Rebase_State;
with Version.Am;
with Version.Cherry;
with Version.Range_Diff;
with Version.Shortlog;
with Version.Grep;
with Version.Ref_Transaction;
with Version.Hash;
with Version.Describe;
with Version.Notes;
with Version.Blame;
with Version.Tracking;
with Version.Diff;
with Version.Doctor; use Version.Doctor;
with Version.History;
with Version.Log;
with Version.Show;
with Version.Maintenance;
with Version.Rebase;
with Version.Cherry_Pick;
with Version.Cherry_Pick_State;
with Version.Revert;
with Version.Revert_State;
with Version.Stash;
with Version.Sparse;
with Version.Stage;
with Version.Worktrees;
with Version.Submodules;

package body Version.CLI is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Interfaces.C.long;
   use type Version.Merge.Conflict_Kind;

   procedure Print_Usage is
   begin
      Version.CLI.Help.Print_Top_Level;
   end Print_Usage;

   Usage_Exit : constant Ada.Command_Line.Exit_Status :=
     Ada.Command_Line.Exit_Status (2);

   Command_Failure_Exit : constant Ada.Command_Line.Exit_Status :=
     Ada.Command_Line.Exit_Status (1);

   function Usage_Exit_Status return Ada.Command_Line.Exit_Status is
   begin
      return Usage_Exit;
   end Usage_Exit_Status;

   function Command_Failure_Exit_Status return Ada.Command_Line.Exit_Status is
   begin
      return Command_Failure_Exit;
   end Command_Failure_Exit_Status;

   procedure Expected (Text : String);
   procedure Error_Line (Text : String);
   procedure Set_Usage_Failure;
   procedure Set_Command_Failure;
   procedure Usage_Error (Detail, Usage : String);

   function User_Error_Text
     (E : Ada.Exceptions.Exception_Occurrence) return String
   is
      Name    : constant String := Ada.Exceptions.Exception_Name (E);
      Message : constant String := Ada.Exceptions.Exception_Message (E);
   begin
      if Ada.Strings.Fixed.Index (Name, "CONSTRAINT_ERROR") > 0
        or else Ada.Strings.Fixed.Index (Name, "PROGRAM_ERROR") > 0
      then
         return "internal command error";
      elsif Message'Length > 0 then
         return Message;
      else
         return "command failed";
      end if;
   end User_Error_Text;

   function Error_Output_Text (Text : String) return String is
   begin
      return "error: " & Text;
   end Error_Output_Text;

   function Expected_Output_Text (Text : String) return String is
   begin
      return Error_Output_Text ("expected: " & Text);
   end Expected_Output_Text;

   function Unknown_Command_Output_Text (Command : String) return String is
   begin
      return Error_Output_Text ("unknown command: " & Command);
   end Unknown_Command_Output_Text;

   function Unsupported_Archive_Format_Text (Text : String) return String is
   begin
      return
        "unsupported archive format: "
        & Text
        & " (supported formats: tar, tar.gz, zip; use --format tar,"
        & " --format tar.gz, or --format zip)";
   end Unsupported_Archive_Format_Text;

   function Pathspec_No_Files_Text return String is
   begin
      return "pathspec matched no files";
   end Pathspec_No_Files_Text;

   function Pathspec_No_Tracked_Paths_Text return String is
   begin
      return "pathspec matched no tracked paths";
   end Pathspec_No_Tracked_Paths_Text;

   function Pathspec_No_Source_Paths_Text return String is
   begin
      return "pathspec matched no source paths";
   end Pathspec_No_Source_Paths_Text;

   function Version_Output_Text return String is
   begin
      return "version " & Version.Version_String;
   end Version_Output_Text;

   function Is_Help_Option (Text : String) return Boolean is
   begin
      return Text = "--help" or else Text = "-h";
   end Is_Help_Option;

   function Is_Command_Help_Request
     (Command : String; Option : String; Count : Natural) return Boolean is
   begin
      return
        Count = 2
        and then Is_Help_Option (Option)
        and then Version.CLI.Help.Known_Command (Command);
   end Is_Command_Help_Request;

   Quiet_Mode     : Boolean := False;
   Command_Offset : Natural := 0;

   function Count return Natural is
   begin
      return Ada.Command_Line.Argument_Count - Command_Offset;
   end Count;

   function Arg (Index : Positive) return String is
   begin
      return Ada.Command_Line.Argument (Index + Command_Offset);
   end Arg;

   function Parse_Depth_Argument (Text : String) return Positive is
      Value : Natural := 0;
   begin
      if Text'Length = 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "depth must be a positive integer";
      end if;

      for C of Text loop
         if C < '0' or else C > '9' then
            raise Ada.IO_Exceptions.Data_Error
              with "depth must be a positive integer";
         end if;

         declare
            Digit : constant Natural :=
              Character'Pos (C) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               raise Ada.IO_Exceptions.Data_Error
                 with "depth must be a positive integer";
            end if;

            Value := Value * 10 + Digit;
         end;
      end loop;

      if Value = 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "depth must be a positive integer";
      end if;

      return Positive (Value);
   end Parse_Depth_Argument;

   function Parse_Mainline_Argument (Text : String) return Positive is
      Value : Natural := 0;
   begin
      if Text'Length = 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "mainline must be a positive integer";
      end if;

      for C of Text loop
         if C < '0' or else C > '9' then
            raise Ada.IO_Exceptions.Data_Error
              with "mainline must be a positive integer";
         end if;

         declare
            Digit : constant Natural :=
              Character'Pos (C) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               raise Ada.IO_Exceptions.Data_Error
                 with "mainline must be a positive integer";
            end if;

            Value := Value * 10 + Digit;
         end;
      end loop;

      if Value = 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "mainline must be a positive integer";
      end if;

      return Positive (Value);
   end Parse_Mainline_Argument;

   function Has_Path_Argument (First_Index : Positive) return Boolean is
   begin
      if Count < First_Index then
         return False;
      end if;

      for I in First_Index .. Count loop
         if Arg (I) /= "--" then
            return True;
         end if;
      end loop;

      return False;
   end Has_Path_Argument;

   function Pathspecs_From_Args
     (First_Index : Positive) return Version.Pathspec.Pathspec_Vectors.Vector
   is
      Result : Version.Pathspec.Pathspec_Vectors.Vector;
   begin
      if Count >= First_Index then
         for I in First_Index .. Count loop
            if Arg (I) /= "--" then
               Version.Pathspec.Append_Parse (Result, Arg (I));
            end if;
         end loop;
      end if;

      return Result;
   end Pathspecs_From_Args;

   function Is_Absolute_Path (Path : String) return Boolean is
   begin
      return
        Path'Length > 0
        and then
          (Path (Path'First) = '/'
           or else Version.Platform.Is_Windows_Drive_Path (Path));
   end Is_Absolute_Path;

   function Read
     (Fd     : Interfaces.C.int;
      Buf    : System.Address;
      Count  : Interfaces.C.size_t) return Interfaces.C.long;
   pragma Import (C, Read, "read");

   function C_Write
     (Fd     : Interfaces.C.int;
      Buf    : System.Address;
      Count  : Interfaces.C.size_t) return Interfaces.C.long;
   pragma Import (C, C_Write, "write");

   type Check_Ignore_Options is record
      Quiet        : Boolean := False;
      Verbose      : Boolean := False;
      From_Stdin   : Boolean := False;
      Nul          : Boolean := False;
      Non_Matching : Boolean := False;
      Honor_Index  : Boolean := True;
   end record;

   function Check_Ignore_Is_Directory
     (Repo : Version.Repository.Repository_Handle;
      Path : String) return Boolean
   is
      Normal_Path : constant String := Version.Files.Normalize_Separators (Path);
      Candidate   : constant String :=
        (if Is_Absolute_Path (Normal_Path)
         then Normal_Path
         else Version.Files.Join (Version.Repository.Root_Path (Repo), Normal_Path));
      Native      : constant String := Version.Files.To_Native_Path (Candidate);
   begin
      if Normal_Path'Length > 0
        and then Normal_Path (Normal_Path'Last) = '/'
      then
         return True;
      elsif Ada.Directories.Exists (Native) then
         return Ada.Directories.Kind (Native) = Ada.Directories.Directory;
      else
         return False;
      end if;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         return False;
   end Check_Ignore_Is_Directory;

   function Check_Ignore_Index_Path
     (Repo : Version.Repository.Repository_Handle;
      Path : String) return String
   is
      Root   : constant String :=
        Version.Files.Normalize_Separators (Version.Repository.Root_Path (Repo));
      Normal : constant String := Version.Files.Normalize_Separators (Path);
   begin
      if Normal'Length = 0 then
         return "";
      elsif Is_Absolute_Path (Normal) then
         if Root'Length = 0
           or else Normal'Length <= Root'Length
           or else Normal (Normal'First .. Normal'First + Root'Length - 1) /= Root
           or else Normal (Normal'First + Root'Length) /= '/'
         then
            return "";
         else
            return Version.Path_Safety.Normalize_Relative_Path
              (Normal (Normal'First + Root'Length + 1 .. Normal'Last));
         end if;
      else
         return Version.Path_Safety.Normalize_Relative_Path (Normal);
      end if;
   exception
      when others =>
         return "";
   end Check_Ignore_Index_Path;

   function Check_Ignore_Is_Tracked
     (Repo  : Version.Repository.Repository_Handle;
      Index : Version.Staging.Index_Entry_Vectors.Vector;
      Path  : String) return Boolean
   is
      Relative : constant String := Check_Ignore_Index_Path (Repo, Path);
   begin
      return
        Relative'Length > 0
        and then Version.Staging.Find_Path (Index, Relative) /= Natural'Last;
   end Check_Ignore_Is_Tracked;

   function Check_Ignore_Stdin_Paths
     (Options : Check_Ignore_Options) return Version.Path_Safety.Path_Vector
   is
      Result : Version.Path_Safety.Path_Vector;
   begin
      if Options.Nul then
         declare
            Buffer  : aliased String (1 .. 4096);
            Current : Unbounded_String;
         begin
            loop
               declare
                  Count : constant Interfaces.C.long :=
                    Read
                      (0,
                       Buffer (Buffer'First)'Address,
                       Interfaces.C.size_t (Buffer'Length));
               begin
                  if Count < 0 then
                     raise Ada.IO_Exceptions.Data_Error
                       with "could not read check-ignore stdin";
                  elsif Count = 0 then
                     exit;
                  end if;

                  for I in Buffer'First .. Buffer'First + Integer (Count) - 1 loop
                     if Buffer (I) = Character'Val (0) then
                        Result.Append (To_String (Current));
                        Current := Null_Unbounded_String;
                     else
                        Append (Current, Buffer (I));
                     end if;
                  end loop;
               end;
            end loop;

            if Length (Current) > 0 then
               Result.Append (To_String (Current));
            end if;
         end;
      else
         while not Ada.Text_IO.End_Of_File loop
            Result.Append (Ada.Text_IO.Get_Line);
         end loop;
      end if;

      return Result;
   end Check_Ignore_Stdin_Paths;

   procedure Put_Raw (Text : String) is
      Written : Interfaces.C.long;
   begin
      if Text'Length > 0 then
         Written :=
           C_Write
             (1, Text (Text'First)'Address, Interfaces.C.size_t (Text'Length));

         if Written < 0 then
            raise Ada.IO_Exceptions.Data_Error
              with "could not write check-ignore output";
         end if;
      end if;
   end Put_Raw;

   procedure Put_Nul is
      Nul     : aliased Character := Character'Val (0);
      Written : Interfaces.C.long;
   begin
      Written := C_Write (1, Nul'Address, 1);

      if Written < 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "could not write check-ignore output";
      end if;
   end Put_Nul;

   procedure Put_Check_Ignore_Output
     (Path    : String;
      Match   : Version.Ignore.Match_Result;
      Options : Check_Ignore_Options)
   is
   begin
      if Options.Quiet then
         return;
      end if;

      if Options.Verbose then
         if Options.Nul then
            Put_Raw (To_String (Match.Source_Path));
            Put_Nul;
            if Match.Source_Line > 0 then
               Put_Raw
                 (Ada.Strings.Fixed.Trim
                    (Natural'Image (Match.Source_Line), Ada.Strings.Left));
            end if;
            Put_Nul;
            Put_Raw (To_String (Match.Pattern));
            Put_Nul;
            Put_Raw (Path);
            Put_Nul;
         else
            Ada.Text_IO.Put (To_String (Match.Source_Path));
            Ada.Text_IO.Put (":");
            if Match.Source_Line > 0 then
               Ada.Text_IO.Put (Ada.Strings.Fixed.Trim (Natural'Image (Match.Source_Line), Ada.Strings.Left));
            end if;
            Ada.Text_IO.Put (":");
            Ada.Text_IO.Put (To_String (Match.Pattern));
            Ada.Text_IO.Put (Character'Val (9));
            Ada.Text_IO.Put_Line (Path);
         end if;
      elsif Options.Nul then
         Put_Raw (Path);
         Put_Nul;
      else
         Ada.Text_IO.Put_Line (Path);
      end if;
   end Put_Check_Ignore_Output;

   procedure Run_Check_Ignore
     (Paths   : Version.Path_Safety.Path_Vector;
      Options : Check_Ignore_Options)
   is
      Repo    : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Rules   : constant Version.Ignore.Ignore_Rules := Version.Ignore.Load (Repo);
      Index   : constant Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);
      Matched : Boolean := False;
   begin
      if not Paths.Is_Empty then
         for I in Paths.First_Index .. Paths.Last_Index loop
            declare
               Path   : constant String := Paths.Element (I);
               Result : Version.Ignore.Match_Result;
            begin
               if Options.Honor_Index
                 and then Check_Ignore_Is_Tracked (Repo, Index, Path)
               then
                  Result := (others => <>);
               else
                  Result :=
                    Version.Ignore.Match
                      (Rules         => Rules,
                       Relative_Path => Path,
                       Is_Directory  => Check_Ignore_Is_Directory (Repo, Path));
               end if;

               if Options.Verbose then
                  if Result.Has_Match then
                     Matched := True;
                     Put_Check_Ignore_Output (Path, Result, Options);
                  elsif Options.Non_Matching then
                     Put_Check_Ignore_Output (Path, Result, Options);
                  end if;
               elsif Result.Is_Ignored then
                  Matched := True;
                  Put_Check_Ignore_Output (Path, Result, Options);
               end if;
            end;
         end loop;
      end if;

      if not Matched then
         Set_Command_Failure;
      end if;
   end Run_Check_Ignore;

   procedure Parse_Pathspec_Command_Arguments
     (Command_Name, Usage : String; OK : out Boolean)
   is
      After_Separator : Boolean := False;
      Operand_Count   : Natural := 0;
   begin
      OK := False;

      if Count >= 2 then
         for I in 2 .. Count loop
            if Arg (I) = "--" and then not After_Separator then
               After_Separator := True;
            elsif not After_Separator
              and then Arg (I)'Length > 0
              and then Arg (I) (Arg (I)'First) = '-'
            then
               Usage_Error
                 ("unknown " & Command_Name & " option: " & Arg (I), Usage);
               return;
            else
               Operand_Count := Operand_Count + 1;
            end if;
         end loop;
      end if;

      if Operand_Count = 0 then
         Usage_Error ("missing " & Command_Name & " pathspec", Usage);
      else
         OK := True;
      end if;
   end Parse_Pathspec_Command_Arguments;

   procedure Append_Unique
     (Paths : in out Version.Path_Safety.Path_Vector; Path : String) is
   begin
      if not Paths.Is_Empty then
         for I in Paths.First_Index .. Paths.Last_Index loop
            if Paths.Element (I) = Path then
               return;
            end if;
         end loop;
      end if;

      Paths.Append (Path);
   end Append_Unique;

   function Working_Candidates
     (Include_Ignored : Boolean := False)
      return Version.Path_Safety.Path_Vector
   is
      Repo    : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Index   : constant Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);
      Rules   : constant Version.Ignore.Ignore_Rules := Version.Ignore.Load (Repo);
      Working : constant Version.Working_Tree.Working_File_Vectors.Vector :=
        (if Include_Ignored
         then Version.Working_Tree.Scan (Repo)
         else Version.Working_Tree.Scan
           (Repo => Repo, Ignore_Rules => Rules, Tracked_Paths => Index));
      Result  : Version.Path_Safety.Path_Vector;
   begin
      if not Working.Is_Empty then
         for I in Working.First_Index .. Working.Last_Index loop
            Append_Unique (Result, To_String (Working.Element (I).Path));
         end loop;
      end if;
      return Result;
   end Working_Candidates;

   function Index_Candidates return Version.Path_Safety.Path_Vector is
      Repo   : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Index  : constant Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);
      Result : Version.Path_Safety.Path_Vector;
   begin
      if not Index.Is_Empty then
         for I in Index.First_Index .. Index.Last_Index loop
            Append_Unique (Result, To_String (Index.Element (I).Path));
         end loop;
      end if;
      return Result;
   end Index_Candidates;

   procedure Append_All_Unique
     (Target : in out Version.Path_Safety.Path_Vector;
      Source : Version.Path_Safety.Path_Vector) is
   begin
      if not Source.Is_Empty then
         for I in Source.First_Index .. Source.Last_Index loop
            Append_Unique (Target, Source.Element (I));
         end loop;
      end if;
   end Append_All_Unique;

   function Merge_Candidates
     (Left  : Version.Path_Safety.Path_Vector;
      Right : Version.Path_Safety.Path_Vector)
      return Version.Path_Safety.Path_Vector
   is
      Result : Version.Path_Safety.Path_Vector;
   begin
      Append_All_Unique (Result, Left);
      Append_All_Unique (Result, Right);
      return Result;
   end Merge_Candidates;

   function Merge_Candidates
     (First  : Version.Path_Safety.Path_Vector;
      Second : Version.Path_Safety.Path_Vector;
      Third  : Version.Path_Safety.Path_Vector)
      return Version.Path_Safety.Path_Vector
   is
      Result : Version.Path_Safety.Path_Vector;
   begin
      Append_All_Unique (Result, First);
      Append_All_Unique (Result, Second);
      Append_All_Unique (Result, Third);
      return Result;
   end Merge_Candidates;

   function Commit_Tree_Id
     (Repo      : Version.Repository.Repository_Handle;
      Commit_Id : Version.Objects.Hex_Object_Id)
      return Version.Objects.Hex_Object_Id
   is
      Obj : constant Version.Objects.Git_Object :=
        Version.Objects.Read_Object (Repo, Commit_Id);
   begin
      if Version.Objects.Kind (Obj) /= Version.Objects.Commit_Object then
         raise Ada.IO_Exceptions.Data_Error with "object is not a commit";
      end if;

      return Version.Objects.Commit_Tree_Id (Obj);
   end Commit_Tree_Id;

   function Tree_Candidates
     (Commit_Id : Version.Objects.Hex_Object_Id)
      return Version.Path_Safety.Path_Vector
   is
      Repo   : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Items  : constant Version.Objects.Tree_Entry_Vectors.Vector :=
        Version.Objects.Flatten_Tree
          (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, Commit_Id));
      Result : Version.Path_Safety.Path_Vector;
   begin
      if not Items.Is_Empty then
         for I in Items.First_Index .. Items.Last_Index loop
            Append_Unique (Result, To_String (Items.Element (I).Path));
         end loop;
      end if;
      return Result;
   end Tree_Candidates;

   function Matching_Candidates
     (Candidates : Version.Path_Safety.Path_Vector;
      Specs      : Version.Pathspec.Pathspec_Vectors.Vector)
      return Version.Path_Safety.Path_Vector
   is
      Result : Version.Path_Safety.Path_Vector;
   begin
      if not Candidates.Is_Empty then
         for I in Candidates.First_Index .. Candidates.Last_Index loop
            declare
               Path : constant String := Candidates.Element (I);
            begin
               if Version.Pathspec.Matches_Any (Specs, Path) then
                  Append_Unique (Result, Path);
               end if;
            end;
         end loop;
      end if;

      return Result;
   end Matching_Candidates;

   procedure Success_Line (Text : String) is
   begin
      if not Quiet_Mode then
         Ada.Text_IO.Put_Line (Text);
      end if;
   end Success_Line;

   function Has_Stashable_Changes
     (Include_Untracked : Boolean;
      Include_Ignored   : Boolean := False;
      Pathspecs         : Version.Pathspec.Pathspec_Vectors.Vector :=
        Version.Pathspec.Pathspec_Vectors.Empty_Vector)
      return Boolean
   is
      Status : constant Version.Status.Status_Result :=
        (if Pathspecs.Is_Empty
         then Version.Status.Current_Status
         else Version.Status.Current_Status (Pathspecs));

      function Has_Matching_Ignored_File return Boolean is
         Repo    : constant Version.Repository.Repository_Handle :=
           Version.Repository.Open;
         Index   : constant Version.Staging.Index_Entry_Vectors.Vector :=
           Version.Staging.Load (Repo);
         Rules   : constant Version.Ignore.Ignore_Rules := Version.Ignore.Load (Repo);
         Working : constant Version.Working_Tree.Working_File_Vectors.Vector :=
           Version.Working_Tree.Scan (Repo);
      begin
         if not Include_Ignored then
            return False;
         end if;

         if not Working.Is_Empty then
            for I in Working.First_Index .. Working.Last_Index loop
               declare
                  Path : constant String := To_String (Working.Element (I).Path);
               begin
                  if Version.Staging.Find_Path (Index, Path) = Natural'Last
                    and then Version.Ignore.Is_Ignored
                               (Rules         => Rules,
                                Relative_Path => Path,
                                Is_Directory  => False)
                    and then (Pathspecs.Is_Empty
                              or else Version.Pathspec.Matches_Any
                                (Pathspecs, Path))
                  then
                     return True;
                  end if;
               end;
            end loop;
         end if;

         return False;
      end Has_Matching_Ignored_File;
   begin
      return
        not Status.Changes.Is_Empty
        or else not Status.Staged.Is_Empty
        or else not Status.Conflicted.Is_Empty
        or else (Include_Untracked and then not Status.Untracked.Is_Empty)
        or else Has_Matching_Ignored_File;
   end Has_Stashable_Changes;

   procedure Require_Clean_Working_Tree (Operation : String) is
      Status : constant Version.Status.Status_Result :=
        Version.Status.Current_Status;
   begin
      if not Status.Changes.Is_Empty
        or else not Status.Staged.Is_Empty
        or else not Status.Untracked.Is_Empty
        or else not Status.Conflicted.Is_Empty
      then
         raise Ada.IO_Exceptions.Data_Error
           with Operation & " requires a clean working tree";
      end if;
   end Require_Clean_Working_Tree;

   function Has_Any_Untracked_Working_File return Boolean is
      Repo    : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Index   : constant Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);
      Rules   : constant Version.Ignore.Ignore_Rules := Version.Ignore.Load (Repo);
      Working : constant Version.Working_Tree.Working_File_Vectors.Vector :=
        Version.Working_Tree.Scan
          (Repo => Repo, Ignore_Rules => Rules, Tracked_Paths => Index);
   begin
      if Working.Is_Empty then
         return False;
      end if;

      for I in Working.First_Index .. Working.Last_Index loop
         declare
            Path : constant String := To_String (Working.Element (I).Path);
         begin
            if Version.Staging.Find_Path (Index, Path) = Natural'Last then
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Any_Untracked_Working_File;

   procedure Require_Clean_Working_Tree_Including_Sparse_Excluded
     (Operation : String) is
   begin
      Require_Clean_Working_Tree (Operation);

      if Has_Any_Untracked_Working_File then
         raise Ada.IO_Exceptions.Data_Error
           with Operation & " requires a clean working tree";
      end if;
   end Require_Clean_Working_Tree_Including_Sparse_Excluded;

   function Sparse_Items_From_Args
     (First_Index : Positive) return Version.Sparse.String_Vectors.Vector
   is
      Result : Version.Sparse.String_Vectors.Vector;
   begin
      if Count >= First_Index then
         for I in First_Index .. Count loop
            if Arg (I) /= "--" then
               declare
                  Parsed : constant Version.Pathspec.Pathspec_Item :=
                    Version.Pathspec.Parse (Arg (I));
                  pragma Unreferenced (Parsed);
               begin
                  Result.Append (Arg (I));
               end;
            end if;
         end loop;
      end if;

      return Result;
   end Sparse_Items_From_Args;

   function Sparse_Patterns_From_Texts
     (Items : Version.Sparse.String_Vectors.Vector)
      return Version.Pathspec.Pathspec_Vectors.Vector
   is
      Result : Version.Pathspec.Pathspec_Vectors.Vector;
   begin
      if not Items.Is_Empty then
         for I in Items.First_Index .. Items.Last_Index loop
            Version.Pathspec.Append_Parse (Result, Items.Element (I));
         end loop;
      end if;

      return Result;
   end Sparse_Patterns_From_Texts;

   procedure Preflight_Sparse_Restore
     (Repo           : Version.Repository.Repository_Handle;
      Sparse_Enabled : Boolean;
      Items          : Version.Sparse.String_Vectors.Vector)
   is
      Commit_Id : constant String := Version.Refs.Current_Commit_Id (Repo);
      Patterns  : constant Version.Pathspec.Pathspec_Vectors.Vector :=
        Sparse_Patterns_From_Texts (Items);
   begin
      if Commit_Id'Length = 0 then
         raise Ada.IO_Exceptions.Data_Error
           with "cannot update sparse checkout on unborn branch";
      end if;

      Version.Restore.Preflight_Working_Tree_For_Commit
        (Repo            => Repo,
         Commit_Id       => Version.Objects.To_Object_Id (Commit_Id),
         Sparse_Enabled  => Sparse_Enabled,
         Sparse_Patterns => Patterns);
   end Preflight_Sparse_Restore;

   procedure Print_Sparse_List is
      Repo  : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Items : Version.Sparse.String_Vectors.Vector;
   begin
      if Version.Sparse.Enabled (Repo) then
         Items := Version.Sparse.Pattern_Texts (Repo);
      end if;

      if not Items.Is_Empty then
         for I in Items.First_Index .. Items.Last_Index loop
            Ada.Text_IO.Put_Line (Items.Element (I));
         end loop;
      end if;
   end Print_Sparse_List;

   procedure Print_Sparse_Status is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
   begin
      Ada.Text_IO.Put (Version.Sparse.Status_Text (Repo));
   end Print_Sparse_Status;

   function Natural_Image (Value : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
   end Natural_Image;

   function Short_Id (Id : String) return String is
   begin
      if Id'Length > 12 then
         return Id (Id'First .. Id'First + 11);
      else
         return Id;
      end if;
   end Short_Id;

   procedure Print_Worktree_List is
      Items : constant Version.Worktrees.Worktree_Info_Vectors.Vector :=
        Version.Worktrees.List;
   begin
      if not Items.Is_Empty then
         for I in Items.First_Index .. Items.Last_Index loop
            Ada.Text_IO.Put_Line
              (Version.Worktrees.Worktree_Status_Line (Items.Element (I)));
         end loop;
      end if;
   end Print_Worktree_List;

   function Ends_With (Text : String; Suffix : String) return Boolean is
   begin
      return
        Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Ends_With;

   function Lower_ASCII (Text : String) return String is
      Result : String := Text;
   begin
      for I in Result'Range loop
         if Result (I) >= 'A' and then Result (I) <= 'Z' then
            Result (I) :=
              Character'Val
                (Character'Pos (Result (I))
                 - Character'Pos ('A')
                 + Character'Pos ('a'));
         end if;
      end loop;
      return Result;
   end Lower_ASCII;

   function Archive_Format_From_Text
     (Text : String) return Version.Archive.Archive_Format
   is
      Lower : constant String := Lower_ASCII (Text);
   begin
      if Lower = "tar" then
         return Version.Archive.Tar_Format;
      elsif Lower = "tar.gz" or else Lower = "tgz" then
         return Version.Archive.Tar_Gz_Format;
      elsif Lower = "zip" then
         return Version.Archive.Zip_Format;
      else
         raise Ada.IO_Exceptions.Data_Error
           with Unsupported_Archive_Format_Text (Text);
      end if;
   end Archive_Format_From_Text;

   function Looks_Like_Unsupported_Archive_Output
     (Path : String) return Boolean
   is
      Lower : constant String := Lower_ASCII (Path);
   begin
      return
        Ends_With (Lower, ".tar.xz")
        or else Ends_With (Lower, ".txz")
        or else Ends_With (Lower, ".xz")
        or else Ends_With (Lower, ".tar.bz2")
        or else Ends_With (Lower, ".tbz")
        or else Ends_With (Lower, ".tbz2")
        or else Ends_With (Lower, ".bz2")
        or else Ends_With (Lower, ".zipx")
        or else Ends_With (Lower, ".7z")
        or else Ends_With (Lower, ".rar");
   end Looks_Like_Unsupported_Archive_Output;

   procedure Run_Archive_Command is
      Usage           : constant String :=
        "version archive REV [--output PATH] [--format tar|zip] [--prefix PATH] [--] [PATHSPEC...]";
      Format          : Version.Archive.Archive_Format :=
        Version.Archive.Tar_Format;
      Format_Explicit : Boolean := False;
      Output_Explicit : Boolean := False;
      Prefix_Explicit : Boolean := False;
      After_Dash_Dash : Boolean := False;
      Output          : Unbounded_String;
      Prefix          : Unbounded_String;
      Specs           : Version.Pathspec.Pathspec_Vectors.Vector;
      I               : Positive := 3;

      function Is_Option (Text : String) return Boolean is
      begin
         return Text'Length > 0 and then Text (Text'First) = '-';
      end Is_Option;
   begin
      if Count < 2 then
         Usage_Error ("missing archive revision", Usage);
         return;
      end if;

      while I <= Count loop
         if After_Dash_Dash then
            Version.Pathspec.Append_Parse (Specs, Arg (I));
            I := I + 1;
         elsif Arg (I) = "--output" then
            if Output_Explicit then
               Usage_Error ("duplicate option: --output", Usage);
               return;
            elsif I = Count then
               Usage_Error ("--output requires a path", Usage);
               return;
            end if;

            Output_Explicit := True;
            Output := To_Unbounded_String (Arg (I + 1));
            I := I + 2;
         elsif Arg (I) = "--format" then
            if Format_Explicit then
               Usage_Error ("duplicate option: --format", Usage);
               return;
            elsif I = Count then
               Usage_Error ("--format requires a value", Usage);
               return;
            end if;

            Format := Archive_Format_From_Text (Arg (I + 1));
            Format_Explicit := True;
            I := I + 2;
         elsif Arg (I) = "--prefix" then
            if Prefix_Explicit then
               Usage_Error ("duplicate option: --prefix", Usage);
               return;
            elsif I = Count then
               Usage_Error ("--prefix requires a path", Usage);
               return;
            end if;

            Prefix_Explicit := True;
            Prefix := To_Unbounded_String (Arg (I + 1));
            I := I + 2;
         elsif Arg (I) = "--" then
            After_Dash_Dash := True;
            I := I + 1;
         elsif Is_Option (Arg (I)) then
            Usage_Error ("unknown archive option: " & Arg (I), Usage);
            return;
         else
            Version.Pathspec.Append_Parse (Specs, Arg (I));
            I := I + 1;
         end if;
      end loop;

      if Length (Output) > 0
        and then Looks_Like_Unsupported_Archive_Output (To_String (Output))
      then
         raise Ada.IO_Exceptions.Data_Error
           with
             Version.Archive.Unsupported_Output_Format_Text
               (To_String (Output));
      elsif Length (Output) > 0
        and then not Format_Explicit
        and then Ends_With (Lower_ASCII (To_String (Output)), ".zip")
      then
         Format := Version.Archive.Zip_Format;
      elsif Length (Output) > 0
        and then not Format_Explicit
        and then (Ends_With (Lower_ASCII (To_String (Output)), ".tar.gz")
                  or else Ends_With (Lower_ASCII (To_String (Output)), ".tgz"))
      then
         Format := Version.Archive.Tar_Gz_Format;
      end if;

      if Length (Output) = 0 then
         Output :=
           To_Unbounded_String
             ((case Format is
               when Version.Archive.Zip_Format    => "archive.zip",
               when Version.Archive.Tar_Gz_Format => "archive.tar.gz",
               when Version.Archive.Tar_Format    => "archive.tar"));
      end if;

      declare
         Repo : constant Version.Repository.Repository_Handle :=
           Version.Repository.Open;
      begin
         Version.Archive.Create
           (Repository => Repo,
            Revision   => Arg (2),
            Output     => To_String (Output),
            Format     => Format,
            Pathspecs  => Specs,
            Prefix     => To_String (Prefix));
      end;
      Success_Line ("created archive " & To_String (Output));
   end Run_Archive_Command;

   procedure Set_Usage_Failure is
   begin
      Ada.Command_Line.Set_Exit_Status (Usage_Exit);
   end Set_Usage_Failure;

   procedure Set_Command_Failure is
   begin
      Ada.Command_Line.Set_Exit_Status (Command_Failure_Exit);
   end Set_Command_Failure;

   procedure Error_Line (Text : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Error_Output_Text (Text));
   end Error_Line;

   procedure Expected (Text : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Expected_Output_Text (Text));
      Set_Usage_Failure;
   end Expected;

   procedure Usage_Error (Detail, Usage : String) is
   begin
      Error_Line (Detail);
      Expected (Usage);
   end Usage_Error;

   function Join (Left, Right : String) return String
   renames Version.Files.Join;

   function Contains_Pathspec_Glob_Meta (Text : String) return Boolean is
   begin
      for C of Text loop
         if C = '*' or else C = '?' or else C = '[' then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Pathspec_Glob_Meta;

   procedure Raise_If_Explicit_Sparse_Missing_Stage (First_Index : Positive) is
      Repo  : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Index : constant Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);
   begin
      if not Version.Sparse.Enabled (Repo) then
         return;
      end if;

      if Count >= First_Index then
         for I in First_Index .. Count loop
            if Arg (I) /= "--"
              and then Arg (I)'Length > 0
              and then Arg (I) (Arg (I)'First) /= ':'
              and then not Contains_Pathspec_Glob_Meta (Arg (I))
            then
               declare
                  Safe_Path : constant String :=
                    Version.Path_Safety.Normalize_Relative_Path (Arg (I));
                  Full_Path : constant String :=
                    Join (Version.Repository.Root_Path (Repo), Safe_Path);
               begin
                  Version.Path_Safety.Require_Safe_Relative_Path (Safe_Path);

                  if Version.Staging.Find_Path (Index, Safe_Path)
                    /= Natural'Last
                    and then not Version.Sparse.Included (Repo, Safe_Path)
                    and then not Ada.Directories.Exists (Full_Path)
                  then
                     raise Ada.IO_Exceptions.Data_Error
                       with
                         Version.Availability.Path_Excluded_By_Sparse_Checkout
                           (Safe_Path);
                  end if;
               end;
            end if;
         end loop;
      end if;
   end Raise_If_Explicit_Sparse_Missing_Stage;

   procedure Stage_Path (Path : String) is
   begin
      Version.Stage.Stage_Path (Path);
   end Stage_Path;

   procedure Print_History is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Current : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Version.Refs.Current_Commit_Id (Repo));
   begin
      if Ada.Strings.Unbounded.Length (Current) = 0 then
         Ada.Text_IO.Put_Line ("No saved history");
         return;
      end if;

      while Ada.Strings.Unbounded.Length (Current) > 0 loop
         declare
            Current_Text : constant String :=
              Ada.Strings.Unbounded.To_String (Current);
         begin
            if not Version.Objects.Is_Valid_Hex_Object_Id (Current_Text) then
               raise Ada.Text_IO.Data_Error
                 with "corrupt repository: invalid commit id";
            end if;

            declare
               Commit_Id : constant Version.Objects.Hex_Object_Id :=
                 Version.Objects.To_Object_Id (Current_Text);

               Obj : constant Version.Objects.Git_Object :=
                 Version.Objects.Read_Object (Repo, Commit_Id);

               Message : constant String :=
                 Version.Objects.Commit_Message_First_Line (Obj);

               Parent : constant String :=
                 Version.Objects.Commit_Parent_Id (Obj);
            begin
               Ada.Text_IO.Put_Line (Current_Text & "  " & Message);
               Current := Ada.Strings.Unbounded.To_Unbounded_String (Parent);
            end;
         end;
      end loop;
   end Print_History;

   procedure Sort_Branches
     (List : in out Version.Refs.Branch_Name_Vectors.Vector) is
      Swapped : Boolean := True;
   begin
      if List.Length < 2 then
         return;
      end if;

      while Swapped loop
         Swapped := False;

         for I in List.First_Index .. List.Last_Index - 1 loop
            if To_String (List.Element (I + 1)) < To_String (List.Element (I))
            then
               declare
                  Temp : constant Unbounded_String := List.Element (I);
               begin
                  List.Replace_Element (I, List.Element (I + 1));
                  List.Replace_Element (I + 1, Temp);
                  Swapped := True;
               end;
            end if;
         end loop;
      end loop;
   end Sort_Branches;

   procedure Print_Branch_List is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Head : constant Version.Refs.Head_Info := Version.Refs.Read_Head (Repo);

      Current : constant String :=
        (if Version.Refs.Is_Attached (Head)
         then Version.Refs.Branch_Name (Head)
         else "");

      Branches : Version.Refs.Branch_Name_Vectors.Vector :=
        Version.Refs.List_Branches (Repo);
   begin
      Sort_Branches (Branches);

      if Branches.Is_Empty then
         Ada.Text_IO.Put_Line ("No branches");
      else
         for I in Branches.First_Index .. Branches.Last_Index loop
            declare
               Name : constant String := To_String (Branches.Element (I));
            begin
               if Name = Current then
                  Ada.Text_IO.Put_Line ("* " & Name);
               else
                  Ada.Text_IO.Put_Line ("  " & Name);
               end if;
            end;
         end loop;
      end if;
   end Print_Branch_List;

   procedure Run is
   begin
      Quiet_Mode := False;
      Command_Offset := 0;

      if Ada.Command_Line.Argument_Count > 0
        and then Ada.Command_Line.Argument (1) = "--quiet"
      then
         Quiet_Mode := True;
         Command_Offset := 1;
      end if;

      if Count = 0 then
         Print_Usage;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         return;
      end if;

      declare
         Command : constant String := Arg (1);
      begin
         if Is_Help_Option (Command) then
            if Count /= 1 then
               Expected ("version --help");
               return;
            end if;

            Print_Usage;

         elsif Command = "help" then
            if Count = 1 then
               Print_Usage;

            elsif Count = 2 then
               if Version.CLI.Help.Known_Command (Arg (2)) then
                  Version.CLI.Help.Print_Command (Arg (2));
               else
                  Error_Line ("unknown command: " & Arg (2));
                  Set_Usage_Failure;
                  return;
               end if;

            else
               Expected ("version help [COMMAND]");
               return;
            end if;

         elsif Command = "man" then
            if Count = 1 then
               Ada.Text_IO.Put (Version.CLI.Help.Man_Page_Text);
            else
               Expected ("version man");
               return;
            end if;

         elsif Command = "completion" then
            if Count = 2 and then Arg (2) = "bash" then
               Ada.Text_IO.Put (Version.CLI.Help.Completion_Bash_Text);
            else
               Expected ("version completion bash");
               return;
            end if;

         elsif Command = "--version" then
            if Count /= 1 then
               Expected ("version --version");
               return;
            end if;

            Ada.Text_IO.Put_Line (Version_Output_Text);

         elsif Command = "doctor" then
            if Count = 1 then
               declare
                  Result : constant Version.Doctor.Doctor_Result :=
                    Version.Doctor.Check_Repository;
               begin
                  Ada.Text_IO.Put (Version.Doctor.Result_Text (Result));
                  if Result.Repository_Status /= Version.Doctor.Pass
                    or else Result.Object_Format_Status /= Version.Doctor.Pass
                    or else Result.Head_Status /= Version.Doctor.Pass
                    or else Result.Index_Status /= Version.Doctor.Pass
                  then
                     Set_Command_Failure;
                  end if;
               end;

            elsif Count = 2 and then Arg (2) = "--release" then
               Ada.Text_IO.Put (Version.Doctor.Release_Check_Text);
               if Version.Doctor.Run_Release_Checks then
                  Success_Line ("release checks passed");
               else
                  Error_Line ("release checks failed");
                  Set_Command_Failure;
               end if;

            else
               Expected ("version doctor [--release]");
               return;
            end if;

         elsif Count = 2
           and then Is_Command_Help_Request (Command, Arg (2), Count)
         then
            Version.CLI.Help.Print_Command (Command);

         elsif Command = "status" then
            declare
               Usage        : constant String :=
                 "version status [--porcelain|--short|--branch] "
                 & "[--ignored[=MODE]] [--] [PATHSPEC...]";
               Mode         : Natural := 0;
               Include_Ignored : Boolean := False;
               Ignored_Mode : Version.Status.Ignored_Display_Mode :=
                 Version.Status.Ignored_Traditional;
               Has_Separator : Boolean := False;
               Path_First   : Positive := Count + 1;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--" and then not Has_Separator then
                        Has_Separator := True;
                        if I < Count then
                           Path_First := I + 1;
                        end if;
                     elsif not Has_Separator and then Arg (I) = "--porcelain" then
                        if Mode /= 0 then
                           Usage_Error
                             ("duplicate status mode option: " & Arg (I), Usage);
                           return;
                        end if;
                        Mode := 1;
                     elsif not Has_Separator and then Arg (I) = "--short" then
                        if Mode /= 0 then
                           Usage_Error
                             ("duplicate status mode option: " & Arg (I), Usage);
                           return;
                        end if;
                        Mode := 2;
                     elsif not Has_Separator and then Arg (I) = "--branch" then
                        if Mode /= 0 then
                           Usage_Error
                             ("duplicate status mode option: " & Arg (I), Usage);
                           return;
                        end if;
                        Mode := 3;
                     elsif not Has_Separator and then Arg (I) = "--ignored" then
                        Include_Ignored := True;
                        Ignored_Mode := Version.Status.Ignored_Traditional;
                     elsif not Has_Separator
                       and then Arg (I)'Length > 10
                       and then Arg (I) (Arg (I)'First .. Arg (I)'First + 9)
                                = "--ignored="
                     then
                        declare
                           Value : constant String :=
                             Arg (I) (Arg (I)'First + 10 .. Arg (I)'Last);
                        begin
                           if Value = "traditional" then
                              Include_Ignored := True;
                              Ignored_Mode := Version.Status.Ignored_Traditional;
                           elsif Value = "matching" then
                              Include_Ignored := True;
                              Ignored_Mode := Version.Status.Ignored_Matching;
                           elsif Value = "no" then
                              Include_Ignored := False;
                           else
                              Usage_Error
                                ("unknown status ignored mode: " & Value, Usage);
                              return;
                           end if;
                        end;
                     elsif not Has_Separator
                       and then Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error ("unknown status option: " & Arg (I), Usage);
                        return;
                     elsif Path_First = Count + 1 then
                        Path_First := I;
                     end if;
                  end loop;
               end if;

               if Has_Separator and then not Has_Path_Argument (Path_First) then
                  Usage_Error ("missing status pathspec", Usage);
                  return;
               elsif Count < Path_First or else not Has_Path_Argument (Path_First) then
                  if Mode = 1 then
                     Version.Status.Print_Porcelain_Status
                       (Include_Ignored => Include_Ignored,
                        Ignored_Mode    => Ignored_Mode);
                  elsif Mode = 2 then
                     Version.Status.Print_Short_Status
                       (Include_Ignored => Include_Ignored,
                        Ignored_Mode    => Ignored_Mode);
                  elsif Mode = 3 then
                     Version.Status.Print_Branch_Status
                       (Include_Ignored => Include_Ignored,
                        Ignored_Mode    => Ignored_Mode);
                  elsif Include_Ignored then
                     Version.Status.Print_Ignored_Status (Ignored_Mode);
                  else
                     Version.Status.Print_Status;
                  end if;
               elsif Mode = 1 then
                  Version.Status.Print_Porcelain_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode);
               elsif Mode = 2 then
                  Version.Status.Print_Short_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode);
               elsif Mode = 3 then
                  Version.Status.Print_Branch_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode);
               elsif Include_Ignored then
                  Version.Status.Print_Ignored_Status
                    (Pathspecs_From_Args (Path_First), Ignored_Mode);
               else
                  Version.Status.Print_Status (Pathspecs_From_Args (Path_First));
               end if;
            end;

         elsif Command = "check-ignore" then
            declare
               Usage        : constant String :=
                 "version check-ignore [-q|--quiet] [-v|--verbose] "
                 & "[--stdin] [-z] [-n|--non-matching] "
                 & "[--index|--no-index] [--] PATH...";
               Options     : Check_Ignore_Options;
               Has_Separator : Boolean := False;
               Paths       : Version.Path_Safety.Path_Vector;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--" and then not Has_Separator then
                        Has_Separator := True;
                     elsif not Has_Separator and then Arg (I) = "--no-quiet" then
                        Options.Quiet := False;
                     elsif not Has_Separator
                       and then (Arg (I) = "-q" or else Arg (I) = "--quiet")
                     then
                        if Options.Quiet then
                           Usage_Error
                             ("duplicate check-ignore option: " & Arg (I), Usage);
                           return;
                        end if;

                        Options.Quiet := True;
                     elsif not Has_Separator and then Arg (I) = "--no-verbose" then
                        Options.Verbose := False;
                     elsif not Has_Separator
                       and then (Arg (I) = "-v" or else Arg (I) = "--verbose")
                     then
                        if Options.Verbose then
                           Usage_Error
                             ("duplicate check-ignore option: " & Arg (I), Usage);
                           return;
                        end if;

                        Options.Verbose := True;
                     elsif not Has_Separator and then Arg (I) = "--no-stdin" then
                        Options.From_Stdin := False;
                     elsif not Has_Separator and then Arg (I) = "--stdin" then
                        if Options.From_Stdin then
                           Usage_Error
                             ("duplicate check-ignore option: --stdin", Usage);
                           return;
                        end if;

                        Options.From_Stdin := True;
                     elsif not Has_Separator and then Arg (I) = "-z" then
                        if Options.Nul then
                           Usage_Error
                             ("duplicate check-ignore option: -z", Usage);
                           return;
                        end if;

                        Options.Nul := True;
                     elsif not Has_Separator
                       and then Arg (I) = "--no-non-matching"
                     then
                        Options.Non_Matching := False;
                     elsif not Has_Separator
                       and then (Arg (I) = "-n" or else Arg (I) = "--non-matching")
                     then
                        if Options.Non_Matching then
                           Usage_Error
                             ("duplicate check-ignore option: " & Arg (I), Usage);
                           return;
                        end if;

                        Options.Non_Matching := True;
                     elsif not Has_Separator and then Arg (I) = "--no-index" then
                        Options.Honor_Index := False;
                     elsif not Has_Separator and then Arg (I) = "--index" then
                        Options.Honor_Index := True;
                     elsif not Has_Separator
                       and then Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error
                          ("unknown check-ignore option: " & Arg (I), Usage);
                        return;
                     else
                        Paths.Append (Arg (I));
                     end if;
                  end loop;
               end if;

               if Options.Quiet and then Options.Verbose then
                  Usage_Error
                    ("check-ignore --quiet cannot be combined with --verbose",
                     Usage);
                  return;
               elsif Options.Non_Matching and then not Options.Verbose then
                  Usage_Error
                    ("check-ignore --non-matching requires --verbose", Usage);
                  return;
               elsif Options.From_Stdin and then not Paths.Is_Empty then
                  Usage_Error
                    ("check-ignore --stdin cannot be combined with path operands",
                     Usage);
                  return;
               elsif not Options.From_Stdin and then Paths.Is_Empty then
                  Usage_Error ("missing check-ignore path", Usage);
                  return;
               end if;

               if Options.From_Stdin then
                  Paths := Check_Ignore_Stdin_Paths (Options);
               end if;

               Run_Check_Ignore (Paths, Options);
            end;

         elsif Command = "diff" then
            declare
               Usage        : constant String :=
                 "version diff [--staged|--cached] [--] [PATHSPEC...] | version diff REV1 REV2";
               Path_First   : Positive := 2;
               Has_Separator : Boolean := False;
            begin
               if Count = 1 then
                  Ada.Text_IO.Put
                    (Version.Diff.Diff_Working_Tree (Version.Repository.Open));
               elsif Arg (2) = "--staged" or else Arg (2) = "--cached" then
                  Path_First := 3;
                  if Count >= Path_First then
                     for I in Path_First .. Count loop
                        if Arg (I) = "--" then
                           if Has_Separator then
                              Usage_Error ("duplicate option: --", Usage);
                              return;
                           end if;
                           Has_Separator := True;
                        elsif not Has_Separator
                          and then Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error ("unknown diff option: " & Arg (I), Usage);
                           return;
                        end if;
                     end loop;
                  end if;

                  if Has_Separator and then not Has_Path_Argument (Path_First) then
                     Usage_Error ("missing diff pathspec", Usage);
                     return;
                  elsif Count < Path_First or else not Has_Path_Argument (Path_First) then
                     Ada.Text_IO.Put
                       (Version.Diff.Diff_Staged (Version.Repository.Open));
                  else
                     Ada.Text_IO.Put
                       (Version.Diff.Diff_Staged
                          (Version.Repository.Open, Pathspecs_From_Args (Path_First)));
                  end if;
               elsif Arg (2) = "--" then
                  Has_Separator := True;
                  Path_First := 3;
                  if not Has_Path_Argument (Path_First) then
                     Usage_Error ("missing diff pathspec", Usage);
                     return;
                  end if;
                  Ada.Text_IO.Put
                    (Version.Diff.Diff_Working_Tree
                       (Version.Repository.Open, Pathspecs_From_Args (Path_First)));
               elsif Arg (2)'Length > 0 and then Arg (2) (Arg (2)'First) = '-' then
                  Usage_Error ("unknown diff option: " & Arg (2), Usage);
                  return;
               elsif Count = 2 then
                  Ada.Text_IO.Put
                    (Version.Diff.Diff_Working_Tree
                       (Version.Repository.Open, Pathspecs_From_Args (2)));
               elsif Count = 3 then
                  declare
                     Repo               :
                       constant Version.Repository.Repository_Handle :=
                         Version.Repository.Open;
                     Old_Id             : Version.Objects.Hex_Object_Id :=
                       Version.Objects.Zero_Object_Id;
                     New_Id             : Version.Objects.Hex_Object_Id :=
                       Version.Objects.Zero_Object_Id;
                     Revisions_Resolved : Boolean := False;
                  begin
                     begin
                        Old_Id :=
                          Version.Revisions.Resolve_Commit (Repo, Arg (2));
                        New_Id :=
                          Version.Revisions.Resolve_Commit (Repo, Arg (3));
                        Revisions_Resolved := True;
                     exception
                        when Ada.IO_Exceptions.Data_Error | Constraint_Error =>
                           Revisions_Resolved := False;
                     end;

                     if Revisions_Resolved then
                        Ada.Text_IO.Put
                          (Version.Diff.Diff_Commits (Repo, Old_Id, New_Id));
                     else
                        Ada.Text_IO.Put
                          (Version.Diff.Diff_Working_Tree
                             (Repo, Pathspecs_From_Args (2)));
                     end if;
                  end;
               else
                  Usage_Error ("too many diff arguments", Usage);
                  return;
               end if;
            end;

         elsif Command = "log" then
            declare
               Usage : constant String :=
                 "version log [--oneline] [--show-signature] [REV]";
               Oneline  : Boolean := False;
               Show_Sig : Boolean := False;
               Rev      : Unbounded_String;
               Have_Rev : Boolean := False;
               Bad      : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--oneline" then
                     Oneline := True;
                  elsif Arg (I) = "--show-signature" then
                     Show_Sig := True;
                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown log option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  elsif not Have_Rev then
                     Rev := To_Unbounded_String (Arg (I));
                     Have_Rev := True;
                  else
                     Usage_Error ("too many log arguments", Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Oneline and then Have_Rev then
                        Ada.Text_IO.Put
                          (Version.Log.Log_Oneline_From_Commit
                             (Repo,
                              Version.Revisions.Resolve_Commit
                                (Repo, To_String (Rev))));
                     elsif Oneline then
                        Ada.Text_IO.Put
                          (Version.Log.Log_Oneline_Head (Repo));
                     elsif Have_Rev then
                        Ada.Text_IO.Put
                          (Version.Log.Log_From_Commit
                             (Repo,
                              Version.Revisions.Resolve_Commit
                                (Repo, To_String (Rev)),
                              Show_Signature => Show_Sig));
                     else
                        Ada.Text_IO.Put
                          (Version.Log.Log_Head
                             (Repo, Show_Signature => Show_Sig));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "show" then
            declare
               Usage : constant String := "version show [REV]";
            begin
               if Count = 1 then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     Ada.Text_IO.Put
                       (Version.Show.Show_Commit
                          (Repo, Version.Show.Resolve_Revision (Repo, "HEAD")));
                  end;
               elsif Count = 2 then
                  if Arg (2)'Length > 0 and then Arg (2) (Arg (2)'First) = '-' then
                     Usage_Error ("unknown show option: " & Arg (2), Usage);
                     return;
                  end if;
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     Ada.Text_IO.Put
                       (Version.Show.Show_Commit
                          (Repo, Version.Show.Resolve_Revision (Repo, Arg (2))));
                  end;
               elsif Arg (2)'Length > 0 and then Arg (2) (Arg (2)'First) = '-' then
                  Usage_Error ("unknown show option: " & Arg (2), Usage);
                  return;
               else
                  Usage_Error ("too many show arguments", Usage);
                  return;
               end if;
            end;

         elsif Command = "archive" then
            Run_Archive_Command;

         elsif Command = "init" then
            declare
               Format_Prefix : constant String := "--object-format=";
               Ref_Prefix    : constant String := "--ref-format=";
               Usage         : constant String :=
                 "version init [--bare] [--object-format=(sha1|sha256)]"
                 & " [--ref-format=(files|reftable)] [PATH]";
               Bare          : Boolean := False;
               Target        : Unbounded_String := To_Unbounded_String (".");
               Operand_Count : Natural := 0;
               Object_Format : Version.Hash.Hash_Algorithm := Version.Hash.Sha1;
               Ref_Storage   : Version.Init.Ref_Storage_Kind :=
                 Version.Init.Files;
               Format_Set    : Boolean := False;
               Ref_Set       : Boolean := False;
               Skip_Next     : Boolean := False;
               Bad_Format    : Boolean := False;

               procedure Apply_Format (Value : String) is
               begin
                  if Format_Set then
                     Usage_Error ("duplicate option: --object-format", Usage);
                     Bad_Format := True;
                  elsif Value = "sha1" then
                     Object_Format := Version.Hash.Sha1;
                     Format_Set := True;
                  elsif Value = "sha256" then
                     Object_Format := Version.Hash.Sha256;
                     Format_Set := True;
                  else
                     Usage_Error
                       ("unknown object format: " & Value
                        & " (expected sha1 or sha256)", Usage);
                     Bad_Format := True;
                  end if;
               end Apply_Format;

               procedure Apply_Ref_Format (Value : String) is
               begin
                  if Ref_Set then
                     Usage_Error ("duplicate option: --ref-format", Usage);
                     Bad_Format := True;
                  elsif Value = "files" then
                     Ref_Storage := Version.Init.Files;
                     Ref_Set := True;
                  elsif Value = "reftable" then
                     Ref_Storage := Version.Init.Reftable;
                     Ref_Set := True;
                  else
                     Usage_Error
                       ("unknown ref format: " & Value
                        & " (expected files or reftable)", Usage);
                     Bad_Format := True;
                  end if;
               end Apply_Ref_Format;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     exit when Bad_Format;
                     if Skip_Next then
                        Skip_Next := False;

                     elsif Arg (I) = "--bare" then
                        if Bare then
                           Usage_Error ("duplicate option: --bare", Usage);
                           return;
                        end if;
                        Bare := True;

                     elsif Arg (I) = "--object-format" then
                        if I >= Count then
                           Usage_Error
                             ("--object-format requires a value", Usage);
                           return;
                        end if;
                        Apply_Format (Arg (I + 1));
                        Skip_Next := True;

                     elsif Arg (I)'Length > Format_Prefix'Length
                       and then Arg (I)
                                  (Arg (I)'First
                                   .. Arg (I)'First + Format_Prefix'Length - 1)
                                = Format_Prefix
                     then
                        Apply_Format
                          (Arg (I)
                             (Arg (I)'First + Format_Prefix'Length
                              .. Arg (I)'Last));

                     elsif Arg (I) = "--ref-format" then
                        if I >= Count then
                           Usage_Error
                             ("--ref-format requires a value", Usage);
                           return;
                        end if;
                        Apply_Ref_Format (Arg (I + 1));
                        Skip_Next := True;

                     elsif Arg (I)'Length > Ref_Prefix'Length
                       and then Arg (I)
                                  (Arg (I)'First
                                   .. Arg (I)'First + Ref_Prefix'Length - 1)
                                = Ref_Prefix
                     then
                        Apply_Ref_Format
                          (Arg (I)
                             (Arg (I)'First + Ref_Prefix'Length
                              .. Arg (I)'Last));

                     elsif Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error ("unknown init option: " & Arg (I), Usage);
                        return;

                     else
                        Operand_Count := Operand_Count + 1;
                        if Operand_Count = 1 then
                           Target := To_Unbounded_String (Arg (I));
                        else
                           Usage_Error ("too many init arguments", Usage);
                           return;
                        end if;
                     end if;
                  end loop;
               end if;

               if Bad_Format then
                  return;
               end if;

               if Bare then
                  Version.Init.Init_Bare
                    (To_String (Target), Object_Format, Ref_Storage);
                  Success_Line
                    ("initialized bare repository in " & To_String (Target));
               else
                  Version.Init.Init
                    (To_String (Target), Object_Format, Ref_Storage);
                  Success_Line
                    ("initialized repository in " & To_String (Target));
               end if;
            end;

         elsif Command = "history" then
            declare
               Usage : constant String := "version history";
            begin
               if Count /= 1 then
                  Usage_Error ("history takes no arguments", Usage);
                  return;
               end if;

               Print_History;
            end;

         elsif Command = "save" then
            declare
               Usage      : constant String :=
                 "version save [--amend] [--no-verify] [-m] MESSAGE";
               I          : Natural := 2;
               Amend      : Boolean := False;
               No_Verify  : Boolean := False;
               Message    : Unbounded_String;
               Has_Message : Boolean := False;
               Used_M     : Boolean := False;
            begin
               while I <= Count loop
                  if Arg (I) = "--amend" then
                     if Amend then
                        Usage_Error ("duplicate option: --amend", Usage);
                        return;
                     end if;

                     Amend := True;
                     I := I + 1;

                  elsif Arg (I) = "--no-verify" then
                     if No_Verify then
                        Usage_Error ("duplicate option: --no-verify", Usage);
                        return;
                     end if;

                     No_Verify := True;
                     I := I + 1;

                  elsif Arg (I) = "-m" then
                     if Used_M then
                        Usage_Error ("duplicate option: -m", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("-m requires a message", Usage);
                        return;
                     elsif Has_Message then
                        Usage_Error ("too many save arguments", Usage);
                        return;
                     end if;

                     Used_M := True;
                     Has_Message := True;
                     Message := To_Unbounded_String (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown save option: " & Arg (I), Usage);
                     return;

                  else
                     if Has_Message then
                        Usage_Error ("too many save arguments", Usage);
                        return;
                     end if;

                     Has_Message := True;
                     Message := To_Unbounded_String (Arg (I));
                     I := I + 1;
                  end if;
               end loop;

               if not Has_Message then
                  Usage_Error ("missing save message", Usage);
                  return;
               elsif Amend then
                  Version.Write.Save_Amend
                    (Message   => To_String (Message),
                     Run_Hooks => not No_Verify);
               else
                  Version.Write.Save
                    (Message   => To_String (Message),
                     Run_Hooks => not No_Verify);
               end if;

               Success_Line
                 ("saved "
                  & Short_Id
                      (Version.Refs.Current_Commit_Id
                         (Version.Repository.Open)));
            end;

         elsif Command = "branch" then
            declare
               Usage : constant String := "version branch SUBCOMMAND [ARGS]";
            begin
               if Count < 2 then
                  Usage_Error ("missing branch subcommand", Usage);
                  return;
               elsif Arg (2) = "list" then
                  if Count = 2 then
                     Print_Branch_List;
                  elsif Arg (3) = "--verbose" then
                     if Count = 3 then
                        Ada.Text_IO.Put (Version.Branch.List_Branches_Verbose_Text);
                     else
                        Usage_Error ("too many branch list arguments", Usage);
                        return;
                     end if;
                  elsif Arg (3) = "--contains" then
                     if Count = 3 then
                        Usage_Error ("missing branch list revision", Usage);
                        return;
                     elsif Count = 4 then
                        Ada.Text_IO.Put
                          (Version.Branch.Branches_Containing_Text (Arg (4)));
                     else
                        Usage_Error ("too many branch list arguments", Usage);
                        return;
                     end if;
                  elsif Arg (3) = "--merged" then
                     if Count = 3 then
                        Ada.Text_IO.Put (Version.Branch.Merged_Branches_Text);
                     elsif Count = 4 then
                        Ada.Text_IO.Put
                          (Version.Branch.Merged_Branches_Text (Arg (4)));
                     else
                        Usage_Error ("too many branch list arguments", Usage);
                        return;
                     end if;
                  elsif Arg (3) = "--no-merged" then
                     if Count = 3 then
                        Ada.Text_IO.Put (Version.Branch.Unmerged_Branches_Text);
                     elsif Count = 4 then
                        Ada.Text_IO.Put
                          (Version.Branch.Unmerged_Branches_Text (Arg (4)));
                     else
                        Usage_Error ("too many branch list arguments", Usage);
                        return;
                     end if;
                  elsif Arg (3)'Length > 0
                    and then Arg (3) (Arg (3)'First) = '-'
                  then
                     Usage_Error ("unknown branch list option: " & Arg (3), Usage);
                     return;
                  else
                     Usage_Error ("too many branch list arguments", Usage);
                     return;
                  end if;

               elsif Arg (2) = "current" then
                  if Count /= 2 then
                     Usage_Error ("too many branch current arguments", Usage);
                     return;
                  end if;
                  Ada.Text_IO.Put (Version.Branch.Current_Branch_Text);

               elsif Arg (2) = "exists" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch exists arguments", Usage);
                     return;
                  end if;
                  if not Version.Branch.Branch_Exists (Arg (3)) then
                     Ada.Command_Line.Set_Exit_Status (Command_Failure_Exit);
                  end if;

               elsif Arg (2) = "resolve" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch resolve arguments", Usage);
                     return;
                  end if;
                  Ada.Text_IO.Put (Version.Branch.Resolve_Branch_Text (Arg (3)));

               elsif Arg (2) = "upstream" then
                  if Count = 2 then
                     Ada.Text_IO.Put (Version.Branch.Upstream_Text);
                  elsif Count = 3 then
                     Ada.Text_IO.Put (Version.Branch.Upstream_Text (Arg (3)));
                  else
                     Usage_Error ("too many branch upstream arguments", Usage);
                     return;
                  end if;

               elsif Arg (2) = "contains" then
                  if Count = 2 then
                     Usage_Error ("missing branch contains revision", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch contains arguments", Usage);
                     return;
                  end if;
                  Ada.Text_IO.Put
                    (Version.Branch.Branches_Containing_Text (Arg (3)));

               elsif Arg (2) = "merged" then
                  if Count = 2 then
                     Ada.Text_IO.Put (Version.Branch.Merged_Branches_Text);
                  elsif Count = 3 then
                     Ada.Text_IO.Put (Version.Branch.Merged_Branches_Text (Arg (3)));
                  else
                     Usage_Error ("too many branch merged arguments", Usage);
                     return;
                  end if;

               elsif Arg (2) = "unmerged" then
                  if Count = 2 then
                     Ada.Text_IO.Put (Version.Branch.Unmerged_Branches_Text);
                  elsif Count = 3 then
                     Ada.Text_IO.Put
                       (Version.Branch.Unmerged_Branches_Text (Arg (3)));
                  else
                     Usage_Error ("too many branch unmerged arguments", Usage);
                     return;
                  end if;

               elsif Arg (2) = "create" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch create arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Create_Branch (Arg (3));
                  Success_Line ("created branch " & Arg (3));

               elsif Arg (2) = "switch" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch switch arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Switch_Branch (Arg (3));
                  Success_Line ("switched to branch " & Arg (3));

               elsif Arg (2) = "rename" then
                  if Count = 2 then
                     Usage_Error ("missing branch new name", Usage);
                     return;
                  elsif Count = 3 then
                     Version.Branch.Rename_Current_Branch (Arg (3));
                     Success_Line ("renamed current branch to " & Arg (3));
                  elsif Count = 4 then
                     Version.Branch.Rename_Branch
                       (Old_Name => Arg (3), New_Name => Arg (4));
                     Success_Line
                       ("renamed branch " & Arg (3) & " to " & Arg (4));
                  else
                     Usage_Error ("too many branch rename arguments", Usage);
                     return;
                  end if;

               elsif Arg (2) = "delete" then
                  declare
                     Force         : Boolean := False;
                     Name          : Unbounded_String;
                     Operand_Count : Natural := 0;
                  begin
                     for I in 3 .. Count loop
                        if Arg (I) = "--force" then
                           if Force then
                              Usage_Error ("duplicate option: --force", Usage);
                              return;
                           end if;
                           Force := True;
                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown branch delete option: " & Arg (I), Usage);
                           return;
                        else
                           Operand_Count := Operand_Count + 1;
                           if Operand_Count = 1 then
                              Name := To_Unbounded_String (Arg (I));
                           else
                              Usage_Error
                                ("too many branch delete arguments", Usage);
                              return;
                           end if;
                        end if;
                     end loop;

                     if Operand_Count = 0 then
                        Usage_Error ("missing branch name", Usage);
                        return;
                     end if;

                     Version.Branch.Delete_Branch
                       (Name => To_String (Name), Force => Force);
                     Success_Line ("deleted branch " & To_String (Name));
                  end;

               elsif Arg (2) = "set-upstream" then
                  if Count < 5 then
                     Usage_Error
                       ("missing branch upstream arguments", Usage);
                     return;
                  elsif Count > 5 then
                     Usage_Error
                       ("too many branch set-upstream arguments", Usage);
                     return;
                  end if;
                  Version.Tracking.Set_Upstream
                    (Repo        => Version.Repository.Open,
                     Branch_Name => Arg (3),
                     Remote_Name => Arg (4),
                     Merge_Ref   => "refs/heads/" & Arg (5));
                  Success_Line
                    ("set upstream for "
                     & Arg (3)
                     & " to "
                     & Arg (4)
                     & "/"
                     & Arg (5));

               elsif Arg (2) = "unset-upstream" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error
                       ("too many branch unset-upstream arguments", Usage);
                     return;
                  end if;
                  Version.Tracking.Unset_Upstream
                    (Repo => Version.Repository.Open, Branch_Name => Arg (3));
                  Success_Line ("unset upstream for " & Arg (3));

               elsif Arg (2) = "ahead-behind" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error
                       ("too many branch ahead-behind arguments", Usage);
                     return;
                  end if;
                  declare
                     Counts : constant Version.Tracking.Ahead_Behind :=
                       Version.Tracking.Count_Ahead_Behind
                         (Repo        => Version.Repository.Open,
                          Branch_Name => Arg (3));
                  begin
                     Ada.Text_IO.Put_Line
                       ("ahead "
                        & Natural_Image (Counts.Ahead)
                        & " behind "
                        & Natural_Image (Counts.Behind));
                  end;

               elsif Arg (2) = "update" then
                  if Count = 2 then
                     Usage_Error ("missing branch name", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch update arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Update_Current_Branch (Arg (3));
                  Success_Line ("updated current branch to " & Arg (3));

               elsif Arg (2) = "integrate" then
                  if Count = 2 then
                     Usage_Error ("missing branch integration target", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many branch integrate arguments", Usage);
                     return;
                  elsif Arg (3) = "--abort" then
                     Version.Branch.Abort_Integration;
                     Success_Line ("aborted branch integration");
                  elsif Arg (3) = "--finalize" then
                     Version.Branch.Finalize_Integration;
                     Success_Line ("finalized branch integration");
                  elsif Arg (3)'Length > 0
                    and then Arg (3) (Arg (3)'First) = '-'
                  then
                     Usage_Error
                       ("unknown branch integrate option: " & Arg (3), Usage);
                     return;
                  else
                     Version.Branch.Integrate_Branch (Arg (3));
                     Success_Line ("integrated branch " & Arg (3));
                  end if;

               elsif Arg (2) = "finalize" then
                  if Count /= 2 then
                     Usage_Error ("too many branch finalize arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Finalize_Integration;
                  Success_Line ("finalized branch integration");

               else
                  Usage_Error ("unknown branch subcommand: " & Arg (2), Usage);
                  return;
               end if;
            end;

         elsif Command = "merge" then
            declare
               Usage : constant String :=
                 "version merge [OPTIONS] [TARGET...] | version merge --continue"
                 & " | version merge --abort | version merge --quit";

               function After_Equals (Text, Prefix : String) return String is
               begin
                  return Text (Text'First + Prefix'Length .. Text'Last);
               end After_Equals;

               function Parse_Rename_Threshold
                 (Text : String; OK : out Boolean) return Natural
               is
                  Last  : Natural := Text'Last;
                  Value : Natural := 0;
               begin
                  OK := False;
                  if Text'Length = 0 then
                     return 0;
                  end if;

                  if Text (Last) = '%' then
                     if Text'Length = 1 then
                        return 0;
                     end if;
                     Last := Last - 1;
                  end if;

                  for I in Text'First .. Last loop
                     if Text (I) < '0' or else Text (I) > '9' then
                        return 0;
                     end if;

                     declare
                        Digit : constant Natural :=
                          Character'Pos (Text (I)) - Character'Pos ('0');
                     begin
                        if Value > 100 then
                           return 0;
                        end if;
                        Value := Value * 10 + Digit;
                     end;
                  end loop;

                  if Value > 100 then
                     return 0;
                  end if;

                  OK := True;
                  return Value;
               end Parse_Rename_Threshold;

               function Parse_Natural_Option
                 (Text : String; OK : out Boolean) return Natural
               is
                  Value : Natural := 0;
               begin
                  OK := False;
                  if Text'Length = 0 then
                     return 0;
                  end if;

                  for I in Text'Range loop
                     if Text (I) < '0' or else Text (I) > '9' then
                        return 0;
                     end if;

                     Value := Value * 10
                       + Character'Pos (Text (I)) - Character'Pos ('0');
                  end loop;

                  OK := True;
                  return Value;
               end Parse_Natural_Option;

               function Lower_Config (Text : String) return String is
                  Result : String := Version.Config.Trim (Text);
               begin
                  for I in Result'Range loop
                     if Result (I) in 'A' .. 'Z' then
                        Result (I) := Character'Val
                          (Character'Pos (Result (I))
                           - Character'Pos ('A') + Character'Pos ('a'));
                     end if;
                  end loop;
                  return Result;
               end Lower_Config;

               function Config_Value (Name : String) return String is
               begin
                  return Version.Config.Get_Value (Version.Repository.Open, Name);
               exception
                  when others =>
                     return "";
               end Config_Value;

               function Config_True (Text : String) return Boolean is
                  Value : constant String := Lower_Config (Text);
               begin
                  return Value = "true" or else Value = "1"
                    or else Value = "yes" or else Value = "on";
               end Config_True;

               function Config_False (Text : String) return Boolean is
                  Value : constant String := Lower_Config (Text);
               begin
                  return Value = "false" or else Value = "0"
                    or else Value = "no" or else Value = "off";
               end Config_False;

               function Parse_Recurse_Submodules_Mode
                 (Text : String; OK : out Boolean) return Boolean
               is
                  Value : constant String := Lower_Config (Text);
               begin
                  OK := True;
                  if Config_False (Value) then
                     return False;
                  elsif Config_True (Value)
                    or else Value = "on-demand"
                    or else Value = "check"
                  then
                     return True;
                  else
                     OK := False;
                     return False;
                  end if;
               end Parse_Recurse_Submodules_Mode;

               function Default_To_Upstream return Boolean is
                  Value : constant String := Config_Value ("merge.defaultToUpstream");
               begin
                  if Config_False (Value) then
                     return False;
                  else
                     return True;
                  end if;
               end Default_To_Upstream;

               function Default_Upstream_Target return String is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Branch_Name : constant String := Version.Refs.Current_Branch_Name (Repo);
                  Info : constant Version.Tracking.Upstream_Info :=
                    Version.Tracking.Upstream
                      (Repo => Repo, Branch_Name => Branch_Name);
               begin
                  return Version.Tracking.Remote_Tracking_Ref (Info);
               end Default_Upstream_Target;

               function Effective_Stat
                 (Options : Version.Branch.Merge_Options) return Boolean
               is
                  Stat_Config : constant String := Config_Value ("merge.stat");
                  Summary_Config : constant String := Config_Value ("merge.summary");
               begin
                  if Options.Stat_Explicit then
                     return Options.Stat;
                  elsif Config_True (Stat_Config) or else Config_True (Summary_Config) then
                     return True;
                  elsif Config_False (Stat_Config) or else Config_False (Summary_Config) then
                     return False;
                  else
                     return Options.Stat;
                  end if;
               end Effective_Stat;

               function Cleanup_Mode_OK (Mode : String) return Boolean is
                  Value : constant String := Lower_Config (Mode);
               begin
                  return Value = "default"
                    or else Value = "strip"
                    or else Value = "whitespace"
                    or else Value = "verbatim"
                    or else Value = "scissors";
               end Cleanup_Mode_OK;

               function Merge_Stat_Text
                 (Before_Id : Version.Objects.Hex_Object_Id;
                  After_Id  : Version.Objects.Hex_Object_Id) return String
               is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Old_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, Before_Id));
                  New_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, After_Id));
                  Paths : Version.Path_Safety.Path_Vector;
                  Text  : Ada.Strings.Unbounded.Unbounded_String;
                  Count : Natural := 0;

                  function Find_Path
                    (Items : Version.Objects.Tree_Entry_Vectors.Vector;
                     Path  : String) return Natural
                  is
                  begin
                     if not Items.Is_Empty then
                        for I in Items.First_Index .. Items.Last_Index loop
                           if To_String (Items.Element (I).Path) = Path then
                              return I;
                           end if;
                        end loop;
                     end if;

                     return Natural'Last;
                  end Find_Path;

                  function Changed (Path : String) return Boolean is
                     Old_Pos : constant Natural := Find_Path (Old_Items, Path);
                     New_Pos : constant Natural := Find_Path (New_Items, Path);
                  begin
                     if Old_Pos = Natural'Last or else New_Pos = Natural'Last then
                        return Old_Pos /= New_Pos;
                     else
                        return Old_Items.Element (Old_Pos).Id /= New_Items.Element (New_Pos).Id
                          or else Old_Items.Element (Old_Pos).Kind /= New_Items.Element (New_Pos).Kind
                          or else To_String (Old_Items.Element (Old_Pos).Mode)
                                  /= To_String (New_Items.Element (New_Pos).Mode);
                     end if;
                  end Changed;

                  procedure Add_Paths
                    (Items : Version.Objects.Tree_Entry_Vectors.Vector) is
                  begin
                     if not Items.Is_Empty then
                        for I in Items.First_Index .. Items.Last_Index loop
                           Append_Unique (Paths, To_String (Items.Element (I).Path));
                        end loop;
                     end if;
                  end Add_Paths;
               begin
                  Add_Paths (Old_Items);
                  Add_Paths (New_Items);

                  if not Paths.Is_Empty then
                     for I in Paths.First_Index .. Paths.Last_Index loop
                        if Changed (Paths.Element (I)) then
                           Count := Count + 1;
                           Ada.Strings.Unbounded.Append
                             (Text, " " & Paths.Element (I) & Character'Val (10));
                        end if;
                     end loop;
                  end if;

                  if Count > 0 then
                     Ada.Strings.Unbounded.Append
                       (Text, Natural'Image (Count) & " files changed");
                  end if;

                  return Ada.Strings.Unbounded.To_String (Text);
               end Merge_Stat_Text;

               procedure Print_Merge_Stat_If_Requested
                 (Options   : Version.Branch.Merge_Options;
                  Before_Id : Version.Objects.Hex_Object_Id)
               is
                  After_Text : constant String := Version.Refs.Current_Commit_Id
                    (Version.Repository.Open);
               begin
                  if Effective_Stat (Options)
                    and then Version.Objects.Is_Valid_Hex_Object_Id (After_Text)
                    and then After_Text /= To_String (Before_Id)
                  then
                     declare
                        Stat_Text : constant String :=
                          Merge_Stat_Text
                            (Before_Id => Before_Id,
                             After_Id  => Version.Objects.To_Object_Id (After_Text));
                     begin
                        if Stat_Text'Length > 0 then
                           Success_Line (Stat_Text);
                        end if;
                     end;
                  end if;
               end Print_Merge_Stat_If_Requested;

               procedure Put_Merge_Diagnostic (Text : String);

               function Git_Ort_Conflict_Class
                 (Kind : Version.Merge.Conflict_Kind) return String
               is
               begin
                  case Kind is
                     when Version.Merge.Content_Conflict =>
                        return "content";
                     when Version.Merge.Add_Add_Conflict =>
                        return "add/add";
                     when Version.Merge.Delete_Modify_Conflict =>
                        return "modify/delete";
                     when Version.Merge.Directory_File_Conflict =>
                        return "file/directory";
                     when Version.Merge.Binary_Conflict =>
                        return "content";
                  end case;
               end Git_Ort_Conflict_Class;

               function Git_Ort_Target_Label
                 (Target_Branch : Unbounded_String) return String
               is
                  Label : constant String := To_String (Target_Branch);
               begin
                  if Label'Length = 0 then
                     return "MERGE_HEAD";
                  else
                     return Label;
                  end if;
               end Git_Ort_Target_Label;

               function Has_Conflict_Stage
                 (Entries : Version.Staging.Index_Entry_Vectors.Vector;
                  Path    : String;
                  Stage   : Natural) return Boolean
               is
               begin
                  return Version.Staging.Find_Stage_Entry
                    (Entries => Entries,
                     Path    => Path,
                     Stage   => Stage) /= Natural'Last;
               end Has_Conflict_Stage;

               function Rename_Delete_Old_Path
                 (Repo    : Version.Repository.Repository_Handle;
                  Base_Id : Version.Objects.Hex_Object_Id;
                  Entries : Version.Staging.Index_Entry_Vectors.Vector;
                  Path    : String) return String
               is
                  Stage_1_Pos : constant Natural :=
                    Version.Staging.Find_Stage_Entry
                      (Entries => Entries,
                       Path    => Path,
                       Stage   => 1);
               begin
                  if Stage_1_Pos = Natural'Last then
                     return "";
                  end if;

                  declare
                     Stage_1 : constant Version.Staging.Index_Entry :=
                       Entries.Element (Stage_1_Pos);
                     Base_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                       Version.Objects.Flatten_Tree
                         (Repo    => Repo,
                          Tree_Id => Commit_Tree_Id (Repo, Base_Id));
                  begin
                     if not Base_Items.Is_Empty then
                        for I in Base_Items.First_Index .. Base_Items.Last_Index loop
                           declare
                              Item : constant Version.Objects.Tree_Entry :=
                                Base_Items.Element (I);
                              Base_Path : constant String := To_String (Item.Path);
                           begin
                              if Base_Path /= Path
                                and then Item.Id = Stage_1.Id
                                and then To_String (Item.Mode) = To_String (Stage_1.Mode)
                                and then Version.Staging.Find_Path
                                  (Entries => Entries, Path => Base_Path)
                                    = Natural'Last
                              then
                                 return Base_Path;
                              end if;
                           end;
                        end loop;
                     end if;
                  end;

                  return "";
               exception
                  when others =>
                     return "";
               end Rename_Delete_Old_Path;

               function Tree_Path_For_Stage_In_Commit
                 (Repo      : Version.Repository.Repository_Handle;
                  Commit_Id : Version.Objects.Hex_Object_Id;
                  Entries   : Version.Staging.Index_Entry_Vectors.Vector;
                  Path      : String;
                  Stage     : Natural) return String
               is
                  Stage_Pos : constant Natural :=
                    Version.Staging.Find_Stage_Entry
                      (Entries => Entries,
                       Path    => Path,
                       Stage   => Stage);
               begin
                  if Stage_Pos = Natural'Last then
                     return "";
                  end if;

                  declare
                     Stage_Entry : constant Version.Staging.Index_Entry :=
                       Entries.Element (Stage_Pos);
                     Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                       Version.Objects.Flatten_Tree
                         (Repo    => Repo,
                          Tree_Id => Commit_Tree_Id (Repo, Commit_Id));
                  begin
                     if not Items.Is_Empty then
                        for I in Items.First_Index .. Items.Last_Index loop
                           declare
                              Item : constant Version.Objects.Tree_Entry :=
                                Items.Element (I);
                              Item_Path : constant String := To_String (Item.Path);
                           begin
                              if Item_Path /= Path
                                and then Item.Id = Stage_Entry.Id
                                and then To_String (Item.Mode) = To_String (Stage_Entry.Mode)
                              then
                                 return Item_Path;
                              end if;
                           end;
                        end loop;
                     end if;
                  end;

                  return "";
               exception
                  when others =>
                     return "";
               end Tree_Path_For_Stage_In_Commit;

               function Rename_Old_Path_For_Stage
                 (Repo    : Version.Repository.Repository_Handle;
                  Base_Id : Version.Objects.Hex_Object_Id;
                  Entries : Version.Staging.Index_Entry_Vectors.Vector;
                  Path    : String;
                  Stage   : Natural) return String
               is
                  Stage_Pos : constant Natural :=
                    Version.Staging.Find_Stage_Entry
                      (Entries => Entries,
                       Path    => Path,
                       Stage   => Stage);
               begin
                  if Stage_Pos = Natural'Last then
                     return "";
                  end if;

                  declare
                     Stage_Entry : constant Version.Staging.Index_Entry :=
                       Entries.Element (Stage_Pos);
                     Base_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                       Version.Objects.Flatten_Tree
                         (Repo    => Repo,
                          Tree_Id => Commit_Tree_Id (Repo, Base_Id));
                  begin
                     if not Base_Items.Is_Empty then
                        for I in Base_Items.First_Index .. Base_Items.Last_Index loop
                           declare
                              Item : constant Version.Objects.Tree_Entry :=
                                Base_Items.Element (I);
                              Base_Path : constant String := To_String (Item.Path);
                           begin
                              if Base_Path /= Path
                                and then Item.Id = Stage_Entry.Id
                                and then To_String (Item.Mode) = To_String (Stage_Entry.Mode)
                                and then Version.Staging.Find_Path
                                  (Entries => Entries, Path => Base_Path)
                                    = Natural'Last
                              then
                                 return Base_Path;
                              end if;
                           end;
                        end loop;
                     end if;
                  end;

                  return "";
               exception
                  when others =>
                     return "";
               end Rename_Old_Path_For_Stage;

               function Is_Rename_Delete_Diagnostic
                 (Repo    : Version.Repository.Repository_Handle;
                  Base_Id : Version.Objects.Hex_Object_Id;
                  Item    : Version.Merge.Conflict;
                  Entries : Version.Staging.Index_Entry_Vectors.Vector) return Boolean
               is
                  Path : constant String := To_String (Item.Path);
               begin
                  return Item.Kind = Version.Merge.Delete_Modify_Conflict
                    and then Has_Conflict_Stage (Entries, Path, 2)
                              /= Has_Conflict_Stage (Entries, Path, 3)
                    and then Rename_Delete_Old_Path
                      (Repo    => Repo,
                       Base_Id => Base_Id,
                       Entries => Entries,
                       Path    => Path)'Length > 0;
               end Is_Rename_Delete_Diagnostic;

               function Is_File_Location_Diagnostic
                 (Repo       : Version.Repository.Repository_Handle;
                  Current_Id : Version.Objects.Hex_Object_Id;
                  Target_Id  : Version.Objects.Hex_Object_Id;
                  Item       : Version.Merge.Conflict;
                  Entries    : Version.Staging.Index_Entry_Vectors.Vector) return Boolean
               is
                  Path : constant String := To_String (Item.Path);
                  Has_Current : constant Boolean :=
                    Has_Conflict_Stage (Entries, Path, 2);
                  Has_Target : constant Boolean :=
                    Has_Conflict_Stage (Entries, Path, 3);
               begin
                  if Item.Kind /= Version.Merge.Add_Add_Conflict
                    or else Has_Current = Has_Target
                  then
                     return False;
                  elsif Has_Current then
                     return Tree_Path_For_Stage_In_Commit
                       (Repo      => Repo,
                        Commit_Id => Current_Id,
                        Entries   => Entries,
                        Path      => Path,
                        Stage     => 2)'Length > 0;
                  else
                     return Tree_Path_For_Stage_In_Commit
                       (Repo      => Repo,
                        Commit_Id => Target_Id,
                        Entries   => Entries,
                        Path      => Path,
                        Stage     => 3)'Length > 0;
                  end if;
               end Is_File_Location_Diagnostic;

               function Should_Print_Auto_Merging
                 (Repo       : Version.Repository.Repository_Handle;
                  Current_Id : Version.Objects.Hex_Object_Id;
                  Target_Id  : Version.Objects.Hex_Object_Id;
                  Base_Id    : Version.Objects.Hex_Object_Id;
                  Item       : Version.Merge.Conflict;
                  Entries    : Version.Staging.Index_Entry_Vectors.Vector) return Boolean
               is
               begin
                  return not Is_Rename_Delete_Diagnostic
                    (Repo    => Repo,
                     Base_Id => Base_Id,
                     Item    => Item,
                     Entries => Entries)
                    and then not Is_File_Location_Diagnostic
                      (Repo       => Repo,
                       Current_Id => Current_Id,
                       Target_Id  => Target_Id,
                       Item       => Item,
                       Entries    => Entries);
               end Should_Print_Auto_Merging;

               procedure Put_Git_Ort_Conflict_Message
                 (Repo         : Version.Repository.Repository_Handle;
                  Current_Id   : Version.Objects.Hex_Object_Id;
                  Target_Id    : Version.Objects.Hex_Object_Id;
                  Base_Id      : Version.Objects.Hex_Object_Id;
                  Item         : Version.Merge.Conflict;
                  Entries      : Version.Staging.Index_Entry_Vectors.Vector;
                  Target_Label : String)
               is
                  Path : constant String := To_String (Item.Path);
               begin
                  case Item.Kind is
                     when Version.Merge.Delete_Modify_Conflict =>
                        declare
                           Has_Current : constant Boolean :=
                             Has_Conflict_Stage (Entries, Path, 2);
                           Has_Target : constant Boolean :=
                             Has_Conflict_Stage (Entries, Path, 3);
                           Old_Path : constant String :=
                             Rename_Delete_Old_Path
                               (Repo    => Repo,
                                Base_Id => Base_Id,
                                Entries => Entries,
                                Path    => Path);
                        begin
                           if Old_Path'Length > 0
                             and then (Has_Current xor Has_Target)
                           then
                              if Has_Current then
                                 Put_Merge_Diagnostic
                                   ("CONFLICT (rename/delete): " & Old_Path
                                    & " renamed to " & Path
                                    & " in HEAD, but deleted in "
                                    & Target_Label & ".");
                              else
                                 Put_Merge_Diagnostic
                                   ("CONFLICT (rename/delete): " & Old_Path
                                    & " renamed to " & Path
                                    & " in " & Target_Label
                                    & ", but deleted in HEAD.");
                              end if;
                           elsif (not Has_Current) and then Has_Target then
                              Put_Merge_Diagnostic
                                ("CONFLICT (modify/delete): " & Path
                                 & " deleted in HEAD and modified in "
                                 & Target_Label & ".  Version " & Target_Label
                                 & " of " & Path & " left in tree.");
                           elsif Has_Current and then not Has_Target then
                              Put_Merge_Diagnostic
                                ("CONFLICT (modify/delete): " & Path
                                 & " deleted in " & Target_Label
                                 & " and modified in HEAD.  Version HEAD of "
                                 & Path & " left in tree.");
                           else
                              Put_Merge_Diagnostic
                                ("CONFLICT (modify/delete): Merge conflict in "
                                 & Path);
                           end if;
                        end;
                     when Version.Merge.Add_Add_Conflict =>
                        declare
                           Has_Current : constant Boolean :=
                             Has_Conflict_Stage (Entries, Path, 2);
                           Has_Target : constant Boolean :=
                             Has_Conflict_Stage (Entries, Path, 3);
                           Current_Old_Path : constant String :=
                             Tree_Path_For_Stage_In_Commit
                               (Repo      => Repo,
                                Commit_Id => Current_Id,
                                Entries   => Entries,
                                Path      => Path,
                                Stage     => 2);
                           Target_Old_Path : constant String :=
                             Tree_Path_For_Stage_In_Commit
                               (Repo      => Repo,
                                Commit_Id => Target_Id,
                                Entries   => Entries,
                                Path      => Path,
                                Stage     => 3);
                        begin
                           if Has_Current
                             and then not Has_Target
                             and then Current_Old_Path'Length > 0
                           then
                              Put_Merge_Diagnostic
                                ("CONFLICT (file location): " & Current_Old_Path
                                 & " added in HEAD inside a directory that was renamed in "
                                 & Target_Label
                                 & ", suggesting it should perhaps be moved to "
                                 & Path & ".");
                           elsif Has_Target
                             and then not Has_Current
                             and then Target_Old_Path'Length > 0
                           then
                              Put_Merge_Diagnostic
                                ("CONFLICT (file location): " & Target_Old_Path
                                 & " added in " & Target_Label
                                 & " inside a directory that was renamed in HEAD, suggesting it should"
                                 & " perhaps be moved to "
                                 & Path & ".");
                           else
                              Put_Merge_Diagnostic
                                ("CONFLICT (add/add): Merge conflict in " & Path);
                           end if;
                        end;
                     when Version.Merge.Directory_File_Conflict =>
                        Put_Merge_Diagnostic
                          ("CONFLICT (file/directory): directory/file conflict in "
                           & Path);
                     when others =>
                        Put_Merge_Diagnostic
                          ("CONFLICT ("
                           & Git_Ort_Conflict_Class (Item.Kind)
                           & "): Merge conflict in "
                           & Path);
                  end case;
               end Put_Git_Ort_Conflict_Message;

               procedure Put_Merge_Diagnostic (Text : String) is
               begin
                  Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
               end Put_Merge_Diagnostic;

               Last_Merge_Was_Fast_Forward : Boolean := False;
               Last_Merge_Was_Already_Up_To_Date : Boolean := False;

               procedure Print_Git_Ort_Conflict_Output is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Current_Id : Version.Objects.Hex_Object_Id;
                  Target_Id  : Version.Objects.Hex_Object_Id;
                  Base_Id    : Version.Objects.Hex_Object_Id;
                  Target_Branch : Unbounded_String;
                  Conflicts  : Version.Merge.Conflict_Vectors.Vector;
                  Entries    : Version.Staging.Index_Entry_Vectors.Vector;
                  Reported   : Version.Path_Safety.Path_Vector;

                  function Path_Reported (Path : String) return Boolean is
                  begin
                     if not Reported.Is_Empty then
                        for I in Reported.First_Index .. Reported.Last_Index loop
                           if Reported.Element (I) = Path then
                              return True;
                           end if;
                        end loop;
                     end if;

                     return False;
                  end Path_Reported;

                  procedure Mark_Reported (Path : String) is
                  begin
                     Append_Unique (Reported, Path);
                  end Mark_Reported;

                  procedure Try_Print_Rename_Rename
                    (Item    : Version.Merge.Conflict;
                     Printed : out Boolean)
                  is
                     Path : constant String := To_String (Item.Path);
                     Has_Current : constant Boolean :=
                       Has_Conflict_Stage (Entries, Path, 2);
                     Has_Target : constant Boolean :=
                       Has_Conflict_Stage (Entries, Path, 3);
                     Current_Path : Unbounded_String;
                     Target_Path  : Unbounded_String;
                     Old_Path     : Unbounded_String;
                  begin
                     Printed := False;

                     if Item.Kind /= Version.Merge.Content_Conflict
                       or else Has_Current = Has_Target
                     then
                        return;
                     end if;

                     if Has_Current then
                        Current_Path := To_Unbounded_String (Path);
                        Old_Path := To_Unbounded_String
                          (Rename_Old_Path_For_Stage
                             (Repo    => Repo,
                              Base_Id => Base_Id,
                              Entries => Entries,
                              Path    => Path,
                              Stage   => 2));
                     else
                        Target_Path := To_Unbounded_String (Path);
                        Old_Path := To_Unbounded_String
                          (Rename_Old_Path_For_Stage
                             (Repo    => Repo,
                              Base_Id => Base_Id,
                              Entries => Entries,
                              Path    => Path,
                              Stage   => 3));
                     end if;

                     if Length (Old_Path) = 0 or else Conflicts.Is_Empty then
                        return;
                     end if;

                     for Other_Index in Conflicts.First_Index .. Conflicts.Last_Index loop
                        declare
                           Other : constant Version.Merge.Conflict :=
                             Conflicts.Element (Other_Index);
                           Other_Path : constant String := To_String (Other.Path);
                           Other_Has_Current : constant Boolean :=
                             Has_Conflict_Stage (Entries, Other_Path, 2);
                           Other_Has_Target : constant Boolean :=
                             Has_Conflict_Stage (Entries, Other_Path, 3);
                           Other_Old_Path : Unbounded_String;
                        begin
                           if Other_Path /= Path
                             and then not Path_Reported (Other_Path)
                             and then Other.Kind = Version.Merge.Content_Conflict
                             and then Other_Has_Current /= Other_Has_Target
                             and then Other_Has_Current /= Has_Current
                           then
                              Other_Old_Path := To_Unbounded_String
                                (Rename_Old_Path_For_Stage
                                   (Repo    => Repo,
                                    Base_Id => Base_Id,
                                    Entries => Entries,
                                    Path    => Other_Path,
                                    Stage   => (if Other_Has_Current then 2 else 3)));

                              if To_String (Other_Old_Path) = To_String (Old_Path) then
                                 if Other_Has_Current then
                                    Current_Path := To_Unbounded_String (Other_Path);
                                 else
                                    Target_Path := To_Unbounded_String (Other_Path);
                                 end if;

                                 Put_Merge_Diagnostic
                                   ("CONFLICT (rename/rename): "
                                    & To_String (Old_Path)
                                    & " renamed to " & To_String (Current_Path)
                                    & " in HEAD and to " & To_String (Target_Path)
                                    & " in " & Git_Ort_Target_Label (Target_Branch)
                                    & ".");
                                 Mark_Reported (Path);
                                 Mark_Reported (Other_Path);
                                 Printed := True;
                                 return;
                              end if;
                           end if;
                        end;
                     end loop;
                  end Try_Print_Rename_Rename;
               begin
                  if not Version.Merge_State.State_Exists (Repo) then
                     return;
                  end if;

                  Version.Merge_State.Read_State
                    (Repo          => Repo,
                     Current_Id    => Current_Id,
                     Target_Id     => Target_Id,
                     Base_Id       => Base_Id,
                     Target_Branch => Target_Branch,
                     Conflicts     => Conflicts);
                  Entries := Version.Staging.Load (Repo);

                  if not Conflicts.Is_Empty then
                     for Index in Conflicts.First_Index .. Conflicts.Last_Index loop
                        declare
                           Item : constant Version.Merge.Conflict :=
                             Conflicts.Element (Index);
                           Path : constant String := To_String (Item.Path);
                        begin
                           if not Path_Reported (Path) then
                              declare
                                 Printed_Rename_Rename : Boolean;
                              begin
                                 Try_Print_Rename_Rename
                                   (Item    => Item,
                                    Printed => Printed_Rename_Rename);

                                 if not Printed_Rename_Rename then
                                    if Item.Kind = Version.Merge.Binary_Conflict then
                                       Put_Merge_Diagnostic
                                         ("warning: Cannot merge binary files: " & Path
                                          & " (HEAD vs "
                                          & Git_Ort_Target_Label (Target_Branch) & ")");
                                    end if;

                                    if Should_Print_Auto_Merging
                                      (Repo       => Repo,
                                       Current_Id => Current_Id,
                                       Target_Id  => Target_Id,
                                       Base_Id    => Base_Id,
                                       Item       => Item,
                                       Entries    => Entries)
                                    then
                                       Put_Merge_Diagnostic ("Auto-merging " & Path);
                                    end if;

                                    Put_Git_Ort_Conflict_Message
                                      (Repo         => Repo,
                                       Current_Id   => Current_Id,
                                       Target_Id    => Target_Id,
                                       Base_Id      => Base_Id,
                                       Item         => Item,
                                       Entries      => Entries,
                                       Target_Label => Git_Ort_Target_Label (Target_Branch));
                                    Mark_Reported (Path);
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end if;

                  Put_Merge_Diagnostic
                    ("Automatic merge failed; fix conflicts and then commit the result.");
               exception
                  when others =>
                     null;
               end Print_Git_Ort_Conflict_Output;

               function Run_Merge_One
                 (Target  : String;
                  Options : Version.Branch.Merge_Options) return Boolean
               is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Before_Text : constant String :=
                    Version.Refs.Current_Commit_Id (Repo);
                  Before_Id : constant Version.Objects.Hex_Object_Id :=
                    Version.Objects.To_Object_Id (Before_Text);
               begin
                  Last_Merge_Was_Fast_Forward := False;
                  Last_Merge_Was_Already_Up_To_Date := False;

                  begin
                     Version.Branch.Merge (Target => Target, Options => Options);
                  exception
                     when E : Ada.IO_Exceptions.Data_Error =>
                        if Ada.Exceptions.Exception_Message (E)
                          = "cannot merge: conflicts recorded"
                        then
                           Print_Git_Ort_Conflict_Output;
                           Set_Command_Failure;
                           return False;
                        end if;
                        raise;
                  end;

                  declare
                     After_Text : constant String :=
                       Version.Refs.Current_Commit_Id (Repo);
                  begin
                     if Version.Objects.Is_Valid_Hex_Object_Id (Before_Text)
                       and then Version.Objects.Is_Valid_Hex_Object_Id (After_Text)
                     then
                        if After_Text = Before_Text then
                           Last_Merge_Was_Already_Up_To_Date :=
                             not Options.Squash and then not Options.No_Commit;
                        else
                           declare
                              After_Id : constant Version.Objects.Hex_Object_Id :=
                                Version.Objects.To_Object_Id (After_Text);
                           begin
                              Last_Merge_Was_Fast_Forward :=
                                Version.History.Parent_Commits
                                  (Repo      => Repo,
                                   Commit_Id => After_Id).Length = 1
                                and then Version.History.Is_Ancestor
                                  (Repo       => Repo,
                                   Base_Id    => Before_Id,
                                   Derived_Id => After_Id);
                           end;
                        end if;
                     end if;
                  end;

                  Print_Merge_Stat_If_Requested (Options, Before_Id);
                  return True;
               end Run_Merge_One;

               function Run_Merge_Multiple
                 (Targets : Version.Branch.Merge_Target_Vectors.Vector;
                  Options : Version.Branch.Merge_Options) return Boolean
               is
                  Before_Id : constant Version.Objects.Hex_Object_Id :=
                    Version.Objects.To_Object_Id
                      (Version.Refs.Current_Commit_Id (Version.Repository.Open));
               begin
                  Last_Merge_Was_Fast_Forward := False;
                  Last_Merge_Was_Already_Up_To_Date := False;

                  begin
                     Version.Branch.Merge_Multiple (Targets => Targets, Options => Options);
                  exception
                     when E : Ada.IO_Exceptions.Data_Error =>
                        if Ada.Strings.Fixed.Index
                          (Ada.Exceptions.Exception_Message (E),
                           "conflicts recorded") /= 0
                        then
                           Print_Git_Ort_Conflict_Output;
                           Set_Command_Failure;
                           return False;
                        end if;
                        raise;
                  end;

                  Print_Merge_Stat_If_Requested (Options, Before_Id);
                  return True;
               end Run_Merge_Multiple;

               procedure Apply_Strategy
                 (Name    : String;
                  Options : in out Version.Branch.Merge_Options;
                  OK      : out Boolean) is
               begin
                  OK := True;
                  if Name = "ours" then
                     Options.Strategy := Version.Branch.Strategy_Ours;
                     Options.Strategy_Explicit := True;
                     Options.Strategy_Ours := True;
                  elsif Name = "ort" then
                     Options.Strategy := Version.Branch.Strategy_Ort;
                     Options.Strategy_Explicit := True;
                  elsif Name = "recursive" then
                     Options.Strategy := Version.Branch.Strategy_Recursive;
                     Options.Strategy_Explicit := True;
                  elsif Name = "resolve" then
                     Options.Strategy := Version.Branch.Strategy_Resolve;
                     Options.Strategy_Explicit := True;
                  elsif Name = "octopus" then
                     Options.Strategy := Version.Branch.Strategy_Octopus;
                     Options.Strategy_Explicit := True;
                  elsif Name = "subtree" then
                     Options.Strategy := Version.Branch.Strategy_Subtree;
                     Options.Strategy_Explicit := True;
                     Options.Subtree := True;
                  else
                     OK := False;
                  end if;
               end Apply_Strategy;

               procedure Apply_Conflict_Style
                 (Name    : String;
                  Options : in out Version.Branch.Merge_Options;
                  OK      : out Boolean) is
               begin
                  OK := True;
                  if Name = "merge" then
                     Options.Conflict_Style :=
                       Version.Branch.Conflict_Style_Merge;
                  elsif Name = "diff3" then
                     Options.Conflict_Style :=
                       Version.Branch.Conflict_Style_Diff3;
                  elsif Name = "zdiff3" then
                     Options.Conflict_Style :=
                       Version.Branch.Conflict_Style_ZDiff3;
                  else
                     OK := False;
                  end if;
               end Apply_Conflict_Style;

               procedure Apply_Strategy_Option
                 (Name    : String;
                  Options : in out Version.Branch.Merge_Options;
                  OK      : out Boolean) is
               begin
                  OK := True;
                  if Name = "ours" then
                     Options.Conflict_Favor := Version.Branch.Favor_Current;
                     Options.Conflict_Favor_Explicit := True;
                  elsif Name = "theirs" then
                     Options.Conflict_Favor := Version.Branch.Favor_Target;
                     Options.Conflict_Favor_Explicit := True;
                  elsif Name = "ignore-space-change" then
                     Options.Whitespace :=
                       Version.Branch.Whitespace_Ignore_Space_Change;
                  elsif Name = "ignore-all-space" then
                     Options.Whitespace :=
                       Version.Branch.Whitespace_Ignore_All_Space;
                  elsif Name = "ignore-space-at-eol" then
                     Options.Whitespace :=
                       Version.Branch.Whitespace_Ignore_Space_At_EOL;
                  elsif Name = "ignore-cr-at-eol" then
                     Options.Whitespace :=
                       Version.Branch.Whitespace_Ignore_CR_At_EOL;
                  elsif Name = "renormalize" then
                     Options.Renormalize := True;
                     Options.Renormalize_Explicit := True;
                  elsif Name = "no-renormalize" then
                     Options.Renormalize := False;
                     Options.Renormalize_Explicit := True;
                  elsif Name = "find-renames" or else Name = "renames" then
                     Options.Detect_Renames := True;
                     Options.Detect_Renames_Explicit := True;
                  elsif Name'Length > 13
                    and then Name (Name'First .. Name'First + 12)
                             = "find-renames="
                  then
                     declare
                        Threshold_OK : Boolean := False;
                        Threshold : constant Natural :=
                          Parse_Rename_Threshold
                            (Name (Name'First + 13 .. Name'Last), Threshold_OK);
                     begin
                        if Threshold_OK then
                           Options.Detect_Renames := True;
                           Options.Detect_Renames_Explicit := True;
                           Options.Rename_Threshold := Threshold;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name'Length > 8
                    and then Name (Name'First .. Name'First + 7)
                             = "renames="
                  then
                     declare
                        Threshold_OK : Boolean := False;
                        Threshold : constant Natural :=
                          Parse_Rename_Threshold
                            (Name (Name'First + 8 .. Name'Last), Threshold_OK);
                     begin
                        if Threshold_OK then
                           Options.Detect_Renames := True;
                           Options.Detect_Renames_Explicit := True;
                           Options.Rename_Threshold := Threshold;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name = "find-copies" or else Name = "copies"
                    or else Name = "find-copies-harder"
                  then
                     Options.Detect_Copies := True;
                     Options.Detect_Copies_Explicit := True;
                  elsif Name'Length > 12
                    and then Name (Name'First .. Name'First + 11)
                             = "find-copies="
                  then
                     declare
                        Threshold_OK : Boolean := False;
                        Threshold : constant Natural :=
                          Parse_Rename_Threshold
                            (Name (Name'First + 12 .. Name'Last), Threshold_OK);
                     begin
                        if Threshold_OK then
                           Options.Detect_Copies := True;
                           Options.Detect_Copies_Explicit := True;
                           Options.Rename_Threshold := Threshold;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name'Length > 7
                    and then Name (Name'First .. Name'First + 6)
                             = "copies="
                  then
                     declare
                        Threshold_OK : Boolean := False;
                        Threshold : constant Natural :=
                          Parse_Rename_Threshold
                            (Name (Name'First + 7 .. Name'Last), Threshold_OK);
                     begin
                        if Threshold_OK then
                           Options.Detect_Copies := True;
                           Options.Detect_Copies_Explicit := True;
                           Options.Rename_Threshold := Threshold;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name = "no-copies" then
                     Options.Detect_Copies := False;
                     Options.Detect_Copies_Explicit := True;
                  elsif Name = "break-rewrites" or else Name = "no-break-rewrites" then
                     null;
                  elsif Name'Length > 15
                    and then Name (Name'First .. Name'First + 14)
                             = "break-rewrites="
                  then
                     declare
                        Ignore_OK : Boolean := False;
                        Ignore : constant Natural :=
                          Parse_Rename_Threshold
                            (Name (Name'First + 15 .. Name'Last), Ignore_OK);
                     begin
                        if not Ignore_OK then
                           OK := False;
                        end if;
                     end;
                  elsif Name = "directory-renames" then
                     Options.Directory_Renames := Version.Branch.Directory_Renames_Apply;
                  elsif Name = "no-directory-renames" then
                     Options.Directory_Renames := Version.Branch.Directory_Renames_Disabled;
                  elsif Name'Length > 18
                    and then Name (Name'First .. Name'First + 17)
                             = "directory-renames="
                  then
                     declare
                        Mode : constant String := Name (Name'First + 18 .. Name'Last);
                     begin
                        if Mode = "true" or else Mode = "1"
                          or else Mode = "yes" or else Mode = "on"
                        then
                           Options.Directory_Renames := Version.Branch.Directory_Renames_Apply;
                        elsif Mode = "false" or else Mode = "0"
                          or else Mode = "no" or else Mode = "off"
                        then
                           Options.Directory_Renames := Version.Branch.Directory_Renames_Disabled;
                        elsif Mode = "conflict" then
                           Options.Directory_Renames := Version.Branch.Directory_Renames_Conflict;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name = "recurse-submodules" then
                     Options.Recurse_Submodules := True;
                     Options.Recurse_Submodules_Explicit := True;
                  elsif Name = "no-recurse-submodules" then
                     Options.Recurse_Submodules := False;
                     Options.Recurse_Submodules_Explicit := True;
                  elsif Name'Length > 19
                    and then Name (Name'First .. Name'First + 18)
                             = "recurse-submodules="
                  then
                     declare
                        Mode_OK : Boolean := False;
                        Enabled : constant Boolean :=
                          Parse_Recurse_Submodules_Mode
                            (Name (Name'First + 19 .. Name'Last), Mode_OK);
                     begin
                        if Mode_OK then
                           Options.Recurse_Submodules := Enabled;
                           Options.Recurse_Submodules_Explicit := True;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name = "no-renames" then
                     Options.Detect_Renames := False;
                     Options.Detect_Renames_Explicit := True;
                  elsif Name = "patience" then
                     Options.Algorithm := Version.Branch.Diff_Algorithm_Patience;
                  elsif Name = "histogram" then
                     Options.Algorithm := Version.Branch.Diff_Algorithm_Histogram;
                  elsif Name = "minimal" then
                     Options.Algorithm := Version.Branch.Diff_Algorithm_Minimal;
                  elsif Name = "myers" then
                     Options.Algorithm := Version.Branch.Diff_Algorithm_Myers;
                  elsif Name'Length > 13
                    and then Name (Name'First .. Name'First + 12)
                             = "rename-limit="
                  then
                     declare
                        Limit_OK : Boolean := False;
                        Limit : constant Natural :=
                          Parse_Natural_Option
                            (Name (Name'First + 13 .. Name'Last), Limit_OK);
                     begin
                        if Limit_OK then
                           Options.Rename_Limit := Limit;
                           Options.Rename_Limit_Explicit := True;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name'Length > 15
                    and then Name (Name'First .. Name'First + 14)
                             = "diff-algorithm="
                  then
                     declare
                        Algorithm : constant String :=
                          Name (Name'First + 15 .. Name'Last);
                     begin
                        if Algorithm = "patience" then
                           Options.Algorithm :=
                             Version.Branch.Diff_Algorithm_Patience;
                        elsif Algorithm = "histogram" then
                           Options.Algorithm :=
                             Version.Branch.Diff_Algorithm_Histogram;
                        elsif Algorithm = "minimal" then
                           Options.Algorithm :=
                             Version.Branch.Diff_Algorithm_Minimal;
                        elsif Algorithm = "myers" then
                           Options.Algorithm :=
                             Version.Branch.Diff_Algorithm_Myers;
                        elsif Algorithm = "default" then
                           Options.Algorithm :=
                             Version.Branch.Diff_Algorithm_Default;
                        else
                           OK := False;
                        end if;
                     end;
                  elsif Name = "subtree" then
                     Options.Subtree := True;
                  elsif Name'Length > 8
                    and then Name (Name'First .. Name'First + 7)
                             = "subtree="
                  then
                     declare
                        Prefix : constant String :=
                          Name (Name'First + 8 .. Name'Last);
                     begin
                        if Prefix'Length = 0 then
                           OK := False;
                        else
                           Options.Subtree := True;
                           Options.Subtree_Prefix :=
                             Ada.Strings.Unbounded.To_Unbounded_String (Prefix);
                        end if;
                     end;
                  else
                     OK := False;
                  end if;
               end Apply_Strategy_Option;
            begin
               if Count >= 2 and then Arg (2) = "--continue" then
                  declare
                     Run_Hooks : Boolean := True;
                  begin
                     if Count > 3 then
                        Usage_Error ("too many merge --continue arguments", Usage);
                        return;
                     elsif Count = 3 then
                        if Arg (3) = "--no-verify" then
                           Run_Hooks := False;
                        elsif Arg (3) = "--verify" then
                           Run_Hooks := True;
                        else
                           Usage_Error
                             ("unknown merge --continue option: " & Arg (3), Usage);
                           return;
                        end if;
                     end if;

                     Version.Branch.Finalize_Integration (Run_Hooks => Run_Hooks);
                     Success_Line ("continued merge");
                  end;
               elsif Count >= 2 and then Arg (2) = "--abort" then
                  if Count /= 2 then
                     Usage_Error ("too many merge --abort arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Abort_Integration;
                  Success_Line ("aborted merge");
               elsif Count >= 2 and then Arg (2) = "--quit" then
                  if Count /= 2 then
                     Usage_Error ("too many merge --quit arguments", Usage);
                     return;
                  end if;
                  Version.Branch.Quit_Integration;
                  Success_Line ("quit merge");
               else
                  declare
                     Options : Version.Branch.Merge_Options;
                     Targets : Version.Branch.Merge_Target_Vectors.Vector;
                     I       : Positive := 2;
                  begin
                     while I <= Count loop
                        declare
                           A : constant String := Arg (I);
                           OK : Boolean := True;
                        begin
                           if A = "--ff" then
                              Options.Fast_Forward :=
                                Version.Branch.Fast_Forward_Allowed;
                              Options.Fast_Forward_Explicit := True;
                           elsif A = "--ff-only" then
                              Options.Fast_Forward :=
                                Version.Branch.Fast_Forward_Only;
                              Options.Fast_Forward_Explicit := True;
                           elsif A = "--no-ff" then
                              Options.Fast_Forward :=
                                Version.Branch.Fast_Forward_Disabled;
                              Options.Fast_Forward_Explicit := True;
                           elsif A = "--squash" then
                              Options.Squash := True;
                              Options.Squash_Explicit := True;
                           elsif A = "--no-commit" then
                              Options.No_Commit := True;
                              Options.No_Commit_Explicit := True;
                           elsif A = "--commit" then
                              Options.No_Commit := False;
                              Options.No_Commit_Explicit := True;
                           elsif A = "--allow-unrelated-histories" then
                              Options.Allow_Unrelated_Histories := True;
                           elsif A = "--no-verify" then
                              Options.Run_Hooks := False;
                           elsif A = "--verify" then
                              Options.Run_Hooks := True;
                           elsif A = "--quiet" or else A = "-q" then
                              Quiet_Mode := True;
                           elsif A = "--verbose" or else A = "-v"
                             or else A = "--progress"
                             or else A = "--no-progress"
                           then
                              null;
                           elsif A = "--autostash" then
                              Options.Autostash := True;
                              Options.Autostash_Explicit := True;
                           elsif A = "--no-autostash" then
                              Options.Autostash := False;
                              Options.Autostash_Explicit := True;
                           elsif A = "--stat" or else A = "--summary" then
                              Options.Stat := True;
                              Options.Stat_Explicit := True;
                           elsif A = "--no-stat" or else A = "--no-summary" then
                              Options.Stat := False;
                              Options.Stat_Explicit := True;
                           elsif A = "--compact-summary" then
                              Options.Stat := True;
                              Options.Stat_Explicit := True;
                              Options.Compact_Summary := True;
                           elsif A = "--log" then
                              Options.Log_Limit := 20;
                              Options.Log_Explicit := True;
                           elsif A'Length > 6
                             and then A (A'First .. A'First + 5) = "--log="
                           then
                              declare
                                 Log_OK : Boolean := False;
                                 Log_Limit : constant Natural :=
                                   Parse_Natural_Option
                                     (After_Equals (A, "--log="), Log_OK);
                              begin
                                 if Log_OK then
                                    Options.Log_Limit := Log_Limit;
                                    Options.Log_Explicit := True;
                                 else
                                    Usage_Error
                                      ("unsupported merge log count: "
                                       & After_Equals (A, "--log="), Usage);
                                    return;
                                 end if;
                              end;
                           elsif A = "--no-log" then
                              Options.Log_Limit := 0;
                              Options.Log_Explicit := True;
                           elsif A = "--signoff" then
                              Options.Signoff := True;
                              Options.Signoff_Explicit := True;
                           elsif A = "--no-signoff" then
                              Options.Signoff := False;
                              Options.Signoff_Explicit := True;
                           elsif A = "--verify-signatures" then
                              Options.Verify_Signatures := True;
                              Options.Verify_Signatures_Explicit := True;
                           elsif A = "--no-verify-signatures" then
                              Options.Verify_Signatures := False;
                              Options.Verify_Signatures_Explicit := True;
                           elsif A = "--gpg-sign" or else A = "-S" then
                              Options.GPG_Sign := To_Unbounded_String ("default");
                              Options.GPG_Sign_Explicit := True;
                           elsif A'Length > 11
                             and then A (A'First .. A'First + 10) = "--gpg-sign="
                           then
                              declare
                                 Key : constant String := After_Equals (A, "--gpg-sign=");
                              begin
                                 Options.GPG_Sign :=
                                   To_Unbounded_String
                                     ((if Key'Length = 0 then "default" else Key));
                                 Options.GPG_Sign_Explicit := True;
                              end;
                           elsif A'Length > 2
                             and then A (A'First .. A'First + 1) = "-S"
                           then
                              Options.GPG_Sign :=
                                To_Unbounded_String (A (A'First + 2 .. A'Last));
                              Options.GPG_Sign_Explicit := True;
                           elsif A = "--no-gpg-sign" then
                              Options.GPG_Sign := To_Unbounded_String ("");
                              Options.GPG_Sign_Explicit := True;
                           elsif A = "--edit" then
                              Options.Edit_Message := True;
                              Options.Edit_Explicit := True;
                           elsif A = "--no-edit" then
                              Options.Edit_Message := False;
                              Options.Edit_Explicit := True;
                           elsif A = "--cleanup" then
                              if I = Count then
                                 Usage_Error ("missing merge cleanup mode", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              if Cleanup_Mode_OK (Arg (I)) then
                                 Options.Cleanup_Mode := To_Unbounded_String (Arg (I));
                              else
                                 Usage_Error
                                   ("unsupported merge cleanup mode: " & Arg (I),
                                    Usage);
                                 return;
                              end if;
                           elsif A'Length > 10
                             and then A (A'First .. A'First + 9) = "--cleanup="
                           then
                              declare
                                 Mode : constant String := After_Equals (A, "--cleanup=");
                              begin
                                 if Cleanup_Mode_OK (Mode) then
                                    Options.Cleanup_Mode := To_Unbounded_String (Mode);
                                 else
                                    Usage_Error
                                      ("unsupported merge cleanup mode: " & Mode,
                                       Usage);
                                    return;
                                 end if;
                              end;
                           elsif A = "--into-name" then
                              if I = Count then
                                 Usage_Error ("missing merge into-name", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Options.Into_Name := To_Unbounded_String (Arg (I));
                           elsif A'Length > 12
                             and then A (A'First .. A'First + 11) = "--into-name="
                           then
                              Options.Into_Name :=
                                To_Unbounded_String
                                  (After_Equals (A, "--into-name="));
                           elsif A = "--renormalize" then
                              Options.Renormalize := True;
                              Options.Renormalize_Explicit := True;
                           elsif A = "--no-renormalize" then
                              Options.Renormalize := False;
                              Options.Renormalize_Explicit := True;
                           elsif A = "--find-renames" then
                              Options.Detect_Renames := True;
                              Options.Detect_Renames_Explicit := True;
                           elsif A'Length > 15
                             and then A (A'First .. A'First + 14)
                                      = "--find-renames="
                           then
                              declare
                                 Threshold_OK : Boolean := False;
                                 Threshold : constant Natural :=
                                   Parse_Rename_Threshold
                                     (After_Equals (A, "--find-renames="),
                                      Threshold_OK);
                              begin
                                 if Threshold_OK then
                                    Options.Detect_Renames := True;
                                    Options.Detect_Renames_Explicit := True;
                                    Options.Rename_Threshold := Threshold;
                                 else
                                    Usage_Error
                                      ("unsupported merge rename threshold: "
                                       & After_Equals (A, "--find-renames="),
                                       Usage);
                                    return;
                                 end if;
                              end;
                           elsif A = "--find-copies" or else A = "--find-copies-harder" then
                              Options.Detect_Copies := True;
                              Options.Detect_Copies_Explicit := True;
                           elsif A'Length > 14
                             and then A (A'First .. A'First + 13)
                                      = "--find-copies="
                           then
                              declare
                                 Threshold_OK : Boolean := False;
                                 Threshold : constant Natural :=
                                   Parse_Rename_Threshold
                                     (After_Equals (A, "--find-copies="),
                                      Threshold_OK);
                              begin
                                 if Threshold_OK then
                                    Options.Detect_Copies := True;
                                    Options.Detect_Copies_Explicit := True;
                                    Options.Rename_Threshold := Threshold;
                                 else
                                    Usage_Error
                                      ("unsupported merge copy threshold: "
                                       & After_Equals (A, "--find-copies="),
                                       Usage);
                                    return;
                                 end if;
                              end;
                           elsif A = "--no-copies" then
                              Options.Detect_Copies := False;
                              Options.Detect_Copies_Explicit := True;
                           elsif A = "--recurse-submodules" then
                              Options.Recurse_Submodules := True;
                              Options.Recurse_Submodules_Explicit := True;
                           elsif A'Length > 21
                             and then A (A'First .. A'First + 20)
                                      = "--recurse-submodules="
                           then
                              declare
                                 Mode_OK : Boolean := False;
                                 Enabled : constant Boolean :=
                                   Parse_Recurse_Submodules_Mode
                                     (After_Equals (A, "--recurse-submodules="),
                                      Mode_OK);
                              begin
                                 if Mode_OK then
                                    Options.Recurse_Submodules := Enabled;
                                    Options.Recurse_Submodules_Explicit := True;
                                 else
                                    Usage_Error
                                      ("unsupported recurse-submodules mode: "
                                       & After_Equals (A, "--recurse-submodules="),
                                       Usage);
                                    return;
                                 end if;
                              end;
                           elsif A = "--no-recurse-submodules" then
                              Options.Recurse_Submodules := False;
                              Options.Recurse_Submodules_Explicit := True;
                           elsif A = "--no-renames" then
                              Options.Detect_Renames := False;
                              Options.Detect_Renames_Explicit := True;
                           elsif A = "--rerere-autoupdate" then
                              Options.Enable_Rerere := True;
                           elsif A = "--no-rerere-autoupdate" then
                              null;
                           elsif A = "--conflict"
                             or else A = "--conflict-style"
                           then
                              if I = Count then
                                 Usage_Error ("missing merge conflict style", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Apply_Conflict_Style (Arg (I), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge conflict style: " & Arg (I),
                                    Usage);
                                 return;
                              end if;
                           elsif A'Length > 11
                             and then A (A'First .. A'First + 10)
                                      = "--conflict="
                           then
                              Apply_Conflict_Style
                                (After_Equals (A, "--conflict="), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge conflict style: "
                                    & After_Equals (A, "--conflict="), Usage);
                                 return;
                              end if;
                           elsif A'Length > 17
                             and then A (A'First .. A'First + 16)
                                      = "--conflict-style="
                           then
                              Apply_Conflict_Style
                                (After_Equals (A, "--conflict-style="), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge conflict style: "
                                    & After_Equals (A, "--conflict-style="), Usage);
                                 return;
                              end if;
                           elsif A = "--marker-size" then
                              if I = Count then
                                 Usage_Error ("missing merge marker size", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Options.Marker_Size := Parse_Depth_Argument (Arg (I));
                           elsif A'Length > 14
                             and then A (A'First .. A'First + 13)
                                      = "--marker-size="
                           then
                              Options.Marker_Size :=
                                Parse_Depth_Argument
                                  (After_Equals (A, "--marker-size="));
                           elsif A = "-m" or else A = "--message" then
                              if I = Count then
                                 Usage_Error ("missing merge message", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Options.Message := To_Unbounded_String (Arg (I));
                           elsif A'Length > 10
                             and then A (A'First .. A'First + 9) = "--message="
                           then
                              Options.Message :=
                                To_Unbounded_String (After_Equals (A, "--message="));
                           elsif A = "-F" or else A = "--file" then
                              if I = Count then
                                 Usage_Error ("missing merge message file", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Options.Message :=
                                To_Unbounded_String
                                  (Version.Files.Read_Binary_File (Arg (I)));
                           elsif A'Length > 7
                             and then A (A'First .. A'First + 6) = "--file="
                           then
                              Options.Message :=
                                To_Unbounded_String
                                  (Version.Files.Read_Binary_File
                                     (After_Equals (A, "--file=")));
                           elsif A'Length > 2
                             and then A (A'First .. A'First + 1) = "-F"
                           then
                              Options.Message :=
                                To_Unbounded_String
                                  (Version.Files.Read_Binary_File
                                     (A (A'First + 2 .. A'Last)));
                           elsif A = "-s" or else A = "--strategy" then
                              if I = Count then
                                 Usage_Error ("missing merge strategy", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Apply_Strategy (Arg (I), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge strategy: " & Arg (I), Usage);
                                 return;
                              end if;
                           elsif A'Length > 11
                             and then A (A'First .. A'First + 10) = "--strategy="
                           then
                              Apply_Strategy
                                (After_Equals (A, "--strategy="), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge strategy: "
                                    & After_Equals (A, "--strategy="), Usage);
                                 return;
                              end if;
                           elsif A = "-X"
                             or else A = "--strategy-option"
                           then
                              if I = Count then
                                 Usage_Error ("missing merge strategy option", Usage);
                                 return;
                              end if;
                              I := I + 1;
                              Apply_Strategy_Option (Arg (I), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge strategy option: " & Arg (I),
                                    Usage);
                                 return;
                              end if;
                           elsif A'Length > 2
                             and then A (A'First .. A'First + 1) = "-X"
                           then
                              Apply_Strategy_Option
                                (A (A'First + 2 .. A'Last), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge strategy option: "
                                    & A (A'First + 2 .. A'Last), Usage);
                                 return;
                              end if;
                           elsif A'Length > 18
                             and then A (A'First .. A'First + 17)
                                      = "--strategy-option="
                           then
                              Apply_Strategy_Option
                                (After_Equals (A, "--strategy-option="), Options, OK);
                              if not OK then
                                 Usage_Error
                                   ("unsupported merge strategy option: "
                                    & After_Equals (A, "--strategy-option="), Usage);
                                 return;
                              end if;
                           elsif A'Length > 0 and then A (A'First) = '-' then
                              Usage_Error ("unknown merge option: " & A, Usage);
                              return;
                           else
                              Targets.Append (To_Unbounded_String (A));
                           end if;
                        end;

                        I := I + 1;
                     end loop;

                     if Targets.Is_Empty then
                        if Default_To_Upstream then
                           Targets.Append
                             (To_Unbounded_String (Default_Upstream_Target));
                        else
                           Usage_Error ("missing merge target or action", Usage);
                           return;
                        end if;
                     end if;

                     if Targets.Length = 1 then
                        declare
                           Target : constant String :=
                             To_String (Targets.Element (Targets.First_Index));
                        begin
                           if Run_Merge_One
                                (Target  => Target,
                                 Options => Options)
                           then
                              if Options.Squash then
                                 Success_Line ("Squash commit -- not updating HEAD");
                                 Success_Line
                                   ("Automatic merge went well; stopped before committing as requested");
                              elsif Options.No_Commit then
                                 Success_Line
                                   ("Automatic merge went well; stopped before committing as requested");
                              elsif Last_Merge_Was_Fast_Forward then
                                 Success_Line ("Fast-forward");
                              elsif Last_Merge_Was_Already_Up_To_Date then
                                 Success_Line ("Already up to date.");
                              else
                                 Success_Line ("Merge made by the 'ort' strategy.");
                              end if;
                           end if;
                        end;
                     else
                        if Run_Merge_Multiple
                             (Targets => Targets,
                              Options => Options)
                        then
                           if Options.Squash then
                              Success_Line ("Squash commit -- not updating HEAD");
                              Success_Line
                                ("Automatic merge went well; stopped before committing as requested");
                           elsif Options.No_Commit then
                              Success_Line
                                ("Automatic merge went well; stopped before committing as requested");
                           else
                              Success_Line ("Merge made by the 'octopus' strategy.");
                           end if;
                        end if;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "submodule" then
            declare
               Usage : constant String := "version submodule SUBCOMMAND [ARGS]";
            begin
               if Count < 2 then
                  Usage_Error ("missing submodule subcommand", Usage);
                  return;
               elsif Arg (2) = "init" then
                  if Count /= 2 then
                     Usage_Error ("too many submodule init arguments", Usage);
                     return;
                  end if;
                  Version.Submodules.Init;
                  Success_Line ("initialized submodules");

               elsif Arg (2) = "update" then
                  declare
                     Update_Usage : constant String :=
                       "version submodule update [--recursive]";
                     I        : Natural := 3;
                     Recursive : Boolean := False;
                  begin
                     while I <= Count loop
                        if Arg (I) = "--recursive" then
                           if Recursive then
                              Usage_Error ("duplicate option: --recursive", Update_Usage);
                              return;
                           end if;

                           Recursive := True;
                           I := I + 1;

                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown submodule update option: " & Arg (I),
                              Update_Usage);
                           return;

                        else
                           Usage_Error
                             ("too many submodule update arguments", Update_Usage);
                           return;
                        end if;
                     end loop;

                     Version.Submodules.Update (Recursive => Recursive);
                     Success_Line ("updated submodules");
                  end;

               elsif Arg (2) = "status" then
                  if Count /= 2 then
                     Usage_Error ("too many submodule status arguments", Usage);
                     return;
                  end if;
                  Version.Submodules.Status;

               else
                  Usage_Error
                    ("unknown submodule subcommand: " & Arg (2), Usage);
                  return;
               end if;
            end;

         elsif Command = "worktree" then
            declare
               Usage : constant String := "version worktree SUBCOMMAND [ARGS]";
            begin
               if Count < 2 then
                  Usage_Error ("missing worktree subcommand", Usage);
                  return;
               elsif Arg (2) = "list" then
                  if Count /= 2 then
                     Usage_Error ("too many worktree list arguments", Usage);
                     return;
                  end if;
                  Print_Worktree_List;

               elsif Arg (2) = "current" then
                  if Count /= 2 then
                     Usage_Error ("too many worktree current arguments", Usage);
                     return;
                  end if;
                  Ada.Text_IO.Put (Version.Worktrees.Current_Worktree_Text);

               elsif Arg (2) = "add" then
                  declare
                     Add_Usage    : constant String :=
                       "version worktree add [--detach] PATH BRANCH_OR_REV";
                     I             : Natural := 3;
                     Detached      : Boolean := False;
                     Path          : Unbounded_String;
                     Branch_Or_Rev : Unbounded_String;
                     Operand_Count : Natural := 0;
                  begin
                     while I <= Count loop
                        if Arg (I) = "--detach" then
                           if Detached then
                              Usage_Error ("duplicate option: --detach", Add_Usage);
                              return;
                           end if;

                           Detached := True;
                           I := I + 1;

                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown worktree add option: " & Arg (I), Add_Usage);
                           return;

                        else
                           Operand_Count := Operand_Count + 1;
                           if Operand_Count = 1 then
                              Path := To_Unbounded_String (Arg (I));
                           elsif Operand_Count = 2 then
                              Branch_Or_Rev := To_Unbounded_String (Arg (I));
                           else
                              Usage_Error
                                ("too many worktree add arguments", Add_Usage);
                              return;
                           end if;
                           I := I + 1;
                        end if;
                     end loop;

                     if Operand_Count = 0 then
                        Usage_Error ("missing worktree path", Add_Usage);
                        return;
                     elsif Operand_Count = 1 and then Detached then
                        Usage_Error ("missing worktree revision", Add_Usage);
                        return;
                     elsif Operand_Count = 1 then
                        Usage_Error ("missing worktree branch", Add_Usage);
                        return;
                     elsif Detached then
                        Version.Worktrees.Add_Detached
                          (Path => To_String (Path), Rev => To_String (Branch_Or_Rev));
                        Success_Line
                          ("added detached worktree " & To_String (Path));
                     else
                        Version.Worktrees.Add
                          (Path   => To_String (Path),
                           Branch => To_String (Branch_Or_Rev));
                        Success_Line ("added worktree " & To_String (Path));
                     end if;
                  end;

               elsif Arg (2) = "remove" then
                  if Count = 2 then
                     Usage_Error ("missing worktree path", Usage);
                     return;
                  elsif Count > 3 then
                     Usage_Error ("too many worktree remove arguments", Usage);
                     return;
                  end if;
                  Version.Worktrees.Remove (Arg (3));
                  Success_Line ("removed worktree " & Arg (3));

               else
                  Usage_Error
                    ("unknown worktree subcommand: " & Arg (2), Usage);
                  return;
               end if;
            end;

         elsif Command = "rebase" then
            declare
               Usage : constant String :=
                 "version rebase TARGET | version rebase -i UPSTREAM"
                 & " | version rebase --continue | version rebase --abort";
            begin
               if Count < 2 then
                  Usage_Error ("missing rebase target or action", Usage);
                  return;
               elsif Arg (2) = "-i" or else Arg (2) = "--interactive" then
                  if Count /= 3 then
                     Usage_Error ("rebase -i requires an upstream", Usage);
                     return;
                  end if;
                  Version.Rebase.Start_Interactive (Arg (3));
                  if Version.Rebase.In_Progress then
                     Success_Line
                       ("stopped for edit; amend as needed, then run "
                        & "version rebase --continue");
                  else
                     Success_Line ("rebased onto " & Arg (3));
                  end if;
               elsif Arg (2) = "--rebase-merges" then
                  if Count /= 3 then
                     Usage_Error
                       ("rebase --rebase-merges requires an upstream", Usage);
                     return;
                  end if;
                  Version.Rebase.Start_Rebase_Merges (Arg (3));
                  Success_Line ("rebased onto " & Arg (3));
               elsif Arg (2) = "--preserve-merges" then
                  raise Ada.IO_Exceptions.Data_Error with
                    Version.Rebase.Merge_Preserving_Rebase_Not_Supported;
               elsif Arg (2) = "--continue" then
                  if Count > 2 then
                     Usage_Error ("too many rebase --continue arguments", Usage);
                     return;
                  end if;
                  Version.Rebase.Continue_Rebase;
                  if Version.Rebase.In_Progress then
                     Success_Line
                       ("stopped for edit; amend as needed, then run "
                        & "version rebase --continue");
                  else
                     Success_Line ("continued rebase");
                  end if;
               elsif Arg (2) = "--abort" then
                  if Count > 2 then
                     Usage_Error ("too many rebase --abort arguments", Usage);
                     return;
                  end if;
                  Version.Rebase.Abort_Rebase;
                  Success_Line ("aborted rebase");
               elsif Arg (2) = "--root" then
                  if Count = 4 and then Arg (3) = "--onto" then
                     Version.Rebase.Start_Root (Arg (4));
                     Success_Line ("rebased onto " & Arg (4));
                  elsif Count = 2 then
                     Version.Rebase.Start_Root_Bare;
                     Success_Line ("rebased from root");
                  else
                     Usage_Error
                       ("rebase --root requires --onto NEWBASE", Usage);
                     return;
                  end if;
               elsif Arg (2)'Length > 0 and then Arg (2) (Arg (2)'First) = '-' then
                  Usage_Error ("unknown rebase option: " & Arg (2), Usage);
                  return;
               elsif Count > 2 then
                  Usage_Error ("too many rebase arguments", Usage);
                  return;
               else
                  Version.Rebase.Start (Arg (2));
                  Success_Line ("rebased onto " & Arg (2));
               end if;
            end;

         elsif Command = "cherry-pick" then
            declare
               Usage : constant String :=
                 "version cherry-pick [-m PARENT|--mainline PARENT] REV...";
            begin
               if Count = 2 and then Arg (2) = "--continue" then
                  Version.Cherry_Pick.Continue_Cherry_Pick;
                  Success_Line ("continued cherry-pick");

               elsif Count = 2 and then Arg (2) = "--abort" then
                  Version.Cherry_Pick.Abort_Cherry_Pick;
                  Success_Line ("aborted cherry-pick");

               elsif Count >= 2 then
                  declare
                     Mainline       : Natural := 0;
                     Has_Mainline   : Boolean := False;
                     Revision_Count : Natural := 0;
                     I              : Natural := 2;
                  begin
                     while I <= Count loop
                        if Arg (I) = "-m" or else Arg (I) = "--mainline" then
                           if Has_Mainline then
                              Usage_Error ("duplicate option: " & Arg (I), Usage);
                              return;
                           elsif I = Count then
                              Usage_Error
                                (Arg (I) & " requires a parent number", Usage);
                              return;
                           end if;

                           begin
                              Mainline := Parse_Mainline_Argument (Arg (I + 1));
                           exception
                              when Ada.IO_Exceptions.Data_Error =>
                                 Usage_Error
                                   ("mainline must be a positive integer",
                                    Usage);
                                 return;
                           end;

                           Has_Mainline := True;
                           I := I + 2;

                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown cherry-pick option: " & Arg (I),
                              Usage);
                           return;

                        else
                           Revision_Count := Revision_Count + 1;
                           I := I + 1;
                        end if;
                     end loop;

                     if Revision_Count = 0 then
                        Usage_Error ("missing cherry-pick revision", Usage);
                        return;
                     end if;

                     declare
                        Repo           : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Commits        : Version.Cherry_Pick_State.Commit_Vectors.Vector;
                        First_Revision : Unbounded_String;
                     begin
                        I := 2;
                        while I <= Count loop
                           if Arg (I) = "-m" or else Arg (I) = "--mainline" then
                              I := I + 2;
                           else
                              if Commits.Is_Empty then
                                 First_Revision := To_Unbounded_String (Arg (I));
                              end if;
                              Commits.Append
                                (Version.Revisions.Resolve_Commit
                                   (Repo => Repo, Text => Arg (I)));
                              I := I + 1;
                           end if;
                        end loop;

                        Version.Cherry_Pick.Start (Commits, Mainline);
                        Success_Line
                          ("cherry-picked " & To_String (First_Revision));
                     end;
                  end;

               else
                  Usage_Error ("missing cherry-pick revision", Usage);
                  return;
               end if;
            end;

         elsif Command = "revert" then
            declare
               Usage : constant String :=
                 "version revert [-m PARENT|--mainline PARENT] REV...";
            begin
               if Count = 2 and then Arg (2) = "--continue" then
                  Version.Revert.Continue_Revert;
                  Success_Line ("continued revert");

               elsif Count = 2 and then Arg (2) = "--abort" then
                  Version.Revert.Abort_Revert;
                  Success_Line ("aborted revert");

               elsif Count >= 2 then
                  declare
                     Mainline       : Natural := 0;
                     Has_Mainline   : Boolean := False;
                     Revision_Count : Natural := 0;
                     I              : Natural := 2;
                  begin
                     while I <= Count loop
                        if Arg (I) = "-m" or else Arg (I) = "--mainline" then
                           if Has_Mainline then
                              Usage_Error ("duplicate option: " & Arg (I), Usage);
                              return;
                           elsif I = Count then
                              Usage_Error
                                (Arg (I) & " requires a parent number", Usage);
                              return;
                           end if;

                           begin
                              Mainline := Parse_Mainline_Argument (Arg (I + 1));
                           exception
                              when Ada.IO_Exceptions.Data_Error =>
                                 Usage_Error
                                   ("mainline must be a positive integer",
                                    Usage);
                                 return;
                           end;

                           Has_Mainline := True;
                           I := I + 2;

                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown revert option: " & Arg (I), Usage);
                           return;

                        else
                           Revision_Count := Revision_Count + 1;
                           I := I + 1;
                        end if;
                     end loop;

                     if Revision_Count = 0 then
                        Usage_Error ("missing revert revision", Usage);
                        return;
                     end if;

                     declare
                        Repo           : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Commits        : Version.Revert_State.Commit_Vectors.Vector;
                        First_Revision : Unbounded_String;
                     begin
                        I := 2;
                        while I <= Count loop
                           if Arg (I) = "-m" or else Arg (I) = "--mainline" then
                              I := I + 2;
                           else
                              if Commits.Is_Empty then
                                 First_Revision := To_Unbounded_String (Arg (I));
                              end if;
                              Commits.Append
                                (Version.Revisions.Resolve_Commit
                                   (Repo => Repo, Text => Arg (I)));
                              I := I + 1;
                           end if;
                        end loop;

                        Version.Revert.Start (Commits, Mainline);
                        Success_Line ("reverted " & To_String (First_Revision));
                     end;
                  end;

               else
                  Usage_Error ("missing revert revision", Usage);
                  return;
               end if;
            end;

         elsif Command = "stash" then
            declare
               Usage : constant String :=
                 "version stash [push [--include-untracked|--include-ignored] [--] [PATH...]] | "
                 & "version stash create [--include-untracked|--include-ignored] [--] [PATH...] | "
                 & "version stash store [-m MESSAGE] COMMIT | "
                 & "version stash list | version stash show [--patch] [stash@{N}] [--] [PATH...] | "
                 & "version stash apply [stash@{N}] [--] [PATH...] | "
                 & "version stash pop [stash@{N}] [--] [PATH...] | "
                 & "version stash branch NAME [stash@{N}] | "
                 & "version stash drop [stash@{N}] | version stash clear";

               function Is_Option (Text : String) return Boolean is
               begin
                  return Text'Length > 0 and then Text (Text'First) = '-';
               end Is_Option;

               function Is_Stash_Spec (Text : String) return Boolean is
               begin
                  return Ada.Strings.Fixed.Index (Text, "stash@{") = 1;
               end Is_Stash_Spec;

               procedure Parse_Stash_Path_Command
                 (Subcommand        : String;
                  First_Index       : Positive;
                  Include_Untracked : out Boolean;
                  Include_Ignored   : out Boolean;
                  Path_First        : out Natural;
                  OK                : out Boolean)
               is
                  I               : Natural := First_Index;
                  After_Separator : Boolean := False;
                  Saw_Untracked   : Boolean := False;
                  Saw_Ignored     : Boolean := False;
               begin
                  Include_Untracked := False;
                  Include_Ignored := False;
                  Path_First := First_Index;
                  OK := False;

                  while I <= Count loop
                     if Arg (I) = "--" and then not After_Separator then
                        After_Separator := True;
                        Path_First := I;
                        OK := True;
                        return;

                     elsif not After_Separator
                       and then Arg (I) = "--include-untracked"
                     then
                        if Saw_Untracked then
                           Usage_Error
                             ("duplicate stash " & Subcommand
                              & " option: --include-untracked",
                              Usage);
                           return;
                        elsif Saw_Ignored then
                           Usage_Error
                             ("stash " & Subcommand
                              & " --include-untracked cannot be combined with --include-ignored",
                              Usage);
                           return;
                        end if;

                        Saw_Untracked := True;
                        Include_Untracked := True;
                        I := I + 1;

                     elsif not After_Separator
                       and then Arg (I) = "--include-ignored"
                     then
                        if Saw_Ignored then
                           Usage_Error
                             ("duplicate stash " & Subcommand
                              & " option: --include-ignored",
                              Usage);
                           return;
                        elsif Saw_Untracked then
                           Usage_Error
                             ("stash " & Subcommand
                              & " --include-untracked cannot be combined with --include-ignored",
                              Usage);
                           return;
                        end if;

                        Saw_Ignored := True;
                        Include_Untracked := True;
                        Include_Ignored := True;
                        I := I + 1;

                     elsif not After_Separator and then Is_Option (Arg (I)) then
                        Usage_Error
                          ("unknown stash " & Subcommand & " option: " & Arg (I),
                           Usage);
                        return;

                     else
                        Path_First := I;
                        OK := True;
                        return;
                     end if;
                  end loop;

                  Path_First := Count + 1;
                  OK := True;
               end Parse_Stash_Path_Command;

               procedure Run_Stash_Push
                 (First_Index : Positive; Subcommand_Present : Boolean)
               is
                  Include_Untracked : Boolean;
                  Include_Ignored   : Boolean;
                  Path_First        : Natural;
                  OK                : Boolean;
               begin
                  if Subcommand_Present then
                     Parse_Stash_Path_Command
                       ("push", First_Index, Include_Untracked, Include_Ignored,
                        Path_First, OK);
                     if not OK then
                        return;
                     end if;
                  else
                     Include_Untracked := False;
                     Include_Ignored := False;
                     Path_First := Count + 1;
                  end if;

                  declare
                     Specs : constant Version.Pathspec.Pathspec_Vectors.Vector :=
                       Pathspecs_From_Args (Positive (Path_First));
                  begin
                     if Has_Stashable_Changes
                          (Include_Untracked => Include_Untracked,
                           Include_Ignored   => Include_Ignored,
                           Pathspecs         => Specs)
                     then
                        Version.Stash.Push
                          (Include_Untracked => Include_Untracked,
                           Include_Ignored   => Include_Ignored,
                           Pathspecs         => Specs);
                        Success_Line ("stashed changes");
                     else
                        Success_Line ("no changes to stash");
                     end if;
                  end;
               end Run_Stash_Push;

               procedure Run_Stash_Create (First_Index : Positive) is
                  Include_Untracked : Boolean;
                  Include_Ignored   : Boolean;
                  Path_First        : Natural;
                  OK                : Boolean;
               begin
                  Parse_Stash_Path_Command
                    ("create", First_Index, Include_Untracked, Include_Ignored,
                     Path_First, OK);
                  if not OK then
                     return;
                  end if;

                  declare
                     Specs : constant Version.Pathspec.Pathspec_Vectors.Vector :=
                       Pathspecs_From_Args (Positive (Path_First));
                     Id : constant String :=
                       Version.Stash.Create
                         (Include_Untracked => Include_Untracked,
                          Include_Ignored   => Include_Ignored,
                          Pathspecs         => Specs);
                  begin
                     if Id'Length > 0 then
                        Ada.Text_IO.Put_Line (Id);
                     end if;
                  end;
               end Run_Stash_Create;

               procedure Run_Stash_Show is
                  Patch           : Boolean := False;
                  Spec            : Unbounded_String;
                  Has_Spec        : Boolean := False;
                  Path_First      : Natural := Count + 1;
                  After_Separator : Boolean := False;
                  I               : Natural := 3;
               begin
                  while I <= Count loop
                     if Arg (I) = "--" and then not After_Separator then
                        After_Separator := True;
                        Path_First := I;
                        exit;

                     elsif not After_Separator and then Arg (I) = "--patch" then
                        if Patch then
                           Usage_Error
                             ("duplicate stash show option: --patch", Usage);
                           return;
                        end if;
                        Patch := True;

                     elsif not After_Separator and then Is_Stash_Spec (Arg (I)) then
                        if Has_Spec then
                           Usage_Error ("too many stash show stash specs", Usage);
                           return;
                        end if;
                        Has_Spec := True;
                        Spec := To_Unbounded_String (Arg (I));

                     elsif not After_Separator and then Is_Option (Arg (I)) then
                        Usage_Error
                          ("unknown stash show option: " & Arg (I), Usage);
                        return;

                     else
                        Path_First := I;
                        exit;
                     end if;

                     I := I + 1;
                  end loop;

                  if Has_Spec then
                     Ada.Text_IO.Put
                       (Version.Stash.Show
                          (Spec      => To_String (Spec),
                           Patch     => Patch,
                           Pathspecs => Pathspecs_From_Args
                                          (Positive (Path_First))));
                  else
                     Ada.Text_IO.Put
                       (Version.Stash.Show
                          (Patch     => Patch,
                           Pathspecs => Pathspecs_From_Args
                                          (Positive (Path_First))));
                  end if;
               end Run_Stash_Show;

               procedure Run_Stash_Apply_Or_Pop (Pop : Boolean) is
                  Spec            : Unbounded_String;
                  Has_Spec        : Boolean := False;
                  Path_First      : Natural := Count + 1;
                  After_Separator : Boolean := False;
                  I               : Natural := 3;
               begin
                  while I <= Count loop
                     if Arg (I) = "--" and then not After_Separator then
                        After_Separator := True;
                        Path_First := I;
                        exit;

                     elsif not After_Separator and then Is_Stash_Spec (Arg (I)) then
                        if Has_Spec then
                           Usage_Error
                             ("too many stash "
                              & (if Pop then "pop" else "apply")
                              & " stash specs",
                              Usage);
                           return;
                        end if;
                        Has_Spec := True;
                        Spec := To_Unbounded_String (Arg (I));

                     elsif not After_Separator and then Is_Option (Arg (I)) then
                        Usage_Error
                          ("unknown stash "
                           & (if Pop then "pop" else "apply")
                           & " option: " & Arg (I),
                           Usage);
                        return;

                     else
                        Path_First := I;
                        exit;
                     end if;

                     I := I + 1;
                  end loop;

                  if Path_First > Count and then not Has_Spec then
                     if Pop then
                        Version.Stash.Pop;
                        Success_Line ("popped stash");
                     else
                        Version.Stash.Apply;
                        Success_Line ("applied stash");
                     end if;

                  elsif Has_Spec then
                     if Version.Stash.Apply_Selected
                          (Spec      => To_String (Spec),
                           Pathspecs => Pathspecs_From_Args
                                          (Positive (Path_First)))
                     then
                        if Pop then
                           Version.Stash.Drop (To_String (Spec));
                           Success_Line ("popped stash " & To_String (Spec));
                        else
                           Success_Line ("applied stash " & To_String (Spec));
                        end if;
                     else
                        Success_Line ("no matching paths in stash");
                     end if;

                  else
                     if Version.Stash.Apply_Selected
                          (Pathspecs => Pathspecs_From_Args
                                          (Positive (Path_First)))
                     then
                        if Pop then
                           Version.Stash.Drop;
                           Success_Line ("popped stash");
                        else
                           Success_Line ("applied stash");
                        end if;
                     else
                        Success_Line ("no matching paths in stash");
                     end if;
                  end if;
               end Run_Stash_Apply_Or_Pop;

               procedure Run_Stash_Store is
                  Message         : Unbounded_String;
                  Has_Message     : Boolean := False;
                  Commit_Text     : Unbounded_String;
                  Has_Commit      : Boolean := False;
                  I               : Natural := 3;
               begin
                  while I <= Count loop
                     if Arg (I) = "-m" then
                        if Has_Message then
                           Usage_Error ("duplicate stash store option: -m", Usage);
                           return;
                        elsif I = Count then
                           Usage_Error ("stash store -m requires a message", Usage);
                           return;
                        end if;

                        Has_Message := True;
                        Message := To_Unbounded_String (Arg (I + 1));
                        I := I + 2;

                     elsif Is_Option (Arg (I)) then
                        Usage_Error
                          ("unknown stash store option: " & Arg (I), Usage);
                        return;

                     else
                        if Has_Commit then
                           Usage_Error ("too many stash store arguments", Usage);
                           return;
                        end if;
                        Has_Commit := True;
                        Commit_Text := To_Unbounded_String (Arg (I));
                        I := I + 1;
                     end if;
                  end loop;

                  if not Has_Commit then
                     Usage_Error ("missing stash store commit", Usage);
                     return;
                  end if;

                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Has_Message then
                        Version.Stash.Store
                          (Commit_Id => Version.Revisions.Resolve_Commit
                                          (Repo, To_String (Commit_Text)),
                           Message   => To_String (Message));
                     else
                        Version.Stash.Store
                          (Version.Revisions.Resolve_Commit
                             (Repo, To_String (Commit_Text)));
                     end if;
                     Success_Line ("stored stash " & To_String (Commit_Text));
                  end;
               end Run_Stash_Store;

               Subcommand : constant String :=
                 (if Count >= 2 then Arg (2) else "push");
            begin
               if Count = 1 then
                  Run_Stash_Push (2, Subcommand_Present => False);

               elsif Subcommand = "push" then
                  Run_Stash_Push (3, Subcommand_Present => True);

               elsif Subcommand = "create" then
                  Run_Stash_Create (3);

               elsif Subcommand = "store" then
                  Run_Stash_Store;

               elsif Subcommand = "list" then
                  if Count /= 2 then
                     Usage_Error ("stash list takes no arguments", Usage);
                     return;
                  end if;
                  Version.Stash.List;

               elsif Subcommand = "show" then
                  Run_Stash_Show;

               elsif Subcommand = "apply" then
                  Run_Stash_Apply_Or_Pop (Pop => False);

               elsif Subcommand = "pop" then
                  Run_Stash_Apply_Or_Pop (Pop => True);

               elsif Subcommand = "branch" then
                  if Count < 3 then
                     Usage_Error ("missing stash branch name", Usage);
                     return;
                  elsif Is_Option (Arg (3)) then
                     Usage_Error
                       ("unknown stash branch option: " & Arg (3), Usage);
                     return;
                  elsif Count > 4 then
                     Usage_Error ("too many stash branch arguments", Usage);
                     return;
                  elsif Count = 4 then
                     Version.Stash.Branch (Arg (3), Arg (4));
                     Success_Line
                       ("created branch " & Arg (3) & " from " & Arg (4));
                  else
                     Version.Stash.Branch (Arg (3));
                     Success_Line
                       ("created branch " & Arg (3) & " from stash@{0}");
                  end if;

               elsif Subcommand = "drop" then
                  if Count > 3 then
                     Usage_Error ("too many stash drop arguments", Usage);
                     return;
                  elsif Count = 3 and then Is_Option (Arg (3)) then
                     Usage_Error
                       ("unknown stash drop option: " & Arg (3), Usage);
                     return;
                  elsif Count = 3 then
                     Version.Stash.Drop (Arg (3));
                     Success_Line ("dropped stash " & Arg (3));
                  else
                     Version.Stash.Drop;
                     Success_Line ("dropped stash");
                  end if;

               elsif Subcommand = "clear" then
                  if Count /= 2 then
                     Usage_Error ("stash clear takes no arguments", Usage);
                     return;
                  end if;
                  Version.Stash.Clear;
                  Success_Line ("cleared stash");

               elsif Is_Option (Subcommand) then
                  Usage_Error ("unknown stash option: " & Subcommand, Usage);
                  return;

               else
                  Usage_Error ("unknown stash subcommand: " & Subcommand, Usage);
                  return;
               end if;
            end;

         elsif Command = "sparse" then
            declare
               Subcommand : constant String :=
                 (if Count >= 2 then Arg (2) else "");

               function Is_Option (Text : String) return Boolean is
               begin
                  return Text'Length > 0 and then Text (Text'First) = '-';
               end Is_Option;

               procedure Reject_Extra
                 (Index : Positive; Context, Usage : String) is
               begin
                  if Is_Option (Arg (Index)) then
                     Usage_Error
                       ("unknown sparse " & Context & " option: " & Arg (Index),
                        Usage);
                  else
                     Usage_Error
                       ("too many sparse " & Context & " arguments", Usage);
                  end if;
               end Reject_Extra;

               procedure Parse_Pathspec_Operands
                 (Context, Usage : String; OK : out Boolean) is
                  After_Separator : Boolean := False;
                  Operand_Count   : Natural := 0;
               begin
                  OK := False;

                  if Count >= 3 then
                     for I in 3 .. Count loop
                        if Arg (I) = "--" and then not After_Separator then
                           After_Separator := True;
                        elsif not After_Separator and then Is_Option (Arg (I)) then
                           Usage_Error
                             ("unknown sparse " & Context & " option: " & Arg (I),
                              Usage);
                           return;
                        else
                           Operand_Count := Operand_Count + 1;
                        end if;
                     end loop;
                  end if;

                  if Operand_Count = 0 then
                     Usage_Error ("missing sparse pathspec", Usage);
                  else
                     OK := True;
                  end if;
               end Parse_Pathspec_Operands;
            begin
               if Count = 1 then
                  Usage_Error
                    ("missing sparse subcommand", "version sparse <subcommand>");
                  return;

               elsif Subcommand = "list" then
                  declare
                     Usage : constant String := "version sparse list";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "list", Usage);
                        return;
                     end if;

                     Print_Sparse_List;
                  end;

               elsif Subcommand = "status" then
                  declare
                     Usage : constant String := "version sparse status";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "status", Usage);
                        return;
                     end if;

                     Print_Sparse_Status;
                  end;

               elsif Subcommand = "set" then
                  declare
                     Usage : constant String := "version sparse set PATHSPEC...";
                     OK    : Boolean := False;
                  begin
                     Parse_Pathspec_Operands ("set", Usage, OK);
                     if not OK then
                        return;
                     end if;
                  end;

                  Require_Clean_Working_Tree_Including_Sparse_Excluded
                    ("sparse set");
                  declare
                     Repo  : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Items : constant Version.Sparse.String_Vectors.Vector :=
                       Sparse_Items_From_Args (3);
                  begin
                     Preflight_Sparse_Restore
                       (Repo => Repo, Sparse_Enabled => True, Items => Items);
                     Version.Sparse.Set_From_Strings
                       (Repo => Repo, Items => Items);
                     Version.Restore.Restore_Working_Tree (Repo);
                  end;
                  Success_Line ("updated sparse checkout");

               elsif Subcommand = "add" then
                  declare
                     Usage : constant String := "version sparse add PATHSPEC...";
                     OK    : Boolean := False;
                  begin
                     Parse_Pathspec_Operands ("add", Usage, OK);
                     if not OK then
                        return;
                     end if;
                  end;

                  declare
                     Repo     : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Existing : Version.Sparse.String_Vectors.Vector;
                     Added    : constant Version.Sparse.String_Vectors.Vector :=
                       Sparse_Items_From_Args (3);
                  begin
                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse add");

                     if Version.Sparse.Enabled (Repo) then
                        Existing := Version.Sparse.Pattern_Texts (Repo);
                     end if;

                     if not Added.Is_Empty then
                        for I in Added.First_Index .. Added.Last_Index loop
                           Existing.Append (Added.Element (I));
                        end loop;
                     end if;

                     Preflight_Sparse_Restore
                       (Repo => Repo, Sparse_Enabled => True, Items => Existing);
                     Version.Sparse.Set_From_Strings
                       (Repo => Repo, Items => Existing);
                     Version.Restore.Restore_Working_Tree (Repo);
                  end;
                  Success_Line ("updated sparse checkout");

               elsif Subcommand = "disable" then
                  declare
                     Usage : constant String := "version sparse disable";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "disable", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse disable");
                     declare
                        Repo  : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Items : Version.Sparse.String_Vectors.Vector;
                     begin
                        Preflight_Sparse_Restore
                          (Repo => Repo, Sparse_Enabled => False, Items => Items);
                        Version.Sparse.Disable (Repo);
                        Version.Restore.Restore_Working_Tree (Repo);
                     end;
                     Success_Line ("disabled sparse checkout");
                  end;

               elsif Subcommand = "init" then
                  declare
                     Usage : constant String := "version sparse init";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "init", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse init");
                     declare
                        Items : Version.Sparse.String_Vectors.Vector;
                     begin
                        Items.Append ("*");
                        declare
                           Repo : constant Version.Repository.Repository_Handle :=
                             Version.Repository.Open;
                        begin
                           Preflight_Sparse_Restore
                             (Repo => Repo, Sparse_Enabled => True, Items => Items);
                           Version.Sparse.Set_From_Strings
                             (Repo => Repo, Items => Items);
                           Version.Restore.Restore_Working_Tree (Repo);
                        end;
                     end;
                     Success_Line ("initialized sparse checkout");
                  end;

               elsif Is_Option (Subcommand) then
                  Usage_Error
                    ("unknown sparse option: " & Subcommand,
                     "version sparse <subcommand>");
                  return;
               else
                  Usage_Error
                    ("unknown sparse subcommand: " & Subcommand,
                     "version sparse <subcommand>");
                  return;
               end if;
            end;

         elsif Command = "stage" then
            declare
               Usage : constant String :=
                 "version stage [-f|--force] [--] PATHSPEC...";
               Force         : Boolean := False;
               After_Separator : Boolean := False;
               Specs         : Version.Pathspec.Pathspec_Vectors.Vector;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--" and then not After_Separator then
                        After_Separator := True;
                     elsif not After_Separator
                       and then (Arg (I) = "-f" or else Arg (I) = "--force")
                     then
                        if Force then
                           Usage_Error ("duplicate option: " & Arg (I), Usage);
                           return;
                        end if;

                        Force := True;
                     elsif not After_Separator
                       and then Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error ("unknown stage option: " & Arg (I), Usage);
                        return;
                     else
                        Version.Pathspec.Append_Parse (Specs, Arg (I));
                     end if;
                  end loop;
               end if;

               if Specs.Is_Empty then
                  Usage_Error ("missing stage pathspec", Usage);
                  return;
               end if;

               declare
                  Matches : constant Version.Path_Safety.Path_Vector :=
                    Matching_Candidates
                      (Working_Candidates (Include_Ignored => Force), Specs);
               begin
                  if Matches.Is_Empty then
                     Raise_If_Explicit_Sparse_Missing_Stage (2);
                     raise Ada.IO_Exceptions.Data_Error
                       with Pathspec_No_Files_Text;
                  end if;

                  for I in Matches.First_Index .. Matches.Last_Index loop
                     Stage_Path (Matches.Element (I));
                  end loop;

                  if Natural (Matches.Length) = 1 then
                     Success_Line
                       ("staged " & Matches.Element (Matches.First_Index));
                  else
                     Success_Line
                       ("staged "
                        & Natural_Image (Natural (Matches.Length))
                        & " paths");
                  end if;
               end;
            end;

         elsif Command = "remove" then
            declare
               Usage : constant String := "version remove [--] PATHSPEC...";
               OK    : Boolean := False;
            begin
               Parse_Pathspec_Command_Arguments ("remove", Usage, OK);
               if not OK then
                  return;
               end if;
            end;

            declare
               Specs   : constant Version.Pathspec.Pathspec_Vectors.Vector :=
                 Pathspecs_From_Args (2);
               Matches : constant Version.Path_Safety.Path_Vector :=
                 Matching_Candidates (Index_Candidates, Specs);
            begin
               if Matches.Is_Empty then
                  raise Ada.IO_Exceptions.Data_Error
                    with Pathspec_No_Tracked_Paths_Text;
               end if;

               for I in Matches.First_Index .. Matches.Last_Index loop
                  Version.Remove.Remove_Path (Matches.Element (I));
               end loop;

               if Natural (Matches.Length) = 1 then
                  Success_Line
                    ("removed " & Matches.Element (Matches.First_Index));
               else
                  Success_Line
                    ("removed "
                     & Natural_Image (Natural (Matches.Length))
                     & " paths");
               end if;
            end;

         elsif Command = "restore" then
            declare
               Usage : constant String :=
                 "version restore [--source REV] [--staged] [--] [PATHSPEC...]";
               I               : Natural := 2;
               Has_Source      : Boolean := False;
               Has_Staged      : Boolean := False;
               After_Separator : Boolean := False;
               Source_Rev      : Unbounded_String;
               Pathspec_First  : Natural := 0;
               Pathspec_Count  : Natural := 0;

               function Is_Option (Text : String) return Boolean is
               begin
                  return Text'Length > 0 and then Text (Text'First) = '-';
               end Is_Option;
            begin
               while I <= Count loop
                  if After_Separator then
                     if Pathspec_First = 0 then
                        Pathspec_First := I;
                     end if;
                     Pathspec_Count := Pathspec_Count + 1;
                     I := I + 1;

                  elsif Arg (I) = "--" then
                     After_Separator := True;
                     if Pathspec_First = 0 then
                        Pathspec_First := I;
                     end if;
                     I := I + 1;

                  elsif Arg (I) = "--source" then
                     if Has_Source then
                        Usage_Error ("duplicate option: --source", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("--source requires a revision", Usage);
                        return;
                     elsif Arg (I + 1) = "--"
                       or else Is_Option (Arg (I + 1))
                     then
                        Usage_Error ("--source requires a revision", Usage);
                        return;
                     end if;

                     Has_Source := True;
                     Source_Rev := To_Unbounded_String (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I) = "--staged" then
                     if Has_Staged then
                        Usage_Error ("duplicate option: --staged", Usage);
                        return;
                     end if;

                     Has_Staged := True;
                     I := I + 1;

                  elsif Is_Option (Arg (I)) then
                     Usage_Error
                       ("unknown restore option: " & Arg (I), Usage);
                     return;

                  else
                     if Pathspec_First = 0 then
                        Pathspec_First := I;
                     end if;
                     Pathspec_Count := Pathspec_Count + 1;
                     I := I + 1;
                  end if;
               end loop;

               if Count = 1 then
                  Version.Restore.Restore_Current_Commit;
                  Success_Line ("restored working tree");

               elsif Pathspec_Count = 0 then
                  Usage_Error ("missing restore pathspec", Usage);
                  return;

               elsif Has_Source and then Has_Staged then
                  declare
                     Repo    : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Revision : constant String := To_String (Source_Rev);
                     Commit  : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Commit (Repo, Revision);
                     Specs   :
                       constant Version.Pathspec.Pathspec_Vectors.Vector :=
                         Pathspecs_From_Args (Positive (Pathspec_First));
                     Matches : constant Version.Path_Safety.Path_Vector :=
                       Matching_Candidates
                         (Merge_Candidates
                            (Tree_Candidates (Commit), Index_Candidates),
                          Specs);
                  begin
                     if Matches.Is_Empty then
                        raise Ada.IO_Exceptions.Data_Error
                          with Pathspec_No_Source_Paths_Text;
                     end if;

                     for J in Matches.First_Index .. Matches.Last_Index loop
                        Version.Restore.Restore_Staged_Path_From_Source
                          (Revision, Matches.Element (J));
                     end loop;
                     Success_Line ("restored staged paths from " & Revision);
                  end;

               elsif Has_Source then
                  declare
                     Repo    : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Revision : constant String := To_String (Source_Rev);
                     Commit  : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Commit (Repo, Revision);
                     Specs   :
                       constant Version.Pathspec.Pathspec_Vectors.Vector :=
                         Pathspecs_From_Args (Positive (Pathspec_First));
                     Matches : constant Version.Path_Safety.Path_Vector :=
                       Matching_Candidates
                         (Merge_Candidates
                            (Tree_Candidates (Commit),
                             Index_Candidates,
                             Working_Candidates),
                          Specs);
                  begin
                     if Matches.Is_Empty then
                        raise Ada.IO_Exceptions.Data_Error
                          with Pathspec_No_Source_Paths_Text;
                     end if;

                     for J in Matches.First_Index .. Matches.Last_Index loop
                        Version.Restore.Restore_Path_From_Source
                          (Revision, Matches.Element (J));
                     end loop;
                     Success_Line ("restored paths from " & Revision);
                  end;

               elsif Has_Staged then
                  declare
                     Repo    : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit  : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Commit (Repo, "HEAD");
                     Specs   :
                       constant Version.Pathspec.Pathspec_Vectors.Vector :=
                         Pathspecs_From_Args (Positive (Pathspec_First));
                     Matches : constant Version.Path_Safety.Path_Vector :=
                       Matching_Candidates
                         (Merge_Candidates
                            (Tree_Candidates (Commit), Index_Candidates),
                          Specs);
                  begin
                     if Matches.Is_Empty then
                        raise Ada.IO_Exceptions.Data_Error
                          with Pathspec_No_Source_Paths_Text;
                     end if;

                     for J in Matches.First_Index .. Matches.Last_Index loop
                        Version.Restore.Restore_Staged_Path (Matches.Element (J));
                     end loop;
                     Success_Line ("restored staged paths");
                  end;

               else
                  declare
                     Repo    : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit  : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Commit (Repo, "HEAD");
                     Specs   :
                       constant Version.Pathspec.Pathspec_Vectors.Vector :=
                         Pathspecs_From_Args (Positive (Pathspec_First));
                     Matches : constant Version.Path_Safety.Path_Vector :=
                       Matching_Candidates
                         (Merge_Candidates
                            (Tree_Candidates (Commit),
                             Index_Candidates,
                             Working_Candidates),
                          Specs);
                  begin
                     if Matches.Is_Empty then
                        raise Ada.IO_Exceptions.Data_Error
                          with Pathspec_No_Source_Paths_Text;
                     end if;

                     for J in Matches.First_Index .. Matches.Last_Index loop
                        Version.Restore.Restore_Path (Matches.Element (J));
                     end loop;
                     Success_Line ("restored paths");
                  end;
               end if;
            end;

         elsif Command = "checkout" then
            declare
               Usage : constant String :=
                 "version checkout REV [-- PATHSPEC...]";
            begin
               if Count < 2 then
                  Usage_Error ("missing checkout revision", Usage);
               elsif Arg (2)'Length > 0 and then Arg (2) (Arg (2)'First) = '-' then
                  Usage_Error ("unknown checkout option: " & Arg (2), Usage);
               elsif Count = 2 then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     Version.Checkout.Checkout_Commit
                       (Version.Revisions.Resolve_Commit (Repo, Arg (2)));
                     Success_Line ("checked out " & Arg (2));
                  end;
               elsif Arg (3) /= "--" then
                  if Arg (3)'Length > 0
                    and then Arg (3) (Arg (3)'First) = '-'
                  then
                     Usage_Error ("unknown checkout option: " & Arg (3), Usage);
                  else
                     Usage_Error ("expected -- before checkout pathspec", Usage);
                  end if;
               elsif Count = 3 then
                  Usage_Error ("missing checkout pathspec", Usage);
               else
                  declare
                     Repo   : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Commit (Repo, Arg (2));
                  begin
                     declare
                        Specs   :
                          constant Version.Pathspec.Pathspec_Vectors.Vector :=
                            Pathspecs_From_Args (4);
                        Matches : constant Version.Path_Safety.Path_Vector :=
                          Matching_Candidates (Tree_Candidates (Commit), Specs);
                     begin
                        if Matches.Is_Empty then
                           raise Ada.IO_Exceptions.Data_Error
                             with Pathspec_No_Source_Paths_Text;
                        end if;

                        for I in Matches.First_Index .. Matches.Last_Index loop
                           Version.Checkout.Checkout_Path_From_Commit
                             (Commit, Matches.Element (I));
                        end loop;
                     end;
                     Success_Line ("checked out paths from " & Arg (2));
                  end;
               end if;
            end;

         elsif Command = "reset" then
            declare
               Usage : constant String :=
                 "version reset [--soft|--mixed|--hard] [REV]"
                 & " | version reset [REV] -- PATHSPEC...";
               DD : Natural := 0;
               use type Version.Reset.Reset_Mode;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--" then
                     DD := I;
                     exit;
                  end if;
               end loop;

               if DD /= 0 then
                  --  Path form: reset [REV] -- PATHSPEC...
                  if DD > 3 then
                     Usage_Error ("too many revisions before --", Usage);
                  elsif DD = Count then
                     Usage_Error ("missing reset pathspec", Usage);
                  else
                     declare
                        Repo   : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Target : constant String :=
                          (if DD = 3 then Arg (2) else "HEAD");
                        Paths  : Version.Reset.Path_Vectors.Vector;
                     begin
                        for I in DD + 1 .. Count loop
                           Paths.Append (To_Unbounded_String (Arg (I)));
                        end loop;
                        Version.Reset.Reset_Paths (Repo, Target, Paths);
                     end;
                  end if;
               else
                  --  Commit/mode form: reset [--soft|--mixed|--hard] [REV]
                  declare
                     Mode       : Version.Reset.Reset_Mode := Version.Reset.Mixed;
                     Bad_Option : Boolean := False;
                     Rev_Index  : Positive := 2;
                  begin
                     if Count >= 2
                       and then Arg (2)'Length >= 1
                       and then Arg (2) (Arg (2)'First) = '-'
                     then
                        if Arg (2) = "--soft" then
                           Mode := Version.Reset.Soft;
                        elsif Arg (2) = "--mixed" then
                           Mode := Version.Reset.Mixed;
                        elsif Arg (2) = "--hard" then
                           Mode := Version.Reset.Hard;
                        else
                           Bad_Option := True;
                        end if;
                        Rev_Index := 3;
                     end if;

                     if Bad_Option then
                        Usage_Error ("unknown reset option: " & Arg (2), Usage);
                     elsif Rev_Index < Count then
                        Usage_Error ("too many reset arguments", Usage);
                     else
                        declare
                           Repo   : constant Version.Repository.Repository_Handle :=
                             Version.Repository.Open;
                           Target : constant String :=
                             (if Rev_Index <= Count then Arg (Rev_Index)
                              else "HEAD");
                        begin
                           Version.Reset.Reset_To_Commit (Repo, Mode, Target);

                           if Mode = Version.Reset.Hard then
                              declare
                                 New_Id : constant String :=
                                   Version.Refs.Current_Commit_Id (Repo);
                                 Obj    : constant Version.Objects.Git_Object :=
                                   Version.Objects.Read_Object
                                     (Repo,
                                      Version.Objects.To_Object_Id (New_Id));
                              begin
                                 Success_Line
                                   ("HEAD is now at "
                                    & New_Id (New_Id'First .. New_Id'First + 6)
                                    & " "
                                    & Version.Objects.Commit_Message_First_Line
                                        (Obj));
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "reflog" then
            declare
               Usage   : constant String := "version reflog [show] [REV]";
               Ref_Arg : Unbounded_String := To_Unbounded_String ("HEAD");
               I       : Positive := 2;
            begin
               if I <= Count and then Arg (I) = "show" then
                  I := I + 1;
               end if;
               if I <= Count then
                  Ref_Arg := To_Unbounded_String (Arg (I));
                  I := I + 1;
               end if;

               if I <= Count then
                  Usage_Error ("too many reflog arguments", Usage);
               else
                  declare
                     Repo    : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Entries :
                       constant Version.Reflog.Log_Entry_Vectors.Vector :=
                         Version.Reflog.Read_Entries (Repo, To_String (Ref_Arg));
                  begin
                     for J in reverse
                       Entries.First_Index .. Entries.Last_Index
                     loop
                        declare
                           E     : constant Version.Reflog.Log_Entry :=
                             Entries.Element (J);
                           New_S : constant String := To_String (E.New_Id);
                           Idx   : constant String :=
                             Natural'Image (Entries.Last_Index - J);
                        begin
                           Success_Line
                             (New_S (New_S'First .. New_S'First + 6)
                              & " " & To_String (Ref_Arg)
                              & "@{" & Idx (Idx'First + 1 .. Idx'Last) & "}: "
                              & To_String (E.Message));
                        end;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "mv" then
            declare
               Usage : constant String :=
                 "version mv [-f] SOURCE DEST | version mv [-f] SOURCE... DIR";
               Force    : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               I        : Positive := 2;
            begin
               while I <= Count and then Arg (I)'Length > 0
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  if Arg (I) = "-f" or else Arg (I) = "--force" then
                     Force := True;
                     I := I + 1;
                  elsif Arg (I) = "--" then
                     I := I + 1;
                     exit;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown mv option: " & To_String (Bad_Text),
                               Usage);
               elsif Count - I + 1 < 2 then
                  Usage_Error ("mv requires a source and a destination", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Last : constant String := Arg (Count);
                     Dst_Is_Dir : constant Boolean :=
                       Ada.Directories.Exists (Last)
                       and then Ada.Directories.Kind (Last)
                                = Ada.Directories.Directory;
                  begin
                     if Count - I + 1 = 2 and then not Dst_Is_Dir then
                        Version.Move.Move_Path
                          (Repo, Arg (I), Arg (Count), Force);
                     elsif not Dst_Is_Dir then
                        Usage_Error
                          ("destination must be a directory when moving "
                           & "multiple sources", Usage);
                     else
                        for J in I .. Count - 1 loop
                           Version.Move.Move_Path
                             (Repo, Arg (J),
                              Last & "/"
                              & Ada.Directories.Simple_Name (Arg (J)),
                              Force);
                        end loop;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "clean" then
            declare
               Usage : constant String := "version clean [-n] [-f] [-d] [-x]";
               Dry      : Boolean := False;
               Force    : Boolean := False;
               Opts     : Version.Clean.Clean_Options;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               I        : Positive := 2;

               procedure Apply_Flag (C : Character) is
               begin
                  case C is
                     when 'n' => Dry := True;
                     when 'f' => Force := True;
                     when 'd' => Opts.Directories := True;
                     when 'x' => Opts.Ignored := True;
                     when others =>
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String ("-" & C);
                  end case;
               end Apply_Flag;
            begin
               while I <= Count and then Arg (I)'Length > 0
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "--" then
                        I := I + 1;
                        exit;
                     elsif A = "--dry-run" then
                        Dry := True;
                     elsif A = "--force" then
                        Force := True;
                     elsif A'Length >= 2 and then A (A'First + 1) /= '-' then
                        for K in A'First + 1 .. A'Last loop
                           Apply_Flag (A (K));
                        end loop;
                     else
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                     end if;
                  end;
                  exit when Bad_Opt;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown clean option: " & To_String (Bad_Text),
                               Usage);
               elsif I <= Count then
                  Usage_Error ("clean does not support path arguments", Usage);
               elsif not Dry and then not Force then
                  Error_Line ("neither -n nor -f given; refusing to clean");
                  Set_Command_Failure;
               else
                  declare
                     Repo  : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Cands : constant Version.Clean.Path_Vectors.Vector :=
                       Version.Clean.Candidates (Repo, Opts);
                  begin
                     for C of Cands loop
                        declare
                           P : constant String := To_String (C);
                        begin
                           if Dry then
                              Success_Line ("Would remove " & P);
                           else
                              Version.Clean.Remove_Candidate (Repo, P);
                              Success_Line ("Removing " & P);
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "bundle" then
            declare
               Usage : constant String :=
                 "version bundle create FILE REF... | "
                 & "version bundle verify FILE | version bundle list-heads FILE";
            begin
               if Count < 3 then
                  Usage_Error ("bundle requires a subcommand and a file", Usage);
               else
                  declare
                     Sub  : constant String := Arg (2);
                     File : constant String := Arg (3);
                  begin
                     if Sub = "create" then
                        if Count < 4 then
                           Usage_Error
                             ("bundle create requires at least one ref", Usage);
                        else
                           declare
                              Repo : constant
                                Version.Repository.Repository_Handle :=
                                  Version.Repository.Open;
                              Refs : Version.Bundle.Ref_Vectors.Vector;
                           begin
                              for J in 4 .. Count loop
                                 declare
                                    A : constant String := Arg (J);
                                 begin
                                    if A = "--all" then
                                       for B of
                                         Version.Refs.List_Branches (Repo)
                                       loop
                                          Refs.Append
                                            (Version.Bundle.Ref_Entry'
                                               (Id =>
                                                Version.Branch.Resolve_Branch
                                                  (To_String (B)),
                                              Name => To_Unbounded_String
                                                ("refs/heads/"
                                                 & To_String (B))));
                                       end loop;
                                    elsif A = "HEAD" then
                                       Refs.Append
                                         (Version.Bundle.Ref_Entry'
                                            (Id =>
                                             Version.Objects.To_Object_Id
                                               (Version.Refs.Current_Commit_Id
                                                  (Repo)),
                                           Name =>
                                             To_Unbounded_String ("HEAD")));
                                    elsif Version.Branch.Branch_Exists (A) then
                                       Refs.Append
                                         (Version.Bundle.Ref_Entry'
                                            (Id =>
                                             Version.Branch.Resolve_Branch (A),
                                           Name => To_Unbounded_String
                                             ("refs/heads/" & A)));
                                    else
                                       raise Ada.IO_Exceptions.Data_Error with
                                         "unrecognized ref: " & A;
                                    end if;
                                 end;
                              end loop;
                              Version.Bundle.Create (Repo, File, Refs);
                           end;
                        end if;

                     elsif Sub = "verify" or else Sub = "list-heads" then
                        declare
                           Info : constant Version.Bundle.Bundle_Info :=
                             Version.Bundle.Read_Header (File);
                        begin
                           if Sub = "verify" then
                              if Natural (Info.Refs.Length) = 1 then
                                 Success_Line
                                   ("The bundle contains this ref:");
                              else
                                 Success_Line
                                   ("The bundle contains these"
                                    & Natural'Image (Natural (Info.Refs.Length))
                                    & " refs:");
                              end if;
                           end if;

                           for R of Info.Refs loop
                              Success_Line
                                (To_String (R.Id) & " " & To_String (R.Name));
                           end loop;

                           if Sub = "verify" then
                              if Info.Complete then
                                 Success_Line
                                   ("The bundle records a complete history.");
                              end if;
                              Success_Line (File & " is okay");
                           end if;
                        end;

                     elsif Sub = "unbundle" then
                        --  Unpack the bundle's objects into the object store
                        --  and print its ref lines (git parity; refs are not
                        --  created). Any trailing args are treated as ref
                        --  filters by git; we print all ref lines.
                        declare
                           Repo : constant
                             Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                           Info : Version.Bundle.Bundle_Info;
                        begin
                           Version.Bundle.Unbundle (Repo, File, Info);
                           for R of Info.Refs loop
                              Success_Line
                                (To_String (R.Id) & " " & To_String (R.Name));
                           end loop;
                        end;

                     else
                        Usage_Error
                          ("unknown bundle subcommand: " & Sub, Usage);
                     end if;
                  end;
               end if;
            end;

         elsif Command = "apply" then
            declare
               Usage    : constant String :=
                 "version apply [--check] [PATCHFILE]";
               Check    : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               File_Idx : Natural := 0;
               I        : Positive := 2;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0,
                             Buffer (Buffer'First)'Address,
                             Interfaces.C.size_t (Buffer'Length));
                     begin
                        exit when N <= 0;
                        Append
                          (Acc,
                           Buffer (Buffer'First ..
                                   Buffer'First + Integer (N) - 1));
                     end;
                  end loop;
                  return To_String (Acc);
               end Read_Stdin;
            begin
               while I <= Count and then Arg (I)'Length > 0
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  if Arg (I) = "--check" then
                     Check := True;
                  elsif Arg (I) = "--" then
                     I := I + 1;
                     exit;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if not Bad_Opt and then I <= Count then
                  File_Idx := I;
                  I := I + 1;
               end if;

               if Bad_Opt then
                  Usage_Error ("unknown apply option: " & To_String (Bad_Text),
                               Usage);
               elsif I <= Count then
                  Usage_Error ("apply accepts at most one patch file", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Patch_Text : constant String :=
                       (if File_Idx /= 0
                        then Version.Files.Read_Binary_File (Arg (File_Idx))
                        else Read_Stdin);
                  begin
                     Version.Apply.Apply_Patch
                       (Repo, Patch_Text, (Check => Check));
                  end;
               end if;
            end;

         elsif Command = "format-patch" then
            declare
               Usage    : constant String :=
                 "version format-patch [--stdout] [-o DIR] REVISION";
               Stdout   : Boolean := False;
               Out_Dir  : Unbounded_String := To_Unbounded_String (".");
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               Rev_Idx  : Natural := 0;
               I        : Positive := 2;

               function Pad4 (N : Natural) return String is
                  Img : constant String := Natural'Image (N);
                  S   : constant String := Img (Img'First + 1 .. Img'Last);
               begin
                  if S'Length >= 4 then
                     return S;
                  else
                     return [1 .. 4 - S'Length => '0'] & S;
                  end if;
               end Pad4;

               function Sanitize (Subj : String) return String is
                  R         : Unbounded_String;
                  Prev_Dash : Boolean := False;
               begin
                  for C of Subj loop
                     exit when Length (R) >= 52;
                     if C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' then
                        Append (R, C);
                        Prev_Dash := False;
                     elsif not Prev_Dash then
                        Append (R, '-');
                        Prev_Dash := True;
                     end if;
                  end loop;

                  declare
                     S     : constant String := To_String (R);
                     First : Integer := S'First;
                     Last  : Integer := S'Last;
                  begin
                     while Last >= First and then S (Last) = '-' loop
                        Last := Last - 1;
                     end loop;
                     while First <= Last and then S (First) = '-' loop
                        First := First + 1;
                     end loop;
                     return (if First > Last then "patch" else S (First .. Last));
                  end;
               end Sanitize;
            begin
               while I <= Count loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "--stdout" then
                        Stdout := True;
                     elsif A = "-o" then
                        if I = Count then
                           Bad_Opt := True;
                           Bad_Text := To_Unbounded_String ("-o (missing dir)");
                           exit;
                        end if;
                        Out_Dir := To_Unbounded_String (Arg (I + 1));
                        I := I + 1;
                     elsif A'Length >= 1 and then A (A'First) = '-' then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                        exit;
                     elsif Rev_Idx /= 0 then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                        exit;
                     else
                        Rev_Idx := I;
                     end if;
                  end;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error
                    ("unknown format-patch argument: " & To_String (Bad_Text),
                     Usage);
               elsif Rev_Idx = 0 then
                  Usage_Error ("format-patch requires a revision", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Rev  : constant String := Arg (Rev_Idx);
                     DD   : Natural := 0;
                  begin
                     for K in Rev'First .. Rev'Last - 1 loop
                        if Rev (K) = '.' and then Rev (K + 1) = '.' then
                           DD := K;
                           exit;
                        end if;
                     end loop;

                     declare
                        Since : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Commit
                            (Repo,
                             (if DD = 0 then Rev
                              else Rev (Rev'First .. DD - 1)));
                        Tip   : constant Version.Objects.Hex_Object_Id :=
                          (if DD = 0
                           then Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo))
                           else Version.Revisions.Resolve_Commit
                                  (Repo, Rev (DD + 2 .. Rev'Last)));
                        Commits : constant
                          Version.Rebase_State.Commit_Vectors.Vector :=
                            Version.Rebase.Commits_To_Replay (Repo, Tip, Since);
                        Total : constant Natural := Natural (Commits.Length);
                        N     : Natural := 0;
                     begin
                        for C of Commits loop
                           N := N + 1;
                           declare
                              Patch : constant String :=
                                Version.Format_Patch.Patch_For_Commit
                                  (Repo, C, N,
                                   (if Total = 0 then 1 else Total));
                           begin
                              if Stdout then
                                 Ada.Text_IO.Put (Patch);
                              else
                                 declare
                                    Obj : constant Version.Objects.Git_Object :=
                                      Version.Objects.Read_Object (Repo, C);
                                    Name : constant String :=
                                      Pad4 (N) & "-"
                                      & Sanitize
                                          (Version.Objects
                                             .Commit_Message_First_Line (Obj))
                                      & ".patch";
                                    Full : constant String :=
                                      Join (To_String (Out_Dir), Name);
                                 begin
                                    Version.Files.Write_Binary_File
                                      (Full, Patch);
                                    Success_Line (Full);
                                 end;
                              end if;
                           end;
                        end loop;
                     end;
                  end;
               end if;
            end;

         elsif Command = "am" then
            declare
               Mailbox : Unbounded_String;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0,
                             Buffer (Buffer'First)'Address,
                             Interfaces.C.size_t (Buffer'Length));
                     begin
                        exit when N <= 0;
                        Append
                          (Acc,
                           Buffer (Buffer'First ..
                                   Buffer'First + Integer (N) - 1));
                     end;
                  end loop;
                  return To_String (Acc);
               end Read_Stdin;
            begin
               if Count < 2 then
                  Mailbox := To_Unbounded_String (Read_Stdin);
               else
                  for J in 2 .. Count loop
                     Append
                       (Mailbox, Version.Files.Read_Binary_File (Arg (J)));
                  end loop;
               end if;

               declare
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
               begin
                  Version.Am.Apply_Mailbox (Repo, To_String (Mailbox));
               end;
            end;

         elsif Command = "cherry" then
            declare
               Usage    : constant String :=
                 "version cherry [-v] [UPSTREAM [HEAD]]";
               Verbose  : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               Up_Arg   : Unbounded_String;
               Head_Arg : Unbounded_String;
               Ops      : Natural := 0;
               I        : Positive := 2;
            begin
               while I <= Count loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "-v" then
                        Verbose := True;
                     elsif A'Length >= 1 and then A (A'First) = '-' then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                        exit;
                     else
                        Ops := Ops + 1;
                        if Ops = 1 then
                           Up_Arg := To_Unbounded_String (A);
                        elsif Ops = 2 then
                           Head_Arg := To_Unbounded_String (A);
                        else
                           Bad_Opt := True;
                           Bad_Text := To_Unbounded_String (A);
                           exit;
                        end if;
                     end if;
                  end;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown cherry argument: " & To_String (Bad_Text),
                               Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Head_Id : constant Version.Objects.Hex_Object_Id :=
                       (if Ops >= 2
                        then Version.Revisions.Resolve_Commit
                               (Repo, To_String (Head_Arg))
                        else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                     Up_Id : Version.Objects.Hex_Object_Id := Version.Objects.Zero_Object_Id;
                  begin
                     if Ops >= 1 then
                        Up_Id := Version.Revisions.Resolve_Commit
                                   (Repo, To_String (Up_Arg));
                     else
                        declare
                           Branch : constant String :=
                             Version.Refs.Current_Branch_Name (Repo);
                        begin
                           if not Version.Tracking.Has_Upstream (Repo, Branch)
                           then
                              raise Ada.IO_Exceptions.Data_Error with
                                "cherry: no upstream configured; give one";
                           end if;
                           Up_Id := Version.Revisions.Resolve_Commit
                             (Repo,
                              Version.Tracking.Remote_Tracking_Ref
                                (Version.Tracking.Upstream (Repo, Branch)));
                        end;
                     end if;

                     for E of Version.Cherry.Status (Repo, Up_Id, Head_Id) loop
                        declare
                           Mark : constant String :=
                             (if E.Equivalent_Upstream then "- " else "+ ");
                        begin
                           if Verbose then
                              Success_Line
                                (Mark & To_String (E.Id) & " "
                                 & Version.Objects.Commit_Message_First_Line
                                     (Version.Objects.Read_Object (Repo, E.Id)));
                           else
                              Success_Line (Mark & To_String (E.Id));
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "range-diff" then
            declare
               Usage : constant String :=
                 "version range-diff BASE..OLD BASE..NEW";

               function Dotdot (R : String) return Natural is
               begin
                  for K in R'First .. R'Last - 1 loop
                     if R (K) = '.' and then R (K + 1) = '.' then
                        return K;
                     end if;
                  end loop;
                  return 0;
               end Dotdot;

               function Pos_Img (N : Natural) return String is
                  Img : constant String := Natural'Image (N);
               begin
                  return (if N = 0 then "-" else Img (Img'First + 1 .. Img'Last));
               end Pos_Img;
            begin
               if Count /= 3
                 or else Dotdot (Arg (2)) = 0 or else Dotdot (Arg (3)) = 0
               then
                  Usage_Error ("range-diff requires two BASE..TIP ranges", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     R1 : constant String := Arg (2);
                     R2 : constant String := Arg (3);
                     D1 : constant Natural := Dotdot (R1);
                     D2 : constant Natural := Dotdot (R2);
                     Pairs : constant Version.Range_Diff.Pairing_Vectors.Vector :=
                       Version.Range_Diff.Compare
                         (Repo,
                          Old_Base => Version.Revisions.Resolve_Commit
                                        (Repo, R1 (R1'First .. D1 - 1)),
                          Old_Tip  => Version.Revisions.Resolve_Commit
                                        (Repo, R1 (D1 + 2 .. R1'Last)),
                          New_Base => Version.Revisions.Resolve_Commit
                                        (Repo, R2 (R2'First .. D2 - 1)),
                          New_Tip  => Version.Revisions.Resolve_Commit
                                        (Repo, R2 (D2 + 2 .. R2'Last)));

                     use type Version.Range_Diff.Pair_Status;
                  begin
                     for P of Pairs loop
                        declare
                           Old_H : constant String :=
                             (if P.Old_Pos = 0 then "--------"
                              else To_String (P.Old_Id)
                                     (1 .. 1 + 6));
                           New_H : constant String :=
                             (if P.New_Pos = 0 then "--------"
                              else To_String (P.New_Id)
                                     (1 .. 1 + 6));
                           Op : constant String :=
                             (case P.Status is
                                 when Version.Range_Diff.Unchanged => "=",
                                 when Version.Range_Diff.Changed   => "!",
                                 when Version.Range_Diff.Removed   => "<",
                                 when Version.Range_Diff.Added     => ">");
                        begin
                           Success_Line
                             (Pos_Img (P.Old_Pos) & ": " & Old_H & " " & Op & " "
                              & Pos_Img (P.New_Pos) & ": " & New_H & " "
                              & To_String (P.Subject));
                        end;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "shortlog" then
            declare
               Usage    : constant String := "version shortlog [-s] [-n] [REV]";
               Summary  : Boolean := False;
               By_Count : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               Rev_Idx  : Natural := 0;
               I        : Positive := 2;

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;
            begin
               while I <= Count loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "-s" then
                        Summary := True;
                     elsif A = "-n" then
                        By_Count := True;
                     elsif A'Length >= 1 and then A (A'First) = '-' then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                        exit;
                     elsif Rev_Idx /= 0 then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (A);
                        exit;
                     else
                        Rev_Idx := I;
                     end if;
                  end;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error
                    ("unknown shortlog argument: " & To_String (Bad_Text),
                     Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Tip : constant Version.Objects.Hex_Object_Id :=
                       (if Rev_Idx /= 0
                        then Version.Revisions.Resolve_Commit (Repo, Arg (Rev_Idx))
                        else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                     Groups : Version.Shortlog.Group_Vectors.Vector :=
                       Version.Shortlog.Summarize (Repo, Tip);

                     function Fewer
                       (L, R : Version.Shortlog.Author_Group) return Boolean is
                       (Natural (L.Subjects.Length)
                        > Natural (R.Subjects.Length));
                     package Sorter is new
                       Version.Shortlog.Group_Vectors.Generic_Sorting (Fewer);
                  begin
                     if By_Count then
                        Sorter.Sort (Groups);
                     end if;
                     for G of Groups loop
                        if Summary then
                           declare
                              Cnt : constant String :=
                                Img (Natural (G.Subjects.Length));
                              Pad : constant String :=
                                [1 .. (if Cnt'Length < 6 then 6 - Cnt'Length
                                       else 0) => ' '];
                           begin
                              Success_Line
                                (Pad & Cnt & Character'Val (9)
                                 & To_String (G.Name));
                           end;
                        else
                           Success_Line
                             (To_String (G.Name) & " ("
                              & Img (Natural (G.Subjects.Length)) & "):");
                           for S of G.Subjects loop
                              Success_Line ("      " & To_String (S));
                           end loop;
                           Success_Line ("");
                        end if;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "grep" then
            declare
               Usage      : constant String := "version grep [-n] [-i] PATTERN";
               Show_Lines : Boolean := False;
               Ignore     : Boolean := False;
               Bad_Opt    : Boolean := False;
               Bad_Text   : Unbounded_String;
               Pat_Idx    : Natural := 0;
               I          : Positive := 2;

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;
            begin
               while I <= Count and then Arg (I)'Length >= 1
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  if Arg (I) = "-n" then
                     Show_Lines := True;
                  elsif Arg (I) = "-i" then
                     Ignore := True;
                  elsif Arg (I) = "--" then
                     I := I + 1;
                     exit;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if not Bad_Opt and then I <= Count then
                  Pat_Idx := I;
                  I := I + 1;
               end if;

               if Bad_Opt then
                  Usage_Error ("unknown grep option: " & To_String (Bad_Text),
                               Usage);
               elsif Pat_Idx = 0 then
                  Usage_Error ("grep requires a pattern", Usage);
               elsif I <= Count then
                  Usage_Error ("grep path arguments are not supported", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Matches : constant Version.Grep.Match_Vectors.Vector :=
                       Version.Grep.Search (Repo, Arg (Pat_Idx), Ignore);
                  begin
                     for M of Matches loop
                        if Show_Lines then
                           Success_Line
                             (To_String (M.Path) & ":" & Img (M.Line_No) & ":"
                              & To_String (M.Text));
                        else
                           Success_Line
                             (To_String (M.Path) & ":" & To_String (M.Text));
                        end if;
                     end loop;
                     if Matches.Is_Empty then
                        Set_Command_Failure;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "describe" then
            declare
               Usage : constant String := "version describe [REV]";
            begin
               if Count > 2 then
                  Usage_Error ("describe takes at most one revision", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit : constant Version.Objects.Hex_Object_Id :=
                       (if Count = 2
                        then Version.Revisions.Resolve_Commit (Repo, Arg (2))
                        else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                  begin
                     Success_Line (Version.Describe.Describe (Repo, Commit));
                  end;
               end if;
            end;

         elsif Command = "notes" then
            declare
               Usage : constant String :=
                 "version notes add -m MSG [REV] | version notes show [REV]";
            begin
               if Count < 2 then
                  Usage_Error ("notes requires a subcommand", Usage);
               elsif Arg (2) = "add" then
                  declare
                     Msg      : Unbounded_String;
                     Has_Msg  : Boolean := False;
                     Bad_Opt  : Boolean := False;
                     Bad_Text : Unbounded_String;
                     Rev_Idx  : Natural := 0;
                     I        : Positive := 3;
                  begin
                     while I <= Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A = "-m" then
                              if I = Count then
                                 Bad_Opt := True;
                                 Bad_Text := To_Unbounded_String ("-m");
                                 exit;
                              end if;
                              Msg := To_Unbounded_String (Arg (I + 1));
                              Has_Msg := True;
                              I := I + 1;
                           elsif A'Length >= 1 and then A (A'First) = '-' then
                              Bad_Opt := True;
                              Bad_Text := To_Unbounded_String (A);
                              exit;
                           elsif Rev_Idx /= 0 then
                              Bad_Opt := True;
                              Bad_Text := To_Unbounded_String (A);
                              exit;
                           else
                              Rev_Idx := I;
                           end if;
                        end;
                        I := I + 1;
                     end loop;

                     if Bad_Opt then
                        Usage_Error
                          ("unknown notes argument: " & To_String (Bad_Text),
                           Usage);
                     elsif not Has_Msg then
                        Usage_Error ("notes add requires -m MESSAGE", Usage);
                     else
                        declare
                           Repo : constant
                             Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                           Commit : constant Version.Objects.Hex_Object_Id :=
                             (if Rev_Idx /= 0
                              then Version.Revisions.Resolve_Commit
                                     (Repo, Arg (Rev_Idx))
                              else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                        begin
                           Version.Notes.Add (Repo, Commit, To_String (Msg));
                        end;
                     end if;
                  end;
               elsif Arg (2) = "show" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit : constant Version.Objects.Hex_Object_Id :=
                       (if Count >= 3
                        then Version.Revisions.Resolve_Commit (Repo, Arg (3))
                        else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                     Note : constant String :=
                       Version.Notes.Show (Repo, Commit);
                  begin
                     if Note = "" then
                        Error_Line ("no note found for " & To_String (Commit));
                        Set_Command_Failure;
                     else
                        Ada.Text_IO.Put (Note);
                        if Note (Note'Last) /= Character'Val (10) then
                           Ada.Text_IO.New_Line;
                        end if;
                     end if;
                  end;
               else
                  Usage_Error
                    ("unknown notes subcommand: " & Arg (2), Usage);
               end if;
            end;

         elsif Command = "blame" then
            declare
               Usage : constant String := "version blame [REV] FILE";

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;
            begin
               if Count < 2 then
                  Usage_Error ("blame requires a file", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Two  : constant Boolean := Count >= 3;
                     Tip  : constant Version.Objects.Hex_Object_Id :=
                       (if Two
                        then Version.Revisions.Resolve_Commit (Repo, Arg (2))
                        else Version.Objects.To_Object_Id (Version.Refs.Current_Commit_Id (Repo)));
                     File : constant String := (if Two then Arg (3) else Arg (2));
                     Lines : constant Version.Blame.Blame_Vectors.Vector :=
                       Version.Blame.Blame_File (Repo, Tip, File);
                     N : Natural := 0;
                  begin
                     for L of Lines loop
                        N := N + 1;
                        Success_Line
                          (To_String (L.Commit)
                             (1 .. 1 + 7)
                           & " " & Img (N) & ") " & To_String (L.Text));
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "cat-file" then
            declare
               Usage : constant String :=
                 "version cat-file (-t|-s|-e|-p|--batch|--batch-check) OBJECT";
               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;

               Is_Batch : constant Boolean :=
                 Count >= 2
                 and then (Arg (2) = "--batch"
                           or else (Arg (2)'Length >= 8
                                    and then Arg (2)
                                      (Arg (2)'First .. Arg (2)'First + 7)
                                      = "--batch="));
               Is_Batch_Check : constant Boolean :=
                 Count >= 2
                 and then (Arg (2) = "--batch-check"
                           or else (Arg (2)'Length >= 14
                                    and then Arg (2)
                                      (Arg (2)'First .. Arg (2)'First + 13)
                                      = "--batch-check="));
            begin
               if Is_Batch or else Is_Batch_Check then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Eq   : constant Natural :=
                       Ada.Strings.Fixed.Index (Arg (2), "=");
                     Fmt  : constant String :=
                       (if Eq = 0
                        then "%(objectname) %(objecttype) %(objectsize)"
                        else Arg (2) (Eq + 1 .. Arg (2)'Last));

                     function Expand
                       (Token, Rest : String;
                        Id   : Version.Objects.Hex_Object_Id;
                        Obj  : Version.Objects.Git_Object) return String
                     is
                        Result : Unbounded_String;
                        I      : Natural := Fmt'First;
                        function Kind_Name return String is
                          (case Version.Objects.Kind (Obj) is
                              when Blob_Object   => "blob",
                              when Tree_Object   => "tree",
                              when Commit_Object => "commit",
                              when Tag_Object    => "tag",
                              when others        => "unknown");
                     begin
                        while I <= Fmt'Last loop
                           if Fmt (I) = '%' and then I < Fmt'Last
                             and then Fmt (I + 1) = '('
                           then
                              declare
                                 Close : Natural := 0;
                              begin
                                 for K in I + 2 .. Fmt'Last loop
                                    if Fmt (K) = ')' then
                                       Close := K;
                                       exit;
                                    end if;
                                 end loop;
                                 if Close = 0 then
                                    Append (Result, Fmt (I));
                                    I := I + 1;
                                 else
                                    declare
                                       A : constant String :=
                                         Fmt (I + 2 .. Close - 1);
                                    begin
                                       if A = "objectname" then
                                          Append (Result, To_String (Id));
                                       elsif A = "objecttype" then
                                          Append (Result, Kind_Name);
                                       elsif A = "objectsize" then
                                          Append (Result, Img
                                            (Version.Objects.Content
                                               (Obj)'Length));
                                       elsif A = "rest" then
                                          Append (Result, Rest);
                                       else
                                          Append (Result, Token);
                                       end if;
                                    end;
                                    I := Close + 1;
                                 end if;
                              end;
                           else
                              Append (Result, Fmt (I));
                              I := I + 1;
                           end if;
                        end loop;
                        return To_String (Result);
                     end Expand;
                  begin
                     while not Ada.Text_IO.End_Of_File loop
                        declare
                           Line  : constant String := Ada.Text_IO.Get_Line;
                           Sp    : constant Natural :=
                             Ada.Strings.Fixed.Index (Line, " ");
                           Token : constant String :=
                             (if Sp = 0 then Line
                              else Line (Line'First .. Sp - 1));
                           Rest  : constant String :=
                             (if Sp = 0 then ""
                              else Line (Sp + 1 .. Line'Last));
                        begin
                           if Token = "" then
                              null;
                           else
                              begin
                                 declare
                                    Id : constant Version.Objects.Hex_Object_Id
                                      := Version.Revisions.Resolve
                                           (Repo, Token);
                                    Obj : constant Version.Objects.Git_Object
                                      := Version.Objects.Read_Object (Repo, Id);
                                 begin
                                    Success_Line (Expand (Token, Rest, Id, Obj));
                                    if Is_Batch then
                                       Ada.Text_IO.Put
                                         (Version.Objects.Content (Obj));
                                       Ada.Text_IO.New_Line;
                                    end if;
                                 end;
                              exception
                                 when others =>
                                    Success_Line (Token & " missing");
                              end;
                           end if;
                        end;
                     end loop;
                  end;
               elsif Count /= 3 then
                  Usage_Error ("cat-file requires an option and an object",
                               Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Id : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve (Repo, Arg (3));
                     Obj : constant Version.Objects.Git_Object :=
                       Version.Objects.Read_Object (Repo, Id);
                     K : constant Version.Objects.Object_Kind :=
                       Version.Objects.Kind (Obj);
                     function Kind_Name return String is
                       (case K is
                           when Blob_Object   => "blob",
                           when Tree_Object   => "tree",
                           when Commit_Object => "commit",
                           when Tag_Object    => "tag",
                           when others        => "unknown");
                  begin
                     if Arg (2) = "-t" then
                        Success_Line (Kind_Name);
                     elsif Arg (2) = "-s" then
                        Success_Line (Img (Version.Objects.Content (Obj)'Length));
                     elsif Arg (2) = "-e" then
                        null;  --  resolve+read succeeded: exists, exit 0
                     elsif Arg (2) = "-p" then
                        if K = Tree_Object then
                           for E of Version.Objects.Flatten_Tree (Repo, Id) loop
                              Success_Line
                                (To_String (E.Mode) & " "
                                 & (if E.Kind = Tree_Gitlink then "commit"
                                    else "blob")
                                 & " " & To_String (E.Id)
                                 & Character'Val (9) & To_String (E.Path));
                           end loop;
                        else
                           Ada.Text_IO.Put (Version.Objects.Content (Obj));
                        end if;
                     else
                        Usage_Error ("unknown cat-file option: " & Arg (2),
                                     Usage);
                     end if;
                  end;
               end if;
            end;

         elsif Command = "rev-parse" then
            declare
               Usage : constant String :=
                 "version rev-parse [--abbrev-ref] REV...";
               Abbrev : Boolean := False;
               I      : Positive := 2;
            begin
               if Count >= 2 and then Arg (2) = "--abbrev-ref" then
                  Abbrev := True;
                  I := 3;
               end if;
               if I > Count then
                  Usage_Error ("rev-parse requires a revision", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     for J in I .. Count loop
                        if Abbrev and then Arg (J) = "HEAD" then
                           declare
                              H : constant Version.Refs.Head_Info :=
                                Version.Refs.Read_Head (Repo);
                           begin
                              if Version.Refs.Is_Attached (H) then
                                 Success_Line (Version.Refs.Branch_Name (H));
                              else
                                 Success_Line ("HEAD");
                              end if;
                           end;
                        elsif Abbrev then
                           Success_Line (Arg (J));
                        else
                           Success_Line
                             (To_String (Version.Revisions.Resolve (Repo, Arg (J))));
                        end if;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "ls-files" then
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Entries : constant Version.Staging.Index_Entry_Vectors.Vector :=
                 Version.Staging.Load (Repo);
            begin
               for E of Entries loop
                  if E.Stage = 0 then
                     Success_Line (To_String (E.Path));
                  end if;
               end loop;
            end;

         elsif Command = "ls-tree" then
            declare
               Usage : constant String :=
                 "version ls-tree [-r] [--name-only] TREE-ISH";
               Name_Only : Boolean := False;
               Recursive : Boolean := False;
               Bad_Opt   : Boolean := False;
               Bad_Text  : Unbounded_String;
               Tree_Idx  : Natural := 0;
               I         : Positive := 2;

               --  git renders modes as six zero-padded octal digits.
               function Mode6 (M : String) return String is
                 ((1 .. 6 - M'Length => '0') & M);
            begin
               while I <= Count loop
                  if Arg (I) = "-r" then
                     Recursive := True;
                  elsif Arg (I) = "--name-only" then
                     Name_Only := True;
                  elsif Arg (I)'Length >= 1 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  elsif Tree_Idx = 0 then
                     Tree_Idx := I;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown ls-tree argument: "
                               & To_String (Bad_Text), Usage);
               elsif Tree_Idx = 0 then
                  Usage_Error ("ls-tree requires a tree-ish", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Tree : constant Version.Objects.Hex_Object_Id :=
                       Version.Revisions.Resolve_Tree (Repo, Arg (Tree_Idx));
                     Entries : constant
                       Version.Objects.Tree_Entry_Vectors.Vector :=
                         (if Recursive
                          then Version.Objects.Flatten_Tree (Repo, Tree)
                          else Version.Objects.Tree_Entries (Repo, Tree));
                  begin
                     for E of Entries loop
                        if Name_Only then
                           Success_Line (To_String (E.Path));
                        else
                           Success_Line
                             (Mode6 (To_String (E.Mode)) & " "
                              & (case E.Kind is
                                    when Tree_Directory => "tree",
                                    when Tree_Gitlink   => "commit",
                                    when Tree_Blob      => "blob")
                              & " " & To_String (E.Id)
                              & Character'Val (9) & To_String (E.Path));
                        end if;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "hash-object" then
            declare
               Usage : constant String :=
                 "version hash-object [-w] [--stdin] [FILE]";
               Write_It : Boolean := False;
               Stdin    : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               File_Idx : Natural := 0;
               I        : Positive := 2;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read (0, Buffer (Buffer'First)'Address,
                                Interfaces.C.size_t (Buffer'Length));
                     begin
                        exit when N <= 0;
                        Append (Acc, Buffer (Buffer'First ..
                                Buffer'First + Integer (N) - 1));
                     end;
                  end loop;
                  return To_String (Acc);
               end Read_Stdin;
            begin
               while I <= Count and then Arg (I)'Length >= 1
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  if Arg (I) = "-w" then
                     Write_It := True;
                  elsif Arg (I) = "--stdin" then
                     Stdin := True;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;
               if not Bad_Opt and then not Stdin and then I <= Count then
                  File_Idx := I;
               end if;

               if Bad_Opt then
                  Usage_Error ("unknown hash-object option: "
                               & To_String (Bad_Text), Usage);
               elsif not Stdin and then File_Idx = 0 then
                  Usage_Error ("hash-object requires --stdin or a file", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Content : constant String :=
                       (if Stdin then Read_Stdin
                        else Version.Files.Read_Binary_File (Arg (File_Idx)));
                  begin
                     if Write_It then
                        Success_Line
                          (To_String (Version.Write.Write_Blob (Repo, Content)));
                     else
                        Success_Line
                          (Version.Objects.To_String
                             (Version.Objects.Compute_Object_Id
                                (Version.Repository.Algorithm (Repo),
                                 "blob", Content)));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "write-tree" then
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
            begin
               Success_Line
                 (To_String (Version.Write.Write_Tree_From_Index
                            (Repo, Version.Staging.Load (Repo))));
            end;

         elsif Command = "commit-tree" then
            declare
               Usage : constant String :=
                 "version commit-tree TREE [-p PARENT]... -m MESSAGE";
               Tree_Idx : Natural := 0;
               Has_Msg  : Boolean := False;
               Bad_Opt  : Boolean := False;
               Bad_Text : Unbounded_String;
               Msg      : Unbounded_String;
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Parents : Version.Objects.Object_Id_Vectors.Vector;
               I : Positive := 2;
            begin
               while I <= Count loop
                  if Arg (I) = "-p" then
                     if I = Count then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String ("-p");
                        exit;
                     end if;
                     Parents.Append
                       (Version.Revisions.Resolve_Commit (Repo, Arg (I + 1)));
                     I := I + 1;
                  elsif Arg (I) = "-m" then
                     if I = Count then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String ("-m");
                        exit;
                     end if;
                     Msg := To_Unbounded_String (Arg (I + 1));
                     Has_Msg := True;
                     I := I + 1;
                  elsif Arg (I)'Length >= 1 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  elsif Tree_Idx = 0 then
                     Tree_Idx := I;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown commit-tree argument: "
                               & To_String (Bad_Text), Usage);
               elsif Tree_Idx = 0 or else not Has_Msg then
                  Usage_Error ("commit-tree requires a tree and -m MESSAGE",
                               Usage);
               else
                  Success_Line
                    (To_String (Version.Write.Write_Commit_With_Parents
                       (Repo,
                        Version.Revisions.Resolve_Tree (Repo, Arg (Tree_Idx)),
                        Parents, To_String (Msg))));
               end if;
            end;

         elsif Command = "update-ref" then
            declare
               Usage : constant String :=
                 "version update-ref REF NEWVALUE [OLDVALUE]"
                 & " | version update-ref -d REF [OLDVALUE]";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Tx : Version.Ref_Transaction.Transaction;
            begin
               if Count >= 3 and then Arg (2) = "-d" then
                  Version.Ref_Transaction.Start (Tx, Repo);
                  Version.Ref_Transaction.Add_Delete
                    (Tx, Arg (3),
                     (if Count >= 4
                      then To_String (Version.Revisions.Resolve (Repo, Arg (4)))
                      else ""));
                  Version.Ref_Transaction.Commit (Tx);
               elsif Count = 3 or else Count = 4 then
                  Version.Ref_Transaction.Start (Tx, Repo);
                  Version.Ref_Transaction.Add_Update
                    (Tx, Arg (2),
                     Version.Revisions.Resolve (Repo, Arg (3)),
                     (if Count = 4
                      then To_String (Version.Revisions.Resolve (Repo, Arg (4)))
                      else ""));
                  Version.Ref_Transaction.Commit (Tx);
               else
                  Usage_Error ("update-ref requires a ref and a value", Usage);
               end if;
            end;

         elsif Command = "symbolic-ref" then
            declare
               Usage : constant String :=
                 "version symbolic-ref HEAD [REF]";
            begin
               if Count = 2 and then Arg (2) = "HEAD" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     H : constant Version.Refs.Head_Info :=
                       Version.Refs.Read_Head (Repo);
                  begin
                     if Version.Refs.Is_Attached (H) then
                        Success_Line
                          ("refs/heads/" & Version.Refs.Branch_Name (H));
                     else
                        raise Ada.IO_Exceptions.Data_Error with
                          "ref HEAD is not a symbolic ref";
                     end if;
                  end;
               elsif Count = 3 and then Arg (2) = "HEAD" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     Version.Refs.Write_Symbolic_HEAD (Repo, Arg (3));
                  end;
               else
                  Usage_Error
                    ("symbolic-ref supports only HEAD (read or set)", Usage);
               end if;
            end;

         elsif Command = "show-ref" then
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
            begin
               for B of Version.Refs.List_Branches (Repo) loop
                  declare
                     R : constant String := "refs/heads/" & To_String (B);
                  begin
                     Success_Line
                       (To_String (Version.Refs.Resolve_Ref (Repo, R)) & " " & R);
                  end;
               end loop;
               for Tg of Version.Tags.List_Tags loop
                  declare
                     R : constant String := "refs/tags/" & To_String (Tg);
                  begin
                     Success_Line
                       (To_String (Version.Refs.Resolve_Ref (Repo, R)) & " " & R);
                  end;
               end loop;
            end;

         elsif Command = "read-tree" then
            declare
               Usage : constant String := "version read-tree TREE-ISH";
            begin
               if Count /= 2 then
                  Usage_Error ("read-tree requires a tree-ish", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     Version.Staging.Write_From_Tree
                       (Repo,
                        Version.Revisions.Resolve_Tree (Repo, Arg (2)));
                  end;
               end if;
            end;

         elsif Command = "credential" then
            declare
               Usage : constant String :=
                 "version credential (fill|approve|reject)";
               Action : constant String := (if Count >= 2 then Arg (2) else "");
               Input  : Unbounded_String;
               Cred   : Version.Credential.Credential;
            begin
               if Action /= "fill" and then Action /= "approve"
                 and then Action /= "reject"
               then
                  Usage_Error
                    ("credential requires fill, approve, or reject", Usage);
               else
                  while not Ada.Text_IO.End_Of_File loop
                     Append (Input, Ada.Text_IO.Get_Line & Character'Val (10));
                  end loop;
                  Version.Credential.Parse (To_String (Input), Cred);
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Action = "fill" then
                        Version.Credential.Fill (Repo, Cred);
                        Ada.Text_IO.Put (Version.Credential.Serialize (Cred));
                     elsif Action = "approve" then
                        Version.Credential.Approve (Repo, Cred);
                     else
                        Version.Credential.Reject (Repo, Cred);
                     end if;
                  end;
               end if;
            end;

         elsif Command = "verify-tag" or else Command = "verify-commit" then
            declare
               Usage : constant String :=
                 "version " & Command & " OBJECT...";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Is_Tag : constant Boolean := Command = "verify-tag";
            begin
               if Count < 2 then
                  Usage_Error (Command & " requires an object", Usage);
               else
                  for J in 2 .. Count loop
                     declare
                        Id : constant Version.Objects.Hex_Object_Id :=
                          (if Is_Tag
                           then Version.Refs.Resolve_Ref
                                  (Repo, "refs/tags/" & Arg (J))
                           else Version.Revisions.Resolve (Repo, Arg (J)));
                        Result : constant Version.Verify.Verify_Result :=
                          Version.Verify.Verify_Object (Repo, Id);
                     begin
                        case Result is
                           when Version.Verify.Good_Signature =>
                              null;   --  gpg already reported the good signature
                           when Version.Verify.Bad_Signature =>
                              Set_Command_Failure;
                           when Version.Verify.No_Signature =>
                              Error_Line
                                ("no signature found on " & Arg (J));
                              Set_Command_Failure;
                        end case;
                     end;
                  end loop;
               end if;
            end;

         elsif Command = "update-index" then
            declare
               Usage : constant String :=
                 "version update-index [--add] [--remove] [--force-remove] "
                 & "[--chmod=(+|-)x] [--cacheinfo <mode>[,<sha>,<path>]] "
                 & "[--] <path>...";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Add_Mode     : Boolean := False;
               Remove_Mode  : Boolean := False;
               Force_Remove : Boolean := False;
               Has_Chmod    : Boolean := False;
               Chmod_Exec   : Boolean := False;
               End_Opts     : Boolean := False;
               I            : Positive := 2;

               function Is_Tracked (Path : String) return Boolean is
                 (Version.Staging.Find_Path
                    (Version.Staging.Load (Repo), Path) /= Natural'Last);

               procedure Remove_From_Index (Path : String) is
                  E : Version.Staging.Index_Entry_Vectors.Vector :=
                    Version.Staging.Load (Repo);
               begin
                  Version.Staging.Remove_Path (E, Path);
                  Version.Staging.Write (Repo, E);
               end Remove_From_Index;

               procedure Insert_Cacheinfo (Mode, Sha, Path : String) is
                  E : Version.Staging.Index_Entry_Vectors.Vector :=
                    Version.Staging.Load (Repo);
               begin
                  if Version.Staging.Find_Path (E, Path) = Natural'Last
                    and then not Add_Mode
                  then
                     raise Ada.IO_Exceptions.Data_Error with
                       Path & ": cannot add to the index - missing --add option?";
                  end if;
                  Version.Staging.Replace_Entry
                    (E,
                     (Path  => To_Unbounded_String (Path),
                      Id    => Version.Objects.To_Object_Id (Sha),
                      Mode  => To_Unbounded_String (Mode),
                      Stage => 0));
                  Version.Staging.Write (Repo, E);
               end Insert_Cacheinfo;

               procedure Apply_Chmod (Path : String) is
                  E   : Version.Staging.Index_Entry_Vectors.Vector :=
                    Version.Staging.Load (Repo);
                  Pos : constant Natural :=
                    Version.Staging.Find_Path (E, Path);
               begin
                  if Pos = Natural'Last then
                     return;
                  end if;
                  declare
                     Ent : Version.Staging.Index_Entry := E.Element (Pos);
                  begin
                     Ent.Mode := To_Unbounded_String
                       (if Chmod_Exec then "100755" else "100644");
                     E.Replace_Element (Pos, Ent);
                     Version.Staging.Write (Repo, E);
                  end;
               end Apply_Chmod;

               procedure Process_Path (Path : String) is
                  Present : constant Boolean := Ada.Directories.Exists (Path);
               begin
                  if Force_Remove then
                     Remove_From_Index (Path);
                  elsif Remove_Mode and then not Present then
                     Remove_From_Index (Path);
                  elsif not Present then
                     raise Ada.IO_Exceptions.Data_Error with
                       Path & ": does not exist and --remove not passed";
                  elsif not Add_Mode and then not Is_Tracked (Path) then
                     raise Ada.IO_Exceptions.Data_Error with
                       Path & ": cannot add to the index - missing --add option?";
                  else
                     Stage_Path (Path);
                  end if;
                  if Has_Chmod and then not Force_Remove then
                     Apply_Chmod (Path);
                  end if;
               end Process_Path;
            begin
               if Count < 2 then
                  Usage_Error ("update-index requires an option or path", Usage);
               end if;
               while I <= Count loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if not End_Opts and then A = "--" then
                        End_Opts := True;
                     elsif not End_Opts and then A = "--add" then
                        Add_Mode := True;
                     elsif not End_Opts and then A = "--remove" then
                        Remove_Mode := True;
                     elsif not End_Opts and then A = "--force-remove" then
                        Force_Remove := True;
                     elsif not End_Opts and then A = "--refresh" then
                        null;  --  up-to-date index: nothing to surface
                     elsif not End_Opts and then A = "--chmod=+x" then
                        Has_Chmod := True;
                        Chmod_Exec := True;
                     elsif not End_Opts and then A = "--chmod=-x" then
                        Has_Chmod := True;
                        Chmod_Exec := False;
                     elsif not End_Opts and then A = "--cacheinfo" then
                        if I < Count
                          and then Ada.Strings.Fixed.Index (Arg (I + 1), ",") > 0
                        then
                           declare
                              Spec : constant String := Arg (I + 1);
                              C1 : constant Natural :=
                                Ada.Strings.Fixed.Index (Spec, ",");
                              C2 : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Spec (C1 + 1 .. Spec'Last), ",");
                           begin
                              Insert_Cacheinfo
                                (Spec (Spec'First .. C1 - 1),
                                 Spec (C1 + 1 .. C2 - 1),
                                 Spec (C2 + 1 .. Spec'Last));
                           end;
                           I := I + 1;
                        elsif I + 3 <= Count then
                           Insert_Cacheinfo
                             (Arg (I + 1), Arg (I + 2), Arg (I + 3));
                           I := I + 3;
                        else
                           Usage_Error
                             ("update-index --cacheinfo requires "
                              & "<mode> <sha> <path>", Usage);
                        end if;
                     elsif not End_Opts and then A'Length > 2
                       and then A (A'First .. A'First + 1) = "--"
                     then
                        Usage_Error
                          ("unknown update-index option: " & A, Usage);
                     else
                        Process_Path (A);
                     end if;
                  end;
                  I := I + 1;
               end loop;
            end;

         elsif Command = "for-each-ref" then
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Patterns : Version.Ref_Format.String_Vectors.Vector;
               Format   : Unbounded_String;
               Sort_Key : Unbounded_String;
               Ref_Cnt  : Natural := 0;

               function Option_Value
                 (A : String; Name : String) return String is
               begin
                  return A (A'First + Name'Length .. A'Last);
               end Option_Value;
            begin
               for I in 2 .. Count loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A'Length >= 9
                       and then A (A'First .. A'First + 8) = "--format="
                     then
                        Format := To_Unbounded_String (Option_Value (A, "--format="));
                     elsif A'Length >= 7
                       and then A (A'First .. A'First + 6) = "--sort="
                     then
                        Sort_Key := To_Unbounded_String (Option_Value (A, "--sort="));
                     elsif A'Length >= 8
                       and then A (A'First .. A'First + 7) = "--count="
                     then
                        Ref_Cnt := Natural'Value (Option_Value (A, "--count="));
                     elsif A'Length >= 2 and then A (A'First .. A'First + 1) = "--"
                     then
                        Usage_Error
                          ("unknown for-each-ref option: " & A,
                           "version for-each-ref [--format=<fmt>] [--sort=<key>]"
                           & " [--count=<n>] [<pattern>...]");
                     else
                        Patterns.Append (A);
                     end if;
                  end;
               end loop;

               for Line of Version.Ref_Format.For_Each_Ref
                 (Repo     => Repo,
                  Patterns => Patterns,
                  Format   => To_String (Format),
                  Sort_Key => To_String (Sort_Key),
                  Count    => Ref_Cnt)
               loop
                  Success_Line (Line);
               end loop;
            end;

         elsif Command = "rev-list" then
            declare
               Usage : constant String := "version rev-list [--count] REV";
               Count_Only : Boolean := False;
               Bad_Opt    : Boolean := False;
               Bad_Text   : Unbounded_String;
               Rev_Idx    : Natural := 0;
               I          : Positive := 2;

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;
            begin
               while I <= Count loop
                  if Arg (I) = "--count" then
                     Count_Only := True;
                  elsif Arg (I)'Length >= 1 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  elsif Rev_Idx = 0 then
                     Rev_Idx := I;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  Usage_Error ("unknown rev-list argument: "
                               & To_String (Bad_Text), Usage);
               elsif Rev_Idx = 0 then
                  Usage_Error ("rev-list requires a revision", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Result : Version.History.Commit_Id_Vectors.Vector;
                     Queue  : Version.History.Commit_Id_Vectors.Vector;

                     function Seen (X : Version.Objects.Hex_Object_Id)
                        return Boolean is
                     begin
                        for C of Result loop
                           if C = X then
                              return True;
                           end if;
                        end loop;
                        return False;
                     end Seen;
                  begin
                     Queue.Append
                       (Version.Revisions.Resolve_Commit (Repo, Arg (Rev_Idx)));
                     while not Queue.Is_Empty loop
                        declare
                           C : constant Version.Objects.Hex_Object_Id :=
                             Queue.Last_Element;
                        begin
                           Queue.Delete_Last;
                           if not Seen (C) then
                              Result.Append (C);
                              for P of Version.History.Parent_Commits (Repo, C)
                              loop
                                 if not Seen (P) then
                                    Queue.Append (P);
                                 end if;
                              end loop;
                           end if;
                        end;
                     end loop;

                     if Count_Only then
                        Success_Line (Img (Natural (Result.Length)));
                     else
                        for C of Result loop
                           Success_Line (To_String (C));
                        end loop;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "pull" then
            declare
               Usage : constant String :=
                 "version pull [--rebase] [--ff-only] [REMOTE [BRANCH]]";
               Do_Rebase  : Boolean := False;
               FF_Only    : Boolean := False;
               Bad_Opt    : Boolean := False;
               Bad_Text   : Unbounded_String;
               Remote_Arg : Unbounded_String;
               Branch_Arg : Unbounded_String;
               I          : Positive := 2;
            begin
               while I <= Count and then Arg (I)'Length > 0
                 and then Arg (I) (Arg (I)'First) = '-'
               loop
                  if Arg (I) = "--rebase" then
                     Do_Rebase := True;
                  elsif Arg (I) = "--ff-only" then
                     FF_Only := True;
                  else
                     Bad_Opt := True;
                     Bad_Text := To_Unbounded_String (Arg (I));
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if not Bad_Opt and then I <= Count then
                  Remote_Arg := To_Unbounded_String (Arg (I));
                  I := I + 1;
               end if;
               if not Bad_Opt and then I <= Count then
                  Branch_Arg := To_Unbounded_String (Arg (I));
                  I := I + 1;
               end if;

               if Bad_Opt then
                  Usage_Error ("unknown pull option: " & To_String (Bad_Text),
                               Usage);
               elsif I <= Count then
                  Usage_Error ("too many pull arguments", Usage);
               else
                  declare
                     Repo   : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Branch : constant String :=
                       Version.Refs.Current_Branch_Name (Repo);
                     Remote : Unbounded_String := Remote_Arg;
                     Target : Unbounded_String;
                  begin
                     if Length (Branch_Arg) > 0 then
                        Target := To_Unbounded_String
                          ("refs/remotes/" & To_String (Remote_Arg)
                           & "/" & To_String (Branch_Arg));
                     elsif Version.Tracking.Has_Upstream (Repo, Branch) then
                        declare
                           Info : constant Version.Tracking.Upstream_Info :=
                             Version.Tracking.Upstream (Repo, Branch);
                        begin
                           if Length (Remote) = 0 then
                              Remote := Info.Remote;
                           end if;
                           Target := To_Unbounded_String
                             (Version.Tracking.Remote_Tracking_Ref (Info));
                        end;
                     else
                        raise Ada.IO_Exceptions.Data_Error with
                          "there is no tracking information for the current "
                          & "branch";
                     end if;

                     Version.Fetch.Fetch (To_String (Remote));

                     if Do_Rebase then
                        Version.Rebase.Start (To_String (Target));
                        Success_Line
                          ("Successfully rebased and updated " & Branch & ".");
                     else
                        declare
                           Before  : constant String :=
                             Version.Refs.Current_Commit_Id (Repo);
                           Options : Version.Branch.Merge_Options;
                        begin
                           if FF_Only then
                              Options.Fast_Forward :=
                                Version.Branch.Fast_Forward_Only;
                              Options.Fast_Forward_Explicit := True;
                           end if;

                           Version.Branch.Merge
                             (Target  => To_String (Target),
                              Options => Options);

                           declare
                              After : constant String :=
                                Version.Refs.Current_Commit_Id (Repo);
                           begin
                              if After = Before then
                                 Success_Line ("Already up to date.");
                              elsif Version.Objects.Is_Valid_Hex_Object_Id
                                      (Before)
                                and then
                                  Version.Objects.Is_Valid_Hex_Object_Id (After)
                                and then Version.History.Parent_Commits
                                  (Repo      => Repo,
                                   Commit_Id =>
                                     Version.Objects.To_Object_Id (After))
                                  .Length = 1
                                and then Version.History.Is_Ancestor
                                  (Repo       => Repo,
                                   Base_Id    =>
                                     Version.Objects.To_Object_Id (Before),
                                   Derived_Id =>
                                     Version.Objects.To_Object_Id (After))
                              then
                                 Success_Line ("Fast-forward");
                              else
                                 Success_Line
                                   ("Merge made by the 'ort' strategy.");
                              end if;
                           end;
                        exception
                           when E : Ada.IO_Exceptions.Data_Error =>
                              if Ada.Exceptions.Exception_Message (E)
                                = "cannot merge: conflicts recorded"
                              then
                                 Error_Line
                                   ("Automatic merge failed; fix conflicts and "
                                    & "then commit the result.");
                                 Set_Command_Failure;
                              else
                                 raise;
                              end if;
                        end;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "tag" then

            if Count >= 2 and then Arg (2) = "create" then
               declare
                  Usage         : constant String :=
                    "version tag create [-a|-s|-u KEY] NAME [REV] [-m MESSAGE]";
                  I             : Natural := 3;
                  Annotated     : Boolean := False;
                  Has_Message   : Boolean := False;
                  Signing_Key   : Unbounded_String;
                  Message       : Unbounded_String;
                  Name          : Unbounded_String;
                  Revision      : Unbounded_String;
                  Operand_Count : Natural := 0;
               begin
                  while I <= Count loop
                     if Arg (I) = "-a" then
                        if Annotated then
                           Usage_Error ("duplicate option: -a", Usage);
                           return;
                        end if;

                        Annotated := True;
                        I := I + 1;

                     elsif Arg (I) = "-s" then
                        --  Sign with the default key (implies annotated).
                        Annotated := True;
                        Signing_Key := To_Unbounded_String ("default");
                        I := I + 1;

                     elsif Arg (I) = "-u" then
                        if I = Count then
                           Usage_Error ("-u requires a key id", Usage);
                           return;
                        end if;
                        Annotated := True;
                        Signing_Key := To_Unbounded_String (Arg (I + 1));
                        I := I + 2;

                     elsif Arg (I)'Length > 2
                       and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "-u"
                     then
                        Annotated := True;
                        Signing_Key :=
                          To_Unbounded_String
                            (Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last));
                        I := I + 1;

                     elsif Arg (I) = "-m" then
                        if Has_Message then
                           Usage_Error ("duplicate option: -m", Usage);
                           return;
                        elsif I = Count then
                           Usage_Error ("-m requires a message", Usage);
                           return;
                        end if;

                        Has_Message := True;
                        Message := To_Unbounded_String (Arg (I + 1));
                        I := I + 2;

                     elsif Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error
                          ("unknown tag create option: " & Arg (I), Usage);
                        return;

                     else
                        Operand_Count := Operand_Count + 1;
                        if Operand_Count = 1 then
                           Name := To_Unbounded_String (Arg (I));
                        elsif Operand_Count = 2 then
                           Revision := To_Unbounded_String (Arg (I));
                        else
                           Usage_Error
                             ("too many tag create arguments", Usage);
                           return;
                        end if;
                        I := I + 1;
                     end if;
                  end loop;

                  if Operand_Count = 0 then
                     Usage_Error ("missing tag name", Usage);
                     return;
                  elsif Annotated and then not Has_Message then
                     Usage_Error
                       ("annotated tag requires -m MESSAGE", Usage);
                     return;
                  elsif Has_Message and then not Annotated then
                     Usage_Error
                       ("-m requires annotated tag option -a", Usage);
                     return;
                  elsif Annotated and then Operand_Count = 1 then
                     Version.Tags.Create_Annotated_Tag
                       (Name        => To_String (Name),
                        Message     => To_String (Message),
                        Signing_Key => To_String (Signing_Key));
                     Success_Line
                       ("created annotated tag " & To_String (Name));
                  elsif Annotated then
                     Version.Tags.Create_Annotated_Tag
                       (Name        => To_String (Name),
                        Revision    => To_String (Revision),
                        Message     => To_String (Message),
                        Signing_Key => To_String (Signing_Key));
                     Success_Line
                       ("created annotated tag " & To_String (Name));
                  elsif Operand_Count = 1 then
                     Version.Tags.Create_Tag (To_String (Name));
                     Success_Line ("created tag " & To_String (Name));
                  else
                     Version.Tags.Create_Tag
                       (Name     => To_String (Name),
                        Revision => To_String (Revision));
                     Success_Line ("created tag " & To_String (Name));
                  end if;
               end;

            elsif Count = 2 and then Arg (2) = "list" then
               declare
                  Tags : constant Version.Tags.Tag_Name_Vectors.Vector :=
                    Version.Tags.List_Tags;
               begin
                  if not Tags.Is_Empty then
                     for I in Tags.First_Index .. Tags.Last_Index loop
                        Ada.Text_IO.Put_Line
                          (Ada.Strings.Unbounded.To_String (Tags.Element (I)));
                     end loop;
                  end if;
               end;

            elsif Count = 4
              and then Arg (2) = "list"
              and then Arg (3) = "--points-at"
            then
               Ada.Text_IO.Put
                 (Version.Tags.List_Tags_Points_At_Text (Arg (4)));

            elsif Count = 4
              and then Arg (2) = "list"
              and then Arg (3) = "--contains"
            then
               Ada.Text_IO.Put
                 (Version.Tags.List_Tags_Containing_Text (Arg (4)));

            elsif Count = 3 and then Arg (2) = "exists" then
               if not Version.Tags.Tag_Exists (Arg (3)) then
                  Ada.Command_Line.Set_Exit_Status (Command_Failure_Exit);
               end if;

            elsif Count = 3 and then Arg (2) = "resolve" then
               Ada.Text_IO.Put (Version.Tags.Resolve_Tag_Text (Arg (3)));

            elsif Count = 3 and then Arg (2) = "peel" then
               Ada.Text_IO.Put (Version.Tags.Peel_Tag_Text (Arg (3)));

            elsif Count = 3 and then Arg (2) = "show" then
               Ada.Text_IO.Put (Version.Tags.Show_Tag_Text (Arg (3)));

            elsif Count = 4 and then Arg (2) = "rename" then
               Success_Line
                 (Version.Tags.Rename_Tag_Text
                    (Old_Name => Arg (3), New_Name => Arg (4)));

            elsif Count = 3
              and then (Arg (2) = "delete" or else Arg (2) = "remove")
            then
               Success_Line (Version.Tags.Delete_Tag_Text (Arg (3)));

            else
               Expected ("version tag create NAME");
               Error_Line ("      or: version tag create NAME REV");
               Error_Line ("      or: version tag create -a NAME -m MESSAGE");
               Error_Line ("      or: version tag create -a NAME REV -m MESSAGE");
               Error_Line ("      or: version tag delete NAME");
               Error_Line ("      or: version tag remove NAME");
               Error_Line ("      or: version tag rename OLD NEW");
               Error_Line ("      or: version tag list");
               Error_Line ("      or: version tag list --points-at REV");
               Error_Line ("      or: version tag list --contains REV");
               Error_Line ("      or: version tag exists NAME");
               Error_Line ("      or: version tag resolve NAME");
               Error_Line ("      or: version tag peel NAME");
               Error_Line ("      or: version tag show NAME");
               return;
            end if;

         elsif Command = "config" then
            declare
               Subcommand : constant String :=
                 (if Count >= 2 then Arg (2) else "");

               function Is_Option (Text : String) return Boolean is
               begin
                  return Text'Length > 0 and then Text (Text'First) = '-';
               end Is_Option;

               procedure Reject_Extra
                 (Index : Positive; Context, Usage : String) is
               begin
                  if Is_Option (Arg (Index)) then
                     Usage_Error
                       ("unknown config " & Context & " option: " & Arg (Index),
                        Usage);
                  else
                     Usage_Error
                       ("too many config " & Context & " arguments", Usage);
                  end if;
               end Reject_Extra;

               procedure Parse_Config_Key
                 (Usage, Context : String;
                  Key            : out Unbounded_String;
                  OK             : out Boolean) is
               begin
                  OK := False;

                  if Count < 3 then
                     Usage_Error ("missing config key", Usage);
                  elsif Is_Option (Arg (3)) then
                     Usage_Error
                       ("unknown config " & Context & " option: " & Arg (3),
                        Usage);
                  elsif Count > 3 then
                     Reject_Extra (4, Context, Usage);
                  else
                     Key := To_Unbounded_String (Arg (3));
                     OK := True;
                  end if;
               end Parse_Config_Key;
            begin
               if Count = 1 then
                  Usage_Error
                    ("missing config subcommand", "version config <subcommand>");
                  return;

               elsif Subcommand = "list" then
                  declare
                     Usage : constant String := "version config list";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "list", Usage);
                        return;
                     end if;

                     Ada.Text_IO.Put
                       (Version.Config.List_Text (Version.Repository.Open));
                  end;

               elsif Subcommand = "keys" then
                  declare
                     Usage : constant String := "version config keys";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "keys", Usage);
                        return;
                     end if;

                     Ada.Text_IO.Put
                       (Version.Config.Keys_Text (Version.Repository.Open));
                  end;

               elsif Subcommand = "get" then
                  declare
                     Usage : constant String := "version config get KEY";
                     Key   : Unbounded_String;
                     OK    : Boolean := False;
                  begin
                     Parse_Config_Key (Usage, "get", Key, OK);
                     if not OK then
                        return;
                     end if;

                     Ada.Text_IO.Put
                       (Version.Config.Get_Text
                          (Version.Repository.Open, To_String (Key)));
                  end;

               elsif Subcommand = "has" then
                  declare
                     Usage : constant String := "version config has KEY";
                     Key   : Unbounded_String;
                     OK    : Boolean := False;
                  begin
                     Parse_Config_Key (Usage, "has", Key, OK);
                     if not OK then
                        return;
                     end if;

                     if not Version.Config.Has_Key
                       (Version.Repository.Open, To_String (Key))
                     then
                        Ada.Command_Line.Set_Exit_Status (Command_Failure_Exit);
                     end if;
                  end;

               elsif Subcommand = "set" then
                  declare
                     Usage : constant String := "version config set KEY VALUE";
                     WT    : constant Boolean :=
                       Count >= 3 and then Arg (3) = "--worktree";
                     Base  : constant Positive := (if WT then 4 else 3);
                  begin
                     if Count < Base then
                        Usage_Error ("missing config key", Usage);
                     elsif Is_Option (Arg (Base)) then
                        Usage_Error
                          ("unknown config set option: " & Arg (Base), Usage);
                     elsif Count < Base + 1 then
                        Usage_Error ("missing config value", Usage);
                     elsif Count > Base + 1 then
                        Reject_Extra (Base + 2, "set", Usage);
                     elsif WT then
                        Version.Config.Set_Key_Worktree
                          (Version.Repository.Open, Arg (Base), Arg (Base + 1));
                        Success_Line ("set config " & Arg (Base));
                     else
                        Version.Config.Set_Key
                          (Version.Repository.Open, Arg (Base), Arg (Base + 1));
                        Success_Line ("set config " & Arg (Base));
                     end if;
                  end;

               elsif Subcommand = "unset" then
                  declare
                     Usage : constant String := "version config unset KEY";
                     WT    : constant Boolean :=
                       Count >= 3 and then Arg (3) = "--worktree";
                     Base  : constant Positive := (if WT then 4 else 3);
                  begin
                     if Count < Base then
                        Usage_Error ("missing config key", Usage);
                     elsif Is_Option (Arg (Base)) then
                        Usage_Error
                          ("unknown config unset option: " & Arg (Base), Usage);
                     elsif Count > Base then
                        Reject_Extra (Base + 1, "unset", Usage);
                     elsif WT then
                        Version.Config.Unset_Key_Worktree
                          (Version.Repository.Open, Arg (Base));
                        Success_Line ("unset config " & Arg (Base));
                     else
                        Version.Config.Unset_Key
                          (Version.Repository.Open, Arg (Base));
                        Success_Line ("unset config " & Arg (Base));
                     end if;
                  end;

               elsif Is_Option (Subcommand) then
                  Usage_Error
                    ("unknown config option: " & Subcommand,
                     "version config <subcommand>");
                  return;
               else
                  Usage_Error
                    ("unknown config subcommand: " & Subcommand,
                     "version config <subcommand>");
                  return;
               end if;
            end;

         elsif Command = "remote" then
            declare
               Subcommand : constant String :=
                 (if Count >= 2 then Arg (2) else "");

               function Is_Option (Text : String) return Boolean is
               begin
                  return Text'Length > 0 and then Text (Text'First) = '-';
               end Is_Option;

               procedure Reject_Extra
                 (Index : Positive; Context, Usage : String) is
               begin
                  if Is_Option (Arg (Index)) then
                     Usage_Error
                       ("unknown remote " & Context & " option: " & Arg (Index),
                        Usage);
                  else
                     Usage_Error
                       ("too many remote " & Context & " arguments", Usage);
                  end if;
               end Reject_Extra;

               procedure Parse_One_Remote_Name
                 (Usage, Context : String;
                  Name           : out Unbounded_String;
                  OK             : out Boolean) is
               begin
                  OK := False;

                  if Count < 3 then
                     Usage_Error ("missing remote name", Usage);
                  elsif Is_Option (Arg (3)) then
                     Usage_Error
                       ("unknown remote " & Context & " option: " & Arg (3),
                        Usage);
                  elsif Count > 3 then
                     Reject_Extra (4, Context, Usage);
                  else
                     Name := To_Unbounded_String (Arg (3));
                     OK := True;
                  end if;
               end Parse_One_Remote_Name;
            begin
               if Count = 1 then
                  Usage_Error
                    ("missing remote subcommand", "version remote <subcommand>");
                  return;

               elsif Subcommand = "list" then
                  declare
                     Usage : constant String := "version remote list";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "list", Usage);
                        return;
                     end if;

                     Ada.Text_IO.Put (Version.Remotes.List_Text);
                  end;

               elsif Subcommand = "get-url" then
                  declare
                     Usage : constant String := "version remote get-url NAME";
                     Name  : Unbounded_String;
                     OK    : Boolean := False;
                  begin
                     Parse_One_Remote_Name (Usage, "get-url", Name, OK);
                     if not OK then
                        return;
                     end if;

                     Ada.Text_IO.Put
                       (Version.Remotes.Get_Url_Text (To_String (Name)));
                  end;

               elsif Subcommand = "exists" then
                  declare
                     Usage : constant String := "version remote exists NAME";
                     Name  : Unbounded_String;
                     OK    : Boolean := False;
                  begin
                     Parse_One_Remote_Name (Usage, "exists", Name, OK);
                     if not OK then
                        return;
                     end if;

                     if not Version.Remotes.Remote_Exists (To_String (Name)) then
                        Ada.Command_Line.Set_Exit_Status (Command_Failure_Exit);
                     end if;
                  end;

               elsif Subcommand = "add" then
                  declare
                     Usage : constant String := "version remote add NAME URL";
                  begin
                     if Count < 3 then
                        Usage_Error ("missing remote name", Usage);
                        return;
                     elsif Is_Option (Arg (3)) then
                        Usage_Error
                          ("unknown remote add option: " & Arg (3), Usage);
                        return;
                     elsif Count < 4 then
                        Usage_Error ("missing remote URL", Usage);
                        return;
                     elsif Count > 4 then
                        Reject_Extra (5, "add", Usage);
                        return;
                     end if;

                     Version.Remotes.Add_Remote (Name => Arg (3), Url => Arg (4));
                     Success_Line ("added remote " & Arg (3));
                  end;

               elsif Subcommand = "set-url" then
                  declare
                     Usage : constant String := "version remote set-url NAME URL";
                  begin
                     if Count < 3 then
                        Usage_Error ("missing remote name", Usage);
                        return;
                     elsif Is_Option (Arg (3)) then
                        Usage_Error
                          ("unknown remote set-url option: " & Arg (3), Usage);
                        return;
                     elsif Count < 4 then
                        Usage_Error ("missing remote URL", Usage);
                        return;
                     elsif Count > 4 then
                        Reject_Extra (5, "set-url", Usage);
                        return;
                     end if;

                     Version.Remotes.Set_Url (Name => Arg (3), Url => Arg (4));
                     Success_Line ("updated remote " & Arg (3));
                  end;

               elsif Subcommand = "rename" then
                  declare
                     Usage : constant String := "version remote rename OLD NEW";
                  begin
                     if Count < 3 then
                        Usage_Error ("missing remote name", Usage);
                        return;
                     elsif Is_Option (Arg (3)) then
                        Usage_Error
                          ("unknown remote rename option: " & Arg (3), Usage);
                        return;
                     elsif Count < 4 then
                        Usage_Error ("missing remote new name", Usage);
                        return;
                     elsif Count > 4 then
                        Reject_Extra (5, "rename", Usage);
                        return;
                     end if;

                     Version.Remotes.Rename_Remote
                       (Old_Name => Arg (3), New_Name => Arg (4));
                     Success_Line
                       ("renamed remote " & Arg (3) & " to " & Arg (4));
                  end;

               elsif Subcommand = "delete" or else Subcommand = "remove" then
                  declare
                     Usage : constant String :=
                       "version remote " & Subcommand & " NAME";
                     Name  : Unbounded_String;
                     OK    : Boolean := False;
                  begin
                     Parse_One_Remote_Name (Usage, Subcommand, Name, OK);
                     if not OK then
                        return;
                     end if;

                     Version.Remotes.Delete_Remote (To_String (Name));
                     Success_Line ("deleted remote " & To_String (Name));
                  end;

               elsif Subcommand = "prune" then
                  declare
                     Usage         : constant String :=
                       "version remote prune [--dry-run] NAME";
                     I             : Natural := 3;
                     Has_Dry_Run   : Boolean := False;
                     Remote_Name   : Unbounded_String;
                     Operand_Count : Natural := 0;
                  begin
                     while I <= Count loop
                        if Arg (I) = "--dry-run" then
                           if Has_Dry_Run then
                              Usage_Error ("duplicate option: --dry-run", Usage);
                              return;
                           end if;

                           Has_Dry_Run := True;

                        elsif Is_Option (Arg (I)) then
                           Usage_Error
                             ("unknown remote prune option: " & Arg (I), Usage);
                           return;

                        else
                           Operand_Count := Operand_Count + 1;
                           if Operand_Count = 1 then
                              Remote_Name := To_Unbounded_String (Arg (I));
                           else
                              Usage_Error
                                ("too many remote prune arguments", Usage);
                              return;
                           end if;
                        end if;

                        I := I + 1;
                     end loop;

                     if Operand_Count = 0 then
                        Usage_Error ("missing remote name", Usage);
                        return;
                     elsif Has_Dry_Run then
                        Ada.Text_IO.Put
                          (Version.Remotes.Prune_Dry_Run_Text
                             (To_String (Remote_Name)));
                     else
                        Ada.Text_IO.Put
                          (Version.Remotes.Prune_Text (To_String (Remote_Name)));
                     end if;
                  end;

               elsif Is_Option (Subcommand) then
                  Usage_Error
                    ("unknown remote option: " & Subcommand,
                     "version remote <subcommand>");
                  return;
               else
                  Usage_Error
                    ("unknown remote subcommand: " & Subcommand,
                     "version remote <subcommand>");
                  return;
               end if;
            end;

         elsif Command = "fetch" then
            declare
               Usage         : constant String :=
                 "version fetch [--depth N] REMOTE";
               I             : Natural := 2;
               Has_Depth     : Boolean := False;
               Depth_Value   : Positive := 1;
               Remote_Name   : Unbounded_String;
               Operand_Count : Natural := 0;
            begin
               while I <= Count loop
                  if Arg (I) = "--depth" then
                     if Has_Depth then
                        Usage_Error ("duplicate option: --depth", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("--depth requires a value", Usage);
                        return;
                     end if;

                     Has_Depth := True;
                     Depth_Value := Parse_Depth_Argument (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown fetch option: " & Arg (I), Usage);
                     return;

                  else
                     Operand_Count := Operand_Count + 1;
                     if Operand_Count = 1 then
                        Remote_Name := To_Unbounded_String (Arg (I));
                     else
                        Usage_Error ("too many fetch arguments", Usage);
                        return;
                     end if;
                     I := I + 1;
                  end if;
               end loop;

               if Operand_Count = 0 then
                  Usage_Error ("missing remote", Usage);
                  return;
               elsif Has_Depth then
                  Version.Fetch.Fetch
                    (Remote_Name => To_String (Remote_Name),
                     Depth       => Depth_Value);
               else
                  Version.Fetch.Fetch (To_String (Remote_Name));
               end if;

               Success_Line ("fetched " & To_String (Remote_Name));
            end;

         elsif Command = "clone" then
            declare
               Usage         : constant String :=
                 "version clone [--depth N|--recursive|--filter SPEC]"
                 & " SOURCE TARGET";
               I             : Natural := 2;
               Has_Depth     : Boolean := False;
               Depth_Value   : Positive := 1;
               Recursive     : Boolean := False;
               Has_Filter    : Boolean := False;
               Filter        : Unbounded_String;
               Source        : Unbounded_String;
               Target        : Unbounded_String;
               Operand_Count : Natural := 0;

               Filter_Eq     : constant String := "--filter=";
            begin
               while I <= Count loop
                  if Arg (I)'Length >= Filter_Eq'Length
                    and then Arg (I) (Arg (I)'First
                                      .. Arg (I)'First + Filter_Eq'Length - 1)
                             = Filter_Eq
                  then
                     if Has_Filter then
                        Usage_Error ("duplicate option: --filter", Usage);
                        return;
                     end if;

                     Has_Filter := True;
                     Filter := To_Unbounded_String
                       (Arg (I) (Arg (I)'First + Filter_Eq'Length
                                 .. Arg (I)'Last));
                     I := I + 1;

                  elsif Arg (I) = "--filter" then
                     if Has_Filter then
                        Usage_Error ("duplicate option: --filter", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("--filter requires a value", Usage);
                        return;
                     end if;

                     Has_Filter := True;
                     Filter := To_Unbounded_String (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I) = "--depth" then
                     if Has_Depth then
                        Usage_Error ("duplicate option: --depth", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("--depth requires a value", Usage);
                        return;
                     end if;

                     Has_Depth := True;
                     Depth_Value := Parse_Depth_Argument (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I) = "--recursive" then
                     if Recursive then
                        Usage_Error ("duplicate option: --recursive", Usage);
                        return;
                     end if;

                     Recursive := True;
                     I := I + 1;

                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown clone option: " & Arg (I), Usage);
                     return;

                  else
                     Operand_Count := Operand_Count + 1;
                     if Operand_Count = 1 then
                        Source := To_Unbounded_String (Arg (I));
                     elsif Operand_Count = 2 then
                        Target := To_Unbounded_String (Arg (I));
                     else
                        Usage_Error ("too many clone arguments", Usage);
                        return;
                     end if;
                     I := I + 1;
                  end if;
               end loop;

               if Operand_Count < 2 then
                  Usage_Error ("missing clone source or target", Usage);
                  return;
               elsif Has_Depth and then Recursive then
                  Usage_Error
                    ("clone --depth cannot be combined with --recursive",
                     Usage);
                  return;
               elsif Has_Filter and then (Has_Depth or else Recursive) then
                  Usage_Error
                    ("clone --filter cannot be combined with --depth or"
                     & " --recursive", Usage);
                  return;
               elsif Has_Filter and then Length (Filter) = 0 then
                  Usage_Error ("--filter requires a non-empty spec", Usage);
                  return;
               elsif Has_Filter then
                  Version.Clone.Clone_Filtered
                    (Source => To_String (Source),
                     Target => To_String (Target),
                     Filter => To_String (Filter));
               elsif Has_Depth then
                  Version.Clone.Clone
                    (Source => To_String (Source),
                     Target => To_String (Target),
                     Depth  => Depth_Value);
               elsif Recursive then
                  Version.Submodules.Clone_Recursive
                    (Url => To_String (Source), Target => To_String (Target));
               else
                  Version.Clone.Clone
                    (Source => To_String (Source),
                     Target => To_String (Target));
               end if;

               Success_Line
                 ("cloned " & To_String (Source) & " to " & To_String (Target));
            end;

         elsif Command = "pack-refs" then
            declare
               Usage : constant String := "version pack-refs [--prune]";
               Prune_Loose : Boolean := False;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--prune" then
                        if Prune_Loose then
                           Usage_Error ("duplicate option: --prune", Usage);
                           return;
                        end if;
                        Prune_Loose := True;

                     elsif Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error
                          ("unknown pack-refs option: " & Arg (I), Usage);
                        return;

                     else
                        Usage_Error ("too many pack-refs arguments", Usage);
                        return;
                     end if;
                  end loop;
               end if;

               Version.Packed_Refs.Pack_Refs
                 (Repo => Version.Repository.Open,
                  Prune_Loose => Prune_Loose);
               Success_Line ("packed refs");
            end;

         elsif Command = "verify" then
            declare
               Usage : constant String := "version verify";
            begin
               if Count /= 1 then
                  Usage_Error ("verify takes no arguments", Usage);
                  return;
               end if;

               declare
                  Result : constant Version.Maintenance.Maintenance_Result :=
                    Version.Maintenance.Verify (Version.Repository.Open);
               begin
                  Ada.Text_IO.Put_Line
                    ("verify: ok ("
                     & Natural_Image (Result.Object_Count)
                     & " objects)");
               end;
            end;

         elsif Command = "repack" then
            declare
               Usage : constant String := "version repack";
            begin
               if Count /= 1 then
                  Usage_Error ("repack takes no arguments", Usage);
                  return;
               end if;

               declare
                  Result : constant Version.Maintenance.Maintenance_Result :=
                    Version.Maintenance.Repack (Version.Repository.Open);
               begin
                  Success_Line
                    ("repack: wrote "
                     & Natural_Image (Result.Object_Count)
                     & " objects");
               end;
            end;

         elsif Command = "prune" then
            declare
               Usage   : constant String := "version prune [--dry-run|--now]";
               Dry_Run : Boolean := True;
               Now     : Boolean := False;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--dry-run" then
                        if not Dry_Run or else Now then
                           Usage_Error
                             ("prune --dry-run cannot be combined with --now",
                              Usage);
                           return;
                        elsif I > 2 then
                           Usage_Error ("duplicate option: --dry-run", Usage);
                           return;
                        end if;
                        Dry_Run := True;

                     elsif Arg (I) = "--now" then
                        if Now then
                           Usage_Error ("duplicate option: --now", Usage);
                           return;
                        elsif Dry_Run and then I > 2 then
                           Usage_Error
                             ("prune --dry-run cannot be combined with --now",
                              Usage);
                           return;
                        end if;
                        Dry_Run := False;
                        Now := True;

                     elsif Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error
                          ("unknown prune option: " & Arg (I), Usage);
                        return;

                     else
                        Usage_Error ("too many prune arguments", Usage);
                        return;
                     end if;
                  end loop;
               end if;

               declare
                  Result : constant Version.Maintenance.Maintenance_Result :=
                    Version.Maintenance.Prune
                      (Repo    => Version.Repository.Open,
                       Dry_Run => Dry_Run,
                       Now     => Now);
               begin
                  if Dry_Run then
                     Success_Line
                       ("prune: "
                        & Natural_Image (Result.Unreachable_Count)
                        & " unreachable loose objects");
                  else
                     Success_Line
                       ("prune: deleted "
                        & Natural_Image (Result.Deleted_Count)
                        & " loose objects");
                  end if;
               end;
            end;

         elsif Command = "gc" then
            declare
               Usage   : constant String := "version gc [--dry-run|--now]";
               Dry_Run : Boolean := True;
               Now     : Boolean := False;
            begin
               if Count >= 2 then
                  for I in 2 .. Count loop
                     if Arg (I) = "--dry-run" then
                        if not Dry_Run or else Now then
                           Usage_Error
                             ("gc --dry-run cannot be combined with --now",
                              Usage);
                           return;
                        elsif I > 2 then
                           Usage_Error ("duplicate option: --dry-run", Usage);
                           return;
                        end if;
                        Dry_Run := True;

                     elsif Arg (I) = "--now" then
                        if Now then
                           Usage_Error ("duplicate option: --now", Usage);
                           return;
                        elsif Dry_Run and then I > 2 then
                           Usage_Error
                             ("gc --dry-run cannot be combined with --now",
                              Usage);
                           return;
                        end if;
                        Dry_Run := False;
                        Now := True;

                     elsif Arg (I)'Length > 0
                       and then Arg (I) (Arg (I)'First) = '-'
                     then
                        Usage_Error ("unknown gc option: " & Arg (I), Usage);
                        return;

                     else
                        Usage_Error ("too many gc arguments", Usage);
                        return;
                     end if;
                  end loop;
               end if;

               declare
                  Result : constant Version.Maintenance.Maintenance_Result :=
                    Version.Maintenance.GC
                      (Repo => Version.Repository.Open, Dry_Run => Dry_Run);
               begin
                  if Dry_Run then
                     Success_Line
                       ("gc: ok ("
                        & Natural_Image (Result.Object_Count)
                        & " objects, "
                        & Natural_Image (Result.Unreachable_Count)
                        & " unreachable)");
                  else
                     Success_Line
                       ("gc: ok ("
                        & Natural_Image (Result.Object_Count)
                        & " objects, "
                        & Natural_Image (Result.Deleted_Count)
                        & " deleted)");
                  end if;
               end;
            end;

         elsif Command = "push" then
            declare
               Usage         : constant String :=
                 "version push [--no-verify] [--force] [--atomic] REMOTE"
                 & " REFSPEC..."
                 & " | version push [--no-verify] --tags [REMOTE]"
                 & " | version push [--no-verify] [--atomic] --delete REMOTE"
                 & " REF...";
               I             : Natural := 2;
               No_Verify     : Boolean := False;
               Force         : Boolean := False;
               Tags          : Boolean := False;
               Delete        : Boolean := False;
               Atomic        : Boolean := False;
               Remote_Name   : Unbounded_String;
               Operand_Count : Natural := 0;
               Refspecs      : Version.Ref_Format.String_Vectors.Vector;

               Atomic_Cmds   : Version.Push.Atomic_Command_Vectors.Vector;
               Atomic_Force  : Boolean := False;

               function Normalize_Ref (R : String) return String is
                 (if R'Length >= 5 and then R (R'First .. R'First + 4) = "refs/"
                  then R else "refs/heads/" & R);

               --  Expand a "<src>*<...>:<dst>*<...>" wildcard refspec into one
               --  concrete push per matching local ref (git parity; git sends
               --  these in one batched request, we send one per ref, matching
               --  the default non-atomic end state).
               procedure Expand_Glob_Push
                 (Remote, Src_Pat, Dst_Pat : String;
                  Spec_Force, Run_Hooks    : Boolean)
               is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Src_Star : constant Natural :=
                    Ada.Strings.Fixed.Index (Src_Pat, "*");
                  Dst_Star : constant Natural :=
                    Ada.Strings.Fixed.Index (Dst_Pat, "*");
                  Src_Pre  : constant String :=
                    Src_Pat (Src_Pat'First .. Src_Star - 1);
                  Src_Suf  : constant String :=
                    Src_Pat (Src_Star + 1 .. Src_Pat'Last);
                  Dst_Pre  : constant String :=
                    Dst_Pat (Dst_Pat'First .. Dst_Star - 1);
                  Dst_Suf  : constant String :=
                    Dst_Pat (Dst_Star + 1 .. Dst_Pat'Last);
                  Patterns : Version.Ref_Format.String_Vectors.Vector;
               begin
                  Patterns.Append (Src_Pat);
                  for R of Version.Ref_Format.For_Each_Ref
                    (Repo => Repo, Patterns => Patterns,
                     Format => "%(refname)")
                  loop
                     declare
                        Mid : constant String :=
                          R (R'First + Src_Pre'Length
                             .. R'Last - Src_Suf'Length);
                        Dst : constant String := Dst_Pre & Mid & Dst_Suf;
                     begin
                        Version.Push.Push_Refspec
                          (Remote_Name => Remote,
                           Source      => R,
                           Dest_Ref    => Dst,
                           Force       => Spec_Force,
                           Run_Hooks   => Run_Hooks);
                        Success_Line
                          ("pushed " & R & " to " & Dst & " on " & Remote);
                     end;
                  end loop;
               end Expand_Glob_Push;

               procedure Process_One_Refspec
                 (Remote, Raw : String; Opt_Force, Run_Hooks : Boolean)
               is
                  Spec_Force : Boolean := Opt_Force;
                  Spec_First : Positive := Raw'First;
                  Colon      : Natural := 0;
               begin
                  if Raw'Length > 0 and then Raw (Raw'First) = '+' then
                     Spec_Force := True;
                     Spec_First := Raw'First + 1;
                  end if;

                  for J in Spec_First .. Raw'Last loop
                     if Raw (J) = ':' then
                        Colon := J;
                        exit;
                     end if;
                  end loop;

                  if Colon = 0 then
                     Version.Push.Push
                       (Remote_Name => Remote,
                        Branch_Name => Raw (Spec_First .. Raw'Last),
                        Run_Hooks   => Run_Hooks,
                        Force       => Spec_Force);
                     Success_Line
                       ("pushed " & Raw (Spec_First .. Raw'Last)
                        & " to " & Remote);
                  else
                     declare
                        Src : constant String := Raw (Spec_First .. Colon - 1);
                        Dst : constant String := Raw (Colon + 1 .. Raw'Last);
                     begin
                        if Src'Length = 0 and then Dst'Length = 0 then
                           --  Bare ":" -> matching push (update every remote
                           --  branch that shares a name with a local branch).
                           Version.Push.Push_Matching
                             (Remote_Name => Remote,
                              Force        => Spec_Force,
                              Run_Hooks    => Run_Hooks);
                           Success_Line
                             ("pushed matching branches to " & Remote);
                        elsif Dst'Length = 0 then
                           Usage_Error
                             ("push refspec is missing a destination ref",
                              Usage);
                        elsif Src'Length = 0 then
                           Version.Push.Delete_Ref
                             (Remote_Name => Remote,
                              Ref_Name    => Normalize_Ref (Dst),
                              Run_Hooks   => Run_Hooks);
                           Success_Line
                             ("deleted " & Normalize_Ref (Dst)
                              & " on " & Remote);
                        elsif Ada.Strings.Fixed.Index (Src, "*") /= 0
                          and then Ada.Strings.Fixed.Index (Dst, "*") /= 0
                        then
                           Expand_Glob_Push
                             (Remote, Src, Dst, Spec_Force, Run_Hooks);
                        else
                           Version.Push.Push_Refspec
                             (Remote_Name => Remote,
                              Source      => Src,
                              Dest_Ref    => Normalize_Ref (Dst),
                              Force       => Spec_Force,
                              Run_Hooks   => Run_Hooks);
                           Success_Line
                             ("pushed " & Src & " to "
                              & Normalize_Ref (Dst) & " on " & Remote);
                        end if;
                     end;
                  end if;
               end Process_One_Refspec;

               --  Parse one refspec into atomic command(s) (glob refspecs
               --  expand to one command per matching local ref) for a single
               --  batched Push_Atomic call.
               procedure Collect_Atomic (Raw : String; Opt_Force : Boolean) is
                  Spec_Force : Boolean := Opt_Force;
                  Spec_First : Positive := Raw'First;
                  Colon      : Natural := 0;
               begin
                  if Raw'Length > 0 and then Raw (Raw'First) = '+' then
                     Spec_Force := True;
                     Spec_First := Raw'First + 1;
                  end if;
                  if Spec_Force then
                     Atomic_Force := True;
                  end if;

                  for J in Spec_First .. Raw'Last loop
                     if Raw (J) = ':' then
                        Colon := J;
                        exit;
                     end if;
                  end loop;

                  if Colon = 0 then
                     Atomic_Cmds.Append
                       (Version.Push.Atomic_Command'
                          (Source   =>
                             To_Unbounded_String (Raw (Spec_First .. Raw'Last)),
                           Dest_Ref =>
                             To_Unbounded_String
                               (Normalize_Ref (Raw (Spec_First .. Raw'Last))),
                           Delete   => False));
                  else
                     declare
                        Src : constant String := Raw (Spec_First .. Colon - 1);
                        Dst : constant String := Raw (Colon + 1 .. Raw'Last);
                     begin
                        if Dst'Length = 0 then
                           Usage_Error
                             ("push refspec is missing a destination ref",
                              Usage);
                        elsif Src'Length = 0 then
                           Atomic_Cmds.Append
                             (Version.Push.Atomic_Command'
                                (Source   => Null_Unbounded_String,
                                 Dest_Ref =>
                                   To_Unbounded_String (Normalize_Ref (Dst)),
                                 Delete   => True));
                        elsif Ada.Strings.Fixed.Index (Src, "*") /= 0
                          and then Ada.Strings.Fixed.Index (Dst, "*") /= 0
                        then
                           declare
                              Repo : constant
                                Version.Repository.Repository_Handle :=
                                  Version.Repository.Open;
                              Src_Star : constant Natural :=
                                Ada.Strings.Fixed.Index (Src, "*");
                              Dst_Star : constant Natural :=
                                Ada.Strings.Fixed.Index (Dst, "*");
                              Src_Pre  : constant String :=
                                Src (Src'First .. Src_Star - 1);
                              Src_Suf  : constant String :=
                                Src (Src_Star + 1 .. Src'Last);
                              Dst_Pre  : constant String :=
                                Dst (Dst'First .. Dst_Star - 1);
                              Dst_Suf  : constant String :=
                                Dst (Dst_Star + 1 .. Dst'Last);
                              Patterns :
                                Version.Ref_Format.String_Vectors.Vector;
                           begin
                              Patterns.Append (Src);
                              for R of Version.Ref_Format.For_Each_Ref
                                (Repo => Repo, Patterns => Patterns,
                                 Format => "%(refname)")
                              loop
                                 declare
                                    Mid : constant String :=
                                      R (R'First + Src_Pre'Length
                                         .. R'Last - Src_Suf'Length);
                                 begin
                                    Atomic_Cmds.Append
                                      (Version.Push.Atomic_Command'
                                         (Source   => To_Unbounded_String (R),
                                          Dest_Ref => To_Unbounded_String
                                            (Dst_Pre & Mid & Dst_Suf),
                                          Delete   => False));
                                 end;
                              end loop;
                           end;
                        else
                           Atomic_Cmds.Append
                             (Version.Push.Atomic_Command'
                                (Source   => To_Unbounded_String (Src),
                                 Dest_Ref =>
                                   To_Unbounded_String (Normalize_Ref (Dst)),
                                 Delete   => False));
                        end if;
                     end;
                  end if;
               end Collect_Atomic;
            begin
               while I <= Count loop
                  if Arg (I) = "--no-verify" then
                     if No_Verify then
                        Usage_Error ("duplicate option: --no-verify", Usage);
                        return;
                     end if;

                     No_Verify := True;
                     I := I + 1;

                  elsif Arg (I) = "--force" or else Arg (I) = "-f" then
                     if Force then
                        Usage_Error ("duplicate option: --force", Usage);
                        return;
                     end if;

                     Force := True;
                     I := I + 1;

                  elsif Arg (I) = "--delete" or else Arg (I) = "-d" then
                     if Delete then
                        Usage_Error ("duplicate option: --delete", Usage);
                        return;
                     end if;

                     Delete := True;
                     I := I + 1;

                  elsif Arg (I) = "--tags" then
                     if Tags then
                        Usage_Error ("duplicate option: --tags", Usage);
                        return;
                     end if;

                     Tags := True;
                     I := I + 1;

                  elsif Arg (I) = "--atomic" then
                     if Atomic then
                        Usage_Error ("duplicate option: --atomic", Usage);
                        return;
                     end if;

                     Atomic := True;
                     I := I + 1;

                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown push option: " & Arg (I), Usage);
                     return;

                  else
                     Operand_Count := Operand_Count + 1;
                     if Operand_Count = 1 then
                        Remote_Name := To_Unbounded_String (Arg (I));
                     else
                        Refspecs.Append (Arg (I));
                     end if;
                     I := I + 1;
                  end if;
               end loop;

               if Atomic and then Tags then
                  Usage_Error
                    ("push --atomic cannot be combined with --tags", Usage);
                  return;

               elsif Delete then
                  if Tags or else Force then
                     Usage_Error
                       ("push --delete cannot be combined with --tags or"
                        & " --force", Usage);
                     return;
                  end if;

                  if Operand_Count < 2 then
                     Usage_Error
                       ("push --delete requires a remote and a ref", Usage);
                     return;
                  end if;

                  if Atomic then
                     --  All deletions in one all-or-nothing request.
                     for Ref_Arg of Refspecs loop
                        Atomic_Cmds.Append
                          (Version.Push.Atomic_Command'
                             (Source   => Null_Unbounded_String,
                              Dest_Ref =>
                                To_Unbounded_String (Normalize_Ref (Ref_Arg)),
                              Delete   => True));
                     end loop;
                     Version.Push.Push_Atomic
                       (Remote_Name => To_String (Remote_Name),
                        Commands    => Atomic_Cmds,
                        Force       => False,
                        Run_Hooks   => not No_Verify);
                     Success_Line
                       ("atomically deleted"
                        & Natural'Image (Natural (Atomic_Cmds.Length))
                        & " ref(s) on " & To_String (Remote_Name));
                  else
                     --  Delete every listed ref on the remote (git parity).
                     for Ref_Arg of Refspecs loop
                        declare
                           Full_Ref : constant String :=
                             Normalize_Ref (Ref_Arg);
                        begin
                           Version.Push.Delete_Ref
                             (Remote_Name => To_String (Remote_Name),
                              Ref_Name    => Full_Ref,
                              Run_Hooks   => not No_Verify);
                           Success_Line
                             ("deleted " & Full_Ref & " on "
                              & To_String (Remote_Name));
                        end;
                     end loop;
                  end if;

               elsif Tags then
                  if Operand_Count = 0 then
                     Remote_Name := To_Unbounded_String ("origin");
                  elsif Operand_Count > 1 then
                     Usage_Error
                       ("push --tags accepts at most one remote", Usage);
                     return;
                  end if;

                  Version.Push.Push_Tags
                    (Remote_Name => To_String (Remote_Name),
                     Run_Hooks   => not No_Verify,
                     Force       => Force);
                  Success_Line ("pushed tags to " & To_String (Remote_Name));

               elsif Operand_Count = 0 then
                  Usage_Error ("missing push remote", Usage);
                  return;

               elsif Refspecs.Is_Empty then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Matching : constant Boolean :=
                       Version.Config.Has_Key (Repo, "push.default")
                       and then Ada.Characters.Handling.To_Lower
                                  (Version.Config.Get_Value
                                     (Repo, "push.default")) = "matching";
                  begin
                     if Matching then
                        Version.Push.Push_Matching
                          (Remote_Name => To_String (Remote_Name),
                           Force        => Force,
                           Run_Hooks    => not No_Verify);
                        Success_Line
                          ("pushed matching branches to "
                           & To_String (Remote_Name));
                     else
                        Version.Push.Push_Default
                          (Remote_Name => To_String (Remote_Name),
                           Run_Hooks   => not No_Verify);
                        Success_Line ("pushed to " & To_String (Remote_Name));
                     end if;
                  end;

               elsif Atomic then
                  --  Collect every refspec into one all-or-nothing request.
                  for Spec of Refspecs loop
                     Collect_Atomic (Spec, Force);
                  end loop;
                  Version.Push.Push_Atomic
                    (Remote_Name => To_String (Remote_Name),
                     Commands    => Atomic_Cmds,
                     Force       => Force or else Atomic_Force,
                     Run_Hooks   => not No_Verify);
                  Success_Line
                    ("atomically pushed"
                     & Natural'Image (Natural (Atomic_Cmds.Length))
                     & " ref(s) to " & To_String (Remote_Name));

               else
                  --  One or more refspecs: process each (glob refspecs expand
                  --  to one push per matching local ref).
                  for Spec of Refspecs loop
                     Process_One_Refspec
                       (To_String (Remote_Name), Spec, Force,
                        not No_Verify);
                  end loop;
               end if;
            end;

         else
            Error_Line ("unknown command: " & Command);
            Print_Usage;
            Set_Usage_Failure;
         end if;
      end;

   exception
      when
        E :
          Ada.Directories.Name_Error
          | Ada.Text_IO.Data_Error
          | Ada.IO_Exceptions.Data_Error
          | Ada.IO_Exceptions.Use_Error
          | Constraint_Error
          | Program_Error
      =>
         Error_Line (User_Error_Text (E));
         Set_Command_Failure;
   end Run;

end Version.CLI;
