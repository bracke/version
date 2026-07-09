with Ada.Command_Line;
with Ada.Text_IO;

with Project_Tools.Alire_Manifests.Validation;
with Project_Tools.Files;

--  Validate the two-crate workspace development manifests using the shared
--  project_tools manifest helpers. The version CLI crate and the versionlib
--  library crate each keep local path pins for sibling crates during
--  development; this guards that those intentional pins stay correct (the
--  pins are stripped for publication -- see docs/RELEASE_CHECKLIST.md).
procedure Check_Release_Manifests is
   package Validation renames Project_Tools.Alire_Manifests.Validation;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: check_release_manifests");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  version (CLI crate) pins the library and shared tooling crates.
   --  The version (CLI) crate pins the library and shared tooling crates.
   --  versionlib validates its own dependency pins in versionlib/tools.
   Validation.Require_Workspace_Pin ("alire.toml", "versionlib", "../versionlib");
   Validation.Require_Workspace_Pin
     ("alire.toml", "project_tools", "../project_tools");
   Project_Tools.Files.Require_Contains
     ("alire.toml",
      "gnat_native = ""=15.2.1""",
      "root manifest must pin gnat_native = ""=15.2.1""");
   Project_Tools.Files.Require_Contains
     ("tests/alire.toml",
      "gnat_native = ""=15.2.1""",
      "tests manifest must pin gnat_native = ""=15.2.1""");

   Ada.Text_IO.Put_Line ("release manifest checks passed");
exception
   when Program_Error =>
      --  A Require_* helper already emitted a diagnostic and set the failure
      --  exit status before raising; exit non-zero without a traceback.
      null;
end Check_Release_Manifests;
