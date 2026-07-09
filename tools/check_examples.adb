with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

with Tool_Support;

procedure Check_Examples is
   Root : constant String := Ada.Directories.Current_Directory;
   Tmp  : constant String := "/tmp/version-example-smoke-ada";

   procedure Run_In (Directory, Command : String; Quiet : Boolean := False) is
   begin
      Tool_Support.Run_In_Directory_Checked
        (Directory => Directory,
         Command   => Command,
         Message   => "example smoke command failed: " & Command,
         Quiet     => Quiet);
   end Run_In;

   procedure Basic_Workflow is
      Work : constant String := Tool_Support.Join (Tmp, "basic");
      Repo : constant String := Tool_Support.Join (Work, "demo");
   begin
      Ada.Directories.Create_Path (Work);
      Run_In (Work, "version init demo");
      Tool_Support.Write_File (Tool_Support.Join (Repo, "hello.txt"), "hello" & ASCII.LF);
      Run_In (Repo, "version stage hello.txt");
      Run_In (Repo, "version save " & Tool_Support.Shell_Quote ("initial"));
      Run_In (Repo, "version status", Quiet => True);
      Run_In (Repo, "version log", Quiet => True);
      Run_In (Repo, "version verify");
      Run_In (Repo, "git fsck --strict", Quiet => True);
   end Basic_Workflow;

   procedure Local_Remote_Workflow is
      Work   : constant String := Tool_Support.Join (Tmp, "local");
      Source : constant String := Tool_Support.Join (Work, "source");
      Clone  : constant String := Tool_Support.Join (Work, "clone");
   begin
      Ada.Directories.Create_Path (Work);
      Run_In (Work, "version init --bare remote.git");
      Run_In (Work, "version init source");
      Tool_Support.Write_File (Tool_Support.Join (Source, "hello.txt"), "hello" & ASCII.LF);
      Run_In (Source, "version stage hello.txt");
      Run_In (Source, "version save " & Tool_Support.Shell_Quote ("initial"));
      Run_In (Source, "version remote add origin ../remote.git");
      Run_In (Source, "version push origin main");
      Run_In (Work, "version clone remote.git clone");
      Run_In (Clone, "version fetch origin");
      Run_In (Clone, "version status", Quiet => True);
      Run_In (Clone, "git fsck --strict", Quiet => True);
   end Local_Remote_Workflow;

   procedure Worktree_Workflow is
      Work    : constant String := Tool_Support.Join (Tmp, "worktree");
      Repo    : constant String := Tool_Support.Join (Work, "demo");
      Feature : constant String := Tool_Support.Join (Work, "feature");
   begin
      Ada.Directories.Create_Path (Work);
      Run_In (Work, "version init demo");
      Tool_Support.Write_File (Tool_Support.Join (Repo, "base.txt"), "base" & ASCII.LF);
      Run_In (Repo, "version stage base.txt");
      Run_In (Repo, "version save " & Tool_Support.Shell_Quote ("base"));
      Run_In (Repo, "version branch create feature");
      Run_In (Repo, "version worktree add ../feature feature");
      Run_In (Repo, "version worktree list", Quiet => True);
      Tool_Support.Write_File (Tool_Support.Join (Feature, "feature.txt"), "feature" & ASCII.LF);
      Run_In (Feature, "version stage feature.txt");
      Run_In (Feature, "version save " & Tool_Support.Shell_Quote ("feature work"));
      Run_In (Feature, "version status", Quiet => True);
   end Worktree_Workflow;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: check_examples");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Tool_Support.Require_Command ("version");
   Tool_Support.Require_Command ("git");

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Directories.Create_Path (Tmp);

   Basic_Workflow;
   Local_Remote_Workflow;
   Worktree_Workflow;

   Tool_Support.Delete_If_Exists (Tmp);
   Ada.Text_IO.Put_Line ("example smoke tests passed: " & Tool_Support.Join (Root, "examples"));
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when others =>
      Tool_Support.Delete_If_Exists (Tmp);
      raise;
end Check_Examples;
