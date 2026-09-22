with Ada.Directories;
with GNAT.OS_Lib;

with Version.Platform;
with Project_Tools.Files;
with Project_Tools.Test_Fixtures;
with Version.Files;

--  Thin adapter over the shared project_tools test-fixture helpers, keeping the
--  Version.Test_Support API the test suites already use. The fixture logic
--  lives once in Project_Tools.Test_Fixtures / Project_Tools.Files.
package body Version.Test_Support is

   --  Forward slashes throughout: every fixture interpolates this root into
   --  a shell command, and on Windows the native spelling arrives as
   --  C:\Users\... whose backslashes sh reads as escapes -- the path came out
   --  as C:UsersRUNNER~1AppData... and nothing could be written to it. Windows
   --  itself accepts either separator.
   function Fresh_Temp_Dir (Name : String) return String is
      --  Canonical first: on Windows %TEMP% is the 8.3 short spelling, while
      --  git and the CLI print the long one, so a fixture path built from it
      --  never matched the paths in the output it was compared against.
      Dir : String :=
        Version.Platform.Canonical_Path
          (Project_Tools.Test_Fixtures.Fresh_Temp_Dir (Name));
   begin
      for C of Dir loop
         if C = '\' then
            C := '/';
         end if;
      end loop;
      return Dir;
   end Fresh_Temp_Dir;

   procedure Cleanup (Path : String) is
   begin
      Project_Tools.Test_Fixtures.Cleanup (Path);
   end Cleanup;

   procedure Make_Directory (Path : String) is
   begin
      Project_Tools.Test_Fixtures.Make_Directory (Path);
   end Make_Directory;

   procedure Write_Text_File (Path : String; Content : String) is
   begin
      --  Byte for byte: a fixture writes the content it means, and a host
      --  that translates would otherwise turn `#!/bin/sh` into `#!/bin/sh\r`
      --  -- an interpreter no shell can find -- and a `.gitignore` or a
      --  patch into something git never wrote.
      Version.Files.Write_Binary_File (Path, Content);
   end Write_Text_File;

   function Read_Text_File (Path : String) return String is
   begin
      return Project_Tools.Test_Fixtures.Read_Text_File (Path);
   end Read_Text_File;

   function Join (Left : String; Right : String) return String is
   begin
      return Project_Tools.Files.Join (Left, Right);
   end Join;


   function Shell_Program return String is
      use type GNAT.OS_Lib.String_Access;
      Found : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("sh");
   begin
      if Found = null then
         return "/bin/sh";
      end if;
      declare
         Path : constant String := Found.all;
      begin
         GNAT.OS_Lib.Free (Found);
         return Path;
      end;
   end Shell_Program;


   function CLI_Command (Root : String) return String is
      Exe   : constant String := Join (Root, "bin/main.exe");
      Built : constant String :=
        (if Ada.Directories.Exists (Exe) then Exe else Join (Root, "bin/main"));
      Word  : String := Built;
   begin
      for C of Word loop
         if C = '\' then
            C := '/';
         end if;
      end loop;
      return '"' & Word & '"';
   end CLI_Command;

end Version.Test_Support;
