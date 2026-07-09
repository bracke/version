with Ada.Command_Line;
with Ada.Exceptions;

package Version.CLI is
   function User_Error_Text
     (E : Ada.Exceptions.Exception_Occurrence)
      return String;

   function Error_Output_Text (Text : String) return String;
   function Expected_Output_Text (Text : String) return String;
   function Unknown_Command_Output_Text (Command : String) return String;

   function Unsupported_Archive_Format_Text (Text : String) return String;

   function Pathspec_No_Files_Text return String;
   function Pathspec_No_Tracked_Paths_Text return String;
   function Pathspec_No_Source_Paths_Text return String;

   function Version_Output_Text return String;

   function Is_Help_Option (Text : String) return Boolean;

   function Is_Command_Help_Request
     (Command : String;
      Option  : String;
      Count   : Natural)
      return Boolean;

   function Usage_Exit_Status return Ada.Command_Line.Exit_Status;

   function Command_Failure_Exit_Status return Ada.Command_Line.Exit_Status;

   procedure Run;
end Version.CLI;
