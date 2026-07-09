with Ada.Strings.Unbounded;

package Tool_Support is
   function Exists (Path : String) return Boolean;
   function Is_File (Path : String) return Boolean;
   function Is_Directory (Path : String) return Boolean;
   function Read_File (Path : String) return String;
   function First_Line (Path : String) return String;
   function Second_Nonblank_Line (Path : String) return String;
   function Index (Text, Needle : String) return Natural;
   function Starts_With (Value, Prefix : String) return Boolean;
   function Ends_With (Value, Suffix : String) return Boolean;
   function Contains (Path : String; Needle : String) return Boolean;
   function Contains_Case_Insensitive (Path, Needle : String) return Boolean;
   function Has_Line (Path, Text : String) return Boolean;
   function Value_Of (Path, Key : String) return String;
   function Contains_Bad_Marker (Path : String) return Boolean;
   function Find_File (Directory, Name : String) return String;
   function Command_Output (Command : String) return String;
   function Command_Output_Trimmed (Command : String) return String;
   function Run (Command : String) return Integer;
   function Run_Program (Program : String) return Integer;
   function Run_Program_With_Path_Prefix
     (Program     : String;
      Path_Prefix : String) return Integer;
   procedure Run_Checked (Command : String; Message : String);
   function Run_In_Directory
     (Directory   : String;
      Command     : String;
      Quiet       : Boolean := False;
      Output_File : String := "") return Integer;
   procedure Run_In_Directory_Checked
     (Directory : String;
      Command   : String;
      Message   : String;
      Quiet     : Boolean := False);
   function Shell_Quote (Value : String) return String;
   function Join (Left, Right : String) return String;
   function Dirname (Path : String) return String;
   function Basename (Path : String) return String;

   procedure Delete_If_Exists (Path : String);
   procedure Delete_File_If_Exists (Path : String);
   procedure Write_File (Path, Text : String);
   procedure Copy_Tree (Source, Dest : String);
   procedure Copy_File_To (Source, Dest : String);

   procedure Fail (Message : String);
   procedure Require_File (Path : String);
   procedure Require_File (Path : String; Message : String);
   procedure Require_Directory (Path : String; Message : String);
   procedure Require_Contains
     (Path    : String;
      Needle  : String;
      Message : String);
   procedure Require_Command (Command : String);

   package US renames Ada.Strings.Unbounded;
end Tool_Support;
