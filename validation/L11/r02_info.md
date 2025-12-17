## Nodes of Rack02

```
[std-bcm-mst01->device]% list -t HeadNode
Type             Hostname (key)   MAC                Category         IP               Network          Status
---------------- ---------------- ------------------ ---------------- ---------------- ---------------- --------------------------------
HeadNode         std-bcm-mst01    40:5B:7F:9F:C4:9B                   10.135.8.2       internalnet      [   UP   ], health check failed+

[std-bcm-mst01->device]% list -r GB200-Rack2
Type             Hostname (key)     MAC                Category         IP               Network          Status
---------------- ------------------ ------------------ ---------------- ---------------- ---------------- --------------------------------
PhysicalNode     GB200-Rack2-CT01   9A:32:79:36:23:28  gb200            10.135.0.65      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT02   B6:FD:40:0A:9A:FA  gb200            10.135.0.66      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT03   76:2B:B1:34:BF:DA  gb200            10.135.0.67      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT04   EA:D5:8C:AE:91:BF  gb200            10.135.0.68      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT05   6E:34:CF:B7:DC:B4  gb200            10.135.0.69      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT06   F2:36:0F:C3:79:7A  gb200            10.135.0.70      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT07   5A:79:20:9A:5B:9C  gb200            10.135.0.71      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT08   8A:D8:07:42:20:9A  gb200            10.135.0.72      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT09   2A:80:77:33:26:34  gb200            10.135.0.73      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT10   8A:98:2D:E1:E5:15  gb200            10.135.0.74      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT11   9E:6E:7A:79:68:00  gb200            10.135.0.75      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT12   C6:83:04:B3:53:D6  gb200            10.135.0.76      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT13   DE:AE:61:43:E7:33  gb200            10.135.0.77      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT14   A2:54:56:89:97:76  gb200            10.135.0.78      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT15   36:F6:63:E9:49:45  gb200            10.135.0.79      rack2-inband     [   UP   ], health check failed+
PhysicalNode     GB200-Rack2-CT16   FA:18:1C:0F:86:2A  gb200            10.135.0.80      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT17   4A:2E:F4:14:82:5C  gb200            10.135.0.81      rack2-inband     [   UP   ], health check failed
PhysicalNode     GB200-Rack2-CT18   FA:37:E3:72:8D:7B  gb200            10.135.0.82      rack2-inband     [   UP   ], health check failed
PowerShelf       GB200-Rack2-PWR1   24:5B:F0:80:BD:D5                   10.135.36.9      powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR2   24:5B:F0:80:BD:C2                   10.135.36.10     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR3   24:5B:F0:80:BE:5F                   10.135.36.11     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR4   24:5B:F0:80:BE:5E                   10.135.36.12     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR5   24:5B:F0:80:BE:63                   10.135.36.13     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR6   24:5B:F0:80:BE:62                   10.135.36.14     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR7   24:5B:F0:80:BE:67                   10.135.36.15     powershelf-oob1  [  DOWN  ]
PowerShelf       GB200-Rack2-PWR8   24:5B:F0:80:BE:64                   10.135.36.16     powershelf-oob1  [  DOWN  ]
Switch           GB200-Rack2-NVSW1  50:00:E6:60:92:74                   10.135.32.192    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW2  50:00:E6:2D:71:94                   10.135.32.194    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW3  50:00:E6:68:BA:80                   10.135.32.196    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW4  50:00:E6:3D:12:12                   10.135.32.198    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW5  50:00:E6:5E:AB:10                   10.135.32.200    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW6  50:00:E6:5E:85:B8                   10.135.32.202    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW7  50:00:E6:5E:B3:08                   10.135.32.204    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW8  50:00:E6:2D:DB:36                   10.135.32.206    rack2-oob        [  DOWN  ]
Switch           GB200-Rack2-NVSW9  50:00:E6:99:ED:7E                   10.135.32.208    rack2-oob        [  DOWN  ]
```

## Target nodes Status:

```
root@std-bcm-mst01:~# pdsh -R ssh -w GB200-Rack2-CT[01-18] <<- EOF | dshbak -c
dmidecode | grep -e 699-2G548-1201-A00 -e 699-2G548-1201-A10 -e 699-2G548-1201-800 -e 699-2G548-0202-800 -e 699-2G548-0202-A00
EOF
----------------
GB200-Rack2-CT[01-03,05-10,12-14,16-18]
----------------
        Version: 699-2G548-1201-A00
        Version: 699-2G548-1201-A00
        Part Number: 699-2G548-1201-A00
        Part Number: 699-2G548-1201-A00
----------------
GB200-Rack2-CT[04,11]
----------------
        Version: 699-2G548-1201-800
        Version: 699-2G548-1201-800
        Part Number: 699-2G548-1201-800
        Part Number: 699-2G548-1201-800
----------------
GB200-Rack2-CT15
----------------
        Version: 699-2G548-1201-A00
        Version: 699-2G548-1201-800
        Part Number: 699-2G548-1201-A00
        Part Number: 699-2G548-1201-A00
```
