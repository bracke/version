with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Tool_Support;

with Version.Init;
with Version.Objects;
with Version.Ref_Transaction;
with Version.Repository;

procedure Check_Ref_Transaction_Selftest is
   use Version.Objects;
   use type Ada.Directories.File_Kind;

   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version_ref_transaction_selftest_ada";

   Id_A : constant Version.Objects.Hex_Object_Id :=
     Version.Objects.To_Object_Id ("1111111111111111111111111111111111111111");
   Id_B : constant Version.Objects.Hex_Object_Id :=
     Version.Objects.To_Object_Id ("2222222222222222222222222222222222222222");
   Id_C : constant Version.Objects.Hex_Object_Id :=
     Version.Objects.To_Object_Id ("3333333333333333333333333333333333333333");
   Zero_Id : constant String := "0000000000000000000000000000000000000000";

   function Ref_Path
     (Repo : Version.Repository.Repository_Handle;
      Name : String) return String
   is
   begin
      return Tool_Support.Join (Version.Repository.Common_Git_Dir (Repo), Name);
   end Ref_Path;

   procedure Write_Ref
     (Repo : Version.Repository.Repository_Handle;
      Name : String;
      Id   : Version.Objects.Hex_Object_Id)
   is
   begin
      Tool_Support.Write_File (Ref_Path (Repo, Name), To_String (Id) & ASCII.LF);
   end Write_Ref;

   function Read_Ref
     (Repo : Version.Repository.Repository_Handle;
      Name : String) return String
   is
   begin
      return Tool_Support.Read_File (Ref_Path (Repo, Name));
   end Read_Ref;

   function Rollback_Artifact_Exists (Directory : String) return Boolean is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Opened : Boolean := False;
   begin
      if not Ada.Directories.Exists (Directory) then
         return False;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory,
         "*",
         [Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          Ada.Directories.Special_File  => False]);
      Opened := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
            Full : constant String := Ada.Directories.Full_Name (Item);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Strings.Fixed.Index (Name, ".rollback-") /= 0 then
               Ada.Directories.End_Search (Search);
               return True;
            elsif Ada.Directories.Kind (Item) = Ada.Directories.Directory
              and then Rollback_Artifact_Exists (Full)
            then
               Ada.Directories.End_Search (Search);
               return True;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      return False;
   exception
      when others =>
         if Opened then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Rollback_Artifact_Exists;

   procedure Require (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Tool_Support.Fail (Message);
      end if;
   end Require;

   function Make_Repo (Name : String) return String is
      Dir : constant String := Tool_Support.Join (Tmp, Name);
   begin
      Tool_Support.Delete_If_Exists (Dir);
      Ada.Directories.Create_Path (Dir);
      Version.Init.Init (Dir);
      return Dir;
   end Make_Repo;

   procedure Good_Expected_Old_Update is
      Dir     : constant String := Make_Repo ("good-update");
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Ada.Directories.Set_Directory (Dir);
      declare
         Repo : constant Version.Repository.Repository_Handle := Version.Repository.Open;
         Tx   : Version.Ref_Transaction.Transaction;
      begin
         Write_Ref (Repo, "refs/heads/main", Id_A);
         Version.Ref_Transaction.Start (Tx, Repo);
         Version.Ref_Transaction.Add_Update
           (Item         => Tx,
            Ref_Name     => "refs/heads/main",
            New_Id       => Id_B,
            Expected_Old => To_String (Id_A));
         Version.Ref_Transaction.Commit (Tx);
         Require
           (Read_Ref (Repo, "refs/heads/main") = To_String (Id_B) & ASCII.LF,
            "matching expected-old update did not write new ref");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Good_Expected_Old_Update;

   procedure Expected_Old_Mismatch_Fails is
      Dir     : constant String := Make_Repo ("old-mismatch");
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Raised  : Boolean := False;
   begin
      Ada.Directories.Set_Directory (Dir);
      declare
         Repo : constant Version.Repository.Repository_Handle := Version.Repository.Open;
         Tx   : Version.Ref_Transaction.Transaction;
      begin
         Write_Ref (Repo, "refs/heads/main", Id_A);
         begin
            Version.Ref_Transaction.Start (Tx, Repo);
            Version.Ref_Transaction.Add_Update
              (Item         => Tx,
               Ref_Name     => "refs/heads/main",
               New_Id       => Id_C,
               Expected_Old => To_String (Id_B));
            Version.Ref_Transaction.Commit (Tx);
         exception
            when E : Ada.IO_Exceptions.Data_Error =>
               Raised := True;
               Require
                 (Ada.Exceptions.Exception_Message (E)
                  = Version.Ref_Transaction.Expected_Old_Mismatch_Diagnostic
                    ("refs/heads/main"),
                  "expected-old mismatch diagnostic changed: " &
                  Ada.Exceptions.Exception_Message (E));
               Version.Ref_Transaction.Cancel (Tx);
         end;

         Require (Raised, "expected-old mismatch did not fail");
         Require
           (Read_Ref (Repo, "refs/heads/main") = To_String (Id_A) & ASCII.LF,
            "expected-old mismatch mutated existing ref");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Expected_Old_Mismatch_Fails;

   procedure Zero_Expected_Old_Rejects_Existing is
      Dir     : constant String := Make_Repo ("zero-existing");
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Raised  : Boolean := False;
   begin
      Ada.Directories.Set_Directory (Dir);
      declare
         Repo : constant Version.Repository.Repository_Handle := Version.Repository.Open;
         Tx   : Version.Ref_Transaction.Transaction;
      begin
         Write_Ref (Repo, "refs/tags/v1", Id_A);
         begin
            Version.Ref_Transaction.Start (Tx, Repo);
            Version.Ref_Transaction.Add_Update
              (Item         => Tx,
               Ref_Name     => "refs/tags/v1",
               New_Id       => Id_B,
               Expected_Old => Zero_Id);
            Version.Ref_Transaction.Commit (Tx);
         exception
            when E : Ada.IO_Exceptions.Data_Error =>
               Raised := True;
               Require
                 (Ada.Exceptions.Exception_Message (E)
                  = Version.Ref_Transaction.Expected_Missing_Ref_Diagnostic
                    ("refs/tags/v1"),
                  "zero expected-old diagnostic changed: " &
                  Ada.Exceptions.Exception_Message (E));
               Version.Ref_Transaction.Cancel (Tx);
         end;

         Require (Raised, "zero expected-old did not reject existing ref");
         Require
           (Read_Ref (Repo, "refs/tags/v1") = To_String (Id_A) & ASCII.LF,
            "zero expected-old failure mutated existing ref");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Zero_Expected_Old_Rejects_Existing;

   procedure Rename_Style_Delete_Failure_Cleans_Up is
      Dir     : constant String := Make_Repo ("rename-stale-delete");
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Raised  : Boolean := False;
   begin
      Ada.Directories.Set_Directory (Dir);
      declare
         Repo : constant Version.Repository.Repository_Handle := Version.Repository.Open;
         Tx   : Version.Ref_Transaction.Transaction;
      begin
         Write_Ref (Repo, "refs/heads/source", Id_B);
         begin
            Version.Ref_Transaction.Start (Tx, Repo);
            Version.Ref_Transaction.Add_Update
              (Item         => Tx,
               Ref_Name     => "refs/heads/dest",
               New_Id       => Id_A,
               Expected_Old => Zero_Id);
            Version.Ref_Transaction.Add_Delete
              (Item         => Tx,
               Ref_Name     => "refs/heads/source",
               Expected_Old => To_String (Id_A));
            Version.Ref_Transaction.Commit (Tx);
         exception
            when E : Ada.IO_Exceptions.Data_Error =>
               Raised := True;
               Require
                 (Ada.Exceptions.Exception_Message (E)
                  = Version.Ref_Transaction.Expected_Old_Mismatch_Diagnostic
                    ("refs/heads/source"),
                  "rename-style stale delete diagnostic changed: " &
                  Ada.Exceptions.Exception_Message (E));
               Version.Ref_Transaction.Cancel (Tx);
         end;

         Require (Raised, "rename-style stale delete did not fail");
         Require
           (Read_Ref (Repo, "refs/heads/source") = To_String (Id_B) & ASCII.LF,
            "rename-style stale delete did not preserve source ref");
         Require
           (not Ada.Directories.Exists (Ref_Path (Repo, "refs/heads/dest")),
            "rename-style stale delete left destination ref");
         Require
           (not Ada.Directories.Exists (Ref_Path (Repo, "refs/heads/source.lock"))
            and then not Ada.Directories.Exists (Ref_Path (Repo, "refs/heads/dest.lock")),
            "rename-style stale delete left lock files");
         Require
           (not Rollback_Artifact_Exists (Version.Repository.Common_Git_Dir (Repo)),
            "rename-style stale delete left rollback artifacts");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Rename_Style_Delete_Failure_Cleans_Up;

begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_ref_transaction_selftest");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Create_Path (Tmp);

   Good_Expected_Old_Update;
   Expected_Old_Mismatch_Fails;
   Zero_Expected_Old_Rejects_Existing;
   Rename_Style_Delete_Failure_Cleans_Up;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Set_Directory (Root);
   Ada.Text_IO.Put_Line ("ref transaction self-tests passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      Ada.Directories.Set_Directory (Root);
      raise;
end Check_Ref_Transaction_Selftest;
