安装Archlinux操作系统

参考
1. https://wiki.archlinux.org/title/installation_guide
2. https://archlinuxstudio.github.io/ArchLinuxTutorial/#/


需要注意的是：
1. 一定要安装bootloader，不然启动不了。
2. arch-chroot之后，一定要安装dhcpcd, iwd, 不然系统启动起来之后连不上网，啥也装不了。
3. pacstrap命名如果碰上报错 "signature from  is unknown trust", 可以执行 `pacman -Sy archlinux-keyring` 更新一下keyring数据库就行。


