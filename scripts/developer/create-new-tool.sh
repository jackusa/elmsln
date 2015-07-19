#!/bin/bash
# this script adds a new tool to ELMSLN. It creates the right directories
# in the domains folder, correctly symlinks to things inside of config
# and generates a stubbed out config area. Other setup scripts still need
# to fire in order to ensure that all domains / tools are in place and
# we also need to make sure that the source is updated to support the
# domains that we do but this gets a lot of the way there in conjunction
# with the drush plugin to automatically generate a new stack correctly
# off of a distro / dslm setup.

# where am i? move to where I am. This ensures source is properly sourced
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
elmsln="${DIR}/../../"
configsdir="${DIR}/../../../instances/_development/config-example"
address="YOURUNIT"
serviceaddress="SERVICEYOURUNIT"
serviceprefix="DATA."
#provide messaging colors for output to console
txtbld=$(tput bold)             # Bold
bldgrn=${txtbld}$(tput setaf 2) #  green
bldred=${txtbld}$(tput setaf 1) #  red
txtreset=$(tput sgr0)
elmslnecho(){
  echo "${bldgrn}$1${txtreset}"
}
elmslnwarn(){
  echo "${bldred}$1${txtreset}"
}

# test for an argument as to what user to write as
if [ -z $1 ]; then
  elmslnwarn "You must supply a domain to produce"
  exit 1
fi
# test for an argument as to what user to write as
if [ -z $2 ]; then
  elmslnwarn "You must supply a distro to create like inbox"
  exit 1
fi
# test for an argument as to what user to write as
if [ -z $3 ]; then
  elmslnwarn "You must supply the version such as 7.x-1.x."
  exit 1
fi
# test for an argument as to what user to write as
if [ -z $4 ]; then
  elmslnwarn "You must supply the type of tool this is, authority or instance?"
  exit 1
fi
domain=$1
distro=$2
version=$3
tooltype=$4
# check that this domain exists as a stack, otherwise error out
if [ ! -d "$elmsln/core/dslmcode/stacks/$domain" ]; then
  elmslnwarn "This domain must already exist if we are to correctly discover it."
  exit 1
fi
# check that the config doesn't already exist in the example directory
if [ ! -d "$configsdir/stacks/$domain" ]; then
  # get structure in place for stack config
  mkdir -p "$configsdir/stacks/$domain/sites/default/files"
  cp "$elmsln/core/dslmcode/cores/drupal-7/sites/default/default.settings.php" "$configsdir/stacks/$domain/sites/default/default.settings.php"
  mkdir "$configsdir/stacks/$domain/sites/$domain"
  # get favicon in place
  cp "$elmsln/docs/assets/favicon.png" "$configsdir/stacks/$domain/favicon.ico"
  cp "$elmsln/core/dslmcode/cores/drupal-7/.htaccess" "$configsdir/stacks/$domain/.htaccess"
  # copy sites.php example then write into it at bottom
  cp "$elmsln/core/dslmcode/cores/drupal-7/sites/example.sites.php" "$configsdir/stacks/$domain/sites/sites.php"
  echo "\$sites = array(" >> "$configsdir/stacks/$domain/sites/sites.php"
  echo "" >> "$configsdir/stacks/$domain/sites/sites.php"
  echo ");" >> "$configsdir/stacks/$domain/sites/sites.php"
fi

# check for the distro, if we don't have it then create it
if [ ! -d "$elmsln/core/dslmcode/profiles/${distro}-${version}" ]; then
  cd "$elmsln/core/dslmcode/profiles"
  cp -R ulmus-7.x-1.x "${distro}-${version}"
  cd "${distro}-${version}"
  renames=('local.make.example' 'drecipes/elmsln_ulmus.drecipe' 'ulmus.info' 'ulmus.install' 'ulmus.profile' 'themes/SUB_foundation_access/SUB_foundation_access.info' 'themes/SUB_foundation_access/css/SUB_styles.css' 'themes/SUB_foundation_access/template.php')
  for rename in "${renames[@]}"
    do
    sed -i "/\ulmus/a \ \t $distro" $rename
    sed -i "/\SUB/a \ \t $distro" $rename
  done
  find . -name 'ulmus*' -type f -exec bash -c 'mv "$1" "${1/\/ulmus/$distro/}"' -- {} \;
  find . -name 'SUB*' -type f -exec bash -c 'mv "$1" "${1/\/SUB/$distro/}"' -- {} \;
  # add into the file the correct depdendencies for these
  if [ $tooltype == 'authority' ];
    then
    sed -i "/\;dependencies[] = cis_course_authority/a \ \t \dependencies[] = cis_course_authority" "${distro}.info"
  fi
  # instances don't change anything abnormal
  if [ $tooltype == 'instance' ];
    then
    sed -i "/\;dependencies[] = og/a \ \t \dependencies[] = og" "${distro}.info"
    sed -i "/\;dependencies[] = og_ui/a \ \t \dependencies[] = og_ui" "${distro}.info"
    sed -i "/\;dependencies[] = cis_section/a \ \t \dependencies[] = cis_section" "${distro}.info"
  fi
fi

# remove git in this new place and create a new repo w/ the correct name conventions
# rm -rf .git
# git init
#git checkout -b $version
# git add -A
# git commit -m "initial commit of $distro"
elmslnecho "issue this for d.o work: git remote add origin YOU@git.drupal.org:project/$distro.git"

# check that it doesn't already exist
if [ ! -d "$elmsln/domains/$domain" ]; then
  cd "$elmsln/domains"
  # authorities are just a symlink to the folder in question, much easier!
  if [ $tooltype == 'authority' ];
    then
    drush eas $domain $distro --service-instance=TRUE
  fi
  # instances have a bit more symlinks
  if [ $tooltype == 'instance' ];
    then
    drush eas $domain $distro --service-instance=TRUE
    cp "$elmsln/core/dslmcode/cores/drupal-7/entity-iframe-consumer.html" "$domain/entity-iframe-consumer.html"
    cp "$elmsln/core/dslmcode/cores/drupal-7/apple-touch-icon-precomposed.png" "$domain/apple-touch-icon-precomposed.png"
    cp "courses/.gitignore" "$domain/.gitignore"
    cp "courses/README.txt" "$domain/README.txt"
  fi
fi

# update the documentation file on apache config
echo "<VirtualHost *:80>" >  $elmsln/docs/domains.txt
echo "    DocumentRoot $elmsln/domains/$domain" >  $elmsln/docs/domains.txt
echo "    ServerName $domain.${address}" >  $elmsln/docs/domains.txt
echo "    ServerAlias ${serviceprefix}${domain}.${serviceaddress}" >  $elmsln/docs/domains.txt
echo "</VirtualHost>" >  $elmsln/docs/domains.txt
echo "<Directory $elmsln/domains/$domain>" >  $elmsln/docs/domains.txt
echo "    AllowOverride All" >  $elmsln/docs/domains.txt
echo "    Order allow,deny" >  $elmsln/docs/domains.txt
echo "    allow from all" >  $elmsln/docs/domains.txt
echo "    Include $elmsln/domains/$domain/.htaccess" >  $elmsln/docs/domains.txt
echo "</Directory>" >  $elmsln/docs/domains.txt

# todo, still need to re-up the _elmsln_scripted key that's been generated
# need to grep into the following file, look to drush-create-site for example
# "$configsdir/shared/drupal-7.x/modules/_elmsln_scripted/${university}/${university}_${host}_settings/${university}_${host}_settings.module
# todo, need to issue a registry resync against CIS
# this will activate the new service once we've populated the info above
elmslnecho "The tool named $domain has now been added to the ELMSLN structure, but the URLs associated to it are not active."
elmslnecho "You should add this to $elmsln/docs/domains.txt for how to hook it up to apache."
elmslnecho "You'll want to add something like the following to /etc/httpd/conf.d/elmsln.conf"
elmslnecho "<VirtualHost *:80>"
elmslnecho "    DocumentRoot $elmsln/domains/$domain"
elmslnecho "    ServerName $domain.${address}"
elmslnecho "    ServerAlias ${serviceprefix}${domain}.${serviceaddress}"
elmslnecho "</VirtualHost>"
elmslnecho "<Directory $elmsln/domains/$domain>"
elmslnecho "    AllowOverride All"
elmslnecho "    Order allow,deny"
elmslnecho "    allow from all"
elmslnecho "    Include $elmsln/domains/$domain/.htaccess"
elmslnecho "</Directory>"
elmslnecho ""
elmslnecho "After that is in place, restart apache and then you should be able to access ${protocol}://${domain}.${address}/README.txt"
