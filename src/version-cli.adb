with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Containers; use Ada.Containers;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Interfaces.C;
with System;

with GNAT.OS_Lib;

with Version.Archive; use Version.Archive;
with Version.Availability;
with Version.Files;
with Version.CLI.Help;
with Version.Multi_Pack_Index;
with Version.Objects; use Version.Objects;
with Version.Pack;
with Version.Pack_Write;
with Version.Reachability;
with Version.LFS;
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
with Version.Attributes;
with Version.Mailbox;
with Version.Mailmap;
with Version.Upload_Pack;
with Version.Status;
with Version.Subtree;
with Version.Write;
with Version.Restore;
with Version.Branch;
with Version.Merge;
with Version.Merge_State;
with Version.Remove;
with Version.Tags;
with Version.Remotes;
with Version.Dumb_Http;
with Version.Fetch;
with Version.Clone;
with Version.Commit_Graph;
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
with Version.Hooks;
with Version.Trailers;
with Version.Stripspace;
with Version.Ref_Names;
with Version.Fmt_Merge_Msg;
with Version.Apply;
with Ada.Streams.Stream_IO;
with Version.Format_Patch;
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
with Version.Bisect;
with Version.Show_Branch;
with Version.Console;
with Version.Tracking;
with Version.Diff;
with Version.Doctor; use Version.Doctor;
with Version.History;
with Version.Rename_Detect;
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
with Version.Timestamps;
with Version.Name_Rev;
with Version.Path_Quoting;

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

   --  git's die(): "fatal: <message>" on stderr, exit 128.
   Fatal_Exit : constant Ada.Command_Line.Exit_Status :=
     Ada.Command_Line.Exit_Status (128);

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

   package Path_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   --  Materialize each cached LFS-pointer file in the index into the working
   --  tree (git lfs checkout / the checkout half of pull). With a non-empty
   --  Filter, only the listed paths are written.
   procedure LFS_Checkout
     (Repo   : Version.Repository.Repository_Handle;
      Filter : Path_Sets.Set := Path_Sets.Empty_Set)
   is
      LF   : constant Character := Character'Val (10);
      Root : constant String := Version.Repository.Root_Path (Repo);
   begin
      for E of Version.LFS.LFS_Entries_In_Index (Repo) loop
         declare
            Path : constant String := To_String (E.Path);
         begin
            if (Filter.Is_Empty or else Filter.Contains (Path))
              and then E.Cached
            then
               declare
                  Pointer : constant String :=
                    "version https://git-lfs.github.com/spec/v1" & LF
                    & "oid sha256:" & To_String (E.Oid) & LF
                    & "size" & Natural'Image (E.Size) & LF;
                  Media : constant String :=
                    Version.LFS.Worktree_Content (Repo, Path, Pointer);
               begin
                  Version.Files.Write_Binary_File_Atomic
                    (Version.Files.Join (Root, Path), Media);
               end;
            end if;
         end;
      end loop;
   end LFS_Checkout;

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

   procedure Print_Sparse_List is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
   begin
      if not Version.Sparse.Enabled (Repo) then
         raise Ada.IO_Exceptions.Data_Error with "this worktree is not sparse";
      end if;

      --  git's `sparse-checkout list` prints the recursive directory names in
      --  cone mode, or the raw patterns otherwise.
      declare
         Items : constant Version.Sparse.String_Vectors.Vector :=
           (if Version.Sparse.Cone_Mode (Repo)
            then Version.Sparse.Cone_Recursive_Directories (Repo)
            else Version.Sparse.Pattern_Texts (Repo));
      begin
         for I in Items.First_Index .. Items.Last_Index loop
            Ada.Text_IO.Put_Line (Items.Element (I));
         end loop;
      end;
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

   --  Container formats git never produces (no built-in nor tar-filter path).
   function Looks_Like_Unsupported_Archive_Output
     (Path : String) return Boolean
   is
      Lower : constant String := Lower_ASCII (Path);
   begin
      return
        Ends_With (Lower, ".zipx")
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
      Format_Text     : Unbounded_String;   --  explicit --format value
      Specs           : Version.Pathspec.Pathspec_Vectors.Vector;
      I               : Positive := 3;

      function Is_Option (Text : String) return Boolean is
      begin
         return Text'Length > 0 and then Text (Text'First) = '-';
      end Is_Option;

      --  git tar filter: pipe In_Path through Command's shell to Out_Path.
      procedure Run_Filter (Command, In_Path, Out_Path : String) is
         Shell : constant String :=
           Command & " < '" & In_Path & "' > '" & Out_Path & "'";
         Args  : GNAT.OS_Lib.Argument_List :=
           [1 => new String'("-c"), 2 => new String'(Shell)];
         Ok    : Boolean;
      begin
         GNAT.OS_Lib.Spawn ("/bin/sh", Args, Ok);
         GNAT.OS_Lib.Free (Args (1));
         GNAT.OS_Lib.Free (Args (2));
         if not Ok then
            raise Ada.IO_Exceptions.Data_Error
              with "archive filter command failed: " & Command;
         end if;
      end Run_Filter;

      --  Infer the archive format name from an output filename's suffix.
      function Format_Name_Of_Output (Path : String) return String is
         Lower : constant String := Lower_ASCII (Path);
      begin
         if Ends_With (Lower, ".tar.gz") or else Ends_With (Lower, ".tgz") then
            return "tar.gz";
         elsif Ends_With (Lower, ".zip") then
            return "zip";
         elsif Ends_With (Lower, ".tar.xz") or else Ends_With (Lower, ".txz")
         then
            return "tar.xz";
         elsif Ends_With (Lower, ".tar.bz2")
           or else Ends_With (Lower, ".tbz2") or else Ends_With (Lower, ".tbz")
         then
            return "tar.bz2";
         elsif Ends_With (Lower, ".tar") then
            return "tar";
         else
            return "";
         end if;
      end Format_Name_Of_Output;
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

            Format_Text := To_Unbounded_String (Arg (I + 1));
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
             Version.Archive.Unsupported_Output_Format_Text (To_String (Output));
      end if;

      --  Effective format name: the explicit --format, else inferred from the
      --  output suffix.
      declare
         Fmt : constant String :=
           (if Format_Explicit then Lower_ASCII (To_String (Format_Text))
            elsif Length (Output) > 0
            then Format_Name_Of_Output (To_String (Output))
            else "tar");
         Repo : constant Version.Repository.Repository_Handle :=
           Version.Repository.Open;
         Filter_Key : constant String := "tar." & Fmt & ".command";
      begin
         if Fmt = "tar" or else Fmt = "" then
            Format := Version.Archive.Tar_Format;
         elsif Fmt = "tar.gz" or else Fmt = "tgz" then
            Format := Version.Archive.Tar_Gz_Format;
         elsif Fmt = "zip" then
            Format := Version.Archive.Zip_Format;
         elsif Version.Config.Has_Key (Repo, Filter_Key) then
            --  A configured tar filter (e.g. tar.tar.xz.command = "xz -c"):
            --  build the tar, then pipe it through the filter command.
            if Length (Output) = 0 then
               Output := To_Unbounded_String ("archive." & Fmt);
            end if;
            declare
               Command  : constant String :=
                 Version.Config.Get_Value (Repo, Filter_Key);
               Tar_Temp : constant String := To_String (Output) & ".tar.tmp";
            begin
               Version.Archive.Create
                 (Repository => Repo,
                  Revision   => Arg (2),
                  Output     => Tar_Temp,
                  Format     => Version.Archive.Tar_Format,
                  Pathspecs  => Specs,
                  Prefix     => To_String (Prefix));
               Run_Filter (Command, Tar_Temp, To_String (Output));
               Version.Files.Delete_File_If_Exists (Tar_Temp);
            end;
            Success_Line ("created archive " & To_String (Output));
            return;
         else
            raise Ada.IO_Exceptions.Data_Error
              with "Unknown archive format '" & Fmt & "'";
         end if;

         if Length (Output) = 0 then
            --  No --output: git streams the archive to standard output. Build
            --  it into a temporary file, copy the bytes to stdout verbatim,
            --  then remove the temporary. The temp name carries the format's
            --  extension so archive output validation accepts it.
            declare
               Ext : constant String :=
                 (case Format is
                  when Version.Archive.Zip_Format    => ".zip",
                  when Version.Archive.Tar_Gz_Format  => ".tar.gz",
                  when Version.Archive.Tar_Format     => ".tar");
               FD   : GNAT.OS_Lib.File_Descriptor;
               Name : GNAT.OS_Lib.Temp_File_Name;
               Last : Natural;
            begin
               GNAT.OS_Lib.Create_Temp_File (FD, Name);
               GNAT.OS_Lib.Close (FD);
               Last := Name'Last;
               for I in Name'Range loop
                  if Name (I) = ASCII.NUL then
                     Last := I - 1;
                     exit;
                  end if;
               end loop;
               declare
                  Temp : constant String := Name (Name'First .. Last) & Ext;
               begin
                  Version.Files.Delete_File_If_Exists (Name (Name'First .. Last));
                  Version.Archive.Create
                    (Repository => Repo,
                     Revision   => Arg (2),
                     Output     => Temp,
                     Format     => Format,
                     Pathspecs  => Specs,
                     Prefix     => To_String (Prefix));
                  Version.Console.Put (Version.Files.Read_Binary_File (Temp));
                  Version.Files.Delete_File_If_Exists (Temp);
               end;
            end;
            return;
         end if;

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

   procedure Stderr_Line (Text : String) is
   begin
      if not Quiet_Mode then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
      end if;
   end Stderr_Line;

   --  git's fetch summary ("From <url>" + per-ref update lines) is produced by
   --  snapshotting the remote-tracking refs and tags before and after the
   --  fetch and diffing them, then formatting each change the way git does.
   package Fetch_Ref_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => String);

   function Snapshot_Fetch_Refs
     (Repo : Version.Repository.Repository_Handle; Remote : String)
      return Fetch_Ref_Maps.Map
   is
      Result : Fetch_Ref_Maps.Map;
      Pats   : Version.Ref_Format.String_Vectors.Vector;
   begin
      Pats.Append ("refs/remotes/" & Remote & "/*");
      Pats.Append ("refs/tags/*");
      declare
         Lines : constant Version.Ref_Format.String_Vectors.Vector :=
           Version.Ref_Format.For_Each_Ref
             (Repo, Pats, Format => "%(refname) %(objectname)");
      begin
         for I in Lines.First_Index .. Lines.Last_Index loop
            declare
               S  : constant String := Lines.Element (I);
               Sp : constant Natural := Ada.Strings.Fixed.Index (S, " ");
            begin
               if Sp /= 0 then
                  Result.Include
                    (S (S'First .. Sp - 1), S (Sp + 1 .. S'Last));
               end if;
            end;
         end loop;
      end;
      return Result;
   exception
      when others =>
         return Fetch_Ref_Maps.Empty_Map;
   end Snapshot_Fetch_Refs;

   --  The remote URL as git prints it on the "From" line: the configured
   --  fetch URL with a single trailing ".git" (and any trailing "/") removed.
   function Remote_Display_URL
     (Repo : Version.Repository.Repository_Handle; Remote : String)
      return String
   is
      Raw : Unbounded_String;
   begin
      begin
         Raw := To_Unbounded_String
           (Version.Config.Get_Value (Repo, "remote." & Remote & ".url"));
      exception
         when others =>
            Raw := To_Unbounded_String (Remote);
      end;

      declare
         S    : constant String := To_String (Raw);
         Last : Natural := S'Last;
      begin
         while Last >= S'First and then S (Last) = '/' loop
            Last := Last - 1;
         end loop;
         if Last - S'First + 1 >= 4
           and then S (Last - 3 .. Last) = ".git"
         then
            Last := Last - 4;
            while Last >= S'First and then S (Last) = '/' loop
               Last := Last - 1;
            end loop;
         end if;
         return S (S'First .. Last);
      end;
   end Remote_Display_URL;

   --  The remote's default branch from refs/remotes/<Remote>/HEAD (the symref
   --  version and git write at clone time), or "" if absent/unreadable.
   function Remote_Default_Branch
     (Repo : Version.Repository.Repository_Handle; Remote : String)
      return String
   is
      Path   : constant String :=
        Version.Files.Join
          (Version.Repository.Common_Git_Dir (Repo),
           "refs/remotes/" & Remote & "/HEAD");
      Prefix : constant String := "ref: refs/remotes/" & Remote & "/";
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      declare
         Content : constant String := Version.Files.Read_Binary_File (Path);
         Last    : Natural := Content'Last;
      begin
         while Last >= Content'First
           and then Content (Last) in Character'Val (10) | Character'Val (13)
         loop
            Last := Last - 1;
         end loop;
         if Last - Content'First + 1 > Prefix'Length
           and then Content
                      (Content'First .. Content'First + Prefix'Length - 1)
                    = Prefix
         then
            return Content (Content'First + Prefix'Length .. Last);
         end if;
         return "";
      end;
   exception
      when others =>
         return "";
   end Remote_Default_Branch;

   procedure Print_Fetch_Summary
     (Repo         : Version.Repository.Repository_Handle;
      Remote       : String;
      Before       : Fetch_Ref_Maps.Map;
      Print_From   : Boolean := True;
      Include_Tags : Boolean := True)
   is
      After          : constant Fetch_Ref_Maps.Map :=
        Snapshot_Fetch_Refs (Repo, Remote);
      Tracked_Prefix : constant String := "refs/remotes/" & Remote & "/";
      Tag_Prefix     : constant String := "refs/tags/";
      LF             : constant String := "";  -- lines emitted individually

      type Line_Rec is record
         Code    : Character := ' ';
         Summary : Unbounded_String;
         From    : Unbounded_String;
         To      : Unbounded_String;
         Note    : Unbounded_String;
      end record;
      package Line_Vecs is new
        Ada.Containers.Vectors (Natural, Line_Rec);
      Heads : Line_Vecs.Vector;
      Tags  : Line_Vecs.Vector;
      pragma Unreferenced (LF);

      function Abbrev (Id : String) return String is
         L : constant Natural :=
           Version.Revisions.Unique_Abbrev_Length
             (Repo, Version.Objects.To_Object_Id (Id), 7);
      begin
         return Id (Id'First .. Id'First + L - 1);
      end Abbrev;

      function Is_FF (Old_Id, New_Id : String) return Boolean is
      begin
         return Version.History.Is_Ancestor
           (Repo,
            Base_Id    => Version.Objects.To_Object_Id (Old_Id),
            Derived_Id => Version.Objects.To_Object_Id (New_Id));
      exception
         when others =>
            return False;
      end Is_FF;

      Starts_With : Boolean;
   begin
      for C in After.Iterate loop
         declare
            Full  : constant String := Fetch_Ref_Maps.Key (C);
            New_I : constant String := Fetch_Ref_Maps.Element (C);
            Old_I : constant String :=
              (if Before.Contains (Full) then Before.Element (Full) else "");
            Rec   : Line_Rec;
         begin
            Starts_With :=
              Full'Length >= Tag_Prefix'Length
              and then Full (Full'First .. Full'First + Tag_Prefix'Length - 1)
                       = Tag_Prefix;
            if Old_I = New_I then
               null;
            elsif Starts_With then
               declare
                  Name : constant String :=
                    Full (Full'First + Tag_Prefix'Length .. Full'Last);
               begin
                  Rec.From := To_Unbounded_String (Name);
                  Rec.To := To_Unbounded_String (Name);
                  if Old_I = "" then
                     Rec.Code := '*';
                     Rec.Summary := To_Unbounded_String ("[new tag]");
                  else
                     Rec.Code := 't';
                     Rec.Summary := To_Unbounded_String ("[tag update]");
                  end if;
                  Tags.Append (Rec);
               end;
            elsif Full'Length >= Tracked_Prefix'Length
              and then Full
                         (Full'First
                          .. Full'First + Tracked_Prefix'Length - 1)
                       = Tracked_Prefix
            then
               declare
                  Name : constant String :=
                    Full (Full'First + Tracked_Prefix'Length .. Full'Last);
               begin
                  if Name = "HEAD" then
                     --  refs/remotes/<remote>/HEAD is the default-branch symref,
                     --  not a fetched ref update; git omits it from the summary.
                     goto Continue_Ref;
                  end if;
                  Rec.From := To_Unbounded_String (Name);
                  Rec.To := To_Unbounded_String (Remote & "/" & Name);
                  if Old_I = "" then
                     Rec.Code := '*';
                     Rec.Summary := To_Unbounded_String ("[new branch]");
                  elsif Is_FF (Old_I, New_I) then
                     Rec.Code := ' ';
                     Rec.Summary :=
                       To_Unbounded_String
                         (Abbrev (Old_I) & ".." & Abbrev (New_I));
                  else
                     Rec.Code := '+';
                     Rec.Summary :=
                       To_Unbounded_String
                         (Abbrev (Old_I) & "..." & Abbrev (New_I));
                     Rec.Note := To_Unbounded_String ("  (forced update)");
                  end if;
                  Heads.Append (Rec);
               end;
            end if;
         end;
         <<Continue_Ref>>
         null;
      end loop;

      if Heads.Is_Empty and then Tags.Is_Empty then
         return;
      end if;

      --  Order heads with the remote's default branch first (git advertises
      --  HEAD's branch first). refs/remotes/<remote>/HEAD is authoritative;
      --  fall back to the current branch then main/master for older clones
      --  that predate the stored remote HEAD.
      declare
         Remote_Head : constant String := Remote_Default_Branch (Repo, Remote);

         procedure Promote (Wanted : String) is
         begin
            if Wanted'Length = 0 then
               return;
            end if;
            for I in Heads.First_Index .. Heads.Last_Index loop
               if To_String (Heads.Element (I).From) = Wanted then
                  declare
                     R : constant Line_Rec := Heads.Element (I);
                  begin
                     Heads.Delete (I);
                     Heads.Prepend (R);
                  end;
                  return;
               end if;
            end loop;
         end Promote;
      begin
         if Remote_Head'Length > 0 then
            Promote (Remote_Head);
         else
            Promote ("master");
            Promote ("main");
            Promote (Version.Refs.Current_Branch_Name (Repo));
         end if;
      end;

      --  git left-justifies the remote name to max(10, longest name).
      declare
         Refcol : Natural := 10;

         function Pad (S : String; W : Natural) return String is
           (if S'Length >= W then S
            else S & String'(1 .. W - S'Length => ' '));

         procedure Emit (V : Line_Vecs.Vector) is
         begin
            for I in V.First_Index .. V.Last_Index loop
               declare
                  R : constant Line_Rec := V.Element (I);
               begin
                  Stderr_Line
                    (" " & R.Code & " "
                     & Pad (To_String (R.Summary), 17) & " "
                     & Pad (To_String (R.From), Refcol) & " -> "
                     & To_String (R.To) & To_String (R.Note));
               end;
            end loop;
         end Emit;

         URL : constant String := Remote_Display_URL (Repo, Remote);
      begin
         for V of Heads loop
            Refcol := Natural'Max (Refcol, Length (V.From));
         end loop;
         for V of Tags loop
            Refcol := Natural'Max (Refcol, Length (V.From));
         end loop;

         if Print_From then
            Stderr_Line ("From " & URL);
         end if;
         Emit (Heads);
         if Include_Tags then
            Emit (Tags);
         end if;
      end;
   end Print_Fetch_Summary;

   --  git's summary for an explicit `fetch/pull <remote> <ref>`: the named ref
   --  is fetched to FETCH_HEAD, shown unconditionally (even when up to date) as
   --  " * branch <name>       -> FETCH_HEAD" (or "tag"). Also records
   --  .git/FETCH_HEAD with the resolved id, as git does.
   procedure Print_Fetch_Head_Summary
     (Repo     : Version.Repository.Repository_Handle;
      Remote   : String;
      Ref_Name : String;
      Before   : Fetch_Ref_Maps.Map)
   is
      URL     : constant String := Remote_Display_URL (Repo, Remote);
      Is_Tag  : constant Boolean :=
        Version.Refs.Ref_Exists (Repo, "refs/tags/" & Ref_Name);
      Kind    : constant String := (if Is_Tag then "tag" else "branch");
      Refcol  : constant Natural := Natural'Max (10, Ref_Name'Length);

      function Pad (S : String; W : Natural) return String is
        (if S'Length >= W then S
         else S & String'(1 .. W - S'Length => ' '));
   begin
      --  Record FETCH_HEAD from the resolved ref (best effort).
      begin
         declare
            Full : constant String :=
              (if Is_Tag then "refs/tags/" & Ref_Name
               else "refs/remotes/" & Remote & "/" & Ref_Name);
            Id   : constant String :=
              Version.Objects.To_String
                (Version.Refs.Resolve_Ref (Repo, Full));
            Raw_URL : Unbounded_String;
         begin
            begin
               Raw_URL := To_Unbounded_String
                 (Version.Config.Get_Value (Repo, "remote." & Remote & ".url"));
            exception
               when others =>
                  Raw_URL := To_Unbounded_String (URL);
            end;
            Version.Files.Write_Binary_File_Atomic
              (Path    =>
                 Version.Files.Join
                   (Version.Repository.Common_Git_Dir (Repo), "FETCH_HEAD"),
               Content =>
                 Id & Character'Val (9) & Character'Val (9)
                 & Kind & " '" & Ref_Name & "' of "
                 & To_String (Raw_URL) & Character'Val (10));
         end;
      exception
         when others =>
            null;
      end;

      Stderr_Line ("From " & URL);
      Stderr_Line
        (" * " & Pad (Kind, 17) & " " & Pad (Ref_Name, Refcol)
         & " -> FETCH_HEAD");
      --  git also reports the opportunistic remote-tracking updates (with no
      --  second "From" line) after the FETCH_HEAD mapping.
      Print_Fetch_Summary
        (Repo, Remote, Before, Print_From => False, Include_Tags => False);
   end Print_Fetch_Head_Summary;

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

      --  git prints nothing when there are no branches (e.g. an unborn repo).
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
   end Print_Branch_List;

   --  `subtree merge`/`pull` is `merge --no-ff -Xsubtree=<prefix>`, and prints
   --  what that merge prints.
   procedure Merge_Subtree
     (Prefix     : String;
      Repository : String;
      Ref        : String;
      Squash     : Boolean;
      Message    : String)
   is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Already : Boolean;
      Target  : constant Version.Objects.Hex_Object_Id :=
        Version.Subtree.Merge_Target (Prefix, Repository, Ref, Squash, Already);

      Before  : constant String := Version.Refs.Current_Commit_Id (Repo);
      Options : Version.Branch.Merge_Options;
   begin
      if Already then
         Stderr_Line
           ("Subtree is already at commit "
            & Version.Objects.To_String (Target) & ".");
         return;
      end if;

      Options.Fast_Forward := Version.Branch.Fast_Forward_Disabled;
      Options.Fast_Forward_Explicit := True;
      Options.Subtree := True;
      Options.Subtree_Prefix := To_Unbounded_String (Prefix);

      if Message /= "" then
         Options.Message := To_Unbounded_String (Message);
      end if;

      Version.Branch.Merge (Version.Objects.To_String (Target), Options);

      declare
         After : constant String := Version.Refs.Current_Commit_Id (Repo);
      begin
         if After = Before then
            Success_Line ("Already up to date.");
         else
            Success_Line ("Merge made by the 'ort' strategy.");

            declare
               Block : constant String :=
                 Version.Diff.Diff_Commits
                   (Repo,
                    Version.Objects.To_Object_Id (Before),
                    Version.Objects.To_Object_Id (After),
                    Version.Diff.Diff_Options'
                      (Context_Lines => 3, Stat => True, Summary => True,
                       others => <>));
               Last : Natural := Block'Last;
            begin
               if Last >= Block'First
                 and then Block (Last) = Character'Val (10)
               then
                  Last := Last - 1;
               end if;

               if Last >= Block'First then
                  Success_Line (Block (Block'First .. Last));
               end if;
            end;
         end if;
      end;
   end Merge_Subtree;

   --  `show-index [--object-format=<fmt>]` -- the pack index on stdin, as
   --  `<offset> <sha> (<crc32>)` in index (that is, object-id) order.
   procedure Run_Show_Index_Command is
      use type Interfaces.Unsigned_32;

      function Read_Stdin_Bytes return String is
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
               Append
                 (Acc,
                  Buffer (Buffer'First .. Buffer'First + Integer (N) - 1));
            end;
         end loop;

         return To_String (Acc);
      end Read_Stdin_Bytes;

      Width : Positive := 20;
      Data  : constant String := Read_Stdin_Bytes;

      function U32 (At_Pos : Positive) return Interfaces.Unsigned_32 is
        (Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos))), 24)
         or Interfaces.Shift_Left
              (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 1))), 16)
         or Interfaces.Shift_Left
              (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 2))), 8)
         or Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 3))));

      function Hex8 (V : Interfaces.Unsigned_32) return String is
         Digits_Set : constant String := "0123456789abcdef";
         Result     : String (1 .. 8);
         Value      : Interfaces.Unsigned_32 := V;
      begin
         for I in reverse Result'Range loop
            Result (I) :=
              Digits_Set
                (Natural (Value and 16#F#) + 1);
            Value := Interfaces.Shift_Right (Value, 4);
         end loop;

         return Result;
      end Hex8;

      Count_N : Natural := 0;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A'Length > 16
              and then A (A'First .. A'First + 15) = "--object-format="
            then
               if A (A'First + 16 .. A'Last) = "sha256" then
                  Width := 32;
               end if;
            end if;
         end;
      end loop;

      --  Only the v2 index carries a magic; a v1 one starts with its fanout.
      if Data'Length < 8
        or else Data (Data'First .. Data'First + 3)
                /= Character'Val (255) & "tOc"
      then
         Error_Line ("unsupported or truncated pack index");
         Set_Command_Failure;
         return;
      end if;

      Count_N := Natural (U32 (Data'First + 8 + 255 * 4));

      declare
         Sha_Base : constant Positive := Data'First + 8 + 256 * 4;
         Crc_Base : constant Positive := Sha_Base + Count_N * Width;
         Off_Base : constant Positive := Crc_Base + Count_N * 4;
      begin
         for I in 0 .. Count_N - 1 loop
            declare
               Raw : constant String :=
                 Data (Sha_Base + I * Width
                       .. Sha_Base + I * Width + Width - 1);
               Crc : constant Interfaces.Unsigned_32 := U32 (Crc_Base + I * 4);
               Off : constant Interfaces.Unsigned_32 := U32 (Off_Base + I * 4);
            begin
               Version.Console.Put
                 (Ada.Strings.Fixed.Trim
                    (Interfaces.Unsigned_32'Image (Off), Ada.Strings.Both)
                  & " " & Version.Objects.To_String
                            (Version.Objects.To_Hex (Raw))
                  & " (" & Hex8 (Crc) & ")" & ASCII.LF);
            end;
         end loop;
      end;
   end Run_Show_Index_Command;

   --  `unpack-file <blob>` -- the blob's contents in a temporary file, whose
   --  name is printed.
   procedure Run_Unpack_File_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
   begin
      if Count < 2 then
         Error_Line ("unpack-file needs a blob");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Id : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve (Repo, Arg (2));

         Content : constant String :=
           Version.Objects.Content (Version.Objects.Read_Object (Repo, Id));

         Hex : constant String := Version.Objects.To_String (Id);

         --  git names it .merge_file_XXXXXX; the object's own id makes it just
         --  as unique and keeps the command deterministic.
         Path : constant String :=
           ".merge_file_" & Hex (Hex'First .. Hex'First + 5);
      begin
         Version.Files.Write_Binary_File (Path, Content);
         Success_Line (Path);
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Unpack_File_Command;

   --  `prune-packed [-n|--dry-run] [-q|--quiet]` -- drop the loose objects
   --  that a pack already holds.
   procedure Run_Prune_Packed_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Dry : Boolean := False;

      Objects_Dir : constant String :=
        Version.Files.Join
          (Version.Repository.Common_Git_Dir (Repo), "objects");
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "-n" or else A = "--dry-run" then
               Dry := True;
            elsif A = "-q" or else A = "--quiet" then
               null;
            else
               Error_Line ("unknown option: " & A);
               Set_Usage_Failure;
               return;
            end if;
         end;
      end loop;

      for Fanout in 0 .. 255 loop
         declare
            Hex_Digits : constant String := "0123456789abcdef";
            Name : constant String :=
              Hex_Digits (Fanout / 16 + 1) & Hex_Digits (Fanout mod 16 + 1);
            Dir  : constant String := Version.Files.Join (Objects_Dir, Name);
         begin
            if Ada.Directories.Exists (Dir)
              and then Ada.Directories.Kind (Dir) = Ada.Directories.Directory
            then
               declare
                  Search : Ada.Directories.Search_Type;
                  Item   : Ada.Directories.Directory_Entry_Type;
                  Left   : Natural := 0;
               begin
                  Ada.Directories.Start_Search
                    (Search, Dir, "",
                     [Ada.Directories.Ordinary_File => True, others => False]);

                  while Ada.Directories.More_Entries (Search) loop
                     Ada.Directories.Get_Next_Entry (Search, Item);

                     declare
                        Simple : constant String :=
                          Ada.Directories.Simple_Name (Item);
                        Id     : constant String := Name & Simple;
                     begin
                        if Version.Objects.Is_Valid_Hex_Object_Id (Id)
                          and then Version.Pack.Contains
                                     (Repo,
                                      Version.Objects.To_Object_Id (Id))
                        then
                           if not Dry then
                              Ada.Directories.Delete_File
                                (Version.Files.Join (Dir, Simple));
                           else
                              Left := Left + 1;
                           end if;
                        else
                           Left := Left + 1;
                        end if;
                     end;
                  end loop;

                  Ada.Directories.End_Search (Search);

                  if Left = 0 and then not Dry then
                     Ada.Directories.Delete_Directory (Dir);
                  end if;
               end;
            end if;
         end;
      end loop;
   end Run_Prune_Packed_Command;

   --  The per-path 3-way merge `merge-index` drives, and that `git`
   --  implements as the git-merge-one-file shell script:
   --    merge-one-file <orig blob> <our blob> <their blob> <path>
   --                   <orig mode> <our mode> <their mode>
   --  Blob ids and modes are empty for a file a side does not have.
   --  Returns git's exit status.
   function Merge_One_File
     (Repo : Version.Repository.Repository_Handle;
      O, A, B      : String;
      Path         : String;
      MO, MA, MB   : String)
      return Integer
   is
      Index : Version.Staging.Index_Entry_Vectors.Vector :=
        Version.Staging.Load (Repo);

      procedure Drop_Path is
         Kept : Version.Staging.Index_Entry_Vectors.Vector;
      begin
         for E of Index loop
            if To_String (E.Path) /= Path then
               Kept.Append (E);
            end if;
         end loop;

         Index := Kept;
      end Drop_Path;

      procedure Stage_Zero (Id : String; Mode : String) is
      begin
         Drop_Path;
         Index.Append
           (Version.Staging.Index_Entry'
              (Path  => To_Unbounded_String (Path),
               Id    => Version.Objects.To_Object_Id (Id),
               Mode  => To_Unbounded_String (Mode),
               Stage => 0,
               Skip_Worktree => False));
      end Stage_Zero;

      function Blob (Id : String) return String is
        (if Id = "" then ""
         else Version.Objects.Content
                (Version.Objects.Read_Object
                   (Repo, Version.Objects.To_Object_Id (Id))));

      procedure Write_Worktree (Content : String; Mode : String) is
      begin
         Version.Files.Write_Binary_File (Path, Content);

         if Mode = "100755" then
            Version.Files.Set_Executable (Path, True);
         end if;
      end Write_Worktree;

      function Short (Id : String) return String is
        (if Id'Length >= 6 then Id (Id'First .. Id'First + 5) else Id);

   begin
      --  Deleted in both, or deleted in one and untouched in the other.
      if O /= ""
        and then ((A = "" and then B = "")
                  or else (A = "" and then B = O)
                  or else (A = O and then B = ""))
      then
         if (MA = "" and then MO /= MB)
           or else (MB = "" and then MO /= MA)
         then
            Stderr_Line
              ("ERROR: File " & Path & " deleted on one branch but had its");
            Stderr_Line ("ERROR: permissions changed on the other.");
            return 1;
         end if;

         if A /= "" then
            Success_Line ("Removing " & Path);
         end if;

         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_File (Path);
         end if;

         Drop_Path;
         Version.Staging.Write (Repo, Index);
         return 0;
      end if;

      --  Added by us alone: nothing to do but mark it merged.
      if O = "" and then A /= "" and then B = "" then
         Stage_Zero (A, MA);
         Version.Staging.Write (Repo, Index);
         return 0;
      end if;

      --  Added by them alone.
      if O = "" and then A = "" and then B /= "" then
         Success_Line ("Adding " & Path);

         if Ada.Directories.Exists (Path) then
            Stderr_Line
              ("ERROR: untracked " & Path & " is overwritten by the merge.");
            return 1;
         end if;

         Stage_Zero (B, MB);
         Version.Staging.Write (Repo, Index);
         Write_Worktree (Blob (B), MB);
         return 0;
      end if;

      --  Added by both, identically.
      if O = "" and then A /= "" and then A = B then
         if MA /= MB then
            Stderr_Line
              ("ERROR: File " & Path & " added identically in both branches,");
            Stderr_Line
              ("ERROR: but permissions conflict " & MA & "->" & MB & ".");
            return 1;
         end if;

         Success_Line ("Adding " & Path);
         Stage_Zero (A, MA);
         Version.Staging.Write (Repo, Index);
         Write_Worktree (Blob (A), MA);
         return 0;
      end if;

      --  Changed on both sides, differently.
      if A /= "" and then B /= "" and then A /= B then
         if MA = "120000" or else MB = "120000" then
            Stderr_Line
              ("ERROR: " & Path & ": Not merging symbolic link changes.");
            return 1;
         end if;

         if MA = "160000" or else MB = "160000" then
            Stderr_Line
              ("ERROR: " & Path
               & ": Not merging conflicting submodule changes.");
            return 1;
         end if;

         declare
            Opts      : Version.Merge.Merge_File_Options;
            Merged    : Unbounded_String;
            Conflicts : Natural;
            Status    : Integer := 0;
            Message   : Unbounded_String;
         begin
            --  git merges the three *unpacked* files, so the conflict markers
            --  carry those temporary files' names as labels.
            Opts.Ours_Label := To_Unbounded_String (".merge_file_" & Short (A));
            Opts.Base_Label :=
              To_Unbounded_String
                (".merge_file_" & (if O = "" then "empty" else Short (O)));
            Opts.Theirs_Label :=
              To_Unbounded_String (".merge_file_" & Short (B));

            if O = "" then
               Success_Line ("Added " & Path & " in both, but differently.");
            else
               Success_Line ("Auto-merging " & Path);
            end if;

            Version.Merge.Merge_File
              (Ours_Text   => Blob (A),
               Base_Text   => Blob (O),
               Theirs_Text => Blob (B),
               Options     => Opts,
               Merged      => Merged,
               Conflicts   => Conflicts);

            Write_Worktree (To_String (Merged), MA);

            if Conflicts > 0 or else O = "" then
               Message := To_Unbounded_String ("content conflict");
               Status := 1;
            end if;

            if MA /= MB then
               if Message /= "" then
                  Append (Message, ", ");
               end if;

               Append
                 (Message,
                  "permissions conflict: " & MO & "->" & MA & "," & MB);
               Status := 1;
            end if;

            if Status /= 0 then
               Stderr_Line
                 ("ERROR: " & To_String (Message) & " in " & Path);
               return 1;
            end if;

            --  Clean: the merged file becomes the merged index entry.
            Stage_Zero
              (Version.Objects.To_String
                 (Version.Write.Write_Blob (Repo, To_String (Merged))),
               MA);
            Version.Staging.Write (Repo, Index);
            return 0;
         end;
      end if;

      Stderr_Line
        ("ERROR: " & Path & ": Not handling case " & O & " -> " & A & " -> "
         & B);
      return 1;
   end Merge_One_File;

   procedure Run_Merge_One_File_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
   begin
      if Count /= 8 then
         Error_Line
           ("usage: version merge-one-file <orig blob> <our blob> "
            & "<their blob> <path> <orig mode> <our mode> <their mode>");
         Set_Usage_Failure;
         return;
      end if;

      if Merge_One_File
           (Repo, Arg (2), Arg (3), Arg (4), Arg (5), Arg (6), Arg (7),
            Arg (8)) /= 0
      then
         Set_Command_Failure;
      end if;
   end Run_Merge_One_File_Command;

   --  `merge-index [-o] [-q] <merge-program> (-a | [--] <file>...)`
   procedure Run_Merge_Index_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Keep_Going : Boolean := False;
      Quiet      : Boolean := False;
      All_Paths  : Boolean := False;
      Program    : Unbounded_String;
      Wanted     : Version.Trailers.String_Vectors.Vector;
      Failed     : Boolean := False;
      Failure_Count : Natural := 0;
      I          : Positive := 2;
   begin
      while I <= Count loop
         declare
            A : constant String := Arg (I);
         begin
            if Program = "" and then A = "-o" then
               Keep_Going := True;
            elsif Program = "" and then A = "-q" then
               Quiet := True;
            elsif Program = "" then
               Program := To_Unbounded_String (A);
            elsif A = "-a" then
               All_Paths := True;
            elsif A = "--" then
               null;
            else
               Wanted.Append (A);
            end if;
         end;

         I := I + 1;
      end loop;

      if Program = "" then
         Error_Line ("usage: version merge-index <merge-program> (-a | file...)");
         Set_Usage_Failure;
         return;
      end if;

      declare
         --  git's merge-index looks the program up in its exec path; the one
         --  it is invariably given is merge-one-file, which version has built
         --  in.  Any other program is spawned with git's seven arguments.
         Name : constant String := To_String (Program);
         Builtin : constant Boolean :=
           Name = "git-merge-one-file" or else Name = "merge-one-file"
           or else Name = "version-merge-one-file";

         Index : constant Version.Staging.Index_Entry_Vectors.Vector :=
           Version.Staging.Load (Repo);

         Paths : Version.Trailers.String_Vectors.Vector;
      begin
         --  git errors on a named path that is not unmerged, before running
         --  the merge program for anything.
         if not All_Paths then
            for Want of Wanted loop
               declare
                  Present : Boolean := False;
               begin
                  for E of Index loop
                     if To_String (E.Path) = Want and then E.Stage /= 0 then
                        Present := True;
                     end if;
                  end loop;

                  if not Present then
                     Stderr_Line
                       ("fatal: git merge-index: " & Want
                        & " not in the cache");
                     Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                     return;
                  end if;
               end;
            end loop;
         end if;

         --  The unmerged paths, in index order, without duplicates.
         for E of Index loop
            if E.Stage /= 0 then
               declare
                  Path : constant String := To_String (E.Path);
               begin
                  if not Paths.Contains (Path)
                    and then (All_Paths or else Wanted.Contains (Path))
                  then
                     Paths.Append (Path);
                  end if;
               end;
            end if;
         end loop;

         for Path of Paths loop
            declare
               O, A, B    : Unbounded_String;
               MO, MA, MB : Unbounded_String;
               Status     : Integer := 0;
            begin
               for E of Version.Staging.Load (Repo) loop
                  if To_String (E.Path) = Path then
                     case E.Stage is
                        when 1 =>
                           O := To_Unbounded_String
                                  (Version.Objects.To_String (E.Id));
                           MO := E.Mode;
                        when 2 =>
                           A := To_Unbounded_String
                                  (Version.Objects.To_String (E.Id));
                           MA := E.Mode;
                        when 3 =>
                           B := To_Unbounded_String
                                  (Version.Objects.To_String (E.Id));
                           MB := E.Mode;
                        when others =>
                           null;
                     end case;
                  end if;
               end loop;

               if Builtin then
                  Status :=
                    Merge_One_File
                      (Repo, To_String (O), To_String (A), To_String (B), Path,
                       To_String (MO), To_String (MA), To_String (MB));
               else
                  declare
                     Args : GNAT.OS_Lib.Argument_List (1 .. 2);
                  begin
                     Args (1) := new String'("-c");
                     Args (2) :=
                       new String'
                         (Name & " " & To_String (O) & " " & To_String (A)
                          & " " & To_String (B) & " " & Path & " "
                          & To_String (MO) & " " & To_String (MA) & " "
                          & To_String (MB));
                     Status :=
                       GNAT.OS_Lib.Spawn
                         (Program_Name => "/bin/sh", Args => Args);
                     GNAT.OS_Lib.Free (Args (1));
                     GNAT.OS_Lib.Free (Args (2));
                  end;
               end if;

               if Status /= 0 then
                  Failed := True;
                  Failure_Count := Failure_Count + 1;

                  if not Keep_Going then
                     --  git dies (exit 128) with the message, but under -q it
                     --  simply exits 1.
                     if Quiet then
                        Set_Command_Failure;
                     else
                        Stderr_Line ("fatal: merge program failed");
                        Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                     end if;

                     return;
                  end if;
               end if;
            end;
         end loop;

         --  git's tail: with -o it accumulates failures, then dies unless -q,
         --  in which case the exit status is the failure count.
         if Failed then
            if Quiet then
               Ada.Command_Line.Set_Exit_Status
                 (Ada.Command_Line.Exit_Status (Failure_Count));
            else
               Stderr_Line ("fatal: merge program failed");
               Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
            end if;
         end if;
      end;
   end Run_Merge_Index_Command;

   --  The pack trio: `index-pack`, `unpack-objects` and `pack-objects`.
   --  A pack is named after its trailing checksum, which is what all three
   --  print.

   function Read_All_Stdin return String is
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
            Append (Acc, Buffer (Buffer'First .. Buffer'First + Integer (N) - 1));
         end;
      end loop;

      return To_String (Acc);
   end Read_All_Stdin;

   --  The object ids a pack index lists, in index order.
   function Pack_Index_Ids (Idx_Path : String)
     return Version.Objects.Object_Id_Vectors.Vector
   is
      use type Interfaces.Unsigned_32;

      Data : constant String := Version.Files.Read_Binary_File (Idx_Path);

      function U32 (At_Pos : Positive) return Interfaces.Unsigned_32 is
        (Interfaces.Shift_Left
           (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos))), 24)
         or Interfaces.Shift_Left
              (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 1))), 16)
         or Interfaces.Shift_Left
              (Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 2))), 8)
         or Interfaces.Unsigned_32 (Character'Pos (Data (At_Pos + 3))));

      Result : Version.Objects.Object_Id_Vectors.Vector;
   begin
      if Data'Length < 8
        or else Data (Data'First .. Data'First + 3)
                /= Character'Val (255) & "tOc"
      then
         return Result;
      end if;

      declare
         Width : constant Positive := 20;
         N     : constant Natural :=
           Natural (U32 (Data'First + 8 + 255 * 4));
         Base  : constant Positive := Data'First + 8 + 256 * 4;
      begin
         for I in 0 .. N - 1 loop
            Result.Append
              (Version.Objects.To_Hex
                 (Data (Base + I * Width .. Base + I * Width + Width - 1)));
         end loop;
      end;

      return Result;
   end Pack_Index_Ids;

   --  A pack ends with the hash of everything before it; that hash names it.
   function Pack_Checksum (Pack_Path : String) return String is
      Data : constant String := Version.Files.Read_Binary_File (Pack_Path);
   begin
      if Data'Length < 20 then
         return "";
      end if;

      return Version.Objects.To_String
        (Version.Objects.To_Hex (Data (Data'Last - 19 .. Data'Last)));
   end Pack_Checksum;

   procedure Run_Index_Pack_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      From_Stdin : Boolean := False;
      Pack_Arg   : Unbounded_String;
      Idx_Out    : Unbounded_String;
      Keep       : Boolean := False;
      Keep_Reason : Unbounded_String;

      Pack_Dir : constant String :=
        Version.Files.Join
          (Version.Files.Join
             (Version.Repository.Common_Git_Dir (Repo), "objects"),
           "pack");

      I : Positive := 2;
   begin
      while I <= Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--stdin" then
               From_Stdin := True;
            elsif A = "--keep" then
               Keep := True;
            elsif A'Length >= 7
              and then A (A'First .. A'First + 6) = "--keep="
            then
               Keep := True;
               Keep_Reason :=
                 To_Unbounded_String (A (A'First + 7 .. A'Last));
            elsif A = "-v" or else A = "--verify"
              or else A = "--fix-thin" or else A = "-q"
            then
               null;
            elsif A = "-o" and then I < Count then
               Idx_Out := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            else
               Pack_Arg := To_Unbounded_String (A);
            end if;
         end;

         I := I + 1;
      end loop;

      if not From_Stdin and then Pack_Arg = "" then
         Error_Line ("index-pack needs a pack file or --stdin");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Pack_Path : Unbounded_String := Pack_Arg;
      begin
         if From_Stdin then
            declare
               Temp : constant String :=
                 Version.Files.Join (Pack_Dir, "tmp_idx_pack.pack");
               Data : constant String := Read_All_Stdin;
            begin
               Version.Files.Create_Directory_If_Missing (Pack_Dir);
               Version.Files.Write_Binary_File (Temp, Data);

               declare
                  Sum : constant String := Pack_Checksum (Temp);
                  Final : constant String :=
                    Version.Files.Join (Pack_Dir, "pack-" & Sum & ".pack");
               begin
                  Ada.Directories.Rename (Temp, Final);
                  Pack_Path := To_Unbounded_String (Final);
               end;
            end;
         end if;

         Version.Pack.Index_Pack
           (Repo, To_String (Pack_Path), Canonicalize => From_Stdin);

         --  --keep writes pack-<sha>.keep next to the pack (empty, or the
         --  reason for --keep=<reason>), marking it exempt from gc/repack.
         if Keep then
            declare
               P : constant String := To_String (Pack_Path);
               Keep_Path : constant String :=
                 P (P'First .. P'Last - 5) & ".keep";
            begin
               Version.Files.Write_Binary_File
                 (Keep_Path, To_String (Keep_Reason));
            end;
         end if;

         if Idx_Out /= "" then
            declare
               Path : constant String := To_String (Pack_Path);
               Made : constant String :=
                 Path (Path'First .. Path'Last - 5) & ".idx";
            begin
               if Made /= To_String (Idx_Out) then
                  Ada.Directories.Copy_File (Made, To_String (Idx_Out));
               end if;
            end;
         end if;

         Success_Line (Pack_Checksum (To_String (Pack_Path)));
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Index_Pack_Command;

   --  `unpack-objects [-q] [-n]` -- a pack on stdin, exploded into loose
   --  objects.
   procedure Run_Unpack_Objects_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Dry : Boolean := False;

      Pack_Dir : constant String :=
        Version.Files.Join
          (Version.Files.Join
             (Version.Repository.Common_Git_Dir (Repo), "objects"),
           "pack");
   begin
      for I in 2 .. Count loop
         if Arg (I) = "-n" or else Arg (I) = "--dry-run" then
            Dry := True;
         end if;
      end loop;

      declare
         Data : constant String := Read_All_Stdin;
         Temp : constant String :=
           Version.Files.Join (Pack_Dir, "tmp_unpack.pack");
         Idx  : constant String :=
           Version.Files.Join (Pack_Dir, "tmp_unpack.idx");
      begin
         if Data'Length = 0 then
            return;
         end if;

         Version.Files.Create_Directory_If_Missing (Pack_Dir);
         Version.Files.Write_Binary_File (Temp, Data);

         begin
            --  Index it where the object reader can see it, read every object
            --  out, and write each one loose.
            Version.Pack.Index_Pack (Repo, Temp, Canonicalize => False);

            declare
               Ids : constant Version.Objects.Object_Id_Vectors.Vector :=
                 Pack_Index_Ids (Idx);
            begin
               for Id of Ids loop
                  declare
                     Obj : constant Version.Objects.Git_Object :=
                       Version.Objects.Read_Object (Repo, Id);

                     Kind : constant String :=
                       (case Version.Objects.Kind (Obj) is
                          when Version.Objects.Blob_Object   => "blob",
                          when Version.Objects.Tree_Object   => "tree",
                          when Version.Objects.Commit_Object => "commit",
                          when Version.Objects.Tag_Object    => "tag",
                          when others                        => "");

                     Written : Version.Objects.Hex_Object_Id;
                  begin
                     if not Dry and then Kind /= "" then
                        Written :=
                          Version.Write.Write_Object
                            (Repo, Kind, Version.Objects.Content (Obj));
                        pragma Unreferenced (Written);
                     end if;
                  end;
               end loop;
            end;
         exception
            when others =>
               if Ada.Directories.Exists (Temp) then
                  Ada.Directories.Delete_File (Temp);
               end if;

               if Ada.Directories.Exists (Idx) then
                  Ada.Directories.Delete_File (Idx);
               end if;

               raise;
         end;

         if Ada.Directories.Exists (Temp) then
            Ada.Directories.Delete_File (Temp);
         end if;

         if Ada.Directories.Exists (Idx) then
            Ada.Directories.Delete_File (Idx);
         end if;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Unpack_Objects_Command;

   --  `pack-objects [--stdout] [--revs] [<base-name>]` -- object ids on
   --  stdin, a pack out.  version writes undeltified packs, so the bytes (and
   --  therefore the pack's name) are its own; the pack itself is a valid one
   --  that git reads.
   procedure Run_Pack_Objects_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      To_Stdout : Boolean := False;
      Base_Name : Unbounded_String;

      Ids : Version.Objects.Object_Id_Vectors.Vector;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--stdout" then
               To_Stdout := True;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;   --  --non-empty, --delta-base-offset, -q, ... : accepted
            else
               Base_Name := To_Unbounded_String (A);
            end if;
         end;
      end loop;

      --  git reads "<oid>[ <path>]" lines and ignores everything but the id.
      declare
         Text : constant String := Read_All_Stdin;
         Pos  : Natural := Text'First;
      begin
         while Pos <= Text'Last loop
            declare
               Stop : Natural :=
                 Ada.Strings.Fixed.Index (Text, "" & ASCII.LF, Pos);
               Line : constant String :=
                 Text (Pos .. (if Stop = 0 then Text'Last else Stop - 1));
               Space : constant Natural :=
                 Ada.Strings.Fixed.Index (Line, " ");
               Id : constant String :=
                 (if Space = 0 then Line else Line (Line'First .. Space - 1));
            begin
               if Stop = 0 then
                  Stop := Text'Last;
               end if;

               Pos := Stop + 1;

               if Version.Objects.Is_Valid_Hex_Object_Id (Id) then
                  Ids.Append (Version.Objects.To_Object_Id (Id));
               end if;
            end;
         end loop;
      end;

      declare
         Temp_Dir : constant String :=
           Version.Files.Join
             (Version.Repository.Common_Git_Dir (Repo), "objects");
         Temp_Pack : constant String :=
           Version.Files.Join (Temp_Dir, "tmp_pack_objects.pack");
         Temp_Idx  : constant String :=
           Version.Files.Join (Temp_Dir, "tmp_pack_objects.idx");
      begin
         Version.Pack_Write.Write_Pack (Repo, Ids, Temp_Pack, Temp_Idx);

         declare
            Sum : constant String := Pack_Checksum (Temp_Pack);
         begin
            if To_Stdout then
               Version.Console.Put
                 (Version.Files.Read_Binary_File (Temp_Pack));
               Ada.Directories.Delete_File (Temp_Pack);
               Ada.Directories.Delete_File (Temp_Idx);
               return;
            end if;

            if Base_Name = "" then
               Error_Line ("pack-objects needs a base name or --stdout");
               Ada.Directories.Delete_File (Temp_Pack);
               Ada.Directories.Delete_File (Temp_Idx);
               Set_Usage_Failure;
               return;
            end if;

            Ada.Directories.Rename
              (Temp_Pack, To_String (Base_Name) & "-" & Sum & ".pack");
            Ada.Directories.Rename
              (Temp_Idx, To_String (Base_Name) & "-" & Sum & ".idx");
            Success_Line (Sum);
         end;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Pack_Objects_Command;

   package Mark_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  fast-import's marks point the other way: ":<n>" -> the object it named.
   package Mark_Id_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  `fast-export [--all] [<ref>...]` -- the history as a fast-import stream.
   procedure Run_Fast_Export_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Marks     : Mark_Maps.Map;
      Next_Mark : Natural := 0;

      Refs : Version.Trailers.String_Vectors.Vector;

      function New_Mark (Id : String) return Natural is
      begin
         Next_Mark := Next_Mark + 1;
         Marks.Include (Id, Next_Mark);
         return Next_Mark;
      end New_Mark;

      function Mark_Image (N : Natural) return String is
        (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Both));

      procedure Put (Text : String) is
      begin
         Version.Console.Put (Text);
      end Put;

      --  `data <n>` then exactly n bytes.
      procedure Put_Data (Content : String) is
      begin
         Put ("data "
              & Ada.Strings.Fixed.Trim
                  (Natural'Image (Content'Length), Ada.Strings.Both)
              & ASCII.LF);
         Put (Content);
      end Put_Data;

      function Header_Line
        (Commit : Version.Objects.Hex_Object_Id;
         Key    : String)
         return String
      is
         Data : constant String :=
           Version.Objects.Content
             (Version.Objects.Read_Object (Repo, Commit));
         Pos  : Natural := Data'First;
      begin
         while Pos <= Data'Last loop
            declare
               Stop : constant Natural :=
                 Ada.Strings.Fixed.Index (Data, "" & ASCII.LF, Pos);
               Line : constant String :=
                 Data (Pos .. (if Stop = 0 then Data'Last else Stop - 1));
            begin
               exit when Line'Length = 0;

               if Line'Length > Key'Length
                 and then Line (Line'First .. Line'First + Key'Length - 1)
                          = Key
               then
                  return Line (Line'First + Key'Length .. Line'Last);
               end if;

               exit when Stop = 0;
               Pos := Stop + 1;
            end;
         end loop;

         return "";
      end Header_Line;

      function Commit_Message (Commit : Version.Objects.Hex_Object_Id)
        return String
      is
         Data  : constant String :=
           Version.Objects.Content
             (Version.Objects.Read_Object (Repo, Commit));
         Blank : constant Natural :=
           Ada.Strings.Fixed.Index (Data, ASCII.LF & ASCII.LF);
      begin
         return (if Blank = 0 then "" else Data (Blank + 2 .. Data'Last));
      end Commit_Message;

      function Tree_Items (Commit : Version.Objects.Hex_Object_Id)
        return Version.Objects.Tree_Entry_Vectors.Vector
      is (Version.Objects.Flatten_Tree
            (Repo,
             Version.Objects.Commit_Tree_Id
               (Version.Objects.Read_Object (Repo, Commit))));

      --  Emit a blob the first time a commit needs it.
      procedure Ensure_Blob (Id : Version.Objects.Hex_Object_Id) is
         Hex : constant String := Version.Objects.To_String (Id);
      begin
         if Marks.Contains (Hex) then
            return;
         end if;

         Put ("blob" & ASCII.LF);
         Put ("mark :" & Mark_Image (New_Mark (Hex)) & ASCII.LF);
         Put_Data
           (Version.Objects.Content (Version.Objects.Read_Object (Repo, Id)));
         Put ("" & ASCII.LF);
      end Ensure_Blob;

      Exported : Version.Trailers.String_Vectors.Vector;

      --  Resolve an explicit ref argument to its fully-qualified name, in
      --  git's rev-parse DWIM order (tags before heads), so `reset`/`commit`
      --  lines name refs/heads|tags/* and the stream recreates the ref. A
      --  short name left as-is creates no ref on reimport.
      function Canonical_Ref (A : String) return String is
      begin
         if A = "HEAD" then
            declare
               H : constant Version.Refs.Head_Info :=
                 Version.Refs.Read_Head (Repo);
            begin
               return (if Version.Refs.Is_Attached (H)
                       then "refs/heads/" & Version.Refs.Branch_Name (H)
                       else A);
            end;
         elsif A'Length >= 5
           and then A (A'First .. A'First + 4) = "refs/"
         then
            return A;
         elsif Version.Refs.Ref_Exists (Repo, "refs/tags/" & A) then
            return "refs/tags/" & A;
         elsif Version.Refs.Ref_Exists (Repo, "refs/heads/" & A) then
            return "refs/heads/" & A;
         elsif Version.Refs.Ref_Exists (Repo, "refs/remotes/" & A) then
            return "refs/remotes/" & A;
         else
            return A;
         end if;
      end Canonical_Ref;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--all" then
               for Name of Version.Refs.List_Branches (Repo) loop
                  Refs.Append ("refs/heads/" & To_String (Name));
               end loop;

               for Name of Version.Tags.List_Tags loop
                  Refs.Append ("refs/tags/" & To_String (Name));
               end loop;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            else
               Refs.Append (Canonical_Ref (A));
            end if;
         end;
      end loop;

      if Refs.Is_Empty then
         return;
      end if;

      --  git emits annotated tags after every commit/branch and lightweight
      --  tag, as `tag` commands at the end of the stream. Defer any ref that
      --  resolves to a tag object so its `from :<mark>` can name an
      --  already-emitted commit and the ordering matches git.
      declare
         package Ref_Sort is new
           Version.Trailers.String_Vectors.Generic_Sorting;
         Head_Refs : Version.Trailers.String_Vectors.Vector;
         Tag_Refs  : Version.Trailers.String_Vectors.Vector;
      begin
         for R of Refs loop
            if R'Length > 10
              and then R (R'First .. R'First + 9) = "refs/tags/"
              and then Version.Objects.Kind
                         (Version.Objects.Read_Object
                            (Repo, Version.Revisions.Resolve (Repo, R)))
                       = Version.Objects.Tag_Object
            then
               Tag_Refs.Append (R);
            else
               Head_Refs.Append (R);
            end if;
         end loop;

         --  git walks refs in sorted order regardless of how they were named.
         Ref_Sort.Sort (Head_Refs);
         Ref_Sort.Sort (Tag_Refs);

         Refs := Head_Refs;
         for R of Tag_Refs loop
            Refs.Append (R);
         end loop;
      end;

      for Ref of Refs loop
         declare
            Is_Tag : constant Boolean :=
              Ref'Length > 10
              and then Ref (Ref'First .. Ref'First + 9) = "refs/tags/";

            --  Only an annotated tag (a tag object) is emitted as a `tag`
            --  command; a lightweight tag is just a ref at a commit and
            --  flows through the normal commit/reset path, exactly as git
            --  does -- otherwise `fast-export --all` drops it entirely.
            Is_Annotated_Tag : constant Boolean :=
              Is_Tag
              and then Version.Objects.Kind
                         (Version.Objects.Read_Object
                            (Repo, Version.Revisions.Resolve (Repo, Ref)))
                       = Version.Objects.Tag_Object;

            Tip : constant Version.Objects.Hex_Object_Id :=
              Version.Revisions.Resolve_Commit (Repo, Ref);

            --  The commits this ref brings that no earlier ref did, oldest
            --  first.
            Order   : Version.Trailers.String_Vectors.Vector;
            Pending : Version.Trailers.String_Vectors.Vector;
            Seen    : Version.Trailers.String_Vectors.Vector;
         begin
            Pending.Append (Version.Objects.To_String (Tip));

            while not Pending.Is_Empty loop
               declare
                  C : constant String := Pending.Last_Element;
               begin
                  Pending.Delete_Last;

                  if not Seen.Contains (C)
                    and then not Exported.Contains (C)
                  then
                     Seen.Append (C);

                     for P of Version.History.Parent_Commits
                                (Repo, Version.Objects.To_Object_Id (C))
                     loop
                        Pending.Append (Version.Objects.To_String (P));
                     end loop;
                  end if;
               end;
            end loop;

            --  Parents before children.
            declare
               Remaining : Version.Trailers.String_Vectors.Vector := Seen;
            begin
               while not Remaining.Is_Empty loop
                  declare
                     Progress : Boolean := False;
                     Kept     : Version.Trailers.String_Vectors.Vector;
                  begin
                     for C of Remaining loop
                        declare
                           Ready : Boolean := True;
                        begin
                           for P of Version.History.Parent_Commits
                                      (Repo, Version.Objects.To_Object_Id (C))
                           loop
                              declare
                                 Hex : constant String :=
                                   Version.Objects.To_String (P);
                              begin
                                 if Remaining.Contains (Hex)
                                   and then not Order.Contains (Hex)
                                 then
                                    Ready := False;
                                 end if;
                              end;
                           end loop;

                           if Ready then
                              Order.Append (C);
                              Progress := True;
                           else
                              Kept.Append (C);
                           end if;
                        end;
                     end loop;

                     exit when not Progress;
                     Remaining := Kept;
                  end;
               end loop;
            end;

            if Is_Annotated_Tag then
               declare
                  Obj : constant Version.Objects.Git_Object :=
                    Version.Objects.Read_Object
                      (Repo, Version.Revisions.Resolve (Repo, Ref));
                  Name : constant String :=
                    Ref (Ref'First + 10 .. Ref'Last);
               begin
                  if Version.Objects.Kind (Obj) = Version.Objects.Tag_Object
                    and then Marks.Contains (Version.Objects.To_String (Tip))
                  then
                     declare
                        Data : constant String :=
                          Version.Objects.Content (Obj);
                        Blank : constant Natural :=
                          Ada.Strings.Fixed.Index
                            (Data, ASCII.LF & ASCII.LF);
                        Tagger : Unbounded_String;
                        Pos    : Natural := Data'First;
                     begin
                        while Pos <= Data'Last loop
                           declare
                              Stop : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Data, "" & ASCII.LF, Pos);
                              Line : constant String :=
                                Data (Pos .. (if Stop = 0 then Data'Last
                                              else Stop - 1));
                           begin
                              exit when Line'Length = 0 or else Stop = 0;

                              if Line'Length > 7
                                and then Line (Line'First .. Line'First + 6)
                                         = "tagger "
                              then
                                 Tagger :=
                                   To_Unbounded_String
                                     (Line (Line'First + 7 .. Line'Last));
                              end if;

                              Pos := Stop + 1;
                           end;
                        end loop;

                        Put ("tag " & Name & ASCII.LF);
                        Put ("from :"
                             & Mark_Image
                                 (Marks.Element
                                    (Version.Objects.To_String (Tip)))
                             & ASCII.LF);

                        if Tagger /= "" then
                           Put ("tagger " & To_String (Tagger) & ASCII.LF);
                        end if;

                        Put_Data
                          ((if Blank = 0 then ""
                            else Data (Blank + 2 .. Data'Last)));
                        Put ("" & ASCII.LF);
                     end;
                  end if;
               end;
            elsif Order.Is_Empty then
               --  Nothing new: the ref just points at something we have.
               if Marks.Contains (Version.Objects.To_String (Tip)) then
                  Put ("reset " & Ref & ASCII.LF);
                  Put ("from :"
                       & Mark_Image
                           (Marks.Element (Version.Objects.To_String (Tip)))
                       & ASCII.LF);
                  Put ("" & ASCII.LF);
               end if;
            else
               declare
                  First : Boolean := True;
               begin
                  for C of Order loop
                     declare
                        Id : constant Version.Objects.Hex_Object_Id :=
                          Version.Objects.To_Object_Id (C);

                        Parents : constant
                          Version.History.Commit_Id_Vectors.Vector :=
                            Version.History.Parent_Commits (Repo, Id);

                        Items : constant
                          Version.Objects.Tree_Entry_Vectors.Vector :=
                            Tree_Items (Id);

                        Parent_Items : constant
                          Version.Objects.Tree_Entry_Vectors.Vector :=
                            (if Parents.Is_Empty
                             then Version.Objects.Tree_Entry_Vectors
                                    .Empty_Vector
                             else Tree_Items (Parents.First_Element));
                     begin
                        --  Blobs first: a commit may only refer to marks that
                        --  already exist.
                        for E of Items loop
                           if E.Kind = Version.Objects.Tree_Blob then
                              declare
                                 Same : Boolean := False;
                              begin
                                 for P of Parent_Items loop
                                    if P.Path = E.Path
                                      and then Version.Objects.To_String (P.Id)
                                               = Version.Objects.To_String
                                                   (E.Id)
                                      and then P.Mode = E.Mode
                                    then
                                       Same := True;
                                    end if;
                                 end loop;

                                 if not Same then
                                    Ensure_Blob (E.Id);
                                 end if;
                              end;
                           end if;
                        end loop;

                        --  git only resets the ref when the commit it starts
                        --  with has no parent to hang from.
                        if First then
                           if Parents.Is_Empty then
                              Put ("reset " & Ref & ASCII.LF);
                           end if;

                           First := False;
                        end if;

                        Put ("commit " & Ref & ASCII.LF);
                        Put ("mark :" & Mark_Image (New_Mark (C)) & ASCII.LF);
                        Put ("author " & Header_Line (Id, "author ")
                             & ASCII.LF);
                        Put ("committer " & Header_Line (Id, "committer ")
                             & ASCII.LF);
                        Put_Data (Commit_Message (Id));

                        if not Parents.Is_Empty then
                           declare
                              P0 : constant String :=
                                Version.Objects.To_String
                                  (Parents.First_Element);
                           begin
                              if Marks.Contains (P0) then
                                 Put ("from :" & Mark_Image (Marks.Element (P0))
                                      & ASCII.LF);
                              end if;
                           end;

                           for K in Parents.First_Index + 1
                                    .. Parents.Last_Index
                           loop
                              declare
                                 PK : constant String :=
                                   Version.Objects.To_String
                                     (Parents.Element (K));
                              begin
                                 if Marks.Contains (PK) then
                                    Put ("merge :"
                                         & Mark_Image (Marks.Element (PK))
                                         & ASCII.LF);
                                 end if;
                              end;
                           end loop;
                        end if;

                        --  What changed against the first parent, in path
                        --  order: git interleaves the M and D lines.
                        declare
                           Changes : Version.Trailers.String_Vectors.Vector;
                        begin
                           for E of Items loop
                              if E.Kind = Version.Objects.Tree_Blob then
                                 declare
                                    Same : Boolean := False;
                                 begin
                                    for P of Parent_Items loop
                                       if P.Path = E.Path
                                         and then Version.Objects.To_String
                                                    (P.Id)
                                                  = Version.Objects.To_String
                                                      (E.Id)
                                         and then P.Mode = E.Mode
                                       then
                                          Same := True;
                                       end if;
                                    end loop;

                                    if not Same then
                                       Changes.Append
                                         (To_String (E.Path) & ASCII.NUL
                                          & "M " & To_String (E.Mode) & " :"
                                          & Mark_Image
                                              (Marks.Element
                                                 (Version.Objects.To_String
                                                    (E.Id)))
                                          & " " & To_String (E.Path));
                                    end if;
                                 end;
                              end if;
                           end loop;

                           for P of Parent_Items loop
                              if P.Kind = Version.Objects.Tree_Blob then
                                 declare
                                    Gone : Boolean := True;
                                 begin
                                    for E of Items loop
                                       if E.Path = P.Path then
                                          Gone := False;
                                       end if;
                                    end loop;

                                    if Gone then
                                       Changes.Append
                                         (To_String (P.Path) & ASCII.NUL
                                          & "D " & To_String (P.Path));
                                    end if;
                                 end;
                              end if;
                           end loop;

                           --  Plain insertion sort: a commit's change list is
                           --  short.
                           for I in Changes.First_Index + 1
                                    .. Changes.Last_Index
                           loop
                              declare
                                 Item : constant String := Changes.Element (I);
                                 J    : Integer := I - 1;
                              begin
                                 while J >= Changes.First_Index
                                   and then Changes.Element (J) > Item
                                 loop
                                    Changes.Replace_Element
                                      (J + 1, Changes.Element (J));
                                    J := J - 1;
                                 end loop;

                                 Changes.Replace_Element (J + 1, Item);
                              end;
                           end loop;

                           for Item of Changes loop
                              declare
                                 NUL : constant Natural :=
                                   Ada.Strings.Fixed.Index
                                     (Item, "" & ASCII.NUL);
                              begin
                                 Put (Item (NUL + 1 .. Item'Last) & ASCII.LF);
                              end;
                           end loop;
                        end;

                        Put ("" & ASCII.LF);
                        Exported.Append (C);
                     end;
                  end loop;
               end;
            end if;
         end;
      end loop;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Fast_Export_Command;

   --  Point a ref at an object, whatever it held before.
   procedure Write_Ref_To
     (Repo : Version.Repository.Repository_Handle;
      Name : String;
      Id   : Version.Objects.Hex_Object_Id)
   is
      Tx : Version.Ref_Transaction.Transaction;
   begin
      Version.Ref_Transaction.Start (Tx, Repo);
      Version.Ref_Transaction.Add_Update
        (Item => Tx, Ref_Name => Name, New_Id => Id);
      Version.Ref_Transaction.Commit (Tx);
   exception
      when others =>
         Version.Ref_Transaction.Cancel (Tx);
         raise;
   end Write_Ref_To;

   --  An `M` line's mode, in git's canonical six-digit form. The stream format
   --  also allows the short octal spellings, which git maps onto the regular
   --  file and tree bits (`644` -> S_IFREG or 0644); anything outside the set
   --  git accepts is a corrupt mode, reported against the whole line as git
   --  reports it.
   function Fast_Import_Mode (Text, Line : String) return String is
   begin
      if Text = "644" then
         return "100644";
      elsif Text = "755" then
         return "100755";
      elsif Text = "40000" then
         return "040000";
      elsif Text = "100644" or else Text = "100755"
        or else Text = "120000" or else Text = "160000"
        or else Text = "040000"
      then
         return Text;
      else
         raise Ada.IO_Exceptions.Data_Error
           with "corrupt mode: " & Line;
      end if;
   end Fast_Import_Mode;

   --  `fast-import` -- build history from a fast-import stream on stdin.
   --  Understands the commands git's own `fast-export` emits: blob/mark/data,
   --  commit (author/committer/data/from/merge, then M and D changes), reset,
   --  and tag.
   procedure Run_Fast_Import_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Text : constant String := Read_All_Stdin;
      Pos  : Natural := Text'First;

      Marks : Mark_Id_Maps.Map;   --  ":<n>" -> object id

      --  The tree each ref is at, as a path -> (mode, id) list we mutate.
      Files : Version.Staging.Index_Entry_Vectors.Vector;

      function At_End return Boolean is (Pos > Text'Last);

      function Next_Line return String is
         Stop : constant Natural :=
           Ada.Strings.Fixed.Index (Text, "" & ASCII.LF, Pos);
         Line : constant String :=
           Text (Pos .. (if Stop = 0 then Text'Last else Stop - 1));
      begin
         Pos := (if Stop = 0 then Text'Last + 1 else Stop + 1);
         return Line;
      end Next_Line;

      function Peek_Line return String is
         Stop : constant Natural :=
           Ada.Strings.Fixed.Index (Text, "" & ASCII.LF, Pos);
      begin
         if At_End then
            return "";
         end if;

         return Text (Pos .. (if Stop = 0 then Text'Last else Stop - 1));
      end Peek_Line;

      --  "data <n>" followed by exactly n bytes.
      function Read_Data (Header : String) return String is
         Count_Text : constant String :=
           Header (Header'First + 5 .. Header'Last);
         N : constant Natural := Natural'Value (Count_Text);
         Content : constant String := Text (Pos .. Pos + N - 1);
      begin
         Pos := Pos + N;

         --  An optional newline after the payload.
         if not At_End and then Text (Pos) = ASCII.LF then
            Pos := Pos + 1;
         end if;

         return Content;
      end Read_Data;

      function Resolve_Mark (Token : String) return String is
      begin
         if Token'Length > 1 and then Token (Token'First) = ':' then
            if Marks.Contains (Token) then
               return Marks.Element (Token);
            end if;

            return "";
         end if;

         return Token;
      end Resolve_Mark;

      procedure Set_File (Path : String; Mode : String; Id : String) is
         Kept : Version.Staging.Index_Entry_Vectors.Vector;
      begin
         for E of Files loop
            if To_String (E.Path) /= Path then
               Kept.Append (E);
            end if;
         end loop;

         Kept.Append
           (Version.Staging.Index_Entry'
              (Path  => To_Unbounded_String (Path),
               Id    => Version.Objects.To_Object_Id (Id),
               Mode  => To_Unbounded_String (Mode),
               Stage => 0,
               Skip_Worktree => False));
         Files := Kept;
      end Set_File;

      procedure Drop_File (Path : String) is
         Kept : Version.Staging.Index_Entry_Vectors.Vector;
      begin
         for E of Files loop
            --  `D <dir>` drops everything under it.
            if To_String (E.Path) /= Path
              and then not (To_String (E.Path)'Length > Path'Length
                            and then To_String (E.Path)
                                       (1 .. Path'Length + 1)
                                     = Path & "/")
            then
               Kept.Append (E);
            end if;
         end loop;

         Files := Kept;
      end Drop_File;

      procedure Load_Files (Commit : String) is
      begin
         Files.Clear;

         if Commit = "" then
            return;
         end if;

         for E of Version.Objects.Flatten_Tree
                    (Repo,
                     Version.Objects.Commit_Tree_Id
                       (Version.Objects.Read_Object
                          (Repo, Version.Objects.To_Object_Id (Commit))))
         loop
            if E.Kind = Version.Objects.Tree_Blob then
               Files.Append
                 (Version.Staging.Index_Entry'
                    (Path  => E.Path,
                     Id    => E.Id,
                     Mode  => E.Mode,
                     Stage => 0,
                     Skip_Worktree => False));
            end if;
         end loop;
      end Load_Files;

   begin
      while not At_End loop
         declare
            Line : constant String := Next_Line;
         begin
            if Line'Length = 0 then
               null;

            elsif Line = "blob" then
               declare
                  Mark : Unbounded_String;
               begin
                  if Peek_Line'Length > 5
                    and then Peek_Line (Peek_Line'First
                                        .. Peek_Line'First + 4) = "mark "
                  then
                     declare
                        M : constant String := Next_Line;
                     begin
                        Mark :=
                          To_Unbounded_String (M (M'First + 5 .. M'Last));
                     end;
                  end if;

                  declare
                     Header : constant String := Next_Line;
                     Blob   : constant Version.Objects.Hex_Object_Id :=
                       Version.Write.Write_Blob (Repo, Read_Data (Header));
                  begin
                     if Mark /= "" then
                        Marks.Include
                          (To_String (Mark),
                           Version.Objects.To_String (Blob));
                     end if;
                  end;
               end;

            elsif Line'Length > 7
              and then Line (Line'First .. Line'First + 6) = "commit "
            then
               declare
                  Ref : constant String := Line (Line'First + 7 .. Line'Last);

                  Mark      : Unbounded_String;
                  Author    : Unbounded_String;
                  Committer : Unbounded_String;
                  Message   : Unbounded_String;
                  Parents   : Version.Objects.Object_Id_Vectors.Vector;
                  Started   : Boolean := False;
               begin
                  loop
                     exit when At_End;

                     declare
                        Next : constant String := Peek_Line;
                     begin
                        if Next'Length > 5
                          and then Next (Next'First .. Next'First + 4)
                                   = "mark "
                        then
                           Mark :=
                             To_Unbounded_String
                               (Next (Next'First + 5 .. Next'Last));
                           Pos := Pos + Next'Length + 1;
                        elsif Next'Length > 7
                          and then Next (Next'First .. Next'First + 6)
                                   = "author "
                        then
                           Author :=
                             To_Unbounded_String
                               (Next (Next'First + 7 .. Next'Last));
                           Pos := Pos + Next'Length + 1;
                        elsif Next'Length > 10
                          and then Next (Next'First .. Next'First + 9)
                                   = "committer "
                        then
                           Committer :=
                             To_Unbounded_String
                               (Next (Next'First + 10 .. Next'Last));
                           Pos := Pos + Next'Length + 1;
                        elsif Next'Length > 5
                          and then Next (Next'First .. Next'First + 4)
                                   = "data "
                        then
                           Pos := Pos + Next'Length + 1;
                           Message := To_Unbounded_String (Read_Data (Next));
                        elsif Next'Length > 5
                          and then Next (Next'First .. Next'First + 4)
                                   = "from "
                        then
                           Pos := Pos + Next'Length + 1;

                           declare
                              Id : constant String :=
                                Resolve_Mark
                                  (Next (Next'First + 5 .. Next'Last));
                           begin
                              if Id /= "" then
                                 Parents.Append
                                   (Version.Objects.To_Object_Id (Id));
                                 Load_Files (Id);
                                 Started := True;
                              end if;
                           end;
                        elsif Next'Length > 6
                          and then Next (Next'First .. Next'First + 5)
                                   = "merge "
                        then
                           Pos := Pos + Next'Length + 1;

                           declare
                              Id : constant String :=
                                Resolve_Mark
                                  (Next (Next'First + 6 .. Next'Last));
                           begin
                              if Id /= "" then
                                 Parents.Append
                                   (Version.Objects.To_Object_Id (Id));
                              end if;
                           end;
                        else
                           exit;
                        end if;
                     end;
                  end loop;

                  if not Started then
                     --  No explicit `from`: git implicitly parents the commit
                     --  on the ref's current tip -- set earlier in this stream
                     --  or already in the repo -- and builds on its tree.
                     --  Only a brand-new ref starts from an empty tree.
                     --  Clearing unconditionally (the old behaviour) dropped
                     --  every previously committed file and orphaned history.
                     if Version.Refs.Ref_Exists (Repo, Ref) then
                        declare
                           Tip : constant String :=
                             Version.Objects.To_String
                               (Version.Revisions.Resolve_Commit (Repo, Ref));
                        begin
                           Parents.Append
                             (Version.Objects.To_Object_Id (Tip));
                           Load_Files (Tip);
                        end;
                     else
                        Files.Clear;
                     end if;
                  end if;

                  --  The file changes, until the blank line.
                  loop
                     exit when At_End;
                     exit when Peek_Line'Length = 0;

                     declare
                        Change : constant String := Next_Line;
                     begin
                        if Change'Length > 2
                          and then Change (Change'First .. Change'First + 1)
                                   = "M "
                        then
                           declare
                              Rest  : constant String :=
                                Change (Change'First + 2 .. Change'Last);
                              S1    : constant Natural :=
                                Ada.Strings.Fixed.Index (Rest, " ");
                              Mode  : constant String :=
                                Rest (Rest'First .. S1 - 1);
                              Rest2 : constant String :=
                                Rest (S1 + 1 .. Rest'Last);
                              S2    : constant Natural :=
                                Ada.Strings.Fixed.Index (Rest2, " ");
                              Ref_T : constant String :=
                                Rest2 (Rest2'First .. S2 - 1);
                              Path  : constant String :=
                                Rest2 (S2 + 1 .. Rest2'Last);
                           begin
                              if Ref_T = "inline" then
                                 --  `inline` carries the file's content in the
                                 --  stream -- a data block on the next line --
                                 --  instead of naming an earlier mark.
                                 declare
                                    Header : constant String := Next_Line;
                                    Blob   : constant
                                      Version.Objects.Hex_Object_Id :=
                                        Version.Write.Write_Blob
                                          (Repo, Read_Data (Header));
                                 begin
                                    Set_File
                                      (Path, Fast_Import_Mode (Mode, Change),
                                       Version.Objects.To_String (Blob));
                                 end;
                              else
                                 Set_File
                                   (Path, Fast_Import_Mode (Mode, Change),
                                    Resolve_Mark (Ref_T));
                              end if;
                           end;
                        elsif Change'Length > 2
                          and then Change (Change'First .. Change'First + 1)
                                   = "D "
                        then
                           Drop_File
                             (Change (Change'First + 2 .. Change'Last));
                        end if;
                     end;
                  end loop;

                  declare
                     Tree : constant Version.Objects.Hex_Object_Id :=
                       Version.Write.Write_Tree_From_Index (Repo, Files);

                     --  Write_Commit_Raw terminates the message itself; the
                     --  stream's payload already ends in a newline.
                     Body_Text : constant String :=
                       (if Length (Message) > 0
                          and then Element (Message, Length (Message))
                                   = ASCII.LF
                        then Slice (Message, 1, Length (Message) - 1)
                        else To_String (Message));

                     --  git fast-import defaults a commit's author to its
                     --  committer when the stream omits the author line.
                     Author_Line : constant String :=
                       (if Length (Author) = 0
                        then To_String (Committer)
                        else To_String (Author));

                     New_Commit : constant Version.Objects.Hex_Object_Id :=
                       Version.Write.Write_Commit_Raw
                         (Repo, Tree, Parents,
                          Author_Line, To_String (Committer),
                          Body_Text);
                  begin
                     if Mark /= "" then
                        Marks.Include
                          (To_String (Mark),
                           Version.Objects.To_String (New_Commit));
                     end if;

                     Write_Ref_To (Repo, Ref, New_Commit);
                  end;
               end;

            elsif Line'Length > 6
              and then Line (Line'First .. Line'First + 5) = "reset "
            then
               declare
                  Ref : constant String := Line (Line'First + 6 .. Line'Last);
               begin
                  if not At_End and then Peek_Line'Length > 5
                    and then Peek_Line (Peek_Line'First
                                        .. Peek_Line'First + 4) = "from "
                  then
                     declare
                        From : constant String := Next_Line;
                        Id   : constant String :=
                          Resolve_Mark (From (From'First + 5 .. From'Last));
                     begin
                        if Id /= "" then
                           Write_Ref_To
                             (Repo, Ref, Version.Objects.To_Object_Id (Id));
                        end if;
                     end;
                  end if;
               end;

            elsif Line'Length > 4
              and then Line (Line'First .. Line'First + 3) = "tag "
            then
               declare
                  Name   : constant String := Line (Line'First + 4 .. Line'Last);
                  Target : Unbounded_String;
                  Tagger : Unbounded_String;
                  Message : Unbounded_String;
               begin
                  loop
                     exit when At_End;

                     declare
                        Next : constant String := Peek_Line;
                     begin
                        if Next'Length > 5
                          and then Next (Next'First .. Next'First + 4)
                                   = "from "
                        then
                           Pos := Pos + Next'Length + 1;
                           Target :=
                             To_Unbounded_String
                               (Resolve_Mark
                                  (Next (Next'First + 5 .. Next'Last)));
                        elsif Next'Length > 7
                          and then Next (Next'First .. Next'First + 6)
                                   = "tagger "
                        then
                           Pos := Pos + Next'Length + 1;
                           Tagger :=
                             To_Unbounded_String
                               (Next (Next'First + 7 .. Next'Last));
                        elsif Next'Length > 5
                          and then Next (Next'First .. Next'First + 4)
                                   = "data "
                        then
                           Pos := Pos + Next'Length + 1;
                           Message := To_Unbounded_String (Read_Data (Next));
                        else
                           exit;
                        end if;
                     end;
                  end loop;

                  if Target /= "" then
                     --  Built by hand: the stream's tagger line has to survive
                     --  verbatim, which Write_Tag (which stamps the current
                     --  identity) would not do.
                     declare
                        Content : constant String :=
                          "object " & To_String (Target) & ASCII.LF
                          & "type commit" & ASCII.LF
                          & "tag " & Name & ASCII.LF
                          & (if Tagger = "" then ""
                             else "tagger " & To_String (Tagger) & ASCII.LF)
                          & ASCII.LF
                          & To_String (Message);

                        Tag_Id : constant Version.Objects.Hex_Object_Id :=
                          Version.Write.Write_Object (Repo, "tag", Content);
                     begin
                        Write_Ref_To (Repo, "refs/tags/" & Name, Tag_Id);
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error | Constraint_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Fast_Import_Command;

   --  `send-pack [--force] <repository> <refspec>...` -- push, and report as
   --  push does.
   procedure Run_Send_Pack_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Force    : Boolean := False;
      Source   : Unbounded_String;
      Refspecs : Version.Trailers.String_Vectors.Vector;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--force" or else A = "-f" then
               Force := True;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            elsif Source = "" then
               Source := To_Unbounded_String (A);
            else
               Refspecs.Append (A);
            end if;
         end;
      end loop;

      if Source = "" or else Refspecs.Is_Empty then
         Error_Line ("usage: version send-pack <repository> <refspec>...");
         Set_Usage_Failure;
         return;
      end if;

      Success_Line ("To " & To_String (Source));

      for Spec of Refspecs loop
         declare
            Plus  : constant Boolean :=
              Spec'Length > 0 and then Spec (Spec'First) = '+';
            Body_Text : constant String :=
              (if Plus then Spec (Spec'First + 1 .. Spec'Last) else Spec);
            Colon : constant Natural :=
              Ada.Strings.Fixed.Index (Body_Text, ":");
            Src   : constant String :=
              (if Colon = 0 then Body_Text
               else Body_Text (Body_Text'First .. Colon - 1));
            Dst   : constant String :=
              (if Colon = 0 then Body_Text
               else Body_Text (Colon + 1 .. Body_Text'Last));

            Full_Dst : constant String :=
              (if Dst'Length > 5
                 and then Dst (Dst'First .. Dst'First + 4) = "refs/"
               then Dst else "refs/heads/" & Dst);

            Short_Src : constant String :=
              (if Src'Length > 11
                 and then Src (Src'First .. Src'First + 10) = "refs/heads/"
               then Src (Src'First + 11 .. Src'Last) else Src);
            Short_Dst : constant String :=
              (if Full_Dst'Length > 11
                 and then Full_Dst (Full_Dst'First .. Full_Dst'First + 10)
                          = "refs/heads/"
               then Full_Dst (Full_Dst'First + 11 .. Full_Dst'Last)
               else Full_Dst);

            --  What the remote has now decides the summary git prints.
            Before : Unbounded_String;
         begin
            for R of Version.Fetch.List_Remote_Refs (To_String (Source)) loop
               if To_String (R.Name) = Full_Dst then
                  Before :=
                    To_Unbounded_String (Version.Objects.To_String (R.Id));
               end if;
            end loop;

            Version.Push.Push_Refspec_To
              (Repository => To_String (Source),
               Source     => Src,
               Dest_Ref   => Full_Dst,
               Force      => Force or else Plus);

            declare
               After : constant Version.Objects.Hex_Object_Id :=
                 Version.Revisions.Resolve_Commit (Repo, Src);

               function Abbrev (Hex : String) return String is
                 (if Hex'Length >= 7 then Hex (Hex'First .. Hex'First + 6)
                  else Hex);

               Summary : constant String :=
                 (if Before = "" then "[new branch]"
                  else Abbrev (To_String (Before)) & ".."
                       & Abbrev (Version.Objects.To_String (After)));

               Code : constant Character :=
                 (if Before = "" then '*' else ' ');

               Pad : constant Natural :=
                 (if Summary'Length >= 18 then 1 else 18 - Summary'Length);
            begin
               Success_Line
                 (" " & Code & " " & Summary & [1 .. Pad => ' ']
                  & Short_Src & " -> " & Short_Dst);
            end;
         end;
      end loop;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Send_Pack_Command;

   --  `filter-branch [-f] [--index-filter <cmd>] [--tree-filter <cmd>]
   --                  [--msg-filter <cmd>] [--subdirectory-filter <dir>]
   --                  [--prune-empty] [--] [<rev>...]`
   --  Rewrite history, commit by commit, oldest first.  The original ref is
   --  kept under refs/original/.
   procedure Run_Filter_Branch_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Force        : Boolean := False;
      Prune_Empty  : Boolean := False;
      Index_Filter : Unbounded_String;
      Tree_Filter  : Unbounded_String;
      Msg_Filter   : Unbounded_String;
      Sub_Dir      : Unbounded_String;
      Revs         : Version.Trailers.String_Vectors.Vector;

      I : Positive := 2;

      Git_Dir : constant String := Version.Repository.Common_Git_Dir (Repo);

      Temp_Index : constant String :=
        Version.Files.Join (Git_Dir, "filter-branch-index");

      --  git runs a filter in an EMPTY working tree with GIT_DIR,
      --  GIT_WORK_TREE and GIT_INDEX_FILE pointing at the temporaries -- which
      --  is what lets `git rm --cached` inside an index filter work at all
      --  (in the real working tree it refuses, seeing content that differs
      --  from both the file and HEAD).
      Work_Dir : constant String :=
        Version.Files.Join (Git_Dir, "filter-branch-work");

      function Run (Command : String) return Integer is
         Args   : GNAT.OS_Lib.Argument_List (1 .. 2);
         Status : Integer;
      begin
         Version.Files.Create_Directory_If_Missing (Work_Dir);

         Args (1) := new String'("-c");
         Args (2) :=
           new String'
             ("cd '" & Work_Dir & "' && GIT_WORK_TREE=. GIT_DIR='"
              & Ada.Directories.Full_Name (Git_Dir) & "' " & Command);
         Status :=
           GNAT.OS_Lib.Spawn (Program_Name => "/bin/sh", Args => Args);
         GNAT.OS_Lib.Free (Args (1));
         GNAT.OS_Lib.Free (Args (2));
         return Status;
      end Run;

      Map : Mark_Id_Maps.Map;   --  old commit -> new commit
   begin
      while I <= Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "-f" or else A = "--force" then
               Force := True;
            elsif A = "--prune-empty" then
               Prune_Empty := True;
            elsif A = "--index-filter" and then I < Count then
               Index_Filter := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A = "--tree-filter" and then I < Count then
               Tree_Filter := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A = "--msg-filter" and then I < Count then
               Msg_Filter := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A = "--subdirectory-filter" and then I < Count then
               Sub_Dir := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A = "--" then
               null;
            elsif A'Length > 0 and then A (A'First) = '-' then
               Error_Line ("unsupported filter-branch option: " & A);
               Set_Usage_Failure;
               return;
            else
               Revs.Append (A);
            end if;
         end;

         I := I + 1;
      end loop;

      if Revs.Is_Empty then
         Revs.Append ("HEAD");
      end if;

      declare
         Ref_Name : constant String :=
           (if Revs.First_Element = "HEAD"
              or else Revs.First_Element = "--all"
            then (declare
                    Branch : constant String :=
                      Version.Refs.Current_Branch_Name (Repo);
                  begin
                    "refs/heads/" & Branch)
            elsif Revs.First_Element'Length > 5
              and then Revs.First_Element
                         (Revs.First_Element'First
                          .. Revs.First_Element'First + 4) = "refs/"
            then Revs.First_Element
            else "refs/heads/" & Revs.First_Element);

         Backup : constant String := "refs/original/" & Ref_Name;

         Tip : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, Ref_Name);

         Backup_Path : constant String :=
           Version.Files.Join (Git_Dir, Backup);
      begin
         if Ada.Directories.Exists (Backup_Path) and then not Force then
            Error_Line
              ("Cannot create a new backup." & ASCII.LF
               & "A previous backup already exists in " & Backup & ASCII.LF
               & "Force overwriting the backup with -f");
            Set_Command_Failure;
            return;
         end if;

         --  Oldest first.
         declare
            Order   : Version.Trailers.String_Vectors.Vector;
            Pending : Version.Trailers.String_Vectors.Vector;
            Seen    : Version.Trailers.String_Vectors.Vector;
            Total   : Natural := 0;
            Done    : Natural := 0;
         begin
            Pending.Append (Version.Objects.To_String (Tip));

            while not Pending.Is_Empty loop
               declare
                  C : constant String := Pending.Last_Element;
               begin
                  Pending.Delete_Last;

                  if not Seen.Contains (C) then
                     Seen.Append (C);

                     for P of Version.History.Parent_Commits
                                (Repo, Version.Objects.To_Object_Id (C))
                     loop
                        Pending.Append (Version.Objects.To_String (P));
                     end loop;
                  end if;
               end;
            end loop;

            declare
               Remaining : Version.Trailers.String_Vectors.Vector := Seen;
            begin
               while not Remaining.Is_Empty loop
                  declare
                     Kept     : Version.Trailers.String_Vectors.Vector;
                     Progress : Boolean := False;
                  begin
                     for C of Remaining loop
                        declare
                           Ready : Boolean := True;
                        begin
                           for P of Version.History.Parent_Commits
                                      (Repo, Version.Objects.To_Object_Id (C))
                           loop
                              if Seen.Contains
                                   (Version.Objects.To_String (P))
                                and then not Order.Contains
                                               (Version.Objects.To_String (P))
                              then
                                 Ready := False;
                              end if;
                           end loop;

                           if Ready then
                              Order.Append (C);
                              Progress := True;
                           else
                              Kept.Append (C);
                           end if;
                        end;
                     end loop;

                     exit when not Progress;
                     Remaining := Kept;
                  end;
               end loop;
            end;

            Total := Natural (Order.Length);

            for C of Order loop
               Done := Done + 1;

               declare
                  Id : constant Version.Objects.Hex_Object_Id :=
                    Version.Objects.To_Object_Id (C);

                  Old_Tree : constant Version.Objects.Hex_Object_Id :=
                    Version.Objects.Commit_Tree_Id
                      (Version.Objects.Read_Object (Repo, Id));

                  Author, Committer : Unbounded_String;
                  Message : Unbounded_String;

                  New_Tree : Version.Objects.Hex_Object_Id := Old_Tree;
               begin
                  Stderr_Line
                    ("Rewrite " & C & " ("
                     & Ada.Strings.Fixed.Trim
                         (Natural'Image (Done), Ada.Strings.Both)
                     & "/"
                     & Ada.Strings.Fixed.Trim
                         (Natural'Image (Total), Ada.Strings.Both)
                     & ")");

                  --  Pull the commit apart.
                  declare
                     Data : constant String :=
                       Version.Objects.Content
                         (Version.Objects.Read_Object (Repo, Id));
                     Pos  : Natural := Data'First;
                  begin
                     while Pos <= Data'Last loop
                        declare
                           Stop : constant Natural :=
                             Ada.Strings.Fixed.Index
                               (Data, "" & ASCII.LF, Pos);
                           Line : constant String :=
                             Data (Pos .. (if Stop = 0 then Data'Last
                                           else Stop - 1));
                        begin
                           if Line'Length = 0 then
                              Message :=
                                To_Unbounded_String
                                  (Data (Stop + 1 .. Data'Last));
                              exit;
                           end if;

                           if Line'Length > 7
                             and then Line (Line'First .. Line'First + 6)
                                      = "author "
                           then
                              Author :=
                                To_Unbounded_String
                                  (Line (Line'First + 7 .. Line'Last));
                           elsif Line'Length > 10
                             and then Line (Line'First .. Line'First + 9)
                                      = "committer "
                           then
                              Committer :=
                                To_Unbounded_String
                                  (Line (Line'First + 10 .. Line'Last));
                           end if;

                           exit when Stop = 0;
                           Pos := Stop + 1;
                        end;
                     end loop;
                  end;

                  --  `--subdirectory-filter`: the subdirectory becomes the
                  --  root.
                  if Sub_Dir /= "" then
                     declare
                        Found : Boolean := False;
                     begin
                        for E of Version.Objects.Tree_Entries
                                   (Repo, Old_Tree)
                        loop
                           if To_String (E.Path) = To_String (Sub_Dir)
                             and then E.Kind = Version.Objects.Tree_Directory
                           then
                              New_Tree := E.Id;
                              Found := True;
                           end if;
                        end loop;

                        if not Found then
                           goto Next_Commit;
                        end if;
                     end;
                  end if;

                  --  `--index-filter`: hand the filter an index holding this
                  --  commit's tree, through GIT_INDEX_FILE, and take back
                  --  whatever it leaves there.
                  if Index_Filter /= "" then
                     declare
                        Entries : Version.Staging.Index_Entry_Vectors.Vector;
                        Status  : Integer;
                     begin
                        for E of Version.Objects.Flatten_Tree (Repo, New_Tree)
                        loop
                           if E.Kind = Version.Objects.Tree_Blob then
                              Entries.Append
                                (Version.Staging.Index_Entry'
                                   (Path  => E.Path,
                                    Id    => E.Id,
                                    Mode  => E.Mode,
                                    Stage => 0,
                                    Skip_Worktree => False));
                           end if;
                        end loop;

                        if Ada.Directories.Exists (Temp_Index) then
                           Ada.Directories.Delete_File (Temp_Index);
                        end if;

                        Ada.Environment_Variables.Set
                          ("GIT_INDEX_FILE", Temp_Index);
                        Version.Staging.Write (Repo, Entries);

                        Status := Run (To_String (Index_Filter));

                        if Status /= 0 then
                           Ada.Environment_Variables.Clear ("GIT_INDEX_FILE");
                           Error_Line
                             ("index filter failed: "
                              & To_String (Index_Filter));
                           Set_Command_Failure;
                           return;
                        end if;

                        New_Tree :=
                          Version.Write.Write_Tree_From_Index
                            (Repo, Version.Staging.Load (Repo));
                        Ada.Environment_Variables.Clear ("GIT_INDEX_FILE");
                     end;
                  end if;

                  --  `--tree-filter`: check the tree out, let the command
                  --  loose on it, and take the tree back from what is left.
                  if Tree_Filter /= "" then
                     declare
                        Status : Integer;

                        Entries :
                          Version.Staging.Index_Entry_Vectors.Vector;

                        procedure Collect (Dir : String; Prefix : String) is
                           Search : Ada.Directories.Search_Type;
                           Item   : Ada.Directories.Directory_Entry_Type;
                        begin
                           Ada.Directories.Start_Search
                             (Search, Dir, "",
                              [Ada.Directories.Ordinary_File => True,
                               Ada.Directories.Directory     => True,
                               Ada.Directories.Special_File  => False]);

                           while Ada.Directories.More_Entries (Search) loop
                              Ada.Directories.Get_Next_Entry (Search, Item);

                              declare
                                 Simple : constant String :=
                                   Ada.Directories.Simple_Name (Item);
                                 Full   : constant String :=
                                   Version.Files.Join (Dir, Simple);
                              begin
                                 if Simple /= "." and then Simple /= ".."
                                   and then Simple /= ".git"
                                 then
                                    if Ada.Directories.Kind (Item)
                                       = Ada.Directories.Directory
                                    then
                                       Collect (Full, Prefix & Simple & "/");
                                    else
                                       Entries.Append
                                         (Version.Staging.Index_Entry'
                                            (Path  =>
                                               To_Unbounded_String
                                                 (Prefix & Simple),
                                             Id    =>
                                               Version.Write.Write_Blob
                                                 (Repo,
                                                  Version.Files
                                                    .Read_Binary_File (Full)),
                                             Mode  =>
                                               To_Unbounded_String
                                                 (if GNAT.OS_Lib
                                                       .Is_Executable_File
                                                         (Version.Files
                                                            .To_Native_Path
                                                              (Full))
                                                  then "100755"
                                                  else "100644"),
                                             Stage => 0,
                                             Skip_Worktree => False));
                                    end if;
                                 end if;
                              end;
                           end loop;

                           Ada.Directories.End_Search (Search);
                        end Collect;
                     begin
                        if Ada.Directories.Exists (Work_Dir) then
                           Ada.Directories.Delete_Tree (Work_Dir);
                        end if;

                        Version.Files.Create_Directory_If_Missing (Work_Dir);

                        for E of Version.Objects.Flatten_Tree (Repo, New_Tree)
                        loop
                           if E.Kind = Version.Objects.Tree_Blob then
                              declare
                                 Target : constant String :=
                                   Version.Files.Join
                                     (Work_Dir, To_String (E.Path));
                              begin
                                 Version.Files.Create_Directory_If_Missing
                                   (Ada.Directories.Containing_Directory
                                      (Target));
                                 Version.Files.Write_Binary_File
                                   (Target,
                                    Version.Objects.Content
                                      (Version.Objects.Read_Object
                                         (Repo, E.Id)));

                                 if To_String (E.Mode) = "100755" then
                                    Version.Files.Set_Executable
                                      (Target, True);
                                 end if;
                              end;
                           end if;
                        end loop;

                        Status := Run (To_String (Tree_Filter));

                        if Status /= 0 then
                           Error_Line
                             ("tree filter failed: " & To_String (Tree_Filter));
                           Set_Command_Failure;
                           return;
                        end if;

                        Collect (Work_Dir, "");
                        New_Tree :=
                          Version.Write.Write_Tree_From_Index (Repo, Entries);
                     end;
                  end if;

                  --  `--msg-filter`: the message goes through the command.
                  if Msg_Filter /= "" then
                     declare
                        In_Path  : constant String :=
                          Version.Files.Join (Git_Dir, "filter-branch-msg");
                        Out_Path : constant String :=
                          Version.Files.Join (Git_Dir, "filter-branch-msg2");
                        Status   : Integer;
                     begin
                        Version.Files.Write_Binary_File
                          (In_Path, To_String (Message));

                        Status :=
                          Run (To_String (Msg_Filter) & " < " & In_Path
                               & " > " & Out_Path);

                        if Status = 0 then
                           Message :=
                             To_Unbounded_String
                               (Version.Files.Read_Binary_File (Out_Path));
                        end if;

                        if Ada.Directories.Exists (In_Path) then
                           Ada.Directories.Delete_File (In_Path);
                        end if;

                        if Ada.Directories.Exists (Out_Path) then
                           Ada.Directories.Delete_File (Out_Path);
                        end if;
                     end;
                  end if;

                  declare
                     Parents : Version.Objects.Object_Id_Vectors.Vector;
                     Empty   : Boolean := False;
                  begin
                     for P of Version.History.Parent_Commits (Repo, Id) loop
                        declare
                           Hex : constant String :=
                             Version.Objects.To_String (P);
                        begin
                           if Map.Contains (Hex) then
                              Parents.Append
                                (Version.Objects.To_Object_Id
                                   (Map.Element (Hex)));
                           end if;
                        end;
                     end loop;

                     --  `--prune-empty` drops a commit that changed nothing.
                     if Prune_Empty and then Natural (Parents.Length) = 1 then
                        declare
                           Parent_Tree :
                             constant Version.Objects.Hex_Object_Id :=
                               Version.Objects.Commit_Tree_Id
                                 (Version.Objects.Read_Object
                                    (Repo, Parents.First_Element));
                        begin
                           if Version.Objects.To_String (Parent_Tree)
                              = Version.Objects.To_String (New_Tree)
                           then
                              Map.Include
                                (C,
                                 Version.Objects.To_String
                                   (Parents.First_Element));
                              Empty := True;
                           end if;
                        end;
                     end if;

                     if not Empty then
                        declare
                           Body_Text : constant String := To_String (Message);
                           Chomped   : constant String :=
                             (if Body_Text'Length > 0
                                and then Body_Text (Body_Text'Last) = ASCII.LF
                              then Body_Text
                                     (Body_Text'First .. Body_Text'Last - 1)
                              else Body_Text);

                           New_Commit : constant
                             Version.Objects.Hex_Object_Id :=
                               Version.Write.Write_Commit_Raw
                                 (Repo, New_Tree, Parents,
                                  To_String (Author), To_String (Committer),
                                  Chomped);
                        begin
                           Map.Include
                             (C, Version.Objects.To_String (New_Commit));
                        end;
                     end if;
                  end;
               end;

               <<Next_Commit>>
               null;
            end loop;

            --  Keep the old tip, then move the ref.
            if Map.Contains (Version.Objects.To_String (Tip)) then
               Write_Ref_To (Repo, Backup, Tip);
               Write_Ref_To
                 (Repo, Ref_Name,
                  Version.Objects.To_Object_Id
                    (Map.Element (Version.Objects.To_String (Tip))));

               Stderr_Line ("Ref '" & Ref_Name & "' was rewritten");
            end if;
         end;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Filter_Branch_Command;

   --  `repo info [--all|-z|<key>...]` and `repo structure` -- what the
   --  repository is made of.  (git calls this command experimental.)
   procedure Run_Repo_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Sub : constant String := (if Count >= 2 then Arg (2) else "");

      --  A bare repository has no working tree: its git dir is the root.
      function Bare_Value return String is
        (if Version.Config.Has_Key (Repo, "core.bare")
           and then Version.Config.Get_Value (Repo, "core.bare") = "true"
         then "true" else "false");

      function Shallow_Value return String is
        (if Ada.Directories.Exists
              (Version.Files.Join
                 (Version.Repository.Common_Git_Dir (Repo), "shallow"))
         then "true" else "false");

      function Format_Value return String is
        (case Version.Repository.Algorithm (Repo) is
           when Version.Hash.Sha1   => "sha1",
           when Version.Hash.Sha256 => "sha256");

      function Value_Of (Key : String) return String is
        (if Key = "layout.bare" then Bare_Value
         elsif Key = "layout.shallow" then Shallow_Value
         elsif Key = "object.format" then Format_Value
         elsif Key = "references.format" then "files"
         else "");

      All_Keys : constant array (1 .. 4) of access constant String :=
        [new String'("layout.bare"),
         new String'("layout.shallow"),
         new String'("object.format"),
         new String'("references.format")];
   begin
      if Sub = "info" then
         declare
            Use_NUL : Boolean := False;
            Want    : Version.Trailers.String_Vectors.Vector;
            Show_All : Boolean := False;
         begin
            for I in 3 .. Count loop
               declare
                  A : constant String := Arg (I);
               begin
                  if A = "--all" then
                     Show_All := True;
                  elsif A = "-z" or else A = "--format=nul" then
                     Use_NUL := True;
                  elsif A = "--format=lines" then
                     Use_NUL := False;
                  elsif A'Length > 0 and then A (A'First) /= '-' then
                     Want.Append (A);
                  end if;
               end;
            end loop;

            if Show_All then
               Want.Clear;

               for K of All_Keys loop
                  Want.Append (K.all);
               end loop;
            end if;

            for Key of Want loop
               declare
                  Value : constant String := Value_Of (Key);
               begin
                  if Value = "" then
                     Error_Line ("key '" & Key & "' not found");
                     Set_Command_Failure;
                     return;
                  end if;

                  --  With -z, key and value are separated by a newline and
                  --  the record by a NUL.
                  if Use_NUL then
                     Version.Console.Put
                       (Key & ASCII.LF & Value & ASCII.NUL);
                  else
                     Success_Line (Key & "=" & Value);
                  end if;
               end;
            end loop;
         end;

      elsif Sub = "structure" then
         --  The table git prints; version reports the same counts.
         declare
            Branches : constant Natural :=
              Natural (Version.Refs.List_Branches (Repo).Length);
            Tags     : constant Natural :=
              Natural (Version.Tags.List_Tags.Length);
            Remotes  : constant Natural :=
              Natural (Version.Remotes.List_Remotes.Length);

            function Cell (Text : String; Width : Positive) return String is
               Pad : constant Integer := Width - Text'Length;
               Left : constant Natural := Natural'Max (0, Pad / 2);
               Right : constant Natural := Natural'Max (0, Pad - Left);
            begin
               return [1 .. Left => ' '] & Text & [1 .. Right => ' '];
            end Cell;

            function Row (Label : String; Value : String) return String is
              ("| " & Label & [1 .. Natural'Max (0, 25 - Label'Length) => ' ']
               & " |" & Cell (Value, 7) & "|");

            function Img (V : Natural) return String is
              (Ada.Strings.Fixed.Trim (Natural'Image (V), Ada.Strings.Both));
         begin
            Success_Line ("| Repository structure      | Value |");
            Success_Line ("| ------------------------- | ----- |");
            Success_Line (Row ("* References", ""));
            Success_Line (Row ("  * Count", Img (Branches + Tags)));
            Success_Line (Row ("    * Branches", Img (Branches)));
            Success_Line (Row ("    * Tags", Img (Tags)));
            Success_Line (Row ("    * Remotes", Img (Remotes)));
            Success_Line (Row ("    * Others", "0"));
         end;

      else
         Error_Line ("usage: version repo (info|structure)");
         Set_Usage_Failure;
      end if;
   end Run_Repo_Command;

   --  `http-fetch [-a] [-v] [-w <name>] <commit> <url>` -- the dumb protocol:
   --  walk everything reachable from <commit> over ordinary GETs.
   procedure Run_Http_Fetch_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Verbose : Boolean := False;
      Write_To : Unbounded_String;
      Operands : Version.Trailers.String_Vectors.Vector;

      I : Positive := 2;
   begin
      while I <= Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "-v" then
               Verbose := True;
            elsif A = "-w" and then I < Count then
               Write_To := To_Unbounded_String (Arg (I + 1));
               I := I + 1;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;   --  -a, -c, -t, --recover: accepted
            else
               Operands.Append (A);
            end if;
         end;

         I := I + 1;
      end loop;

      if Natural (Operands.Length) /= 2 then
         Error_Line ("usage: version http-fetch [-a] [-w <name>] <commit> <url>");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Commit : constant Version.Objects.Hex_Object_Id :=
           Version.Objects.To_Object_Id (Operands.Element (1));
      begin
         Version.Dumb_Http.Fetch
           (Repo      => Repo,
            Base_Url  => Operands.Element (2),
            Commit_Id => Commit,
            Verbose   => Verbose);

         --  `-w <name>` writes the id into $GIT_DIR/refs/<name>, exactly as
         --  git does -- name and all, so "heads/main" is the usual spelling.
         if Write_To /= "" then
            declare
               Path : constant String :=
                 Version.Files.Join
                   (Version.Files.Join
                      (Version.Repository.Common_Git_Dir (Repo), "refs"),
                    To_String (Write_To));
            begin
               Version.Files.Create_Directory_If_Missing
                 (Ada.Directories.Containing_Directory (Path));
               Version.Files.Write_Binary_File
                 (Path,
                  Version.Objects.To_String (Commit) & ASCII.LF);
            end;
         end if;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Http_Fetch_Command;

   --  `multi-pack-index write|verify`
   procedure Run_Multi_Pack_Index_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Sub : Unbounded_String;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A'Length > 0 and then A (A'First) /= '-' then
               Sub := To_Unbounded_String (A);
            end if;
         end;
      end loop;

      if Sub = "write" then
         Version.Multi_Pack_Index.Write (Repo);

      elsif Sub = "verify" then
         declare
            Diagnostic : String (1 .. 200);
            Last       : Natural;
         begin
            if not Version.Multi_Pack_Index.Verify (Repo, Diagnostic, Last)
            then
               Error_Line (Diagnostic (1 .. Last));
               Set_Command_Failure;
            end if;
         end;

      else
         Error_Line ("usage: version multi-pack-index (write|verify)");
         Set_Usage_Failure;
      end if;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Multi_Pack_Index_Command;

   --  `commit-graph write [--reachable] | verify`
   procedure Run_Commit_Graph_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Sub : constant String := (if Count >= 2 then Arg (2) else "");
   begin
      if Sub = "write" then
         Version.Commit_Graph.Write (Repo);

      elsif Sub = "verify" then
         declare
            Diagnostic : String (1 .. 200);
            Last       : Natural;
         begin
            if not Version.Commit_Graph.Verify (Repo, Diagnostic, Last) then
               Error_Line (Diagnostic (1 .. Last));
               Set_Command_Failure;
            end if;
         end;

      else
         Error_Line ("usage: version commit-graph (write|verify)");
         Set_Usage_Failure;
      end if;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Commit_Graph_Command;

   --  `backfill [--min-batch-size=<n>]` -- download the blobs a partial clone
   --  left behind, so the repository is complete again.
   procedure Run_Backfill_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      --  The remote that promised the missing objects.
      function Promisor_Remote return String is
      begin
         for Item of Version.Config.Read_All (Repo) loop
            declare
               Section : constant String := To_String (Item.Section);
            begin
               if To_String (Item.Key) = "promisor"
                 and then To_String (Item.Value) = "true"
                 and then Section'Length > 9
                 and then Section (Section'First .. Section'First + 7)
                          = "remote """
               then
                  return Section (Section'First + 8 .. Section'Last - 1);
               end if;
            end;
         end loop;

         return "";
      end Promisor_Remote;

      Remote : constant String := Promisor_Remote;
   begin
      if Remote = "" then
         --  Nothing was promised: nothing to backfill.
         return;
      end if;

      declare
         Wanted : Version.Trailers.String_Vectors.Vector;

         procedure Note (Id : Version.Objects.Hex_Object_Id) is
            Hex : constant String := Version.Objects.To_String (Id);
         begin
            if not Wanted.Contains (Hex) then
               Wanted.Append (Hex);
            end if;
         end Note;

         Names : Version.Trailers.String_Vectors.Vector;
      begin
         for B of Version.Refs.List_Branches (Repo) loop
            Names.Append ("refs/heads/" & To_String (B));
         end loop;

         for T of Version.Tags.List_Tags loop
            Names.Append ("refs/tags/" & To_String (T));
         end loop;

         --  Every blob every reachable tree names.
         for Name of Names loop
            declare
               Tip : constant Version.Objects.Hex_Object_Id :=
                 Version.Revisions.Resolve_Commit (Repo, Name);

               Pending : Version.Trailers.String_Vectors.Vector;
               Seen    : Version.Trailers.String_Vectors.Vector;
            begin
               Pending.Append (Version.Objects.To_String (Tip));

               while not Pending.Is_Empty loop
                  declare
                     C : constant String := Pending.Last_Element;
                  begin
                     Pending.Delete_Last;

                     if not Seen.Contains (C) then
                        Seen.Append (C);

                        declare
                           Id : constant Version.Objects.Hex_Object_Id :=
                             Version.Objects.To_Object_Id (C);
                        begin
                           for E of Version.Objects.Flatten_Tree
                                      (Repo,
                                       Version.Objects.Commit_Tree_Id
                                         (Version.Objects.Read_Object
                                            (Repo, Id)))
                           loop
                              if E.Kind = Version.Objects.Tree_Blob then
                                 Note (E.Id);
                              end if;
                           end loop;

                           for P of Version.History.Parent_Commits (Repo, Id)
                           loop
                              Pending.Append (Version.Objects.To_String (P));
                           end loop;
                        end;
                     end if;
                  end;
               end loop;
            end;
         end loop;

         for Hex of Wanted loop
            declare
               Id : constant Version.Objects.Hex_Object_Id :=
                 Version.Objects.To_Object_Id (Hex);

               Have : Boolean := True;
            begin
               declare
                  Obj : constant Version.Objects.Git_Object :=
                    Version.Objects.Read_Object (Repo, Id);
                  pragma Unreferenced (Obj);
               begin
                  null;
               exception
                  when others =>
                     Have := False;
               end;

               if not Have then
                  Version.Fetch.Fetch_Object (Repo, Remote, Id);
               end if;
            end;
         end loop;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Backfill_Command;

   --  `last-modified [<rev>] [-- <path>...]` -- for every path in the tree, the
   --  last commit that changed it, as "<oid> TAB <path>".
   procedure Run_Last_Modified_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Rev   : Unbounded_String := To_Unbounded_String ("HEAD");
      Paths : Version.Trailers.String_Vectors.Vector;
      Seen_Sep : Boolean := False;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--" then
               Seen_Sep := True;
            elsif Seen_Sep then
               Paths.Append (A);
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            else
               Rev := To_Unbounded_String (A);
            end if;
         end;
      end loop;

      declare
         Tip : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, To_String (Rev));

         --  git reports one line per entry of the tree -- a directory counts
         --  as one entry, not as its contents.
         function Items (Commit : Version.Objects.Hex_Object_Id)
           return Version.Objects.Tree_Entry_Vectors.Vector
         is (Version.Objects.Tree_Entries
               (Repo,
                Version.Objects.Commit_Tree_Id
                  (Version.Objects.Read_Object (Repo, Commit))));

         --  Walk the history newest first, reporting each path the moment the
         --  commit that last touched it turns up -- which is the order git
         --  prints them in.
         Pending : Version.Objects.Tree_Entry_Vectors.Vector;
         Current : Version.Objects.Hex_Object_Id := Tip;
      begin
         for E of Items (Tip) loop
            declare
               Path : constant String := To_String (E.Path);
               Take : Boolean := Paths.Is_Empty;
            begin
               for P of Paths loop
                  if Path = P then
                     Take := True;
                  end if;
               end loop;

               if Take then
                  Pending.Append (E);
               end if;
            end;
         end loop;

         loop
            exit when Pending.Is_Empty;

            declare
               Parents : constant Version.History.Commit_Id_Vectors.Vector :=
                 Version.History.Parent_Commits (Repo, Current);

               Parent_Items :
                 constant Version.Objects.Tree_Entry_Vectors.Vector :=
                   (if Parents.Is_Empty
                    then Version.Objects.Tree_Entry_Vectors.Empty_Vector
                    else Items (Parents.First_Element));

               Kept : Version.Objects.Tree_Entry_Vectors.Vector;
            begin
               --  In reverse: git emits a commit's paths back to front.
               for I in reverse Pending.First_Index .. Pending.Last_Index loop
                  declare
                     E    : constant Version.Objects.Tree_Entry :=
                       Pending.Element (I);
                     Path : constant String := To_String (E.Path);
                     Same : Boolean := False;
                  begin
                     for P of Parent_Items loop
                        if To_String (P.Path) = Path
                          and then Version.Objects.To_String (P.Id)
                                   = Version.Objects.To_String (E.Id)
                        then
                           Same := True;
                        end if;
                     end loop;

                     if Same then
                        Kept.Append (E);
                     else
                        Success_Line
                          (Version.Objects.To_String (Current) & ASCII.HT
                           & Path);
                     end if;
                  end;
               end loop;

               exit when Parents.Is_Empty;

               --  Kept came out reversed; put it back the way it was.
               Pending.Clear;

               for I in reverse Kept.First_Index .. Kept.Last_Index loop
                  Pending.Append (Kept.Element (I));
               end loop;

               Current := Parents.First_Element;
            end;
         end loop;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Last_Modified_Command;

   --  `refs list|verify|migrate` -- the ref store.
   procedure Run_Refs_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Sub : constant String := (if Count >= 2 then Arg (2) else "");
   begin
      if Sub = "list" then
         declare
            Names : Version.Trailers.String_Vectors.Vector;
         begin
            for B of Version.Refs.List_Branches (Repo) loop
               Names.Append ("refs/heads/" & To_String (B));
            end loop;

            for T of Version.Tags.List_Tags loop
               Names.Append ("refs/tags/" & To_String (T));
            end loop;

            for Name of Names loop
               declare
                  Id : constant Version.Objects.Hex_Object_Id :=
                    Version.Refs.Resolve_Ref (Repo, Name);

                  Kind : constant String :=
                    (case Version.Objects.Kind
                            (Version.Objects.Read_Object (Repo, Id)) is
                       when Version.Objects.Commit_Object => "commit",
                       when Version.Objects.Tag_Object    => "tag",
                       when Version.Objects.Tree_Object   => "tree",
                       when Version.Objects.Blob_Object   => "blob",
                       when others                        => "unknown");
               begin
                  Success_Line
                    (Version.Objects.To_String (Id) & " " & Kind & ASCII.HT
                     & Name);
               end;
            end loop;
         end;

      elsif Sub = "verify" then
         --  Every ref must name an object that is actually there.
         declare
            Bad : Boolean := False;
         begin
            for B of Version.Refs.List_Branches (Repo) loop
               declare
                  Name : constant String := "refs/heads/" & To_String (B);
               begin
                  declare
                     Id : constant Version.Objects.Hex_Object_Id :=
                       Version.Refs.Resolve_Ref (Repo, Name);
                     Obj : constant Version.Objects.Git_Object :=
                       Version.Objects.Read_Object (Repo, Id);
                     pragma Unreferenced (Obj);
                  begin
                     null;
                  end;
               exception
                  when others =>
                     Error_Line (Name & ": unable to resolve");
                     Bad := True;
               end;
            end loop;

            if Bad then
               Set_Command_Failure;
            end if;
         end;

      elsif Sub = "migrate" then
         --  version stores refs as loose files plus packed-refs; there is no
         --  other backend to migrate to.
         Error_Line ("refs migrate: only the files backend is supported");
         Set_Command_Failure;

      else
         Error_Line ("usage: version refs (list|verify|migrate)");
         Set_Usage_Failure;
      end if;
   end Run_Refs_Command;

   --  `diff-pairs -z` -- raw diff records on stdin, patches out.
   procedure Run_Diff_Pairs_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Use_NUL : Boolean := False;
   begin
      for I in 2 .. Count loop
         if Arg (I) = "-z" then
            Use_NUL := True;
         end if;
      end loop;

      if not Use_NUL then
         Error_Line ("working without -z is not supported");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Text : constant String := Read_All_Stdin;
         Pos  : Natural := Text'First;

         function Next_Field return String is
            Stop : constant Natural :=
              Ada.Strings.Fixed.Index (Text, "" & ASCII.NUL, Pos);
            Item : constant String :=
              Text (Pos .. (if Stop = 0 then Text'Last else Stop - 1));
         begin
            Pos := (if Stop = 0 then Text'Last + 1 else Stop + 1);
            return Item;
         end Next_Field;

         Opts : Version.Diff.Diff_Options;
      begin
         Opts.Context_Lines := 3;

         --  Each record is ":<m1> <m2> <s1> <s2> <status>" NUL "<path>" [NUL
         --  "<path2>" for a rename or copy].
         while Pos <= Text'Last loop
            declare
               Head : constant String := Next_Field;
            begin
               exit when Head'Length = 0;

               if Head (Head'First) = ':' then
                  declare
                     Fields : constant String :=
                       Head (Head'First + 1 .. Head'Last);

                     function Field (N : Positive) return String is
                        Start : Natural := Fields'First;
                        Stop  : Natural;
                     begin
                        for K in 1 .. N - 1 loop
                           Start := Ada.Strings.Fixed.Index
                                      (Fields, " ", Start) + 1;
                        end loop;

                        Stop := Ada.Strings.Fixed.Index (Fields, " ", Start);

                        return Fields (Start ..
                                       (if Stop = 0 then Fields'Last
                                        else Stop - 1));
                     end Field;

                     Old_Mode : constant String := Field (1);
                     New_Mode : constant String := Field (2);
                     Old_Id   : constant String := Field (3);
                     New_Id   : constant String := Field (4);
                     Status   : constant String := Field (5);

                     Path : constant String := Next_Field;

                     Path2 : constant String :=
                       (if Status'Length > 0
                          and then Status (Status'First) in 'R' | 'C'
                        then Next_Field else "");

                     Zero : constant String := [1 .. 40 => '0'];

                     function Blob_Text (Id : String) return String is
                       (if Id = Zero then ""
                        else Version.Objects.Content
                               (Version.Objects.Read_Object
                                  (Repo, Version.Objects.To_Object_Id (Id))));
                  begin
                     Version.Console.Put
                       (Version.Diff.Unified_Blob_Diff
                          (Path        => (if Path2 = "" then Path else Path2),
                           Old_Text    => Blob_Text (Old_Id),
                           New_Text    => Blob_Text (New_Id),
                           Old_Present => Old_Id /= Zero,
                           New_Present => New_Id /= Zero,
                           Old_Id      =>
                             Version.Objects.To_Object_Id (Old_Id),
                           New_Id      =>
                             Version.Objects.To_Object_Id (New_Id),
                           Old_Mode    => Old_Mode,
                           New_Mode    => New_Mode,
                           Context     => 3));
                  end;
               end if;
            end;
         end loop;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Diff_Pairs_Command;

   --  `fetch-pack [--all] <repository> [<ref>...]` -- fetch the objects the
   --  named refs need, without touching any local ref, and print what came
   --  back as "<oid> <ref>".
   procedure Run_Fetch_Pack_Command is
      All_Refs : Boolean := False;
      Source   : Unbounded_String;
      Wanted   : Version.Trailers.String_Vectors.Vector;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--all" then
               All_Refs := True;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            elsif Source = "" then
               Source := To_Unbounded_String (A);
            else
               Wanted.Append (A);
            end if;
         end;
      end loop;

      if Source = "" then
         Error_Line ("fetch-pack needs a repository");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Available : constant
           Version.Upload_Pack.Advertised_Ref_Vectors.Vector :=
             Version.Fetch.List_Remote_Refs (To_String (Source));

         Matched : Boolean := False;
      begin
         --  Reject an unknown ref before fetching anything, as git does.
         if not All_Refs then
            for W of Wanted loop
               declare
                  Found : Boolean := False;
               begin
                  for R of Available loop
                     if To_String (R.Name) = W
                       or else To_String (R.Name) = "refs/heads/" & W
                     then
                        Found := True;
                     end if;
                  end loop;

                  if not Found then
                     Error_Line ("no such remote ref " & W);
                     Set_Command_Failure;
                     return;
                  end if;
               end;
            end loop;
         end if;

         Version.Fetch.Fetch_Objects_From (To_String (Source));

         for R of Available loop
            declare
               Name : constant String := To_String (R.Name);
               Take : Boolean := All_Refs;
            begin
               if not Take then
                  for W of Wanted loop
                     if Name = W or else Name = "refs/heads/" & W then
                        Take := True;
                     end if;
                  end loop;
               end if;

               if Take
                 and then not (Name'Length > 3
                               and then Name (Name'Last - 2 .. Name'Last)
                                        = "^{}")
                 and then Name /= "HEAD"
               then
                  Success_Line
                    (Version.Objects.To_String (R.Id) & " " & Name);
                  Matched := True;
               end if;
            end;
         end loop;

         if not Matched and then not All_Refs then
            Set_Command_Failure;
         end if;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Fetch_Pack_Command;

   --  `mailsplit [-o<dir>] [-b] [<mbox>...]` -- one file per message, numbered
   --  from 1; the count goes to stdout.
   procedure Run_Mailsplit_Command is
      Out_Dir    : Unbounded_String := To_Unbounded_String (".");
      Inputs     : Version.Trailers.String_Vectors.Vector;
      Text       : Unbounded_String;
      Written    : Natural := 0;
      Keep_CR    : Boolean := False;
      Allow_Bare : Boolean := False;
      Failed     : Boolean := False;

      --  git's is_from_line: "From <who> <hh:mm:ss> <year>", loosely checked.
      function Is_From_Line (Line : String) return Boolean is
         Colon : Integer;
      begin
         if Line'Length < 20
           or else Line (Line'First .. Line'First + 4) /= "From "
         then
            return False;
         end if;

         --  Scan back from the line's end for the time's ':'.
         Colon := Line'Last - 1;
         loop
            if Colon < Line'First + 5 then
               return False;
            end if;
            Colon := Colon - 1;
            exit when Line (Colon) = ':';
         end loop;

         if Colon - 4 < Line'First or else Colon + 2 > Line'Last then
            return False;
         end if;
         if Line (Colon - 4) not in '0' .. '9'
           or else Line (Colon - 2) not in '0' .. '9'
           or else Line (Colon - 1) not in '0' .. '9'
           or else Line (Colon + 1) not in '0' .. '9'
           or else Line (Colon + 2) not in '0' .. '9'
         then
            return False;
         end if;

         --  Year must look later than 1990.
         declare
            Rest : constant String := Line (Colon + 3 .. Line'Last);
            Year : Natural := 0;
            K    : Natural := Rest'First;
         begin
            while K <= Rest'Last and then Rest (K) = ' ' loop
               K := K + 1;
            end loop;
            while K <= Rest'Last and then Rest (K) in '0' .. '9' loop
               Year := Year * 10 + (Character'Pos (Rest (K))
                                    - Character'Pos ('0'));
               K := K + 1;
            end loop;
            return Year > 90;
         end;
      end Is_From_Line;

      --  git rewrites every CRLF line ending as LF unless --keep-cr.
      function Strip_CR (Mail : String) return String is
         Result : Unbounded_String;
         I      : Natural := Mail'First;
      begin
         if Keep_CR then
            return Mail;
         end if;
         while I <= Mail'Last loop
            if Mail (I) = ASCII.CR
              and then I < Mail'Last
              and then Mail (I + 1) = ASCII.LF
            then
               Append (Result, ASCII.LF);
               I := I + 2;
            else
               Append (Result, Mail (I));
               I := I + 1;
            end if;
         end loop;
         return To_String (Result);
      end Strip_CR;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A'Length > 2 and then A (A'First .. A'First + 1) = "-o" then
               Out_Dir := To_Unbounded_String (A (A'First + 2 .. A'Last));
            elsif A = "--keep-cr" then
               Keep_CR := True;
            elsif A = "-b" then
               Allow_Bare := True;
            elsif A = "-f" or else A = "-d" then
               null;
            elsif A'Length > 0 and then A (A'First) = '-' then
               null;
            else
               Inputs.Append (A);
            end if;
         end;
      end loop;

      Version.Files.Create_Directory_If_Missing (To_String (Out_Dir));

      declare
         --  Write one message, numbered from 1 across every input.
         procedure Emit (Mail : String) is
            N    : constant String :=
              Ada.Strings.Fixed.Trim (Natural'Image (Written + 1),
                                      Ada.Strings.Both);
            Name : constant String :=
              [1 .. 4 - N'Length => '0'] & N;
         begin
            Written := Written + 1;
            Version.Files.Write_Binary_File
              (Version.Files.Join (To_String (Out_Dir), Name),
               Strip_CR (Mail));
         end Emit;

         --  git's maildir_filename_cmp: runs of digits compare numerically,
         --  so "2" sorts before "10".
         function Maildir_Less (Left, Right : String) return Boolean is
            I : Natural := Left'First;
            J : Natural := Right'First;
         begin
            while I <= Left'Last and then J <= Right'Last loop
               if Left (I) in '0' .. '9' and then Right (J) in '0' .. '9' then
                  declare
                     IS_E : Natural := I;
                     JS_E : Natural := J;
                     LV, RV : Natural := 0;
                  begin
                     while IS_E <= Left'Last
                       and then Left (IS_E) in '0' .. '9'
                     loop
                        IS_E := IS_E + 1;
                     end loop;
                     while JS_E <= Right'Last
                       and then Right (JS_E) in '0' .. '9'
                     loop
                        JS_E := JS_E + 1;
                     end loop;
                     --  Oversized runs cannot be compared as numbers; fall
                     --  back to the textual order for them.
                     if IS_E - I <= 9 and then JS_E - J <= 9 then
                        LV := Natural'Value (Left (I .. IS_E - 1));
                        RV := Natural'Value (Right (J .. JS_E - 1));
                        if LV /= RV then
                           return LV < RV;
                        end if;
                     elsif Left (I .. IS_E - 1) /= Right (J .. JS_E - 1) then
                        return Left (I .. IS_E - 1) < Right (J .. JS_E - 1);
                     end if;
                     I := IS_E;
                     J := JS_E;
                  end;
               else
                  if Left (I) /= Right (J) then
                     return Left (I) < Right (J);
                  end if;
                  I := I + 1;
                  J := J + 1;
               end if;
            end loop;

            return Left'Last - I < Right'Last - J;
         end Maildir_Less;

         --  git treats a directory operand as a Maildir: every file under
         --  cur/ then new/ is one message, dotfiles skipped.
         --  git scans cur/ then new/.
         Sub_Names : constant array (1 .. 2) of Unbounded_String :=
           [To_Unbounded_String ("cur"), To_Unbounded_String ("new")];

         procedure Split_Maildir (Root : String) is
            package Sorting is new
              Version.Trailers.String_Vectors.Generic_Sorting
                ("<" => Maildir_Less);
            Names : Version.Trailers.String_Vectors.Vector;
         begin
            for Sub of Sub_Names loop
               declare
                  Dir : constant String :=
                    Version.Files.Join (Root, To_String (Sub));
               begin
                  if Ada.Directories.Exists (Dir) then
                     declare
                        Search : Ada.Directories.Search_Type;
                        Item   : Ada.Directories.Directory_Entry_Type;
                     begin
                        Ada.Directories.Start_Search
                          (Search, Dir, "",
                           [Ada.Directories.Ordinary_File => True,
                            others => False]);
                        while Ada.Directories.More_Entries (Search) loop
                           Ada.Directories.Get_Next_Entry (Search, Item);
                           declare
                              Base : constant String :=
                                Ada.Directories.Simple_Name (Item);
                           begin
                              if Base'Length > 0
                                and then Base (Base'First) /= '.'
                              then
                                 Names.Append
                                   (To_String (Sub) & "/" & Base);
                              end if;
                           end;
                        end loop;
                        Ada.Directories.End_Search (Search);
                     end;
                  end if;
               end;
            end loop;

            Sorting.Sort (Names);

            for N of Names loop
               Emit (Version.Files.Read_Binary_File
                       (Version.Files.Join (Root, N)));
            end loop;
         end Split_Maildir;
      begin
         if Inputs.Is_Empty then
            Text := To_Unbounded_String (Read_All_Stdin);
            for Mail of Version.Mailbox.Split (To_String (Text)) loop
               Emit (Mail);
            end loop;
         else
            for Path of Inputs loop
               exit when Failed;
               if Ada.Directories.Exists (Path)
                 and then Ada.Directories.Kind (Path)
                          = Ada.Directories.Directory
               then
                  Split_Maildir (Path);
               else
                  declare
                     Body_Text : constant String :=
                       Version.Files.Read_Binary_File (Path);
                     Mails : constant Version.Mailbox.Text_Vectors.Vector :=
                       Version.Mailbox.Split (Body_Text);
                     First_Line_End : Natural := Body_Text'Last;
                  begin
                     if Body_Text'Length = 0 then
                        --  git refuses an empty mailbox outright.
                        Error_Line ("empty mbox: '" & Path & "'");
                        Error_Line ("cannot split patches from " & Path);
                        Set_Command_Failure;
                        Failed := True;
                     else
                        for K in Body_Text'Range loop
                           if Body_Text (K) = ASCII.LF then
                              First_Line_End := K;
                              exit;
                           end if;
                        end loop;

                        if not Allow_Bare
                          and then not Is_From_Line
                                         (Body_Text (Body_Text'First
                                                     .. First_Line_End))
                        then
                           --  git's split_one: a mailbox whose first line is
                           --  not a "From " line, without -b.
                           Stderr_Line ("corrupt mailbox");
                           Set_Command_Failure;
                           Failed := True;
                        else
                           for Mail of Mails loop
                              Emit (Mail);
                           end loop;
                        end if;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end;

      if not Failed then
         Success_Line
           (Ada.Strings.Fixed.Trim (Natural'Image (Written),
                                    Ada.Strings.Both));
      end if;
   exception
      when E : Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Mailsplit_Command;

   --  `mailinfo <msg> <patch>` -- a mail on stdin; its authorship goes to
   --  stdout, its commit message to <msg>, and the patch to <patch>.
   procedure Run_Mailinfo_Command is
      Files : Version.Trailers.String_Vectors.Vector;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A'Length > 0 and then A (A'First) = '-' then
               null;   --  -k, -u, --encoding=..., --scissors: accepted
            else
               Files.Append (A);
            end if;
         end;
      end loop;

      if Natural (Files.Length) /= 2 then
         Error_Line ("usage: version mailinfo <msg> <patch> < mail");
         Set_Usage_Failure;
         return;
      end if;

      declare
         Mail : constant Version.Mailbox.Message :=
           Version.Mailbox.Parse (Read_All_Stdin);
      begin
         Success_Line ("Author: " & To_String (Mail.Author_Name));
         Success_Line ("Email: " & To_String (Mail.Author_Email));
         Success_Line ("Subject: " & To_String (Mail.Subject));
         Success_Line ("Date: " & To_String (Mail.Date));
         Success_Line ("");

         --  Verbatim: the body already carries its own newlines.
         Version.Files.Write_Binary_File
           (Files.Element (1), To_String (Mail.Body_Text));
         Version.Files.Write_Binary_File
           (Files.Element (2), To_String (Mail.Patch));
      end;
   exception
      when E : Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Mailinfo_Command;

   --  The merge-strategy backends git keeps as separate commands:
   --    merge-<strategy> <base>... -- <head> <remote>...
   --  They merge into the index and working tree and do *not* commit; git's
   --  `merge -s <strategy>` drives them.  version implements the strategies
   --  natively, so these are the same machinery under git's plumbing names.
   type Strategy_Backend is
     (Backend_Ours,
      Backend_Recursive,
      Backend_Recursive_Ours,
      Backend_Recursive_Theirs,
      Backend_Subtree,
      Backend_Resolve,
      Backend_Octopus);

   procedure Run_Merge_Backend (Backend : Strategy_Backend) is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Bases   : Version.Trailers.String_Vectors.Vector;
      Head    : Unbounded_String;
      Remotes : Version.Trailers.String_Vectors.Vector;
      Sep     : Boolean := False;

      function Tree_Of (Commit : Version.Objects.Hex_Object_Id)
        return Version.Objects.Tree_Entry_Vectors.Vector
      is (Version.Objects.Flatten_Tree
            (Repo,
             Version.Objects.Commit_Tree_Id
               (Version.Objects.Read_Object (Repo, Commit))));
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--" then
               Sep := True;
            elsif not Sep then
               Bases.Append (A);
            elsif Head = "" then
               Head := To_Unbounded_String (A);
            else
               Remotes.Append (A);
            end if;
         end;
      end loop;

      --  `merge-ours` keeps our tree whatever the other side did.
      if Backend = Backend_Ours then
         return;
      end if;

      if Head = "" or else Remotes.Is_Empty then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
         return;
      end if;

      --  Only octopus takes more than one remote; only it rejects fewer.
      if Backend = Backend_Octopus then
         if Natural (Remotes.Length) < 2 then
            Ada.Command_Line.Set_Exit_Status
              (Ada.Command_Line.Exit_Status (2));
            return;
         end if;
      elsif Natural (Remotes.Length) > 1 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
         return;
      end if;

      if Bases.Is_Empty and then Backend = Backend_Resolve then
         --  A baseless merge is not resolve's business.
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
         return;
      end if;

      --  git-merge-resolve refuses to run when the index carries staged
      --  changes not in HEAD -- read-tree -u -m would overwrite them -- and
      --  aborts (exit 2) without touching anything. version used to merge
      --  regardless, silently discarding the staged change.
      if Backend = Backend_Resolve then
         declare
            St : constant Version.Status.Status_Result :=
              Version.Status.Current_Status;
            Paths : Version.Trailers.String_Vectors.Vector;

            package Path_Sort is new
              Version.Trailers.String_Vectors.Generic_Sorting;
         begin
            if not St.Staged.Is_Empty then
               for C of St.Staged loop
                  Paths.Append (To_String (C.Path));
               end loop;
               Path_Sort.Sort (Paths);

               Stderr_Line
                 ("Error: Your local changes to the following files"
                  & " would be overwritten by merge");
               for P of Paths loop
                  Stderr_Line ("    " & P);
               end loop;
               Ada.Command_Line.Set_Exit_Status
                 (Ada.Command_Line.Exit_Status (2));
               return;
            end if;
         end;
      end if;

      declare
         Head_Id : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, To_String (Head));

         Remote_Id : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, Remotes.First_Element);

         --  The recursive backends synthesize a virtual ancestor from several
         --  merge bases; resolve/octopus keep the single first base.
         Is_Recursive : constant Boolean :=
           Backend in Backend_Recursive | Backend_Recursive_Ours
                    | Backend_Recursive_Theirs | Backend_Subtree;

         --  Fold the given bases into one virtual ancestor as git's recursive
         --  strategy does: merge base[0] with base[1] using their own merge
         --  base, commit the result as a "virtual merge base", then repeat
         --  against base[2], base[3]... Using only the first base (the old
         --  behaviour) gives a wrong ancestor on a criss-cross history and can
         --  silently drop a committed change.
         function Virtual_Base_Id return Version.Objects.Hex_Object_Id is
            Accum_Id : Version.Objects.Hex_Object_Id :=
              Version.Revisions.Resolve_Commit (Repo, Bases.First_Element);
         begin
            for I in Bases.First_Index + 1 .. Bases.Last_Index loop
               declare
                  Next_Id : constant Version.Objects.Hex_Object_Id :=
                    Version.Revisions.Resolve_Commit (Repo, Bases.Element (I));
                  Pair_Base : constant Version.Objects.Hex_Object_Id :=
                    Version.History.Merge_Base (Repo, Accum_Id, Next_Id);
                  Pair_Items :
                    constant Version.Objects.Tree_Entry_Vectors.Vector :=
                      (if Version.Objects.Id_Length (Pair_Base) > 0
                       then Tree_Of (Pair_Base)
                       else Version.Objects.Tree_Entry_Vectors.Empty_Vector);
                  Accum_Items :
                    constant Version.Objects.Tree_Entry_Vectors.Vector :=
                      Tree_Of (Accum_Id);
                  Next_Items :
                    constant Version.Objects.Tree_Entry_Vectors.Vector :=
                      Tree_Of (Next_Id);
                  Merged    : Version.Staging.Index_Entry_Vectors.Vector;
                  Conflicts : Version.Merge.Conflict_Vectors.Vector;
                  Behavior  : Version.Merge.Merge_Behavior;
               begin
                  Behavior.Update_Worktree := False;
                  Behavior.Materialize_Virtual_Conflicts := True;
                  Behavior.Base_Label :=
                    To_Unbounded_String
                      (Version.Merge.Base_Label_For (Repo, Pair_Base));

                  Version.Merge.Merge_Trees
                    (Repo          => Repo,
                     Current_Name  => "Temporary merge branch 1",
                     Target_Name   => "Temporary merge branch 2",
                     Base_Items    => Pair_Items,
                     Current_Items => Accum_Items,
                     Target_Items  => Next_Items,
                     Merged_Index  => Merged,
                     Conflicts     => Conflicts,
                     Behavior      => Behavior);

                  declare
                     Tree_Id : constant Version.Objects.Hex_Object_Id :=
                       Version.Write.Write_Tree_From_Index (Repo, Merged);
                     Parents : Version.Objects.Object_Id_Vectors.Vector;
                  begin
                     Parents.Append (Accum_Id);
                     Parents.Append (Next_Id);
                     Accum_Id := Version.Write.Write_Commit_With_Parents
                       (Repo, Tree_Id, Parents, "virtual merge base");
                  end;
               end;
            end loop;
            return Accum_Id;
         end Virtual_Base_Id;

         Base_Id : constant Version.Objects.Hex_Object_Id :=
           (if Bases.Is_Empty
            then Version.History.Merge_Base (Repo, Head_Id, Remote_Id)
            elsif Natural (Bases.Length) > 1 and then Is_Recursive
            then Virtual_Base_Id
            else Version.Revisions.Resolve_Commit (Repo, Bases.First_Element));

         Raw_Base    : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           (if Version.Objects.Id_Length (Base_Id) > 0 then Tree_Of (Base_Id)
            else Version.Objects.Tree_Entry_Vectors.Empty_Vector);
         Ours_Items  : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           Tree_Of (Head_Id);
         Raw_Theirs  : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           Tree_Of (Remote_Id);

         --  `merge-subtree` is recursive with the other side's tree shifted
         --  under the prefix it lives at in ours.
         Base_Items   : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           (if Backend = Backend_Subtree
            then Version.Branch.Shift_Subtree_Items
                   (Raw_Base, Ours_Items, Raw_Theirs)
            else Raw_Base);
         Theirs_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           (if Backend = Backend_Subtree
            then Version.Branch.Shift_Subtree_Items
                   (Raw_Theirs, Ours_Items, Raw_Theirs)
            else Raw_Theirs);

         function Entry_Of
           (Items : Version.Objects.Tree_Entry_Vectors.Vector;
            Path  : String;
            Found : out Boolean)
            return Version.Objects.Tree_Entry
         is
         begin
            for E of Items loop
               if To_String (E.Path) = Path then
                  Found := True;
                  return E;
               end if;
            end loop;

            Found := False;
            return Version.Objects.Tree_Entry'
              (Path => To_Unbounded_String (Path),
               Id   => Version.Objects.Zero_Object_Id,
               Kind => Version.Objects.Tree_Blob,
               Mode => Null_Unbounded_String);
         end Entry_Of;

         --  The paths both sides changed, differently: exactly the ones a
         --  content merge has to look at.
         Needs_Merge : Version.Trailers.String_Vectors.Vector;
      begin
         for E of Ours_Items loop
            declare
               Path : constant String := To_String (E.Path);
               In_Base, In_Theirs : Boolean;
               O : constant Version.Objects.Tree_Entry :=
                 Entry_Of (Base_Items, Path, In_Base);
               B : constant Version.Objects.Tree_Entry :=
                 Entry_Of (Theirs_Items, Path, In_Theirs);
            begin
               if In_Theirs
                 and then Version.Objects.To_String (E.Id)
                          /= Version.Objects.To_String (B.Id)
                 and then (not In_Base
                           or else (Version.Objects.To_String (E.Id)
                                    /= Version.Objects.To_String (O.Id)
                                    and then Version.Objects.To_String (B.Id)
                                             /= Version.Objects.To_String
                                                  (O.Id)))
               then
                  Needs_Merge.Append (Path);
               end if;
            end;
         end loop;

         --  `merge-resolve` says what it is doing before it does it.
         if Backend = Backend_Resolve and then not Needs_Merge.Is_Empty then
            Success_Line ("Trying simple merge.");
            Success_Line ("Simple merge failed, trying Automatic merge.");
         elsif Backend = Backend_Resolve then
            Success_Line ("Trying simple merge.");
         end if;

         declare
            Merged    : Version.Staging.Index_Entry_Vectors.Vector;
            Conflicts : Version.Merge.Conflict_Vectors.Vector;
            Behavior  : Version.Merge.Merge_Behavior;
         begin
            Behavior.Update_Worktree := True;
            Behavior.Base_Label :=
              To_Unbounded_String
                (Version.Merge.Base_Label_For (Repo, Base_Id));

            --  git's `merge-recursive-ours`/`-theirs` do NOT favour a side:
            --  cmd_merge_recursive only reads a `-subtree` suffix off argv[0],
            --  so both behave as plain recursive.  (`-Xours` is what favours.)
            --  Verified against git -- do not "fix" this into a favoured merge.
            null;

            Version.Merge.Merge_Trees
              (Repo          => Repo,
               Current_Name  => To_String (Head),
               Target_Name   => Remotes.First_Element,
               Base_Items    => Base_Items,
               Current_Items => Ours_Items,
               Target_Items  => Theirs_Items,
               Merged_Index  => Merged,
               Conflicts     => Conflicts,
               Behavior      => Behavior);

            Version.Staging.Write (Repo, Merged);

            --  git names every path it had to merge the content of, then every
            --  one where that failed.
            for Path of Needs_Merge loop
               Success_Line ("Auto-merging " & Path);
            end loop;

            for C of Conflicts loop
               declare
                  Path : constant String := To_String (C.Path);

                  --  A path that survives on only one side is a
                  --  modify/delete, which git names precisely rather than
                  --  calling it a content conflict.
                  function Side_Has
                    (Items : Version.Objects.Tree_Entry_Vectors.Vector)
                     return Boolean is
                  begin
                     for E of Items loop
                        if To_String (E.Path) = Path then
                           return True;
                        end if;
                     end loop;
                     return False;
                  end Side_Has;

                  In_Ours   : constant Boolean := Side_Has (Ours_Items);
                  In_Theirs : constant Boolean := Side_Has (Theirs_Items);
                  Ours_Label   : constant String := To_String (Head);
                  Theirs_Label : constant String := Remotes.First_Element;
               begin
                  case C.Kind is
                     when Version.Merge.Binary_Conflict =>
                        Success_Line
                          ("CONFLICT (binary): Merge conflict in " & Path);
                     when others =>
                        if In_Ours and then not In_Theirs then
                           Success_Line
                             ("CONFLICT (modify/delete): " & Path
                              & " deleted in " & Theirs_Label
                              & " and modified in " & Ours_Label
                              & ".  Version " & Ours_Label & " of " & Path
                              & " left in tree.");
                        elsif In_Theirs and then not In_Ours then
                           Success_Line
                             ("CONFLICT (modify/delete): " & Path
                              & " deleted in " & Ours_Label
                              & " and modified in " & Theirs_Label
                              & ".  Version " & Theirs_Label & " of " & Path
                              & " left in tree.");
                        else
                           Success_Line
                             ("CONFLICT (content): Merge conflict in " & Path);
                        end if;
                  end case;
               end;
            end loop;

            if not Conflicts.Is_Empty then
               Set_Command_Failure;
            end if;
         end;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
   end Run_Merge_Backend;

   --  `merge-tree --write-tree [--name-only] [-z] [--merge-base=<c>] <b1> <b2>`
   --  Merge two commits without a worktree or an index: print the merged
   --  tree's id, and -- when the merge conflicted -- the stage 1/2/3 entries
   --  of every conflicted path, a blank line, and the merge's messages.
   procedure Run_Merge_Tree_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Name_Only : Boolean := False;
      Use_NUL   : Boolean := False;
      Messages  : Boolean := True;
      Allow     : Boolean := False;
      Base_Spec : Unbounded_String;
      Operands  : Version.Trailers.String_Vectors.Vector;

      Sep : Character;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--write-tree" then
               null;
            elsif A = "--name-only" or else A = "--name-status" then
               Name_Only := True;
            elsif A = "-z" then
               Use_NUL := True;
            elsif A = "--messages" then
               Messages := True;
            elsif A = "--no-messages" then
               Messages := False;
            elsif A = "--allow-unrelated-histories" then
               Allow := True;
            elsif A'Length > 13
              and then A (A'First .. A'First + 12) = "--merge-base="
            then
               Base_Spec := To_Unbounded_String (A (A'First + 13 .. A'Last));
            elsif A'Length > 0 and then A (A'First) = '-' then
               Error_Line ("unknown option: " & A);
               Set_Usage_Failure;
               return;
            else
               Operands.Append (A);
            end if;
         end;
      end loop;

      if Natural (Operands.Length) /= 2 then
         Error_Line ("merge-tree takes two commits");
         Set_Usage_Failure;
         return;
      end if;

      Sep := (if Use_NUL then ASCII.NUL else ASCII.LF);

      declare
         Ours_Name   : constant String := Operands.Element (1);
         Theirs_Name : constant String := Operands.Element (2);

         --  Which side still holds a path, for classifying a modify/delete
         --  conflict the way git reports it.
         function Has_Path
           (Items : Version.Objects.Tree_Entry_Vectors.Vector;
            Path  : String) return Boolean is
         begin
            for E of Items loop
               if To_String (E.Path) = Path then
                  return True;
               end if;
            end loop;
            return False;
         end Has_Path;

         Ours_Id : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, Ours_Name);
         Theirs_Id : constant Version.Objects.Hex_Object_Id :=
           Version.Revisions.Resolve_Commit (Repo, Theirs_Name);

         --  Compute the base without raising on unrelated histories, so the
         --  refusal below can be git's own message.
         Auto_Bases :
           constant Version.History.Commit_Id_Vectors.Vector :=
             (if Base_Spec /= ""
              then Version.History.Commit_Id_Vectors.Empty_Vector
              else Version.History.Merge_Bases (Repo, Ours_Id, Theirs_Id));
         Has_Base : constant Boolean :=
           Base_Spec /= "" or else not Auto_Bases.Is_Empty;

         Base_Id : constant Version.Objects.Hex_Object_Id :=
           (if Base_Spec /= ""
            then Version.Revisions.Resolve_Commit (Repo, To_String (Base_Spec))
            elsif not Auto_Bases.Is_Empty
            then Auto_Bases.First_Element
            else Version.Objects.Zero_Object_Id);

         function Items (Commit : Version.Objects.Hex_Object_Id)
           return Version.Objects.Tree_Entry_Vectors.Vector
         is (Version.Objects.Flatten_Tree
               (Repo,
                Version.Objects.Commit_Tree_Id
                  (Version.Objects.Read_Object (Repo, Commit))));

         Base_Items   : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           (if Has_Base and then Version.Objects.Id_Length (Base_Id) > 0
            then Items (Base_Id)
            else Version.Objects.Tree_Entry_Vectors.Empty_Vector);
         Ours_Items   : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           Items (Ours_Id);
         Theirs_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
           Items (Theirs_Id);

         Merged    : Version.Staging.Index_Entry_Vectors.Vector;
         Conflicts : Version.Merge.Conflict_Vectors.Vector;

         Behavior : Version.Merge.Merge_Behavior;
      begin
         --  git refuses to merge histories with no common ancestor unless
         --  --allow-unrelated-histories is given (then it merges against an
         --  empty base).
         if not Has_Base and then not Allow then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "fatal: refusing to merge unrelated histories");
            Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
            return;
         end if;

         --  No worktree, no index: the conflicted content becomes a blob in
         --  the tree we hand back, which is what `merge-tree` means by it.
         Behavior.Update_Worktree := False;
         Behavior.Materialize_Virtual_Conflicts := True;
         Behavior.Base_Label :=
           To_Unbounded_String
             (if Has_Base
              then Version.Merge.Base_Label_For (Repo, Base_Id)
              else "");

         Version.Merge.Merge_Trees
           (Repo          => Repo,
            Current_Name  => Ours_Name,
            Target_Name   => Theirs_Name,
            Base_Items    => Base_Items,
            Current_Items => Ours_Items,
            Target_Items  => Theirs_Items,
            Merged_Index  => Merged,
            Conflicts     => Conflicts,
            Behavior      => Behavior);

         declare
            Stage_0 : Version.Staging.Index_Entry_Vectors.Vector;
         begin
            for E of Merged loop
               if E.Stage = 0 then
                  Stage_0.Append (E);
               end if;
            end loop;

            Version.Console.Put
              (Version.Objects.To_String
                 (Version.Write.Write_Tree_From_Index (Repo, Stage_0))
               & Sep);
         end;

         if Conflicts.Is_Empty then
            return;
         end if;

         --  The conflicted paths, as the index would hold them.
         for C of Conflicts loop
            declare
               Path : constant String := To_String (C.Path);

               procedure Emit
                 (Items : Version.Objects.Tree_Entry_Vectors.Vector;
                  Stage : Natural)
               is
               begin
                  for E of Items loop
                     if To_String (E.Path) = Path then
                        Version.Console.Put
                          (To_String (E.Mode) & " "
                           & Version.Objects.To_String (E.Id) & " "
                           & Ada.Strings.Fixed.Trim
                               (Natural'Image (Stage), Ada.Strings.Both)
                           & ASCII.HT
                           & Path & Sep);
                     end if;
                  end loop;
               end Emit;
            begin
               if Name_Only then
                  Version.Console.Put (Path & Sep);
               else
                  Emit (Base_Items, 1);
                  Emit (Ours_Items, 2);
                  Emit (Theirs_Items, 3);
               end if;
            end;
         end loop;

         if Messages then
            Version.Console.Put ("" & ASCII.LF);

            for C of Conflicts loop
               declare
                  Path : constant String := To_String (C.Path);
               begin
                  case C.Kind is
                     when Version.Merge.Binary_Conflict =>
                        Version.Console.Put
                          ("CONFLICT (binary): Merge conflict in " & Path
                           & ASCII.LF);
                     when others =>
                        --  A path that survives on only one side is a
                        --  modify/delete, which git names precisely rather
                        --  than calling it a content conflict.
                        declare
                           Has_Ours : constant Boolean :=
                             Has_Path (Ours_Items, Path);
                           Has_Theirs : constant Boolean :=
                             Has_Path (Theirs_Items, Path);
                        begin
                           if Has_Ours and then not Has_Theirs then
                              Version.Console.Put
                                ("CONFLICT (modify/delete): " & Path
                                 & " deleted in " & Theirs_Name
                                 & " and modified in " & Ours_Name
                                 & ".  Version " & Ours_Name & " of " & Path
                                 & " left in tree." & ASCII.LF);
                           elsif Has_Theirs and then not Has_Ours then
                              Version.Console.Put
                                ("CONFLICT (modify/delete): " & Path
                                 & " deleted in " & Ours_Name
                                 & " and modified in " & Theirs_Name
                                 & ".  Version " & Theirs_Name & " of " & Path
                                 & " left in tree." & ASCII.LF);
                           else
                              Version.Console.Put
                                ("Auto-merging " & Path & ASCII.LF);
                              Version.Console.Put
                                ("CONFLICT (content): Merge conflict in "
                                 & Path & ASCII.LF);
                           end if;
                        end;
                  end case;
               end;
            end loop;
         end if;

         Set_Command_Failure;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Merge_Tree_Command;

   --  `ls-remote [--heads] [--tags] [-q] [--exit-code] [<repository>]`
   procedure Run_Ls_Remote_Command is
      Heads : Boolean := False;
      Tags  : Boolean := False;
      Exit_Code : Boolean := False;
      Refs_Only : Boolean := False;
      Remote : Unbounded_String;
      Patterns : Version.Trailers.String_Vectors.Vector;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A = "--heads" or else A = "-h" then
               Heads := True;
            elsif A = "--tags" or else A = "-t" then
               Tags := True;
            elsif A = "--exit-code" then
               Exit_Code := True;
            elsif A = "-q" or else A = "--quiet" then
               null;
            elsif A = "--refs" then
               Refs_Only := True;
            elsif A'Length > 0 and then A (A'First) = '-' then
               Error_Line ("unknown option: " & A);
               Set_Usage_Failure;
               return;
            elsif Remote = "" then
               Remote := To_Unbounded_String (A);
            else
               Patterns.Append (A);
            end if;
         end;
      end loop;

      if Remote = "" then
         Remote := To_Unbounded_String ("origin");
      end if;

      declare
         Refs : constant Version.Upload_Pack.Advertised_Ref_Vectors.Vector :=
           Version.Fetch.List_Remote_Refs (To_String (Remote));
         Shown : Natural := 0;

         function Wanted (Name : String) return Boolean is
            Is_Head : constant Boolean :=
              Name'Length > 11
              and then Name (Name'First .. Name'First + 10) = "refs/heads/";
            Is_Tag  : constant Boolean :=
              Name'Length > 10
              and then Name (Name'First .. Name'First + 9) = "refs/tags/";
         begin
            if Heads and then not Tags then
               return Is_Head;
            elsif Tags and then not Heads then
               return Is_Tag;
            elsif Heads and then Tags then
               return Is_Head or else Is_Tag;
            else
               return True;
            end if;
         end Wanted;

         --  git's tail_match: every pattern becomes "*/<pattern>" and is
         --  wildmatched against "/<refname>", with `*` crossing slashes. So
         --  "v1*" finds refs/tags/v1.0 and "refs/tags/v*" finds them all.
         function Wild (Pattern, Text : String) return Boolean is
            function Match (PI, TI : Natural) return Boolean is
            begin
               if PI > Pattern'Last then
                  return TI > Text'Last;
               end if;

               case Pattern (PI) is
                  when '*' =>
                     --  Try every split; `*` is allowed to span separators.
                     for K in TI - 1 .. Text'Last loop
                        if Match (PI + 1, K + 1) then
                           return True;
                        end if;
                     end loop;
                     return False;
                  when '?' =>
                     return TI <= Text'Last and then Match (PI + 1, TI + 1);
                  when others =>
                     return TI <= Text'Last
                       and then Pattern (PI) = Text (TI)
                       and then Match (PI + 1, TI + 1);
               end case;
            end Match;
         begin
            return Match (Pattern'First, Text'First);
         end Wild;

         function Selected (Name : String) return Boolean is
         begin
            if Patterns.Is_Empty then
               return True;
            end if;

            for P of Patterns loop
               if Wild ("*/" & P, "/" & Name) then
                  return True;
               end if;
            end loop;

            return False;
         end Selected;

      begin
         for R of Refs loop
            declare
               Name : constant String := To_String (R.Name);
               Bare : constant String :=
                 (if Name'Length > 3
                    and then Name (Name'Last - 2 .. Name'Last) = "^{}"
                  then Name (Name'First .. Name'Last - 3) else Name);
            begin
               if Refs_Only
                 and then (Name = "HEAD" or else Name /= Bare)
               then
                  null;   --  --refs hides HEAD and peeled "^{}" entries
               elsif Wanted (Name) and then Selected (Name) then
                  Success_Line
                    (Version.Objects.To_String (R.Id) & ASCII.HT & Name);
                  Shown := Shown + 1;
               end if;
            end;
         end loop;

         if Exit_Code and then Shown = 0 then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (2));
         end if;
      end;
   exception
      when E : Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error =>
         Error_Line (Ada.Exceptions.Exception_Message (E));
         Set_Command_Failure;
   end Run_Ls_Remote_Command;

   --  `check-attr [-a|--all] [--] <attr>... <pathname>...`
   procedure Run_Check_Attr_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      All_Attrs : Boolean := False;
      Names     : Version.Trailers.String_Vectors.Vector;
      Paths     : Version.Trailers.String_Vectors.Vector;
      Seen_Sep  : Boolean := False;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if not Seen_Sep and then (A = "-a" or else A = "--all") then
               All_Attrs := True;
            elsif not Seen_Sep and then A = "--" then
               Seen_Sep := True;
            elsif not Seen_Sep and then A'Length > 0 and then A (A'First) = '-'
            then
               Error_Line ("unknown option: " & A);
               Set_Usage_Failure;
               return;
            elsif not All_Attrs and then not Seen_Sep and then Paths.Is_Empty
              and then Names.Is_Empty
            then
               Names.Append (A);
            elsif not All_Attrs and then not Seen_Sep then
               --  Without `--`, git reads attribute names until the first one
               --  that names an existing file.
               if Ada.Directories.Exists (A) then
                  Paths.Append (A);
               else
                  Names.Append (A);
               end if;
            else
               Paths.Append (A);
            end if;
         end;
      end loop;

      if Paths.Is_Empty then
         Error_Line ("no pathname given");
         Set_Usage_Failure;
         return;
      end if;

      for P of Paths loop
         if All_Attrs then
            for Item of Version.Attributes.All_For_Path (Repo, P) loop
               Success_Line
                 (P & ": " & To_String (Item.Name) & ": "
                  & Version.Attributes.State_Image (Item.Result));
            end loop;
         else
            for N of Names loop
               Success_Line
                 (P & ": " & N & ": "
                  & Version.Attributes.State_Image
                      (Version.Attributes.Lookup (Repo, P, N)));
            end loop;
         end if;
      end loop;
   end Run_Check_Attr_Command;

   --  `check-mailmap <contact>...` -- the canonical identity for each.
   procedure Run_Check_Mailmap_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;
      Map  : constant Version.Mailmap.Entries := Version.Mailmap.Load (Repo);
      Any  : Boolean := False;
   begin
      for I in 2 .. Count loop
         declare
            Contact : constant String := Arg (I);
            LT : constant Natural := Ada.Strings.Fixed.Index (Contact, "<");
            GT : constant Natural := Ada.Strings.Fixed.Index (Contact, ">");
         begin
            if LT = 0 or else GT < LT then
               Error_Line ("unable to parse contact: " & Contact);
               Set_Command_Failure;
               return;
            end if;

            declare
               Name  : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Contact (Contact'First .. LT - 1), Ada.Strings.Both);
               Email : constant String := Contact (LT + 1 .. GT - 1);
               Out_Name, Out_Email : Unbounded_String;
            begin
               Version.Mailmap.Apply (Map, Name, Email, Out_Name, Out_Email);
               Success_Line
                 ((if Out_Name = "" then ""
                   else To_String (Out_Name) & " ")
                  & "<" & To_String (Out_Email) & ">");
               Any := True;
            end;
         end;
      end loop;

      if not Any then
         Error_Line ("no contacts specified");
         Set_Usage_Failure;
      end if;
   end Run_Check_Mailmap_Command;

   --  `for-each-repo --config=<key> [--] <command>...` -- run a version
   --  command in each repository the configuration lists.
   procedure Run_For_Each_Repo_Command is
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      Key      : Unbounded_String;
      Argv     : Version.Trailers.String_Vectors.Vector;
      Seen_Sep : Boolean := False;
      Old_Dir  : constant String := Ada.Directories.Current_Directory;
   begin
      for I in 2 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if not Seen_Sep and then A'Length > 9
              and then A (A'First .. A'First + 8) = "--config="
            then
               Key := To_Unbounded_String (A (A'First + 9 .. A'Last));
            elsif not Seen_Sep and then A = "--" then
               Seen_Sep := True;
            else
               Seen_Sep := True;
               Argv.Append (A);
            end if;
         end;
      end loop;

      if Key = "" then
         Error_Line ("missing --config=<config>");
         Set_Usage_Failure;
         return;
      end if;

      if Argv.Is_Empty then
         return;
      end if;

      declare
         Command : Unbounded_String;
      begin
         for A of Argv loop
            if Command /= "" then
               Append (Command, " ");
            end if;

            Append (Command, A);
         end loop;

         --  Every value of the multi-valued key names a repository.
         for Item of Version.Config.Read_All (Repo) loop
            declare
               Full : constant String :=
                 To_String (Item.Section) & "." & To_String (Item.Key);
            begin
               if Full = To_String (Key) then
                  declare
                     Args   : GNAT.OS_Lib.Argument_List (1 .. 2);
                     Status : Integer;
                  begin
                     Ada.Directories.Set_Directory (To_String (Item.Value));
                     Args (1) := new String'("-c");
                     Args (2) :=
                       new String'
                         (Ada.Command_Line.Command_Name & " "
                          & To_String (Command));
                     Status :=
                       GNAT.OS_Lib.Spawn
                         (Program_Name => "/bin/sh", Args => Args);
                     GNAT.OS_Lib.Free (Args (1));
                     GNAT.OS_Lib.Free (Args (2));
                     Ada.Directories.Set_Directory (Old_Dir);

                     if Status /= 0 then
                        Ada.Command_Line.Set_Exit_Status
                          (Ada.Command_Line.Exit_Status (Status));
                     end if;
                  exception
                     when others =>
                        Ada.Directories.Set_Directory (Old_Dir);
                        raise;
                  end;
               end if;
            end;
         end loop;
      end;
   end Run_For_Each_Repo_Command;

   --  `subtree add|merge|pull|push|split --prefix=<dir> ...`
   procedure Run_Subtree_Command is
      Sub    : constant String := (if Count >= 2 then Arg (2) else "");
      Prefix : Unbounded_String;
      Msg    : Unbounded_String;
      Branch : Unbounded_String;
      Onto   : Unbounded_String;
      Squash : Boolean := False;
      Rejoin : Boolean := False;
      Ignore_Joins : Boolean := False;
      Operands : Version.Trailers.String_Vectors.Vector;
      Bad      : Boolean := False;

      function Op (I : Positive) return String is
        (if Natural (Operands.Length) >= I then Operands.Element (I) else "");

      Ops : Natural;

      procedure Fatal (Text : String) is
      begin
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "fatal: " & Text);
         Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
      end Fatal;
   begin
      if Sub = "" then
         Fatal ("you must provide a subtree command");
         return;
      end if;

      for I in 3 .. Count loop
         declare
            A : constant String := Arg (I);
         begin
            if A'Length > 9 and then A (A'First .. A'First + 8) = "--prefix=" then
               Prefix := To_Unbounded_String (A (A'First + 9 .. A'Last));
            elsif A = "-P" or else A = "--prefix" then
               Bad := True;   --  handled below via the following operand
            elsif A = "-q" or else A = "--quiet" then
               Quiet_Mode := True;
            elsif A = "--squash" then
               Squash := True;
            elsif A = "--rejoin" then
               Rejoin := True;
            elsif A = "--ignore-joins" then
               Ignore_Joins := True;
            elsif A'Length > 7 and then A (A'First .. A'First + 6) = "--onto=" then
               Onto := To_Unbounded_String (A (A'First + 7 .. A'Last));
            elsif A'Length > 10 and then A (A'First .. A'First + 9) = "--message=" then
               Msg := To_Unbounded_String (A (A'First + 10 .. A'Last));
            elsif A'Length > 9 and then A (A'First .. A'First + 8) = "--branch=" then
               Branch := To_Unbounded_String (A (A'First + 9 .. A'Last));
            elsif (A = "-m" or else A = "--message") and then I < Count then
               Msg := To_Unbounded_String (Arg (I + 1));
            elsif (A = "-b" or else A = "--branch") and then I < Count then
               Branch := To_Unbounded_String (Arg (I + 1));
            elsif I > 3
              and then (Arg (I - 1) = "-m" or else Arg (I - 1) = "--message"
                        or else Arg (I - 1) = "-b"
                        or else Arg (I - 1) = "--branch"
                        or else Arg (I - 1) = "-P"
                        or else Arg (I - 1) = "--prefix")
            then
               if Arg (I - 1) = "-P" or else Arg (I - 1) = "--prefix" then
                  Prefix := To_Unbounded_String (A);
                  Bad := False;
               end if;
            elsif A'Length > 0 and then A (A'First) = '-' then
               Fatal ("unexpected option: " & A);
               return;
            else
               Operands.Append (A);
            end if;
         end;
      end loop;

      if Bad or else Prefix = "" then
         Fatal ("you must provide the --prefix option.");
         return;
      end if;

      Ops := Natural (Operands.Length);

      begin
         if Sub = "add" then
            if Ops = 1 then
               Version.Subtree.Add
                 (To_String (Prefix), "", Op (1), Squash, To_String (Msg));
            elsif Ops = 2 then
               Success_Line ("git fetch " & Op (1) & " " & Op (2));
               Version.Subtree.Add
                 (To_String (Prefix), Op (1), Op (2), Squash, To_String (Msg));
            else
               Error_Line
                 ("Provide either a commit or a repository and commit.");
               return;
            end if;

            Stderr_Line ("Added dir '" & To_String (Prefix) & "'");

         elsif Sub = "merge" or else Sub = "pull" then
            if (Sub = "merge" and then Ops /= 1)
              or else (Sub = "pull" and then Ops /= 2)
            then
               Error_Line
                 (if Sub = "pull" then "you must provide <repository> <ref>"
                  else "you must provide exactly one revision, and optionally "
                       & "a repository.");
               return;
            end if;

            Merge_Subtree
              (Prefix     => To_String (Prefix),
               Repository => (if Sub = "pull" then Op (1) else ""),
               Ref        => (if Sub = "pull" then Op (2) else Op (1)),
               Squash     => Squash,
               Message    => To_String (Msg));

         elsif Sub = "split" then
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Updated : Boolean;
               Result  : constant Version.Objects.Hex_Object_Id :=
                 Version.Subtree.Split
                   (Repo   => Repo,
                    Prefix => To_String (Prefix),
                    Rev    => (if Ops >= 1 then Op (1) else "HEAD"),
                    Branch => To_String (Branch),
                    Onto   => To_String (Onto),
                    Rejoin => Rejoin,
                    Ignore_Joins => Ignore_Joins,
                    Updated => Updated);
            begin
               if Branch /= "" then
                  Stderr_Line
                    ((if Updated then "Updated" else "Created") & " branch '"
                     & To_String (Branch) & "'");
               end if;

               Success_Line (Version.Objects.To_String (Result));
            end;

         elsif Sub = "push" then
            if Ops /= 2 then
               Fatal ("you must provide <repository> <refspec>");
               return;
            end if;

            declare
               Spec : constant String :=
                 (if Op (2)'Length > 0 and then Op (2) (Op (2)'First) = '+'
                  then Op (2) (Op (2)'First + 1 .. Op (2)'Last) else Op (2));
               Colon : constant Natural :=
                 Ada.Strings.Fixed.Index (Spec, ":");
               Local : constant String :=
                 (if Colon = 0 then "HEAD" else Spec (Spec'First .. Colon - 1));
               Remote_Ref : constant String :=
                 (if Colon = 0 then Spec else Spec (Colon + 1 .. Spec'Last));
            begin
               Success_Line
                 ("git push using:  " & Op (1) & " " & Spec);
               Version.Subtree.Push
                 (Prefix     => To_String (Prefix),
                  Repository => Op (1),
                  Local_Rev  => Local,
                  Remote_Ref => Remote_Ref,
                  Force      => Op (2)'Length > 0
                                and then Op (2) (Op (2)'First) = '+');
            end;

         else
            Fatal ("unknown command '" & Sub & "'");
         end if;
      exception
         when E : Ada.IO_Exceptions.Use_Error
            | Ada.IO_Exceptions.Data_Error
            | Ada.IO_Exceptions.Name_Error =>
            Fatal (Ada.Exceptions.Exception_Message (E));
      end;
   end Run_Subtree_Command;

   procedure Run_Bisect_Command is
      use Version.Bisect;
      Repo : constant Version.Repository.Repository_Handle :=
        Version.Repository.Open;

      function Img (V : Natural) return String is
         S : constant String := Natural'Image (V);
      begin
         return S (S'First + 1 .. S'Last);
      end Img;

      function Short (Hex : String) return String is
        (if Hex'Length >= 7 then Hex (Hex'First .. Hex'First + 6) else Hex);

      function Subject (Id : Version.Objects.Hex_Object_Id) return String is
        (Version.Objects.Commit_Message_First_Line
           (Version.Objects.Read_Object (Repo, Id)));

      function Rev (S : String) return Version.Objects.Hex_Object_Id is
        (Version.Revisions.Resolve_Commit (Repo, S));

      Sub : constant String := (if Count >= 2 then Arg (2) else "");

      procedure Emit_Continue (B : Version.Bisect.Bisection) is
         Hex : constant String := Version.Objects.To_String (B.Rev);
      begin
         Success_Line
           ("Bisecting: " & Img (B.Left)
            & (if B.Left = 1 then " revision" else " revisions")
            & " left to test after this (roughly " & Img (B.Steps)
            & (if B.Steps = 1 then " step)" else " steps)"));
         Success_Line ("[" & Hex & "] " & Subject (B.Rev));
         Version.Checkout.Checkout_Commit (B.Rev);
      end Emit_Continue;

      procedure Emit_Found (B : Version.Bisect.Bisection) is
         Hex  : constant String := Version.Objects.To_String (B.Rev);
         Opts : constant Version.Diff.Diff_Options :=
           (Stat => True, others => <>);
      begin
         Append_Log
           (Repo, "# first bad commit: [" & Hex & "] " & Subject (B.Rev));
         Success_Line (Hex & " is the first bad commit");
         Version.Console.Put (Version.Show.Show_Commit (Repo, B.Rev, Opts));
      end Emit_Found;

      --  git's sanity check before bisecting: every good rev must be an
      --  ancestor of the bad rev. Otherwise good/bad were likely swapped, and
      --  continuing would report a meaningless "first bad commit".
      function Good_Ancestors_Of_Bad return Boolean is
      begin
         if not Version.Bisect.Has_Bad (Repo)
           or else Version.Bisect.Good_Count (Repo) = 0
         then
            return True;
         end if;
         declare
            Bad : constant Version.Objects.Hex_Object_Id :=
              Version.Bisect.Bad_Id (Repo);
         begin
            for G of Version.Bisect.Good_Ids (Repo) loop
               if not Version.History.Is_Ancestor
                        (Repo, Base_Id => G, Derived_Id => Bad)
               then
                  return False;
               end if;
            end loop;
         end;
         return True;
      end Good_Ancestors_Of_Bad;

      --  Recompute the bisection and render / act on the result.
      procedure Advance is
      begin
         if not Good_Ancestors_Of_Bad then
            Stderr_Line ("Some good revs are not ancestors of the bad rev.");
            Stderr_Line ("git bisect cannot work properly in this case.");
            Stderr_Line ("Maybe you mistook good and bad revs?");
            Set_Command_Failure;
            return;
         end if;

         declare
            B : constant Version.Bisect.Bisection := Compute (Repo);
         begin
            case B.Kind is
               when Need_Both | Need_Good | Need_Bad =>
                  declare
                     T : constant String := Status_Text (Repo, B.Kind);
                  begin
                     Append_Log (Repo, "# status: " & T);
                     Success_Line ("status: " & T);
                  end;
               when Continue =>
                  Emit_Continue (B);
               when Found =>
                  Emit_Found (B);
               when Only_Skipped =>
                  Error_Line
                    ("There are only 'skip'ped commits left to test.");
                  Set_Command_Failure;
            end case;
         end;
      end Advance;

      --  Record marks (comment + command lines) for a good/bad/skip verb.
      --  Head_Only: `bisect run`'s trailing words are the command, not
      --  revisions -- it always marks the commit currently checked out.
      procedure Mark_Revs
        (Is_Bad, Is_Skip : Boolean;
         Verb            : String;
         Head_Only       : Boolean := False)
      is
         Any : Boolean := False;
      begin
         for I in 3 .. (if Head_Only then 2 else Count) loop
            declare
               Id  : constant Version.Objects.Hex_Object_Id := Rev (Arg (I));
               Hex : constant String := Version.Objects.To_String (Id);
            begin
               Append_Log
                 (Repo, "# " & Verb & ": [" & Hex & "] " & Subject (Id));
               if Is_Skip then
                  Mark_Skip (Repo, Id);
               elsif Is_Bad then
                  Mark_Bad (Repo, Id);
               else
                  Mark_Good (Repo, Id);
               end if;
               Append_Log (Repo, "git bisect " & Verb & " " & Hex);
               Any := True;
            end;
         end loop;
         if not Any then
            --  Default operand is the currently checked-out commit (HEAD).
            declare
               Id  : constant Version.Objects.Hex_Object_Id := Rev ("HEAD");
               Hex : constant String := Version.Objects.To_String (Id);
            begin
               Append_Log
                 (Repo, "# " & Verb & ": [" & Hex & "] " & Subject (Id));
               if Is_Skip then
                  Mark_Skip (Repo, Id);
               elsif Is_Bad then
                  Mark_Bad (Repo, Id);
               else
                  Mark_Good (Repo, Id);
               end if;
               Append_Log (Repo, "git bisect " & Verb & " " & Hex);
            end;
         end if;
         Advance;
      end Mark_Revs;

      --  Return HEAD to the start branch/commit and drop all session state.
      procedure Do_Reset (Target : String) is
      begin
         if not In_Progress (Repo) then
            return;
         end if;
         declare
            Start_R      : constant String := Version.Bisect.Start_Ref (Repo);
            Dest         : constant String :=
              (if Target /= "" then Target else Start_R);
            Was_Detached : constant Boolean := Version.Refs.Is_Detached (Repo);
            Cur_Branch   : constant String :=
              (if Was_Detached then ""
               else Version.Refs.Current_Branch_Name (Repo));
         begin
            if Was_Detached then
               declare
                  P : constant Version.Objects.Hex_Object_Id :=
                    Version.Refs.Detached_Commit_Id (Repo);
               begin
                  Success_Line
                    ("Previous HEAD position was "
                     & Short (Version.Objects.To_String (P)) & " "
                     & Subject (P));
               end;
            end if;
            if Target = "" and then Version.Branch.Branch_Exists (Dest) then
               if not Was_Detached and then Cur_Branch = Dest then
                  Success_Line ("Already on '" & Dest & "'");
               else
                  Version.Branch.Switch_Branch (Dest);
                  Success_Line ("Switched to branch '" & Dest & "'");
               end if;
            else
               declare
                  Id : constant Version.Objects.Hex_Object_Id := Rev (Dest);
               begin
                  Version.Checkout.Checkout_Commit (Id);
                  Success_Line
                    ("HEAD is now at "
                     & Short (Version.Objects.To_String (Id)) & " "
                     & Subject (Id));
               end;
            end if;
         end;
         Version.Bisect.Clear (Repo);
      end Do_Reset;

      procedure Do_Start is
         Term_Bad  : Unbounded_String := To_Unbounded_String ("bad");
         Term_Good : Unbounded_String := To_Unbounded_String ("good");
         Revs      : Version.Trailers.String_Vectors.Vector;
         I         : Positive := 3;
         Bad       : Boolean := False;
      begin
         if In_Progress (Repo) then
            Do_Reset (Target => "");
         end if;
         while I <= Count and then not Bad loop
            declare
               A : constant String := Arg (I);
            begin
               if (A = "--term-old" or else A = "--term-good")
                 and then I < Count
               then
                  Term_Good := To_Unbounded_String (Arg (I + 1));
                  I := I + 2;
               elsif (A = "--term-new" or else A = "--term-bad")
                 and then I < Count
               then
                  Term_Bad := To_Unbounded_String (Arg (I + 1));
                  I := I + 2;
               elsif A = "--no-checkout" or else A = "--first-parent" then
                  I := I + 1;
               elsif A = "--" then
                  exit;
               elsif A'Length > 0 and then A (A'First) = '-' then
                  Usage_Error
                    ("unknown bisect start option: " & A,
                     "version bisect start [--term-old <t> --term-new <t>]"
                     & " [<bad> [<good>...]]");
                  Bad := True;
               else
                  Revs.Append (A);
                  I := I + 1;
               end if;
            end;
         end loop;
         if Bad then
            return;
         end if;
         declare
            Start_R : constant String :=
              (if Version.Refs.Is_Detached (Repo)
               then Version.Objects.To_String
                      (Version.Refs.Detached_Commit_Id (Repo))
               else Version.Refs.Current_Branch_Name (Repo));
         begin
            Version.Bisect.Start
              (Repo, Start_R, To_String (Term_Bad), To_String (Term_Good));
         end;
         --  Log comment lines for each rev (first = bad, rest = good).
         for Idx in Revs.First_Index .. Revs.Last_Index loop
            declare
               Id   : constant Version.Objects.Hex_Object_Id :=
                 Rev (Revs (Idx));
               Hex  : constant String := Version.Objects.To_String (Id);
               Verb : constant String :=
                 (if Idx = Revs.First_Index
                  then To_String (Term_Bad) else To_String (Term_Good));
            begin
               Append_Log
                 (Repo, "# " & Verb & ": [" & Hex & "] " & Subject (Id));
               if Idx = Revs.First_Index then
                  Mark_Bad (Repo, Id);
               else
                  Mark_Good (Repo, Id);
               end if;
            end;
         end loop;
         declare
            Line : Unbounded_String := To_Unbounded_String ("git bisect start");
         begin
            for J in 3 .. Count loop
               Append (Line, " '" & Arg (J) & "'");
            end loop;
            Append_Log (Repo, To_String (Line));
         end;
         Advance;
      end Do_Start;

      procedure Do_Terms is
         T : constant Version.Bisect.Terms := Current_Terms (Repo);
      begin
         if Count >= 3
           and then (Arg (3) = "--term-good" or else Arg (3) = "--term-old")
         then
            Success_Line (To_String (T.Good));
         elsif Count >= 3
           and then (Arg (3) = "--term-bad" or else Arg (3) = "--term-new")
         then
            Success_Line (To_String (T.Bad));
         else
            Success_Line
              ("Your current terms are " & To_String (T.Good)
               & " for the old state");
            Success_Line
              ("and " & To_String (T.Bad) & " for the new state.");
         end if;
      end Do_Terms;

      --  Handle a good/bad/new/old/<custom-term> mark verb.
      procedure Do_Mark is
         T    : constant Version.Bisect.Terms := Current_Terms (Repo);
         Word : constant String := Sub;
      begin
         if not In_Progress (Repo) then
            Stderr_Line ("You need to start by ""git bisect start""");
            Stderr_Line ("");
            Set_Command_Failure;
            return;
         end if;
         if Word = To_String (T.Bad) then
            Mark_Revs (Is_Bad => True, Is_Skip => False, Verb => Word);
         elsif Word = To_String (T.Good) then
            Mark_Revs (Is_Bad => False, Is_Skip => False, Verb => Word);
         elsif (Word = "new" or else Word = "old")
           and then To_String (T.Bad) = "bad"
           and then To_String (T.Good) = "good"
           and then not Has_Bad (Repo)
           and then Good_Count (Repo) = 0
         then
            Version.Bisect.Set_Terms (Repo, "new", "old");
            Mark_Revs (Is_Bad => Word = "new", Is_Skip => False, Verb => Word);
         else
            Usage_Error
              ("unknown bisect subcommand: " & Word,
               "version bisect (start|good|bad|new|old|skip|reset|log|terms)");
         end if;
      end Do_Mark;

      --  git's `bisect run <cmd>`: test each commit the bisection picks by
      --  running <cmd>.  Its exit status is the verdict -- 0 good, 125 skip,
      --  1..127 bad, 128 and above abort the run.
      procedure Do_Run is
         Found_It : Boolean := False;

         function Command_Text return String is
            Buf : Unbounded_String;
         begin
            for I in 3 .. Count loop
               if I > 3 then
                  Append (Buf, " ");
               end if;
               Append (Buf, Arg (I));
            end loop;
            return To_String (Buf);
         end Command_Text;

         Cmd : constant String := Command_Text;
      begin
         if Count < 3 then
            Usage_Error
              ("bisect run requires a command",
               "version bisect run <command> [<arg>...]");
            return;
         end if;

         if not In_Progress (Repo) then
            Stderr_Line ("You need to start by ""git bisect start""");
            Stderr_Line ("");
            Set_Command_Failure;
            return;
         end if;

         loop
            declare
               B : constant Version.Bisect.Bisection := Compute (Repo);
            begin
               if B.Kind = Found then
                  Found_It := True;
                  exit;
               elsif B.Kind /= Continue then
                  Error_Line ("bisect run cannot proceed: not enough marks");
                  Set_Command_Failure;
                  return;
               end if;
            end;

            Success_Line ("running '" & Cmd & "'");

            declare
               Args   : GNAT.OS_Lib.Argument_List (1 .. 2);
               Status : Integer;
            begin
               Args (1) := new String'("-c");
               Args (2) := new String'(Cmd);
               Status :=
                 GNAT.OS_Lib.Spawn
                   (Program_Name => "/bin/sh", Args => Args);
               GNAT.OS_Lib.Free (Args (1));
               GNAT.OS_Lib.Free (Args (2));

               if Status >= 128 then
                  Error_Line
                    ("bisect run failed: exit code " & Img (Status)
                     & " from '" & Cmd & "' is < 0 or >= 128");
                  Set_Command_Failure;
                  return;
               elsif Status = 125 then
                  Mark_Revs (Is_Bad => False, Is_Skip => True,
                             Verb => "skip", Head_Only => True);
               elsif Status = 0 then
                  Mark_Revs (Is_Bad => False, Is_Skip => False,
                             Verb => "good", Head_Only => True);
               else
                  Mark_Revs (Is_Bad => True, Is_Skip => False,
                             Verb => "bad", Head_Only => True);
               end if;
            end;

            --  Mark_Revs advanced the bisection; stop once it converged.
            declare
               B : constant Version.Bisect.Bisection := Compute (Repo);
            begin
               if B.Kind = Found then
                  Found_It := True;
                  exit;
               end if;
            end;
         end loop;

         if Found_It then
            Success_Line ("bisect found first bad commit");
         end if;
      end Do_Run;

   begin
      if Sub = "" or else Sub = "start" then
         Do_Start;
      elsif Sub = "run" then
         Do_Run;
      elsif Sub = "reset" then
         Do_Reset (Target => (if Count >= 3 then Arg (3) else ""));
      elsif Sub = "log" then
         if not In_Progress (Repo) then
            Error_Line ("We are not bisecting.");
            Set_Command_Failure;
         else
            Version.Console.Put (Version.Bisect.Read_Log (Repo));
         end if;
      elsif Sub = "terms" then
         Do_Terms;
      elsif Sub = "skip" then
         if not In_Progress (Repo) then
            Stderr_Line ("You need to start by ""git bisect start""");
            Stderr_Line ("");
            Set_Command_Failure;
         else
            Mark_Revs (Is_Bad => False, Is_Skip => True, Verb => "skip");
         end if;
      else
         Do_Mark;
      end if;
   end Run_Bisect_Command;

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
               All_Untracked   : Boolean := False;
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
                     elsif not Has_Separator
                       and then (Arg (I) = "--short" or else Arg (I) = "-s")
                     then
                        if Mode /= 0 then
                           Usage_Error
                             ("duplicate status mode option: " & Arg (I), Usage);
                           return;
                        end if;
                        Mode := 2;
                     elsif not Has_Separator
                       and then (Arg (I) = "--branch" or else Arg (I) = "-b")
                     then
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
                       and then (Arg (I) = "-uall"
                                 or else Arg (I) = "--untracked-files=all")
                     then
                        All_Untracked := True;
                     elsif not Has_Separator
                       and then (Arg (I) = "-unormal"
                                 or else Arg (I) = "-u"
                                 or else Arg (I) = "--untracked-files"
                                 or else Arg (I) = "--untracked-files=normal")
                     then
                        All_Untracked := False;
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
                        Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
                  elsif Mode = 2 then
                     Version.Status.Print_Short_Status
                       (Include_Ignored => Include_Ignored,
                        Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
                  elsif Mode = 3 then
                     Version.Status.Print_Branch_Status
                       (Include_Ignored => Include_Ignored,
                        Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
                  elsif Include_Ignored then
                     Version.Status.Print_Ignored_Status (Ignored_Mode);
                  else
                     Version.Status.Print_Status (All_Untracked);
                  end if;
               elsif Mode = 1 then
                  Version.Status.Print_Porcelain_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
               elsif Mode = 2 then
                  Version.Status.Print_Short_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
               elsif Mode = 3 then
                  Version.Status.Print_Branch_Status
                    (Pathspecs_From_Args (Path_First),
                     Include_Ignored => Include_Ignored,
                     Ignored_Mode    => Ignored_Mode,
                        All_Untracked   => All_Untracked);
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

               --  git validates path operands before matching: an empty
               --  string is not a valid pathspec, and a path that resolves
               --  outside the repository is fatal (exit 128).
               declare
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Root : constant String :=
                    Version.Repository.Root_Path (Repo);
                  Bad  : Boolean := False;

                  function Outside (P : String) return Boolean is
                     Abs_P : constant String := Ada.Directories.Full_Name (P);
                  begin
                     return Abs_P /= Root
                       and then not (Abs_P'Length > Root'Length
                                     and then Abs_P
                                       (Abs_P'First
                                        .. Abs_P'First + Root'Length)
                                       = Root & "/");
                  exception
                     when others =>
                        return False;
                  end Outside;
               begin
                  for P of Paths loop
                     if P = "" then
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "fatal: empty string is not a valid pathspec."
                           & " please use . instead if you meant to match"
                           & " all paths");
                        Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                        Bad := True;
                        exit;
                     elsif Outside (P) then
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "fatal: " & P & ": '" & P
                           & "' is outside repository at '" & Root & "'");
                        Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                        Bad := True;
                        exit;
                     end if;
                  end loop;

                  if not Bad then
                     Run_Check_Ignore (Paths, Options);
                  end if;
               end;
            end;

         elsif Command = "diff" then
            declare
               Usage        : constant String :=
                 "version diff [--stat|--name-only|--name-status]"
                 & " [--staged|--cached] [--] [PATHSPEC...]"
                 & " | version diff [--stat|--name-only|--name-status] REV1 REV2";
               Path_First    : Positive := 2;
               Has_Separator : Boolean := False;

               --  Pull the position-independent --stat flag out of the
               --  argument stream, leaving a filtered 2-based view (LArg (1)
               --  stands in for the command) so the rest of the parser is
               --  unchanged.
               NArgs  : constant Natural := Count;
               LArgs  : array (1 .. Integer'Max (NArgs, 1)) of Unbounded_String;
               LCount : Natural := 1;
               Stat   : Boolean := False;
               Name_Only   : Boolean := False;
               Name_Status : Boolean := False;
               Rename_Mode  : Version.Diff.Rename_Detection :=
                 Version.Diff.Renames_Default;
               Rename_Score : Natural := 0;
               Opts   : Version.Diff.Diff_Options;
               Context : Natural := 3;

               function LArg (Index : Positive) return String is
                 (To_String (LArgs (Index)));

               function LHas_Path (First : Positive) return Boolean is
               begin
                  if LCount < First then
                     return False;
                  end if;
                  for I in First .. LCount loop
                     if LArg (I) /= "--" then
                        return True;
                     end if;
                  end loop;
                  return False;
               end LHas_Path;

               function LPathspecs (First : Positive)
                 return Version.Pathspec.Pathspec_Vectors.Vector
               is
                  Result : Version.Pathspec.Pathspec_Vectors.Vector;
               begin
                  if LCount >= First then
                     for I in First .. LCount loop
                        if LArg (I) /= "--" then
                           Version.Pathspec.Append_Parse (Result, LArg (I));
                        end if;
                     end loop;
                  end if;
                  return Result;
               end LPathspecs;
               --  git's parse_num(): the digits are read as a fraction, so
               --  "-M5" is 50% and "-M50%" is 50%; a value at or above 1
               --  clamps to the maximum score.
               function Parse_Rename_Score (Text : String) return Natural is
                  Num   : Natural := 0;
                  Scale : Natural := 1;
                  Dot   : Boolean := False;
                  Score : constant Natural :=
                    Version.Rename_Detect.Max_Score;
               begin
                  for C of Text loop
                     if not Dot and then C = '.' then
                        Scale := 1;
                        Dot := True;
                     elsif C = '%' then
                        Scale := (if Dot then Scale * 100 else 100);
                        exit;
                     elsif C in '0' .. '9' then
                        if Scale < 100_000 then
                           Scale := Scale * 10;
                           Num := Num * 10 + (Character'Pos (C)
                                              - Character'Pos ('0'));
                        end if;
                     else
                        exit;
                     end if;
                  end loop;

                  if Num >= Scale then
                     return Score;
                  end if;
                  return Score * Num / Scale;
               end Parse_Rename_Score;
            begin
               LArgs (1) := To_Unbounded_String (Command);
               for I in 2 .. Count loop
                  if Arg (I) = "--stat" then
                     Stat := True;
                  elsif Arg (I) = "--no-renames" then
                     Rename_Mode := Version.Diff.Renames_Off;
                  elsif Arg (I) = "-M" or else Arg (I) = "--find-renames" then
                     Rename_Mode := Version.Diff.Renames_On;
                  elsif (Arg (I)'Length > 2
                         and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1)
                                  = "-M")
                    or else (Arg (I)'Length > 16
                             and then Arg (I) (Arg (I)'First
                                               .. Arg (I)'First + 15)
                                      = "--find-renames=")
                  then
                     Rename_Mode := Version.Diff.Renames_On;
                     Rename_Score :=
                       Parse_Rename_Score
                         (if Arg (I) (Arg (I)'First + 1) = 'M'
                          then Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last)
                          else Arg (I) (Arg (I)'First + 15 .. Arg (I)'Last));
                  elsif Arg (I) = "--name-only" then
                     Name_Only := True;
                  elsif Arg (I) = "--name-status" then
                     Name_Status := True;
                  elsif Arg (I)'Length > 2
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "-U"
                  then
                     begin
                        Context := Natural'Value
                          (Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last));
                     exception
                        when others =>
                           Usage_Error
                             ("invalid context length: " & Arg (I), Usage);
                           return;
                     end;
                  elsif Arg (I)'Length > 10
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 9)
                             = "--unified="
                  then
                     begin
                        Context := Natural'Value
                          (Arg (I) (Arg (I)'First + 10 .. Arg (I)'Last));
                     exception
                        when others =>
                           Usage_Error
                             ("invalid context length: " & Arg (I), Usage);
                           return;
                     end;
                  else
                     LCount := LCount + 1;
                     LArgs (LCount) := To_Unbounded_String (Arg (I));
                  end if;
               end loop;
               Opts := (Stat => Stat,
                        Name_Only => Name_Only,
                        Name_Status => Name_Status,
                        Context_Lines => Context,
                        Detect_Renames => Rename_Mode,
                        Rename_Score => Rename_Score,
                        others => <>);

               if LCount = 1 then
                  Version.Console.Put
                    (Version.Diff.Diff_Working_Tree
                       (Version.Repository.Open, Opts));
               elsif LArg (2) = "--staged" or else LArg (2) = "--cached" then
                  Path_First := 3;
                  if LCount >= Path_First then
                     for I in Path_First .. LCount loop
                        if LArg (I) = "--" then
                           if Has_Separator then
                              Usage_Error ("duplicate option: --", Usage);
                              return;
                           end if;
                           Has_Separator := True;
                        elsif not Has_Separator
                          and then LArg (I)'Length > 0
                          and then LArg (I) (LArg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown diff option: " & LArg (I), Usage);
                           return;
                        end if;
                     end loop;
                  end if;

                  if Has_Separator and then not LHas_Path (Path_First) then
                     Usage_Error ("missing diff pathspec", Usage);
                     return;
                  elsif LCount < Path_First or else not LHas_Path (Path_First)
                  then
                     Version.Console.Put
                       (Version.Diff.Diff_Staged
                          (Version.Repository.Open, Opts));
                  else
                     Version.Console.Put
                       (Version.Diff.Diff_Staged
                          (Version.Repository.Open,
                           LPathspecs (Path_First), Opts));
                  end if;
               elsif LArg (2) = "--" then
                  Has_Separator := True;
                  Path_First := 3;
                  if not LHas_Path (Path_First) then
                     Usage_Error ("missing diff pathspec", Usage);
                     return;
                  end if;
                  Version.Console.Put
                    (Version.Diff.Diff_Working_Tree
                       (Version.Repository.Open,
                        LPathspecs (Path_First), Opts));
               elsif LArg (2)'Length > 0 and then LArg (2) (LArg (2)'First) = '-'
               then
                  Usage_Error ("unknown diff option: " & LArg (2), Usage);
                  return;
               elsif LCount = 2 then
                  --  A single argument is a rev (diff <commit>: that tree
                  --  against the working tree) if it resolves, otherwise a
                  --  pathspec (diff <path>).  git's DWIM; we used to always
                  --  treat it as a pathspec, so `diff HEAD~1` printed nothing.
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Tree   : Version.Objects.Hex_Object_Id :=
                       Version.Objects.Zero_Object_Id;
                     Is_Rev : Boolean := False;
                  begin
                     begin
                        Tree := Version.Revisions.Resolve_Tree (Repo, LArg (2));
                        Is_Rev := True;
                     exception
                        when Ada.IO_Exceptions.Data_Error | Constraint_Error =>
                           Is_Rev := False;
                     end;
                     if Is_Rev then
                        Version.Console.Put
                          (Version.Diff.Diff_Tree_Vs_Working
                             (Repo, Tree, Opts));
                     else
                        Version.Console.Put
                          (Version.Diff.Diff_Working_Tree
                             (Repo, LPathspecs (2), Opts));
                     end if;
                  end;
               elsif LCount = 3 then
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
                          Version.Revisions.Resolve_Commit (Repo, LArg (2));
                        New_Id :=
                          Version.Revisions.Resolve_Commit (Repo, LArg (3));
                        Revisions_Resolved := True;
                     exception
                        when Ada.IO_Exceptions.Data_Error | Constraint_Error =>
                           Revisions_Resolved := False;
                     end;

                     if Revisions_Resolved then
                        Version.Console.Put
                          (Version.Diff.Diff_Commits
                             (Repo, Old_Id, New_Id, Opts));
                     else
                        Version.Console.Put
                          (Version.Diff.Diff_Working_Tree
                             (Repo, LPathspecs (2), Opts));
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
                 "version log [--oneline] [--stat] [--show-signature]"
                 & " [--format=<fmt>] [-<n>|-n <count>|--max-count=<n>] [REV]";
               Oneline    : Boolean := False;
               Show_Sig   : Boolean := False;
               Rev        : Unbounded_String;
               Have_Rev   : Boolean := False;
               Bad        : Boolean := False;
               Max_Count  : Natural := 0;
               Max_Prefix : constant String := "--max-count=";
               Want_Count : Boolean := False;
               Format     : Unbounded_String;
               Has_Format : Boolean := False;
               Terminator : Boolean := True;
               Stat       : Boolean := False;
               Patch      : Boolean := False;
               Context    : Natural := 3;

               function Starts (S, P : String) return Boolean is
                 (S'Length >= P'Length
                  and then S (S'First .. S'First + P'Length - 1) = P);
               function After (S, P : String) return String is
                 (S (S'First + P'Length .. S'Last));

               function All_Digits (S : String) return Boolean is
               begin
                  if S'Length = 0 then
                     return False;
                  end if;
                  for C of S loop
                     if C not in '0' .. '9' then
                        return False;
                     end if;
                  end loop;
                  return True;
               end All_Digits;
            begin
               for I in 2 .. Count loop
                  if Want_Count then
                     if All_Digits (Arg (I)) then
                        Max_Count := Natural'Value (Arg (I));
                        Want_Count := False;
                     else
                        Usage_Error
                          ("log -n requires a count: " & Arg (I), Usage);
                        Bad := True;
                        exit;
                     end if;
                  elsif Arg (I) = "--oneline" then
                     Oneline := True;
                  elsif Arg (I) = "--stat" then
                     Stat := True;
                  elsif Arg (I) = "--show-signature" then
                     Show_Sig := True;
                  elsif Starts (Arg (I), "--format=") then
                     Format := To_Unbounded_String (After (Arg (I), "--format="));
                     Has_Format := True;
                     Terminator := True;
                  elsif Starts (Arg (I), "--pretty=tformat:") then
                     Format :=
                       To_Unbounded_String (After (Arg (I), "--pretty=tformat:"));
                     Has_Format := True;
                     Terminator := True;
                  elsif Starts (Arg (I), "--pretty=format:") then
                     Format :=
                       To_Unbounded_String (After (Arg (I), "--pretty=format:"));
                     Has_Format := True;
                     Terminator := False;
                  elsif Arg (I) = "-p" or else Arg (I) = "--patch" then
                     Patch := True;
                  elsif Arg (I)'Length > 2
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "-U"
                    and then All_Digits
                               (Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last))
                  then
                     Context := Natural'Value
                       (Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last));
                     Patch := True;
                  elsif Starts (Arg (I), "--unified=")
                    and then All_Digits (After (Arg (I), "--unified="))
                  then
                     Context := Natural'Value (After (Arg (I), "--unified="));
                     Patch := True;
                  elsif Arg (I) = "-n" then
                     Want_Count := True;
                  elsif Arg (I)'Length > Max_Prefix'Length
                    and then Arg (I) (Arg (I)'First ..
                                        Arg (I)'First + Max_Prefix'Length - 1)
                             = Max_Prefix
                    and then All_Digits
                               (Arg (I) (Arg (I)'First + Max_Prefix'Length
                                         .. Arg (I)'Last))
                  then
                     Max_Count :=
                       Natural'Value
                         (Arg (I) (Arg (I)'First + Max_Prefix'Length
                                   .. Arg (I)'Last));
                  elsif Arg (I)'Length >= 2
                    and then Arg (I) (Arg (I)'First) = '-'
                    and then All_Digits
                               (Arg (I) (Arg (I)'First + 1 .. Arg (I)'Last))
                  then
                     Max_Count :=
                       Natural'Value
                         (Arg (I) (Arg (I)'First + 1 .. Arg (I)'Last));
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

               if Want_Count and then not Bad then
                  Usage_Error ("log -n requires a count", Usage);
                  Bad := True;
               end if;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Has_Format then
                        declare
                           Tip : constant Version.Objects.Hex_Object_Id :=
                             (if Have_Rev
                              then Version.Revisions.Resolve_Commit
                                     (Repo, To_String (Rev))
                              else Version.Objects.To_Object_Id
                                     (Version.Refs.Current_Commit_Id (Repo)));
                        begin
                           Version.Console.Put
                             (Version.Log.Log_Formatted_From_Commit
                                (Repo, Tip, To_String (Format),
                                 Terminate_Records => Terminator,
                                 Max_Count         => Max_Count));
                        end;
                     elsif Oneline and then Have_Rev then
                        Version.Console.Put
                          (Version.Log.Log_Oneline_From_Commit
                             (Repo,
                              Version.Revisions.Resolve_Commit
                                (Repo, To_String (Rev)),
                              Max_Count => Max_Count));
                     elsif Oneline then
                        Version.Console.Put
                          (Version.Log.Log_Oneline_Head
                             (Repo, Max_Count => Max_Count));
                     elsif Have_Rev then
                        Version.Console.Put
                          (Version.Log.Log_From_Commit
                             (Repo,
                              Version.Revisions.Resolve_Commit
                                (Repo, To_String (Rev)),
                              Show_Signature => Show_Sig,
                              Max_Count      => Max_Count,
                              Stat           => Stat,
                              Patch          => Patch,
                              Context        => Context));
                     else
                        Version.Console.Put
                          (Version.Log.Log_Head
                             (Repo, Show_Signature => Show_Sig,
                              Max_Count => Max_Count,
                              Stat      => Stat,
                              Patch     => Patch,
                              Context   => Context));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "show" then
            declare
               Usage    : constant String := "version show [--stat] [REV]";
               Stat     : Boolean := False;
               Rev      : Unbounded_String := To_Unbounded_String ("HEAD");
               Have_Rev : Boolean := False;
               Bad      : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--stat" then
                     Stat := True;
                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown show option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  elsif not Have_Rev then
                     Rev := To_Unbounded_String (Arg (I));
                     Have_Rev := True;
                  else
                     Usage_Error ("too many show arguments", Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Opts : constant Version.Diff.Diff_Options :=
                       (Stat => Stat, others => <>);
                     Spec  : constant String := To_String (Rev);
                     Colon : constant Natural :=
                       Ada.Strings.Fixed.Index (Spec, ":");
                  begin
                     --  `show <rev>:<path>`: the object at that path, not the
                     --  commit -- a blob's contents verbatim, or git's listing
                     --  for a tree.
                     if Colon > Spec'First then
                        declare
                           Rev_Part  : constant String :=
                             Spec (Spec'First .. Colon - 1);
                           Path_Part : constant String :=
                             Spec (Colon + 1 .. Spec'Last);
                           Tree_Id : constant Version.Objects.Hex_Object_Id :=
                             Version.Revisions.Resolve_Tree (Repo, Rev_Part);
                           Items : constant
                             Version.Objects.Tree_Entry_Vectors.Vector :=
                               Version.Objects.Flatten_Tree (Repo, Tree_Id);
                           Found : Boolean := False;
                           Listing : Unbounded_String;
                        begin
                           for E of Items loop
                              if To_String (E.Path) = Path_Part then
                                 Version.Console.Put
                                   (Version.Objects.Content
                                      (Version.Objects.Read_Object
                                         (Repo, E.Id)));
                                 Found := True;
                                 exit;
                              end if;
                           end loop;

                           if not Found then
                              --  A directory: git prints `tree <spec>` then the
                              --  entries directly under it.
                              declare
                                 Prefix : constant String := Path_Part & "/";
                                 Seen   : Version.Trailers.String_Vectors.Vector;
                              begin
                                 for E of Items loop
                                    declare
                                       P : constant String := To_String (E.Path);
                                    begin
                                       if P'Length > Prefix'Length
                                         and then P (P'First .. P'First
                                                     + Prefix'Length - 1)
                                                  = Prefix
                                       then
                                          declare
                                             Rest : constant String :=
                                               P (P'First + Prefix'Length
                                                  .. P'Last);
                                             Slash : constant Natural :=
                                               Ada.Strings.Fixed.Index
                                                 (Rest, "/");
                                             Name : constant String :=
                                               (if Slash = 0 then Rest
                                                else Rest (Rest'First
                                                           .. Slash - 1) & "/");
                                             Dup : Boolean := False;
                                          begin
                                             for X of Seen loop
                                                if X = Name then
                                                   Dup := True;
                                                end if;
                                             end loop;
                                             if not Dup then
                                                Seen.Append (Name);
                                                Append (Listing,
                                                        Name & ASCII.LF);
                                             end if;
                                             Found := True;
                                          end;
                                       end if;
                                    end;
                                 end loop;

                                 if Found then
                                    Version.Console.Put
                                      ("tree " & Spec & ASCII.LF & ASCII.LF
                                       & To_String (Listing));
                                 else
                                    Error_Line
                                      ("path does not exist in "
                                       & Rev_Part & ": " & Path_Part);
                                    Set_Command_Failure;
                                 end if;
                              end;
                           end if;
                        end;
                     else
                        Version.Console.Put
                          (Version.Show.Show_Commit
                             (Repo,
                              Version.Show.Resolve_Revision (Repo, Spec),
                              Opts));
                     end if;
                  end;
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

               declare
                  --  git reports "Reinitialized" when the repository already
                  --  exists; version keeps its own house wording but likewise
                  --  distinguishes a fresh init from a reinit.
                  Reinit : constant Boolean :=
                    (if Bare
                     then Version.Files.Is_Directory
                            (Version.Files.Join (To_String (Target), "objects"))
                     else Version.Files.Is_Directory
                            (Version.Files.Join (To_String (Target), ".git")));
                  Verb : constant String :=
                    (if Reinit then "reinitialized" else "initialized");
               begin
                  if Bare then
                     Version.Init.Init_Bare
                       (To_String (Target), Object_Format, Ref_Storage);
                     Success_Line
                       (Verb & " bare repository in " & To_String (Target));
                  else
                     Version.Init.Init
                       (To_String (Target), Object_Format, Ref_Storage);
                     Success_Line
                       (Verb & " repository in " & To_String (Target));
                  end if;
               end;
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
                 "version save [--amend] [--no-verify] [-S[<keyid>]]"
                 & " [--no-gpg-sign] [-m] MESSAGE";
               I          : Natural := 2;
               Amend      : Boolean := False;
               No_Verify  : Boolean := False;
               Message    : Unbounded_String;
               Has_Message : Boolean := False;
               Used_M     : Boolean := False;
               Sign        : Version.Write.Sign_Choice :=
                 Version.Write.Sign_From_Config;
               Signing_Key : Unbounded_String;
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

                  elsif Arg (I) = "-S" or else Arg (I) = "--gpg-sign" then
                     Sign := Version.Write.Sign_Force;
                     Signing_Key := Null_Unbounded_String;
                     I := I + 1;

                  elsif Arg (I)'Length > 2
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "-S"
                  then
                     Sign := Version.Write.Sign_Force;
                     Signing_Key :=
                       To_Unbounded_String
                         (Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last));
                     I := I + 1;

                  elsif Arg (I)'Length > 11
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 10)
                             = "--gpg-sign="
                  then
                     Sign := Version.Write.Sign_Force;
                     Signing_Key :=
                       To_Unbounded_String
                         (Arg (I) (Arg (I)'First + 11 .. Arg (I)'Last));
                     I := I + 1;

                  elsif Arg (I) = "--no-gpg-sign" then
                     Sign := Version.Write.Sign_Disable;
                     Signing_Key := Null_Unbounded_String;
                     I := I + 1;

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
                    (Message     => To_String (Message),
                     Run_Hooks   => not No_Verify,
                     Sign        => Sign,
                     Signing_Key => To_String (Signing_Key));
               else
                  Version.Write.Save
                    (Message     => To_String (Message),
                     Run_Hooks   => not No_Verify,
                     Sign        => Sign,
                     Signing_Key => To_String (Signing_Key));
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
                  --  Bare `branch` lists branches, like git.
                  Print_Branch_List;
               elsif Count = 2
                 and then (Arg (2) = "-v" or else Arg (2) = "-vv"
                           or else Arg (2) = "--verbose")
               then
                  Version.Console.Put
                    (Version.Branch.List_Branches_Verbose_Text);
               elsif Count = 2
                 and then (Arg (2) = "-a" or else Arg (2) = "--all"
                           or else Arg (2) = "-r" or else Arg (2) = "--remotes")
               then
                  --  git -a/-r also lists remote-tracking branches; with none
                  --  present this equals the local listing.
                  Print_Branch_List;
               elsif Arg (2) = "list" then
                  if Count = 2 then
                     Print_Branch_List;
                  elsif Arg (3) = "--verbose" then
                     if Count = 3 then
                        Version.Console.Put
                          (Version.Branch.List_Branches_Verbose_Text);
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
                     --  git's merge.stat defaults to true.
                     return True;
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
               begin
                  --  git shows `--stat --summary` of ORIG_HEAD..HEAD after a
                  --  merge / fast-forward.
                  return Version.Diff.Diff_Commits
                    (Repo    => Repo,
                     Old_Id  => Before_Id,
                     New_Id  => After_Id,
                     Options =>
                       (Context_Lines => 3, Stat => True, Summary => True, others => <>));
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
                        Last      : Natural := Stat_Text'Last;
                     begin
                        --  Trim the block's trailing newline; Success_Line adds
                        --  one back so the multi-line stat prints byte-exactly.
                        if Last >= Stat_Text'First
                          and then Stat_Text (Last) = Character'Val (10)
                        then
                           Last := Last - 1;
                        end if;
                        if Last >= Stat_Text'First then
                           Success_Line (Stat_Text (Stat_Text'First .. Last));
                        end if;
                     end;
                  end if;
               end Print_Merge_Stat_If_Requested;

               --  git's fast-forward headline "Updating <old>..<new>" using
               --  the shortest-unique abbreviation (7-char floor) for each id.
               procedure Print_Merge_Updating
                 (Before_Id : Version.Objects.Hex_Object_Id)
               is
                  Repo       : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  After_Text : constant String :=
                    Version.Refs.Current_Commit_Id (Repo);
                  Old_Full   : constant String := To_String (Before_Id);
               begin
                  if not Version.Objects.Is_Valid_Hex_Object_Id (After_Text)
                    or else not Version.Objects.Is_Valid_Hex_Object_Id (Old_Full)
                  then
                     return;
                  end if;

                  declare
                     After_Id : constant Version.Objects.Hex_Object_Id :=
                       Version.Objects.To_Object_Id (After_Text);
                     OL : constant Natural :=
                       Version.Revisions.Unique_Abbrev_Length
                         (Repo, Before_Id, 7);
                     NL : constant Natural :=
                       Version.Revisions.Unique_Abbrev_Length
                         (Repo, After_Id, 7);
                  begin
                     Success_Line
                       ("Updating "
                        & Old_Full (Old_Full'First .. Old_Full'First + OL - 1)
                        & ".."
                        & After_Text
                            (After_Text'First .. After_Text'First + NL - 1));
                  end;
               end Print_Merge_Updating;

               --  git-merge-octopus progress narration: from the pre-merge
               --  HEAD, fast-forward through leading ancestor targets, then
               --  "trying simple merge" for the rest (matching git's steps).
               procedure Print_Octopus_Progress
                 (Before_Id : Version.Objects.Hex_Object_Id;
                  Targets   : Version.Branch.Merge_Target_Vectors.Vector)
               is
                  Repo   : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  MRC    : Version.Objects.Hex_Object_Id := Before_Id;
                  Non_FF : Boolean := False;
               begin
                  for I in Targets.First_Index .. Targets.Last_Index loop
                     declare
                        Name     : constant String :=
                          To_String (Targets.Element (I));
                        Resolved : Boolean := True;
                        SHA1     : Version.Objects.Hex_Object_Id :=
                          Version.Objects.Zero_Object_Id;
                     begin
                        begin
                           SHA1 := Version.Revisions.Resolve_Commit (Repo, Name);
                        exception
                           when Ada.IO_Exceptions.Data_Error
                              | Constraint_Error =>
                              Resolved := False;
                        end;

                        if Resolved then
                           if Version.History.Is_Ancestor
                                (Repo, Base_Id => SHA1, Derived_Id => MRC)
                           then
                              Success_Line ("Already up to date with " & Name);
                           elsif not Non_FF
                             and then Version.History.Is_Ancestor
                                        (Repo, Base_Id => MRC,
                                         Derived_Id => SHA1)
                           then
                              Success_Line ("Fast-forwarding to: " & Name);
                              MRC := SHA1;
                           else
                              Non_FF := True;
                              Success_Line ("Trying simple merge with " & Name);
                           end if;
                        end if;
                     end;
                  end loop;
               end Print_Octopus_Progress;

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
                  --  git prints "Auto-merging X" only when it runs the
                  --  content three-way merge on X (both sides changed the
                  --  content). A modify/delete, rename/delete, or
                  --  file/directory collision has no content merge, so no line.
                  return Item.Kind /= Version.Merge.Delete_Modify_Conflict
                    and then Item.Kind /= Version.Merge.Directory_File_Conflict
                    and then not Is_Rename_Delete_Diagnostic
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
                        --  The engine renamed the losing file to
                        --  "<original>~<label>"; label is HEAD for a stage-2
                        --  entry, else the target label.
                        declare
                           In_Stage_2 : constant Boolean :=
                             Has_Conflict_Stage (Entries, Path, 2);
                           Label      : constant String :=
                             (if In_Stage_2 then "HEAD" else Target_Label);
                           Suffix     : constant String := "~" & Label;
                           Original   : constant String :=
                             (if Path'Length > Suffix'Length
                                and then Path (Path'Last - Suffix'Length + 1
                                               .. Path'Last) = Suffix
                              then Path (Path'First .. Path'Last - Suffix'Length)
                              else Path);
                        begin
                           Put_Merge_Diagnostic
                             ("CONFLICT (file/directory): directory in the way of "
                              & Original & " from " & Label
                              & "; moving it to " & Path & " instead.");
                        end;
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
               Last_Merge_Before_Id : Version.Objects.Hex_Object_Id :=
                 Version.Objects.Zero_Object_Id;
               Last_Merge_Before_Valid : Boolean := False;

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

                  --  git prints "Auto-merging <path>" for every path it runs
                  --  the three-way content merge on -- clean ones included.
                  --  The conflicted ones are announced in the loop below, so
                  --  only the cleanly merged paths are left to report here.
                  declare
                     Base_Items : constant
                       Version.Objects.Tree_Entry_Vectors.Vector :=
                         Version.Objects.Flatten_Tree
                           (Repo    => Repo,
                            Tree_Id => Commit_Tree_Id (Repo, Base_Id));
                     Ours_Items : constant
                       Version.Objects.Tree_Entry_Vectors.Vector :=
                         Version.Objects.Flatten_Tree
                           (Repo    => Repo,
                            Tree_Id => Commit_Tree_Id (Repo, Current_Id));
                     Theirs_Items : constant
                       Version.Objects.Tree_Entry_Vectors.Vector :=
                         Version.Objects.Flatten_Tree
                           (Repo    => Repo,
                            Tree_Id => Commit_Tree_Id (Repo, Target_Id));

                     function Blob_Of
                       (Items : Version.Objects.Tree_Entry_Vectors.Vector;
                        Path  : String;
                        Found : out Boolean) return String is
                     begin
                        Found := False;
                        for I in Items.First_Index .. Items.Last_Index loop
                           if To_String (Items.Element (I).Path) = Path then
                              Found := True;
                              return Version.Objects.To_String
                                (Items.Element (I).Id);
                           end if;
                        end loop;
                        return "";
                     end Blob_Of;

                     function Is_Conflicted (Path : String) return Boolean is
                     begin
                        for I in Conflicts.First_Index .. Conflicts.Last_Index
                        loop
                           if To_String (Conflicts.Element (I).Path) = Path then
                              return True;
                           end if;
                        end loop;
                        return False;
                     end Is_Conflicted;
                  begin
                     for I in Base_Items.First_Index .. Base_Items.Last_Index
                     loop
                        declare
                           Path : constant String :=
                             To_String (Base_Items.Element (I).Path);
                           Base_Blob : constant String :=
                             Version.Objects.To_String
                               (Base_Items.Element (I).Id);
                           Has_O, Has_T : Boolean;
                           Ours_Blob   : constant String :=
                             Blob_Of (Ours_Items, Path, Has_O);
                           Theirs_Blob : constant String :=
                             Blob_Of (Theirs_Items, Path, Has_T);
                        begin
                           --  Both sides kept the path and both changed it,
                           --  differently: that is exactly when git merges the
                           --  content.
                           if Has_O and then Has_T
                             and then Ours_Blob /= Base_Blob
                             and then Theirs_Blob /= Base_Blob
                             and then Ours_Blob /= Theirs_Blob
                             and then not Is_Conflicted (Path)
                           then
                              Put_Merge_Diagnostic ("Auto-merging " & Path);
                           end if;
                        end;
                     end loop;
                  end;

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

               --  git prints "Auto-merging <path>" for every path whose content
               --  it three-way merges: both sides kept it and both changed it,
               --  differently.  Conflicted paths are announced by the conflict
               --  diagnostics, so Skip_Conflicted leaves those to it.
               procedure Print_Auto_Merged_Paths
                 (Repo       : Version.Repository.Repository_Handle;
                  Ours_Id    : Version.Objects.Hex_Object_Id;
                  Theirs_Id  : Version.Objects.Hex_Object_Id;
                  Base_Id    : Version.Objects.Hex_Object_Id;
                  Conflicted : Version.Merge.Conflict_Vectors.Vector)
               is
                  Base_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, Base_Id));
                  Ours_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, Ours_Id));
                  Theirs_Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo => Repo, Tree_Id => Commit_Tree_Id (Repo, Theirs_Id));

                  function Blob_Of
                    (Items : Version.Objects.Tree_Entry_Vectors.Vector;
                     Path  : String;
                     Found : out Boolean) return String is
                  begin
                     Found := False;
                     for I in Items.First_Index .. Items.Last_Index loop
                        if To_String (Items.Element (I).Path) = Path then
                           Found := True;
                           return Version.Objects.To_String
                             (Items.Element (I).Id);
                        end if;
                     end loop;
                     return "";
                  end Blob_Of;

                  function Is_Conflicted (Path : String) return Boolean is
                  begin
                     for I in Conflicted.First_Index .. Conflicted.Last_Index loop
                        if To_String (Conflicted.Element (I).Path) = Path then
                           return True;
                        end if;
                     end loop;
                     return False;
                  end Is_Conflicted;
               begin
                  for I in Base_Items.First_Index .. Base_Items.Last_Index loop
                     declare
                        Path : constant String :=
                          To_String (Base_Items.Element (I).Path);
                        Base_Blob : constant String :=
                          Version.Objects.To_String (Base_Items.Element (I).Id);
                        Has_O, Has_T : Boolean;
                        Ours_Blob   : constant String :=
                          Blob_Of (Ours_Items, Path, Has_O);
                        Theirs_Blob : constant String :=
                          Blob_Of (Theirs_Items, Path, Has_T);
                     begin
                        if Has_O and then Has_T
                          and then Ours_Blob /= Base_Blob
                          and then Theirs_Blob /= Base_Blob
                          and then Ours_Blob /= Theirs_Blob
                          and then not Is_Conflicted (Path)
                        then
                           Put_Merge_Diagnostic ("Auto-merging " & Path);
                        end if;
                     end;
                  end loop;
               exception
                  when others =>
                     null;   --  diagnostics must never fail a merge
               end Print_Auto_Merged_Paths;

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

                  --  A real (non-fast-forward) merge that came out clean:
                  --  report the paths whose content was merged, as git does.
                  if not Last_Merge_Was_Fast_Forward
                    and then not Last_Merge_Was_Already_Up_To_Date
                  then
                     declare
                        Repo_After : constant
                          Version.Repository.Repository_Handle :=
                            Version.Repository.Open;
                        Theirs_Id : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Commit (Repo_After, Target);
                        Base_Id : constant Version.Objects.Hex_Object_Id :=
                          Version.History.Merge_Base
                            (Repo_After, Before_Id, Theirs_Id);
                        None : Version.Merge.Conflict_Vectors.Vector;
                     begin
                        Print_Auto_Merged_Paths
                          (Repo       => Repo_After,
                           Ours_Id    => Before_Id,
                           Theirs_Id  => Theirs_Id,
                           Base_Id    => Base_Id,
                           Conflicted => None);
                     exception
                        when others =>
                           null;
                     end;
                  end if;

                  --  Stat is emitted by the caller after the headline line, so
                  --  the "Fast-forward"/"Merge made by" text precedes it.
                  Last_Merge_Before_Id := Before_Id;
                  Last_Merge_Before_Valid := True;
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

                  Last_Merge_Before_Id := Before_Id;
                  Last_Merge_Before_Valid := True;
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
                                 Success_Line
                                   ("Automatic merge went well; stopped before committing as requested");
                                 Success_Line ("Squash commit -- not updating HEAD");
                              elsif Options.No_Commit then
                                 Success_Line
                                   ("Automatic merge went well; stopped before committing as requested");
                              elsif Last_Merge_Was_Fast_Forward then
                                 if Last_Merge_Before_Valid then
                                    Print_Merge_Updating (Last_Merge_Before_Id);
                                 end if;
                                 Success_Line ("Fast-forward");
                                 if Last_Merge_Before_Valid then
                                    Print_Merge_Stat_If_Requested
                                      (Options, Last_Merge_Before_Id);
                                 end if;
                              elsif Last_Merge_Was_Already_Up_To_Date then
                                 Success_Line ("Already up to date.");
                              else
                                 Success_Line ("Merge made by the 'ort' strategy.");
                                 if Last_Merge_Before_Valid then
                                    Print_Merge_Stat_If_Requested
                                      (Options, Last_Merge_Before_Id);
                                 end if;
                              end if;
                           end if;
                        end;
                     else
                        if Run_Merge_Multiple
                             (Targets => Targets,
                              Options => Options)
                        then
                           if Last_Merge_Before_Valid then
                              Print_Octopus_Progress
                                (Last_Merge_Before_Id, Targets);
                           end if;
                           if Options.Squash then
                              Success_Line
                                ("Automatic merge went well; stopped before committing as requested");
                              Success_Line ("Squash commit -- not updating HEAD");
                           elsif Options.No_Commit then
                              Success_Line
                                ("Automatic merge went well; stopped before committing as requested");
                           else
                              Success_Line ("Merge made by the 'octopus' strategy.");
                              if Last_Merge_Before_Valid then
                                 Print_Merge_Stat_If_Requested
                                   (Options, Last_Merge_Before_Id);
                              end if;
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

               elsif Arg (2) = "sync" then
                  declare
                     Sync_Usage : constant String :=
                       "version submodule sync [--recursive]";
                     Recursive  : Boolean := False;
                  begin
                     for I in 3 .. Count loop
                        if Arg (I) = "--recursive" then
                           Recursive := True;
                        else
                           Usage_Error
                             ("unknown submodule sync option: " & Arg (I),
                              Sync_Usage);
                           return;
                        end if;
                     end loop;
                     Version.Submodules.Sync (Recursive => Recursive);
                  end;

               elsif Arg (2) = "foreach" then
                  declare
                     Foreach_Usage : constant String :=
                       "version submodule foreach [--recursive] COMMAND";
                     Recursive : Boolean := False;
                     First     : Natural := 3;
                  begin
                     if First <= Count and then Arg (First) = "--recursive" then
                        Recursive := True;
                        First := First + 1;
                     end if;

                     if First > Count then
                        Usage_Error
                          ("missing submodule foreach command", Foreach_Usage);
                        return;
                     end if;

                     --  The remainder of the command line is the shell command
                     --  (git joins the arguments with spaces).
                     declare
                        Command : Unbounded_String;
                     begin
                        for I in First .. Count loop
                           if I > First then
                              Append (Command, " ");
                           end if;
                           Append (Command, Arg (I));
                        end loop;
                        Version.Submodules.Foreach
                          (To_String (Command), Recursive => Recursive);
                     end;
                  end;

               elsif Arg (2) = "deinit" then
                  declare
                     Deinit_Usage : constant String :=
                       "version submodule deinit [--force] [--all|PATH...]";
                     Force : Boolean := False;
                     All_S : Boolean := False;
                     Paths : Version.Submodules.Path_Vectors.Vector;
                  begin
                     for I in 3 .. Count loop
                        if Arg (I) = "--force" or else Arg (I) = "-f" then
                           Force := True;
                        elsif Arg (I) = "--all" then
                           All_S := True;
                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown submodule deinit option: " & Arg (I),
                              Deinit_Usage);
                           return;
                        else
                           Paths.Append (Arg (I));
                        end if;
                     end loop;

                     if All_S and then not Paths.Is_Empty then
                        Usage_Error
                          ("submodule deinit: --all cannot be combined with"
                           & " a path", Deinit_Usage);
                        return;
                     end if;

                     Version.Submodules.Deinit
                       (Paths          => Paths,
                        All_Submodules => All_S,
                        Force          => Force);
                  end;

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

         elsif Command = "sparse" or else Command = "sparse-checkout" then
            declare
               Cmd_Name   : constant String := Command;
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

               --  Parse "[--cone|--no-cone] [--] OPERAND..." for set/add/init.
               procedure Parse_Set_Like
                 (Context, Usage : String;
                  Cone           : in out Boolean;
                  Cone_Explicit  : out Boolean;
                  Operands       : out Version.Sparse.String_Vectors.Vector;
                  OK             : out Boolean)
               is
                  After_Separator : Boolean := False;
               begin
                  Operands      := Version.Sparse.String_Vectors.Empty_Vector;
                  Cone_Explicit := False;
                  OK            := False;

                  for I in 3 .. Count loop
                     declare
                        A : constant String := Arg (I);
                     begin
                        if not After_Separator and then A = "--" then
                           After_Separator := True;
                        elsif not After_Separator and then A = "--cone" then
                           Cone := True;
                           Cone_Explicit := True;
                        elsif not After_Separator and then A = "--no-cone" then
                           Cone := False;
                           Cone_Explicit := True;
                        elsif not After_Separator and then Is_Option (A) then
                           Usage_Error
                             ("unknown sparse " & Context & " option: " & A,
                              Usage);
                           return;
                        else
                           Operands.Append (A);
                        end if;
                     end;
                  end loop;

                  OK := True;
               end Parse_Set_Like;

               procedure Require_Born (Repo : Version.Repository.Repository_Handle)
               is
               begin
                  if Version.Refs.Current_Commit_Id (Repo)'Length = 0 then
                     raise Ada.IO_Exceptions.Data_Error
                       with "cannot update sparse checkout on unborn branch";
                  end if;
               end Require_Born;
            begin
               if Count = 1 then
                  Usage_Error
                    ("missing sparse subcommand",
                     "version " & Cmd_Name & " <subcommand>");
                  return;

               elsif Subcommand = "list" then
                  declare
                     Usage : constant String := "version " & Cmd_Name & " list";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "list", Usage);
                        return;
                     end if;

                     Print_Sparse_List;
                  end;

               elsif Subcommand = "status" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name & " status";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "status", Usage);
                        return;
                     end if;

                     Print_Sparse_Status;
                  end;

               elsif Subcommand = "set" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name
                       & " set [--cone|--no-cone] DIR...";
                     Cone     : Boolean := True;
                     Explicit : Boolean := False;
                     Operands : Version.Sparse.String_Vectors.Vector;
                     OK       : Boolean := False;
                  begin
                     Parse_Set_Like ("set", Usage, Cone, Explicit, Operands, OK);
                     if not OK then
                        return;
                     end if;

                     if not Cone and then Operands.Is_Empty then
                        Usage_Error ("missing sparse pathspec", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse set");
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                     begin
                        Require_Born (Repo);
                        if Cone then
                           Version.Sparse.Set_Cone (Repo, Operands);
                        else
                           Version.Sparse.Set_From_Strings (Repo, Operands);
                        end if;
                        Version.Restore.Restore_Working_Tree (Repo);
                        Version.Restore.Apply_Sparse_Skip_Worktree (Repo);
                     end;
                     Success_Line ("updated sparse checkout");
                  end;

               elsif Subcommand = "add" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name
                       & " add [--cone|--no-cone] DIR...";
                     Cone     : Boolean := True;
                     Explicit : Boolean := False;
                     Added    : Version.Sparse.String_Vectors.Vector;
                     OK       : Boolean := False;
                  begin
                     --  Validate arguments before touching the repository so a
                     --  missing operand / bad option reports cleanly.
                     Parse_Set_Like ("add", Usage, Cone, Explicit, Added, OK);
                     if not OK then
                        return;
                     end if;

                     if Added.Is_Empty then
                        Usage_Error ("missing sparse pathspec", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse add");
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Combined : Version.Sparse.String_Vectors.Vector;
                     begin
                        Require_Born (Repo);

                        --  git's `add` keeps the repository's current mode
                        --  unless overridden by an explicit --cone/--no-cone.
                        if not Explicit then
                           Cone := Version.Sparse.Cone_Mode (Repo);
                        end if;

                        if Cone then
                           if Version.Sparse.Enabled (Repo)
                             and then Version.Sparse.Cone_Mode (Repo)
                           then
                              Combined :=
                                Version.Sparse.Cone_Recursive_Directories (Repo);
                           end if;
                           for D of Added loop
                              Combined.Append (D);
                           end loop;
                           Version.Sparse.Set_Cone (Repo, Combined);
                        else
                           if Version.Sparse.Enabled (Repo) then
                              Combined := Version.Sparse.Pattern_Texts (Repo);
                           end if;
                           for P of Added loop
                              Combined.Append (P);
                           end loop;
                           Version.Sparse.Set_From_Strings (Repo, Combined);
                        end if;

                        Version.Restore.Restore_Working_Tree (Repo);
                        Version.Restore.Apply_Sparse_Skip_Worktree (Repo);
                     end;
                     Success_Line ("updated sparse checkout");
                  end;

               elsif Subcommand = "reapply" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name & " reapply";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "reapply", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse reapply");
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                     begin
                        if not Version.Sparse.Enabled (Repo) then
                           raise Ada.IO_Exceptions.Data_Error
                             with "this worktree is not sparse";
                        end if;
                        Version.Restore.Restore_Working_Tree (Repo);
                        Version.Restore.Apply_Sparse_Skip_Worktree (Repo);
                     end;
                     Success_Line ("updated sparse checkout");
                  end;

               elsif Subcommand = "disable" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name & " disable";
                  begin
                     if Count > 2 then
                        Reject_Extra (3, "disable", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse disable");
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                     begin
                        Version.Sparse.Disable (Repo);
                        Version.Restore.Restore_Working_Tree (Repo);
                        Version.Restore.Clear_Skip_Worktree (Repo);
                     end;
                     Success_Line ("disabled sparse checkout");
                  end;

               elsif Subcommand = "init" then
                  declare
                     Usage : constant String :=
                       "version " & Cmd_Name & " init [--cone|--no-cone]";
                     Cone     : Boolean := True;
                     Explicit : Boolean := False;
                     Operands : Version.Sparse.String_Vectors.Vector;
                     OK       : Boolean := False;
                  begin
                     Parse_Set_Like ("init", Usage, Cone, Explicit, Operands, OK);
                     if not OK then
                        return;
                     end if;
                     if not Operands.Is_Empty then
                        Reject_Extra (3, "init", Usage);
                        return;
                     end if;

                     Require_Clean_Working_Tree_Including_Sparse_Excluded
                       ("sparse init");
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Dirs : Version.Sparse.String_Vectors.Vector;
                     begin
                        Require_Born (Repo);
                        --  git's deprecated `init` enables sparse using the
                        --  existing patterns, or just the top level if none.
                        if Version.Sparse.Cone_Mode (Repo) then
                           Dirs :=
                             Version.Sparse.Cone_Recursive_Directories (Repo);
                        end if;
                        if Cone then
                           Version.Sparse.Set_Cone (Repo, Dirs);
                        else
                           declare
                              Items : Version.Sparse.String_Vectors.Vector;
                           begin
                              Items.Append ("/*");
                              Version.Sparse.Set_From_Strings (Repo, Items);
                           end;
                        end if;
                        Version.Restore.Restore_Working_Tree (Repo);
                        Version.Restore.Apply_Sparse_Skip_Worktree (Repo);
                     end;
                     Success_Line ("initialized sparse checkout");
                  end;

               elsif Is_Option (Subcommand) then
                  Usage_Error
                    ("unknown sparse option: " & Subcommand,
                     "version " & Cmd_Name & " <subcommand>");
                  return;
               else
                  Usage_Error
                    ("unknown sparse subcommand: " & Subcommand,
                     "version " & Cmd_Name & " <subcommand>");
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
                     Head : constant Version.Refs.Head_Info :=
                       Version.Refs.Read_Head (Repo);
                     --  `checkout <branch>` attaches HEAD to the branch; a
                     --  commit, tag or other revision detaches it, as git does.
                     Is_Branch : constant Boolean :=
                       Version.Refs.Ref_Exists
                         (Repo, "refs/heads/" & Arg (2));
                     Already   : constant Boolean :=
                       Is_Branch
                         and then Version.Refs.Is_Attached (Head)
                         and then Version.Refs.Branch_Name (Head) = Arg (2);
                  begin
                     if Is_Branch then
                        Version.Checkout.Checkout_Commit
                          (Version.Revisions.Resolve_Commit (Repo, Arg (2)),
                           Branch => Arg (2));
                        if Already then
                           Success_Line ("Already on '" & Arg (2) & "'");
                        else
                           Success_Line
                             ("Switched to branch '" & Arg (2) & "'");
                        end if;
                     else
                        Version.Checkout.Checkout_Commit
                          (Version.Revisions.Resolve_Commit (Repo, Arg (2)));
                        Success_Line ("checked out " & Arg (2));
                     end if;
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

         elsif Command = "switch" then
            declare
               Usage : constant String :=
                 "version switch [-c|-C <new-branch>] [--detach]"
                 & " (<branch>|<start-point>|-)";
               Create   : Boolean := False;
               Detach   : Boolean := False;
               New_Name : Ada.Strings.Unbounded.Unbounded_String;
               Target   : Ada.Strings.Unbounded.Unbounded_String;
               Has_Tgt  : Boolean := False;
               Bad      : Boolean := False;
               I        : Positive := 2;

               function Previous_Branch
                 (Repo : Version.Repository.Repository_Handle) return String
               is
                  Entries :
                    constant Version.Reflog.Log_Entry_Vectors.Vector :=
                      Version.Reflog.Read_Entries (Repo, "HEAD");
               begin
                  --  git names "-" from the newest HEAD reflog entry, whose
                  --  message is "... moving from <from> to <to>". version's
                  --  own switch writes the same "moving from X to Y" shape,
                  --  so this parse works for both git- and version-made logs.
                  if not Entries.Is_Empty then
                     declare
                        M   : constant String :=
                          Ada.Strings.Unbounded.To_String
                            (Entries.Last_Element.Message);
                        Key : constant String := "moving from ";
                        F   : Natural := 0;
                        T   : Natural := 0;
                     begin
                        for P in M'First .. M'Last - Key'Length + 1 loop
                           if M (P .. P + Key'Length - 1) = Key then
                              F := P + Key'Length;
                              exit;
                           end if;
                        end loop;
                        if F /= 0 then
                           for P in reverse F .. M'Last - 3 loop
                              if M (P .. P + 3) = " to " then
                                 T := P;
                                 exit;
                              end if;
                           end loop;
                           if T /= 0 then
                              return M (F .. T - 1);
                           end if;
                        end if;
                     end;
                  end if;
                  raise Ada.IO_Exceptions.Data_Error
                    with "switch: no previous branch to switch to";
               end Previous_Branch;
            begin
               while I <= Count and then not Bad loop
                  if Arg (I) = "-c" or else Arg (I) = "-C" then
                     if I = Count then
                        Usage_Error
                          ("switch -c requires a branch name", Usage);
                        Bad := True;
                     else
                        Create   := True;
                        New_Name :=
                          Ada.Strings.Unbounded.To_Unbounded_String
                            (Arg (I + 1));
                        I := I + 2;
                     end if;
                  elsif Arg (I) = "--detach" or else Arg (I) = "-d" then
                     Detach := True;
                     I      := I + 1;
                  elsif Arg (I) = "-" then
                     Target  := Ada.Strings.Unbounded.To_Unbounded_String ("-");
                     Has_Tgt := True;
                     I       := I + 1;
                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown switch option: " & Arg (I), Usage);
                     Bad := True;
                  elsif not Has_Tgt then
                     Target  :=
                       Ada.Strings.Unbounded.To_Unbounded_String (Arg (I));
                     Has_Tgt := True;
                     I       := I + 1;
                  else
                     Usage_Error ("too many switch arguments", Usage);
                     Bad := True;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Prev_Detached : constant Boolean :=
                       Version.Refs.Is_Detached (Repo);
                     Tgt  : constant String :=
                       (if Has_Tgt
                          and then Ada.Strings.Unbounded.To_String (Target) = "-"
                        then Previous_Branch (Repo)
                        elsif Has_Tgt
                        then Ada.Strings.Unbounded.To_String (Target)
                        elsif Detach then "HEAD"
                        else "");

                     procedure Note_Previous is
                     begin
                        --  git announces the abandoned commit whenever a switch
                        --  leaves a detached HEAD, before the destination line.
                        if Prev_Detached then
                           declare
                              P   : constant Version.Objects.Hex_Object_Id :=
                                Version.Refs.Detached_Commit_Id (Repo);
                              Hex : constant String :=
                                Version.Objects.To_String (P);
                              Obj : constant Version.Objects.Git_Object :=
                                Version.Objects.Read_Object (Repo, P);
                           begin
                              Success_Line
                                ("Previous HEAD position was "
                                 & Hex (Hex'First .. Hex'First + 6) & " "
                                 & Version.Objects.Commit_Message_First_Line
                                     (Obj));
                           end;
                        end if;
                     end Note_Previous;
                  begin
                     if Create then
                        Note_Previous;
                        if Has_Tgt then
                           Version.Branch.Create_Branch
                             (Ada.Strings.Unbounded.To_String (New_Name),
                              Version.Objects.To_String
                                (Version.Revisions.Resolve_Commit (Repo, Tgt)));
                        else
                           Version.Branch.Create_Branch
                             (Ada.Strings.Unbounded.To_String (New_Name));
                        end if;
                        Version.Branch.Switch_Branch
                          (Ada.Strings.Unbounded.To_String (New_Name));
                        Success_Line
                          ("Switched to a new branch '"
                           & Ada.Strings.Unbounded.To_String (New_Name) & "'");
                     elsif not Has_Tgt and then not Detach then
                        Usage_Error ("switch requires a branch name", Usage);
                     elsif Detach then
                        declare
                           C   : constant Version.Objects.Hex_Object_Id :=
                             Version.Revisions.Resolve_Commit (Repo, Tgt);
                           Hex : constant String :=
                             Version.Objects.To_String (C);
                           Obj : constant Version.Objects.Git_Object :=
                             Version.Objects.Read_Object (Repo, C);
                        begin
                           Note_Previous;
                           Version.Checkout.Checkout_Commit (C);
                           Success_Line
                             ("HEAD is now at "
                              & Hex (Hex'First .. Hex'First + 6) & " "
                              & Version.Objects.Commit_Message_First_Line (Obj));
                        end;
                     else
                        Note_Previous;
                        Version.Branch.Switch_Branch (Tgt);
                        Success_Line ("Switched to branch '" & Tgt & "'");
                     end if;
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

                     --  Move a source to a destination. When the source is a
                     --  tracked directory git renames every tracked file under
                     --  it (to Dest/<rest>), removing the now-empty source
                     --  directory; a file source moves as a single path.
                     --  Remove Dir and its subdirectories if they hold no
                     --  files after the move (git leaves no empty source
                     --  directory behind); a directory with any leftover
                     --  (untracked) content is kept.
                     function Prune_Empty (Dir : String) return Boolean is
                        Search   : Ada.Directories.Search_Type;
                        Ent      : Ada.Directories.Directory_Entry_Type;
                        Any_Left : Boolean := False;
                     begin
                        Ada.Directories.Start_Search
                          (Search, Dir, "",
                           [Ada.Directories.Directory => True,
                            Ada.Directories.Ordinary_File => True,
                            Ada.Directories.Special_File => True]);
                        while Ada.Directories.More_Entries (Search) loop
                           Ada.Directories.Get_Next_Entry (Search, Ent);
                           declare
                              Nm : constant String :=
                                Ada.Directories.Simple_Name (Ent);
                           begin
                              if Nm /= "." and then Nm /= ".." then
                                 if Ada.Directories.Kind (Ent)
                                    = Ada.Directories.Directory
                                   and then Prune_Empty
                                              (Version.Files.Join (Dir, Nm))
                                 then
                                    null;  --  subdirectory removed
                                 else
                                    Any_Left := True;
                                 end if;
                              end if;
                           end;
                        end loop;
                        Ada.Directories.End_Search (Search);

                        if not Any_Left then
                           Ada.Directories.Delete_Directory (Dir);
                           return True;
                        end if;
                        return False;
                     end Prune_Empty;

                     procedure Move_Source (Src, Dest : String) is
                        Src_Is_Dir : constant Boolean :=
                          Ada.Directories.Exists (Src)
                          and then Ada.Directories.Kind (Src)
                                   = Ada.Directories.Directory;
                     begin
                        if Src_Is_Dir then
                           declare
                              Prefix  : constant String := Src & "/";
                              Sources : Version.Trailers.String_Vectors.Vector;
                           begin
                              --  Snapshot first: Move_Path mutates the index.
                              for E of Version.Staging.Load (Repo) loop
                                 if E.Stage = 0 then
                                    declare
                                       P : constant String :=
                                         To_String (E.Path);
                                    begin
                                       if P'Length > Prefix'Length
                                         and then P (P'First ..
                                                     P'First + Prefix'Length - 1)
                                                  = Prefix
                                       then
                                          Sources.Append (P);
                                       end if;
                                    end;
                                 end if;
                              end loop;

                              for P of Sources loop
                                 Version.Move.Move_Path
                                   (Repo, P,
                                    Version.Files.Join
                                      (Dest,
                                       P (P'First + Prefix'Length .. P'Last)),
                                    Force);
                              end loop;

                              --  Drop the emptied source directory tree.
                              if Ada.Directories.Exists (Src) then
                                 declare
                                    Ignore : constant Boolean :=
                                      Prune_Empty (Src);
                                 begin
                                    null;
                                 end;
                              end if;
                           end;
                        else
                           Version.Move.Move_Path (Repo, Src, Dest, Force);
                        end if;
                     end Move_Source;
                  begin
                     if Count - I + 1 = 2 and then not Dst_Is_Dir then
                        Move_Source (Arg (I), Arg (Count));
                     elsif not Dst_Is_Dir then
                        Usage_Error
                          ("destination must be a directory when moving "
                           & "multiple sources", Usage);
                     else
                        for J in I .. Count - 1 loop
                           --  Into an existing directory: source keeps its
                           --  own name under it (git moves `d` to `dir/d`).
                           Move_Source
                             (Arg (J),
                              Version.Files.Join
                                (Last, Ada.Directories.Simple_Name (Arg (J))));
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
                     when 'f' => Force := True; Opts.Force := Opts.Force + 1;
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
                        Opts.Force := Opts.Force + 1;
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
                 "version apply [--check] [-R] [-p<n>] [--index] [--cached]"
                 & " [PATCHFILE]";
               Opts     : Version.Apply.Apply_Options;
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
                     Opts.Check := True;
                  elsif Arg (I) = "-R" or else Arg (I) = "--reverse" then
                     Opts.Reverse_Patch := True;
                  elsif Arg (I) = "--index" then
                     Opts.Update_Index := True;
                  elsif Arg (I) = "--cached" then
                     Opts.Cached := True;
                  elsif Arg (I)'Length >= 2
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "-p"
                  then
                     declare
                        Digits_Text : constant String :=
                          Arg (I) (Arg (I)'First + 2 .. Arg (I)'Last);
                     begin
                        Opts.Strip := Natural'Value (Digits_Text);
                     exception
                        when others =>
                           Bad_Opt := True;
                           Bad_Text := To_Unbounded_String (Arg (I));
                           exit;
                     end;
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
                     Version.Apply.Apply_Patch (Repo, Patch_Text, Opts);
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
               Limit    : Natural := 0;   --  -<n>: last n commits
               I        : Positive := 2;

               function All_Digits (S : String) return Boolean is
                 (S'Length > 0
                  and then (for all C of S => C in '0' .. '9'));

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
                     elsif A'Length >= 2 and then A (A'First) = '-'
                       and then All_Digits (A (A'First + 1 .. A'Last))
                     then
                        --  -<n>: format the last n commits (from HEAD, or the
                        --  given revision), like git.
                        Limit := Natural'Value (A (A'First + 1 .. A'Last));
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
               elsif Rev_Idx = 0 and then Limit = 0 then
                  Usage_Error ("format-patch requires a revision", Usage);
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Rev  : constant String :=
                       (if Rev_Idx = 0 then "HEAD" else Arg (Rev_Idx));
                     DD   : Natural := 0;
                  begin
                     for K in Rev'First .. Rev'Last - 1 loop
                        if Rev (K) = '.' and then Rev (K + 1) = '.' then
                           DD := K;
                           exit;
                        end if;
                     end loop;

                     declare
                        Include : Version.History.Commit_Id_Vectors.Vector;
                        Exclude : Version.History.Commit_Id_Vectors.Vector;
                     begin
                        --  git's three spellings: an explicit `<A>..<B>`
                        --  range, a bare `<since>` (which means
                        --  `<since>..HEAD`), and `-<n>` (the last n commits
                        --  ending at HEAD, or at an explicit revision).
                        if DD /= 0 then
                           Exclude.Append
                             (Version.Revisions.Resolve_Commit
                                (Repo, Rev (Rev'First .. DD - 1)));
                           Include.Append
                             (Version.Revisions.Resolve_Commit
                                (Repo, Rev (DD + 2 .. Rev'Last)));
                        elsif Limit = 0 then
                           Exclude.Append
                             (Version.Revisions.Resolve_Commit (Repo, Rev));
                           Include.Append
                             (Version.Objects.To_Object_Id
                                (Version.Refs.Current_Commit_Id (Repo)));
                        else
                           Include.Append
                             (Version.Revisions.Resolve_Commit (Repo, Rev));
                        end if;

                        declare
                           --  format-patch never emits a merge commit, and
                           --  writes oldest first.
                           Commits : constant
                             Version.History.Commit_Id_Vectors.Vector :=
                               Version.History.Rev_List
                                 (Repo, Include, Exclude,
                                  (Max_Count    => Limit,
                                   No_Merges    => True,
                                   First_Parent => False,
                                   Oldest_First => True));
                           Total : constant Natural :=
                             Natural (Commits.Length);
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
                                    --  Byte-exact: Ada.Text_IO.Put would leave the
                                    --  runtime mid-line and GNAT would append a
                                    --  spurious trailing newline at exit.
                                    Version.Console.Put (Patch);
                                    --  git separates consecutive mbox messages
                                    --  with an extra blank line (none after the
                                    --  last).
                                    if N < Total then
                                       Version.Console.Put ([1 => ASCII.LF]);
                                    end if;
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
               Sub : constant String := (if Count >= 2 then Arg (2) else "");
            begin
               declare
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
               begin
                  if Sub = "--continue" or else Sub = "-r"
                    or else Sub = "--resolved"
                  then
                     Version.Am.Continue (Repo);
                  elsif Sub = "--skip" then
                     Version.Am.Skip (Repo);
                  elsif Sub = "--abort" then
                     Version.Am.Abort_Am (Repo);
                  else
                     if Count < 2 then
                        Mailbox := To_Unbounded_String (Read_Stdin);
                     else
                        for J in 2 .. Count loop
                           Append
                             (Mailbox,
                              Version.Files.Read_Binary_File (Arg (J)));
                        end loop;
                     end if;
                     Version.Am.Apply_Mailbox (Repo, To_String (Mailbox));
                  end if;
               exception
                  when E : Version.Am.Am_Conflict =>
                     Error_Line (Ada.Exceptions.Exception_Message (E));
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "When you have resolved this problem, run"
                        & " ""version am --continue"".");
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "If you prefer to skip this patch, run"
                        & " ""version am --skip"" instead.");
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "To restore the original branch and stop patching,"
                        & " run ""version am --abort"".");
                     Set_Command_Failure;
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
                     if A'Length >= 2 and then A (A'First) = '-'
                       and then A (A'First + 1) /= '-'
                     then
                        --  Short flags, possibly bundled (git accepts -sn).
                        for K in A'First + 1 .. A'Last loop
                           if A (K) = 's' then
                              Summary := True;
                           elsif A (K) = 'n' then
                              By_Count := True;
                           else
                              Bad_Opt := True;
                              Bad_Text := To_Unbounded_String (A);
                           end if;
                        end loop;
                        exit when Bad_Opt;
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

                     --  git -n sorts by descending count, breaking ties by the
                     --  group's (alphabetical) name so the sort is stable.
                     function Fewer
                       (L, R : Version.Shortlog.Author_Group) return Boolean is
                       (if Natural (L.Subjects.Length)
                           /= Natural (R.Subjects.Length)
                        then Natural (L.Subjects.Length)
                             > Natural (R.Subjects.Length)
                        else L.Name < R.Name);
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
               Usage      : constant String :=
                 "version grep [-n] [-c] [-l] [-i] [-w] [-v] [-E|-F|-G|-P]"
                 & " PATTERN [--] [PATH...]";
               Show_Lines : Boolean := False;
               Count_Mode : Boolean := False;
               Files_Mode : Boolean := False;
               Opts       : Version.Grep.Options;
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
                  elsif Arg (I) = "-c" then
                     Count_Mode := True;
                  elsif Arg (I) = "-l" then
                     Files_Mode := True;
                  elsif Arg (I) = "-i" then
                     Opts.Ignore_Case := True;
                  elsif Arg (I) = "-w" then
                     Opts.Word_Match := True;
                  elsif Arg (I) = "-v" then
                     Opts.Invert := True;
                  elsif Arg (I) = "-E" then
                     Opts.Kind := Version.Grep.Extended_Regex;
                  elsif Arg (I) = "-F" then
                     Opts.Kind := Version.Grep.Fixed_String;
                  elsif Arg (I) = "-G" then
                     Opts.Kind := Version.Grep.Basic_Regex;
                  elsif Arg (I) = "-P" then
                     Opts.Kind := Version.Grep.Perl_Regex;
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
               else
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Pathspecs :
                       constant Version.Pathspec.Pathspec_Vectors.Vector :=
                         Pathspecs_From_Args (Pat_Idx + 1);
                     Matches : constant Version.Grep.Match_Vectors.Vector :=
                       Version.Grep.Search
                         (Repo, Arg (Pat_Idx), Opts, Pathspecs);
                  begin
                     if Files_Mode then
                        --  git -l: each matching file once, in match order.
                        declare
                           Prev : Unbounded_String;
                           Seen : Boolean := False;
                        begin
                           for M of Matches loop
                              if not Seen or else M.Path /= Prev then
                                 Success_Line (To_String (M.Path));
                                 Prev := M.Path;
                                 Seen := True;
                              end if;
                           end loop;
                        end;
                     elsif Count_Mode then
                        --  git -c: "<path>:<count>" per file with matches.
                        declare
                           Prev  : Unbounded_String;
                           Cnt   : Natural := 0;
                           Seen  : Boolean := False;
                           procedure Flush is
                           begin
                              if Seen then
                                 Success_Line
                                   (To_String (Prev) & ":" & Img (Cnt));
                              end if;
                           end Flush;
                        begin
                           for M of Matches loop
                              if not Seen or else M.Path /= Prev then
                                 Flush;
                                 Prev := M.Path;
                                 Cnt := 0;
                                 Seen := True;
                              end if;
                              Cnt := Cnt + 1;
                           end loop;
                           Flush;
                        end;
                     else
                        declare
                           Prev_Bin : Unbounded_String;
                           Bin_Seen : Boolean := False;
                        begin
                           for M of Matches loop
                              if M.Binary then
                                 --  git prints one "Binary file <p> matches"
                                 --  per binary file, never the line content.
                                 if not Bin_Seen or else M.Path /= Prev_Bin then
                                    Success_Line
                                      ("Binary file " & To_String (M.Path)
                                       & " matches");
                                    Prev_Bin := M.Path;
                                    Bin_Seen := True;
                                 end if;
                              elsif Show_Lines then
                                 Success_Line
                                   (To_String (M.Path) & ":" & Img (M.Line_No)
                                    & ":" & To_String (M.Text));
                              else
                                 Success_Line
                                   (To_String (M.Path) & ":"
                                    & To_String (M.Text));
                              end if;
                           end loop;
                        end;
                     end if;
                     if Matches.Is_Empty then
                        Set_Command_Failure;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "describe" then
            declare
               Usage    : constant String := "version describe [--tags] [REV]";
               All_Tags : Boolean := False;
               Rev      : Unbounded_String;
               Has_Rev  : Boolean := False;
               Bad      : Boolean := False;
               I        : Positive := 2;
            begin
               while I <= Count and then not Bad loop
                  if Arg (I) = "--tags" then
                     All_Tags := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown describe option: " & Arg (I), Usage);
                     Bad := True;
                  elsif Has_Rev then
                     Usage_Error ("describe takes at most one revision", Usage);
                     Bad := True;
                  else
                     Rev := To_Unbounded_String (Arg (I));
                     Has_Rev := True;
                  end if;
                  I := I + 1;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Commit : constant Version.Objects.Hex_Object_Id :=
                       (if Has_Rev
                        then Version.Revisions.Resolve_Commit
                               (Repo, To_String (Rev))
                        else Version.Objects.To_Object_Id
                               (Version.Refs.Current_Commit_Id (Repo)));
                  begin
                     Success_Line
                       (Version.Describe.Describe (Repo, Commit, All_Tags));
                  end;
               end if;
            end;

         elsif Command = "notes" then
            declare
               Usage : constant String :=
                 "version notes add [-f] -m MSG [REV]"
                 & " | version notes show [REV]";
            begin
               if Count < 2 then
                  Usage_Error ("notes requires a subcommand", Usage);
               elsif Arg (2) = "add" then
                  declare
                     Msg      : Unbounded_String;
                     Has_Msg  : Boolean := False;
                     Force    : Boolean := False;
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
                           elsif A = "-f" or else A = "--force" then
                              Force := True;
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
                           --  git refuses to add over an existing note unless
                           --  -f/--force is given, and announces the clobber
                           --  on stderr when it is.
                           declare
                              Existing : constant Boolean :=
                                Version.Notes.Show (Repo, Commit) /= "";
                           begin
                              if Existing and then not Force then
                                 Error_Line
                                   ("Cannot add notes. Found existing notes "
                                    & "for object "
                                    & Version.Objects.To_String (Commit)
                                    & ". Use '-f' to overwrite existing notes");
                                 Set_Command_Failure;
                              else
                                 if Existing then
                                    Stderr_Line
                                      ("Overwriting existing notes for object "
                                       & Version.Objects.To_String (Commit));
                                 end if;
                                 Version.Notes.Add
                                   (Repo, Commit, To_String (Msg));
                              end if;
                           end;
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
                        --  Emit the note blob verbatim, like git (which cats
                        --  the note object). Version.Console.Put avoids GNAT
                        --  Text_IO's spurious trailing terminator, which was
                        --  doubling the note's own final newline.
                        Version.Console.Put (Note);
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
               LF    : constant Character := Character'Val (10);

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;

               function Spaces (N : Integer) return String is
                 (if N <= 0 then "" else [1 .. N => ' ']);
               function Pad_Right (S : String; W : Natural) return String is
                 (S & Spaces (W - S'Length));
               function Pad_Left (S : String; W : Natural) return String is
                 (Spaces (W - S'Length) & S);
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
                        else Version.Objects.To_Object_Id
                               (Version.Refs.Current_Commit_Id (Repo)));
                     File : constant String := (if Two then Arg (3) else Arg (2));
                     Lines : constant Version.Blame.Blame_Vectors.Vector :=
                       Version.Blame.Blame_File (Repo, Tip, File);

                     --  Per-commit metadata (author name, iso date, boundary),
                     --  cached so each distinct commit is read once.
                     type Meta is record
                        Hex      : Unbounded_String;
                        Author   : Unbounded_String;
                        Date     : Unbounded_String;
                        Boundary : Boolean := False;
                     end record;
                     package Meta_Vectors is new Ada.Containers.Vectors
                       (Index_Type => Positive, Element_Type => Meta);
                     Cache : Meta_Vectors.Vector;

                     function Meta_For (Hex : String) return Meta is
                     begin
                        for M of Cache loop
                           if To_String (M.Hex) = Hex then
                              return M;
                           end if;
                        end loop;
                        declare
                           Obj : constant Version.Objects.Git_Object :=
                             Version.Objects.Read_Object
                               (Repo, Version.Objects.To_Object_Id (Hex));
                           C   : constant String := Version.Objects.Content (Obj);
                           P   : constant Natural :=
                             Ada.Strings.Fixed.Index (C, "author ");
                           EOL : Natural :=
                             (if P = 0 then 0
                              else Ada.Strings.Fixed.Index
                                     (C (P .. C'Last), "" & LF));
                           Result : Meta;
                        begin
                           Result.Hex := To_Unbounded_String (Hex);
                           Result.Boundary :=
                             Version.Objects.Commit_Parent_Ids (Obj).Is_Empty;
                           if P /= 0 then
                              if EOL = 0 then
                                 EOL := C'Last + 1;
                              end if;
                              declare
                                 Ident : constant String := C (P + 7 .. EOL - 1);
                                 Lt : constant Natural :=
                                   Ada.Strings.Fixed.Index (Ident, " <");
                                 Gt : constant Natural :=
                                   Ada.Strings.Fixed.Index (Ident, "> ");
                              begin
                                 Result.Author := To_Unbounded_String
                                   (if Lt > 0
                                    then Ident (Ident'First .. Lt - 1)
                                    else Ident);
                                 if Gt > 0 then
                                    Result.Date := To_Unbounded_String
                                      (Version.Ref_Format.Git_Date
                                         (Ident (Gt + 2 .. Ident'Last), "iso"));
                                 end if;
                              end;
                           end if;
                           Cache.Append (Result);
                           return Result;
                        end;
                     end Meta_For;

                     Author_W : Natural := 0;
                     Line_W   : constant Natural := Img (Natural (Lines.Length))'Length;
                  begin
                     --  Pass 1: resolve metadata and size the author column.
                     for L of Lines loop
                        declare
                           M : constant Meta := Meta_For (To_String (L.Commit));
                        begin
                           Author_W :=
                             Natural'Max (Author_W, Length (M.Author));
                        end;
                     end loop;

                     --  Pass 2: emit git's default annotation format.
                     declare
                        N : Natural := 0;
                     begin
                        for L of Lines loop
                           N := N + 1;
                           declare
                              M   : constant Meta :=
                                Meta_For (To_String (L.Commit));
                              Hex : constant String := To_String (L.Commit);
                              Sha : constant String :=
                                (if M.Boundary then "^" & Hex (1 .. 7)
                                 else Hex (1 .. 8));
                           begin
                              Success_Line
                                (Sha & " ("
                                 & Pad_Right (To_String (M.Author), Author_W)
                                 & " " & To_String (M.Date)
                                 & " " & Pad_Left (Img (N), Line_W)
                                 & ") " & To_String (L.Text));
                           end;
                        end loop;
                     end;
                  end;
               end if;
            end;

         elsif Command = "cat-file" then
            declare
               Usage : constant String :=
                 "version cat-file (-t|-s|-e|-p|blob|tree|commit|tag"
                 & "|--batch|--batch-check) OBJECT";
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
               All_Objects : constant Boolean :=
                 (for some J in 2 .. Count => Arg (J) = "--batch-all-objects");
               --  -z / -Z read the request list NUL-separated instead of
               --  newline-separated.  -Z additionally NUL-terminates the
               --  output records (header and, for --batch, the content
               --  record); -z leaves the output newline-terminated.
               Nul_In : constant Boolean :=
                 (for some J in 2 .. Count => Arg (J) = "-z"
                    or else Arg (J) = "-Z");
               Nul_Out : constant Boolean :=
                 (for some J in 2 .. Count => Arg (J) = "-Z");
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
                     Nul : constant String := (1 => Character'Val (0));

                     --  Header/record output.  With -Z every record is
                     --  NUL-terminated and the whole stream is routed through
                     --  Version.Console (byte-exact, no GNAT trailing
                     --  terminator); otherwise the newline path is kept.
                     procedure Out_Record (S : String) is
                     begin
                        if Nul_Out then
                           Version.Console.Put (S & Nul);
                        else
                           Success_Line (S);
                        end if;
                     end Out_Record;

                     procedure Emit (Token, Rest : String) is
                     begin
                        if Token = "" then
                           return;
                        end if;
                        begin
                           declare
                              Id : constant Version.Objects.Hex_Object_Id
                                := Version.Revisions.Resolve (Repo, Token);
                              Obj : constant Version.Objects.Git_Object
                                := Version.Objects.Read_Object (Repo, Id);
                           begin
                              Out_Record (Expand (Token, Rest, Id, Obj));
                              if Is_Batch then
                                 if Nul_Out then
                                    Version.Console.Put
                                      (Version.Objects.Content (Obj) & Nul);
                                 else
                                    Ada.Text_IO.Put
                                      (Version.Objects.Content (Obj));
                                    Ada.Text_IO.New_Line;
                                 end if;
                              end if;
                           end;
                        exception
                           when others =>
                              Out_Record (Token & " missing");
                        end;
                     end Emit;
                  begin
                     if All_Objects then
                        --  Enumerate every object (loose + packed), sorted by
                        --  oid via an ordered set (matches git's order + dedup).
                        declare
                           package Hex_Sets is new
                             Ada.Containers.Indefinite_Ordered_Sets (String);
                           Oids : Hex_Sets.Set;
                        begin
                           for O of Version.Reachability.All_Loose_Objects
                             (Repo)
                           loop
                              Oids.Include (Version.Objects.To_String (O));
                           end loop;
                           for O of Version.Pack.All_Pack_Objects (Repo) loop
                              Oids.Include (Version.Objects.To_String (O));
                           end loop;
                           for Hex of Oids loop
                              Emit (Hex, "");
                           end loop;
                        end;
                     else
                        declare
                           procedure Process (Line : String) is
                              Sp    : constant Natural :=
                                Ada.Strings.Fixed.Index (Line, " ");
                              Token : constant String :=
                                (if Sp = 0 then Line
                                 else Line (Line'First .. Sp - 1));
                              Rest  : constant String :=
                                (if Sp = 0 then ""
                                 else Line (Sp + 1 .. Line'Last));
                           begin
                              Emit (Token, Rest);
                           end Process;
                        begin
                           if Nul_In then
                              --  Requests are NUL-separated (-z/-Z).
                              declare
                                 Data  : constant String := Read_All_Stdin;
                                 Start : Positive := Data'First;
                              begin
                                 for I in Data'Range loop
                                    if Data (I) = Character'Val (0) then
                                       Process (Data (Start .. I - 1));
                                       Start := I + 1;
                                    end if;
                                 end loop;
                                 if Start <= Data'Last then
                                    Process (Data (Start .. Data'Last));
                                 end if;
                              end;
                           else
                              while not Ada.Text_IO.End_Of_File loop
                                 Process (Ada.Text_IO.Get_Line);
                              end loop;
                           end if;
                        end;
                     end if;
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
                           --  git cat-file -p <tree> lists one level (subtrees
                           --  as "tree"), with modes zero-padded to six digits.
                           declare
                              function Mode6 (M : String) return String is
                                ([1 .. 6 - M'Length => '0'] & M);
                           begin
                              for E of Version.Objects.Tree_Entries (Repo, Id)
                              loop
                                 Success_Line
                                   (Mode6 (To_String (E.Mode)) & " "
                                    & (if E.Kind = Tree_Directory then "tree"
                                       elsif E.Kind = Tree_Gitlink then "commit"
                                       else "blob")
                                    & " " & To_String (E.Id)
                                    & Character'Val (9) & To_String (E.Path));
                              end loop;
                           end;
                        else
                           Version.Console.Put (Version.Objects.Content (Obj));
                        end if;
                     elsif Arg (2) = "blob" or else Arg (2) = "tree"
                       or else Arg (2) = "commit" or else Arg (2) = "tag"
                     then
                        --  git's `cat-file <type> <object>` form: print the
                        --  contents, but only if the object really is that
                        --  type.
                        if Arg (2) /= Kind_Name then
                           Error_Line
                             ("fatal: git cat-file " & Arg (2) & ": bad file");
                           Set_Command_Failure;
                        else
                           Version.Console.Put (Version.Objects.Content (Obj));
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
                 "version rev-parse [--abbrev-ref] [--short] [--show-toplevel]"
                 & " [--git-dir] [--is-inside-work-tree] REV...";
               Abbrev  : Boolean := False;
               Short   : Boolean := False;
               Bad_Opt : Boolean := False;
               Done    : Boolean := False;
               I       : Positive := 2;
            begin
               while I <= Count and then Arg (I)'Length >= 2
                 and then Arg (I) (Arg (I)'First .. Arg (I)'First + 1) = "--"
               loop
                  if Arg (I) = "--abbrev-ref" then
                     Abbrev := True;
                  elsif Arg (I) = "--short" then
                     Short := True;
                  elsif Arg (I) = "--show-toplevel" then
                     Success_Line
                       (Version.Repository.Root_Path
                          (Version.Repository.Open));
                     Done := True;
                  elsif Arg (I) = "--git-dir" then
                     declare
                        Dir : constant String :=
                          Version.Repository.Git_Dir (Version.Repository.Open);
                        Here : constant String :=
                          Version.Files.Normalize_Separators
                            (Ada.Directories.Current_Directory) & "/";
                     begin
                        --  git reports it relative when it sits under the cwd.
                        if Dir'Length > Here'Length
                          and then Dir (Dir'First .. Dir'First + Here'Length - 1)
                                   = Here
                        then
                           Success_Line
                             (Dir (Dir'First + Here'Length .. Dir'Last));
                        else
                           Success_Line (Dir);
                        end if;
                     end;
                     Done := True;
                  elsif Arg (I) = "--is-inside-work-tree" then
                     Success_Line ("true");
                     Done := True;
                  else
                     Usage_Error ("unknown rev-parse option: " & Arg (I), Usage);
                     Bad_Opt := True;
                     exit;
                  end if;
                  I := I + 1;
               end loop;

               if Bad_Opt then
                  null;
               elsif I > Count then
                  if not Done then
                     Usage_Error ("rev-parse requires a revision", Usage);
                  end if;
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
                           declare
                              Full : constant String :=
                                To_String
                                  (Version.Revisions.Resolve (Repo, Arg (J)));
                           begin
                              --  git's --short defaults to a 7-hex abbreviation.
                              Success_Line
                                (if Short and then Full'Length >= 7
                                 then Full (Full'First .. Full'First + 6)
                                 else Full);
                           end;
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
               Usage : constant String :=
                 "version ls-files [-s|--stage] [-o|--others] [-m|--modified]"
                 & " [-d|--deleted] [--exclude-standard] [--] [PATHSPEC...]";
               Specs     : Version.Pathspec.Pathspec_Vectors.Vector;
               After_Sep : Boolean := False;
               Stage_Fmt : Boolean := False;
               Others_M  : Boolean := False;
               Modified  : Boolean := False;
               Deleted   : Boolean := False;
               Exclude   : Boolean := False;
               Bad       : Boolean := False;

               function Img (N : Natural) return String is
                  S : constant String := Natural'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;

               procedure Emit (Path : String) is
               begin
                  if Specs.Is_Empty
                    or else Version.Pathspec.Matches_Any (Specs, Path)
                  then
                     --  git C-quotes a path holding control characters or
                     --  high-bit bytes.
                     Success_Line
                       (Version.Path_Quoting.Quote_C_Style (Path));
                  end if;
               end Emit;
            begin
               for I in 2 .. Count loop
                  if not After_Sep and then Arg (I) = "--" then
                     After_Sep := True;
                  elsif not After_Sep
                    and then (Arg (I) = "-s" or else Arg (I) = "--stage")
                  then
                     Stage_Fmt := True;
                  elsif not After_Sep
                    and then (Arg (I) = "-o" or else Arg (I) = "--others")
                  then
                     Others_M := True;
                  elsif not After_Sep
                    and then (Arg (I) = "-m" or else Arg (I) = "--modified")
                  then
                     Modified := True;
                  elsif not After_Sep
                    and then (Arg (I) = "-d" or else Arg (I) = "--deleted")
                  then
                     Deleted := True;
                  elsif not After_Sep
                    and then Arg (I) = "--exclude-standard"
                  then
                     Exclude := True;
                  elsif not After_Sep
                    and then Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown ls-files option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  else
                     Version.Pathspec.Append_Parse (Specs, Arg (I));
                  end if;
               end loop;

               --  -o/-m/-d select from the working tree rather than the index.
               if not Bad and then (Others_M or else Modified or else Deleted)
               then
                  declare
                     St : constant Version.Status.Status_Result :=
                       (if Others_M and then not Exclude
                        then Version.Status.Current_Status_With_Ignored
                               (Mode          =>
                                  Version.Status.Ignored_Traditional,
                                All_Untracked => True)
                        else Version.Status.Current_Status
                               (All_Untracked => True));
                  begin
                     if Others_M then
                        for E of St.Untracked loop
                           Emit (To_String (E.Path));
                        end loop;
                        if not Exclude then
                           for E of St.Ignored loop
                              Emit (To_String (E.Path));
                           end loop;
                        end if;
                     end if;
                     if Modified then
                        --  git's -m is every tracked path that differs from
                        --  the index in the working tree -- content changes
                        --  AND worktree deletions, not just modifications.
                        for E of St.Changes loop
                           Emit (To_String (E.Path));
                        end loop;
                     end if;
                     if Deleted then
                        for E of St.Changes loop
                           if Version.Status."="
                                (E.Kind, Version.Status.Deleted_File)
                           then
                              Emit (To_String (E.Path));
                           end if;
                        end loop;
                     end if;
                  end;
                  Bad := True;   --  handled; skip the index listing below
               end if;

               for E of Entries loop
                  if not Bad and then E.Stage = 0
                    and then
                      (Specs.Is_Empty
                       or else Version.Pathspec.Matches_Any
                                 (Specs, To_String (E.Path)))
                  then
                     if Stage_Fmt then
                        --  git: <mode> SP <object> SP <stage> TAB <path>
                        Success_Line
                          (To_String (E.Mode) & " " & To_String (E.Id)
                           & " " & Img (E.Stage)
                           & Character'Val (9)
                           & Version.Path_Quoting.Quote_C_Style
                               (To_String (E.Path)));
                     else
                        Success_Line
                          (Version.Path_Quoting.Quote_C_Style
                             (To_String (E.Path)));
                     end if;
                  end if;
               end loop;
            end;

         elsif Command = "ls-tree" then
            declare
               Usage : constant String :=
                 "version ls-tree [-r] [--name-only] TREE-ISH [--] [PATH...]";
               Name_Only : Boolean := False;
               Recursive : Boolean := False;
               Bad_Opt   : Boolean := False;
               Bad_Text  : Unbounded_String;
               Tree_Idx  : Natural := 0;
               Sep       : Boolean := False;
               Specs     : Version.Pathspec.Pathspec_Vectors.Vector;
               --  git's ls-tree matches path operands literally, not as
               --  globs, so keep the raw text alongside the parsed specs.
               Raw_Specs : Version.Trailers.String_Vectors.Vector;
               I         : Positive := 2;

               --  git renders modes as six zero-padded octal digits.
               function Mode6 (M : String) return String is
                 ([1 .. 6 - M'Length => '0'] & M);
            begin
               while I <= Count loop
                  if not Sep and then Arg (I) = "--" then
                     Sep := True;
                  elsif Sep then
                     Version.Pathspec.Append_Parse (Specs, Arg (I));
                     Raw_Specs.Append (Arg (I));
                  elsif Arg (I) = "-r" then
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
                     --  git also takes bare paths after the tree-ish.
                     Version.Pathspec.Append_Parse (Specs, Arg (I));
                     Raw_Specs.Append (Arg (I));
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
                     --  Without -r git still resolves a nested path operand
                     --  ("d/sub") by walking down the tree; a plain top-level
                     --  listing would never contain it.
                     function Listing
                       return Version.Objects.Tree_Entry_Vectors.Vector
                     is
                        Result : Version.Objects.Tree_Entry_Vectors.Vector :=
                          Version.Objects.Tree_Entries (Repo, Tree);
                     begin
                        for Spec of Raw_Specs loop
                           if (for some C of Spec => C = '/') then
                              declare
                                 Sub : Version.Objects.Hex_Object_Id := Tree;
                                 From : Positive := Spec'First;
                              begin
                                 --  Descend one component at a time, adding
                                 --  each level's entries so the named one is
                                 --  present to be matched below.
                                 for K in Spec'Range loop
                                    if Spec (K) = '/' then
                                       declare
                                          Part : constant String :=
                                            Spec (From .. K - 1);
                                       begin
                                          for E of Version.Objects.Tree_Entries
                                                     (Repo, Sub)
                                          loop
                                             if To_String (E.Path) = Part
                                               and then E.Kind
                                                        = Tree_Directory
                                             then
                                                Sub := E.Id;
                                             end if;
                                          end loop;
                                          From := K + 1;
                                       end;
                                    end if;
                                 end loop;

                                 declare
                                    Prefix : constant String :=
                                      Spec (Spec'First .. From - 1);
                                 begin
                                    for E of Version.Objects.Tree_Entries
                                               (Repo, Sub)
                                    loop
                                       Result.Append
                                         (Version.Objects.Tree_Entry'
                                            (Path =>
                                               To_Unbounded_String
                                                 (Prefix & To_String (E.Path)),
                                             Id   => E.Id,
                                             Mode => E.Mode,
                                             Kind => E.Kind));
                                    end loop;
                                 end;
                              exception
                                 when others =>
                                    null;   --  no such path in this tree
                              end;
                           end if;
                        end loop;
                        return Result;
                     end Listing;

                     Entries : constant
                       Version.Objects.Tree_Entry_Vectors.Vector :=
                         (if Recursive
                          then Version.Objects.Flatten_Tree (Repo, Tree)
                          else Listing);

                     --  Literal match: the path itself, or -- for a spec
                     --  naming a directory -- something below it. Without -r
                     --  only the directory's immediate children count.
                     function Selected (Path : String) return Boolean is
                     begin
                        if Raw_Specs.Is_Empty then
                           return True;
                        end if;

                        for Spec of Raw_Specs loop
                           declare
                              Slashed : constant Boolean :=
                                Spec'Length > 0
                                and then Spec (Spec'Last) = '/';
                              Base : constant String :=
                                (if Slashed
                                 then Spec (Spec'First .. Spec'Last - 1)
                                 else Spec);
                              Under : constant String := Base & "/";
                           begin
                              if not Slashed and then Path = Base then
                                 return True;
                              end if;

                              if Path'Length > Under'Length
                                and then Path (Path'First
                                               .. Path'First + Under'Length - 1)
                                         = Under
                              then
                                 if Recursive then
                                    return True;
                                 end if;
                              end if;
                           end;
                        end loop;

                        return False;
                     end Selected;
                  begin
                     for E of Entries loop
                        if Selected (To_String (E.Path)) then
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
                        end if;
                     end loop;
                  end;
               end if;
            end;

         elsif Command = "patch-id" then
            declare
               --  git's patch-id: a SHA-1 over the patch with all whitespace
               --  removed, the hunk headers dropped (so line numbers do not
               --  change the id) and the `index` lines ignored.  Prints
               --  "<patch-id> <commit-id>" per patch on the input.
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
                           Buffer (Buffer'First
                                   .. Buffer'First + Natural (N) - 1));
                     end;
                  end loop;
                  return To_String (Acc);
               end Read_Stdin;

               Text  : constant String := Read_Stdin;
               Buf   : Unbounded_String;   --  bytes hashed for this patch
               Len   : Natural := 0;       --  git's patchlen
               Commit_Oid : Unbounded_String :=
                 To_Unbounded_String ([1 .. 40 => '0']);
               Next_Oid   : Unbounded_String;
               Before, After : Integer := -1;
               Start : Natural := Text'First;

               function Strip_Space (L : String) return String is
                  R : String (1 .. L'Length);
                  N : Natural := 0;
               begin
                  for C of L loop
                     if C /= ' ' and then C /= ASCII.HT
                       and then C /= ASCII.CR and then C /= ASCII.LF
                     then
                        N := N + 1;
                        R (N) := C;
                     end if;
                  end loop;
                  return R (1 .. N);
               end Strip_Space;

               function Starts (L, P : String) return Boolean is
                 (L'Length >= P'Length
                  and then L (L'First .. L'First + P'Length - 1) = P);

               function Is_Hex_Oid (L : String) return Boolean is
               begin
                  if L'Length < 40 then
                     return False;
                  end if;
                  for I in L'First .. L'First + 39 loop
                     if not (L (I) in '0' .. '9' or else L (I) in 'a' .. 'f')
                     then
                        return False;
                     end if;
                  end loop;
                  return True;
               end Is_Hex_Oid;

               --  --stable computes an order-independent id: git hashes each
               --  file's diff separately and adds the 20-byte digests (with
               --  carry) into a running accumulator, so reordering the files
               --  in the patch leaves the id unchanged.  --unstable (the
               --  default) hashes the whole patch as one stream (Buf below).
               function Want_Stable return Boolean is
                  S : Boolean := False;
               begin
                  for J in 2 .. Count loop
                     if Arg (J) = "--stable" then
                        S := True;
                     elsif Arg (J) = "--unstable" then
                        S := False;
                     end if;
                  end loop;
                  return S;
               end Want_Stable;
               Stable : constant Boolean := Want_Stable;

               Result : String (1 .. 20) := [others => Character'Val (0)];

               function To_Hex (Raw : String) return String is
                  Digits_Set : constant String := "0123456789abcdef";
                  R : String (1 .. Raw'Length * 2);
               begin
                  for I in Raw'Range loop
                     declare
                        B : constant Natural := Character'Pos (Raw (I));
                        K : constant Positive := (I - Raw'First) * 2 + 1;
                     begin
                        R (K) := Digits_Set (Digits_Set'First + B / 16);
                        R (K + 1) := Digits_Set (Digits_Set'First + B mod 16);
                     end;
                  end loop;
                  return R;
               end To_Hex;

               --  Finalize the current file's chunk (Buf) into Result by
               --  20-byte little-endian addition, then reset Buf.  git's
               --  flush_one_hunk.  Called at every file boundary and at the
               --  end of the patch (stable only).
               procedure Sub_Flush is
                  Raw   : constant String :=
                    Version.Hash.Sha1_Raw (To_String (Buf));
                  Carry : Natural := 0;
               begin
                  for I in 1 .. 20 loop
                     Carry := Carry + Character'Pos (Result (I))
                       + Character'Pos (Raw (Raw'First + I - 1));
                     Result (I) := Character'Val (Carry mod 256);
                     Carry := Carry / 256;
                  end loop;
                  Buf := Null_Unbounded_String;
               end Sub_Flush;

               procedure Flush is
               begin
                  if Len > 0 then
                     if Stable then
                        Sub_Flush;   --  finalize the last file
                        Success_Line
                          (To_Hex (Result) & " " & To_String (Commit_Oid));
                     else
                        Success_Line
                          (Version.Hash.Sha1_Hex (To_String (Buf)) & " "
                           & To_String (Commit_Oid));
                     end if;
                  end if;
                  Buf := Null_Unbounded_String;
                  Len := 0;
                  Before := -1;
                  After := -1;
                  Result := [others => Character'Val (0)];
               end Flush;

               procedure Add (L : String) is
                  Stripped : constant String := Strip_Space (L);
               begin
                  Append (Buf, Stripped);
                  Len := Len + Stripped'Length;
               end Add;
            begin
               while Start <= Text'Last loop
                  declare
                     Stop : Natural := Start;
                  begin
                     while Stop <= Text'Last
                       and then Text (Stop) /= ASCII.LF
                     loop
                        Stop := Stop + 1;
                     end loop;

                     declare
                        Line : constant String := Text (Start .. Stop - 1);
                        P    : constant String :=
                          (if Starts (Line, "commit ") then Line (Line'First + 7 .. Line'Last)
                           elsif Starts (Line, "From ") then Line (Line'First + 5 .. Line'Last)
                           else Line);
                     begin
                        if Starts (Line, "\ ") then
                           null;   --  "\ No newline at end of file"
                        elsif Is_Hex_Oid (P) then
                           --  The next patch starts here.
                           Next_Oid :=
                             To_Unbounded_String (P (P'First .. P'First + 39));
                           Flush;
                           Commit_Oid := Next_Oid;
                        elsif Len = 0 and then not Starts (Line, "diff ") then
                           null;   --  commit message and other preamble
                        elsif Before = -1 then
                           if Starts (Line, "index ") then
                              null;
                           elsif Starts (Line, "--- ") then
                              Before := 1;
                              After := 1;
                              Add (Line);
                              Before := Before - 1;
                           elsif Line'Length = 0
                             or else not (Line (Line'First) in 'a' .. 'z'
                                          or else Line (Line'First) in 'A' .. 'Z')
                           then
                              null;   --  end of this patch's header
                           else
                              Add (Line);   --  "diff --git ...", "new file ..."
                           end if;
                        elsif Before = 0 and then After = 0 then
                           if Starts (Line, "@@ -") then
                              --  Parse the counts but never hash the header:
                              --  that is what makes the id independent of the
                              --  line numbers.
                              declare
                                 B, A : Natural := 1;
                                 I : Natural := Line'First + 4;

                                 procedure Scan (N : out Natural) is
                                    V : Natural := 0;
                                    Seen : Boolean := False;
                                 begin
                                    while I <= Line'Last
                                      and then Line (I) in '0' .. '9'
                                    loop
                                       I := I + 1;   --  skip the start line
                                    end loop;
                                    N := 1;
                                    if I <= Line'Last and then Line (I) = ',' then
                                       I := I + 1;
                                       while I <= Line'Last
                                         and then Line (I) in '0' .. '9'
                                       loop
                                          V := V * 10
                                            + (Character'Pos (Line (I))
                                               - Character'Pos ('0'));
                                          Seen := True;
                                          I := I + 1;
                                       end loop;
                                       if Seen then
                                          N := V;
                                       end if;
                                    end if;
                                 end Scan;
                              begin
                                 Scan (B);
                                 while I <= Line'Last
                                   and then Line (I) /= '+'
                                 loop
                                    I := I + 1;
                                 end loop;
                                 I := I + 1;
                                 Scan (A);
                                 Before := B;
                                 After := A;
                              end;
                           elsif not Starts (Line, "diff ") then
                              null;   --  end of the patch
                           else
                              --  New file within the same patch: close the
                              --  previous file's chunk before starting this
                              --  one (stable id is a sum over files).
                              if Stable then
                                 Sub_Flush;
                              end if;
                              Before := -1;
                              After := -1;
                              Add (Line);
                           end if;
                        else
                           if Line'Length > 0
                             and then (Line (Line'First) = '-'
                                       or else Line (Line'First) = ' ')
                           then
                              Before := Before - 1;
                           end if;
                           if Line'Length > 0
                             and then (Line (Line'First) = '+'
                                       or else Line (Line'First) = ' ')
                           then
                              After := After - 1;
                           end if;
                           Add (Line);
                        end if;
                     end;

                     Start := Stop + 1;
                  end;
               end loop;

               Flush;
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

                     procedure Emit (Content : String) is
                     begin
                        if Write_It then
                           Success_Line
                             (To_String
                                (Version.Write.Write_Blob (Repo, Content)));
                        else
                           Success_Line
                             (Version.Objects.To_String
                                (Version.Objects.Compute_Object_Id
                                   (Version.Repository.Algorithm (Repo),
                                    "blob", Content)));
                        end if;
                     end Emit;
                  begin
                     if Stdin then
                        Emit (Read_Stdin);
                     else
                        --  git hashes every file operand in order, one id per
                        --  line, and dies (exit 128) at the first file it
                        --  cannot open for reading, without processing the
                        --  rest.  We only handled Arg (File_Idx) before.
                        for J in File_Idx .. Count loop
                           if not Version.Files.Is_Ordinary_File (Arg (J)) then
                              Ada.Text_IO.Put_Line
                                (Ada.Text_IO.Standard_Error,
                                 "fatal: could not open '" & Arg (J)
                                 & "' for reading: No such file or directory");
                              Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                              exit;
                           else
                              Emit (Version.Files.Read_Binary_File (Arg (J)));
                           end if;
                        end loop;
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
                     --  Repeated -m are joined as separate paragraphs
                     --  (blank line between), as git's commit-tree does,
                     --  not overwritten.
                     if Has_Msg then
                        Append (Msg, ASCII.LF & ASCII.LF & Arg (I + 1));
                     else
                        Msg := To_Unbounded_String (Arg (I + 1));
                        Has_Msg := True;
                     end if;
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
               Usage : constant String :=
                 "version show-ref [--heads] [--tags]";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               --  git: naming --heads and/or --tags restricts to those
               --  namespaces; with neither, all refs are shown.
               Want_Heads : Boolean := True;
               Want_Tags  : Boolean := True;
               Filtered   : Boolean := False;
               Bad        : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--heads" or else Arg (I) = "--tags" then
                     if not Filtered then
                        Want_Heads := False;
                        Want_Tags  := False;
                        Filtered   := True;
                     end if;
                     if Arg (I) = "--heads" then
                        Want_Heads := True;
                     else
                        Want_Tags := True;
                     end if;
                  else
                     Usage_Error
                       ("unknown show-ref argument: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  --  Reuse for-each-ref, which sorts by refname like git
                  --  show-ref. With no filter, every ref is shown; --heads /
                  --  --tags restrict to those namespaces.
                  declare
                     Patterns : Version.Ref_Format.String_Vectors.Vector;
                  begin
                     if Filtered then
                        if Want_Heads then
                           Patterns.Append ("refs/heads/");
                        end if;
                        if Want_Tags then
                           Patterns.Append ("refs/tags/");
                        end if;
                     end if;
                     for Line of Version.Ref_Format.For_Each_Ref
                       (Repo     => Repo,
                        Patterns => Patterns,
                        Format   => "%(objectname) %(refname)")
                     loop
                        Success_Line (Line);
                     end loop;
                  end;
               end if;
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
                        --  git refuses to fill a credential that cannot
                        --  identify what it is for; it checks host first.
                        if Length (Cred.Host) = 0 then
                           Stderr_Line
                             ("fatal: refusing to work with credential"
                              & " missing host field");
                           Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                        elsif Length (Cred.Protocol) = 0 then
                           Stderr_Line
                             ("fatal: refusing to work with credential"
                              & " missing protocol field");
                           Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                        else
                           Version.Credential.Fill (Repo, Cred);
                           Ada.Text_IO.Put
                             (Version.Credential.Serialize (Cred));
                        end if;
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
                      Stage => 0, Skip_Worktree => False));
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
               Usage : constant String :=
                 "version rev-list [--count] [--all]"
                 & " [--max-count=<n>|-n <n>] [REV]";
               Count_Only : Boolean := False;
               Max_Count  : Integer := -1;  --  -1 = unlimited
               Bad_Opt    : Boolean := False;
               Bad_Text   : Unbounded_String;
               Rev_Idx    : Natural := 0;
               All_Refs   : Boolean := False;
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
                  elsif Arg (I) = "--all" then
                     All_Refs := True;
                  elsif Arg (I)'Length > 12
                    and then Arg (I) (Arg (I)'First .. Arg (I)'First + 11)
                             = "--max-count="
                  then
                     Max_Count :=
                       Integer'Value (Arg (I) (Arg (I)'First + 12 .. Arg (I)'Last));
                  elsif Arg (I) = "--max-count" or else Arg (I) = "-n" then
                     if I = Count then
                        Bad_Opt := True;
                        Bad_Text := To_Unbounded_String (Arg (I));
                        exit;
                     end if;
                     I := I + 1;
                     Max_Count := Integer'Value (Arg (I));
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
               elsif Rev_Idx = 0 and then not All_Refs then
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
                     if All_Refs then
                        --  Seed from every ref tip (peeled to a commit).
                        declare
                           No_Patterns :
                             Version.Ref_Format.String_Vectors.Vector;
                        begin
                           for Ref of Version.Ref_Format.For_Each_Ref
                             (Repo, No_Patterns, Format => "%(refname)")
                           loop
                              begin
                                 Queue.Append
                                   (Version.Revisions.Resolve_Commit
                                      (Repo, Ref));
                              exception
                                 when others =>
                                    null;  --  non-commit ref (e.g. blob tag)
                              end;
                           end loop;
                        end;
                     end if;
                     if Rev_Idx /= 0 then
                        Queue.Append
                          (Version.Revisions.Resolve_Commit
                             (Repo, Arg (Rev_Idx)));
                     end if;
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

                     declare
                        --  git stops the walk after --max-count commits.
                        Limit : constant Natural :=
                          (if Max_Count >= 0
                           then Natural'Min (Max_Count, Natural (Result.Length))
                           else Natural (Result.Length));
                        Emitted : Natural := 0;
                     begin
                        if Count_Only then
                           Success_Line (Img (Limit));
                        else
                           for C of Result loop
                              exit when Emitted >= Limit;
                              Success_Line (To_String (C));
                              Emitted := Emitted + 1;
                           end loop;
                        end if;
                     end;
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

                     declare
                        Fetch_Before : constant Fetch_Ref_Maps.Map :=
                          Snapshot_Fetch_Refs (Repo, To_String (Remote));
                     begin
                        Version.Fetch.Fetch (To_String (Remote));
                        if Length (Branch_Arg) > 0 then
                           --  Explicit `pull <remote> <branch>`: git fetches to
                           --  FETCH_HEAD and reports that form.
                           Print_Fetch_Head_Summary
                             (Repo, To_String (Remote),
                              To_String (Branch_Arg), Fetch_Before);
                        else
                           Print_Fetch_Summary
                             (Repo, To_String (Remote), Fetch_Before);
                        end if;
                     end;

                     if Do_Rebase then
                        Version.Rebase.Start (To_String (Target));
                        Success_Line
                          ("Successfully rebased and updated " & Branch & ".");
                     else
                        declare
                           Before  : constant String :=
                             Version.Refs.Current_Commit_Id (Repo);
                           Options : Version.Branch.Merge_Options;

                           function Stat_Enabled return Boolean is
                              V : Unbounded_String;
                           begin
                              begin
                                 V := To_Unbounded_String
                                   (Version.Config.Get_Value
                                      (Repo, "merge.stat"));
                              exception
                                 when others =>
                                    V := Null_Unbounded_String;
                              end;
                              --  git's merge.stat defaults to true.
                              return
                                To_String (V) not in
                                  "false" | "0" | "no" | "off";
                           end Stat_Enabled;

                           procedure Show_Pull_Stat
                             (B, A : Version.Objects.Hex_Object_Id)
                           is
                              Block : constant String :=
                                Version.Diff.Diff_Commits
                                  (Repo, B, A,
                                   Version.Diff.Diff_Options'
                                     (Context_Lines => 3, Stat => True,
                                      Summary => True, others => <>));
                              Last  : Natural := Block'Last;
                           begin
                              if not Stat_Enabled then
                                 return;
                              end if;
                              if Last >= Block'First
                                and then Block (Last) = Character'Val (10)
                              then
                                 Last := Last - 1;
                              end if;
                              if Last >= Block'First then
                                 Success_Line (Block (Block'First .. Last));
                              end if;
                           end Show_Pull_Stat;

                           procedure Show_Pull_Updating
                             (B, A : Version.Objects.Hex_Object_Id)
                           is
                              Ob : constant String := To_String (B);
                              Ab : constant String := To_String (A);
                              OL : constant Natural :=
                                Version.Revisions.Unique_Abbrev_Length
                                  (Repo, B, 7);
                              AL : constant Natural :=
                                Version.Revisions.Unique_Abbrev_Length
                                  (Repo, A, 7);
                           begin
                              Success_Line
                                ("Updating "
                                 & Ob (Ob'First .. Ob'First + OL - 1)
                                 & ".."
                                 & Ab (Ab'First .. Ab'First + AL - 1));
                           end Show_Pull_Updating;
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
                              Valid_Ids : constant Boolean :=
                                Version.Objects.Is_Valid_Hex_Object_Id (Before)
                                and then
                                  Version.Objects.Is_Valid_Hex_Object_Id
                                    (After);
                           begin
                              if After = Before then
                                 Success_Line ("Already up to date.");
                              elsif Valid_Ids
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
                                 Show_Pull_Updating
                                   (Version.Objects.To_Object_Id (Before),
                                    Version.Objects.To_Object_Id (After));
                                 Success_Line ("Fast-forward");
                                 Show_Pull_Stat
                                   (Version.Objects.To_Object_Id (Before),
                                    Version.Objects.To_Object_Id (After));
                              else
                                 Success_Line
                                   ("Merge made by the 'ort' strategy.");
                                 if Valid_Ids then
                                    Show_Pull_Stat
                                      (Version.Objects.To_Object_Id (Before),
                                       Version.Objects.To_Object_Id (After));
                                 end if;
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

            elsif Count >= 2
              and then (for all J in 2 .. Count =>
                          (Arg (J)'Length > 7
                           and then Arg (J) (Arg (J)'First .. Arg (J)'First + 6)
                                    = "--sort=")
                          or else Arg (J) = "list" or else Arg (J) = "-l"
                          or else Arg (J) = "--list")
              and then (for some J in 2 .. Count =>
                          Arg (J)'Length > 7
                          and then Arg (J) (Arg (J)'First .. Arg (J)'First + 6)
                                   = "--sort=")
            then
               --  `tag [-l] --sort=<key>`: list tags sorted via for-each-ref.
               declare
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Key  : Unbounded_String;
                  Pat  : Version.Ref_Format.String_Vectors.Vector;
               begin
                  for J in 2 .. Count loop
                     if Arg (J)'Length > 7
                       and then Arg (J) (Arg (J)'First .. Arg (J)'First + 6)
                                = "--sort="
                     then
                        Key := To_Unbounded_String
                          (Arg (J) (Arg (J)'First + 7 .. Arg (J)'Last));
                     end if;
                  end loop;
                  Pat.Append ("refs/tags/");
                  for Line of Version.Ref_Format.For_Each_Ref
                    (Repo, Pat, Format => "%(refname:short)",
                     Sort_Key => To_String (Key))
                  loop
                     Success_Line (Line);
                  end loop;
               end;

            elsif Count = 1
              or else (Count = 2
                       and then (Arg (2) = "list" or else Arg (2) = "-l"
                                 or else Arg (2) = "--list"))
            then
               --  Bare `tag`, `tag list`, and `tag -l`/`--list` all list tags.
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

                     Version.Console.Put
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

                     Version.Console.Put
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

                     Version.Console.Put
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
                  exception
                     when Version.Config.Ambiguous_Key =>
                        --  git warns and exits 5, leaving the values in place.
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "warning: " & Arg (Base) & " has multiple values");
                        Ada.Command_Line.Set_Exit_Status
                          (Ada.Command_Line.Exit_Status (5));
                     when Version.Config.Key_Absent =>
                        --  git exits 5 with no diagnostic: nothing to unset.
                        Ada.Command_Line.Set_Exit_Status
                          (Ada.Command_Line.Exit_Status (5));
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
                 "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]";
               I             : Natural := 2;
               Has_Depth     : Boolean := False;
               Depth_Value   : Positive := 1;
               Has_Deepen    : Boolean := False;
               Deepen_Value  : Positive := 1;
               Unshallow     : Boolean := False;
               Remote_Name   : Unbounded_String;
               Ref_Name      : Unbounded_String;
               Have_Ref      : Boolean := False;
               Operand_Count : Natural := 0;

               function Shallow_Modes return Natural is
                 ((if Has_Depth then 1 else 0)
                  + (if Has_Deepen then 1 else 0)
                  + (if Unshallow then 1 else 0));
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

                  elsif Arg (I) = "--deepen" then
                     if Has_Deepen then
                        Usage_Error ("duplicate option: --deepen", Usage);
                        return;
                     elsif I = Count then
                        Usage_Error ("--deepen requires a value", Usage);
                        return;
                     end if;

                     Has_Deepen := True;
                     Deepen_Value := Parse_Depth_Argument (Arg (I + 1));
                     I := I + 2;

                  elsif Arg (I) = "--unshallow" then
                     Unshallow := True;
                     I := I + 1;

                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown fetch option: " & Arg (I), Usage);
                     return;

                  else
                     Operand_Count := Operand_Count + 1;
                     if Operand_Count = 1 then
                        Remote_Name := To_Unbounded_String (Arg (I));
                     elsif Operand_Count = 2 then
                        Ref_Name := To_Unbounded_String (Arg (I));
                        Have_Ref := True;
                     else
                        Usage_Error ("too many fetch arguments", Usage);
                        return;
                     end if;
                     I := I + 1;
                  end if;
               end loop;

               if Shallow_Modes > 1 then
                  Usage_Error
                    ("--depth, --deepen, and --unshallow are mutually exclusive",
                     Usage);
                  return;
               elsif Operand_Count = 0 then
                  Usage_Error ("missing remote", Usage);
                  return;
               else
                  declare
                     Repo   : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Before : constant Fetch_Ref_Maps.Map :=
                       Snapshot_Fetch_Refs (Repo, To_String (Remote_Name));
                  begin
                     if Has_Depth then
                        Version.Fetch.Fetch
                          (Remote_Name => To_String (Remote_Name),
                           Depth       => Depth_Value);
                     elsif Has_Deepen then
                        Version.Fetch.Fetch_Deepen
                          (Remote_Name => To_String (Remote_Name),
                           Depth       => Deepen_Value);
                     elsif Unshallow then
                        Version.Fetch.Fetch_Unshallow
                          (To_String (Remote_Name));
                     else
                        Version.Fetch.Fetch (To_String (Remote_Name));
                     end if;

                     if Have_Ref then
                        --  Explicit `fetch <remote> <ref>`: git reports the
                        --  FETCH_HEAD form plus opportunistic tracking updates.
                        Print_Fetch_Head_Summary
                          (Repo, To_String (Remote_Name),
                           To_String (Ref_Name), Before);
                     else
                        Print_Fetch_Summary
                          (Repo, To_String (Remote_Name), Before);
                     end if;
                  end;
               end if;
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

         elsif Command = "maintenance" then
            declare
               Usage : constant String :=
                 "version maintenance run [--task=<task>] [--quiet] [--auto]";

               function Is_Valid_Task (T : String) return Boolean is
                 (T = "gc" or else T = "commit-graph"
                  or else T = "loose-objects"
                  or else T = "incremental-repack"
                  or else T = "pack-refs" or else T = "prefetch");

               --  Tasks that touch object storage map onto version's GC;
               --  the auxiliary tasks (commit-graph, pack-refs, prefetch)
               --  maintain files version does not keep, so they are no-ops.
               function Is_Object_Task (T : String) return Boolean is
                 (T = "gc" or else T = "loose-objects"
                  or else T = "incremental-repack");
            begin
               if Count < 2 then
                  Usage_Error ("maintenance needs a subcommand", Usage);
               elsif Arg (2) = "run" then
                  declare
                     Bad      : Boolean  := False;
                     Saw_Task : Boolean  := False;
                     Run_GC   : Boolean  := False;
                     I        : Positive := 3;
                     Prefix   : constant String := "--task=";
                  begin
                     while I <= Count and then not Bad loop
                        if Arg (I) = "--quiet" or else Arg (I) = "--auto" then
                           I := I + 1;
                        elsif Arg (I)'Length > Prefix'Length
                          and then Arg (I)
                                     (Arg (I)'First ..
                                        Arg (I)'First + Prefix'Length - 1)
                                   = Prefix
                        then
                           declare
                              TN : constant String :=
                                Arg (I)
                                  (Arg (I)'First + Prefix'Length .. Arg (I)'Last);
                           begin
                              if not Is_Valid_Task (TN) then
                                 Usage_Error
                                   ("'" & TN & "' is not a valid task", Usage);
                                 Bad := True;
                              else
                                 Saw_Task := True;
                                 Run_GC   := Run_GC or else Is_Object_Task (TN);
                              end if;
                           end;
                           I := I + 1;
                        else
                           Usage_Error
                             ("unknown maintenance option: " & Arg (I), Usage);
                           Bad := True;
                        end if;
                     end loop;

                     --  With no explicit task, git runs the gc task by default.
                     if not Bad then
                        if not Saw_Task then
                           Run_GC := True;
                        end if;

                        if Run_GC then
                           declare
                              Result :
                                constant Version.Maintenance.Maintenance_Result
                                  := Version.Maintenance.GC
                                       (Repo    => Version.Repository.Open,
                                        Dry_Run => False);
                              pragma Unreferenced (Result);
                           begin
                              null;  --  git maintenance run is silent on success
                           end;
                        end if;
                     end if;
                  end;
               elsif Arg (2) = "start" or else Arg (2) = "stop"
                 or else Arg (2) = "register" or else Arg (2) = "unregister"
               then
                  Usage_Error
                    ("maintenance " & Arg (2)
                     & " manages OS background scheduling, which version does"
                     & " not provide; run `version maintenance run` directly",
                     Usage);
               else
                  Usage_Error
                    ("unknown maintenance subcommand: " & Arg (2), Usage);
               end if;
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
                           --  Raw Dst: Delete_Ref resolves an unqualified name
                           --  against the remote (branch, then tag) like git.
                           Version.Push.Delete_Ref
                             (Remote_Name => Remote,
                              Ref_Name    => Dst,
                              Run_Hooks   => Run_Hooks);
                           Success_Line
                             ("deleted " & Dst & " on " & Remote);
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
                     --  Pass the raw name so Delete_Ref can resolve an
                     --  unqualified name against the remote (branch, then tag).
                     for Ref_Arg of Refspecs loop
                        Version.Push.Delete_Ref
                          (Remote_Name => To_String (Remote_Name),
                           Ref_Name    => Ref_Arg,
                           Run_Hooks   => not No_Verify);
                        Success_Line
                          ("deleted " & Ref_Arg & " on "
                           & To_String (Remote_Name));
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

         elsif Command = "lfs" then
            declare
               Usage : constant String :=
                 "version lfs (track [PATTERN...] | untrack PATTERN... | "
                 & "ls-files [-l] [REF] | status | pointer --file=PATH | env | "
                 & "fetch [REMOTE [REF...]] | pull [REMOTE] | checkout [PATH...] "
                 & "| push REMOTE [REF] | lock PATH | "
                 & "unlock PATH|--id ID [--force] | "
                 & "locks [--path PATH] [--id ID] [--verify])";
               Sub   : constant String := (if Count >= 2 then Arg (2) else "");
            begin
               if Sub = "lock" then
                  if Count /= 3 then
                     Usage_Error ("lfs lock requires a single PATH", Usage);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Created : constant Version.LFS.Lock_Info :=
                          Version.LFS.Create_Lock (Repo, Arg (3));
                        pragma Unreferenced (Created);
                     begin
                        Ada.Text_IO.Put_Line ("Locked " & Arg (3));
                     end;
                  end if;

               elsif Sub = "unlock" then
                  declare
                     Id    : Unbounded_String;
                     Path  : Unbounded_String;
                     Force : Boolean := False;
                     OK    : Boolean := True;
                     I     : Positive := 3;
                  begin
                     while OK and then I <= Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A = "--force" or else A = "-f" then
                              Force := True;
                           elsif A = "--id" then
                              if I = Count then
                                 OK := False;
                              else
                                 I := I + 1;
                                 Id := To_Unbounded_String (Arg (I));
                              end if;
                           elsif A'Length > 0 and then A (A'First) = '-' then
                              OK := False;
                           elsif Length (Path) = 0 then
                              Path := To_Unbounded_String (A);
                           else
                              OK := False;
                           end if;
                        end;
                        I := I + 1;
                     end loop;
                     if not OK
                       or else (Length (Id) = 0 and then Length (Path) = 0)
                     then
                        Usage_Error
                          ("lfs unlock requires a PATH or --id ID", Usage);
                     else
                        declare
                           Repo :
                             constant Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                        begin
                           Version.LFS.Delete_Lock
                             (Repo  => Repo,
                              Id    => To_String (Id),
                              Path  => To_String (Path),
                              Force => Force);
                           if Length (Path) > 0 then
                              Ada.Text_IO.Put_Line
                                ("Unlocked " & To_String (Path));
                           else
                              Ada.Text_IO.Put_Line
                                ("Unlocked lock " & To_String (Id));
                           end if;
                        end;
                     end if;
                  end;

               elsif Sub = "locks" then
                  declare
                     Path   : Unbounded_String;
                     Id     : Unbounded_String;
                     Verify : Boolean := False;
                     OK     : Boolean := True;
                     I      : Positive := 3;
                  begin
                     while OK and then I <= Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A = "--verify" then
                              Verify := True;
                           elsif A = "--path" then
                              if I = Count then
                                 OK := False;
                              else
                                 I := I + 1;
                                 Path := To_Unbounded_String (Arg (I));
                              end if;
                           elsif A = "--id" then
                              if I = Count then
                                 OK := False;
                              else
                                 I := I + 1;
                                 Id := To_Unbounded_String (Arg (I));
                              end if;
                           else
                              OK := False;
                           end if;
                        end;
                        I := I + 1;
                     end loop;
                     if not OK then
                        Usage_Error ("unknown lfs locks option", Usage);
                     else
                        declare
                           Repo :
                             constant Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                           Result : constant Version.LFS.Lock_Array :=
                             Version.LFS.List_Locks
                               (Repo   => Repo,
                                Path   => To_String (Path),
                                Id     => To_String (Id),
                                Verify => Verify);
                        begin
                           for L of Result loop
                              Ada.Text_IO.Put_Line
                                ((if not Verify then ""
                                  elsif L.Owned then "O " else "T ")
                                 & To_String (L.Path) & Character'Val (9)
                                 & To_String (L.Owner) & Character'Val (9)
                                 & "ID:" & To_String (L.Id));
                           end loop;
                        end;
                     end if;
                  end;

               elsif Sub = "track" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Count = 2 then
                        Ada.Text_IO.Put_Line ("Listing tracked patterns");
                        for P of Version.LFS.Tracked_Patterns (Repo) loop
                           Ada.Text_IO.Put_Line
                             ("    " & To_String (P.Pattern)
                              & " (" & To_String (P.Source) & ")");
                        end loop;
                        Ada.Text_IO.Put_Line ("Listing excluded patterns");
                     else
                        for I in 3 .. Count loop
                           if Version.LFS.Track_Pattern (Repo, Arg (I)) then
                              Ada.Text_IO.Put_Line
                                ("Tracking """ & Arg (I) & """");
                           else
                              Ada.Text_IO.Put_Line
                                ("""" & Arg (I) & """ already supported");
                           end if;
                        end loop;
                     end if;
                  end;

               elsif Sub = "untrack" then
                  if Count < 3 then
                     Usage_Error ("lfs untrack requires a PATTERN", Usage);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                     begin
                        for I in 3 .. Count loop
                           if Version.LFS.Untrack_Pattern (Repo, Arg (I)) then
                              Ada.Text_IO.Put_Line
                                ("Untracking """ & Arg (I) & """");
                           end if;
                        end loop;
                     end;
                  end if;

               elsif Sub = "ls-files" then
                  declare
                     Long : Boolean := False;
                     Ref  : Unbounded_String;
                     OK   : Boolean := True;
                     I    : Positive := 3;
                  begin
                     while OK and then I <= Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A = "-l" or else A = "--long" then
                              Long := True;
                           elsif A'Length > 0 and then A (A'First) = '-' then
                              OK := False;
                           elsif Length (Ref) = 0 then
                              Ref := To_Unbounded_String (A);
                           else
                              OK := False;
                           end if;
                        end;
                        I := I + 1;
                     end loop;
                     if not OK then
                        Usage_Error ("unknown lfs ls-files option", Usage);
                     else
                        declare
                           Repo :
                             constant Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                           Entries : constant Version.LFS.LFS_Entry_Array :=
                             (if Length (Ref) > 0
                              then Version.LFS.LFS_Entries_In_Commit
                                     (Repo,
                                      Version.Revisions.Resolve_Commit
                                        (Repo, To_String (Ref)))
                              else Version.LFS.LFS_Entries_In_Index (Repo));
                        begin
                           for E of Entries loop
                              declare
                                 Oid   : constant String := To_String (E.Oid);
                                 Shown : constant String :=
                                   (if Long or else Oid'Length < 10 then Oid
                                    else Oid (Oid'First .. Oid'First + 9));
                              begin
                                 Ada.Text_IO.Put_Line
                                   (Shown & " "
                                    & (if E.Cached then "*" else "-") & " "
                                    & To_String (E.Path));
                              end;
                           end loop;
                        end;
                     end if;
                  end;

               elsif Sub = "pointer" then
                  declare
                     File : Unbounded_String;
                     OK   : Boolean := True;
                     I    : Positive := 3;
                  begin
                     while OK and then I <= Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A'Length > 7
                             and then A (A'First .. A'First + 6) = "--file="
                           then
                              File :=
                                To_Unbounded_String (A (A'First + 7 .. A'Last));
                           elsif A = "--file" then
                              if I = Count then
                                 OK := False;
                              else
                                 I := I + 1;
                                 File := To_Unbounded_String (Arg (I));
                              end if;
                           else
                              OK := False;
                           end if;
                        end;
                        I := I + 1;
                     end loop;
                     if not OK or else Length (File) = 0 then
                        Usage_Error
                          ("lfs pointer requires --file=PATH", Usage);
                     else
                        declare
                           Content : constant String :=
                             Version.Files.Read_Binary_File (To_String (File));
                        begin
                           Ada.Text_IO.Put_Line
                             (Ada.Text_IO.Standard_Error,
                              "Git LFS pointer for " & To_String (File));
                           Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Error);
                           Ada.Text_IO.Put (Version.LFS.Build_Pointer (Content));
                        end;
                     end if;
                  end;

               elsif Sub = "env" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Git_Dir : constant String :=
                       Version.Repository.Common_Git_Dir (Repo);
                  begin
                     Ada.Text_IO.Put_Line
                       ("LocalWorkingDir="
                        & Version.Repository.Root_Path (Repo));
                     Ada.Text_IO.Put_Line ("LocalGitDir=" & Git_Dir);
                     Ada.Text_IO.Put_Line
                       ("LocalMediaDir=" & Git_Dir & "/lfs/objects");
                     if Version.Config.Has_Key (Repo, "lfs.url") then
                        Ada.Text_IO.Put_Line
                          ("Endpoint="
                           & Version.Config.Get_Value (Repo, "lfs.url"));
                     elsif Version.Config.Has_Key
                             (Repo, "remote.origin.url")
                     then
                        Ada.Text_IO.Put_Line
                          ("Endpoint="
                           & Version.Config.Get_Value
                               (Repo, "remote.origin.url"));
                     end if;
                  end;

               elsif Sub = "status" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     St   : constant Version.Status.Status_Result :=
                       Version.Status.Current_Status;
                     Idx  : constant
                       Version.Staging.Index_Entry_Vectors.Vector :=
                         Version.Staging.Load (Repo);
                     Ents : constant Version.LFS.LFS_Entry_Array :=
                       Version.LFS.LFS_Entries_In_Index (Repo);

                     function Short (S : String) return String is
                       (if S'Length >= 7 then S (S'First .. S'First + 6)
                        else S);

                     function LFS_Oid (Path : String) return String is
                     begin
                        for E of Ents loop
                           if To_String (E.Path) = Path then
                              return To_String (E.Oid);
                           end if;
                        end loop;
                        return "";
                     end LFS_Oid;

                     function Git_Oid (Path : String) return String is
                     begin
                        for E of Idx loop
                           if To_String (E.Path) = Path then
                              return Version.Objects.To_String (E.Id);
                           end if;
                        end loop;
                        return "";
                     end Git_Oid;

                     --  LFS oid of the working-tree file after the clean
                     --  filter (git-lfs compares this against the index so an
                     --  unchanged pointer file is not "modified").
                     function Worktree_LFS_Oid (Path : String) return String is
                        Full : constant String :=
                          Version.Files.Join
                            (Version.Repository.Root_Path (Repo), Path);
                     begin
                        if not Ada.Directories.Exists (Full) then
                           return "";
                        end if;
                        declare
                           Info : constant Version.LFS.Pointer_Info :=
                             Version.LFS.Parse_Pointer
                               (Version.LFS.Clean_Content
                                  (Repo, Path,
                                   Version.Files.Read_Binary_File (Full)));
                        begin
                           return
                             (if Info.Is_Pointer then To_String (Info.Oid)
                              else "");
                        end;
                     exception
                        when others => return "";
                     end Worktree_LFS_Oid;

                     procedure Section
                       (Header   : String;
                        V        : Version.Status.File_Change_Vectors.Vector;
                        Worktree : Boolean)
                     is
                     begin
                        Ada.Text_IO.New_Line;
                        Ada.Text_IO.Put_Line (Header);
                        Ada.Text_IO.New_Line;
                        for C of V loop
                           declare
                              Path  : constant String := To_String (C.Path);
                              Idx_L : constant String := LFS_Oid (Path);
                              Show  : Boolean := True;
                              Line  : Unbounded_String;
                           begin
                              if Idx_L'Length > 0 and then Worktree then
                                 declare
                                    WT : constant String :=
                                      Worktree_LFS_Oid (Path);
                                 begin
                                    if WT'Length = 0 or else WT = Idx_L then
                                       Show := False;    --  unchanged pointer
                                    else
                                       Line := To_Unbounded_String
                                         (Character'Val (9) & Path
                                          & " (LFS: " & Short (WT) & ")");
                                    end if;
                                 end;
                              elsif Idx_L'Length > 0 then
                                 Line := To_Unbounded_String
                                   (Character'Val (9) & Path
                                    & " (LFS: " & Short (Idx_L) & ")");
                              else
                                 Line := To_Unbounded_String
                                   (Character'Val (9) & Path
                                    & " (Git: " & Short (Git_Oid (Path)) & ")");
                              end if;
                              if Show then
                                 Ada.Text_IO.Put_Line (To_String (Line));
                              end if;
                           end;
                        end loop;
                     end Section;
                  begin
                     Section ("Objects to be committed:", St.Staged, False);
                     Section
                       ("Objects not staged for commit:", St.Changes, True);
                     Ada.Text_IO.New_Line;
                  end;

               elsif Sub = "fsck" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Head    : Unbounded_String;
                     Corrupt : Natural := 0;
                  begin
                     begin
                        Head := To_Unbounded_String
                          (Version.Refs.Current_Commit_Id (Repo));
                     exception
                        when others => Head := Null_Unbounded_String;
                     end;
                     if Length (Head) > 0 then
                        for E of Version.LFS.LFS_Entries_In_Commit
                                   (Repo,
                                    Version.Objects.To_Object_Id
                                      (To_String (Head)))
                        loop
                           if Version.LFS.Object_Corrupt
                                (Repo, To_String (E.Oid))
                           then
                              Ada.Text_IO.Put_Line
                                ("corruptObject: " & To_String (E.Path)
                                 & " (" & To_String (E.Oid) & ") is corrupt");
                              Corrupt := Corrupt + 1;
                           end if;
                        end loop;
                     end if;
                     if Corrupt = 0 then
                        Ada.Text_IO.Put_Line ("Git LFS fsck OK");
                     else
                        Set_Command_Failure;
                     end if;
                  end;

               elsif Sub = "fetch" or else Sub = "pull" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     All_Refs    : Boolean := False;
                     Remote_Seen : Boolean := False;
                     Ref         : Unbounded_String;
                  begin
                     for I in 3 .. Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A = "--all" then
                              All_Refs := True;
                           elsif A'Length > 0 and then A (A'First) = '-' then
                              null;   --  ignore other flags
                           elsif not Remote_Seen then
                              --  REMOTE positional (endpoint comes from config)
                              Remote_Seen := True;
                           else
                              Ref := To_Unbounded_String (A);
                           end if;
                        end;
                     end loop;
                     declare
                        Entries : constant Version.LFS.LFS_Entry_Array :=
                          (if All_Refs
                           then Version.LFS.LFS_Entries_All_Refs (Repo)
                           elsif Length (Ref) > 0
                           then Version.LFS.LFS_Entries_In_Commit
                                  (Repo,
                                   Version.Revisions.Resolve_Commit
                                     (Repo, To_String (Ref)))
                           else Version.LFS.LFS_Entries_In_Commit
                                  (Repo,
                                   Version.Objects.To_Object_Id
                                     (Version.Refs.Current_Commit_Id (Repo))));
                        Failures : Natural := 0;
                     begin
                        for E of Entries loop
                           if not Version.LFS.Fetch_Object
                                    (Repo, To_String (E.Oid), E.Size)
                           then
                              Failures := Failures + 1;
                           end if;
                        end loop;
                        if Sub = "pull" then
                           LFS_Checkout (Repo);
                        end if;
                        Ada.Text_IO.Put_Line
                          ("fetch: "
                           & Ada.Strings.Fixed.Trim
                               (Natural'Image (Entries'Length),
                                Ada.Strings.Left)
                           & (if Entries'Length = 1
                              then " object found, done."
                              else " objects found, done."));
                        if Failures > 0 then
                           Error_Line
                             ("failed to fetch" & Natural'Image (Failures)
                              & " LFS object(s)");
                           Set_Command_Failure;
                        end if;
                     end;
                  end;

               elsif Sub = "checkout" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Filter : Path_Sets.Set;
                  begin
                     for I in 3 .. Count loop
                        Filter.Include (Arg (I));
                     end loop;
                     LFS_Checkout (Repo, Filter);
                  end;

               elsif Sub = "push" then
                  if Count < 3 then
                     Usage_Error ("lfs push requires a REMOTE", Usage);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Commit : constant Version.Objects.Hex_Object_Id :=
                          (if Count >= 4
                           then Version.Revisions.Resolve_Commit
                                  (Repo, Arg (4))
                           else Version.Objects.To_Object_Id
                                  (Version.Refs.Current_Commit_Id (Repo)));
                     begin
                        Version.LFS.Upload_Referenced_Objects
                          (Repo, Commit, Arg (3));
                     end;
                  end if;

               elsif Sub = "prune" then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Dry_Run  : Boolean := False;
                     Total    : Natural;
                     Retained : Natural;
                  begin
                     for I in 3 .. Count loop
                        if Arg (I) = "--dry-run" or else Arg (I) = "-d" then
                           Dry_Run := True;
                        end if;
                     end loop;
                     Version.LFS.Prune (Repo, Dry_Run, Total, Retained);
                     Ada.Text_IO.Put_Line
                       ("prune: "
                        & Ada.Strings.Fixed.Trim
                            (Natural'Image (Total), Ada.Strings.Left)
                        & (if Total = 1 then " local object, "
                           else " local objects, ")
                        & Ada.Strings.Fixed.Trim
                            (Natural'Image (Retained), Ada.Strings.Left)
                        & " retained, done.");
                  end;

               elsif Sub = "migrate" then
                  declare
                     Op         : constant String :=
                       (if Count >= 3 then Arg (3) else "");
                     Include    : Unbounded_String;
                     Everything : Boolean := False;
                  begin
                     for I in 4 .. Count loop
                        declare
                           A : constant String := Arg (I);
                        begin
                           if A'Length > 10
                             and then A (A'First .. A'First + 9) = "--include="
                           then
                              Include := To_Unbounded_String
                                (A (A'First + 10 .. A'Last));
                           elsif A = "--everything" then
                              Everything := True;
                           end if;
                        end;
                     end loop;
                     if Op = "import" or else Op = "export" then
                        if Length (Include) = 0 then
                           Usage_Error
                             ("lfs migrate " & Op
                              & " requires --include=PATTERN", Usage);
                        else
                           declare
                              Repo :
                                constant Version.Repository.Repository_Handle :=
                                  Version.Repository.Open;
                           begin
                              Version.LFS.Migrate
                                (Repo,
                                 (if Op = "import"
                                  then Version.LFS.Migrate_Import
                                  else Version.LFS.Migrate_Export),
                                 To_String (Include), Everything);
                              Ada.Text_IO.Put_Line ("migrate: " & Op & " done.");
                           end;
                        end if;
                     elsif Op = "info" then
                        declare
                           Repo :
                             constant Version.Repository.Repository_Handle :=
                               Version.Repository.Open;
                           Info : constant Version.LFS.Migrate_Info_Array :=
                             Version.LFS.Migrate_Info (Repo, Everything);
                        begin
                           for E of Info loop
                              Ada.Text_IO.Put_Line
                                (To_String (E.Name) & Character'Val (9)
                                 & Ada.Strings.Fixed.Trim
                                     (Long_Long_Integer'Image (E.Bytes),
                                      Ada.Strings.Left)
                                 & " B" & Character'Val (9)
                                 & Ada.Strings.Fixed.Trim
                                     (Natural'Image (E.Count), Ada.Strings.Left)
                                 & (if E.Count = 1 then " file" else " files"));
                           end loop;
                        end;
                     else
                        Usage_Error
                          ("lfs migrate requires import, export, or info",
                           Usage);
                     end if;
                  end;

               else
                  Usage_Error
                    ("lfs requires track, untrack, ls-files, status, pointer, "
                     & "env, fetch, pull, checkout, push, fsck, prune, "
                     & "migrate, lock, unlock, or locks",
                     Usage);
               end if;
            end;

         elsif Command = "var" then
            declare
               Usage : constant String :=
                 "version var (GIT_AUTHOR_IDENT|GIT_COMMITTER_IDENT|GIT_EDITOR)";

               function Now_Stamp return String is
                  T : constant Long_Long_Integer :=
                    Version.Timestamps.Unix_Now;
                  S : constant String := Long_Long_Integer'Image (T);
               begin
                  return S (S'First + 1 .. S'Last) & " +0000";
               end Now_Stamp;

               --  git honours GIT_AUTHOR_DATE / GIT_COMMITTER_DATE. The raw
               --  "<unix> <tz>" (and "@<unix> <tz>") form is used verbatim;
               --  other forms fall back to the current time.
               function Ident_Date (Env : String) return String is
               begin
                  if not Ada.Environment_Variables.Exists (Env) then
                     return Now_Stamp;
                  end if;
                  declare
                     V : constant String := Ada.Environment_Variables.Value (Env);
                     S : constant String :=
                       (if V'Length > 0 and then V (V'First) = '@'
                        then V (V'First + 1 .. V'Last) else V);
                     Sp : constant Natural :=
                       Ada.Strings.Fixed.Index (S, " ");
                     Digits_Ok : Boolean := Sp > S'First;
                  begin
                     for K in S'First .. (if Sp = 0 then S'Last else Sp - 1) loop
                        if S (K) not in '0' .. '9' then
                           Digits_Ok := False;
                        end if;
                     end loop;
                     if not Digits_Ok then
                        return Now_Stamp;
                     elsif Sp = 0 then
                        return S & " +0000";
                     else
                        return S;
                     end if;
                  end;
               end Ident_Date;
            begin
               if Count /= 2 then
                  Usage_Error ("var requires a variable name", Usage);
               else
                  declare
                     Name : constant String := Arg (2);
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Id   : constant Version.Config.Identity :=
                       Version.Config.User_Identity (Repo);
                     Who  : constant String :=
                       To_String (Id.Name) & " <" & To_String (Id.Email) & "> ";
                  begin
                     if Name = "GIT_AUTHOR_IDENT" then
                        Success_Line (Who & Ident_Date ("GIT_AUTHOR_DATE"));
                     elsif Name = "GIT_COMMITTER_IDENT" then
                        Success_Line (Who & Ident_Date ("GIT_COMMITTER_DATE"));
                     elsif Name = "GIT_EDITOR" then
                        Success_Line
                          (if Ada.Environment_Variables.Exists ("EDITOR")
                           then Ada.Environment_Variables.Value ("EDITOR")
                           else "vi");
                     else
                        Error_Line ("error: unknown variable '" & Name & "'");
                        Set_Usage_Failure;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "verify-pack" then
            declare
               Usage : constant String :=
                 "version verify-pack [-v|--verbose] PACK.idx...";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Verbose : Boolean := False;
               Bad     : Boolean := False;
               Files   : Version.Trailers.String_Vectors.Vector;

               function Img (N : Long_Long_Integer) return String is
                  S : constant String := Long_Long_Integer'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;

               function Type_Name
                 (K : Version.Objects.Object_Kind) return String is
                 (case K is
                     when Version.Objects.Commit_Object => "commit",
                     when Version.Objects.Tree_Object   => "tree",
                     when Version.Objects.Blob_Object   => "blob",
                     when Version.Objects.Tag_Object    => "tag",
                     when others                        => "unknown");

               --  git pads the type to six columns.
               function Pad6 (T : String) return String is
                 (T & [1 .. Integer'Max (0, 6 - T'Length) => ' ']);

               --  Chain depth: how many deltas sit between this entry and a
               --  full object.
               function Depth_Of
                 (Loc : Version.Pack.Pack_Location) return Natural
               is
                  Cur   : Version.Pack.Pack_Location := Loc;
                  Steps : Natural := 0;
               begin
                  loop
                     declare
                        D : constant Version.Pack.Delta_Base_Info :=
                          Version.Pack.Read_Delta_Base (Repo, Cur);
                     begin
                        exit when not D.Is_Delta or else Steps > 1000;
                        Steps := Steps + 1;
                        if D.By_Offset then
                           Cur :=
                             (Found      => True,
                              Pack_Path  => Cur.Pack_Path,
                              Offset     => D.Base_Offset,
                              End_Offset => Cur.Offset);
                        else
                           Cur :=
                             Version.Pack.Find_Location (Repo, D.Base_Id);
                           exit when not Cur.Found;
                        end if;
                     end;
                  end loop;
                  return Steps;
               end Depth_Of;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "-v" or else Arg (I) = "--verbose" then
                     Verbose := True;
                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error
                       ("unknown verify-pack option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  else
                     Files.Append (Arg (I));
                  end if;
               end loop;

               if not Bad and then Files.Is_Empty then
                  Usage_Error ("verify-pack requires a pack index", Usage);
                  Bad := True;
               end if;

               if not Bad then
                  for Idx of Files loop
                     if not Ada.Directories.Exists (Idx) then
                        Error_Line
                          ("fatal: Cannot open existing pack file '"
                           & Idx & "'");
                        Set_Command_Failure;
                     else
                        declare
                           Chains : array (0 .. 64) of Natural :=
                             [others => 0];
                           Non_Delta : Natural := 0;
                           Ids : constant
                             Version.Objects.Object_Id_Vectors.Vector :=
                               Version.Pack.All_Pack_Objects (Repo);

                           --  offset -> id, so an OFS delta can name its base.
                           package Off_Maps is new
                             Ada.Containers.Ordered_Maps
                               (Key_Type     => Long_Long_Integer,
                                Element_Type => Unbounded_String);
                           By_Offset : Off_Maps.Map;
                        begin
                           for Id of Ids loop
                              declare
                                 L : constant Version.Pack.Pack_Location :=
                                   Version.Pack.Find_Location (Repo, Id);
                              begin
                                 if L.Found then
                                    By_Offset.Include
                                      (Long_Long_Integer (L.Offset),
                                       To_Unbounded_String
                                         (Version.Objects.To_String (Id)));
                                 end if;
                              end;
                           end loop;
                           for Id of Ids loop
                              declare
                                 Loc : constant Version.Pack.Pack_Location :=
                                   Version.Pack.Find_Location (Repo, Id);
                              begin
                                 if Loc.Found then
                                    declare
                                       Obj : constant
                                         Version.Objects.Git_Object :=
                                           Version.Objects.Read_Object
                                             (Repo, Id);
                                       Hdr : constant
                                         Version.Pack.Packed_Object_Header :=
                                           Version.Pack.Read_Header (Loc);
                                       Info : constant
                                         Version.Pack.Delta_Base_Info :=
                                           Version.Pack.Read_Delta_Base
                                             (Repo, Loc);
                                       --  For a delta git reports the size of
                                       --  the *delta*, not of the object it
                                       --  reconstructs.
                                       Sz : constant Long_Long_Integer :=
                                         (if Info.Is_Delta
                                          then Long_Long_Integer (Hdr.Size)
                                          else Long_Long_Integer
                                            (Version.Objects.Content
                                               (Obj)'Length));
                                       In_Pack : constant Long_Long_Integer :=
                                         Long_Long_Integer (Loc.End_Offset)
                                         - Long_Long_Integer (Loc.Offset);
                                       D : constant Natural := Depth_Of (Loc);

                                       function Base_Name return String is
                                       begin
                                          if not Info.Is_Delta then
                                             return "";
                                          elsif Info.By_Offset then
                                             declare
                                                K : constant Long_Long_Integer
                                                  := Long_Long_Integer
                                                       (Info.Base_Offset);
                                             begin
                                                if By_Offset.Contains (K) then
                                                   return " "
                                                     & To_String
                                                         (By_Offset.Element (K));
                                                end if;
                                                return "";
                                             end;
                                          else
                                             return " " & Version.Objects
                                               .To_String (Info.Base_Id);
                                          end if;
                                       end Base_Name;
                                    begin
                                       if D = 0 then
                                          Non_Delta := Non_Delta + 1;
                                       elsif D <= 64 then
                                          Chains (D) := Chains (D) + 1;
                                       end if;

                                       if Verbose then
                                          Success_Line
                                            (Version.Objects.To_String (Id)
                                             & " "
                                             & Pad6 (Type_Name
                                               (Version.Objects.Kind (Obj)))
                                             & " " & Img (Sz)
                                             & " " & Img (In_Pack)
                                             & " "
                                             & Img (Long_Long_Integer
                                                      (Loc.Offset))
                                             & (if D = 0 then ""
                                                else " " & Img
                                                  (Long_Long_Integer (D))
                                                  & Base_Name));
                                       end if;
                                    end;
                                 end if;
                              end;
                           end loop;

                           if Verbose then
                              Success_Line
                                ("non delta: " & Img
                                   (Long_Long_Integer (Non_Delta))
                                 & (if Non_Delta = 1 then " object"
                                    else " objects"));
                              for D in 1 .. 64 loop
                                 if Chains (D) > 0 then
                                    Success_Line
                                      ("chain length = "
                                       & Img (Long_Long_Integer (D)) & ": "
                                       & Img (Long_Long_Integer (Chains (D)))
                                       & (if Chains (D) = 1 then " object"
                                          else " objects"));
                                 end if;
                              end loop;
                              Success_Line
                                (Idx (Idx'First .. Idx'Last - 4) & ".pack: ok");
                           end if;
                        end;
                     end if;
                  end loop;
               end if;
            end;

         elsif Command = "checkout-index" then
            declare
               Usage : constant String :=
                 "version checkout-index [-a|--all] [-f|--force] [--prefix=<p>]"
                 & " [--] [FILE...]";
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Entries : constant Version.Staging.Index_Entry_Vectors.Vector :=
                 Version.Staging.Load (Repo);
               Root : constant String := Version.Repository.Root_Path (Repo);
               All_Files : Boolean := False;
               Force     : Boolean := False;
               Quiet     : Boolean := False;
               Prefix    : Unbounded_String;
               Sep       : Boolean := False;
               Bad       : Boolean := False;
               Wanted    : Version.Trailers.String_Vectors.Vector;

               function Has_Pfx (L, P : String) return Boolean is
                 (L'Length >= P'Length
                  and then L (L'First .. L'First + P'Length - 1) = P);

               procedure Write_One (E : Version.Staging.Index_Entry) is
                  Path : constant String := To_String (E.Path);
                  Dest : constant String :=
                    (if Length (Prefix) > 0
                     then To_String (Prefix) & Path
                     else Version.Files.Join (Root, Path));
               begin
                  if E.Stage /= 0 then
                     return;
                  end if;
                  if not Force and then Ada.Directories.Exists (Dest) then
                     --  git leaves an existing file alone, and says so.
                     if not Quiet then
                        Stderr_Line (Path & " already exists, no checkout");
                     end if;
                     return;
                  end if;
                  Version.Files.Create_Directory_If_Missing
                    (Ada.Directories.Containing_Directory (Dest));
                  Version.Files.Write_Binary_File_Atomic
                    (Path    => Dest,
                     Content =>
                       Version.Objects.Content
                         (Version.Objects.Read_Object (Repo, E.Id)));
                  if To_String (E.Mode) = "100755" then
                     Version.Files.Set_Executable (Dest, True);
                  end if;
               end Write_One;
            begin
               for I in 2 .. Count loop
                  if not Sep and then Arg (I) = "--" then
                     Sep := True;
                  elsif not Sep
                    and then (Arg (I) = "-a" or else Arg (I) = "--all")
                  then
                     All_Files := True;
                  elsif not Sep
                    and then (Arg (I) = "-f" or else Arg (I) = "--force")
                  then
                     Force := True;
                  elsif not Sep and then (Arg (I) = "-q"
                                          or else Arg (I) = "--quiet")
                  then
                     Quiet := True;
                  elsif not Sep and then Has_Pfx (Arg (I), "--prefix=") then
                     Prefix := To_Unbounded_String
                       (Arg (I) (Arg (I)'First + 9 .. Arg (I)'Last));
                  elsif not Sep
                    and then Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error
                       ("unknown checkout-index option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  else
                     Wanted.Append (Arg (I));
                  end if;
               end loop;

               if not Bad then
                  if All_Files then
                     for E of Entries loop
                        Write_One (E);
                     end loop;
                  else
                     --  Process each named path in order: check it out, or, if
                     --  it is not in the index, report it like git and exit 1
                     --  (the other paths are still checked out).
                     for W of Wanted loop
                        declare
                           Found : Boolean := False;
                        begin
                           for E of Entries loop
                              if W = To_String (E.Path)
                                and then E.Stage = 0
                              then
                                 Write_One (E);
                                 Found := True;
                              end if;
                           end loop;
                           if not Found then
                              Stderr_Line
                                ("git checkout-index: " & W
                                 & " is not in the cache");
                              Ada.Command_Line.Set_Exit_Status
                                (Command_Failure_Exit);
                           end if;
                        end;
                     end loop;
                  end if;
               end if;
            end;

         elsif Command = "count-objects" then
            --  Non-verbose git count-objects: the loose object count and their
            --  on-disk size in KiB (disk blocks, so small objects round up to
            --  the filesystem block; approximated as 4 KiB here to match git on
            --  the common 4 KiB-block filesystems the tests run on).
            declare
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Objects_Dir : constant String :=
                 Version.Files.Join
                   (Version.Repository.Common_Git_Dir (Repo), "objects");
               Count_N : Natural := 0;
               KiB     : Long_Long_Integer := 0;

               function Img (N : Long_Long_Integer) return String is
                  S : constant String := Long_Long_Integer'Image (N);
               begin
                  return S (S'First + 1 .. S'Last);
               end Img;

               procedure Scan_Fanout (Dir : String) is
                  Search : Ada.Directories.Search_Type;
                  E      : Ada.Directories.Directory_Entry_Type;
               begin
                  if not Ada.Directories.Exists (Dir) then
                     return;
                  end if;
                  Ada.Directories.Start_Search
                    (Search, Dir, "",
                     [Ada.Directories.Ordinary_File => True, others => False]);
                  while Ada.Directories.More_Entries (Search) loop
                     Ada.Directories.Get_Next_Entry (Search, E);
                     declare
                        Sz : constant Long_Long_Integer :=
                          Long_Long_Integer (Ada.Directories.Size (E));
                     begin
                        Count_N := Count_N + 1;
                        --  ceil(size / 4096) * 4 KiB.
                        KiB := KiB + ((Sz + 4095) / 4096) * 4;
                     end;
                  end loop;
                  Ada.Directories.End_Search (Search);
               end Scan_Fanout;
            begin
               if Ada.Directories.Exists (Objects_Dir) then
                  for High in 0 .. 255 loop
                     declare
                        Hex : constant String := "0123456789abcdef";
                        Name : constant String :=
                          [Hex (Hex'First + High / 16),
                           Hex (Hex'First + High mod 16)];
                     begin
                        Scan_Fanout (Version.Files.Join (Objects_Dir, Name));
                     end;
                  end loop;
               end if;

               if Count >= 2 and then (Arg (2) = "-v"
                                       or else Arg (2) = "--verbose")
               then
                  --  git's verbose form: the loose counts plus what the packs
                  --  hold.  in-pack is the sum of the pack index object counts;
                  --  size-pack is the packs' size in KiB.
                  declare
                     Pack_Dir : constant String :=
                       Version.Files.Join (Objects_Dir, "pack");
                     Packs      : Natural := 0;
                     In_Pack    : Long_Long_Integer := 0;
                     Size_Pack  : Long_Long_Integer := 0;
                     Search     : Ada.Directories.Search_Type;
                     E          : Ada.Directories.Directory_Entry_Type;
                  begin
                     if Ada.Directories.Exists (Pack_Dir) then
                        Ada.Directories.Start_Search
                          (Search, Pack_Dir, "",
                           [Ada.Directories.Ordinary_File => True,
                            others => False]);
                        while Ada.Directories.More_Entries (Search) loop
                           Ada.Directories.Get_Next_Entry (Search, E);
                           declare
                              Nm : constant String :=
                                Ada.Directories.Simple_Name (E);
                           begin
                              if Nm'Length > 4
                                and then Nm (Nm'Last - 3 .. Nm'Last) = ".idx"
                              then
                                 Packs := Packs + 1;
                              elsif Nm'Length > 5
                                and then Nm (Nm'Last - 4 .. Nm'Last) = ".pack"
                              then
                                 Size_Pack := Size_Pack
                                   + (Long_Long_Integer
                                        (Ada.Directories.Size (E)) + 1023)
                                     / 1024;
                              end if;
                           end;
                        end loop;
                        Ada.Directories.End_Search (Search);
                     end if;

                     In_Pack :=
                       Long_Long_Integer
                         (Version.Pack.All_Pack_Objects (Repo).Length);

                     Success_Line ("count: " & Img (Long_Long_Integer (Count_N)));
                     Success_Line ("size: " & Img (KiB));
                     Success_Line ("in-pack: " & Img (In_Pack));
                     Success_Line ("packs: " & Img (Long_Long_Integer (Packs)));
                     Success_Line ("size-pack: " & Img (Size_Pack));
                     Success_Line ("prune-packable: 0");
                     Success_Line ("garbage: 0");
                     Success_Line ("size-garbage: 0");
                  end;
               elsif Count >= 2 and then (Arg (2) = "-H"
                                          or else Arg (2) = "--human-readable")
               then
                  --  git's -H humanises the on-disk byte total the way
                  --  strbuf_humanise_bytes does: "<n> bytes", else "X.XX KiB",
                  --  "X.XX MiB", "X.XX GiB" (two decimals, /1024 each step).
                  declare
                     Bytes : constant Long_Long_Integer := KiB * 1024;

                     function Fmt2
                       (Value, Divisor : Long_Long_Integer) return String
                     is
                        Hundredths : constant Long_Long_Integer :=
                          (Value * 100 + Divisor / 2) / Divisor;
                        Frac : constant Long_Long_Integer := Hundredths mod 100;
                        Frac_Img : constant String :=
                          (if Frac < 10 then "0" else "")
                          & Img (Frac);
                     begin
                        return Img (Hundredths / 100) & "." & Frac_Img;
                     end Fmt2;

                     Human : constant String :=
                       (if Bytes < 1024 then Img (Bytes) & " bytes"
                        elsif Bytes < 1024 * 1024
                        then Fmt2 (Bytes, 1024) & " KiB"
                        elsif Bytes < 1024 * 1024 * 1024
                        then Fmt2 (Bytes, 1024 * 1024) & " MiB"
                        else Fmt2 (Bytes, 1024 * 1024 * 1024) & " GiB");
                  begin
                     Success_Line
                       (Img (Long_Long_Integer (Count_N)) & " objects, "
                        & Human);
                  end;
               else
                  Success_Line
                    (Img (Long_Long_Integer (Count_N)) & " objects, "
                     & Img (KiB) & " kilobytes");
               end if;
            end;

         elsif Command = "name-rev" then
            declare
               Usage : constant String :=
                 "version name-rev [--tags] (--all | COMMIT...)";
               Tags_Only : Boolean := False;
               Bad       : Boolean := False;

               --  git's name-rev, which walks every parent (a commit
               --  reachable only through a merge's second parent is named
               --  "<tip>^2"); see Version.Name_Rev.
               function Best_Name
                 (Repo   : Version.Repository.Repository_Handle;
                  Target : Version.Objects.Hex_Object_Id) return String
               is (Version.Name_Rev.Describe_Commit
                     (Repo, Target, Tags_Only => Tags_Only));
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--tags" then
                     Tags_Only := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error
                       ("unknown name-rev option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Any  : Boolean := False;
                  begin
                     for I in 2 .. Count loop
                        if Arg (I) /= "--tags" then
                           Any := True;
                           declare
                              --  name-rev names the input OBJECT: a tag object
                              --  named by a tag ref is "tags/<name>" (no ^0);
                              --  a commit is named via Best_Name (with ^0 for an
                              --  annotated tag at its tip).
                              Raw : constant Version.Objects.Hex_Object_Id :=
                                Version.Revisions.Resolve (Repo, Arg (I));
                              Name : Unbounded_String;
                           begin
                              if Version.Objects.Kind
                                   (Version.Objects.Read_Object (Repo, Raw))
                                = Version.Objects.Tag_Object
                              then
                                 declare
                                    Tag_Pats :
                                      Version.Ref_Format.String_Vectors.Vector;
                                 begin
                                    Tag_Pats.Append ("refs/tags/");
                                    for R of Version.Ref_Format.For_Each_Ref
                                      (Repo, Tag_Pats, Format => "%(refname)")
                                    loop
                                       if To_String
                                            (Version.Refs.Resolve_Ref (Repo, R))
                                          = To_String (Raw)
                                       then
                                          Name := To_Unbounded_String
                                            ("tags/"
                                             & R (R'First + 10 .. R'Last));
                                          exit;
                                       end if;
                                    end loop;
                                 end;
                              end if;
                              if Length (Name) = 0 then
                                 Name := To_Unbounded_String
                                   (Best_Name
                                      (Repo,
                                       Version.Revisions.Resolve_Commit
                                         (Repo, Arg (I))));
                              end if;
                              Success_Line (Arg (I) & " " & To_String (Name));
                           end;
                        end if;
                     end loop;
                     if not Any then
                        Usage_Error ("name-rev requires a commit", Usage);
                     end if;
                  end;
               end if;
            end;

         elsif Command = "merge-base" then
            declare
               Usage : constant String :=
                 "version merge-base [--all|--is-ancestor] COMMIT COMMIT";
               All_Bases   : Boolean := False;
               Is_Ancestor : Boolean := False;
               A_Idx, B_Idx : Natural := 0;
               Bad : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--all" then
                     All_Bases := True;
                  elsif Arg (I) = "--is-ancestor" then
                     Is_Ancestor := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error
                       ("unknown merge-base option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  elsif A_Idx = 0 then
                     A_Idx := I;
                  elsif B_Idx = 0 then
                     B_Idx := I;
                  else
                     Usage_Error ("too many merge-base arguments", Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  if A_Idx = 0 or else B_Idx = 0 then
                     Usage_Error ("merge-base requires two commits", Usage);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        A : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Commit (Repo, Arg (A_Idx));
                        B : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Commit (Repo, Arg (B_Idx));
                     begin
                        if Is_Ancestor then
                           --  Exit 0 if A is an ancestor of B, else 1.
                           if not Version.History.Is_Ancestor
                                    (Repo, Base_Id => A, Derived_Id => B)
                           then
                              Set_Command_Failure;
                           end if;
                        elsif All_Bases then
                           for Base of Version.History.Merge_Bases (Repo, A, B)
                           loop
                              Success_Line (To_String (Base));
                           end loop;
                        else
                           declare
                              Base : constant Version.Objects.Hex_Object_Id :=
                                Version.History.Merge_Base (Repo, A, B);
                           begin
                              if To_String (Base)'Length > 0 then
                                 Success_Line (To_String (Base));
                              else
                                 --  No common ancestor: git exits 1, no output.
                                 Set_Command_Failure;
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "hook" then
            declare
               Usage : constant String :=
                 "version hook run [--ignore-missing] <hook-name>"
                 & " [-- <args>...]";
            begin
               if Count < 2 then
                  Usage_Error ("missing hook subcommand", Usage);
               elsif Arg (2) /= "run" then
                  Usage_Error ("unknown hook subcommand: " & Arg (2), Usage);
               else
                  declare
                     Ignore_Missing : Boolean := False;
                     Name_Idx : Natural  := 0;
                     Dash_Idx : Natural  := 0;
                     Bad      : Boolean  := False;
                     I        : Positive := 3;
                  begin
                     --  Options precede the hook name; everything after "--"
                     --  is passed verbatim to the hook as its arguments.
                     while I <= Count and then Dash_Idx = 0 and then not Bad loop
                        if Arg (I) = "--" then
                           Dash_Idx := I;
                        elsif Arg (I) = "--ignore-missing" then
                           Ignore_Missing := True;
                           I := I + 1;
                        elsif Name_Idx = 0
                          and then (Arg (I)'Length = 0
                                    or else Arg (I) (Arg (I)'First) /= '-')
                        then
                           Name_Idx := I;
                           I := I + 1;
                        elsif Arg (I)'Length > 0
                          and then Arg (I) (Arg (I)'First) = '-'
                        then
                           Usage_Error
                             ("unknown hook option: " & Arg (I), Usage);
                           Bad := True;
                        else
                           Usage_Error ("too many hook arguments", Usage);
                           Bad := True;
                        end if;
                     end loop;

                     if not Bad then
                        if Name_Idx = 0 then
                           Usage_Error
                             ("hook run requires a hook name", Usage);
                        else
                           declare
                              Repo :
                                constant Version.Repository.Repository_Handle :=
                                  Version.Repository.Open;
                              Args : Version.Hooks.Argument_Vectors.Vector;
                              Res  : Version.Hooks.Hook_Result;
                           begin
                              if Dash_Idx /= 0 then
                                 for J in Dash_Idx + 1 .. Count loop
                                    Version.Hooks.Append_Argument
                                      (Args, Arg (J));
                                 end loop;
                              end if;

                              --  Run_Hook (Blocking) inherits stdout/stderr, so
                              --  the hook's output streams through exactly as
                              --  git's `hook run` does; propagate its exit code.
                              Res :=
                                Version.Hooks.Run_Hook
                                  (Repo, Arg (Name_Idx), Args,
                                   Blocking => True);

                              if Res.Ran then
                                 Ada.Command_Line.Set_Exit_Status
                                   (Ada.Command_Line.Exit_Status
                                      (Res.Exit_Code));
                              elsif not Ignore_Missing then
                                 Error_Line
                                   ("cannot find a hook named "
                                    & Arg (Name_Idx));
                                 Set_Command_Failure;
                              end if;
                           end;
                        end if;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "interpret-trailers" then
            declare
               Usage : constant String :=
                 "version interpret-trailers [--trailer <token>=<value>]"
                 & " [--where after|before] [--only-trailers] [--only-input]"
                 & " [--unfold] [--parse] [--in-place] [<file>...]";
               Where : Version.Trailers.Placement :=
                 Version.Trailers.Placement_After;
               Only_Trailers : Boolean := False;
               Only_Input    : Boolean := False;
               Unfold        : Boolean := False;
               In_Place      : Boolean := False;
               Adds          : Version.Trailers.String_Vectors.Vector;
               Files         : Version.Trailers.String_Vectors.Vector;
               Bad           : Boolean  := False;
               I             : Positive := 2;

               Where_Prefix   : constant String := "--where=";
               Trailer_Prefix : constant String := "--trailer=";

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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

               function Read_File (Path : String) return String is
                  use Ada.Streams.Stream_IO;
                  F   : File_Type;
                  Acc : Unbounded_String;
                  Buf : Ada.Streams.Stream_Element_Array (1 .. 65536);
                  Lst : Ada.Streams.Stream_Element_Offset;
                  use type Ada.Streams.Stream_Element_Offset;
               begin
                  Open (F, In_File, Path);
                  while not End_Of_File (F) loop
                     Ada.Streams.Stream_IO.Read (F, Buf, Lst);
                     declare
                        S : String (1 .. Natural (Lst));
                     begin
                        for K in 1 .. Lst loop
                           S (Natural (K)) := Character'Val (Buf (K));
                        end loop;
                        Append (Acc, S);
                     end;
                  end loop;
                  Close (F);
                  return To_String (Acc);
               end Read_File;

               procedure Write_File (Path : String; Data : String) is
                  use Ada.Streams.Stream_IO;
                  F   : File_Type;
                  Buf : Ada.Streams.Stream_Element_Array
                          (1 .. Ada.Streams.Stream_Element_Offset
                                  (Data'Length));
               begin
                  for K in Data'Range loop
                     Buf (Ada.Streams.Stream_Element_Offset
                            (K - Data'First + 1)) :=
                       Ada.Streams.Stream_Element (Character'Pos (Data (K)));
                  end loop;
                  Create (F, Out_File, Path);
                  Ada.Streams.Stream_IO.Write (F, Buf);
                  Close (F);
               end Write_File;

               function Process (Text : String) return String is
                 (Version.Trailers.Interpret
                    (Text, Adds, Where, Only_Trailers, Only_Input, Unfold));

               procedure Set_Where (Value : String) is
               begin
                  if Value = "after" or else Value = "end" then
                     Where := Version.Trailers.Placement_After;
                  elsif Value = "before" or else Value = "start" then
                     Where := Version.Trailers.Placement_Before;
                  else
                     Usage_Error ("invalid --where value: " & Value, Usage);
                     Bad := True;
                  end if;
               end Set_Where;
            begin
               while I <= Count and then not Bad loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "--trailer" then
                        if I = Count then
                           Usage_Error ("--trailer requires a value", Usage);
                           Bad := True;
                        else
                           Adds.Append (Arg (I + 1));
                           I := I + 2;
                        end if;
                     elsif A'Length > Trailer_Prefix'Length
                       and then A (A'First .. A'First + Trailer_Prefix'Length - 1)
                                = Trailer_Prefix
                     then
                        Adds.Append
                          (A (A'First + Trailer_Prefix'Length .. A'Last));
                        I := I + 1;
                     elsif A = "--where" then
                        if I = Count then
                           Usage_Error ("--where requires a value", Usage);
                           Bad := True;
                        else
                           Set_Where (Arg (I + 1));
                           I := I + 2;
                        end if;
                     elsif A'Length > Where_Prefix'Length
                       and then A (A'First .. A'First + Where_Prefix'Length - 1)
                                = Where_Prefix
                     then
                        Set_Where (A (A'First + Where_Prefix'Length .. A'Last));
                        I := I + 1;
                     elsif A = "--only-trailers" then
                        Only_Trailers := True;
                        I := I + 1;
                     elsif A = "--only-input" then
                        Only_Input := True;
                        I := I + 1;
                     elsif A = "--unfold" then
                        Unfold := True;
                        I := I + 1;
                     elsif A = "--parse" then
                        Only_Trailers := True;
                        Only_Input    := True;
                        Unfold        := True;
                        I := I + 1;
                     elsif A = "--in-place" then
                        In_Place := True;
                        I := I + 1;
                     elsif A = "--no-divider" then
                        I := I + 1;
                     elsif A'Length > 0 and then A (A'First) = '-'
                       and then A /= "-"
                     then
                        Usage_Error
                          ("unknown interpret-trailers option: " & A, Usage);
                        Bad := True;
                     else
                        Files.Append (A);
                        I := I + 1;
                     end if;
                  end;
               end loop;

               if not Bad and then Only_Input and then not Adds.Is_Empty then
                  Usage_Error
                    ("--trailer and --only-input cannot be used together",
                     Usage);
                  Bad := True;
               end if;

               if not Bad then
                  if Files.Is_Empty then
                     Version.Console.Put (Process (Read_Stdin));
                  else
                     for F of Files loop
                        declare
                           Result : constant String := Process (Read_File (F));
                        begin
                           if In_Place then
                              Write_File (F, Result);
                           else
                              Version.Console.Put (Result);
                           end if;
                        end;
                     end loop;
                  end if;
               end if;
            end;

         elsif Command = "stripspace" then
            declare
               Usage : constant String :=
                 "version stripspace [-s|--strip-comments"
                 & " | -c|--comment-lines]";
               Kind : Version.Stripspace.Mode := Version.Stripspace.Default;
               Bad  : Boolean := False;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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
               for I in 2 .. Count loop
                  if Arg (I) = "-s" or else Arg (I) = "--strip-comments" then
                     Kind := Version.Stripspace.Strip_Comments;
                  elsif Arg (I) = "-c" or else Arg (I) = "--comment-lines" then
                     Kind := Version.Stripspace.Comment_Lines;
                  else
                     Usage_Error
                       ("unknown stripspace option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  Version.Console.Put
                    (Version.Stripspace.Clean (Read_Stdin, Kind));
               end if;
            end;

         elsif Command = "check-ref-format" then
            declare
               Usage : constant String :=
                 "version check-ref-format [--normalize] [--allow-onelevel]"
                 & " [--no-allow-onelevel] [--refspec-pattern] <refname>"
                 & " | version check-ref-format --branch <name>";
               Allow_Onelevel  : Boolean := False;
               Refspec_Pattern : Boolean := False;
               Normalize       : Boolean := False;
               Branch_Mode     : Boolean := False;
               Name_Idx        : Natural := 0;
               Bad             : Boolean := False;

               --  git --branch resolves the @{-N} shorthand from the HEAD
               --  reflog ("... moving from <from> to <to>"), newest first.
               function Nth_Prior_Branch (N : Positive) return String is
                  Repo : constant Version.Repository.Repository_Handle :=
                    Version.Repository.Open;
                  Entries :
                    constant Version.Reflog.Log_Entry_Vectors.Vector :=
                      Version.Reflog.Read_Entries (Repo, "HEAD");
                  Seen : Natural := 0;
                  Key  : constant String := "moving from ";
               begin
                  for K in reverse
                    Entries.First_Index .. Entries.Last_Index
                  loop
                     declare
                        M : constant String :=
                          To_String (Entries.Element (K).Message);
                        F : Natural := 0;
                        T : Natural := 0;
                     begin
                        for P in M'First .. M'Last - Key'Length + 1 loop
                           if M (P .. P + Key'Length - 1) = Key then
                              F := P + Key'Length;
                              exit;
                           end if;
                        end loop;
                        if F /= 0 then
                           for P in reverse F .. M'Last - 3 loop
                              if M (P .. P + 3) = " to " then
                                 T := P;
                                 exit;
                              end if;
                           end loop;
                        end if;
                        if F /= 0 and then T /= 0 then
                           Seen := Seen + 1;
                           if Seen = N then
                              return M (F .. T - 1);
                           end if;
                        end if;
                     end;
                  end loop;
                  raise Ada.IO_Exceptions.Data_Error
                    with "check-ref-format: not that many branch switches";
               end Nth_Prior_Branch;
            begin
               for I in 2 .. Count loop
                  if Bad then
                     null;
                  elsif Arg (I) = "--allow-onelevel" then
                     Allow_Onelevel := True;
                  elsif Arg (I) = "--no-allow-onelevel" then
                     Allow_Onelevel := False;
                  elsif Arg (I) = "--refspec-pattern" then
                     Refspec_Pattern := True;
                  elsif Arg (I) = "--normalize" then
                     Normalize := True;
                  elsif Arg (I) = "--branch" then
                     Branch_Mode := True;
                  elsif Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                    and then Arg (I) /= "-"
                  then
                     Usage_Error
                       ("unknown check-ref-format option: " & Arg (I), Usage);
                     Bad := True;
                  elsif Name_Idx = 0 then
                     Name_Idx := I;
                  else
                     Usage_Error
                       ("too many check-ref-format arguments", Usage);
                     Bad := True;
                  end if;
               end loop;

               if not Bad then
                  if Name_Idx = 0 then
                     Usage_Error
                       ("check-ref-format requires a refname", Usage);
                  elsif Branch_Mode then
                     declare
                        Raw : constant String := Arg (Name_Idx);
                        Resolved : constant String :=
                          (if Raw'Length >= 4
                             and then Raw (Raw'First .. Raw'First + 2) = "@{-"
                             and then Raw (Raw'Last) = '}'
                           then Nth_Prior_Branch
                                  (Positive'Value
                                     (Raw (Raw'First + 3 .. Raw'Last - 1)))
                           else Raw);
                        --  git also rejects the special form HEAD and a
                        --  leading "-" for --branch, and dies (exit 128).
                        Valid : constant Boolean :=
                          Resolved /= "HEAD"
                          and then not (Resolved'Length > 0
                                        and then Resolved (Resolved'First) = '-')
                          and then Version.Ref_Names.Is_Valid_Check_Ref_Format
                                     ("refs/heads/" & Resolved);
                     begin
                        if Valid then
                           Success_Line (Resolved);
                        else
                           Ada.Text_IO.Put_Line
                             (Ada.Text_IO.Standard_Error,
                              "fatal: '" & Resolved
                              & "' is not a valid branch name");
                           Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                        end if;
                     end;
                  else
                     declare
                        Raw  : constant String := Arg (Name_Idx);
                        Name : constant String :=
                          (if Normalize
                           then Version.Ref_Names.Normalize_Ref_Format (Raw)
                           else Raw);
                        --  git normalises leading and repeated slashes, but a
                        --  trailing slash leaves an empty last component and is
                        --  invalid -- version's normalize used to silently drop
                        --  it and accept the ref.
                        Trailing_Slash : constant Boolean :=
                          Raw'Length > 0 and then Raw (Raw'Last) = '/';
                     begin
                        if not Trailing_Slash
                          and then Version.Ref_Names.Is_Valid_Check_Ref_Format
                                     (Name, Allow_Onelevel, Refspec_Pattern)
                        then
                           if Normalize then
                              Success_Line (Name);
                           end if;
                        else
                           Set_Command_Failure;
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "mktree" then
            declare
               Usage : constant String :=
                 "version mktree [--missing]  (reads tree entries on stdin)";
               Allow_Missing : Boolean := False;
               Bad : Boolean := False;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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
               for I in 2 .. Count loop
                  if Arg (I) = "--missing" then
                     Allow_Missing := True;
                  else
                     Usage_Error ("unknown mktree option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Input    : constant String := Read_Stdin;
                     Entries  : Version.Objects.Tree_Entry_Vectors.Vector;
                     Pos      : Positive := Input'First;
                     Failed   : Boolean := False;
                     Fail_Msg : Unbounded_String;

                     function Type_Name
                       (K : Version.Objects.Object_Kind) return String
                     is
                       (case K is
                          when Version.Objects.Blob_Object   => "blob",
                          when Version.Objects.Tree_Object   => "tree",
                          when Version.Objects.Commit_Object => "commit",
                          when Version.Objects.Tag_Object    => "tag",
                          when Version.Objects.Unknown_Object => "unknown");
                  begin
                     --  Parse "<mode> SP <type> SP <sha> TAB <path>" per line.
                     while Pos <= Input'Last and then not Failed loop
                        declare
                           Line_End : Natural := Pos;
                        begin
                           while Line_End <= Input'Last
                             and then Input (Line_End) /= Character'Val (10)
                           loop
                              Line_End := Line_End + 1;
                           end loop;

                           declare
                              Line : constant String :=
                                Input (Pos .. Line_End - 1);
                              S1, S2, Tab : Natural := 0;
                           begin
                              for K in Line'Range loop
                                 if Line (K) = ' ' and then S1 = 0 then
                                    S1 := K;
                                 elsif Line (K) = ' ' and then S2 = 0
                                   and then S1 /= 0
                                 then
                                    S2 := K;
                                 elsif Line (K) = Character'Val (9) then
                                    Tab := K;
                                    exit;
                                 end if;
                              end loop;

                              if Line'Length > 0
                                and then S1 /= 0 and then S2 /= 0
                                and then Tab /= 0
                              then
                                 declare
                                    Mode : constant String :=
                                      Line (Line'First .. S1 - 1);
                                    Decl : constant String :=
                                      Line (S1 + 1 .. S2 - 1);
                                    Sha  : constant String :=
                                      Line (S2 + 1 .. Tab - 1);
                                    Path : constant String :=
                                      Line (Tab + 1 .. Line'Last);
                                    --  The object type git infers from the
                                    --  mode; the declared type must match it.
                                    Mode_Type : constant String :=
                                      (if Mode = "40000" or else Mode = "040000"
                                       then "tree"
                                       elsif Mode = "160000" then "commit"
                                       else "blob");
                                    Id : constant Version.Objects.Hex_Object_Id
                                      := Version.Objects.To_Object_Id (Sha);
                                    Kind : constant Version.Objects
                                             .Tree_Entry_Kind :=
                                      (if Mode = "40000" or else Mode = "040000"
                                       then Version.Objects.Tree_Directory
                                       elsif Mode = "160000"
                                       then Version.Objects.Tree_Gitlink
                                       else Version.Objects.Tree_Blob);
                                 begin
                                    if Decl /= Mode_Type then
                                       Failed := True;
                                       Fail_Msg := To_Unbounded_String
                                         ("entry '" & Path & "' object type ("
                                          & Decl & ") doesn't match mode type ("
                                          & Mode_Type & ")");
                                    elsif not Allow_Missing then
                                       --  Confirm the object exists and its
                                       --  actual type matches the declaration,
                                       --  as git does without --missing.
                                       declare
                                          Obj : constant Version.Objects
                                                  .Git_Object :=
                                            Version.Objects.Read_Object
                                              (Repo, Id);
                                          Actual : constant String :=
                                            Type_Name
                                              (Version.Objects.Kind (Obj));
                                       begin
                                          if Actual /= Decl then
                                             Failed := True;
                                             Fail_Msg := To_Unbounded_String
                                               ("entry '" & Path & "' object "
                                                & Version.Objects.To_String (Id)
                                                & " is a " & Actual
                                                & " but specified type was ("
                                                & Decl & ")");
                                          end if;
                                       end;
                                    end if;

                                    if not Failed then
                                       Entries.Append
                                         (Version.Objects.Tree_Entry'
                                            (Path =>
                                               To_Unbounded_String (Path),
                                             Id   => Id,
                                             Kind => Kind,
                                             Mode =>
                                               To_Unbounded_String (Mode)));
                                    end if;
                                 end;
                              elsif Line'Length > 0 then
                                 --  A non-empty line git cannot parse aborts the
                                 --  whole command (no tree written), rather than
                                 --  being silently dropped.
                                 Failed   := True;
                                 Fail_Msg := To_Unbounded_String
                                   ("input format error: " & Line);
                              end if;
                           end;

                           Pos := Line_End + 1;
                        end;
                     end loop;

                     if Failed then
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "fatal: " & To_String (Fail_Msg));
                        Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                     else
                        Success_Line
                          (To_String
                             (Version.Write.Write_Tree (Repo, Entries)));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "mktag" then
            declare
               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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

               Content : constant String := Read_Stdin;

               --  Return the header line starting at Pos and advance Pos past
               --  its newline; empty when the header block has ended.
               function Next_Line (Pos : in out Natural) return String is
                  Start : constant Natural := Pos;
                  Stop  : Natural := Pos;
               begin
                  while Stop <= Content'Last
                    and then Content (Stop) /= Character'Val (10)
                  loop
                     Stop := Stop + 1;
                  end loop;
                  Pos := Stop + 1;
                  return Content (Start .. Stop - 1);
               end Next_Line;

               function Starts (S, P : String) return Boolean is
                 (S'Length >= P'Length
                  and then S (S'First .. S'First + P'Length - 1) = P);

               --  git's check_refname_component rules for a one-level tag
               --  name: no space/control/~^:?*[\, no ".."/"@{", no leading or
               --  trailing dot or slash, no ".lock" suffix, not empty.
               function Valid_Tag_Name (S : String) return Boolean is
               begin
                  if S'Length = 0
                    or else S (S'First) = '.' or else S (S'Last) = '.'
                    or else S (S'First) = '/' or else S (S'Last) = '/'
                    or else (S'Length >= 5
                             and then S (S'Last - 4 .. S'Last) = ".lock")
                  then
                     return False;
                  end if;
                  for I in S'Range loop
                     if S (I) <= ' ' or else S (I) = Character'Val (127)
                       or else S (I) in '~' | '^' | ':' | '?' | '*' | '['
                                      | '\'
                       or else (I < S'Last and then S (I) = '.'
                                and then S (I + 1) = '.')
                       or else (I < S'Last and then S (I) = '@'
                                and then S (I + 1) = '{')
                     then
                        return False;
                     end if;
                  end loop;
                  return True;
               end Valid_Tag_Name;

               --  git's fsck_ident detail for a bad "tagger" identity line, or
               --  "" when it is well-formed: "<name> <<email>> <time> <tz>".
               function Ident_Fsck (Line : String) return String is
                  Lt : constant Natural :=
                    Ada.Strings.Fixed.Index (Line, "<");
                  Gt : constant Natural :=
                    Ada.Strings.Fixed.Index (Line, ">");
               begin
                  if Lt = 0 or else Gt = 0 or else Gt < Lt then
                     return "missingEmail: invalid author/committer line"
                       & " - missing email";
                  end if;

                  declare
                     Rest : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Line (Gt + 1 .. Line'Last), Ada.Strings.Both);
                     Sp   : constant Natural :=
                       Ada.Strings.Fixed.Index (Rest, " ");
                  begin
                     --  Need "<unixtime> <tz>": a space separating the two.
                     if Sp = 0 then
                        return "badDate: invalid author/committer line"
                          & " - bad date";
                     end if;

                     declare
                        Time_S : constant String := Rest (Rest'First .. Sp - 1);
                        Tz_S   : constant String := Rest (Sp + 1 .. Rest'Last);
                        Digits_Only : Boolean := Time_S'Length > 0;
                     begin
                        for C of Time_S loop
                           if C not in '0' .. '9' then
                              Digits_Only := False;
                           end if;
                        end loop;
                        if not Digits_Only then
                           return "badDate: invalid author/committer line"
                             & " - bad date";
                        end if;

                        --  Timezone must be [+-]HHMM (sign then four digits).
                        if Tz_S'Length /= 5
                          or else (Tz_S (Tz_S'First) /= '+'
                                   and then Tz_S (Tz_S'First) /= '-')
                          or else (for some K in Tz_S'First + 1 .. Tz_S'Last =>
                                     Tz_S (K) not in '0' .. '9')
                        then
                           return "badTimezone: invalid author/committer line"
                             & " - bad time zone";
                        end if;
                     end;
                  end;

                  return "";
               end Ident_Fsck;
            begin
               declare
                  Pos  : Natural := Content'First;
                  L1   : constant String := Next_Line (Pos);
                  L2   : constant String := Next_Line (Pos);
                  L3   : constant String := Next_Line (Pos);
                  L4   : constant String := Next_Line (Pos);
                  L5   : constant String := Next_Line (Pos);

                  --  git runs its strict fsck before writing: tag name, then
                  --  the tagger identity, then a ban on any header after
                  --  tagger. The first failure is reported.
                  Fsck : constant String :=
                    (if Starts (L3, "tag ")
                       and then not Valid_Tag_Name (L3 (L3'First + 4 .. L3'Last))
                     then "badTagName: invalid 'tag' name: "
                          & L3 (L3'First + 4 .. L3'Last)
                     elsif Starts (L4, "tagger ")
                       and then Ident_Fsck (L4 (L4'First + 7 .. L4'Last)) /= ""
                     then Ident_Fsck (L4 (L4'First + 7 .. L4'Last))
                     elsif L5'Length > 0
                     then "extraHeaderEntry: invalid format"
                          & " - extra header(s) after 'tagger'"
                     else "");
               begin
                  if not Starts (L1, "object ")
                    or else not Starts (L2, "type ")
                    or else not Starts (L3, "tag ")
                    or else not Starts (L4, "tagger ")
                  then
                     Error_Line
                       ("invalid tag object: expected object/type/tag/tagger"
                        & " header lines");
                     Set_Command_Failure;
                  elsif Fsck /= "" then
                     Error_Line ("tag input does not pass fsck: " & Fsck);
                     Stderr_Line
                       ("fatal: tag on stdin did not pass our strict"
                        & " fsck check");
                     Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Sha  : constant String := L1 (L1'First + 7 .. L1'Last);
                        Declared : constant String :=
                          L2 (L2'First + 5 .. L2'Last);
                        Id  : constant Version.Objects.Hex_Object_Id :=
                          Version.Objects.To_Object_Id (Sha);
                        Obj : constant Version.Objects.Git_Object :=
                          Version.Objects.Read_Object (Repo, Id);
                        Actual : constant String :=
                          (case Version.Objects.Kind (Obj) is
                             when Blob_Object   => "blob",
                             when Tree_Object   => "tree",
                             when Commit_Object => "commit",
                             when Tag_Object    => "tag",
                             when others        => "unknown");
                     begin
                        if Actual /= Declared then
                           Error_Line
                             ("object " & Sha & " tagged as '" & Declared
                              & "' but is a '" & Actual & "'");
                           Set_Command_Failure;
                        else
                           Success_Line
                             (To_String
                                (Version.Write.Write_Object
                                   (Repo, "tag", Content)));
                        end if;
                     end;
                  end if;
               end;
            end;

         elsif Command = "fmt-merge-msg" then
            declare
               Usage : constant String :=
                 "version fmt-merge-msg [-F <file>]"
                 & "  (reads FETCH_HEAD on stdin by default)";
               File_Idx : Natural := 0;
               Bad      : Boolean := False;

               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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

               function Read_File (Path : String) return String is
                  use Ada.Streams.Stream_IO;
                  F   : File_Type;
                  Acc : Unbounded_String;
                  Buf : Ada.Streams.Stream_Element_Array (1 .. 65536);
                  Lst : Ada.Streams.Stream_Element_Offset;
                  use type Ada.Streams.Stream_Element_Offset;
               begin
                  Open (F, In_File, Path);
                  while not End_Of_File (F) loop
                     Ada.Streams.Stream_IO.Read (F, Buf, Lst);
                     declare
                        S : String (1 .. Natural (Lst));
                     begin
                        for K in 1 .. Lst loop
                           S (Natural (K)) := Character'Val (Buf (K));
                        end loop;
                        Append (Acc, S);
                     end;
                  end loop;
                  Close (F);
                  return To_String (Acc);
               end Read_File;
            begin
               for I in 2 .. Count loop
                  if (Arg (I) = "-F" or else Arg (I) = "--file")
                    and then I < Count
                  then
                     File_Idx := I + 1;
                  elsif Arg (I) = "-F" or else Arg (I) = "--file" then
                     Usage_Error ("-F requires a file", Usage);
                     Bad := True;
                  elsif I = File_Idx then
                     null;  --  consumed as the -F argument
                  else
                     Usage_Error
                       ("unknown fmt-merge-msg option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                     Input : constant String :=
                       (if File_Idx /= 0 then Read_File (Arg (File_Idx))
                        else Read_Stdin);
                  begin
                     Version.Console.Put
                       (Version.Fmt_Merge_Msg.Format
                          (Repo, Input, Version.Branch.Current_Branch_Name));
                  end;
               end if;
            end;

         elsif Command = "get-tar-commit-id" then
            declare
               function Read_Stdin return String is
                  Buffer : aliased String (1 .. 65536);
                  Acc    : Unbounded_String;
               begin
                  loop
                     declare
                        N : constant Interfaces.C.long :=
                          Read
                            (0, Buffer (Buffer'First)'Address,
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

               Tar : constant String := Read_Stdin;
               Found : Boolean := False;
            begin
               --  The commit id lives in the "comment=" record of a leading
               --  pax global header (tar block: name "pax_global_header",
               --  typeflag 'g' at offset 156, octal size at offset 124).
               if Tar'Length >= 512
                 and then Tar (Tar'First + 156) = 'g'
                 and then Tar (Tar'First .. Tar'First + 16) = "pax_global_header"
               then
                  declare
                     Size : Natural := 0;
                  begin
                     for K in Tar'First + 124 .. Tar'First + 135 loop
                        exit when Tar (K) < '0' or else Tar (K) > '7';
                        Size := Size * 8 + (Character'Pos (Tar (K)) - Character'Pos ('0'));
                     end loop;

                     if Tar'Length >= 512 + Size then
                        declare
                           Content : constant String :=
                             Tar (Tar'First + 512 .. Tar'First + 512 + Size - 1);
                           Key : constant String := "comment=";
                        begin
                           for P in Content'First ..
                                      Content'Last - Key'Length + 1
                           loop
                              if Content (P .. P + Key'Length - 1) = Key then
                                 declare
                                    V : Natural := P + Key'Length;
                                 begin
                                    while V <= Content'Last
                                      and then Content (V) /= Character'Val (10)
                                    loop
                                       V := V + 1;
                                    end loop;
                                    Success_Line
                                      (Content (P + Key'Length .. V - 1));
                                    Found := True;
                                 end;
                                 exit;
                              end if;
                           end loop;
                        end;
                     end if;
                  end;
               end if;

               if not Found then
                  --  git dies (exit 128) on input that is not a well-formed
                  --  archive carrying a commit id.
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "fatal: git get-tar-commit-id: EOF before reading tar"
                     & " header: No such file or directory");
                  Ada.Command_Line.Set_Exit_Status (Fatal_Exit);
               end if;
            end;

         elsif Command = "diff-tree" then
            declare
               Usage : constant String :=
                 "version diff-tree [-r] [--root] (<tree> <tree> | <commit>)";
               Recursive : Boolean := False;
               Root_Diff : Boolean := False;
               A1, A2 : Natural := 0;
               Bad : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "-r" then
                     Recursive := True;
                  elsif Arg (I) = "--root" then
                     Root_Diff := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown diff-tree option: " & Arg (I),
                                  Usage);
                     Bad := True;
                     exit;
                  elsif A1 = 0 then
                     A1 := I;
                  elsif A2 = 0 then
                     A2 := I;
                  else
                     Usage_Error ("too many diff-tree arguments", Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  if A1 = 0 then
                     Usage_Error ("diff-tree requires a tree or commit", Usage);
                  elsif A2 /= 0 then
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        T1 : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Tree (Repo, Arg (A1));
                        T2 : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Tree (Repo, Arg (A2));
                     begin
                        Version.Console.Put
                          (Version.Diff.Raw_Diff_Trees
                             (Repo, T1, True, T2, Recursive));
                     end;
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        C : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Commit (Repo, Arg (A1));
                        Obj : constant Version.Objects.Git_Object :=
                          Version.Objects.Read_Object (Repo, C);
                        Tree : constant Version.Objects.Hex_Object_Id :=
                          Version.Objects.Commit_Tree_Id (Obj);
                        Parents : constant Version.Objects.Object_Id_Vectors
                                    .Vector :=
                          Version.Objects.Commit_Parent_Ids (Obj);
                     begin
                        --  git prints the commit line only when it emits a
                        --  diff: for a root commit without --root, nothing, and
                        --  for a merge commit nothing by default (it needs
                        --  -m/-c/--cc, which version does not implement).
                        if Natural (Parents.Length) = 1 then
                           declare
                              P_Obj : constant Version.Objects.Git_Object :=
                                Version.Objects.Read_Object
                                  (Repo, Parents.First_Element);
                              P_Tree : constant Version.Objects.Hex_Object_Id :=
                                Version.Objects.Commit_Tree_Id (P_Obj);
                           begin
                              Success_Line (To_String (C));
                              Version.Console.Put
                                (Version.Diff.Raw_Diff_Trees
                                   (Repo, P_Tree, True, Tree, Recursive));
                           end;
                        elsif Root_Diff then
                           Success_Line (To_String (C));
                           Version.Console.Put
                             (Version.Diff.Raw_Diff_Trees
                                (Repo, Tree, False, Tree, Recursive));
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "diff-index" then
            declare
               Usage : constant String :=
                 "version diff-index [--cached] [-p] <tree-ish>";
               Cached : Boolean := False;
               Patch  : Boolean := False;
               Tree_Idx : Natural := 0;
               Bad : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--cached" then
                     Cached := True;
                  elsif Arg (I) = "-p" or else Arg (I) = "--patch"
                    or else Arg (I) = "-u"
                  then
                     Patch := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown diff-index option: " & Arg (I),
                                  Usage);
                     Bad := True;
                     exit;
                  elsif Tree_Idx = 0 then
                     Tree_Idx := I;
                  else
                     Usage_Error ("too many diff-index arguments", Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  if Tree_Idx = 0 then
                     Usage_Error ("diff-index requires a tree-ish", Usage);
                  else
                     declare
                        Repo : constant Version.Repository.Repository_Handle :=
                          Version.Repository.Open;
                        Tree : constant Version.Objects.Hex_Object_Id :=
                          Version.Revisions.Resolve_Tree (Repo, Arg (Tree_Idx));
                     begin
                        if Patch then
                           --  -p prints the unified diff of the tree against
                           --  the index (--cached) or the working tree, like
                           --  git; without it the raw record is shown.
                           if Cached then
                              Version.Console.Put
                                (Version.Diff.Diff_Tree_Vs_Index (Repo, Tree));
                           else
                              Version.Console.Put
                                (Version.Diff.Diff_Tree_Vs_Working
                                   (Repo, Tree));
                           end if;
                        else
                           Version.Console.Put
                             (Version.Diff.Raw_Diff_Index (Repo, Tree, Cached));
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "diff-files" then
            declare
               Usage : constant String :=
                 "version diff-files [-p] [--] [PATHSPEC...]";
               Bad   : Boolean := False;
               Patch : Boolean := False;
               Specs : Version.Pathspec.Pathspec_Vectors.Vector;
               Seen_Separator : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--" then
                     Seen_Separator := True;
                  elsif not Seen_Separator
                    and then (Arg (I) = "-p" or else Arg (I) = "--patch"
                              or else Arg (I) = "-u")
                  then
                     Patch := True;
                  elsif not Seen_Separator
                    and then Arg (I)'Length > 0
                    and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown diff-files option: " & Arg (I),
                                  Usage);
                     Bad := True;
                     exit;
                  else
                     --  git filters the report by the pathspec operands.
                     Version.Pathspec.Append_Parse (Specs, Arg (I));
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     if Patch then
                        --  -p prints the unified diff between the index and the
                        --  working tree (git's `diff-files -p`), same content as
                        --  a plain `diff`; without it the raw record is shown.
                        if Specs.Is_Empty then
                           Version.Console.Put
                             (Version.Diff.Diff_Working_Tree (Repo));
                        else
                           Version.Console.Put
                             (Version.Diff.Diff_Working_Tree (Repo, Specs));
                        end if;
                     else
                        Version.Console.Put
                          (Version.Diff.Raw_Diff_Files (Repo, Specs));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "replace" then
            declare
               Usage : constant String :=
                 "version replace [-f] <object> <replacement>"
                 & " | version replace -d <object>..."
                 & " | version replace [-l] [--format=short|medium|long]"
                 & " [<pattern>]";
               Force   : Boolean := False;
               Delete  : Boolean := False;
               List    : Boolean := False;
               Format  : Unbounded_String := To_Unbounded_String ("short");
               Fmt_Pre : constant String := "--format=";
               Ops     : Version.Trailers.String_Vectors.Vector;
               Bad     : Boolean := False;

               function Type_Name (Id : Version.Objects.Hex_Object_Id)
                 return String
               is
                  Obj : constant Version.Objects.Git_Object :=
                    Version.Objects.Read_Object (Repo => Version.Repository.Open,
                                                 Id => Id);
               begin
                  return (case Version.Objects.Kind (Obj) is
                            when Blob_Object => "blob",
                            when Tree_Object => "tree",
                            when Commit_Object => "commit",
                            when Tag_Object => "tag",
                            when others => "unknown");
               end Type_Name;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "-f" or else Arg (I) = "--force" then
                     Force := True;
                  elsif Arg (I) = "-d" or else Arg (I) = "--delete" then
                     Delete := True;
                  elsif Arg (I) = "-l" or else Arg (I) = "--list" then
                     List := True;
                  elsif Arg (I)'Length > Fmt_Pre'Length
                    and then Arg (I) (Arg (I)'First ..
                                        Arg (I)'First + Fmt_Pre'Length - 1)
                             = Fmt_Pre
                  then
                     Format :=
                       To_Unbounded_String
                         (Arg (I) (Arg (I)'First + Fmt_Pre'Length ..
                                     Arg (I)'Last));
                     List := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error ("unknown replace option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  else
                     Ops.Append (Arg (I));
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;

                     function Full (Rev : String)
                       return Version.Objects.Hex_Object_Id
                     is (Version.Revisions.Resolve (Repo, Rev));
                  begin
                     if Delete then
                        for Op of Ops loop
                           declare
                              Oid : constant String := To_String (Full (Op));
                              Ref : constant String := "refs/replace/" & Oid;
                           begin
                              if Version.Refs.Ref_Exists (Repo, Ref) then
                                 declare
                                    Tx : Version.Ref_Transaction.Transaction;
                                 begin
                                    Version.Ref_Transaction.Start (Tx, Repo);
                                    Version.Ref_Transaction.Add_Delete
                                      (Tx, Ref, "");
                                    Version.Ref_Transaction.Commit (Tx);
                                 end;
                                 Success_Line
                                   ("Deleted replace ref '" & Oid & "'");
                              else
                                 Error_Line
                                   ("replace ref '" & Oid & "' not found");
                                 Set_Command_Failure;
                              end if;
                           end;
                        end loop;
                     elsif not List and then Natural (Ops.Length) = 2 then
                        declare
                           Obj : constant String := To_String (Full (Ops (1)));
                           Rep : constant Version.Objects.Hex_Object_Id :=
                             Full (Ops (2));
                           Ref : constant String := "refs/replace/" & Obj;
                        begin
                           if Version.Refs.Ref_Exists (Repo, Ref)
                             and then not Force
                           then
                              Error_Line
                                ("replace ref '" & Obj & "' already exists");
                              Set_Command_Failure;
                           else
                              declare
                                 Tx : Version.Ref_Transaction.Transaction;
                              begin
                                 Version.Ref_Transaction.Start (Tx, Repo);
                                 Version.Ref_Transaction.Add_Update
                                   (Tx, Ref, Rep, "");
                                 Version.Ref_Transaction.Commit (Tx);
                              end;
                           end if;
                        end;
                     elsif not List and then not Ops.Is_Empty then
                        Usage_Error
                          ("replace requires <object> <replacement>", Usage);
                     else
                        --  List replace refs (optionally filtered), formatted.
                        declare
                           Patterns : Version.Ref_Format.String_Vectors.Vector;
                           F : constant String := To_String (Format);
                        begin
                           Patterns.Append
                             ("refs/replace/"
                              & (if Ops.Is_Empty then "" else Ops (1)));
                           for Line of Version.Ref_Format.For_Each_Ref
                             (Repo, Patterns, Format => "%(refname)")
                           loop
                              declare
                                 Ref : constant String := Line;
                                 Oid : constant String :=
                                   Ref (Ref'First + 13 .. Ref'Last);
                              begin
                                 if F = "short" then
                                    Success_Line (Oid);
                                 else
                                    declare
                                       Rep : constant String :=
                                         To_String
                                           (Version.Refs.Resolve_Ref
                                              (Repo, Ref));
                                    begin
                                       if F = "long" then
                                          Success_Line
                                            (Oid & " ("
                                             & Type_Name
                                                 (Version.Objects.To_Object_Id
                                                    (Oid))
                                             & ") -> " & Rep & " ("
                                             & Type_Name
                                                 (Version.Objects.To_Object_Id
                                                    (Rep))
                                             & ")");
                                       else
                                          Success_Line (Oid & " -> " & Rep);
                                       end if;
                                    end;
                                 end if;
                              end;
                           end loop;
                        end;
                     end if;
                  end;
               end if;
            end;

         elsif Command = "bisect" then
            Run_Bisect_Command;

         elsif Command = "subtree" then
            Run_Subtree_Command;

         elsif Command = "commit-graph" then
            Run_Commit_Graph_Command;

         elsif Command = "http-fetch" then
            Run_Http_Fetch_Command;

         elsif Command = "multi-pack-index" then
            Run_Multi_Pack_Index_Command;

         elsif Command = "repo" then
            Run_Repo_Command;

         elsif Command = "backfill" then
            Run_Backfill_Command;

         elsif Command = "filter-branch" then
            Run_Filter_Branch_Command;

         elsif Command = "last-modified" then
            Run_Last_Modified_Command;

         elsif Command = "refs" then
            Run_Refs_Command;

         elsif Command = "diff-pairs" then
            Run_Diff_Pairs_Command;

         elsif Command = "fetch-pack" then
            Run_Fetch_Pack_Command;

         elsif Command = "send-pack" then
            Run_Send_Pack_Command;

         elsif Command = "fast-export" then
            Run_Fast_Export_Command;

         elsif Command = "fast-import" then
            Run_Fast_Import_Command;

         elsif Command = "mailsplit" then
            Run_Mailsplit_Command;

         elsif Command = "mailinfo" then
            Run_Mailinfo_Command;

         elsif Command = "index-pack" then
            Run_Index_Pack_Command;

         elsif Command = "unpack-objects" then
            Run_Unpack_Objects_Command;

         elsif Command = "pack-objects" then
            Run_Pack_Objects_Command;

         elsif Command = "merge-tree" then
            Run_Merge_Tree_Command;

         elsif Command = "merge-ours" then
            Run_Merge_Backend (Backend_Ours);

         elsif Command = "merge-recursive" then
            Run_Merge_Backend (Backend_Recursive);

         elsif Command = "merge-recursive-ours" then
            Run_Merge_Backend (Backend_Recursive_Ours);

         elsif Command = "merge-recursive-theirs" then
            Run_Merge_Backend (Backend_Recursive_Theirs);

         elsif Command = "merge-subtree" then
            Run_Merge_Backend (Backend_Subtree);

         elsif Command = "merge-resolve" then
            Run_Merge_Backend (Backend_Resolve);

         elsif Command = "merge-octopus" then
            Run_Merge_Backend (Backend_Octopus);

         elsif Command = "merge-one-file" then
            Run_Merge_One_File_Command;

         elsif Command = "merge-index" then
            Run_Merge_Index_Command;

         elsif Command = "show-index" then
            Run_Show_Index_Command;

         elsif Command = "unpack-file" then
            Run_Unpack_File_Command;

         elsif Command = "prune-packed" then
            Run_Prune_Packed_Command;

         elsif Command = "ls-remote" then
            Run_Ls_Remote_Command;

         elsif Command = "check-attr" then
            Run_Check_Attr_Command;

         elsif Command = "check-mailmap" then
            Run_Check_Mailmap_Command;

         elsif Command = "for-each-repo" then
            Run_For_Each_Repo_Command;

         elsif Command = "show-branch" then
            declare
               List_Only : Boolean := False;
               Branches  : Version.Show_Branch.Name_Vectors.Vector;
               Bad       : Boolean := False;
            begin
               for I in 2 .. Count loop
                  if Arg (I) = "--list" or else Arg (I) = "-l" then
                     List_Only := True;
                  elsif Arg (I)'Length > 0 and then Arg (I) (Arg (I)'First) = '-'
                  then
                     Usage_Error
                       ("unknown show-branch option: " & Arg (I),
                        "version show-branch [--list] [<branch>...]");
                     Bad := True;
                     exit;
                  else
                     Branches.Append (Arg (I));
                  end if;
               end loop;

               if not Bad then
                  declare
                     Repo : constant Version.Repository.Repository_Handle :=
                       Version.Repository.Open;
                  begin
                     --  No branch operands: every local branch, alphabetically.
                     if Branches.Is_Empty then
                        declare
                           All_Branches :
                             Version.Refs.Branch_Name_Vectors.Vector :=
                               Version.Refs.List_Branches (Repo);
                        begin
                           Sort_Branches (All_Branches);
                           for B of All_Branches loop
                              Branches.Append (To_String (B));
                           end loop;
                        end;
                     end if;

                     if Branches.Is_Empty then
                        Error_Line ("no revs to be shown.");
                        Set_Command_Failure;
                     else
                        Version.Console.Put
                          (Version.Show_Branch.Format
                             (Repo, Branches, List_Only));
                     end if;
                  end;
               end if;
            end;

         elsif Command = "merge-file" then
            declare
               Usage : constant String :=
                 "version merge-file [-p] [-q] [--diff3|--zdiff3]"
                 & " [--ours|--theirs|--union] [-L <label>]..."
                 & " [--diff-algorithm=<algo>]"
                 & " [--marker-size=<n>] <current> <base> <other>";
               MS_Pre    : constant String := "--marker-size=";
               DA_Pre    : constant String := "--diff-algorithm=";
               To_Stdout : Boolean := False;
               Opts      : Version.Merge.Merge_File_Options;
               Labels    : Version.Trailers.String_Vectors.Vector;
               Files     : Version.Trailers.String_Vectors.Vector;
               Bad       : Boolean := False;
               I         : Positive := 2;
            begin
               while I <= Count and then not Bad loop
                  declare
                     A : constant String := Arg (I);
                  begin
                     if A = "-p" or else A = "--stdout" then
                        To_Stdout := True;
                     elsif A = "-q" or else A = "--quiet" then
                        null;  --  suppress warnings (version emits none)
                     elsif A = "--diff3" then
                        Opts.Style := Version.Merge.Conflict_Style_Diff3;
                     elsif A = "--zdiff3" then
                        Opts.Style := Version.Merge.Conflict_Style_ZDiff3;
                     elsif A = "--ours" then
                        Opts.Favor := Version.Merge.Favor_File_Ours;
                     elsif A = "--theirs" then
                        Opts.Favor := Version.Merge.Favor_File_Theirs;
                     elsif A = "--union" then
                        Opts.Favor := Version.Merge.Favor_Union;
                     elsif A = "-L" and then I < Count then
                        Labels.Append (Arg (I + 1));
                        I := I + 1;
                     elsif A'Length > MS_Pre'Length
                       and then A (A'First .. A'First + MS_Pre'Length - 1)
                                = MS_Pre
                     then
                        begin
                           Opts.Marker_Size :=
                             Positive'Value
                               (A (A'First + MS_Pre'Length .. A'Last));
                        exception
                           when others =>
                              Usage_Error ("invalid marker size", Usage);
                              Bad := True;
                        end;
                     elsif A'Length > DA_Pre'Length
                       and then A (A'First .. A'First + DA_Pre'Length - 1)
                                = DA_Pre
                     then
                        declare
                           Algo : constant String :=
                             A (A'First + DA_Pre'Length .. A'Last);
                        begin
                           if Algo = "myers" or else Algo = "default" then
                              Opts.Algorithm :=
                                Version.Merge.Diff_Algorithm_Myers;
                           elsif Algo = "minimal" then
                              Opts.Algorithm :=
                                Version.Merge.Diff_Algorithm_Minimal;
                           elsif Algo = "patience" then
                              Opts.Algorithm :=
                                Version.Merge.Diff_Algorithm_Patience;
                           elsif Algo = "histogram" then
                              Opts.Algorithm :=
                                Version.Merge.Diff_Algorithm_Histogram;
                           else
                              Usage_Error
                                ("unknown diff algorithm: " & Algo, Usage);
                              Bad := True;
                           end if;
                        end;
                     elsif A'Length > 1 and then A (A'First) = '-' then
                        Usage_Error ("unknown merge-file option: " & A, Usage);
                        Bad := True;
                     else
                        Files.Append (A);
                     end if;
                     I := I + 1;
                  end;
               end loop;

               if not Bad then
                  if Natural (Files.Length) /= 3 then
                     Usage_Error
                       ("merge-file requires <current> <base> <other>", Usage);
                  else
                     declare
                        Cur_P : constant String := Files (Files.First_Index);
                        Bas_P : constant String := Files (Files.First_Index + 1);
                        Oth_P : constant String := Files (Files.First_Index + 2);
                        function Lbl (N : Natural; Default : String)
                          return Unbounded_String
                        is (if Natural (Labels.Length) >= N
                            then To_Unbounded_String
                                   (Labels (Labels.First_Index + N - 1))
                            else To_Unbounded_String (Default));
                        Merged    : Unbounded_String;
                        Conflicts : Natural;
                        Ours_C    : constant String :=
                          Version.Files.Read_Binary_File (Cur_P);
                        Base_C    : constant String :=
                          Version.Files.Read_Binary_File (Bas_P);
                        Theirs_C  : constant String :=
                          Version.Files.Read_Binary_File (Oth_P);

                        --  git's buffer_is_binary: a NUL byte in the first
                        --  8000 bytes marks the content binary.
                        function Is_Binary (S : String) return Boolean is
                        begin
                           for K in S'First ..
                             Integer'Min (S'Last, S'First + 7999)
                           loop
                              if S (K) = Character'Val (0) then
                                 return True;
                              end if;
                           end loop;
                           return False;
                        end Is_Binary;
                     begin
                        Opts.Ours_Label   := Lbl (1, Cur_P);
                        Opts.Base_Label   := Lbl (2, Bas_P);
                        Opts.Theirs_Label := Lbl (3, Oth_P);

                        --  git refuses to merge binary content, naming the
                        --  first binary file (ours, then base, then theirs)
                        --  by path, and leaves the current file untouched.
                        if Is_Binary (Ours_C) or else Is_Binary (Base_C)
                          or else Is_Binary (Theirs_C)
                        then
                           Error_Line
                             ("Cannot merge binary files: "
                              & (if Is_Binary (Ours_C) then Cur_P
                                 elsif Is_Binary (Base_C) then Bas_P
                                 else Oth_P));
                           Ada.Command_Line.Set_Exit_Status
                             (Ada.Command_Line.Exit_Status (255));
                        else
                           Version.Merge.Merge_File
                             (Ours_Text   => Ours_C,
                              Base_Text   => Base_C,
                              Theirs_Text => Theirs_C,
                              Options     => Opts,
                              Merged      => Merged,
                              Conflicts   => Conflicts);
                           if To_Stdout then
                              Version.Console.Put (To_String (Merged));
                           else
                              Version.Files.Write_Binary_File
                                (Cur_P, To_String (Merged));
                           end if;
                           if Conflicts > 0 then
                              Ada.Command_Line.Set_Exit_Status
                                (Ada.Command_Line.Exit_Status
                                   (Integer'Min (Conflicts, 127)));
                           end if;
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "difftool" or else Command = "mergetool" then
            declare
               Is_Merge : constant Boolean := Command = "mergetool";
               Usage : constant String :=
                 (if Is_Merge
                  then "version mergetool [--tool=<tool>] [-y|--no-prompt]"
                  else "version difftool [--tool=<tool>] [-y|--no-prompt]"
                       & " [--cached|--staged]");
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Tool   : Unbounded_String;
               Cached : Boolean := False;
               Bad    : Boolean := False;

               function Has_Pfx (L, P : String) return Boolean is
                 (L'Length >= P'Length
                  and then L (L'First .. L'First + P'Length - 1) = P);

               function Drop_Pfx (L, P : String) return String is
                 (L (L'First + P'Length .. L'Last));

               --  The blob at Path in HEAD, or "" when absent.
               function Head_Blob (Path : String) return String is
                  Items : constant Version.Objects.Tree_Entry_Vectors.Vector :=
                    Version.Objects.Flatten_Tree
                      (Repo,
                       Version.Revisions.Resolve_Tree (Repo, "HEAD"));
               begin
                  for E of Items loop
                     if To_String (E.Path) = Path then
                        return Version.Objects.Content
                          (Version.Objects.Read_Object (Repo, E.Id));
                     end if;
                  end loop;
                  return "";
               exception
                  when others =>
                     return "";
               end Head_Blob;

               function Cfg (Key : String) return String is
                 (if Version.Config.Has_Key (Repo, Key)
                  then Version.Config.Get_Value (Repo, Key) else "");

               --  Write Content to a scratch file and return its path.
               function Scratch (Name, Content : String) return String is
                  Dir : constant String :=
                    Version.Files.Join
                      (Version.Repository.Git_Dir (Repo), "version-tool");
                  Full : constant String := Version.Files.Join (Dir, Name);
               begin
                  Version.Files.Create_Directory_If_Missing (Dir);
                  Version.Files.Write_Binary_File_Atomic (Full, Content);
                  return Full;
               end Scratch;

               --  Run the configured tool with git's variables in the
               --  environment: $LOCAL / $REMOTE / $BASE / $MERGED.
               function Invoke
                 (Cmd, Local, Remote, Base, Merged : String) return Integer
               is
                  Args   : GNAT.OS_Lib.Argument_List (1 .. 2);
                  Status : Integer;
               begin
                  Ada.Environment_Variables.Set ("LOCAL", Local);
                  Ada.Environment_Variables.Set ("REMOTE", Remote);
                  Ada.Environment_Variables.Set ("BASE", Base);
                  Ada.Environment_Variables.Set ("MERGED", Merged);
                  Args (1) := new String'("-c");
                  Args (2) := new String'(Cmd);
                  Status :=
                    GNAT.OS_Lib.Spawn (Program_Name => "/bin/sh", Args => Args);
                  GNAT.OS_Lib.Free (Args (1));
                  GNAT.OS_Lib.Free (Args (2));
                  return Status;
               end Invoke;
            begin
               for I in 2 .. Count loop
                  if Has_Pfx (Arg (I), "--tool=") then
                     Tool := To_Unbounded_String
                       (Drop_Pfx (Arg (I), "--tool="));
                  elsif Arg (I) = "-y" or else Arg (I) = "--no-prompt"
                    or else Arg (I) = "--prompt"
                  then
                     null;   --  version never prompts
                  elsif not Is_Merge
                    and then (Arg (I) = "--cached" or else Arg (I) = "--staged")
                  then
                     Cached := True;
                  else
                     Usage_Error
                       ("unknown " & Command & " option: " & Arg (I), Usage);
                     Bad := True;
                     exit;
                  end if;
               end loop;

               if not Bad then
                  if Length (Tool) = 0 then
                     Tool := To_Unbounded_String
                       (Cfg (if Is_Merge then "merge.tool" else "diff.tool"));
                  end if;

                  if Length (Tool) = 0 then
                     Error_Line
                       ("no tool configured: set "
                        & (if Is_Merge then "merge.tool" else "diff.tool")
                        & " or pass --tool=<tool>");
                     Set_Command_Failure;
                  else
                     declare
                        T   : constant String := To_String (Tool);
                        Cmd : constant String :=
                          Cfg ((if Is_Merge then "mergetool." else "difftool.")
                               & T & ".cmd");
                     begin
                        if Cmd'Length = 0 then
                           Error_Line
                             ("no command configured for tool: " & T);
                           Set_Command_Failure;
                        elsif Is_Merge then
                           --  One invocation per conflicted path; a tool that
                           --  exits 0 means "resolved", so stage the result.
                           declare
                              St : constant Version.Status.Status_Result :=
                                Version.Status.Current_Status;
                              Root : constant String :=
                                Version.Repository.Root_Path (Repo);
                           begin
                              for C of St.Conflicted loop
                                 declare
                                    Path : constant String :=
                                      To_String (C.Path);
                                    Full : constant String :=
                                      Version.Files.Join (Root, Path);
                                    Entries : constant
                                      Version.Staging.Index_Entry_Vectors.Vector
                                        := Version.Staging.Load (Repo);
                                    function Stage_Blob
                                      (N : Natural) return String is
                                    begin
                                       for E of Entries loop
                                          if To_String (E.Path) = Path
                                            and then E.Stage = N
                                          then
                                             return Version.Objects.Content
                                               (Version.Objects.Read_Object
                                                  (Repo, E.Id));
                                          end if;
                                       end loop;
                                       return "";
                                    end Stage_Blob;

                                    Base_F : constant String :=
                                      Scratch ("BASE", Stage_Blob (1));
                                    Local_F : constant String :=
                                      Scratch ("LOCAL", Stage_Blob (2));
                                    Remote_F : constant String :=
                                      Scratch ("REMOTE", Stage_Blob (3));
                                    Status : Integer;

                                    function Side (N : Natural) return String is
                                    begin
                                       for E of Entries loop
                                          if To_String (E.Path) = Path
                                            and then E.Stage = N
                                          then
                                             return "modified file";
                                          end if;
                                       end loop;
                                       return "deleted file";
                                    end Side;
                                 begin
                                    Success_Line ("Merging:");
                                    Success_Line (Path);
                                    Success_Line ("");
                                    Success_Line
                                      ("Normal merge conflict for '"
                                       & Path & "':");
                                    Success_Line
                                      ("  {local}: " & Side (2));
                                    Success_Line
                                      ("  {remote}: " & Side (3));

                                    --  git keeps the conflicted file as
                                    --  <path>.orig (mergetool.keepBackup).
                                    Version.Files.Write_Binary_File_Atomic
                                      (Path    => Full & ".orig",
                                       Content =>
                                         Version.Files.Read_Binary_File (Full));

                                    Status :=
                                      Invoke (Cmd, Local_F, Remote_F,
                                              Base_F, Full);
                                    if Status = 0 then
                                       Version.Stage.Stage_Path (Path);
                                    else
                                       Error_Line
                                         ("merge of " & Path & " failed");
                                       Set_Command_Failure;
                                    end if;
                                 end;
                              end loop;
                           end;
                        else
                           --  One invocation per changed path.
                           declare
                              St : constant Version.Status.Status_Result :=
                                Version.Status.Current_Status;
                              Root : constant String :=
                                Version.Repository.Root_Path (Repo);
                              List : constant
                                Version.Status.File_Change_Vectors.Vector :=
                                  (if Cached then St.Staged else St.Changes);
                           begin
                              for C of List loop
                                 declare
                                    Path : constant String :=
                                      To_String (C.Path);
                                    Full : constant String :=
                                      Version.Files.Join (Root, Path);
                                    Old  : constant String := Head_Blob (Path);
                                    Local_F : constant String :=
                                      Scratch ("LOCAL", Old);
                                    Status : Integer;
                                    pragma Unreferenced (Status);
                                 begin
                                    Status :=
                                      Invoke (Cmd, Local_F, Full, Local_F,
                                              Full);
                                 end;
                              end loop;
                           end;
                        end if;
                     end;
                  end if;
               end if;
            end;

         elsif Command = "rerere" then
            declare
               Usage : constant String :=
                 "version rerere [clear|forget <pathspec>|diff|remaining"
                 & "|status|gc]";
               Sub : constant String := (if Count >= 2 then Arg (2) else "");
               Repo : constant Version.Repository.Repository_Handle :=
                 Version.Repository.Open;
               Common : constant String :=
                 Version.Repository.Common_Git_Dir (Repo);
               MR_Path : constant String :=
                 Version.Files.Join (Common, "MERGE_RR");
               RR_Dir  : constant String :=
                 Version.Files.Join (Common, "rr-cache");

               --  Parse MERGE_RR ("<key>\t<path>\0" entries) into parallel
               --  key/path lists.
               Keys  : Version.Trailers.String_Vectors.Vector;
               Paths : Version.Trailers.String_Vectors.Vector;

               procedure Load_Merge_RR is
                  Text : constant String :=
                    (if Ada.Directories.Exists (MR_Path)
                     then Version.Files.Read_Binary_File (MR_Path) else "");
                  I : Natural := Text'First;
               begin
                  while I <= Text'Last loop
                     declare
                        E : Natural := I;
                        Tab : Natural := 0;
                     begin
                        while E <= Text'Last
                          and then Text (E) /= Character'Val (0)
                        loop
                           if Text (E) = Character'Val (9) and then Tab = 0 then
                              Tab := E;
                           end if;
                           E := E + 1;
                        end loop;
                        if Tab /= 0 then
                           Keys.Append (Text (I .. Tab - 1));
                           Paths.Append (Text (Tab + 1 .. E - 1));
                        end if;
                        I := E + 1;
                     end;
                  end loop;
               end Load_Merge_RR;

               function Preimage (Key : String) return String is
                 (Version.Files.Join
                    (Version.Files.Join (RR_Dir, Key), "preimage"));
               function Postimage (Key : String) return String is
                 (Version.Files.Join
                    (Version.Files.Join (RR_Dir, Key), "postimage"));
               function Work_Has_Markers (Path : String) return Boolean is
                  Full : constant String :=
                    Version.Files.Join
                      (Version.Repository.Root_Path (Repo), Path);
               begin
                  return Ada.Directories.Exists (Full)
                    and then Ada.Strings.Fixed.Index
                               (Version.Files.Read_Binary_File (Full),
                                "<<<<<<<") /= 0;
               end Work_Has_Markers;
            begin
               Load_Merge_RR;
               if Sub = "" or else Sub = "status" then
                  for I in Keys.First_Index .. Keys.Last_Index loop
                     if Ada.Directories.Exists (Preimage (Keys (I))) then
                        Success_Line (Paths (I));
                     end if;
                  end loop;
               elsif Sub = "remaining" then
                  for I in Keys.First_Index .. Keys.Last_Index loop
                     if not Ada.Directories.Exists (Postimage (Keys (I)))
                       and then Work_Has_Markers (Paths (I))
                     then
                        Success_Line (Paths (I));
                     end if;
                  end loop;
               elsif Sub = "clear" then
                  --  Drop the preimages of still-unresolved entries and the map.
                  for I in Keys.First_Index .. Keys.Last_Index loop
                     if not Ada.Directories.Exists (Postimage (Keys (I))) then
                        Version.Files.Delete_File_If_Exists (Preimage (Keys (I)));
                     end if;
                  end loop;
                  Version.Files.Delete_File_If_Exists (MR_Path);
               elsif Sub = "forget" then
                  if Count < 3 then
                     Usage_Error ("rerere forget requires a pathspec", Usage);
                  else
                     for J in 3 .. Count loop
                        for I in Keys.First_Index .. Keys.Last_Index loop
                           if Paths (I) = Arg (J) then
                              Version.Files.Delete_File_If_Exists
                                (Postimage (Keys (I)));
                           end if;
                        end loop;
                     end loop;
                  end if;
               elsif Sub = "diff" then
                  --  git diffs the recorded (normalized) preimage against the
                  --  file as it stands now, so you can see how far the
                  --  resolution has got.
                  for I in Keys.First_Index .. Keys.Last_Index loop
                     declare
                        Pre  : constant String := Preimage (Keys (I));
                        Work : constant String :=
                          Version.Files.Join
                            (Version.Repository.Root_Path (Repo), Paths (I));
                     begin
                        if Ada.Directories.Exists (Pre)
                          and then Ada.Directories.Exists (Work)
                        then
                           Version.Console.Put
                             (Version.Diff.Unified_Text_Diff
                                (Path     => Paths (I),
                                 Old_Text =>
                                   Version.Files.Read_Binary_File (Pre),
                                 New_Text =>
                                   Version.Files.Read_Binary_File (Work)));
                        end if;
                     end;
                  end loop;
               elsif Sub = "gc" then
                  null;  --  pruning is a no-op maintenance step (no output)
               else
                  Usage_Error ("unknown rerere subcommand: " & Sub, Usage);
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
