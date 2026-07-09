with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.Text;
with Project_Tools.Release_Checks;

--  Guard the version (CLI) crate's test scope: the CLI-side AUnit suites must
--  remain present and registered, and the registered-routine count must stay
--  above a closure floor. Functionality-suite scope is owned by versionlib's
--  own check_test_scope_completeness; this tool covers only version/tests.
procedure Check_Test_Scope_Completeness is
   Suite_File : constant String := "tests/src/version_suite.adb";
   Floor      : constant Natural := 80;

   procedure Require_Suite (Suite : String) is
   begin
      Project_Tools.Files.Require_Contains
        (Suite_File, "with " & Suite & ";",
         "CLI suite missing with-clause for " & Suite);
      Project_Tools.Files.Require_Contains
        (Suite_File, "new " & Suite & ".Test_Case",
         "CLI suite does not register " & Suite);
   end Require_Suite;

   procedure Count_In_Tree (Directory : String; Count : in out Natural) is
      Search : Ada.Directories.Search_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Directory, "",
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
               Full   : constant String :=
                 Project_Tools.Files.Join (Directory, Simple);
            begin
               if Simple /= "." and then Simple /= ".." then
                  case Ada.Directories.Kind (Item) is
                     when Ada.Directories.Ordinary_File =>
                        Count := Count + Project_Tools.Text.Count
                          (Project_Tools.Files.Read_Raw_File (Full),
                           "Register_Routine");
                     when Ada.Directories.Directory =>
                        Count_In_Tree (Full, Count);
                     when others =>
                        null;
                  end case;
               end if;
            end;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Count_In_Tree;

   Routines : Natural := 0;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: check_test_scope_completeness");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Project_Tools.Files.Require_File
     (Suite_File, "CLI test suite registry missing: " & Suite_File);
   Project_Tools.Files.Require_File
     ("tests/src/version-cli-tests.adb", "missing CLI test source");
   Project_Tools.Files.Require_File
     ("tests/src/version-hooks-tests.adb", "missing hooks CLI test source");
   Project_Tools.Files.Require_File
     ("tests/src/version-documentation-tests.adb", "missing docs test source");
   Project_Tools.Files.Require_File
     ("tests/src/cli_integration_tests.adb", "missing CLI-integration test source");

   Require_Suite ("Version.CLI.Tests");
   Require_Suite ("Version.Hooks.Tests");
   Require_Suite ("Version.Documentation.Tests");
   Require_Suite ("CLI_Integration_Tests");

   Count_In_Tree ("tests/src", Routines);
   if Routines < Floor then
      Project_Tools.Release_Checks.Fail
        ("registered AUnit routine count below CLI closure floor:"
         & Natural'Image (Routines));
   end if;

   Ada.Text_IO.Put_Line
     ("test-scope completeness checks passed (" & Natural'Image (Routines)
      & " routines)");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when Program_Error =>
      null;  -- a Require_* / Fail already set the failure exit status
end Check_Test_Scope_Completeness;
