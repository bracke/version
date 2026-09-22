with Ada.Directories;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Version.Test_Support;

package body Version.Git_Fixtures is

   --  A failing fixture on a host one cannot reach explains nothing: the
   --  common shape is `test "$(tool ...)" = "$(git ...)"`, which prints
   --  nothing at all when the two differ.  Capture every fixture's combined
   --  output, and on failure print its tail and then the tail of a re-run
   --  under the shell's xtrace -- the trace carries each command *after*
   --  expansion, so both sides of that comparison land in the log verbatim.
   --  The trace is a re-run rather than the run itself because xtrace goes
   --  to the shell's standard error, which the fixtures redirect into the
   --  very files they compare.
   Trace_Dir : constant String :=
     Version.Test_Support.Fresh_Temp_Dir ("fixture_trace");

   Output_Log : constant String :=
     Version.Test_Support.Join (Trace_Dir, "out.log");

   Trace_Log : constant String :=
     Version.Test_Support.Join (Trace_Dir, "trace.log");

   Tail_Lines : constant := 200;

   --  The last Tail_Lines lines of Path, or "" when it cannot be read.
   function Tail (Path : String) return String;

   function Tail (Path : String) return String is
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      declare
         Text  : constant String :=
           Version.Test_Support.Read_Text_File (Path);
         Seen  : Natural := 0;
         First : Natural := Text'First;
      begin
         for I in reverse Text'Range loop
            if Text (I) = Character'Val (10) then
               Seen := Seen + 1;
               if Seen > Tail_Lines then
                  First := I + 1;
                  exit;
               end if;
            end if;
         end loop;

         return Text (First .. Text'Last);
      end;
   exception
      when others =>
         return "";
   end Tail;

   procedure Run
     (Dir     : String;
      Command : String)
   is
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Status  : Integer;
      Success : Boolean;

      Args : GNAT.OS_Lib.Argument_List :=
        [1 => new String'("-c"),
         2 => new String'(Command)];

      --  A fixture that is itself a script gets its *inner* commands traced;
      --  tracing the one-line `bash <script>` call says nothing.
      Is_Script : constant Boolean :=
        Command'Length > 5
        and then Command (Command'First .. Command'First + 4) = "bash ";

      Traced : constant String :=
        (if Is_Script
         then "bash -x " & Command (Command'First + 5 .. Command'Last)
         else Command);

      Trace_Args : GNAT.OS_Lib.Argument_List :=
        [1 => new String'("-x"),
         2 => new String'("-c"),
         3 => new String'(Traced)];
   begin
      Ada.Directories.Set_Directory (Dir);

      GNAT.OS_Lib.Spawn
        (Program_Name => Version.Test_Support.Shell_Program,
         Args         => Args,
         Output_File  => Output_Log,
         Success      => Success,
         Return_Code  => Status,
         Err_To_Out   => True);

      if not Success or else Status /= 0 then
         declare
            Retried : Boolean;
            Ignored : Integer;
         begin
            GNAT.OS_Lib.Spawn
              (Program_Name => Version.Test_Support.Shell_Program,
               Args         => Trace_Args,
               Output_File  => Trace_Log,
               Success      => Retried,
               Return_Code  => Ignored,
               Err_To_Out   => True);
         end;
      end if;

      Ada.Directories.Set_Directory (Old_Dir);

      for A of Args loop
         GNAT.OS_Lib.Free (A);
      end loop;

      for A of Trace_Args loop
         GNAT.OS_Lib.Free (A);
      end loop;

      if not Success or else Status /= 0 then
         --  The exception message alone truncates; put the command, what it
         --  printed and the expanded trace where the test log carries them.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "fixture command failed (status" & Integer'Image (Status)
            & ") in " & Dir & ": " & Command);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "--- fixture output ---");
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Tail (Output_Log));
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "--- fixture trace ---");
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Tail (Trace_Log));
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "--- end fixture trace ---");
         raise Program_Error with
           "command failed: " & Command;
      end if;

   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;

         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;

         for A of Trace_Args loop
            GNAT.OS_Lib.Free (A);
         end loop;

         raise;
   end Run;

   procedure Init_Repo_With_One_Commit
     (Root : String)
   is
   begin
      Run (Root, "git init");
      Run (Root, "git config user.email test@example.com");
      Run (Root, "git config user.name Test");
      Run (Root, "git config gc.auto 0");

      Version.Test_Support.Write_Text_File
        (Version.Test_Support.Join (Root, "a.txt"),
         "hello" & Character'Val (10));

      Run (Root, "git add a.txt");
      Run (Root, "git commit -m initial");
   end Init_Repo_With_One_Commit;

   procedure Init_Repo_With_Similar_Files
   (Root : String)
   is
   begin
      Run (Root, "git init");
      Run (Root, "git config user.email test@example.com");
      Run (Root, "git config user.name Test");
      Run (Root, "git config gc.auto 0");

      Version.Test_Support.Write_Text_File
      (Version.Test_Support.Join (Root, "a.txt"),
         "line 1" & Character'Val (10)
         & "line 2" & Character'Val (10)
         & "line 3" & Character'Val (10)
         & "line 4" & Character'Val (10));

      Version.Test_Support.Write_Text_File
      (Version.Test_Support.Join (Root, "b.txt"),
         "line 1" & Character'Val (10)
         & "line 2 changed" & Character'Val (10)
         & "line 3" & Character'Val (10)
         & "line 4" & Character'Val (10));

      Version.Test_Support.Write_Text_File
      (Version.Test_Support.Join (Root, "c.txt"),
         "line 1" & Character'Val (10)
         & "line 2 changed again" & Character'Val (10)
         & "line 3" & Character'Val (10)
         & "line 4" & Character'Val (10));

      Run (Root, "git add a.txt b.txt c.txt");
      Run (Root, "git commit -m similar-files");
   end Init_Repo_With_Similar_Files;

end Version.Git_Fixtures;