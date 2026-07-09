with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Tool_Support;

procedure Check_Release_Ready is
   use Ada.Strings.Unbounded;

   type Step is record
      Label     : Unbounded_String;
      Directory : Unbounded_String;
      Command   : Unbounded_String;
   end record;

   function Make_Step
     (Label     : String;
      Command   : String;
      Directory : String := "") return Step
   is
   begin
      return
        (Label     => To_Unbounded_String (Label),
         Directory => To_Unbounded_String (Directory),
         Command   => To_Unbounded_String (Command));
   end Make_Step;

   Steps : constant array (Positive range <>) of Step :=
     [Make_Step ("check release manifests", "tools/bin/check_release_manifests"),
      Make_Step ("build main project", "alr build"),
      Make_Step ("build test suite", "alr exec -- gprbuild -P tests.gpr", "tests"),
      Make_Step ("run test suite", "./tests/bin/tests"),
      Make_Step ("build tools", "alr exec -- gprbuild -P tools/tools.gpr"),
      Make_Step ("check version metadata", "tools/bin/check_version_metadata"),
      Make_Step ("check documentation coherence", "tools/bin/check_documentation_coherence"),
      Make_Step ("check test-scope completeness", "tools/bin/check_test_scope_completeness"),
      Make_Step ("check ref write policy", "tools/bin/check_ref_write_policy"),
      Make_Step ("self-test ref write policy", "tools/bin/check_ref_write_policy_selftest"),
      Make_Step ("self-test ref transaction", "tools/bin/check_ref_transaction_selftest"),
      Make_Step ("check release consistency", "tools/bin/check_release_consistency"),
      Make_Step ("self-test release consistency", "tools/bin/check_release_consistency_selftest"),
      Make_Step ("self-test platform CI evidence", "tools/bin/check_platform_ci_evidence_selftest"),
      Make_Step ("self-test release package", "tools/bin/check_release_package_selftest")];

   function Run_Check_Examples return Integer is
      Root        : constant String := Ada.Directories.Current_Directory;
      Tmp         : constant String := "/tmp/version-release-ready-ada";
      Version_Bin : constant String :=
        (if Tool_Support.Is_File (Tool_Support.Join (Root, "bin/version"))
         then Tool_Support.Join (Root, "bin/version")
         else Tool_Support.Join (Root, "bin/main"));
      Tmp_Bin     : constant String := Tool_Support.Join (Tmp, "version");
      Copied      : Boolean;
      Status      : Integer;
   begin
      if not Tool_Support.Is_File (Version_Bin) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "error: missing built version executable: " & Version_Bin);
         return 1;
      end if;

      Tool_Support.Delete_If_Exists (Tmp);
      Ada.Directories.Create_Path (Tmp);
      GNAT.OS_Lib.Copy_File
        (Name     => Version_Bin,
         Pathname => Tmp_Bin,
         Success  => Copied,
         Preserve => GNAT.OS_Lib.Full);
      if not Copied then
         Tool_Support.Delete_If_Exists (Tmp);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "error: failed to prepare temporary version executable");
         return 1;
      end if;

      Status := Tool_Support.Run_Program_With_Path_Prefix
        (Program     => Tool_Support.Join (Root, "tools/bin/check_examples"),
         Path_Prefix => Tmp);
      Tool_Support.Delete_If_Exists (Tmp);
      return Status;
   exception
      when others =>
         Tool_Support.Delete_If_Exists (Tmp);
         return 1;
   end Run_Check_Examples;

   procedure Run_Preflight_Step (Current : Step) is
      Label_Text : constant String := To_String (Current.Label);
      Command    : constant String := To_String (Current.Command);
      Message    : constant String :=
        "release preflight failed during " & Label_Text;
   begin
      Ada.Text_IO.Put_Line ("==> " & Label_Text);
      if Length (Current.Directory) = 0 then
         Ada.Text_IO.Put_Line ("$ " & Command);
         Tool_Support.Run_Checked (Command, Message);
      else
         declare
            Directory : constant String := To_String (Current.Directory);
         begin
            Ada.Text_IO.Put_Line
              ("$ cd " & Directory & " && " & Command);
            Tool_Support.Run_In_Directory_Checked
              (Directory => Directory,
               Command   => Command,
               Message   => Message);
         end;
      end if;
   end Run_Preflight_Step;

   Status : Integer;
begin
   Ada.Text_IO.Put_Line ("release preflight");

   for Current of Steps loop
      Run_Preflight_Step (Current);
   end loop;

   Ada.Text_IO.Put_Line ("==> check examples");
   Ada.Text_IO.Put_Line ("$ tools/bin/check_examples");
   Status := Run_Check_Examples;
   if Status /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: release preflight failed during check examples with status" &
         Integer'Image (Status));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Text_IO.Put_Line ("release preflight passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Check_Release_Ready;
