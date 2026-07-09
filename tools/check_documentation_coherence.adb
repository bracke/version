with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Tool_Doc_Guards;
with Tool_Support;

procedure Check_Documentation_Coherence is
   use Ada.Strings.Unbounded;

   Failed : Boolean := False;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "error: " & Message);
      Failed := True;
   end Fail;

   type Accumulating_Reporter is new Tool_Doc_Guards.Reporter with null record;

   overriding procedure Report
     (Item    : in out Accumulating_Reporter;
      Message : String)
   is
      pragma Unreferenced (Item);
   begin
      Fail (Message);
   end Report;

   procedure Require_Line (Path : String; Line : String; Message : String) is
   begin
      if not Tool_Support.Has_Line (Path, Line) then
         Fail (Message);
      end if;
   end Require_Line;

   procedure Require_Contains
     (Path : String; Phrase : String; Message : String) is
   begin
      if not Tool_Support.Contains (Path, Phrase) then
         Fail (Message);
      end if;
   end Require_Contains;

   function Tree_Contains (Root : String; Phrase : String) return Boolean;

   function File_Contains (Path : String; Phrase : String) return Boolean is
   begin
      return Tool_Support.Contains (Path, Phrase);
   exception
      when others =>
         return False;
   end File_Contains;

   function Tree_Contains (Root : String; Phrase : String) return Boolean is
      Search : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Opened : Boolean := False;
   begin
      if not Tool_Support.Exists (Root) then
         return False;
      end if;

      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Root,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => False]);
      Opened := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if File_Contains (Full, Phrase) then
                        Ada.Directories.End_Search (Search);
                        return True;
                     end if;
                  when Ada.Directories.Directory =>
                     if Tree_Contains (Full, Phrase) then
                        Ada.Directories.End_Search (Search);
                        return True;
                     end if;
                  when others =>
                     null;
               end case;
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
         return False;
   end Tree_Contains;

   procedure Check_No_Stale_Http_Diagnostic is
      Phrase : constant String := "HTTP transport not implemented yet";
   begin
      if Tool_Support.Contains ("README.md", Phrase)
        or else Tree_Contains ("docs", Phrase)
        or else Tree_Contains ("src", Phrase)
        or else Tree_Contains ("tests", Phrase)
      then
         Fail ("stale HTTP transport diagnostic remains");
      end if;
   end Check_No_Stale_Http_Diagnostic;

   procedure Check_No_Stale_Merge_Symlink_Diagnostic is
      Phrase : constant String := "symlink merge is not supported on this platform";
   begin
      if Tree_Contains ("docs", Phrase)
        or else Tree_Contains ("src", Phrase)
        or else Tree_Contains ("tests", Phrase)
      then
         Fail ("stale merge symlink platform diagnostic remains");
      end if;
   end Check_No_Stale_Merge_Symlink_Diagnostic;

   Required_Files : constant array (Positive range <>) of Unbounded_String :=
     [To_Unbounded_String ("README.md"),
      To_Unbounded_String ("CHANGELOG.md"),
      To_Unbounded_String ("docs/CHANGELOG.md"),
      To_Unbounded_String ("docs/RELEASE_NOTES.md"),
      To_Unbounded_String ("docs/RELEASE_CHECKLIST.md"),
      To_Unbounded_String ("docs/PACKAGING.md"),
      To_Unbounded_String ("docs/TESTING.md")];

   Release_Gates : constant array (Positive range <>) of Unbounded_String :=
     [To_Unbounded_String ("check_version_metadata"),
      To_Unbounded_String ("check_release_consistency"),
      To_Unbounded_String ("check_release_ready"),
      To_Unbounded_String ("check_test_scope_completeness"),
      To_Unbounded_String ("check_release_package_selftest"),
      To_Unbounded_String ("check_documentation_coherence")];

begin
   for File of Required_Files loop
      Tool_Support.Require_File (To_String (File), "missing documentation file: " & To_String (File));
   end loop;

   Require_Line ("README.md", "```sh", "README release gates are not in a shell block");
   Require_Line
     ("README.md",
      "tools/bin/check_release_package_selftest",
      "README missing package self-test command");
   Require_Line
     ("README.md",
      "tools/bin/check_platform_ci_evidence .release/platform-ci-evidence",
      "README missing platform evidence command");

   if Tool_Support.First_Line ("docs/RELEASE_NOTES.md") /= "# Release notes: 0.1.0-dev" then
      Fail ("release notes must start with the release heading");
   end if;

   if not Tool_Support.Starts_With
       (Tool_Support.Second_Nonblank_Line ("docs/RELEASE_NOTES.md"),
        "This is a release-stabilization")
   then
      Fail ("release notes must start with the baseline release narrative");
   end if;

   Check_No_Stale_Http_Diagnostic;
   Check_No_Stale_Merge_Symlink_Diagnostic;
   declare
      Reporter : Accumulating_Reporter;
   begin
      Tool_Doc_Guards.Check_No_Stale_Tool_Script_References (Reporter);
   end;

   for Gate of Release_Gates loop
      Require_Contains
        ("docs/RELEASE_CHECKLIST.md", To_String (Gate),
         "release checklist missing " & To_String (Gate));
      Require_Contains
        ("docs/PACKAGING.md", To_String (Gate),
         "packaging docs missing " & To_String (Gate));
   end loop;

   Require_Contains
     ("docs/TESTING.md", "check_documentation_coherence",
      "testing docs missing documentation coherence gate");
   Require_Contains
     ("docs/TESTING.md", "check_release_ready",
      "testing docs missing Ada release preflight");
   Require_Contains
     ("tools/tools.gpr", "check_documentation_coherence.adb",
      "tools project missing Ada documentation coherence main");
   Require_Contains
     ("tools/tools.gpr", "check_release_ready.adb",
      "tools project missing Ada release preflight main");
   Require_Contains
     ("docs/RELEASE_NOTES.md", "Version.Files.Rollback",
      "release notes missing rollback file API boundary");

   Require_Contains
     ("docs/COMMANDS.md", "malformed `file://` percent escape",
      "clone docs missing malformed file URL escape failure");
   Require_Contains
     ("docs/COMPATIBILITY.md", "percent escapes are decoded",
      "compatibility docs missing file URL percent-decoding note");

   Require_Contains ("README.md", "version config list", "README missing config list command");
   Require_Contains ("docs/COMMANDS.md", "version config list", "commands docs missing config list command");
   Require_Contains ("docs/USAGE.md", "version config list", "usage docs missing config list command");

   if Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("documentation coherence checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Check_Documentation_Coherence;
