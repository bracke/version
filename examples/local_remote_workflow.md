# Local remote workflow

```sh
version init --bare remote.git
version init source
cd source
printf 'hello\n' > hello.txt
version stage hello.txt
version save "initial"
version remote add origin ../remote.git
version push origin main
cd ..
version clone remote.git clone
cd clone
version fetch origin
version status
git fsck --strict
```
