#!/bin/sh
set -e

# ******************** CHECK / INSTALL COMPOSER *************************

if ! composer --version; then
  echo "Install composer";
  apt install -y composer
  apt install -y php-simplexml
fi

# ******************** CHECK / INSTALL DOCKER *************************

if ! docker --version; then
  echo "Install docker";
  apt-get update
  apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
  apt install -y curl
  sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  usermod -aG docker $username
fi

# ******************** STOP AND REMOVER DOCKER CONTAINERS *************************

if [ ! -z "$(docker ps -a -q)" ]; then
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q);
fi

# ******************** CREATE DATA FOLDERS *************************

username=$1
rm -rf $2
mkdir $2
cd $2

dir=$(pwd);

mkdir behatdata
mkdir behatfaildumps
mkdir codelogs
mkdir jenkins
mkdir moodle
mkdir moodledata
mkdir phpunitdata
mkdir postgres

export MOODLE_DOCKER_WWWROOT=$dir/moodle
export MOODLE_DOCKER_WEBSERVERLOGS=$dir/codelogs
export MOODLE_DOCKER_MOODLEDATAROOT=$dir/moodledata
export MOODLE_DOCKER_PHPUNITDATAROOT=$dir/phpunitdata
export MOODLE_DOCKER_BEHATDATAROOT=$dir/behatdata
export MOODLE_DOCKER_BEHATFAILDUMPSDATAROOT=$dir/behatfaildumps
export MOODLE_DOCKER_POSTGRESDATAROOT=$dir/postgres
export MOODLE_DOCKER_JENKINSDATAROOT=$dir/jenkins

chown -R $username:$username *;
chmod -R 777 *;

# ******************** CHECK IF MOODLE TAR EXISTS - OTHERWISE GET CODE FROM BITBUCKET *************************

tarfile=`find ../ -maxdepth 1 -name "*.tar.*" | head -1`
if [ -z "$tarfile" ]; then

    # ******************** GIT CLONE BUILD SCRIPTS *************************

    set +e
    git clone ssh://git@bitbucket.apps.monash.edu:7999/eass/build-scripts.git
    git clone ssh://git@bitbucket.apps.monash.edu:7999/eass/vagrant-dev.git

    # ******************** REPLACE BUILD.XML WITH CUSTOM BUILD.XML *************************

    cd build-scripts/
    rm build.xml
    cp ../../additional_files/build.xml build.xml

    composer install --no-dev

    # ******************** START PHING RUNNER *************************

    getgit=1
    gitcount=1
    while [[ "$getgit" == "1" ]]
    do
      ((gitcount++))
      if [ $gitcount -gt 5 ]; then
        exit 1
      fi
      vendor/bin/phing package-retain-git
      if [ "$?" = "0" ]; then
        getgit=0
      else
        echo "Attempt $gitcount failed. Waiting 30 seconds"
        sleep 30
      fi
    done

    # ******************** END PHING RUNNER *************************


    # ******************** CLEANUP OBSOLETE FOLDERS *************************
    cd ..
    rm -rf moodle 2> /dev/null
    mv ./vagrant-dev/* ./
    rm -rf ./vagrant-dev

    # ******************** MOVE TAR TO PARENT FOLDER *************************

    mv ./build-scripts/artefacts/eass-app-0.0.1.tar.gz ../eass-app-0.0.1.tar.gz

fi

set -e
# ******************** UNPACK MOODLE CODE TO MOODLE FOLDER *************************

cd $dir;
cd moodle;
tarfile=`find ../../ -maxdepth 1 -name "*.tar.*" | head -1`
if [ ! -z "$tarfile" ]; then
    tar --force-local -vxzf $tarfile
fi

# ******************** BACKUP CONFIG.PHP *************************

configfile=`find ./ -maxdepth 1 -name "config.php" | head -1`
if [ ! -z "$configfile" ]; then
  mv config.php config.php.bak
fi

# ******************** INCLUDE MOOSH & ADMINER *************************
# MOOSH - MOOdle SHell - commandline tool for Moodle tasks - https://moosh-online.com/
# ADMINER - Database management in a single PHP file - https://www.adminer.org/

cp -r ../../additional_files/moosh moosh
cp -r ../../additional_files/adminer adminer
cd ..

# ******************** GIT CLONE DOCKER TEST RUNNER *************************

git clone ssh://git@bitbucket.apps.monash.edu:7999/eass/docker-ci_testrunner.git
cd docker-ci_testrunner

# ******************** ROLLBACK TO 03/08/2019 WORKAROUND FOR UID ERRORS *************************
git checkout 1300f4cd7764079896c498b9b8138bf0384c2a29

set +e
sed -i '/${MOODLE_DOCKER_WEBSERVERLOGS}\/nginx/d' base.yml
# **********************************END WORKAROUND********************************

./bin/moodle-docker-compose up -d
echo "Wait 15 seconds to allow container up to complete"
sleep 15
set -e

phpID=$(docker ps -aqf "name=phpfpm_1");
psqlID=$(docker ps -aqf "name=db_1");

# ******************** INSTALL DATABASE *************************
cd $dir;
git apply --directory=moodle/theme/monash --reject -v ../additional_files/patch/theme_monash.patch

sed -i 's/2018120300/2018051704/' moodle/local/boostnavigation/version.php

docker exec --user www-data $phpID php admin/cli/install_database.php --agree-license --adminpass=admin --adminemail=admin@localhost.com --shortname=moodle --fullname=moodle --summary=moodle

# ******************** SKIP REGISTRATION PAGE*************************

docker exec --user www-data $phpID php moosh/moosh.php config-set registrationpending 0 core

# ******************** ADD MOODLE USERS *************************

users=( student student1 student2 teacher teacher1)
for i in "${users[@]}"
do
	docker exec --user www-data $phpID php moosh/moosh.php user-create --password $i --email $i@localhost.com --firstname $i --lastname $i $i
done

# ******************** IMPORT COUSE BACKUPS *************************

cd $dir;
cd moodle;
for filename in ../../additional_files/MoodleCourseImport/*.mbz
do
  echo $filename
  cp "$filename" courseimport.mbz
  docker exec -it --user www-data $phpID php moosh/moosh.php course-restore courseimport.mbz 1
  rm courseimport.mbz
done

# ******************** CREATE ADMIN USER FOR PSQL *************************

docker exec -it --user postgres $psqlID psql -U moodle -c "CREATE ROLE admin SUPERUSER CREATEDB CREATEROLE LOGIN;"
docker exec -it --user postgres $psqlID psql -U moodle -c "ALTER USER admin WITH PASSWORD 'admin';"
