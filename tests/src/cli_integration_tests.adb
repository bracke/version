with Ada.Directories;
with AUnit.Assertions;     use AUnit.Assertions;
with AUnit.Test_Cases;     use AUnit.Test_Cases;

with Version.Test_Support;
with Version.Git_Fixtures;
with Version.Init;
with Version.Write;
with Version.Refs;
with Version.Repository;
with Version.Cherry_Pick_State;
with Version.Revert_State;

package body CLI_Integration_Tests is

   LF : constant Character := Character'Val (10);

   procedure Configure_User (Root : String) is
   begin
      Version.Git_Fixtures.Run (Root, "git config user.email test@example.com");
      Version.Git_Fixtures.Run (Root, "git config user.name Test");
      Version.Git_Fixtures.Run (Root, "git config gc.auto 0");
   end Configure_User;

   procedure Write_File (Root, Name, Content : String) is
   begin
      Version.Test_Support.Write_Text_File
        (Version.Test_Support.Join (Root, Name), Content);
   end Write_File;

   function File_Text (Root, Name : String) return String is
   begin
      return Version.Test_Support.Read_Text_File
        (Version.Test_Support.Join (Root, Name));
   end File_Text;

   procedure Cherry_Pick_CLI_Merge_Mainline_Options
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "base.txt", "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Version.Git_Fixtures.Run (Root, "git checkout -b side");
      Write_File (Root, "side.txt", "side" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add side.txt");
      Version.Git_Fixtures.Run (Root, "git commit -m side");
      declare
         Side_Parent : constant String :=
           Version.Refs.Current_Commit_Id (Version.Repository.Open);
      begin
         Version.Git_Fixtures.Run (Root, "git checkout main");
         Write_File (Root, "main.txt", "main" & Character'Val (10));
         Version.Git_Fixtures.Run (Root, "git add main.txt");
         Version.Git_Fixtures.Run (Root, "git commit -m main");
         declare
            Main_Parent : constant String :=
              Version.Refs.Current_Commit_Id (Version.Repository.Open);
         begin
            Version.Git_Fixtures.Run (Root, "git merge --no-ff side -m merge-side");
            declare
               Merge_Commit : constant String :=
                 Version.Refs.Current_Commit_Id (Version.Repository.Open);
            begin
               Version.Git_Fixtures.Run (Root, "git reset --hard " & Main_Parent);
               Version.Git_Fixtures.Run
                 (Root, CLI & " cherry-pick -m 1 " & Merge_Commit);
               Assert (File_Text (Root, "side.txt") = "side",
                       "CLI -m 1 cherry-pick must replay side changes");
               Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");

               Version.Git_Fixtures.Run (Root, "git reset --hard " & Side_Parent);
               Version.Git_Fixtures.Run
                 (Root, CLI & " cherry-pick --mainline 2 " & Merge_Commit);
               Assert (File_Text (Root, "main.txt") = "main",
                       "CLI --mainline 2 cherry-pick must replay main changes");
               Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");
            end;
         end;
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Cherry_Pick_CLI_Merge_Mainline_Options;

   procedure Cherry_Pick_CLI_Invalid_Mainline_No_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "base.txt", "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Version.Git_Fixtures.Run (Root, "git checkout -b side");
      Write_File (Root, "side.txt", "side" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add side.txt");
      Version.Git_Fixtures.Run (Root, "git commit -m side");
      declare
         Side_Parent : constant String :=
           Version.Refs.Current_Commit_Id (Version.Repository.Open);
      begin
         Version.Git_Fixtures.Run (Root, "git checkout main");
         Write_File (Root, "main.txt", "main" & Character'Val (10));
         Version.Git_Fixtures.Run (Root, "git add main.txt");
         Version.Git_Fixtures.Run (Root, "git commit -m main");
         declare
            Original_Head : constant String :=
              Version.Refs.Current_Commit_Id (Version.Repository.Open);
         begin
            Version.Git_Fixtures.Run (Root, "git merge --no-ff side -m merge-side");
            declare
               Merge_Commit : constant String :=
                 Version.Refs.Current_Commit_Id (Version.Repository.Open);
            begin
               Version.Git_Fixtures.Run (Root, "git reset --hard " & Original_Head);
               Version.Git_Fixtures.Run
                 (Root, "! " & CLI & " cherry-pick -m 0 " & Merge_Commit);
               Assert (Version.Refs.Current_Commit_Id (Version.Repository.Open) = Original_Head,
                       "CLI invalid mainline must not move HEAD");
               Assert (not Version.Cherry_Pick_State.State_Exists (Version.Repository.Open),
                       "CLI invalid mainline must not write cherry-pick state");
               Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");

               Version.Git_Fixtures.Run
                 (Root, "! " & CLI & " cherry-pick -m 1 " & Side_Parent);
               Assert (Version.Refs.Current_Commit_Id (Version.Repository.Open) = Original_Head,
                       "CLI mainline on non-merge must not move HEAD");
               Assert (not Version.Cherry_Pick_State.State_Exists (Version.Repository.Open),
                       "CLI mainline on non-merge must not write state");
               Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");
            end;
         end;
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Cherry_Pick_CLI_Invalid_Mainline_No_Mutation;

   procedure Revert_CLI_Merge_Mainline_Options
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "base.txt", "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Version.Git_Fixtures.Run (Root, "git checkout -b side");
      Write_File (Root, "side.txt", "side" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add side.txt");
      Version.Git_Fixtures.Run (Root, "git commit -m side");
      Version.Git_Fixtures.Run (Root, "git checkout main");
      Write_File (Root, "main.txt", "main" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add main.txt");
      Version.Git_Fixtures.Run (Root, "git commit -m main");
      Version.Git_Fixtures.Run (Root, "git merge --no-ff side -m merge-side");
      declare
         Merge_Commit : constant String :=
           Version.Refs.Current_Commit_Id (Version.Repository.Open);
      begin
         Version.Git_Fixtures.Run
           (Root, CLI & " revert -m 1 " & Merge_Commit);
         Assert (not Ada.Directories.Exists
                   (Version.Test_Support.Join (Root, "side.txt")),
                 "CLI -m 1 revert must remove side changes");
         Assert (File_Text (Root, "main.txt") = "main",
                 "CLI -m 1 revert must keep mainline content");
         Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");

         Version.Git_Fixtures.Run (Root, "git reset --hard " & Merge_Commit);
         Version.Git_Fixtures.Run
           (Root, CLI & " revert --mainline 2 " & Merge_Commit);
         Assert (not Ada.Directories.Exists
                   (Version.Test_Support.Join (Root, "main.txt")),
                 "CLI --mainline 2 revert must remove main changes");
         Assert (File_Text (Root, "side.txt") = "side",
                 "CLI --mainline 2 revert must keep side mainline content");
         Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Revert_CLI_Merge_Mainline_Options;

   procedure Revert_CLI_Invalid_Mainline_No_Mutation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "base.txt", "base" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add base.txt");
      Version.Write.Save ("base");
      Write_File (Root, "change.txt", "change" & Character'Val (10));
      Version.Git_Fixtures.Run (Root, "git add change.txt");
      Version.Write.Save ("change");
      declare
         Non_Merge : constant String :=
           Version.Refs.Current_Commit_Id (Version.Repository.Open);
         Original_Head : constant String := Non_Merge;
      begin
         Version.Git_Fixtures.Run (Root, "! " & CLI & " revert -m");
         Assert (Version.Refs.Current_Commit_Id (Version.Repository.Open) = Original_Head,
                 "CLI missing mainline parent must not move HEAD");
         Assert (not Version.Revert_State.State_Exists (Version.Repository.Open),
                 "CLI missing mainline parent must not write revert state");
         Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");

         Version.Git_Fixtures.Run
           (Root, "! " & CLI & " revert -m 1 " & Non_Merge);
         Assert (Version.Refs.Current_Commit_Id (Version.Repository.Open) = Original_Head,
                 "CLI mainline on non-merge revert must not move HEAD");
         Assert (not Version.Revert_State.State_Exists (Version.Repository.Open),
                 "CLI mainline on non-merge revert must not write state");
         Version.Git_Fixtures.Run (Root, "test -z ""$(git status --porcelain)""");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Revert_CLI_Invalid_Mainline_No_Mutation;

   procedure Pull_Fast_Forward_And_Up_To_Date
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Remote  : constant String := Root;
      Work    : constant String := Root & "-work";
   begin
      --  Build the remote with one commit.
      Version.Init.Init (Remote);
      Configure_User (Remote);
      Ada.Directories.Set_Directory (Remote);
      Write_File (Remote, "f.txt", "a" & LF);
      Version.Git_Fixtures.Run (Remote, "git add f.txt");
      Version.Write.Save ("c1");

      --  Clone it (configures origin and upstream tracking).
      Version.Git_Fixtures.Run
        (Old_Dir,
         "git clone --quiet """ & Remote & """ """ & Work & """");
      Configure_User (Work);

      --  Advance the remote.
      Ada.Directories.Set_Directory (Remote);
      Write_File (Remote, "f.txt", "a" & LF & "b" & LF);
      Version.Git_Fixtures.Run (Remote, "git add f.txt");
      Version.Write.Save ("c2");

      --  Pull into the clone: fast-forward to the remote state.
      Version.Git_Fixtures.Run (Work, CLI & " pull");
      Assert
        (File_Text (Work, "f.txt") = "a" & LF & "b",
         "pull must fast-forward the working file to the remote state");

      --  Pulling again must still succeed (already up to date).
      Version.Git_Fixtures.Run (Work, CLI & " pull");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Pull_Fast_Forward_And_Up_To_Date;

   procedure Pull_Without_Upstream_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Raised  : Boolean := False;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "f.txt", "a" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Write.Save ("c1");

      begin
         Version.Git_Fixtures.Run (Root, CLI & " pull");
      exception
         when others =>
            Raised := True;
      end;

      Ada.Directories.Set_Directory (Old_Dir);
      Assert (Raised, "pull without tracking information must fail");
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Pull_Without_Upstream_Fails;

   procedure Plumbing_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "a.txt", "hello" & LF);
      Version.Git_Fixtures.Run (Root, "mkdir -p dir");
      Version.Git_Fixtures.Run (Root, "printf 'b\n' > dir/b.txt");
      Version.Git_Fixtures.Run (Root, "git add a.txt dir/b.txt");
      Version.Write.Save ("first");

      --  Each plumbing command's output must equal git's.
      Version.Git_Fixtures.Run
        (Root, "test ""$(" & CLI & " rev-parse HEAD)"" = ""$(git rev-parse HEAD)""");
      Version.Git_Fixtures.Run
        (Root, "test ""$(" & CLI & " write-tree)"" = ""$(git write-tree)""");
      Version.Git_Fixtures.Run
        (Root, "test ""$(" & CLI & " ls-files)"" = ""$(git ls-files)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " rev-list --count HEAD)"""
         & " = ""$(git rev-list --count HEAD)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " hash-object --stdin < a.txt)"""
         & " = ""$(git hash-object --stdin < a.txt)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " symbolic-ref HEAD)"""
         & " = ""$(git symbolic-ref HEAD)""");
      --  cat-file -e exits 0 for an existing object.
      Version.Git_Fixtures.Run
        (Root, CLI & " cat-file -e ""$(git rev-parse HEAD)""");
      --  ls-tree one-level (subtree shown as a tree entry) and recursive.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " ls-tree HEAD)"" = ""$(git ls-tree HEAD)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " ls-tree -r HEAD)"" = ""$(git ls-tree -r HEAD)""");
      --  for-each-ref (single branch, no tags yet).
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " for-each-ref)"" = ""$(git for-each-ref)""");
      --  for-each-ref richer: add a tag and a second branch, then compare
      --  --format / --sort / glob / --count against git.
      Version.Git_Fixtures.Run (Root, "git tag -a v1 -m release");
      Version.Git_Fixtures.Run (Root, "git branch zzz");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI
         & " for-each-ref --format='%(refname:short) %(objecttype)')"""
         & " = ""$(git for-each-ref"
         & " --format='%(refname:short) %(objecttype)')""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI
         & " for-each-ref --sort=-refname --format='%(refname)')"""
         & " = ""$(git for-each-ref"
         & " --sort=-refname --format='%(refname)')""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " for-each-ref 'refs/heads/*')"""
         & " = ""$(git for-each-ref 'refs/heads/*')""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " for-each-ref --count=1 --format='%(refname)')"""
         & " = ""$(git for-each-ref --count=1 --format='%(refname)')""");
      --  cat-file --batch-check and --batch match git (fed the same oid list).
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git rev-parse HEAD HEAD^{tree} | " & CLI
         & " cat-file --batch-check)"""
         & " = ""$(git rev-parse HEAD HEAD^{tree} |"
         & " git cat-file --batch-check)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git rev-parse HEAD:a.txt | " & CLI
         & " cat-file --batch)"""
         & " = ""$(git rev-parse HEAD:a.txt | git cat-file --batch)""");
      --  update-index --chmod flips the exec bit git reads back from the index.
      Version.Git_Fixtures.Run (Root, CLI & " update-index --chmod=+x a.txt");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git ls-files -s a.txt | cut -d' ' -f1)"" = ""100755""");
      --  update-index --cacheinfo inserts an entry for an existing blob.
      Version.Git_Fixtures.Run
        (Root,
         "B=$(git hash-object a.txt); " & CLI
         & " update-index --add --cacheinfo 100644,$B,injected"
         & " && test ""$(git ls-files -s injected | cut -d' ' -f2)"" = ""$B""");
      --  update-index --force-remove drops a path from the index.
      Version.Git_Fixtures.Run
        (Root,
         CLI & " update-index --force-remove injected"
         & " && test -z ""$(git ls-files injected)""");
      --  read-tree then write-tree reproduces HEAD's tree id.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " read-tree HEAD && " & CLI & " write-tree)"""
         & " = ""$(git rev-parse 'HEAD^{tree}')""");
      --  symbolic-ref set points HEAD at a ref without touching the worktree.
      Version.Git_Fixtures.Run (Root, "git branch other");
      Version.Git_Fixtures.Run (Root, CLI & " symbolic-ref HEAD refs/heads/other");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " symbolic-ref HEAD)"" = ""refs/heads/other""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git symbolic-ref HEAD)"" = ""refs/heads/other""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Plumbing_Matches_Git;

   procedure Push_Multiple_And_Glob_Refspecs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Remote : constant String :=
        Version.Test_Support.Join (Root, "remote.git");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "m.txt", "m" & LF);
      Version.Git_Fixtures.Run (Root, "git add m.txt");
      Version.Write.Save ("main-commit");
      Version.Git_Fixtures.Run (Root, "git checkout -q -b feat1");
      Write_File (Root, "f1.txt", "1" & LF);
      Version.Git_Fixtures.Run (Root, "git add f1.txt");
      Version.Write.Save ("feat1-commit");
      Version.Git_Fixtures.Run (Root, "git checkout -q -b feat2");
      Write_File (Root, "f2.txt", "2" & LF);
      Version.Git_Fixtures.Run (Root, "git add f2.txt");
      Version.Write.Save ("feat2-commit");
      Version.Git_Fixtures.Run (Root, "git checkout -q main");

      Version.Git_Fixtures.Run (Root, "git init -q --bare remote.git");
      Version.Git_Fixtures.Run
        (Root, "git remote add origin " & Remote);

      --  Two explicit refspecs in one invocation update both remote refs.
      Version.Git_Fixtures.Run
        (Root,
         CLI & " push origin main:refs/heads/main"
         & " feat1:refs/heads/feat1");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git --git-dir=" & Remote
         & " rev-parse refs/heads/main)"" = ""$(git rev-parse main)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git --git-dir=" & Remote
         & " rev-parse refs/heads/feat1)"" = ""$(git rev-parse feat1)""");

      --  A wildcard refspec pushes every matching local head (incl. feat2).
      Version.Git_Fixtures.Run
        (Root, CLI & " push origin 'refs/heads/*:refs/heads/*'");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git --git-dir=" & Remote
         & " rev-parse refs/heads/feat2)"" = ""$(git rev-parse feat2)""");
      --  The remote's heads now match the local heads exactly.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git --git-dir=" & Remote
         & " for-each-ref --format='%(refname) %(objectname)' refs/heads/)"""
         & " = ""$(git for-each-ref --format='%(refname) %(objectname)'"
         & " refs/heads/)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Push_Multiple_And_Glob_Refspecs;

   procedure Credential_Helper_Protocol_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Helper : constant String := Version.Test_Support.Join (Root, "helper.sh");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      --  Helper: answers get with fixed credentials, logs store/erase.
      Write_File
        (Root, "helper.sh",
         "#!/bin/sh" & LF
         & "case ""$1"" in" & LF
         & "  get) echo username=alice; echo password=s3cret ;;" & LF
         & "  store) echo STORE >> log ;;" & LF
         & "  erase) echo ERASE >> log ;;" & LF
         & "esac" & LF);
      Version.Git_Fixtures.Run (Root, "chmod +x helper.sh");
      Version.Git_Fixtures.Run
        (Root, "git config credential.helper " & Helper);

      --  fill output is byte-identical to git's.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(printf 'protocol=https\nhost=example.com\n' | " & CLI
         & " credential fill)"""
         & " = ""$(printf 'protocol=https\nhost=example.com\n'"
         & " | git credential fill)""");

      --  approve invokes the helper's store, reject invokes erase.
      Version.Git_Fixtures.Run
        (Root,
         ": > log; printf 'protocol=https\nhost=example.com\nusername=alice\n"
         & "password=s3cret\n' | " & CLI & " credential approve;"
         & " grep -q STORE log");
      Version.Git_Fixtures.Run
        (Root,
         ": > log; printf 'protocol=https\nhost=example.com\n' | " & CLI
         & " credential reject; grep -q ERASE log");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Credential_Helper_Protocol_Matches_Git;

   overriding procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Plumbing_Matches_Git'Access,
         "Plumbing: rev-parse/write-tree/ls-files/hash-object match git");
      Register_Routine
        (T, Credential_Helper_Protocol_Matches_Git'Access,
         "Credential: fill/approve/reject drive the configured helper");
      Register_Routine
        (T, Push_Multiple_And_Glob_Refspecs'Access,
         "Push: multiple refspecs and wildcard refspec update the remote");
      Register_Routine
        (T, Pull_Fast_Forward_And_Up_To_Date'Access,
         "Pull: fast-forward then already up to date");
      Register_Routine
        (T, Pull_Without_Upstream_Fails'Access,
         "Pull: without tracking information fails");
      Register_Routine
        (T, Cherry_Pick_CLI_Merge_Mainline_Options'Access,
         "Cherry-pick CLI: replays merge commits with mainline options");
      Register_Routine
        (T, Cherry_Pick_CLI_Invalid_Mainline_No_Mutation'Access,
         "Cherry-pick CLI: invalid mainline rejects without mutation");
      Register_Routine
        (T, Revert_CLI_Merge_Mainline_Options'Access,
         "Revert CLI: replays merge commits with mainline options");
      Register_Routine
        (T, Revert_CLI_Invalid_Mainline_No_Mutation'Access,
         "Revert CLI: invalid mainline rejects without mutation");
   end Register_Tests;

   overriding function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("CLI Integration");
   end Name;

end CLI_Integration_Tests;
