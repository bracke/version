# Basic workflow

```sh
version init demo
cd demo
printf 'hello\n' > hello.txt
version stage hello.txt
version save "initial"
version status
version log
version verify
git fsck --strict
```
