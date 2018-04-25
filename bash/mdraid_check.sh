cd /dev
for MD in md[0-9]*; do
    echo check > /sys/block/${MD}/md/sync_action
done

