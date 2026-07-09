with Ada.Strings.Unbounded;

with Tool_Support;

package body Tool_Doc_Guards is
   use Ada.Strings.Unbounded;

   Stale_Tools : constant array (Positive range <>) of Unbounded_String :=
     [To_Unbounded_String ("tools/check_examples.sh"),
      To_Unbounded_String ("tools/check_platform_ci_evidence.sh"),
      To_Unbounded_String ("tools/check_release_consistency.sh"),
      To_Unbounded_String ("tools/check_release_package.sh"),
      To_Unbounded_String ("tools/check_release_package_selftest.sh"),
      To_Unbounded_String ("tools/check_test_scope_completeness.sh"),
      To_Unbounded_String ("tools/summarize_release_evidence.sh")];

   Checked_Files : constant array (Positive range <>) of Unbounded_String :=
     [To_Unbounded_String ("README.md"),
      To_Unbounded_String ("CHANGELOG.md"),
      To_Unbounded_String ("docs/CHANGELOG.md"),
      To_Unbounded_String ("docs/CI.md"),
      To_Unbounded_String ("docs/PACKAGING.md"),
      To_Unbounded_String ("docs/RELEASE_CHECKLIST.md"),
      To_Unbounded_String ("docs/RELEASE_NOTES.md"),
      To_Unbounded_String ("docs/TESTING.md")];

   function Message (Path, Stale_Name : String) return String is
   begin
      return Path & " contains stale shell tool reference: " & Stale_Name;
   end Message;

   procedure Check_No_Stale_Tool_Script_References
     (Item : in out Reporter'Class)
   is
   begin
      for Tool of Stale_Tools loop
         declare
            Stale_Name : constant String := To_String (Tool);
         begin
            for File of Checked_Files loop
               declare
                  Path : constant String := To_String (File);
               begin
                  if Tool_Support.Contains (Path, Stale_Name) then
                     Item.Report (Message (Path, Stale_Name));
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Check_No_Stale_Tool_Script_References;

   type Fail_Fast_Reporter is new Reporter with null record;

   overriding procedure Report
     (Item    : in out Fail_Fast_Reporter;
      Message : String)
   is
      pragma Unreferenced (Item);
   begin
      Tool_Support.Fail (Message);
   end Report;

   procedure Require_No_Stale_Tool_Script_References is
      Fail_Fast : Fail_Fast_Reporter;
   begin
      Check_No_Stale_Tool_Script_References (Fail_Fast);
   end Require_No_Stale_Tool_Script_References;
end Tool_Doc_Guards;
