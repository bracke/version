# Worktree workflow

```sh
version init demo
cd demo
printf 'base\n' > base.txt
version stage base.txt
version save "base"
version branch create feature
version worktree add ../feature feature
version worktree list
cd ../feature
printf 'feature\n' > feature.txt
version stage feature.txt
version save "feature work"
version status
```
