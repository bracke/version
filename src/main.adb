with Interfaces.C;

with Version.CLI;
with Version.Platform;

procedure Main is
   --  MinGW's C startup expands a wildcard in argv before main() sees it, so
   --  `grep foo '*.txt'` arrived already replaced by the names in the current
   --  directory -- where git matches that pathspec across directories, and
   --  answered with two more files. git turns the same knob off in
   --  compat/mingw.c. Nothing reads it on a host that does not glob.
   --  Both spellings, because the two MinGW runtimes read different ones:
   --  the older one consults _CRT_glob, mingw-w64 consults _dowildcard.
   --  Each is the sanctioned user-side override in its own runtime, and the
   --  other is then simply a variable nothing reads.
   CRT_Glob : Interfaces.C.int := 0
     with Export, Convention => C, External_Name => "_CRT_glob";
   pragma Warnings (Off, CRT_Glob);

   Do_Wildcard : Interfaces.C.int := 0
     with Export, Convention => C, External_Name => "_dowildcard";
   pragma Warnings (Off, Do_Wildcard);
begin
   --  Before anything is written: git's output is LF on every host, and
   --  GNAT's Text_IO would otherwise write the host's own terminator.
   Version.Platform.Use_Byte_Exact_Standard_Streams;
   Version.CLI.Run;
end Main;
