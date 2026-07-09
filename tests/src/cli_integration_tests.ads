with AUnit;
with Version.Temp_Fixture;

--  CLI-integration tests that drive the built `version` executable
--  (bin/main). They live in the version crate's test suite because they
--  require the CLI binary; the underlying library behaviour is covered by
--  the per-feature suites in versionlib/tests.
package CLI_Integration_Tests is

   type Test_Case is new Version.Temp_Fixture.Test_Case with null record;

   overriding procedure Register_Tests (T : in out Test_Case);

   overriding function Name (T : Test_Case) return AUnit.Message_String;

end CLI_Integration_Tests;
