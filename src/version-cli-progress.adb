with Ada.Text_IO;

package body Version.CLI.Progress is

   overriding procedure Message
     (Item : in out Stderr_Sink;
      Text : String)
   is
      pragma Unreferenced (Item);
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Text);
   end Message;

end Version.CLI.Progress;
