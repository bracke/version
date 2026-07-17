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
   end Register_Tests;

   overriding function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("CLI Integration");
   end Name;

end CLI_Integration_Tests;
