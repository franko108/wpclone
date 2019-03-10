## Clone wp script ##

Script that can clone worpdress from one domain to another on the same server. If cloning from another server, run script from 
destination server. However, if you may have to tweak the path of source wp if it is coming from another server. Basicaly, one can change on the line 25: `source_dir` and put data from another server.    
Good for massive cloning or you're just sick of those wordpress cloning.  

Script will:

* clone all files from source to new destination (new_cpanel_user , it will assume that destination is in public_html, script will ask if another destination directory) 
* take care of proper permissions
* create a new database, db owner and permissions over database. If cpanel username is longer than 8 characters, it will strip it for creating database name and db user
* db export from the first database and import to a second db
* set a new connection string in *wp-config.php*
* if cloning from one domain to another, script will download search and replace script and make search and replace in database from old domain name to the new one as well as the directory path from one *home* to another
* delete search&replace instance from server.

### Prerequisite  ###

* new domain with cpanel user is already created on cpanel.

WHM API for quick creating new cpanel user(s):

```
$ whmapi1 createacct username=domainuser domain=domain.com plan=default featurelist=default quota=0 password=TGMFTK88g5pBQo0M ip=n cgi=1 hasshell=1 contactemail=email%40domain.com cpmod=paper_lantern maxftp=5 maxsql=5 maxpop=20 maxlst=5 maxsub=1 maxpark=1 maxaddon=3 bwlimit=20000 language=en useregns=1 hasuseregns=1 reseller=0 forcedns=1 mailbox_format=mdbox mxcheck=local max_email_per_hour=120 max_defer_fail_percentage=80 owner=root
```

Owner can be root or reseller username.

I was tempted to put this part in the script, but it may end badly, especially if the domain name is someting like *brandeditem* or *apartments*, it may have a collision with an existing name.

### Usage ###
The script is interactive (for good or bad part)   
Script will interactively ask for inputs:

* new_cpanel_user
* new_domain name
* old_domain name (if other than "new domain"
* destination directory if not *public_html*

Example
```
root@branded2 [~]# ./wpclone.sh 
Enter created cpanel (linux) user name for wp destination?
camelbak
Enter the old domain name - source of wp
bettonipens.com
Enter domain name for destination wp? (leave blank if the same as "old" domain name)
camelbak.brandeditems.com
Destination path will be /home/camelbak/public_html. If this is ok, leave blank and press Enter. 
For other destination directory, enter the name of the directory - relative path within /home/camelbak (directory must exist)

Input is following:
Destination cpanel user: camelbak
Destination domain name: camelbak.brandeditems.com 
Source wp directory: /home/bettonipens/public_html 
Old domain name: bettonipens.com 
Destination path for wp: /home/camelbak/public_html 
Continue?  [y/n]: 
....
```

### Limitations ###

* to be used on cpanel only
* basic validation only, however, before cloning, you are asked to confirm all parameters. If provided user is invalid, nothing bad will happen, script will just fail
* it doesn't check the `.htaccess` if there is some hardcoded domain name or so.

---

After usage don't forget to remove script from server.

Thanks to https://github.com/interconnectit/Search-Replace-DB for doing proper search&replace within the wp database.


