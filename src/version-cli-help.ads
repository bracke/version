package Version.CLI.Help is

   function Known_Command (Name : String) return Boolean;

   function Top_Level_Text return String;
   function Command_Text (Name : String) return String;
   function Completion_Bash_Text return String;
   function Man_Page_Text return String;

   procedure Print_Top_Level;
   procedure Print_Command (Name : String);

end Version.CLI.Help;
