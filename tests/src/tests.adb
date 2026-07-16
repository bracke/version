with Ada.Environment_Variables;
with AUnit.Reporter.Text;
with AUnit.Run;
with All_Suites;

procedure Tests is
   procedure Runner is new AUnit.Run.Test_Runner (All_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   --  Run hermetically: the CLI reads git's full system/global config stack,
   --  and the CLI-integration tests spawn bin/main (and real git) as
   --  subprocesses that inherit this environment, so pin the config scope to
   --  keep behaviour reproducible regardless of the developer's ~/.gitconfig.
   --  Real git in fixtures still needs init.defaultBranch=main, injected via
   --  GIT_CONFIG_COUNT (git honours it; Version.Config does not read that
   --  channel, so version's own config view stays clean).
   Ada.Environment_Variables.Set ("GIT_CONFIG_NOSYSTEM", "1");
   Ada.Environment_Variables.Set ("GIT_CONFIG_GLOBAL", "/dev/null");
   Ada.Environment_Variables.Clear ("GIT_CONFIG_SYSTEM");
   Ada.Environment_Variables.Set ("GIT_CONFIG_COUNT", "1");
   Ada.Environment_Variables.Set ("GIT_CONFIG_KEY_0", "init.defaultBranch");
   Ada.Environment_Variables.Set ("GIT_CONFIG_VALUE_0", "main");
   Runner (Reporter);
end Tests;