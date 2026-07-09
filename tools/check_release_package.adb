with Ada.Command_Line;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Release_Package is
   function Strip_Leading_Dot_Slash (Path : String) return String is
   begin
      if Tool_Support.Starts_With (Path, "./") then
         return Path (Path'First + 2 .. Path'Last);
      end if;
      return Path;
   end Strip_Leading_Dot_Slash;

   function Slash_Count (Path : String) return Natural is
      Count : Natural := 0;
   begin
      for Ch of Path loop
         if Ch = '/' then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Slash_Count;

   function Has_Component (Path, Component : String) return Boolean is
      Normal : constant String := Strip_Leading_Dot_Slash (Path);
   begin
      return Normal = Component
        or else Tool_Support.Starts_With (Normal, Component & "/")
        or else Tool_Support.Ends_With (Normal, "/" & Component)
        or else Tool_Support.Index (Normal, "/" & Component & "/") /= 0;
   end Has_Component;

   function Has_Suffix (Path : String) return Boolean is
   begin
      return Tool_Support.Ends_With (Path, ".ali")
        or else Tool_Support.Ends_With (Path, ".o")
        or else Tool_Support.Ends_With (Path, ".a")
        or else Tool_Support.Ends_With (Path, ".so")
        or else Tool_Support.Ends_With (Path, ".dylib")
        or else Tool_Support.Ends_With (Path, ".dll")
        or else Tool_Support.Ends_With (Path, ".exe")
        or else Tool_Support.Ends_With (Path, ".tmp")
        or else Tool_Support.Ends_With (Path, ".lock")
        or else Tool_Support.Ends_With (Path, ".zip")
        or else Tool_Support.Ends_With (Path, ".tar")
        or else Tool_Support.Ends_With (Path, ".tar.gz")
        or else Tool_Support.Ends_With (Path, ".tgz")
        or else Tool_Support.Ends_With (Path, "~")
        or else Tool_Support.Ends_With (Path, ".swp")
        or else Tool_Support.Ends_With (Path, ".DS_Store");
   end Has_Suffix;

   function Is_Generated_Artifact (Path : String) return Boolean is
   begin
      return Has_Component (Path, "obj")
        or else Has_Component (Path, "bin")
        or else Has_Component (Path, "share")
        or else Has_Component (Path, ".git")
        or else Has_Component (Path, ".github")
        or else Has_Component (Path, ".alire")
        or else Has_Component (Path, "coverage")
        or else Has_Component (Path, "tmp")
        or else Has_Suffix (Path);
   end Is_Generated_Artifact;

   procedure For_Each_Line
     (Text    : String;
      Process : not null access procedure (Line : String))
   is
      Start : Positive := Text'First;
   begin
      while Start <= Text'Last loop
         declare
            LF   : constant Natural := Tool_Support.Index (Text (Start .. Text'Last), "" & ASCII.LF);
            Stop : constant Natural := (if LF = 0 then Text'Last else LF - 1);
         begin
            if Stop >= Start then
               Process (Text (Start .. Stop));
            end if;
            exit when LF = 0;
            Start := LF + 1;
         end;
      end loop;
   exception
      when Constraint_Error =>
         null;
   end For_Each_Line;

   function Find_Entry (Contents, Name : String) return String is
      Found : Tool_Support.US.Unbounded_String;
      procedure Check (Line : String) is
      begin
         if Tool_Support.US.Length (Found) = 0
           and then Has_Component (Line, Name)
         then
            Found := Tool_Support.US.To_Unbounded_String (Line);
         end if;
      end Check;
   begin
      For_Each_Line (Contents, Check'Access);
      return Tool_Support.US.To_String (Found);
   end Find_Entry;

   function Find_Exact_File (Contents, Name : String) return String is
      Found : Tool_Support.US.Unbounded_String;
      procedure Check (Line : String) is
         Normal : constant String := Strip_Leading_Dot_Slash (Line);
      begin
         if Tool_Support.US.Length (Found) = 0
           and then (Normal = Name or else Tool_Support.Ends_With (Normal, "/" & Name))
         then
            Found := Tool_Support.US.To_Unbounded_String (Line);
         end if;
      end Check;
   begin
      For_Each_Line (Contents, Check'Access);
      return Tool_Support.US.To_String (Found);
   end Find_Exact_File;

   function Find_Root_File (Contents, Name : String) return String is
      Found : Tool_Support.US.Unbounded_String;
      procedure Check (Line : String) is
         Normal : constant String := Strip_Leading_Dot_Slash (Line);
      begin
         if Tool_Support.US.Length (Found) = 0
           and then (Normal = Name
             or else (Slash_Count (Normal) = 1 and then Tool_Support.Ends_With (Normal, "/" & Name)))
         then
            Found := Tool_Support.US.To_Unbounded_String (Line);
         end if;
      end Check;
   begin
      For_Each_Line (Contents, Check'Access);
      return Tool_Support.US.To_String (Found);
   end Find_Root_File;

   procedure Reject_Generated_Artifacts (Contents : String) is
      Bad : Tool_Support.US.Unbounded_String;
      procedure Check (Line : String) is
      begin
         if Line /= "" and then Is_Generated_Artifact (Line) then
            Tool_Support.US.Append (Bad, Line);
            Tool_Support.US.Append (Bad, ASCII.LF);
         end if;
      end Check;
   begin
      For_Each_Line (Contents, Check'Access);
      if Tool_Support.US.Length (Bad) /= 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "error: archive contains generated or local artifacts:");
         Ada.Text_IO.Put
           (Ada.Text_IO.Standard_Error, Tool_Support.US.To_String (Bad));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         Tool_Support.Fail ("archive contains generated or local artifacts");
      end if;
   end Reject_Generated_Artifacts;

   procedure Require_Entry (Contents, Name : String) is
   begin
      if Find_Entry (Contents, Name) = "" then
         Tool_Support.Fail ("archive missing " & Name);
      end if;
   end Require_Entry;

   procedure Require_Root_File (Contents, Name : String) is
   begin
      if Find_Root_File (Contents, Name) = "" then
         Tool_Support.Fail ("archive missing root " & Name);
      end if;
   end Require_Root_File;

   procedure Require_Exact_File (Contents, Name : String) is
   begin
      if Find_Exact_File (Contents, Name) = "" then
         Tool_Support.Fail ("archive missing " & Name);
      end if;
   end Require_Exact_File;

   function Archive_List_Command (Archive : String) return String is
   begin
      if Tool_Support.Ends_With (Archive, ".tar")
        or else Tool_Support.Ends_With (Archive, ".tar.gz")
        or else Tool_Support.Ends_With (Archive, ".tgz")
      then
         return "tar -tf " & Tool_Support.Shell_Quote (Archive);
      elsif Tool_Support.Ends_With (Archive, ".zip") then
         return "zipinfo -1 " & Tool_Support.Shell_Quote (Archive);
      else
         return "";
      end if;
   end Archive_List_Command;

   function Archive_Cat_Command (Archive, Member : String) return String is
   begin
      if Tool_Support.Ends_With (Archive, ".tar")
        or else Tool_Support.Ends_With (Archive, ".tar.gz")
        or else Tool_Support.Ends_With (Archive, ".tgz")
      then
         return "tar -xOf " & Tool_Support.Shell_Quote (Archive) & " " &
           Tool_Support.Shell_Quote (Member);
      else
         return "unzip -p " & Tool_Support.Shell_Quote (Archive) & " " &
           Tool_Support.Shell_Quote (Member);
      end if;
   end Archive_Cat_Command;

   function Contains_Parent_Pin (Text : String) return Boolean is
      Position : Natural := Text'First;
   begin
      while Position <= Text'Last loop
         declare
            LF   : constant Natural := Tool_Support.Index (Text (Position .. Text'Last), "" & ASCII.LF);
            Stop : constant Natural := (if LF = 0 then Text'Last else LF - 1);
            Line : constant String := Text (Position .. Stop);
         begin
            if Tool_Support.Index (Line, "path") /= 0
              and then Tool_Support.Index (Line, "=") /= 0
              and then Tool_Support.Index (Line, "..") /= 0
            then
               return True;
            end if;
            exit when LF = 0;
            Position := LF + 1;
         end;
      end loop;
      return False;
   exception
      when Constraint_Error =>
         return False;
   end Contains_Parent_Pin;

   function Declares_Version (Text : String) return Boolean is
   begin
      return Tool_Support.Starts_With (Text, "version")
        or else Tool_Support.Index (Text, ASCII.LF & "version") /= 0;
   end Declares_Version;

   Archive     : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   List_Cmd    : constant String := Archive_List_Command (Archive);
   Contents    : Tool_Support.US.Unbounded_String;
   Alire_Entry : Tool_Support.US.Unbounded_String;
   Alire_Text  : Tool_Support.US.Unbounded_String;
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: check_release_package ARCHIVE.tar.gz|ARCHIVE.zip");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if List_Cmd = "" then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: unsupported archive type: " & Archive);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if Tool_Support.Is_File ("./tools/bin/check_release_consistency") then
      if Tool_Support.Command_Output ("./tools/bin/check_release_consistency") = "" then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
   end if;

   Contents := Tool_Support.US.To_Unbounded_String
     (Tool_Support.Command_Output (List_Cmd));
   if Tool_Support.US.Length (Contents) = 0 then
      Tool_Support.Fail ("could not list archive: " & Archive);
   end if;

   Reject_Generated_Artifacts (Tool_Support.US.To_String (Contents));

   Require_Entry (Tool_Support.US.To_String (Contents), "src");
   Require_Entry (Tool_Support.US.To_String (Contents), "tests");
   Require_Entry (Tool_Support.US.To_String (Contents), "docs");
   Require_Entry (Tool_Support.US.To_String (Contents), "examples");
   Require_Entry (Tool_Support.US.To_String (Contents), "tools");
   Require_Entry (Tool_Support.US.To_String (Contents), "config");
   Require_Entry (Tool_Support.US.To_String (Contents), "ci");
   Require_Entry (Tool_Support.US.To_String (Contents), "LICENSES");

   Require_Root_File (Tool_Support.US.To_String (Contents), "alire.toml");
   Require_Root_File (Tool_Support.US.To_String (Contents), "version.gpr");
   Require_Root_File (Tool_Support.US.To_String (Contents), "README.md");
   Require_Root_File (Tool_Support.US.To_String (Contents), "CHANGELOG.md");
   Require_Root_File (Tool_Support.US.To_String (Contents), "LICENSE");

   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/COMPATIBILITY.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/RELEASE_CHECKLIST.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/RELEASE_NOTES.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/SECURITY.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/COMMANDS.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/PACKAGING.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "docs/CI.md");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "ci/github-actions-platform-matrix.yml");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_release_consistency.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_release_package_selftest.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_release_ready.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_test_scope_completeness.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_ref_write_policy.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_ref_write_policy_selftest.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_ref_transaction_selftest.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_documentation_coherence.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/tool_doc_guards.ads");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/tool_doc_guards.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_platform_ci_matrix.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_platform_ci_evidence.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/check_platform_ci_evidence_selftest.adb");
   Require_Exact_File (Tool_Support.US.To_String (Contents), "tools/summarize_release_evidence.adb");

   Alire_Entry := Tool_Support.US.To_Unbounded_String
     (Find_Root_File (Tool_Support.US.To_String (Contents), "alire.toml"));
   if Tool_Support.US.Length (Alire_Entry) = 0 then
      Tool_Support.Fail ("archive missing root alire.toml");
   end if;

   Alire_Text := Tool_Support.US.To_Unbounded_String
     (Tool_Support.Command_Output
        (Archive_Cat_Command (Archive, Tool_Support.US.To_String (Alire_Entry))));
   if Tool_Support.US.Length (Alire_Text) = 0 then
      Tool_Support.Fail ("could not read archive alire.toml");
   end if;

   if Contains_Parent_Pin (Tool_Support.US.To_String (Alire_Text)) then
      Tool_Support.Fail
        ("release alire.toml contains a parent-directory dependency pin");
   end if;

   if not Declares_Version (Tool_Support.US.To_String (Alire_Text)) then
      Tool_Support.Fail ("release alire.toml does not declare a version");
   end if;

   Ada.Text_IO.Put_Line ("release package looks clean");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Check_Release_Package;
