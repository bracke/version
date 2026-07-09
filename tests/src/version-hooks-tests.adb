with Ada.Calendar;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit.Assertions;
with AUnit.Test_Cases;

with Version.Branch;
with Version.CLI; use Version.CLI;
with Version.Cherry_Pick;
with Version.Clone;
with Version.Git_Fixtures;
with Version.Init;
with Version.Platform; use Version.Platform;
with Version.Push;
with Version.Refs;
with Version.Repository;
with Version.Test_Support;
with Version.Write;
with Version.Worktrees;

package body Version.Hooks.Tests is

   use AUnit.Assertions;
   use AUnit.Test_Cases.Registration;

   function Join (Left, Right : String) return String
   renames Version.Test_Support.Join;

   procedure Skip_Unless_POSIX is
   begin
      if Version.Platform.Current /= Version.Platform.POSIX_Platform then
         raise AUnit.Assertions.Assertion_Error
           with "POSIX hook script test skipped on non-POSIX platform";
      end if;
   end Skip_Unless_POSIX;

   procedure Skip_Unless_Windows is
   begin
      if Version.Platform.Current /= Version.Platform.Windows_Platform then
         raise AUnit.Assertions.Assertion_Error
           with "Windows hook command test skipped on non-Windows platform";
      end if;
   end Skip_Unless_Windows;

   procedure Configure_User (Root : String) is
   begin
      Version.Git_Fixtures.Run
        (Root, "git config user.email test@example.com");
      Version.Git_Fixtures.Run (Root, "git config user.name Test");
      Version.Git_Fixtures.Run (Root, "git config gc.auto 0");
   end Configure_User;

   procedure Write_Hook (Root : String; Name : String; Content : String) is
   begin
      Version.Test_Support.Write_Text_File
        (Join (Join (Join (Root, ".git"), "hooks"), Name),
         "#!/bin/sh" & Character'Val (10) & Content);
      Version.Git_Fixtures.Run (Root, "chmod +x .git/hooks/" & Name);
   end Write_Hook;

   procedure Init_Staged_File (Root : String; Text : String := "content") is
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Version.Test_Support.Write_Text_File
        (Join (Root, "a.txt"), Text & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
   end Init_Staged_File;

   function Wait_For_File
     (Path    : String;
      Timeout : Duration := 3.0)
      return Boolean
   is
      Start : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      loop
         if Ada.Directories.Exists (Path) then
            return True;
         end if;

         exit when Ada.Calendar."-" (Ada.Calendar.Clock, Start) >= Timeout;
         delay 0.05;
      end loop;

      return Ada.Directories.Exists (Path);
   end Wait_For_File;

   procedure Missing_Hook_Is_No_Op
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
      Args : Version.Hooks.Argument_Vectors.Vector;
   begin
      Version.Init.Init (Root);
      Ada.Directories.Set_Directory (Root);
      declare
         Result : constant Version.Hooks.Hook_Result :=
           Version.Hooks.Run_Hook
             (Version.Repository.Open, "pre-commit", Args);
      begin
         Assert (not Result.Ran, "missing hook must not run");
         Assert
           (Result.Exit_Code = 0, "missing hook must be a successful no-op");
      end;
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Missing_Hook_Is_No_Op;

   procedure Pre_Commit_Runs_Before_Save
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "pre-commit",
         "echo ran > hook-ran.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("with hook");
      Assert
        (Ada.Directories.Exists (Join (Root, "hook-ran.txt")),
         "pre-commit marker missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Pre_Commit_Runs_Before_Save;

   procedure Pre_Commit_Blocks_Save
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old     : constant String := Ada.Directories.Current_Directory;
      Blocked : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "pre-commit",
         "echo blocked > hook-blocked.txt"
         & Character'Val (10)
         & "exit 1"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("blocked");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;
      Assert (Blocked, "pre-commit failure must block save");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 0,
         "blocked save must not create commit");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Pre_Commit_Blocks_Save;

   procedure Commit_Msg_Can_Edit_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "commit-msg",
         "echo edited message > ""$1"""
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("original message");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""edited message""");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Commit_Msg_Can_Edit_Message;

   procedure Commit_Msg_Blocks_Save
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old     : constant String := Ada.Directories.Current_Directory;
      Blocked : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "commit-msg",
         "echo rejected > commit-msg-blocked.txt"
         & Character'Val (10)
         & "exit 1"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("blocked by message hook");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;
      Assert (Blocked, "commit-msg failure must block save");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 0,
         "blocked commit-msg must not create commit");
      Assert
        (Ada.Directories.Exists (Join (Root, "commit-msg-blocked.txt")),
         "commit-msg hook marker missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Commit_Msg_Blocks_Save;

   procedure Hook_Failure_Restores_Current_Directory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old     : constant String := Ada.Directories.Current_Directory;
      Blocked : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook (Root, "pre-commit", "exit 1" & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("restore cwd");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;
      Assert (Blocked, "pre-commit failure expected");
      Assert
        (Ada.Directories.Current_Directory = Root,
         "hook failure must restore caller current directory");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Hook_Failure_Restores_Current_Directory;

   procedure No_Verify_Skips_Commit_Hooks
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook (Root, "pre-commit", "exit 1" & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save (Message => "bypass", Run_Hooks => False);
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 40,
         "no-verify save must commit");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end No_Verify_Skips_Commit_Hooks;

   procedure Post_Commit_Failure_Does_Not_Roll_Back
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root     : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old      : constant String := Ada.Directories.Current_Directory;
      Reported : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "post-commit",
         "echo post > post-commit-ran.txt"
         & Character'Val (10)
         & "exit 1"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("post commit failure is reported only");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Reported := True;
      end;
      Assert (Reported, "post-commit failure must be reported to caller");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 40,
         "post-commit failure must not roll back completed commit");
      Assert
        (Ada.Directories.Exists (Join (Root, "post-commit-ran.txt")),
         "post-commit hook marker missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Commit_Failure_Does_Not_Roll_Back;

   procedure Save_Amend_Runs_Post_Commit
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root, "initial");
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("initial commit");

      Write_Hook
        (Root,
         "post-commit",
         "echo amend post > amend-post-commit.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Version.Test_Support.Write_Text_File
        (Join (Root, "a.txt"), "amended" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Version.Write.Save_Amend ("amended commit");

      Assert
        (Ada.Directories.Exists (Join (Root, "amend-post-commit.txt")),
         "amend-created commit must run post-commit hook");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""amended commit""");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Save_Amend_Runs_Post_Commit;

   procedure Post_Commit_Observes_Updated_HEAD
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "post-commit",
         "git rev-parse HEAD > post-commit-head.txt"
         & Character'Val (10)
         & "git log --format=%s -1 > post-commit-subject.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("visible to post commit");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "post-commit-head.txt")),
            Version.Refs.Current_Commit_Id (Version.Repository.Open))
         /= 0,
         "post-commit must observe the updated HEAD commit");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "post-commit-subject.txt")),
            "visible to post commit")
         /= 0,
         "post-commit must observe the committed message");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Commit_Observes_Updated_HEAD;

   procedure Post_Commit_Runs_In_Repository_Root
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "post-commit",
         "pwd > post-commit-pwd.txt"
         & Character'Val (10)
         & "printf '%s\n' ""$GIT_WORK_TREE"" > post-commit-work-tree.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("post commit cwd");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "post-commit-pwd.txt")),
            Root)
         /= 0,
         "post-commit must run with repository root as cwd");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "post-commit-work-tree.txt")),
            Root)
         /= 0,
         "post-commit must receive GIT_WORK_TREE");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Commit_Runs_In_Repository_Root;

   procedure Post_Commit_Not_Run_When_Pre_Commit_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old     : constant String := Ada.Directories.Current_Directory;
      Blocked : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook (Root, "pre-commit", "exit 1" & Character'Val (10));
      Write_Hook
        (Root,
         "post-commit",
         "echo should-not-run > post-commit-should-not-run.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("blocked before commit");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;
      Assert (Blocked, "pre-commit failure must block save");
      Assert
        (not Ada.Directories.Exists
               (Join (Root, "post-commit-should-not-run.txt")),
         "post-commit must not run when commit creation is blocked");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 0,
         "blocked save must not create HEAD");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Commit_Not_Run_When_Pre_Commit_Fails;

   procedure Post_Commit_Not_Run_When_Commit_Msg_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old     : constant String := Ada.Directories.Current_Directory;
      Blocked : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Write_Hook (Root, "commit-msg", "exit 1" & Character'Val (10));
      Write_Hook
        (Root,
         "post-commit",
         "echo should-not-run > post-commit-after-commit-msg.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      begin
         Version.Write.Save ("blocked by commit msg before commit");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;
      Assert (Blocked, "commit-msg failure must block save");
      Assert
        (not Ada.Directories.Exists
               (Join (Root, "post-commit-after-commit-msg.txt")),
         "post-commit must not run when commit-msg blocks commit creation");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 0,
         "commit-msg blocked save must not create HEAD");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Commit_Not_Run_When_Commit_Msg_Fails;

   procedure Disabled_Hooks_Skip_Post_Commit
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root        : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old         : constant String := Ada.Directories.Current_Directory;
      Had_Disable : constant Boolean :=
        Ada.Environment_Variables.Exists ("VERSION_NO_HOOKS");
      Old_Disable : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      Skip_Unless_POSIX;
      if Had_Disable then
         Old_Disable :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (Ada.Environment_Variables.Value ("VERSION_NO_HOOKS"));
      end if;

      Init_Staged_File (Root);
      Write_Hook
        (Root,
         "post-commit",
         "echo should-not-run > disabled-post-commit.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Environment_Variables.Set ("VERSION_NO_HOOKS", "1");
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("hooks disabled");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)'Length = 40,
         "disabled hooks must not block commit creation");
      Assert
        (not Ada.Directories.Exists (Join (Root, "disabled-post-commit.txt")),
         "VERSION_NO_HOOKS must suppress post-commit execution");
      Ada.Directories.Set_Directory (Old);
      if Had_Disable then
         Ada.Environment_Variables.Set
           ("VERSION_NO_HOOKS", Ada.Strings.Unbounded.To_String (Old_Disable));
      else
         Ada.Environment_Variables.Clear ("VERSION_NO_HOOKS");
      end if;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         if Had_Disable then
            Ada.Environment_Variables.Set
              ("VERSION_NO_HOOKS",
               Ada.Strings.Unbounded.To_String (Old_Disable));
         else
            Ada.Environment_Variables.Clear ("VERSION_NO_HOOKS");
         end if;
         raise;
   end Disabled_Hooks_Skip_Post_Commit;

   procedure Hook_Output_Field_Remains_Stable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root   : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old    : constant String := Ada.Directories.Current_Directory;
      Args   : Version.Hooks.Argument_Vectors.Vector;
      Result : Version.Hooks.Hook_Result;
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Write_Hook
        (Root,
         "pre-commit",
         "echo stdout-line"
         & Character'Val (10)
         & "echo stderr-line >&2"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Result :=
        Version.Hooks.Run_Hook (Version.Repository.Open, "pre-commit", Args);
      Assert (Result.Ran, "hook must run");
      Assert (Result.Exit_Code = 0, "hook must succeed");
      Assert
        (Ada.Strings.Unbounded.To_String (Result.Output)'Length = 0,
         "hook result output capture is intentionally empty/stable");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Hook_Output_Field_Remains_Stable;

   procedure Non_Executable_POSIX_Hook_Is_Ignored
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root   : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old    : constant String := Ada.Directories.Current_Directory;
      Args   : Version.Hooks.Argument_Vectors.Vector;
      Result : Version.Hooks.Hook_Result;
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Version.Test_Support.Write_Text_File
        (Join (Join (Join (Root, ".git"), "hooks"), "pre-commit"),
         "#!/bin/sh"
         & Character'Val (10)
         & "echo should-not-run > non-executable-ran.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "chmod -x .git/hooks/pre-commit");
      Ada.Directories.Set_Directory (Root);
      Result :=
        Version.Hooks.Run_Hook (Version.Repository.Open, "pre-commit", Args);
      Assert (not Result.Ran, "non-executable POSIX hook must be ignored");
      Assert
        (Result.Exit_Code = 0, "ignored non-executable hook must be a no-op");
      Assert
        (not Ada.Directories.Exists (Join (Root, "non-executable-ran.txt")),
         "non-executable hook must not execute");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Non_Executable_POSIX_Hook_Is_Ignored;

   procedure Invalid_Hook_Name_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root     : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old      : constant String := Ada.Directories.Current_Directory;
      Args     : Version.Hooks.Argument_Vectors.Vector;
      Rejected : Boolean := False;
   begin
      Version.Init.Init (Root);
      Ada.Directories.Set_Directory (Root);
      begin
         declare
            Result : constant Version.Hooks.Hook_Result :=
              Version.Hooks.Run_Hook
                (Version.Repository.Open, "../pre-commit", Args);
            pragma Unreferenced (Result);
         begin
            null;
         end;
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "generic hook runner must reject unsafe hook names");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Invalid_Hook_Name_Is_Rejected;

   procedure Absolute_Hook_Name_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root     : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old      : constant String := Ada.Directories.Current_Directory;
      Args     : Version.Hooks.Argument_Vectors.Vector;
      Rejected : Boolean := False;
   begin
      Version.Init.Init (Root);
      Ada.Directories.Set_Directory (Root);
      begin
         declare
            Result : constant Version.Hooks.Hook_Result :=
              Version.Hooks.Run_Hook
                (Version.Repository.Open, "/tmp/pre-commit", Args);
            pragma Unreferenced (Result);
         begin
            null;
         end;
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected,
         "absolute hook names must be rejected before path resolution");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Absolute_Hook_Name_Is_Rejected;

   procedure Symlinked_POSIX_Hook_Is_Ignored
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root   : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old    : constant String := Ada.Directories.Current_Directory;
      Args   : Version.Hooks.Argument_Vectors.Vector;
      Result : Version.Hooks.Hook_Result;
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Version.Test_Support.Write_Text_File
        (Join (Root, "outside-hook.sh"),
         "#!/bin/sh"
         & Character'Val (10)
         & "echo escaped > symlink-hook-ran.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "chmod +x outside-hook.sh");
      Version.Git_Fixtures.Run
        (Root, "ln -s ../../outside-hook.sh .git/hooks/pre-commit");
      Ada.Directories.Set_Directory (Root);
      Result :=
        Version.Hooks.Run_Hook (Version.Repository.Open, "pre-commit", Args);
      Assert (not Result.Ran, "symlinked POSIX hook must be ignored");
      Assert (Result.Exit_Code = 0, "ignored symlinked hook must be a no-op");
      Assert
        (not Ada.Directories.Exists (Join (Root, "symlink-hook-ran.txt")),
         "hook symlink must not execute target outside .git/hooks");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Symlinked_POSIX_Hook_Is_Ignored;

   procedure Hook_Receives_Cwd_And_Environment
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;

      Old_Index_Exists : constant Boolean :=
        Ada.Environment_Variables.Exists ("GIT_INDEX_FILE");

      Old_Index_Value : constant Ada.Strings.Unbounded.Unbounded_String :=
        (if Old_Index_Exists then
            Ada.Strings.Unbounded.To_Unbounded_String
              (Ada.Environment_Variables.Value ("GIT_INDEX_FILE"))
         else
            Ada.Strings.Unbounded.Null_Unbounded_String);

      procedure Restore_Index_Env is
      begin
         if Old_Index_Exists then
            Ada.Environment_Variables.Set
              ("GIT_INDEX_FILE",
               Ada.Strings.Unbounded.To_String (Old_Index_Value));
         else
            Ada.Environment_Variables.Clear ("GIT_INDEX_FILE");
         end if;
      end Restore_Index_Env;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root);
      Ada.Environment_Variables.Set
        ("GIT_INDEX_FILE", Join (Root, "outside-index"));
      Write_Hook
        (Root,
         "pre-commit",
         "pwd > hook-pwd.txt"
         & Character'Val (10)
         & "printf '%s\n' ""$GIT_DIR"" > hook-git-dir.txt"
         & Character'Val (10)
         & "printf '%s\n' ""$GIT_COMMON_DIR"" > hook-common-dir.txt"
         & Character'Val (10)
         & "printf '%s\n' ""$GIT_WORK_TREE"" > hook-work-tree.txt"
         & Character'Val (10)
         & "printf '%s\n' ""$GIT_INDEX_FILE"" > hook-index-file.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("env");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File (Join (Root, "hook-pwd.txt")),
            Root)
         /= 0,
         "hook cwd must be repo root");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "hook-git-dir.txt")),
            Join (Root, ".git"))
         /= 0,
         "GIT_DIR missing");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "hook-common-dir.txt")),
            Join (Root, ".git"))
         /= 0,
         "GIT_COMMON_DIR missing");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "hook-work-tree.txt")),
            Root)
         /= 0,
         "GIT_WORK_TREE missing");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "hook-index-file.txt")),
            Join (Join (Root, ".git"), "index"))
         /= 0,
         "GIT_INDEX_FILE missing");
      Assert
        (Ada.Environment_Variables.Exists ("GIT_INDEX_FILE")
         and then Ada.Environment_Variables.Value ("GIT_INDEX_FILE")
           = Join (Root, "outside-index"),
         "GIT_INDEX_FILE must be restored after hook execution");
      Ada.Directories.Set_Directory (Old);
      Restore_Index_Env;
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         Restore_Index_Env;
         raise;
   end Hook_Receives_Cwd_And_Environment;

   procedure Post_Checkout_Runs_After_Branch_Switch
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Version.Git_Fixtures.Init_Repo_With_One_Commit (Root);
      Write_Hook
        (Root,
         "post-checkout",
         "echo ""$1 $2 $3"" > checkout-args.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Branch.Create_Branch ("topic");
      Version.Branch.Switch_Branch ("topic");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Root, "checkout-args.txt")),
            " 1")
         /= 0,
         "post-checkout branch flag missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Checkout_Runs_After_Branch_Switch;

   procedure Post_Checkout_Runs_After_Worktree_Add
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root   : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Linked : constant String := Root & "-linked";
      Old    : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Version.Git_Fixtures.Init_Repo_With_One_Commit (Root);
      Write_Hook
        (Root,
         "post-checkout",
         "echo ""$1 $2 $3"" > worktree-checkout-args.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Ada.Directories.Set_Directory (Root);
      Version.Branch.Create_Branch ("worktree-topic");
      Version.Worktrees.Add (Path => Linked, Branch => "worktree-topic");
      Assert
        (Ada.Directories.Exists (Join (Linked, "worktree-checkout-args.txt")),
         "worktree add must run post-checkout in the linked worktree root");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Linked, "worktree-checkout-args.txt")),
            " 1")
         /= 0,
         "worktree add post-checkout branch flag missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Post_Checkout_Runs_After_Worktree_Add;

   procedure Pre_Push_Blocks_Remote_Update
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root       : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Source     : constant String := Join (Root, "source");
      Clone_Path : constant String := Join (Root, "clone");
      Old        : constant String := Ada.Directories.Current_Directory;
      Blocked    : Boolean := False;
   begin
      Skip_Unless_POSIX;
      Ada.Directories.Create_Directory (Source);
      Version.Init.Init (Source);
      Configure_User (Source);
      Version.Test_Support.Write_Text_File
        (Join (Source, "a.txt"), "initial" & Character'Val (10));
      Version.Git_Fixtures.Run (Source, "git add a.txt");
      Ada.Directories.Set_Directory (Source);
      Version.Write.Save ("initial");
      Ada.Directories.Set_Directory (Old);

      Version.Clone.Clone (Source => Source, Target => Clone_Path);

      Ada.Directories.Set_Directory (Clone_Path);
      Version.Test_Support.Write_Text_File
        (Join (Clone_Path, "a.txt"), "changed" & Character'Val (10));
      Version.Git_Fixtures.Run (Clone_Path, "git add a.txt");
      Version.Write.Save ("changed");

      Write_Hook
        (Clone_Path,
         "pre-push",
         "echo blocked > pre-push-blocked.txt"
         & Character'Val (10)
         & "exit 1"
         & Character'Val (10));

      begin
         Version.Push.Push (Remote_Name => "origin", Branch_Name => "main");
      exception
         when Ada.IO_Exceptions.Data_Error =>
            Blocked := True;
      end;

      Assert (Blocked, "pre-push failure must block push");
      Version.Git_Fixtures.Run
        (Source, "test ""$(git log --format=%s -1)"" = ""initial""");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Pre_Push_Blocks_Remote_Update;

   procedure Pre_Push_Receives_Remote_Arguments
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root       : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Source     : constant String := Join (Root, "source");
      Clone_Path : constant String := Join (Root, "clone");
      Old        : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Ada.Directories.Create_Directory (Source);
      Version.Init.Init (Source);
      Configure_User (Source);
      Version.Test_Support.Write_Text_File
        (Join (Source, "a.txt"), "initial" & Character'Val (10));
      Version.Git_Fixtures.Run (Source, "git add a.txt");
      Ada.Directories.Set_Directory (Source);
      Version.Write.Save ("initial");
      Ada.Directories.Set_Directory (Old);

      Version.Clone.Clone (Source => Source, Target => Clone_Path);
      Ada.Directories.Set_Directory (Clone_Path);
      Version.Test_Support.Write_Text_File
        (Join (Clone_Path, "a.txt"), "changed" & Character'Val (10));
      Version.Git_Fixtures.Run (Clone_Path, "git add a.txt");
      Version.Write.Save ("changed");
      Write_Hook
        (Clone_Path,
         "pre-push",
         "printf '%s\n%s\n' ""$1"" ""$2"" > pre-push-args.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));

      Version.Push.Push (Remote_Name => "origin", Branch_Name => "main");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Clone_Path, "pre-push-args.txt")),
            "origin")
         /= 0,
         "pre-push must receive remote name");
      Assert
        (Ada.Strings.Fixed.Index
           (Version.Test_Support.Read_Text_File
              (Join (Clone_Path, "pre-push-args.txt")),
            Source)
         /= 0,
         "pre-push must receive remote URL");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Pre_Push_Receives_Remote_Arguments;

   procedure Merge_Hooks_Receive_Sanitized_Git_Local_Environment
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
      Options : Version.Branch.Merge_Options;

      procedure Clear_Stale_Env is
      begin
         Ada.Environment_Variables.Clear ("GIT_OBJECT_DIRECTORY");
         Ada.Environment_Variables.Clear ("GIT_ALTERNATE_OBJECT_DIRECTORIES");
         Ada.Environment_Variables.Clear ("GIT_PREFIX");
         Ada.Environment_Variables.Clear ("GIT_SHALLOW_FILE");
      end Clear_Stale_Env;

      procedure Assert_Hook_Env (Path, Label : String) is
         Text : constant String := Version.Test_Support.Read_Text_File (Path);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_DIR=") /= 0,
            Label & " must receive GIT_DIR");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_COMMON_DIR=") /= 0,
            Label & " must receive GIT_COMMON_DIR");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_WORK_TREE=") /= 0,
            Label & " must receive GIT_WORK_TREE");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_INDEX_FILE=") /= 0,
            Label & " must receive GIT_INDEX_FILE");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_IMPLICIT_WORK_TREE=0") /= 0,
            Label & " must receive explicit worktree mode");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_OBJECT_DIRECTORY=") = 0,
            Label & " must not inherit stale GIT_OBJECT_DIRECTORY");
         Assert
           (Ada.Strings.Fixed.Index
              (Text, "GIT_ALTERNATE_OBJECT_DIRECTORIES=") = 0,
            Label & " must not inherit stale alternates");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_PREFIX=") = 0,
            Label & " must not inherit stale GIT_PREFIX");
         Assert
           (Ada.Strings.Fixed.Index (Text, "GIT_SHALLOW_FILE=") = 0,
            Label & " must not inherit stale GIT_SHALLOW_FILE");
      end Assert_Hook_Env;
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Version.Test_Support.Write_Text_File
        (Join (Root, "base.txt"), "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Version.Branch.Create_Branch ("feature");

      Version.Branch.Switch_Branch ("feature");
      Version.Test_Support.Write_Text_File
        (Join (Root, "feature.txt"), "feature" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add feature.txt");
      Version.Write.Save ("feature");

      Version.Branch.Switch_Branch ("main");
      Version.Test_Support.Write_Text_File
        (Join (Root, "main.txt"), "main" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add main.txt");
      Version.Write.Save ("main");

      Write_Hook
        (Root,
         "pre-merge-commit",
         "env | grep '^GIT_' | sort > pre-merge-env.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));
      Write_Hook
        (Root,
         "post-merge",
         "env | grep '^GIT_' | sort > post-merge-env.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));

      Ada.Environment_Variables.Set
        ("GIT_OBJECT_DIRECTORY", Join (Root, "outside-objects"));
      Ada.Environment_Variables.Set
        ("GIT_ALTERNATE_OBJECT_DIRECTORIES", Join (Root, "outside-alt"));
      Ada.Environment_Variables.Set ("GIT_PREFIX", "outside-prefix");
      Ada.Environment_Variables.Set
        ("GIT_SHALLOW_FILE", Join (Root, "outside-shallow"));

      Options.Fast_Forward := Version.Branch.Fast_Forward_Disabled;
      Version.Branch.Merge ("feature", Options);

      Assert_Hook_Env
        (Join (Root, "pre-merge-env.txt"), "pre-merge-commit");
      Assert_Hook_Env (Join (Root, "post-merge-env.txt"), "post-merge");
      Assert
        (Ada.Environment_Variables.Exists ("GIT_OBJECT_DIRECTORY")
         and then Ada.Environment_Variables.Value ("GIT_OBJECT_DIRECTORY")
           = Join (Root, "outside-objects"),
         "caller GIT_OBJECT_DIRECTORY must be restored after merge hooks");
      Assert
        (Ada.Environment_Variables.Exists ("GIT_PREFIX")
         and then Ada.Environment_Variables.Value ("GIT_PREFIX")
           = "outside-prefix",
         "caller GIT_PREFIX must be restored after merge hooks");

      Clear_Stale_Env;
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Clear_Stale_Env;
         Ada.Directories.Set_Directory (Old);
         raise;
   end Merge_Hooks_Receive_Sanitized_Git_Local_Environment;

   procedure Replay_Commits_Run_Shared_Commit_Hooks
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Version.Test_Support.Write_Text_File
        (Join (Root, "base.txt"), "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Version.Branch.Create_Branch ("feature");

      Version.Branch.Switch_Branch ("feature");
      Version.Test_Support.Write_Text_File
        (Join (Root, "feature.txt"), "feature" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add feature.txt");
      Version.Write.Save ("feature original");

      declare
         Feature_Commit : constant String :=
           Version.Refs.Current_Commit_Id (Version.Repository.Open);
      begin
         Version.Branch.Switch_Branch ("main");
         Version.Test_Support.Write_Text_File
           (Join (Root, "main.txt"), "main" & Character'Val (10));
         Version.Git_Fixtures.Run (Root, "git add main.txt");
         Version.Write.Save ("main change");

         Write_Hook
           (Root,
            "commit-msg",
            "echo replay edited > ""$1"""
            & Character'Val (10)
            & "exit 0"
            & Character'Val (10));
         Write_Hook
           (Root,
            "post-commit",
            "echo replay post > replay-post-commit.txt"
            & Character'Val (10)
            & "exit 0"
            & Character'Val (10));

         Version.Cherry_Pick.Start (Feature_Commit);
      end;

      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""replay edited""");
      Assert
        (Ada.Directories.Exists (Join (Root, "replay-post-commit.txt")),
         "replay-created commit must run shared post-commit hook");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Replay_Commits_Run_Shared_Commit_Hooks;

   procedure No_Op_Save_Skips_Post_Commit
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root        : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old         : constant String := Ada.Directories.Current_Directory;
      Original_Id : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root, "initial");
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("initial");
      Original_Id :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Version.Refs.Current_Commit_Id (Version.Repository.Open));

      Write_Hook
        (Root,
         "post-commit",
         "echo should-not-run > no-op-post-commit.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));

      Version.Write.Save ("no-op save");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)
         = Ada.Strings.Unbounded.To_String (Original_Id),
         "no-op save must not create a replacement commit");
      Assert
        (not Ada.Directories.Exists (Join (Root, "no-op-post-commit.txt")),
         "post-commit must not run for no-op save");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end No_Op_Save_Skips_Post_Commit;

   procedure Object_Storage_Failure_Skips_Post_Commit
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root        : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old         : constant String := Ada.Directories.Current_Directory;
      Failed      : Boolean := False;
      Head_Before : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Skip_Unless_POSIX;
      Init_Staged_File (Root, "initial");
      Ada.Directories.Set_Directory (Root);
      Version.Write.Save ("initial");
      Head_Before :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Version.Refs.Current_Commit_Id (Version.Repository.Open));

      Version.Test_Support.Write_Text_File
        (Join (Root, "a.txt"), "changed" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Write_Hook
        (Root,
         "post-commit",
         "echo should-not-run > object-failure-post-commit.txt"
         & Character'Val (10)
         & "exit 0"
         & Character'Val (10));

      Version.Git_Fixtures.Run
        (Root, "mv .git/objects .git/objects.saved && touch .git/objects");
      begin
         Version.Write.Save ("object write failure");
      exception
         when
           Ada.IO_Exceptions.Data_Error
           | Ada.IO_Exceptions.Name_Error
           | Ada.IO_Exceptions.Use_Error
         =>
            Failed := True;
      end;
      Version.Git_Fixtures.Run
        (Root, "rm -f .git/objects && mv .git/objects.saved .git/objects");

      Assert
        (Failed, "object storage failure must fail save before post-commit");
      Assert
        (Version.Refs.Current_Commit_Id (Version.Repository.Open)
         = Ada.Strings.Unbounded.To_String (Head_Before),
         "object storage failure must preserve HEAD");
      Assert
        (not Ada.Directories.Exists
               (Join (Root, "object-failure-post-commit.txt")),
         "post-commit must not run when commit object creation cannot complete");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         if Ada.Directories.Exists (Join (Root, ".git/objects.saved")) then
            Version.Git_Fixtures.Run
              (Root,
               "rm -f .git/objects && mv .git/objects.saved .git/objects");
         end if;
         Ada.Directories.Set_Directory (Old);
         raise;
   end Object_Storage_Failure_Skips_Post_Commit;

   procedure Non_Blocking_Run_Hook_Returns_Before_Hook_Finishes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
      Args : Version.Hooks.Argument_Vectors.Vector;
      Marker : constant String := Join (Root, "nonblocking-ran.txt");
   begin
      Skip_Unless_POSIX;
      Version.Init.Init (Root);
      Write_Hook
        (Root,
         "post-commit",
         "sleep 1" & Character'Val (10)
         & "echo done > nonblocking-ran.txt" & Character'Val (10));

      Ada.Directories.Set_Directory (Root);
      declare
         Result : constant Version.Hooks.Hook_Result :=
           Version.Hooks.Run_Hook
             (Version.Repository.Open, "post-commit", Args, Blocking => False);
      begin
         Assert (Result.Ran, "non-blocking hook must be launched");
         Assert
           (Result.Exit_Code = 0,
            "successful non-blocking hook launch must report zero status");
      end;

      Assert
        (not Ada.Directories.Exists (Marker),
         "non-blocking hook call must not wait for delayed side effect");
      Assert
        (Wait_For_File (Marker),
         "non-blocking hook process must eventually run");

      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Non_Blocking_Run_Hook_Returns_Before_Hook_Finishes;

   procedure Hook_Failure_Diagnostic_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Error_Output_Text ("post-commit hook failed")
         = "error: post-commit hook failed",
         "hook failure diagnostic must remain stable");
      Assert
        (Version.CLI.Command_Failure_Exit_Status
         = Ada.Command_Line.Exit_Status (1),
         "hook failure must be reported as a command failure");
   end Hook_Failure_Diagnostic_Is_Frozen;

   procedure Windows_Cmd_Hook_Runs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old  : constant String := Ada.Directories.Current_Directory;
      Args : Version.Hooks.Argument_Vectors.Vector;
   begin
      Skip_Unless_Windows;
      Version.Init.Init (Root);
      Version.Test_Support.Write_Text_File
        (Join (Join (Join (Root, ".git"), "hooks"), "pre-commit.cmd"),
         "@echo off"
         & Character'Val (13)
         & Character'Val (10)
         & "echo ran > hook-cmd-ran.txt"
         & Character'Val (13)
         & Character'Val (10)
         & "exit /b 0"
         & Character'Val (13)
         & Character'Val (10));

      Ada.Directories.Set_Directory (Root);
      declare
         Result : constant Version.Hooks.Hook_Result :=
           Version.Hooks.Run_Hook
             (Version.Repository.Open, "pre-commit", Args);
      begin
         Assert (Result.Ran, "Windows .cmd hook must be discovered and run");
         Assert
           (Result.Exit_Code = 0, "Windows .cmd hook must exit successfully");
      end;
      Assert
        (Ada.Directories.Exists (Join (Root, "hook-cmd-ran.txt")),
         "Windows .cmd hook marker missing");
      Ada.Directories.Set_Directory (Old);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old);
         raise;
   end Windows_Cmd_Hook_Runs;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      Register_Routine
        (T, Missing_Hook_Is_No_Op'Access, "Hooks: missing hook is no-op");
      Register_Routine
        (T,
         Pre_Commit_Runs_Before_Save'Access,
         "Hooks: pre-commit runs before save");
      Register_Routine
        (T,
         Pre_Commit_Blocks_Save'Access,
         "Hooks: pre-commit nonzero blocks save");
      Register_Routine
        (T,
         Commit_Msg_Can_Edit_Message'Access,
         "Hooks: commit-msg can edit message");
      Register_Routine
        (T,
         Commit_Msg_Blocks_Save'Access,
         "Hooks: commit-msg nonzero blocks save");
      Register_Routine
        (T,
         Hook_Failure_Restores_Current_Directory'Access,
         "Hooks: current directory restored after hook failure");
      Register_Routine
        (T,
         No_Verify_Skips_Commit_Hooks'Access,
         "Hooks: no-verify skips commit hooks");
      Register_Routine
        (T,
         Post_Commit_Failure_Does_Not_Roll_Back'Access,
         "Hooks: post-commit failure does not roll back commit");
      Register_Routine
        (T,
         Save_Amend_Runs_Post_Commit'Access,
         "Hooks: amend save runs post-commit");
      Register_Routine
        (T,
         No_Op_Save_Skips_Post_Commit'Access,
         "Hooks: no-op save skips post-commit");
      Register_Routine
        (T,
         Object_Storage_Failure_Skips_Post_Commit'Access,
         "Hooks: object storage failure skips post-commit");
      Register_Routine
        (T,
         Non_Blocking_Run_Hook_Returns_Before_Hook_Finishes'Access,
         "Hooks: non-blocking hook launch returns before completion");
      Register_Routine
        (T,
         Hook_Failure_Diagnostic_Is_Frozen'Access,
         "Hooks: hook failure diagnostic is frozen");
      Register_Routine
        (T,
         Post_Commit_Observes_Updated_HEAD'Access,
         "Hooks: post-commit observes updated HEAD");
      Register_Routine
        (T,
         Post_Commit_Runs_In_Repository_Root'Access,
         "Hooks: post-commit runs in repository root");
      Register_Routine
        (T,
         Post_Commit_Not_Run_When_Pre_Commit_Fails'Access,
         "Hooks: post-commit is skipped when commit creation fails");
      Register_Routine
        (T,
         Post_Commit_Not_Run_When_Commit_Msg_Fails'Access,
         "Hooks: post-commit is skipped when commit-msg fails");
      Register_Routine
        (T,
         Disabled_Hooks_Skip_Post_Commit'Access,
         "Hooks: disabled hooks skip post-commit");
      Register_Routine
        (T,
         Hook_Output_Field_Remains_Stable'Access,
         "Hooks: hook result output field is stable");
      Register_Routine
        (T,
         Non_Executable_POSIX_Hook_Is_Ignored'Access,
         "Hooks: non-executable POSIX hook is ignored");
      Register_Routine
        (T,
         Replay_Commits_Run_Shared_Commit_Hooks'Access,
         "Hooks: replay commits run shared commit hooks");
      Register_Routine
        (T,
         Invalid_Hook_Name_Is_Rejected'Access,
         "Hooks: invalid hook name is rejected");
      Register_Routine
        (T,
         Absolute_Hook_Name_Is_Rejected'Access,
         "Hooks: absolute hook name is rejected");
      Register_Routine
        (T,
         Symlinked_POSIX_Hook_Is_Ignored'Access,
         "Hooks: symlinked POSIX hook is ignored");
      Register_Routine
        (T,
         Hook_Receives_Cwd_And_Environment'Access,
         "Hooks: hook receives cwd and environment");
      Register_Routine
        (T,
         Merge_Hooks_Receive_Sanitized_Git_Local_Environment'Access,
         "Hooks: merge hooks receive sanitized Git local environment");
      Register_Routine
        (T,
         Post_Checkout_Runs_After_Branch_Switch'Access,
         "Hooks: post-checkout runs after branch switch");
      Register_Routine
        (T,
         Post_Checkout_Runs_After_Worktree_Add'Access,
         "Hooks: post-checkout runs after worktree add");
      Register_Routine
        (T,
         Pre_Push_Blocks_Remote_Update'Access,
         "Hooks: pre-push nonzero blocks remote update");
      Register_Routine
        (T,
         Pre_Push_Receives_Remote_Arguments'Access,
         "Hooks: pre-push receives remote arguments");
      Register_Routine
        (T,
         Windows_Cmd_Hook_Runs'Access,
         "Hooks: Windows .cmd hook runs when hooks enabled");
   end Register_Tests;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Version.Hooks");
   end Name;

end Version.Hooks.Tests;
