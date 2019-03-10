#!/bin/bash
# cloning wp from one domain  to another domain or subdomain or to the same domain on another cpanel user
#
# Prepare to have  created new domain and cpanel user that is owner of the new domain.
# 
# usage (interactive questions):
# ./wpclone.sh 

echo "Enter created cpanel (linux) user name for wp destination?"
read  new_cpanel_user

echo "Enter the old domain name - source of wp"
read old_domain

echo "Enter domain name for destination wp? (leave blank if the same as \"old\" domain name)"
read new_domain

if [[ $new_domain == "" ]]
then
	new_domain=$old_domain
fi

# source of wp
source_user=$(grep $old_domain /etc/userdomains | awk '{print $2}'| tail -n 1)
source_dir=$(grep documentroot /var/cpanel/userdata/$source_user/$old_domain | awk '{print $2}')

# destination_wp assumed to live in public_html  directory, change it if you need so (it will be prompted)
user_home=$(grep $new_cpanel_user /etc/passwd | awk -F':' '{ print $6}')
destination_wp=$user_home/'public_html'

echo "Destination path will be $destination_wp. If this is ok, leave blank and press Enter. For other destination directory, enter the name of the directory - relative path within $user_home (directory must exist)"
read dest_dir
echo $dest_dir

# remove / on the end of destination path if exists
if [[ -n $dest_dir ]]
then
	cc="${dest_dir: -1}"
	echo $cc
	if [[ $cc == "/" ]]
	  then
		dest="${dest_dir:0:-1}"
    else
		dest=$dest_dir
	fi
else
	dest="public_html"
fi	
destination_wp=$user_home/$dest

# confirm to continue function
prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input, y/n?"
    esac 
  done  
}

# confirm if we are good to go
prompt_confirm "Input is following:
Destination cpanel user: $new_cpanel_user
Destination domain name: $new_domain 
Source wp directory: $source_dir 
Old domain name: $old_domain 
Destination path for wp: $destination_wp 
Continue? " || exit 0

check_source=$(ls $source_dir)
if [ -z "$check_source" ]
then
    echo "Fatal error: No proper source of wordpress"
    exit;
fi

##################### so much of validation, if you didn't give proper input data that you confirmed, sorry. #############################

#password generator, 16 characters ( -c 16)
genpasswd() {
	tr -dc A-Za-z0-9 < /dev/urandom | head -c 16 | xargs
}


echo "copying files..."
rsync -av $source_dir/ $destination_wp/

#fix permissions
chown $new_cpanel_user.nobody $destination_wp
chmod 750 $destination_wp
chown -R $new_cpanel_user. $destination_wp/* $destination_wp/.htaccess $destination_wp/.ftpquota $destination_wp/.well-known

# cpanel API - generate db_name, db_user, give all privileges to db_name
user_size=${#new_cpanel_user}
if [ $user_size > 8 ]
    then
      db_prefix=$(echo $new_cpanel_user | cut -c 1-8)
    else
      db_prefix=$new_cpanel_user
fi


db2=$db_prefix'_wpwppr'
db_user2=$db_prefix'_wpwppr'
db_pass2=$(genpasswd)

cpapi2 --user=$new_cpanel_user MysqlFE createdb db=$db2
uapi --user=$new_cpanel_user Mysql create_user name=$db2 password=$db_pass2
uapi --user=$new_cpanel_user Mysql set_privileges_on_database user=$db_user2 database=$db2 privileges=ALL PRIVILEGES

# prepare wp-config.php connection string
db1=$( grep DB_NAME $destination_wp/wp-config.php | awk -F "'" '{ print $4}')

# mysqldump and restore in second db
echo "database dump and restore..."
mysqldump $db1 > db_backup_tmp.sql
mysql $db2 < db_backup_tmp.sql

RESULT=$?
	if [ $RESULT -eq 0 ]; then
	  echo "Db import successfull."
	else
	  echo "mysqldump and import not successfull. Check the rest of the process manually."
	  echo "Exit..."
	  exit;			
	fi

rm db_backup_tmp.sql

db_user=$( grep DB_USER $destination_wp/wp-config.php | awk -F "'" '{ print $4}')

# replace db name, db user
sed -i -e "s/$db1/$db2/g" $destination_wp/wp-config.php
sed -i -e "s/$db_user/$db_user2/g" $destination_wp/wp-config.php

#optional , if there is a cache path in wp-config
wp_cache=$(grep WPCACHEHOME $destination_wp/wp-config.php )
if [ ! -z "$wp_cache" ] 
then
	sed -i "/WPCACHEHOME/d" $destination_wp/wp-config.php
	wp_cache2="define( \'WPCACHEHOME\', \'$destination_wp/wp-content/plugins/wp-super-cache/\' );"
	sed -i "24i $wp_cache2" $destination_wp/wp-config.php
	
fi

# delete password line as password may have characters not easy to replace
sed -i "/DB_PASSWORD/d" $destination_wp/wp-config.php
wp_pass="define(\'DB_PASSWORD\', \'$db_pass2\');"
# append line with new db_user password, somewhere between 25 and 31 line
sed -i "31i $wp_pass" $destination_wp/wp-config.php

#db search and replace php script if "new_domain" is other then "old_domain
if [[ $old_domain != $new_domain ]]
then
	wget https://github.com/interconnectit/Search-Replace-DB/archive/master.zip
	unzip master.zip -d $destination_wp/
	rm -f master.zip
	
	echo "Search and replace $old_domain with $new_domain data in database..."

	# replace $old_domain with $new_domain in database
	$(php $destination_wp/Search-Replace-DB-master/srdb.cli.php -h localhost -n $db2 -u $db_user2 -p $db_pass2 -s $old_domain -r $new_domain)
		
	# replace directory path from old and new wp source
	$(php $destination_wp/Search-Replace-DB-master/srdb.cli.php -h localhost -n $db2 -u $db_user2 -p $db_pass2 -s $source_dir -r $destination_wp)
	rm -fr $destination_wp/Search-Replace-DB-master/
fi

echo "##################"
echo "Done! Check it out"
