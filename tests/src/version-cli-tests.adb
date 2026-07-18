with Ada.Characters.Latin_1;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Containers; use Ada.Containers;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit.Assertions;
with AUnit.Test_Cases;

with GNAT.OS_Lib;

with Version.Availability;
with Version.Archive;
with Version.Branch;
with Version.CLI.Help;
with Version.CLI.Arguments;
with Version.CLI.Progress;
with Version.Git_Fixtures;
with Version.Init;
with Version.Objects;
with Version.Repository;
with Version.Test_Support;
with Version.Write;
with Version.Doctor;
with Version.Remotes;
with Version.Pathspec;
with Version.Rebase;
with Version.Rebase_State;
with Version.Refs;
with Version.Stash;
with Version.Stash_Test_Support;
with Version.Status;
with Version.Unsupported;

package body Version.CLI.Tests is

   use AUnit.Assertions;
   use AUnit.Test_Cases.Registration;

   Version_Bin : constant String := "/home/bent/Projekte/Ada/version/bin/main";

   function Join (Left, Right : String) return String renames Version.Test_Support.Join;

   procedure Write_File (Root, Name, Content : String) is
   begin
      Version.Test_Support.Write_Text_File (Join (Root, Name), Content);
   end Write_File;

   function File_Text (Root, Name : String) return String is
   begin
      return Version.Test_Support.Read_Text_File (Join (Root, Name));
   end File_Text;

   procedure Configure_User (Root : String) is
   begin
      Version.Git_Fixtures.Run
        (Root, "git config user.email test@example.com");
      Version.Git_Fixtures.Run (Root, "git config user.name Test");
      Version.Git_Fixtures.Run (Root, "git config gc.auto 0");
   end Configure_User;

   procedure Commit_File (Root, Name, Content, Message : String) is
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, Name, Content);
      Version.Git_Fixtures.Run (Root, "git add " & Name);
      Version.Write.Save (Message);
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end Commit_File;

   function Shell_Quote (Text : String) return String is
      Result : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("'");
   begin
      for C of Text loop
         if C = ''' then
            Ada.Strings.Unbounded.Append (Result, "'\''");
         else
            Ada.Strings.Unbounded.Append (Result, C);
         end if;
      end loop;
      Ada.Strings.Unbounded.Append (Result, "'");
      return Ada.Strings.Unbounded.To_String (Result);
   end Shell_Quote;

   function Run_CLI (Root, Command : String) return String is
      Output : constant String := Root & ".cli.out";
   begin
      Version.Git_Fixtures.Run
        (Root, Version_Bin & " " & Command & " > " & Shell_Quote (Output) & " 2>&1");
      return Version.Test_Support.Read_Text_File (Output);
   end Run_CLI;

   procedure Run_CLI_Capture
     (Root    : String;
      Command : String;
      Output  : out Ada.Strings.Unbounded.Unbounded_String;
      Status  : out Integer)
   is
      Output_Path : constant String := Root & ".cli.out";
      Old_Dir     : constant String := Ada.Directories.Current_Directory;
      Args        : GNAT.OS_Lib.Argument_List :=
        [1 => new String'("-c"),
         2 => new String'
           (Version_Bin & " " & Command & " > " & Shell_Quote (Output_Path) & " 2>&1")];
   begin
      Ada.Directories.Set_Directory (Root);
      Status := GNAT.OS_Lib.Spawn (Program_Name => "/bin/sh", Args => Args);
      Ada.Directories.Set_Directory (Old_Dir);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));
      Output := Ada.Strings.Unbounded.To_Unbounded_String
        (Version.Test_Support.Read_Text_File (Output_Path));
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         GNAT.OS_Lib.Free (Args (1));
         GNAT.OS_Lib.Free (Args (2));
         raise;
   end Run_CLI_Capture;

   function Stash_Ref_Path (Root : String) return String
     renames Version.Stash_Test_Support.Stash_Ref_Path;
   function Stash_Log_Path (Root : String) return String
     renames Version.Stash_Test_Support.Stash_Log_Path;

   procedure Help_Knows_Stable_Command_Surface
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Version.CLI.Help.Known_Command ("init"), "init help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("stage"), "stage help must exist");
      Assert (Version.CLI.Help.Known_Command ("save"), "save help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("check-ignore"),
         "check-ignore help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("branch"), "branch help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("merge"), "merge help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("remote"), "remote help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("fetch"), "fetch help must exist");
      Assert (Version.CLI.Help.Known_Command ("push"), "push help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("clone"), "clone help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("restore"),
         "restore help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("checkout"),
         "checkout help must exist");
      Assert (Version.CLI.Help.Known_Command ("tag"), "tag help must exist");
      Assert (Version.CLI.Help.Known_Command ("gc"), "gc help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("doctor"), "doctor help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("config"), "config help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("stash"), "stash help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("sparse"), "sparse help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("submodule"),
         "submodule help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("pack-refs"),
         "pack-refs help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("archive"),
         "archive help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("completion"),
         "completion help must exist");
      Assert
        (Version.CLI.Help.Known_Command ("man"),
         "man help must exist");
      Assert
        (not Version.CLI.Help.Known_Command ("frobnicate"),
         "unknown command must not be documented as known");
   end Help_Knows_Stable_Command_Surface;

   procedure Argument_Helper_Stops_Options_At_Double_Dash
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : Version.CLI.Arguments.Argument_List :=
        Version.CLI.Arguments.Empty;
   begin
      Version.CLI.Arguments.Append (Args, "--quiet");
      Version.CLI.Arguments.Append (Args, "checkout");
      Version.CLI.Arguments.Append (Args, "HEAD");
      Version.CLI.Arguments.Append (Args, "--");
      Version.CLI.Arguments.Append (Args, "--literal-file-name");

      Assert
        (Version.CLI.Arguments.Count (Args) = 5,
         "argument helper must preserve every argument");
      Assert
        (Version.CLI.Arguments.Has_Option (Args, "--quiet"),
         "option before -- must be visible");
      Assert
        (not Version.CLI.Arguments.Has_Option (Args, "--literal-file-name"),
         "path-like arguments after -- must not be parsed as options");
      Assert
        (Version.CLI.Arguments.Double_Dash_Index (Args) = 4,
         "argument helper must expose -- boundary");
      Assert
        (Version.CLI.Arguments.Positional (Args, 5) = "--literal-file-name",
         "argument helper must preserve positional text after --");
   end Argument_Helper_Stops_Options_At_Double_Dash;

   procedure CLI_Progress_Sink_Is_Available
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Sink : Version.CLI.Progress.Stderr_Sink;
      pragma Unreferenced (Sink);
   begin
      Assert (True, "CLI progress sink must be instantiable");
   end CLI_Progress_Sink_Is_Available;

   procedure Version_String_Is_Centralized
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      declare
         Actual : constant Ada.Strings.Unbounded.Unbounded_String :=
           Ada.Strings.Unbounded.To_Unbounded_String (Version.Version_String);
      begin
         Assert
           (Ada.Strings.Unbounded.To_String (Actual) = "0.1.0-dev",
            "version --version must have a central stable value");
      end;
   end Version_String_Is_Centralized;

   procedure CLI_Help_And_Version_Affordances_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Is_Help_Option ("--help"),
         "--help must remain a global help option");
      Assert
        (Version.CLI.Is_Help_Option ("-h"),
         "-h must remain a global help option");
      Assert
        (not Version.CLI.Is_Help_Option ("help"),
         "help command must not be parsed as a help option");

      Assert
        (Version.CLI.Is_Command_Help_Request ("stage", "--help", 2),
         "version stage --help must be recognized as command help");
      Assert
        (Version.CLI.Is_Command_Help_Request ("stage", "-h", 2),
         "version stage -h must be recognized as command help");
      Assert
        (Version.CLI.Is_Command_Help_Request ("branch", "--help", 2),
         "version branch --help must be recognized as command help");
      Assert
        (not Version.CLI.Is_Command_Help_Request ("frobnicate", "--help", 2),
         "unknown commands with --help must remain usage errors");
      Assert
        (not Version.CLI.Is_Command_Help_Request ("stage", "--help", 3),
         "command help aliases must not hide extra arguments");

      Assert
        (Version.CLI.Version_Output_Text = "version " & Version.Version_String,
         "version --version output must be centralized and stable");
   end CLI_Help_And_Version_Affordances_Are_Frozen;

   procedure CLI_Error_Text_Preserves_User_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      begin
         raise Ada.IO_Exceptions.Data_Error
           with "unsupported repository format";
      exception
         when E : Ada.IO_Exceptions.Data_Error =>
            Assert
              (Version.CLI.User_Error_Text (E)
               = "unsupported repository format",
               "expected user errors must preserve the actionable message");
      end;
   end CLI_Error_Text_Preserves_User_Message;

   procedure CLI_Error_Text_Hides_Internal_Exception_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      begin
         raise Constraint_Error;
      exception
         when E : Constraint_Error =>
            declare
               Text : constant String := Version.CLI.User_Error_Text (E);
            begin
               Assert
                 (Ada.Strings.Fixed.Index (Text, "CONSTRAINT_ERROR") = 0
                  and then Ada.Strings.Fixed.Index (Text, "raised") = 0,
                  "internal exceptions must not leak Ada exception names");
               Assert
                 (Text = "internal command error",
                  "internal exceptions must normalize to a stable CLI error");
            end;
      end;
   end CLI_Error_Text_Hides_Internal_Exception_Names;

   procedure CLI_Exit_Statuses_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Usage_Exit_Status = Ada.Command_Line.Exit_Status (2),
         "usage and argument errors must keep exit status 2");
      Assert
        (Version.CLI.Command_Failure_Exit_Status
         = Ada.Command_Line.Exit_Status (1),
         "command failures must keep exit status 1");
   end CLI_Exit_Statuses_Are_Frozen;

   procedure CLI_Error_Text_Uses_Stable_Prefix_Payload
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      begin
         raise Ada.IO_Exceptions.Data_Error with "bad ref name";
      exception
         when E : Ada.IO_Exceptions.Data_Error =>
            Assert
              ("error: " & Version.CLI.User_Error_Text (E)
               = "error: bad ref name",
               "CLI error output payload must remain stable under the error prefix");
      end;
   end CLI_Error_Text_Uses_Stable_Prefix_Payload;

   procedure CLI_Error_Text_Preserves_Working_Tree_Read_Race
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      begin
         raise Ada.IO_Exceptions.Data_Error
           with "working tree file changed while reading: file.txt";
      exception
         when E : Ada.IO_Exceptions.Data_Error =>
            Assert
              (Version.CLI.User_Error_Text (E)
               = "working tree file changed while reading: file.txt",
               "working tree read races must remain actionable user errors");
      end;
   end CLI_Error_Text_Preserves_Working_Tree_Read_Race;

   procedure Assert_Contains
     (Text : String; Pattern : String; Context : String) is
   begin
      if Pattern'Length = 0 then
         return;
      end if;

      Assert
        (Ada.Strings.Fixed.Index (Text, Pattern) /= 0,
         Context & " must contain '" & Pattern & "'");
   end Assert_Contains;

   procedure Assert_Not_Contains
     (Text : String; Pattern : String; Context : String) is
   begin
      Assert
        (Ada.Strings.Fixed.Index (Text, Pattern) = 0,
         Context & " must not contain '" & Pattern & "'");
   end Assert_Not_Contains;

   procedure CLI_Help_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String := Version.CLI.Help.Top_Level_Text;
   begin
      Assert_Contains
        (Text,
         "Usage:"
         & Character'Val (10)
         & "  version [--quiet] <command> [arguments]",
         "top-level help");
      Assert_Contains
        (Text,
         "Repository:"
         & Character'Val (10)
         & "  init              Create a Git-compatible repository",
         "top-level help repository section");
      Assert_Contains
        (Text,
         "Changes:"
         & Character'Val (10)
         & "  stage             Add paths to the index",
         "top-level help changes section");
      Assert_Contains
        (Text,
         "Branches:"
         & Character'Val (10)
         & "  branch list       List branches (--verbose/--contains/--merged/no-merged)"
         & Character'Val (10)
         & "  branch current    Print the current branch name"
         & Character'Val (10)
         & "  branch exists     Test whether a branch exists"
         & Character'Val (10)
         & "  branch resolve    Print the branch tip object id"
         & Character'Val (10)
         & "  branch upstream   Print a branch upstream"
         & Character'Val (10)
         & "  branch contains   List branches containing a commit"
         & Character'Val (10)
         & "  branch merged     List branches merged into a branch"
         & Character'Val (10)
         & "  branch unmerged   List branches not merged into a branch",
         "top-level help branches section");
      Assert_Contains
        (Text,
         "  merge             Merge branches into HEAD",
         "top-level help merge command");
      Assert_Contains
        (Text, "  version <command> --help", "top-level help command alias");
      Assert_Contains
        (Text, "  version --help | -h", "top-level help short alias");
      Assert_Contains
        (Text,
         "  version doctor [--release]",
         "top-level help doctor affordance");
      Assert_Contains
        (Text,
         "Use 'version help <command>' or 'version <command> --help' for command-specific help.",
         "top-level help footer");
   end CLI_Help_Output_Is_Frozen;

   procedure CLI_Man_Page_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String := Version.CLI.Help.Man_Page_Text;
   begin
      Assert_Contains
        (Version.CLI.Help.Top_Level_Text,
         "version man",
         "top-level help documents man command");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("man"),
         "version man",
         "man command help");
      Assert_Contains (Text, ".TH VERSION 1", "man page heading");
      Assert_Contains (Text, ".SH NAME", "man page name section");
      Assert_Contains (Text, ".SH SYNOPSIS", "man page synopsis section");
      Assert_Contains
        (Text, "version completion bash", "man page completion reference");
      Assert_Contains
        (Text, "version save [--no-verify] MESSAGE", "man page save no-verify reference");
      Assert_Contains
        (Text, "version push [--no-verify] [--force] REMOTE BRANCH", "man page push no-verify reference");
      Assert_Contains
        (Text, "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]", "man page fetch depth reference");
      Assert_Contains
        (Text, "version clone [--depth N] SOURCE TARGET", "man page clone depth reference");
      Assert_Contains
        (Text, "0 success; 1 expected operation or validation failure; 2 usage error",
         "man page exit status");
   end CLI_Man_Page_Output_Is_Frozen;

   procedure CLI_Completion_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String := Version.CLI.Help.Completion_Bash_Text;
   begin
      Assert_Contains
        (Version.CLI.Help.Top_Level_Text,
         "version completion bash",
         "top-level help documents completion command");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("completion"),
         "version completion bash",
         "completion command help");
      Assert_Contains
        (Text, "# bash completion for version", "completion header");
      Assert_Contains
        (Text, "_version_completion()", "completion function name");
      Assert_Contains
        (Text, "complete -F _version_completion version",
         "completion registration");
      Assert_Contains
        (Text,
         "init clone verify repack prune gc pack-refs config stage remove save",
         "top-level completion commands");
      Assert_Contains
        (Text,
         "status check-ignore diff log show restore checkout branch merge rebase cherry-pick",
         "top-level completion commands");
      Assert_Contains
        (Text,
         "revert stash sparse sparse-checkout worktree submodule archive "
         & "tag remote fetch",
         "top-level completion commands");
      Assert_Contains
        (Text,
         "push doctor completion man history",
         "top-level completion commands");
      Assert_Contains
        (Text, "branch) COMPREPLY", "branch completion case");
      Assert_Contains
        (Text, "merge) COMPREPLY", "merge completion case");
      Assert_Contains
        (Text, "--continue --abort --quit", "merge completion options");
      Assert_Contains
        (Text, "--ff --ff-only --no-ff", "merge completion ff options");
      Assert_Contains
        (Text,
         "list current exists resolve upstream contains merged unmerged create",
         "branch completion subcommands");
      Assert_Contains
        (Text,
         "switch rename delete integrate finalize set-upstream unset-upstream",
         "branch completion subcommands");
      Assert_Contains
        (Text,
         "ahead-behind update --verbose --contains --merged --no-merged --force",
         "branch completion subcommands");
      Assert_Contains
        (Text, "tag) COMPREPLY", "tag completion case");
      Assert_Contains
        (Text,
         "create delete remove rename list exists resolve peel show",
         "tag completion subcommands");
      Assert_Contains
        (Text,
         "--points-at --contains -a -m",
         "tag completion options");
      Assert_Contains
        (Text, "remote) COMPREPLY", "remote completion case");
      Assert_Contains
        (Text,
         "add list get-url exists set-url rename prune delete remove --dry-run",
         "remote completion subcommands");
      Assert_Contains
        (Text, "save) COMPREPLY", "save completion case");
      Assert_Contains
        (Text, "--no-verify --amend -m", "save completion options");
      Assert_Contains
        (Text, "push) COMPREPLY", "push completion case");
      Assert_Contains
        (Text, "--no-verify --tags", "push completion options");
      Assert_Contains
        (Text, "fetch) COMPREPLY", "fetch completion case");
      Assert_Contains
        (Text, "check-ignore", "check-ignore completion command");
      Assert_Contains
        (Text, "check-ignore) COMPREPLY", "check-ignore completion case");
      Assert_Contains
        (Text,
         "--quiet --no-quiet",
         "check-ignore quiet completion options");
      Assert_Contains
        (Text,
         "--verbose --no-verbose",
         "check-ignore verbose completion options");
      Assert_Contains
        (Text,
         "--stdin --no-stdin",
         "check-ignore stdin completion options");
      Assert_Contains
        (Text,
         "--non-matching --no-non-matching",
         "check-ignore non-matching completion options");
      Assert_Contains
        (Text, "clone) COMPREPLY", "clone completion case");
      Assert_Contains
        (Text, "--depth --recursive", "clone completion options");
      Assert_Contains
        (Text, "completion) COMPREPLY", "completion command case");
      Assert_Contains
        (Text, "--quiet --help -h --version",
         "global completion options");
   end CLI_Completion_Output_Is_Frozen;

   procedure CLI_Command_Help_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Help.Command_Text ("stage")
         = "Usage:"
           & Character'Val (10)
           & "  version stage [-f|--force] [--] PATHSPEC..."
           & Character'Val (10)
           & Character'Val (10)
           & "Add one or more matching working tree paths to the index."
           & Character'Val (10)
           & "Use -f or --force to stage ignored matches."
           & Character'Val (10),
         "stage command help must be stable");

      Assert_Contains
        (Version.CLI.Help.Command_Text ("save"),
         "  version save --no-verify MESSAGE",
         "save no-verify command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("save"),
         "Use --no-verify to skip blocking commit hooks.",
         "save no-verify command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("restore"),
         "  version restore --source REV --staged [--] PATHSPEC...",
         "restore command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("check-ignore"),
         "  version check-ignore [-q|--quiet] [-v|--verbose] "
         & "[--stdin] [-z] [-n|--non-matching] "
         & "[--index|--no-index] [--] PATH...",
         "check-ignore command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("check-ignore"),
         "use --stdin, -z, --verbose, --non-matching",
         "check-ignore quiet command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch list --verbose",
         "branch verbose list command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch list --contains REV",
         "branch list contains command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch list --merged [BRANCH]",
         "branch list merged command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch list --no-merged [BRANCH]",
         "branch list no-merged command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch current",
         "branch current command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch exists NAME",
         "branch exists command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch resolve NAME",
         "branch resolve command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch upstream [BRANCH]",
         "branch upstream command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch contains REV",
         "branch contains command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch merged [BRANCH]",
         "branch merged command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch unmerged [BRANCH]",
         "branch unmerged command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("branch"),
         "  version branch switch NAME",
         "branch command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("merge"),
         "  version merge [OPTIONS] [TARGET...]",
         "merge command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("merge"),
         "  version merge --continue [--verify|--no-verify]",
         "merge continue command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("merge"),
         "  version merge --abort",
         "merge abort command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("merge"),
         "  version merge --quit",
         "merge quit command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("doctor"),
         "  version doctor --release",
         "doctor command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag create NAME REV",
         "tag explicit create command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag create -a NAME -m MESSAGE",
         "tag annotated create command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag create -a NAME REV -m MESSAGE",
         "tag annotated explicit create command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag list --points-at REV",
         "tag points-at command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag list --contains REV",
         "tag contains command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag rename OLD NEW",
         "tag rename command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag exists NAME",
         "tag exists command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag resolve NAME",
         "tag resolve command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag peel NAME",
         "tag peel command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("tag"),
         "  version tag show NAME",
         "tag show command help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("log"),
         "",
         "log oneline command help");
   end CLI_Command_Help_Output_Is_Frozen;

   procedure CLI_Usage_And_Unknown_Output_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Unknown_Command_Output_Text ("frobnicate")
         = "error: unknown command: frobnicate",
         "unknown command diagnostic must remain stable");
      Assert
        (Version.CLI.Expected_Output_Text ("version stage [-f|--force] [--] PATHSPEC...")
         = "error: expected: version stage [-f|--force] [--] PATHSPEC...",
         "missing operand diagnostic must remain stable");
   end CLI_Usage_And_Unknown_Output_Are_Frozen;

   procedure CLI_Status_Output_Fragments_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      --  The long format is git's, so these seams freeze git's wording:
      --  a tab, the label padded to column 12 (17 when unmerged), the path.
      Assert
        (Version.Status.Clean_Status_Line
         = "nothing to commit, working tree clean",
         "clean status line must remain stable");
      Assert
        (Version.Status.Long_Status_Line
           (Version.Status.New_File, "src/main.adb")
         = Ada.Characters.Latin_1.HT & "new file:   src/main.adb",
         "new-file status line must remain stable");
      Assert
        (Version.Status.Long_Status_Line
           (Version.Status.Modified_File, "src/main.adb")
         = Ada.Characters.Latin_1.HT & "modified:   src/main.adb",
         "modified status line must remain stable");
      Assert
        (Version.Status.Long_Status_Line
           (Version.Status.Deleted_File, "src/main.adb")
         = Ada.Characters.Latin_1.HT & "deleted:    src/main.adb",
         "deleted status line must remain stable");
      Assert
        (Version.Status.Long_Status_Line
           (Version.Status.Renamed_File, "old.adb -> new.adb")
         = Ada.Characters.Latin_1.HT & "renamed:    old.adb -> new.adb",
         "renamed status line must remain stable");
      Assert
        (Version.Status.Long_Status_Line
           (Version.Status.Both_Added_File, "c.txt", Unmerged => True)
         = Ada.Characters.Latin_1.HT & "both added:      c.txt",
         "unmerged status line must remain stable");
   end CLI_Status_Output_Fragments_Are_Frozen;

   procedure CLI_Status_Porcelain_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : Version.Status.Status_Result;
   begin
      Assert
        (Version.Status.Porcelain_Kind_Code (Version.Status.New_File) = "A",
         "porcelain added code must remain stable");
      Assert
        (Version.Status.Porcelain_Kind_Code (Version.Status.Modified_File)
         = "M",
         "porcelain modified code must remain stable");
      Assert
        (Version.Status.Porcelain_Kind_Code (Version.Status.Deleted_File)
         = "D",
         "porcelain deleted code must remain stable");
      Assert
        (Version.Status.Porcelain_Kind_Code (Version.Status.Ignored_File)
         = "!",
         "porcelain ignored code must remain stable");
      Assert
        (Version.Status.Porcelain_Status_Text (Result) = "",
         "clean porcelain status must remain empty");

      Result.Staged.Append
        (Version.Status.File_Change'
           (Path => Ada.Strings.Unbounded.To_Unbounded_String ("src/main.adb"),
            Kind => Version.Status.New_File,
            Old_Path => Ada.Strings.Unbounded.Null_Unbounded_String));
      Result.Changes.Append
        (Version.Status.File_Change'
           (Path => Ada.Strings.Unbounded.To_Unbounded_String ("src/lib.adb"),
            Kind => Version.Status.Modified_File,
            Old_Path => Ada.Strings.Unbounded.Null_Unbounded_String));
      Result.Untracked.Append
        (Version.Status.File_Change'
           (Path => Ada.Strings.Unbounded.To_Unbounded_String ("notes.txt"),
            Kind => Version.Status.New_File,
            Old_Path => Ada.Strings.Unbounded.Null_Unbounded_String));
      Result.Ignored.Append
        (Version.Status.File_Change'
           (Path => Ada.Strings.Unbounded.To_Unbounded_String ("obj/main.o"),
            Kind => Version.Status.Ignored_File,
            Old_Path => Ada.Strings.Unbounded.Null_Unbounded_String));

      Assert
        (Version.Status.Porcelain_Status_Text (Result)
         = " M src/lib.adb"
           & Character'Val (10)
           & "A  src/main.adb"
           & Character'Val (10)
           & "?? notes.txt"
           & Character'Val (10),
         "porcelain status must match git's XY format (tracked sorted, then "
         & "untracked)");
      Assert
        (Version.Status.Short_Status_Text (Result)
         = Version.Status.Porcelain_Status_Text (Result),
         "short status alias must remain byte-identical to porcelain status");
      Assert
        (Version.Status.Porcelain_Status_Text
           (Result, Include_Ignored => True)
         = Version.Status.Porcelain_Status_Text (Result)
           & "!! obj/main.o" & Character'Val (10),
         "porcelain status ignored entries must remain stable when requested");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("status"),
         "version status [--porcelain[=v1]|--short|--long] [--branch]"
         & " [--ignored[=MODE]] [--untracked-files[=MODE]]",
         "status help porcelain, short, branch, and ignored form");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("status"),
         "--short alias",
         "status help documents short alias");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("status"),
         "--branch",
         "status help documents branch summary mode");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("status"),
         "--ignored",
         "status help documents ignored mode");
   end CLI_Status_Porcelain_Output_Is_Frozen;

   procedure CLI_Command_Failure_Output_Is_Frozen_And_Redacted
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Error_Output_Text ("branch does not exist: missing")
         = "error: branch does not exist: missing",
         "branch switch failure diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Unsupported.Object_Format ("sha512"))
         = "error: " & Version.Unsupported.Object_Format ("sha512"),
         "unsupported repository format diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("corrupt loose object")
         = "error: corrupt loose object",
         "corruption diagnostic prefix must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("transport failed")
         = "error: transport failed",
         "transport diagnostic prefix must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("post-commit hook failed")
         = "error: post-commit hook failed",
         "hook diagnostic prefix must remain stable");

      Assert_Not_Contains
        (Version.CLI.Error_Output_Text ("internal command error"),
         "/tmp/version_test_",
         "normalized internal CLI error");
      Assert_Not_Contains
        (Version.CLI.Error_Output_Text ("internal command error"),
         "raised CONSTRAINT_ERROR",
         "normalized internal CLI error");
   end CLI_Command_Failure_Output_Is_Frozen_And_Redacted;

   procedure CLI_Remote_And_Advanced_Command_Help_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Contains
        (Version.CLI.Help.Command_Text ("clone"),
         "  version clone SOURCE TARGET",
         "clone help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("clone"),
         "  version clone --depth N SOURCE TARGET",
         "clone help depth form");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("clone"),
         "  version clone --recursive SOURCE TARGET",
         "clone help recursive form");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("fetch"),
         "  version fetch REMOTE",
         "fetch help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("fetch"),
         "  version fetch --depth N REMOTE",
         "fetch help depth form");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("push"),
         "  version push REMOTE BRANCH",
         "push help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("push"),
         "  version push --no-verify REMOTE BRANCH",
         "push no-verify help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("push"),
         "  version push --tags REMOTE",
         "push tags help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("push"),
         "  version push --no-verify --tags [REMOTE]",
         "push no-verify tags help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("archive"),
         "  version archive REV --format tar|zip",
         "archive help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("submodule"),
         "  version submodule update [--recursive]",
         "submodule help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("worktree"),
         "  version worktree add --detach PATH REV",
         "worktree help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("worktree"),
         "  version worktree current",
         "worktree current help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("sparse"),
         "  version sparse-checkout set [--cone|--no-cone] DIR...",
         "sparse help");
      Assert_Contains
        (Version.CLI.Help.Command_Text ("sparse-checkout"),
         "  version sparse-checkout status",
         "sparse-checkout status help");
   end CLI_Remote_And_Advanced_Command_Help_Is_Frozen;

   procedure CLI_Remote_And_Feature_Failure_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Error_Output_Text ("clone failed: remote unavailable")
         = "error: clone failed: remote unavailable",
         "clone failure diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           ("fetch failed: malformed upload-pack response")
         = "error: fetch failed: malformed upload-pack response",
         "fetch failure diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("push rejected: non-fast-forward")
         = "error: push rejected: non-fast-forward",
         "push rejection diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.CLI.Unsupported_Archive_Format_Text ("xz"))
         = "error: unsupported archive format: xz (supported formats: tar,"
           & " tar.gz, zip; use --format tar, --format tar.gz, or"
           & " --format zip)",
         "archive unsupported-format diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("invalid submodule path: ../escape")
         = "error: invalid submodule path: ../escape",
         "submodule malformed-config diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           ("branch already checked out in another worktree: main")
         = "error: branch already checked out in another worktree: main",
         "worktree unsafe-branch diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           ("path is outside sparse checkout: deps/lib")
         = "error: path is outside sparse checkout: deps/lib",
         "sparse excluded-path diagnostic must remain stable");
   end CLI_Remote_And_Feature_Failure_Output_Is_Frozen;

   procedure CLI_Merge_Command_Routes_To_Branch_Integration
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Usage   : constant String :=
        "version merge [OPTIONS] [TARGET...] | version merge --continue"
        & " | version merge --abort | version merge --quit";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;
   begin
      Check_Usage_Failure
        ("merge --continue extra",
         "unknown merge --continue option: extra",
         "merge continue unknown option");
      Check_Usage_Failure
        ("merge --definitely-not-supported",
         "unknown merge option: --definitely-not-supported",
         "merge unknown option");

      Check_Usage_Failure
        ("merge -Xsubtree= topic",
         "unsupported merge strategy option: subtree=",
         "merge empty subtree option unsupported");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "base.txt", "base" & Character'Val (10), "base");

      Check_Success
        ("branch create ff-topic",
         "created branch ff-topic",
         "merge fast-forward fixture branch");
      Check_Success
        ("branch switch ff-topic",
         "switched to branch ff-topic",
         "merge fast-forward fixture switch topic");
      Commit_File
        (Root, "ff.txt", "ff" & Character'Val (10), "ff topic");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge fast-forward fixture switch main");
      Check_Success
        ("merge ff-topic",
         "Fast-forward",
         "merge command fast-forward output");
      Version.Git_Fixtures.Run (Root, "test -f ff.txt");
      Check_Success
        ("merge ff-topic",
         "Already up to date.",
         "merge command already-up-to-date output");

      Check_Success
        ("branch create topic",
         "created branch topic",
         "merge command fixture branch");
      Check_Success
        ("branch switch topic",
         "switched to branch topic",
         "merge command fixture switch topic");
      Commit_File
        (Root, "topic.txt", "topic" & Character'Val (10), "topic");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge command fixture switch main");
      Commit_File
        (Root, "main.txt", "main" & Character'Val (10), "main");

      Check_Success
        ("merge --no-ff --verbose --progress --no-progress "
         & "--find-renames=75 -Xdiff-algorithm=histogram "
         & "-Xfind-renames=60 -m cli-merge-message topic",
         "Merge made by the 'ort' strategy.",
         "merge command clean merge accepts progress verbosity options");

      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""cli-merge-message""");
      Version.Git_Fixtures.Run (Root, "test -f topic.txt");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git rev-list --parents -n 1 HEAD | wc -w)"" = ""3""");

      Check_Success
        ("branch create quiet-topic",
         "created branch quiet-topic",
         "merge quiet fixture branch");
      Check_Success
        ("branch switch quiet-topic",
         "switched to branch quiet-topic",
         "merge quiet fixture switch topic");
      Commit_File
        (Root, "quiet-topic.txt", "quiet" & Character'Val (10),
         "quiet topic");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge quiet fixture switch main");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture
           (Root,
            "merge --quiet --stat --no-ff -m quiet-merge quiet-topic",
            Output,
            Status);
         Assert (Status = 0, "quiet merge must succeed");
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Text'Length = 0,
               "merge --quiet must suppress success and stat output");
         end;
      end;
      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""quiet-merge""");
      Version.Git_Fixtures.Run (Root, "test -f quiet-topic.txt");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Merge_Command_Routes_To_Branch_Integration;

   procedure CLI_Merge_Upstream_And_Expanded_Options
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Message_Path : constant String := Root & ".merge-message";

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      procedure Check_Command_Failure
        (Command, Output_Fragment, Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert
           (Status = Integer (Version.CLI.Command_Failure_Exit_Status),
            Context & " must fail as command failure");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Command_Failure;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "base.txt", "base" & Character'Val (10), "base");

      Check_Success
        ("branch create topic",
         "created branch topic",
         "upstream fixture branch");
      Check_Success
        ("branch switch topic",
         "switched to branch topic",
         "upstream fixture switch topic");
      Commit_File
        (Root, "topic.txt", "topic" & Character'Val (10), "topic subject");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "upstream fixture switch main");

      Version.Git_Fixtures.Run (Root, "git update-ref refs/remotes/origin/topic topic");
      Version.Git_Fixtures.Run (Root, "git config branch.main.remote origin");
      Version.Git_Fixtures.Run
        (Root, "git config branch.main.merge refs/heads/topic");
      Version.Test_Support.Write_Text_File
        (Message_Path, "  cli upstream merge  " & Character'Val (10));

      declare
         Before : constant String := Version.Refs.Current_Commit_Id (Version.Repository.Open);
      begin
         Check_Command_Failure
           ("merge --verify-signatures refs/remotes/origin/topic",
            "target commit signature could not be verified",
            "merge verify-signatures preflight");
         Assert
           (Version.Refs.Current_Commit_Id (Version.Repository.Open) = Before,
            "verify-signatures CLI failure must keep HEAD");
      end;

      Check_Success
        ("merge --no-ff --stat --summary --compact-summary --log=1 "
         & "--signoff --cleanup=strip -F " & Shell_Quote (Message_Path),
         "Merge made by the 'ort' strategy.",
         "merge no-target upstream with expanded options");

      Version.Git_Fixtures.Run
        (Root, "test ""$(git log -1 --format=%s)"" = ""cli upstream merge""");
      Version.Git_Fixtures.Run
        (Root, "git log -1 --format=%B | grep -q 'topic subject'");
      Version.Git_Fixtures.Run
        (Root, "git log -1 --format=%B | grep -q 'Signed-off-by: Test <test@example.com>'");
      Version.Git_Fixtures.Run (Root, "test -f topic.txt");

      Check_Success
        ("branch create stat-topic",
         "created branch stat-topic",
         "config stat fixture branch");
      Check_Success
        ("branch switch stat-topic",
         "switched to branch stat-topic",
         "config stat fixture switch topic");
      Commit_File
        (Root, "stat-topic.txt", "stat" & Character'Val (10),
         "stat subject");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "config stat fixture switch main");

      Version.Git_Fixtures.Run
        (Root, "git update-ref refs/remotes/origin/stat-topic stat-topic");
      Version.Git_Fixtures.Run
        (Root, "git config branch.main.merge refs/heads/stat-topic");
      Version.Git_Fixtures.Run (Root, "git config merge.stat true");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture
           (Root, "merge --no-ff -m config-stat-merge", Output, Status);
         Assert (Status = 0, "merge config stat upstream must succeed");
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert_Contains
              (Text, " stat-topic.txt",
               "merge.stat config prints changed path");
            Assert_Contains
              (Text, " 1 file changed",
               "merge.stat config prints changed count");
            Assert_Contains
              (Text, "Merge made by the 'ort' strategy.",
               "merge.stat config still reports merge strategy");
         end;
      end;
      Version.Git_Fixtures.Run (Root, "test -f stat-topic.txt");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Merge_Upstream_And_Expanded_Options;

   procedure CLI_Merge_No_Commit_Writes_Git_State_And_Continues
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "base.txt", "base" & Character'Val (10), "base");

      Check_Success
        ("branch create topic",
         "created branch topic",
         "no-commit fixture branch");
      Check_Success
        ("branch switch topic",
         "switched to branch topic",
         "no-commit fixture switch topic");
      Commit_File
        (Root, "topic.txt", "topic" & Character'Val (10), "topic");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "no-commit fixture switch main");
      Commit_File
        (Root, "main.txt", "main" & Character'Val (10), "main");

      Check_Success
        ("merge --no-commit -m no-commit-message topic",
         "Automatic merge went well; stopped before committing as requested",
         "merge no-commit");

      Version.Git_Fixtures.Run (Root, "test -f .git/MERGE_HEAD");
      Version.Git_Fixtures.Run
        (Root, "grep -q no-commit-message .git/MERGE_MSG");
      Version.Git_Fixtures.Run (Root, "test -f topic.txt");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git rev-list --parents -n 1 HEAD | wc -w)"" = ""2""");

      Check_Success
        ("merge --continue",
         "continued merge",
         "merge no-commit continue");

      Version.Git_Fixtures.Run (Root, "test ! -e .git/MERGE_HEAD");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git log --format=%s -1)"" = ""no-commit-message""");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git rev-list --parents -n 1 HEAD | wc -w)"" = ""3""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Merge_No_Commit_Writes_Git_State_And_Continues;

   procedure CLI_Merge_Conflict_Writes_Git_State_And_Auto_Merge
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "base" & Character'Val (10), "base");

      Check_Success
        ("branch create topic",
         "created branch topic",
         "merge conflict fixture branch");
      Check_Success
        ("branch switch topic",
         "switched to branch topic",
         "merge conflict fixture switch topic");
      Commit_File (Root, "a.txt", "topic" & Character'Val (10), "topic");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge conflict fixture switch main");
      Commit_File (Root, "a.txt", "main" & Character'Val (10), "main");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "merge topic", Output, Status);
         Assert (Status /= 0, "conflicting merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "Auto-merging a.txt",
            "conflicting merge auto-merging output");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (content): Merge conflict in a.txt",
            "conflicting merge content diagnostic output");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "Automatic merge failed; fix conflicts and then commit the result.",
            "conflicting merge final diagnostic output");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "conflicts recorded",
            "conflicting merge output must not include Version-internal summary");
      end;

      Version.Git_Fixtures.Run (Root, "test -f .git/MERGE_HEAD");
      Version.Git_Fixtures.Run (Root, "test -f .git/AUTO_MERGE");
      Version.Git_Fixtures.Run
        (Root, "test ""$(git cat-file -t $(cat .git/AUTO_MERGE))"" = ""tree""");
      Version.Git_Fixtures.Run
        (Root, "test -n ""$(git ls-files -u -- a.txt)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Merge_Conflict_Writes_Git_State_And_Auto_Merge;

   procedure CLI_Merge_Conflict_Diagnostics_Are_Git_Style
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "base.txt", "base" & Character'Val (10), "base");

      Check_Success
        ("branch create add-topic",
         "created branch add-topic",
         "merge add/add fixture branch");
      Check_Success
        ("branch switch add-topic",
         "switched to branch add-topic",
         "merge add/add fixture switch topic");
      Commit_File
        (Root, "aa.txt", "topic" & Character'Val (10), "topic add");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge add/add fixture switch main");
      Commit_File
        (Root, "aa.txt", "main" & Character'Val (10), "main add");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "merge add-topic", Output, Status);
         Assert (Status /= 0, "add/add merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (add/add): Merge conflict in aa.txt",
            "add/add conflict diagnostic output");
      end;

      Check_Success
        ("merge --abort",
         "aborted merge",
         "merge add/add abort");
      Commit_File (Root, "md.txt", "base" & Character'Val (10), "md base");
      Check_Success
        ("branch create md-topic",
         "created branch md-topic",
         "merge modify/delete fixture branch");
      Check_Success
        ("branch switch md-topic",
         "switched to branch md-topic",
         "merge modify/delete fixture switch topic");
      Commit_File
        (Root, "md.txt", "topic" & Character'Val (10), "topic modify");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge modify/delete fixture switch main");
      Version.Git_Fixtures.Run (Root, "git rm md.txt");
      Version.Write.Save ("main delete");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "merge md-topic", Output, Status);
         Assert (Status /= 0, "modify/delete merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (modify/delete): md.txt deleted in HEAD and modified in md-topic.  Version md-topic of md.txt left in tree.",
            "modify/delete conflict diagnostic output");
      end;

      Check_Success
        ("merge --abort",
         "aborted merge",
         "merge modify/delete abort");
      Commit_File
        (Root, "old.txt", "base" & Character'Val (10), "rename/delete base");
      Check_Success
        ("branch create rd-topic",
         "created branch rd-topic",
         "merge rename/delete fixture branch");
      Check_Success
        ("branch switch rd-topic",
         "switched to branch rd-topic",
         "merge rename/delete fixture switch topic");
      Version.Git_Fixtures.Run (Root, "git mv old.txt new.txt");
      Version.Write.Save ("topic rename");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge rename/delete fixture switch main");
      Version.Git_Fixtures.Run (Root, "git rm old.txt");
      Version.Write.Save ("main delete");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "merge rd-topic", Output, Status);
         Assert (Status /= 0, "rename/delete merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (rename/delete): old.txt renamed to new.txt in rd-topic, but deleted in HEAD.",
            "rename/delete conflict diagnostic output");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "Auto-merging new.txt",
            "rename/delete conflict must not print auto-merging noise");
      end;

      Check_Success
        ("merge --abort",
         "aborted merge",
         "merge rename/delete abort");
      Commit_File
        (Root, "rr-old.txt", "base" & Character'Val (10), "rename/rename base");
      Check_Success
        ("branch create rr-topic",
         "created branch rr-topic",
         "merge rename/rename fixture branch");
      Check_Success
        ("branch switch rr-topic",
         "switched to branch rr-topic",
         "merge rename/rename fixture switch topic");
      Version.Git_Fixtures.Run (Root, "git mv rr-old.txt rr-target.txt");
      Version.Write.Save ("topic rename target");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge rename/rename fixture switch main");
      Version.Git_Fixtures.Run (Root, "git mv rr-old.txt rr-current.txt");
      Version.Write.Save ("main rename current");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "merge rr-topic", Output, Status);
         Assert (Status /= 0, "rename/rename merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (rename/rename): rr-old.txt renamed to rr-current.txt in HEAD and to rr-target.txt in rr-topic.",
            "rename/rename conflict diagnostic output");
      end;

      Check_Success
        ("merge --abort",
         "aborted merge",
         "merge rename/rename abort");
      Version.Git_Fixtures.Run (Root, "mkdir -p dr");
      Write_File (Root, "dr/base.txt", "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add dr/base.txt");
      Version.Write.Save ("directory rename base");
      Check_Success
        ("branch create dr-topic",
         "created branch dr-topic",
         "merge directory rename fixture branch");
      Write_File (Root, "dr/new.txt", "current" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add dr/new.txt");
      Version.Write.Save ("main add under old directory");
      Check_Success
        ("branch switch dr-topic",
         "switched to branch dr-topic",
         "merge directory rename fixture switch topic");
      Version.Git_Fixtures.Run (Root, "mkdir -p dr-renamed");
      Version.Git_Fixtures.Run (Root, "git mv dr/base.txt dr-renamed/base.txt");
      Version.Git_Fixtures.Run (Root, "rmdir dr");
      Version.Write.Save ("topic rename directory");
      Check_Success
        ("branch switch main",
         "switched to branch main",
         "merge directory rename fixture switch main");

      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture
           (Root, "merge -Xdirectory-renames=conflict dr-topic", Output, Status);
         Assert (Status /= 0, "directory rename conflict merge must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "CONFLICT (file location): dr/new.txt added in HEAD inside a directory that was renamed in dr-topic, suggesting it should perhaps be moved to dr-renamed/new.txt.",
            "directory rename file-location diagnostic output");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "Auto-merging dr-renamed/new.txt",
            "directory rename file-location conflict must not print auto-merging noise");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Merge_Conflict_Diagnostics_Are_Git_Style;

   procedure CLI_Branch_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String := "version branch SUBCOMMAND [ARGS]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      --  Bare `branch` now lists branches (like git) rather than being a parse
      --  error; that behaviour is byte-oracled in Plumbing_Matches_Git.
      Check_Usage_Failure
        ("branch frobnicate",
         "unknown branch subcommand: frobnicate",
         "branch unknown subcommand");
      Check_Usage_Failure
        ("branch list --contains",
         "missing branch list revision",
         "branch list contains missing revision");
      Check_Usage_Failure
        ("branch list --format short",
         "unknown branch list option: --format",
         "branch list unknown option");
      Check_Usage_Failure
        ("branch create",
         "missing branch name",
         "branch create missing name");
      Check_Usage_Failure
        ("branch create one two",
         "too many branch create arguments",
         "branch create too many arguments");
      Check_Usage_Failure
        ("branch rename",
         "missing branch new name",
         "branch rename missing name");
      Check_Usage_Failure
        ("branch rename a b c",
         "too many branch rename arguments",
         "branch rename too many arguments");
      Check_Usage_Failure
        ("branch delete",
         "missing branch name",
         "branch delete missing name");
      Check_Usage_Failure
        ("branch delete --force --force topic",
         "duplicate option: --force",
         "branch delete duplicate force");
      Check_Usage_Failure
        ("branch delete --merged topic",
         "unknown branch delete option: --merged",
         "branch delete unknown option");
      Check_Usage_Failure
        ("branch set-upstream main origin",
         "missing branch upstream arguments",
         "branch set-upstream missing argument");
      Check_Usage_Failure
        ("branch integrate",
         "missing branch integration target",
         "branch integrate missing target");
      Check_Usage_Failure
        ("branch integrate --continue",
         "unknown branch integrate option: --continue",
         "branch integrate unknown option");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Success ("branch create topic", "created branch topic", "branch create");
      Check_Success
        ("branch list --contains HEAD",
         "main",
         "branch list contains");
      Check_Success
        ("branch list --merged main",
         "main",
         "branch list merged with branch");
      Check_Success
        ("branch rename topic renamed",
         "renamed branch topic to renamed",
         "branch rename old new");
      Check_Success
        ("branch delete --force renamed",
         "deleted branch renamed",
         "branch delete force before name");
      Check_Success ("branch create topic", "created branch topic", "branch recreate");
      Check_Success
        ("branch delete topic --force",
         "deleted branch topic",
         "branch delete force after name");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Branch_Option_Parsing_Is_Frozen;

   procedure CLI_Read_Only_Command_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Status_Usage : constant String :=
        "version status [--porcelain[=v1]|--short|--long] [--branch]"
        & " [--ignored[=MODE]] [--untracked-files[=MODE]] [--] [PATHSPEC...]";
      Diff_Usage : constant String :=
        "version diff [--stat|--name-only|--name-status]"
        & " [--staged|--cached] [--] [PATHSPEC...]"
        & " | version diff [--stat|--name-only|--name-status] REV1 REV2";
      Check_Ignore_Usage : constant String :=
        "version check-ignore [-q|--quiet] [-v|--verbose] "
        & "[--stdin] [-z] [-n|--non-matching] "
        & "[--index|--no-index] [--] PATH...";
      Log_Usage : constant String :=
        "version log [--oneline] [--stat] [--show-signature]"
        & " [--format=<fmt>] [-<n>|-n <count>|--max-count=<n>] [REV]";
      Show_Usage : constant String := "version show [--stat] [REV]";
      History_Usage : constant String := "version history";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("status --ignored=unknown",
         "unknown status ignored mode: unknown",
         Status_Usage,
         "status unknown ignored mode rejected");
      Check_Usage_Failure
        ("status --short --",
         "missing status pathspec",
         Status_Usage,
         "status separator only after mode");
      --  --branch is a modifier in git, not a format, so it no longer
      --  conflicts; two real formats still do.
      Check_Usage_Failure
        ("status --short --porcelain",
         "duplicate status mode option: --porcelain",
         Status_Usage,
         "status second mode rejected");

      Check_Usage_Failure
        ("diff --frobnicate",
         "unknown diff option: --frobnicate",
         Diff_Usage,
         "diff unknown option");
      Check_Usage_Failure
        ("diff --staged --",
         "missing diff pathspec",
         Diff_Usage,
         "diff staged separator only");
      Check_Usage_Failure
        ("diff a b c d",
         "too many diff arguments",
         Diff_Usage,
         "diff too many arguments");

      Check_Usage_Failure
        ("check-ignore",
         "missing check-ignore path",
         Check_Ignore_Usage,
         "check-ignore missing path");
      Check_Usage_Failure
        ("check-ignore --bogus ignored.log",
         "unknown check-ignore option: --bogus",
         Check_Ignore_Usage,
         "check-ignore unknown option");
      Check_Usage_Failure
        ("check-ignore -q --verbose ignored.log",
         "check-ignore --quiet cannot be combined with --verbose",
         Check_Ignore_Usage,
         "check-ignore quiet verbose conflict");
      Check_Usage_Failure
        ("check-ignore -n ignored.log",
         "check-ignore --non-matching requires --verbose",
         Check_Ignore_Usage,
         "check-ignore non-matching requires verbose");
      Check_Usage_Failure
        ("check-ignore --stdin ignored.log",
         "check-ignore --stdin cannot be combined with path operands",
         Check_Ignore_Usage,
         "check-ignore stdin with path rejected");
      Check_Usage_Failure
        ("check-ignore -q --quiet ignored.log",
         "duplicate check-ignore option: --quiet",
         Check_Ignore_Usage,
         "check-ignore duplicate quiet");

      Check_Usage_Failure
        ("log --decorate",
         "unknown log option: --decorate",
         Log_Usage,
         "log unknown option");
      --  git accepts several revisions (`log main side` lists the union), so
      --  a second operand is not an error. One that names neither a revision
      --  nor a path is git's die(): "fatal: ambiguous argument", exit 128.
      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "log HEAD extra", Output, Status);
         Assert
           (Status = 128,
            "log with an unresolvable operand must exit 128");
         --  This fixture has no commits, so HEAD is the first operand that
         --  fails to resolve; the point is the diagnostic and the status,
         --  not which operand is named.
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "fatal: ambiguous argument",
            "log unresolvable operand diagnostic");
      end;
      Check_Usage_Failure
        ("log --oneline --graph",
         "unknown log option: --graph",
         Log_Usage,
         "log oneline unknown option");

      Check_Usage_Failure
        ("show --name-only",
         "unknown show option: --name-only",
         Show_Usage,
         "show unknown option");
      Check_Usage_Failure
        ("show HEAD extra",
         "too many show arguments",
         Show_Usage,
         "show too many arguments");

      Check_Usage_Failure
        ("history extra",
         "history takes no arguments",
         History_Usage,
         "history extra argument");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "--literal", "literal" & Character'Val (10));

      Check_Success
        ("status -- --literal",
         "--literal",
         "status option-looking pathspec after separator");
      Check_Success
        ("status --short -- --literal",
         "--literal",
         "short status option-looking pathspec after separator");

      Check_Success ("stage -- --literal", "staged --literal", "stage literal");
      Version.Write.Save ("literal file");
      Write_File (Root, "--literal", "changed" & Character'Val (10));
      Check_Success
        ("diff -- --literal",
         "--literal",
         "diff option-looking pathspec after separator");
      Check_Success
        ("diff --staged",
         "",
         "diff staged without pathspec");
      Check_Success
        ("log --oneline HEAD",
         "literal file",
         "log oneline revision");
      Check_Success
        ("log -1",
         "literal file",
         "log commit-count limit");
      Check_Success
        ("diff --stat -- --literal",
         "--literal",
         "diff --stat pathspec");
      Check_Success
        ("show HEAD",
         "literal file",
         "show revision");
      Check_Success
        ("show --stat HEAD",
         "literal file",
         "show --stat revision");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Read_Only_Command_Parsing_Is_Frozen;

   procedure CLI_Status_Ignored_Output_And_Pathspecs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Build   : constant String := Join (Root, "build");
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Version.Test_Support.Make_Directory (Build);
      Write_File
        (Root,
         ".gitignore",
         "*.log" & Character'Val (10)
         & "build/" & Character'Val (10));
      Write_File (Root, "ignored.log", "ignored" & Character'Val (10));
      Write_File
        (Root, "build/generated.txt", "ignored" & Character'Val (10));
      Write_File (Root, "visible.txt", "visible" & Character'Val (10));

      declare
         Output : constant String := Run_CLI (Root, "status --ignored");
      begin
         Assert_Contains
           (Output, "Ignored files:", "ignored status section");
         Assert_Contains
           (Output,
            Ada.Characters.Latin_1.HT & "build/generated.txt",
            "ignored status reports ignored directory content");
         Assert_Contains
           (Output,
            Ada.Characters.Latin_1.HT & "ignored.log",
            "ignored status reports ignored file");
         Assert_Contains
           (Output, "Untracked files:", "ordinary untracked section remains");
         Assert_Contains
           (Output, Ada.Characters.Latin_1.HT & "visible.txt",
            "ignored status still reports ordinary untracked file");
      end;

      declare
         Output : constant String :=
           Run_CLI (Root, "status --ignored -- ignored.log");
      begin
         Assert_Contains
           (Output, Ada.Characters.Latin_1.HT & "ignored.log",
            "ignored status pathspec keeps matching ignored file");
         Assert
           (Ada.Strings.Fixed.Index (Output, "build/generated.txt") = 0,
            "ignored status pathspec filters nonmatching ignored files");
         Assert
           (Ada.Strings.Fixed.Index (Output, "visible.txt") = 0,
            "ignored status pathspec filters nonmatching untracked files");
      end;

      declare
         Output : constant String := Run_CLI (Root, "status --short --ignored");
      begin
         Assert_Contains
           (Output, "!! build/generated.txt",
            "short ignored status reports ignored directory content");
         Assert_Contains
           (Output, "!! ignored.log",
            "short ignored status reports ignored file");
      end;

      declare
         Output : constant String :=
           Run_CLI (Root, "status --porcelain --ignored=matching");
      begin
         Assert_Contains
           (Output, "!! build/",
            "matching ignored porcelain status reports ignored directory");
         Assert_Contains
           (Output, "!! ignored.log",
            "matching ignored porcelain status reports ignored file");
         Assert
           (Ada.Strings.Fixed.Index (Output, "build/generated.txt") = 0,
            "matching ignored porcelain status collapses ignored directory");
      end;

      declare
         Output : constant String := Run_CLI (Root, "status --branch --ignored=no");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Output, "!! ignored.log") = 0,
            "ignored=no branch status omits ignored porcelain entries");
         Assert
           (Ada.Strings.Fixed.Index (Output, "Ignored files:") = 0,
            "ignored=no branch status omits ignored long section");
      end;

      declare
         Output : constant String := Run_CLI (Root, "status --ignored=matching");
      begin
         Assert_Contains
           (Output, Ada.Characters.Latin_1.HT & "build/",
            "matching ignored long status reports ignored directory");
         Assert
           (Ada.Strings.Fixed.Index (Output, "build/generated.txt") = 0,
            "matching ignored long status collapses ignored directory");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Status_Ignored_Output_And_Pathspecs;

   procedure CLI_Check_Ignore_Output_And_Status
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Build   : constant String := Join (Root, "build");
      Old_Dir : constant String := Ada.Directories.Current_Directory;

      procedure Check
        (Command : String; Expected_Status : Integer; Expected_Output : String;
         Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = Expected_Status, Context & " status");
         Assert
           (Ada.Strings.Unbounded.To_String (Output) = Expected_Output,
            Context & " output");
      end Check;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Version.Test_Support.Make_Directory (Build);
      Write_File
        (Root,
         ".gitignore",
         "*.log" & Character'Val (10)
         & "build/" & Character'Val (10)
         & "!keep.log" & Character'Val (10)
         & "--literal.log" & Character'Val (10));
      Write_File (Root, "ignored.log", "ignored" & Character'Val (10));
      Write_File (Root, "keep.log", "visible" & Character'Val (10));
      Write_File (Root, "tracked.log", "tracked" & Character'Val (10));
      Write_File
        (Root, "build/generated.txt", "ignored" & Character'Val (10));
      Write_File (Root, "--literal.log", "ignored" & Character'Val (10));
      Write_File (Root, "visible.txt", "visible" & Character'Val (10));
      Write_File
        (Root,
         "check-ignore.stdin",
         "ignored.log" & Character'Val (10)
         & "visible.txt" & Character'Val (10)
         & "build/generated.txt" & Character'Val (10));
      Write_File
        (Root,
         "check-ignore.nul",
         "ignored.log" & Character'Val (0)
         & "visible.txt" & Character'Val (0)
         & "build/generated.txt" & Character'Val (0));
      Version.Git_Fixtures.Run (Root, "git add -f tracked.log");

      Check
        ("check-ignore ignored.log visible.txt build build/generated.txt",
         0,
         "ignored.log" & Character'Val (10)
         & "build" & Character'Val (10)
         & "build/generated.txt",
         "check-ignore prints ignored operands only");

      Check
        ("check-ignore --quiet ignored.log visible.txt",
         0,
         "",
         "check-ignore quiet ignored operand");

      Check
        ("check-ignore -q visible.txt",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "",
         "check-ignore quiet nonmatching operand");

      Check
        ("check-ignore visible.txt",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "",
         "check-ignore nonmatching operand");

      Check
        ("check-ignore -- --literal.log",
         0,
         "--literal.log",
         "check-ignore option-looking path after separator");

      Check
        ("check-ignore --verbose ignored.log visible.txt keep.log build/generated.txt",
         0,
         ".gitignore:1:*.log" & Character'Val (9) & "ignored.log"
         & Character'Val (10)
         & ".gitignore:3:!keep.log" & Character'Val (9) & "keep.log"
         & Character'Val (10)
         & ".gitignore:2:build/" & Character'Val (9) & "build/generated.txt",
         "check-ignore verbose reports matching rule provenance");

      Check
        ("check-ignore -v -n visible.txt keep.log",
         0,
         "::" & Character'Val (9) & "visible.txt"
         & Character'Val (10)
         & ".gitignore:3:!keep.log" & Character'Val (9) & "keep.log",
         "check-ignore non-matching verbose output");

      Check
        ("check-ignore -v -n visible.txt",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "::" & Character'Val (9) & "visible.txt",
         "check-ignore non-matching only preserves failure status");

      Check
        ("check-ignore --stdin < check-ignore.stdin",
         0,
         "ignored.log" & Character'Val (10) & "build/generated.txt",
         "check-ignore stdin newline input");

      Check
        ("check-ignore --stdin -z < check-ignore.nul | od -An -tx1 | tr -d ' \n'",
         0,
         "69676e6f7265642e6c6f6700"
         & "6275696c642f67656e6572617465642e74787400",
         "check-ignore stdin nul input and output");

      Check
        ("check-ignore -z ignored.log visible.txt | od -An -tx1 | tr -d ' \n'",
         0,
         "69676e6f7265642e6c6f6700",
         "check-ignore argv nul output");

      Check
        ("check-ignore tracked.log",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "",
         "check-ignore honors index by default");

      Check
        ("check-ignore --no-index tracked.log",
         0,
         "tracked.log",
         "check-ignore no-index includes tracked ignored path");

      Check
        ("check-ignore --index --no-index tracked.log",
         0,
         "tracked.log",
         "check-ignore index no-index ordering last wins");

      Check
        ("check-ignore --no-index --index tracked.log",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "",
         "check-ignore no-index index ordering last wins");

      Check
        ("check-ignore --quiet --no-quiet ignored.log",
         0,
         "ignored.log",
         "check-ignore no-quiet re-enables output");

      Check
        ("check-ignore --verbose --no-verbose ignored.log",
         0,
         "ignored.log",
         "check-ignore no-verbose restores plain output");

      Check
        ("check-ignore --verbose --non-matching --no-non-matching visible.txt",
         Integer (Version.CLI.Command_Failure_Exit_Status),
         "",
         "check-ignore no-non-matching disables nonmatching output");

      Check
        ("check-ignore --stdin --no-stdin ignored.log",
         0,
         "ignored.log",
         "check-ignore no-stdin restores path operands");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Check_Ignore_Output_And_Status;

   procedure CLI_Fetch_And_Clone_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;
   begin
      Check_Usage_Failure
        ("fetch --depth",
         "--depth requires a value",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch missing depth");
      Check_Usage_Failure
        ("fetch --depth 1 origin extra more",
         "too many fetch arguments",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch extra operand");
      Check_Usage_Failure
        ("fetch --depth 1 --depth 2 origin",
         "duplicate option: --depth",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch duplicate depth");
      Check_Usage_Failure
        ("fetch --prune origin",
         "unknown fetch option: --prune",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch unknown option");
      Check_Usage_Failure
        ("fetch --deepen",
         "--deepen requires a value",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch missing deepen value");
      Check_Usage_Failure
        ("fetch --depth 1 --deepen 2 origin",
         "--depth, --deepen, and --unshallow are mutually exclusive",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch depth+deepen mutually exclusive");
      Check_Usage_Failure
        ("fetch --unshallow --depth 1 origin",
         "--depth, --deepen, and --unshallow are mutually exclusive",
         "version fetch [--depth N|--deepen N|--unshallow] REMOTE [REF]",
         "fetch unshallow+depth mutually exclusive");

      Check_Usage_Failure
        ("clone source",
         "missing clone source or target",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone missing target");
      Check_Usage_Failure
        ("clone --recursive --recursive source target",
         "duplicate option: --recursive",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone duplicate recursive");
      Check_Usage_Failure
        ("clone source target extra",
         "too many clone arguments",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone extra operand");
      Check_Usage_Failure
        ("clone source target --recursive --depth 1",
         "clone --depth cannot be combined with --recursive",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone combined options");
      Check_Usage_Failure
        ("clone --mirror source target",
         "unknown clone option: --mirror",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone unknown option");
      Check_Usage_Failure
        ("clone --filter=blob:none --depth 1 source target",
         "clone --filter cannot be combined with --depth or --recursive",
         "version clone [--depth N|--recursive|--filter SPEC] SOURCE TARGET",
         "clone filter with depth");
   end CLI_Fetch_And_Clone_Option_Parsing_Is_Frozen;

   procedure CLI_Push_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version push [--no-verify] [--force] [--atomic] REMOTE"
        & " REFSPEC..."
        & " | version push [--no-verify] --tags [REMOTE]"
        & " | version push [--no-verify] [--atomic] --delete REMOTE"
        & " REF...";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;
   begin
      Check_Usage_Failure
        ("push",
         "missing push remote",
         "push missing remote");
      --  Multiple refspec operands are now accepted (git parity: they push
      --  several refs in one invocation), so "push REMOTE a b" is no longer a
      --  usage error. Option-parsing freeze is still exercised by the cases
      --  below.
      Check_Usage_Failure
        ("push --no-verify --no-verify origin main",
         "duplicate option: --no-verify",
         "push duplicate no-verify");
      Check_Usage_Failure
        ("push --tags --tags origin",
         "duplicate option: --tags",
         "push duplicate tags");
      Check_Usage_Failure
        ("push --bogus origin main",
         "unknown push option: --bogus",
         "push unknown option");
      Check_Usage_Failure
        ("push --force --force origin main",
         "duplicate option: --force",
         "push duplicate force");
      Check_Usage_Failure
        ("push --delete origin",
         "push --delete requires a remote and a ref",
         "push delete missing ref");
      Check_Usage_Failure
        ("push --delete --delete origin topic",
         "duplicate option: --delete",
         "push duplicate delete");
      Check_Usage_Failure
        ("push --delete --force origin topic",
         "push --delete cannot be combined with --tags or --force",
         "push delete with force");
      Check_Usage_Failure
        ("push origin main:",
         "push refspec is missing a destination ref",
         "push refspec missing destination");
      Check_Usage_Failure
        ("push --tags --no-verify origin main",
         "push --tags accepts at most one remote",
         "push mixed option order with too many tag operands");
      Check_Usage_Failure
        ("push origin main --no-verify --tags",
         "push --tags accepts at most one remote",
         "push trailing options with too many tag operands");
   end CLI_Push_Option_Parsing_Is_Frozen;

   procedure CLI_Save_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version save [--amend] [--no-verify] [-S[<keyid>]]"
        & " [--no-gpg-sign] [-m] MESSAGE";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command : String; Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "saved ",
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("save",
         "missing save message",
         "save missing message");
      Check_Usage_Failure
        ("save -m",
         "-m requires a message",
         "save missing -m message");
      Check_Usage_Failure
        ("save --amend --amend message",
         "duplicate option: --amend",
         "save duplicate amend");
      Check_Usage_Failure
        ("save --no-verify --no-verify message",
         "duplicate option: --no-verify",
         "save duplicate no-verify");
      Check_Usage_Failure
        ("save -m one -m two",
         "duplicate option: -m",
         "save duplicate message option");
      Check_Usage_Failure
        ("save --signoff message",
         "unknown save option: --signoff",
         "save unknown option");
      Check_Usage_Failure
        ("save message extra",
         "too many save arguments",
         "save extra operand");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "a.txt", "one" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Check_Success
        ("save -m mixed-order --no-verify",
         "save mixed order");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Check_Success
        ("save --no-verify --amend -m amended-order",
         "save amend mixed order");

      --  --no-gpg-sign is accepted (and produces an unsigned commit) without a
      --  configured key or gpg; -S/--gpg-sign are parsed as signing options
      --  rather than rejected as unknown.
      Write_File (Root, "a.txt", "three" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Check_Success
        ("save --no-gpg-sign -m unsigned-explicit",
         "save no-gpg-sign");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Save_Option_Parsing_Is_Frozen;

   procedure CLI_Tag_Create_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version tag create [-a|-s|-u KEY] NAME [REV] [-m MESSAGE]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("tag create",
         "missing tag name",
         "tag create missing name");
      Check_Usage_Failure
        ("tag create -a v1",
         "annotated tag requires -m MESSAGE",
         "tag create annotated missing message");
      Check_Usage_Failure
        ("tag create -a -a v1 -m msg",
         "duplicate option: -a",
         "tag create duplicate annotated option");
      Check_Usage_Failure
        ("tag create -a v1 -m one -m two",
         "duplicate option: -m",
         "tag create duplicate message option");
      Check_Usage_Failure
        ("tag create -a v1 -m",
         "-m requires a message",
         "tag create missing message value");
      Check_Usage_Failure
        ("tag create --annotate v1 -m msg",
         "unknown tag create option: --annotate",
         "tag create unknown option");
      Check_Usage_Failure
        ("tag create v1 -m msg",
         "-m requires annotated tag option -a",
         "tag create message without annotated option");
      Check_Usage_Failure
        ("tag create v1 HEAD extra",
         "too many tag create arguments",
         "tag create extra operand");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Check_Success
        ("tag create v-light",
         "created tag v-light",
         "tag create lightweight");
      Check_Success
        ("tag create -a v-ann -m annotated-message",
         "created annotated tag v-ann",
         "tag create annotated");
      Check_Success
        ("tag create -a v-ann-rev HEAD -m annotated-head",
         "created annotated tag v-ann-rev",
         "tag create annotated explicit revision");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Tag_Create_Option_Parsing_Is_Frozen;

   procedure CLI_Submodule_Update_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version submodule update [--recursive]";
      Top_Usage : constant String := "version submodule SUBCOMMAND [ARGS]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage_Text : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage_Text),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("submodule",
         "missing submodule subcommand",
         Top_Usage,
         "submodule missing subcommand");
      Check_Usage_Failure
        ("submodule frobnicate",
         "unknown submodule subcommand: frobnicate",
         Top_Usage,
         "submodule unknown subcommand");
      Check_Usage_Failure
        ("submodule init extra",
         "too many submodule init arguments",
         Top_Usage,
         "submodule init extra argument");
      Check_Usage_Failure
        ("submodule status extra",
         "too many submodule status arguments",
         Top_Usage,
         "submodule status extra argument");
      Check_Usage_Failure
        ("submodule update --recursive --recursive",
         "duplicate option: --recursive",
         Usage,
         "submodule update duplicate recursive");
      Check_Usage_Failure
        ("submodule update --checkout",
         "unknown submodule update option: --checkout",
         Usage,
         "submodule update unknown option");
      Check_Usage_Failure
        ("submodule update path",
         "too many submodule update arguments",
         Usage,
         "submodule update extra operand");

      Version.Init.Init (Root);
      Ada.Directories.Set_Directory (Root);
      Check_Success
        ("submodule update",
         "updated submodules",
         "submodule update default");
      Check_Success
        ("submodule update --recursive",
         "updated submodules",
         "submodule update recursive");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Submodule_Update_Option_Parsing_Is_Frozen;

   procedure CLI_Cherry_Pick_And_Revert_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Cherry_Pick_Usage : constant String :=
        "version cherry-pick [-m PARENT|--mainline PARENT] REV...";
      Revert_Usage : constant String :=
        "version revert [-m PARENT|--mainline PARENT] REV...";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text, Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Usage_Failure
        ("cherry-pick",
         "missing cherry-pick revision",
         Cherry_Pick_Usage,
         "cherry-pick missing revision");
      Check_Usage_Failure
        ("revert",
         "missing revert revision",
         Revert_Usage,
         "revert missing revision");

      Check_Usage_Failure
        ("cherry-pick -m",
         "-m requires a parent number",
         Cherry_Pick_Usage,
         "cherry-pick missing mainline value");
      Check_Usage_Failure
        ("cherry-pick --mainline nope HEAD",
         "mainline must be a positive integer",
         Cherry_Pick_Usage,
         "cherry-pick invalid mainline value");
      Check_Usage_Failure
        ("cherry-pick -m 1 --mainline 2 HEAD",
         "duplicate option: --mainline",
         Cherry_Pick_Usage,
         "cherry-pick duplicate mainline option");
      Check_Usage_Failure
        ("cherry-pick --strategy ours HEAD",
         "unknown cherry-pick option: --strategy",
         Cherry_Pick_Usage,
         "cherry-pick unknown option");
      Check_Usage_Failure
        ("cherry-pick -m 1",
         "missing cherry-pick revision",
         Cherry_Pick_Usage,
         "cherry-pick missing revision after options");

      Check_Usage_Failure
        ("revert --mainline",
         "--mainline requires a parent number",
         Revert_Usage,
         "revert missing mainline value");
      Check_Usage_Failure
        ("revert -m zero HEAD",
         "mainline must be a positive integer",
         Revert_Usage,
         "revert invalid mainline value");
      Check_Usage_Failure
        ("revert --mainline 1 -m 2 HEAD",
         "duplicate option: -m",
         Revert_Usage,
         "revert duplicate mainline option");
      Check_Usage_Failure
        ("revert --no-commit HEAD",
         "unknown revert option: --no-commit",
         Revert_Usage,
         "revert unknown option");
      Check_Usage_Failure
        ("revert --mainline 1",
         "missing revert revision",
         Revert_Usage,
         "revert missing revision after options");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Cherry_Pick_And_Revert_Option_Parsing_Is_Frozen;

   procedure CLI_Maintenance_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Pack_Refs_Usage : constant String :=
        "version pack-refs [--all] [--prune]";
      Prune_Usage     : constant String := "version prune [--dry-run|--now]";
      GC_Usage        : constant String := "version gc [--dry-run|--now]";
      Verify_Usage    : constant String := "version verify";
      Repack_Usage    : constant String := "version repack";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text, Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("pack-refs --prune --prune",
         "duplicate option: --prune",
         Pack_Refs_Usage,
         "pack-refs duplicate prune");
      --  git accepts --all, so it is no longer an error; keep the
      --  unknown-option coverage with an option git does not have either.
      Check_Usage_Failure
        ("pack-refs --bogus",
         "unknown pack-refs option: --bogus",
         Pack_Refs_Usage,
         "pack-refs unknown option");
      Check_Usage_Failure
        ("pack-refs refs/heads/main",
         "too many pack-refs arguments",
         Pack_Refs_Usage,
         "pack-refs extra operand");

      Check_Usage_Failure
        ("prune --dry-run --dry-run",
         "duplicate option: --dry-run",
         Prune_Usage,
         "prune duplicate dry-run");
      Check_Usage_Failure
        ("prune --dry-run --now",
         "prune --dry-run cannot be combined with --now",
         Prune_Usage,
         "prune conflicting options");
      Check_Usage_Failure
        ("prune --expire now",
         "unknown prune option: --expire",
         Prune_Usage,
         "prune unknown option");
      Check_Usage_Failure
        ("prune loose-object",
         "too many prune arguments",
         Prune_Usage,
         "prune extra operand");

      Check_Usage_Failure
        ("gc --now --now",
         "duplicate option: --now",
         GC_Usage,
         "gc duplicate now");
      Check_Usage_Failure
        ("gc --now --dry-run",
         "gc --dry-run cannot be combined with --now",
         GC_Usage,
         "gc conflicting options");
      Check_Usage_Failure
        ("gc --aggressive",
         "unknown gc option: --aggressive",
         GC_Usage,
         "gc unknown option");
      Check_Usage_Failure
        ("gc objects",
         "too many gc arguments",
         GC_Usage,
         "gc extra operand");

      Check_Usage_Failure
        ("verify extra",
         "verify takes no arguments",
         Verify_Usage,
         "verify extra argument");
      Check_Usage_Failure
        ("repack extra",
         "repack takes no arguments",
         Repack_Usage,
         "repack extra argument");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Success ("pack-refs", "packed refs", "pack-refs default");
      Check_Success
        ("pack-refs --prune", "packed refs", "pack-refs prune");
      Check_Success
        ("prune", "unreachable loose objects", "prune default");
      Check_Success
        ("prune --dry-run", "unreachable loose objects", "prune dry-run");
      Check_Success ("gc", "gc: ok (", "gc default");
      Check_Success ("gc --dry-run", "gc: ok (", "gc dry-run");
      Check_Success ("verify", "verify: ok (", "verify default");
      Check_Success ("repack", "repack: wrote ", "repack default");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Maintenance_Option_Parsing_Is_Frozen;

   procedure CLI_Init_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version init [--bare] [--object-format=(sha1|sha256)]"
        & " [--ref-format=(files|reftable)] [PATH]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text, Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Normal_Path : constant String := Root & "-init-path";
      Bare_Path   : constant String := Root & "-init-bare";
   begin
      Check_Usage_Failure
        ("init --bare --bare",
         "duplicate option: --bare",
         "init duplicate bare");
      Check_Usage_Failure
        ("init --template tpl",
         "unknown init option: --template",
         "init unknown option");
      Check_Usage_Failure
        ("init one two",
         "too many init arguments",
         "init extra operand");
      Check_Usage_Failure
        ("init --object-format=bogus",
         "unknown object format: bogus",
         "init bad object format");
      Check_Usage_Failure
        ("init --object-format",
         "--object-format requires a value",
         "init object format missing value");
      Check_Usage_Failure
        ("init --ref-format=bogus",
         "unknown ref format: bogus",
         "init bad ref format");
      Check_Usage_Failure
        ("init --ref-format",
         "--ref-format requires a value",
         "init ref format missing value");

      Check_Success ("init", "initialized repository in .", "init default");
      Check_Success
        ("init " & Shell_Quote (Normal_Path),
         "initialized repository in " & Normal_Path,
         "init explicit path");
      Check_Success
        ("init --bare " & Shell_Quote (Bare_Path),
         "initialized bare repository in " & Bare_Path,
         "init bare explicit path");
      Check_Success
        ("init --object-format=sha256 " & Shell_Quote (Root & "-init-256"),
         "initialized repository in " & Root & "-init-256",
         "init sha256 object format");
      Check_Success
        ("init --ref-format=reftable " & Shell_Quote (Root & "-init-reftable"),
         "initialized repository in " & Root & "-init-reftable",
         "init reftable ref format");
   end CLI_Init_Option_Parsing_Is_Frozen;

   procedure CLI_Worktree_Add_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version worktree add [--detach] PATH BRANCH_OR_REV";
      Top_Usage : constant String := "version worktree SUBCOMMAND [ARGS]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage_Text : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert (Status /= 0, Context & " must fail");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage_Text),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Normal_Path   : constant String := Root & "-wt-feature";
      Detached_Path : constant String := Root & "-wt-detached";
      Old_Dir       : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("worktree",
         "missing worktree subcommand",
         Top_Usage,
         "worktree missing subcommand");
      Check_Usage_Failure
        ("worktree frobnicate",
         "unknown worktree subcommand: frobnicate",
         Top_Usage,
         "worktree unknown subcommand");
      Check_Usage_Failure
        ("worktree list extra",
         "too many worktree list arguments",
         Top_Usage,
         "worktree list extra argument");
      Check_Usage_Failure
        ("worktree current extra",
         "too many worktree current arguments",
         Top_Usage,
         "worktree current extra argument");
      Check_Usage_Failure
        ("worktree remove",
         "missing worktree path",
         Top_Usage,
         "worktree remove missing path");
      Check_Usage_Failure
        ("worktree remove one two",
         "too many worktree remove arguments",
         Top_Usage,
         "worktree remove too many arguments");
      Check_Usage_Failure
        ("worktree add",
         "missing worktree path",
         Usage,
         "worktree add missing path");
      Check_Usage_Failure
        ("worktree add ../wt",
         "missing worktree branch",
         Usage,
         "worktree add missing branch");
      Check_Usage_Failure
        ("worktree add --detach ../wt",
         "missing worktree revision",
         Usage,
         "worktree add detached missing revision");
      Check_Usage_Failure
        ("worktree add --detach --detach ../wt HEAD",
         "duplicate option: --detach",
         Usage,
         "worktree add duplicate detach");
      Check_Usage_Failure
        ("worktree add --orphan ../wt main",
         "unknown worktree add option: --orphan",
         Usage,
         "worktree add unknown option");
      Check_Usage_Failure
        ("worktree add ../wt main extra",
         "too many worktree add arguments",
         Usage,
         "worktree add extra operand");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Version.Branch.Create_Branch ("feature");
      Check_Success
        ("worktree add " & Shell_Quote (Normal_Path) & " feature",
         "added worktree " & Normal_Path,
         "worktree add normal");
      Check_Success
        ("worktree add " & Shell_Quote (Detached_Path) & " --detach HEAD",
         "added detached worktree " & Detached_Path,
         "worktree add trailing detach");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Worktree_Add_Option_Parsing_Is_Frozen;

   procedure CLI_Remote_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      procedure Check_Status_Success (Command, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
      end Check_Status_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("remote",
         "missing remote subcommand",
         "version remote <subcommand>",
         "remote missing subcommand");
      Check_Usage_Failure
        ("remote --verbose",
         "unknown remote option: --verbose",
         "version remote <subcommand>",
         "remote unknown top-level option");
      Check_Usage_Failure
        ("remote sync origin",
         "unknown remote subcommand: sync",
         "version remote <subcommand>",
         "remote unknown subcommand");
      Check_Usage_Failure
        ("remote add origin",
         "missing remote URL",
         "version remote add NAME URL",
         "remote add missing URL");
      Check_Usage_Failure
        ("remote add --mirror origin https://example.invalid/project.git",
         "unknown remote add option: --mirror",
         "version remote add NAME URL",
         "remote add unknown option");
      Check_Usage_Failure
        ("remote add origin https://example.invalid/project.git extra",
         "too many remote add arguments",
         "version remote add NAME URL",
         "remote add extra operand");
      Check_Usage_Failure
        ("remote set-url origin",
         "missing remote URL",
         "version remote set-url NAME URL",
         "remote set-url missing URL");
      Check_Usage_Failure
        ("remote rename origin",
         "missing remote new name",
         "version remote rename OLD NEW",
         "remote rename missing new name");
      Check_Usage_Failure
        ("remote delete",
         "missing remote name",
         "version remote delete NAME",
         "remote delete missing name");
      Check_Usage_Failure
        ("remote get-url",
         "missing remote name",
         "version remote get-url NAME",
         "remote get-url missing name");
      Check_Usage_Failure
        ("remote prune",
         "missing remote name",
         "version remote prune [--dry-run] NAME",
         "remote prune missing name");
      Check_Usage_Failure
        ("remote prune --dry-run --dry-run origin",
         "duplicate option: --dry-run",
         "version remote prune [--dry-run] NAME",
         "remote prune duplicate dry-run");
      Check_Usage_Failure
        ("remote prune --stale origin",
         "unknown remote prune option: --stale",
         "version remote prune [--dry-run] NAME",
         "remote prune unknown option");
      Check_Usage_Failure
        ("remote prune origin extra",
         "too many remote prune arguments",
         "version remote prune [--dry-run] NAME",
         "remote prune extra operand");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Check_Success
        ("remote add origin https://example.invalid/project.git",
         "added remote origin",
         "remote add");
      Check_Success
        ("remote list",
         "origin" & Character'Val (9) & "https://example.invalid/project.git",
         "remote list");
      Check_Success
        ("remote get-url origin",
         "https://example.invalid/project.git",
         "remote get-url");
      Check_Status_Success ("remote exists origin", "remote exists");
      Check_Success
        ("remote set-url origin https://example.invalid/new.git",
         "updated remote origin",
         "remote set-url");
      Check_Success
        ("remote rename origin upstream",
         "renamed remote origin to upstream",
         "remote rename");
      Check_Status_Success ("remote exists upstream", "remote exists renamed");
      Check_Success
        ("remote remove upstream",
         "deleted remote upstream",
         "remote remove");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Remote_Option_Parsing_Is_Frozen;

   procedure CLI_Config_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      procedure Check_Status_Success (Command, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
      end Check_Status_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("config",
         "missing config subcommand",
         "version config <subcommand>",
         "config missing subcommand");
      Check_Usage_Failure
        ("config --global",
         "unknown config option: --global",
         "version config <subcommand>",
         "config unknown top-level option");
      Check_Usage_Failure
        ("config edit",
         "unknown config subcommand: edit",
         "version config <subcommand>",
         "config unknown subcommand");
      Check_Usage_Failure
        ("config list extra",
         "too many config list arguments",
         "version config list",
         "config list extra operand");
      Check_Usage_Failure
        ("config keys --null",
         "unknown config keys option: --null",
         "version config keys",
         "config keys unknown option");
      Check_Usage_Failure
        ("config get",
         "missing config key",
         "version config get KEY",
         "config get missing key");
      Check_Usage_Failure
        ("config get --name-only",
         "unknown config get option: --name-only",
         "version config get KEY",
         "config get unknown option");
      Check_Usage_Failure
        ("config has user.name extra",
         "too many config has arguments",
         "version config has KEY",
         "config has extra operand");
      Check_Usage_Failure
        ("config set user.name",
         "missing config value",
         "version config set KEY VALUE",
         "config set missing value");
      Check_Usage_Failure
        ("config set --add user.name Ada",
         "unknown config set option: --add",
         "version config set KEY VALUE",
         "config set unknown option");
      Check_Usage_Failure
        ("config set user.name Ada extra",
         "too many config set arguments",
         "version config set KEY VALUE",
         "config set extra operand");
      Check_Usage_Failure
        ("config unset",
         "missing config key",
         "version config unset KEY",
         "config unset missing key");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Check_Success
        ("config set core.editor ed",
         "set config core.editor",
         "config set");
      Check_Success
        ("config list",
         "core.editor=ed",
         "config list");
      Check_Success
        ("config keys",
         "core.editor",
         "config keys");
      Check_Success
        ("config get core.editor",
         "ed",
         "config get");
      Check_Status_Success ("config has core.editor", "config has");
      Check_Success
        ("config unset core.editor",
         "unset config core.editor",
         "config unset");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Config_Option_Parsing_Is_Frozen;

   procedure CLI_Sparse_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("sparse",
         "missing sparse subcommand",
         "version sparse <subcommand>",
         "sparse missing subcommand");
      Check_Usage_Failure
        ("sparse --cone",
         "unknown sparse option: --cone",
         "version sparse <subcommand>",
         "sparse unknown top-level option");
      Check_Usage_Failure
        ("sparse check-rules",
         "unknown sparse subcommand: check-rules",
         "version sparse <subcommand>",
         "sparse unknown subcommand");
      Check_Usage_Failure
        ("sparse list extra",
         "too many sparse list arguments",
         "version sparse list",
         "sparse list extra operand");
      Check_Usage_Failure
        ("sparse status --porcelain",
         "unknown sparse status option: --porcelain",
         "version sparse status",
         "sparse status unknown option");
      Check_Usage_Failure
        ("sparse disable --force",
         "unknown sparse disable option: --force",
         "version sparse disable",
         "sparse disable unknown option");
      Check_Usage_Failure
        ("sparse init extra",
         "too many sparse init arguments",
         "version sparse init [--cone|--no-cone]",
         "sparse init extra operand");
      --  A raw ("--no-cone") set still requires at least one pattern; cone
      --  set with no directories is valid (top level only), matching git.
      Check_Usage_Failure
        ("sparse set --no-cone",
         "missing sparse pathspec",
         "version sparse set [--cone|--no-cone] DIR...",
         "sparse set --no-cone missing pathspec");
      Check_Usage_Failure
        ("sparse set --bogus src",
         "unknown sparse set option: --bogus",
         "version sparse set [--cone|--no-cone] DIR...",
         "sparse set unknown option");
      Check_Usage_Failure
        ("sparse add",
         "missing sparse pathspec",
         "version sparse add [--cone|--no-cone] DIR...",
         "sparse add missing pathspec");
      Check_Usage_Failure
        ("sparse add --sparse docs",
         "unknown sparse add option: --sparse",
         "version sparse add [--cone|--no-cone] DIR...",
         "sparse add unknown option");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Success ("sparse status", "disabled", "sparse status disabled");
      Check_Success ("sparse init", "initialized sparse checkout", "sparse init");
      Check_Success ("sparse set a.txt", "updated sparse checkout", "sparse set");
      Check_Success ("sparse list", "a.txt", "sparse list");
      Check_Success ("sparse add -- --literal", "updated sparse checkout", "sparse add separator");
      Check_Success ("sparse status", "enabled", "sparse status enabled");
      Check_Success
        ("sparse disable", "disabled sparse checkout", "sparse disable");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Sparse_Option_Parsing_Is_Frozen;

   procedure CLI_Archive_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version archive REV [--output PATH] [--format tar|zip] [--prefix PATH] [--] [PATHSPEC...]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Tar_Output     : constant String := Join (Root, "cli-archive.tar");
      Zip_Output     : constant String := Join (Root, "cli-archive.zip");
      Literal_Output : constant String := Join (Root, "cli-archive-literal.tar");
      Old_Dir        : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("archive",
         "missing archive revision",
         "archive missing revision");
      Check_Usage_Failure
        ("archive HEAD --output",
         "--output requires a path",
         "archive output missing path");
      Check_Usage_Failure
        ("archive HEAD --format",
         "--format requires a value",
         "archive format missing value");
      Check_Usage_Failure
        ("archive HEAD --prefix",
         "--prefix requires a path",
         "archive prefix missing path");
      Check_Usage_Failure
        ("archive HEAD --output one.tar --output two.tar",
         "duplicate option: --output",
         "archive duplicate output");
      Check_Usage_Failure
        ("archive HEAD --format tar --format zip",
         "duplicate option: --format",
         "archive duplicate format");
      Check_Usage_Failure
        ("archive HEAD --prefix src/ --prefix docs/",
         "duplicate option: --prefix",
         "archive duplicate prefix");
      Check_Usage_Failure
        ("archive HEAD --worktree-attributes",
         "unknown archive option: --worktree-attributes",
         "archive unknown option");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Success
        ("archive HEAD --output " & Shell_Quote (Tar_Output),
         "created archive " & Tar_Output,
         "archive tar output");
      Assert (Ada.Directories.Exists (Tar_Output), "tar archive must be written");

      Check_Success
        ("archive HEAD --output " & Shell_Quote (Zip_Output),
         "created archive " & Zip_Output,
         "archive zip output inferred");
      Assert (Ada.Directories.Exists (Zip_Output), "zip archive must be written");

      Check_Success
        ("archive HEAD --output "
         & Shell_Quote (Literal_Output)
         & " -- --not-an-option",
         "created archive " & Literal_Output,
         "archive option-looking pathspec after separator");
      Assert
        (Ada.Directories.Exists (Literal_Output),
         "literal pathspec archive must be written");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Archive_Option_Parsing_Is_Frozen;

   procedure CLI_Stage_And_Remove_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Usage : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("stage",
         "missing stage pathspec",
         "version stage [-f|--force] [--] PATHSPEC...",
         "stage missing pathspec");
      Check_Usage_Failure
        ("stage --",
         "missing stage pathspec",
         "version stage [-f|--force] [--] PATHSPEC...",
         "stage separator only");
      Check_Usage_Failure
        ("stage --patch a.txt",
         "unknown stage option: --patch",
         "version stage [-f|--force] [--] PATHSPEC...",
         "stage unknown option");
      Check_Usage_Failure
        ("stage --force -f a.txt",
         "duplicate option: -f",
         "version stage [-f|--force] [--] PATHSPEC...",
         "stage duplicate force option");
      Check_Usage_Failure
        ("remove",
         "missing remove pathspec",
         "version remove [--] PATHSPEC...",
         "remove missing pathspec");
      Check_Usage_Failure
        ("remove --",
         "missing remove pathspec",
         "version remove [--] PATHSPEC...",
         "remove separator only");
      Check_Usage_Failure
        ("remove --cached a.txt",
         "unknown remove option: --cached",
         "version remove [--] PATHSPEC...",
         "remove unknown option");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Write_File (Root, "--literal", "literal" & Character'Val (10));
      Check_Success
        ("stage -- --literal",
         "staged --literal",
         "stage option-looking pathspec after separator");
      Version.Write.Save ("literal file");

      Check_Success
        ("remove -- --literal",
         "removed --literal",
         "remove option-looking pathspec after separator");

      Write_File (Root, ".gitignore", "*.log" & Character'Val (10));
      Write_File (Root, "ignored.log", "ignored" & Character'Val (10));
      declare
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, "stage ignored.log", Output, Status);
         Assert
           (Status = Integer (Version.CLI.Command_Failure_Exit_Status),
            "plain stage ignored file must fail with command status");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "pathspec matched no files",
            "plain stage ignored file reports no match");
      end;
      Check_Success
        ("stage --force ignored.log",
         "staged ignored.log",
         "stage force includes ignored file");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stage_And_Remove_Option_Parsing_Is_Frozen;

   procedure CLI_Restore_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version restore [--source REV] [--staged] [--] [PATHSPEC...]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("restore --source",
         "--source requires a revision",
         "restore source missing revision");
      Check_Usage_Failure
        ("restore --source --staged a.txt",
         "--source requires a revision",
         "restore source option as revision");
      Check_Usage_Failure
        ("restore --source HEAD --source main a.txt",
         "duplicate option: --source",
         "restore duplicate source");
      Check_Usage_Failure
        ("restore --staged --staged a.txt",
         "duplicate option: --staged",
         "restore duplicate staged");
      Check_Usage_Failure
        ("restore --ours a.txt",
         "unknown restore option: --ours",
         "restore unknown option");
      Check_Usage_Failure
        ("restore --source HEAD",
         "missing restore pathspec",
         "restore source missing pathspec");
      Check_Usage_Failure
        ("restore --staged",
         "missing restore pathspec",
         "restore staged missing pathspec");
      Check_Usage_Failure
        ("restore --",
         "missing restore pathspec",
         "restore separator only");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success ("restore a.txt", "restored paths", "restore pathspec");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success
        ("restore --source HEAD -- a.txt",
         "restored paths from HEAD",
         "restore source pathspec");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success ("stage a.txt", "staged a.txt", "stage for restore");
      Check_Success
        ("restore --staged a.txt",
         "restored staged paths",
         "restore staged pathspec");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success ("stage a.txt", "staged a.txt", "stage for source staged");
      Check_Success
        ("restore --source HEAD --staged -- a.txt",
         "restored staged paths from HEAD",
         "restore source staged pathspec");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success ("stage a.txt", "staged a.txt", "stage for staged source");
      Check_Success
        ("restore --staged --source HEAD -- a.txt",
         "restored staged paths from HEAD",
         "restore staged source pathspec");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Restore_Option_Parsing_Is_Frozen;

   procedure CLI_Checkout_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version checkout REV [-- PATHSPEC...]";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      procedure Check_Success (Command, Output_Fragment, Context : String) is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status = 0, Context & " must succeed");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            Output_Fragment,
            Context & " output");
      end Check_Success;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("checkout",
         "missing checkout revision",
         "checkout missing revision");
      Check_Usage_Failure
        ("checkout --detach HEAD",
         "unknown checkout option: --detach",
         "checkout unknown leading option");
      Check_Usage_Failure
        ("checkout HEAD a.txt",
         "expected -- before checkout pathspec",
         "checkout missing separator");
      Check_Usage_Failure
        ("checkout HEAD --ours a.txt",
         "unknown checkout option: --ours",
         "checkout unknown option after revision");
      Check_Usage_Failure
        ("checkout HEAD --",
         "missing checkout pathspec",
         "checkout separator only");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Check_Success ("checkout HEAD", "checked out HEAD", "checkout revision");

      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Check_Success
        ("checkout HEAD -- a.txt",
         "checked out paths from HEAD",
         "checkout pathspec");

      Write_File (Root, "--literal", "literal" & Character'Val (10));
      Check_Success ("stage -- --literal", "staged --literal", "stage literal");
      Version.Write.Save ("literal file");
      Write_File (Root, "--literal", "changed" & Character'Val (10));
      Check_Success
        ("checkout HEAD -- --literal",
         "checked out paths from HEAD",
         "checkout option-looking pathspec after separator");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Checkout_Option_Parsing_Is_Frozen;

   procedure CLI_Unsupported_Feature_Diagnostics_Are_Precise
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      --  SHA-256 is a supported object format, so it has no unsupported
      --  diagnostic; only genuinely unsupported formats do.
      Assert
        (Version.Unsupported.Object_Format ("sha512")
         = "unsupported repository object format: sha512",
         "unsupported object-format diagnostic must be precise");
      Assert
        (Version.Unsupported.Promisor_Objects
         = "unsupported promisor object: no configured partial-clone promisor remote",
         "promisor unsupported diagnostic must mention missing remote scope");
      Assert
        (Version.Unsupported.Http_3
         = "unsupported transport feature: HTTP/3 backend is not available",
         "HTTP/3 unsupported diagnostic must remain stable");
      Assert
        (Version.Unsupported.H2C
         = "unsupported transport feature: h2c upgrade is not supported",
         "h2c unsupported diagnostic must remain stable");
      Assert
        (Version.Unsupported.Server_Push
         = "unsupported transport feature: server push is not supported",
         "server-push unsupported diagnostic must remain stable");
      Assert
        (Version.Unsupported.Remote_Url
         = "unsupported remote URL: expected local path, file://, http(s) smart transport, or configured SSH transport",
         "unsupported remote URL diagnostic must describe supported schemes");
      Assert
        (Version.CLI.Error_Output_Text (Version.Rebase.Root_Rebase_Not_Supported)
         = "error: root rebases not supported",
         "root rebase diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Rebase.Merge_Commit_Rebase_Not_Supported)
         = "error: rebase of merge commits not supported",
         "merge rebase diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Rebase.Interactive_Rebase_Not_Supported)
         = "error: interactive rebase is not supported",
         "interactive rebase diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Rebase.Merge_Preserving_Rebase_Not_Supported)
         = "error: merge-preserving rebase is not supported",
         "merge-preserving rebase diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Pathspec.Backslash_Separator_Diagnostic ("src\main.adb"))
         = "error: backslash pathspec separators are not supported: src\main.adb",
         "backslash pathspec diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Pathspec.Traversal_Component_Diagnostic ("../x"))
         = "error: pathspec traversal is not allowed: ../x",
         "pathspec traversal diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Pathspec.Absolute_Pathspec_Diagnostic ("/tmp/a.txt"))
         = "error: absolute pathspecs are not allowed: /tmp/a.txt",
         "absolute pathspec diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Pathspec.Unknown_Magic_Diagnostic ("icase"))
         = "error: unknown pathspec magic: icase",
         "unknown pathspec magic diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.Pathspec.Empty_Magic_Diagnostic)
         = "error: empty pathspec magic",
         "empty pathspec magic diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.CLI.Pathspec_No_Files_Text)
         = "error: pathspec matched no files",
         "pathspec no-files diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.CLI.Pathspec_No_Tracked_Paths_Text)
         = "error: pathspec matched no tracked paths",
         "pathspec no-tracked-paths diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.CLI.Pathspec_No_Source_Paths_Text)
         = "error: pathspec matched no source paths",
         "pathspec no-source-paths diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Invalid_Stash_Spec_Diagnostic ("stash@{}"))
         = "error: invalid stash spec: stash@{}",
         "invalid stash spec diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Stash_Spec_Out_Of_Range_Diagnostic ("stash@{9}"))
         = "error: stash spec out of range: stash@{9}",
         "stash range diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.Stash.No_Stash_Entries_Diagnostic)
         = "error: no stash entries",
         "no stash entries diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Malformed_Stash_Reflog_Diagnostic)
         = "error: malformed stash reflog",
         "malformed stash reflog diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Inconsistent_Stash_Storage_Diagnostic)
         = "error: inconsistent stash storage",
         "inconsistent stash storage diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Apply_In_Progress_State_Diagnostic)
         = "error: stash apply requires no in-progress merge or replay state",
         "stash apply in-progress diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Stash.Apply_Dirty_Working_Tree_Diagnostic)
         = "error: stash apply requires clean working tree and index",
         "stash apply dirty-tree diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text (Version.Stash.Apply_Conflicts_Diagnostic)
         = "error: stash apply has conflicts",
         "stash apply conflict diagnostic must remain stable");
   end CLI_Unsupported_Feature_Diagnostics_Are_Precise;

   procedure CLI_Command_Boundary_Corruption_Output_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Error_Output_Text ("status failed: corrupt index")
         = "error: status failed: corrupt index",
         "status corruption diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("stage failed: corrupt index")
         = "error: stage failed: corrupt index",
         "stage corruption diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("restore failed: corrupt source tree")
         = "error: restore failed: corrupt source tree",
         "restore corruption diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           ("branch switch failed: corrupt target tree")
         = "error: branch switch failed: corrupt target tree",
         "branch switch corruption diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text ("archive failed: corrupt tree")
         = "error: archive failed: corrupt tree",
         "archive corruption diagnostic must remain stable");
      Assert
        (Version.CLI.Error_Output_Text
           ("fetch failed: corrupt received object")
         = "error: fetch failed: corrupt received object",
         "fetch corruption diagnostic must remain stable");

      Assert_Not_Contains
        (Version.CLI.Error_Output_Text
           ("fetch failed: corrupt received object"),
         "/tmp/",
         "command-boundary corruption diagnostic");
      Assert_Not_Contains
        (Version.CLI.Error_Output_Text ("archive failed: corrupt tree"),
         "Exception",
         "archive corruption diagnostic");
   end CLI_Command_Boundary_Corruption_Output_Is_Frozen;

   procedure CLI_Command_Unavailable_Diagnostics_Are_Precise
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.Availability.No_Repository
         = "no repository found: run 'version init' or move into a working tree",
         "missing-repository diagnostic must be actionable");
      Assert
        (Version.Availability.No_Active_Branch
         = "no active branch: HEAD is detached or unborn",
         "active-branch precondition diagnostic must remain stable");
      Assert
        (Version.Availability.No_Staged_Changes = "no staged changes to save",
         "no-staged-changes diagnostic must remain stable");
      Assert
        (Version.Availability.No_Remote_Configured ("origin")
         = "no remote configured: origin",
         "missing-remote diagnostic must name the remote");
      Assert
        (Version.Availability.No_Upstream_Configured ("main")
         = "no upstream configured for branch: main",
         "missing-upstream diagnostic must name the branch");
      Assert
        (Version.Availability.Repository_Format_Unsupported ("reftable")
         = "repository format unsupported: reftable",
         "repository-format unavailable diagnostic must remain stable");
      Assert
        (Version.Availability.Operation_Unsafe_In_Linked_Worktree
           ("remove primary worktree")
         = "operation unsafe in linked worktree: remove primary worktree",
         "linked-worktree unsafe diagnostic must remain stable");
      Assert
        (Version.Availability.Path_Outside_Worktree ("../x")
         = "path is outside worktree: ../x",
         "outside-worktree diagnostic must name the path");
      Assert
        (Version.Availability.Path_Excluded_By_Sparse_Checkout ("deps/lib")
         = "path is outside sparse checkout: deps/lib",
         "sparse-excluded diagnostic must name the path");
      Assert
        (Version.Availability.Branch_In_Use_By_Worktree ("main")
         = "branch already checked out in another worktree: main",
         "branch-in-use diagnostic must remain stable");
   end CLI_Command_Unavailable_Diagnostics_Are_Precise;

   procedure CLI_Archive_UX_Diagnostics_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Version.CLI.Unsupported_Archive_Format_Text ("xz")
         = "unsupported archive format: xz (supported formats: tar, tar.gz,"
           & " zip; use --format tar, --format tar.gz, or --format zip)",
         "archive --format diagnostic should suggest supported values");
      Assert
        (Version.CLI.Error_Output_Text
           (Version.Archive.Unsupported_Output_Format_Text ("release.tar.xz"))
         = "error: unsupported archive output format: release.tar.xz "
           & "(supported outputs end in .tar, .tar.gz, .tgz, or .zip; "
           & "use --format tar|tar.gz|zip)",
         "archive output diagnostic should suggest supported extensions and --format");
   end CLI_Archive_UX_Diagnostics_Are_Frozen;

   procedure CLI_Doctor_Output_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : Version.Doctor.Doctor_Result;
   begin
      Result.Repository_Status := Version.Doctor.Pass;
      Result.Object_Format_Status := Version.Doctor.Pass;
      Result.Head_Status := Version.Doctor.Pass;
      Result.Index_Status := Version.Doctor.Pass;

      declare
         Text : constant String := Version.Doctor.Result_Text (Result);
      begin
         Assert_Contains (Text, "version doctor", "doctor output header");
         Assert_Contains (Text, "repository: ok", "doctor repository status");
         Assert_Contains (Text, "format: ok", "doctor format status");
         Assert_Contains (Text, "HEAD: ok", "doctor HEAD status");
         Assert_Contains (Text, "index: ok", "doctor index status");
      end;
   end CLI_Doctor_Output_Surface_Is_Frozen;

   procedure CLI_Doctor_Release_Check_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String := Version.Doctor.Release_Check_Text;
   begin
      Assert_Contains
        (Text, "version doctor --release", "doctor release header");
      Assert_Contains
        (Text,
         "tools/bin/check_release_consistency",
         "doctor release consistency gate");
      Assert_Contains
        (Text,
         "tools/bin/check_release_package_selftest",
         "doctor package self-test gate");
   end CLI_Doctor_Release_Check_Surface_Is_Frozen;

   procedure CLI_Config_List_Output_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Help_Text : constant String := Version.CLI.Help.Command_Text ("config");
   begin
      Assert_Contains
        (Version.CLI.Help.Top_Level_Text, "config", "top-level help");
      Assert_Contains
        (Help_Text, "version config list", "config command help");
      Assert_Contains
        (Help_Text, "version config keys", "config command help");
      Assert_Contains
        (Help_Text, "version config get KEY", "config command help");
      Assert_Contains
        (Help_Text, "version config has KEY", "config command help");
      Assert_Contains
        (Help_Text, "version config set KEY VALUE", "config command help");
      Assert_Contains
        (Help_Text, "version config unset KEY", "config command help");
      Assert_Contains (Help_Text, "section.key=value", "config command help");
      Assert_Contains (Help_Text, "keys only", "config command help");
      Assert_Contains
        (Help_Text, "set one local config key", "config command help");
      Assert_Contains
        (Help_Text, "remove one local config key", "config command help");
      Assert_Contains (Help_Text, "read-only", "config command help");
      Assert_Contains (Help_Text, "exit status", "config command help");
   end CLI_Config_List_Output_Surface_Is_Frozen;

   procedure CLI_Remote_List_Output_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Help_Text : constant String := Version.CLI.Help.Command_Text ("remote");
   begin
      Assert_Contains
        (Help_Text, "version remote list", "remote command help");
      Assert_Contains
        (Help_Text, "version remote get-url NAME", "remote command help");
      Assert_Contains
        (Help_Text, "version remote exists NAME", "remote command help");
      Assert_Contains
        (Help_Text, "version remote set-url NAME URL", "remote command help");
      Assert_Contains
        (Help_Text, "version remote rename OLD NEW", "remote command help");
      Assert_Contains
        (Help_Text,
         "version remote prune NAME --dry-run",
         "remote command help");
      Assert_Contains
        (Help_Text, "version remote prune NAME", "remote command help");
      Assert_Contains
        (Help_Text, "prints only the configured URL", "remote command help");
      Assert_Contains
        (Help_Text, "reports existence by exit status", "remote command help");
      Assert_Contains
        (Help_Text, "updates one existing remote URL", "remote command help");
      Assert_Contains
        (Help_Text,
         "remote rename renames an existing remote",
         "remote command help");
      Assert_Contains
        (Help_Text, "stale remote-tracking refs", "remote command help");
      Assert_Contains (Help_Text, "name", "remote command help");
      Assert_Contains (Help_Text, "url", "remote command help");
      Assert
        (Version.Remotes.Remote_Line
           (Version.Remotes.Remote'
              (Name => Ada.Strings.Unbounded.To_Unbounded_String ("origin"),
               Url  =>
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("https://example.invalid/project.git")))
         = "origin"
           & Character'Val (9)
           & "https://example.invalid/project.git",
         "remote list output line must remain tab-separated and stable");
   end CLI_Remote_List_Output_Surface_Is_Frozen;

   procedure CLI_Diff_Cached_Alias_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Help_Text : constant String := Version.CLI.Help.Command_Text ("diff");
   begin
      Assert_Contains
        (Help_Text,
         "",
         "diff help staged form");
      Assert_Contains
        (Help_Text,
         "",
         "diff help cached alias form");
      Assert_Contains
        (Help_Text,
         "",
         "diff help documents cached alias semantics");
   end CLI_Diff_Cached_Alias_Surface_Is_Frozen;

   procedure CLI_Log_Oneline_Surface_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Help_Text : constant String := Version.CLI.Help.Command_Text ("log");
   begin
      Assert_Contains
        (Help_Text, "", "log help oneline form");
      Assert_Contains
        (Help_Text,
         "",
         "log help documents oneline semantics");
      Assert
        (Version.CLI.Expected_Output_Text ("version log [--oneline] [REV]")
         = "error: expected: version log [--oneline] [REV]",
         "log usage diagnostic must mention oneline form");
   end CLI_Log_Oneline_Surface_Is_Frozen;

   procedure CLI_Stash_Show_Pathspec_Routes_To_Selected_Output
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base-a");
      Commit_File (Root, "b.txt", "one" & Character'Val (10), "base-b");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Write_File (Root, "b.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash show stash@{0} a.txt");
      begin
         Assert_Contains (Text, "M a.txt", "stash show pathspec CLI output");
         Assert_Not_Contains (Text, "M b.txt", "stash show pathspec CLI output");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Show_Pathspec_Routes_To_Selected_Output;

   procedure CLI_Stash_Show_Patch_Pathspec_Routes_To_Selected_Output
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base-a");
      Commit_File (Root, "b.txt", "one" & Character'Val (10), "base-b");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Write_File (Root, "b.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String :=
           Run_CLI (Root, "stash show --patch stash@{0} a.txt");
      begin
         Assert_Contains
           (Text, "diff --git a/a.txt b/a.txt", "stash show patch CLI output");
         Assert_Not_Contains
           (Text, "diff --git a/b.txt b/b.txt", "stash show patch CLI output");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Show_Patch_Pathspec_Routes_To_Selected_Output;

   procedure CLI_Stash_Apply_Pathspec_Routes_Selected_Path
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base-a");
      Commit_File (Root, "b.txt", "one" & Character'Val (10), "base-b");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Write_File (Root, "b.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash apply a.txt");
      begin
         Assert_Contains (Text, "applied stash", "stash apply pathspec CLI output");
      end;
      Assert (File_Text (Root, "a.txt") = "two", "CLI stash apply pathspec restores selected path");
      Assert (File_Text (Root, "b.txt") = "one", "CLI stash apply pathspec leaves other path");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Apply_Pathspec_Routes_Selected_Path;

   procedure CLI_Stash_Pop_Pathspec_Routes_Selected_Path
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base-a");
      Commit_File (Root, "b.txt", "one" & Character'Val (10), "base-b");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      Write_File (Root, "b.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash pop stash@{0} a.txt");
      begin
         Assert_Contains (Text, "popped stash stash@{0}", "stash pop pathspec CLI output");
      end;
      Assert (File_Text (Root, "a.txt") = "two", "CLI stash pop pathspec restores selected path");
      Assert (File_Text (Root, "b.txt") = "one", "CLI stash pop pathspec leaves other path");
      Assert
        (Version.Stash.List_Entries (Version.Repository.Open).Is_Empty,
         "CLI stash pop pathspec drops stash after selected apply");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Pop_Pathspec_Routes_Selected_Path;

   procedure CLI_Stash_Apply_Pathspec_No_Match_Feedback
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash apply missing.txt");
      begin
         Assert_Contains
           (Text, "no matching paths in stash", "stash apply no-match CLI output");
         Assert_Not_Contains (Text, "applied stash", "stash apply no-match CLI output");
      end;
      Assert
        (Version.Stash.List_Entries (Version.Repository.Open).Length = 1,
         "CLI stash apply no-match must keep stash");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Apply_Pathspec_No_Match_Feedback;

   procedure CLI_Stash_Pop_Pathspec_No_Match_Feedback_Keeps_Stash
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash pop missing.txt");
      begin
         Assert_Contains
           (Text, "no matching paths in stash", "stash pop no-match CLI output");
         Assert_Not_Contains (Text, "popped stash", "stash pop no-match CLI output");
      end;
      Assert
        (Version.Stash.List_Entries (Version.Repository.Open).Length = 1,
         "CLI stash pop no-match must keep stash");
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Pop_Pathspec_No_Match_Feedback_Keeps_Stash;

   procedure CLI_Stash_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version stash [push [--include-untracked|--include-ignored] [--] [PATH...]] | "
        & "version stash create [--include-untracked|--include-ignored] [--] [PATH...] | "
        & "version stash store [-m MESSAGE] COMMIT | "
        & "version stash list | version stash show [--patch] [stash@{N}] [--] [PATH...] | "
        & "version stash apply [stash@{N}] [--] [PATH...] | "
        & "version stash pop [stash@{N}] [--] [PATH...] | "
        & "version stash branch NAME [stash@{N}] | "
        & "version stash drop [stash@{N}] | version stash clear";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;
   begin
      Check_Usage_Failure
        ("stash --bogus",
         "unknown stash option: --bogus",
         "stash unknown top-level option");
      Check_Usage_Failure
        ("stash frobnicate",
         "unknown stash subcommand: frobnicate",
         "stash unknown subcommand");
      Check_Usage_Failure
        ("stash push --include-untracked --include-ignored",
         "stash push --include-untracked cannot be combined with --include-ignored",
         "stash push conflicting include options");
      Check_Usage_Failure
        ("stash push --bad",
         "unknown stash push option: --bad",
         "stash push unknown option");
      Check_Usage_Failure
        ("stash create --include-ignored --include-ignored",
         "duplicate stash create option: --include-ignored",
         "stash create duplicate option");
      Check_Usage_Failure
        ("stash store",
         "missing stash store commit",
         "stash store missing commit");
      Check_Usage_Failure
        ("stash store -m",
         "stash store -m requires a message",
         "stash store missing message");
      Check_Usage_Failure
        ("stash store --message msg commit",
         "unknown stash store option: --message",
         "stash store unknown option");
      Check_Usage_Failure
        ("stash list extra",
         "stash list takes no arguments",
         "stash list extra argument");
      Check_Usage_Failure
        ("stash show --patch --patch",
         "duplicate stash show option: --patch",
         "stash show duplicate patch");
      Check_Usage_Failure
        ("stash show --bad",
         "unknown stash show option: --bad",
         "stash show unknown option");
      Check_Usage_Failure
        ("stash apply --bad",
         "unknown stash apply option: --bad",
         "stash apply unknown option");
      Check_Usage_Failure
        ("stash pop stash@{0} stash@{1}",
         "too many stash pop stash specs",
         "stash pop too many stash specs");
      Check_Usage_Failure
        ("stash branch",
         "missing stash branch name",
         "stash branch missing name");
      Check_Usage_Failure
        ("stash branch --bad",
         "unknown stash branch option: --bad",
         "stash branch unknown option");
      Check_Usage_Failure
        ("stash branch topic stash@{0} extra",
         "too many stash branch arguments",
         "stash branch too many arguments");
      Check_Usage_Failure
        ("stash drop stash@{0} extra",
         "too many stash drop arguments",
         "stash drop too many arguments");
      Check_Usage_Failure
        ("stash clear extra",
         "stash clear takes no arguments",
         "stash clear extra argument");
   end CLI_Stash_Option_Parsing_Is_Frozen;

   procedure CLI_Rebase_Option_Parsing_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Usage : constant String :=
        "version rebase TARGET | version rebase -i UPSTREAM"
        & " | version rebase --continue | version rebase --abort";

      procedure Check_Usage_Failure
        (Command : String; Detail : String; Context : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Output);
         begin
            Assert
              (Status = Integer (Version.CLI.Usage_Exit_Status),
               Context & " must fail with usage status");
            Assert_Contains (Text, "error: " & Detail, Context & " detail");
            Assert_Contains
              (Text,
               Version.CLI.Expected_Output_Text (Usage),
               Context & " usage");
         end;
      end Check_Usage_Failure;

      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Check_Usage_Failure
        ("rebase",
         "missing rebase target or action",
         "rebase missing target");
      Check_Usage_Failure
        ("rebase --continue extra",
         "too many rebase --continue arguments",
         "rebase continue extra argument");
      Check_Usage_Failure
        ("rebase --abort extra",
         "too many rebase --abort arguments",
         "rebase abort extra argument");
      Check_Usage_Failure
        ("rebase --onto main topic",
         "unknown rebase option: --onto",
         "rebase unknown option");
      Check_Usage_Failure
        ("rebase main extra",
         "too many rebase arguments",
         "rebase too many arguments");

      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Rebase_Option_Parsing_Is_Frozen;

   procedure CLI_Unsupported_Rebase_Modes_Reject_Without_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;

      procedure Check_Unsupported
        (Command           : String;
         Expected_Diagnostic : String;
         Context           : String)
      is
         Output : Ada.Strings.Unbounded.Unbounded_String;
         Status : Integer;
         Repo : constant Version.Repository.Repository_Handle :=
           Version.Repository.Open;
         Head_Before : constant String := Version.Refs.Current_Commit_Id (Repo);
      begin
         Write_File (Root, "topic.txt", "dirty" & Character'Val (10));

         Run_CLI_Capture (Root, Command, Output, Status);
         Assert (Status /= 0, Context & " must fail");
         Assert_Contains
           (Ada.Strings.Unbounded.To_String (Output),
            "error: " & Expected_Diagnostic,
            Context & " diagnostic");
         Assert
           (Version.Refs.Current_Commit_Id (Repo) = Head_Before,
            Context & " must not move HEAD");
         Assert
           (not Version.Rebase_State.State_Exists (Repo),
            Context & " must not create rebase state");
         Assert
           (File_Text (Root, "topic.txt") = "dirty",
            Context & " must preserve dirty worktree file");
      end Check_Unsupported;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "base.txt", "base" & Character'Val (10), "base");
      Commit_File (Root, "topic.txt", "clean" & Character'Val (10), "topic");

      Check_Unsupported
        ("rebase --preserve-merges main",
         Version.Rebase.Merge_Preserving_Rebase_Not_Supported,
         "rebase --preserve-merges");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Unsupported_Rebase_Modes_Reject_Without_Mutation;

   procedure CLI_Unsupported_Pathspec_Magic_Rejected_At_Boundary
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Status  : Integer;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));

      Run_CLI_Capture
        (Root,
         "status " & Shell_Quote (":(bogus)a.txt"),
         Output,
         Status);
      Assert (Status /= 0, "status must reject unsupported pathspec magic");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Output),
         "error: " & Version.Pathspec.Unknown_Magic_Diagnostic ("bogus"),
         "status unsupported pathspec magic diagnostic");

      Run_CLI_Capture
        (Root,
         "diff " & Shell_Quote (":(from-file:paths.txt)a.txt"),
         Output,
         Status);
      Assert (Status /= 0, "diff must reject unsupported from-file pathspec magic");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Output),
         "error: " & Version.Pathspec.Unknown_Magic_Diagnostic
           ("from-file:paths.txt"),
         "diff unsupported pathspec magic diagnostic");

      Run_CLI_Capture
        (Root,
         "stash push " & Shell_Quote (":(from-file:paths.txt)a.txt"),
         Output,
         Status);
      Assert (Status /= 0, "stash push must reject unsupported from-file pathspec magic");
      Assert_Contains
        (Ada.Strings.Unbounded.To_String (Output),
         "error: " & Version.Pathspec.Unknown_Magic_Diagnostic
           ("from-file:paths.txt"),
         "stash push unsupported pathspec magic diagnostic");
      Assert (File_Text (Root, "a.txt") = "two",
              "failed unsupported-magic stash push must preserve dirty file");
      Assert
        (Version.Stash.List_Entries (Version.Repository.Open).Is_Empty,
         "failed unsupported-magic stash push must not create a stash");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Unsupported_Pathspec_Magic_Rejected_At_Boundary;

   procedure CLI_Stash_Malformed_Reflog_Diagnostic_Is_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Status  : Integer;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Ref_Before : constant String :=
           Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root));
      begin
         Version.Test_Support.Write_Text_File
           (Stash_Log_Path (Root), Version.Stash.Malformed_Stash_Reflog_Diagnostic & Character'Val (10));
         Run_CLI_Capture (Root, "stash list", Output, Status);

         Assert
           (Status = Integer (Version.CLI.Command_Failure_Exit_Status),
            "malformed stash reflog CLI must fail with command-failure status");
         Assert
           (Ada.Strings.Unbounded.To_String (Output)
            = Version.CLI.Error_Output_Text
                (Version.Stash.Malformed_Stash_Reflog_Diagnostic),
            "malformed stash reflog CLI diagnostic must remain stable");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "/tmp/",
            "malformed stash reflog CLI diagnostic");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "Exception",
            "malformed stash reflog CLI diagnostic");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root)) = Ref_Before,
            "failed stash list CLI must preserve refs/stash bytes");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Log_Path (Root))
            = Version.Stash.Malformed_Stash_Reflog_Diagnostic,
            "failed stash list CLI must preserve malformed reflog bytes");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Malformed_Reflog_Diagnostic_Is_Frozen;

   procedure CLI_Stash_Broken_Reflog_Chain_Diagnostics_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Status  : Integer;
      procedure Assert_Fails_Without_Mutation (Command, Label : String) is
         Ref_Before : constant String :=
           Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root));
         Log_Before : constant String :=
           Version.Test_Support.Read_Text_File (Stash_Log_Path (Root));
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert
           (Status = Integer (Version.CLI.Command_Failure_Exit_Status),
            Label & " must fail with command-failure status");
         Assert
           (Ada.Strings.Unbounded.To_String (Output)
            = Version.CLI.Error_Output_Text
                (Version.Stash.Inconsistent_Stash_Storage_Diagnostic),
            Label & " diagnostic must remain stable");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "/tmp/", Label & " diagnostic");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "Exception", Label & " diagnostic");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root)) = Ref_Before,
            Label & " must preserve refs/stash bytes");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Log_Path (Root)) = Log_Before,
            Label & " must preserve stash reflog bytes");
         Assert
           (File_Text (Root, "a.txt") = "one",
            Label & " must preserve working-tree content");
      end Assert_Fails_Without_Mutation;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         First_Id : constant String :=
           Version.Objects.To_String (Version.Stash.Resolve_Stash (Version.Repository.Open, "stash@{0}"));
      begin
         Write_File (Root, "a.txt", "three" & Character'Val (10));
         declare
            Ignored : constant String := Run_CLI (Root, "stash push");
            pragma Unreferenced (Ignored);
         begin
            null;
         end;

         declare
            Second_Id : constant String :=
              Version.Objects.To_String (Version.Stash.Resolve_Stash (Version.Repository.Open, "stash@{0}"));
            Broken_Log : constant String :=
              Version.Stash_Test_Support.Broken_Reflog_Chain
                (First_Id => First_Id, Second_Id => Second_Id);
         begin
            Version.Test_Support.Write_Text_File (Stash_Log_Path (Root), Broken_Log);
         end;
      end;

      Assert_Fails_Without_Mutation ("stash list", "stash list broken-chain CLI");
      Assert_Fails_Without_Mutation ("stash show", "stash show broken-chain CLI");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Broken_Reflog_Chain_Diagnostics_Are_Frozen;

   procedure CLI_Stash_Ref_Reflog_Mismatch_Diagnostics_Are_Frozen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Status  : Integer;

      procedure Assert_Fails_Without_Mutation (Command, Label : String) is
         Ref_Before : constant String :=
           Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root));
         Log_Before : constant String :=
           Version.Test_Support.Read_Text_File (Stash_Log_Path (Root));
      begin
         Run_CLI_Capture (Root, Command, Output, Status);
         Assert
           (Status = Integer (Version.CLI.Command_Failure_Exit_Status),
            Label & " must fail with command-failure status");
         Assert
           (Ada.Strings.Unbounded.To_String (Output)
            = Version.CLI.Error_Output_Text
                (Version.Stash.Inconsistent_Stash_Storage_Diagnostic),
            Label & " diagnostic must remain stable");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "/tmp/", Label & " diagnostic");
         Assert_Not_Contains
           (Ada.Strings.Unbounded.To_String (Output), "Exception", Label & " diagnostic");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Ref_Path (Root)) = Ref_Before,
            Label & " must preserve refs/stash bytes");
         Assert
           (Version.Test_Support.Read_Text_File (Stash_Log_Path (Root)) = Log_Before,
            Label & " must preserve stash reflog bytes");
         Assert
           (File_Text (Root, "a.txt") = "one",
            Label & " must preserve working-tree content");
      end Assert_Fails_Without_Mutation;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));
      declare
         Ignored : constant String := Run_CLI (Root, "stash push");
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      declare
         Older_Id : constant Version.Objects.Hex_Object_Id :=
           Version.Stash.Resolve_Stash (Version.Repository.Open, "stash@{0}");
      begin
         Write_File (Root, "a.txt", "three" & Character'Val (10));
         declare
            Ignored : constant String := Run_CLI (Root, "stash push");
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
         Version.Test_Support.Write_Text_File
           (Stash_Ref_Path (Root), Version.Objects.To_String (Older_Id) & Character'Val (10));
      end;

      Assert_Fails_Without_Mutation ("stash show", "stash show mismatch CLI");
      Assert_Fails_Without_Mutation ("stash apply", "stash apply mismatch CLI");
      Assert_Fails_Without_Mutation ("stash drop", "stash drop mismatch CLI");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Ref_Reflog_Mismatch_Diagnostics_Are_Frozen;

   procedure CLI_Stash_Store_Message_Routes_To_List
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "a.txt", "one" & Character'Val (10), "base");
      Write_File (Root, "a.txt", "two" & Character'Val (10));

      declare
         Id : constant String := Run_CLI (Root, "stash create");
      begin
         declare
            Ignored : constant String :=
              Run_CLI (Root, "stash store -m cli-message " & Id);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      end;

      declare
         Text : constant String := Run_CLI (Root, "stash list");
      begin
         Assert_Contains (Text, "cli-message", "stash store message CLI output");
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end CLI_Stash_Store_Message_Routes_To_List;

   procedure CLI_Ls_Files_Filters_By_Pathspec
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      LF      : constant Character := Character'Val (10);
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Commit_File (Root, "README.md", "readme" & LF, "readme");
      Commit_File (Root, "src/a.adb", "a" & LF, "a");
      Commit_File (Root, "src/b.txt", "b" & LF, "b");

      --  No pathspec: every tracked path is listed.
      declare
         Out_All : constant String := Run_CLI (Root, "ls-files");
      begin
         Assert_Contains
           (Out_All, "README.md", "ls-files lists all tracked paths");
         Assert_Contains
           (Out_All, "src/a.adb", "ls-files lists nested tracked paths");
      end;

      --  A directory-prefix pathspec restricts the output to that subtree.
      declare
         Out_Src : constant String := Run_CLI (Root, "ls-files src");
      begin
         Assert_Contains
           (Out_Src, "src/a.adb", "ls-files src includes src paths");
         Assert_Contains
           (Out_Src, "src/b.txt", "ls-files src includes every src path");
         Assert_Not_Contains
           (Out_Src, "README.md", "ls-files src excludes non-src paths");
      end;

      --  The :(icase) magic matches a path despite case differences.
      declare
         Out_Icase : constant String :=
           Run_CLI (Root, "ls-files ':(icase)SRC/A.ADB'");
      begin
         Assert_Contains
           (Out_Icase, "src/a.adb", ":(icase) matches case-insensitively");
         Assert_Not_Contains
           (Out_Icase, "src/b.txt", ":(icase) restricts to the matched path");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Old_Dir then
            Ada.Directories.Set_Directory (Old_Dir);
         end if;
         raise;
   end CLI_Ls_Files_Filters_By_Pathspec;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      Register_Routine
        (T,
         CLI_Ls_Files_Filters_By_Pathspec'Access,
         "CLI: ls-files filters by pathspec (prefix and :(icase))");
      Register_Routine
        (T,
         Help_Knows_Stable_Command_Surface'Access,
         "CLI: help knows stable command surface");

      Register_Routine
        (T,
         Argument_Helper_Stops_Options_At_Double_Dash'Access,
         "CLI: argument helper stops options at double dash");

      Register_Routine
        (T,
         Version_String_Is_Centralized'Access,
         "CLI: version string is centralized");

      Register_Routine
        (T,
         CLI_Help_And_Version_Affordances_Are_Frozen'Access,
         "CLI: help and version affordances are frozen");

      Register_Routine
        (T,
         CLI_Progress_Sink_Is_Available'Access,
         "CLI: progress sink is available");

      Register_Routine
        (T,
         CLI_Error_Text_Preserves_User_Message'Access,
         "CLI: user error text preserves actionable messages");

      Register_Routine
        (T,
         CLI_Exit_Statuses_Are_Frozen'Access,
         "CLI: exit statuses are frozen");

      Register_Routine
        (T,
         CLI_Error_Text_Uses_Stable_Prefix_Payload'Access,
         "CLI: error output prefix and payload are stable");

      Register_Routine
        (T,
         CLI_Error_Text_Preserves_Working_Tree_Read_Race'Access,
         "CLI: working tree read race remains actionable");

      Register_Routine
        (T,
         CLI_Error_Text_Hides_Internal_Exception_Names'Access,
         "CLI: internal exception names are not printed");

      Register_Routine
        (T,
         CLI_Help_Output_Is_Frozen'Access,
         "CLI: top-level help output is frozen");

      Register_Routine
        (T,
         CLI_Command_Help_Output_Is_Frozen'Access,
         "CLI: command help output is frozen");

      Register_Routine
        (T,
         CLI_Completion_Output_Is_Frozen'Access,
         "CLI: bash completion output is frozen");

      Register_Routine
        (T,
         CLI_Man_Page_Output_Is_Frozen'Access,
         "CLI: generated man page output is frozen");

      Register_Routine
        (T,
         CLI_Usage_And_Unknown_Output_Are_Frozen'Access,
         "CLI: unknown and missing-operand output is frozen");

      Register_Routine
        (T,
         CLI_Status_Output_Fragments_Are_Frozen'Access,
         "CLI: status clean and dirty output fragments are frozen");

      Register_Routine
        (T,
         CLI_Status_Porcelain_Output_Is_Frozen'Access,
         "CLI: status porcelain output subset is frozen");

      Register_Routine
        (T,
         CLI_Diff_Cached_Alias_Surface_Is_Frozen'Access,
         "CLI: diff cached alias surface is frozen");

      Register_Routine
        (T,
         CLI_Log_Oneline_Surface_Is_Frozen'Access,
         "CLI: log oneline surface is frozen");

      Register_Routine
        (T,
         CLI_Command_Failure_Output_Is_Frozen_And_Redacted'Access,
         "CLI: failure diagnostics are frozen and redacted");

      Register_Routine
        (T,
         CLI_Stash_Show_Pathspec_Routes_To_Selected_Output'Access,
         "CLI: stash show pathspec routes to selected output");

      Register_Routine
        (T,
         CLI_Stash_Show_Patch_Pathspec_Routes_To_Selected_Output'Access,
         "CLI: stash show patch pathspec routes to selected output");

      Register_Routine
        (T,
         CLI_Stash_Apply_Pathspec_Routes_Selected_Path'Access,
         "CLI: stash apply pathspec routes selected path");

      Register_Routine
        (T,
         CLI_Stash_Pop_Pathspec_Routes_Selected_Path'Access,
         "CLI: stash pop pathspec routes selected path");

      Register_Routine
        (T,
         CLI_Stash_Apply_Pathspec_No_Match_Feedback'Access,
         "CLI: stash apply pathspec no-match feedback");

      Register_Routine
        (T,
         CLI_Stash_Pop_Pathspec_No_Match_Feedback_Keeps_Stash'Access,
         "CLI: stash pop pathspec no-match feedback keeps stash");

      Register_Routine
        (T,
         CLI_Unsupported_Pathspec_Magic_Rejected_At_Boundary'Access,
         "CLI: unsupported pathspec magic rejected at command boundary");
      Register_Routine
        (T,
         CLI_Stash_Option_Parsing_Is_Frozen'Access,
         "CLI: stash option parsing is frozen");

      Register_Routine
        (T,
         CLI_Rebase_Option_Parsing_Is_Frozen'Access,
         "CLI: rebase option parsing is frozen");

      Register_Routine
        (T,
         CLI_Unsupported_Rebase_Modes_Reject_Without_Mutation'Access,
         "CLI: unsupported rebase modes reject without mutation");

      Register_Routine
        (T,
         CLI_Stash_Malformed_Reflog_Diagnostic_Is_Frozen'Access,
         "CLI: stash malformed reflog diagnostic is frozen");

      Register_Routine
        (T,
         CLI_Stash_Broken_Reflog_Chain_Diagnostics_Are_Frozen'Access,
         "CLI: stash broken reflog chain diagnostics are frozen");

      Register_Routine
        (T,
         CLI_Stash_Ref_Reflog_Mismatch_Diagnostics_Are_Frozen'Access,
         "CLI: stash ref/reflog mismatch diagnostics are frozen");

      Register_Routine
        (T,
         CLI_Stash_Store_Message_Routes_To_List'Access,
         "CLI: stash store message routes to list");

      Register_Routine
        (T,
         CLI_Remote_And_Advanced_Command_Help_Is_Frozen'Access,
         "CLI: remote and advanced command help output is frozen");

      Register_Routine
        (T,
         CLI_Remote_And_Feature_Failure_Output_Is_Frozen'Access,
         "CLI: remote and feature failure output is frozen");

      Register_Routine
        (T,
         CLI_Merge_Command_Routes_To_Branch_Integration'Access,
         "CLI: merge command routes to branch integration");

      Register_Routine
        (T,
         CLI_Merge_Upstream_And_Expanded_Options'Access,
         "CLI: merge upstream and expanded options");

      Register_Routine
        (T,
         CLI_Merge_No_Commit_Writes_Git_State_And_Continues'Access,
         "CLI: merge no-commit writes Git state and continues");

      Register_Routine
        (T,
         CLI_Merge_Conflict_Writes_Git_State_And_Auto_Merge'Access,
         "CLI: conflicting merge writes Git state and AUTO_MERGE");

      Register_Routine
        (T,
         CLI_Merge_Conflict_Diagnostics_Are_Git_Style'Access,
         "CLI: merge conflict diagnostics are Git-style");

      Register_Routine
        (T,
         CLI_Branch_Option_Parsing_Is_Frozen'Access,
         "CLI: branch option parsing is frozen");

      Register_Routine
        (T,
         CLI_Read_Only_Command_Parsing_Is_Frozen'Access,
         "CLI: read-only command parsing is frozen");

      Register_Routine
        (T,
         CLI_Status_Ignored_Output_And_Pathspecs'Access,
         "CLI: status ignored output and pathspecs");

      Register_Routine
        (T,
         CLI_Check_Ignore_Output_And_Status'Access,
         "CLI: check-ignore output and status");

      Register_Routine
        (T,
         CLI_Fetch_And_Clone_Option_Parsing_Is_Frozen'Access,
         "CLI: fetch and clone option parsing is frozen");

      Register_Routine
        (T,
         CLI_Push_Option_Parsing_Is_Frozen'Access,
         "CLI: push option parsing is frozen");

      Register_Routine
        (T,
         CLI_Save_Option_Parsing_Is_Frozen'Access,
         "CLI: save option parsing is frozen");

      Register_Routine
        (T,
         CLI_Tag_Create_Option_Parsing_Is_Frozen'Access,
         "CLI: tag create option parsing is frozen");

      Register_Routine
        (T,
         CLI_Submodule_Update_Option_Parsing_Is_Frozen'Access,
         "CLI: submodule update option parsing is frozen");

      Register_Routine
        (T,
         CLI_Cherry_Pick_And_Revert_Option_Parsing_Is_Frozen'Access,
         "CLI: cherry-pick and revert option parsing is frozen");

      Register_Routine
        (T,
         CLI_Maintenance_Option_Parsing_Is_Frozen'Access,
         "CLI: maintenance option parsing is frozen");

      Register_Routine
        (T,
         CLI_Init_Option_Parsing_Is_Frozen'Access,
         "CLI: init option parsing is frozen");

      Register_Routine
        (T,
         CLI_Worktree_Add_Option_Parsing_Is_Frozen'Access,
         "CLI: worktree add option parsing is frozen");

      Register_Routine
        (T,
         CLI_Remote_Option_Parsing_Is_Frozen'Access,
         "CLI: remote option parsing is frozen");

      Register_Routine
        (T,
         CLI_Config_Option_Parsing_Is_Frozen'Access,
         "CLI: config option parsing is frozen");

      Register_Routine
        (T,
         CLI_Sparse_Option_Parsing_Is_Frozen'Access,
         "CLI: sparse option parsing is frozen");

      Register_Routine
        (T,
         CLI_Archive_Option_Parsing_Is_Frozen'Access,
         "CLI: archive option parsing is frozen");

      Register_Routine
        (T,
         CLI_Stage_And_Remove_Option_Parsing_Is_Frozen'Access,
         "CLI: stage and remove option parsing is frozen");

      Register_Routine
        (T,
         CLI_Restore_Option_Parsing_Is_Frozen'Access,
         "CLI: restore option parsing is frozen");

      Register_Routine
        (T,
         CLI_Checkout_Option_Parsing_Is_Frozen'Access,
         "CLI: checkout option parsing is frozen");

      Register_Routine
        (T,
         CLI_Doctor_Output_Surface_Is_Frozen'Access,
         "CLI: doctor output surface is frozen");

      Register_Routine
        (T,
         CLI_Config_List_Output_Surface_Is_Frozen'Access,
         "CLI: config list output surface is frozen");

      Register_Routine
        (T,
         CLI_Remote_List_Output_Surface_Is_Frozen'Access,
         "CLI: remote list output surface is frozen");

      Register_Routine
        (T,
         CLI_Doctor_Release_Check_Surface_Is_Frozen'Access,
         "CLI: doctor release-check surface is frozen");

      Register_Routine
        (T,
         CLI_Unsupported_Feature_Diagnostics_Are_Precise'Access,
         "CLI: unsupported feature diagnostics are precise");

      Register_Routine
        (T,
         CLI_Command_Unavailable_Diagnostics_Are_Precise'Access,
         "CLI: command-unavailable diagnostics are precise");

      Register_Routine
        (T,
         CLI_Archive_UX_Diagnostics_Are_Frozen'Access,
         "CLI: archive UX diagnostics are frozen");

      Register_Routine
        (T,
         CLI_Command_Boundary_Corruption_Output_Is_Frozen'Access,
         "CLI: command-boundary corruption output is frozen");
   end Register_Tests;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Version.CLI");
   end Name;

end Version.CLI.Tests;
