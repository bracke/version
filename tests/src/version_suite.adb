with Version.CLI.Tests;
with Version.Hooks.Tests;
with Version.Documentation.Tests;
with CLI_Integration_Tests;

package body Version_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Version.CLI.Tests.Test_Case);
      Result.Add_Test (new Version.Hooks.Tests.Test_Case);
      Result.Add_Test (new Version.Documentation.Tests.Test_Case);
      Result.Add_Test (new CLI_Integration_Tests.Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Version_Suite;
