#!/bin/bash

# Backs up elasticsearch 0.9 database using LVM snapshots

if [ -z "$1" ]; then
    TS=`date +%G%m%d%H%M`;
else
    TS=$1;
fi

set -u

BEGIN_TIME=`date +%G%m%d%H%M`;

SOURCE_SERVER=`/bin/hostname`

BACKUP_DIR=/var/lib/elasticsearch/backup

# Do NOT add a trailing slash to this path, it will change rsync's behavior
DEST_DIR=/var/lib/elasticsearch/backup/tmp

ES_DIR=v20140808

doBackup() {

    set -e

    if [ $SOURCE_SERVER == "prd-search21.avention.com" ]; then
        /bin/echo -n "Disabling Index Flushing...   "
        curl -XPUT "http://$SOURCE_SERVER:9200/_all/_settings" -d '{ "index": { "translog.disable_flush": "true" } }'
        /bin/echo

        /bin/echo -n "Disabling Shard Allocation... "
        curl -XPUT "http://$SOURCE_SERVER:9200/*/_settings" -d '{ "index.routing.allocation.disable_allocation" : "true" }'
        /bin/echo
        sleep 10;
    else
        # Everyone else waits for the above commands to take effect
        echo "Waiting for prd-search21 to disable index flushing and shard allocation..."
        sleep 30;
    fi


    echo "Cleaning up old log files"
    find $BACKUP_DIR/logs -type f -mtime +31 | xargs -iLOGFILE rm -f "LOGFILE"

    echo "Creating temp directories at $BACKUP_DIR/tmp"
    mkdir -p $BACKUP_DIR/tmp/data1
    mkdir -p $BACKUP_DIR/tmp/data2
    mkdir -p $BACKUP_DIR/tmp/data3
    mkdir -p $BACKUP_DIR/tmp/data4

    chown elasticsearch:elasticsearch $BACKUP_DIR/tmp/data1
    chown elasticsearch:elasticsearch $BACKUP_DIR/tmp/data2
    chown elasticsearch:elasticsearch $BACKUP_DIR/tmp/data3
    chown elasticsearch:elasticsearch $BACKUP_DIR/tmp/data4

    echo "Creating LVM snapshots"
    #/sbin/lvcreate -L250G -s -n esdata1_backup esdata1/esdata1_master
    #/sbin/lvcreate -L250G -s -n esdata2_backup esdata2/esdata2_master
    #/sbin/lvcreate -L250G -s -n esdata3_backup esdata3/esdata3_master
    #/sbin/lvcreate -L250G -s -n esdata4_backup esdata4/esdata4_master
    /sbin/lvcreate -L80G -s -n esdata1_backup esdata1/esdata1_master
    /sbin/lvcreate -L80G -s -n esdata2_backup esdata2/esdata2_master
    /sbin/lvcreate -L80G -s -n esdata3_backup esdata3/esdata3_master
    /sbin/lvcreate -L80G -s -n esdata4_backup esdata4/esdata4_master

    echo "Creating LVM snapshot mount points"
    mkdir -p /var/lib/elasticsearch/backup1-snapshot
    mkdir -p /var/lib/elasticsearch/backup2-snapshot
    mkdir -p /var/lib/elasticsearch/backup3-snapshot
    mkdir -p /var/lib/elasticsearch/backup4-snapshot

    echo "Mounting LVM snapshots"
    mount -o,ro /dev/esdata1/esdata1_backup /var/lib/elasticsearch/backup1-snapshot
    mount -o,ro /dev/esdata2/esdata2_backup /var/lib/elasticsearch/backup2-snapshot
    mount -o,ro /dev/esdata3/esdata3_backup /var/lib/elasticsearch/backup3-snapshot
    mount -o,ro /dev/esdata4/esdata4_backup /var/lib/elasticsearch/backup4-snapshot

    echo "LVM snapshots created. It is now safe to enable Elasticsearch index flushing and shard reallocation."


    if [ $SOURCE_SERVER == "prd-search21.avention.com" ]; then
        echo "Waiting for other servers to catch up and get out ahead of this point in the script..."
        sleep 60

        /bin/echo -n "Enabling Index Flushing...   "
        curl -XPUT "http://$SOURCE_SERVER:9200/_all/_settings" -d '{"index": {"translog.disable_flush": "false" } }'
        /bin/echo

        /bin/echo -n "Enabling Shard Allocation... "
        curl -XPUT "http://$SOURCE_SERVER:9200/*/_settings" -d '{"index.routing.allocation.disable_allocation" : "false" }'
        /bin/echo
    fi


    for ((i=1; i<5; i++)); do

        echo "Synchronizing ES data from /var/lib/elasticsearch/backup${i}/$ES_DIR to $BACKUP_DIR/tmp/data${i}";
        rsync -avL --delete /var/lib/elasticsearch/backup${i}-snapshot/$ES_DIR  $BACKUP_DIR/tmp/data${i} > $BACKUP_DIR/logs/rsync_data${i}-${TS}.log 2>&1;

        sleep 5;

        echo "- Unmounting LVM snapshot /var/lib/elasticsearch/backup${i}";
        umount /var/lib/elasticsearch/backup${i}-snapshot;
        rmdir  /var/lib/elasticsearch/backup${i}-snapshot;

        echo "- Removing LVM snapshot /dev/esdata${i}/esdata${i}_backup";
        /sbin/lvremove -vf /dev/esdata${i}/esdata${i}_backup;

    done


    # We used to tar everything up, but this takes a really long time on the slow backup disk
    #echo "Creating a tar-gzip archive of the ES data: es-backup-$TS.tgz"
    #cd $BACKUP_DIR/tmp
    #tar cfz "es-backup-$TS.tgz" data1 data2 data3 data4
    #mv "es-backup-$TS.tgz" $BACKUP_DIR/

    case $SOURCE_SERVER in
        #prd-search04.avention.com ) DEST_SERVER="prd-search16.avention.com" ;;
        #prd-search05.avention.com ) DEST_SERVER="prd-search17.avention.com" ;;
        #prd-search06.avention.com ) DEST_SERVER="prd-search18.avention.com" ;;
        #prd-search07.avention.com ) DEST_SERVER="prd-search19.avention.com" ;;
        #prd-search08.avention.com ) DEST_SERVER="prd-search20.avention.com" ;;
        #prd-search09.avention.com ) DEST_SERVER="prd-search21.avention.com" ;;
        #prd-search10.avention.com ) DEST_SERVER="prd-search22.avention.com" ;;
        #prd-search11.avention.com ) DEST_SERVER="prd-search23.avention.com" ;;
        #prd-search12.avention.com ) DEST_SERVER="prd-search24.avention.com" ;;
        #prd-search13.avention.com ) DEST_SERVER="prd-search25.avention.com" ;;
        #prd-search14.avention.com ) DEST_SERVER="prd-search26.avention.com" ;;
        #prd-search15.avention.com ) DEST_SERVER="prd-search27.avention.com" ;;
        prd-search16.avention.com ) DEST_SERVER="prd-search04.avention.com" ;;
        prd-search17.avention.com ) DEST_SERVER="prd-search05.avention.com" ;;
        prd-search18.avention.com ) DEST_SERVER="prd-search06.avention.com" ;;
        prd-search19.avention.com ) DEST_SERVER="prd-search07.avention.com" ;;
        prd-search20.avention.com ) DEST_SERVER="prd-search08.avention.com" ;;
        prd-search21.avention.com ) DEST_SERVER="prd-search09.avention.com" ;;
        prd-search22.avention.com ) DEST_SERVER="prd-search10.avention.com" ;;
        prd-search23.avention.com ) DEST_SERVER="prd-search11.avention.com" ;;
        prd-search24.avention.com ) DEST_SERVER="prd-search12.avention.com" ;;
        prd-search25.avention.com ) DEST_SERVER="prd-search13.avention.com" ;;
        prd-search26.avention.com ) DEST_SERVER="prd-search14.avention.com" ;;
        prd-search27.avention.com ) DEST_SERVER="prd-search15.avention.com" ;;
        * ) echo "Error: Missing backup server definition" ;;
    esac


    # Create/update the BACKUP-STATUS file *before* the rsync to the destination server, that way both sides have the same file
    echo "Last successful backup was - $BEGIN_TIME" > $BACKUP_DIR/tmp/BACKUP-STATUS
    chown elasticsearch:elasticsearch $BACKUP_DIR/tmp/BACKUP-STATUS


    echo "Synchronizing backup from $SOURCE_SERVER to $DEST_SERVER"
    rsync -av --delete --exclude 'backup' --exclude 'lost+found' -e '/usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /opt/elasticsearch/.ssh/backup_sync-id_rsa' $BACKUP_DIR/tmp/ elasticsearch@$DEST_SERVER:$DEST_DIR  > $BACKUP_DIR/logs/rsync_remote-${TS}.log 2>&1;


    END_TIME=`date +%G%m%d%H%M`
    echo "Backup Complete ($BEGIN_TIME to $END_TIME)"
}

mkdir -p $BACKUP_DIR/logs
chown elasticsearch:elasticsearch $BACKUP_DIR/logs

doBackup 2> $BACKUP_DIR/logs/backup-$TS.errors 1> $BACKUP_DIR/logs/backup-$TS.log &

wait

ERR_COUNT=`cat $BACKUP_DIR/logs/backup-$TS.errors | wc -l`
if [ "$ERR_COUNT" -gt 0 ]; then
    echo "$ERR_COUNT Error(s) encountered when running ES backup on $HOSTNAME"
    cat $BACKUP_DIR/logs/backup-$TS.errors | mail -s "ES Backup - $ERR_COUNT Error(s) on $HOSTNAME" "jeremy.frank@avention.com"
fi

