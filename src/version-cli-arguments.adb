with Ada.Strings.Unbounded;

package body Version.CLI.Arguments is

   use Ada.Strings.Unbounded;

   function Empty return Argument_List is
      Result : Argument_List;
   begin
      return Result;
   end Empty;

   procedure Append
     (Args  : in out Argument_List;
      Value : String)
   is
   begin
      Args.Items.Append (To_Unbounded_String (Value));
   end Append;

   function Count
     (Args : Argument_List)
      return Natural
   is
   begin
      return Natural (Args.Items.Length);
   end Count;

   function Positional
     (Args  : Argument_List;
      Index : Positive)
      return String
   is
   begin
      return To_String (Args.Items.Element (Index));
   end Positional;

   function Has_Option
     (Args : Argument_List;
      Name : String)
      return Boolean
   is
   begin
      if Args.Items.Is_Empty then
         return False;
      end if;

      for I in Args.Items.First_Index .. Args.Items.Last_Index loop
         exit when To_String (Args.Items.Element (I)) = "--";

         if To_String (Args.Items.Element (I)) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Has_Option;

   function Double_Dash_Index
     (Args : Argument_List)
      return Natural
   is
   begin
      if Args.Items.Is_Empty then
         return 0;
      end if;

      for I in Args.Items.First_Index .. Args.Items.Last_Index loop
         if To_String (Args.Items.Element (I)) = "--" then
            return Natural (I);
         end if;
      end loop;

      return 0;
   end Double_Dash_Index;

end Version.CLI.Arguments;
