package Tool_Doc_Guards is
   type Reporter is limited interface;
   procedure Report
     (Item    : in out Reporter;
      Message : String) is abstract;

   procedure Check_No_Stale_Tool_Script_References
     (Item : in out Reporter'Class);

   procedure Require_No_Stale_Tool_Script_References;
end Tool_Doc_Guards;
