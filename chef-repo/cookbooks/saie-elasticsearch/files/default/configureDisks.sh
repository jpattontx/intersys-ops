#!/bin/sh
if grep 'elasticsearch' "/etc/fstab";then
  echo "Disks have already been configured"
elif [ -e "/etc/fstab.backup" ]; then
  echo "A previous attempt was made to configure the disks.  Remove the file /etc/fstab.backup, and re-run this script to try and configure them again"
else
  echo "Configuring disks..."
  service elasticsearch stop
  rm -rf /var/lib/elasticsearch/data1/*
  rm -rf /var/lib/elasticsearch/data2/*
  rm -rf /var/lib/elasticsearch/data3/*
  rm -rf /var/lib/elasticsearch/data4/*

  # Unmount disks
  umount /disk1
  umount /disk2
  umount /disk3
  umount /disk4

  # Update /etc/fstab
  cp /etc/fstab /etc/fstab.backup

  sed 's/\t\/disk/\t\/var\/lib\/elasticsearch\/data/g' /etc/fstab > /etc/fstab.tmp

  if ! grep 'elasticsearch' "/etc/fstab.tmp";then
      sed 's/ \/disk/ \/var\/lib\/elasticsearch\/data/g' /etc/fstab > /etc/fstab.tmp
  fi

  if grep 'elasticsearch' "/etc/fstab.tmp";then
    mv -f /etc/fstab.tmp /etc/fstab

    mount /var/lib/elasticsearch/data1
    mount /var/lib/elasticsearch/data2
    mount /var/lib/elasticsearch/data3
    mount /var/lib/elasticsearch/data4

    chown -R elasticsearch:elasticsearch /var/lib/elasticsearch

  else
    echo "Disk configuration failed"
  fi
fi
