with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
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

   --  Regression: `version shortlog` must match `git shortlog` byte-for-byte
   --  across default, -s, -n, and bundled -sn -- exercising within-group
   --  subject order (oldest first) and the -n count-then-name tie-break.
   procedure Shortlog_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      procedure Commit (Name, Subject : String) is
      begin
         Version.Git_Fixtures.Run
           (Root,
            "GIT_AUTHOR_NAME='" & Name & "' GIT_AUTHOR_EMAIL='"
            & Name & "@x' GIT_COMMITTER_NAME='" & Name
            & "' GIT_COMMITTER_EMAIL='" & Name & "@x'"
            & " git commit -q --allow-empty -m '" & Subject & "'");
      end Commit;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      --  Alice x2, Bob x2 (count tie), Carol x1 -> exercises the tie-break.
      Commit ("Alice", "add feature");
      Commit ("Bob", "fix bug");
      Commit ("Alice", "another thing");
      Commit ("Carol", "z last");
      Commit ("Bob", "second bob");

      declare
         procedure Check (Opt : String) is
         begin
            Version.Git_Fixtures.Run
              (Root,
               "test ""$(" & CLI & " shortlog " & Opt & " HEAD)"""
               & " = ""$(git shortlog " & Opt & " HEAD)""");
         end Check;
      begin
         Check ("");
         Check ("-s");
         Check ("-n");
         Check ("-sn");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Shortlog_Matches_Git;

   --  Regression: `log` must be a full reachability walk over ALL parents in
   --  commit-date order, not a first-parent-only follow (which silently
   --  dropped every commit reachable only through a merge's later parent).
   --  Also covers the "Merge: <p1> <p2>" header and git's rule that merge
   --  commits emit no diff under --stat/-p by default.
   procedure Log_Merge_History_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      D : constant String :=
        "GIT_AUTHOR_DATE='1700000000 +0000'"
        & " GIT_COMMITTER_DATE='1700000000 +0000' ";
      procedure Oracle (Cmd : String) is
      begin
         Version.Git_Fixtures.Run
           (Root,
            "test ""$(" & CLI & " " & Cmd & ")"" = ""$(git " & Cmd & ")""");
      end Oracle;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "a", "1" & LF);
      Version.Git_Fixtures.Run (Root, "git add a && " & D & "git commit -q -m c1");
      Write_File (Root, "a", "2" & LF);
      Version.Git_Fixtures.Run (Root, D & "git commit -qam c2");
      --  Branch off c1 and add a commit reachable ONLY via the merge's
      --  second parent.
      Version.Git_Fixtures.Run (Root, "git checkout -q -B topic HEAD~1");
      Write_File (Root, "btopic", "t" & LF);
      Version.Git_Fixtures.Run
        (Root, "git add btopic && " & D & "git commit -q -m t1_on_topic");
      Version.Git_Fixtures.Run (Root, "git checkout -q main");
      Version.Git_Fixtures.Run (Root, D & "git merge -q --no-ff topic -m M_merge");
      Write_File (Root, "a", "3" & LF);
      Version.Git_Fixtures.Run (Root, D & "git commit -qam after_merge");

      Oracle ("log --oneline");
      Oracle ("log");
      Oracle ("log --stat");
      Oracle ("log -p");
      Oracle ("log --format='%H|%P|%s'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Log_Merge_History_Matches_Git;

   --  Regression: `apply --index` must honour git's precondition that the
   --  working-tree file already matches the index -- on a dirty worktree git
   --  refuses (exit 1) and changes nothing; version used to apply and stage
   --  anyway, silently clobbering the worktree/index. --cached is exempt.
   procedure Apply_Index_Precondition_Matches_Git
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
      Write_File (Root, "f", "a" & LF & "b" & LF & "c" & LF);
      Version.Git_Fixtures.Run (Root, "git add f && git commit -qm c1");
      --  A patch that changes b -> B, saved to a file; restore f afterward.
      Version.Git_Fixtures.Run
        (Root,
         "printf 'a\nB\nc\n' > f && git diff > pf.diff && git checkout -q -- f");

      --  Dirty worktree: version must REFUSE (non-zero), leave nothing staged,
      --  and leave the working tree untouched.
      Version.Git_Fixtures.Run
        (Root,
         "printf 'a\nb\nc\nDIRTY\n' > f; "
         & "if " & CLI & " apply --index pf.diff >/dev/null 2>&1;"
         & " then exit 1; fi; "
         & "test -z ""$(git diff --cached --name-only)""; "
         & "test ""$(cat f)"" = ""$(printf 'a\nb\nc\nDIRTY\n')""");

      --  Clean worktree: the same patch must apply and stage (exit 0).
      Version.Git_Fixtures.Run
        (Root,
         "git checkout -q -- f && " & CLI & " apply --index pf.diff && "
         & "test -n ""$(git diff --cached --name-only)""");

      --  --cached is exempt from the precondition even on a dirty worktree.
      Version.Git_Fixtures.Run
        (Root,
         "git reset -q && printf 'a\nb\nc\nDIRTY2\n' > f && "
         & CLI & " apply --cached pf.diff && "
         & "test -n ""$(git diff --cached --name-only)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Apply_Index_Precondition_Matches_Git;

   --  Regression: `clean -fd` must NOT delete a nested git repository (a
   --  directory holding a `.git`); git preserves it and needs -ff. version
   --  used to remove it -- silent data loss of a whole embedded repo.
   procedure Clean_Nested_Repo_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      procedure Rebuild is
      begin
         Version.Git_Fixtures.Run
           (Root,
            "rm -rf sub plain && mkdir sub && ( cd sub && git init -q"
            & " && printf y > inner ) && mkdir plain && printf z > plain/u");
      end Rebuild;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "tracked", "x" & LF);
      Version.Git_Fixtures.Run (Root, "git add tracked && git commit -qm c1");

      --  Dry-run output must match git byte-for-byte (nested repo absent).
      --  git localizes "Would remove", so pin the locale for the comparison.
      Rebuild;
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C; test ""$(" & CLI & " clean -fdn)"""
         & " = ""$(git clean -fdn)""");

      --  A real -fd preserves the nested repo, removing only the plain dir.
      Rebuild;
      Version.Git_Fixtures.Run
        (Root,
         CLI & " clean -fd >/dev/null && test -d sub/.git && test ! -d plain");

      --  Doubled force (-ff) does remove the nested repo, as git does.
      Rebuild;
      Version.Git_Fixtures.Run
        (Root, CLI & " clean -ffd >/dev/null && test ! -e sub");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Clean_Nested_Repo_Matches_Git;

   --  Regression: `archive` streams the tar to stdout (git parity) instead of
   --  writing an archive.tar file, and the tar is byte-identical to git's --
   --  entry order (recursive tree order, not dirs-first), mode (tar.umask),
   --  mtime (commit time), owner (root), and 20-block padding all match.
   procedure Archive_Byte_Identical_To_Git
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
      --  A tree exercising nested dirs, an executable, and a symlink.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; mkdir -p d/e sub; printf 'r\n' > r;"
         & " printf 'x\n' > d/e/z; printf 'y\n' > d/nested;"
         & " printf '#!/bin/sh\n' > ex; chmod +x ex; ln -s r lnk;"
         & " printf q > sub/a; git add -A; git update-index --chmod=+x ex;"
         & " git commit -qm c1");

      --  Streamed (no --output): byte-identical to git, and no stray file.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; " & CLI & " archive HEAD > v.tar; git archive HEAD > g.tar;"
         & " cmp -s g.tar v.tar; test ! -e archive.tar");

      --  With a multi-level --prefix, also byte-identical.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; " & CLI & " archive HEAD --prefix p/q/ > v2.tar;"
         & " git archive --prefix=p/q/ HEAD > g2.tar; cmp -s g2.tar v2.tar");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Archive_Byte_Identical_To_Git;

   --  Regression: `notes add` must not clobber an existing note. git errors
   --  (exit 1) and keeps the old note unless -f is given, and announces the
   --  overwrite on stderr when it is. version had no -f and silently replaced.
   procedure Notes_Add_Overwrite_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);
      --  Identical content and pinned dates give both repos the same commit
      --  id, so the two tools' messages compare byte-for-byte. git localizes
      --  them, hence LC_ALL=C throughout.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; for r in g v; do mkdir -p $r; ( cd $r;"
         & " git init -q .; git config user.email test@example.com;"
         & " git config user.name Test; printf 'x\n' > f; git add f;"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'"
         & " git commit -qm c1 ); done;"
         & " test ""$(git -C g rev-parse HEAD)"""
         & " = ""$(git -C v rev-parse HEAD)""");

      --  Adding over an existing note: same stderr, same exit 1, note intact.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C; ( cd g && git notes add -m first ) &&"
         & " ( cd v && " & CLI & " notes add -m first ) && { "
         & " ge=0; ( cd g; git notes add -m second ) 2> g.err || ge=$?;"
         & " ve=0; ( cd v; " & CLI & " notes add -m second ) 2> v.err || ve=$?;"
         & " test $ge -eq 1 && test $ve -eq 1 && cmp -s g.err v.err &&"
         & " test ""$(git -C g notes show)"" = first &&"
         & " test ""$(git -C v notes show)"" = first; }");

      --  With -f both overwrite, exit 0, and report the clobber identically.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C; { "
         & " gf=0; ( cd g; git notes add -f -m third ) 2> gf.err || gf=$?;"
         & " vf=0; ( cd v; " & CLI & " notes add -f -m third ) 2> vf.err"
         & " || vf=$?;"
         & " test $gf -eq 0 && test $vf -eq 0 && cmp -s gf.err vf.err &&"
         & " test ""$(git -C g notes show)"" = third &&"
         & " test ""$(git -C v notes show)"" = third; }");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Notes_Add_Overwrite_Matches_Git;

   --  Regression: fast-import stream parity. A commit that omits `author`
   --  defaults it to the committer (version wrote a literal empty `author `
   --  line -> corrupt commit), and an `M` line's short octal modes (644/755)
   --  mean regular files -- version read them as gitlinks (160000), silently
   --  importing every file as a broken submodule.
   procedure Fast_Import_Stream_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      --  No `author` line, and the short mode spellings git documents.
      Stream : constant String :=
        "printf 'blob\nmark :1\ndata 2\nx\n\nblob\nmark :2\ndata 2\ny\n\n"
        & "commit refs/heads/master\nmark :3\n"
        & "committer Test <test@example.com> 1700000000 +0000\n"
        & "data 3\nc1\nM 644 :1 f\nM 755 :2 s\n\n' > s.fi;";
      procedure Import (Dir, Tool : String) is
      begin
         Version.Git_Fixtures.Run
           (Root,
            "set -e; export LC_ALL=C; rm -rf " & Dir & "; mkdir " & Dir
            & "; ( cd " & Dir & "; git init -q .;"
            & " git config user.email test@example.com;"
            & " git config user.name Test; " & Tool & " < ../s.fi >/dev/null )");
      end Import;
   begin
      Ada.Directories.Set_Directory (Root);
      Version.Git_Fixtures.Run (Root, "set -e; " & Stream);
      Import ("g", "git fast-import --quiet");
      Import ("v", CLI & " fast-import");

      --  The whole commit must be byte-identical: same modes, same tree,
      --  same author-defaulted-to-committer, therefore the same commit id.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C;"
         & " test ""$(git -C g ls-tree refs/heads/master)"""
         & " = ""$(git -C v ls-tree refs/heads/master)"" &&"
         & " test ""$(git -C g cat-file -p refs/heads/master)"""
         & " = ""$(git -C v cat-file -p refs/heads/master)"" &&"
         & " test ""$(git -C g rev-parse refs/heads/master)"""
         & " = ""$(git -C v rev-parse refs/heads/master)""");

      --  The author line is really the committer, not an empty `author `.
      Version.Git_Fixtures.Run
        (Root,
         "git -C v cat-file -p refs/heads/master |"
         & " grep -qx 'author Test <test@example.com> 1700000000 +0000'");

      --  A mode outside the set git accepts is refused, not imported.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C;"
         & " sed 's/M 644 :1 f/M 999 :1 f/' s.fi > bad.fi;"
         & " rm -rf b; mkdir b; ( cd b; git init -q .;"
         & " if " & CLI & " fast-import < ../bad.fi >/dev/null 2>&1;"
         & " then exit 1; fi;"
         & " test -z ""$(git rev-parse --quiet --verify refs/heads/master)"" )");

      --  `inline` file data (content in the stream, no mark) imports to the
      --  same commit as git's; version used to read `inline` as an object id.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; printf 'commit refs/heads/master\n"
         & "committer Test <test@example.com> 1700000000 +0000\n"
         & "data 3\nc1\nM 644 inline f\ndata 2\nx\n"
         & "M 755 inline s\ndata 2\ny\n\n' > s.fi");
      Import ("gi", "git fast-import --quiet");
      Import ("vi", CLI & " fast-import");
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C;"
         & " test ""$(git -C gi ls-tree refs/heads/master)"""
         & " = ""$(git -C vi ls-tree refs/heads/master)"" &&"
         & " test ""$(git -C gi rev-parse refs/heads/master)"""
         & " = ""$(git -C vi rev-parse refs/heads/master)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fast_Import_Stream_Matches_Git;

   --  Regression: `checkout <branch>` must attach HEAD to the branch, not
   --  detach at the raw commit. version used to always write the bare commit
   --  id into HEAD, so any commit made after `checkout <branch>` was orphaned
   --  (the branch never moved). A non-branch revision still detaches.
   procedure Checkout_Branch_Attaches_Head_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);
      --  Two identical repos, each with two commits and a branch `feature`
      --  at the first. Pinned dates keep the commit ids equal across g and v.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; for r in g v; do"
         & " mkdir -p $r; ( cd $r; git init -q .;"
         & " git config user.email test@example.com;"
         & " git config user.name Test; printf 'a\n' > f; git add f;"
         & " git commit -qm c1; printf 'b\n' >> f; git add f;"
         & " git commit -qm c2; git branch feature HEAD~1 ); done;"
         & " test ""$(git -C g rev-parse HEAD)"""
         & " = ""$(git -C v rev-parse HEAD)""");

      --  Checking out the branch attaches HEAD symbolically in both tools and
      --  prints the same line.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C;"
         & " ( cd g && git checkout feature ) > g.out 2>&1;"
         & " ( cd v && " & CLI & " checkout feature ) > v.out 2>&1;"
         & " test ""$(cat g/.git/HEAD)"" = 'ref: refs/heads/feature' &&"
         & " test ""$(cat v/.git/HEAD)"" = 'ref: refs/heads/feature' &&"
         & " grep -q ""Switched to branch 'feature'"" v.out");

      --  The data-loss guard: a commit made now lands on `feature`, and the
      --  branch ref advances -- it is not orphaned. Both tools must agree.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C"
         & " GIT_AUTHOR_DATE='1700000100 +0000'"
         & " GIT_COMMITTER_DATE='1700000100 +0000'; for r in g v; do"
         & " ( cd $r; printf 'c\n' >> f; git add f; git commit -qm c3 ); done;"
         & " test ""$(git -C g rev-parse feature)"" = ""$(git -C g rev-parse HEAD)"";"
         & " test ""$(git -C v rev-parse feature)"" = ""$(git -C v rev-parse HEAD)"";"
         & " test ""$(git -C g symbolic-ref HEAD)"" = refs/heads/feature;"
         & " test ""$(git -C v symbolic-ref HEAD)"" = refs/heads/feature");

      --  A non-branch revision (a raw commit id) still detaches, as git does.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C;"
         & " C=""$(git -C v rev-parse HEAD~1)"";"
         & " ( cd v && " & CLI & " checkout ""$C"" ) >/dev/null 2>&1;"
         & " test ""$(cat v/.git/HEAD)"" = ""$C"";"
         & " ( cd v && git symbolic-ref -q HEAD ) && exit 1 || true");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Checkout_Branch_Attaches_Head_Matches_Git;

   --  Regression: config value quoting/escaping and multivar unset. version
   --  wrote values raw (a `#`, `;`, quote or edge whitespace corrupted the
   --  value on the next read) and `unset` deleted every value of a multivar.
   procedure Config_Quoting_And_Unset_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  For each awkward value, version's raw config bytes and the value git
      --  reads back from version's file must both match git's own.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " for v in '  hp # x  ' 'tr ' ' ld' 'q""q' 'b\\s' 's;c' plain; do"
         & "   rm -rf g v; mkdir g v;"
         & "   ( cd g && git init -q && git config t.k ""$v"" );"
         & "   ( cd v && git init -q && " & CLI & " config set t.k ""$v"" );"
         & "   test ""$(grep -a 'k =' g/.git/config)"""
         & "     = ""$(grep -a 'k =' v/.git/config)"";"
         & "   test ""$(git -C g config t.k)"" = ""$(git -C v config t.k)"";"
         & " done");

      --  unset of a multivar: warn, exit 5, leave both values; single unset ok.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf v; mkdir v;"
         & " ( cd v && git init -q && git config --add m.k one"
         & " && git config --add m.k two ) &&"
         & " { ve=0; ( cd v && " & CLI & " config unset m.k ) || ve=$?;"
         & "   test $ve -eq 5 &&"
         & "   test ""$(git -C v config --get-all m.k | tr '\n' ',')"""
         & "     = 'one,two,' ; } &&"
         & " ( cd v && git config single.k solo &&"
         & "   " & CLI & " config unset single.k ) &&"
         & " test -z ""$(git -C v config --get-all single.k || true)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Config_Quoting_And_Unset_Matches_Git;

   --  Regression: commit-tree joined repeated -m as paragraphs (was dropping
   --  all but the last); mktree rejects malformed / type-mismatched input
   --  (was silently dropping lines and coercing types into a corrupt tree).
   procedure Commit_Tree_And_Mktree_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  commit-tree with two -m: same commit id as git (identical body).
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'"
         & " GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@e"
         & " GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@e;"
         & " rm -rf r; mkdir r; cd r; git init -q; printf 'x\n' > f;"
         & " git add f; TR=$(git write-tree);"
         & " g=$(git commit-tree $TR -m one -m two);"
         & " v=$(" & CLI & " commit-tree $TR -m one -m two);"
         & " test ""$g"" = ""$v""");

      --  mktree: a malformed line and a type/mode mismatch each abort with
      --  git's message and exit 128; a valid line yields git's tree id.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf r; mkdir r; cd r; git init -q;"
         & " B=$(printf 'hello\n' | git hash-object -w --stdin);"
         & " ge=0; printf 'garbage line\n' | git mktree 2>g.e || ge=$?;"
         & " ve=0; printf 'garbage line\n' | " & CLI & " mktree 2>v.e || ve=$?;"
         & " test $ge -eq 128 && test $ve -eq 128 && cmp -s g.e v.e;"
         & " printf '100644 tree %s\tf\n' $B | git mktree 2>g2.e"
         & "   && false || true;"
         & " printf '100644 tree %s\tf\n' $B | " & CLI & " mktree 2>v2.e"
         & "   && false || true; cmp -s g2.e v2.e;"
         & " gt=$(printf '100644 blob %s\tf\n' $B | git mktree);"
         & " vt=$(printf '100644 blob %s\tf\n' $B | " & CLI & " mktree);"
         & " test ""$gt"" = ""$vt""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Commit_Tree_And_Mktree_Matches_Git;

   --  Regression: fast-export/fast-import parity. fast-export dropped
   --  lightweight tags and emitted short refs verbatim; fast-import, on a
   --  second `commit` with no `from`, orphaned history and dropped files.
   procedure Fast_Export_Import_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  fast-export --all (lightweight + annotated tags) and a short ref
      --  must be byte-identical to git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r; cd r;"
         & " git init -q -b main; git config user.email t@e;"
         & " git config user.name T; printf 'a\n' > f; git add f;"
         & " git commit -qm c1; git tag light; git tag -a annot -m msg;"
         & " test ""$(git fast-export --all)"" = ""$(" & CLI
         & " fast-export --all)"";"
         & " test ""$(git fast-export main)"" = ""$(" & CLI
         & " fast-export main)""");

      --  fast-import: a second commit with no `from` inherits the ref tip as
      --  parent and keeps earlier files -- same head oid as git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " printf 'blob\nmark :1\ndata 2\na\n\ncommit refs/heads/m\n"
         & "mark :2\ncommitter T <t@e> 1700000000 +0000\ndata 3\nc1\n"
         & "M 644 :1 a\n\nblob\nmark :3\ndata 2\nb\n\ncommit refs/heads/m\n"
         & "mark :4\ncommitter T <t@e> 1700000000 +0000\ndata 3\nc2\n"
         & "M 644 :3 b\n\n' > s.fi;"
         & " rm -rf g v; mkdir g v;"
         & " ( cd g && git init -q && git fast-import --quiet < ../s.fi );"
         & " ( cd v && git init -q && " & CLI & " fast-import < ../s.fi );"
         & " test ""$(git -C g rev-parse refs/heads/m)"""
         & "   = ""$(git -C v rev-parse refs/heads/m)"";"
         & " test ""$(git -C v ls-tree --name-only refs/heads/m"
         & " | tr '\n' ',')"" = 'a,b,'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fast_Export_Import_Matches_Git;

   --  Regression: index-pack --keep writes the .keep file; merge-file refuses
   --  binary content (both were silent no-ops / data corruption before).
   procedure Index_Pack_Keep_And_Merge_File_Binary
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf r; mkdir r;"
         & " cd r; git init -q;"
         & " B=$(printf 'data\n' | git hash-object -w --stdin);"
         & " printf '%s\n' ""$B"" | git pack-objects --stdout > p.pack"
         & "   2>/dev/null;"
         & " " & CLI & " index-pack --stdin --keep < p.pack >/dev/null 2>&1;"
         & " test -f .git/objects/pack/*.keep;"
         & " test -z ""$(cat .git/objects/pack/*.keep)"";"
         & " rm -f .git/objects/pack/*;"
         & " " & CLI & " index-pack --stdin --keep=why < p.pack"
         & "   >/dev/null 2>&1;"
         & " test ""$(cat .git/objects/pack/*.keep)"" = why");

      --  merge-file on binary content: git and version agree byte-for-byte
      --  (message + exit) and leave the current file untouched.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C; rm -rf r; mkdir r; cd r;"
         & " printf 'x\0z\n' > cur; printf 'x\nb\n' > base;"
         & " printf 'x\no\n' > oth; cp cur cur.bak;"
         & " ge=0; go=$(git merge-file -p cur base oth 2>&1) || ge=$?;"
         & " ve=0; vo=$(" & CLI & " merge-file -p cur base oth 2>&1) || ve=$?;"
         & " test ""$go"" = ""$vo"" && test $ge -eq $ve &&"
         & " cmp -s cur cur.bak");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Index_Pack_Keep_And_Merge_File_Binary;

   --  Regression: merge-resolve refuses a dirty index; merge-recursive folds
   --  multiple bases into a virtual ancestor so the conflicted index (stage-1
   --  virtual-base blob included) byte-matches git on a criss-cross history.
   procedure Merge_Backends_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  merge-recursive on a criss-cross (two-merge-base) history: the
      --  conflicted index -- including the stage-1 virtual-ancestor blob --
      --  must be identical between git and version. `build` takes a target
      --  directory and the merge-recursive tool to exercise.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " build() { git init -q -b main ""$1""; ( cd ""$1"";"
         & " git config user.email t@e; git config user.name T;"
         & " printf '1\n2\n3\n4\n5\n' > f; git add f; git commit -qm O;"
         & " git checkout -q -b x; printf '1\n2\n3\n4\n5x\n' > f; git add f;"
         & " git commit -qm a; A=$(git rev-parse HEAD);"
         & " git checkout -q -b y main; printf '1x\n2\n3\n4\n5\n' > f;"
         & " git add f; git commit -qm b; B=$(git rev-parse HEAD);"
         & " git checkout -q x; git merge -q --no-ff ""$B"" -m m1;"
         & " git checkout -q y; git merge -q --no-ff ""$A"" -m m2;"
         & " git checkout -q x; printf '1\n2\n3M1\n4\n5x\n' > f; git add f;"
         & " git commit -qm c1; X=$(git rev-parse HEAD);"
         & " git checkout -q y; printf '1x\n2\n3M2\n4\n5\n' > f; git add f;"
         & " git commit -qm c2; Y=$(git rev-parse HEAD);"
         & " git checkout -q -f x;"
         & " P1=$(git merge-base --all ""$X"" ""$Y"" | sort | head -1);"
         & " P2=$(git merge-base --all ""$X"" ""$Y"" | sort | tail -1);"
         & " ""$2"" merge-recursive ""$P1"" ""$P2"" -- ""$X"" ""$Y"""
         & "   >/dev/null 2>&1 || true; git ls-files -s > ../""$1"".idx ); };"
         & " rm -rf g v; build g git; build v " & CLI & ";"
         & " cmp -s g.idx v.idx");

      --  merge-resolve with a staged change refuses (exit 2, git's message)
      --  and preserves the staged file.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf mr; mkdir mr;"
         & " cd mr; git init -q -b main; git config user.email t@e;"
         & " git config user.name T; printf 'a\n' > f; git add f;"
         & " git commit -qm base; git branch other;"
         & " printf 'ours\n' > f; git add f; git commit -qm ours;"
         & " git checkout -q other; printf 'theirs\n' > f; git add f;"
         & " git commit -qm theirs; git checkout -q main;"
         & " printf 'DIRTY\n' > staged; git add staged;"
         & " Bs=$(git merge-base main other);"
         & " ve=0; vo=$(" & CLI & " merge-resolve $Bs -- main other 2>&1)"
         & "   || ve=$?;"
         & " test $ve -eq 2 &&"
         & " printf '%s\n' ""$vo"" | head -1 |"
         & "   grep -q 'would be overwritten by merge' &&"
         & " test ""$(git diff --cached --name-only)"" = staged");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Backends_Match_Git;

   --  Regression: assorted correctness fixes -- describe no longer aborts on a
   --  merge commit, init --bare drops core.logallrefupdates, notes writes
   --  git's commit message, and config unset of a missing key exits 5 silent.
   procedure Correctness_Batch_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  describe on a history with a merge commit: byte-identical to git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r; cd r;"
         & " git init -q -b main; git config user.email t@e;"
         & " git config user.name T; printf 'a\n' > f; git add f;"
         & " git commit -qm c1; git tag -a v1 -m v1;"
         & " git checkout -q -b feat; printf 'b\n' > g; git add g;"
         & " git commit -qm c2; git checkout -q main;"
         & " git merge -q --no-ff feat -m merge;"
         & " test ""$(git describe)"" = ""$(" & CLI & " describe)""");

      --  init --bare omits core.logallrefupdates, as git does.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf b;"
         & " " & CLI & " init --bare b >/dev/null 2>&1;"
         & " test -z ""$(git config -f b/config core.logallrefupdates"
         & "   || true)""");

      --  notes add writes git's exact notes-commit message.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf n; mkdir n; cd n;"
         & " git init -q; git config user.email t@e; git config user.name T;"
         & " printf x > f; git add f; git commit -qm c;"
         & " " & CLI & " notes add -m hello >/dev/null;"
         & " test ""$(git log --format=%s -1 refs/notes/commits)"""
         & "   = ""Notes added by 'git notes add'""");

      --  config unset of a missing key: exit 5, no output.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf c; mkdir c; cd c;"
         & " git init -q;"
         & " e=0; o=$(" & CLI & " config unset no.such 2>&1) || e=$?;"
         & " test $e -eq 5 && test -z ""$o""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Correctness_Batch_Matches_Git;

   --  Regression: mktag runs git's strict fsck. A well-formed tag writes the
   --  same object id as git; each malformation is rejected with git's exact
   --  two-line message and exit 128 (was silently written as a real tag).
   procedure Mktag_Fsck_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  Each case: git and version must agree on stdout/stderr and exit.
      --  $H is a valid tagger header line; the loop substitutes the tagger
      --  and tag-name fields to exercise the five fsck failures plus valid.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r; cd r;"
         & " git init -q; git config user.email t@e; git config user.name T;"
         & " printf 'x\n' > f; git add f; git commit -qm c;"
         & " C=$(git rev-parse HEAD);"
         & " check() {"     --  $1 = tag name field, $2 = tagger field
         & "   s=""object $C\ntype commit\ntag $1\ntagger $2\n"";"
         & "   ge=0; go=$(printf ""$s"" | git mktag 2>&1) || ge=$?;"
         & "   ve=0; vo=$(printf ""$s"" | " & CLI & " mktag 2>&1) || ve=$?;"
         & "   test ""$go"" = ""$vo"" && test $ge -eq $ve; };"
         & " check v1 'T <t@e> 1700000000 +0000';"     --  valid
         & " check v1 'T 1700000000 +0000';"           --  missingEmail
         & " check v1 'T <t@e> 1700000000 +9999x';"    --  badTimezone
         & " check v1 'T <t@e> 1700000000';"           --  badDate
         & " check 'v 1' 'T <t@e> 1700000000 +0000'"); --  badTagName

      --  Valid mktag writes git's exact object id.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; cd r; C=$(git rev-parse"
         & " HEAD);"
         & " s=""object $C\ntype commit\ntag v1\n"
         & "tagger T <t@e> 1700000000 +0000\n"";"
         & " test ""$(printf ""$s"" | git mktag)"""
         & "   = ""$(printf ""$s"" | " & CLI & " mktag)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mktag_Fsck_Matches_Git;

   --  Regression: grep collapses a binary file to "Binary file <p> matches"
   --  (was dumping raw NUL bytes); count-objects -H humanises the size (was
   --  "N kilobytes"); diff shows mode changes for a chmod, worktree and
   --  --cached, pure and alongside content (was empty / missing headers).
   procedure Grep_Count_Diff_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  grep on a binary + a text file: default/-n/-c/-l all match git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r; cd r;"
         & " git init -q; git config user.email t@e; git config user.name T;"
         & " printf 'match\0x match\nmatch two\n' > b;"
         & " printf 'plain match\n' > t; git add b t; git commit -qm c;"
         & " for o in '' '-n' '-c' '-l'; do"
         & "   test ""$(git grep $o match)"" = ""$(" & CLI & " grep $o match)"";"
         & " done;"
         & " test ""$(git count-objects -H)"" = ""$(" & CLI
         & " count-objects -H)""");

      --  diff mode changes: pure chmod (worktree and staged) and chmod with
      --  content, each byte-identical to git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf d; mkdir d; cd d;"
         & " git init -q; git config user.email t@e; git config user.name T;"
         & " printf 'x\ny\n' > f; git add f; git commit -qm c;"
         & " chmod +x f;"
         & " test ""$(git diff)"" = ""$(" & CLI & " diff)"";"      --  worktree
         & " git add f;"
         & " test ""$(git diff --cached)"" = ""$(" & CLI
         & " diff --cached)"";"                                     --  staged
         & " git commit -qm chmod; printf 'x\nY\n' > f;"
         & " test ""$(git diff)"" = ""$(" & CLI & " diff)""");      --  +content

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Grep_Count_Diff_Match_Git;

   --  Regression: ls-files -m now includes worktree-deleted files, and the raw
   --  diff-files/diff-index plumbing reports a working-tree mode change (chmod)
   --  with git's exact record (they saw only content changes before).
   procedure Ls_Files_Raw_Diff_Mode_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  ls-files -m lists a worktree-modified AND a worktree-deleted file.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r; cd r;"
         & " git init -q; git config user.email t@e; git config user.name T;"
         & " printf 'a\n' > f1; printf 'b\n' > f2; git add f1 f2;"
         & " git commit -qm c; rm -f f2; printf 'X\n' > f1;"
         & " test ""$(git ls-files -m)"" = ""$(" & CLI & " ls-files -m)""");

      --  Raw diff-files and diff-index report the chmod (pure and with
      --  content) exactly as git, and don't regress content-only/deletion.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " case_() { rm -rf d; mkdir d; ( cd d; git init -q;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'x\n' > f; git add f; git commit -qm c; eval ""$1"";"
         & "   test ""$(git diff-files)"" = ""$(" & CLI & " diff-files)"";"
         & "   test ""$(git diff-index HEAD)"""
         & "     = ""$(" & CLI & " diff-index HEAD)"" ); };"
         & " case_ 'chmod +x f';"                        --  pure mode
         & " case_ 'chmod +x f; printf Y > f';"          --  content+mode
         & " case_ 'printf Y > f';"                       --  content only
         & " case_ 'rm -f f'");                            --  deletion

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Ls_Files_Raw_Diff_Mode_Match_Git;

   --  Regression: bisect refuses when a good rev is not an ancestor of the bad
   --  rev (was silently reporting a bogus first-bad-commit); cat-file honours
   --  -z, reading NUL-separated requests (was one malformed object name).
   procedure Bisect_Catfile_Z_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  Swapped good/bad: version and git both refuse with the same message
      --  and exit 1; a normal bisect still starts.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf r; mkdir r;"
         & " ( cd r; git init -q -b main; git config user.email t@e;"
         & "   git config user.name T;"
         & "   for i in 1 2 3 4 5; do printf '%s\n' $i >> f; git add f;"
         & "     git commit -qm c$i; done;"
         & "   OLD=$(git rev-parse HEAD~3); NEW=$(git rev-parse HEAD);"
         & "   ge=0; go=$( ( git bisect start; git bisect bad $OLD;"
         & "     git bisect good $NEW ) 2>&1 ) || ge=$?; git bisect reset"
         & "     >/dev/null 2>&1;"
         & "   ve=0; vo=$( ( " & CLI & " bisect start; " & CLI
         & " bisect bad $OLD; " & CLI & " bisect good $NEW ) 2>&1 ) || ve=$?;"
         & "   " & CLI & " bisect reset >/dev/null 2>&1;"
         & "   test $ge -eq 1 && test $ve -eq 1 &&"
         & "   printf '%s\n' ""$vo"" |"
         & "     grep -q 'not ancestors of the bad rev' )");

      --  cat-file --batch-check -z: NUL-separated requests, output matches git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf c; mkdir c;"
         & " ( cd c; git init -q; git config user.email t@e;"
         & "   git config user.name T; printf 'hi\n' > f; git add f;"
         & "   git commit -qm c; H=$(git rev-parse HEAD);"
         & "   B=$(git rev-parse HEAD:f);"
         & "   test ""$(printf '%s\0%s\0' ""$H"" ""$B"" |"
         & "     git cat-file --batch-check -z)"""
         & "     = ""$(printf '%s\0%s\0' ""$H"" ""$B"" | " & CLI
         & " cat-file --batch-check -z)"";"
         --  -Z NUL-terminates the output too; compare byte-exactly (command
         --  substitution strips NULs) for both --batch-check and --batch.
         & "   printf '%s\0nope\0' ""$B"" | git cat-file --batch-check -Z"
         & "     > gc; printf '%s\0nope\0' ""$B"" | " & CLI
         & " cat-file --batch-check -Z > vc; cmp gc vc;"
         & "   printf '%s\0' ""$B"" | git cat-file --batch -Z > gb;"
         & "   printf '%s\0' ""$B"" | " & CLI & " cat-file --batch -Z > vb;"
         & "   cmp gb vb )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Bisect_Catfile_Z_Match_Git;

   --  Regression: hash-object/get-tar-commit-id die (exit 128, git's message)
   --  on bad input; init is idempotent (a second init succeeds); merge-tree
   --  honours --allow-unrelated-histories and otherwise refuses like git.
   procedure Plumbing_Errors_And_Init_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  hash-object on a missing file and get-tar-commit-id on junk: version
      --  prints git's exact (English) fatal message and exits 128, and git
      --  exits 128 too. (git localizes the text; version does not, so we
      --  assert version's literal output and only compare git's exit code.)
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf r; mkdir r; cd r;"
         & " git init -q;"
         & " ge=0; git hash-object nope >/dev/null 2>&1 || ge=$?;"
         & " ve=0; vo=$(" & CLI & " hash-object nope 2>&1) || ve=$?;"
         & " test $ge -eq 128 && test $ve -eq 128 &&"
         & " test ""$vo"" = ""fatal: could not open 'nope' for reading:"
         & " No such file or directory"";"
         & " ge=0; printf junk | git get-tar-commit-id >/dev/null 2>&1"
         & "   || ge=$?;"
         & " ve=0; vo=$(printf junk | " & CLI
         & " get-tar-commit-id 2>&1) || ve=$?;"
         & " test $ge -eq 128 && test $ve -eq 128 &&"
         & " test ""$vo"" = ""fatal: git get-tar-commit-id: EOF before"
         & " reading tar header: No such file or directory""");

      --  hash-object hashes EVERY file operand (one id per line), not just the
      --  first, and dies (exit 128) at the first unopenable file after emitting
      --  the ids of the files before it -- matching git.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf h; mkdir h; cd h;"
         & " git init -q; printf 'aaa\n' > a; printf 'bbb\n' > b;"
         & " printf 'ccc\n' > c;"
         & " test ""$(" & CLI & " hash-object a b c)"""
         & "   = ""$(git hash-object a b c)"" &&"
         & " ve=0; vo=$(" & CLI & " hash-object a nope c 2>/dev/null)"
         & "   || ve=$?;"
         & " test $ve -eq 128 &&"
         & " test ""$vo"" = ""$(git hash-object a 2>/dev/null)""");

      --  init is idempotent: a second init succeeds (exit 0) and leaves the
      --  repo intact.
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf i; mkdir i; cd i;"
         & " " & CLI & " init >/dev/null 2>&1 &&"
         & " " & CLI & " init >/dev/null 2>&1 && test -d .git");

      --  merge-tree refuses unrelated histories, matching git, and merges
      --  with --allow-unrelated-histories to git's exact tree id.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf m; mkdir m;"
         & " ( cd m; git init -q -b main; git config user.email t@e;"
         & "   git config user.name T; printf a > x; git add x;"
         & "   git commit -qm a; A=$(git rev-parse HEAD);"
         & "   git checkout -q --orphan other; git rm -q -rf .;"
         & "   printf b > y; git add y; git commit -qm b;"
         & "   B=$(git rev-parse HEAD);"
         & "   ge=0; git merge-tree --write-tree $A $B >/dev/null 2>&1"
         & "     || ge=$?;"
         & "   ve=0; " & CLI & " merge-tree --write-tree $A $B >/dev/null"
         & "     2>&1 || ve=$?;"
         & "   test $ge -eq 128 && test $ve -eq 128;"
         & "   test ""$(git merge-tree --write-tree"
         & "     --allow-unrelated-histories $A $B)"""
         & "     = ""$(" & CLI & " merge-tree --write-tree"
         & "     --allow-unrelated-histories $A $B)"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Plumbing_Errors_And_Init_Match_Git;

   --  Regression: check-ignore rejects an empty pathspec and a path resolving
   --  outside the repository (git exit 128), instead of silently treating
   --  them as not-ignored. version's messages are asserted in English (git
   --  localizes them; we compare only git's exit code).
   procedure Check_Ignore_Path_Errors_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf r; mkdir r; cd r;"
         & " git init -q;"
         --  empty pathspec
         & " ge=0; git check-ignore '' >/dev/null 2>&1 || ge=$?;"
         & " ve=0; vo=$(" & CLI & " check-ignore '' 2>&1) || ve=$?;"
         & " test $ge -eq 128 && test $ve -eq 128 &&"
         & " printf '%s\n' ""$vo"" |"
         & "   grep -q 'empty string is not a valid pathspec';"
         --  absolute path outside the repository
         & " ge=0; git check-ignore /etc/passwd >/dev/null 2>&1 || ge=$?;"
         & " ve=0; vo=$(" & CLI & " check-ignore /etc/passwd 2>&1) || ve=$?;"
         & " test $ge -eq 128 && test $ve -eq 128 &&"
         & " printf '%s\n' ""$vo"" | grep -q 'is outside repository at'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Check_Ignore_Path_Errors_Match_Git;

   --  Regression: check-ref-format --branch rejects HEAD and a leading "-"
   --  (exit 128) but accepts @ and ordinary names, matching git's exit codes;
   --  diff-tree prints nothing for a merge commit by default.
   procedure Check_Ref_Format_And_Diff_Tree_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  --branch exit codes match git for a range of names (git localizes
      --  the message text, so only the exit status is compared).
      Version.Git_Fixtures.Run
        (Root,
         "export LC_ALL=C GIT_CONFIG_NOSYSTEM=1; rm -rf r; mkdir r; cd r;"
         & " git init -q;"
         & " for b in HEAD - @ main feat/x .bad; do"
         & "   ge=0; git check-ref-format --branch ""$b"" >/dev/null 2>&1"
         & "     || ge=$?;"
         & "   ve=0; " & CLI & " check-ref-format --branch ""$b"" >/dev/null"
         & "     2>&1 || ve=$?;"
         & "   test $ge -eq $ve || exit 1;"
         & " done;"
         --  --normalize: a trailing slash is invalid; leading/repeated
         --  slashes normalize. Compare full output + exit code.
         & " for n in 'refs/heads/x/' '/refs/heads/x' 'refs/heads//x'"
         & "   'refs/heads/x'; do"
         & "   go=$(git check-ref-format --normalize ""$n"" 2>&1); ge=$?;"
         & "   vo=$(" & CLI & " check-ref-format --normalize ""$n"" 2>&1);"
         & "   ve=$?;"
         & "   test ""$go"" = ""$vo"" && test $ge -eq $ve || exit 1;"
         & " done");

      --  diff-tree on a merge commit prints nothing by default, like git.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000'; rm -rf d; mkdir d;"
         & " ( cd d; git init -q -b main; git config user.email t@e;"
         & "   git config user.name T; printf a > f; git add f;"
         & "   git commit -qm c; git checkout -q -b feat; printf b > g;"
         & "   git add g; git commit -qm c2; git checkout -q main;"
         & "   git merge -q --no-ff feat -m merge; M=$(git rev-parse HEAD);"
         & "   test ""$(git diff-tree $M)"" = ""$(" & CLI
         & " diff-tree $M)"" && test -z ""$(" & CLI & " diff-tree $M)"";"
         & "   C=$(git rev-parse HEAD~1);"
         & "   test ""$(git diff-tree $C)"" = ""$(" & CLI
         & " diff-tree $C)"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Check_Ref_Format_And_Diff_Tree_Match_Git;

   --  Regression: mv accepts a directory source -- it renames every tracked
   --  file under it (index byte-identical to git) and removes the emptied
   --  directory, for both a plain rename and a move into an existing dir.
   procedure Mv_Directory_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      --  `build` sets up an identical repo, runs the mv $1, and prints the
      --  tracked file list plus whether the source dir still exists.
      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " build() { rm -rf ""$1""; mkdir ""$1""; ( cd ""$1"";"
         & "   git init -q; git config user.email t@e;"
         & "   git config user.name T; mkdir -p d/sub; printf a > d/f;"
         & "   printf b > d/sub/g; printf c > top; git add .;"
         & "   git commit -qm c; eval ""$2"" >/dev/null 2>&1;"
         & "   git ls-files | tr '\n' ',' > ../""$1"".files;"
         & "   ([ -d d ] && echo Y || echo N) >> ../""$1"".files ); };"
         --  plain directory rename
         & " build g 'git mv d d2'; build v '" & CLI & " mv d d2';"
         & " cmp -s g.files v.files;"
         --  move directory into an existing directory
         & " build g 'mkdir existing; git mv d existing';"
         & " build v 'mkdir existing; " & CLI & " mv d existing';"
         & " cmp -s g.files v.files;"
         --  plain single-file mv still works
         & " build g 'git mv top top2'; build v '" & CLI & " mv top top2';"
         & " cmp -s g.files v.files");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mv_Directory_Matches_Git;

   --  Regression: <rev>^0 peels to the commit (rev-parse/name-rev);
   --  checkout-index reports a path not in the index (exit 1) yet still
   --  checks out the present paths; diff-files -p prints the unified diff.
   procedure Rev_Zero_Checkout_Index_Diff_Files_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q; git config user.email t@e;"
         & "   git config user.name T; printf 'A\n' > a; printf 'B\n' > b;"
         & "   git add a b; git commit -qm c; git tag v1;"
         --  ^0 peels to the commit (rev-parse and name-rev both match git)
         & "   test ""$(" & CLI & " rev-parse HEAD^0)"""
         & "     = ""$(git rev-parse HEAD^0)"";"
         & "   test ""$(" & CLI & " name-rev HEAD^0)"""
         & "     = ""$(git name-rev HEAD^0)"";"
         --  checkout-index: present paths restored, missing path errors exit 1
         & "   rm -f a b;"
         & "   ve=0; vo=$(" & CLI & " checkout-index a nope b 2>&1) || ve=$?;"
         & "   test $ve -eq 1;"
         & "   test ""$vo"" ="
         & "     'git checkout-index: nope is not in the cache';"
         & "   test -f a && test -f b;"
         --  diff-files -p prints the unified diff like git
         & "   printf 'A\nX\n' > a;"
         & "   test ""$(" & CLI & " diff-files -p)"""
         & "     = ""$(git diff-files -p)"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Rev_Zero_Checkout_Index_Diff_Files_Match_Git;

   --  Regression: `diff <rev>` diffs that tree against the working tree (was
   --  treated as a pathspec, printing nothing); `diff-index -p` prints the
   --  unified diff against the working tree, and `-p --cached` against the
   --  index.  All byte-compared with git.
   procedure Diff_Rev_And_Diff_Index_Patch_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'l1\nl2\nl3\n' > a; printf 'del\n' > gone;"
         & "   git add a gone; git commit -qm c1; git tag base;"
         & "   printf 'l1\nCHANGED\nl3\n' > a; git add a; git commit -qm c2;"
         --  worktree edits: unstaged content change, a deletion, an untracked
         --  file (which diff <rev> must not show), and a staged change.
         & "   printf 'l1\nCHANGED\nl3\nWORK\n' > a; rm -f gone;"
         & "   printf 'new\n' > added; printf 's\n' > st; git add st;"
         --  diff <rev>: base tree vs working tree
         & "   test ""$(" & CLI & " diff base)"" = ""$(git diff base)"";"
         --  diff-index -p: tree vs working tree
         & "   test ""$(" & CLI & " diff-index -p HEAD)"""
         & "     = ""$(git diff-index -p HEAD)"";"
         --  diff-index -p --cached: tree vs index
         & "   test ""$(" & CLI & " diff-index -p --cached HEAD)"""
         & "     = ""$(git diff-index -p --cached HEAD)"";"
         --  a non-rev single argument is still a pathspec
         & "   test ""$(" & CLI & " diff a)"" = ""$(git diff -- a)"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Rev_And_Diff_Index_Patch_Match_Git;

   --  Regression: format-patch emits git's mbox byte-for-byte -- the diffstat
   --  and summary block after "---", the body running straight into "---", the
   --  -<n> form (last n non-merge commits, root-inclusive), a blank line
   --  between consecutive patches but none after the last, and no spurious
   --  trailing newline.  Compared as raw bytes (git's own version number in the
   --  trailer is normalised away).
   procedure Format_Patch_Mbox_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      --  Normalise the "-- \n<git version>" trailer, which is git's own.
      Norm : constant String :=
        "sed 's/^[0-9][0-9.]*$/VERSION/'";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'l1\nl2\nl3\n' > a; mkdir -p d; printf 'x\n' > d/b;"
         & "   git add -A; git commit -qm 'first commit';"
         --  a commit with a multi-paragraph body, a delete and a new exec file
         & "   printf 'l1\nL2\nl3\nl4\n' > a; git rm -q d/b;"
         & "   printf '#!/bin/sh\necho hi\n' > s.sh; chmod +x s.sh; git add -A;"
         & "   git commit -qm 'second commit' -m 'Body line.' -m 'More body.';"
         & "   printf 'l5\n' >> a; git add -A; git commit -qm 'third commit';"
         --  --stdout: single, multiple (blank-line separated), over-long -<n>,
         --  and an explicit range.  Raw bytes, so the trailing newline counts.
         & "   for s in -1 -2 -3 -9 HEAD~2..HEAD HEAD~2..HEAD~1; do"
         & "     git format-patch --stdout $s | " & Norm & " > g.mbox;"
         & "     " & CLI & " format-patch --stdout $s | " & Norm & " > v.mbox;"
         & "     cmp -s g.mbox v.mbox || { echo ""mismatch $s""; exit 1; };"
         & "   done;"
         --  -o <dir>: same file names and same bytes
         & "   mkdir go vo;"
         & "   git format-patch -o go -2 > g.names;"
         & "   " & CLI & " format-patch -o vo -2 > v.names;"
         & "   ( cd go; ls ) > g.ls; ( cd vo; ls ) > v.ls; cmp -s g.ls v.ls;"
         & "   for f in $(cat g.ls); do"
         & "     " & Norm & " go/$f > g.p; " & Norm & " vo/$f > v.p;"
         & "     cmp -s g.p v.p || { echo ""file mismatch $f""; exit 1; };"
         & "   done )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Format_Patch_Mbox_Matches_Git;

   --  Regression: rename detection. git pairs deletions with creations and
   --  reports "similarity index"/"rename from"/"rename to", the `a => b` (and
   --  brace-compressed `d/{a => b}`) stat names, R<nnn> in --name-status, and
   --  honours -M/--no-renames/diff.renames. A mode-only change must still be
   --  reported as a change by --stat and --name-status.
   procedure Diff_Renames_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   mkdir -p d/sub;"
         & "   seq 1 20 | sed 's/$/ line/' > d/sub/a.txt;"
         & "   cp d/sub/a.txt d/sub/b.txt; cp d/sub/a.txt top.txt;"
         & "   cp d/sub/a.txt mode.txt; git add -A; git commit -qm c1;"
         --  a pure rename inside a directory, a rename across directories, a
         --  rename with an edit, and a mode-only change
         & "   git mv d/sub/a.txt d/other.txt;"
         & "   git mv top.txt d/sub/top.txt;"
         & "   git mv d/sub/b.txt d/sub/a2.txt;"
         & "   sed -i '2s/.*/EDITED/' d/sub/a2.txt;"
         & "   chmod +x mode.txt;"
         & "   git add -A; git commit -qm c2;"
         --  patch, stat, name-status and name-only all byte-match git
         & "   for o in '' '--stat' '--name-status' '--name-only'; do"
         & "     git diff $o HEAD~1 HEAD > g.out;"
         & "     " & CLI & " diff $o HEAD~1 HEAD > v.out;"
         & "     cmp -s g.out v.out || { echo mismatch-$o; exit 1; };"
         & "   done;"
         --  -M with a score, --no-renames, and diff.renames=false
         & "   for o in '-M5' '-M99%' '--no-renames'; do"
         & "     git diff $o --name-status HEAD~1 HEAD > g.out;"
         & "     " & CLI & " diff $o --name-status HEAD~1 HEAD > v.out;"
         & "     cmp -s g.out v.out || { echo mismatch-$o; exit 1; };"
         & "   done;"
         & "   git config diff.renames false;"
         & "   git diff --name-status HEAD~1 HEAD > g.out;"
         & "   " & CLI & " diff --name-status HEAD~1 HEAD > v.out;"
         & "   cmp -s g.out v.out;"
         & "   git config --unset diff.renames;"
         --  format-patch carries the same rename block and stat
         & "   git format-patch --stdout -1 | sed 's/^[0-9][0-9.]*$/V/' > g.p;"
         & "   " & CLI & " format-patch --stdout -1"
         & "     | sed 's/^[0-9][0-9.]*$/V/' > v.p;"
         & "   cmp -s g.p v.p )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Renames_Match_Git;

   --  Regression: format-patch implies git's --binary, so a binary change
   --  travels as an appliable `GIT binary patch` (full index, literal blocks,
   --  forward then reverse) instead of a "Binary files ... differ" line. The
   --  deflated payload is deliberately NOT compared to git's -- a zlib stream
   --  is not canonical -- so this asserts what matters: git can apply what we
   --  write, and the resulting blob is identical.
   procedure Format_Patch_Binary_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r d2; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'keep\n' > keep.txt;"
         --  a binary blob: NUL in the first bytes makes it binary to both
         & "   printf 'BIN\000\001\002\377data\000here' > img.bin;"
         & "   git add -A; git commit -qm base;"
         & "   printf 'BIN\000\001\002\377CHANGED\000tail' > img.bin;"
         & "   git add -A; git commit -qm changebin;"
         --  we emit a GIT binary patch, not a "differ" line
         & "   " & CLI & " format-patch --stdout -1 > v.patch;"
         & "   grep -q '^GIT binary patch$' v.patch;"
         & "   grep -q '^literal ' v.patch;"
         & "   ! grep -q 'Binary files' v.patch;"
         --  the index line is unabbreviated, as git writes it with --binary
         & "   grep -qE '^index [0-9a-f]{40,}\.\.[0-9a-f]{40,}' v.patch );"
         --  git applies it and reproduces the exact tree
         & " git init -q -b main d2; ( cd d2;"
         & "   git config user.email t@e; git config user.name T;"
         & "   git fetch -q ../r main; git reset -q --hard FETCH_HEAD~1;"
         & "   git am ../r/v.patch >/dev/null;"
         & "   test ""$(git rev-parse HEAD^{tree})"""
         & "     = ""$(cd ../r; git rev-parse HEAD^{tree})"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Format_Patch_Binary_Matches_Git;

   --  Regression: every timestamp version writes must be real Unix time.
   --  `Ada.Calendar.Time_Of (1970, 1, 1)` builds the epoch in the LOCAL zone,
   --  so `Clock - Epoch` was short by the zone's 1970 UTC offset and every
   --  commit, tag and reflog entry landed in the future (an hour, in central
   --  Europe). Compare version's own stamp against the system clock.
   procedure Commit_Timestamp_Is_Unix_Time
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         --  deliberately NOT setting GIT_*_DATE: this checks the clock path
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f.txt; " & CLI & " stage f.txt;"
         & "   before=$(date +%s);"
         & "   " & CLI & " save -m c1 >/dev/null;"
         & "   after=$(date +%s);"
         --  the committer stamp must sit inside the wall-clock window
         & "   c=$(git cat-file -p HEAD | awk '/^committer/{print $(NF-1)}');"
         & "   test ""$c"" -ge ""$before"";"
         & "   test ""$c"" -le ""$after"";"
         --  and so must the reflog entry git wrote alongside it
         & "   r=$(awk 'END{print $5}' .git/logs/HEAD);"
         & "   test ""$r"" -ge ""$before"";"
         & "   test ""$r"" -le ""$after"";"
         --  var reports the same clock
         & "   v=$(" & CLI & " var GIT_COMMITTER_IDENT | awk '{print $(NF-1)}');"
         & "   test ""$v"" -ge ""$before"" )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Commit_Timestamp_Is_Unix_Time;

   --  Regression: a repo-local config write must not drag the user's global
   --  config into the repository. Replace_Section/Remove_Section read the
   --  MERGED config (system + global + local) and wrote it back to the local
   --  file, so `clone` (which sets remote.origin.* and branch.*) copied the
   --  whole of ~/.gitconfig -- identity, credential helpers and all -- into
   --  every clone, twice. Also checks git's section framing (no blank line).
   procedure Clone_Config_Excludes_Global
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         --  a HOME with a global config carrying a distinctive marker
         & " rm -rf home src dst gdst; mkdir home;"
         & " printf '[user]\n\tname = Global Person\n"
         & "\temail = global@example.invalid\n' > home/.gitconfig;"
         & " printf '[secretsection]\n\tmarker = LEAKED\n' >> home/.gitconfig;"
         & " export HOME=$PWD/home;"
         & " git init -q -b main src; ( cd src;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f.txt; git add -A; git commit -qm c1 );"
         & " " & CLI & " clone src dst >/dev/null;"
         --  nothing from the global config may appear in the clone
         & " ! grep -q LEAKED dst/.git/config;"
         & " ! grep -q 'Global Person' dst/.git/config;"
         & " ! grep -q secretsection dst/.git/config;"
         --  and the file matches what git itself writes, byte for byte
         & " git clone -q src gdst;"
         & " cmp -s dst/.git/config gdst/.git/config");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Clone_Config_Excludes_Global;

   --  Regression: mailsplit. A directory operand is a Maildir (cur/ then new/,
   --  dotfiles skipped, filenames in git's natural order so "2" precedes
   --  "10") -- feeding one to Read_Binary_File previously exhausted the heap.
   --  Every CRLF line ending becomes LF unless --keep-cr, an empty mailbox is
   --  an error, and a mailbox whose first line is not a "From " line is
   --  "corrupt mailbox" unless -b.
   procedure Mailsplit_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf M g o; mkdir -p M/cur M/new g o;"
         --  CRLF in one message, natural-order names, and a skipped dotfile
         & " printf 'From: a@b\r\nSubject: one\r\n\r\nbody\r\n'"
         & "   > M/cur/2;"
         & " printf 'From: c@d\nSubject: two\n\nbody two\n' > M/cur/10;"
         & " printf 'From: e@f\nSubject: three\n\nbody 3\n' > M/new/1;"
         & " printf 'hidden\n' > M/cur/.skip;"
         & " git mailsplit -og M > g.count;"
         & " " & CLI & " mailsplit -oo M > o.count;"
         & " cmp -s g.count o.count;"
         & " for f in 0001 0002 0003; do cmp -s g/$f o/$f; done;"
         --  --keep-cr leaves the CRLF alone, as git does
         & " rm -rf g2 o2; mkdir g2 o2;"
         & " printf 'From x Mon Sep 17 00:00:00 2001\r\nA: b\r\n\r\nc\r\n'"
         & "   > crlf.mbox;"
         & " git mailsplit --keep-cr -og2 crlf.mbox > /dev/null;"
         & " " & CLI & " mailsplit --keep-cr -oo2 crlf.mbox > /dev/null;"
         & " cmp -s g2/0001 o2/0001;"
         --  an empty mailbox is an error, with git's two lines and exit 1
         & " : > empty.mbox; rm -rf o3; mkdir o3;"
         & " rc=0; " & CLI & " mailsplit -oo3 empty.mbox > /dev/null 2> e.err"
         & "   || rc=$?;"
         & " test $rc -eq 1;"
         & " grep -q ""^error: empty mbox: .empty.mbox.$"" e.err;"
         & " grep -q ""^error: cannot split patches from empty.mbox$"" e.err;"
         --  a bare mailbox is corrupt without -b, accepted with it
         & " printf 'not a from line\nblah\n' > bare.mbox;"
         & " rm -rf o4 o5; mkdir o4 o5;"
         & " rc=0; " & CLI & " mailsplit -oo4 bare.mbox > /dev/null 2> b.err"
         & "   || rc=$?;"
         & " test $rc -eq 1; grep -q ""^corrupt mailbox$"" b.err;"
         & " " & CLI & " mailsplit -b -oo5 bare.mbox > /dev/null");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mailsplit_Matches_Git;

   --  Regression: name-rev walked first-parent history only, so a commit
   --  reachable solely through a merge's second parent could not be named
   --  "<tip>^2" -- it fell back to a branch name, or to "undefined" under
   --  --tags. Ported git's name-rev (multi-parent walk, merge-traversal
   --  weighting, tag-and-age tip ordering) in Version.Name_Rev.
   procedure Name_Rev_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f; git add -A; git commit -qm c1; git tag v1;"
         & "   git checkout -qb side;"
         & "   printf 's\n' > g; git add -A; git commit -qm s1;"
         & "   printf 's2\n' >> g; git add -A; git commit -qm s2;"
         & "   git checkout -q main;"
         & "   printf 'b\n' >> f; git add -A; git commit -qm c2;"
         & "   git merge -q --no-ff side -m merge;"
         & "   git tag -a v2 -m two;"
         --  every commit must get git's exact name, with and without --tags
         & "   for r in $(git rev-list --all); do"
         & "     test ""$(" & CLI & " name-rev $r)"" = ""$(git name-rev $r)"";"
         & "     test ""$(" & CLI & " name-rev --tags $r)"""
         & "       = ""$(git name-rev --tags $r)"";"
         & "   done;"
         --  the side tip specifically must be named through the merge parent
         & "   test ""$(" & CLI & " name-rev $(git rev-parse side)"
         & "     | awk '{print $2}')"" = 'tags/v2^2' )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Name_Rev_Matches_Git;

   --  Regression: a filename holding a control character. Reading a tree that
   --  contained one raised "path contains control character" (a write-side
   --  safety check applied to a read path), so ls-files -m failed outright
   --  with exit 1 where git lists normally. git also C-quotes such a path on
   --  output; we printed the raw bytes.
   procedure Ls_Files_Control_Chars_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         --  a tab, a high-bit byte and a DEL in tracked names
         & "   printf 'x' > ""$(printf 'tab\there.txt')"";"
         & "   printf 'x' > ""$(printf 'hi\303\251.txt')"";"
         & "   printf 'x' > ""$(printf 'del\177.txt')"";"
         & "   printf 'y' > normal.txt;"
         & "   git add -A; git commit -qm c1;"
         --  listing matches git byte for byte, including the C-quoting
         & "   git ls-files > g.out; " & CLI & " ls-files > v.out;"
         & "   cmp -s g.out v.out;"
         & "   git ls-files -s > gs.out; " & CLI & " ls-files -s > vs.out;"
         & "   cmp -s gs.out vs.out;"
         --  and reading the tree for -m no longer fails
         & "   printf 'z' > normal.txt;"
         & "   git ls-files -m > gm.out;"
         & "   " & CLI & " ls-files -m > vm.out;"
         & "   cmp -s gm.out vm.out )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Ls_Files_Control_Chars_Match_Git;

   --  Regression: a conflicted cherry-pick left no state git could read --
   --  no stage 1/2/3 entries, no CHERRY_PICK_HEAD, no MERGE_MSG -- so
   --  `git status` reported a plain modification instead of "UU". And a pick
   --  that turns out to be empty (already applied) recorded an empty commit
   --  and exited 0, where git refuses and pauses.
   procedure Cherry_Pick_Conflict_State_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r e; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'base\n' > f.txt; git add -A; git commit -qm c1;"
         & "   git checkout -qb feature;"
         & "   printf 'feature\n' > f.txt; git add -A; git commit -qm featmod;"
         & "   git checkout -q main;"
         & "   printf 'mainside\n' > f.txt; git add -A; git commit -qm mainmod;"
         --  the conflicted pick pauses with git-readable state
         & "   rc=0; " & CLI & " cherry-pick feature > /dev/null 2>&1 || rc=$?;"
         & "   test $rc -eq 1;"
         & "   test -f .git/CHERRY_PICK_HEAD; test -f .git/MERGE_MSG;"
         & "   test ""$(git ls-files -u | wc -l)"" = 3;"
         & "   test ""$(git status --short)"" = 'UU f.txt';"
         --  and --continue clears git's state files, as git does
         & "   printf 'resolved\n' > f.txt; " & CLI & " stage f.txt;"
         & "   " & CLI & " cherry-pick --continue > /dev/null;"
         & "   test ! -f .git/CHERRY_PICK_HEAD; test ! -f .git/MERGE_MSG );"
         --  an already-applied pick must not record an empty commit
         & " mkdir e; ( cd e; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f.txt; git add -A; git commit -qm c1;"
         & "   git checkout -qb feature;"
         & "   printf 'a\nb\n' > f.txt; git add -A; git commit -qm addb;"
         & "   git checkout -q main;"
         & "   " & CLI & " cherry-pick feature > /dev/null;"
         & "   before=$(git rev-list --count HEAD);"
         & "   rc=0; " & CLI & " cherry-pick feature > /dev/null 2>&1 || rc=$?;"
         & "   test $rc -eq 1;"
         & "   test ""$(git rev-list --count HEAD)"" = ""$before"";"
         & "   test -f .git/CHERRY_PICK_HEAD;"
         & "   " & CLI & " cherry-pick --abort > /dev/null;"
         & "   test ! -f .git/CHERRY_PICK_HEAD )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Cherry_Pick_Conflict_State_Matches_Git;

   --  Regression: two merge behaviours. `merge --no-commit` cannot stop a
   --  fast-forward -- there is no merge commit to withhold, so git moves the
   --  branch; we used to leave HEAD put, write MERGE_HEAD and stage the
   --  change. And the merge-recursive/merge-tree backends reported a path
   --  deleted on one side as a content conflict instead of naming the
   --  modify/delete.
   procedure Merge_No_Commit_And_Modify_Delete_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         --  fast-forwardable: --no-commit must still fast-forward
         & " rm -rf ff nf md; mkdir ff; ( cd ff; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f.txt; git add -A; git commit -qm c1;"
         & "   git checkout -qb feature;"
         & "   printf 'a\nb\n' > f.txt; git add -A; git commit -qm c2;"
         & "   git checkout -q main;"
         & "   " & CLI & " merge --no-commit feature > /dev/null;"
         & "   test ""$(git rev-parse HEAD)"" = ""$(git rev-parse feature)"";"
         & "   test ! -f .git/MERGE_HEAD;"
         & "   test -z ""$(git status --short)"" );"
         --  --no-ff --no-commit is a real merge and must still pause
         & " cp -a ff nf; ( cd nf; git reset -q --hard main@{1} 2>/dev/null"
         & "     || git reset -q --hard HEAD~1;"
         & "   " & CLI & " merge --no-ff --no-commit feature > /dev/null;"
         & "   test -f .git/MERGE_HEAD );"
         --  a path deleted on one side is a modify/delete, named as git names it
         & " mkdir md; ( cd md; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   seq 1 20 | sed 's/$/ line/' > f.txt;"
         & "   git add -A; git commit -qm base;"
         & "   git checkout -qb side; git rm -q f.txt;"
         & "   printf 'diff\n' > g.txt; git add -A; git commit -qm replace;"
         & "   git checkout -q main; sed -i '3s/.*/EDIT/' f.txt;"
         & "   git add -A; git commit -qm modify;"
         & "   b=$(git merge-base main side);"
         & "   git merge-recursive $b -- main side > g.out 2>&1 || true;"
         & "   git reset -q --hard main;"
         & "   " & CLI & " merge-recursive $b -- main side > v.out 2>&1"
         & "     || true;"
         & "   grep -q 'CONFLICT (modify/delete): f.txt deleted in side' v.out;"
         & "   cmp -s g.out v.out )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_No_Commit_And_Modify_Delete_Match_Git;

   --  Regression: a checked-out executable took only the owner exec bit
   --  (744 under umask 022, 764 under 002) because the checkout path used
   --  GNAT.OS_Lib.Set_Executable. git creates the file 0777 & ~umask, so it
   --  is 755 and 775 respectively. Non-executables already matched.
   procedure Checkout_Exec_Bits_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf src; mkdir src; ( cd src; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf '#!/bin/sh\n' > run.sh; chmod +x run.sh;"
         & "   printf 'plain\n' > p.txt; git add -A; git commit -qm c1 );"
         --  clone under two umasks and compare the resulting modes with git
         & " for u in 002 022; do"
         & "   ( umask $u; rm -rf g o;"
         & "     git clone -q src g;"
         & "     " & CLI & " clone src o > /dev/null;"
         & "     test ""$(stat -c %a g/run.sh)"" = ""$(stat -c %a o/run.sh)"";"
         & "     test ""$(stat -c %a g/p.txt)"" = ""$(stat -c %a o/p.txt)"";"
         --  and again through the checkout path, not just the clone path
         & "     rm -f g/run.sh o/run.sh;"
         & "     ( cd g; git checkout -- run.sh );"
         & "     ( cd o; " & CLI & " restore run.sh > /dev/null );"
         & "     test ""$(stat -c %a g/run.sh)"" = ""$(stat -c %a o/run.sh)"" );"
         & " done");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Checkout_Exec_Bits_Match_Git;

   --  Regression: interpret-trailers. A new trailer landed after the "---"
   --  patch divider instead of in the trailer block before it; --unfold left
   --  continuation lines folded in whole-message output (it only worked under
   --  --only-trailers) and did not strip a leading tab; and the blank
   --  separator line git always emits was missing when no trailer was added.
   procedure Interpret_Trailers_Edge_Cases_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf t; mkdir t; ( cd t;"
         & "   printf 'subj\n' > m1.txt;"
         & "   printf 'subj\n\nbody\n' > m2.txt;"
         & "   printf 'subj\n\nSigned-off-by: A\n\tcont\n  more\n'"
         & "     > m3.txt;"
         & "   printf 'subj\n\nbody\n\nSigned-off-by: A <a@x>\n---\n"
         & " diff --git a/x b/x\n' > m4.txt;"
         & "   printf '\n' > m5.txt;"
         & "   : > m6.txt;"
         --  every message shape against every option combination
         & "   for m in m1 m2 m3 m4 m5 m6; do"
         & "     for o in '' '--unfold' '--only-trailers' '--parse'"
         & "              '--only-input'; do"
         & "       git interpret-trailers $o $m.txt > g.out 2>&1 || true;"
         & "       " & CLI & " interpret-trailers $o $m.txt > v.out 2>&1"
         & "         || true;"
         & "       cmp -s g.out v.out || { echo ""$m [$o]""; exit 1; };"
         & "     done;"
         & "     git interpret-trailers --trailer 'X: y' $m.txt > g.out 2>&1;"
         & "     " & CLI & " interpret-trailers --trailer 'X: y' $m.txt"
         & "       > v.out 2>&1;"
         & "     cmp -s g.out v.out || { echo ""$m trailer""; exit 1; };"
         & "     git interpret-trailers --where before --trailer 'X: y'"
         & "       $m.txt > g.out 2>&1;"
         & "     " & CLI & " interpret-trailers --where before"
         & "       --trailer 'X: y' $m.txt > v.out 2>&1;"
         & "     cmp -s g.out v.out || { echo ""$m before""; exit 1; };"
         & "   done )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Interpret_Trailers_Edge_Cases_Match_Git;

   --  Regression: pathspec handling in two plumbing commands. `diff-files`
   --  ignored its pathspec operands entirely and reported every changed file.
   --  `ls-tree` matched path operands as globs, so `*.txt` listed files git
   --  does not, and could not resolve a nested path like `d/sub` without -r
   --  because it only ever enumerated the top level.
   procedure Diff_Files_And_Ls_Tree_Pathspecs_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   mkdir -p d/sub;"
         & "   printf 'a\n' > a.txt; printf 'x\n' > d/x.txt;"
         & "   printf 'y\n' > d/sub/y.txt; printf 'z\n' > z.md;"
         & "   git add -A; git commit -qm c1;"
         --  ls-tree: literal paths, nested paths, and no glob expansion
         & "   for p in a.txt d d/sub d/x.txt d/sub/y.txt z.md nope '*.txt'; do"
         & "     git ls-tree HEAD ""$p"" > g.out;"
         & "     " & CLI & " ls-tree HEAD ""$p"" > v.out;"
         & "     cmp -s g.out v.out || { echo ""ls-tree $p""; exit 1; };"
         & "     git ls-tree -r HEAD ""$p"" > g.out;"
         & "     " & CLI & " ls-tree -r HEAD ""$p"" > v.out;"
         & "     cmp -s g.out v.out || { echo ""ls-tree -r $p""; exit 1; };"
         & "   done;"
         --  diff-files: the pathspec must actually filter
         & "   printf 'a2\n' > a.txt; printf 'x2\n' > d/x.txt;"
         & "   for p in a.txt d/x.txt nope; do"
         & "     git diff-files -- ""$p"" > g.out;"
         & "     " & CLI & " diff-files -- ""$p"" > v.out;"
         & "     cmp -s g.out v.out || { echo ""diff-files $p""; exit 1; };"
         & "   done;"
         & "   git diff-files > g.out; " & CLI & " diff-files > v.out;"
         & "   cmp -s g.out v.out )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Files_And_Ls_Tree_Pathspecs_Match_Git;

   --  Regression: ls-remote ignored --refs (it still printed HEAD and the
   --  peeled "^{}" entries git suppresses) and never matched its pattern
   --  operands, returning nothing for `ls-remote <repo> v1*`. git turns each
   --  pattern into "*/<pattern>" and wildmatches it against "/<refname>",
   --  where `*` crosses slashes -- and matches the full name, so a pattern
   --  ending before "^{}" excludes the peeled line.
   procedure Ls_Remote_Refs_And_Patterns_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf src; mkdir src; ( cd src; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f; git add -A; git commit -qm c1;"
         & "   git tag v1.0; git tag -a v2.0 -m two;"
         & "   git branch feature; git branch release/1 );"
         & " for a in '' '--refs' '--tags' '--tags --refs' '--heads'"
         & "          '--heads --refs'; do"
         & "   git ls-remote $a src > g.out;"
         & "   " & CLI & " ls-remote $a src > v.out;"
         & "   cmp -s g.out v.out || { echo ""flags [$a]""; exit 1; };"
         & " done;"
         & " for p in 'v1*' 'refs/tags/v*' feature 'release/*' '*/1' 'nope*'"
         & "          'v?.0' '*.0'; do"
         & "   git ls-remote src ""$p"" > g.out;"
         & "   " & CLI & " ls-remote src ""$p"" > v.out;"
         & "   cmp -s g.out v.out || { echo ""pattern [$p]""; exit 1; };"
         & "   git ls-remote --refs src ""$p"" > g.out;"
         & "   " & CLI & " ls-remote --refs src ""$p"" > v.out;"
         & "   cmp -s g.out v.out || { echo ""refs [$p]""; exit 1; };"
         & " done");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Ls_Remote_Refs_And_Patterns_Match_Git;

   --  Regression: `credential fill` accepted a record that cannot identify
   --  what it is for -- no host, or no protocol -- and exited 0 having echoed
   --  the partial input back. git dies with exit 128, checking host first.
   procedure Credential_Fill_Validation_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         --  missing host, missing protocol, and wholly empty input
         & "   rc=0; printf 'protocol=https\n\n' | " & CLI
         & "     credential fill > out 2> err || rc=$?;"
         & "   test $rc -eq 128;"
         & "   grep -q 'missing host field' err; test ! -s out;"
         & "   rc=0; printf 'host=example.com\n\n' | " & CLI
         & "     credential fill > out 2> err || rc=$?;"
         & "   test $rc -eq 128;"
         & "   grep -q 'missing protocol field' err; test ! -s out;"
         & "   rc=0; printf '\n' | " & CLI
         & "     credential fill > out 2> err || rc=$?;"
         & "   test $rc -eq 128;"
         & "   grep -q 'missing host field' err )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Credential_Fill_Validation_Matches_Git;

   --  Regression: merge-index exit statuses. git dies (128) at the first
   --  failing merge program, but under -q exits 1 silently; with -o it runs
   --  every path and then dies, or under -q exits with the failure count. It
   --  also refuses a named path that is not unmerged. version exited 128 for
   --  -q, 1 for -o, and silently succeeded on a missing path.
   procedure Merge_Index_Exit_Codes_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; printf '#!/bin/sh\nexit 1\n' > fail.sh;"
         & " chmod +x fail.sh;"
         & " mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'base\n' > a.txt; printf 'base\n' > b.txt;"
         & "   git add -A; git commit -qm base;"
         & "   git checkout -qb side;"
         & "   printf 's\n' > a.txt; printf 's\n' > b.txt;"
         & "   git add -A; git commit -qm s;"
         & "   git checkout -q main;"
         & "   printf 'm\n' > a.txt; printf 'm\n' > b.txt;"
         & "   git add -A; git commit -qm m;"
         & "   git merge side > /dev/null 2>&1 || true;"
         --  plain: dies with git's message and 128
         & "   rc=0; " & CLI & " merge-index ../fail.sh -a > /dev/null"
         & "     2> e1 || rc=$?;"
         & "   test $rc -eq 128; grep -q '^fatal: merge program failed$' e1;"
         --  -q: exit 1, no message
         & "   rc=0; " & CLI & " merge-index -q ../fail.sh -a > /dev/null"
         & "     2> e2 || rc=$?;"
         & "   test $rc -eq 1; test ! -s e2;"
         --  -o: every path attempted, then the same fatal
         & "   rc=0; " & CLI & " merge-index -o ../fail.sh -a > /dev/null"
         & "     2> e3 || rc=$?;"
         & "   test $rc -eq 128; grep -q '^fatal: merge program failed$' e3;"
         --  -o -q: exit status is the failure count (two conflicted paths)
         & "   rc=0; " & CLI & " merge-index -o -q ../fail.sh -a > /dev/null"
         & "     2> e4 || rc=$?;"
         & "   test $rc -eq 2; test ! -s e4;"
         --  a path that is not unmerged is fatal
         & "   rc=0; " & CLI & " merge-index ../fail.sh nope.txt > /dev/null"
         & "     2> e5 || rc=$?;"
         & "   test $rc -eq 128;"
         & "   grep -q 'not in the cache' e5 )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Index_Exit_Codes_Match_Git;

   --  Regression: a plain `fetch <remote>` never wrote .git/FETCH_HEAD, so
   --  anything reading it (fmt-merge-msg, scripted merges, `merge FETCH_HEAD`)
   --  saw nothing. Only the explicit-ref form recorded it. git writes one line
   --  per fetched branch, marking the current branch's upstream for-merge and
   --  listing it first.
   procedure Fetch_Head_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf src g o; mkdir src; ( cd src; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f; git add -A; git commit -qm c1;"
         & "   git branch feature; git branch other );"
         & " git clone -q src g; git clone -q src o;"
         & " ( cd src; printf 'b\n' >> f; git add -A; git commit -qm c2 );"
         & " ( cd g; git config user.email t@e; git config user.name T;"
         & "   git fetch origin > /dev/null 2>&1 );"
         & " ( cd o; git config user.email t@e; git config user.name T;"
         & "   " & CLI & " fetch origin > /dev/null 2>&1 );"
         & " test -f o/.git/FETCH_HEAD;"
         --  same lines, same order, same for-merge marking
         & " cmp -s g/.git/FETCH_HEAD o/.git/FETCH_HEAD");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fetch_Head_Matches_Git;

   --  Regression: index-pack. `-o <file>` wrote the requested index *and*
   --  left a stray one beside the pack, and `--stdin` printed a bare checksum
   --  where git prefixes it with "pack\t" (the caller cannot know the pack's
   --  name otherwise).
   procedure Index_Pack_Output_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r a b; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'l1\n' > f.txt; git add -A; git commit -qm c1;"
         & "   printf 'l2\n' >> f.txt; git add -A; git commit -qm c2;"
         & "   git rev-list --objects --all | awk '{print $1}'"
         & "     | git pack-objects --stdout > ../p.pack );"
         --  -o writes only the index it was asked for
         & " mkdir a; cp p.pack a/my.pack;"
         & " ( cd a; " & CLI & " index-pack -o custom.idx my.pack"
         & "     > /dev/null;"
         & "   test -f custom.idx; test ! -f my.idx );"
         --  --stdin reports "pack<TAB><checksum>", as git does
         & " mkdir b; ( cd b; git init -q .;"
         & "   " & CLI & " index-pack --stdin < ../p.pack > out;"
         & "   git init -q ../bg; ( cd ../bg;"
         & "     git index-pack --stdin < ../p.pack > ../b/gout );"
         & "   cmp -s out gout )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Index_Pack_Output_Matches_Git;

   --  Regression: mailinfo left RFC 2047 encoded-words raw ("=?UTF-8?Q?..?="
   --  in Author and Subject), stripped only the first leading bracket group,
   --  kept a leading "Re:", and printed an empty "Date:" line git omits.
   --  Base64 words additionally overflowed the decoder's accumulator.
   procedure Mailinfo_Headers_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1;"
         & " rm -rf m; mkdir m; ( cd m;"
         --  quoted-printable in both headers, and nested bracket groups
         & "   printf 'From: =?UTF-8?Q?Bj=C3=B6rn?= <b@x>\n"
         & "Subject: [PATCH 1/1] [RFC] Fix =?UTF-8?Q?=C3=A4?= thing\n"
         & "\nBody here.\n' > e1.txt;"
         --  base64 word, and a Date that must be echoed
         & "   printf 'From: P <p@x>\nDate: Mon, 3 Jul 2023 10:00:00 +0000\n"
         & "Subject: =?UTF-8?B?QmFzZTY0IHN1YmplY3Q=?=\n\nBody.\n' > e2.txt;"
         --  no date at all: git prints no Date line
         & "   printf 'From: N <n@x>\nSubject: plain\n\nBody.\n' > e3.txt;"
         --  a leading Re:, mixed case, ahead of a bracket group
         & "   printf 'From: A <a@x>\nSubject: re: RE: [PATCH] mixed\n"
         & "\nB.\n' > e4.txt;"
         --  Latin-1 must be transcoded to UTF-8, not passed through raw
         & "   printf 'From: =?ISO-8859-1?Q?Caf=E9?= <c@x>\n"
         & "Subject: =?utf-8?q?lower_case?=\n\nB.\n' > e5.txt;"
         & "   for e in e1 e2 e3 e4 e5; do"
         & "     git mailinfo g.msg g.patch < $e.txt > g.hdr 2>/dev/null;"
         & "     " & CLI & " mailinfo v.msg v.patch < $e.txt > v.hdr"
         & "       2>/dev/null;"
         & "     cmp -s g.hdr v.hdr || { echo ""hdr $e""; exit 1; };"
         & "     cmp -s g.msg v.msg || { echo ""msg $e""; exit 1; };"
         & "   done )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mailinfo_Headers_Match_Git;

   --  Regression: difftool compared HEAD against the working tree in both
   --  modes. git compares the index against the working tree, and under
   --  --cached HEAD against the index -- so a staged-then-modified file was
   --  shown with the wrong pair of sides either way.
   procedure Difftool_Sides_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         --  HEAD=B, index=C, worktree=D, so each pair is distinguishable
         & "   printf 'B\n' > f.txt; git add -A; git commit -qm c1;"
         & "   printf 'C\n' > f.txt; git add f.txt;"
         & "   printf 'D\n' > f.txt;"
         & "   git config difftool.x.cmd"
         & "     'echo LOCAL=$(cat ""$LOCAL"") REMOTE=$(cat ""$REMOTE"")';"
         & "   git difftool -y -t x > g.out 2>/dev/null;"
         & "   " & CLI & " difftool -y --tool=x > v.out 2>/dev/null;"
         & "   cmp -s g.out v.out;"
         & "   grep -q 'LOCAL=C REMOTE=D' v.out;"
         & "   git difftool -y --cached -t x > gc.out 2>/dev/null;"
         & "   " & CLI & " difftool -y --cached --tool=x > vc.out 2>/dev/null;"
         & "   cmp -s gc.out vc.out;"
         & "   grep -q 'LOCAL=B REMOTE=C' vc.out )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Difftool_Sides_Match_Git;

   --  Regression: check-attr treated every leading operand as an attribute
   --  name, guessing where the paths began by testing which operands named an
   --  existing file. git is simpler: without `--` the first operand is the one
   --  attribute and everything after it is a path (existing or not); with
   --  `--`, everything before it is an attribute.
   procedure Check_Attr_Operands_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf '*.txt text\n*.bin binary\n' > .gitattributes;"
         & "   printf 'x\n' > a.txt; printf 'y\n' > b.bin;"
         & "   git add -A; git commit -qm c1;"
         --  'binary' here is a PATH, not a second attribute
         & "   git check-attr text binary a.txt > g1 2>&1;"
         & "   " & CLI & " check-attr text binary a.txt > v1 2>&1;"
         & "   cmp -s g1 v1;"
         --  with --, both operands before it are attributes
         & "   git check-attr text binary -- a.txt b.bin > g2 2>&1;"
         & "   " & CLI & " check-attr text binary -- a.txt b.bin > v2 2>&1;"
         & "   cmp -s g2 v2;"
         --  a path that does not exist is still a path
         & "   git check-attr text nope.txt > g3 2>&1;"
         & "   " & CLI & " check-attr text nope.txt > v3 2>&1;"
         & "   cmp -s g3 v3;"
         & "   git check-attr -a a.txt b.bin > g4 2>&1;"
         & "   " & CLI & " check-attr -a a.txt b.bin > v4 2>&1;"
         & "   cmp -s g4 v4 )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Check_Attr_Operands_Match_Git;

   --  Regression: for-each-repo ran the command in every configured
   --  repository even after one failed. git stops at the first failure and
   --  exits with that command's status, so a scripted sweep does not keep
   --  going after something has already gone wrong.
   procedure For_Each_Repo_Stops_On_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r1 r2 cfg;"
         & " for r in r1 r2; do git init -q -b main $r;"
         & "   ( cd $r; git config user.email t@e; git config user.name T;"
         & "     printf 'a\n' > f; git add -A; git commit -qm c1 );"
         & " done;"
         & " git init -q -b main cfg; ( cd cfg;"
         & "   git config user.email t@e; git config user.name T;"
         & "   git config --add for-each.k ../r1;"
         & "   git config --add for-each.k ../r2;"
         --  success: the command runs in both repositories
         & "   " & CLI & " for-each-repo --config=for-each.k --"
         & "     rev-parse HEAD > ok.out 2>&1;"
         & "   test ""$(wc -l < ok.out)"" = 2;"
         --  failure: it stops after the first, so only one error is reported
         & "   rc=0;"
         & "   " & CLI & " for-each-repo --config=for-each.k --"
         & "     rev-parse refs/heads/nope > /dev/null 2> bad.err || rc=$?;"
         & "   test $rc -ne 0;"
         & "   test ""$(wc -l < bad.err)"" = 1 )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end For_Each_Repo_Stops_On_Failure;

   --  Regression: fmt-merge-msg wrote "of <url>" once per kind and joined the
   --  kinds with "; ", so a branch and a tag from one remote read
   --  "branch 'a' of U; tag 't' of U" where git writes
   --  "branch 'a', tag 't' of U". A description that is just a URL (a HEAD
   --  fetch) produced no output at all.
   procedure Fmt_Merge_Msg_Grouping_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf r; mkdir r; ( cd r; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f; git add -A; git commit -qm c1;"
         & "   s=$(git rev-parse HEAD);"
         --  one FETCH_HEAD shape per case, compared with git
         & "   run () {"
         & "     printf ""$1"" > fh.txt;"
         & "     git fmt-merge-msg -F fh.txt > g.out 2>&1 || true;"
         & "     " & CLI & " fmt-merge-msg -F fh.txt > v.out 2>&1 || true;"
         & "     cmp -s g.out v.out || { echo ""case: $2""; exit 1; };"
         & "   };"
         & "   run ""$s\t\tbranch 'a' of U\n"" one-branch;"
         & "   run ""$s\t\tbranch 'a' of U\n$s\t\tbranch 'b' of U\n"""
         & "     two-branches;"
         & "   run ""$s\t\tbranch 'a' of U\n$s\t\tbranch 'b' of U\n"
         & "$s\t\tbranch 'c' of U\n"" three-branches;"
         & "   run ""$s\t\tbranch 'a' of U\n$s\t\ttag 't1' of U\n"""
         & "     branch-and-tag;"
         & "   run ""$s\t\tbranch 'a' of U\n$s\t\ttag 't1' of U\n"
         & "$s\t\ttag 't2' of U\n"" branch-and-two-tags;"
         & "   run ""$s\t\tbranch 'a' of U1\n$s\t\tbranch 'b' of U2\n"""
         & "     two-urls;"
         & "   run ""$s\t\tU\n"" url-only;"
         & "   run ""$s\t\tU\n$s\t\tbranch 'a' of U\n"" url-and-branch;"
         & "   run ""$s\t\tbranch 'a'\n"" local-branch;"
         & "   run ""$s\tnot-for-merge\tbranch 'a' of U\n"" not-for-merge )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fmt_Merge_Msg_Grouping_Matches_Git;

   --  Regression: `commit-graph write` wrote a graph from the refs even with
   --  no packs, where git's plain form reads the pack indexes and so writes
   --  nothing (only --reachable walks refs). And `maintenance run
   --  --task=pack-refs` / `--task=commit-graph` were stubs that did nothing,
   --  although version has both capabilities.
   procedure Commit_Graph_And_Maintenance_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " seed () { rm -rf $1; git init -q -b main $1;"
         & "   ( cd $1; git config user.email t@e; git config user.name T;"
         & "     printf 'l1\n' > f.txt; git add -A; git commit -qm c1;"
         & "     printf 'l2\n' >> f.txt; git add -A; git commit -qm c2;"
         & "     git branch b1 ); };"
         --  loose objects only: git writes no graph, and neither must we
         & " seed a; ( cd a; " & CLI & " commit-graph write > /dev/null 2>&1;"
         & "   test ! -e .git/objects/info/commit-graph );"
         --  --reachable walks the refs and does write one
         & " seed b; ( cd b;"
         & "   " & CLI & " commit-graph write --reachable > /dev/null 2>&1;"
         & "   test -f .git/objects/info/commit-graph;"
         --  and real git must be able to verify what we wrote
         & "   git commit-graph verify );"
         --  maintenance tasks do their work instead of silently passing
         & " seed c; ( cd c;"
         & "   " & CLI & " maintenance run --task=pack-refs > /dev/null 2>&1;"
         & "   test -f .git/packed-refs );"
         & " seed d; ( cd d;"
         & "   " & CLI & " maintenance run --task=commit-graph"
         & "     > /dev/null 2>&1;"
         & "   test -f .git/objects/info/commit-graph;"
         & "   git commit-graph verify )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Commit_Graph_And_Maintenance_Match_Git;

   --  Regression: `hook run` only looked in .git/hooks, so hooks declared in
   --  configuration (hook.<id>.event / hook.<id>.command) never ran -- git
   --  runs those first, in config order, then the hookdir hook, and a failing
   --  one supplies the exit status. `mktree` also accepted a blank line
   --  outside batch mode and wrote a tree, where git rejects the input.
   procedure Hook_Run_And_Mktree_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " rm -rf h; mkdir h; ( cd h; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   git config hook.a.event pre-commit;"
         & "   git config hook.a.command 'echo CONFIG-A';"
         & "   git config hook.b.event pre-commit;"
         & "   git config hook.b.command 'echo CONFIG-B';"
         & "   mkdir -p .git/hooks;"
         & "   printf '#!/bin/sh\necho FILE-HOOK\n' > .git/hooks/pre-commit;"
         & "   chmod +x .git/hooks/pre-commit;"
         --  config hooks run in order, then the hookdir hook
         & "   git hook run pre-commit > g.out 2>&1;"
         & "   " & CLI & " hook run pre-commit > v.out 2>&1;"
         & "   cmp -s g.out v.out;"
         --  a failing config hook stops the run and sets the status
         & "   git config hook.c.event pre-commit;"
         & "   git config hook.c.command 'exit 3';"
         & "   rc=0; " & CLI & " hook run pre-commit > /dev/null 2>&1 || rc=$?;"
         & "   test $rc -eq 3 );"
         --  mktree rejects a blank line outside batch mode
         & " rm -rf m; mkdir m; ( cd m; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   b=$(printf 'x\n' | git hash-object -w --stdin);"
         & "   printf '100644 blob %s\ta.txt\n\n' ""$b"" > blank.in;"
         & "   printf '100644 blob %s\ta.txt\n' ""$b"" > ok.in;"
         & "   rc=0; " & CLI & " mktree < blank.in > /dev/null 2> e || rc=$?;"
         & "   test $rc -eq 128;"
         & "   grep -q 'blank line only valid in batch mode' e;"
         --  a well-formed input still produces git's tree id
         & "   git mktree < ok.in > g.id;"
         & "   " & CLI & " mktree < ok.in > v.id;"
         & "   cmp -s g.id v.id )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Hook_Run_And_Mktree_Match_Git;

   --  Regression: `lfs pointer` appended a newline the pointer must not have
   --  (Ada.Text_IO.Put leaves the runtime mid-line and GNAT terminates it at
   --  exit), which changes the bytes the pointer's object id is computed over.
   --  `lfs status --porcelain` was accepted and ignored, printing the human
   --  form instead of git-lfs's short one.
   procedure Lfs_Pointer_And_Status_Match_Git_Lfs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         --  git-lfs may not be installed; the pointer check needs it
         & " command -v git-lfs > /dev/null 2>&1 || exit 0;"
         & " rm -rf p; mkdir p; ( cd p; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'binary content here\n' > file.bin;"
         & "   git lfs pointer --file=file.bin > g.ptr 2>/dev/null;"
         & "   " & CLI & " lfs pointer --file=file.bin > v.ptr 2>/dev/null;"
         --  byte-exact: no trailing newline beyond the pointer itself
         & "   cmp -s g.ptr v.ptr );"
         --  --porcelain reports git-lfs's short codes, per kind of change
         & " rm -rf s; mkdir s; ( cd s; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   git lfs track '*.bin' > /dev/null 2>&1;"
         & "   printf 'data\n' > f.bin; git add -A > /dev/null 2>&1;"
         & "   git commit -qm c1 > /dev/null 2>&1;"
         & "   printf 'changed\n' > f.bin;"
         & "   git lfs status --porcelain > g.out 2>/dev/null;"
         & "   " & CLI & " lfs status --porcelain > v.out 2>/dev/null;"
         & "   cmp -s g.out v.out;"
         & "   rm -f f.bin;"
         & "   git lfs status --porcelain > gd.out 2>/dev/null;"
         & "   " & CLI & " lfs status --porcelain > vd.out 2>/dev/null;"
         & "   cmp -s gd.out vd.out )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Lfs_Pointer_And_Status_Match_Git_Lfs;

   --  Regression: `multi-pack-index verify` checked only the trailing
   --  checksum, so a structurally corrupt file whose hash had been recomputed
   --  passed silently -- exactly the shape a broken writer produces. It also
   --  covers `bundle create --all`, which bundled only the branches and left
   --  every tag (and HEAD) out.
   procedure Midx_Verify_And_Bundle_All_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         --  bundle --all must carry tags and HEAD, like git
         & " rm -rf b; mkdir b; ( cd b; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'a\n' > f; git add -A; git commit -qm c1;"
         & "   git tag light; git tag -a annot -m msg; git branch feature;"
         & "   git bundle create g.bundle --all > /dev/null 2>&1;"
         & "   " & CLI & " bundle create v.bundle --all > /dev/null 2>&1;"
         & "   git bundle list-heads g.bundle > g.heads 2>/dev/null;"
         & "   git bundle list-heads v.bundle > v.heads 2>/dev/null;"
         & "   cmp -s g.heads v.heads;"
         --  and git must accept what we wrote
         & "   git bundle verify v.bundle > /dev/null 2>&1 );"
         --  a re-checksummed structural corruption must still be caught
         & " rm -rf m; mkdir m; ( cd m; git init -q -b main;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'l1\n' > f.txt; git add -A; git commit -qm c1;"
         & "   printf 'l2\n' >> f.txt; git add -A; git commit -qm c2;"
         & "   git repack -ad > /dev/null 2>&1;"
         & "   git multi-pack-index write > /dev/null 2>&1;"
         & "   test -f .git/objects/pack/multi-pack-index || exit 0;"
         --  healthy file is accepted
         & "   " & CLI & " multi-pack-index verify > /dev/null 2>&1;"
         --  Corrupt the fanout and recompute the trailer, so only a
         --  structural check can notice. The script is written through a
         --  quoted here-doc and uses single quotes throughout, so nothing
         --  needs escaping on the way through Ada or the shell.
         & "   cat > corrupt.py <<'PYEOF'" & ASCII.LF
         & "import struct,hashlib" & ASCII.LF
         & "p='.git/objects/pack/multi-pack-index'" & ASCII.LF
         & "d=bytearray(open(p,'rb').read())" & ASCII.LF
         & "n=d[6]; o=12; c={}" & ASCII.LF
         & "for i in range(n+1):" & ASCII.LF
         & "    c[bytes(d[o:o+4])]=struct.unpack('>Q',d[o+4:o+12])[0]"
         & ASCII.LF
         & "    o+=12" & ASCII.LF
         & "struct.pack_into('>I',d,c[b'OIDF']+512,1000)" & ASCII.LF
         & "d[-20:]=hashlib.sha1(bytes(d[:-20])).digest()" & ASCII.LF
         & "open(p,'wb').write(bytes(d))" & ASCII.LF
         & "PYEOF" & ASCII.LF
         & "   python3 corrupt.py;"
         & "   rc=0;"
         & "   " & CLI & " multi-pack-index verify > /dev/null 2>&1 || rc=$?;"
         & "   test $rc -ne 0 )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Midx_Verify_And_Bundle_All_Match_Git;

   --  Regression: `filter-branch --subdirectory-filter` kept commits that
   --  never touched the subdirectory, so the rewritten history carried empty
   --  commits git prunes (it remaps them onto their ancestor). Also: a repack
   --  now refreshes objects/info/packs and the commit-graph, as git's gc does.
   procedure Filter_Branch_And_Repack_Artifacts_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C GIT_CONFIG_NOSYSTEM=1"
         & " FILTER_BRANCH_SQUELCH_WARNING=1"
         & " GIT_AUTHOR_DATE='1700000000 +0000'"
         & " GIT_COMMITTER_DATE='1700000000 +0000';"
         & " seed () { rm -rf $1; git init -q -b main $1;"
         & "   ( cd $1; git config user.email t@e; git config user.name T;"
         & "     mkdir -p sub;"
         & "     printf 'a\n' > sub/f.txt; git add -A; git commit -qm c1;"
         & "     printf 'b\n' >> sub/f.txt; git add -A; git commit -qm c2;"
         & "     printf 'r\n' > root.txt; git add -A; git commit -qm c3root;"
         & "     printf 'c\n' >> sub/f.txt; git add -A; git commit -qm c4 );"
         & " };"
         --  the commit that left sub/ untouched must not survive
         & " seed g; seed o;"
         & " ( cd g; git filter-branch -f --subdirectory-filter sub"
         & "     > /dev/null 2>&1 );"
         & " ( cd o; " & CLI & " filter-branch -f --subdirectory-filter sub"
         & "     > /dev/null 2>&1 );"
         & " git -C g log --format=%s > g.subjects;"
         & " git -C o log --format=%s > o.subjects;"
         & " cmp -s g.subjects o.subjects;"
         & " test ""$(git -C g rev-parse HEAD^{tree})"""
         & "   = ""$(git -C o rev-parse HEAD^{tree})"";"
         --  a repack leaves the pack list and commit-graph git expects
         & " rm -rf p; git init -q -b main p; ( cd p;"
         & "   git config user.email t@e; git config user.name T;"
         & "   printf 'x\n' > f; git add -A; git commit -qm c1;"
         & "   printf 'y\n' >> f; git add -A; git commit -qm c2;"
         & "   " & CLI & " gc > /dev/null 2>&1;"
         & "   test -f .git/objects/info/packs;"
         & "   grep -q '^P .*\.pack$' .git/objects/info/packs;"
         & "   test -f .git/objects/info/commit-graph;"
         --  and git accepts what we wrote
         & "   git commit-graph verify; git fsck > /dev/null )");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Filter_Branch_And_Repack_Artifacts_Match_Git;

   --  Byte-oracle the remaining plumbing: var, count-objects, rev-parse @{n},
   --  name-rev, and for-each-ref %(upstream).
   procedure Extra_Plumbing_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      procedure Oracle (Cmd : String) is
      begin
         Version.Git_Fixtures.Run
           (Root,
            "test ""$(" & CLI & " " & Cmd & ")"" = ""$(git " & Cmd & ")""");
      end Oracle;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "f.txt", "one" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Write.Save ("c1");
      Version.Git_Fixtures.Run (Root, "git tag -a v1.0 -m rel");
      Write_File (Root, "f.txt", "two" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Write.Save ("c2");
      Write_File (Root, "f.txt", "three" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Write.Save ("c3");
      --  An upstream for %(upstream).
      Version.Git_Fixtures.Run (Root, "git remote add origin /tmp/x.git");
      Version.Git_Fixtures.Run (Root, "git config branch.main.remote origin");
      Version.Git_Fixtures.Run
        (Root, "git config branch.main.merge refs/heads/main");

      Oracle ("count-objects");
      Oracle ("rev-parse HEAD@{0}");
      Oracle ("rev-parse HEAD@{1}");
      Oracle ("rev-parse @{2}");
      Oracle ("name-rev HEAD");
      Oracle ("name-rev v1.0");
      Oracle ("name-rev --tags HEAD");
      Oracle ("for-each-ref"
              & " --format='%(refname:short) %(upstream) %(upstream:short)'"
              & " refs/heads");
      --  var with a fixed raw date so the identity is reproducible.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(GIT_AUTHOR_DATE='1577836800 +0000' " & CLI
         & " var GIT_AUTHOR_IDENT)"""
         & " = ""$(GIT_AUTHOR_DATE='1577836800 +0000' git var"
         & " GIT_AUTHOR_IDENT)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Extra_Plumbing_Matches_Git;

   --  `diff --name-only`/`--name-status` (with add/delete/modify) match git.
   procedure Diff_Name_Only_Matches_Git
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
      Write_File (Root, "keep.txt", "l1" & LF & "l2" & LF);
      Write_File (Root, "gone.txt", "x" & LF);
      Version.Git_Fixtures.Run (Root, "git add keep.txt gone.txt");
      Version.Write.Save ("c1");
      Write_File (Root, "keep.txt", "l1" & LF & "CHG" & LF);  --  modify
      Write_File (Root, "added.txt", "new" & LF);            --  add
      Version.Git_Fixtures.Run (Root, "rm gone.txt");         --  delete
      Version.Git_Fixtures.Run (Root, "git add -A");
      Version.Write.Save ("c2");

      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " diff --name-only HEAD~1 HEAD)"""
         & " = ""$(git diff --name-only HEAD~1 HEAD)""");
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " diff --name-status HEAD~1 HEAD)"""
         & " = ""$(git diff --name-status HEAD~1 HEAD)""");
      --  The full unified diff must be byte-identical too: the LCS must keep
      --  the unchanged middle line as context (minimal, Myers-like) rather
      --  than deleting and re-adding it.
      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " diff HEAD~1 HEAD)"""
         & " = ""$(git diff HEAD~1 HEAD)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Name_Only_Matches_Git;

   --  `cat-file --batch-check --batch-all-objects` must enumerate every object
   --  (loose AND packed) in git's oid order. Exercises the pack-index reader.
   procedure Cat_File_Batch_All_Objects_Matches_Git
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
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Version.Write.Save ("c1");
      Version.Git_Fixtures.Run (Root, "git tag -a v1 -m rel");
      Write_File (Root, "b.txt", "world" & LF);
      Version.Git_Fixtures.Run (Root, "git add b.txt");
      Version.Write.Save ("c2");
      --  Pack everything, then add a loose object, so the enumeration must
      --  merge packed and loose ids.
      Version.Git_Fixtures.Run (Root, "git repack -adq");
      Write_File (Root, "c.txt", "loose" & LF);
      Version.Git_Fixtures.Run (Root, "git add c.txt");
      Version.Write.Save ("c3");

      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " cat-file --batch-check --batch-all-objects)"""
         & " = ""$(git cat-file --batch-check --batch-all-objects)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Cat_File_Batch_All_Objects_Matches_Git;

   --  Regression: `mv FILE DIR/` (trailing slash) and `mv FILE DIR` (bare)
   --  must both move the file into the directory, matching git. The trailing
   --  slash previously produced a "DIR//FILE" path and moved nothing.
   procedure Mv_Into_Directory_Matches_Git
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
      Write_File (Root, "a.txt", "a" & LF);
      Write_File (Root, "b.txt", "b" & LF);
      Version.Git_Fixtures.Run (Root, "git add a.txt b.txt");
      Version.Write.Save ("first");
      Version.Git_Fixtures.Run (Root, "mkdir sub");

      --  Trailing slash and bare directory forms.
      Version.Git_Fixtures.Run (Root, CLI & " mv a.txt sub/");
      Version.Git_Fixtures.Run (Root, CLI & " mv b.txt sub");

      Version.Git_Fixtures.Run
        (Root,
         "test ""$(git ls-files)"" = ""$(printf 'sub/a.txt\nsub/b.txt')""");
      Version.Git_Fixtures.Run
        (Root,
         "test ! -e a.txt && test ! -e b.txt"
         & " && test -e sub/a.txt && test -e sub/b.txt");
      Version.Git_Fixtures.Run (Root, "git fsck --strict");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mv_Into_Directory_Matches_Git;

   --  Regression: `version blame` default output must match `git blame`
   --  byte-for-byte (boundary "^" marker, author/date columns, and padding).
   procedure Blame_Matches_Git
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
      --  Two authors across two commits, and >9 lines, exercise the author
      --  column padding, the boundary caret, and line-number alignment.
      Version.Git_Fixtures.Run (Root, "git config user.name alice");
      Write_File
        (Root, "f.txt",
         "l1" & LF & "l2" & LF & "l3" & LF & "l4" & LF & "l5" & LF
         & "l6" & LF & "l7" & LF & "l8" & LF & "l9" & LF & "l10" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Git_Fixtures.Run
        (Root, "GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' git commit -q -m c1");
      Version.Git_Fixtures.Run (Root, "git config user.name bob");
      Write_File
        (Root, "f.txt",
         "l1" & LF & "l2" & LF & "CHG" & LF & "l4" & LF & "l5" & LF
         & "l6" & LF & "l7" & LF & "l8" & LF & "l9" & LF & "l10" & LF);
      Version.Git_Fixtures.Run (Root, "git add f.txt");
      Version.Git_Fixtures.Run
        (Root, "GIT_AUTHOR_DATE='2021-06-15T12:30:45 +0200' git commit -q -m c2");

      Version.Git_Fixtures.Run
        (Root,
         "test ""$(" & CLI & " blame f.txt)"" = ""$(git blame f.txt)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Blame_Matches_Git;

   --  `switch` mutates HEAD, so it can't be diffed in place. Build two
   --  byte-identical repos (fixed author + committer dates => identical
   --  hashes), run the same switch sequence through git and through version,
   --  and require the accumulated stdout to match exactly -- covering the new
   --  branch, "-" previous-branch, existing branch, --detach, and the
   --  "Previous HEAD position was" line emitted when leaving a detached HEAD.
   procedure Switch_Matches_Git
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

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; D=""$PWD""; "
         & "export GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' "
         & "GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000'; "
         & "build() { rm -rf ""$1""; mkdir ""$1""; cd ""$1""; "
         & "git init -q -b main .; git config user.name T; "
         & "git config user.email t@e; git config gc.auto 0; "
         & "echo a > f; git add f; git commit -qm c1; "
         & "echo b >> f; git commit -qam c2; cd ""$D""; }; "
         & "runseq() { cd ""$1""; ""$2"" switch -c feature; ""$2"" switch -; "
         & """$2"" switch feature; ""$2"" switch --detach HEAD~1; "
         & """$2"" switch main; ""$2"" switch --detach HEAD; cd ""$D""; }; "
         & "build g; build v; "
         --  git writes these advisories to stderr, version to stdout; this
         --  test asserts text parity, so fold both streams for the compare.
         & "gout=""$(runseq g git 2>&1)""; "
         & "vout=""$(runseq v " & CLI & " 2>&1)""; "
         & "test ""$vout"" = ""$gout""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Switch_Matches_Git;

   --  `hook run` streams the hook's stdout/stderr and propagates its exit
   --  code; a missing hook errors with exit 1 unless --ignore-missing. Assert
   --  each against git in the same repo (hook run does not mutate state).
   procedure Hook_Run_Matches_Git
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

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & "mkdir -p .git/hooks; "
         & "printf '#!/bin/sh\necho ""hook out $@""\n"
         & "echo err >&2\nexit 3\n' > .git/hooks/pre-commit; "
         & "chmod +x .git/hooks/pre-commit; "
         --  existing hook: merged output and exit code both match git
         & "test ""$(" & CLI & " hook run pre-commit -- a b 2>&1)"" "
         & "= ""$(git hook run pre-commit -- a b 2>&1)""; "
         & CLI & " hook run pre-commit >/dev/null 2>&1 && ec=0 || ec=$?; "
         & "test $ec -eq 3; "
         --  missing hook: error text matches git and exit is 1
         & "test ""$(" & CLI & " hook run post-commit 2>&1)"" "
         & "= ""$(git hook run post-commit 2>&1)""; "
         & "if " & CLI & " hook run post-commit >/dev/null 2>&1; "
         & "then false; else test $? -eq 1; fi; "
         --  --ignore-missing: silent success on a missing hook
         & CLI & " hook run post-commit --ignore-missing; test $? -eq 0");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Hook_Run_Matches_Git;

   --  `maintenance run` performs repository maintenance silently (like git),
   --  leaving the repository git-valid; a bad --task errors as git does.
   procedure Maintenance_Run_Matches_Git
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
      Version.Git_Fixtures.Run (Root, "git config user.name T");
      Version.Git_Fixtures.Run (Root, "git config user.email t@e");
      Write_File (Root, "f", "l1" & LF);
      Version.Git_Fixtures.Run (Root, "git add f");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");
      Write_File (Root, "f", "l1" & LF & "l2" & LF);
      Version.Git_Fixtures.Run (Root, "git add f");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c2");

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         --  a maintenance run is silent, exits 0, and keeps the repo valid
         & "out=""$(" & CLI & " maintenance run 2>&1)""; test -z ""$out""; "
         & CLI & " maintenance run --task=gc --quiet; "
         & "git fsck --strict >/dev/null 2>&1; "
         & "test ""$(git log --oneline | wc -l)"" = 2; "
         --  an unknown task is rejected with git's message and non-zero exit
         & CLI & " maintenance run --task=bogus >/dev/null 2>&1 "
         & "&& ec=0 || ec=$?; test $ec -ne 0; "
         & "test ""$(" & CLI & " maintenance run --task=bogus 2>&1 "
         & "| head -1)"" = ""error: 'bogus' is not a valid task""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Maintenance_Run_Matches_Git;

   --  `interpret-trailers` output must match git byte-for-byte across the
   --  common shapes: appending to an existing trailer block, opening a new
   --  block, --only-trailers extraction, --parse folding, and the empty-value
   --  normalisation ("Fixes: ").
   procedure Interpret_Trailers_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      function Both (Input, Args : String) return String is
        ("test ""$(printf '" & Input & "' | " & CLI
         & " interpret-trailers " & Args & " 2>&1)"" = "
         & """$(printf '" & Input & "' | git interpret-trailers "
         & Args & " 2>&1)""; ");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & Both ("subject\n\nbody\n\nSigned-off-by: A <a@x>\n",
                 "--trailer 'Reviewed-by: B <b@y>'")
         & Both ("subject\n", "--trailer 'Helped-by: D'")
         & Both ("subject\n\nSigned-off-by: A\n", "--trailer 'ack=E'")
         & Both ("subject\n\nbody\n\nSigned-off-by: A\nAcked-by: B\n",
                 "--only-trailers")
         & Both ("subject\n\nbody\n\nSigned-off-by: A\nfold: a\n b\n",
                 "--parse")
         & Both ("subject\n\nSigned-off-by: A\n", "--where before --trailer 'X: 1'")
         & Both ("subject\n\nSigned-off-by: A\n", "--trailer 'Fixes:'"));

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Interpret_Trailers_Matches_Git;

   --  `stripspace` output must match git byte-for-byte for the default cleanup
   --  and the -s/-c modes.
   procedure Stripspace_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      function Both (Input, Args : String) return String is
        ("test ""$(printf '" & Input & "' | " & CLI
         & " stripspace " & Args & " 2>&1 | cat -A)"" = "
         & """$(printf '" & Input & "' | git stripspace "
         & Args & " 2>&1 | cat -A)""; ");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & Both ("a  \n\n\n\nb\t\n\n\n", "")
         & Both ("\n\n\nhello\n\n\n", "")
         & Both ("x", "")
         & Both ("# comment\ntext\n# another\n", "-s")
         & Both ("hello\n\nworld\n", "-c")
         & Both ("a  \n\n\n\nb\n\n", "-c")
         & Both ("  # kept\ntext\n", "--strip-comments"));

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Stripspace_Matches_Git;

   --  `check-ref-format` validity (exit code) and --normalize output must
   --  match git across the refname grammar and the refspec-pattern glob.
   procedure Check_Ref_Format_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      --  Compare the exit code of version vs git for one refname + flags.
      function Rc (Ref, Flags : String) return String is
        (CLI & " check-ref-format " & Flags & " '" & Ref
         & "' >/dev/null 2>&1 && a=0 || a=$?; "
         & "git check-ref-format " & Flags & " '" & Ref
         & "' >/dev/null 2>&1 && b=0 || b=$?; test ""$a"" = ""$b""; ");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & Rc ("heads/main", "")
         & Rc ("main", "")
         & Rc ("main", "--allow-onelevel")
         & Rc ("refs/heads/.hidden", "")
         & Rc ("refs/heads/foo..bar", "")
         & Rc ("refs/heads/foo.lock", "")
         & Rc ("refs/heads/foo.", "")
         & Rc ("refs/heads./x", "")
         & Rc ("refs/heads/foo~1", "")
         & Rc ("refs/heads/@", "")
         & Rc ("@", "")
         & Rc ("refs/heads/*", "")
         & Rc ("refs/heads/*", "--refspec-pattern")
         & Rc ("refs/heads/**", "--refspec-pattern")
         --  --normalize prints the collapsed name when valid
         & "test ""$(" & CLI
         & " check-ref-format --normalize 'refs/heads//foo' 2>&1)"" = "
         & """$(git check-ref-format --normalize 'refs/heads//foo' 2>&1)""; "
         & "test ""$(" & CLI
         & " check-ref-format --branch main 2>&1)"" = "
         & """$(git check-ref-format --branch main 2>&1)""");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Check_Ref_Format_Matches_Git;

   --  `mktree` must produce the same tree oid as git for sorted, unsorted, and
   --  mixed blob/subtree input (exercising git tree-order + serialisation).
   procedure Mktree_Matches_Git
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

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & "H=$(printf hello | git hash-object --stdin -w); "
         & "H2=$(printf world | git hash-object --stdin -w); "
         & "SUB=$(printf '100644 blob '""$H""'\tinner\n' | git mktree); "
         & "cmp() { "
         & "test ""$(printf ""$1"" | " & CLI & " mktree 2>&1)"" "
         & "= ""$(printf ""$1"" | git mktree 2>&1)""; }; "
         & "cmp '100644 blob '""$H""'\tf\n'; "
         & "cmp '100644 blob '""$H2""'\tb\n100644 blob '""$H""'\ta\n'; "
         & "cmp '040000 tree '""$SUB""'\tfoo\n100644 blob '""$H""'\tfoo.txt\n'; "
         & "cmp '0100644 blob '""$H""'\tz\n'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mktree_Matches_Git;

   --  `mktag` writes a caller-supplied tag object; its oid must equal git's,
   --  and a type mismatch must be rejected.
   procedure Mktag_Matches_Git
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
      Write_File (Root, "z", "z" & LF);
      Version.Git_Fixtures.Run (Root, "git add z");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; C=$(git rev-parse HEAD); "
         & "body=""object $C\ntype commit\ntag v1\n"
         & "tagger T <t@e> 1600000000 +0000\n\nmsg\n""; "
         --  the tag oid matches git mktag exactly
         & "test ""$(printf ""$body"" | " & CLI & " mktag 2>/dev/null)"" "
         & "= ""$(printf ""$body"" | git mktag 2>/dev/null)""; "
         --  a wrong declared type is rejected (non-zero exit)
         & "bad=""object $C\ntype blob\ntag v1\n"
         & "tagger T <t@e> 1600000000 +0000\n\nmsg\n""; "
         & "if printf ""$bad"" | " & CLI & " mktag >/dev/null 2>&1; "
         & "then false; else true; fi");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Mktag_Matches_Git;

   --  `fmt-merge-msg` must reproduce git's merge-message grouping across the
   --  common FETCH_HEAD shapes: single/local branches, same/different source
   --  grouping, an annotated tag (whose message is appended), and skipping
   --  not-for-merge lines.
   procedure Fmt_Merge_Msg_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      function Both (Input : String) return String is
        ("test ""$(printf '" & Input & "' | " & CLI
         & " fmt-merge-msg 2>&1)"" = "
         & """$(printf '" & Input & "' | git fmt-merge-msg 2>&1)""; ");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "f", "a" & LF);
      Version.Git_Fixtures.Run (Root, "git add f");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");
      Version.Git_Fixtures.Run (Root, "git branch feature");
      Version.Git_Fixtures.Run (Root, "git branch topic");
      Version.Git_Fixtures.Run (Root, "git tag -a v1 -m 'tag one'");

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & "C=$(git rev-parse feature); D=$(git rev-parse topic); "
         & "V=$(git rev-parse v1); "
         & Both ("'""$C""'\t\tbranch '\''feature'\'' of ../repo\n")
         & Both ("'""$C""'\t\tbranch '\''feature'\''\n")
         & Both ("'""$C""'\t\tbranch '\''feature'\'' of ../repo\n"
                 & "'""$D""'\t\tbranch '\''topic'\'' of ../repo\n")
         & Both ("'""$C""'\t\tbranch '\''feature'\''\n"
                 & "'""$D""'\t\tbranch '\''topic'\''\n")
         & Both ("'""$C""'\t\tbranch '\''feature'\'' of ../repoA\n"
                 & "'""$D""'\t\tbranch '\''topic'\'' of ../repoB\n")
         & Both ("'""$V""'\t\ttag '\''v1'\''\n")
         & Both ("'""$C""'\t\tbranch '\''feature'\''\n"
                 & "'""$V""'\t\ttag '\''v1'\''\n")
         & Both ("'""$C""'\tnot-for-merge\tbranch '\''feature'\''\n"
                 & "'""$D""'\t\tbranch '\''topic'\''\n"));

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fmt_Merge_Msg_Matches_Git;

   --  version's `archive` now embeds git's pax global header, so both
   --  `get-tar-commit-id` implementations recover the commit id from a
   --  version-produced tar and from a git-produced tar alike.
   procedure Get_Tar_Commit_Id_Matches_Git
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
      Write_File (Root, "f", "a" & LF);
      Version.Git_Fixtures.Run (Root, "git add f");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; C=$(git rev-parse HEAD); "
         & "git archive --format=tar HEAD > g.tar; "
         & CLI & " archive HEAD --output v.tar; "
         --  the commit id is recovered from git's and version's tars, by
         --  both tools, and equals HEAD
         & "test ""$(" & CLI & " get-tar-commit-id < g.tar)"" = ""$C""; "
         & "test ""$(" & CLI & " get-tar-commit-id < v.tar)"" = ""$C""; "
         & "test ""$(git get-tar-commit-id < v.tar)"" = ""$C""; "
         --  a tar with no pax header fails, like git
         & "tar cf plain.tar f; "
         & "if " & CLI & " get-tar-commit-id < plain.tar >/dev/null 2>&1; "
         & "then false; else true; fi");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Get_Tar_Commit_Id_Matches_Git;

   --  The raw-format diff plumbing (diff-tree/diff-index/diff-files) must
   --  match git across tree/commit, --cached, and unstaged/staged working
   --  changes, including nested paths.
   procedure Diff_Plumbing_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      function Both (Cmd : String) return String is
        ("test ""$(" & CLI & " " & Cmd & " 2>&1)"" = "
         & """$(git " & Cmd & " 2>&1)""; ");
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Write_File (Root, "f", "a" & LF);
      Write_File (Root, "g", "x" & LF);
      Ada.Directories.Create_Directory
        (Version.Test_Support.Join (Root, "sub"));
      Write_File (Root, "sub/n", "s" & LF);
      Version.Git_Fixtures.Run (Root, "git add -A");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");
      Write_File (Root, "f", "a" & LF & "b" & LF);
      Version.Git_Fixtures.Run (Root, "git commit -q -am c2");

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & "T1=$(git rev-parse HEAD~1^{tree}); T2=$(git rev-parse HEAD^{tree}); "
         & Both ("diff-tree -r $T1 $T2")
         & Both ("diff-tree $T1 $T2")
         & Both ("diff-tree -r HEAD")
         & Both ("diff-tree -r --root HEAD~1")
         & Both ("diff-index --cached HEAD")
         & Both ("diff-files")
         --  introduce unstaged and staged changes, then re-check each
         & "printf 'a\nb\nc\n' > f; rm -f g; printf 'z\n' > h; "
         & Both ("diff-files")
         & Both ("diff-index HEAD")
         & "git add -A; "
         & Both ("diff-index --cached HEAD")
         & Both ("diff-index HEAD"));

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Plumbing_Matches_Git;

   --  `replace` manages refs/replace/* and, crucially, object reads honor the
   --  replacement (unless GIT_NO_REPLACE_OBJECTS) -- all matching git.
   procedure Replace_Matches_Git
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

      Version.Git_Fixtures.Run
        (Root,
         "set -e; export LC_ALL=C; "
         & "B1=$(printf 'AAA\n' | git hash-object -w --stdin); "
         & "B2=$(printf 'BBB\n' | git hash-object -w --stdin); "
         & CLI & " replace ""$B1"" ""$B2""; "
         --  the replace ref and its listings match git
         & "test ""$(" & CLI & " replace)"" = ""$(git replace)""; "
         & "test ""$(" & CLI & " replace --format=medium)"" "
         & "= ""$(git replace --format=medium)""; "
         & "test ""$(" & CLI & " replace --format=long)"" "
         & "= ""$(git replace --format=long)""; "
         --  reads follow the replacement, and GIT_NO_REPLACE_OBJECTS disables
         & "test ""$(" & CLI & " cat-file -p ""$B1"")"" = BBB; "
         & "test ""$(GIT_NO_REPLACE_OBJECTS=1 " & CLI
         & " cat-file -p ""$B1"")"" = AAA; "
         --  delete matches git's message, and a missing delete exits non-zero
         & "test ""$(" & CLI & " replace -d ""$B1"")"" "
         & "= ""Deleted replace ref '""$B1""'""; "
         & "if " & CLI & " replace -d ""$B1"" >/dev/null 2>&1; "
         & "then false; else true; fi");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Replace_Matches_Git;

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
      --  Bare `branch`/`tag` list; show-ref with/without --tags/--heads;
      --  ls-files -s; rev-list --max-count; cat-file -p <tree> (one level);
      --  describe; for-each-ref --sort=creatordate -- all byte-exact vs git.
      declare
         procedure Oracle (Cmd : String) is
         begin
            Version.Git_Fixtures.Run
              (Root,
               "test ""$(" & CLI & " " & Cmd & ")"" = ""$(git " & Cmd & ")""");
         end Oracle;
      begin
         Oracle ("branch");
         Oracle ("tag");
         Oracle ("tag -l");
         Oracle ("show-ref");
         Oracle ("show-ref --tags");
         Oracle ("show-ref --heads");
         Oracle ("ls-files -s");
         Oracle ("rev-list --max-count=1 HEAD");
         Oracle ("rev-list -n 1 HEAD");
         Oracle ("cat-file -p HEAD^{tree}");
         Oracle ("describe");
         Oracle ("describe --tags");
         Oracle ("for-each-ref --sort=creatordate");
         Oracle ("rev-parse --short HEAD");
         Oracle ("log --format=%H");
         Oracle ("log --pretty=format:%h");
         Oracle ("log --format=%an|%s");
         Oracle ("grep hello");
         Oracle ("grep -c hello");
         Oracle ("grep -l hello");
         Oracle ("merge-base HEAD HEAD");
         Oracle ("branch -v");
         Oracle ("branch -a");
         Oracle ("rev-list --all --count");
         Oracle ("tag --sort=-refname");
         Oracle ("tag -l --sort=creatordate");
         Oracle ("log --stat -1");
      end;
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

   --  git lfs porcelain: track a pattern, stage an LFS file (caching the media
   --  and pointer), confirm ls-files reports it cached, then round-trip through
   --  the pointer and lfs checkout to restore the media.
   procedure LFS_Porcelain_Round_Trip
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

      Version.Git_Fixtures.Run (Root, CLI & " lfs track '*.bin'");
      Version.Git_Fixtures.Run (Root, "grep -q 'filter=lfs' .gitattributes");
      Version.Git_Fixtures.Run (Root, "printf 'porcelain media\n' > big.bin");
      Version.Git_Fixtures.Run (Root, CLI & " stage .gitattributes big.bin");
      --  ls-files reports the staged pointer with the cached marker '*'.
      Version.Git_Fixtures.Run
        (Root, CLI & " lfs ls-files | grep -q '[*] big.bin'");
      --  Replace the working file with its pointer, then restore via checkout.
      Version.Git_Fixtures.Run
        (Root, CLI & " lfs pointer --file=big.bin 2>/dev/null > big.bin");
      Version.Git_Fixtures.Run (Root, "grep -q 'git-lfs' big.bin");
      Version.Git_Fixtures.Run (Root, CLI & " lfs checkout big.bin");
      Version.Git_Fixtures.Run
        (Root, "test ""$(cat big.bin)"" = 'porcelain media'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end LFS_Porcelain_Round_Trip;

   --  git lfs maintenance/history: migrate a plain blob into LFS (rewriting
   --  history), confirm ls-files/fsck see it, then prune (keeping the still-
   --  referenced object) and export it back out.
   procedure LFS_Migrate_And_Maintenance
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

      Version.Git_Fixtures.Run (Root, "printf 'plain media payload\n' > data.bin");
      Version.Git_Fixtures.Run (Root, "git add data.bin");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");
      --  Before migrate the blob is plain content, not a pointer.
      Version.Git_Fixtures.Run
        (Root, "git cat-file -p HEAD:data.bin | grep -qv 'git-lfs'");

      Version.Git_Fixtures.Run (Root, CLI & " lfs migrate import --include='*.bin'");
      --  After import the committed blob is an LFS pointer and .gitattributes
      --  carries the rule.
      Version.Git_Fixtures.Run
        (Root, "git cat-file -p HEAD:data.bin | grep -q 'git-lfs'");
      Version.Git_Fixtures.Run
        (Root, "git cat-file -p HEAD:.gitattributes | grep -q 'filter=lfs'");
      Version.Git_Fixtures.Run (Root, CLI & " lfs ls-files | grep -q data.bin");
      Version.Git_Fixtures.Run
        (Root, "test ""$(" & CLI & " lfs fsck)"" = 'Git LFS fsck OK'");
      --  The migrated object is referenced by HEAD, so prune retains it.
      Version.Git_Fixtures.Run
        (Root, CLI & " lfs prune | grep -q '1 retained'");

      Version.Git_Fixtures.Run (Root, CLI & " lfs migrate export --include='*.bin'");
      Version.Git_Fixtures.Run
        (Root, "git cat-file -p HEAD:data.bin | grep -qv 'git-lfs'");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end LFS_Migrate_And_Maintenance;

   --  archive tar filter: a configured tar.<fmt>.command pipes the tar output
   --  through the command (git's mechanism), and an unconfigured format errors.
   procedure Archive_Tar_Filter_Command
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
      Version.Git_Fixtures.Run (Root, "printf 'hello\n' > a.txt");
      Version.Git_Fixtures.Run (Root, "git add a.txt");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");

      --  Identity filter (cat) exercises the pipe mechanism deterministically.
      Version.Git_Fixtures.Run (Root, "git config tar.tar.cpy.command cat");
      Version.Git_Fixtures.Run
        (Root, CLI & " archive HEAD --format tar.cpy --output out.tar.cpy");
      --  cat passes the tar through unchanged, so it lists the archived file.
      Version.Git_Fixtures.Run (Root, "tar -tf out.tar.cpy | grep -q a.txt");

      --  A format with no configured filter is rejected (git parity).
      Version.Git_Fixtures.Run
        (Root,
         "! " & CLI & " archive HEAD --format tar.nofilter"
         & " --output x 2>/dev/null");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Archive_Tar_Filter_Command;

   function Read_Raw_Bytes (Path : String) return String is
      use Ada.Streams.Stream_IO;
      File   : File_Type;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Read (File, Buffer, Last);
         for I in Buffer'First .. Last loop
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Integer (Buffer (I))));
         end loop;
      end loop;
      Close (File);
      return Ada.Strings.Unbounded.To_String (Result);
   end Read_Raw_Bytes;

   procedure Output_Is_Byte_Exact_Against_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      LF : constant Character := Character'Val (10);
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      --  A blob without a trailing newline, so cat-file byte-exactness is
      --  observable; an untracked file drives a single porcelain line.
      Version.Git_Fixtures.Run (Root, "printf 'no-newline' > nn.txt");
      Version.Git_Fixtures.Run (Root, "git add nn.txt");
      Version.Git_Fixtures.Run (Root, "git commit -q -m c1");
      Version.Git_Fixtures.Run (Root, "printf 'x\n' > u.txt");

      --  Capture outside the working tree so the redirect target does not
      --  itself appear as an untracked entry in the status output.
      Version.Git_Fixtures.Run
        (Root, CLI & " status --porcelain > " & Root & ".st.out");
      Assert
        (Read_Raw_Bytes (Root & ".st.out") = "?? u.txt" & LF,
         "status --porcelain must not append a spurious trailing newline");

      Version.Git_Fixtures.Run
        (Root, CLI & " cat-file -p HEAD:nn.txt > " & Root & ".cf.out");
      Assert
        (Read_Raw_Bytes (Root & ".cf.out") = "no-newline",
         "cat-file must emit blob bytes without a forced trailing newline");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Output_Is_Byte_Exact_Against_Git;

   procedure Rerere_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";
      Q : constant Character := '"';

      --  Create a conflicting merge with TOOL, then run rerere status/remaining
      --  (both list the conflicted path) and clear, capturing to Out_Path.
      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "mkdir -p " & Q & Dir & Q & LF & "cd " & Q & Dir & Q & LF
           & "export " & GEnv & LF
           & "git init -q" & LF
           & "git config rerere.enabled true" & LF
           & "au() { git -c user.name=T -c user.email=t@t "
           & "commit -q -m " & Q & "$1" & Q & "; }" & LF
           & "printf 'a\nb\nc\n' > f; git add f; au base" & LF
           & "git checkout -q -b feat" & LF
           & "printf 'a\nFEAT\nc\n' > f; git add f; au feat" & LF
           & "git checkout -q main" & LF
           & "printf 'a\nMAIN\nc\n' > f; git add f; au main" & LF
           & Tool & " merge feat > /dev/null 2>&1 || true" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "set +e" & LF
           & "echo status: >> " & Q & "$TF" & Q & LF
           & Tool & " rerere status >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo remaining: >> " & Q & "$TF" & Q & LF
           & Tool & " rerere remaining >> " & Q & "$TF" & Q & " 2>&1" & LF
           & Tool & " rerere clear >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "test -f .git/MERGE_RR && echo MERGE_RR-present >> " & Q & "$TF"
           & Q & " || echo MERGE_RR-gone >> " & Q & "$TF" & Q & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "g"), "git",
                Version.Test_Support.Join (Base, "g.sh"),
                Version.Test_Support.Join (Base, "g.T"));
      Run_Flow (Version.Test_Support.Join (Base, "v"), CLI,
                Version.Test_Support.Join (Base, "v.sh"),
                Version.Test_Support.Join (Base, "v.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "g.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "v.T"));
      begin
         Assert (G = V,
                 "rerere status/remaining/clear must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Rerere_Matches_Git;

   --  A real conflicted merge, end to end, against git: the conflicted file's
   --  bytes (all three conflict styles), the unmerged index stages, the
   --  rr-cache conflict id and its preimage, plus -Xours (which resolves the
   --  conflicting hunk only -- the other side's clean hunk must survive).
   --  Commit dates are pinned so both repositories produce identical commit
   --  ids, which makes the diff3 base label (an abbreviated oid) comparable.
   procedure Merge_Conflict_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true "
        & "GIT_AUTHOR_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q & " "
        & "GIT_COMMITTER_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q;

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "au() { git -c user.name=T -c user.email=t@t "
           & "commit -q -m " & Q & "$1" & Q & "; }" & LF
           --  One repo per conflict style, plus -Xours and a CRLF file (whose
           --  conflict markers must themselves end CR/LF, as git's do).
           & "for style in merge diff3 zdiff3 ours crlf; do" & LF
           & "  d=" & Q & Dir & Q & "/$style" & LF
           & "  rm -rf " & Q & "$d" & Q & "; mkdir -p " & Q & "$d" & Q & LF
           & "  cd " & Q & "$d" & Q & LF
           & "  git init -q" & LF
           & "  git config rerere.enabled true" & LF
           & "  if [ $style = crlf ]; then N='\r\n'; else N='\n'; fi" & LF
           & "  printf " & Q & "a${N}b${N}c${N}d${N}e${N}" & Q
           & " > f; git add f; au base" & LF
           & "  git checkout -q -b feat" & LF
           & "  printf " & Q & "a${N}B2${N}c${N}d${N}E2${N}TAIL${N}" & Q
           & " > f; git add f; au feat" & LF
           & "  git checkout -q main" & LF
           & "  printf " & Q & "a${N}B3${N}c${N}d${N}E2${N}" & Q
           & " > f; git add f; au main" & LF
           & "  set +e" & LF
           & "  if [ $style = ours ]; then" & LF
           & "    " & Tool & " merge -Xours feat > /dev/null 2>&1" & LF
           & "  else" & LF
           & "    if [ $style != crlf ]; then" & LF
           & "      git config merge.conflictStyle $style" & LF
           & "    fi" & LF
           & "    " & Tool & " merge feat > /dev/null 2>&1" & LF
           & "  fi" & LF
           & "  set -e" & LF
           & "  echo " & Q & "== $style file:" & Q & " >> " & Q & "$TF" & Q & LF
           & "  cat f >> " & Q & "$TF" & Q & LF
           & "  echo " & Q & "== $style stages:" & Q & " >> " & Q & "$TF"
           & Q & LF
           & "  git ls-files -u >> " & Q & "$TF" & Q & LF
           & "  echo " & Q & "== $style rerere diff:" & Q & " >> " & Q & "$TF"
           & Q & LF
           & "  " & Tool & " rerere diff >> " & Q & "$TF" & Q & " 2>&1"
           & " || true" & LF
           & "  echo " & Q & "== $style rr-cache:" & Q & " >> " & Q & "$TF"
           & Q & LF
           --  A clean merge (-Xours) records nothing, so these may find no
           --  files; that absence is itself part of what must match git.
           & "  ls .git/rr-cache 2>/dev/null >> " & Q & "$TF" & Q
           & " || true" & LF
           & "  cat .git/rr-cache/*/preimage 2>/dev/null >> " & Q & "$TF"
           & Q & " || true" & LF
           & "  cd " & Q & Base & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "mg"), "git",
                Version.Test_Support.Join (Base, "mg.sh"),
                Version.Test_Support.Join (Base, "mg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "mv"), CLI,
                Version.Test_Support.Join (Base, "mv.sh"),
                Version.Test_Support.Join (Base, "mv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "mg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "mv.T"));
      begin
         Assert (G = V,
                 "conflicted merge must match git byte for byte." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Conflict_Matches_Git;

   --  A rename on one side makes git disambiguate the conflict markers with
   --  each side's own path (`HEAD:old.txt` / `feature:new.txt`); renames to the
   --  same path keep the plain labels.  Also covers -Xignore-space-change,
   --  where a side whose only change is whitespace loses to the other side.
   procedure Merge_Rename_And_Whitespace_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "au() { git -c user.name=T -c user.email=t@t "
           & "commit -q -m " & Q & "$1" & Q & "; }" & LF
           --  ours-renames / theirs-renames / both-rename-same / whitespace
           & "for case in oursren theirsren sameren ws; do" & LF
           & "  d=" & Q & Dir & Q & "/$case" & LF
           & "  rm -rf " & Q & "$d" & Q & "; mkdir -p " & Q & "$d" & Q & LF
           & "  cd " & Q & "$d" & Q & LF
           & "  git init -q" & LF
           & "  printf 'alpha\nbeta\ngamma\ndelta\n' > old.txt" & LF
           & "  git add old.txt; au base" & LF
           & "  git checkout -q -b feature" & LF
           & "  if [ $case = theirsren ] || [ $case = sameren ]; then" & LF
           & "    git mv old.txt new.txt" & LF
           & "    printf 'alpha\nbeta\ngamma-feature\ndelta\n' > new.txt" & LF
           & "    git add new.txt" & LF
           & "  elif [ $case = ws ]; then" & LF
           & "    printf 'alpha\nbeta\ngamma\nDELTA2\n' > old.txt" & LF
           & "    git add old.txt" & LF
           & "  else" & LF
           & "    printf 'alpha\nbeta\ngamma-feature\ndelta\n' > old.txt" & LF
           & "    git add old.txt" & LF
           & "  fi" & LF
           & "  au feature" & LF
           & "  git checkout -q main" & LF
           & "  if [ $case = oursren ] || [ $case = sameren ]; then" & LF
           & "    git mv old.txt new.txt" & LF
           & "    printf 'alpha\nbeta-main\ngamma\ndelta\n' > new.txt" & LF
           & "    git add new.txt" & LF
           & "  elif [ $case = ws ]; then" & LF
           --  a whitespace-only change: must count as no change at all
           & "    printf 'alpha\nbeta   \t\ngamma\ndelta\n' > old.txt" & LF
           & "    git add old.txt" & LF
           & "  else" & LF
           & "    printf 'alpha\nbeta-main\ngamma\ndelta\n' > old.txt" & LF
           & "    git add old.txt" & LF
           & "  fi" & LF
           & "  au main" & LF
           & "  set +e" & LF
           & "  if [ $case = ws ]; then" & LF
           & "    " & Tool & " merge -Xignore-space-change feature"
           & " > /dev/null 2>&1" & LF
           & "  else" & LF
           & "    " & Tool & " merge feature > /dev/null 2>&1" & LF
           & "  fi" & LF
           & "  set -e" & LF
           & "  echo " & Q & "== $case:" & Q & " >> " & Q & "$TF" & Q & LF
           & "  cat new.txt old.txt 2>/dev/null >> " & Q & "$TF" & Q
           & " || true" & LF
           & "  git ls-files -u >> " & Q & "$TF" & Q & LF
           & "  cd " & Q & Base & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "rg"), "git",
                Version.Test_Support.Join (Base, "rg.sh"),
                Version.Test_Support.Join (Base, "rg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "rv"), CLI,
                Version.Test_Support.Join (Base, "rv.sh"),
                Version.Test_Support.Join (Base, "rv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "rg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "rv.T"));
      begin
         Assert (G = V,
                 "rename labels and whitespace merges must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Rename_And_Whitespace_Matches_Git;

   --  The merge classes that had gone unprobed: the "Auto-merging" line on a
   --  cleanly content-merged path (and its ordering against a CONFLICT line),
   --  a custom merge driver that exits non-zero (its output is the result),
   --  and merge.renormalize (line-ending churn is not a change).
   procedure Merge_Untested_Classes_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           --  -a: these fixtures edit tracked files in place.
           & "au() { git -c user.name=T -c user.email=t@t "
           & "commit -q -a -m " & Q & "$1" & Q & "; }" & LF
           & "for kind in automerge driver renorm; do" & LF
           & "  d=" & Q & Dir & Q & "/$kind" & LF
           & "  rm -rf " & Q & "$d" & Q & "; mkdir -p " & Q & "$d" & Q & LF
           & "  cd " & Q & "$d" & Q & LF
           & "  git init -q" & LF
           & "  if [ $kind = driver ]; then" & LF
           --  resolves to *theirs* and reports conflicts: git keeps that
           --  output instead of writing its own markers
           & "    echo '* merge=custom' > .gitattributes" & LF
           & "    git config merge.custom.driver "
           & Q & "cp %B %A; exit 1" & Q & LF
           & "    printf 'base\n' > f; git add f .gitattributes; au base" & LF
           & "    git checkout -q -b feat" & LF
           & "    printf 'theirs\n' > f; au feat" & LF
           & "    git checkout -q main; printf 'ours\n' > f; au main" & LF
           & "  elif [ $kind = renorm ]; then" & LF
           & "    printf 'a\nb\nc\n' > f; git add f; au base" & LF
           & "    git checkout -q -b feat" & LF
           & "    printf 'a\r\nb2\r\nc\r\n' > f; au feat" & LF
           & "    git checkout -q main; printf 'a\nb\nc2\n' > f; au main" & LF
           & "    echo '* text=auto' > .gitattributes" & LF
           & "    git add .gitattributes; au attrs" & LF
           & "    git config merge.renormalize true" & LF
           & "  else" & LF
           --  f merges cleanly, g conflicts: pins the interleaving of the
           --  "Auto-merging" lines with the CONFLICT line
           & "    printf 'a\nb\nc\nd\ne\n' > f" & LF
           & "    printf '1\n2\n3\n4\n5\n' > g" & LF
           & "    git add f g; au base" & LF
           & "    git checkout -q -b feat" & LF
           & "    printf 'a\nb\nc\nd\nE2\n' > f" & LF
           & "    printf '1\nT2\n3\n4\n5\n' > g; au feat" & LF
           & "    git checkout -q main" & LF
           & "    printf 'A2\nb\nc\nd\ne\n' > f" & LF
           & "    printf '1\nO2\n3\n4\n5\n' > g; au main" & LF
           & "  fi" & LF
           & "  set +e" & LF
           & "  echo " & Q & "== $kind:" & Q & " >> " & Q & "$TF" & Q & LF
           & "  " & Tool & " merge feat >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "  echo " & Q & "rc=$?" & Q & " >> " & Q & "$TF" & Q & LF
           & "  set -e" & LF
           & "  cat f >> " & Q & "$TF" & Q & LF
           & "  git ls-files -u >> " & Q & "$TF" & Q & LF
           & "  cd " & Q & Base & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "ug"), "git",
                Version.Test_Support.Join (Base, "ug.sh"),
                Version.Test_Support.Join (Base, "ug.T"));
      Run_Flow (Version.Test_Support.Join (Base, "uv"), CLI,
                Version.Test_Support.Join (Base, "uv.sh"),
                Version.Test_Support.Join (Base, "uv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "ug.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "uv.T"));
      begin
         Assert (G = V,
                 "auto-merging / merge driver / renormalize must match git."
                 & LF & "--- git ---" & LF & G
                 & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Untested_Classes_Match_Git;

   --  status/blame classes that had never been compared with git: a mode-only
   --  change (chmod +x), an entirely-untracked directory (git collapses it to
   --  `dir/`; -uall lists it out), and blame's line attribution.
   procedure Status_And_Blame_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true "
        & "GIT_AUTHOR_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q & " "
        & "GIT_COMMITTER_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q;

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q" & LF
           & "ci() { git -c user.name=$1 -c user.email=u@u "
           & "commit -q -a -m " & Q & "$2" & Q & "; }" & LF
           --  blame: line 3 is never touched after the first commit
           & "printf 'one\ntwo\nthree\n' > f" & LF
           & "mkdir -p partial; printf 'p\n' > partial/tracked" & LF
           & "git add f partial/tracked" & LF
           & "git -c user.name=A -c user.email=u@u commit -q -m c1" & LF
           & "printf 'one\nTWO\nthree\nfour\n' > f; ci B c2" & LF
           & "printf 'one\nTWO\nthree\nfour\nfive\n' > f; ci C c3" & LF
           --  status: mode-only change, wholly-untracked dir, partial dir
           & "chmod +x f" & LF
           & "mkdir -p ud/deep" & LF
           & "printf 'a\n' > ud/f1; printf 'b\n' > ud/deep/f2" & LF
           & "printf 'c\n' > loose; printf 'q\n' > partial/new" & LF
           --  a staged rename (+ a worktree edit of its destination => RM),
           --  and a low-similarity rewrite, which git does NOT call a rename
           & "printf 'r0\nr1\nr2\nr3\nr4\nr5\nr6\nr7\n' > ren.txt" & LF
           & "printf 'w0\nw1\nw2\nw3\nw4\nw5\nw6\nw7\n' > rw.txt" & LF
           & "git add ren.txt rw.txt; ci A c4" & LF
           & "git mv ren.txt ren_new.txt" & LF
           & "printf 'dirty\n' >> ren_new.txt" & LF
           & "git mv rw.txt rw_new.txt" & LF
           & "printf 'zzz\nzzz\nzzz\n' > rw_new.txt; git add rw_new.txt" & LF
           & "echo '== blame:' >> " & Q & "$TF" & Q & LF
           & Tool & " blame f >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== porcelain:' >> " & Q & "$TF" & Q & LF
           & Tool & " status --porcelain >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== porcelain -uall:' >> " & Q & "$TF" & Q & LF
           & Tool & " status --porcelain -uall >> " & Q & "$TF" & Q
           & " 2>&1" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "sg"), "git",
                Version.Test_Support.Join (Base, "sg.sh"),
                Version.Test_Support.Join (Base, "sg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "sv"), CLI,
                Version.Test_Support.Join (Base, "sv.sh"),
                Version.Test_Support.Join (Base, "sv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "sg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "sv.T"));
      begin
         Assert (G = V,
                 "status (mode change, untracked dirs) and blame must match"
                 & " git." & LF & "--- git ---" & LF & G
                 & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Status_And_Blame_Match_Git;

   --  The diff engine is git's own (indent heuristic included), so hunks land
   --  where git puts them; `log -p`, `show <rev>:<path>`, `-U<n>` and
   --  `rev-parse --show-toplevel` are exercised alongside it.
   procedure Diff_Engine_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true "
        & "GIT_AUTHOR_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q & " "
        & "GIT_COMMITTER_DATE=" & Q & "2026-01-01T00:00:00 +0000" & Q;

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q" & LF
           --  indented, brace-y, blank-line-rich source: what the indent
           --  heuristic exists for -- a plain LCS slides these hunks elsewhere
           & "printf 'def a():\n    x = 1\n\n    if x:\n        return 1\n"
           & "\n    return 0\n\ndef b():\n    y = 2\n\n    return y\n' > f"
           & LF
           & "mkdir -p d; printf 'inner\n' > d/g" & LF
           & "git add f d/g" & LF
           & "git -c user.name=A -c user.email=u@u commit -q -m c1" & LF
           & "printf 'def a():\n    x = 1\n\n    if x:\n        return 1\n"
           & "\n    return 0\n\ndef NEW():\n    z = 9\n\n    return z\n"
           & "\ndef b():\n    y = 2\n\n    return y\n' > f" & LF
           & "git -c user.name=B -c user.email=u@u commit -q -a -m c2" & LF
           & "echo '== diff HEAD~1 HEAD:' >> " & Q & "$TF" & Q & LF
           & Tool & " diff HEAD~1 HEAD >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== diff -U0:' >> " & Q & "$TF" & Q & LF
           & Tool & " diff -U0 HEAD~1 HEAD >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== log -p:' >> " & Q & "$TF" & Q & LF
           & Tool & " log -p >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== show rev:path:' >> " & Q & "$TF" & Q & LF
           & Tool & " show HEAD:d/g >> " & Q & "$TF" & Q & " 2>&1" & LF
           & Tool & " show HEAD:d >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== rev-parse:' >> " & Q & "$TF" & Q & LF
           & Tool & " rev-parse --is-inside-work-tree >> " & Q & "$TF" & Q
           & " 2>&1" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "dg"), "git",
                Version.Test_Support.Join (Base, "dg.sh"),
                Version.Test_Support.Join (Base, "dg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "dv"), CLI,
                Version.Test_Support.Join (Base, "dv.sh"),
                Version.Test_Support.Join (Base, "dv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "dg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "dv.T"));
      begin
         Assert (G = V,
                 "diff hunks / log -p / show rev:path must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Diff_Engine_Matches_Git;

   --  bisect run (verdict from exit status: 0 good / 125 skip / 1..127 bad)
   --  and patch-id, both byte-compared with git.  bisect run also proves an
   --  untracked file (its own test script!) no longer blocks the checkouts.
   --  A transcript driver shared by the commit and checkout parity tests:
   --  the same scenario script runs once under git and once under this
   --  tool, each in a fresh isolated repository, recording every command's
   --  combined output and exit code plus the repository state after it
   --  (HEAD, log, status, reflog). The two transcripts must be identical.
   procedure Run_Parity_Transcript
     (Root, Scenario, Context : String)
   is
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        Version.Test_Support.Join (Old_Dir, "bin/main");
      Q       : constant Character := '"';

      --  git localizes its messages, so pin the locale; pin dates and the
      --  default branch so both repositories get identical ids; isolate
      --  HOME so no user config leaks in.
      Env : constant String :=
        "LC_ALL=C LANG=C LANGUAGE=C GIT_CONFIG_NOSYSTEM=1 "
        & "GIT_AUTHOR_DATE='2024-01-02T03:04:05+0100' "
        & "GIT_COMMITTER_DATE='2024-01-02T03:04:05+0100'";

      Driver : constant String :=
        "set -u" & LF
        & "export " & Env & LF
        & "export HOME=" & Q & "$BASE/home_$NAME" & Q
        & "; mkdir -p " & Q & "$HOME" & Q & LF
        --  The fixture runner points GIT_CONFIG_GLOBAL at /dev/null; both
        --  tools must see the same global file, so re-point it into HOME.
        & "export GIT_CONFIG_GLOBAL=" & Q & "$HOME/.gitconfig" & Q & LF
        & "git config --global init.defaultBranch main" & LF
        & "git config --global advice.detachedHead false" & LF
        & "TF=" & Q & "$BASE/$NAME.T" & Q & "; : > " & Q & "$TF" & Q & LF
        & "R=" & Q & "$BASE/$NAME" & Q & "; rm -rf " & Q & "$R" & Q
        & "; mkdir -p " & Q & "$R" & Q & "; cd " & Q & "$R" & Q & LF
        --  t LABEL ARGS...: run the tool, record output, exit code, state.
        & "t() { l=$1; shift; echo " & Q & "\$ $l" & Q
        & " >> " & Q & "$TF" & Q & "; " & Q & "$TOOL" & Q & " " & Q & "$@" & Q
        & " >> " & Q & "$TF" & Q & " 2>&1 < /dev/null; echo " & Q
        & "[rc=$?]" & Q & " >> " & Q & "$TF" & Q & "; state; }" & LF
        --  te LABEL ARGS...: the same, with $ED as the message editor.
        & "te() { l=$1; shift; echo " & Q & "\$ $l" & Q
        & " >> " & Q & "$TF" & Q & "; GIT_EDITOR=" & Q & "$ED" & Q & " "
        & Q & "$TOOL" & Q & " " & Q & "$@" & Q
        & " >> " & Q & "$TF" & Q & " 2>&1 < /dev/null; echo " & Q
        & "[rc=$?]" & Q & " >> " & Q & "$TF" & Q & "; state; }" & LF
        & "state() { { cat .git/HEAD; git log --all --format='%h|%an|%ae|%ad|%cn|%P|%s|%b' 2>/dev/null;"
        & " git status --porcelain=v1 -b; git reflog -2 --format=%gs 2>/dev/null;"
        & " git branch -vv --no-color 2>/dev/null | sed 's/ *$//'; } >> " & Q & "$TF" & Q & " 2>&1; }" & LF
        & "seed() { git init -q; git config user.email a@b; git config user.name A;"
        & " printf 'one\ntwo\n' > f; echo k > keep; git add f keep;"
        & " GIT_AUTHOR_NAME=Orig GIT_AUTHOR_EMAIL=o@o"
        & " GIT_AUTHOR_DATE='2001-01-01T00:00:00+0000' git commit -qm first; }" & LF;

      procedure Run_Flow (Name, Tool : String) is
         Script_Path : constant String :=
           Version.Test_Support.Join (Root, Name & ".sh");
      begin
         Version.Test_Support.Write_Text_File
           (Script_Path,
            "BASE=" & Q & Root & Q & LF
            & "NAME=" & Name & LF
            & "TOOL=" & Q & Tool & Q & LF
            & Driver & Scenario
            & "sed -i " & Q & "s#$BASE/wt_$NAME#WT#g; s#$BASE/$NAME#REPO#g" & Q
            & " " & Q & "$TF" & Q & LF);
         Version.Git_Fixtures.Run (Root, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow ("g", "git");
      Run_Flow ("v", CLI);
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Root, "g.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Root, "v.T"));
      begin
         Assert (G = V,
                 Context & " transcript must match git byte-for-byte." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
   end Run_Parity_Transcript;

   --  `commit`: git's option surface and the state machines behind it --
   --  bundled flags, -m paragraphs, amend keeping the author, reuse, fixup
   --  and squash subjects, sign-off and trailers, dates, partial commits,
   --  nothing-to-commit, the editor template, merge and cherry-pick
   --  conclusion, and the unmerged refusal.
   procedure Commit_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Q    : constant Character := '"';
      Scenario : constant String :=
        "seed" & LF
        --  The editor: keep a copy of the template, then prepend "ed" to
        --  the first line so the message is non-empty and edited.
        & "ED='cp " & Q & "$1" & Q & " tmpl.txt; sed -i 1s/^/ed/'" & LF
        & "printf 'one\nthree\n' > f" & LF
        & "t 'nothing staged' commit -m x" & LF
        & "t 'bundled -am' commit -am second" & LF
        & "printf 'four\n' >> f" & LF
        & "t '-m twice + signoff' commit -asm one -m two" & LF
        & "t 'amend keeps author' commit --amend -m amended" & LF
        & "t 'amend --no-edit' commit --amend --no-edit" & LF
        & "t 'amend --reset-author' commit --amend --reset-author -m ra" & LF
        & "t 'amend --author' commit --amend -m x --author='Z <z@z>'" & LF
        & "echo more >> f" & LF
        & "t '-C reuses author' commit -a -C HEAD~1" & LF
        & "echo more >> f" & LF
        & "t '--fixup' commit -a --fixup=HEAD" & LF
        & "echo more >> f" & LF
        & "t '--squash -m' commit -a --squash=HEAD~1 -m sq" & LF
        & "echo more >> f" & LF
        & "t '--date --trailer' commit -am dated --date='2020-05-06T07:08:09+0000'"
        & " --trailer 'Reviewed-by: R <r@r>'" & LF
        & "t '--allow-empty' commit --allow-empty -m empty" & LF
        & "t 'empty message' commit --allow-empty -m ''" & LF
        & "t 'clean tree' commit -m nothing" & LF
        & "t '--dry-run' commit --dry-run" & LF
        & "echo p > f; echo p > keep; echo n > newf" & LF
        & "t 'untracked pathspec' commit -m x newf" & LF
        & "t 'partial --only' commit -m only f" & LF
        & "t 'partial --include' commit -i -m incl keep" & LF
        & "rm keep" & LF
        & "t '-a deletion' commit -am del" & LF
        & "t '-a with paths' commit -am x f" & LF
        & "t 'verbatim' commit --allow-empty -m 'x  ' --cleanup=verbatim" & LF
        --  The editor path, with the template bytes captured for comparison.
        & "echo e > f" & LF
        & "te 'editor -a -v' commit -a -v" & LF
        & "cat tmpl.txt >> " & Q & "$TF" & Q & LF
        & "te 'editor amend' commit --amend" & LF
        & "cat tmpl.txt >> " & Q & "$TF" & Q & LF
        & "echo u > u; git add u; echo w > w" & LF
        & "te 'editor signoff status' commit -s" & LF
        & "cat tmpl.txt >> " & Q & "$TF" & Q & LF
        & "ED=true te 'editor no change' commit --allow-empty" & LF
        --  Concluding a merge: two parents, MERGE_MSG, state cleared.
        & "git checkout -qb side; echo s > s; git add s; git commit -qm s;"
        & " git checkout -q main; echo m > m; git add m; git commit -qm m;"
        & " git merge -q --no-commit side > /dev/null 2>&1; echo r > r" & LF
        & "t 'merge --amend refused' commit --amend -m x" & LF
        & "t 'merge commit' commit -m merged" & LF
        --  A conflicted merge: refused until resolved, then concluded.
        & "git checkout -qb c1; printf 'one\nS\n' > f; git commit -qam s2;"
        & " git checkout -q main; printf 'one\nM\n' > f; git commit -qam m2;"
        & " git merge -q c1 > /dev/null 2>&1" & LF
        & "t 'unmerged refused' commit -m x" & LF
        & "printf 'one\nR\n' > f; git add f" & LF
        & "te 'resolved merge editor' commit" & LF
        & "cat tmpl.txt >> " & Q & "$TF" & Q & LF
        --  A conflicted cherry-pick keeps the picked author.
        & "git checkout -qb c2; printf 'one\nP\n' > f;"
        & " GIT_AUTHOR_NAME=P GIT_AUTHOR_EMAIL=p@p git commit -qam picked;"
        & " git checkout -q main; printf 'one\nQ\n' > f; git commit -qam q;"
        & " git cherry-pick c2 > /dev/null 2>&1; printf 'one\nZ\n' > f; git add f" & LF
        & "t 'cherry-pick conclude' commit -m mine" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "commit");
   end Commit_Option_Surface_Matches_Git;

   --  `checkout`/`switch`: branch creation and reset, orphans, detaching,
   --  the remote-name DWIM and tracking, carried and refused local edits
   --  (staged ones keeping their index state), path restores with git's
   --  "Updated N paths" line, and switch's stricter operand rules.
   procedure Checkout_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Q    : constant Character := '"';
      Scenario : constant String :=
        "seed" & LF
        & "git checkout -qb side; echo 2 > f; git commit -qam side;"
        & " git checkout -q main; git branch -q f;"
        & " git remote add origin .; git fetch -q origin;"
        & " git update-ref refs/remotes/origin/feat side" & LF
        & "t 'branch' checkout side" & LF
        & "t 'same branch' checkout side" & LF
        & "t '-q' checkout -q main" & LF
        & "t 'detach rev' checkout side~0" & LF
        & "t 'detach same commit' checkout side~0" & LF
        & "t '--detach branch' checkout --detach main" & LF
        & "t 'dash' checkout -" & LF
        & "t 'main' checkout main" & LF
        & "t '-b' checkout -b nb" & LF
        & "t '-b existing' checkout -b side" & LF
        & "t '-B current' checkout -B nb side" & LF
        & "t '-B other' checkout -B f main" & LF
        & "t 'DWIM remote' checkout feat" & LF
        & "git update-ref refs/remotes/origin/feat2 side" & LF
        & "t 'back to main' checkout -q main" & LF
        & "t '--no-guess' checkout --no-guess feat2" & LF
        & "t '-t remote' checkout -t origin/feat2" & LF
        & "t '-b from remote' checkout -b x2 origin/feat" & LF
        & "t 'unknown' checkout nosuch" & LF
        & "t 'switch commit' switch side~0" & LF
        & "t 'switch bad' switch nosuch" & LF
        & "t 'switch none' switch" & LF
        & "t 'switch -c' switch -c sw main" & LF
        & "t 'switch -C' switch -C f side" & LF
        & "t 'switch -d' switch -d main" & LF
        & "t 'switch dash' switch -" & LF
        & "t 'orphan' checkout --orphan orph" & LF
        & "t 'orphan back' checkout -q -f main" & LF
        --  Local edits: carried, listed, refused, discarded.
        & "echo mod >> keep; echo mod2 > f" & LF
        & "t 'conflict refused' checkout side" & LF
        & "t 'conflict -f' checkout -f side" & LF
        & "git checkout -q main; echo mod >> keep; echo n > newf; git add newf keep; git rm -q --cached f" & LF
        & "t 'staged carried' checkout side" & LF
        & "t 'staged carried back' checkout main" & LF
        & "git add -A; git commit -qm staged" & LF
        --  Path restores.
        & "echo z > keep; echo z > newf" & LF
        & "t 'path from index' checkout -- keep" & LF
        & "t 'path nodash' checkout newf" & LF
        & "t 'tree path' checkout side -- keep" & LF
        & "t 'tree path nodash' checkout side keep" & LF
        & "t 'path nomatch' checkout -- nosuch" & LF
        & "t '-b with path' checkout -b zz -- keep" & LF
        & "t 'ours outside' checkout --ours keep" & LF
        --  --ours/--theirs on a real conflict.
        & "git checkout -q -f main; git checkout -qb o1; printf 'one\nS\n' > f; git add f; git commit -qm o1;"
        & " git checkout -q main; printf 'one\nM\n' > f; git add f; git commit -qm o2;"
        & " git merge -q o1 > /dev/null 2>&1" & LF
        & "t '--ours' checkout --ours f; cat f >> " & Q & "$TF" & Q & LF
        & "t '--theirs' checkout --theirs -- f; cat f >> " & Q & "$TF" & Q & LF
        & "git merge --abort" & LF
        --  A branch checked out in another worktree.
        & "git worktree add -q ../wt_$NAME side > /dev/null 2>&1" & LF
        & "t 'worktree in use' checkout side" & LF
        & "t 'worktree ignore' checkout --ignore-other-worktrees side" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "checkout");
   end Checkout_Option_Surface_Matches_Git;

   --  `add`: git's option surface -- reporting under -n/-v, -A/-u and
   --  their conflicts, deletions with and without --ignore-removal, the
   --  ignored-path refusal, unmatched pathspecs, --chmod, -N (an
   --  intent-to-add entry that status reports as unstaged and a commit
   --  leaves out), --renormalize and --pathspec-from-file.
   procedure Add_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Q    : constant Character := '"';
      Scenario : constant String :=
        "seed" & LF
        & "echo y > g; echo ig > ig; echo ig > .gitignore; git add g .gitignore;"
        & " git commit -qm more; echo new > n; echo z >> f" & LF
        & "t 'bare' add" & LF
        & "t '-nv' add -nv f n" & LF
        & "t '-v' add -v f n" & LF
        & "git reset -q" & LF
        & "t '-A -u' add -A -u" & LF
        & "t '-u untracked' add -u n" & LF
        & "t 'nosuch' add nosuch f" & LF
        & "t '--ignore-missing' add -n --ignore-missing nosuch f" & LF
        & "t 'ignored' add ig f" & LF
        & "t 'ignored -f' add -f ig" & LF
        & "t '-Av' add -Av" & LF
        & "git reset -q; git checkout -q -- f; rm -f ig n" & LF
        & "t '--chmod=+x' add --chmod=+x -v g" & LF
        & "t '--chmod bad' add --chmod=x g" & LF
        & "echo new > n" & LF
        & "t '-N' add -N n" & LF
        & "t '-N status' status --short" & LF
        & "t '-N commit' commit -m x" & LF
        & "t '-N then add' add -v n" & LF
        & "git rm -q --cached n; rm -f n" & LF
        & "rm -f g" & LF
        & "t 'deleted --ignore-removal' add --ignore-removal -v ." & LF
        & "t 'deleted -uv' add -uv" & LF
        & "git checkout -q -- g" & LF
        & "printf 'a\r\n' > crlf; git add crlf; git commit -qm crlf;"
        & " printf '* text=auto\n' > .gitattributes; sleep 1" & LF
        & "t '--renormalize -n' add -n --renormalize crlf" & LF
        & "t '--renormalize' add --renormalize crlf" & LF
        & "printf 'f\n' > list" & LF
        & "t '--pathspec-from-file' add -v --pathspec-from-file=list" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "add");
   end Add_Option_Surface_Matches_Git;

   --  `rebase`: git's option surface -- -q/-v/--stat, --onto/--keep-base/
   --  --fork-point, the up-to-date short-cut and -f/--no-ff, --exec (with
   --  a failing command), --autosquash, --signoff and the date flags, -X
   --  strategy options resolving a conflict, --update-refs, the
   --  cherry-pick dedup warning and --reapply-cherry-picks with --empty,
   --  a flattened merge, the conflict stop with --abort/--skip/--continue,
   --  and an interactive edit stop.
   procedure Rebase_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
        "seed" & LF
        --  main: base, m; topic: base, t1, t2.
        & "git checkout -qb topic; echo t1 > t1; git add t1; git commit -qm t1;"
        & " echo t2 > t2; git add t2; git commit -qm t2;"
        & " git checkout -q main; echo m > m; git add m; git commit -qm m;"
        & " git checkout -q topic" & LF
        & "t 'up to date' rebase HEAD~1" & LF
        & "t 'forced' rebase -f HEAD~1" & LF
        & "t 'unknown upstream' rebase nosuch" & LF
        & "t 'plain -q' rebase -q main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--stat' rebase --stat main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '-v' rebase -v main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--onto' rebase --onto main HEAD~1" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--keep-base' rebase --keep-base main" & LF
        & "t '--fork-point' rebase --fork-point main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--exec' rebase --exec 'echo ran' main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--exec fail' rebase --exec false main" & LF
        & "t 'exec continue' rebase --continue" & LF
        & "t 'exec continue again' rebase --continue" & LF
        & "git reset -q --hard topic@{2}" & LF
        & "t '--signoff' rebase --signoff main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--committer-date-is-author-date' rebase --committer-date-is-author-date main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--no-verify -s ort' rebase --no-verify -s ort main" & LF
        & "git reset -q --hard topic@{1}" & LF
        --  --update-refs moves a branch that pointed into the range.
        & "git branch -q mid topic~1" & LF
        & "t '--update-refs' rebase --update-refs main" & LF
        & "git branch -qD mid; git reset -q --hard topic@{1}" & LF
        --  --autosquash folds a fixup! commit.
        & "echo fx > t1; git commit -qam 'fixup! t1'" & LF
        & "t '--autosquash' rebase --autosquash main" & LF
        & "git reset -q --hard topic@{2}" & LF
        --  A commit already upstream: warned about and skipped, or
        --  reapplied and then dropped/kept/stopped on.
        & "git checkout -q main; git cherry-pick -q topic~1; git checkout -q topic" & LF
        & "t 'dedup' rebase main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--reapply-cherry-picks' rebase --reapply-cherry-picks main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--empty=keep' rebase --reapply-cherry-picks --empty=keep main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t '--empty=stop' rebase --reapply-cherry-picks --empty=stop main" & LF
        & "t 'empty skip' rebase --skip" & LF
        & "git reset -q --hard topic@{1}" & LF
        --  A conflict: -X resolves it; otherwise abort, skip, continue.
        & "git checkout -q main; echo c > t1; git add t1; git commit -qm conflict;"
        & " git checkout -q topic" & LF
        & "t '-X theirs' rebase -X theirs main" & LF
        & "git reset -q --hard topic@{1}" & LF
        & "t 'conflict' rebase main" & LF
        & "t 'conflict abort' rebase --abort" & LF
        & "t 'conflict again' rebase main" & LF
        & "t 'continue unresolved' rebase --continue" & LF
        & "echo r > t1; git add t1" & LF
        & "t 'continue resolved' rebase --continue" & LF
        & "git reset -q --hard topic@{2}" & LF
        & "t 'conflict once more' rebase main" & LF
        & "t 'skip' rebase --skip" & LF
        & "git reset -q --hard topic@{2}" & LF
        --  A merge in the history is flattened.
        & "git merge -q -X theirs main -m merged 2>/dev/null; echo t3 > t3;"
        & " git add t3; git commit -qm t3" & LF
        & "t 'flatten merge' rebase -X theirs main" & LF
        & "git reset -q --hard topic@{2}" & LF
        --  An interactive edit stop and its continue.
        & "export GIT_SEQUENCE_EDITOR='sed -i 1s/pick/edit/'" & LF
        & "t 'edit stop' rebase -i -X theirs main" & LF
        & "t 'edit continue' rebase --continue" & LF
        & "t 'no rebase' rebase --continue" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "rebase");
   end Rebase_Option_Surface_Matches_Git;

   --  `diff`: git's option surface -- the whitespace family, -I and
   --  --ignore-blank-lines (with git's one-byte-line quirk), -W and
   --  --inter-hunk-context, -R, --check, --color with --ws-error-highlight,
   --  the algorithms, --relative, -O, --full-index, --merge-base, textconv,
   --  intent-to-add entries, --output and the --submodule formats.
   procedure Diff_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "seed" & LF
        & "printf 'int main()\n{\n  a;\n  b;\n  c;\n}\n' > f.c" & LF
        & "printf 'x\n' > g" & LF
        & "mkdir sub; printf 'one\ntwo\nthree\n' > sub/s.txt" & LF
        & "printf 'alpha\n\nbeta\n' > blank.txt" & LF
        & "printf 'ws\n' > ws.txt" & LF
        & "printf 'a\r\nb\r\nc\r\n' > crlf.txt" & LF
        & "printf 'p1\np2\np3\n' > pic.txt" & LF
        & "git add .; git commit -qm base" & LF
        & "printf 'int main()\n{\n  a;\n  B; \n  c;\n\td;\n}\n\nvoid f()\n{\n  q;\n}\n\n\n' > f.c" & LF
        & "printf 'x\ny' > g" & LF
        & "printf 'one\ntwo  \nthree\n' > sub/s.txt" & LF
        & "printf 'alpha\n\n\nbeta\n' > blank.txt" & LF
        & "printf 'ws \n \t\n\n\n' > ws.txt" & LF
        & "printf 'a\r\nB\r\nc\n' > crlf.txt" & LF
        & "printf 'p1\np2 \np3\n' > pic.txt" & LF
        & "t 'plain' diff" & LF
        & "t '-w' diff -w" & LF
        & "t '-b' diff -b" & LF
        & "t '--ignore-space-at-eol' diff --ignore-space-at-eol" & LF
        & "t '--ignore-cr-at-eol' diff --ignore-cr-at-eol" & LF
        & "t '--ignore-blank-lines' diff --ignore-blank-lines" & LF
        & "t '-U0 --ignore-blank-lines' diff -U0 --ignore-blank-lines" & LF
        & "t '-I' diff -I 'B;'" & LF
        & "t '-I two' diff -I 'B;' -I 'd;' -- f.c" & LF
        & "t '-I bad' diff -I '['" & LF
        & "t '-W' diff -W" & LF
        & "t '-U0' diff -U0" & LF
        & "t '--inter-hunk-context=5 -U1' diff --inter-hunk-context=5 -U1" & LF
        & "t '--inter-hunk-context bad' diff --inter-hunk-context=x" & LF
        & "t '-R' diff -R" & LF
        & "t '-R --stat' diff -R --stat" & LF
        & "t '-R --name-status' diff -R --name-status" & LF
        & "t '--check' diff --check" & LF
        & "t '--check -w' diff --check -w" & LF
        & "t '--check -b' diff --check -b -- ws.txt pic.txt" & LF
        & "t '--color' diff --color" & LF
        & "t '--color --ws-error-highlight=all' diff --color --ws-error-highlight=all" & LF
        & "t '--color --ws-error-highlight=old,new' diff --color --ws-error-highlight=old,new" & LF
        & "t '--ws-error-highlight bad' diff --ws-error-highlight=bogus" & LF
        & "t '--color --stat' diff --color --stat" & LF
        & "t '--color --check' diff --color --check" & LF
        & "t '--color=never' diff --color=never --stat" & LF
        & "t '--color=bogus' diff --color=bogus" & LF
        & "t '--patience' diff --patience" & LF
        & "t '--histogram' diff --histogram" & LF
        & "t '--minimal' diff --minimal" & LF
        & "t '--diff-algorithm=patience' diff --diff-algorithm=patience" & LF
        & "t '--diff-algorithm=bad' diff --diff-algorithm=bad" & LF
        & "t '--no-indent-heuristic' diff --no-indent-heuristic" & LF
        & "t '--relative=sub/' diff --relative=sub/" & LF
        & "t '--relative=sub/ --stat' diff --relative=sub/ --stat" & LF
        & "t '--relative=sub/ --name-only' diff --relative=sub/ --name-only" & LF
        & "printf 'sub/\n*.c\n' > order" & LF
        & "t '-O' diff -Oorder --name-only" & LF
        & "t '-O sep' diff -O order --stat" & LF
        & "t '-O nofile' diff -Onofile" & LF
        & "t '--full-index' diff --full-index -- g" & LF
        & "t '--submodule=bogus' diff --submodule=bogus" & LF
        & "t '--color-moved=bogus' diff --color-moved=bogus" & LF
        & "t '--color-moved' diff --color-moved -- g" & LF
        & "t '-w --stat' diff -w --stat" & LF
        & "t '-w --numstat' diff -w --numstat" & LF
        & "t '-w --name-only' diff -w --name-only" & LF
        & "git add .; git commit -qm second" & LF
        & "printf 'k1\nk2\nk3\nk4\n' > keep" & LF
        & "git checkout -qb side HEAD~1; printf 'k0\nk1\nk2\nk3\n' > keep; git commit -qam "
          & "side; git checkout -q main" & LF
        & "t '--merge-base one' diff --merge-base side" & LF
        & "t '--merge-base two' diff --merge-base side main --stat" & LF
        & "t '--cached --merge-base' diff --cached --merge-base side" & LF
        & "git add keep" & LF
        & "t '--cached HEAD~1' diff --cached HEAD~1 --stat" & LF
        & "t '--cached HEAD~1 path' diff --cached HEAD~1 -- keep" & LF
        & "echo n > n; git add -N n" & LF
        & "t 'ita' diff" & LF
        & "t 'ita cached' diff --cached" & LF
        & "t 'ita visible' diff --cached --ita-visible-in-index" & LF
        & "t '--output' diff --output=out.patch --stat" & LF
        & "cat out.patch >> ""$TF""" & LF
        & "cd sub" & LF
        & "t 'relative in dir' diff --relative" & LF
        & "t 'relative --check' diff --relative --check" & LF
        & "cd .." & LF
        & "git config diff.algorithm patience" & LF
        & "t 'config algorithm' diff -- f.c" & LF
        & "git config diff.tc.textconv 'tr a-z A-Z <'" & LF
        & "echo 'pic.txt diff=tc' > .gitattributes" & LF
        & "printf 'p1\np2 \np3\nP4\n' > pic.txt" & LF
        & "t 'textconv' diff -- pic.txt" & LF
        & "t '--no-textconv' diff --no-textconv -- pic.txt" & LF
        & "t 'textconv stat' diff --stat -- pic.txt" & LF
        & "SM=$BASE/smsub" & LF
        & "[ -d $SM ] || (git init -q $SM && cd $SM && git config user.email a@b && git config "
          & "user.name A && echo 1 > f && git add f && git commit -qm s1 && echo 2 > f && git "
          & "commit -qam s2 && echo 3 > f && git commit -qam 's3 subject')" & LF
        & "git -c protocol.file.allow=always submodule add -q $SM sm 2>/dev/null; git commit -qm 'add sm'" & LF
        & "t 'submodule new log' diff HEAD~1 --submodule=log -- sm" & LF
        & "t 'submodule new diff' diff HEAD~1 --submodule=diff -- sm" & LF
        & "(cd sm && git checkout -q HEAD~2)" & LF
        & "t 'submodule rewind' diff --submodule" & LF
        & "t 'submodule rewind color' diff --submodule --color" & LF
        & "t 'submodule diff' diff --submodule=diff" & LF
        & "git add sm; git commit -qm rewind" & LF
        & "t 'submodule forward' diff HEAD HEAD~1 --submodule=log" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "diff");
   end Diff_Option_Surface_Matches_Git;

   --  `log` (and `show`): git's option surface -- dates (approxidate),
   --  the walk selectors (--author-date-order, --min/max-parents,
   --  --ancestry-path, --full-history/--sparse, --simplify-by-decoration,
   --  ref globs and excludes, --stdin, --bisect, -g, --merge), the header
   --  layouts (mailmap, tabs, --abbrev-commit, --log-size, -z, decorations
   --  and their filters, --source, --left-right marks, --boundary,
   --  --parents/--children, notes refs, --show-linear-break, --line-prefix,
   --  --output), the pretty aliases and formats, --date modes, -m and
   --  --diff-merges, and the diff-family passthrough.
   procedure Log_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "export TZ=UTC" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""2024-01-0$1T03:04:05+0100"" "
          & "GIT_COMMITTER_DATE=""2024-01-0$1T03:04:05+0100""; }" & LF
        & "d 1; printf 'one\n' > f; git add f; git commit -qm c1" & LF
        & "d 2; printf 'two\n' > f; printf 'tab\tmsg\n\n\tbody\n' > m; git commit -qaF m" & LF
        & "d 3; git checkout -qb side HEAD~1; echo s > s; git add s; git commit -qm 'side one'" & LF
        & "d 4; echo s2 > s; git commit -qam 'side two'" & LF
        & "d 5; git checkout -q main; echo three > f; git commit -qam c3" & LF
        & "d 6; git merge -q --no-ff side -m merge 2>/dev/null" & LF
        & "d 7; git tag -a v1 -m v1 HEAD~1; git tag light HEAD~2" & LF
        & "git update-ref refs/remotes/origin/main HEAD~1" & LF
        & "git update-ref refs/bisect/bad HEAD; git update-ref refs/bisect/good-abc HEAD~2" & LF
        & "printf 'New Name <new@x> <a@b>\n' > .mailmap" & LF
        & "t 'plain' log" & LF
        & "t 'expand tabs default' log -1 HEAD~1" & LF
        & "t '--no-expand-tabs' log --no-expand-tabs -1 HEAD~1" & LF
        & "t '--expand-tabs=4' log --expand-tabs=4 -1 HEAD~1" & LF
        & "t '--no-mailmap' log --no-mailmap -1" & LF
        & "t '--use-mailmap' log --use-mailmap -1" & LF
        & "t '--log-size' log --log-size -2" & LF
        & "t '-z' log -z -2" & LF
        & "t '-z oneline' log -z --oneline -2" & LF
        & "t '--abbrev-commit' log --abbrev-commit -2" & LF
        & "t '--abbrev=10 --oneline' log --abbrev=10 --oneline -2" & LF
        & "t '--no-abbrev-commit --oneline' log --no-abbrev-commit --oneline -2" & LF
        & "t '--decorate' log --decorate --oneline --all" & LF
        & "t '--decorate medium' log --decorate -3" & LF
        & "t '--decorate-refs=tags' log --decorate --decorate-refs=refs/tags --oneline --all" & LF
        & "t '--decorate-refs-exclude' log --decorate --decorate-refs-exclude=refs/tags/v1 --oneline --all" & LF
        & "t '--source' log --source --oneline --all" & LF
        & "t '--source medium' log --source -2 --all" & LF
        & "t '--left-right medium' log --left-right main...side" & LF
        & "t '--date=short' log --date=short -1" & LF
        & "t '--date=format:%Y-%m-%d %H:%M' log --date='format:%Y-%m-%d %H:%M' -1" & LF
        & "t '--date=iso-local' log --date=iso-local -1" & LF
        & "t '--date=default-local' log --date=default-local -1" & LF
        & "t '--date=unix' log --date=unix -1" & LF
        & "t '--pretty=reference' log --pretty=reference -2" & LF
        & "t '--pretty=email' log --pretty=email -1 HEAD~1" & LF
        & "t '--pretty=%s' log --pretty=%s -2" & LF
        & "t '--pretty=%h %s' log '--pretty=%h %s' -2" & LF
        & "git config pretty.mine '%h|%s'" & LF
        & "t 'pretty alias' log --pretty=mine -2" & LF
        & "t '--pretty=bogus' log --pretty=bogus -1" & LF
        & "t '-m -p' log -m -p -1" & LF
        & "t '-m --stat' log -m --stat -1" & LF
        & "t '-m --oneline -p' log -m --oneline -p -1" & LF
        & "t '--diff-merges=first-parent -p' log --diff-merges=first-parent -p -1" & LF
        & "t '--no-diff-merges -p' log --no-diff-merges -p -1" & LF
        & "t '--first-parent -p' log --first-parent -p -2" & LF
        & "t '--author-date-order' log --author-date-order --oneline" & LF
        & "t '--date-order' log --date-order --oneline" & LF
        & "t '--topo-order' log --topo-order --oneline" & LF
        & "t '--min-parents=2' log --min-parents=2 --oneline" & LF
        & "t '--max-parents=1' log --max-parents=1 --oneline" & LF
        & "t '--no-min-parents' log --merges --no-min-parents --oneline" & LF
        & "t '--ancestry-path' log --ancestry-path --oneline HEAD~3..HEAD" & LF
        & "t '--ancestry-path=side' log --ancestry-path=side~1 --oneline HEAD~3..HEAD" & LF
        & "t '--full-history' log --full-history --oneline -- s" & LF
        & "t 'default simplification' log --oneline -- s" & LF
        & "t '--full-history f' log --full-history --oneline -- f" & LF
        & "t '--sparse' log --sparse --oneline -- s" & LF
        & "t '--simplify-by-decoration' log --simplify-by-decoration --oneline" & LF
        & "t '--remotes' log --remotes --oneline" & LF
        & "t '--branches=si*' log --branches='si*' --oneline" & LF
        & "t '--tags=v*' log --tags='v*' --oneline" & LF
        & "t '--glob' log --glob=refs/heads/s* --oneline" & LF
        & "t '--exclude' log --exclude=side --branches --oneline" & LF
        & "t '--exclude glob' log --exclude='refs/tags/*' --all --oneline" & LF
        & "t '--bisect' log --bisect --oneline" & LF
        & "t '-g' log -g --oneline" & LF
        & "t '-g medium' log -g -2" & LF
        & "t '--grep-reflog' log -g --grep-reflog=merge --oneline" & LF
        & "t '--stdin' log --stdin --oneline < /dev/null" & LF
        & "printf 'side\n^main~2\n' | git log --stdin --oneline >> ""$TF"" 2>&1; echo ""[rc=$?]"" >> ""$TF""" & LF
        & "t '--since=' log --since=2024-01-03 --oneline" & LF
        & "t '--since= dot' log --since=2024.01.03 --oneline" & LF
        & "t '--until=' log --until='2024-01-04 00:00' --oneline" & LF
        & "t '--max-age' log --max-age=1704240000 --oneline" & LF
        & "t '--since-as-filter' log --since-as-filter=2024-01-03 --oneline" & LF
        & "t '-F --grep' log -F --grep='side.one' --oneline" & LF
        & "t '-E --grep' log -E --grep='side (one|two)' --oneline" & LF
        & "t '--basic-regexp' log --basic-regexp --grep='side \(one\|two\)' --oneline" & LF
        & "t '--perl-regexp' log -P --grep='side (?:one)' --oneline" & LF
        & "t '--line-prefix' log --line-prefix='> ' --oneline -2" & LF
        & "t '--line-prefix medium' log --line-prefix='| ' -1 --stat" & LF
        & "t '--show-linear-break' log --show-linear-break --oneline" & LF
        & "t '--show-linear-break=X' log --show-linear-break=XXX -3" & LF
        & "t '--quiet -p' log --quiet -p -1 HEAD~1" & LF
        & "t '--output' log --output=out.txt --oneline -2" & LF
        & "cat out.txt >> ""$TF""" & LF
        & "t '--summary' log --summary -1 HEAD~2" & LF
        & "t '--word-diff' log --word-diff -p -1 HEAD~2" & LF
        & "t '--diff-filter' log --diff-filter=A --name-only --oneline" & LF
        & "t '--patch-with-stat' log --patch-with-stat -1 HEAD~1" & LF
        & "t '--patch-with-raw' log --patch-with-raw -1 HEAD~1" & LF
        & "t '--output-indicator' log --output-indicator-new=A --output-indicator-old=D -p -1 HEAD~1" & LF
        & "t '--full-diff' log --full-diff --stat --oneline -- s" & LF
        & "t '--encoding' log --encoding=utf-8 --oneline -1" & LF
        & "t '-c' log -c -1" & LF
        & "t '--simplify-merges' log --simplify-merges --oneline" & LF
        & "t '--notes=foo' log --notes=foo -1" & LF
        & "git notes add -m 'a note' HEAD; git notes --ref=extra add -m 'extra note' HEAD" & LF
        & "t 'notes default' log -1" & LF
        & "t '--notes=extra' log --notes=extra -1" & LF
        & "t '--no-standard-notes --notes=extra' log --no-standard-notes --notes=extra -1" & LF
        & "t '--show-notes' log --show-notes -1" & LF
        & "t '--no-notes --notes' log --no-notes --notes -1" & LF
        & "t 'pretty + notes' log --pretty=medium -1" & LF
        & "t '--merge' log --merge --oneline" & LF
        & "git checkout -q -b conf HEAD~3; echo x > f; git commit -qam conf; git merge main 2>/dev/null" & LF
        & "t '--merge conflict' log --merge --oneline" & LF
        & "t '--merge -p' log --merge -p" & LF
        & "cd ""$R""; /bin/rm -rf sub2; mkdir sub2; cd sub2" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""2024-01-0$1T03:04:05+0100"" "
          & "GIT_COMMITTER_DATE=""2024-01-0$1T03:04:05+0100""; }" & LF
        & "d 1; printf 'one\n' > f; git add f; git commit -qm c1" & LF
        & "d 2; printf 'two\n' > f; git commit -qam c2" & LF
        & "d 3; git checkout -qb side HEAD~1; echo s > s; git add s; git commit -qm 'side one'" & LF
        & "d 4; echo s2 > s; git commit -qam 'side two'" & LF
        & "d 5; git checkout -q main; echo three > f; git commit -qam c3" & LF
        & "d 6; git merge -q --no-ff side -m merge 2>/dev/null" & LF
        & "d 7; echo four > f; git commit -qam c4" & LF
        & "t 'parents medium' log --parents -2" & LF
        & "t 'parents abbrev' log --parents --abbrev-commit -2" & LF
        & "t 'children medium' log --children -3" & LF
        & "t 'boundary medium' log --boundary HEAD~2..HEAD" & LF
        & "t 'graph decorate' log --graph --decorate --oneline" & LF
        & "t 'graph medium abbrev' log --graph --abbrev-commit -3" & LF
        & "t 'graph -m -p' log --graph -m -p -2" & LF
        & "t 'graph source' log --graph --source --oneline --all" & LF
        & "t 'reverse break' log --reverse --show-linear-break --oneline" & LF
        & "t '-g date' log -g --date=short -2" & LF
        & "t '-g format' log -g --format=%gd -2" & LF
        & "t '-g -z' log -g -z --oneline -2" & LF
        & "t 'follow' log --follow --oneline -- f" & LF
        & "t 'follow abbrev' log --follow --no-abbrev-commit --oneline -- f" & LF
        & "t '-z format' log -z --format=%s -3" & LF
        & "t 'log-size oneline' log --log-size --oneline -1" & LF
        & "t 'log-size format' log --log-size --format=%s -1" & LF
        & "t 'log-size merge' log --log-size -1 HEAD~1" & LF
        & "t 'left-right oneline' log --left-right --oneline main...side" & LF
        & "t 'cherry-mark medium' log --cherry-mark main...side" & LF
        & "t 'cherry-pick medium' log --cherry-pick --right-only main...side" & LF
        & "t 'source oneline HEAD' log --source --oneline -2" & LF
        & "t 'source explicit' log --source --oneline main side" & LF
        & "t 'source range' log --source --oneline side..main" & LF
        & "t 'date rfc-local' log --date=rfc-local -1" & LF
        & "t 'date iso-strict-local' log --date=iso-strict-local -1" & LF
        & "t 'date raw-local' log --date=raw-local -1" & LF
        & "t 'date short-local' log --date=short-local -1" & LF
        & "t 'date format-local' log --date='format-local:%H %z' -1" & LF
        & "t 'date format %a %b %e %j %u %w %y %C %I %p' log --date='format:%a %b %e %j %u %w "
          & "%y %C %I %p %D %F %T %R %s %%' -1" & LF
        & "t 'date bogus' log --date=bogus -1" & LF
        & "t 'stdin paths' log --oneline --stdin -- f < /dev/null" & LF
        & "printf 'main\n--\ns\n' | git log --stdin --oneline >> ""$TF"" 2>&1; echo ""[rc=$?]"" >> ""$TF""" & LF
        & "printf 'main\n' | git log --stdin --oneline -- s >> ""$TF"" 2>&1; echo ""[rc=$?]"" >> ""$TF""" & LF
        & "t 'tags no pattern' log --tags --oneline" & LF
        & "git tag t1 HEAD~2; git tag t2 HEAD~4" & LF
        & "t 'tags=t1' log --tags=t1 --oneline" & LF
        & "t 'glob heads' log --glob=heads --oneline" & LF
        & "t 'glob refs/tags/t*' log --glob='refs/tags/t*' --oneline" & LF
        & "t 'exclude before all' log --exclude=refs/heads/side --all --oneline" & LF
        & "t 'exclude after all' log --all --exclude=refs/heads/side --oneline" & LF
        & "t 'remotes empty' log --remotes --oneline" & LF
        & "t 'branches pattern star' log --branches='*ide' --oneline" & LF
        & "t 'ancestry no range' log --ancestry-path --oneline" & LF
        & "t 'max-count skip topo' log --author-date-order --skip=1 -2 --oneline" & LF
        & "t 'expand-tabs oneline' log --expand-tabs --oneline -1" & LF
        & "t 'no-expand short' log --pretty=short -1 HEAD~5" & LF
        & "t 'expand full' log --pretty=full -1 HEAD~5" & LF
        & "t 'mailmap fuller' log --pretty=fuller -1" & LF
        & "printf 'B <b@b> <a@b>\n' > .mailmap" & LF
        & "t 'mailmap default' log -1" & LF
        & "t 'mailmap reference' log --pretty=reference -1" & LF
        & "t 'mailmap email' log --pretty=email -1" & LF
        & "git config log.mailmap false" & LF
        & "t 'log.mailmap false' log -1" & LF
        & "git config log.mailmap true" & LF
        & "t 'log.mailmap true' log -1" & LF
        & "t 'notes ref spelled' log --notes=refs/notes/commits -1" & LF
        & "git notes add -m 'note here' HEAD" & LF
        & "t 'notes ref spelled 2' log --notes=refs/notes/commits -1" & LF
        & "t 'notes/ prefix' log --notes=notes/commits -1" & LF
        & "t 'show-notes ref' log --show-notes=commits --no-standard-notes -1" & LF
        & "t 'notes oneline' log --notes --oneline -1" & LF
        & "t 'decorate full' log --decorate=full --oneline -3" & LF
        & "t 'decorate-refs exclude glob' log --decorate --decorate-refs-exclude='refs/tags/*' --oneline -3" & LF
        & "t 'clear-decorations' log --decorate --clear-decorations --oneline -3" & LF
        & "t 'decorate + source' log --decorate --source --oneline -2" & LF
        & "t 'min-age' log --min-age=1704240000 --oneline" & LF
        & "t 'until+since' log --since=2024-01-02 --until=2024-01-05 --oneline" & LF
        & "t 'since-as-filter' log --since-as-filter=2024-01-03 --oneline" & LF
        & "t 'since iso zone' log --since='2024-01-03T03:04:05+0100' --oneline" & LF
        & "t 'since unix' log --since=@1704240245 --oneline" & LF
        & "t 'before+after' log --after=2024-01-03 --before=2024-01-06 --oneline" & LF
        & "t 'oneline -p' log --oneline -p -1" & LF
        & "t 'oneline --stat -p' log --oneline --stat -p -1" & LF
        & "t 'oneline -m -p' log --oneline -m -p -1 HEAD~1" & LF
        & "t 'oneline -c' log --oneline -c -2" & LF
        & "t 'first-parent oneline -p' log --first-parent --oneline -p -2" & LF
        & "t 'diff-merges=1 stat' log --diff-merges=1 --stat -1 HEAD~1" & LF
        & "t 'diff-merges bad' log --diff-merges=bogus" & LF
        & "t 'remerge-diff' log --remerge-diff -1" & LF
        & "t 'name-status' log --name-status --oneline -3" & LF
        & "t 'output-indicator context' log --output-indicator-context=C -p -U1 -1" & LF
        & "t 'line-prefix graph' log --line-prefix='## ' --graph --oneline -3" & LF
        & "t 'raw abbrev' log --raw --abbrev=12 --oneline -1" & LF
        & "t 'full-index' log --full-index -p -1" & LF
        & "t 'relative' log -p --relative -1" & LF
        & "t 'no-walk' log --no-walk --oneline side main" & LF
        & "t 'do-walk' log --no-walk --do-walk --oneline side" & LF
        & "t 'grep-reflog no -g' log --grep-reflog=x --oneline -1" & LF
        & "cd ""$R""; /bin/rm -rf sub3; mkdir sub3; cd sub3" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""2024-01-0$1T03:04:05+0100"" "
          & "GIT_COMMITTER_DATE=""2024-01-0$1T03:04:05+0100""; }" & LF
        & "d 1; printf 'one\n' > f; git add f; git commit -qm c1" & LF
        & "d 2; printf 'two\n' > f; printf 'tab\tmsg\n\n\tbody\n' > m; git commit -qaF m" & LF
        & "d 3; git checkout -qb side HEAD~1; echo s > s; git add s; git commit -qm 'side one'" & LF
        & "d 5; git checkout -q main; echo three > f; git commit -qam c3" & LF
        & "d 6; git merge -q --no-ff side -m merge 2>/dev/null" & LF
        & "printf 'B <b@b> <a@b>\n' > .mailmap" & LF
        & "git notes add -m 'a note' HEAD; git notes --ref=x add -m 'x note' HEAD" & LF
        & "t 'show plain' show" & LF
        & "t 'show abbrev-commit' show --abbrev-commit --stat" & LF
        & "t 'show abbrev=12' show --abbrev=12 -s" & LF
        & "t 'show no-mailmap' show --no-mailmap -s" & LF
        & "t 'show expand-tabs' show HEAD~2 -s" & LF
        & "t 'show no-expand-tabs' show --no-expand-tabs -s HEAD~2" & LF
        & "t 'show expand-tabs=2' show --expand-tabs=2 -s HEAD~2" & LF
        & "t 'show notes=x' show --notes=x -s" & LF
        & "t 'show no-notes' show --no-notes -s" & LF
        & "t 'show no-standard-notes' show --no-standard-notes --notes=x -s" & LF
        & "t 'show log-size' show --log-size -s" & LF
        & "t 'show date=short' show --date=short -s" & LF
        & "t 'show date format' show --date='format:%Y/%m/%d' -s" & LF
        & "t 'show -m' show -m --stat" & LF
        & "t 'show first-parent' show --first-parent --stat" & LF
        & "t 'show oneline' show --oneline -s" & LF
        & "t 'show format' show --format=%s%n%gd -s" & LF
        & "t 'log plain' log" & LF
        & "t 'log --stat -m' log --stat -m -1" & LF
        & "git config log.mailmap false" & LF
        & "t 'show log.mailmap' show -s" & LF
        & "t 'log log.mailmap' log -1" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "log");
   end Log_Option_Surface_Matches_Git;

   --  `show`: git's option surface as log's no-walk form -- merges as
   --  dense combined diffs (-c/--cc, the ported combine-diff), -m and
   --  --first-parent, the summary formats against the first parent, tags,
   --  trees and blobs in turn, `rev:path`, ranges and -n turning the walk
   --  back on, ref seeding, the walk filters, marks and decorations, the
   --  pretty forms and dates, and the diff-family passthrough; plus
   --  `log -c/--cc` and `diff-tree -c/--cc`.
   procedure Show_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""2024-01-0$1T03:04:05+0100"" "
          & "GIT_COMMITTER_DATE=""2024-01-0$1T03:04:05+0100""; }" & LF
        & "d 1; printf 'int main()\n{\n  a;\n  b;\n  c;\n  d;\n  e;\n  f;\n  g;\n}\nX\nvoid "
          & "tail()\n{\n  t1;\n  t2;\n  t3;\n  t4;\n}\n' > f.c; printf 'k\n' > k; mkdir sub; "
          & "printf 'q\n' > sub/q; printf 'bin\0x\n' > b.bin; git add .; git commit -qm base" & LF
        & "d 2; git checkout -qb s1; sed -i 's/  b;/  B1;/; s/  t2;/  T2;/' f.c; echo s1 > k; "
          & "printf 'bin\0y\n' > b.bin; git rm -q sub/q; git commit -qam s1" & LF
        & "d 3; git checkout -q main; sed -i 's/  b;/  B2;/; s/  g;/  G;/' f.c; echo m > k; "
          & "printf 'n\n' > n; chmod +x sub/q; git add n; git commit -qam m" & LF
        & "d 4; git merge s1 >/dev/null 2>&1; sed -i 's/  B2;/  Bres;/' f.c; echo res > k; "
          & "printf 'bin\0z\n' > b.bin; git add -A; git commit -qm merged" & LF
        & "d 5; git tag -a v1 -m 'tag msg' HEAD~1; git tag light HEAD~2; git branch other HEAD~3" & LF
        & "d 6; echo more >> n; git commit -qam c5" & LF
        & "git update-ref refs/remotes/o/b HEAD~2" & LF
        & "printf 'B <b@b> <a@b>\n' > .mailmap; git add .mailmap; git commit -qm mailmap" & LF
        & "printf 'tab\tone\n\n\tbody\n' > m; git commit -q --allow-empty -F m" & LF
        & "git notes add -m 'a note' HEAD~1" & LF
        & "t 'plain' show" & LF
        & "t 'merge' show HEAD~3" & LF
        & "t 'merge -c' show -c HEAD~3" & LF
        & "t 'merge --cc' show --cc HEAD~3" & LF
        & "t 'merge -U1' show -U1 HEAD~3" & LF
        & "t 'merge -U0' show -U0 HEAD~3" & LF
        & "t 'merge --stat' show --stat HEAD~3" & LF
        & "t 'merge -c --stat' show -c --stat HEAD~3" & LF
        & "t 'merge --stat -p' show --stat -p HEAD~3" & LF
        & "t 'merge --raw' show --raw HEAD~3" & LF
        & "t 'merge --name-status' show --name-status HEAD~3" & LF
        & "t 'merge --name-only' show --name-only HEAD~3" & LF
        & "t 'merge --numstat' show --numstat HEAD~3" & LF
        & "t 'merge --summary' show --summary HEAD~3" & LF
        & "t 'merge -m' show -m HEAD~3" & LF
        & "t 'merge -m --stat' show -m --stat HEAD~3" & LF
        & "t 'merge --first-parent' show --first-parent HEAD~3" & LF
        & "t 'merge --dd' show --dd HEAD~3" & LF
        & "t 'merge --diff-merges=first-parent' show --diff-merges=first-parent HEAD~3" & LF
        & "t 'merge --diff-merges=off' show --diff-merges=off HEAD~3" & LF
        & "t 'merge --no-diff-merges' show --no-diff-merges HEAD~3" & LF
        & "t 'merge --oneline' show --oneline HEAD~3" & LF
        & "t 'merge --format=%s' show --format=%s HEAD~3" & LF
        & "t 'merge --pretty=format:%s' show --pretty=format:%s HEAD~3" & LF
        & "t 'merge -s' show -s HEAD~3" & LF
        & "t 'merge --quiet' show --quiet HEAD~3" & LF
        & "t 'merge --check' show --check HEAD~3" & LF
        & "t 'merge -w' show -w HEAD~3" & LF
        & "t 'merge --full-index' show --full-index HEAD~3" & LF
        & "t 'merge --abbrev=12' show --abbrev=12 --raw HEAD~3" & LF
        & "t 'merge -- k' show HEAD~3 -- k" & LF
        & "t 'merge k' show HEAD~3 k" & LF
        & "t 'merge --full-diff k' show --full-diff --stat HEAD~3 k" & LF
        & "t 'merge -Sres' show -Sres HEAD~3" & LF
        & "t 'merge --output' show --output=x.out HEAD~3" & LF
        & "t 'merge -I' show -I x HEAD~3" & LF
        & "t 'merge --line-prefix' show --line-prefix='| ' HEAD~3" & LF
        & "t 'merge --patch-with-stat' show --patch-with-stat HEAD~3" & LF
        & "t 'merge --patch-with-raw' show --patch-with-raw HEAD~3" & LF
        & "t 'merge --compact-summary' show --compact-summary HEAD~3" & LF
        & "t 'merge --no-abbrev' show --no-abbrev --raw HEAD~3" & LF
        & "t 'merge --textconv' show --textconv HEAD~3" & LF
        & "t 'merge --binary' show --binary HEAD~3" & LF
        & "t 'merge --word-diff' show --word-diff HEAD~3" & LF
        & "t 'merge -M' show -M HEAD~3" & LF
        & "t 'merge --no-renames' show --no-renames HEAD~3" & LF
        & "t 'merge --relative=sub' show --relative=sub/ HEAD~3" & LF
        & "t 'merge --src-prefix' show --src-prefix=x/ --dst-prefix=y/ HEAD~3" & LF
        & "t 'merge --no-prefix' show --no-prefix HEAD~3" & LF
        & "t 'merge --patience' show --patience HEAD~3" & LF
        & "t 'merge --histogram' show --histogram HEAD~3" & LF
        & "t 'merge -W' show -W HEAD~3" & LF
        & "t 'merge -b' show -b HEAD~3" & LF
        & "t 'tag' show v1" & LF
        & "t 'tag -s' show -s v1" & LF
        & "t 'tag --oneline' show --oneline v1" & LF
        & "t 'tag --pretty=short' show --pretty=short v1 -s" & LF
        & "t 'tag --pretty=fuller' show --pretty=fuller v1 -s" & LF
        & "t 'tag --format' show --format=%s v1 -s" & LF
        & "t 'light tag' show light -s" & LF
        & "t 'tree' show HEAD^{tree}" & LF
        & "t 'tree path' show HEAD~4:sub" & LF
        & "t 'blob' show HEAD:k" & LF
        & "t 'blob HEAD' show HEAD:k HEAD -s" & LF
        & "t 'HEAD blob' show HEAD -s HEAD:k" & LF
        & "t 'two commits' show -s HEAD HEAD~1" & LF
        & "t 'two commits oneline' show --oneline -s HEAD HEAD~1" & LF
        & "t 'two commits format:' show --pretty=format:%s -s HEAD HEAD~1" & LF
        & "t 'two commits tformat' show --pretty=tformat:%s -s HEAD HEAD~1" & LF
        & "t 'dup' show -s --oneline HEAD HEAD" & LF
        & "t 'tag commit tree' show -s v1 HEAD~4 HEAD^{tree}" & LF
        & "t 'nosuch' show nosuch" & LF
        & "t 'HEAD:nosuch' show HEAD:nosuch" & LF
        & "t 'path' show -s k" & LF
        & "t 'path oneline' show --oneline k" & LF
        & "t 'HEAD path' show --stat HEAD k" & LF
        & "t 'option after path' show HEAD k --stat" & LF
        & "t 'range' show HEAD~2..HEAD --oneline -s" & LF
        & "t 'sym range' show HEAD~3...other --oneline -s" & LF
        & "t '^!' show HEAD~3^! --oneline -s" & LF
        & "t '^@' show HEAD~3^@ --oneline -s" & LF
        & "t '-n' show -2 -s --oneline" & LF
        & "t '--max-count' show --max-count=2 -s --oneline" & LF
        & "t '--skip' show --skip=1 -s --oneline HEAD HEAD~1 HEAD~2" & LF
        & "t '--do-walk' show --do-walk -3 -s --oneline" & LF
        & "t '--do-walk -p' show --do-walk -3" & LF
        & "t '--graph' show --graph" & LF
        & "t '--graph --do-walk' show --graph --do-walk -3 --oneline" & LF
        & "t '--all' show --all -s --oneline" & LF
        & "t '--branches' show --branches -s --oneline" & LF
        & "t '--tags' show --tags -s" & LF
        & "t '--remotes' show --remotes -s --oneline" & LF
        & "t '--glob' show --glob=refs/heads/o* -s --oneline" & LF
        & "t '--exclude' show --exclude=refs/heads/other --branches -s --oneline" & LF
        & "t '--branches=pat' show --branches='s*' -s --oneline" & LF
        & "t '--tags=pat' show --tags='v*' -s --oneline" & LF
        & "t '--no-merges' show --no-merges -s --oneline HEAD~3 HEAD~4" & LF
        & "t '--merges' show --merges -s --oneline HEAD~3 HEAD~4" & LF
        & "t '--min-parents' show --min-parents=2 -s --oneline HEAD~3 HEAD~4" & LF
        & "t '--grep' show --grep=merged -s --oneline HEAD~3 HEAD~4" & LF
        & "t '--grep -i' show -i --grep=MERGED -s --oneline HEAD~3 HEAD~4" & LF
        & "t '--author' show --author=nobody -s --oneline" & LF
        & "t '--since' show --since=2024-01-05 -s --oneline HEAD~3 HEAD~1" & LF
        & "t '--until' show --until=2024-01-05 -s --oneline HEAD~3 HEAD~1" & LF
        & "t '-Sx' show -Sx -s --oneline HEAD~3 HEAD~4" & LF
        & "t '-Sres nonmerge' show -Sres -s --oneline HEAD~4" & LF
        & "t '--decorate' show --decorate -s" & LF
        & "t '--decorate=full' show --decorate=full -s HEAD~1" & LF
        & "t '--no-decorate' show --no-decorate -s" & LF
        & "t '--decorate-refs' show --decorate --decorate-refs=refs/tags -s HEAD~1" & LF
        & "t '--decorate-refs-exclude' show --decorate --decorate-refs-exclude=refs/tags -s HEAD~1" & LF
        & "t '--decorate oneline' show --decorate --oneline -s HEAD~1" & LF
        & "t '--parents' show --parents -s HEAD~3" & LF
        & "t '--children' show --children -s HEAD~3" & LF
        & "t '--left-right' show --left-right -s --oneline" & LF
        & "t '--cherry-mark' show --cherry-mark -s --oneline" & LF
        & "t '--source' show --source -s --oneline HEAD~1 other" & LF
        & "t '--source --all' show --source --all -s --oneline" & LF
        & "t '--show-signature' show --show-signature -s" & LF
        & "t '-z' show -z -s HEAD HEAD~1" & LF
        & "t '--abbrev-commit' show --abbrev-commit -s HEAD~3" & LF
        & "t '--no-abbrev-commit --oneline' show --no-abbrev-commit --oneline -s" & LF
        & "t '--log-size' show --log-size -s" & LF
        & "t '--expand-tabs' show -s" & LF
        & "t '--no-expand-tabs' show --no-expand-tabs -s" & LF
        & "t '--expand-tabs=4' show --expand-tabs=4 -s" & LF
        & "t '--use-mailmap' show --use-mailmap -s" & LF
        & "t '--no-mailmap' show --no-mailmap -s" & LF
        & "t '--notes' show --notes -s HEAD~1" & LF
        & "t '--no-notes' show --no-notes -s HEAD~1" & LF
        & "t '--notes=x' show --notes=x -s HEAD~1" & LF
        & "t '--date=short' show --date=short -s" & LF
        & "t '--date=iso' show --date=iso -s" & LF
        & "t '--date=format' show --date='format:%Y/%m/%d %H:%M' -s" & LF
        & "t '--date=bogus' show --date=bogus -s" & LF
        & "t '--pretty=reference' show --pretty=reference -s" & LF
        & "t '--pretty=email' show --pretty=email -s HEAD~1" & LF
        & "t '--pretty=raw' show --pretty=raw -s" & LF
        & "t '--pretty=full' show --pretty=full -s" & LF
        & "t '--pretty=%h %s' show '--pretty=%h %s' -s" & LF
        & "t '--encoding' show --encoding=utf-8 -s" & LF
        & "t '-p format' show --format=%s HEAD~4" & LF
        & "t '-p format:' show --pretty=format:%s HEAD~4" & LF
        & "t 'format --stat' show --format=%s --stat HEAD~4" & LF
        & "t 'format --stat -p' show --format=%s --stat -p HEAD~4" & LF
        & "t 'nonmerge default' show HEAD~4" & LF
        & "t 'nonmerge --stat' show --stat HEAD~4" & LF
        & "t 'nonmerge -c' show -c HEAD~4" & LF
        & "t 'root' show HEAD~6" & LF
        & "t 'root --stat' show --stat HEAD~6" & LF
        & "t 'log -c' log -c -4 --oneline" & LF
        & "t 'log --cc' log --cc -4" & LF
        & "t 'log -c --stat' log -c --stat -4" & LF
        & "t 'log -m -c' log -m -c -4 --oneline" & LF
        & "t 'log --cc --name-status' log --cc --name-status -4 --oneline" & LF
        & "t 'log --cc --raw' log --cc --raw -4 --oneline" & LF
        & "t 'log -Sres --cc' log -Sres --cc -4 --oneline" & LF
        & "t 'log --cc -U0' log --cc -U0 -4 --oneline" & LF
        & "t 'log --cc --check' log --cc --check -4" & LF
        & "t 'log --cc --line-prefix' log --cc --line-prefix='> ' -4 --oneline" & LF
        & "t 'diff-tree --cc' diff-tree --cc HEAD~3" & LF
        & "t 'diff-tree -c' diff-tree -c HEAD~3" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "show");
   end Show_Option_Surface_Matches_Git;

   --  `blame`: git's option surface over the blame.c port -- the operand
   --  DWIM, every layout switch, -L in all its forms, ranges and boundaries,
   --  --reverse, --first-parent, -M/-C, --ignore-rev with its marks,
   --  mailmap, the blame.*/color.blame.* config, dates, --contents, and
   --  the error texts.  Nothing here is attributed to the working tree, so
   --  no "Not Committed Yet" timestamp can drift between the two runs.
   procedure Blame_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""200$1-01-01T00:00:00+0000"""
        & " GIT_COMMITTER_DATE=""200$1-01-01T00:00:00+0000""; }" & LF
        & "d 1; printf 'int alpha(int x)\n{\n\treturn x + 1;\n}\n\nint beta(int y)\n{\n\tint z = y"
        & " * 2;\n\treturn z - 1;\n}\n\nstatic void"
        & " helper(void)\n{\n\tputs(""hello"");\n\tputs(""world"");\n}\n' > lib.c" & LF
        & "printf 'ONE\nTWO\nTHREE\nFOUR\nFIVE\nSIX\nSEVEN\nEIGHT\n' > nums; printf 'no newline at"
        & " end' > nonl; : > empty; git add .; git commit -qm initial" & LF
        & "d 2; printf 'static void helper(void)\n{\n\tputs(""hello"");\n\tputs(""world"");\n}\n\nint"
        & " alpha(int x)\n{\n\treturn x + 1;\n}\n\nint beta(int y)\n{\n\tint z = y * 3;\n\treturn"
        & " z - 1;\n}\n' > lib.c" & LF
        & "git commit -qam 'move helper up' --author='Bob <bob@x.org>'" & LF
        & "d 3; printf '#include <stdio.h>\n\nstatic void"
        & " helper(void)\n{\n\tputs(""hello"");\n\tputs(""world"");\n}\n\nvoid"
        & " extra(void)\n{\n\tputs(""extra"");\n}\n' > util.c" & LF
        & "printf 'int alpha(int x)\n{\n\treturn x + 1;\n}\n\nint beta(int y)\n{\n\tint z = y *"
        & " 3;\n\treturn z - 1;\n}\n' > lib.c" & LF
        & "printf 'FIVE\nSIX\nSEVEN\nEIGHT\nONE\nTWO\nTHREE\nFOUR\n' > nums; git add .; git commit"
        & " -qm 'split helper out, rotate nums' --author='Carol <carol@x.org>'" & LF
        & "d 4; sed -i 's/\t/    /' lib.c; git commit -qam 'reindent lib.c'" & LF
        & "d 5; git checkout -qb feat HEAD~2; printf"
        & " 'ONE\nTWO\nTHREE\nFOUR!\nFIVE\nSIX\nSEVEN\nEIGHT\nNINE\n' > nums; git commit -qam"
        & " 'feat: four bang and nine' --author='Dan <dan@x.org>'" & LF
        & "d 6; git checkout -q main; git merge feat -m 'merge feat' >/dev/null 2>&1; printf"
        & " 'FIVE\nSIX\nSEVEN\nEIGHT\nONE\nTWO\nTHREE\nFOUR!\nNINE\n' > nums; git add nums; git"
        & " commit -qm 'merge feat'" & LF
        & "d 7; git mv nums g; printf 'FIVE\nSIX\nSEVEN\nEIGHT\n  ONE\nTWO\nTHREE\nFOUR!\nNINE\n'"
        & " > g; git commit -qam 'rename nums to g, indent one'" & LF
        & "printf 'Bob Builder <bob@x.org>\n' > .mailmap; git add .mailmap; git commit -qm mailmap" & LF
        & "t 'plain' blame g" & LF
        & "t 'HEAD~1' blame HEAD~1 g" & LF
        & "t 'HEAD~2 nums' blame HEAD~2 nums" & LF
        & "t 'g HEAD~1' blame g HEAD~1" & LF
        & "t '-- g HEAD~1' blame -- g HEAD~1" & LF
        & "t 'missing at rev' blame HEAD~2 g" & LF
        & "t 'nofile' blame nofile" & LF
        & "t 'bad rev' blame g HEAD nofile" & LF
        & "t '-s' blame -s g" & LF
        & "t '-l' blame -l g" & LF
        & "t '-e' blame -e g" & LF
        & "t '-t' blame -t g" & LF
        & "t '-f' blame -f lib.c" & LF
        & "t '-n' blame -n g" & LF
        & "t '-c' blame -c g" & LF
        & "t '-b' blame -b g" & LF
        & "t '--root' blame --root g" & LF
        & "t '-w' blame -w g" & LF
        & "t '-fnsl' blame -fnsl g" & LF
        & "t '--abbrev=10' blame --abbrev=10 g" & LF
        & "t '--abbrev=3' blame --abbrev=3 g" & LF
        & "t '--no-abbrev' blame --no-abbrev g" & LF
        & "t '-L 2,4' blame -L 2,4 g" & LF
        & "t '-L2,+2' blame -L2,+2 g" & LF
        & "t '-L 4,-2' blame -L 4,-2 g" & LF
        & "t '-L ,3' blame -L ,3 g" & LF
        & "t '-L 6,' blame -L 6, g" & LF
        & "t '-L /TWO/,+2' blame -L '/TWO/,+2' g" & LF
        & "t '-L /TWO/,/FOUR/' blame -L '/TWO/,/FOUR/' g" & LF
        & "t '-L 2,3 -L 5,6' blame -L 2,3 -L 5,6 g" & LF
        & "t '-L 2,4 -L 3,5' blame -L 2,4 -L 3,5 g" & LF
        & "t '-L 99' blame -L 99 g" & LF
        & "t '-L 0' blame -L 0 g" & LF
        & "t '-L 2,+0' blame -L 2,+0 g" & LF
        & "t '-L /nomatch/' blame -L /nomatch/ g" & LF
        & "t '-L :beta' blame -L :beta lib.c" & LF
        & "t '-L :alpha' blame -L :alpha lib.c" & LF
        & "t '-L 5,6 -L :alpha' blame -L 5,6 -L :alpha lib.c" & LF
        & "t '-L /beta/,/^}/' blame -L '/beta/,/^}/' lib.c" & LF
        & "t '-L 8 -L ^/alpha/,+2' blame -L 8 -L '^/alpha/,+2' lib.c" & LF
        & "t '-L :zzz' blame -L :zzz lib.c" & LF
        & "t '-L bad regex' blame -L '/[/' lib.c" & LF
        & "t '--porcelain' blame --porcelain HEAD g" & LF
        & "t '--line-porcelain' blame --line-porcelain HEAD g" & LF
        & "t '--incremental' blame --incremental HEAD g" & LF
        & "t '--first-parent' blame --first-parent g" & LF
        & "t 'range' blame HEAD~3..HEAD g" & LF
        & "t '^rev' blame ^HEAD~3 g" & LF
        & "t 'sym range' blame HEAD~4...feat g" & LF
        & "t '--since' blame --since=2003-06-01 g" & LF
        & "t '--since -b' blame --since=2005-06-01 -b g" & LF
        & "t '--reverse' blame --reverse HEAD~6..HEAD~2 nums" & LF
        & "t '--reverse one' blame --reverse HEAD~6 -- g" & LF
        & "t '--reverse -M' blame --reverse -M HEAD~6..HEAD~2 nums" & LF
        & "t '--reverse --first-parent' blame --reverse --first-parent HEAD~6..HEAD~2 nums" & LF
        & "t '--reverse --first-parent norange' blame --reverse --first-parent HEAD~4 nums" & LF
        & "t '--reverse off chain' blame --reverse --first-parent feat~1..HEAD nums" & LF
        & "t '--reverse porcelain' blame --reverse --porcelain HEAD~6..HEAD~2 nums" & LF
        & "t 'two tips' blame HEAD feat nums" & LF
        & "t 'lib -M' blame -M HEAD~5 lib.c" & LF
        & "t 'lib -M1' blame -M1 HEAD~5 lib.c" & LF
        & "t 'util -C' blame -C util.c" & LF
        & "t 'util -C -C' blame -C -C util.c" & LF
        & "t 'util -C -C -C' blame -C -C -C util.c" & LF
        & "t 'util -C5' blame -C5 util.c" & LF
        & "t 'find-copies-harder' blame --find-copies-harder util.c" & LF
        & "t 'nums -M' blame -M HEAD~2 nums" & LF
        & "t 'nums -M -n -f' blame -M -n -f HEAD~2 nums" & LF
        & "t 'nums -C first-parent' blame -C --first-parent HEAD~2 nums" & LF
        & "t 'ignore reindent' blame --ignore-rev HEAD~4 lib.c" & LF
        & "t 'ignore porcelain' blame --ignore-rev HEAD~4 --porcelain lib.c" & LF
        & "t 'ignore -w' blame -w --ignore-rev HEAD~4 lib.c" & LF
        & "t 'ignore two' blame --ignore-rev HEAD~4 --ignore-rev HEAD~5 lib.c" & LF
        & "git config blame.markIgnoredLines true; git config blame.markUnblamableLines true" & LF
        & "t 'ignore marks' blame --ignore-rev HEAD~4 lib.c" & LF
        & "t 'ignore marks nums' blame --ignore-rev HEAD~5 HEAD~2 nums" & LF
        & "t 'ignore marks porcelain' blame --ignore-rev HEAD~4 --line-porcelain lib.c" & LF
        & "git config --unset blame.markIgnoredLines; git config --unset blame.markUnblamableLines" & LF
        & "t 'ignore bad' blame --ignore-rev nope g" & LF
        & "git rev-parse HEAD~4 > .ignore" & LF
        & "t 'ignore-revs-file' blame --ignore-revs-file .ignore lib.c" & LF
        & "git config blame.ignoreRevsFile .ignore" & LF
        & "t 'ignore-revs-file config' blame lib.c" & LF
        & "t 'ignore-revs-file reset' blame --ignore-revs-file '' lib.c" & LF
        & "git config --unset blame.ignoreRevsFile" & LF
        & "t 'ignore-revs-file missing' blame --ignore-revs-file nofile g" & LF
        & "t 'nonl' blame nonl" & LF
        & "t 'nonl -p' blame -p nonl" & LF
        & "t 'empty' blame empty" & LF
        & "t 'empty -L' blame -L 1 empty" & LF
        & "t 'mailmap -e' blame -e lib.c" & LF
        & "t 'mailmap -p' blame -p HEAD lib.c" & LF
        & "t '--show-stats' blame --show-stats -M lib.c" & LF
        & "t '--score-debug' blame --score-debug -M HEAD~2 nums" & LF
        & "t '--color-lines' blame --color-lines g" & LF
        & "t '--color-by-age' blame --color-by-age g" & LF
        & "git config blame.coloring highlightRecent; git config color.blame.highlightRecent"
        & " yellow,2004-01-01,green" & LF
        & "t 'coloring config' blame g" & LF
        & "git config --unset blame.coloring; git config --unset color.blame.highlightRecent" & LF
        & "git config color.blame.repeatedLines magenta" & LF
        & "t 'repeated color' blame --color-lines g" & LF
        & "git config --unset color.blame.repeatedLines" & LF
        & "git config blame.showRoot true; git config blame.blankBoundary true; git config"
        & " blame.showEmail true; git config blame.date short" & LF
        & "t 'config layout' blame g" & LF
        & "git config --unset blame.showRoot; git config --unset blame.blankBoundary; git config"
        & " --unset blame.showEmail; git config --unset blame.date" & LF
        & "t '--date=short' blame --date=short g" & LF
        & "t '--date=relative -L1,2' blame --date=relative -L 1,2 g" & LF
        & "t '--date=raw' blame --date=raw g" & LF
        & "t '--date=unix' blame --date=unix g" & LF
        & "t '--date=rfc' blame --date=rfc g" & LF
        & "t '--date=iso-strict' blame --date=iso-strict g" & LF
        & "t '--date=human' blame --date=human g" & LF
        & "t '--date=default' blame --date=default g" & LF
        & "t '--date=format:%Y' blame --date=format:%Y g" & LF
        & "t '--date=bad' blame --date=bad g" & LF
        & "t '--contents -s' blame -s --contents util.c g" & LF
        & "t '--contents missing' blame --contents nofile g" & LF
        & "t '--contents --reverse' blame --contents util.c --reverse HEAD~2..HEAD g" & LF
        & "t '--minimal' blame --minimal lib.c" & LF
        & "t '--diff-algorithm=patience' blame --diff-algorithm=patience lib.c" & LF
        & "t '--diff-algorithm=bad' blame --diff-algorithm=bad lib.c" & LF
        & "t '--no-indent-heuristic' blame --no-indent-heuristic lib.c" & LF
        & "t '--progress porcelain' blame --progress --porcelain g" & LF
        & "t '--no-follow' blame --no-follow g" & LF
        & "t 'annotate' annotate g" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "blame");
   end Blame_Option_Surface_Matches_Git;

   --  `describe`: git's option surface over the describe.c port -- exact
   --  and searched names, --tags/--all, --long/--abbrev, --candidates and
   --  --exact-match, --first-parent, --match/--exclude, misnamed tags,
   --  --always, --debug, blobs, --contains, --dirty/--broken, the error
   --  texts, and a merge-heavy DAG with a dozen tags for the search itself.
   procedure Describe_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "git init -q; git config user.email a@b; git config user.name A" & LF
        & "d() { export GIT_AUTHOR_DATE=""200$1-01-01T00:00:00+0000"""
        & " GIT_COMMITTER_DATE=""200$1-01-01T00:00:00+0000""; }" & LF
        & "d 1; echo a > f; git add f; git commit -qm c1" & LF
        & "t 'no tags' describe" & LF
        & "t 'no tags always' describe --always" & LF
        & "git tag -a v1.0 -m 'v1.0'" & LF
        & "d 2; echo b >> f; git commit -qam c2" & LF
        & "git tag light" & LF
        & "d 3; echo c >> f; git commit -qam c3" & LF
        & "git checkout -qb side HEAD~1" & LF
        & "d 4; echo s > s; git add s; git commit -qm side1" & LF
        & "git tag -a side-tag -m side" & LF
        & "d 5; echo s2 >> s; git commit -qam side2" & LF
        & "git checkout -q main" & LF
        & "d 6; git merge -q side -m merge" & LF
        & "d 7; echo d >> f; git commit -qam c4" & LF
        & "git tag -a v2.0 -m 'v2.0' HEAD~1" & LF
        & "git tag -a v2.0-again -m 'again' HEAD~1" & LF
        & "git tag -a old-tag -m old HEAD~3" & LF
        & "git update-ref refs/remotes/origin/main HEAD~2" & LF
        & "git tag -a misnamed -m mis HEAD~1; git update-ref refs/tags/renamed"
        & " refs/tags/misnamed; git tag -d misnamed >/dev/null" & LF
        & "t 'plain' describe" & LF
        & "t 'HEAD~1' describe HEAD~1" & LF
        & "t 'HEAD~2' describe HEAD~2" & LF
        & "t 'HEAD~3' describe HEAD~3" & LF
        & "t 'v1.0' describe v1.0" & LF
        & "t 'light' describe light" & LF
        & "t 'light --tags' describe --tags light" & LF
        & "t 'multiple' describe HEAD HEAD~1 HEAD~2" & LF
        & "t '--long' describe --long HEAD~1" & LF
        & "t '--long HEAD' describe --long" & LF
        & "t '--abbrev=10' describe --abbrev=10" & LF
        & "t '--abbrev=2' describe --abbrev=2" & LF
        & "t '--abbrev=0' describe --abbrev=0" & LF
        & "t '--no-abbrev' describe --no-abbrev" & LF
        & "t '--abbrev' describe --abbrev" & LF
        & "t '--long --abbrev=0' describe --long --abbrev=0" & LF
        & "t '--tags' describe --tags" & LF
        & "t '--tags HEAD~4' describe --tags HEAD~4" & LF
        & "t '--all' describe --all" & LF
        & "t '--all HEAD~2' describe --all HEAD~2" & LF
        & "t '--all side' describe --all side~1" & LF
        & "t '--all --long' describe --all --long HEAD~1" & LF
        & "t '--all --match' describe --all --match 'v*'" & LF
        & "t '--all --match main' describe --all --match 'main'" & LF
        & "t '--all --exclude' describe --all --exclude 'v*' --exclude 'renamed' --exclude"
        & " 'side*' --exclude old-tag" & LF
        & "t '--first-parent' describe --first-parent" & LF
        & "t '--first-parent side' describe --first-parent HEAD~2" & LF
        & "t '--match' describe --match 'v1*'" & LF
        & "t '--match two' describe --match 'v1*' --match 'old*'" & LF
        & "t '--match none' describe --match 'zzz*'" & LF
        & "t '--match none --always' describe --match 'zzz*' --always" & LF
        & "t '--exclude' describe --exclude 'v2*' --exclude renamed" & LF
        & "t '--exclude=' describe --exclude='v2*' HEAD~1" & LF
        & "t '--no-match' describe --match 'zzz' --no-match" & LF
        & "t '--candidates=1' describe --candidates=1 HEAD" & LF
        & "t '--candidates 1' describe --candidates 1 HEAD" & LF
        & "t '--candidates=0' describe --candidates=0 HEAD" & LF
        & "t '--candidates=0 exact' describe --candidates=0 HEAD~1" & LF
        & "t '--candidates=-3' describe --candidates=-3 HEAD" & LF
        & "t '--candidates=x' describe --candidates=x HEAD" & LF
        & "t '--exact-match' describe --exact-match" & LF
        & "t '--exact-match tag' describe --exact-match HEAD~1" & LF
        & "t '--no-exact-match' describe --exact-match --no-exact-match" & LF
        & "t '--debug' describe --debug" & LF
        & "t '--debug HEAD~1' describe --debug HEAD~1" & LF
        & "t '--debug --candidates=1' describe --debug --candidates=1" & LF
        & "t '--debug --tags' describe --debug --tags HEAD" & LF
        & "t '--debug --all' describe --debug --all HEAD" & LF
        & "t '--always' describe --always" & LF
        & "t 'misnamed' describe HEAD~1" & LF
        & "t 'misnamed --long' describe --long renamed" & LF
        & "t 'blob' describe HEAD:f" & LF
        & "t 'blob old' describe HEAD~3:f" & LF
        & "t 'blob --tags' describe --tags HEAD~2:f" & LF
        & "t 'blob --all' describe --all HEAD~2:f" & LF
        & "t 'tree' describe HEAD^{tree}" & LF
        & "t 'bad' describe nope" & LF
        & "t 'bad then good' describe nope HEAD" & LF
        & "t 'good then bad' describe HEAD nope" & LF
        & "t '--contains' describe --contains HEAD~3" & LF
        & "t '--contains HEAD' describe --contains" & LF
        & "t '--contains side' describe --contains side~1" & LF
        & "t '--contains --all' describe --contains --all HEAD~3" & LF
        & "t '--contains --all side' describe --contains --all side~1" & LF
        & "t '--contains --match' describe --contains --match 'v2*' HEAD~3" & LF
        & "t '--contains --exclude' describe --contains --exclude 'v2*' HEAD~3" & LF
        & "t '--contains --always' describe --contains --always HEAD" & LF
        & "t '--contains none' describe --contains HEAD" & LF
        & "t '--contains bad' describe --contains nope HEAD~3" & LF
        & "t '--contains multiple' describe --contains HEAD~3 HEAD~4" & LF
        & "t '--contains --tags' describe --contains --tags HEAD~5" & LF
        & "t '--dirty clean' describe --dirty" & LF
        & "t '--dirty=X clean' describe --dirty=X" & LF
        & "t '--broken clean' describe --broken" & LF
        & "echo dirty >> f" & LF
        & "t '--dirty' describe --dirty" & LF
        & "t '--dirty=X' describe --dirty=X" & LF
        & "t '--dirty --long' describe --dirty --long" & LF
        & "t '--broken' describe --broken" & LF
        & "t '--broken=Y' describe --broken=Y" & LF
        & "t '--broken --dirty=Z' describe --broken --dirty=Z" & LF
        & "t '--dirty rev' describe --dirty HEAD" & LF
        & "t '--broken rev' describe --broken HEAD" & LF
        & "t '--no-dirty' describe --dirty --no-dirty HEAD" & LF
        & "t '--dirty --always none' describe --dirty --match zzz --always" & LF
        & "git add f" & LF
        & "t '--dirty staged' describe --dirty" & LF
        & "git checkout -q -- f 2>/dev/null; git reset -q --hard" & LF
        & "git checkout -q --orphan empty 2>/dev/null; git rm -qrf . >/dev/null 2>&1" & LF
        & "t 'unborn' describe" & LF
        & "t 'unborn blob' describe main:f" & LF
        & "mkdir dag; cd dag" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "n=0" & LF
        & "c() { n=$((n+1)); export GIT_AUTHOR_DATE=""@$((1000000000 + n*1000)) +0000"""
        & " GIT_COMMITTER_DATE=""@$((1000000000 + n*1000)) +0000""; b=$(git branch"
        & " --show-current); echo ""$n"" >> ""f_$b""; git add ""f_$b""; git commit -qm ""c$n""; }" & LF
        & "m() { n=$((n+1)); export GIT_AUTHOR_DATE=""@$((1000000000 + n*1000)) +0000"""
        & " GIT_COMMITTER_DATE=""@$((1000000000 + n*1000)) +0000""; git merge -q --no-ff ""$1"" -m"
        & " ""m$n""; }" & LF
        & "tg() { GIT_COMMITTER_DATE=""@$((1000000000 + n*1000 + 5)) +0000"" git tag -a ""$1"" -m"
        & " ""$1""; }" & LF
        & "c; tg t1; c; c; tg t2" & LF
        & "git checkout -qb b1; c; tg t3; c; c; tg t4; c" & LF
        & "git checkout -q main; c; c; tg t5; c" & LF
        & "m b1" & LF
        & "git checkout -qb b2 HEAD~1; c; tg t6; c; c; c; tg t7" & LF
        & "git checkout -qb b3; c; git tag l1; c; tg t8" & LF
        & "git checkout -q b2; c; tg t9" & LF
        & "git checkout -q main; c; tg t10; c; tg t11" & LF
        & "m b2" & LF
        & "c; tg t12; m b3; c; git tag l2; c; tg t13; c; c" & LF
        & "t 'HEAD' describe" & LF
        & "t 'HEAD~2' describe HEAD~2" & LF
        & "t 'HEAD~6' describe HEAD~6" & LF
        & "t 'b3' describe b3" & LF
        & "t 'b2' describe b2" & LF
        & "t 'b1' describe b1" & LF
        & "t 'main~12' describe main~12" & LF
        & "t 'HEAD --tags' describe --tags" & LF
        & "t 'HEAD~3 --tags' describe --tags HEAD~3" & LF
        & "t 'HEAD --all' describe --all" & LF
        & "t 'b3~1 --all' describe --all b3~1" & LF
        & "t 'HEAD --first-parent' describe --first-parent" & LF
        & "t 'HEAD~6 --first-parent' describe --first-parent HEAD~6" & LF
        & "t 'HEAD~6 --first-parent --match' describe --first-parent --match 't*' HEAD~6" & LF
        & "t 'HEAD --candidates=1' describe --candidates=1" & LF
        & "t 'HEAD --candidates=2' describe --candidates=2" & LF
        & "t 'HEAD --candidates=3' describe --candidates=3" & LF
        & "t 'HEAD --candidates=5' describe --candidates=5" & LF
        & "t 'HEAD --candidates=30' describe --candidates=30" & LF
        & "t 'HEAD --debug' describe --debug" & LF
        & "t 'HEAD~6 --debug' describe --debug HEAD~6" & LF
        & "t 'HEAD --debug --candidates=3' describe --debug --candidates=3" & LF
        & "t 'HEAD --debug --candidates=30' describe --debug --candidates=30" & LF
        & "t 'HEAD --debug --match t1*' describe --debug --match 't1*'" & LF
        & "t 'HEAD --debug --first-parent' describe --debug --first-parent" & LF
        & "t 'HEAD --debug --tags' describe --debug --tags" & LF
        & "t 'HEAD --debug --all' describe --debug --all" & LF
        & "t 'HEAD --debug --exclude x*' describe --debug --exclude 'x*'" & LF
        & "t 'HEAD --debug --exclude x* --exclude t1*' describe --debug --exclude 'x*' --exclude"
        & " 't1*'" & LF
        & "t 'HEAD --debug --match [tl]1*' describe --debug --tags --match '[tl]1*'" & LF
        & "t 'HEAD --debug --match t[!1]*' describe --debug --match 't[!1]*'" & LF
        & "t 'b3 --debug' describe --debug b3" & LF
        & "t 'multi --debug' describe --debug HEAD b3 b2" & LF
        & "t 'HEAD --long --exclude' describe --long --exclude 'x*' --exclude 't13'" & LF
        & "t 'blob' describe HEAD~3:f_main" & LF
        & "t 'blob --debug' describe --debug HEAD~3:f_main" & LF
        & "t 'blob b3' describe b3:f_b3" & LF
        & "t 'blob b1' describe --tags HEAD:f_b1" & LF
        & "for k in 1 2 3 4 5 6 7 8; do git tag -a ""x$k"" -m ""x$k"" HEAD~$k; done" & LF
        & "t 'x HEAD' describe" & LF
        & "t 'x HEAD --debug --candidates=3' describe --debug --candidates=3" & LF
        & "t 'x HEAD~9 --debug' describe --debug HEAD~9" & LF
        & "t 'x HEAD --exclude x*' describe --debug --exclude 'x*'" & LF
        & "t 'x --all --debug' describe --all --debug HEAD~4" & LF
        & "t 'deep --candidates=1 --debug' describe --debug --candidates=1 --exclude 'x*' HEAD~6" & LF
        & "t 'deep --candidates=2 --debug' describe --debug --candidates=2 --exclude 'x*' HEAD~6" & LF
        & "t 'deep --candidates=3 --debug' describe --debug --candidates=3 --exclude 'x*' HEAD~6" & LF
        & "t 'deep --tags --debug' describe --debug --tags --exclude 'x*' --exclude 't*' HEAD~2" & LF
        & "t 'deep --tags --debug l' describe --debug --tags --exclude 'x*' --exclude 't1*'"
        & " HEAD~2" & LF
        & "t 'deep --first-parent --debug' describe --debug --first-parent --exclude 'x*'"
        & " --exclude 't1*' HEAD~2" & LF
        & "t 'deep b3 --debug' describe --debug --candidates=2 b3" & LF
        & "t 'deep --all --debug' describe --all --debug --exclude 'x*' --exclude 't*' HEAD~2" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "describe");
   end Describe_Option_Surface_Matches_Git;

   --  `shortlog`: git's option surface over the shortlog.c port -- the
   --  groupings (-c, --group=author|committer|trailer:|format:), -s/-n/-e,
   --  -w wrapping, --format records, the subject rules ([PATCH], folding,
   --  <none>), .mailmap, the walk options, and the log-on-stdin form.
   procedure Shortlog_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "git init -q; git config user.email a@b; git config user.name A" & LF
        & "n=0" & LF
        & "c() { n=$((n+1)); export GIT_AUTHOR_DATE=""@$((1000000000 + n*86400)) +0000"""
        & " GIT_COMMITTER_DATE=""@$((1000000000 + n*86400)) +0000""; echo ""$n"" >> ""f_$1""; git add"
        & " ""f_$1""; git -c user.name=""$2"" -c user.email=""$3"" commit -q -m ""$4"" ""${@:5}""; }" & LF
        & "c main A a@b 'first commit'" & LF
        & "c main 'Bob Builder' bob@x.org 'Bob adds a thing'" & LF
        & "c main A a@b '[PATCH 3/7] patch-style subject'" & LF
        & "c main 'Carol' carol@x.org $'multi line subject\nsecond line\n\nbody text'" & LF
        & "c main A a@b $'   leading spaces subject   '" & LF
        & "c main 'Bob Builder' bob@x.org $'Signed off work\n\nSigned-off-by: Carol"
        & " <carol@x.org>\nReviewed-by: Dan <dan@x.org>\nSigned-off-by: Bob Builder <bob@x.org>'" & LF
        & "c main 'Émile Zola' emile@x.org 'Accented author with a very long subject line that"
        & " will certainly need wrapping at seventy six columns or so'" & LF
        & "git checkout -qb side" & LF
        & "c side Dan dan@x.org 'side one'" & LF
        & "c side Dan dan@x.org 'side two'" & LF
        & "git checkout -q main" & LF
        & "n=$((n+1)); export GIT_AUTHOR_DATE=""@$((1000000000 + n*86400)) +0000"""
        & " GIT_COMMITTER_DATE=""@$((1000000000 + n*86400)) +0000""; git -c user.name=Merger -c"
        & " user.email=m@x.org merge -q --no-ff side -m 'merge side'" & LF
        & "c main A a@b 'empty-ish'" & LF
        & "git commit -q --allow-empty --allow-empty-message -m '' 2>/dev/null || true" & LF
        & "GIT_COMMITTER_NAME=Other GIT_COMMITTER_EMAIL=o@x.org c main A a@b 'committer differs'" & LF
        & "printf 'Robert Builder <bob@x.org>\n' > .mailmap; git add .mailmap; c main A a@b"
        & " 'mailmap'" & LF
        & "t 'plain' shortlog HEAD" & LF
        & "t 'HEAD' shortlog HEAD" & LF
        & "t '-s' shortlog -s HEAD" & LF
        & "t '-n' shortlog -n HEAD" & LF
        & "t '-sn' shortlog -sn HEAD" & LF
        & "t '-sne' shortlog -sne HEAD" & LF
        & "t '-e' shortlog -e HEAD" & LF
        & "t '-c' shortlog -c HEAD" & LF
        & "t '-cs' shortlog -cs HEAD" & LF
        & "t '--committer' shortlog --committer -s HEAD" & LF
        & "t '--numbered --summary --email' shortlog --numbered --summary --email HEAD" & LF
        & "t '--group=author' shortlog --group=author -s HEAD" & LF
        & "t '--group=committer' shortlog --group=committer -s HEAD" & LF
        & "t '--group both' shortlog --group=author --group=committer -s HEAD" & LF
        & "t '--group both -e' shortlog --group=author --group=committer -se HEAD" & LF
        & "t '--group=trailer' shortlog --group=trailer:Signed-off-by HEAD" & LF
        & "t '--group=trailer -s' shortlog -s --group=trailer:signed-off-by HEAD" & LF
        & "t '--group=trailer two' shortlog -s --group=trailer:Signed-off-by"
        & " --group=trailer:Reviewed-by HEAD" & LF
        & "t '--group=trailer + author' shortlog -s --group=trailer:Signed-off-by --group=author"
        & " HEAD" & LF
        & "t '--group=format' shortlog --group=format:%an HEAD" & LF
        & "t '--group=format -s' shortlog -s --group='%cn <%ce>'" & LF
        & "t '--group=format two' shortlog -s --group=format:%an --group=format:%cn HEAD" & LF
        & "t '--group bad' shortlog --group=nope HEAD" & LF
        & "t '--no-group' shortlog --group=committer --no-group -s HEAD" & LF
        & "t '-w' shortlog -w HEAD" & LF
        & "t '-w40' shortlog -w40 HEAD" & LF
        & "t '-w40,2,4' shortlog -w40,2,4 HEAD" & LF
        & "t '-w,3' shortlog -w,3 HEAD" & LF
        & "t '-w0' shortlog -w0 HEAD" & LF
        & "t '-w20,25' shortlog -w20,25 HEAD" & LF
        & "t '-wx' shortlog -wx HEAD" & LF
        & "t '-w -e' shortlog -we HEAD" & LF
        & "t '--format' shortlog --format='%h %s'" & LF
        & "t '--format=%s' shortlog --format=%s HEAD" & LF
        & "t '--pretty=format:' shortlog --pretty='format:%an: %s'" & LF
        & "t '--pretty=short' shortlog --pretty=short HEAD" & LF
        & "t '--pretty=oneline' shortlog --pretty=oneline HEAD" & LF
        & "t '--format=%ad --date=short' shortlog --format='%ad %s' --date=short" & LF
        & "t '--format=%ad' shortlog --format='%ad' HEAD" & LF
        & "t '--no-merges' shortlog --no-merges HEAD" & LF
        & "t '--merges' shortlog --merges HEAD" & LF
        & "t '--first-parent' shortlog --first-parent HEAD" & LF
        & "t '--all' shortlog --all -s" & LF
        & "t '--branches' shortlog --branches -s" & LF
        & "t 'range' shortlog HEAD~5..HEAD" & LF
        & "t 'range2' shortlog -s side..main" & LF
        & "t '^rev' shortlog -s ^side main" & LF
        & "t '-3' shortlog -3 HEAD" & LF
        & "t '--max-count=2' shortlog --max-count=2 HEAD" & LF
        & "t '--skip=2 -3' shortlog --skip=2 -3 HEAD" & LF
        & "t '--since' shortlog --since=2001-09-12 HEAD" & LF
        & "t '--until' shortlog --until=2001-09-12 HEAD" & LF
        & "t '--author' shortlog --author=Bob HEAD" & LF
        & "t '--author -i' shortlog --author=bob -i HEAD" & LF
        & "t '--grep' shortlog --grep=side HEAD" & LF
        & "t '--grep two --all-match' shortlog --grep=side --grep=one --all-match HEAD" & LF
        & "t '--invert-grep' shortlog --grep=side --invert-grep -s HEAD" & LF
        & "t '--reverse' shortlog --reverse HEAD" & LF
        & "t '-- path' shortlog -- f_side" & LF
        & "t 'path' shortlog f_main -s" & LF
        & "t 'bad rev' shortlog nope" & LF
        & "t '--output' shortlog --output=out.txt -s HEAD" & LF
        & "t '--group=trailer -e' shortlog -se --group=trailer:Signed-off-by HEAD" & LF
        & "t '-c --group=trailer' shortlog -s -c --group=trailer:Reviewed-by HEAD" & LF
        & "git log --pretty=short > log_short.txt; git log > log_full.txt; git log --pretty=raw"
        & " > log_raw.txt; git log --format=%H > ids.txt" & LF
        & "ts() { l=$1; shift; f=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$TOOL"" ""$@"" >> ""$TF"" 2>&1 <"
        & " ""$f""; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "ts 'stdin short' log_short.txt shortlog" & LF
        & "ts 'stdin short -s' log_short.txt shortlog -s" & LF
        & "ts 'stdin short -sne' log_short.txt shortlog -sne" & LF
        & "ts 'stdin full' log_full.txt shortlog" & LF
        & "ts 'stdin raw' log_raw.txt shortlog -s" & LF
        & "ts 'stdin raw -c' log_raw.txt shortlog -sc" & LF
        & "ts 'stdin full -c' log_full.txt shortlog -sc" & LF
        & "ts 'stdin ids' ids.txt shortlog" & LF
        & "ts 'stdin -w' log_short.txt shortlog -w30" & LF
        & "ts 'stdin --group=trailer' log_short.txt shortlog --group=trailer:x" & LF
        & "ts 'stdin --group=format' log_short.txt shortlog --group=%an" & LF
        & "ts 'stdin multi' log_short.txt shortlog --group=author --group=committer" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "shortlog");
   end Shortlog_Option_Surface_Matches_Git;

   --  `grep`: git's option surface over the grep.c port -- the pattern
   --  expression, every output layout, context and function context,
   --  binary handling, quoting, pathspecs and depth, revisions and blobs,
   --  --cached/--untracked/--no-index, config, the error texts, and the
   --  edge cases of context merging, -w, -o and --column.
   procedure Grep_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "git init -q; git config user.email a@b; git config user.name A" & LF
        & "cat > a.c <<'X'" & LF
        & "int main(void)" & LF
        & "{" & LF
        & "" & Character'Val (9) & "int foo = 1;" & LF
        & "" & Character'Val (9) & "foo += bar();" & LF
        & "" & Character'Val (9) & "return foo;" & LF
        & "}" & LF
        & "" & LF
        & "static int bar(void)" & LF
        & "{" & LF
        & "" & Character'Val (9) & "/* helper */" & LF
        & "" & Character'Val (9) & "return 42;" & LF
        & "}" & LF
        & "" & LF
        & "void FOO_upper(void) {}" & LF
        & "X" & LF
        & "cat > b.txt <<'X'" & LF
        & "first line" & LF
        & "second foo line" & LF
        & "third line with Foo and foo again" & LF
        & "fourth" & LF
        & "fifth foobar" & LF
        & "sixth" & LF
        & "" & LF
        & "eighth line" & LF
        & "X" & LF
        & "mkdir -p sub/deep; printf 'foo in sub\nnothing\n' > sub/s.txt; printf 'foo in"
        & " deep\n' > sub/deep/d.txt" & LF
        & "printf 'binary\0foo\n' > bin.dat" & LF
        & "printf 'no newline foo' > nonl.txt" & LF
        & "printf 'foo\n' > 'sp ace.txt'" & LF
        & "printf 'utf8 föö line\n' > utf.txt" & LF
        & "printf '*.dat -diff\nutf.txt diff\n' > .gitattributes" & LF
        & "printf 'ignored foo\n' > ignored.txt; printf 'ignored.txt\n' > .gitignore" & LF
        & "git add . ; git commit -qm one" & LF
        & "printf 'untracked foo\n' > untracked.txt" & LF
        & "printf 'changed foo in worktree\n' >> b.txt" & LF
        & "git tag v1" & LF
        & "t 'plain' grep foo" & LF
        & "t 'no match' grep zzz" & LF
        & "t '-n' grep -n foo" & LF
        & "t '-c' grep -c foo" & LF
        & "t '-l' grep -l foo" & LF
        & "t '-L' grep -L foo" & LF
        & "t '-h' grep -h foo" & LF
        & "t '-H -h' grep -H -h foo" & LF
        & "t '-i' grep -i foo" & LF
        & "t '-w' grep -w foo" & LF
        & "t '-w -n' grep -wn foo" & LF
        & "t '-v' grep -v foo a.c" & LF
        & "t '-v -c' grep -vc foo" & LF
        & "t '-o' grep -o foo" & LF
        & "t '-o -n' grep -on foo" & LF
        & "t '-o -i' grep -oi foo b.txt" & LF
        & "t '-o --column' grep -o --column foo b.txt" & LF
        & "t '--column' grep --column foo b.txt" & LF
        & "t '--column -n' grep --column -n foo" & LF
        & "t '-e twice' grep -e foo -e bar" & LF
        & "t '--and' grep -e foo --and -e bar" & LF
        & "t '--and -n' grep -n -e foo --and -e again" & LF
        & "t '--or' grep -e foo --or -e third" & LF
        & "t '--not' grep -e foo --and --not -e bar b.txt" & LF
        & "t 'parens' grep -n \( -e foo --or -e third \) --and -e line b.txt" & LF
        & "t '--all-match' grep --all-match -e foo -e bar" & LF
        & "t '--all-match -l' grep -l --all-match -e foo -e third" & LF
        & "t 'unmatched paren' grep \( -e foo" & LF
        & "t 'incomplete' grep -e foo \)" & LF
        & "t '--and missing' grep -e foo --and" & LF
        & "t '--not missing' grep --not" & LF
        & "t '-E' grep -E 'fo+' b.txt" & LF
        & "t '-E alt' grep -E 'second|fourth' b.txt" & LF
        & "t '-F' grep -F 'fo+' b.txt" & LF
        & "t '-F dot' grep -F 'e.' b.txt" & LF
        & "t '-G' grep -G 'fo\+' b.txt" & LF
        & "t '-P' grep -P 'fo{2}' b.txt" & LF
        & "t 'BRE group' grep '\(foo\)' b.txt" & LF
        & "t 'BRE brace' grep 'o\{2\}' b.txt" & LF
        & "t 'class' grep '[[:digit:]]' a.c" & LF
        & "t 'anchor' grep -n '^int' a.c" & LF
        & "t 'anchor end' grep -n 'line$' b.txt" & LF
        & "t 'empty pattern' grep -c ''" & LF
        & "t 'empty -o' grep -o '' b.txt" & LF
        & "t 'bad regex' grep '['" & LF
        & "t 'bad regex -E' grep -E '('" & LF
        & "t '-A1' grep -A1 -n foo a.c" & LF
        & "t '-B1' grep -B1 -n foo a.c" & LF
        & "t '-C1' grep -C1 -n foo a.c" & LF
        & "t '-2' grep -2 foo a.c" & LF
        & "t '-C1 multi' grep -C1 foo a.c b.txt" & LF
        & "t '-A1 -o' grep -A1 -o foo b.txt" & LF
        & "t '--context=2' grep --context=2 foo b.txt" & LF
        & "t '-p' grep -p foo a.c" & LF
        & "t '-p -n' grep -pn return a.c" & LF
        & "t '-W' grep -W helper a.c" & LF
        & "t '-W -n' grep -Wn 'return 42' a.c" & LF
        & "t '-W main' grep -W 'foo +=' a.c" & LF
        & "t '-p -B1' grep -p -B1 -n 'return 42' a.c" & LF
        & "t '--break' grep --break foo a.c b.txt" & LF
        & "t '--heading' grep --heading foo a.c b.txt" & LF
        & "t '--heading -n' grep --heading -n foo a.c b.txt" & LF
        & "t '--break --heading' grep --break --heading -n foo" & LF
        & "t '--break -C1' grep --break -C1 foo a.c b.txt" & LF
        & "t '-z' grep -z -l foo" & LF
        & "t '-z -n' grep -z -n foo a.c" & LF
        & "t '-z -c' grep -zc foo" & LF
        & "t '-m1' grep -m1 -n foo" & LF
        & "t '-m2' grep -m 2 foo b.txt" & LF
        & "t '-m0' grep -m0 foo" & LF
        & "t '-m1 -c' grep -m1 -c foo" & LF
        & "t '-m1 -A1' grep -m1 -A1 -n foo b.txt" & LF
        & "t '-q' grep -q foo" & LF
        & "t '-q none' grep -q zzz" & LF
        & "t '--color' grep --color=always -n foo b.txt" & LF
        & "t '--color -o' grep --color=always -o foo b.txt" & LF
        & "t '--color -C1' grep --color=always -C1 foo a.c" & LF
        & "t '--color -p' grep --color=always -p foo a.c" & LF
        & "t '--color --heading' grep --color=always --heading foo b.txt" & LF
        & "t '--color -c' grep --color=always -c foo b.txt" & LF
        & "t '--color -l' grep --color=always -l foo" & LF
        & "t '--color -v' grep --color=always -v foo b.txt" & LF
        & "t '--color --column' grep --color=always --column foo b.txt" & LF
        & "t '--no-color' grep --color=never foo b.txt" & LF
        & "t 'binary default' grep foo bin.dat" & LF
        & "t 'binary -a' grep -a foo bin.dat" & LF
        & "t 'binary -I' grep -I foo bin.dat" & LF
        & "t 'binary -c' grep -c foo bin.dat" & LF
        & "t 'binary -l' grep -l foo bin.dat" & LF
        & "t 'binary -o' grep -o foo bin.dat" & LF
        & "t 'attr text' grep -n 'o' utf.txt" & LF
        & "t 'nonl' grep -n foo nonl.txt" & LF
        & "t 'nonl -o' grep -o foo nonl.txt" & LF
        & "t 'space name' grep foo 'sp ace.txt'" & LF
        & "t 'space -l' grep -l foo 'sp ace.txt'" & LF
        & "t 'space -z' grep -z -l foo 'sp ace.txt'" & LF
        & "t 'utf8' grep -n 'f..' utf.txt" & LF
        & "t 'utf8 -o' grep -o 'f..' utf.txt" & LF
        & "t 'path dir' grep foo sub" & LF
        & "t 'path glob' grep foo '*.txt'" & LF
        & "t 'path glob2' grep -n foo -- '*.c'" & LF
        & "t '--max-depth=0' grep --max-depth=0 foo" & LF
        & "t '--max-depth=0 sub' grep --max-depth=0 foo sub" & LF
        & "t '--max-depth=1' grep --max-depth=1 foo" & LF
        & "t '--max-depth=1 sub' grep --max-depth=1 foo sub" & LF
        & "t '-r' grep -r foo sub" & LF
        & "t '--cached' grep --cached foo b.txt" & LF
        & "t '--cached -c' grep --cached -c foo" & LF
        & "t 'rev' grep -n foo HEAD" & LF
        & "t 'rev v1' grep foo v1 -- b.txt" & LF
        & "t 'rev two' grep -c foo HEAD v1" & LF
        & "t 'rev cached' grep --cached foo HEAD" & LF
        & "t 'rev -l' grep -l foo HEAD" & LF
        & "t 'rev -z' grep -z -l foo HEAD" & LF
        & "t 'rev -c' grep -c foo HEAD" & LF
        & "t 'rev blob' grep foo HEAD:b.txt" & LF
        & "t 'rev tree' grep foo HEAD^{tree}" & LF
        & "t 'rev bad' grep foo nope" & LF
        & "t 'rev bad dashdash' grep foo nope -- b.txt" & LF
        & "t 'path bad' grep foo b.txt nope" & LF
        & "t 'path bad dashdash' grep foo -- nope" & LF
        & "git tag b.txt; t 'ambiguous both' grep foo b.txt; git tag -d b.txt >/dev/null" & LF
        & "t '--untracked' grep --untracked foo" & LF
        & "t '--untracked -l' grep --untracked -l foo" & LF
        & "t '--no-index' grep --no-index -l foo" & LF
        & "t '--no-index --exclude-standard' grep --no-index --exclude-standard -l foo" & LF
        & "t '--untracked --no-exclude-standard' grep --untracked --no-exclude-standard -l"
        & " foo" & LF
        & "t '--exclude-standard tracked' grep --exclude-standard foo" & LF
        & "t '--no-index rev' grep --no-index foo HEAD -- b.txt" & LF
        & "t '--cached --untracked' grep --cached --untracked foo" & LF
        & "t '--full-name' grep --full-name foo b.txt" & LF
        & "printf 'foo\n\nbar\n' > pats.txt" & LF
        & "t '-f real' grep -f pats.txt -c" & LF
        & "t '-f missing' grep -f nofile" & LF
        & "t '-f -e' grep -f pats.txt -e third -n b.txt" & LF
        & "t 'no pattern' grep" & LF
        & "t 'only -e' grep -e" & LF
        & "t 'bad -C' grep -Cx foo" & LF
        & "t 'bad -A' grep -A foo" & LF
        & "t '--threads' grep --threads=2 -c foo b.txt" & LF
        & "t 'option after pattern' grep foo -n" & LF
        & "t 'dashdash first' grep -- foo b.txt" & LF
        & "t '-e then dashdash' grep -e foo -- b.txt" & LF
        & "t 'pattern then rev then path' grep -n foo HEAD b.txt" & LF
        & "t '-i -w' grep -iw foo" & LF
        & "t '-w -o' grep -wo foo b.txt" & LF
        & "t '-w -o -i' grep -woi foo b.txt" & LF
        & "t '-w -c' grep -wc 'foo'" & LF
        & "t '-w mid' grep -w 'oo' b.txt" & LF
        & "t '-w -v' grep -wv foo b.txt" & LF
        & "t '--textconv' grep --textconv foo bin.dat" & LF
        & "git config grep.lineNumber true" & LF
        & "t 'config linenumber' grep foo b.txt" & LF
        & "t 'config -n override' grep --no-line-number foo b.txt" & LF
        & "git config --unset grep.lineNumber" & LF
        & "git config grep.extendedRegexp true" & LF
        & "t 'config ere' grep 'second|fourth' b.txt" & LF
        & "t 'config ere -G' grep -G 'second|fourth' b.txt" & LF
        & "git config --unset grep.extendedRegexp" & LF
        & "git config grep.patternType fixed" & LF
        & "t 'config fixed' grep 'fo+' b.txt" & LF
        & "git config --unset grep.patternType" & LF
        & "git config grep.column true" & LF
        & "t 'config column' grep foo b.txt" & LF
        & "git config --unset grep.column" & LF
        & "git config grep.fullName true" & LF
        & "t 'config fullname' grep foo b.txt" & LF
        & "git config --unset grep.fullName" & LF
        & "git config color.grep.match 'bold blue'" & LF
        & "git config color.grep.filename yellow" & LF
        & "t 'config colors' grep --color=always foo b.txt" & LF
        & "git config --unset color.grep.match; git config --unset color.grep.filename" & LF
        & "cd sub" & LF
        & "t 'subdir' grep foo" & LF
        & "t 'subdir -l' grep -l foo" & LF
        & "t 'subdir full' grep --full-name -l foo" & LF
        & "t 'subdir rev' grep -l foo HEAD" & LF
        & "t 'subdir path up' grep -c foo ../b.txt" & LF
        & "t 'subdir -z' grep -z -l foo" & LF
        & "t 'subdir glob' grep -l foo '*.txt'" & LF
        & "cd .." & LF
        & "mkdir ""../${NAME}_2"" && cd ""../${NAME}_2""" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "cat > f.py <<'X'" & LF
        & "def alpha():" & LF
        & "    x = 1" & LF
        & "    y = 2" & LF
        & "    return x + y" & LF
        & "" & LF
        & "def beta():" & LF
        & "    """"""doc foo""""""" & LF
        & "    z = foo(3)" & LF
        & "" & LF
        & "    return z" & LF
        & "" & LF
        & "class Gamma:" & LF
        & "    def m(self):" & LF
        & "        foo = 4" & LF
        & "        return foo" & LF
        & "X" & LF
        & "printf 'l1 foo\nl2\nl3 foo\nl4\nl5\nl6 foo\nl7\nl8\nl9\nl10 foo\nl11\n' >"
        & " ctx.txt" & LF
        & "printf 'foofoo foo fo\nafooa foo\nfoo\n' > w.txt" & LF
        & "printf 'a foo b bar c\nfoo bar foo\nbar\n' > ab.txt" & LF
        & "printf 'crlf foo\r\nline two\r\n' > crlf.txt" & LF
        & ": > empty.txt" & LF
        & "printf '\n\n\n' > blanks.txt" & LF
        & "printf 'digits 123 and 45\nno digits\n' > num.txt" & LF
        & "printf 'MiXeD foo FOO Foo\n' > case.txt" & LF
        & "git add .; git commit -qm one" & LF
        & "t 'ctx overlap' grep -n -C1 foo ctx.txt" & LF
        & "t 'ctx -A2' grep -n -A2 foo ctx.txt" & LF
        & "t 'ctx -B2' grep -n -B2 foo ctx.txt" & LF
        & "t 'ctx -C3' grep -n -C3 foo ctx.txt" & LF
        & "t 'ctx -A1 -B2' grep -n -A1 -B2 foo ctx.txt" & LF
        & "t 'ctx -c' grep -c -C2 foo ctx.txt" & LF
        & "t 'ctx -l' grep -l -C2 foo ctx.txt" & LF
        & "t 'ctx -o' grep -o -C1 foo ctx.txt" & LF
        & "t 'ctx -v' grep -n -v -C1 foo ctx.txt" & LF
        & "t 'ctx -m2' grep -n -m2 -C1 foo ctx.txt" & LF
        & "t 'ctx two files' grep -n -C1 foo ctx.txt w.txt" & LF
        & "t 'ctx --break' grep -n -C1 --break foo ctx.txt w.txt" & LF
        & "t 'ctx --heading' grep -n -C1 --heading foo ctx.txt w.txt" & LF
        & "t 'ctx --break --heading' grep -n -C1 --break --heading foo ctx.txt w.txt" & LF
        & "t 'ctx color' grep -n -C1 --color=always foo ctx.txt" & LF
        & "t '-p py' grep -p foo f.py" & LF
        & "t '-p -n py' grep -pn return f.py" & LF
        & "t '-W py' grep -W 'z = foo' f.py" & LF
        & "t '-W return' grep -W 'return' f.py" & LF
        & "t '-W -n class' grep -Wn 'foo = 4' f.py" & LF
        & "t '-W -C1' grep -W -C1 'x = 1' f.py" & LF
        & "t '-W def' grep -W 'def beta' f.py" & LF
        & "t '-W first' grep -W 'def alpha' f.py" & LF
        & "t '-W -p' grep -W -p 'return z' f.py" & LF
        & "t '-p -A1' grep -p -A1 -n 'x = 1' f.py" & LF
        & "t '-p multi' grep -p -n 'return' f.py ctx.txt" & LF
        & "t '-w foofoo' grep -wn foo w.txt" & LF
        & "t '-w -o foofoo' grep -wo foo w.txt" & LF
        & "t '-w -c' grep -wc foo w.txt" & LF
        & "t '-w fo' grep -w fo w.txt" & LF
        & "t '-w -v' grep -wv foo w.txt" & LF
        & "t '-w regex' grep -w 'fo*' w.txt" & LF
        & "t '-w --column' grep -w --column foo w.txt" & LF
        & "t '-o multi' grep -o -e foo -e bar ab.txt" & LF
        & "t '-o overlap' grep -o -e foo -e 'foo b' ab.txt" & LF
        & "t '-o --column multi' grep -o --column -e foo -e bar ab.txt" & LF
        & "t '--column --and' grep --column -e foo --and -e bar ab.txt" & LF
        & "t '--column --not' grep --column -e foo --and --not -e bar ab.txt" & LF
        & "t '--column -v' grep --column -v foo ab.txt" & LF
        & "t '--column --or' grep --column -e bar --or -e foo ab.txt" & LF
        & "t '--column -e2' grep --column -e bar -e foo ab.txt" & LF
        & "t 'and color' grep --color=always -e foo --and -e bar ab.txt" & LF
        & "t 'not color' grep --color=always -e foo --and --not -e 'c$' ab.txt" & LF
        & "t 'crlf' grep -n foo crlf.txt" & LF
        & "t 'crlf $' grep -n 'foo$' crlf.txt" & LF
        & "t 'crlf -o' grep -o 'foo.' crlf.txt" & LF
        & "t 'empty file' grep -c '' empty.txt" & LF
        & "t 'empty file -L' grep -L foo empty.txt" & LF
        & "t 'blanks' grep -n '^$' blanks.txt" & LF
        & "t 'blanks -c' grep -c '' blanks.txt" & LF
        & "t 'blanks -v' grep -vn 'x' blanks.txt" & LF
        & "t '-P digits' grep -P '\d+' num.txt" & LF
        & "t '-P -o' grep -oP '\d+' num.txt" & LF
        & "t '-E digits' grep -E '[0-9]+' num.txt" & LF
        & "t '-E -o' grep -oE '[0-9]+' num.txt" & LF
        & "t '-i color' grep --color=always -i foo case.txt" & LF
        & "t '-i -o' grep -io foo case.txt" & LF
        & "t '-i -c' grep -ic foo case.txt" & LF
        & "t '-i -w' grep -iw foo case.txt" & LF
        & "t 'icase class' grep -i '[a-c]' case.txt" & LF
        & "t '-L' grep -L foo" & LF
        & "t '-L -v' grep -L -v foo" & LF
        & "t '-l -v' grep -l -v foo" & LF
        & "t '-c -v' grep -c -v foo w.txt" & LF
        & "t '-c -m1' grep -c -m1 foo w.txt" & LF
        & "t '-c -o' grep -c -o foo w.txt" & LF
        & "t '-q -l' grep -q -l foo" & LF
        & "t '-h -n' grep -hn foo w.txt ab.txt" & LF
        & "t '-H -l' grep -Hl foo w.txt" & LF
        & "t '-z -o' grep -zo foo w.txt" & LF
        & "t '--heading -o' grep --heading -o foo ab.txt w.txt" & LF
        & "t '--heading -c' grep --heading -c foo ab.txt w.txt" & LF
        & "t '--heading --column' grep --heading --column -n foo ab.txt" & LF
        & "t '--break -l' grep --break -l foo" & LF
        & "t '--break -c' grep --break -c foo" & LF
        & "t 'rev path' grep -n foo HEAD -- w.txt ab.txt" & LF
        & "t 'rev ctx' grep -n -C1 foo HEAD -- ctx.txt" & LF
        & "t 'rev -p' grep -p foo HEAD -- f.py" & LF
        & "t 'rev heading' grep --heading -n foo HEAD -- w.txt ab.txt" & LF
        & "t 'rev -z' grep -z -n foo HEAD -- w.txt" & LF
        & "t 'rev -o' grep -o --column foo HEAD -- ab.txt" & LF
        & "t 'rev -c' grep -c foo HEAD HEAD^{tree}" & LF
        & "t 'rev -l -h' grep -lh foo HEAD" & LF
        & "t '-e -- path' grep -n -e foo -- w.txt" & LF
        & "t 'double dash pattern' grep -- -n" & LF
        & "t 'literal dash pattern' grep -e -n" & LF
        & "t '-F dash' grep -F -- '-n'" & LF
        & "t 'unknown after --' grep -n foo -- --bogus" & LF
        & "t 'after pattern option' grep foo -n w.txt" & LF
        & "t '--all-match --and' grep -l --all-match -e foo --and -e bar -e l1" & LF
        & "t '--all-match none' grep -l --all-match -e foo -e zzz" & LF
        & "printf 'foo\nbar\n' > p1; printf 'l1\n' > p2" & LF
        & "t '-f twice' grep -c -f p1 -f p2" & LF
        & "t '-f -F' grep -F -f p1 -c" & LF
        & "printf 'ok\n[\n' > p3" & LF
        & "t '-f bad line' grep -f p3 w.txt" & LF
        & "t '-e bad' grep -e 'a\{1'" & LF
        & "t '-E bad' grep -E 'a{'" & LF
        & "t '--and bad' grep -e foo --and -e '['" & LF
        & "t 'max-count neg' grep -m -1 -c foo w.txt" & LF
        & "t 'max-count=x' grep --max-count=x foo" & LF
        & "t '-A=' grep --after-context=x foo" & LF
        & "t '-B bad' grep -B x foo" & LF
        & "t '--context bad' grep --context=x foo" & LF
        & "t '-C -1' grep -C -1 foo w.txt" & LF
        & "t 'nested parens' grep -n \( \( -e l1 --or -e l3 \) --and -e foo \) ctx.txt" & LF
        & "t 'not not' grep -n --not --not -e foo w.txt" & LF
        & "t 'or then and' grep -n -e l1 --or -e l3 --and -e foo ctx.txt" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "grep");
   end Grep_Option_Surface_Matches_Git;

   --  `notes`: git's option surface and state machines -- the message
   --  pieces (-m/-F/-C/-c, separators, stripspace), the editor template
   --  (add/edit/append, the empty-message removal), --ref and the
   --  GIT_NOTES_REF/core.notesRef defaults, copy (including --stdin and
   --  --for-rewrite with notes.rewrite* config), remove --stdin, prune
   --  -n/-v, and merge with every strategy plus the manual worktree,
   --  --commit and --abort flow.
   procedure Notes_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "state() { :; }" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'a\n' > f; git add f; git commit -qm one" & LF
        & "printf 'b\n' >> f; git commit -qam two" & LF
        & "printf 'c\n' >> f; git commit -qam three" & LF
        & "git tag -a -m 'tag msg' v1 HEAD~1" & LF
        & "C3=$(git rev-parse HEAD); C2=$(git rev-parse HEAD~1); C1=$(git " & "rev-parse HEAD~2)" & LF
        & "t 'list empty' notes list" & LF
        & "t 'bare' notes" & LF
        & "t 'show none' notes show" & LF
        & "t 'get-ref' notes get-ref" & LF
        & "t 'get-ref --ref x' notes --ref x get-ref" & LF
        & "t 'get-ref --ref sep' notes --ref refs/notes/y get-ref" & LF
        & "t 'get-ref notes/z' notes --ref notes/z get-ref" & LF
        & "t 'get-ref refs/heads' notes --ref refs/heads/main get-ref" & LF
        & "t 'add -m' notes add -m 'first note'" & LF
        & "t 'show' notes show" & LF
        & "t 'list' notes list" & LF
        & "t 'list one' notes list HEAD" & LF
        & "t 'list bad' notes list nonexist" & LF
        & "t 'add exists' notes add -m 'again'" & LF
        & "t 'add -f' notes add -f -m 'again'" & LF
        & "t 'show again' notes show HEAD" & LF
        & "t 'add two -m' notes add -m 'para one' -m 'para two' HEAD~1" & LF
        & "t 'show two' notes show HEAD~1" & LF
        & "t 'add separator' notes add -f -m 'p1' -m 'p2' --separator='---' " & "HEAD~1" & LF
        & "t 'show sep' notes show HEAD~1" & LF
        & "t 'add no-separator' notes add -f -m 'p1' -m 'p2' --no-separator " & "HEAD~1" & LF
        & "t 'show nosep' notes show HEAD~1" & LF
        & "t 'add separator nl' notes add -f -m 'p1' -m 'p2' --separator HEAD~1" & LF
        & "t 'show sepnl' notes show HEAD~1" & LF
        & "t 'add no-stripspace' notes add -f --no-stripspace -m '  spaced  ' -m " & "'x' HEAD~1" & LF
        & "to() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$TOOL"" ""$@"" 2>>""$TF"" < "
          & "/dev/null | od -c >> ""$TF""; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "to 'show nostrip' notes show HEAD~1" & LF
        & "t 'add stripspace' notes add -f --stripspace -m '  spaced  ' -m 'x' " & "HEAD~1" & LF
        & "to 'show strip' notes show HEAD~1" & LF
        & "t 'append' notes append -m 'appended' HEAD~1" & LF
        & "t 'show appended' notes show HEAD~1" & LF
        & "t 'append sep' notes append --separator='***' -m 'more' HEAD~1" & LF
        & "t 'show appended2' notes show HEAD~1" & LF
        & "t 'append new' notes append -m 'fresh' HEAD~2" & LF
        & "t 'show fresh' notes show HEAD~2" & LF
        & "t 'append allow-empty' notes append --allow-empty HEAD~2" & LF
        & "t 'list all' notes list" & LF
        & "t 'copy' notes copy HEAD~2 v1" & LF
        & "t 'copy exists' notes copy HEAD~2 HEAD" & LF
        & "t 'copy -f' notes copy -f HEAD~2 HEAD" & LF
        & "t 'copy missing' notes copy v1^{} HEAD" & LF
        & "t 'copy to head' notes copy -f HEAD~1" & LF
        & "t 'show head' notes show" & LF
        & "t 'remove' notes remove HEAD~2" & LF
        & "t 'remove again' notes remove HEAD~2" & LF
        & "t 'remove ignore' notes remove --ignore-missing HEAD~2" & LF
        & "t 'remove bad' notes remove bogus" & LF
        & "t 'remove bad2' notes remove --ignore-missing bogus HEAD" & LF
        & "t 'list after' notes list" & LF
        & "printf '%s\n%s\n\n' ""$C1"" ""$C2"" > rm.txt" & LF
        & "ts() { l=$1; f=$2; shift 2; echo ""\$ $l"" >> ""$TF""; ""$TOOL"" ""$@"" >> "
          & """$TF"" 2>&1 < ""$f""; echo ""[rc=$?]"" >> ""$TF""; state; }" & LF
        & "ts 'remove stdin' rm.txt notes remove --stdin" & LF
        & "printf '%s \n' ""$C3"" > rm2.txt" & LF
        & "ts 'remove stdin2' rm2.txt notes remove --stdin" & LF
        & "t 'list after2' notes list" & LF
        & "t 'log notes' log --format='%h %s%n%N' refs/notes/commits" & LF
        & "t 'reflog' reflog refs/notes/commits" & LF
        & "t 'add allow-empty' notes add --allow-empty" & LF
        & "t 'show empty' notes show" & LF
        & "t 'list empty note' notes list HEAD" & LF
        & "t 'add -C' notes add -f -C HEAD:f" & LF
        & "to 'show -C' notes show" & LF
        & "t 'add -C nonblob' notes add -f -C HEAD" & LF
        & "t 'add -C bad' notes add -f -C bogus" & LF
        & "t 'add -m -C' notes add -f -m 'lead' -C HEAD:f" & LF
        & "to 'show m-C' notes show" & LF
        & "printf 'file content\n\n\n' > msg.txt" & LF
        & "t 'add -F' notes add -f -F msg.txt" & LF
        & "to 'show -F' notes show" & LF
        & "t 'add -F missing' notes add -f -F nope.txt" & LF
        & "ts 'add -F -' msg.txt notes add -f -F -" & LF
        & "t 'show bad' notes show bogus" & LF
        & "t 'prune -n' notes prune -n" & LF
        & "t 'prune -v' notes prune -v" & LF
        & "t 'prune' notes prune" & LF
        & "t 'ref outside' notes --ref refs/heads/main list" & LF
        & "GIT_NOTES_REF=refs/heads/main t 'env outside add' notes add -m x" & LF
        & "GIT_NOTES_REF=refs/notes/env t 'env add' notes add -m envnote" & LF
        & "GIT_NOTES_REF=refs/notes/env t 'env get-ref' notes get-ref" & LF
        & "t 'env list' notes --ref env list" & LF
        & "git config core.notesRef refs/notes/cfg" & LF
        & "t 'cfg get-ref' notes get-ref" & LF
        & "t 'cfg add' notes add -m cfgnote" & LF
        & "t 'cfg list' notes list" & LF
        & "git config --unset core.notesRef" & LF
        & "t 'ref sep add' notes --ref sep add -m sepnote HEAD~1" & LF
        & "t 'ref sep list' notes --ref sep list" & LF
        & "t 'for-each-ref' for-each-ref refs/notes" & LF
        & "# --- editor flows: an editor that captures the template and writes a " & "note" & LF
        & "cat > ed.sh <<'X'" & LF
        & "#!/bin/sh" & LF
        & "cat ""$1"" > ""$(dirname ""$1"")/../captured.txt""" & LF
        & "printf 'edited note\n# a comment line\n\n\n' > ""$1""" & LF
        & "X" & LF
        & "chmod +x ed.sh" & LF
        & "x() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$@"" >> ""$TF"" 2>&1; echo "
          & """[rc=$?]"" >> ""$TF""; }" & LF
        & "tE() { l=$1; e=$2; shift 2; echo ""\$ $l"" >> ""$TF""; GIT_EDITOR=""$e"" "
          & """$TOOL"" ""$@"" >> ""$TF"" 2>&1 < /dev/null; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "tE 'add editor' ./ed.sh notes add" & LF
        & "x 'captured' cat captured.txt" & LF
        & "t 'show edited' notes show" & LF
        & "tE 'add editor existing -> edit' ./ed.sh notes add" & LF
        & "x 'captured2' cat captured.txt" & LF
        & "tE 'edit -e -m' ./ed.sh notes edit -m 'msg via edit'" & LF
        & "t 'show edit -m' notes show" & LF
        & "tE 'add -e -m' ./ed.sh notes add -f -e -m 'seed msg'" & LF
        & "x 'captured3' cat captured.txt" & LF
        & "t 'show add -e' notes show" & LF
        & "tE 'append -e' ./ed.sh notes append -e HEAD~1" & LF
        & "x 'captured4' cat captured.txt" & LF
        & "t 'show append -e' notes show HEAD~1" & LF
        & "tE 'edit no-stripspace' ./ed.sh notes edit --no-stripspace HEAD~1" & LF
        & "to() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$TOOL"" ""$@"" 2>>""$TF"" < "
          & "/dev/null | od -c >> ""$TF""; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "to 'show nostrip' notes show HEAD~1" & LF
        & "tE 'edit empty -> remove' true notes edit HEAD~1" & LF
        & "t 'list after remove' notes list" & LF
        & "tE 'add editor fails' false notes add HEAD~2" & LF
        & "tE 'add -c' ./ed.sh notes add -f -c HEAD:f" & LF
        & "x 'captured5' cat captured.txt" & LF
        & "tE 'edit allow-empty' true notes edit --allow-empty HEAD~2" & LF
        & "t 'list allow-empty' notes list" & LF
        & "# --- merge" & LF
        & "t 'merge abort nothing' notes merge --abort" & LF
        & "t 'merge commit nothing' notes merge --commit" & LF
        & "t 'merge missing remote' notes merge nosuch" & LF
        & "t 'merge bad remote name' notes merge 'bad..name'" & LF
        & "git notes add -f -m base HEAD; git notes add -f -m base1 HEAD~1; git "
          & "notes add -f -m base2 HEAD~2" & LF
        & "git update-ref refs/notes/other refs/notes/commits" & LF
        & "t 'merge same' notes merge other" & LF
        & "t 'merge same -v' notes merge -v other" & LF
        & "t 'merge same -vv' notes merge -vv other" & LF
        & "t 'merge same -q' notes merge -q other" & LF
        & "git notes --ref other add -f -m theirs HEAD" & LF
        & "t 'merge ff' notes merge other" & LF
        & "t 'show after ff' notes show" & LF
        & "t 'reflog ff' reflog refs/notes/commits" & LF
        & "git notes add -f -m ours HEAD; git notes --ref other add -f -m theirs2 "
          & "HEAD; git notes --ref other add -f -m t1 HEAD~1; git notes --ref other "
          & "remove HEAD~2; git notes add -f -m o2 HEAD~2" & LF
        & "t 'merge conflict' notes merge other" & LF
        & "x 'worktree' ls .git/NOTES_MERGE_WORKTREE" & LF
        & "x 'conflict file' cat .git/NOTES_MERGE_WORKTREE/$C3" & LF
        & "x 'conflict file2' cat .git/NOTES_MERGE_WORKTREE/$C1" & LF
        & "t 'partial' cat-file -p NOTES_MERGE_PARTIAL" & LF
        & "x 'merge ref' cat .git/NOTES_MERGE_REF" & LF
        & "t 'merge again' notes merge other" & LF
        & "t 'merge again -s ours' notes merge -s ours other" & LF
        & "printf 'resolved\n' > .git/NOTES_MERGE_WORKTREE/$C3" & LF
        & "/bin/rm .git/NOTES_MERGE_WORKTREE/$C1" & LF
        & "t 'merge commit' notes merge --commit" & LF
        & "t 'show resolved' notes show" & LF
        & "t 'show t1' notes show HEAD~1" & LF
        & "t 'list resolved' notes list" & LF
        & "t 'log merged' log --format='%h %p %s%n%b' refs/notes/commits" & LF
        & "t 'reflog merged' reflog refs/notes/commits" & LF
        & "x 'state gone' ls .git/NOTES_MERGE_WORKTREE .git/NOTES_MERGE_REF " & ".git/NOTES_MERGE_PARTIAL" & LF
        & "t 'merge commit again' notes merge --commit" & LF
        & "t 'merge abort again' notes merge --abort" & LF
        & "# strategies" & LF
        & "git notes add -f -m 'l1\nshared' HEAD; git notes --ref other add -f -m " & "'r1\nshared' HEAD" & LF
        & "t 'merge ours' notes merge -s ours other" & LF
        & "t 'show ours' notes show" & LF
        & "git notes --ref other add -f -m 'r2' HEAD" & LF
        & "t 'merge theirs' notes merge -s theirs other" & LF
        & "t 'show theirs' notes show" & LF
        & "git notes add -f -m 'l3' HEAD; git notes --ref other add -f -m 'r3' " & "HEAD" & LF
        & "t 'merge union' notes merge -s union other" & LF
        & "t 'show union' notes show" & LF
        & "git notes add -f -m 'b line" & LF
        & "a line" & LF
        & "b line' HEAD; git notes --ref other add -f -m 'c line" & LF
        & "a line' HEAD" & LF
        & "t 'merge csu' notes merge -s cat_sort_uniq other" & LF
        & "t 'show csu' notes show" & LF
        & "git notes add -f -m 'l4' HEAD; git notes --ref other add -f -m 'r4' " & "HEAD" & LF
        & "git config notes.mergeStrategy union" & LF
        & "t 'merge cfg union' notes merge other" & LF
        & "t 'show cfg union' notes show" & LF
        & "git notes add -f -m 'l5' HEAD; git notes --ref other add -f -m 'r5' " & "HEAD" & LF
        & "git config notes.commits.mergeStrategy theirs" & LF
        & "t 'merge cfg theirs' notes merge other" & LF
        & "t 'show cfg theirs' notes show" & LF
        & "git config --unset notes.commits.mergeStrategy; git config --unset " & "notes.mergeStrategy" & LF
        & "# manual conflict then abort" & LF
        & "git notes add -f -m 'l6' HEAD; git notes --ref other add -f -m 'r6' " & "HEAD" & LF
        & "t 'merge conflict2' notes merge other" & LF
        & "t 'merge abort' notes merge --abort" & LF
        & "x 'state after abort' ls .git/NOTES_MERGE_WORKTREE "
          & ".git/NOTES_MERGE_REF .git/NOTES_MERGE_PARTIAL" & LF
        & "t 'show after abort' notes show" & LF
        & "# merge into unborn / from unborn" & LF
        & "t 'merge into unborn' notes --ref fresh merge other" & LF
        & "t 'fresh list' notes --ref fresh list" & LF
        & "t 'merge from unborn' notes merge unborn" & LF
        & "t 'merge empty into empty' notes --ref e1 merge e2" & LF
        & "# merge a commit id directly" & LF
        & "t 'merge by id' notes --ref byid merge $(git rev-parse " & "refs/notes/other)" & LF
        & "t 'byid list' notes --ref byid list" & LF
        & "# delete/modify conflict" & LF
        & "git notes add -f -m 'dm' HEAD~2; git update-ref refs/notes/dm "
          & "refs/notes/commits; git notes --ref dm remove HEAD~2; git notes add -f " & "-m 'dm2' HEAD~2" & LF
        & "t 'merge del/mod' notes merge dm" & LF
        & "x 'del/mod file' cat .git/NOTES_MERGE_WORKTREE/$C1" & LF
        & "t 'abort2' notes merge --abort" & LF
        & "git notes add -f -m 'dm3' HEAD~2; git update-ref refs/notes/dm "
          & "refs/notes/commits; git notes --ref dm add -f -m 'dm4' HEAD~2; git " & "notes remove HEAD~2" & LF
        & "t 'merge mod/del' notes merge dm" & LF
        & "x 'mod/del file' cat .git/NOTES_MERGE_WORKTREE/$C1" & LF
        & "t 'abort3' notes merge --abort" & LF
        & "# add/add conflict" & LF
        & "git notes add -f -m 'aa1' HEAD~2; git update-ref refs/notes/aa "
          & "HEAD^{}; git notes --ref aa add -f -m 'aa2' HEAD~2" & LF
        & "t 'merge add/add' notes merge -v aa" & LF
        & "x 'add/add file' cat .git/NOTES_MERGE_WORKTREE/$C1" & LF
        & "t 'abort4' notes merge --abort" & LF
        & "# --- copy --stdin and --for-rewrite" & LF
        & "printf '%s %s\n' ""$C3"" ""$C2"" > cp.txt" & LF
        & "ts 'copy stdin exists' cp.txt notes copy --stdin" & LF
        & "ts 'copy stdin -f' cp.txt notes copy -f --stdin" & LF
        & "t 'show copied' notes show HEAD~1" & LF
        & "printf 'bogus\n' > cp2.txt" & LF
        & "ts 'copy stdin malformed' cp2.txt notes copy --stdin" & LF
        & "printf 'nope %s\n' ""$C2"" > cp3.txt" & LF
        & "ts 'copy stdin unresolvable' cp3.txt notes copy --stdin" & LF
        & "t 'rewrite no config' notes copy --for-rewrite=amend" & LF
        & "git config notes.rewriteRef refs/notes/commits" & LF
        & "ts 'rewrite default' cp.txt notes copy --for-rewrite=amend" & LF
        & "t 'show rewrite' notes show HEAD~1" & LF
        & "git config notes.rewriteMode overwrite" & LF
        & "ts 'rewrite overwrite' cp.txt notes copy --for-rewrite=amend" & LF
        & "t 'show rewrite2' notes show HEAD~1" & LF
        & "git config notes.rewrite.amend false" & LF
        & "ts 'rewrite disabled' cp.txt notes copy --for-rewrite=amend" & LF
        & "git config notes.rewrite.amend true" & LF
        & "git config notes.rewriteMode cat_sort_uniq" & LF
        & "git notes add -f -m 'z" & LF
        & "a' HEAD~1" & LF
        & "ts 'rewrite csu' cp.txt notes copy --for-rewrite=amend" & LF
        & "t 'show rewrite3' notes show HEAD~1" & LF
        & "git config notes.rewriteMode ignore" & LF
        & "ts 'rewrite ignore' cp.txt notes copy --for-rewrite=amend" & LF
        & "t 'show rewrite4' notes show HEAD~1" & LF
        & "git config notes.rewriteMode bogus" & LF
        & "ts 'rewrite bad mode' cp.txt notes copy --for-rewrite=amend" & LF
        & "git config notes.rewriteMode concatenate" & LF
        & "git config --add notes.rewriteRef refs/notes/other" & LF
        & "git config --add notes.rewriteRef refs/heads/main" & LF
        & "ts 'rewrite two refs' cp.txt notes copy --for-rewrite=amend" & LF
        & "t 'show other rewrite' notes --ref other show HEAD~1" & LF
        & "GIT_NOTES_REWRITE_REF=refs/notes/x1:refs/notes/x2 "
          & "GIT_NOTES_REWRITE_MODE=overwrite ts 'rewrite env' cp.txt notes copy " & "--for-rewrite=amend" & LF
        & "t 'x1 list' notes --ref x1 list" & LF
        & "t 'log commits' log --format='%h %s' refs/notes/commits" & LF
        & "t 'log other' log --format='%h %s' refs/notes/other" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "notes");
   end Notes_Option_Surface_Matches_Git;

   --  `tag`: git's option surface -- creation (lightweight on any object,
   --  -a/-m/-F/-e/--trailer/--cleanup, -f with git's report, the editor
   --  template, nested-tag advice, --create-reflog), listing (patterns,
   --  -n, --format, --sort keys, -i, --contains/--no-contains/--merged/
   --  --no-merged/--points-at with their defaults, --column, --omit-empty,
   --  --color, tag.sort and column.* config), delete and verify, and git's
   --  refusals.
   procedure Tag_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "state() { :; }" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'a\n' > f; git add f; git commit -qm one" & LF
        & "printf 'b\n' >> f; git commit -qam two" & LF
        & "git checkout -q -b side HEAD~1; printf 'c\n' > g; git add g; git "
          & "commit -qm side-commit; git checkout -q main" & LF
        & "printf 'd\n' >> f; git commit -qam three" & LF
        & "x() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$@"" >> ""$TF"" 2>&1; echo "
          & """[rc=$?]"" >> ""$TF""; }" & LF
        & "ts() { l=$1; f=$2; shift 2; echo ""\$ $l"" >> ""$TF""; ""$TOOL"" ""$@"" >> "
          & """$TF"" 2>&1 < ""$f""; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "tE() { l=$1; e=$2; shift 2; echo ""\$ $l"" >> ""$TF""; GIT_EDITOR=""$e"" "
          & """$TOOL"" ""$@"" >> ""$TF"" 2>&1 < /dev/null; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "t 'empty list' tag" & LF
        & "t 'lightweight' tag v1 HEAD~2" & LF
        & "t 'annotated -m' tag -a -m 'first release' v1.0 HEAD~1" & LF
        & "t 'annotated -m twice' tag -m 'para one' -m 'para two' v1.1" & LF
        & "x 'cat v1.1' git cat-file tag v1.1" & LF
        & "t 'blob tag' tag blobtag HEAD:f" & LF
        & "t 'tree tag' tag treetag HEAD^{tree}" & LF
        & "t 'nested' tag -a -m 'nested' nested v1.0" & LF
        & "t 'bundled -am' tag -am 'bundled msg' v2" & LF
        & "t 'list' tag" & LF
        & "t 'list -l' tag -l" & LF
        & "t 'list pattern' tag -l 'v1*'" & LF
        & "t 'list pattern2' tag -l 'v?'" & LF
        & "t 'list patterns' tag -l 'v1' 'v2'" & LF
        & "t 'list -i' tag -l -i 'V1*'" & LF
        & "t 'list -n' tag -n" & LF
        & "t 'list -n2' tag -n2 'v1*'" & LF
        & "t 'list -n 2' tag -n 2" & LF
        & "t 'list -n --format' tag -n --format='%(refname) %(objecttype)'" & LF
        & "t 'list --format' tag -l --format='%(refname:short) %(objecttype) " & "%(*objecttype)'" & LF
        & "t 'list --format contents' tag --list --format='%(refname:short): " & "%(contents:lines=1)'" & LF
        & "t 'list --sort=-refname' tag --sort=-refname" & LF
        & "t 'list --sort=v:refname' tag --sort=v:refname" & LF
        & "t 'list two sorts' tag --sort=-refname --sort=objecttype" & LF
        & "t 'list -i sort' tag -i --sort=refname" & LF
        & "t 'contains' tag --contains HEAD~2" & LF
        & "t 'contains default' tag --contains" & LF
        & "t 'contains side' tag --contains side" & LF
        & "t 'no-contains' tag --no-contains HEAD~1" & LF
        & "t 'with' tag --with HEAD~1" & LF
        & "t 'without' tag --without HEAD~1" & LF
        & "t 'merged' tag --merged HEAD~1" & LF
        & "t 'merged default' tag --merged" & LF
        & "t 'no-merged' tag --no-merged HEAD~1" & LF
        & "t 'merged side' tag --merged side --merged HEAD~2" & LF
        & "t 'points-at' tag --points-at HEAD~1" & LF
        & "t 'points-at default' tag --points-at" & LF
        & "t 'points-at blob' tag --points-at HEAD:f" & LF
        & "t 'points-at two' tag --points-at HEAD~1 --points-at HEAD~2" & LF
        & "t 'column' tag --column" & LF
        & "t 'column row' tag --column=row" & LF
        & "t 'column dense' tag --column=dense" & LF
        & "t 'column plain' tag --column=plain" & LF
        & "t 'column never' tag --column=never" & LF
        & "t 'no-column' tag --no-column" & LF
        & "t 'column -n' tag --column -n" & LF
        & "t 'omit-empty' tag " & "--format='%(if)%(*objecttype)%(then)%(refname:short)%(end)' "
          & "--omit-empty" & LF
        & "t 'color' tag --color " & "--format='%(color:red)%(refname:short)%(color:reset)' 'v1*'" & LF
        & "t 'color never' tag --color=never " & "--format='%(color:red)%(refname:short)%(color:reset)' 'v1*'" & LF
        & "t 'exists' tag v1" & LF
        & "t 'force same' tag -f v1 HEAD~2" & LF
        & "t 'force move' tag -f v1 HEAD" & LF
        & "t 'force annotated' tag -f -a -m 'moved' v1.0 HEAD" & LF
        & "t 'invalid name' tag 'bad..name'" & LF
        & "t 'dash name' tag -- -x" & LF
        & "t 'too many' tag t3 HEAD HEAD" & LF
        & "t 'unresolvable' tag t4 nope" & LF
        & "t '-d --contains' tag -d --contains HEAD x" & LF
        & "t '-v -n' tag -v -n1 x" & LF
        & "t '-F -m' tag -F f -m x t" & LF
        & "t 'delete' tag -d v2" & LF
        & "t 'delete two' tag -d nested blobtag" & LF
        & "t 'delete missing' tag -d nope v1.1" & LF
        & "t 'delete none' tag -d" & LF
        & "t 'list after' tag" & LF
        & "t 'verify lw' tag -v v1" & LF
        & "t 'verify unsigned' tag -v v1.0" & LF
        & "t 'verify missing' tag -v nope" & LF
        & "t 'verify none' tag -v" & LF
        & "printf 'from file\n\n# comment\n\n' > msg.txt" & LF
        & "t '-F' tag -F msg.txt f1" & LF
        & "x 'cat f1' git cat-file tag f1" & LF
        & "ts '-F -' msg.txt tag -F - f2" & LF
        & "x 'cat f2' git cat-file tag f2" & LF
        & "t '-F missing' tag -F nope.txt f3" & LF
        & "t 'cleanup verbatim' tag --cleanup=verbatim -m 'x  ' -m 'y' cv" & LF
        & "x 'cat cv' git cat-file tag cv" & LF
        & "t 'cleanup whitespace' tag --cleanup=whitespace -F msg.txt cw" & LF
        & "x 'cat cw' git cat-file tag cw" & LF
        & "t 'cleanup bad' tag --cleanup=bogus -m x cb" & LF
        & "t 'empty -m' tag -a -m '' e1" & LF
        & "x 'cat e1' git cat-file tag e1" & LF
        & "t 'trailer' tag -m 'subject' --trailer 'Signed-off-by: A <a@b>' " & "--trailer 'Key=Value' tr1" & LF
        & "x 'cat tr1' git cat-file tag tr1" & LF
        & "t 'create-reflog' tag --create-reflog r1 HEAD~1" & LF
        & "x 'reflog r1' git reflog refs/tags/r1" & LF
        & "t 'create-reflog blob' tag --create-reflog r2 HEAD:f" & LF
        & "x 'reflog r2' cat .git/logs/refs/tags/r2" & LF
        & "t 'create-reflog tag' tag --create-reflog r3 v1.0" & LF
        & "x 'reflog r3' cat .git/logs/refs/tags/r3" & LF
        & "GIT_REFLOG_ACTION='custom action' t 'create-reflog action' tag " & "--create-reflog r4" & LF
        & "x 'reflog r4' cat .git/logs/refs/tags/r4" & LF
        & "cat > ed.sh <<'X'" & LF
        & "#!/bin/sh" & LF
        & "cat ""$1"" > ""$(dirname ""$1"")/../captured.txt""" & LF
        & "printf 'edited tag msg\n# a comment\n\nbody\n\n\n' > ""$1""" & LF
        & "X" & LF
        & "chmod +x ed.sh" & LF
        & "tE 'editor -a' ./ed.sh tag -a ed1" & LF
        & "x 'captured' cat captured.txt" & LF
        & "x 'cat ed1' git cat-file tag ed1" & LF
        & "tE 'editor -e -m' ./ed.sh tag -e -m 'seed' ed2" & LF
        & "x 'captured2' cat captured.txt" & LF
        & "tE 'editor -f existing' ./ed.sh tag -f -a ed1" & LF
        & "x 'captured3' cat captured.txt" & LF
        & "tE 'editor verbatim' ./ed.sh tag -a --cleanup=verbatim ed3" & LF
        & "x 'captured4' cat captured.txt" & LF
        & "x 'cat ed3' git cat-file tag ed3" & LF
        & "tE 'editor trailer' ./ed.sh tag -a --trailer 'Acked-by: B' ed4" & LF
        & "x 'captured5' cat captured.txt" & LF
        & "tE 'editor empty' true tag -a ed5" & LF
        & "tE 'editor fails' false tag -a ed6" & LF
        & "tE 'editor -e no msg' true tag -e ed7" & LF
        & "git config tag.sort -refname" & LF
        & "t 'tag.sort' tag" & LF
        & "t 'tag.sort override' tag --sort=refname" & LF
        & "t 'no-sort' tag --no-sort" & LF
        & "git config --unset tag.sort" & LF
        & "git config column.tag always" & LF
        & "t 'column.tag' tag" & LF
        & "git config column.ui row" & LF
        & "t 'column.ui' tag" & LF
        & "t 'column.ui no-column' tag --no-column" & LF
        & "git config --unset column.ui; git config --unset column.tag" & LF
        & "git config advice.nestedTag false" & LF
        & "t 'nested quiet' tag -a -m 'n2' nested2 v1.0" & LF
        & "git config --unset advice.nestedTag" & LF
        & "t 'final list' tag -n1" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "tag");
   end Tag_Option_Surface_Matches_Git;

   --  `branch`: git's option surface -- the listing formats (plain, -v,
   --  -vv with upstream and worktree marks, -a/-r, patterns, -i, --sort,
   --  --format, --column, --color, the detached-HEAD line, the filters
   --  with their HEAD defaults), creation with tracking (--track modes,
   --  branch.autoSetupMerge/Rebase, --create-reflog, the reflog entries),
   --  --set-upstream-to/--unset-upstream, -m/-M/-c/-C with reflog and
   --  config carried along, -d/-D with git's merged checks and messages,
   --  --edit-description, --show-current, and git's refusals.
   procedure Branch_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "state() { :; }" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'a\n' > f; git add f; git commit -qm one" & LF
        & "printf 'b\n' >> f; git commit -qam two" & LF
        & "git checkout -q -b side HEAD~1; printf 'c\n' > g; git add g; git "
          & "commit -qm side-commit; git checkout -q main" & LF
        & "printf 'd\n' >> f; git commit -qam three" & LF
        & "git checkout -q -b feature; printf 'e\n' > h; git add h; git commit "
          & "-qm 'feature work'; git checkout -q main" & LF
        & "git clone -q . ../${NAME}_remote 2>/dev/null; git remote add origin "
          & "../${NAME}_remote; git fetch -q origin" & LF
        & "git branch -q --set-upstream-to=origin/main main 2>/dev/null" & LF
        & "x() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$@"" >> ""$TF"" 2>&1; echo "
          & """[rc=$?]"" >> ""$TF""; }" & LF
        & "tE() { l=$1; e=$2; shift 2; echo ""\$ $l"" >> ""$TF""; GIT_EDITOR=""$e"" "
          & """$TOOL"" ""$@"" >> ""$TF"" 2>&1 < /dev/null; echo ""[rc=$?]"" >> ""$TF""; }" & LF
        & "t 'list' branch" & LF
        & "t 'list -l' branch -l" & LF
        & "t 'list --list' branch --list" & LF
        & "t 'list -a' branch -a" & LF
        & "t 'list -r' branch -r" & LF
        & "t 'list -v' branch -v" & LF
        & "t 'list -vv' branch -vv" & LF
        & "t 'list -av' branch -av" & LF
        & "t 'list -avv' branch -avv" & LF
        & "t 'list -rv' branch -rv" & LF
        & "t 'list pattern' branch -l 'fe*'" & LF
        & "t 'list pattern nolist' branch 'fe*'" & LF
        & "t 'list -i' branch -i -l 'FE*'" & LF
        & "t 'list --abbrev' branch -v --abbrev=4" & LF
        & "t 'list --no-abbrev' branch -v --no-abbrev" & LF
        & "t 'contains' branch --contains HEAD~1" & LF
        & "t 'contains default' branch --contains" & LF
        & "t 'contains -a' branch -a --contains HEAD~2" & LF
        & "t 'no-contains' branch --no-contains side" & LF
        & "t 'merged' branch --merged" & LF
        & "t 'merged rev' branch --merged feature" & LF
        & "t 'no-merged' branch --no-merged" & LF
        & "t 'no-merged -a' branch -a --no-merged main" & LF
        & "t 'points-at' branch --points-at HEAD~1" & LF
        & "t 'points-at -a' branch -a --points-at HEAD" & LF
        & "t 'sort' branch --sort=-refname" & LF
        & "t 'sort committerdate' branch --sort=-committerdate" & LF
        & "t 'format' branch --format='%(refname:short) %(objectname:short) " & "%(upstream:short)'" & LF
        & "t 'format -a' branch -a --format='%(refname)'" & LF
        & "t 'column' branch --column" & LF
        & "t 'column -v' branch --column -v" & LF
        & "t 'omit-empty' branch " & "--format='%(if)%(upstream)%(then)%(refname:short)%(end)' --omit-empty" & LF
        & "t 'show-current' branch --show-current" & LF
        & "t 'create' branch new1" & LF
        & "t 'create start' branch new2 HEAD~1" & LF
        & "t 'create exists' branch new1" & LF
        & "t 'create -f' branch -f new1 HEAD~2" & LF
        & "t 'create bad name' branch 'bad..name'" & LF
        & "t 'create bad start' branch new3 nope" & LF
        & "t 'create -t' branch -t new4 origin/main" & LF
        & "t 'create --track=inherit' branch --track=inherit new5 main" & LF
        & "t 'create no-track' branch --no-track new6 origin/main" & LF
        & "t 'create auto track' branch new7 origin/main" & LF
        & "t 'create -a name' branch -a new8" & LF
        & "t 'create --create-reflog' branch --create-reflog new10" & LF
        & "x 'reflog new10' cat .git/logs/refs/heads/new10" & LF
        & "t 'create -q' branch -q new11 origin/main" & LF
        & "t 'set-upstream-to' branch --set-upstream-to=origin/main new1" & LF
        & "t 'set-upstream-to -u' branch -u origin/side new2" & LF
        & "t 'set-upstream-to current' branch -u origin/main" & LF
        & "t 'set-upstream-to local' branch -u side new2" & LF
        & "t 'set-upstream-to missing' branch -u origin/nope new2" & LF
        & "t 'set-upstream-to no branch' branch -u origin/main nosuch" & LF
        & "t 'set-upstream-to too many' branch -u origin/main a b" & LF
        & "t 'unset-upstream' branch --unset-upstream new1" & LF
        & "t 'unset-upstream none' branch --unset-upstream new1" & LF
        & "t 'unset-upstream current' branch --unset-upstream" & LF
        & "t 'unset-upstream no branch' branch --unset-upstream nosuch" & LF
        & "t 'list -vv after' branch -vv" & LF
        & "t 'rename' branch -m new2 renamed2" & LF
        & "t 'rename exists' branch -m renamed2 new1" & LF
        & "t 'rename -M' branch -M renamed2 new1" & LF
        & "t 'rename current' branch -m main2" & LF
        & "t 'list after rename' branch" & LF
        & "t 'rename back' branch -m main" & LF
        & "t 'rename missing' branch -m nope x" & LF
        & "t 'rename too many' branch -m a b c" & LF
        & "t 'rename bad' branch -m new1 'bad..name'" & LF
        & "t 'rename none' branch -m" & LF
        & "t 'copy' branch -c new1 copy1" & LF
        & "t 'copy exists' branch -c copy1 new1" & LF
        & "t 'copy -C' branch -C copy1 new1" & LF
        & "t 'copy current' branch -c copied-main" & LF
        & "t 'copy missing' branch -c nope x" & LF
        & "t 'list after copy' branch" & LF
        & "t 'delete' branch -d copy1" & LF
        & "t 'delete unmerged' branch -d feature" & LF
        & "t 'delete -D' branch -D feature" & LF
        & "t 'delete -d -f' branch -d -f new1" & LF
        & "t 'delete missing' branch -d nope" & LF
        & "t 'delete missing remote hint' branch -d main2 origin/side" & LF
        & "t 'delete -r' branch -d -r origin/side" & LF
        & "t 'delete -r missing' branch -r -d origin/nope" & LF
        & "t 'delete -a' branch -a -d x" & LF
        & "t 'delete current' branch -d main" & LF
        & "t 'delete none' branch -d" & LF
        & "t 'delete -q' branch -q -d new10" & LF
        & "t 'delete two' branch -D new4 new5" & LF
        & "t 'list after delete' branch -a" & LF
        & "t 'mode + create' branch --show-current x" & LF
        & "cat > ed.sh <<'X'" & LF
        & "#!/bin/sh" & LF
        & "cat ""$1"" > ""$(dirname ""$1"")/../captured.txt""" & LF
        & "printf 'my description\n# comment\n' > ""$1""" & LF
        & "X" & LF
        & "chmod +x ed.sh" & LF
        & "tE 'edit-description' ./ed.sh branch --edit-description" & LF
        & "x 'captured' cat captured.txt" & LF
        & "x 'config desc' git config branch.main.description" & LF
        & "tE 'edit-description named' ./ed.sh branch --edit-description side" & LF
        & "x 'captured2' cat captured.txt" & LF
        & "tE 'edit-description missing' ./ed.sh branch --edit-description nope" & LF
        & "tE 'edit-description empty' true branch --edit-description side" & LF
        & "x 'config desc2' git config --get branch.side.description" & LF
        & "tE 'edit-description two' ./ed.sh branch --edit-description a b" & LF
        & "git checkout -q --detach HEAD" & LF
        & "t 'detached list' branch" & LF
        & "t 'detached list -v' branch -v" & LF
        & "t 'detached list -a' branch -a" & LF
        & "t 'detached show-current' branch --show-current" & LF
        & "t 'detached rename' branch -m x" & LF
        & "t 'detached copy' branch -c x" & LF
        & "t 'detached set-upstream' branch -u origin/main" & LF
        & "t 'detached unset' branch --unset-upstream" & LF
        & "t 'detached edit-description' branch --edit-description" & LF
        & "t 'detached create' branch det1" & LF
        & "t 'detached sort' branch --sort=-refname" & LF
        & "git checkout -q main" & LF
        & "git config branch.sort -refname" & LF
        & "t 'branch.sort' branch" & LF
        & "git config --unset branch.sort" & LF
        & "git config column.branch always" & LF
        & "t 'column.branch' branch" & LF
        & "git config --unset column.branch" & LF
        & "git config color.branch always" & LF
        & "t 'color.branch' branch -v" & LF
        & "t 'color.branch -a' branch -a" & LF
        & "t 'color --no-color' branch --no-color" & LF
        & "git config --unset color.branch" & LF
        & "t 'color always' branch --color=always" & LF
        & "t 'color -vv always' branch --color -vv" & LF
        & "mkdir ""../${NAME}_2"" && cd ""../${NAME}_2""" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'a\n' > f; git add f; git commit -qm one" & LF
        & "printf 'b\n' >> f; git commit -qam two" & LF
        & "git checkout -q -b side HEAD~1; printf 'c\n' > g; git add g; git "
          & "commit -qm side-commit; git checkout -q main" & LF
        & "git clone -q . ../${NAME}_remote 2>/dev/null; git remote add origin "
          & "../${NAME}_remote; git fetch -q origin" & LF
        & "t 'create' branch b1" & LF
        & "x 'reflog b1' git reflog b1" & LF
        & "t 'create from commit' branch b2 HEAD~1" & LF
        & "x 'reflog b2' git reflog b2" & LF
        & "t 'create -f' branch -f b1 HEAD~1" & LF
        & "x 'reflog b1 after -f' git reflog b1" & LF
        & "t 'rename' branch -m b1 b1r" & LF
        & "x 'reflog b1r' git reflog b1r" & LF
        & "x 'log dir' ls .git/logs/refs/heads" & LF
        & "t 'copy' branch -c b1r b1c" & LF
        & "x 'reflog b1c' git reflog b1c" & LF
        & "t 'rename current' branch -m main mainx" & LF
        & "x 'reflog HEAD' git reflog -2 HEAD" & LF
        & "x 'reflog mainx' git reflog -2 mainx" & LF
        & "t 'rename back' branch -m mainx main" & LF
        & "t 'track non-branch' branch -t tb HEAD~1" & LF
        & "t 'track local' branch -t tb side" & LF
        & "t 'track local msg' branch -vv" & LF
        & "t 'set-upstream old' branch --set-upstream x" & LF
        & "git config branch.autoSetupMerge always" & LF
        & "t 'autosetup always' branch asa side" & LF
        & "git config branch.autoSetupMerge false" & LF
        & "t 'autosetup false' branch asf origin/main" & LF
        & "git config branch.autoSetupMerge simple" & LF
        & "t 'autosetup simple diff' branch simp origin/main" & LF
        & "t 'autosetup simple same' branch main2 origin/main" & LF
        & "git branch -D main2 >/dev/null 2>&1; git checkout -q -b main2 main "
          & ">/dev/null 2>&1; git checkout -q main; git branch -D main2 >/dev/null" & LF
        & "git config branch.autoSetupMerge inherit" & LF
        & "t 'autosetup inherit' branch inh tb" & LF
        & "t 'autosetup inherit none' branch inh2 b2" & LF
        & "git config --unset branch.autoSetupMerge" & LF
        & "git config branch.autoSetupRebase always" & LF
        & "t 'autosetup rebase' branch reb origin/main" & LF
        & "git config --unset branch.autoSetupRebase" & LF
        & "t 'list -vv all' branch -vv" & LF
        & "t 'create -q' branch -q q1 origin/main" & LF
        & "t 'gone' branch --set-upstream-to=origin/main b2" & LF
        & "git update-ref -d refs/remotes/origin/main" & LF
        & "t 'list gone' branch -vv" & LF
        & "t 'format gone' branch --format='%(refname:short) [%(upstream:track)] "
          & "[%(upstream:trackshort)]'" & LF
        & "git fetch -q origin" & LF
        & "t 'recurse' branch --recurse-submodules rs" & LF
        & "git config submodule.propagateBranches true" & LF
        & "t 'recurse2' branch --recurse-submodules --list" & LF
        & "git config --unset submodule.propagateBranches" & LF
        & "t 'merged -r' branch -r --merged main" & LF
        & "t 'no-merged -r' branch -r --no-merged side" & LF
        & "t 'pattern slash' branch -a -l 'origin/*'" & LF
        & "t 'pattern slash2' branch -r -l 'origin/m*'" & LF
        & "t 'sort -i' branch -i --sort=refname" & LF
        & "git worktree add -q ../${NAME}_wt side" & LF
        & "t 'worktree list' branch" & LF
        & "t 'worktree list -v' branch -v" & LF
        & "t 'worktree list -vv' branch -vv" & LF
        & "t 'delete wt' branch -D side" & LF
        & "t 'rename wt' branch -m side side2" & LF
        & "t 'create -f wt' branch -f side HEAD" & LF
        & "t 'unset-upstream other' branch --unset-upstream tb" & LF
        & "t 'unset-upstream again' branch --unset-upstream tb" & LF
        & "t 'delete with config' branch -D b2" & LF
        & "x 'config after delete' git config --get-regexp 'branch\.b2\..*'" & LF
        & "x 'log after delete' ls .git/logs/refs/heads" & LF
        & "t 'delete -r' branch -r -d origin/side" & LF
        & "t 'list -r after' branch -r" & LF
        & "t 'edit-description detached check' branch --edit-description nope" & LF
        & "t 'copy -c current' branch -c cur" & LF
        & "x 'reflog cur' git reflog cur" & LF
        & "t 'copy -C existing' branch -C cur b1c" & LF
        & "t 'move onto self' branch -M main main" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "branch");
   end Branch_Option_Surface_Matches_Git;

   --  `stash`: git's option surface -- push/save with -u/-a/-k/-S/-m,
   --  pathspecs and --pathspec-from-file, list through the log machinery,
   --  show with -u/--only-untracked and the diff options, apply/pop with
   --  --index, -q and the conflict-marker labels (including the merge onto
   --  a dirty tree, its narration and the status git prints afterwards),
   --  drop, branch, create, store and clear, with git's messages.
   procedure Stash_Option_Surface_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Scenario : constant String :=
          "state() { :; }" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'a\n1\n2\n3\n4\n5\n' > f; printf 'k\n' > keep; git add f keep; " & "git commit -qm one" & LF
        & "printf 'b\n1\n2\n3\n4\n5\n' > f; printf 'staged\n' > s; git add s" & LF
        & "printf 'u\n' > un.txt; printf 'ig\n' > ig.txt; printf 'ig.txt\n' > "
          & ".gitignore; git add .gitignore; git commit -qm two" & LF
        & "printf 'b2\n1\n2\n3\n4\n5\n' > f; printf 'staged2\n' > s; git add s; " & "printf 'w\n' >> s" & LF
        & "x() { l=$1; shift; echo ""\$ $l"" >> ""$TF""; ""$@"" >> ""$TF"" 2>&1; echo "
          & """[rc=$?]"" >> ""$TF""; }" & LF
        & "t 'push' stash push" & LF
        & "x 'status' git status --porcelain" & LF
        & "t 'list' stash list" & LF
        & "t 'list oneline' stash list --oneline" & LF
        & "t 'list -n1' stash list -n 1" & LF
        & "t 'list format' stash list --format='%gd %gs'" & LF
        & "t 'show' stash show" & LF
        & "t 'show -p' stash show -p" & LF
        & "t 'show --stat' stash show --stat" & LF
        & "t 'show --name-only' stash show --name-only" & LF
        & "t 'show bogus' stash show stash@{9}" & LF
        & "t 'apply' stash apply" & LF
        & "x 'status2' git status --porcelain" & LF
        & "t 'apply again' stash apply" & LF
        & "t 'drop' stash drop" & LF
        & "t 'list after drop' stash list" & LF
        & "t 'drop empty' stash drop" & LF
        & "t 'clear' stash clear" & LF
        & "t 'pop empty' stash pop" & LF
        & "t 'push nothing' stash push" & LF
        & "git checkout -q -- . 2>/dev/null; git reset -q" & LF
        & "printf 'c\n' >> f; printf 'stg\n' > s2; git add s2" & LF
        & "t 'push -k' stash push -k" & LF
        & "x 'status -k' git status --porcelain" & LF
        & "t 'pop' stash pop" & LF
        & "x 'status after pop' git status --porcelain" & LF
        & "t 'push --staged' stash push --staged" & LF
        & "x 'status staged' git status --porcelain" & LF
        & "t 'list2' stash list" & LF
        & "t 'pop --index' stash pop --index" & LF
        & "x 'status after pop index' git status --porcelain" & LF
        & "git reset -q --hard" & LF
        & "printf 'd\n' >> f; printf 'un2\n' > un2.txt" & LF
        & "t 'push -u' stash push -u" & LF
        & "x 'status -u' git status --porcelain" & LF
        & "t 'show -u' stash show -u" & LF
        & "t 'show --only-untracked' stash show --only-untracked" & LF
        & "t 'pop -q' stash pop -q" & LF
        & "x 'status after -q' git status --porcelain" & LF
        & "git reset -q --hard; /bin/rm -f un2.txt" & LF
        & "printf 'e\n' >> f" & LF
        & "t 'push -m msg' stash push -m 'my message'" & LF
        & "t 'list3' stash list" & LF
        & "t 'save legacy' stash save" & LF
        & "printf 'f\n' >> f" & LF
        & "t 'save msg' stash save my saved message" & LF
        & "t 'list4' stash list" & LF
        & "t 'apply idx' stash apply --index stash@{0}" & LF
        & "t 'drop q' stash drop -q" & LF
        & "t 'drop bad ref' stash drop HEAD" & LF
        & "t 'apply bad' stash apply nosuchthing" & LF
        & "t 'apply many' stash apply stash@{0} stash@{1}" & LF
        & "t 'clear2' stash clear" & LF
        & "git reset -q --hard" & LF
        & "printf 'g\n' >> f" & LF
        & "t 'create' stash create" & LF
        & "t 'create msg' stash create my create message" & LF
        & "x 'status after create' git status --porcelain" & LF
        & "t 'store' stash store -m stored $(git stash create)" & LF
        & "t 'list5' stash list" & LF
        & "t 'store bad' stash store -m x nosuch" & LF
        & "t 'store nothing' stash store" & LF
        & "t 'store many' stash store a b" & LF
        & "t 'clear3' stash clear" & LF
        & "git reset -q --hard" & LF
        & "printf 'h\n' >> f" & LF
        & "t 'push paths' stash push -- f" & LF
        & "t 'push paths nomatch' stash push -- nosuch" & LF
        & "t 'clear4' stash clear" & LF
        & "git reset -q --hard" & LF
        & "printf 'i\n' >> f" & LF
        & "t 'branch' stash branch newb" & LF
        & "x 'status branch' git status --porcelain" & LF
        & "t 'list6' stash list" & LF
        & "x 'branch name' git rev-parse --abbrev-ref HEAD" & LF
        & "git checkout -q main 2>/dev/null || git checkout -q master" & LF
        & "t 'branch no name' stash branch" & LF
        & "t 'push then branch' stash push" & LF
        & "t 'branch exists' stash branch main" & LF
        & "t 'unknown sub' stash frobnicate" & LF
        & "t 'push -p' stash push -p" & LF
        & "t 'push -u -p' stash push -p -u" & LF
        & "t 'push -S -u' stash push -S -u" & LF
        & "t 'pathspec-from-file' stash push --pathspec-from-file=- --staged" & LF
        & "t 'pathspec-file-nul' stash push --pathspec-file-nul" & LF
        & "mkdir ""../${NAME}_2"" && cd ""../${NAME}_2""" & LF
        & "git init -q; git config user.email a@b; git config user.name A" & LF
        & "printf 'base\n1\n2\n3\n4\n5\n6\n7\n8\n' > f; printf 'o\n' > other; git "
          & "add f other; git commit -qm one" & LF
        & "# conflicting apply" & LF
        & "printf 'stash\n1\n2\n3\n4\n5\n6\n7\n8\n' > f" & LF
        & "t 'push' stash push -m mine" & LF
        & "printf 'local\n1\n2\n3\n4\n5\n6\n7\n8\n' > f" & LF
        & "git commit -qam 'local change'" & LF
        & "t 'apply conflict' stash apply" & LF
        & "x 'file' cat f" & LF
        & "x 'status' git status --porcelain" & LF
        & "t 'list still' stash list" & LF
        & "git checkout -q --theirs f 2>/dev/null; git reset -q --hard" & LF
        & "t 'pop conflict' stash pop" & LF
        & "x 'file2' cat f" & LF
        & "t 'list after pop conflict' stash list" & LF
        & "git reset -q --hard" & LF
        & "t 'apply labels' stash apply --label-ours=OURS --label-theirs=THEIRS " & "--label-base=BASE" & LF
        & "x 'file3' cat f" & LF
        & "git reset -q --hard" & LF
        & "t 'apply q' stash apply -q" & LF
        & "x 'file3q' cat f" & LF
        & "git reset -q --hard" & LF
        & "t 'drop it' stash drop" & LF
        & "# index restoration" & LF
        & "printf 'staged\n' > st; git add st; printf 'work\n' >> other" & LF
        & "t 'push2' stash push" & LF
        & "t 'apply --index' stash apply --index" & LF
        & "x 'status idx' git status --porcelain" & LF
        & "git reset -q --hard; git clean -qfd" & LF
        & "t 'apply no index' stash apply" & LF
        & "x 'status noidx' git status --porcelain" & LF
        & "git reset -q --hard; git clean -qfd" & LF
        & "git config stash.index true" & LF
        & "t 'apply cfg index' stash apply" & LF
        & "x 'status cfgidx' git status --porcelain" & LF
        & "git config --unset stash.index" & LF
        & "git reset -q --hard; git clean -qfd" & LF
        & "t 'drop2' stash drop" & LF
        & "# untracked round trip" & LF
        & "printf 'unt\n' > u1.txt; mkdir -p d; printf 'unt2\n' > d/u2.txt; "
          & "printf 'ign\n' > i.txt; printf 'i.txt\n' > .gitignore; git add "
          & ".gitignore; git commit -qm ignore" & LF
        & "t 'push -u' stash push -u -m untracked" & LF
        & "x 'status after push -u' git status --porcelain" & LF
        & "x 'ls' ls" & LF
        & "t 'show -u' stash show -u" & LF
        & "t 'show only' stash show --only-untracked" & LF
        & "t 'show -u -p' stash show -u -p" & LF
        & "t 'pop untracked' stash pop" & LF
        & "x 'status after pop -u' git status --porcelain" & LF
        & "x 'cat u1' cat u1.txt" & LF
        & "x 'cat d/u2' cat d/u2.txt" & LF
        & "git clean -qfd" & LF
        & "printf 'x\n' >> other" & LF
        & "t 'push -a' stash push -a -m all" & LF
        & "x 'ls after -a' ls" & LF
        & "t 'pop -a' stash pop" & LF
        & "x 'ls after pop' ls" & LF
        & "git reset -q --hard; git clean -qfdx" & LF
        & "# keep-index" & LF
        & "printf 'k1\n' > k1; git add k1; printf 'w1\n' >> other" & LF
        & "t 'push -k' stash push -k -m keep" & LF
        & "x 'status -k' git status --porcelain" & LF
        & "x 'cat k1' cat k1" & LF
        & "t 'pop -k' stash pop" & LF
        & "x 'status after pop -k' git status --porcelain" & LF
        & "git reset -q --hard; git clean -qfdx" & LF
        & "# stash config for show" & LF
        & "printf 'cfg\n' >> other" & LF
        & "t 'push cfg' stash push" & LF
        & "git config stash.showStat false" & LF
        & "t 'show no stat' stash show" & LF
        & "git config stash.showPatch true" & LF
        & "t 'show patch cfg' stash show" & LF
        & "git config --unset stash.showStat; git config --unset stash.showPatch" & LF
        & "git config stash.showIncludeUntracked true" & LF
        & "t 'show u cfg' stash show" & LF
        & "git config --unset stash.showIncludeUntracked" & LF
        & "t 'show explicit' stash show --name-status" & LF
        & "t 'clear' stash clear" & LF
        & "git reset -q --hard" & LF
        & "# stash create/store round trip and stash-like commits" & LF
        & "printf 'cs\n' >> other" & LF
        & "x 'status create' git status --porcelain" & LF
        & "x 'apply commit' sh -c '""$0"" stash apply ""$(""$0"" stash create)""' " & """$TOOL""" & LF
        & "x 'show commit' sh -c '""$0"" stash show ""$(""$0"" stash create)""' ""$TOOL""" & LF
        & "x 'drop commit' sh -c '""$0"" stash drop ""$(""$0"" stash create)""' ""$TOOL""" & LF
        & "x 'branch commit' sh -c '""$0"" stash branch nb ""$(""$0"" stash create)""' " & """$TOOL""" & LF
        & "x 'branch after' git rev-parse --abbrev-ref HEAD" & LF
        & "x 'status after branch' git status --porcelain" & LF
        & "t 'list after branch' stash list" & LF
        & "git checkout -q main 2>/dev/null || git checkout -q master; git reset "
          & "-q --hard; git clean -qfdx" & LF
        & "# pathspec-from-file" & LF
        & "printf 'p1\n' >> other; printf 'p2\n' > p2; git add p2" & LF
        & "printf 'other\n' > specs.txt" & LF
        & "t 'pathspec file' stash push --pathspec-from-file=specs.txt" & LF
        & "x 'status pf' git status --porcelain" & LF
        & "t 'pop pf' stash pop" & LF
        & "git reset -q --hard; git clean -qfdx" & LF
        & "# store and quiet" & LF
        & "printf 'q\n' >> other" & LF
        & "x 'store quiet' sh -c '""$0"" stash store -q -m quiet ""$(""$0"" stash " & "create)""' ""$TOOL""" & LF
        & "t 'list store' stash list" & LF
        & "x 'store no msg' sh -c '""$0"" stash store ""$(""$0"" stash create)""' " & """$TOOL""" & LF
        & "t 'list store2' stash list" & LF
        & "t 'drop -q' stash drop -q" & LF
        & "t 'clear2' stash clear" & LF
        & "git reset -q --hard" & LF;
   begin
      Run_Parity_Transcript (Root, Scenario, "stash");
   end Stash_Option_Surface_Matches_Git;

   procedure Bisect_Run_And_Patch_Id_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q" & LF
           & "for i in 1 2 3 4 5 6 7; do" & LF
           & "  printf 'v%s\n' $i > f; git add f" & LF
           & "  GIT_COMMITTER_DATE=" & Q & "2026-01-0$i 00:00:00 +0000" & Q
           & " GIT_AUTHOR_DATE=" & Q & "2026-01-0$i 00:00:00 +0000" & Q
           & " git -c user.name=U -c user.email=u@u commit -q -m c$i" & LF
           & "done" & LF
           --  t.sh stays untracked: git checks out fine around it, and so
           --  must version (it used to refuse any untracked file).
           & "printf '#!/bin/sh\ngrep -q " & Q & "v[1-4]$" & Q
           & " f && exit 0 || exit 1\n' > t.sh; chmod +x t.sh" & LF
           & "set +e" & LF
           & "echo '== bisect run:' >> " & Q & "$TF" & Q & LF
           & Tool & " bisect start HEAD HEAD~6 > /dev/null 2>&1" & LF
           & Tool & " bisect run ./t.sh >> " & Q & "$TF" & Q & " 2>&1" & LF
           & Tool & " bisect reset > /dev/null 2>&1" & LF
           & "echo '== patch-id:' >> " & Q & "$TF" & Q & LF
           & "git log -p | " & Tool & " patch-id >> " & Q & "$TF" & Q
           & " 2>&1" & LF
           & "echo '== patch-id --stable:' >> " & Q & "$TF" & Q & LF
           & "git log -p | " & Tool & " patch-id --stable >> " & Q & "$TF" & Q
           & " 2>&1" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "bg"), "git",
                Version.Test_Support.Join (Base, "bg.sh"),
                Version.Test_Support.Join (Base, "bg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "bv"), CLI,
                Version.Test_Support.Join (Base, "bv.sh"),
                Version.Test_Support.Join (Base, "bv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "bg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "bv.T"));
      begin
         Assert (G = V,
                 "bisect run and patch-id must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Bisect_Run_And_Patch_Id_Match_Git;

   --  `subtree add` grafts a foreign history in as a merge; `subtree split`
   --  lifts the prefix back out as a standalone lineage, reusing the foreign
   --  commits and copying the rest with their identities intact.  Both the
   --  resulting commit ids and the printed output must be git's.
   procedure Subtree_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "export GIT_AUTHOR_DATE='1000000000 +0000'" & LF
           & "export GIT_COMMITTER_DATE='1000000000 +0000'" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q lib && cd lib" & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "echo one > f.txt; git add -A; git commit -q -m 'lib c1'" & LF
           & "echo two > f.txt; git commit -q -a -m 'lib c2'" & LF
           & "cd .. && git init -q main && cd main" & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "echo app > app.txt; git add -A; git commit -q -m 'app c1'" & LF
           & "set +e" & LF
           & "echo '== add:' >> " & Q & "$TF" & Q & LF
           --  The fetch chatter belongs to `fetch`, not to `subtree`.
           & Tool & " subtree add --prefix=v/lib ../lib main 2>&1 "
           & "| grep -v -e '^From ' -e 'FETCH_HEAD' >> " & Q & "$TF" & Q & LF
           & "echo three > v/lib/f.txt; git commit -q -a -m 'local edit'" & LF
           & "echo app2 > app.txt; git commit -q -a -m 'app c2'" & LF
           & "echo '== split:' >> " & Q & "$TF" & Q & LF
           --  git's split writes a CR-updated progress counter to stderr;
           --  only the "Created branch" line it ends with is output.
           & Tool & " subtree split --prefix=v/lib -b out > sha.txt 2> err.txt"
           & LF
           & "cat sha.txt >> " & Q & "$TF" & Q & LF
           & "grep -o " & Q & "Created branch 'out'" & Q & " err.txt >> "
           & Q & "$TF" & Q & LF
           & "echo '== split history:' >> " & Q & "$TF" & Q & LF
           & "git log --format='%H %T %P %an %ae %ad %cn %ce %cd %s' out >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== main history:' >> " & Q & "$TF" & Q & LF
           & "git log --format='%H %T %P %s%n%b' >> " & Q & "$TF" & Q
           & " 2>&1" & LF
           & "echo '== second split is idempotent:' >> " & Q & "$TF" & Q & LF
           & Tool & " subtree split --prefix=v/lib 2> /dev/null >> "
           & Q & "$TF" & Q & LF
           & "echo '== refs:' >> " & Q & "$TF" & Q & LF
           & "git show-ref >> " & Q & "$TF" & Q & " 2>&1" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "sg"), "git",
                Version.Test_Support.Join (Base, "sg.sh"),
                Version.Test_Support.Join (Base, "sg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "sv"), CLI,
                Version.Test_Support.Join (Base, "sv.sh"),
                Version.Test_Support.Join (Base, "sv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "sg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "sv.T"));
      begin
         Assert (G = V,
                 "subtree add/split must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Subtree_Matches_Git;

   --  `ls-remote`, `check-attr` (macros, negation, precedence, `-a` ordering),
   --  `check-mailmap` and `for-each-repo`.
   procedure Plumbing_Queries_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "export GIT_AUTHOR_DATE='1000000000 +0000'" & LF
           & "export GIT_COMMITTER_DATE='1000000000 +0000'" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q up && cd up" & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "printf a > a; git add -A; git commit -q -m a" & LF
           & "git tag -a v1 -m t1; git tag light; git branch dev" & LF
           & "cd .. && git init -q w && cd w" & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "mkdir -p sub" & LF
           & "printf 'x\n' > f.txt; printf 'y\n' > sub/g.txt" & LF
           & "printf 'z\n' > sub/h.bin" & LF
           & "printf '*.txt text -diff foo=bar\n*.bin binary\n"
           & "[attr]mymacro text merge=custom\n' > .gitattributes" & LF
           & "printf 'sub/*.txt eol=lf other\nh.bin mymacro !diff\n'"
           & " > sub/.gitattributes" & LF
           & "printf 'Real Name <real@x> <old@x>\nOnly <only@x>\n"
           & "Named <n@x> Old Named <on@x>\n' > .mailmap" & LF
           & "git add -A; git commit -q -m w" & LF
           & "set +e" & LF
           & "echo '== ls-remote:' >> " & Q & "$TF" & Q & LF
           & Tool & " ls-remote ../up >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== ls-remote --heads/--tags:' >> " & Q & "$TF" & Q & LF
           & Tool & " ls-remote --heads ../up >> " & Q & "$TF" & Q & " 2>&1"
           & LF
           & Tool & " ls-remote --tags ../up >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== check-attr:' >> " & Q & "$TF" & Q & LF
           & Tool & " check-attr text diff foo -- f.txt sub/g.txt sub/h.bin "
           & "nofile.txt >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== check-attr -a:' >> " & Q & "$TF" & Q & LF
           & Tool & " check-attr -a f.txt sub/h.bin sub/g.txt >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== check-mailmap:' >> " & Q & "$TF" & Q & LF
           & Tool & " check-mailmap 'Old <old@x>' 'Whoever <only@x>' "
           & "'Old Named <on@x>' 'Other <on@x>' 'Nobody <nb@x>' >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== for-each-repo:' >> " & Q & "$TF" & Q & LF
           & "git config --add my.repos " & Q & "$PWD" & Q & LF
           & Tool & " for-each-repo --config=my.repos rev-parse "
           & "--abbrev-ref HEAD >> " & Q & "$TF" & Q & " 2>&1" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "pg"), "git",
                Version.Test_Support.Join (Base, "pg.sh"),
                Version.Test_Support.Join (Base, "pg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "pv"), CLI,
                Version.Test_Support.Join (Base, "pv.sh"),
                Version.Test_Support.Join (Base, "pv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "pg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "pv.T"));
      begin
         Assert (G = V,
                 "ls-remote/check-attr/check-mailmap/for-each-repo must match "
                 & "git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Plumbing_Queries_Match_Git;

   --  `merge-tree --write-tree`: the merged tree (conflicted paths carrying the
   --  marked-up blob), the stage 1/2/3 entries, the messages, and the exit
   --  code -- plus `show-index`, `unpack-file` and `prune-packed`.
   procedure Merge_Tree_And_Pack_Plumbing_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "export GIT_AUTHOR_DATE='1000000000 +0000'" & LF
           & "export GIT_COMMITTER_DATE='1000000000 +0000'" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q ." & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "printf 'a\nb\nc\nd\ne\nf\ng\n' > f; printf 'x\n' > g" & LF
           & "git add -A; git commit -q -m base" & LF
           & "git checkout -q -b feat" & LF
           & "printf 'A\nb\nc\nd\ne\nf\ng\n' > f; printf 'n\n' > h" & LF
           & "git add -A; git commit -q -m feat" & LF
           & "git checkout -q main" & LF
           & "printf 'a\nb\nc\nd\ne\nf\nG\n' > f" & LF
           & "git commit -q -a -m main" & LF
           & "set +e" & LF
           & "echo '== clean:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-tree --write-tree feat main >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "git checkout -q -b conf main" & LF
           & "printf 'ZZZ\nb\nc\nd\ne\nf\ng\n' > f" & LF
           & "git commit -q -a -m conf" & LF
           & "echo '== conflict:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-tree --write-tree feat conf >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "echo '== conflicted blob:' >> " & Q & "$TF" & Q & LF
           & "TREE=$(" & Tool & " merge-tree --write-tree feat conf | head -1)"
           & LF
           & "git cat-file -p $TREE:f >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== name-only:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-tree --write-tree --name-only feat conf >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "git gc -q 2>/dev/null" & LF
           & "echo '== show-index:' >> " & Q & "$TF" & Q & LF
           & Tool & " show-index < $(ls .git/objects/pack/*.idx | head -1) >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== unpack-file:' >> " & Q & "$TF" & Q & LF
           & "N=$(" & Tool & " unpack-file $(git rev-parse HEAD:f))" & LF
           & "cat " & Q & "$N" & Q & " >> " & Q & "$TF" & Q & "; rm -f "
           & Q & "$N" & Q & LF
           & "printf 'loose\n' | git hash-object -w --stdin > /dev/null" & LF
           & "echo '== prune-packed:' >> " & Q & "$TF" & Q & LF
           & "find .git/objects -type f -not -path '*pack*' | wc -l >> "
           & Q & "$TF" & Q & LF
           & Tool & " prune-packed" & LF
           & "find .git/objects -type f -not -path '*pack*' | wc -l >> "
           & Q & "$TF" & Q & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "tg"), "git",
                Version.Test_Support.Join (Base, "tg.sh"),
                Version.Test_Support.Join (Base, "tg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "tv"), CLI,
                Version.Test_Support.Join (Base, "tv.sh"),
                Version.Test_Support.Join (Base, "tv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "tg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "tv.T"));
      begin
         Assert (G = V,
                 "merge-tree and the pack plumbing must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Tree_And_Pack_Plumbing_Match_Git;

   --  The merge plumbing: `merge-index` driving `merge-one-file` (clean and
   --  conflicted), and the strategy backends.  The conflict-marker labels are
   --  the temporary files' names, which git randomizes, so they are folded
   --  away before comparing.
   procedure Merge_Plumbing_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      procedure Run_Flow
        (Dir, Tool, One_File, Script_Path, Out_Path : String)
      is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "export GIT_AUTHOR_DATE='1000000000 +0000'" & LF
           & "export GIT_COMMITTER_DATE='1000000000 +0000'" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q ." & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "printf 'a\nb\nc\nd\ne\n' > f; printf 'k\n' > k" & LF
           & "git add -A; git commit -q -m base" & LF
           & "git checkout -q -b feat" & LF
           & "printf 'A\nb\nc\nd\ne\n' > f; printf 'n\n' > n" & LF
           & "git add -A; git commit -q -m feat" & LF
           & "git checkout -q main" & LF
           & "printf 'a\nb\nc\nd\nE\n' > f; git rm -q k" & LF
           & "git commit -q -a -m main" & LF
           & "set +e" & LF
           & "B=$(git merge-base main feat)" & LF
           --  merge-index + merge-one-file over a git-staged 3-way index.
           & "git read-tree -m $B HEAD feat" & LF
           & "echo '== merge-index clean:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-index " & One_File & " -a >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "git ls-files -s >> " & Q & "$TF" & Q & LF
           & "cat f >> " & Q & "$TF" & Q & LF
           & "ls >> " & Q & "$TF" & Q & LF
           & "git reset -q --hard; git clean -qfd" & LF
           --  A real content conflict.
           & "git checkout -q -b c1 main" & LF
           & "printf 'a\nXXX\nc\nd\ne\n' > f; git commit -q -a -m c1" & LF
           & "git checkout -q -b c2 feat" & LF
           & "printf 'a\nYYY\nc\nd\ne\n' > f; git commit -q -a -m c2" & LF
           & "git checkout -q c1; B2=$(git merge-base c1 c2)" & LF
           & "git read-tree -m $B2 c1 c2" & LF
           & "echo '== merge-index conflict:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-index " & One_File & " -a >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "sed -E 's/\.merge_file_[A-Za-z0-9]+/LABEL/' f >> "
           & Q & "$TF" & Q & LF
           & "git ls-files -s f >> " & Q & "$TF" & Q & LF
           & "git reset -q --hard; git clean -qfd" & LF
           --  The strategy backends.
           & "echo '== merge-ours:' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-ours $B2 -- HEAD c2 >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "echo '== merge-recursive (conflict):' >> " & Q & "$TF" & Q & LF
           & Tool & " merge-recursive $B2 -- HEAD c2 >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "git ls-files -s f >> " & Q & "$TF" & Q & LF
           & "git reset -q --hard; git clean -qfd" & LF
           & "echo '== merge-resolve (clean):' >> " & Q & "$TF" & Q & LF
           & "git checkout -q main" & LF
           & Tool & " merge-resolve $B -- HEAD feat >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "cat f >> " & Q & "$TF" & Q & LF
           & "git reset -q --hard; git clean -qfd" & LF
           & "echo '== merge-octopus (one remote is not an octopus):' >> "
           & Q & "$TF" & Q & LF
           & Tool & " merge-octopus $B -- HEAD feat >> " & Q & "$TF" & Q
           & " 2>&1; echo " & Q & "(exit $?)" & Q & " >> " & Q & "$TF" & Q & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "mg"), "git",
                "git-merge-one-file",
                Version.Test_Support.Join (Base, "mg.sh"),
                Version.Test_Support.Join (Base, "mg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "mv"), CLI,
                "version-merge-one-file",
                Version.Test_Support.Join (Base, "mv.sh"),
                Version.Test_Support.Join (Base, "mv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "mg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "mv.T"));
      begin
         Assert (G = V,
                 "the merge plumbing must match git." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Plumbing_Matches_Git;

   --  `commit-graph write` (byte-identical, including the EDGE chunk an
   --  octopus merge needs), `filter-branch` over its four filters, and a
   --  `fast-export`/`fast-import` round-trip through git.
   procedure History_Tools_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true FILTER_BRANCH_SQUELCH_WARNING=1";

      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Script : constant String :=
           "set -e" & LF
           & "export " & GEnv & LF
           & "export GIT_AUTHOR_DATE='1000000000 +0000'" & LF
           & "export GIT_COMMITTER_DATE='1000000000 +0000'" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "rm -rf " & Q & Dir & Q & "; mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "git init -q ." & LF
           & "git config user.name U; git config user.email u@u" & LF
           & "printf 'base\n' > f; printf 's\n' > secret.txt" & LF
           & "git add -A; git commit -q -m base" & LF
           --  Three branches and an octopus merge: the EDGE chunk.
           & "for b in x y z; do" & LF
           & "  git checkout -q -b $b main" & LF
           & "  echo $b > $b.txt; git add -A; git commit -q -m $b" & LF
           & "done" & LF
           & "git checkout -q main" & LF
           & "printf 'main2\n' > m.txt; git add -A; git commit -q -m main2"
           & LF
           & "git merge -q --no-ff -m octopus x y z > /dev/null 2>&1" & LF
           & "set +e" & LF
           & "echo '== commit-graph:' >> " & Q & "$TF" & Q & LF
           & Tool & " commit-graph write --reachable >> " & Q & "$TF" & Q
           & " 2>&1" & LF
           --  The file itself is what must match; hash it.
           & "sha1sum < .git/objects/info/commit-graph >> " & Q & "$TF" & Q & LF
           & "git commit-graph verify >> " & Q & "$TF" & Q & " 2>&1; echo "
           & Q & "(verify $?)" & Q & " >> " & Q & "$TF" & Q & LF
           & "echo '== fast-export round-trip through git:' >> "
           & Q & "$TF" & Q & LF
           & Tool & " fast-export --all > stream" & LF
           & "mkdir rt && (cd rt && git init -q . && "
           & "git fast-import --quiet < ../stream)" & LF
           & "(cd rt && git log --all --format='%H %T %P %s' | sort) >> "
           & Q & "$TF" & Q & " 2>&1" & LF
           & "echo '== filter-branch --index-filter:' >> " & Q & "$TF" & Q & LF
           & Tool & " filter-branch -f --index-filter "
           & Q & "git rm -q --cached --ignore-unmatch secret.txt" & Q
           --  git's progress counter is one CR-updated physical line.
           & " HEAD 2>&1 | grep -v Rewrite >> " & Q & "$TF" & Q & LF
           & "git log --format='%H %T %s' >> " & Q & "$TF" & Q & LF
           & "git ls-tree -r HEAD --name-only >> " & Q & "$TF" & Q & LF
           & "git show-ref | grep original >> " & Q & "$TF" & Q & LF
           & "echo '== filter-branch --msg-filter:' >> " & Q & "$TF" & Q & LF
           & Tool & " filter-branch -f --msg-filter 'sed s/base/BASE/' HEAD"
           & " 2>&1 | grep -v Rewrite >> " & Q & "$TF" & Q & LF
           & "git log --format='%s' >> " & Q & "$TF" & Q & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "hg"), "git",
                Version.Test_Support.Join (Base, "hg.sh"),
                Version.Test_Support.Join (Base, "hg.T"));
      Run_Flow (Version.Test_Support.Join (Base, "hv"), CLI,
                Version.Test_Support.Join (Base, "hv.sh"),
                Version.Test_Support.Join (Base, "hv.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "hg.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "hv.T"));
      begin
         Assert (G = V,
                 "commit-graph, fast-export and filter-branch must match git."
                 & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end History_Tools_Match_Git;

   procedure Merge_File_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Q : constant Character := '"';

      --  Runs an identical set of merge-file invocations (with -p, so output
      --  goes to stdout) through TOOL over several base/ours/theirs fixtures
      --  and records stdout+rc per case.
      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Steps : constant String :=
           "-p o1 b1 t1;"                     --  clean, non-overlapping
           & "-p o2 b2 t2;"                   --  simple conflict
           & "-p -L mine -L orig -L yours o2 b2 t2;"
           & "-p --diff3 o2 b2 t2;"
           & "-p --ours o2 b2 t2;-p --theirs o2 b2 t2;-p --union o2 b2 t2;"
           & "-p --marker-size=5 o2 b2 t2;"
           & "-p o3 b3 t3";                   --  two conflicts combined (gap 3)
         Script : constant String :=
           "set -e" & LF
           & "mkdir -p " & Q & Dir & Q & LF & "cd " & Q & Dir & Q & LF
           --  fixture 1: clean (ours changes l2, theirs changes l4)
           & "printf 'l1\nl2\nl3\nl4\nl5\n' > b1" & LF
           & "printf 'l1\nO2\nl3\nl4\nl5\n' > o1" & LF
           & "printf 'l1\nl2\nl3\nT4\nl5\n' > t1" & LF
           --  fixture 2: conflict (both change l2)
           & "printf 'l1\nl2\nl3\nl4\nl5\n' > b2" & LF
           & "printf 'l1\nO2\nl3\nl4\nl5\n' > o2" & LF
           & "printf 'l1\nT2\nl3\nl4\nl5\n' > t2" & LF
           --  fixture 3: both change l1 and l5 (3 common between) -> combined
           & "printf 'A\nc1\nc2\nc3\nZ\n' > b3" & LF
           & "printf 'OA\nc1\nc2\nc3\nOZ\n' > o3" & LF
           & "printf 'TA\nc1\nc2\nc3\nTZ\n' > t3" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "set +e" & LF
           & "S='" & Steps & "'" & LF
           & "OLDIFS=" & Q & "$IFS" & Q & LF & "IFS=';'" & LF
           & "set -- $S" & LF & "IFS=" & Q & "$OLDIFS" & Q & LF
           & "for c in " & Q & "$@" & Q & "; do" & LF
           & "  echo " & Q & "\$ merge-file $c" & Q & " >> " & Q & "$TF" & Q & LF
           & "  " & Tool & " merge-file $c >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "  echo " & Q & "[rc=$?]" & Q & " >> " & Q & "$TF" & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "g"), "git",
                Version.Test_Support.Join (Base, "g.sh"),
                Version.Test_Support.Join (Base, "g.T"));
      Run_Flow (Version.Test_Support.Join (Base, "v"), CLI,
                Version.Test_Support.Join (Base, "v.sh"),
                Version.Test_Support.Join (Base, "v.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "g.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "v.T"));
      begin
         Assert (G = V,
                 "merge-file must match git byte-for-byte." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_File_Matches_Git;

   procedure Merge_Output_Matches_Git_Stat
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      procedure Assert_In (Hay, Needle, Ctx : String) is
      begin
         Assert (Ada.Strings.Fixed.Index (Hay, Needle) /= 0,
                 Ctx & " (missing """ & Needle & """)");
      end Assert_In;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Version.Git_Fixtures.Run (Root, "printf 'a\n' > f.txt");
      Version.Git_Fixtures.Run (Root, "git add f.txt && git commit -q -m c1");
      Version.Git_Fixtures.Run (Root, "git checkout -q -b feat");
      Version.Git_Fixtures.Run (Root, "printf 'x\n' > g.txt");
      Version.Git_Fixtures.Run (Root, "git add g.txt && git commit -q -m c2");
      Version.Git_Fixtures.Run (Root, "git checkout -q -");

      --  Fast-forward: Updating <o>..<n> / Fast-forward / stat / create mode.
      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C " & CLI & " merge feat > " & Root & ".ff 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Root & ".ff");
      begin
         Assert_In (Out_Text, "Updating ", "ff updating line");
         Assert_In (Out_Text, "Fast-forward", "ff headline");
         Assert_In (Out_Text, " g.txt | 1 +", "ff stat line");
         Assert_In (Out_Text, " 1 file changed, 1 insertion(+)", "ff footer");
         Assert_In (Out_Text, " create mode 100644 g.txt", "ff summary");
      end;

      --  Diverge, then a real merge commit: "Merge made by ..." + stat.
      Version.Git_Fixtures.Run (Root, "git checkout -q -b other HEAD~1");
      Version.Git_Fixtures.Run (Root, "printf 'y\n' > h.txt");
      Version.Git_Fixtures.Run (Root, "git add h.txt && git commit -q -m c3");
      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C " & CLI & " merge -m m feat > " & Root & ".mc 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Root & ".mc");
      begin
         Assert_In (Out_Text, "Merge made by the 'ort' strategy.", "mc headline");
         Assert_In (Out_Text, " g.txt | 1 +", "mc stat line");
         Assert_In (Out_Text, " 1 file changed, 1 insertion(+)", "mc footer");
         Assert_In (Out_Text, " create mode 100644 g.txt", "mc summary");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Output_Matches_Git_Stat;

   procedure Bisect_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      --  Deterministic git: C locale, no user/global config, default branch
      --  main, non-interactive editor.
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";

      --  Build a linear repo of 7 commits with fixed, increasing dates so the
      --  bisection commit selection is unambiguous, then run an identical
      --  bisect sequence with TOOL, capturing stdout+stderr+rc per step into
      --  <Dir>/T. The script is written to a file to avoid nested-quote hell.
      Q : constant Character := '"';
      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Steps : constant String :=
           "bisect start;bisect bad;bisect good HEAD~6;bisect good;"
           & "bisect bad;bisect bad;bisect log;bisect terms;bisect reset;"
           & "bisect start --term-old old --term-new new HEAD HEAD~6;"
           & "bisect terms;bisect log;bisect reset";
         Script : constant String :=
           "set -e" & LF
           & "mkdir -p " & Q & Dir & Q & LF
           & "cd " & Q & Dir & Q & LF
           & "export " & GEnv & LF
           & "git init -q" & LF
           & "t=1000000000" & LF
           & "for i in $(seq 1 7); do" & LF
           & "  echo l$i >> f; git add f" & LF
           & "  GIT_AUTHOR_DATE=" & Q & "$t +0000" & Q
           & " GIT_COMMITTER_DATE=" & Q & "$t +0000" & Q
           & " git -c user.name=T -c user.email=t@t commit -q -m "
           & Q & "commit $i" & Q & LF
           & "  t=$((t+60))" & LF
           & "done" & LF
           --  Capture outside the working tree so the transcript file does
           --  not itself become an untracked entry blocking bisect checkouts.
           & "TF=" & Q & Out_Path & Q & LF
           & ": > " & Q & "$TF" & Q & LF
           & "set +e" & LF
           & "S='" & Steps & "'" & LF
           & "OLDIFS=" & Q & "$IFS" & Q & LF
           & "IFS=';'" & LF
           & "set -- $S" & LF
           & "IFS=" & Q & "$OLDIFS" & Q & LF
           & "for c in " & Q & "$@" & Q & "; do" & LF
           & "  echo " & Q & "\$ $c" & Q & " >> " & Q & "$TF" & Q & LF
           & "  " & Tool & " $c >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "  echo " & Q & "[rc=$?]" & Q & " >> " & Q & "$TF" & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "g"), "git",
                Version.Test_Support.Join (Base, "g.sh"),
                Version.Test_Support.Join (Base, "g.T"));
      Run_Flow (Version.Test_Support.Join (Base, "v"), CLI,
                Version.Test_Support.Join (Base, "v.sh"),
                Version.Test_Support.Join (Base, "v.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "g.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "v.T"));
      begin
         Assert (G = V,
                 "bisect transcript must match git byte-for-byte." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Bisect_Matches_Git;

   procedure Show_Branch_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      GEnv : constant String :=
        "LC_ALL=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "
        & "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=init.defaultBranch "
        & "GIT_CONFIG_VALUE_0=main EDITOR=true";
      Q : constant Character := '"';

      --  Three branches diverging from a common base (no merges in range),
      --  fixed dates so the matrix ordering and naming are unambiguous.
      procedure Run_Flow (Dir, Tool, Script_Path, Out_Path : String) is
         Steps : constant String :=
           "show-branch main feature topic;show-branch topic feature main;"
           & "show-branch feature main;show-branch main;show-branch;"
           & "show-branch --list;show-branch --list main feature";
         Script : constant String :=
           "set -e" & LF
           & "mkdir -p " & Q & Dir & Q & LF & "cd " & Q & Dir & Q & LF
           & "export " & GEnv & LF
           & "git init -q" & LF
           & "t=1000000000" & LF
           & "commit() { echo $1 >> f; git add f; "
           & "GIT_AUTHOR_DATE=" & Q & "$t +0000" & Q
           & " GIT_COMMITTER_DATE=" & Q & "$t +0000" & Q
           & " git -c user.name=T -c user.email=t@t commit -q -m " & Q & "$1"
           & Q & "; t=$((t+60)); }" & LF
           & "commit b1; commit b2" & LF
           & "git branch feature; git branch topic" & LF
           & "commit m3" & LF
           & "git checkout -q feature; commit f3; commit f4; commit f5" & LF
           & "git checkout -q topic; commit t3" & LF
           & "git checkout -q main" & LF
           & "TF=" & Q & Out_Path & Q & LF & ": > " & Q & "$TF" & Q & LF
           & "S='" & Steps & "'" & LF
           & "OLDIFS=" & Q & "$IFS" & Q & LF & "IFS=';'" & LF
           & "set -- $S" & LF & "IFS=" & Q & "$OLDIFS" & Q & LF
           & "for c in " & Q & "$@" & Q & "; do" & LF
           & "  echo " & Q & "\$ $c" & Q & " >> " & Q & "$TF" & Q & LF
           & "  " & Tool & " $c >> " & Q & "$TF" & Q & " 2>&1" & LF
           & "  echo " & Q & "[rc=$?]" & Q & " >> " & Q & "$TF" & Q & LF
           & "done" & LF;
      begin
         Version.Test_Support.Write_Text_File (Script_Path, Script);
         Version.Git_Fixtures.Run (Base, "bash " & Q & Script_Path & Q);
      end Run_Flow;
   begin
      Run_Flow (Version.Test_Support.Join (Base, "g"), "git",
                Version.Test_Support.Join (Base, "g.sh"),
                Version.Test_Support.Join (Base, "g.T"));
      Run_Flow (Version.Test_Support.Join (Base, "v"), CLI,
                Version.Test_Support.Join (Base, "v.sh"),
                Version.Test_Support.Join (Base, "v.T"));
      declare
         G : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "g.T"));
         V : constant String :=
           Read_Raw_Bytes (Version.Test_Support.Join (Base, "v.T"));
      begin
         Assert (G = V,
                 "show-branch must match git byte-for-byte." & LF
                 & "--- git ---" & LF & G & LF & "--- version ---" & LF & V);
      end;
      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Show_Branch_Matches_Git;

   procedure Fetch_Summary_Matches_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Up      : constant String := Version.Test_Support.Join (Base, "up.git");
      Work    : constant String := Version.Test_Support.Join (Base, "work");
      Clone   : constant String := Version.Test_Support.Join (Base, "clone");

      procedure Assert_In (Hay, Needle, Ctx : String) is
      begin
         Assert (Ada.Strings.Fixed.Index (Hay, Needle) /= 0,
                 Ctx & " (missing """ & Needle & """)");
      end Assert_In;
   begin
      --  Create the bare upstream with an explicit default branch so the test
      --  is hermetic (does not depend on the ambient init.defaultBranch) and
      --  the pushed `main` matches the remote HEAD.
      Version.Git_Fixtures.Run (Old_Dir, "git init -q --bare -b main " & Up);
      Version.Init.Init (Work);
      Configure_User (Work);
      Version.Git_Fixtures.Run (Work, "printf 'a\n' > f.txt");
      Version.Git_Fixtures.Run (Work, "git add f.txt && git commit -q -m c1");
      Version.Git_Fixtures.Run (Work, "git branch -M main");
      Version.Git_Fixtures.Run (Work, "git remote add origin " & Up);
      Version.Git_Fixtures.Run (Work, "git push -q -u origin main");

      Version.Git_Fixtures.Run (Old_Dir, CLI & " clone " & Up & " " & Clone);
      --  Advance upstream so the clone has one branch update to report.
      Version.Git_Fixtures.Run (Work, "printf 'x\n' > g.txt");
      Version.Git_Fixtures.Run (Work, "git add g.txt && git commit -q -m c2");
      Version.Git_Fixtures.Run (Work, "git push -q origin main");

      Version.Git_Fixtures.Run
        (Clone,
         "LC_ALL=C " & CLI & " fetch origin > " & Base & ".fs 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Base & ".fs");
      begin
         Assert_In (Out_Text, "From ", "fetch From line");
         Assert_In (Out_Text, "  main       -> origin/main", "fetch update line");
      end;

      --  Clone records refs/remotes/origin/HEAD (git parity, drives ordering).
      Assert
        (Ada.Strings.Fixed.Index
           (Read_Raw_Bytes
              (Version.Test_Support.Join
                 (Clone, ".git/refs/remotes/origin/HEAD")),
            "ref: refs/remotes/origin/main") /= 0,
         "clone writes origin/HEAD symref");

      --  A trailing-slash for-each-ref pattern lists refs (not an error), even
      --  with the origin/HEAD symref present.
      Version.Git_Fixtures.Run
        (Clone,
         CLI & " for-each-ref --format='%(refname)' refs/remotes/ > "
         & Base & ".fe 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Base & ".fe");
      begin
         Assert_In (Out_Text, "refs/remotes/origin/main", "for-each-ref match");
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "error:") = 0,
            "for-each-ref trailing-slash pattern must not error");
      end;

      --  Explicit `pull <remote> <branch>` reports git's FETCH_HEAD form.
      Version.Git_Fixtures.Run
        (Clone,
         "LC_ALL=C " & CLI & " pull origin main > " & Base & ".ph 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Base & ".ph");
      begin
         Assert_In (Out_Text, " * branch", "pull explicit FETCH_HEAD kind");
         Assert_In (Out_Text, "-> FETCH_HEAD", "pull explicit FETCH_HEAD target");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Fetch_Summary_Matches_Git;

   procedure Merge_Conflict_Diagnostics_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";

      procedure Assert_In (Hay, Needle, Ctx : String) is
      begin
         Assert (Ada.Strings.Fixed.Index (Hay, Needle) /= 0,
                 Ctx & " (missing """ & Needle & """)");
      end Assert_In;
      procedure Assert_Out (Hay, Needle, Ctx : String) is
      begin
         Assert (Ada.Strings.Fixed.Index (Hay, Needle) = 0,
                 Ctx & " (unexpected """ & Needle & """)");
      end Assert_Out;
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      --  modify/delete: git prints no "Auto-merging" (no content merge).
      Version.Git_Fixtures.Run (Root, "printf 'a\nb\n' > f.txt");
      Version.Git_Fixtures.Run (Root, "git add f.txt && git commit -q -m c1");
      Version.Git_Fixtures.Run (Root, "git checkout -q -b feat");
      Version.Git_Fixtures.Run (Root, "git rm -q f.txt && git commit -q -m del");
      Version.Git_Fixtures.Run (Root, "git checkout -q -");
      Version.Git_Fixtures.Run (Root, "printf 'a\nM\n' > f.txt");
      Version.Git_Fixtures.Run (Root, "git add f.txt && git commit -q -m c3");
      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C " & CLI & " merge feat > " & Root & ".md 2>&1 || true");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Root & ".md");
      begin
         Assert_In
           (Out_Text, "CONFLICT (modify/delete): f.txt deleted in feat",
            "modify/delete conflict line");
         Assert_Out (Out_Text, "Auto-merging", "modify/delete has no Auto-merging");
      end;

      --  file/directory: git renames the losing file to <path>~<branch>.
      declare
         DF : constant String := Version.Test_Support.Join (Root, "df");
      begin
         Version.Init.Init (DF);
         Configure_User (DF);
         Version.Git_Fixtures.Run (DF, "printf 'x\n' > base.txt");
         Version.Git_Fixtures.Run (DF, "git add . && git commit -q -m c1");
         Version.Git_Fixtures.Run (DF, "git checkout -q -b feat");
         Version.Git_Fixtures.Run (DF, "printf 'FILE\n' > thing");
         Version.Git_Fixtures.Run (DF, "git add thing && git commit -q -m c2");
         Version.Git_Fixtures.Run (DF, "git checkout -q -");
         Version.Git_Fixtures.Run
           (DF, "mkdir -p thing && printf 'DIR\n' > thing/inner.txt");
         Version.Git_Fixtures.Run
           (DF, "git add thing/inner.txt && git commit -q -m c3");
         Version.Git_Fixtures.Run
           (DF, "LC_ALL=C " & CLI & " merge feat > " & Root & ".df 2>&1 || true");
         declare
            Out_Text : constant String := Read_Raw_Bytes (Root & ".df");
         begin
            Assert_In
              (Out_Text,
               "CONFLICT (file/directory): directory in the way of thing "
               & "from feat; moving it to thing~feat instead.",
               "file/directory conflict message");
         end;
         Assert
           (Ada.Directories.Exists (Version.Test_Support.Join (DF, "thing~feat")),
            "file/directory moves the losing file to thing~feat");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Merge_Conflict_Diagnostics_Match_Git;

   procedure Cone_Sparse_Index_Is_Operable
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
      Version.Git_Fixtures.Run (Root, "printf 'r\n' > root.txt");
      Version.Git_Fixtures.Run
        (Root, "mkdir -p keep drop && printf 'a\n' > keep/a.txt"
         & " && printf 'x\n' > drop/x.txt");
      Version.Git_Fixtures.Run (Root, "git add -A && git commit -q -m c1");
      --  Put git into cone-mode sparse checkout with a sparse (v3) index.
      Version.Git_Fixtures.Run (Root, "git sparse-checkout init --cone");
      Version.Git_Fixtures.Run (Root, "git config index.sparse true");
      Version.Git_Fixtures.Run (Root, "git sparse-checkout set keep");

      --  version must operate on git's v3 sparse index (not error), and treat
      --  the sparse-excluded drop/ as absent-by-design (clean, not deleted).
      Version.Git_Fixtures.Run
        (Root,
         "LC_ALL=C " & CLI & " status --porcelain > " & Root & ".cs 2>&1");
      Assert
        (Read_Raw_Bytes (Root & ".cs") = "",
         "cone sparse status is clean (drop/ not reported deleted)");

      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C " & CLI & " ls-files > " & Root & ".cl 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Root & ".cl");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "keep/a.txt") /= 0
            and then Ada.Strings.Fixed.Index (Out_Text, "drop/x.txt") /= 0
            and then Ada.Strings.Fixed.Index (Out_Text, "error") = 0,
            "cone sparse ls-files reads the v3 index");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Cone_Sparse_Index_Is_Operable;

   procedure Sparse_Checkout_Set_Round_Trips_With_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Root    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
   begin
      Version.Init.Init (Root);
      Configure_User (Root);
      Ada.Directories.Set_Directory (Root);
      Version.Git_Fixtures.Run (Root, "printf 't\n' > top.txt");
      Version.Git_Fixtures.Run
        (Root, "mkdir -p src docs && printf 's\n' > src/s.txt"
         & " && printf 'd\n' > docs/d.txt");
      Version.Git_Fixtures.Run (Root, "git add -A && git commit -q -m c1");

      --  version sets a cone-mode sparse checkout ...
      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C " & CLI & " sparse-checkout set src > /dev/null 2>&1");

      --  ... whose pattern file matches git byte-for-byte ...
      Version.Git_Fixtures.Run
        (Root, "printf '/*\n!/*/\n/src/\n' > " & Root & ".expect");
      Assert
        (Read_Raw_Bytes (Version.Test_Support.Join (Root, ".git/info/sparse-checkout"))
           = Read_Raw_Bytes (Root & ".expect"),
         "version writes git's cone patterns");

      --  ... and real git reads it: the excluded path is skip-worktree (not
      --  deleted), so status is clean and ls-files -t marks it 'S'.
      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C git status --porcelain > " & Root & ".st 2>&1");
      Assert
        (Read_Raw_Bytes (Root & ".st") = "",
         "git sees a version-made sparse checkout as clean");

      Version.Git_Fixtures.Run
        (Root, "LC_ALL=C git ls-files -t > " & Root & ".t 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Root & ".t");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "S docs/d.txt") /= 0,
            "git marks the excluded path skip-worktree");
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "H src/s.txt") /= 0,
            "git marks the included path present");
      end;

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Sparse_Checkout_Set_Round_Trips_With_Git;

   procedure Submodule_Foreach_Sync_Deinit_Match_Git
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      Base    : constant String :=
        Version.Temp_Fixture.Root (Version.Temp_Fixture.Test_Case (T));
      Old_Dir : constant String := Ada.Directories.Current_Directory;
      CLI     : constant String :=
        """" & Version.Test_Support.Join (Old_Dir, "bin/main") & """";
      Super   : constant String := Version.Test_Support.Join (Base, "super");
   begin
      --  A submodule upstream and a superproject that embeds it (set up with
      --  real git; version's foreach/sync/deinit then operate on it).
      Version.Git_Fixtures.Run
        (Base,
         "git init -q dep.up && cd dep.up && git config user.email a@b.c"
         & " && git config user.name t && echo d > f && git add f"
         & " && git commit -q -m dep");
      Version.Git_Fixtures.Run
        (Base,
         "git init -q super && cd super && git config user.email a@b.c"
         & " && git config user.name t && echo top > top.txt && git add top.txt"
         & " && git -c protocol.file.allow=always submodule add -q file://"
         & Base & "/dep.up vendor/dep && git commit -q -m add");

      --  foreach exposes $sm_path and prints the Entering banner.
      Version.Git_Fixtures.Run
        (Super,
         "LC_ALL=C " & CLI & " submodule foreach 'echo P=$sm_path' > "
         & Base & ".fe 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Base & ".fe");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "Entering 'vendor/dep'") /= 0
            and then Ada.Strings.Fixed.Index (Out_Text, "P=vendor/dep") /= 0,
            "submodule foreach runs the command with $sm_path in each submodule");
      end;

      --  sync copies the .gitmodules URL into .git/config.
      Version.Git_Fixtures.Run
        (Super,
         "LC_ALL=C " & CLI & " submodule sync > " & Base & ".sy 2>&1");
      Assert
        (Ada.Strings.Fixed.Index
           (Read_Raw_Bytes (Base & ".sy"),
            "Synchronizing submodule url for 'vendor/dep'") /= 0,
         "submodule sync reports each synchronized submodule");
      Version.Git_Fixtures.Run
        (Super, "test -n ""$(git config submodule.vendor/dep.url)""");

      --  deinit empties the worktree and drops the config, keeping .gitmodules.
      Version.Git_Fixtures.Run
        (Super,
         "LC_ALL=C " & CLI & " submodule deinit vendor/dep > "
         & Base & ".di 2>&1");
      declare
         Out_Text : constant String := Read_Raw_Bytes (Base & ".di");
      begin
         Assert
           (Ada.Strings.Fixed.Index (Out_Text, "Cleared directory 'vendor/dep'")
            /= 0
            and then Ada.Strings.Fixed.Index
                       (Out_Text, "unregistered for path 'vendor/dep'") /= 0,
            "submodule deinit clears the directory and unregisters the path");
      end;
      Version.Git_Fixtures.Run
        (Super, "test -z ""$(ls -A vendor/dep)""");
      Version.Git_Fixtures.Run
        (Super, "test -z ""$(git config submodule.vendor/dep.url || true)""");
      Version.Git_Fixtures.Run (Super, "grep -q vendor/dep .gitmodules");

      Ada.Directories.Set_Directory (Old_Dir);
   exception
      when others =>
         Ada.Directories.Set_Directory (Old_Dir);
         raise;
   end Submodule_Foreach_Sync_Deinit_Match_Git;

   overriding procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Submodule_Foreach_Sync_Deinit_Match_Git'Access,
         "Submodule: foreach/sync/deinit match git");
      Register_Routine
        (T, Sparse_Checkout_Set_Round_Trips_With_Git'Access,
         "Sparse: version sparse-checkout set round-trips with git");
      Register_Routine
        (T, Archive_Tar_Filter_Command'Access,
         "Archive: configured tar.<fmt>.command filters, unknown format errors");
      Register_Routine
        (T, Cone_Sparse_Index_Is_Operable'Access,
         "Sparse: version operates on git cone-mode sparse (v3) index");
      Register_Routine
        (T, Merge_Conflict_Diagnostics_Match_Git'Access,
         "Merge: modify/delete conflict has no spurious Auto-merging");
      Register_Routine
        (T, Fetch_Summary_Matches_Git'Access,
         "Fetch: prints git's From/<old>..<new> -> origin/<branch> summary");
      Register_Routine
        (T, Merge_Output_Matches_Git_Stat'Access,
         "Merge: fast-forward/merge-commit emit git's Updating + --stat/summary");
      Register_Routine
        (T, Output_Is_Byte_Exact_Against_Git'Access,
         "Output: status/cat-file emit git-exact bytes (no spurious newline)");
      Register_Routine
        (T, LFS_Porcelain_Round_Trip'Access,
         "LFS porcelain: track/stage/ls-files/pointer/checkout round-trip");
      Register_Routine
        (T, LFS_Migrate_And_Maintenance'Access,
         "LFS: migrate import/export + ls-files/fsck/prune maintenance");
      Register_Routine
        (T, Mv_Into_Directory_Matches_Git'Access,
         "Mv: FILE DIR/ and FILE DIR both move into the directory");
      Register_Routine
        (T, Blame_Matches_Git'Access,
         "Blame: default annotation matches git byte-for-byte");
      Register_Routine
        (T, Switch_Matches_Git'Access,
         "Switch: -c/-/branch/--detach output matches git byte-for-byte");
      Register_Routine
        (T, Bisect_Matches_Git'Access,
         "Bisect: start/good/bad/log/terms/reset match git byte-for-byte");
      Register_Routine
        (T, Show_Branch_Matches_Git'Access,
         "Show-branch: matrix/naming/list match git byte-for-byte");
      Register_Routine
        (T, Merge_File_Matches_Git'Access,
         "Merge-file: clean/conflict/diff3/favor/marker/combine match git");
      Register_Routine
        (T, Rerere_Matches_Git'Access,
         "Rerere: status/remaining/clear match git");
      Register_Routine
        (T, Merge_Conflict_Matches_Git'Access,
         "Merge: conflict file/stages/rr-cache/-Xours match git");
      Register_Routine
        (T, Merge_Rename_And_Whitespace_Matches_Git'Access,
         "Merge: rename labels and -Xignore-space-change match git");
      Register_Routine
        (T, Merge_Untested_Classes_Match_Git'Access,
         "Merge: auto-merging line, merge driver, renormalize match git");
      Register_Routine
        (T, Status_And_Blame_Match_Git'Access,
         "Status/blame: mode change, untracked dirs, attribution match git");
      Register_Routine
        (T, Diff_Engine_Matches_Git'Access,
         "Diff: hunks (indent heuristic), log -p, show rev:path match git");
      Register_Routine
        (T, History_Tools_Match_Git'Access,
         "CLI Integration: commit-graph/fast-export/filter-branch match git");
      Register_Routine
        (T, Merge_Plumbing_Matches_Git'Access,
         "CLI Integration: merge-index/merge-one-file + strategy backends "
         & "match git");
      Register_Routine
        (T, Merge_Tree_And_Pack_Plumbing_Match_Git'Access,
         "CLI Integration: merge-tree + show-index/unpack-file/prune-packed "
         & "match git");
      Register_Routine
        (T, Plumbing_Queries_Match_Git'Access,
         "CLI Integration: ls-remote/check-attr/check-mailmap/for-each-repo "
         & "match git");
      Register_Routine
        (T, Subtree_Matches_Git'Access,
         "CLI Integration: subtree add/split match git");
      Register_Routine
        (T, Bisect_Run_And_Patch_Id_Match_Git'Access,
         "Bisect run and patch-id match git");
      Register_Routine
        (T, Hook_Run_Matches_Git'Access,
         "Hook: run output and exit codes match git");
      Register_Routine
        (T, Maintenance_Run_Matches_Git'Access,
         "Maintenance: run is silent, valid, and rejects bad tasks like git");
      Register_Routine
        (T, Interpret_Trailers_Matches_Git'Access,
         "Interpret-trailers: output matches git byte-for-byte");
      Register_Routine
        (T, Stripspace_Matches_Git'Access,
         "Stripspace: default/-s/-c output matches git byte-for-byte");
      Register_Routine
        (T, Check_Ref_Format_Matches_Git'Access,
         "Check-ref-format: validity and --normalize match git");
      Register_Routine
        (T, Mktree_Matches_Git'Access,
         "Mktree: tree oid matches git across sort/subtree/mode cases");
      Register_Routine
        (T, Mktag_Matches_Git'Access,
         "Mktag: tag oid matches git and rejects a type mismatch");
      Register_Routine
        (T, Fmt_Merge_Msg_Matches_Git'Access,
         "Fmt-merge-msg: merge message matches git across grouping cases");
      Register_Routine
        (T, Get_Tar_Commit_Id_Matches_Git'Access,
         "Get-tar-commit-id: recovers the commit id from git and version tars");
      Register_Routine
        (T, Diff_Plumbing_Matches_Git'Access,
         "Diff plumbing: diff-tree/diff-index/diff-files match git raw output");
      Register_Routine
        (T, Replace_Matches_Git'Access,
         "Replace: ref management and read-path honoring match git");
      Register_Routine
        (T, Shortlog_Matches_Git'Access,
         "Shortlog: -s/-n/-sn output matches git byte-for-byte");
      Register_Routine
        (T, Diff_Name_Only_Matches_Git'Access,
         "Diff: --name-only/--name-status match git (A/D/M)");
      Register_Routine
        (T, Extra_Plumbing_Matches_Git'Access,
         "Plumbing: var/count-objects/@{n}/name-rev/%(upstream) match git");
      Register_Routine
        (T, Cat_File_Batch_All_Objects_Matches_Git'Access,
         "Cat-file: --batch-all-objects enumerates loose+packed like git");
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
      Register_Routine
        (T, Log_Merge_History_Matches_Git'Access,
         "Log: merge history walks all parents (git parity)");
      Register_Routine
        (T, Apply_Index_Precondition_Matches_Git'Access,
         "Apply: --index honours the worktree-matches-index precondition");
      Register_Routine
        (T, Clean_Nested_Repo_Matches_Git'Access,
         "Clean: -fd preserves a nested git repo (needs -ff)");
      Register_Routine
        (T, Archive_Byte_Identical_To_Git'Access,
         "Archive: streams to stdout, tar byte-identical to git");
      Register_Routine
        (T, Notes_Add_Overwrite_Matches_Git'Access,
         "Notes: add refuses to clobber an existing note without -f");
      Register_Routine
        (T, Commit_Option_Surface_Matches_Git'Access,
         "Commit: git's option surface, template, merge/pick conclusion");
      Register_Routine
        (T, Checkout_Option_Surface_Matches_Git'Access,
         "Checkout/switch: git's option surface, carried edits, paths");
      Register_Routine
        (T, Add_Option_Surface_Matches_Git'Access,
         "Add: git's option surface, -N, --chmod, --renormalize, refusals");
      Register_Routine
        (T, Rebase_Option_Surface_Matches_Git'Access,
         "Rebase: git's option surface, exec/autosquash/empty, conflicts");
      Register_Routine
        (T, Diff_Option_Surface_Matches_Git'Access,
         "Diff: git's option surface, whitespace, color, check, submodules");
      Register_Routine
        (T, Log_Option_Surface_Matches_Git'Access,
         "Log: git's option surface, dates, walk, layouts, formats, merges");
      Register_Routine
        (T, Show_Option_Surface_Matches_Git'Access,
         "Show: git's option surface, combined diffs, objects, walk forms");
      Register_Routine
        (T, Blame_Option_Surface_Matches_Git'Access,
         "Blame: git's option surface, -L forms, -M/-C, ignore-rev, reverse");
      Register_Routine
        (T, Describe_Option_Surface_Matches_Git'Access,
         "Describe: git's option surface, candidates, contains, blobs, dirty");
      Register_Routine
        (T, Shortlog_Option_Surface_Matches_Git'Access,
         "Shortlog: git's option surface, groups, wrapping, stdin records");
      Register_Routine
        (T, Grep_Option_Surface_Matches_Git'Access,
         "Grep: git's option surface, expressions, context, sources, errors");
      Register_Routine
        (T, Notes_Option_Surface_Matches_Git'Access,
         "Notes: git's option surface, editor, copy/rewrite, merge strategies");
      Register_Routine
        (T, Tag_Option_Surface_Matches_Git'Access,
         "Tag: git's option surface, listing filters, columns, editor, reflog");
      Register_Routine
        (T, Branch_Option_Surface_Matches_Git'Access,
         "Branch: git's option surface, listing formats, tracking, rename, delete");
      Register_Routine
        (T, Stash_Option_Surface_Matches_Git'Access,
         "Stash: git's option surface, push modes, apply/pop merge, show, store");
      Register_Routine
        (T, Fast_Import_Stream_Matches_Git'Access,
         "Fast-import: author defaults to committer, short modes are files");
      Register_Routine
        (T, Checkout_Branch_Attaches_Head_Matches_Git'Access,
         "Checkout: <branch> attaches HEAD, non-branch detaches");
      Register_Routine
        (T, Config_Quoting_And_Unset_Matches_Git'Access,
         "Config: value quoting/escaping and multivar unset match git");
      Register_Routine
        (T, Commit_Tree_And_Mktree_Matches_Git'Access,
         "Commit-tree joins -m; mktree rejects malformed/type-mismatch");
      Register_Routine
        (T, Fast_Export_Import_Matches_Git'Access,
         "Fast-export tags/short-ref and fast-import no-from match git");
      Register_Routine
        (T, Index_Pack_Keep_And_Merge_File_Binary'Access,
         "index-pack --keep writes .keep; merge-file refuses binary");
      Register_Routine
        (T, Merge_Backends_Match_Git'Access,
         "merge-recursive virtual base and merge-resolve precondition");
      Register_Routine
        (T, Correctness_Batch_Matches_Git'Access,
         "describe/init--bare/notes/config-unset correctness match git");
      Register_Routine
        (T, Mktag_Fsck_Matches_Git'Access,
         "mktag runs git's strict fsck (email/date/tz/name/extra-header)");
      Register_Routine
        (T, Grep_Count_Diff_Match_Git'Access,
         "grep binary / count-objects -H / diff mode-change match git");
      Register_Routine
        (T, Ls_Files_Raw_Diff_Mode_Match_Git'Access,
         "ls-files -m deletes; diff-files/diff-index raw mode match git");
      Register_Routine
        (T, Bisect_Catfile_Z_Match_Git'Access,
         "bisect good-ancestor check; cat-file -z NUL input match git");
      Register_Routine
        (T, Plumbing_Errors_And_Init_Match_Git'Access,
         "hash-object/get-tar exit 128; init idempotent; merge-tree unrelated");
      Register_Routine
        (T, Check_Ignore_Path_Errors_Match_Git'Access,
         "check-ignore rejects empty and outside-repo paths (exit 128)");
      Register_Routine
        (T, Check_Ref_Format_And_Diff_Tree_Match_Git'Access,
         "check-ref-format --branch exits; diff-tree merge prints nothing");
      Register_Routine
        (T, Mv_Directory_Matches_Git'Access,
         "mv renames a tracked directory (index + cleanup) like git");
      Register_Routine
        (T, Rev_Zero_Checkout_Index_Diff_Files_Match_Git'Access,
         "rev^0 peels; checkout-index missing path; diff-files -p");
      Register_Routine
        (T, Diff_Rev_And_Diff_Index_Patch_Match_Git'Access,
         "diff <rev> tree-vs-worktree; diff-index -p patch output");
      Register_Routine
        (T, Diff_Renames_Match_Git'Access,
         "diff rename detection (similarity/stat/-M/diff.renames) matches git");
      Register_Routine
        (T, Format_Patch_Binary_Matches_Git'Access,
         "format-patch emits an appliable GIT binary patch");
      Register_Routine
        (T, Commit_Timestamp_Is_Unix_Time'Access,
         "commit/reflog/var timestamps are real Unix time (not local-epoch)");
      Register_Routine
        (T, Clone_Config_Excludes_Global'Access,
         "clone config excludes the global config and matches git");
      Register_Routine
        (T, Mailsplit_Matches_Git'Access,
         "mailsplit: Maildir, CRLF, empty and bare mailboxes match git");
      Register_Routine
        (T, Name_Rev_Matches_Git'Access,
         "name-rev walks all parents and matches git (incl. <tip>^2)");
      Register_Routine
        (T, Ls_Files_Control_Chars_Match_Git'Access,
         "ls-files lists and C-quotes control-character paths like git");
      Register_Routine
        (T, Cherry_Pick_Conflict_State_Matches_Git'Access,
         "cherry-pick conflict/empty state is git-readable");
      Register_Routine
        (T, Merge_No_Commit_And_Modify_Delete_Match_Git'Access,
         "merge --no-commit fast-forwards; modify/delete named like git");
      Register_Routine
        (T, Checkout_Exec_Bits_Match_Git'Access,
         "checkout/clone exec bits honour the umask like git");
      Register_Routine
        (T, Interpret_Trailers_Edge_Cases_Match_Git'Access,
         "interpret-trailers: divider, unfold and separator match git");
      Register_Routine
        (T, Diff_Files_And_Ls_Tree_Pathspecs_Match_Git'Access,
         "diff-files/ls-tree pathspec operands match git");
      Register_Routine
        (T, Ls_Remote_Refs_And_Patterns_Match_Git'Access,
         "ls-remote --refs and ref patterns match git");
      Register_Routine
        (T, Credential_Fill_Validation_Matches_Git'Access,
         "credential fill rejects a record missing host/protocol");
      Register_Routine
        (T, Merge_Index_Exit_Codes_Match_Git'Access,
         "merge-index exit codes and missing-path error match git");
      Register_Routine
        (T, Fetch_Head_Matches_Git'Access,
         "fetch records FETCH_HEAD like git");
      Register_Routine
        (T, Index_Pack_Output_Matches_Git'Access,
         "index-pack -o and --stdin output match git");
      Register_Routine
        (T, Mailinfo_Headers_Match_Git'Access,
         "mailinfo decodes encoded-words and cleans the subject like git");
      Register_Routine
        (T, Difftool_Sides_Match_Git'Access,
         "difftool compares index/worktree and HEAD/index like git");
      Register_Routine
        (T, Check_Attr_Operands_Match_Git'Access,
         "check-attr attribute/path operand split matches git");
      Register_Routine
        (T, For_Each_Repo_Stops_On_Failure'Access,
         "for-each-repo stops at the first failing repository");
      Register_Routine
        (T, Fmt_Merge_Msg_Grouping_Matches_Git'Access,
         "fmt-merge-msg groups refs per source like git");
      Register_Routine
        (T, Commit_Graph_And_Maintenance_Match_Git'Access,
         "commit-graph write gating and maintenance tasks match git");
      Register_Routine
        (T, Hook_Run_And_Mktree_Match_Git'Access,
         "hook run honours config hooks; mktree rejects blank lines");
      Register_Routine
        (T, Lfs_Pointer_And_Status_Match_Git_Lfs'Access,
         "lfs pointer bytes and status --porcelain match git-lfs");
      Register_Routine
        (T, Midx_Verify_And_Bundle_All_Match_Git'Access,
         "midx verify catches structural corruption; bundle --all is complete");
      Register_Routine
        (T, Filter_Branch_And_Repack_Artifacts_Match_Git'Access,
         "filter-branch prunes empty commits; repack writes git's artifacts");
      Register_Routine
        (T, Format_Patch_Mbox_Matches_Git'Access,
         "format-patch mbox (diffstat, -<n>, separators) matches git");
   end Register_Tests;

   overriding function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("CLI Integration");
   end Name;

end CLI_Integration_Tests;
