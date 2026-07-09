with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Text;
with Project_Tools.Files;
with Project_Tools.Alire_Manifests.Validation;

--  Produce publishable, pin-free Alire manifests for the two-crate workspace.
--
--  Each crate's checked-in alire.toml keeps local [[pins]] for sibling crates
--  during development; those pins must not be published. This tool writes a
--  pin-free copy of each manifest under .release/staged/<crate>/alire.toml and
--  validates it with project_tools, making the documented publish step
--  executable. The dev manifests are left untouched.
procedure Stage_Release is
   use Ada.Strings.Unbounded;

   package Validation renames Project_Tools.Alire_Manifests.Validation;

   Staging_Root : constant String := ".release/staged";

   --  Drop every blank-line-delimited block that contains a [[pins]] table
   --  (its leading comments are part of the same block and go with it).
   function Strip_Pins (Content : String) return String is
      Result : Unbounded_String;
      Block  : Unbounded_String;
      First  : Boolean := True;

      procedure End_Block is
      begin
         if Length (Block) > 0 then
            if Project_Tools.Text.Index (To_String (Block), "[[pins]]") = 0 then
               if not First then
                  Append (Result, ASCII.LF);
               end if;
               Append (Result, Block);
               First := False;
            end if;
            Block := Null_Unbounded_String;
         end if;
      end End_Block;

      Start : Positive := Content'First;
   begin
      for I in Content'Range loop
         if Content (I) = ASCII.LF then
            if I = Start then
               End_Block;
            else
               Append (Block, Content (Start .. I));
            end if;
            Start := I + 1;
         end if;
      end loop;
      if Start <= Content'Last then
         Append (Block, Content (Start .. Content'Last));
         Append (Block, ASCII.LF);
      end if;
      End_Block;
      return To_String (Result);
   end Strip_Pins;

   procedure Stage (Crate_Dir : String; Name : String) is
      Source : constant String :=
        Project_Tools.Files.Join (Crate_Dir, "alire.toml");
      Dest_Dir : constant String :=
        Project_Tools.Files.Join (Staging_Root, Name);
      Dest : constant String := Project_Tools.Files.Join (Dest_Dir, "alire.toml");
      Stripped : constant String :=
        Strip_Pins
          (To_String (Project_Tools.Text.Read_Text_File (Source)));
   begin
      Ada.Directories.Create_Path (Dest_Dir);
      Project_Tools.Files.Write_Text_File (Dest, Stripped);
      Validation.Require_Pin_Free_Crate_Manifest (Dest, Name);
      Ada.Text_IO.Put_Line ("staged pin-free manifest: " & Dest);
   end Stage;
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: stage_release");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Stages the version (CLI) crate only; versionlib stages itself from
   --  versionlib/tools. (Publish versionlib first, then version.)
   Stage (".", "version");
   Ada.Text_IO.Put_Line ("release manifests staged");
exception
   when Program_Error =>
      --  A validation helper already emitted the diagnostic and set the
      --  failure exit status before raising; exit non-zero without a traceback.
      null;
end Stage_Release;
