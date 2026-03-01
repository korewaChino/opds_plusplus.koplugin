install:
    ssh kobo "rm -rf /mnt/onboard/.adds/koreader/plugins/opds_plus.koplugin"
    ssh kobo "mkdir -p /mnt/onboard/.adds/koreader/plugins/opds_plus.koplugin"
    scp -r . kobo:/mnt/onboard/.adds/koreader/plugins/opds_plus.koplugin/.