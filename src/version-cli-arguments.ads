with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Version.CLI.Arguments is

   use Ada.Strings.Unbounded;

   type Argument_List is private;

   function Empty return Argument_List;

   procedure Append
     (Args  : in out Argument_List;
      Value : String);

   function Count
     (Args : Argument_List)
      return Natural;

   function Positional
     (Args  : Argument_List;
      Index : Positive)
      return String;

   function Has_Option
     (Args : Argument_List;
      Name : String)
      return Boolean;

   function Double_Dash_Index
     (Args : Argument_List)
      return Natural;

private

   package Argument_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   type Argument_List is record
      Items : Argument_Vectors.Vector;
   end record;

end Version.CLI.Arguments;
