with Version.CLI;
with Version.Platform;

procedure Main is
begin
   --  Before anything is written: git's output is LF on every host, and
   --  GNAT's Text_IO would otherwise write the host's own terminator.
   Version.Platform.Use_Byte_Exact_Standard_Streams;
   Version.CLI.Run;
end Main;
