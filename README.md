# resize-cloud-ova-image
Cloud images usually are built with minimal disk space requirements. This script uses VBoxManage to change its size for use with VirtualBox.

```
resize_ova.sh /path/to/ova [ new-disk-size ]

1st arg     location to ova image
2nd arg     optional disk size in MB (default is 51200, for 50G)

Note: making the size smaller than the size in the ova will be nothing but trouble
```


